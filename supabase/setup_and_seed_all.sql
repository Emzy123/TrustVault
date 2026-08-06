-- TrustVault Master Database Setup & Auth Seed Script
--
-- Copy and paste this ENTIRE script into your Supabase Dashboard SQL Editor and click 'Run'.
-- It creates all tables, triggers, ledger functions, RLS policies, schema permissions,
-- and pre-confirmed demo users without deleting existing records.

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ---------------------------------------------------------------------------
-- 1. Sequences & Enums
-- ---------------------------------------------------------------------------

CREATE SEQUENCE IF NOT EXISTS public.account_number_seq START WITH 1000000001;

DO $$ BEGIN
  CREATE TYPE public.user_role AS ENUM ('user', 'admin', 'super_admin');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.account_status AS ENUM ('unverified', 'verified', 'active', 'frozen');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.kyc_status AS ENUM ('not_submitted', 'pending', 'approved', 'declined');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- 2. Tables
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  phone TEXT,
  role public.user_role NOT NULL DEFAULT 'user',
  account_status public.account_status NOT NULL DEFAULT 'unverified',
  kyc_status public.kyc_status NOT NULL DEFAULT 'not_submitted',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.kyc_submissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  id_type TEXT NOT NULL,
  id_number TEXT NOT NULL,
  dob DATE NOT NULL,
  address TEXT NOT NULL,
  document_url TEXT,
  status public.kyc_status NOT NULL DEFAULT 'pending',
  decline_reason TEXT,
  reviewed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  balance NUMERIC(18, 2) NOT NULL DEFAULT 0.00 CHECK (balance >= 0),
  currency TEXT NOT NULL DEFAULT 'USD',
  account_number TEXT UNIQUE NOT NULL,
  is_system BOOLEAN NOT NULL DEFAULT FALSE,
  label TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL CHECK (type IN ('transfer', 'deposit', 'withdrawal', 'funding')),
  from_account_id UUID REFERENCES public.accounts(id) ON DELETE CASCADE,
  to_account_id UUID REFERENCES public.accounts(id) ON DELETE CASCADE,
  amount NUMERIC(18, 2) NOT NULL CHECK (amount > 0),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'declined', 'flagged', 'reversed')),
  decline_reason TEXT,
  initiated_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.ledger_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id UUID NOT NULL REFERENCES public.accounts(id) ON DELETE CASCADE,
  transaction_id UUID NOT NULL REFERENCES public.transactions(id) ON DELETE CASCADE,
  entry_type TEXT NOT NULL CHECK (entry_type IN ('debit', 'credit')),
  amount NUMERIC(18, 2) NOT NULL CHECK (amount > 0),
  balance_after NUMERIC(18, 2) NOT NULL CHECK (balance_after >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.funding_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  amount NUMERIC(18, 2) NOT NULL CHECK (amount > 0),
  note TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'declined')),
  decline_reason TEXT,
  reviewed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.flags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id UUID NOT NULL REFERENCES public.transactions(id) ON DELETE CASCADE,
  raised_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'resolved', 'dismissed')),
  resolution_note TEXT,
  resolved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  action TEXT NOT NULL,
  target_id UUID,
  metadata JSONB DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Ensure Platform Treasury system account exists
INSERT INTO public.accounts (id, profile_id, balance, currency, account_number, is_system, label)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  NULL,
  1000000000.00,
  'USD',
  'TREASURY-001',
  TRUE,
  'Platform Treasury'
)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3. Functions, Triggers & Ledger RPC
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email, phone, role, account_status, kyc_status)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data ->> 'full_name', ''),
    NEW.email,
    NEW.raw_user_meta_data ->> 'phone',
    'user',
    'unverified',
    'not_submitted'
  )
  ON CONFLICT (id) DO NOTHING;

  IF NOT EXISTS (SELECT 1 FROM public.accounts WHERE profile_id = NEW.id) THEN
    INSERT INTO public.accounts (profile_id, balance, currency, account_number)
    VALUES (
      NEW.id,
      0,
      'NGN',
      LPAD(nextval('public.account_number_seq')::TEXT, 10, '0')
    )
    ON CONFLICT DO NOTHING;
  END IF;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

