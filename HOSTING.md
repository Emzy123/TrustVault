# Hosting TrustVault (Supabase + Flutter Web)

End-to-end checklist to run TrustVault on **hosted Supabase** and a **static web host**.

---

## Overview

| Piece | Where |
|--------|--------|
| Database, Auth, RPCs | [Supabase](https://supabase.com) |
| Transactional email (OTP, etc.) | Supabase Edge Function `send-email` + **Brevo** |
| Flutter Web UI | Netlify, Vercel, Cloudflare Pages, GitHub Pages, etc. |

Your repo already defaults to project ref **`xrumgoeuzufxidxwwusm`** in `app/lib/core/config/env.dart` and `.env` — use that project or create a new one and update `.env` + `dart-define`s.

---

## 1. Supabase project

1. Create or open a project at [supabase.com/dashboard](https://supabase.com/dashboard).
2. Copy **Project URL** and **anon public** key → root `.env` (see `.env.example`).

### Option A — CLI (recommended)

```bash
cd /home/purist/Desktop/projects/TrustVault
cp .env.example .env   # fill in values
npx supabase login
chmod +x scripts/host-supabase.sh scripts/build-web.sh
./scripts/host-supabase.sh
```

This runs `supabase link`, `db push` (all 8 migrations), and deploys `send-email`.

### Option B — SQL Editor only

On a **fresh** database, run these **in order** (paste each file):

1. `supabase/migrations/20260724000001_initial_schema.sql`
2. `supabase/migrations/20260724000002_functions_and_triggers.sql`
3. `supabase/migrations/20260724000003_rls_policies.sql`
4. `supabase/migrations/20260724000004_phase2_operations.sql`
5. `supabase/migrations/20260724000005_phase3_admin_operations.sql`
6. `supabase/migrations/20260727000006_security_and_admin_enhancements.sql`
7. `supabase/migrations/20260730000007_email_notifications.sql`
8. `supabase/migrations/20260731000008_super_admin_user_management.sql`
9. `supabase/seed_auth.sql`
10. `supabase/seed.sql`

Then deploy the edge function manually (Dashboard → Edge Functions) or via CLI:

```bash
npx supabase functions deploy send-email --no-verify-jwt
```

---

## 2. Auth settings (Dashboard)

**Authentication → URL configuration**

- **Site URL:** your public app URL (same as `APP_URL` in `.env`)
- **Redirect URLs:** add `APP_URL` and `APP_URL/**`

**Authentication → Providers → Email:** enable email signup.

**Authentication → SMTP (optional):** Brevo for forgot-password — see `supabase/EMAIL.md`.

---

## 3. Brevo + edge function secrets

Required for **signup OTP** and wallet notification emails:

```bash
npx supabase secrets set \
  BREVO_API_KEY=xkeysib-your-key \
  BREVO_SENDER_EMAIL=noreply@yourdomain.com \
  BREVO_SENDER_NAME="TrustVault" \
  APP_URL=https://your-app.example.com
```

Verify sender/domain in Brevo before going live.

Details: `supabase/EMAIL.md`.

---

## 4. Build Flutter Web

```bash
cd /home/purist/Desktop/projects/TrustVault
# .env must contain SUPABASE_URL, SUPABASE_ANON_KEY, APP_URL
./scripts/build-web.sh
```

Output: `app/build/web/` — upload this folder to your host.

---

## 5. Deploy static site

### Netlify

- **Base directory:** `app`
- **Build command:** use `netlify.toml` or run `./scripts/build-web.sh` locally and deploy `app/build/web` with “Deploy manually”
- **Environment variables:** `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `APP_URL`
- Install Flutter on Netlify only if you build on their CI (otherwise build locally)

### Vercel

- Root directory: `app`
- Set env vars: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `APP_URL`
- Vercel does not include Flutter by default — prefer **local build** + Vercel CLI:

```bash
cd app/build/web && npx vercel --prod
```

### Cloudflare Pages / GitHub Pages

Build locally with `./scripts/build-web.sh`, publish `app/build/web`.

---

## 6. Demo accounts (after seed)

Password: **`Password123!`**

- `superadmin@trustvault.demo` — full control  
- `admin@trustvault.demo` — ops queues  
- `alice@trustvault.demo` — funded user  

---

## 7. Post-deploy checks

- [ ] Login as superadmin  
- [ ] User dashboard loads balance (Alice)  
- [ ] Signup OTP email arrives (needs Brevo)  
- [ ] Forgot password (Auth email or Inbucket/SMTP)  
- [ ] Super Admin → create/delete user  

---

## Troubleshooting

| Issue | Fix |
|--------|-----|
| App hits wrong API | Rebuild with correct `--dart-define=SUPABASE_URL=...` |
| OTP never arrives | Brevo secrets + `send-email` deployed; check `email_outbox` in SQL |
| Auth redirect error | Add app URL to Supabase Auth redirect allow list |
| 404 on refresh | SPA rewrite to `index.html` (Netlify/Vercel config above) |
