-- Fix: post_ledger_transaction must bypass prevent_direct_balance_update trigger.
-- Run if transfers/funding fail with:
--   "Account balance cannot be modified directly. Use post_ledger_transaction."

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

  PERFORM set_config('trustvault.allow_ledger_posting', 'true', true);

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

NOTIFY pgrst, 'reload schema';
