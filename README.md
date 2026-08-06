# TrustVault

Simulated fintech wallet platform — Flutter Web + Supabase.

## Phase 1 (Foundation)

This phase delivers:

- **Supabase schema** — profiles, accounts, ledger, transactions, funding requests, flags, audit logs
- **Row-Level Security** — policies for `user`, `admin`, and `super_admin` roles
- **`post_ledger_transaction`** — atomic double-entry ledger postings (balance changes never from the client)
- **Flutter Web scaffold** — auth, role-based routing (`/app`, `/admin`, `/superadmin`), design tokens

## Phase 2 (User Experience)

- KYC submission and pending/declined status screens
- Funding request flow (server-validated RPC)
- Transfer with confirmation step (server-validated RPC)
- Withdrawal with honest Pending Review state
- Transaction history and detail views
- Loading, empty, and error states on all new screens

**Exit criteria:** a verified demo user can request funding, transfer, and submit a withdrawal end-to-end.

### Demo accounts (optional)

Sign up `alice@trustvault.demo` and `bob@trustvault.demo`, then run `supabase db reset` or apply `supabase/seed.sql` to pre-approve KYC and fund Alice with ₦50,000.

## Project structure

```
TrustVault/
├── app/                    # Flutter Web client
├── supabase/
│   ├── migrations/         # PostgreSQL schema, RLS, functions
│   ├── config.toml
│   └── seed.sql            # Admin promotion notes
└── TrustVault_Product_Blueprint.md
```

## Prerequisites

- [Flutter](https://flutter.dev) (Web enabled)
- [Docker](https://www.docker.com/) (for local Supabase)
- [Supabase CLI](https://supabase.com/docs/guides/cli) (optional but recommended)

## Local Supabase

```bash
# From repo root — requires Docker
supabase start
supabase db reset   # applies migrations + seed

# Copy the anon key from `supabase status`
supabase status
```

## Run the Flutter app

```bash
cd app
flutter pub get

flutter run -d chrome \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_ANON_KEY=<your-local-anon-key>
```

## Creating admin users

1. Sign up a normal user via the app (or create in Supabase Auth dashboard).
2. Promote via SQL (see `supabase/seed.sql`):

```sql
UPDATE public.profiles SET role = 'admin' WHERE email = 'admin@example.com';
UPDATE public.profiles SET role = 'super_admin' WHERE email = 'superadmin@example.com';
```

3. Sign in — the router redirects to `/admin` or `/superadmin` based on role.

## Security notes (Phase 1)

- Only the **anon key** is used in the Flutter client; service role stays server-side.
- `accounts.balance` has no client UPDATE policy — all balance changes go through `post_ledger_transaction`.
- RLS policies should be verified with direct Supabase API calls across roles before Phase 2 screens consume them.

## Routes

| Path | Role | Purpose |
|------|------|---------|
| `/` | Public | Login |
| `/signup` | Public | Registration |
| `/app` | User | Wallet dashboard shell |
| `/admin` | Admin | Admin dashboard shell |
| `/superadmin` | Super Admin | Super Admin dashboard shell |

## Next: Phase 2

KYC flow, funding, transfers, withdrawals, and transaction history.
