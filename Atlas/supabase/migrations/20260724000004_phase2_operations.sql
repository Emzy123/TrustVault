-- Atlas Phase 2: Server-side operations, rate limiting, account sync

-- ---------------------------------------------------------------------------
-- Rate limiting (no client access)
-- ---------------------------------------------------------------------------

CREATE TABLE public.action_rate_limits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  action_type TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_action_rate_limits_lookup
  ON public.action_rate_limits (profile_id, action_type, created_at DESC);

ALTER TABLE public.action_rate_limits ENABLE ROW LEVEL SECURITY;

-- Fund platform treasury for simulated credits
UPDATE public.accounts
SET balance = 1000000000
WHERE is_system = TRUE AND label = 'Platform Treasury';

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

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

CREATE OR REPLACE FUNCTION public.get_user_account_id(p_profile_id UUID DEFAULT auth.uid())
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id FROM public.accounts
  WHERE profile_id = p_profile_id AND is_system = FALSE
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.get_available_balance(p_account_id UUID)
RETURNS NUMERIC
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(a.balance, 0) - COALESCE((
    SELECT SUM(t.amount)
    FROM public.transactions t
    WHERE t.from_account_id = p_account_id
      AND t.type = 'withdrawal'
      AND t.status = 'pending'
  ), 0)
  FROM public.accounts a
  WHERE a.id = p_account_id;
$$;

