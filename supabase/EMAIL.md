# Brevo email configuration (TrustVault)

TrustVault sends transactional emails through **Brevo** (formerly Sendinblue).

## Edge function (`send-email`)

Handles OTP, welcome, KYC, funding, transfer, and withdrawal notifications.

### Required secrets

```bash
supabase secrets set BREVO_API_KEY=xkeysib-your-api-key
supabase secrets set BREVO_SENDER_EMAIL=noreply@yourdomain.com
supabase secrets set BREVO_SENDER_NAME="TrustVault"
supabase secrets set APP_URL=https://your-app.com
```

Create an API key in Brevo: **SMTP & API → API keys → Generate a new API key** (Transactional emails permission).

The sender email must be a **verified sender/domain** in Brevo.

### Deploy

```bash
supabase functions deploy send-email
```

## Supabase Auth emails (password reset)

Auth emails (forgot password) use Brevo SMTP when enabled.

### Hosted Supabase (Dashboard)

1. **Project Settings → Auth → SMTP**
2. Enable custom SMTP:
   - Host: `smtp-relay.brevo.com`
   - Port: `587`
   - Username: your Brevo account login email
   - Password: Brevo **SMTP key** (not the API key)
   - Sender email: verified Brevo sender
   - Sender name: `TrustVault`

### Local development

By default, `config.toml` keeps SMTP disabled so auth emails go to **Inbucket** (`http://localhost:54324`).

To test Brevo locally, set env vars and enable SMTP in `config.toml`:

```toml
[auth.email.smtp]
enabled = true
```

```bash
export BREVO_SMTP_USER=your-login@email.com
export BREVO_SMTP_KEY=your-smtp-key
export BREVO_SENDER_EMAIL=noreply@yourdomain.com
supabase start
```

## Email flows

| Event | Template | Delivery |
|-------|----------|----------|
| Registration OTP | `registration_otp` | Brevo API (edge function) |
| Account created | `welcome` | Brevo API |
| KYC reminder | `kyc_prompt` | Brevo API |
| Funding submitted/approved | `funding_*` | Brevo API |
| Transfer sent/received | `transfer_*` | Brevo API |
| Withdrawal submitted/approved | `withdrawal_*` | Brevo API |
| Forgot password | `recovery.html` | Brevo SMTP (Supabase Auth) |
