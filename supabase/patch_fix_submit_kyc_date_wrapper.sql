-- Quick fix: replace submit_kyc wrapper that called the dropped DATE overload.
-- Run this in Supabase SQL Editor if you see:
--   function public.submit_kyc(text,text,date,text,text) does not exist

ALTER TABLE public.kyc_submissions
  ADD COLUMN IF NOT EXISTS level INTEGER NOT NULL DEFAULT 1;

DROP FUNCTION IF EXISTS public.submit_kyc(TEXT, TEXT, DATE, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.submit_kyc(TEXT, TEXT, TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.submit_kyc(
  p_id_type TEXT,
  p_id_number TEXT,
  p_dob TEXT,
  p_address TEXT,
  p_document_url TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_submission_id UUID;
  v_profile public.profiles%ROWTYPE;
  v_dob DATE;
BEGIN
  PERFORM public.enforce_rate_limit('kyc_submit', 3, 3600);

  SELECT * INTO v_profile FROM public.profiles WHERE id = auth.uid();
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profile not found';
  END IF;

  IF v_profile.account_status = 'frozen' THEN
    RAISE EXCEPTION 'Account is frozen';
  END IF;

  IF v_profile.kyc_status IN ('pending', 'approved') THEN
    RAISE EXCEPTION 'KYC already submitted or approved';
  END IF;

  IF p_id_type IS NULL OR LENGTH(TRIM(p_id_type)) < 2 THEN
    RAISE EXCEPTION 'Valid ID type is required';
  END IF;

  IF p_id_number IS NULL OR LENGTH(TRIM(p_id_number)) < 4 THEN
    RAISE EXCEPTION 'Valid ID number is required';
  END IF;

  IF p_address IS NULL OR LENGTH(TRIM(p_address)) < 5 THEN
    RAISE EXCEPTION 'Valid address is required';
  END IF;

  BEGIN
    v_dob := p_dob::DATE;
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Invalid date of birth format';
  END;

  IF v_dob IS NULL OR v_dob > CURRENT_DATE - INTERVAL '18 years' THEN
    RAISE EXCEPTION 'You must be at least 18 years old';
  END IF;

  INSERT INTO public.kyc_submissions (
    profile_id, id_type, id_number, dob, address, document_url, status, level
  )
  VALUES (
    auth.uid(),
    public.sanitize_text(p_id_type, 50),
    public.sanitize_text(p_id_number, 50),
    v_dob,
    public.sanitize_text(p_address, 300),
    public.sanitize_text(p_document_url, 500),
    'pending',
    1
  )
  RETURNING id INTO v_submission_id;

  UPDATE public.profiles
  SET kyc_status = 'pending', account_status = 'unverified'
  WHERE id = auth.uid();

  RETURN v_submission_id;
END;
$$;

DROP FUNCTION IF EXISTS public.submit_kyc_level1(TEXT, TEXT, TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.submit_kyc_level1(
  p_id_type TEXT,
  p_id_number TEXT,
  p_dob TEXT,
  p_address TEXT,
  p_document_url TEXT DEFAULT NULL
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_submission_id UUID;
BEGIN
  v_submission_id := public.submit_kyc(
    p_id_type,
    p_id_number,
    p_dob,
    p_address,
    p_document_url
  );

  RETURN v_submission_id::TEXT;
END;
$$;

REVOKE ALL ON FUNCTION public.submit_kyc(TEXT, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_kyc(TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.submit_kyc_level1(TEXT, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_kyc_level1(TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
