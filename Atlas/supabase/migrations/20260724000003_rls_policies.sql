-- Atlas Phase 1: Row-Level Security for user, admin, super_admin

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kyc_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ledger_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.funding_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------

CREATE POLICY "Users can view own profile"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (id = auth.uid() OR public.is_admin());

CREATE POLICY "Users can update own profile (limited)"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (
    id = auth.uid()
    AND role = (SELECT role FROM public.profiles WHERE id = auth.uid())
    AND account_status = (SELECT account_status FROM public.profiles WHERE id = auth.uid())
    AND kyc_status = (SELECT kyc_status FROM public.profiles WHERE id = auth.uid())
  );

CREATE POLICY "Super admins can update any profile"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (public.is_super_admin())
  WITH CHECK (public.is_super_admin());

CREATE POLICY "Super admins can insert admin profiles"
  ON public.profiles FOR INSERT
  TO authenticated
  WITH CHECK (public.is_super_admin());

-- ---------------------------------------------------------------------------
-- kyc_submissions
-- ---------------------------------------------------------------------------

CREATE POLICY "Users can view own KYC submissions"
  ON public.kyc_submissions FOR SELECT
  TO authenticated
  USING (profile_id = auth.uid() OR public.is_admin());

CREATE POLICY "Users can submit own KYC"
  ON public.kyc_submissions FOR INSERT
  TO authenticated
  WITH CHECK (profile_id = auth.uid());

CREATE POLICY "Admins can review KYC submissions"
  ON public.kyc_submissions FOR UPDATE
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- ---------------------------------------------------------------------------
-- accounts — balance is never updated from the client (ledger function only)
-- ---------------------------------------------------------------------------

CREATE POLICY "Users can view own account"
  ON public.accounts FOR SELECT
  TO authenticated
  USING (
    profile_id = auth.uid()
    OR public.is_admin()
    OR (is_system = TRUE AND public.is_admin())
  );

-- No INSERT/UPDATE/DELETE policies for accounts — managed by triggers/functions.

-- ---------------------------------------------------------------------------
-- ledger_entries (immutable, read-only for clients)
-- ---------------------------------------------------------------------------

CREATE POLICY "Users can view own ledger entries"
  ON public.ledger_entries FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.accounts a
      WHERE a.id = ledger_entries.account_id
        AND (a.profile_id = auth.uid() OR public.is_admin())
    )
  );

-- ---------------------------------------------------------------------------
-- transactions
-- ---------------------------------------------------------------------------

CREATE POLICY "Users can view own transactions"
  ON public.transactions FOR SELECT
  TO authenticated
  USING (initiated_by = auth.uid() OR public.is_admin());

CREATE POLICY "Users can create transactions"
  ON public.transactions FOR INSERT
  TO authenticated
  WITH CHECK (initiated_by = auth.uid());

CREATE POLICY "Admins can update transaction status (non-withdrawal)"
  ON public.transactions FOR UPDATE
  TO authenticated
  USING (
    public.is_admin()
    AND type <> 'withdrawal'
  )
  WITH CHECK (
    public.is_admin()
    AND type <> 'withdrawal'
  );

CREATE POLICY "Super admins can update withdrawal transactions"
  ON public.transactions FOR UPDATE
  TO authenticated
  USING (public.is_super_admin() AND type = 'withdrawal')
  WITH CHECK (public.is_super_admin() AND type = 'withdrawal');

-- ---------------------------------------------------------------------------
-- funding_requests
-- ---------------------------------------------------------------------------

CREATE POLICY "Users can view own funding requests"
  ON public.funding_requests FOR SELECT
  TO authenticated
  USING (profile_id = auth.uid() OR public.is_admin());

CREATE POLICY "Verified users can create funding requests"
  ON public.funding_requests FOR INSERT
  TO authenticated
  WITH CHECK (
    profile_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.kyc_status = 'approved'
        AND p.account_status IN ('verified', 'active')
        AND p.account_status <> 'frozen'
    )
  );

CREATE POLICY "Admins can review funding requests"
  ON public.funding_requests FOR UPDATE
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- ---------------------------------------------------------------------------
-- flags
-- ---------------------------------------------------------------------------

CREATE POLICY "Admins can view flags"
  ON public.flags FOR SELECT
  TO authenticated
  USING (public.is_admin());

CREATE POLICY "Admins can raise flags"
  ON public.flags FOR INSERT
  TO authenticated
  WITH CHECK (public.is_admin() AND raised_by = auth.uid());

CREATE POLICY "Super admins can resolve flags"
  ON public.flags FOR UPDATE
  TO authenticated
  USING (public.is_super_admin())
  WITH CHECK (public.is_super_admin());

-- ---------------------------------------------------------------------------
-- audit_logs
-- ---------------------------------------------------------------------------

CREATE POLICY "Super admins can view all audit logs"
  ON public.audit_logs FOR SELECT
  TO authenticated
  USING (public.is_super_admin());

CREATE POLICY "Admins can view own audit log entries"
  ON public.audit_logs FOR SELECT
  TO authenticated
  USING (public.is_admin() AND actor_id = auth.uid());

CREATE POLICY "Authenticated users can write audit logs via function"
  ON public.audit_logs FOR INSERT
  TO authenticated
  WITH CHECK (actor_id = auth.uid() AND public.is_admin());
