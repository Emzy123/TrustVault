-- Run in Supabase SQL Editor if migrations are already applied on the hosted project.
-- Makes every newly registered / created wallet use a unique 11-digit account number.

CREATE OR REPLACE FUNCTION public.next_account_number()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  v_next BIGINT;
BEGIN
  v_next := nextval('public.account_number_seq');
  IF v_next < 10000000000 THEN
    PERFORM setval('public.account_number_seq', 10000000000, true);
    v_next := nextval('public.account_number_seq');
  END IF;
  RETURN LPAD(v_next::TEXT, 11, '0');
END;
$$;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role public.user_role := 'user';
  v_next_acc TEXT;
  v_invite public.admin_invitations%ROWTYPE;
BEGIN
  IF NEW.email = 'admin@trustvault.demo' THEN
    v_role := 'admin';
  ELSIF NEW.email = 'superadmin@trustvault.demo' THEN
    v_role := 'super_admin';
  END IF;

  IF v_role = 'user' AND NEW.email IS NOT NULL THEN
    SELECT * INTO v_invite
    FROM public.admin_invitations
    WHERE LOWER(email) = LOWER(NEW.email)
      AND accepted_at IS NULL
    LIMIT 1;

    IF FOUND THEN
      v_role := v_invite.role;
    END IF;
  END IF;

  INSERT INTO public.profiles (id, full_name, email, phone, role, account_status, kyc_status)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data ->> 'full_name', ''),
    COALESCE(NEW.email, ''),
    NEW.raw_user_meta_data ->> 'phone',
    v_role,
    'unverified',
    'not_submitted'
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    phone = COALESCE(EXCLUDED.phone, public.profiles.phone),
    role = CASE
      WHEN EXCLUDED.email IN ('admin@trustvault.demo', 'superadmin@trustvault.demo') THEN v_role
      WHEN public.profiles.role IN ('admin', 'super_admin') THEN public.profiles.role
      ELSE EXCLUDED.role
    END,
    full_name = CASE WHEN EXCLUDED.full_name <> '' THEN EXCLUDED.full_name ELSE public.profiles.full_name END;

  IF v_invite.id IS NOT NULL THEN
    UPDATE public.admin_invitations
    SET accepted_at = NOW(), profile_id = NEW.id
    WHERE id = v_invite.id AND accepted_at IS NULL;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.accounts WHERE profile_id = NEW.id AND is_system = FALSE) THEN
    v_next_acc := public.next_account_number();
    INSERT INTO public.accounts (profile_id, balance, currency, account_number)
    VALUES (NEW.id, 0, 'NGN', v_next_acc)
    ON CONFLICT (profile_id) DO NOTHING;
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'handle_new_user trigger error: %', SQLERRM;
  RETURN NEW;
END;
$$;

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
    id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
    confirmation_token, recovery_token, email_change_token_new, email_change,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
  ) VALUES (
    v_user_id, v_instance_id, 'authenticated', 'authenticated', v_email, v_encrypted_pw, NOW(),
    '', '', '', '',
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object('full_name', v_full_name),
    NOW(), NOW()
  );

  INSERT INTO auth.identities (
    id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
  ) VALUES (
    gen_random_uuid(), v_user_id,
    jsonb_build_object('sub', v_user_id::text, 'email', v_email, 'email_verified', true, 'phone_verified', false),
    'email', v_user_id::text, NOW(), NOW(), NOW()
  );

  INSERT INTO public.profiles (id, full_name, email, role, account_status, kyc_status)
  VALUES (v_user_id, v_full_name, v_email, v_role, 'verified', 'approved')
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    email = EXCLUDED.email,
    role = EXCLUDED.role,
    account_status = 'verified',
    kyc_status = 'approved';

  IF NOT EXISTS (
    SELECT 1 FROM public.accounts WHERE profile_id = v_user_id AND is_system = FALSE
  ) THEN
    v_next_acc := public.next_account_number();
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