CREATE OR REPLACE FUNCTION public.protect_profile_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF session_user <> 'postgres' AND current_user <> 'postgres' AND NOT public.is_admin() THEN
    IF OLD.role IS DISTINCT FROM NEW.role THEN
      RAISE EXCEPTION 'Not authorized to change role';
    END IF;
    IF OLD.kyc_status IS DISTINCT FROM NEW.kyc_status THEN
      RAISE EXCEPTION 'Not authorized to change KYC status';
    END IF;
    IF OLD.account_status IS DISTINCT FROM NEW.account_status THEN
      RAISE EXCEPTION 'Not authorized to change account status';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_profile_columns ON public.profiles;
CREATE TRIGGER trg_protect_profile_columns
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.protect_profile_columns();

CREATE OR REPLACE FUNCTION public.get_treasury_account_id()
RETURNS UUID LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT id FROM public.accounts WHERE is_system = TRUE AND label = 'Platform Treasury' LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.get_user_account_id(p_profile_id UUID)
RETURNS UUID LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT id FROM public.accounts WHERE profile_id = p_profile_id LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.get_available_balance(p_account_id UUID)
RETURNS NUMERIC LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_balance NUMERIC(18, 2);
  v_pending_withdrawals NUMERIC(18, 2);
BEGIN
  SELECT balance INTO v_balance FROM public.accounts WHERE id = p_account_id;
  IF NOT FOUND THEN RETURN 0; END IF;

  SELECT COALESCE(SUM(amount), 0) INTO v_pending_withdrawals
  FROM public.transactions
  WHERE from_account_id = p_account_id AND type = 'withdrawal' AND status = 'pending';

  RETURN GREATEST(v_balance - v_pending_withdrawals, 0);
END;
$$;

CREATE OR REPLACE FUNCTION public.prevent_ledger_tampering()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF current_setting('trustvault.allow_ledger_deletion', TRUE) = 'true' THEN
    IF TG_OP = 'DELETE' THEN
      RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
      RETURN NEW;
    END IF;
  END IF;
  RAISE EXCEPTION 'Ledger entries are strictly immutable. Updates and deletions are forbidden.';
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_ledger_tampering ON public.ledger_entries;
CREATE TRIGGER trg_prevent_ledger_tampering
  BEFORE UPDATE OR DELETE ON public.ledger_entries
  FOR EACH ROW EXECUTE FUNCTION public.prevent_ledger_tampering();

CREATE OR REPLACE FUNCTION public.prevent_direct_balance_update()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF OLD.balance IS DISTINCT FROM NEW.balance THEN
    IF current_setting('trustvault.allow_ledger_posting', TRUE) IS DISTINCT FROM 'true' THEN
      RAISE EXCEPTION 'Account balance cannot be modified directly. Use post_ledger_transaction.';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_direct_balance_update ON public.accounts;
CREATE TRIGGER trg_prevent_direct_balance_update
  BEFORE UPDATE ON public.accounts
  FOR EACH ROW EXECUTE FUNCTION public.prevent_direct_balance_update();

CREATE OR REPLACE FUNCTION public.post_ledger_transaction(
  p_transaction_id UUID,
  p_debit_account_id UUID,
  p_credit_account_id UUID,
  p_amount NUMERIC
)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_debit_balance NUMERIC(18, 2);
  v_credit_balance NUMERIC(18, 2);
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN RAISE EXCEPTION 'Amount must be positive'; END IF;
  IF p_debit_account_id = p_credit_account_id THEN RAISE EXCEPTION 'Debit and credit accounts must differ'; END IF;

  PERFORM set_config('trustvault.allow_ledger_posting', 'true', true);

  SELECT balance INTO v_debit_balance FROM public.accounts WHERE id = p_debit_account_id FOR UPDATE;
  SELECT balance INTO v_credit_balance FROM public.accounts WHERE id = p_credit_account_id FOR UPDATE;

  IF v_debit_balance < p_amount THEN RAISE EXCEPTION 'Insufficient balance'; END IF;

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

