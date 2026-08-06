-- TrustVault: Email notifications & registration OTP

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.registration_otps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  otp_hash TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  verified_at TIMESTAMPTZ,
  attempts INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_registration_otps_email
  ON public.registration_otps (LOWER(email), created_at DESC);

CREATE TABLE IF NOT EXISTS public.email_outbox (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_email TEXT NOT NULL,
  template_key TEXT NOT NULL,
  subject TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}'::JSONB,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'sent', 'failed')),
  error_message TEXT,
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_email_outbox_pending
  ON public.email_outbox (status, created_at)
  WHERE status = 'pending';

ALTER TABLE public.registration_otps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_outbox ENABLE ROW LEVEL SECURITY;

-- No direct client access to OTP or outbox tables
CREATE POLICY "No direct access to registration_otps"
  ON public.registration_otps FOR ALL
  TO authenticated, anon
  USING (FALSE);

CREATE POLICY "No direct access to email_outbox"
  ON public.email_outbox FOR ALL
  TO authenticated, anon
  USING (FALSE);

-- ---------------------------------------------------------------------------
-- Email queue helper
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.queue_email(
  p_recipient_email TEXT,
  p_template_key TEXT,
  p_subject TEXT,
  p_payload JSONB DEFAULT '{}'::JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
  v_email TEXT;
BEGIN
  v_email := LOWER(TRIM(p_recipient_email));
  IF v_email IS NULL OR v_email !~ '^[^@]+@[^@]+\.[^@]+$' THEN
    RAISE EXCEPTION 'Valid recipient email is required';
  END IF;

  INSERT INTO public.email_outbox (recipient_email, template_key, subject, payload)
  VALUES (v_email, p_template_key, p_subject, COALESCE(p_payload, '{}'::JSONB))
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.queue_email(TEXT, TEXT, TEXT, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.queue_email(TEXT, TEXT, TEXT, JSONB) TO authenticated, service_role;

-- Invoke edge function to deliver queued email (best-effort; outbox retains record)
CREATE OR REPLACE FUNCTION public.dispatch_email(p_outbox_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_url TEXT;
  v_service_key TEXT;
BEGIN
  v_url := current_setting('app.settings.supabase_url', TRUE);
  v_service_key := current_setting('app.settings.service_role_key', TRUE);

  IF v_url IS NULL OR v_service_key IS NULL THEN
    RETURN;
  END IF;

  PERFORM net.http_post(
    url := v_url || '/functions/v1/send-email',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_key
    ),
    body := jsonb_build_object('outbox_id', p_outbox_id)
  );
EXCEPTION WHEN OTHERS THEN
  NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.trigger_dispatch_email()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.dispatch_email(NEW.id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS email_outbox_dispatch ON public.email_outbox;
CREATE TRIGGER email_outbox_dispatch
  AFTER INSERT ON public.email_outbox
  FOR EACH ROW EXECUTE FUNCTION public.trigger_dispatch_email();

-- ---------------------------------------------------------------------------
-- Registration OTP
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.request_registration_otp(p_email TEXT)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_email TEXT;
  v_otp TEXT;
  v_otp_hash TEXT;
  v_outbox_id UUID;
BEGIN
  v_email := LOWER(TRIM(p_email));
  IF v_email IS NULL OR v_email !~ '^[^@]+@[^@]+\.[^@]+$' THEN
    RAISE EXCEPTION 'Valid email address is required';
  END IF;

  IF EXISTS (SELECT 1 FROM auth.users WHERE LOWER(email) = v_email) THEN
    RAISE EXCEPTION 'An account with this email already exists';
  END IF;

  -- Simple rate limit: max 3 OTP requests per email per 15 minutes
  IF (
    SELECT COUNT(*) FROM public.registration_otps
    WHERE LOWER(email) = v_email
      AND created_at >= NOW() - INTERVAL '15 minutes'
  ) >= 3 THEN
    RAISE EXCEPTION 'Too many verification codes requested. Please wait before trying again.';
  END IF;

  v_otp := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
  v_otp_hash := crypt(v_otp, gen_salt('bf'));

  INSERT INTO public.registration_otps (email, otp_hash, expires_at)
  VALUES (v_email, v_otp_hash, NOW() + INTERVAL '10 minutes');

  v_outbox_id := public.queue_email(
    v_email,
    'registration_otp',
    'Your TrustVault verification code',
    jsonb_build_object('otp', v_otp, 'expires_minutes', 10)
  );

  RETURN v_outbox_id;
END;
$$;

REVOKE ALL ON FUNCTION public.request_registration_otp(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.request_registration_otp(TEXT) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.complete_registration(
  p_email TEXT,
  p_otp TEXT,
  p_password TEXT,
  p_full_name TEXT,
  p_phone TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_email TEXT;
  v_otp_row public.registration_otps%ROWTYPE;
  v_user_id UUID;
  v_encrypted_pw TEXT;
  v_instance_id UUID;
  v_full_name TEXT;
  v_phone TEXT;
BEGIN
  v_email := LOWER(TRIM(p_email));
  v_full_name := TRIM(p_full_name);
  v_phone := TRIM(p_phone);

  IF v_email IS NULL OR v_email !~ '^[^@]+@[^@]+\.[^@]+$' THEN
    RAISE EXCEPTION 'Valid email address is required';
  END IF;

  IF p_otp IS NULL OR LENGTH(TRIM(p_otp)) <> 6 THEN
    RAISE EXCEPTION 'Enter the 6-digit verification code';
  END IF;

  IF p_password IS NULL OR LENGTH(p_password) < 8 THEN
    RAISE EXCEPTION 'Password must be at least 8 characters';
  END IF;

  IF v_full_name IS NULL OR LENGTH(v_full_name) < 2 THEN
    RAISE EXCEPTION 'Full name is required';
  END IF;

  IF v_phone IS NULL OR LENGTH(v_phone) < 6 THEN
    RAISE EXCEPTION 'Phone number is required';
  END IF;

  IF EXISTS (SELECT 1 FROM auth.users WHERE LOWER(email) = v_email) THEN
    RAISE EXCEPTION 'An account with this email already exists';
  END IF;

  SELECT * INTO v_otp_row
  FROM public.registration_otps
  WHERE LOWER(email) = v_email
    AND verified_at IS NULL
    AND expires_at > NOW()
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Verification code expired or not found. Request a new code.';
  END IF;

  IF v_otp_row.attempts >= 5 THEN
    RAISE EXCEPTION 'Too many failed attempts. Request a new verification code.';
  END IF;

  IF v_otp_row.otp_hash <> crypt(TRIM(p_otp), v_otp_row.otp_hash) THEN
    UPDATE public.registration_otps
    SET attempts = attempts + 1
    WHERE id = v_otp_row.id;
    RAISE EXCEPTION 'Invalid verification code';
  END IF;

  UPDATE public.registration_otps
  SET verified_at = NOW()
  WHERE id = v_otp_row.id;

  SELECT instance_id INTO v_instance_id FROM auth.users WHERE instance_id IS NOT NULL LIMIT 1;
  IF v_instance_id IS NULL THEN
    v_instance_id := '00000000-0000-0000-0000-000000000000'::UUID;
  END IF;

  v_user_id := gen_random_uuid();
  v_encrypted_pw := crypt(p_password, gen_salt('bf'));

  INSERT INTO auth.users (
    id, instance_id, email, encrypted_password, email_confirmed_at,
    confirmation_token, recovery_token, email_change_token_new, email_change,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
  )
  VALUES (
    v_user_id,
    v_instance_id,
    v_email,
    v_encrypted_pw,
    NOW(),
    '', '', '', '',
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object('full_name', v_full_name, 'phone', v_phone),
    NOW(), NOW(),
    'authenticated', 'authenticated'
  );

  PERFORM public.queue_email(
    v_email,
    'welcome',
    'Welcome to TrustVault — your account is ready',
    jsonb_build_object('full_name', v_full_name)
  );

  PERFORM public.queue_email(
    v_email,
    'kyc_prompt',
    'Complete identity verification to unlock your wallet',
    jsonb_build_object('full_name', v_full_name)
  );

  RETURN v_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.complete_registration(TEXT, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.complete_registration(TEXT, TEXT, TEXT, TEXT, TEXT) TO anon, authenticated;

-- ---------------------------------------------------------------------------
-- Post-registration emails for auth.signUp users (non-OTP path / demo accounts)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.send_post_signup_emails()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_full_name TEXT;
BEGIN
  IF NEW.email_confirmed_at IS NULL THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.email_confirmed_at IS NOT NULL THEN
    RETURN NEW;
  END IF;

  v_full_name := COALESCE(NEW.raw_user_meta_data ->> 'full_name', '');

  IF NOT EXISTS (
    SELECT 1 FROM public.email_outbox
    WHERE LOWER(recipient_email) = LOWER(NEW.email)
      AND template_key = 'welcome'
      AND created_at >= NOW() - INTERVAL '1 hour'
  ) THEN
    PERFORM public.queue_email(
      NEW.email,
      'welcome',
      'Welcome to TrustVault — your account is ready',
      jsonb_build_object('full_name', v_full_name)
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.email_outbox
    WHERE LOWER(recipient_email) = LOWER(NEW.email)
      AND template_key = 'kyc_prompt'
      AND created_at >= NOW() - INTERVAL '1 hour'
  ) THEN
    PERFORM public.queue_email(
      NEW.email,
      'kyc_prompt',
      'Complete identity verification to unlock your wallet',
      jsonb_build_object('full_name', v_full_name)
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_confirmed ON auth.users;
CREATE TRIGGER on_auth_user_confirmed
  AFTER INSERT OR UPDATE OF email_confirmed_at ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.send_post_signup_emails();

-- ---------------------------------------------------------------------------
-- Augment wallet RPCs with email notifications
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

  PERFORM public.queue_email(
    v_profile.email,
    'funding_submitted',
    'Funding request received — under review',
    jsonb_build_object(
      'full_name', v_profile.full_name,
      'amount', p_amount,
      'request_id', v_request_id
    )
  );

  RETURN v_request_id;
END;
$$;

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
  v_profile public.profiles%ROWTYPE;
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

  SELECT * INTO v_profile FROM public.profiles WHERE id = v_request.profile_id;

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

    PERFORM public.queue_email(
      v_profile.email,
      'funding_approved',
      'Your wallet has been funded successfully',
      jsonb_build_object(
        'full_name', v_profile.full_name,
        'amount', v_request.amount,
        'transaction_id', v_transaction_id
      )
    );
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

  RETURN v_transaction_id;
END;
$$;

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
  v_sender_account_number TEXT;
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
  SELECT account_number INTO v_sender_account_number
  FROM public.accounts WHERE id = v_sender_account_id;

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

  RETURN v_transaction_id;
END;
$$;

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

  -- LOCK account row to prevent concurrent overdraft race condition
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

  PERFORM public.queue_email(
    v_profile.email,
    'withdrawal_submitted',
    'Withdrawal request submitted — pending review',
    jsonb_build_object(
      'full_name', v_profile.full_name,
      'amount', p_amount,
      'transaction_id', v_transaction_id
    )
  );

  RETURN v_transaction_id;
END;
$$;

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
  v_profile public.profiles%ROWTYPE;
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

  SELECT * INTO v_profile FROM public.profiles WHERE id = v_profile_id;

  IF p_approve THEN
    PERFORM public.post_ledger_transaction(
      v_tx.id, v_tx.from_account_id, v_tx.to_account_id, v_tx.amount
    );

    UPDATE public.transactions
    SET status = 'completed', decline_reason = NULL, updated_at = NOW()
    WHERE id = p_transaction_id;

    PERFORM public.sync_account_status(v_profile_id);

    PERFORM public.queue_email(
      v_profile.email,
      'withdrawal_approved',
      'Your withdrawal has been processed',
      jsonb_build_object(
        'full_name', v_profile.full_name,
        'amount', v_tx.amount,
        'transaction_id', p_transaction_id
      )
    );
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

-- Mark outbox row sent/failed (called by edge function)
CREATE OR REPLACE FUNCTION public.mark_email_sent(
  p_outbox_id UUID,
  p_success BOOLEAN,
  p_error_message TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.email_outbox
  SET
    status = CASE WHEN p_success THEN 'sent' ELSE 'failed' END,
    error_message = p_error_message,
    sent_at = CASE WHEN p_success THEN NOW() ELSE sent_at END
  WHERE id = p_outbox_id;
END;
$$;

REVOKE ALL ON FUNCTION public.mark_email_sent(UUID, BOOLEAN, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mark_email_sent(UUID, BOOLEAN, TEXT) TO service_role;
