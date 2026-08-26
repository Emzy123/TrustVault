-- Atlas: Re-register ALL missing RPCs and helper functions
-- Run this entire script in Supabase SQL Editor.
-- Order matters: helpers first, then the RPCs that call them.

-- ===========================================================================
-- A. sync_account_status  (helper: derive verified/active from KYC + balance)
-- ===========================================================================

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
    UPDATE public.profiles
    SET account_status = 'active'
    WHERE id = p_profile_id AND account_status <> 'frozen';
  ELSIF v_kyc_status = 'approved' AND v_balance = 0 THEN
    UPDATE public.profiles
    SET account_status = 'verified'
    WHERE id = p_profile_id AND account_status <> 'frozen';
  END IF;
END;
$$;

-- ===========================================================================
-- B. post_ledger_transaction  (helper: debit/credit accounts + update balances)
-- ===========================================================================

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
  v_debit_balance  NUMERIC(18, 2);
  v_credit_balance NUMERIC(18, 2);
  v_debit_profile  UUID;
  v_credit_profile UUID;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be positive';
  END IF;

  IF p_debit_account_id = p_credit_account_id THEN
    RAISE EXCEPTION 'Debit and credit accounts must differ';
  END IF;

  PERFORM set_config('atlas.allow_ledger_posting', 'true', true);

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

  v_debit_balance  := v_debit_balance  - p_amount;
  v_credit_balance := v_credit_balance + p_amount;

  INSERT INTO public.ledger_entries (account_id, transaction_id, entry_type, amount, balance_after)
  VALUES (p_debit_account_id,  p_transaction_id, 'debit',  p_amount, v_debit_balance);

  INSERT INTO public.ledger_entries (account_id, transaction_id, entry_type, amount, balance_after)
  VALUES (p_credit_account_id, p_transaction_id, 'credit', p_amount, v_credit_balance);

  UPDATE public.accounts SET balance = v_debit_balance  WHERE id = p_debit_account_id;
  UPDATE public.accounts SET balance = v_credit_balance WHERE id = p_credit_account_id;

  IF v_debit_profile IS NOT NULL THEN
    PERFORM public.sync_account_status(v_debit_profile);
  END IF;
  IF v_credit_profile IS NOT NULL THEN
    PERFORM public.sync_account_status(v_credit_profile);
  END IF;
END;
$$;

-- ===========================================================================
-- 0. submit_funding_request  (User: submit a funding request)
-- ===========================================================================

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
    RAISE EXCEPTION 'Amount must be between $0.01 and $10,000,000';
  END IF;

  INSERT INTO public.funding_requests (profile_id, amount, note, status)
  VALUES (auth.uid(), p_amount, public.sanitize_text(p_note, 300), 'pending')
  RETURNING id INTO v_request_id;

  RETURN v_request_id;
END;
$$;

REVOKE ALL ON FUNCTION public.submit_funding_request(NUMERIC, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_funding_request(NUMERIC, TEXT) TO authenticated;

-- ===========================================================================
-- 1. review_kyc_submission  (Admin: approve / decline KYC submissions)
-- ===========================================================================

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

-- ===========================================================================
-- 2. approve_funding_request  (Admin: approve / decline funding requests)
-- ===========================================================================

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
  v_request        public.funding_requests%ROWTYPE;
  v_user_account_id UUID;
  v_treasury_id    UUID;
  v_transaction_id UUID;
  v_approve        BOOLEAN;
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
    v_treasury_id     := public.get_treasury_account_id();

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
    SET status = 'approved', reviewed_by = auth.uid(), reviewed_at = NOW()
    WHERE id = p_request_id;

    PERFORM public.sync_account_status(v_request.profile_id);
  ELSE
    IF p_decline_reason IS NULL OR LENGTH(TRIM(p_decline_reason)) < 3 THEN
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

  RETURN v_transaction_id;
END;
$$;

REVOKE ALL ON FUNCTION public.approve_funding_request(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.approve_funding_request(UUID, TEXT) TO authenticated;

-- ===========================================================================
-- 3. review_withdrawal  (Admin: approve / decline withdrawal transactions)
-- ===========================================================================

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
  v_tx        public.transactions%ROWTYPE;
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

REVOKE ALL ON FUNCTION public.review_withdrawal(UUID, BOOLEAN, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.review_withdrawal(UUID, BOOLEAN, TEXT) TO authenticated;

-- ===========================================================================
-- 4. Verify all functions exist
-- ===========================================================================

SELECT proname, pg_get_function_arguments(oid)
FROM pg_proc
WHERE proname IN (
  'sync_account_status',
  'post_ledger_transaction',
  'submit_funding_request',
  'review_kyc_submission',
  'approve_funding_request',
  'review_withdrawal'
)
AND pronamespace = 'public'::regnamespace
ORDER BY proname;

-- ===========================================================================
-- 5. Reload PostgREST schema cache
-- ===========================================================================

NOTIFY pgrst, 'reload schema';
