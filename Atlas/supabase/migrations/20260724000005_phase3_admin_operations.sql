-- Atlas Phase 3: Admin & Super Admin Operations, Metrics & RLS Extensions

-- ---------------------------------------------------------------------------
-- 1. Flag Operations
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.raise_flag(
  p_transaction_id UUID,
  p_reason TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_flag_id UUID;
  v_clean_reason TEXT;
  v_tx public.transactions%ROWTYPE;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  v_clean_reason := public.sanitize_text(p_reason, 500);
  IF v_clean_reason IS NULL OR LENGTH(v_clean_reason) < 3 THEN
    RAISE EXCEPTION 'A valid reason is required to raise a flag';
  END IF;

  SELECT * INTO v_tx
  FROM public.transactions
  WHERE id = p_transaction_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Transaction not found';
  END IF;

  INSERT INTO public.flags (transaction_id, raised_by, reason, status)
  VALUES (p_transaction_id, auth.uid(), v_clean_reason, 'open')
  RETURNING id INTO v_flag_id;

  UPDATE public.transactions
  SET status = 'flagged', updated_at = NOW()
  WHERE id = p_transaction_id AND status = 'pending';

  PERFORM public.write_audit_log(
    'transaction.flagged',
    p_transaction_id,
    jsonb_build_object('flag_id', v_flag_id, 'reason', v_clean_reason)
  );

  RETURN v_flag_id;
END;
$$;

REVOKE ALL ON FUNCTION public.raise_flag(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.raise_flag(UUID, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.resolve_flag(
  p_flag_id UUID,
  p_dismiss BOOLEAN,
  p_resolution_note TEXT DEFAULT NULL,
  p_freeze_account BOOLEAN DEFAULT FALSE
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_flag public.flags%ROWTYPE;
  v_tx public.transactions%ROWTYPE;
  v_initiator_id UUID;
BEGIN
  IF NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT * INTO v_flag
  FROM public.flags
  WHERE id = p_flag_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Flag not found';
  END IF;

  IF v_flag.status <> 'open' THEN
    RAISE EXCEPTION 'Flag is already resolved or dismissed';
  END IF;

  UPDATE public.flags
  SET
    status = CASE WHEN p_dismiss THEN 'dismissed'::public.flag_status ELSE 'resolved'::public.flag_status END,
    resolved_by = auth.uid(),
    resolved_at = NOW(),
    resolution_note = public.sanitize_text(p_resolution_note, 500)
  WHERE id = p_flag_id;

  SELECT * INTO v_tx FROM public.transactions WHERE id = v_flag.transaction_id;

  IF p_freeze_account AND v_tx.initiated_by IS NOT NULL THEN
    UPDATE public.profiles
    SET account_status = 'frozen', updated_at = NOW()
    WHERE id = v_tx.initiated_by;
  END IF;

  PERFORM public.write_audit_log(
    CASE WHEN p_dismiss THEN 'flag.dismissed' ELSE 'flag.resolved' END,
    p_flag_id,
    jsonb_build_object(
      'transaction_id', v_flag.transaction_id,
      'freeze_applied', p_freeze_account
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.resolve_flag(UUID, BOOLEAN, TEXT, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.resolve_flag(UUID, BOOLEAN, TEXT, BOOLEAN) TO authenticated;

-- ---------------------------------------------------------------------------
-- 2. Account Freeze / Unfreeze Controls
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.set_account_status(
  p_profile_id UUID,
  p_status TEXT,
  p_reason TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_target public.profiles%ROWTYPE;
  v_new_status public.account_status;
BEGIN
  IF NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF p_status NOT IN ('unverified', 'verified', 'active', 'frozen') THEN
    RAISE EXCEPTION 'Invalid account status';
  END IF;

  v_new_status := p_status::public.account_status;

  SELECT * INTO v_target FROM public.profiles WHERE id = p_profile_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profile not found';
  END IF;

  UPDATE public.profiles
  SET account_status = v_new_status, updated_at = NOW()
  WHERE id = p_profile_id;

  PERFORM public.write_audit_log(
    'account.status_changed',
    p_profile_id,
    jsonb_build_object(
      'old_status', v_target.account_status,
      'new_status', v_new_status,
      'reason', public.sanitize_text(p_reason, 300)
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.set_account_status(UUID, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_account_status(UUID, TEXT, TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- 3. Role Management (Super Admin only)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.manage_user_role(
  p_profile_id UUID,
  p_role TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_target public.profiles%ROWTYPE;
  v_new_role public.user_role;
BEGIN
  IF NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF p_role NOT IN ('user', 'admin', 'super_admin') THEN
    RAISE EXCEPTION 'Invalid user role';
  END IF;

  v_new_role := p_role::public.user_role;

  SELECT * INTO v_target FROM public.profiles WHERE id = p_profile_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profile not found';
  END IF;

  UPDATE public.profiles
  SET role = v_new_role, updated_at = NOW()
  WHERE id = p_profile_id;

  PERFORM public.write_audit_log(
    'user.role_changed',
    p_profile_id,
    jsonb_build_object(
      'old_role', v_target.role,
      'new_role', v_new_role
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.manage_user_role(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.manage_user_role(UUID, TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- 4. Metrics RPCs
-- ---------------------------------------------------------------------------

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
  v_open_flags INT;
  v_daily_volume NUMERIC;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT COUNT(*) INTO v_total_users FROM public.profiles WHERE role = 'user';
  SELECT COUNT(*) INTO v_pending_kyc FROM public.kyc_submissions WHERE status = 'pending';
  SELECT COUNT(*) INTO v_pending_funding FROM public.funding_requests WHERE status = 'pending';
  SELECT COUNT(*) INTO v_open_flags FROM public.flags WHERE status = 'open';

  SELECT COALESCE(SUM(amount), 0) INTO v_daily_volume
  FROM public.transactions
  WHERE status = 'completed' AND created_at >= NOW() - INTERVAL '24 hours';

  RETURN jsonb_build_object(
    'total_users', v_total_users,
    'pending_kyc', v_pending_kyc,
    'pending_funding', v_pending_funding,
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

-- ---------------------------------------------------------------------------
-- 5. RLS Policies for Admin & Audit Logs
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS "Admins view all flags" ON public.flags;
CREATE POLICY "Admins view all flags"
  ON public.flags FOR SELECT
  TO authenticated
  USING (public.is_admin());

DROP POLICY IF EXISTS "Super Admin audit log access" ON public.audit_logs;
CREATE POLICY "Super Admin audit log access"
  ON public.audit_logs FOR SELECT
  TO authenticated
  USING (public.is_super_admin() OR actor_id = auth.uid());

DROP POLICY IF EXISTS "Admins view all profiles" ON public.profiles;
CREATE POLICY "Admins view all profiles"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (id = auth.uid() OR public.is_admin());
