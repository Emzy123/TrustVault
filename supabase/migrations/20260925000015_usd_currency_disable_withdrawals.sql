-- TrustVault: Switch wallet currency to USD and disable withdrawals
-- Run after prior migrations. Safe to re-run.

-- 1. Default currency for new accounts
ALTER TABLE public.accounts
  ALTER COLUMN currency SET DEFAULT 'USD';

-- 2. Migrate existing account currency labels
UPDATE public.accounts
SET currency = 'USD'
WHERE currency IS DISTINCT FROM 'USD';

-- 3. Reject any new withdrawal requests
CREATE OR REPLACE FUNCTION public.request_withdrawal(
  p_amount NUMERIC,
  p_note TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RAISE EXCEPTION 'Withdrawals are no longer supported';
END;
$$;

REVOKE ALL ON FUNCTION public.request_withdrawal(NUMERIC, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.request_withdrawal(NUMERIC, TEXT) TO authenticated;

-- 4. Soft-close any pending withdrawal requests (decline without debit)
UPDATE public.transactions
SET
  status = 'declined',
  decline_reason = COALESCE(decline_reason, 'Withdrawals are no longer supported'),
  updated_at = NOW()
WHERE type = 'withdrawal'
  AND status = 'pending';
