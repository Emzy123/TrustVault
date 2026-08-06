-- TrustVault: Super Admin user creation and account deletion RPC functions

CREATE OR REPLACE FUNCTION public.create_user_account(
  p_email TEXT,
  p_full_name TEXT,
  p_role TEXT DEFAULT 'user',
  p_password TEXT DEFAULT 'TrustVault123!'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_email TEXT;
  v_full_name TEXT;
  v_role public.user_role;
  v_user_id UUID;
  v_encrypted_pw TEXT;
  v_next_acc TEXT;
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

  IF EXISTS (SELECT 1 FROM public.profiles WHERE LOWER(email) = v_email) THEN
    RAISE EXCEPTION 'An account with this email already exists';
  END IF;

  v_user_id := gen_random_uuid();
  v_encrypted_pw := extensions.crypt(COALESCE(p_password, 'TrustVault123!'), extensions.gen_salt('bf'));

  INSERT INTO auth.users (
    id,
    instance_id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at
  ) VALUES (
    v_user_id,
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    v_email,
    v_encrypted_pw,
    NOW(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object('full_name', v_full_name, 'role', p_role),
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

  IF NOT EXISTS (SELECT 1 FROM public.accounts WHERE profile_id = v_user_id AND is_system = FALSE) THEN
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

CREATE OR REPLACE FUNCTION public.delete_user_account(
  p_profile_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_target public.profiles%ROWTYPE;
  v_super_admin_count INT;
BEGIN
  IF NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF p_profile_id = auth.uid() THEN
    RAISE EXCEPTION 'You cannot delete your own account';
  END IF;

  SELECT * INTO v_target FROM public.profiles WHERE id = p_profile_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profile not found';
  END IF;

  IF v_target.role = 'super_admin' THEN
    SELECT COUNT(*) INTO v_super_admin_count
    FROM public.profiles
    WHERE role = 'super_admin';

    IF v_super_admin_count <= 1 THEN
      RAISE EXCEPTION 'Cannot delete the last super admin';
    END IF;
  END IF;

  PERFORM public.write_audit_log(
    'user.deleted',
    p_profile_id,
    jsonb_build_object(
      'email', v_target.email,
      'full_name', v_target.full_name,
      'role', v_target.role
    )
  );

  DELETE FROM public.flags WHERE raised_by = p_profile_id OR transaction_id IN (
    SELECT id FROM public.transactions WHERE initiated_by = p_profile_id
  );
  DELETE FROM public.kyc_submissions WHERE profile_id = p_profile_id;
  DELETE FROM public.funding_requests WHERE profile_id = p_profile_id;
  DELETE FROM public.admin_invitations WHERE invited_by = p_profile_id OR profile_id = p_profile_id;

  DELETE FROM public.ledger_entries WHERE account_id IN (
    SELECT id FROM public.accounts WHERE profile_id = p_profile_id
  );

  DELETE FROM public.transactions WHERE initiated_by = p_profile_id
    OR from_account_id IN (SELECT id FROM public.accounts WHERE profile_id = p_profile_id)
    OR to_account_id IN (SELECT id FROM public.accounts WHERE profile_id = p_profile_id);

  DELETE FROM public.accounts WHERE profile_id = p_profile_id;
  DELETE FROM public.profiles WHERE id = p_profile_id;
  DELETE FROM auth.users WHERE id = p_profile_id;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_user_account(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_user_account(UUID) TO authenticated;
