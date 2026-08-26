-- Reliable "Get code" retrieval: store short-lived plain OTP on registration_otps
-- (email_outbox alone fails when migrations/outbox rows are missing).

ALTER TABLE public.registration_otps
  ADD COLUMN IF NOT EXISTS otp_code TEXT;

CREATE OR REPLACE FUNCTION public.request_registration_otp(p_email TEXT)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_email TEXT;
  v_otp TEXT;
  v_otp_hash TEXT;
  v_outbox_id UUID;
BEGIN
  v_email := LOWER(TRIM(p_email));
  IF v_email IS NULL OR v_email !~ '^[^@]+@[^@]+\.[^@]+$' THEN
    RAISE EXCEPTION 'Valid email address is required';
  END IF;

  IF EXISTS (SELECT 1 FROM auth.users WHERE LOWER(email) = v_email) THEN
    RAISE EXCEPTION 'An account with this email already exists';
  END IF;

  IF (
    SELECT COUNT(*) FROM public.registration_otps
    WHERE LOWER(email) = v_email
      AND created_at >= NOW() - INTERVAL '15 minutes'
  ) >= 3 THEN
    RAISE EXCEPTION 'Too many verification codes requested. Please wait before trying again.';
  END IF;

  v_otp := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
  v_otp_hash := crypt(v_otp, gen_salt('bf'));

  INSERT INTO public.registration_otps (email, otp_hash, otp_code, expires_at)
  VALUES (v_email, v_otp_hash, v_otp, NOW() + INTERVAL '10 minutes');

  v_outbox_id := public.queue_email(
    v_email,
    'registration_otp',
    'Your Atlas verification code',
    jsonb_build_object('otp', v_otp, 'expires_minutes', 10)
  );

  RETURN v_outbox_id;
END;
$$;

REVOKE ALL ON FUNCTION public.request_registration_otp(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.request_registration_otp(TEXT) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_registration_otp(p_email TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_otp TEXT;
  v_email TEXT;
BEGIN
  v_email := LOWER(TRIM(p_email));

  SELECT otp_code INTO v_otp
  FROM public.registration_otps
  WHERE LOWER(email) = v_email
    AND verified_at IS NULL
    AND expires_at > NOW()
    AND otp_code IS NOT NULL
    AND LENGTH(TRIM(otp_code)) = 6
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_otp IS NOT NULL THEN
    RETURN v_otp;
  END IF;

  SELECT payload->>'otp' INTO v_otp
  FROM public.email_outbox
  WHERE LOWER(recipient_email) = v_email
    AND template_key = 'registration_otp'
    AND payload ? 'otp'
    AND COALESCE(payload->>'otp', '') <> ''
  ORDER BY created_at DESC
  LIMIT 1;

  RETURN v_otp;
END;
$$;

REVOKE ALL ON FUNCTION public.get_registration_otp(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_registration_otp(TEXT) TO anon, authenticated;
