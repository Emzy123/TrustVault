-- Atlas Phase 1: Auth hooks, ledger function, updated_at triggers

-- ---------------------------------------------------------------------------
-- Role helpers (used by RLS)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS public.user_role
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT role IN ('admin', 'super_admin') FROM public.profiles WHERE id = auth.uid()),
    FALSE
  );
$$;

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

CREATE OR REPLACE FUNCTION public.get_treasury_account_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id FROM public.accounts WHERE is_system = TRUE AND label = 'Platform Treasury' LIMIT 1;
$$;

-- ---------------------------------------------------------------------------
-- updated_at maintenance
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_set_updated_at ON public.profiles;
CREATE TRIGGER profiles_set_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS accounts_set_updated_at ON public.accounts;
CREATE TRIGGER accounts_set_updated_at
  BEFORE UPDATE ON public.accounts
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS transactions_set_updated_at ON public.transactions;
CREATE TRIGGER transactions_set_updated_at
  BEFORE UPDATE ON public.transactions
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS funding_requests_set_updated_at ON public.funding_requests;
CREATE TRIGGER funding_requests_set_updated_at
  BEFORE UPDATE ON public.funding_requests
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Schema & sequence permissions
-- ---------------------------------------------------------------------------

GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role, postgres;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role, postgres;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role, postgres;

-- ---------------------------------------------------------------------------
-- New user signup: profile + wallet account
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
BEGIN
  IF NEW.email = 'admin@atlas.demo' THEN
    v_role := 'admin';
  ELSIF NEW.email = 'superadmin@atlas.demo' THEN
    v_role := 'super_admin';
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
    role = CASE WHEN EXCLUDED.email IN ('admin@atlas.demo', 'superadmin@atlas.demo') THEN v_role ELSE public.profiles.role END,
    full_name = CASE WHEN EXCLUDED.full_name <> '' THEN EXCLUDED.full_name ELSE public.profiles.full_name END;

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

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Atomic double-entry ledger posting (Section 7.2)
-- Balance changes MUST go through this function — never direct client updates.
-- ---------------------------------------------------------------------------

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
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be positive';
  END IF;

  IF p_debit_account_id = p_credit_account_id THEN
    RAISE EXCEPTION 'Debit and credit accounts must differ';
  END IF;

  SELECT balance INTO v_debit_balance
  FROM public.accounts
  WHERE id = p_debit_account_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Debit account not found';
  END IF;

  SELECT balance INTO v_credit_balance
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
END;
$$;

REVOKE ALL ON FUNCTION public.post_ledger_transaction(UUID, UUID, UUID, NUMERIC) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.post_ledger_transaction(UUID, UUID, UUID, NUMERIC) TO authenticated;

-- ---------------------------------------------------------------------------
-- Audit log helper (used by privileged actions in later phases)
-- ---------------------------------------------------------------------------

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

REVOKE ALL ON FUNCTION public.write_audit_log(TEXT, UUID, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.write_audit_log(TEXT, UUID, JSONB) TO authenticated;
