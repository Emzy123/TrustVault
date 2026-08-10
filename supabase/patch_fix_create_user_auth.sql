-- Fix super-admin-created (and other manual) users that cannot log in.
-- Error: "Database error querying schema" / formatErrorMessage schema hint
--
-- Causes:
--   • create_user_account inserted auth.users without auth.identities
--   • Some rows may have NULL token columns (GoTrue requires empty strings)

-- ---------------------------------------------------------------------------
-- 1. Repair existing auth.users rows
-- ---------------------------------------------------------------------------

UPDATE auth.users SET confirmation_token = '' WHERE confirmation_token IS NULL;
UPDATE auth.users SET recovery_token = '' WHERE recovery_token IS NULL;
UPDATE auth.users SET email_change = '' WHERE email_change IS NULL;
UPDATE auth.users SET email_change_token_new = '' WHERE email_change_token_new IS NULL;

INSERT INTO auth.identities (
  id,
  user_id,
  identity_data,
  provider,
  provider_id,
  last_sign_in_at,
  created_at,
  updated_at
)
SELECT
  gen_random_uuid(),
  u.id,
  jsonb_build_object(
    'sub', u.id::text,
    'email', u.email,
    'email_verified', u.email_confirmed_at IS NOT NULL,
    'phone_verified', false
  ),
  'email',
  u.id::text,
  COALESCE(u.last_sign_in_at, u.created_at, NOW()),
  COALESCE(u.created_at, NOW()),
  COALESCE(u.updated_at, NOW())
FROM auth.users u
WHERE u.email IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM auth.identities i
    WHERE i.user_id = u.id AND i.provider = 'email'
  );

-- ---------------------------------------------------------------------------
-- 2. Fix create_user_account for future super-admin creations
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.create_user_account(
  p_email TEXT,
  p_full_name TEXT,
  p_role TEXT DEFAULT 'user',
  p_password TEXT DEFAULT 'TrustVault123!'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_email TEXT;
  v_full_name TEXT;
  v_role public.user_role;
  v_user_id UUID;
  v_encrypted_pw TEXT;
  v_next_acc TEXT;
  v_instance_id UUID;
  v_password TEXT;
BEGIN
  IF NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  v_email := LOWER(TRIM(p_email));
  IF v_email IS NULL OR v_email !~ '^[^@]+@[^@]+\.[^@]+$' THEN
    RAISE EXCEPTION 'Valid email address is required';
  END IF;

  v_full_name := TRIM(COALESCE(p_full_name, ''));
  IF v_full_name = '' THEN
    RAISE EXCEPTION 'Full name is required';
  END IF;

  IF p_role NOT IN ('user', 'admin', 'super_admin') THEN
    RAISE EXCEPTION 'Role must be user, admin, or super_admin';
  END IF;
  v_role := p_role::public.user_role;

  IF EXISTS (SELECT 1 FROM auth.users WHERE LOWER(email) = v_email) THEN
    RAISE EXCEPTION 'An account with this email already exists';
  END IF;

  IF EXISTS (SELECT 1 FROM public.profiles WHERE LOWER(email) = v_email) THEN
    RAISE EXCEPTION 'An account with this email already exists';
  END IF;

  SELECT instance_id INTO v_instance_id FROM auth.users WHERE instance_id IS NOT NULL LIMIT 1;
  IF v_instance_id IS NULL THEN
    v_instance_id := '00000000-0000-0000-0000-000000000000'::UUID;
  END IF;

  v_password := COALESCE(NULLIF(TRIM(p_password), ''), 'TrustVault123!');
  v_user_id := gen_random_uuid();
  v_encrypted_pw := extensions.crypt(v_password, extensions.gen_salt('bf'));

  INSERT INTO auth.users (
    id,
    instance_id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    confirmation_token,
    recovery_token,
    email_change_token_new,
    email_change,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at
  ) VALUES (
    v_user_id,
    v_instance_id,
    'authenticated',
    'authenticated',
    v_email,
    v_encrypted_pw,
    NOW(),
    '', '', '', '',
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object('full_name', v_full_name),
    NOW(),
    NOW()
  );

  INSERT INTO auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    provider_id,
    last_sign_in_at,
    created_at,
    updated_at
  ) VALUES (
    gen_random_uuid(),
    v_user_id,
    jsonb_build_object(
      'sub', v_user_id::text,
      'email', v_email,
      'email_verified', true,
      'phone_verified', false
    ),
    'email',
    v_user_id::text,
    NOW(),
    NOW(),
    NOW()
  );

  INSERT INTO public.profiles (
    id, full_name, email, role, account_status, kyc_status
  ) VALUES (
    v_user_id, v_full_name, v_email, v_role, 'verified', 'approved'
  )
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    email = EXCLUDED.email,
    role = EXCLUDED.role,
    account_status = 'verified',
    kyc_status = 'approved';

  IF NOT EXISTS (
    SELECT 1 FROM public.accounts
    WHERE profile_id = v_user_id AND is_system = FALSE
  ) THEN
    v_next_acc := LPAD(nextval('public.account_number_seq')::TEXT, 10, '0');
    INSERT INTO public.accounts (profile_id, balance, currency, account_number)
    VALUES (v_user_id, 0, 'NGN', v_next_acc)
    ON CONFLICT (profile_id) DO NOTHING;
  END IF;

  PERFORM public.write_audit_log(
    'user.created',
    v_user_id,
    jsonb_build_object('email', v_email, 'role', p_role, 'full_name', v_full_name)
  );

  RETURN v_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.create_user_account(TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_user_account(TEXT, TEXT, TEXT, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
