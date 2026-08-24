-- Fix hosted Supabase auth + registration issues.
-- Run once in Supabase Dashboard → SQL Editor (project xrumgoeuzufxidxwwusm).
--
-- Resolves:
--   • Login 500 "Database error querying schema" (NULL auth token columns, missing identities)
--   • Registration "column kyc_level does not exist" (outdated complete_registration from setup script)

-- ---------------------------------------------------------------------------
-- 1. Optional column used by the Flutter app
-- ---------------------------------------------------------------------------

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS kyc_level INTEGER NOT NULL DEFAULT 0;

-- ---------------------------------------------------------------------------
-- 2. GoTrue requires non-NULL string token columns on auth.users
-- ---------------------------------------------------------------------------

UPDATE auth.users SET confirmation_token = '' WHERE confirmation_token IS NULL;
UPDATE auth.users SET recovery_token = '' WHERE recovery_token IS NULL;
UPDATE auth.users SET email_change = '' WHERE email_change IS NULL;
UPDATE auth.users SET email_change_token_new = '' WHERE email_change_token_new IS NULL;

-- ---------------------------------------------------------------------------
-- 3. Email/password sign-in requires auth.identities rows
-- ---------------------------------------------------------------------------

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
-- 4. Restore canonical complete_registration (migration version)
-- ---------------------------------------------------------------------------

DROP FUNCTION IF EXISTS public.complete_registration(TEXT, TEXT, TEXT, TEXT, TEXT) CASCADE;

CREATE OR REPLACE FUNCTION public.complete_registration(
  p_email TEXT,
  p_otp TEXT,
  p_password TEXT,
  p_full_name TEXT,
  p_phone TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_email TEXT;
  v_otp_row public.registration_otps%ROWTYPE;
  v_user_id UUID;
  v_encrypted_pw TEXT;
  v_instance_id UUID;
  v_full_name TEXT;
  v_phone TEXT;
BEGIN
  v_email := LOWER(TRIM(p_email));
  v_full_name := TRIM(p_full_name);
  v_phone := TRIM(p_phone);

  IF v_email IS NULL OR v_email !~ '^[^@]+@[^@]+\.[^@]+$' THEN
    RAISE EXCEPTION 'Valid email address is required';
  END IF;

  IF p_otp IS NULL OR LENGTH(TRIM(p_otp)) <> 6 THEN
    RAISE EXCEPTION 'Enter the 6-digit verification code';
  END IF;

  IF p_password IS NULL OR LENGTH(p_password) < 8 THEN
    RAISE EXCEPTION 'Password must be at least 8 characters';
  END IF;

  IF v_full_name IS NULL OR LENGTH(v_full_name) < 2 THEN
    RAISE EXCEPTION 'Full name is required';
  END IF;

  IF v_phone IS NULL OR LENGTH(v_phone) < 6 THEN
    RAISE EXCEPTION 'Phone number is required';
  END IF;

  IF EXISTS (SELECT 1 FROM auth.users WHERE LOWER(email) = v_email) THEN
    RAISE EXCEPTION 'An account with this email already exists';
  END IF;

  SELECT * INTO v_otp_row
  FROM public.registration_otps
  WHERE LOWER(email) = v_email
    AND verified_at IS NULL
    AND expires_at > NOW()
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Verification code expired or not found. Request a new code.';
  END IF;

  IF v_otp_row.attempts >= 5 THEN
    RAISE EXCEPTION 'Too many failed attempts. Request a new verification code.';
  END IF;

  IF v_otp_row.otp_hash <> crypt(TRIM(p_otp), v_otp_row.otp_hash) THEN
    UPDATE public.registration_otps
    SET attempts = attempts + 1
    WHERE id = v_otp_row.id;
    RAISE EXCEPTION 'Invalid verification code';
  END IF;

  UPDATE public.registration_otps
  SET verified_at = NOW()
  WHERE id = v_otp_row.id;

  SELECT instance_id INTO v_instance_id FROM auth.users WHERE instance_id IS NOT NULL LIMIT 1;
  IF v_instance_id IS NULL THEN
    v_instance_id := '00000000-0000-0000-0000-000000000000'::UUID;
  END IF;

  v_user_id := gen_random_uuid();
  v_encrypted_pw := crypt(p_password, gen_salt('bf'));

  INSERT INTO auth.users (
    id, instance_id, email, encrypted_password, email_confirmed_at,
    confirmation_token, recovery_token, email_change_token_new, email_change,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
  )
  VALUES (
    v_user_id,
    v_instance_id,
    v_email,
    v_encrypted_pw,
    NOW(),
    '', '', '', '',
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object('full_name', v_full_name, 'phone', v_phone),
    NOW(), NOW(),
    'authenticated', 'authenticated'
  );

  INSERT INTO auth.identities (
    id, user_id, identity_data, provider, provider_id,
    last_sign_in_at, created_at, updated_at
  )
  VALUES (
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
    NOW(), NOW(), NOW()
  );

  PERFORM public.queue_email(
    v_email,
    'welcome',
    'Welcome to TrustVault — your account is ready',
    jsonb_build_object('full_name', v_full_name)
  );

  PERFORM public.queue_email(
    v_email,
    'kyc_prompt',
    'Complete identity verification to unlock your wallet',
    jsonb_build_object('full_name', v_full_name)
  );

  RETURN v_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.complete_registration(TEXT, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.complete_registration(TEXT, TEXT, TEXT, TEXT, TEXT) TO anon, authenticated;

DROP FUNCTION IF EXISTS public.get_registration_otp(TEXT) CASCADE;
CREATE OR REPLACE FUNCTION public.get_registration_otp(p_email TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_otp TEXT;
BEGIN
  SELECT payload->>'otp' INTO v_otp
  FROM public.email_outbox
  WHERE LOWER(recipient_email) = LOWER(TRIM(p_email))
    AND template_key = 'registration_otp'
  ORDER BY created_at DESC
  LIMIT 1;

  RETURN v_otp;
END;
$$;

REVOKE ALL ON FUNCTION public.get_registration_otp(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_registration_otp(TEXT) TO anon, authenticated;