-- Rate limiting table
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
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_submission_id UUID;
  v_profile public.profiles%ROWTYPE;
BEGIN
  PERFORM public.enforce_rate_limit('kyc_submit', 10, 3600);

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

CREATE OR REPLACE FUNCTION public.review_kyc_submission(
  p_submission_id UUID,
  p_approve BOOLEAN,
  p_decline_reason TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_sub public.kyc_submissions%ROWTYPE;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT * INTO v_sub FROM public.kyc_submissions WHERE id = p_submission_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Submission not found'; END IF;

  IF p_approve THEN
    UPDATE public.kyc_submissions
    SET status = 'approved'::kyc_submission_status, reviewed_by = auth.uid(), reviewed_at = NOW()
    WHERE id = p_submission_id;

    UPDATE public.profiles
    SET kyc_status = 'approved'::kyc_status,
        kyc_level = GREATEST(kyc_level, v_sub.level),
        account_status = CASE WHEN v_sub.level >= 2 THEN 'active'::account_status ELSE 'verified'::account_status END
    WHERE id = v_sub.profile_id;
  ELSE
    UPDATE public.kyc_submissions
    SET status = 'declined'::kyc_submission_status, notes = p_decline_reason, reviewed_by = auth.uid(), reviewed_at = NOW()
    WHERE id = p_submission_id;

    UPDATE public.profiles
    SET kyc_status = 'declined'::kyc_status
    WHERE id = v_sub.profile_id;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_kyc(
  p_id_type TEXT,
  p_id_number TEXT,
  p_dob TEXT,
  p_address TEXT,
  p_document_url TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN public.submit_kyc(
    p_id_type,
    p_id_number,
    p_dob::DATE,
    p_address,
    p_document_url
  );
END;
$$;

REVOKE ALL ON FUNCTION public.submit_kyc(TEXT, TEXT, DATE, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_kyc(TEXT, TEXT, DATE, TEXT, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.submit_kyc(TEXT, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_kyc(TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- 4. Schema Permissions & RLS Setup
-- ---------------------------------------------------------------------------

GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kyc_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ledger_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.funding_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
  );
$$;

CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
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
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_total_users INT;
  v_pending_kyc INT;
  v_pending_funding INT;
  v_pending_withdrawals INT;
  v_open_flags INT;
  v_daily_volume NUMERIC;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT COUNT(*) INTO v_total_users FROM public.profiles WHERE role = 'user';
  SELECT COUNT(*) INTO v_pending_kyc FROM public.kyc_submissions WHERE status = 'pending';
  SELECT COUNT(*) INTO v_pending_funding FROM public.funding_requests WHERE status = 'pending';
  SELECT COUNT(*) INTO v_pending_withdrawals FROM public.transactions WHERE type = 'withdrawal' AND status = 'pending';
  SELECT COUNT(*) INTO v_open_flags FROM public.flags WHERE status = 'open';
  SELECT COALESCE(SUM(amount), 0) INTO v_daily_volume FROM public.transactions
    WHERE status = 'completed' AND created_at >= NOW() - INTERVAL '24 hours';
  RETURN jsonb_build_object(
    'total_users', v_total_users, 'pending_kyc', v_pending_kyc,
    'pending_funding', v_pending_funding, 'pending_withdrawals', v_pending_withdrawals,
    'open_flags', v_open_flags, 'daily_volume', v_daily_volume
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_super_admin_metrics()
RETURNS JSONB
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_total_users INT; v_pending_kyc INT; v_pending_funding INT; v_pending_withdrawals INT;
  v_open_flags INT; v_frozen_accounts INT; v_total_admins INT; v_total_volume NUMERIC;
BEGIN
  IF NOT public.is_super_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT COUNT(*) INTO v_total_users FROM public.profiles WHERE role = 'user';
  SELECT COUNT(*) INTO v_pending_kyc FROM public.kyc_submissions WHERE status = 'pending';
  SELECT COUNT(*) INTO v_pending_funding FROM public.funding_requests WHERE status = 'pending';
  SELECT COUNT(*) INTO v_pending_withdrawals FROM public.transactions WHERE type = 'withdrawal' AND status = 'pending';
  SELECT COUNT(*) INTO v_open_flags FROM public.flags WHERE status = 'open';
  SELECT COUNT(*) INTO v_frozen_accounts FROM public.profiles WHERE account_status = 'frozen';
  SELECT COUNT(*) INTO v_total_admins FROM public.profiles WHERE role IN ('admin', 'super_admin');
  SELECT COALESCE(SUM(amount), 0) INTO v_total_volume FROM public.transactions WHERE status = 'completed';
  RETURN jsonb_build_object(
    'total_users', v_total_users, 'pending_kyc', v_pending_kyc,
    'pending_funding', v_pending_funding, 'pending_withdrawals', v_pending_withdrawals,
    'open_flags', v_open_flags, 'frozen_accounts', v_frozen_accounts,
    'total_admins', v_total_admins, 'total_volume', v_total_volume
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_platform_analytics()
RETURNS JSONB
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_total_users INT; v_active_users INT; v_total_flags INT; v_open_flags INT;
  v_resolved_flags INT; v_flag_rate NUMERIC; v_pending_invites INT;
  v_volume_7d NUMERIC; v_volume_30d NUMERIC;
BEGIN
  IF NOT public.is_super_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT COUNT(*) INTO v_total_users FROM public.profiles WHERE role = 'user';
  SELECT COUNT(*) INTO v_active_users FROM public.profiles WHERE role = 'user' AND account_status = 'active';
  SELECT COUNT(*) INTO v_total_flags FROM public.flags;
  SELECT COUNT(*) INTO v_open_flags FROM public.flags WHERE status = 'open';
  SELECT COUNT(*) INTO v_resolved_flags FROM public.flags WHERE status IN ('resolved', 'dismissed');
  SELECT COUNT(*) INTO v_pending_invites FROM public.admin_invitations WHERE accepted_at IS NULL;
  SELECT COALESCE(SUM(amount), 0) INTO v_volume_7d FROM public.transactions
    WHERE status = 'completed' AND created_at >= NOW() - INTERVAL '7 days';
  SELECT COALESCE(SUM(amount), 0) INTO v_volume_30d FROM public.transactions
    WHERE status = 'completed' AND created_at >= NOW() - INTERVAL '30 days';
  IF v_total_flags > 0 THEN
    v_flag_rate := ROUND((v_open_flags::NUMERIC / v_total_flags::NUMERIC) * 100, 1);
  ELSE v_flag_rate := 0; END IF;
  RETURN jsonb_build_object(
    'active_users', v_active_users,
    'active_user_rate', CASE WHEN v_total_users > 0 THEN ROUND((v_active_users::NUMERIC / v_total_users::NUMERIC) * 100, 1) ELSE 0 END,
    'total_flags', v_total_flags, 'open_flags', v_open_flags, 'resolved_flags', v_resolved_flags,
    'flag_rate_pct', v_flag_rate, 'pending_admin_invites', v_pending_invites,
    'volume_7d', v_volume_7d, 'volume_30d', v_volume_30d
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_admin_metrics() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_admin_metrics() TO authenticated;
REVOKE ALL ON FUNCTION public.get_super_admin_metrics() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_super_admin_metrics() TO authenticated;
REVOKE ALL ON FUNCTION public.get_platform_analytics() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_platform_analytics() TO authenticated;

DROP POLICY IF EXISTS "profiles_select_policy" ON public.profiles;
CREATE POLICY "profiles_select_policy" ON public.profiles
  FOR SELECT USING (auth.uid() = id OR public.is_admin());

DROP POLICY IF EXISTS "profiles_update_policy" ON public.profiles;
CREATE POLICY "profiles_update_policy" ON public.profiles
  FOR UPDATE USING (auth.uid() = id OR public.is_admin());

DROP POLICY IF EXISTS "accounts_select_policy" ON public.accounts;
CREATE POLICY "accounts_select_policy" ON public.accounts
  FOR SELECT USING (auth.uid() = profile_id OR is_system = TRUE OR public.is_admin());

DROP POLICY IF EXISTS "transactions_select_policy" ON public.transactions;
CREATE POLICY "transactions_select_policy" ON public.transactions
  FOR SELECT USING (
    initiated_by = auth.uid() OR
    from_account_id IN (SELECT id FROM public.accounts WHERE profile_id = auth.uid()) OR
    to_account_id IN (SELECT id FROM public.accounts WHERE profile_id = auth.uid()) OR
    public.is_admin()
  );

DROP POLICY IF EXISTS "kyc_submissions_policy" ON public.kyc_submissions;
CREATE POLICY "kyc_submissions_policy" ON public.kyc_submissions
  FOR ALL USING (profile_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "funding_requests_policy" ON public.funding_requests;
CREATE POLICY "funding_requests_policy" ON public.funding_requests
  FOR ALL USING (profile_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "flags_policy" ON public.flags;
CREATE POLICY "flags_policy" ON public.flags
  FOR ALL USING (raised_by = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "audit_logs_policy" ON public.audit_logs;
CREATE POLICY "audit_logs_policy" ON public.audit_logs
  FOR ALL USING (actor_id = auth.uid() OR public.is_admin());

-- ---------------------------------------------------------------------------
-- 5. Pre-Confirmed Auth Users Seeding (Password: Password123!)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.seed_auth_user(
  p_email TEXT,
  p_password TEXT,
  p_full_name TEXT
)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, extensions AS $$
DECLARE
  v_user_id UUID;
  v_encrypted_pw TEXT;
  v_instance_id UUID;
BEGIN
  SELECT instance_id INTO v_instance_id FROM auth.users WHERE instance_id IS NOT NULL LIMIT 1;
  IF v_instance_id IS NULL THEN
    v_instance_id := '00000000-0000-0000-0000-000000000000'::UUID;
  END IF;

  v_encrypted_pw := crypt(p_password, gen_salt('bf'));
  SELECT id INTO v_user_id FROM auth.users WHERE email = p_email;
  
  IF v_user_id IS NULL THEN
    v_user_id := gen_random_uuid();

    INSERT INTO auth.users (
      id, instance_id, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
    )
    VALUES (
      v_user_id,
      v_instance_id,
      p_email,
      v_encrypted_pw,
      NOW(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('full_name', p_full_name, 'phone', '+2348000000000'),
      NOW(), NOW(),
      'authenticated', 'authenticated'
    );
  ELSE
    UPDATE auth.users
    SET encrypted_password = v_encrypted_pw,
        email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
        instance_id = v_instance_id,
        raw_user_meta_data = jsonb_build_object('full_name', p_full_name, 'phone', '+2348000000000'),
        updated_at = NOW()
    WHERE id = v_user_id;
  END IF;

  RETURN v_user_id;
END;
$$;

DO $$
DECLARE
  v_alice_id UUID;
  v_bob_id UUID;
  v_charlie_id UUID;
  v_admin_id UUID;
  v_superadmin_id UUID;
  v_alice_acc UUID;
  v_treasury_id UUID;
  v_tx_id UUID;
BEGIN
  v_alice_id := public.seed_auth_user('alice@trustvault.demo', 'Password123!', 'Alice Vance');
  v_bob_id := public.seed_auth_user('bob@trustvault.demo', 'Password123!', 'Bob Builder');
  v_charlie_id := public.seed_auth_user('charlie@trustvault.demo', 'Password123!', 'Charlie Brown');
  v_admin_id := public.seed_auth_user('admin@trustvault.demo', 'Password123!', 'Admin Officer');
  v_superadmin_id := public.seed_auth_user('superadmin@trustvault.demo', 'Password123!', 'Super Admin Officer');

  -- Profiles
  INSERT INTO public.profiles (id, full_name, email, role, account_status, kyc_status)
  VALUES (v_alice_id, 'Alice Vance', 'alice@trustvault.demo', 'user', 'active', 'approved')
  ON CONFLICT (id) DO UPDATE SET role = 'user', account_status = 'active', kyc_status = 'approved';

  INSERT INTO public.profiles (id, full_name, email, role, account_status, kyc_status)
  VALUES (v_bob_id, 'Bob Builder', 'bob@trustvault.demo', 'user', 'verified', 'approved')
  ON CONFLICT (id) DO UPDATE SET role = 'user', account_status = 'verified', kyc_status = 'approved';

  INSERT INTO public.profiles (id, full_name, email, role, account_status, kyc_status)
  VALUES (v_charlie_id, 'Charlie Brown', 'charlie@trustvault.demo', 'user', 'unverified', 'not_submitted')
  ON CONFLICT (id) DO UPDATE SET role = 'user', account_status = 'unverified', kyc_status = 'not_submitted';

  INSERT INTO public.profiles (id, full_name, email, role, account_status, kyc_status)
  VALUES (v_admin_id, 'Admin Officer', 'admin@trustvault.demo', 'admin', 'verified', 'approved')
  ON CONFLICT (id) DO UPDATE SET role = 'admin', account_status = 'verified', kyc_status = 'approved';

  INSERT INTO public.profiles (id, full_name, email, role, account_status, kyc_status)
  VALUES (v_superadmin_id, 'Super Admin Officer', 'superadmin@trustvault.demo', 'super_admin', 'verified', 'approved')
  ON CONFLICT (id) DO UPDATE SET role = 'super_admin', account_status = 'verified', kyc_status = 'approved';

  -- Accounts
  IF NOT EXISTS (SELECT 1 FROM public.accounts WHERE profile_id = v_alice_id) THEN
    INSERT INTO public.accounts (profile_id, balance, currency, account_number)
    VALUES (v_alice_id, 0, 'NGN', '0000000001') ON CONFLICT DO NOTHING;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.accounts WHERE profile_id = v_bob_id) THEN
    INSERT INTO public.accounts (profile_id, balance, currency, account_number)
    VALUES (v_bob_id, 0, 'NGN', '0000000002') ON CONFLICT DO NOTHING;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.accounts WHERE profile_id = v_charlie_id) THEN
    INSERT INTO public.accounts (profile_id, balance, currency, account_number)
    VALUES (v_charlie_id, 0, 'NGN', '0000000003') ON CONFLICT DO NOTHING;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.accounts WHERE profile_id = v_admin_id) THEN
    INSERT INTO public.accounts (profile_id, balance, currency, account_number)
    VALUES (v_admin_id, 0, 'NGN', '0000000004') ON CONFLICT DO NOTHING;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.accounts WHERE profile_id = v_superadmin_id) THEN
    INSERT INTO public.accounts (profile_id, balance, currency, account_number)
    VALUES (v_superadmin_id, 0, 'NGN', '0000000005') ON CONFLICT DO NOTHING;
  END IF;

  -- Guarantee Platform Treasury liquidity
  PERFORM set_config('trustvault.allow_ledger_posting', 'true', true);
  UPDATE public.accounts
  SET balance = 1000000000.00
  WHERE is_system = TRUE AND label = 'Platform Treasury';

  -- Fund Alice ₦150,000 if 0 balance
  v_alice_acc := public.get_user_account_id(v_alice_id);
  v_treasury_id := public.get_treasury_account_id();

  IF v_alice_acc IS NOT NULL AND (SELECT balance FROM public.accounts WHERE id = v_alice_acc) = 0 THEN
    INSERT INTO public.transactions (type, from_account_id, to_account_id, amount, status, initiated_by, note)
    VALUES ('funding', v_treasury_id, v_alice_acc, 150000, 'completed', v_alice_id, 'Seed funding')
    RETURNING id INTO v_tx_id;

    PERFORM public.post_ledger_transaction(v_tx_id, v_treasury_id, v_alice_acc, 150000);
  END IF;

  RAISE NOTICE 'TrustVault database setup and pre-confirmed auth accounts created successfully.';
END $$;
