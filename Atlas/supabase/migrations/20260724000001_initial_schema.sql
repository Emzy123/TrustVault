-- Atlas Phase 1: Core schema (Section 7)

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------

CREATE TYPE public.user_role AS ENUM ('user', 'admin', 'super_admin');
CREATE TYPE public.account_status AS ENUM ('unverified', 'verified', 'active', 'frozen');
CREATE TYPE public.kyc_status AS ENUM ('not_submitted', 'pending', 'approved', 'declined');
CREATE TYPE public.kyc_submission_status AS ENUM ('pending', 'approved', 'declined');
CREATE TYPE public.transaction_type AS ENUM ('transfer', 'deposit', 'withdrawal', 'funding');
CREATE TYPE public.transaction_status AS ENUM ('pending', 'completed', 'declined', 'flagged', 'reversed');
CREATE TYPE public.ledger_entry_type AS ENUM ('debit', 'credit');
CREATE TYPE public.funding_request_status AS ENUM ('pending', 'approved', 'declined');
CREATE TYPE public.flag_status AS ENUM ('open', 'resolved', 'dismissed');

-- ---------------------------------------------------------------------------
-- Sequences
-- ---------------------------------------------------------------------------

CREATE SEQUENCE public.account_number_seq START 1000000001;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  phone TEXT,
  role public.user_role NOT NULL DEFAULT 'user',
  account_status public.account_status NOT NULL DEFAULT 'unverified',
  kyc_status public.kyc_status NOT NULL DEFAULT 'not_submitted',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.kyc_submissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  id_type TEXT NOT NULL,
  id_number TEXT NOT NULL,
  dob DATE NOT NULL,
  address TEXT NOT NULL,
  document_url TEXT,
  status public.kyc_submission_status NOT NULL DEFAULT 'pending',
  decline_reason TEXT,
  reviewed_by UUID REFERENCES public.profiles (id),
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID UNIQUE REFERENCES public.profiles (id) ON DELETE CASCADE,
  is_system BOOLEAN NOT NULL DEFAULT FALSE,
  label TEXT,
  balance NUMERIC(18, 2) NOT NULL DEFAULT 0 CHECK (balance >= 0),
  currency TEXT NOT NULL DEFAULT 'NGN',
  account_number TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT accounts_owner_check CHECK (
    (is_system = TRUE AND profile_id IS NULL) OR
    (is_system = FALSE AND profile_id IS NOT NULL)
  )
);

CREATE TABLE public.transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type public.transaction_type NOT NULL,
  from_account_id UUID REFERENCES public.accounts (id),
  to_account_id UUID REFERENCES public.accounts (id),
  amount NUMERIC(18, 2) NOT NULL CHECK (amount > 0),
  status public.transaction_status NOT NULL DEFAULT 'pending',
  decline_reason TEXT,
  note TEXT,
  initiated_by UUID NOT NULL REFERENCES public.profiles (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.ledger_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id UUID NOT NULL REFERENCES public.accounts (id),
  transaction_id UUID NOT NULL REFERENCES public.transactions (id),
  entry_type public.ledger_entry_type NOT NULL,
  amount NUMERIC(18, 2) NOT NULL CHECK (amount > 0),
  balance_after NUMERIC(18, 2) NOT NULL CHECK (balance_after >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.funding_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  amount NUMERIC(18, 2) NOT NULL CHECK (amount > 0),
  status public.funding_request_status NOT NULL DEFAULT 'pending',
  note TEXT,
  decline_reason TEXT,
  reviewed_by UUID REFERENCES public.profiles (id),
  reviewed_at TIMESTAMPTZ,
  transaction_id UUID REFERENCES public.transactions (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.flags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id UUID NOT NULL REFERENCES public.transactions (id),
  raised_by UUID NOT NULL REFERENCES public.profiles (id),
  reason TEXT NOT NULL,
  status public.flag_status NOT NULL DEFAULT 'open',
  resolved_by UUID REFERENCES public.profiles (id),
  resolved_at TIMESTAMPTZ,
  resolution_note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID NOT NULL REFERENCES public.profiles (id),
  action TEXT NOT NULL,
  target_id UUID,
  metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------

CREATE INDEX idx_profiles_role ON public.profiles (role);
CREATE INDEX idx_profiles_account_status ON public.profiles (account_status);
CREATE INDEX idx_kyc_submissions_profile_id ON public.kyc_submissions (profile_id);
CREATE INDEX idx_kyc_submissions_status ON public.kyc_submissions (status);
CREATE INDEX idx_accounts_profile_id ON public.accounts (profile_id);
CREATE INDEX idx_ledger_entries_account_id ON public.ledger_entries (account_id);
CREATE INDEX idx_ledger_entries_transaction_id ON public.ledger_entries (transaction_id);
CREATE INDEX idx_transactions_initiated_by ON public.transactions (initiated_by);
CREATE INDEX idx_transactions_status ON public.transactions (status);
CREATE INDEX idx_funding_requests_profile_id ON public.funding_requests (profile_id);
CREATE INDEX idx_funding_requests_status ON public.funding_requests (status);
CREATE INDEX idx_flags_status ON public.flags (status);
CREATE INDEX idx_audit_logs_actor_id ON public.audit_logs (actor_id);
CREATE INDEX idx_audit_logs_created_at ON public.audit_logs (created_at DESC);

-- ---------------------------------------------------------------------------
-- Platform treasury (contra account for funding/deposits)
-- ---------------------------------------------------------------------------

INSERT INTO public.accounts (is_system, label, balance, currency, account_number)
VALUES (TRUE, 'Platform Treasury', 1000000000, 'NGN', '0000000000');