CREATE OR REPLACE FUNCTION public.sync_account_status(p_profile_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_balance NUMERIC(18, 2);
  v_kyc_status public.kyc_status;
  v_account_status public.account_status;
BEGIN
  SELECT p.kyc_status, p.account_status, COALESCE(a.balance, 0)
  INTO v_kyc_status, v_account_status, v_balance
  FROM public.profiles p
  LEFT JOIN public.accounts a ON a.profile_id = p.id AND a.is_system = FALSE
  WHERE p.id = p_profile_id;

  IF v_account_status = 'frozen' THEN
    RETURN;
  END IF;

  IF v_kyc_status = 'approved' AND v_balance > 0 THEN
    UPDATE public.profiles SET account_status = 'active' WHERE id = p_profile_id AND account_status <> 'frozen';
  ELSIF v_kyc_status = 'approved' AND v_balance = 0 THEN
    UPDATE public.profiles SET account_status = 'verified' WHERE id = p_profile_id AND account_status <> 'frozen';
  END IF;
END;
$$;

-- Extend ledger posting to sync account status after balance changes
CREATE OR REPLACE FUNCTION public.post_ledger_transaction(
  p_transaction_id UUID,
  p_debit_account_id UUID,
  p_credit_account_id UUID,
  p_amount NUMERIC
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_debit_balance NUMERIC(18, 2);
  v_credit_balance NUMERIC(18, 2);
  v_debit_profile UUID;
  v_credit_profile UUID;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be positive';
  END IF;

  IF p_debit_account_id = p_credit_account_id THEN
    RAISE EXCEPTION 'Debit and credit accounts must differ';
  END IF;

  SELECT balance, profile_id INTO v_debit_balance, v_debit_profile
  FROM public.accounts
  WHERE id = p_debit_account_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Debit account not found';
  END IF;

  SELECT balance, profile_id INTO v_credit_balance, v_credit_profile
  FROM public.accounts
  WHERE id = p_credit_account_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Credit account not found';
  END IF;

  IF v_debit_balance < p_amount THEN
    RAISE EXCEPTION 'Insufficient balance';
  END IF;

  v_debit_balance := v_debit_balance - p_amount;
  v_credit_balance := v_credit_balance + p_amount;

  INSERT INTO public.ledger_entries (account_id, transaction_id, entry_type, amount, balance_after)
  VALUES (p_debit_account_id, p_transaction_id, 'debit', p_amount, v_debit_balance);

  INSERT INTO public.ledger_entries (account_id, transaction_id, entry_type, amount, balance_after)
  VALUES (p_credit_account_id, p_transaction_id, 'credit', p_amount, v_credit_balance);

  UPDATE public.accounts SET balance = v_debit_balance WHERE id = p_debit_account_id;
  UPDATE public.accounts SET balance = v_credit_balance WHERE id = p_credit_account_id;

  IF v_debit_profile IS NOT NULL THEN
    PERFORM public.sync_account_status(v_debit_profile);
  END IF;
  IF v_credit_profile IS NOT NULL THEN
    PERFORM public.sync_account_status(v_credit_profile);
  END IF;
END;
$$;

-- ---------------------------------------------------------------------------
-- KYC submission
-- ---------------------------------------------------------------------------

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

REVOKE ALL ON FUNCTION public.submit_kyc(TEXT, TEXT, DATE, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_kyc(TEXT, TEXT, DATE, TEXT, TEXT) TO authenticated;

-- Admin KYC review (callable from SQL until Phase 3 UI)
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

  IF p_approve THEN
    UPDATE public.kyc_submissions
    SET status = 'approved', reviewed_by = auth.uid(), reviewed_at = NOW()
    WHERE id = p_submission_id;

    UPDATE public.profiles
    SET kyc_status = 'approved', account_status = 'verified'
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
    SET kyc_status = 'declined', account_status = 'unverified'
    WHERE id = v_submission.profile_id;
  END IF;

  PERFORM public.write_audit_log(
    CASE WHEN p_approve THEN 'kyc.approved' ELSE 'kyc.declined' END,
    p_submission_id,
    jsonb_build_object('profile_id', v_submission.profile_id)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.review_kyc_submission(UUID, BOOLEAN, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.review_kyc_submission(UUID, BOOLEAN, TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- Funding request (server-validated insert)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.submit_funding_request(
  p_amount NUMERIC,
  p_note TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_request_id UUID;
  v_profile public.profiles%ROWTYPE;
BEGIN
  PERFORM public.enforce_rate_limit('funding_request', 5, 300);

  SELECT * INTO v_profile FROM public.profiles WHERE id = auth.uid();
  IF v_profile.kyc_status <> 'approved' THEN
    RAISE EXCEPTION 'Complete identity verification before requesting funding';
  END IF;

  IF v_profile.account_status = 'frozen' THEN
    RAISE EXCEPTION 'Account is frozen';
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 OR p_amount > 10000000 THEN
    RAISE EXCEPTION 'Amount must be between ₦0.01 and ₦10,000,000';
  END IF;

  INSERT INTO public.funding_requests (profile_id, amount, note, status)
  VALUES (auth.uid(), p_amount, public.sanitize_text(p_note, 300), 'pending')
  RETURNING id INTO v_request_id;

  RETURN v_request_id;
END;
$$;

REVOKE ALL ON FUNCTION public.submit_funding_request(NUMERIC, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_funding_request(NUMERIC, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.approve_funding_request(
  p_request_id UUID,
  p_decline_reason TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_request public.funding_requests%ROWTYPE;
  v_user_account_id UUID;
  v_treasury_id UUID;
  v_transaction_id UUID;
  v_approve BOOLEAN;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT * INTO v_request
  FROM public.funding_requests
  WHERE id = p_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Funding request not found';
  END IF;

  IF v_request.status <> 'pending' THEN
    RAISE EXCEPTION 'Funding request is not pending';
  END IF;

  v_approve := p_decline_reason IS NULL;

  IF v_approve THEN
    v_user_account_id := public.get_user_account_id(v_request.profile_id);
    v_treasury_id := public.get_treasury_account_id();

    INSERT INTO public.transactions (
      type, from_account_id, to_account_id, amount, status, initiated_by, note
    )
    VALUES (
      'funding', v_treasury_id, v_user_account_id, v_request.amount,
      'completed', auth.uid(), v_request.note
    )
    RETURNING id INTO v_transaction_id;

    PERFORM public.post_ledger_transaction(
      v_transaction_id, v_treasury_id, v_user_account_id, v_request.amount
    );

    UPDATE public.funding_requests
    SET
      status = 'approved',
      reviewed_by = auth.uid(),
      reviewed_at = NOW(),
      transaction_id = v_transaction_id
    WHERE id = p_request_id;

    PERFORM public.sync_account_status(v_request.profile_id);
  ELSE
    IF LENGTH(TRIM(p_decline_reason)) < 3 THEN
      RAISE EXCEPTION 'Decline reason is required';
    END IF;

    UPDATE public.funding_requests
    SET
      status = 'declined',
      decline_reason = public.sanitize_text(p_decline_reason, 300),
      reviewed_by = auth.uid(),
      reviewed_at = NOW()
    WHERE id = p_request_id;
  END IF;

  PERFORM public.write_audit_log(
    CASE WHEN v_approve THEN 'funding.approved' ELSE 'funding.declined' END,
    p_request_id,
    jsonb_build_object('amount', v_request.amount, 'profile_id', v_request.profile_id)
  );

  RETURN v_transaction_id; -- NULL when declined
END;
$$;

REVOKE ALL ON FUNCTION public.approve_funding_request(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.approve_funding_request(UUID, TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- Peer transfer
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.transfer_funds(
  p_recipient TEXT,
  p_amount NUMERIC,
  p_note TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sender_account_id UUID;
  v_recipient_account_id UUID;
  v_recipient_profile_id UUID;
  v_recipient_profile public.profiles%ROWTYPE;
  v_sender_profile public.profiles%ROWTYPE;
  v_available NUMERIC;
  v_transaction_id UUID;
  v_lookup TEXT;
BEGIN
  PERFORM public.enforce_rate_limit('transfer', 10, 300);

  v_lookup := LOWER(TRIM(p_recipient));
  IF v_lookup IS NULL OR LENGTH(v_lookup) < 3 THEN
    RAISE EXCEPTION 'Enter a valid recipient email or account number';
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 OR p_amount > 5000000 THEN
    RAISE EXCEPTION 'Amount must be between ₦0.01 and ₦5,000,000';
  END IF;

  SELECT * INTO v_sender_profile FROM public.profiles WHERE id = auth.uid();
  IF v_sender_profile.account_status <> 'active' THEN
    RAISE EXCEPTION 'Transfers require an active account with a positive balance';
  END IF;

  IF v_sender_profile.account_status = 'frozen' THEN
    RAISE EXCEPTION 'Account is frozen';
  END IF;

  v_sender_account_id := public.get_user_account_id(auth.uid());
  v_available := public.get_available_balance(v_sender_account_id);

  IF v_available < p_amount THEN
    RAISE EXCEPTION 'Insufficient balance';
  END IF;

  SELECT a.id, a.profile_id
  INTO v_recipient_account_id, v_recipient_profile_id
  FROM public.accounts a
  JOIN public.profiles p ON p.id = a.profile_id
  WHERE a.is_system = FALSE
    AND (
      LOWER(p.email) = v_lookup
      OR a.account_number = TRIM(p_recipient)
    )
  LIMIT 1;

  IF v_recipient_account_id IS NULL THEN
    RAISE EXCEPTION 'Recipient not found';
  END IF;

  SELECT * INTO v_recipient_profile
  FROM public.profiles
  WHERE id = v_recipient_profile_id;

  IF v_recipient_profile.id = auth.uid() THEN
    RAISE EXCEPTION 'Cannot transfer to yourself';
  END IF;

  IF v_recipient_profile.account_status = 'frozen' THEN
    RAISE EXCEPTION 'Recipient account is not available';
  END IF;

  IF v_recipient_profile.kyc_status <> 'approved' THEN
    RAISE EXCEPTION 'Recipient has not completed verification';
  END IF;

  INSERT INTO public.transactions (
    type, from_account_id, to_account_id, amount, status, initiated_by, note
  )
  VALUES (
    'transfer', v_sender_account_id, v_recipient_account_id, p_amount,
    'completed', auth.uid(), public.sanitize_text(p_note, 300)
  )
  RETURNING id INTO v_transaction_id;

  PERFORM public.post_ledger_transaction(
    v_transaction_id, v_sender_account_id, v_recipient_account_id, p_amount
  );

  RETURN v_transaction_id;
END;
$$;

REVOKE ALL ON FUNCTION public.transfer_funds(TEXT, NUMERIC, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.transfer_funds(TEXT, NUMERIC, TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- Withdrawal request (pending review — no debit until approval)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.request_withdrawal(
  p_amount NUMERIC,
  p_note TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_account_id UUID;
  v_profile public.profiles%ROWTYPE;
  v_available NUMERIC;
  v_daily_total NUMERIC;
  v_transaction_id UUID;
BEGIN
  PERFORM public.enforce_rate_limit('withdrawal', 5, 300);

  SELECT * INTO v_profile FROM public.profiles WHERE id = auth.uid();
  IF v_profile.account_status <> 'active' THEN
    RAISE EXCEPTION 'Withdrawals require an active account with a positive balance';
  END IF;

  IF v_profile.account_status = 'frozen' THEN
    RAISE EXCEPTION 'Account is frozen';
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 OR p_amount > 2000000 THEN
    RAISE EXCEPTION 'Amount must be between ₦0.01 and ₦2,000,000';
  END IF;

  v_account_id := public.get_user_account_id(auth.uid());
  v_available := public.get_available_balance(v_account_id);

  IF v_available < p_amount THEN
    RAISE EXCEPTION 'Insufficient available balance';
  END IF;

  SELECT COALESCE(SUM(amount), 0) INTO v_daily_total
  FROM public.transactions
  WHERE from_account_id = v_account_id
    AND type = 'withdrawal'
    AND created_at >= CURRENT_DATE
    AND status IN ('pending', 'completed');

  IF v_daily_total + p_amount > 2000000 THEN
    RAISE EXCEPTION 'Daily withdrawal limit exceeded';
  END IF;

  INSERT INTO public.transactions (
    type, from_account_id, to_account_id, amount, status, initiated_by, note
  )
  VALUES (
    'withdrawal', v_account_id, public.get_treasury_account_id(), p_amount,
    'pending', auth.uid(), public.sanitize_text(p_note, 300)
  )
  RETURNING id INTO v_transaction_id;

  RETURN v_transaction_id;
END;
$$;

REVOKE ALL ON FUNCTION public.request_withdrawal(NUMERIC, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.request_withdrawal(NUMERIC, TEXT) TO authenticated;

-- Super admin withdrawal review (Phase 3 UI will call this)
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
  IF NOT public.is_super_admin() THEN
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

REVOKE ALL ON FUNCTION public.review_withdrawal(UUID, BOOLEAN, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.review_withdrawal(UUID, BOOLEAN, TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- RLS: users see transactions they initiated OR received
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS "Users can view own transactions" ON public.transactions;

CREATE POLICY "Users can view relevant transactions"
  ON public.transactions FOR SELECT
  TO authenticated
  USING (
    initiated_by = auth.uid()
    OR public.is_admin()
    OR EXISTS (
      SELECT 1 FROM public.accounts a
      WHERE a.id = transactions.to_account_id
        AND a.profile_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.accounts a
      WHERE a.id = transactions.from_account_id
        AND a.profile_id = auth.uid()
    )
  );

-- Prevent direct transaction inserts from client (use RPCs)
DROP POLICY IF EXISTS "Users can create transactions" ON public.transactions;

-- Prevent direct funding request inserts (use RPC)
DROP POLICY IF EXISTS "Verified users can create funding requests" ON public.funding_requests;

CREATE POLICY "Verified users create funding via RPC only"
  ON public.funding_requests FOR INSERT
  TO authenticated
  WITH CHECK (FALSE);

-- KYC: only via RPC
DROP POLICY IF EXISTS "Users can submit own KYC" ON public.kyc_submissions;

CREATE POLICY "Users submit KYC via RPC only"
  ON public.kyc_submissions FOR INSERT
  TO authenticated
  WITH CHECK (FALSE);

GRANT EXECUTE ON FUNCTION public.enforce_rate_limit(TEXT, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_available_balance(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_account_id(UUID) TO authenticated;
