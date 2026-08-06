-- TrustVault: Fix missing submit_kyc & user operations RPC functions in Supabase schema cache

-- Rate limiting table
CREATE TABLE IF NOT EXISTS public.action_rate_limits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  action_type TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_action_rate_limits_lookup
  ON public.action_rate_limits (profile_id, action_type, created_at DESC);

ALTER TABLE public.action_rate_limits ENABLE ROW LEVEL SECURITY;

-- Helpers
CREATE OR REPLACE FUNCTION public.enforce_rate_limit(
  p_action_type TEXT,
  p_max_attempts INTEGER DEFAULT 5,
  p_window_seconds INTEGER DEFAULT 300
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  DELETE FROM public.action_rate_limits
  WHERE created_at < NOW() - MAKE_INTERVAL(secs => p_window_seconds);

  SELECT COUNT(*) INTO v_count
  FROM public.action_rate_limits
  WHERE profile_id = auth.uid()
    AND action_type = p_action_type
    AND created_at >= NOW() - MAKE_INTERVAL(secs => p_window_seconds);

  IF v_count >= p_max_attempts THEN
    RAISE EXCEPTION 'Too many attempts. Please wait a few minutes and try again.';
  END IF;

  INSERT INTO public.action_rate_limits (profile_id, action_type)
  VALUES (auth.uid(), p_action_type);
END;
$$;

CREATE OR REPLACE FUNCTION public.sanitize_text(p_input TEXT, p_max_length INTEGER DEFAULT 500)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  IF p_input IS NULL THEN
    RETURN NULL;
  END IF;
  RETURN LEFT(TRIM(REGEXP_REPLACE(p_input, '[[:cntrl:]]', '', 'g')), p_max_length);
END;
$$;

CREATE OR REPLACE FUNCTION public.write_audit_log(
  p_action TEXT,
  p_target_id UUID DEFAULT NULL,
  p_metadata JSONB DEFAULT '{}'::JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_log_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  INSERT INTO public.audit_logs (actor_id, action, target_id, metadata)
  VALUES (auth.uid(), p_action, p_target_id, COALESCE(p_metadata, '{}'::JSONB))
  RETURNING id INTO v_log_id;

  RETURN v_log_id;
END;
$$;

-- Primary submit_kyc overload taking DATE
CREATE OR REPLACE FUNCTION public.submit_kyc(
  p_id_type TEXT,
  p_id_number TEXT,
  p_dob DATE,
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

  IF p_dob IS NULL OR p_dob > CURRENT_DATE - INTERVAL '18 years' THEN
    RAISE EXCEPTION 'You must be at least 18 years old';
  END IF;

  IF p_address IS NULL OR LENGTH(TRIM(p_address)) < 5 THEN
    RAISE EXCEPTION 'Valid address is required';
  END IF;

  INSERT INTO public.kyc_submissions (
    profile_id, id_type, id_number, dob, address, document_url, status
  )
  VALUES (
    auth.uid(),
    public.sanitize_text(p_id_type, 50),
    public.sanitize_text(p_id_number, 50),
    p_dob,
    public.sanitize_text(p_address, 300),
    public.sanitize_text(p_document_url, 500),
    'pending'
  )
  RETURNING id INTO v_submission_id;

  UPDATE public.profiles
  SET kyc_status = 'pending', account_status = 'unverified'
  WHERE id = auth.uid();

  RETURN v_submission_id;
END;
$$;

-- Secondary submit_kyc overload taking TEXT string for PostgREST RPC compatibility
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
BEGIN
  RETURN public.submit_kyc(
    p_id_type,
    p_id_number,
    p_dob::DATE,
    p_address,
    p_document_url
  );
END;
$$;

REVOKE ALL ON FUNCTION public.submit_kyc(TEXT, TEXT, DATE, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_kyc(TEXT, TEXT, DATE, TEXT, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.submit_kyc(TEXT, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_kyc(TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;

GRANT EXECUTE ON FUNCTION public.enforce_rate_limit(TEXT, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.write_audit_log(TEXT, UUID, JSONB) TO authenticated;

NOTIFY pgrst, 'reload schema';
