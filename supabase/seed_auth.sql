-- Demo auth users (Password: Password123!)
-- Runs after migrations, before seed.sql narrative data.

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

CREATE OR REPLACE FUNCTION public.seed_auth_user(
  p_email TEXT,
  p_password TEXT,
  p_full_name TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_user_id UUID;
  v_encrypted_pw TEXT;
  v_instance_id UUID;
BEGIN
  SELECT instance_id INTO v_instance_id FROM auth.users WHERE instance_id IS NOT NULL LIMIT 1;
  IF v_instance_id IS NULL THEN
    v_instance_id := '00000000-0000-0000-0000-000000000000'::UUID;
  END IF;

  v_encrypted_pw := extensions.crypt(p_password, extensions.gen_salt('bf'));
  SELECT id INTO v_user_id FROM auth.users WHERE email = p_email;

  IF v_user_id IS NULL THEN
    v_user_id := gen_random_uuid();

    INSERT INTO auth.users (
      id, instance_id, email, encrypted_password, email_confirmed_at,
      confirmation_token, recovery_token, email_change_token_new, email_change,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
    )
    VALUES (
      v_user_id,
      v_instance_id,
      p_email,
      v_encrypted_pw,
      NOW(),
      '', '', '', '',
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('full_name', p_full_name, 'phone', '+2348000000000'),
      NOW(), NOW(),
      'authenticated', 'authenticated'
    );
  ELSE
    UPDATE auth.users
    SET encrypted_password = v_encrypted_pw,
        email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
        instance_id = v_instance_id,
        raw_user_meta_data = jsonb_build_object('full_name', p_full_name, 'phone', '+2348000000000'),
        updated_at = NOW()
    WHERE id = v_user_id;
  END IF;

  RETURN v_user_id;
END;
$$;

DO $$
DECLARE
  v_alice_id UUID;
  v_bob_id UUID;
  v_charlie_id UUID;
  v_admin_id UUID;
  v_superadmin_id UUID;
BEGIN
  v_alice_id := public.seed_auth_user('alice@trustvault.demo', 'Password123!', 'Alice Vance');
  v_bob_id := public.seed_auth_user('bob@trustvault.demo', 'Password123!', 'Bob Builder');
  v_charlie_id := public.seed_auth_user('charlie@trustvault.demo', 'Password123!', 'Charlie Brown');
  v_admin_id := public.seed_auth_user('admin@trustvault.demo', 'Password123!', 'Admin Officer');
  v_superadmin_id := public.seed_auth_user('superadmin@trustvault.demo', 'Password123!', 'Super Admin Officer');

  UPDATE public.profiles SET role = 'user', account_status = 'active', kyc_status = 'approved'
  WHERE id = v_alice_id;

  UPDATE public.profiles SET role = 'user', account_status = 'verified', kyc_status = 'approved'
  WHERE id = v_bob_id;

  UPDATE public.profiles SET role = 'user', account_status = 'unverified', kyc_status = 'not_submitted'
  WHERE id = v_charlie_id;

  UPDATE public.profiles SET role = 'admin', account_status = 'verified', kyc_status = 'approved'
  WHERE id = v_admin_id;

  UPDATE public.profiles SET role = 'super_admin', account_status = 'verified', kyc_status = 'approved'
  WHERE id = v_superadmin_id;

  UPDATE public.accounts
  SET balance = 1000000000.00
  WHERE is_system = TRUE AND label = 'Platform Treasury';
END $$;
