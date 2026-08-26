-- Atlas: Wallet transfer / withdrawal / funding RPCs
-- Run in Supabase Dashboard → SQL Editor if transfers fail with
--   "Could not find the function public.transfer_funds ..."

-- ---------------------------------------------------------------------------
-- Helpers (safe to re-run)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.action_rate_limits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  action_type TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_action_rate_limits_lookup
  ON public.action_rate_limits (profile_id, action_type, created_at DESC);

ALTER TABLE public.action_rate_limits ENABLE ROW LEVEL SECURITY;

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

  -- Required when prevent_direct_balance_update trigger is enabled (setup_and_seed_all.sql)
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
-- Peer transfer
-- ---------------------------------------------------------------------------

DROP FUNCTION IF EXISTS public.transfer_funds(TEXT, NUMERIC, TEXT);

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
    RAISE EXCEPTION 'Amount must be between $0.01 and $5,000,000';
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

  BEGIN
    PERFORM public.queue_email(
      v_sender_profile.email,
      'transfer_sent',
      'Transfer completed successfully',
      jsonb_build_object(
        'full_name', v_sender_profile.full_name,
        'amount', p_amount,
        'recipient', v_recipient_profile.full_name,
        'recipient_email', v_recipient_profile.email,
        'note', public.sanitize_text(p_note, 300),
        'transaction_id', v_transaction_id
      )
    );

    PERFORM public.queue_email(
      v_recipient_profile.email,
      'transfer_received',
      'You received a transfer',
      jsonb_build_object(
        'full_name', v_recipient_profile.full_name,
        'amount', p_amount,
        'sender', v_sender_profile.full_name,
        'sender_email', v_sender_profile.email,
        'note', public.sanitize_text(p_note, 300),
        'transaction_id', v_transaction_id
      )
    );
  EXCEPTION WHEN undefined_function THEN
    NULL;
  END;

  RETURN v_transaction_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- Withdrawal request
-- ---------------------------------------------------------------------------

DROP FUNCTION IF EXISTS public.request_withdrawal(NUMERIC, TEXT);

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
    RAISE EXCEPTION 'Amount must be between $0.01 and $2,000,000';
  END IF;

  v_account_id := public.get_user_account_id(auth.uid());
  PERFORM balance FROM public.accounts WHERE id = v_account_id FOR UPDATE;

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

-- ---------------------------------------------------------------------------
-- Funding request
-- ---------------------------------------------------------------------------

DROP FUNCTION IF EXISTS public.submit_funding_request(NUMERIC, TEXT);

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

REVOKE ALL ON FUNCTION public.transfer_funds(TEXT, NUMERIC, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.transfer_funds(TEXT, NUMERIC, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.request_withdrawal(NUMERIC, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.request_withdrawal(NUMERIC, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.submit_funding_request(NUMERIC, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_funding_request(NUMERIC, TEXT) TO authenticated;

GRANT EXECUTE ON FUNCTION public.enforce_rate_limit(TEXT, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_available_balance(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_account_id(UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
