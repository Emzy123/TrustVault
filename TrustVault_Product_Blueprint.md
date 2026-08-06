# TrustVault — Fintech Wallet Platform
### Product & Technical Blueprint
**Prepared for Quantro Software Labs**
Version 1.0 — July 2026

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Product Overview](#2-product-overview)
3. [User Roles & Permissions](#3-user-roles--permissions)
4. [Onboarding & KYC Flow](#4-onboarding--kyc-flow)
5. [Funding Flow](#5-funding-flow-zero-balance--admin-approved-funding)
6. [Core Transaction Flows](#6-core-transaction-flows)
7. [Data Model (Supabase / PostgreSQL)](#7-data-model-supabase--postgresql)
8. [Screen Inventory](#8-screen-inventory)
9. [UI/UX Design](#9-uiux-design)
10. [Technical Architecture & Stack](#10-technical-architecture--stack)
11. [Development Phases & Sprints](#11-development-phases--sprints)
12. [Open Items for Next Session](#12-open-items-for-next-session)

---

## 1. Executive Summary

TrustVault is a simulated fintech wallet platform designed as a portfolio-grade demonstration of a real-world money-movement product. Users hold a wallet, transfer funds to other users, deposit, and withdraw — all backed by a simulated ledger rather than a live payment processor. The platform is built as a single Flutter Web codebase serving three role-based experiences: the User app, the Admin dashboard, and the Super Admin dashboard.

The goal of this phase is to produce a complete, professional blueprint before any code is written. This document defines scope, roles, data model, user flows, brand direction, and the build plan for the first working version.

### 1.1 Project Snapshot

| Item | Decision |
|---|---|
| Product name | TrustVault |
| Purpose | Portfolio / client demo piece |
| Platform | Flutter Web (single codebase, role-based routing) |
| Backend | Supabase (PostgreSQL, Auth, Row-Level Security) |
| Hosting | Vercel |
| Money movement | Simulated internal ledger — no real payment rails |
| Target timeline | First working demo within one week |

---

## 2. Product Overview

TrustVault consists of three role-based experiences sharing one codebase and one database:

- **User** — the wallet holder. Registers, completes KYC, requests funding, transfers, withdraws, and views history.
- **Admin** — monitors users and transactions, approves funding requests, and flags suspicious activity for escalation.
- **Super Admin** — has full oversight: resolves flags, approves or declines withdrawals, freezes accounts, manages admins, and reviews the audit log.

Because no real money moves, the product's credibility rests entirely on how realistic and well-designed the simulated flows are — believable states, honest messaging, and a data model that mirrors how a real ledger works.

### 2.1 Design Principle: Honesty in Simulated Flows

One explicit product principle for TrustVault: every status a user sees must be genuine, even though the underlying money is simulated. Pending, approved, and declined states always reflect what is actually happening in the system and, where a request is declined, the real reason is shown. This is both an ethical requirement and, practically, what makes the platform look like it was built by a team that understands financial compliance — which is exactly the impression a client review should leave.

---

## 3. User Roles & Permissions

| Capability | User | Admin | Super Admin |
|---|---|---|---|
| View own wallet & history | Yes | — | — |
| View all users & transactions | No | Yes | Yes |
| Request funding (post-KYC) | Yes | — | — |
| Approve funding requests | No | Yes | Yes |
| Flag suspicious activity | No | Yes | Yes |
| Freeze / unfreeze a user account | No | No | Yes |
| Approve / decline withdrawal requests | No | No | Yes |
| Resolve flags raised by Admins | No | No | Yes |
| Manage Admin accounts | No | No | Yes |
| View full audit log | No | Partial (own actions) | Yes (system-wide) |

**Design rationale:** Admin can flag but not act unilaterally on funds — this creates a two-person, separation-of-duties control that mirrors real fintech operational risk practice, and gives the demo a believable escalation story to walk a client through.

---

## 4. Onboarding & KYC Flow

New users register with a zero balance. No funding, transfer, or withdrawal action is available until identity verification is complete. This models real regulatory practice (KYC-before-funds) without requiring an actual verification provider.

### 4.1 Registration & Verification Steps

1. **Sign up** — email, password, full name, phone number.
2. **KYC submission** — mock identity form: ID type/number field, date of birth, address. Optional: simulated document upload (image file, stored but not actually verified by a third party for this demo).
3. **Verification status** — account enters "Pending Verification." For the demo, this can auto-approve after a short delay, or require Admin/Super Admin manual approval — recommended, since it gives Admins a real queue to demonstrate.
4. **Verified** — wallet activates at a ₦0.00 balance. The user can now request funding, but still cannot transfer or withdraw until a funding request is approved.

### 4.2 Account States

| State | Meaning | What the user can do |
|---|---|---|
| Unverified | Registered, KYC not yet submitted or under review | Nothing beyond viewing onboarding status |
| Verified | KYC approved, zero balance | Request funding |
| Active | Verified and has a positive balance | Transfer, deposit, withdraw, view history |
| Frozen | Suspended by Super Admin | View-only; all actions blocked |

---

## 5. Funding Flow (Zero-Balance → Admin-Approved Funding)

Because TrustVault has no real payment processor, initial and ongoing funding is modeled as an Admin-approved request rather than a card/bank deposit. This keeps the demo self-contained while still exercising a realistic approval workflow.

### 5.1 Flow Steps

1. Verified user submits a funding request: amount + optional note.
2. Request appears in the Admin dashboard queue as "Pending."
3. Admin approves or declines. Approval credits the user's simulated wallet via a ledger entry; decline requires a reason, shown to the user.
4. User sees real-time status: Pending → Approved (balance updates) or Declined (reason shown).

This same underlying mechanism (request → review → ledger entry) is reused later for the deposit feature, so the codebase only needs one approval pipeline, not several.

---

## 6. Core Transaction Flows

### 6.1 Transfer

- User selects a recipient (by account number/email), enters amount, confirms.
- System checks sufficient balance and any transfer limits, then posts a debit to the sender and a credit to the recipient as a single atomic ledger transaction.
- Status shows "Completed" immediately for transfers between two active accounts (no review needed — this mirrors real instant peer transfers).

### 6.2 Deposit

- Modeled the same way as the funding request in Section 5: user submits a deposit request, Admin approves, ledger is credited.
- Optionally, deposits under a small threshold can auto-approve to simulate "instant" deposits, while larger deposits route to manual review — useful for demonstrating both instant and reviewed paths.

### 6.3 Withdrawal — Honest Review Flow

> This flow was deliberately redesigned during planning. An earlier version of this flow always displayed a fabricated "system error" message regardless of the actual request, directing users to contact an admin. That pattern was rejected: it mirrors a well-known scam mechanic used in fraudulent investment and wallet platforms, where withdrawals are always blocked with a fake technical excuse to stall users indefinitely while deposits continue to be solicited. TrustVault's withdrawal flow instead uses a transparent, genuinely stateful review process:

1. User clicks Withdraw, enters amount → request enters **Pending Review** (a real, visible status, not a fake error).
2. Request appears in the Super Admin queue with the real context: account status, KYC status, amount vs. daily/available limits.
3. Super Admin approves or declines with a genuine reason selected from a defined list, e.g. "Awaiting further verification," "Above daily limit," "Approved."
4. User is notified by email and in-app with the actual outcome. An approved withdrawal debits the ledger and marks the transaction Completed; a decline shows the real reason and next steps.

This preserves the operational complexity and admin-in-the-loop mechanic originally requested — a request queue, an email trigger, a human decision point — while keeping every status genuine. It also reads as more sophisticated to a technical reviewer, since real fintech platforms are specifically audited for this kind of transparency around fund availability.

---

## 7. Data Model (Supabase / PostgreSQL)

The ledger is modeled as double-entry: every transaction produces two ledger rows (a debit and a credit) rather than mutating a balance field directly. This keeps balances always derivable, auditable, and resistant to race conditions — the detail that most separates a credible fintech demo from a toy CRUD app.

### 7.1 Core Tables

| Table | Key Columns | Purpose |
|---|---|---|
| `profiles` | id, full_name, email, role, account_status, kyc_status, created_at | One row per person; role ∈ {user, admin, super_admin}; account_status ∈ {unverified, verified, active, frozen} |
| `kyc_submissions` | id, profile_id, id_type, id_number, dob, address, status, reviewed_by, reviewed_at | Mock identity verification record and its review trail |
| `accounts` | id, profile_id, balance (cached), currency, account_number | Wallet shell; balance is derived from ledger_entries and cached for fast reads |
| `ledger_entries` | id, account_id, transaction_id, entry_type (debit/credit), amount, balance_after, created_at | Immutable double-entry rows; source of truth for balances |
| `transactions` | id, type (transfer/deposit/withdrawal/funding), from_account_id, to_account_id, amount, status, decline_reason, initiated_by, created_at | One row per user-facing action; status ∈ {pending, completed, declined, flagged, reversed} |
| `funding_requests` | id, profile_id, amount, status, reviewed_by, reviewed_at, note | Admin-approved funding queue described in Section 5 |
| `flags` | id, transaction_id, raised_by, reason, status, resolved_by, resolved_at | Admin-raised flags awaiting Super Admin resolution |
| `audit_logs` | id, actor_id, action, target_id, metadata (jsonb), created_at | Full system-wide activity trail for Super Admin review |

### 7.2 Row-Level Security Approach

- Users: can select/insert only rows where profile_id / account_id matches their own `auth.uid()`.
- Admins: can select across profiles, accounts, transactions, and funding_requests; can update funding_requests and flags; cannot update accounts.balance directly or approve withdrawals.
- Super Admins: full select/update access across all tables, including profiles.account_status (freeze/unfreeze) and transactions.status for withdrawals.
- All balance changes happen only through a Postgres function that writes matching debit/credit ledger_entries inside a single transaction — no table allows a direct balance update from the client.

---

## 8. Screen Inventory

### 8.1 User

- Sign up / Log in
- Onboarding & KYC form
- Verification pending / status screen
- Dashboard (balance, recent activity, quick actions)
- Request Funding
- Transfer
- Withdraw (+ Pending Review state)
- Transaction history & detail
- Profile / settings

### 8.2 Admin

- Dashboard (key metrics: users, pending requests, flags)
- User list & search, incl. KYC review queue
- Funding request queue (approve/decline)
- Transaction monitor
- Raise a flag on a transaction/user

### 8.3 Super Admin

Everything in Admin, plus:

- Withdrawal review queue (approve/decline with reason)
- Flag resolution queue
- Freeze / unfreeze account control
- Admin management (create/suspend admin accounts)
- Full audit log
- Platform analytics (volumes, active users, flag rate)

---

## 9. UI/UX Design

This section defines how TrustVault should look, feel, and behave before any screen is built — covering brand direction, navigation structure per role, key screen layouts, and the interaction states that make a demo feel like a finished product rather than a prototype.

### 9.1 Design Principles

- **Trustworthy over trendy** — every layout choice should reinforce reliability and clarity, since this is a money product.
- **Honesty in every state** — statuses, errors, and delays shown to the user must always reflect what is genuinely happening (see Section 6.3).
- **Progressive disclosure** — show the user only what they need at each step (e.g. don't show Transfer/Withdraw before KYC is verified; grey out or hide, don't just error).
- **Consistency across roles** — User, Admin, and Super Admin share one design system so the product feels like a single platform, not three bolted-together apps.

### 9.2 Brand & Visual Identity

Direction: trustworthy corporate — navy and blue, clean, minimal clutter, generous white space. This tone signals institutional reliability, which matters more than novelty for a fintech portfolio piece.

| Token | Value | Usage |
|---|---|---|
| Primary — Navy | `#1B2A4A` | Headers, primary buttons, nav |
| Secondary — Blue | `#2F5C9E` | Links, secondary actions, active states |
| Accent — Gold | `#B8860B` | "Send / Confirm" call-to-action, success highlights |
| Neutral — Light Grey | `#F3F4F6` | Backgrounds, card surfaces |
| Text — Grey | `#6B7280` | Secondary/muted text |

Typography: a clean geometric sans (e.g. Inter or Manrope), with clear weight contrast between headings and body text. Base UI text at 14–16px, headings scaling up with a consistent type ramp.

### 9.3 Navigation Structure by Role

| Role | Navigation Pattern | Primary Landing |
|---|---|---|
| User | Top bar (balance + profile) + bottom/side tab bar: Dashboard, Transfer, History, Profile | Dashboard — balance + recent activity |
| Admin | Persistent left sidebar: Dashboard, Users/KYC, Funding Queue, Transactions, Flags | Dashboard — pending counts across all queues |
| Super Admin | Left sidebar (Admin's items) + Withdrawals, Admins, Audit Log, Analytics | Dashboard — system-wide metrics + urgent queue counts |

Admin and Super Admin share the same sidebar shell, with Super-Admin-only items visually distinguished (e.g. a subtle section divider) so the interface reads as one coherent oversight tool rather than a re-skinned copy.

### 9.4 Key Screen Notes

**Dashboard (User)**
- Balance shown large and prominent at top, with account status badge (Verified / Frozen etc.) next to it.
- Primary actions (Transfer, Request Funding, Withdraw) as clearly labelled buttons, disabled with an explanatory tooltip if the account isn't yet eligible (e.g. "Complete verification to unlock transfers").
- Recent activity as a short list (last 5) with a link into full History.

**Transfer**
- Single-page form: recipient lookup, amount, optional note, then a confirmation step before submission — never submit on first tap for a money-movement action.
- Confirmation screen restates recipient, amount, and resulting balance before the user commits.

**Withdrawal (Pending Review)**
- After submission, the status screen should visually read as "in progress," not as an error — a neutral/blue "Pending Review" badge, not red, with a short honest explanation and an estimated review note.
- Transaction history row for this item updates live (via Supabase realtime) when Super Admin resolves it, without the user needing to refresh.

**Admin / Super Admin Queues**
- Funding, flag, and withdrawal queues use a consistent table pattern: requester, amount, date, status, and an action column.
- Every approve/decline action opens a confirmation step requiring a reason where relevant — this becomes the audit log entry, so the UI and the data model reinforce each other.

### 9.5 Interaction States

Each core screen needs four states designed, not just the "happy path" — this is what separates a portfolio-tier build from a tutorial-tier one:

- **Loading** — skeleton placeholders for balances/lists rather than a blank screen or spinner-only.
- **Empty** — a friendly, on-brand message for "no transactions yet" / "no pending requests," not a bare blank table.
- **Error** — specific, honest messaging (e.g. "Transfer failed — insufficient balance"), never a generic "something went wrong."
- **Success / Confirmation** — a clear confirmation moment (toast or screen) after transfers, approvals, and status changes.

### 9.6 Responsive Behaviour & Accessibility

- User experience: designed mobile-first within Flutter Web, since users may open it on a phone browser; layout should collapse gracefully to a single column below ~600px width.
- Admin / Super Admin: designed desktop-first (sidebar + data tables), since oversight work happens at a desk; should remain usable, not necessarily optimal, on tablet width.
- Minimum tap target size 44x44px on interactive elements; text contrast ratios meeting WCAG AA against the navy/white palette; all form fields carry visible labels, not placeholder-only text.

---

## 10. Technical Architecture & Stack

| Layer | Choice | Notes |
|---|---|---|
| Client | Flutter Web | Single codebase; role-based routing (/app, /admin, /superadmin); mobile can reuse this codebase later |
| Backend | Supabase | Postgres + Auth + Row-Level Security + realtime subscriptions for live status updates |
| Database | PostgreSQL (via Supabase) | Relational integrity for the double-entry ledger; not feasible in a document store |
| Hosting | Vercel | Static Flutter Web build deployment |
| Email | Supabase Auth emails or a transactional provider (e.g. Resend) | Used for verification, funding, and withdrawal status notifications |

**Route structure:**

- `/` — login / landing
- `/app/*` — User experience
- `/admin/*` — Admin dashboard
- `/superadmin/*` — Super Admin dashboard

Each area is gated by Supabase Auth plus a role check; a user attempting to reach an area outside their role is redirected to their own.

---

## 11. Development Phases & Sprints

The build is organized into four phases, each containing one sprint, run back-to-back across the one-week fast-demo track. Each sprint ends with a working, demoable increment rather than half-finished pieces across every layer at once.

### Phase 1 — Foundation
**Sprint 1 (Day 1–2): Architecture & Scaffolding**

- Supabase project setup: schema (Section 7) and Row-Level Security policies for all three roles.
- Postgres function for atomic double-entry ledger postings.
- Flutter Web project scaffold: routing shell (/app, /admin, /superadmin), Supabase Auth wired in, role-based redirect guards.
- Design tokens implemented (colors, type ramp) from Section 9.2, so every subsequent screen is built on the real system, not placeholders.

**Security — Phase 1**
- Row-Level Security policies written and tested for every table before any screen consumes them — verified by attempting cross-role reads/writes directly against Supabase, not just through the UI.
- Supabase service-role key kept server-side only (never shipped in the Flutter Web bundle); client uses the anon key with RLS as the actual access boundary.
- HTTPS enforced end-to-end (Vercel default); auth session tokens handled via Supabase's secure client storage, not manually persisted.
- Secrets and API keys managed via environment variables, excluded from version control from day one.

*Sprint 1 exit criteria: a user can sign up, log in, and land on a role-correct empty dashboard shell.*

### Phase 2 — User Experience
**Sprint 2 (Day 3–4): Core User Flows**

- Onboarding & KYC submission flow; account state transitions (Unverified → Verified → Active).
- Dashboard, Funding Request flow, Transfer flow (with confirmation step).
- Withdrawal request + honest Pending Review flow (Section 6.3); transaction history and detail views.
- Loading, empty, and error states applied to every screen built this sprint (Section 9.5), not deferred.

**Security — Phase 2**
- All balance-affecting actions (transfer, funding, withdrawal) re-validated server-side (Postgres function) regardless of what the client already checked — client-side validation is UX only, never the actual control.
- Input validation and sanitization on every form field, particularly KYC data and transfer recipient lookups, to prevent injection via free-text fields.
- KYC submissions treated as sensitive personal data: access restricted via RLS to the owning user and Admin/Super Admin roles only, never publicly readable.
- Basic rate limiting on sensitive actions (login attempts, withdrawal/transfer submissions) to prevent brute-force or rapid-fire abuse, even in a simulated environment.

*Sprint 2 exit criteria: a verified demo user can request funding, transfer, and submit a withdrawal end-to-end, with believable seed data in place.*

### Phase 3 — Admin & Oversight
**Sprint 3 (Day 5–6): Admin & Super Admin Dashboards**

- Admin: dashboard, user list & KYC review queue, funding approval queue, transaction monitor, flag raising.
- Super Admin: withdrawal review queue, flag resolution, freeze/unfreeze control, admin management, audit log, platform analytics.
- Realtime status propagation from Admin/Super Admin actions back to the User app (Supabase realtime subscriptions).

**Security — Phase 3**
- Every Admin/Super Admin privileged action (approve, decline, freeze, resolve flag) enforced server-side via RLS/role checks — hiding a button in the UI is never treated as access control.
- Every privileged action writes an immutable audit_logs row with actor, action, target, and timestamp — no admin action should be possible without a corresponding trail.
- Admin account creation restricted to Super Admin only; no self-registration path exists for the admin or super_admin roles.
- High-risk actions (freeze account, approve withdrawal, resolve flag) require the acting admin's session to be currently valid and re-checked at the moment of the action, not cached from login.

*Sprint 3 exit criteria: the full escalation story works — Admin flags or queues a request, Super Admin resolves it, and the User sees the honest outcome without refreshing.*

### Phase 4 — Polish & Demo Readiness
**Sprint 4 (Day 7): Final Pass**

- Full visual polish pass across all three role experiences against the design system; responsive check per Section 9.6.
- Final review of every interaction state (loading/empty/error/success) across all screens.
- Seed data review for a coherent demo narrative; deployment to Vercel.
- Demo script: a defined click-through path for the client walkthrough, covering all three roles in one continuous story.

**Security — Phase 4**
- Full RLS coverage review: confirm every table denies access outside its intended role, including direct API calls that bypass the UI entirely.
- Confirm no client-side path can mutate accounts.balance directly — all balance changes trace back to the ledger-posting function.
- Adversarial click-through pass: attempt to reach /admin or /superadmin routes as a plain user, attempt to view another user's data, confirm every attempt is blocked.
- Dependency and secrets check before deployment — no exposed keys in the deployed bundle, no debug/test routes left reachable in production.

*Sprint 4 exit criteria: TrustVault is deployed on Vercel and demo-ready with a rehearsed walkthrough script.*

---

## 12. Open Items for Next Session

- Confirm whether KYC approval is manual (Admin queue) or auto-approved after a delay for demo speed.
- Confirm transfer/withdrawal limit values (daily cap, minimum amount) to seed into the system.
- Confirm the deposit auto-approve threshold, if any.
- Logo direction for TrustVault (wordmark only vs. wordmark + mark).
- Whether seed data should represent a specific demo narrative (e.g. a small business, a group of individuals) for the client walkthrough.

**Next step once this blueprint is approved:** Supabase schema + RLS implementation, followed by the Flutter Web project scaffold.
