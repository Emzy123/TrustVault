-- Atlas: KYC level RPCs + submit_kyc overload fix
-- Run in Supabase Dashboard → SQL Editor after patch_fix_hosted_auth.sql

-- ---------------------------------------------------------------------------
-- 1. Schema additions for multi-level KYC
-- ---------------------------------------------------------------------------

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS kyc_level INTEGER NOT NULL DEFAULT 0;

ALTER TABLE public.kyc_submissions
  ADD COLUMN IF NOT EXISTS level INTEGER NOT NULL DEFAULT 1;

ALTER TABLE public.kyc_submissions
  ADD COLUMN IF NOT EXISTS face_image_url TEXT;

ALTER TABLE public.kyc_submissions
  ADD COLUMN IF NOT EXISTS match_score NUMERIC(5, 2);

ALTER TABLE public.kyc_submissions
  ADD COLUMN IF NOT EXISTS proof_of_address_url TEXT;

-- PostgREST cannot pick between DATE vs TEXT p_dob overloads — keep one TEXT implementation.
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

REVOKE ALL ON FUNCTION public.submit_kyc(TEXT, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_kyc(TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- 2. Level 1 — government ID (wraps submit_kyc)
-- ---------------------------------------------------------------------------

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

  UPDATE public.kyc_submissions
  SET level = 1
  WHERE id = v_submission_id;

  RETURN v_submission_id::TEXT;
END;
$$;

-- ---------------------------------------------------------------------------
-- 3. Level 2 — biometric face match
-- ---------------------------------------------------------------------------

DROP FUNCTION IF EXISTS public.submit_kyc_level2(TEXT, NUMERIC);
DROP FUNCTION IF EXISTS public.submit_kyc_level2(TEXT, DOUBLE PRECISION);

CREATE OR REPLACE FUNCTION public.submit_kyc_level2(
  p_face_image_url TEXT,
  p_match_score NUMERIC DEFAULT 94.5
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile public.profiles%ROWTYPE;
  v_prev public.kyc_submissions%ROWTYPE;
  v_submission_id UUID;
BEGIN
  PERFORM public.enforce_rate_limit('kyc_submit', 10, 3600);

  SELECT * INTO v_profile FROM public.profiles WHERE id = auth.uid();
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profile not found';
  END IF;

  IF v_profile.kyc_level < 1 OR v_profile.kyc_status <> 'approved' THEN
    RAISE EXCEPTION 'Complete and get Level 1 approved before Level 2';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.kyc_submissions
    WHERE profile_id = auth.uid() AND level = 2 AND status = 'pending'
  ) THEN
    RAISE EXCEPTION 'Level 2 submission is already pending review';
  END IF;

  SELECT * INTO v_prev
  FROM public.kyc_submissions
  WHERE profile_id = auth.uid() AND level = 1 AND status = 'approved'
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Approved Level 1 submission not found';
  END IF;

  IF p_face_image_url IS NULL OR LENGTH(TRIM(p_face_image_url)) < 5 THEN
    RAISE EXCEPTION 'Face image URL is required';
  END IF;

  INSERT INTO public.kyc_submissions (
    profile_id, id_type, id_number, dob, address,
    document_url, status, level, face_image_url, match_score
  )
  VALUES (
    auth.uid(),
    v_prev.id_type,
    v_prev.id_number,
    v_prev.dob,
    v_prev.address,
    public.sanitize_text(p_face_image_url, 500),
    'pending',
    2,
    public.sanitize_text(p_face_image_url, 500),
    p_match_score
  )
  RETURNING id INTO v_submission_id;

  UPDATE public.profiles
  SET kyc_status = 'pending', account_status = 'unverified'
  WHERE id = auth.uid();

  RETURN v_submission_id::TEXT;
END;
$$;

-- ---------------------------------------------------------------------------
-- 4. Level 3 — proof of address
-- ---------------------------------------------------------------------------

DROP FUNCTION IF EXISTS public.submit_kyc_level3(TEXT);

CREATE OR REPLACE FUNCTION public.submit_kyc_level3(
  p_proof_of_address_url TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile public.profiles%ROWTYPE;
  v_prev public.kyc_submissions%ROWTYPE;
  v_submission_id UUID;
BEGIN
  PERFORM public.enforce_rate_limit('kyc_submit', 10, 3600);

  SELECT * INTO v_profile FROM public.profiles WHERE id = auth.uid();
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profile not found';
  END IF;

  IF v_profile.kyc_level < 2 OR v_profile.kyc_status <> 'approved' THEN
    RAISE EXCEPTION 'Complete and get Level 2 approved before Level 3';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.kyc_submissions
    WHERE profile_id = auth.uid() AND level = 3 AND status = 'pending'
  ) THEN
    RAISE EXCEPTION 'Level 3 submission is already pending review';
  END IF;

  SELECT * INTO v_prev
  FROM public.kyc_submissions
  WHERE profile_id = auth.uid() AND level = 2 AND status = 'approved'
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Approved Level 2 submission not found';
  END IF;

  IF p_proof_of_address_url IS NULL OR LENGTH(TRIM(p_proof_of_address_url)) < 5 THEN
    RAISE EXCEPTION 'Proof of address URL is required';
  END IF;

  INSERT INTO public.kyc_submissions (
    profile_id, id_type, id_number, dob, address,
    document_url, status, level, proof_of_address_url
  )
  VALUES (
    auth.uid(),
    v_prev.id_type,
    v_prev.id_number,
    v_prev.dob,
    v_prev.address,
    public.sanitize_text(p_proof_of_address_url, 500),
    'pending',
    3,
    public.sanitize_text(p_proof_of_address_url, 500)
  )
  RETURNING id INTO v_submission_id;

  UPDATE public.profiles
  SET kyc_status = 'pending', account_status = 'unverified'
  WHERE id = auth.uid();

  RETURN v_submission_id::TEXT;
END;
$$;

-- ---------------------------------------------------------------------------
-- 5. Admin review — bump kyc_level on approval
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.review_kyc_submission(
  p_submission_id UUID,
  p_approve BOOLEAN,
  p_decline_reason TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_submission public.kyc_submissions%ROWTYPE;
  v_level INTEGER;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT * INTO v_submission
  FROM public.kyc_submissions
  WHERE id = p_submission_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'KYC submission not found';
  END IF;

  IF v_submission.status <> 'pending' THEN
    RAISE EXCEPTION 'KYC submission is not pending';
  END IF;

  v_level := COALESCE(v_submission.level, 1);

  IF p_approve THEN
    UPDATE public.kyc_submissions
    SET status = 'approved', reviewed_by = auth.uid(), reviewed_at = NOW()
    WHERE id = p_submission_id;

    UPDATE public.profiles
    SET
      kyc_status = 'approved',
      kyc_level = GREATEST(kyc_level, v_level),
      account_status = CASE
        WHEN v_level >= 2 THEN 'active'::public.account_status
        ELSE 'verified'::public.account_status
      END
    WHERE id = v_submission.profile_id;
  ELSE
    IF p_decline_reason IS NULL OR LENGTH(TRIM(p_decline_reason)) < 3 THEN
      RAISE EXCEPTION 'Decline reason is required';
    END IF;

    UPDATE public.kyc_submissions
    SET
      status = 'declined',
      decline_reason = public.sanitize_text(p_decline_reason, 300),
      reviewed_by = auth.uid(),
      reviewed_at = NOW()
    WHERE id = p_submission_id;

    UPDATE public.profiles
    SET kyc_status = 'declined'
    WHERE id = v_submission.profile_id;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.submit_kyc_level1(TEXT, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_kyc_level1(TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.submit_kyc_level2(TEXT, NUMERIC) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_kyc_level2(TEXT, NUMERIC) TO authenticated;

REVOKE ALL ON FUNCTION public.submit_kyc_level3(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_kyc_level3(TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
