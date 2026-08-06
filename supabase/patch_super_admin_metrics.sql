-- TrustVault patch: super admin dashboard metrics RPCs
-- Run this in the Supabase SQL Editor if the super admin dashboard fails to load metrics.

CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT role = 'super_admin' FROM public.profiles WHERE id = auth.uid()),
    FALSE
  );
$$;

CREATE TABLE IF NOT EXISTS public.admin_invitations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  role public.user_role NOT NULL DEFAULT 'admin',
  invited_by UUID NOT NULL REFERENCES public.profiles (id),
  profile_id UUID REFERENCES public.profiles (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  accepted_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_admin_invitations_pending_email
  ON public.admin_invitations (LOWER(email))
  WHERE accepted_at IS NULL;

ALTER TABLE public.admin_invitations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Super admins manage admin invitations" ON public.admin_invitations;
CREATE POLICY "Super admins manage admin invitations"
  ON public.admin_invitations FOR ALL
  TO authenticated
  USING (public.is_super_admin())
  WITH CHECK (public.is_super_admin());

CREATE OR REPLACE FUNCTION public.get_admin_metrics()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total_users INT;
  v_pending_kyc INT;
  v_pending_funding INT;
  v_pending_withdrawals INT;
  v_open_flags INT;
  v_daily_volume NUMERIC;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT COUNT(*) INTO v_total_users FROM public.profiles WHERE role = 'user';
  SELECT COUNT(*) INTO v_pending_kyc FROM public.kyc_submissions WHERE status = 'pending';
  SELECT COUNT(*) INTO v_pending_funding FROM public.funding_requests WHERE status = 'pending';
  SELECT COUNT(*) INTO v_pending_withdrawals FROM public.transactions WHERE type = 'withdrawal' AND status = 'pending';
  SELECT COUNT(*) INTO v_open_flags FROM public.flags WHERE status = 'open';

  SELECT COALESCE(SUM(amount), 0) INTO v_daily_volume
  FROM public.transactions
  WHERE status = 'completed' AND created_at >= NOW() - INTERVAL '24 hours';

  RETURN jsonb_build_object(
    'total_users', v_total_users,
    'pending_kyc', v_pending_kyc,
    'pending_funding', v_pending_funding,
    'pending_withdrawals', v_pending_withdrawals,
    'open_flags', v_open_flags,
    'daily_volume', v_daily_volume
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_admin_metrics() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_admin_metrics() TO authenticated;

CREATE OR REPLACE FUNCTION public.get_super_admin_metrics()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total_users INT;
  v_pending_kyc INT;
  v_pending_funding INT;
  v_pending_withdrawals INT;
  v_open_flags INT;
  v_frozen_accounts INT;
  v_total_admins INT;
  v_total_volume NUMERIC;
BEGIN
  IF NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT COUNT(*) INTO v_total_users FROM public.profiles WHERE role = 'user';
  SELECT COUNT(*) INTO v_pending_kyc FROM public.kyc_submissions WHERE status = 'pending';
  SELECT COUNT(*) INTO v_pending_funding FROM public.funding_requests WHERE status = 'pending';
  SELECT COUNT(*) INTO v_pending_withdrawals FROM public.transactions WHERE type = 'withdrawal' AND status = 'pending';
  SELECT COUNT(*) INTO v_open_flags FROM public.flags WHERE status = 'open';
  SELECT COUNT(*) INTO v_frozen_accounts FROM public.profiles WHERE account_status = 'frozen';
  SELECT COUNT(*) INTO v_total_admins FROM public.profiles WHERE role IN ('admin', 'super_admin');

  SELECT COALESCE(SUM(amount), 0) INTO v_total_volume
  FROM public.transactions
  WHERE status = 'completed';

  RETURN jsonb_build_object(
    'total_users', v_total_users,
    'pending_kyc', v_pending_kyc,
    'pending_funding', v_pending_funding,
    'pending_withdrawals', v_pending_withdrawals,
    'open_flags', v_open_flags,
    'frozen_accounts', v_frozen_accounts,
    'total_admins', v_total_admins,
    'total_volume', v_total_volume
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_super_admin_metrics() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_super_admin_metrics() TO authenticated;

CREATE OR REPLACE FUNCTION public.get_platform_analytics()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total_users INT;
  v_active_users INT;
  v_total_flags INT;
  v_open_flags INT;
  v_resolved_flags INT;
  v_flag_rate NUMERIC;
  v_pending_invites INT;
  v_volume_7d NUMERIC;
  v_volume_30d NUMERIC;
BEGIN
  IF NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT COUNT(*) INTO v_total_users FROM public.profiles WHERE role = 'user';
  SELECT COUNT(*) INTO v_active_users FROM public.profiles WHERE role = 'user' AND account_status = 'active';
  SELECT COUNT(*) INTO v_total_flags FROM public.flags;
  SELECT COUNT(*) INTO v_open_flags FROM public.flags WHERE status = 'open';
  SELECT COUNT(*) INTO v_resolved_flags FROM public.flags WHERE status IN ('resolved', 'dismissed');
  SELECT COUNT(*) INTO v_pending_invites FROM public.admin_invitations WHERE accepted_at IS NULL;

  SELECT COALESCE(SUM(amount), 0) INTO v_volume_7d
  FROM public.transactions
  WHERE status = 'completed' AND created_at >= NOW() - INTERVAL '7 days';

  SELECT COALESCE(SUM(amount), 0) INTO v_volume_30d
  FROM public.transactions
  WHERE status = 'completed' AND created_at >= NOW() - INTERVAL '30 days';

  IF v_total_flags > 0 THEN
    v_flag_rate := ROUND((v_open_flags::NUMERIC / v_total_flags::NUMERIC) * 100, 1);
  ELSE
    v_flag_rate := 0;
  END IF;

  RETURN jsonb_build_object(
    'active_users', v_active_users,
    'active_user_rate', CASE WHEN v_total_users > 0 THEN ROUND((v_active_users::NUMERIC / v_total_users::NUMERIC) * 100, 1) ELSE 0 END,
    'total_flags', v_total_flags,
    'open_flags', v_open_flags,
    'resolved_flags', v_resolved_flags,
    'flag_rate_pct', v_flag_rate,
    'pending_admin_invites', v_pending_invites,
    'volume_7d', v_volume_7d,
    'volume_30d', v_volume_30d
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_platform_analytics() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_platform_analytics() TO authenticated;
