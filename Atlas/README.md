# Atlas

Simulated fintech wallet platform — Flutter Web + Supabase.

Atlas is a **separate product** from TrustVault. It reuses the same feature set (user, admin, and super admin) with Atlas branding and UI.

## What’s included

- `app/` — Flutter Web client (package name: `atlas`)
- `supabase/` — schema, RLS, RPCs, and seed scripts for a **dedicated** Atlas Supabase project
- `design/` — sample UI references (logo + layout inspiration only)
- `scripts/` — hosting helpers

## Branding

- Product name: **Atlas**
- Logo: `app/assets/images/logo.png` (from `design/IMG-20260826-WA0001.jpg`)
- Palette: teal primary (`#0F5C5B`) + peach accent (`#F3C9B5`)

## Important

1. **Separate Supabase project** — do not point Atlas at the TrustVault project keys.
2. Design images under `design/` are references, not pixel-perfect specs.
3. Some UI icons from the samples (e.g. **Convert**) are shown in Atlas colors but intentionally do nothing; all TrustVault-equivalent flows remain functional.

## Run locally

```bash
# From Atlas/
cp .env.example .env   # fill with Atlas Supabase URL + anon key

cd app
flutter pub get

flutter run -d chrome \
  --dart-define=SUPABASE_URL=<atlas-supabase-url> \
  --dart-define=SUPABASE_ANON_KEY=<atlas-anon-key>
```

## Database

```bash
# From Atlas/
supabase link --project-ref <atlas-project-ref>
supabase db push
# optional: apply seed / patches as needed for your hosted project
```

If **Get code** on verify-email says “No active code found”, Vercel env is not enough — the Atlas Supabase project needs the OTP RPCs. Run `supabase/patch_registration_otp_get_code.sql` in the Supabase SQL Editor, then tap **Resend code** and **Get code** again.
## Roles

| Path | Role |
|------|------|
| `/app` | User |
| `/admin` | Admin |
| `/superadmin` | Super Admin |

Promote admins in SQL on the Atlas project:

```sql
UPDATE public.profiles SET role = 'admin' WHERE email = 'admin@example.com';
UPDATE public.profiles SET role = 'super_admin' WHERE email = 'superadmin@example.com';
```

## Extracting as its own GitHub repo

This folder is self-contained. You can later push only `Atlas/` as a new repository:

```bash
cd Atlas
git init
git add .
git commit -m "Initial Atlas app"
git remote add origin <new-atlas-repo-url>
git push -u origin main
```
