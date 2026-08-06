-- TrustVault Phase 4: Production Demo Narrative Seed Script
-- Demo auth users are created in seed_auth.sql; this adds ledger data and queues.

DO $$
DECLARE
  v_alice_id UUID;
  v_bob_id UUID;
  v_charlie_id UUID;
  v_admin_id UUID;
  v_superadmin_id UUID;
  v_alice_acc UUID;
  v_bob_acc UUID;
  v_treasury_id UUID;
  v_tx1_id UUID;
  v_tx2_id UUID;
BEGIN
  v_treasury_id := public.get_treasury_account_id();

  SELECT id INTO v_alice_id FROM public.profiles WHERE email = 'alice@trustvault.demo';
  SELECT id INTO v_bob_id FROM public.profiles WHERE email = 'bob@trustvault.demo';
  SELECT id INTO v_charlie_id FROM public.profiles WHERE email = 'charlie@trustvault.demo';
  SELECT id INTO v_admin_id FROM public.profiles WHERE email = 'admin@trustvault.demo';
  SELECT id INTO v_superadmin_id FROM public.profiles WHERE email = 'superadmin@trustvault.demo';

  IF v_admin_id IS NOT NULL THEN
    UPDATE public.profiles SET role = 'admin' WHERE id = v_admin_id;
  END IF;

  IF v_superadmin_id IS NOT NULL THEN
    UPDATE public.profiles SET role = 'super_admin' WHERE id = v_superadmin_id;
  END IF;

  IF v_alice_id IS NOT NULL THEN
    UPDATE public.profiles
    SET kyc_status = 'approved', account_status = 'active'
    WHERE id = v_alice_id;

    IF NOT EXISTS (SELECT 1 FROM public.kyc_submissions WHERE profile_id = v_alice_id) THEN
      INSERT INTO public.kyc_submissions (profile_id, id_type, id_number, dob, address, status, reviewed_at)
      VALUES (v_alice_id, 'National ID', 'NIN-987654321', '1992-04-12', '14 Marina Road, Victoria Island, Lagos', 'approved', NOW());
    END IF;

    v_alice_acc := public.get_user_account_id(v_alice_id);

    IF (SELECT balance FROM public.accounts WHERE id = v_alice_acc) = 0 THEN
      INSERT INTO public.transactions (type, from_account_id, to_account_id, amount, status, initiated_by, note)
      VALUES ('funding', v_treasury_id, v_alice_acc, 150000, 'completed', v_alice_id, 'Initial seed funding')
      RETURNING id INTO v_tx1_id;

      PERFORM public.post_ledger_transaction(v_tx1_id, v_treasury_id, v_alice_acc, 150000);
    END IF;
  END IF;

  IF v_bob_id IS NOT NULL THEN
    UPDATE public.profiles
    SET kyc_status = 'approved', account_status = 'verified'
    WHERE id = v_bob_id;

    IF NOT EXISTS (SELECT 1 FROM public.kyc_submissions WHERE profile_id = v_bob_id) THEN
      INSERT INTO public.kyc_submissions (profile_id, id_type, id_number, dob, address, status, reviewed_at)
      VALUES (v_bob_id, 'Passport', 'A09876543', '1988-11-23', '22 Gana Street, Maitama, Abuja', 'approved', NOW());
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.funding_requests WHERE profile_id = v_bob_id AND status = 'pending') THEN
      INSERT INTO public.funding_requests (profile_id, amount, note, status)
      VALUES (v_bob_id, 250000, 'Initial business wallet liquidity request', 'pending');
    END IF;
  END IF;

  IF v_charlie_id IS NOT NULL THEN
    UPDATE public.profiles
    SET kyc_status = 'not_submitted', account_status = 'unverified'
    WHERE id = v_charlie_id;
  END IF;

  IF v_alice_id IS NOT NULL AND v_alice_acc IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM public.transactions WHERE from_account_id = v_alice_acc AND type = 'withdrawal' AND status = 'pending') THEN
      INSERT INTO public.transactions (type, from_account_id, to_account_id, amount, status, initiated_by, note)
      VALUES ('withdrawal', v_alice_acc, v_treasury_id, 20000, 'pending', v_alice_id, 'Demo withdrawal request')
      RETURNING id INTO v_tx2_id;
    END IF;

    IF v_tx1_id IS NULL THEN
      SELECT id INTO v_tx1_id
      FROM public.transactions
      WHERE to_account_id = v_alice_acc AND type = 'funding' AND status = 'completed'
      ORDER BY created_at DESC
      LIMIT 1;
    END IF;

    IF v_tx1_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.flags WHERE transaction_id = v_tx1_id) THEN
      INSERT INTO public.flags (transaction_id, raised_by, reason, status)
      VALUES (v_tx1_id, COALESCE(v_admin_id, v_alice_id), 'High volume transfer requiring secondary compliance check', 'open');
    END IF;
  END IF;

  RAISE NOTICE 'TrustVault demo narrative seed successfully applied.';
END $$;
