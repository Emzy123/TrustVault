-- Return the latest generated registration OTP when email delivery is unavailable.

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
