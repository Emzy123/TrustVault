# TrustVault — Client Demonstration Script & Walkthrough Guide

This document provides a step-by-step click-through narrative guide for presenting TrustVault to prospective clients or reviewers. It covers all three role-based experiences (**User**, **Admin**, **Super Admin**) in one continuous narrative.

---

## 🎬 Narrative Arc: "A Day in the Life of Money Movement & Oversight"

**The Narrative**:
1. **Charlie** registers as a new user with zero balance and undergoes KYC verification.
2. **Bob** requests wallet funding, which **Admin** reviews and approves.
3. **Alice** makes an instant peer-to-peer transfer to Bob, then requests a withdrawal.
4. **Super Admin** reviews Alice's withdrawal in the transparent review queue, resolves an escalated flag, inspects audit logs, and demonstrates account controls.

---

## 📋 Step-by-Step Walkthrough

### Act 1: User Onboarding & Identity Verification (KYC)
**Role**: User (`charlie@trustvault.demo`)

1. **Log in / Sign up**:
   - Navigate to `/` -> Click **Sign up**.
   - Register with `Full Name: Charlie Brown`, `Email: charlie@trustvault.demo`.
2. **Landing on Dashboard**:
   - Notice the prominent banner: **"Complete verification to unlock funding and wallet features."**
   - Notice that **Transfer** and **Withdraw** buttons are disabled with informative tooltips (*"Complete identity verification to unlock"*).
3. **Submit KYC Form**:
   - Click **Start verification** -> Navigates to `/app/kyc`.
   - Select ID type (`National ID`), enter ID number (`NIN-123456789`), pick DOB, enter address.
   - Click **Submit for review**.
   - Screen transitions to the **Pending Verification** state (`/app/kyc/pending`).

---

### Act 2: Admin Queue & Funding Approval
**Role**: Admin (`admin@trustvault.demo`)

1. **Log in as Admin**:
   - Log in with `admin@trustvault.demo` -> Automatically routed to `/admin`.
   - **Dashboard**: Observe key platform metrics (*Total Users, Pending KYC, Pending Funding, Open Flags, 24h Volume*).
2. **KYC Review Queue**:
   - Navigate to **KYC Review** (`/admin/kyc`).
   - Find Charlie Brown's pending submission.
   - Click **Approve** -> Toast confirms approval. Charlie's account status becomes `verified`.
3. **Funding Request Queue**:
   - Navigate to **Funding Queue** (`/admin/funding`).
   - Find Bob's pending funding request for **₦250,000**.
   - Click **Approve & Credit**.
   - *Technical highlight for client*: Emphasize that no arbitrary database mutation occurred — an atomic double-entry ledger entry was posted between the Platform Treasury and Bob's wallet.

---

### Act 3: Peer-to-Peer Transfer & Transparent Withdrawal
**Role**: User (`alice@trustvault.demo`)

1. **Active Wallet Dashboard**:
   - Log in as `alice@trustvault.demo` -> Routed to `/app`.
   - Observe active balance (**₦150,000**), account number (`0000000001`), and active status badge.
2. **Instant Peer Transfer**:
   - Click **Transfer** (`/app/transfer`).
   - Enter recipient email `bob@trustvault.demo`, amount `₦25,000`, note `"Consulting payment"`.
   - Click **Review transfer** -> Review confirmation screen showing recipient, amount, and resulting balance (₦125,000).
   - Click **Confirm & send** -> Transfer completes instantly!
3. **Withdrawal Request (Pending Review)**:
   - Click **Withdraw** (`/app/withdraw`).
   - Enter amount `₦20,000` -> Click **Submit for review**.
   - *Honesty-in-Flows highlight for client*: The screen shows a neutral blue **Pending Review** badge with honest messaging (*"Your request is being reviewed. A Super Admin will approve or decline with a real reason"*). It does NOT display a fabricated "system error".

---

### Act 4: Super Admin Governance & Flag Escalation
**Role**: Super Admin (`superadmin@trustvault.demo`)

1. **Log in as Super Admin**:
   - Log in with `superadmin@trustvault.demo` -> Routed to `/superadmin`.
   - Observe system-wide metrics (*Total volume, Frozen accounts count, Active admins count*).
2. **Withdrawal Review Queue**:
   - Navigate to **Withdrawals Review** (`/superadmin/withdrawals`).
   - Locate Alice's pending withdrawal of ₦20,000.
   - Click **Approve Withdrawal** -> Executes ledger debit and updates Alice's status in real-time.
   - *(Optional Demo)*: Click **Decline** -> Select reason *"Awaiting further identity verification"* -> Alice sees this exact reason on her transaction detail screen!
3. **Flag Resolution Queue**:
   - Navigate to **Flags Queue** (`/superadmin/flags`).
   - View open flag escalated by Admin.
   - Click **Resolve Flag** -> Enter resolution note *"Verified business relationship"* -> Click **Mark Resolved**.
4. **User Account Freeze Control**:
   - Navigate to **User Management** (`/superadmin/users`).
   - Search for a user -> Click **Freeze**.
   - Log in as that user -> Observe that all funding, transfer, and withdrawal features are immediately locked with a clear frozen status badge.
5. **System Audit Log**:
   - Navigate to **Audit Log** (`/superadmin/audit`).
   - Inspect the immutable system-wide activity log showing every actor, action, timestamp, and JSON metadata.

---

## 🎯 Key Client Takeaways

1. **Believable Financial Infrastructure**: Built on a double-entry ledger model, not superficial balance fields.
2. **Honesty in Interaction Design**: Genuine pending and decline states that build user trust.
3. **Institutional Separation of Duties**: Two-tier Admin & Super Admin escalation controls mirroring real compliance workflows.
4. **Security & Data Isolation**: End-to-end Row-Level Security policies protecting user privacy.
