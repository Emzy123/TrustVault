-- TrustVault: Security hardening, admin withdrawal access, admin provisioning, analytics

-- ---------------------------------------------------------------------------
-- 1. Admin invitations table (must exist before handle_new_user references it)
-- ---------------------------------------------------------------------------

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

-- ---------------------------------------------------------------------------
-- 2. Security: block privilege escalation via signup metadata
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role public.user_role := 'user';
  v_next_acc TEXT;
  v_invite public.admin_invitations%ROWTYPE;
BEGIN
  -- Demo accounts only; never trust client-supplied role metadata
  IF NEW.email = 'admin@trustvault.demo' THEN
    v_role := 'admin';
  ELSIF NEW.email = 'superadmin@trustvault.demo' THEN
    v_role := 'super_admin';
  END IF;

  -- Accept pending super-admin invitation
  IF v_role = 'user' AND NEW.email IS NOT NULL THEN
    SELECT * INTO v_invite
    FROM public.admin_invitations
    WHERE LOWER(email) = LOWER(NEW.email)
      AND accepted_at IS NULL
    LIMIT 1;

    IF FOUND THEN
      v_role := v_invite.role;
    END IF;
  END IF;

  INSERT INTO public.profiles (id, full_name, email, phone, role, account_status, kyc_status)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data ->> 'full_name', ''),
    COALESCE(NEW.email, ''),
    NEW.raw_user_meta_data ->> 'phone',
    v_role,
    'unverified',
    'not_submitted'
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    role = CASE
      WHEN EXCLUDED.email IN ('admin@trustvault.demo', 'superadmin@trustvault.demo') THEN v_role
      WHEN public.profiles.role IN ('admin', 'super_admin') THEN public.profiles.role
      ELSE EXCLUDED.role
    END,
    full_name = CASE WHEN EXCLUDED.full_name <> '' THEN EXCLUDED.full_name ELSE public.profiles.full_name END;

  IF v_invite.id IS NOT NULL THEN
    UPDATE public.admin_invitations
    SET accepted_at = NOW(), profile_id = NEW.id
    WHERE id = v_invite.id AND accepted_at IS NULL;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.accounts WHERE profile_id = NEW.id AND is_system = FALSE) THEN
    v_next_acc := LPAD(nextval('public.account_number_seq')::TEXT, 10, '0');
    INSERT INTO public.accounts (profile_id, balance, currency, account_number)
    VALUES (NEW.id, 0, 'NGN', v_next_acc)
    ON CONFLICT (profile_id) DO NOTHING;
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'handle_new_user trigger error: %', SQLERRM;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.invite_admin_user(
  p_email TEXT,
  p_role TEXT DEFAULT 'admin'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email TEXT;
  v_role public.user_role;
  v_invite_id UUID;
  v_existing_role public.user_role;
BEGIN
  IF NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  v_email := LOWER(TRIM(p_email));
  IF v_email IS NULL OR v_email !~ '^[^@]+@[^@]+\.[^@]+$' THEN
    RAISE EXCEPTION 'Valid email address is required';
  END IF;

  IF p_role NOT IN ('admin', 'super_admin') THEN
    RAISE EXCEPTION 'Role must be admin or super_admin';
  END IF;

  v_role := p_role::public.user_role;

  SELECT role INTO v_existing_role
  FROM public.profiles
  WHERE LOWER(email) = v_email;

  IF FOUND THEN
    IF v_existing_role IN ('admin', 'super_admin') THEN
      RAISE EXCEPTION 'User is already an administrator';
    END IF;

    PERFORM public.manage_user_role(
      (SELECT id FROM public.profiles WHERE LOWER(email) = v_email),
      p_role
    );
    RETURN NULL;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.admin_invitations
    WHERE LOWER(email) = v_email AND accepted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'An invitation for this email is already pending';
  END IF;

  INSERT INTO public.admin_invitations (email, role, invited_by)
  VALUES (v_email, v_role, auth.uid())
  RETURNING id INTO v_invite_id;

  PERFORM public.write_audit_log(
    'admin.invited',
    v_invite_id,
    jsonb_build_object('email', v_email, 'role', p_role)
  );

  RETURN v_invite_id;
END;
$$;

REVOKE ALL ON FUNCTION public.invite_admin_user(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.invite_admin_user(TEXT, TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- 3. Role management guardrails
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
  v_super_admin_count INT;
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

  IF p_profile_id = auth.uid() AND v_new_role <> v_target.role THEN
    RAISE EXCEPTION 'You cannot change your own role';
  END IF;

  IF v_target.role = 'super_admin' AND v_new_role <> 'super_admin' THEN
    SELECT COUNT(*) INTO v_super_admin_count
    FROM public.profiles
    WHERE role = 'super_admin';

    IF v_super_admin_count <= 1 THEN
      RAISE EXCEPTION 'Cannot demote the last super admin';
    END IF;
  END IF;

  UPDATE public.profiles
  SET role = v_new_role, updated_at = NOW()
  WHERE id = p_profile_id;

  PERFORM public.write_audit_log(
    'user.role_changed',
    p_profile_id,
    jsonb_build_object(
      'old_role', v_target.role,
      'new_role', v_new_role,
      'email', v_target.email
    )
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- 4. Allow admins to review withdrawals (user requirement)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.review_withdrawal(
  p_transaction_id UUID,
  p_approve BOOLEAN,
  p_decline_reason TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tx public.transactions%ROWTYPE;
  v_profile_id UUID;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT * INTO v_tx
  FROM public.transactions
  WHERE id = p_transaction_id AND type = 'withdrawal'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Withdrawal not found';
  END IF;

  IF v_tx.status <> 'pending' THEN
    RAISE EXCEPTION 'Withdrawal is not pending review';
  END IF;

  SELECT profile_id INTO v_profile_id
  FROM public.accounts WHERE id = v_tx.from_account_id;

  IF p_approve THEN
    PERFORM public.post_ledger_transaction(
      v_tx.id, v_tx.from_account_id, v_tx.to_account_id, v_tx.amount
    );

    UPDATE public.transactions
    SET status = 'completed', decline_reason = NULL, updated_at = NOW()
    WHERE id = p_transaction_id;

    PERFORM public.sync_account_status(v_profile_id);
  ELSE
    IF p_decline_reason IS NULL OR LENGTH(TRIM(p_decline_reason)) < 3 THEN
      RAISE EXCEPTION 'Decline reason is required';
    END IF;

    UPDATE public.transactions
    SET
      status = 'declined',
      decline_reason = public.sanitize_text(p_decline_reason, 300),
      updated_at = NOW()
    WHERE id = p_transaction_id;
  END IF;

  PERFORM public.write_audit_log(
    CASE WHEN p_approve THEN 'withdrawal.approved' ELSE 'withdrawal.declined' END,
    p_transaction_id,
    jsonb_build_object('amount', v_tx.amount, 'profile_id', v_profile_id)
  );
END;
$$;

DROP POLICY IF EXISTS "Super admins can update withdrawal transactions" ON public.transactions;
CREATE POLICY "Admins can update withdrawal transactions"
  ON public.transactions FOR UPDATE
  TO authenticated
  USING (public.is_admin() AND type = 'withdrawal')
  WITH CHECK (public.is_admin() AND type = 'withdrawal');

-- ---------------------------------------------------------------------------
-- 5. Fix unfreeze: restore correct status via sync instead of hardcoded active
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

  IF v_new_status = 'frozen' THEN
    UPDATE public.profiles
    SET account_status = 'frozen', updated_at = NOW()
    WHERE id = p_profile_id;
  ELSE
    -- Unfreeze: let sync derive verified vs active from KYC + balance
    UPDATE public.profiles
    SET account_status = CASE
      WHEN v_target.kyc_status = 'approved' THEN 'verified'::public.account_status
      ELSE 'unverified'::public.account_status
    END,
    updated_at = NOW()
    WHERE id = p_profile_id;

    PERFORM public.sync_account_status(p_profile_id);
  END IF;

  PERFORM public.write_audit_log(
    'account.status_changed',
    p_profile_id,
    jsonb_build_object(
      'old_status', v_target.account_status,
      'new_status', (SELECT account_status FROM public.profiles WHERE id = p_profile_id),
      'requested_status', v_new_status,
      'reason', public.sanitize_text(p_reason, 300)
    )
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- 6. Platform analytics for super admin eagle-eye oversight
-- ---------------------------------------------------------------------------

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

-- Extend admin metrics with pending withdrawals
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

-- ---------------------------------------------------------------------------
-- 7. Lock down internal-only RPCs (critical security fix)
-- ---------------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION public.post_ledger_transaction(UUID, UUID, UUID, NUMERIC) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.write_audit_log(TEXT, UUID, JSONB) FROM authenticated;
