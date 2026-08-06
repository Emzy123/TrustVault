import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type OutboxRow = {
  id: string;
  recipient_email: string;
  template_key: string;
  subject: string;
  payload: Record<string, unknown>;
};

function escapeHtml(value: unknown): string {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function formatAmount(value: unknown): string {
  const num = Number(value);
  if (Number.isNaN(num)) return escapeHtml(value);
  return `\$${num.toLocaleString("en-US", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;
}

function baseLayout(title: string, bodyHtml: string): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escapeHtml(title)}</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background:#F3F4F6; margin:0; padding:0; color:#1F2937; }
    .email-container { max-width:600px; margin:40px auto; background:#FFF; border-radius:12px; overflow:hidden; box-shadow:0 10px 25px rgba(0,0,0,0.08); }
    .header { background:#1B2A4A; padding:32px 24px; text-align:center; }
    .logo-text { color:#FFF; font-size:26px; font-weight:700; }
    .logo-accent { color:#B8860B; }
    .body-content { padding:40px 32px; }
    h1 { color:#1B2A4A; font-size:22px; margin:0 0 16px; }
    p { color:#4B5563; font-size:15px; line-height:1.6; margin:0 0 16px; }
    .otp-box { background:#F8FAFC; border:2px dashed #2F5C9E; border-radius:12px; padding:24px; text-align:center; margin:24px 0; }
    .otp-code { font-size:36px; font-weight:700; letter-spacing:8px; color:#1B2A4A; }
    .cta-button { background:#2F5C9E; color:#FFF !important; font-weight:600; font-size:16px; padding:14px 32px; text-decoration:none; border-radius:8px; display:inline-block; }
    .info-card { background:#F8FAFC; border-left:4px solid #B8860B; padding:16px 20px; border-radius:0 8px 8px 0; margin:24px 0; }
    .detail-row { margin:8px 0; font-size:14px; color:#374151; }
    .footer { background:#F9FAFB; padding:24px 32px; border-top:1px solid #E5E7EB; font-size:13px; color:#9CA3AF; text-align:center; }
  </style>
</head>
<body>
  <div class="email-container">
    <div class="header">
      <div class="logo-text">Trust<span class="logo-accent">Vault</span></div>
      <div style="color:#94A3B8;font-size:12px;margin-top:4px;letter-spacing:1px;">SECURE DIGITAL BANKING</div>
    </div>
    <div class="body-content">${bodyHtml}</div>
    <div class="footer">
      <p>&copy; 2026 TrustVault Software Labs. All rights reserved.</p>
      <p>If you did not expect this email, you can safely ignore it.</p>
    </div>
  </div>
</body>
</html>`;
}

function renderTemplate(row: OutboxRow): { subject: string; html: string } {
  const p = row.payload ?? {};
  const name = escapeHtml(p.full_name || "there");

  switch (row.template_key) {
    case "registration_otp":
      return {
        subject: row.subject,
        html: baseLayout(
          "Verification Code",
          `<h1>Verify your email</h1>
          <p>Hi ${name === "there" ? "there" : name}, use the code below to complete your TrustVault registration. It expires in ${escapeHtml(p.expires_minutes ?? 10)} minutes.</p>
          <div class="otp-box"><div class="otp-code">${escapeHtml(p.otp)}</div></div>
          <div class="info-card"><p><strong>Security tip:</strong> Never share this code with anyone. TrustVault staff will never ask for it.</p></div>`
        ),
      };

    case "welcome":
      return {
        subject: row.subject,
        html: baseLayout(
          "Welcome",
          `<h1>Welcome to TrustVault</h1>
          <p>Hi ${name}, your account has been created successfully. Your digital wallet is ready — complete identity verification to unlock funding, transfers, and withdrawals.</p>
          <p style="text-align:center;margin:32px 0;"><a href="${appUrl()}/app/kyc" class="cta-button">Complete Verification</a></p>`
        ),
      };

    case "kyc_prompt":
      return {
        subject: row.subject,
        html: baseLayout(
          "Complete KYC",
          `<h1>Unlock your wallet features</h1>
          <p>Hi ${name}, to fund your wallet and send money securely, please complete identity verification (KYC). This usually takes just a few minutes.</p>
          <p style="text-align:center;margin:32px 0;"><a href="${appUrl()}/app/kyc" class="cta-button">Start KYC Verification</a></p>
          <div class="info-card"><p>You'll need a valid ID, date of birth, and residential address.</p></div>`
        ),
      };

    case "funding_submitted":
      return {
        subject: row.subject,
        html: baseLayout(
          "Funding Request",
          `<h1>Funding request received</h1>
          <p>Hi ${name}, we've received your funding request and our team is reviewing it.</p>
          <div class="detail-row"><strong>Amount:</strong> ${formatAmount(p.amount)}</div>
          <div class="detail-row"><strong>Reference:</strong> ${escapeHtml(p.request_id)}</div>
          <p>You'll receive another email once your request is approved.</p>`
        ),
      };

    case "funding_approved":
      return {
        subject: row.subject,
        html: baseLayout(
          "Funding Approved",
          `<h1>Your wallet has been funded</h1>
          <p>Hi ${name}, great news — your funding request has been approved and credited to your wallet.</p>
          <div class="detail-row"><strong>Amount:</strong> ${formatAmount(p.amount)}</div>
          <div class="detail-row"><strong>Transaction ID:</strong> ${escapeHtml(p.transaction_id)}</div>
          <p style="text-align:center;margin:32px 0;"><a href="${appUrl()}/app" class="cta-button">View Wallet</a></p>`
        ),
      };

    case "transfer_sent":
      return {
        subject: row.subject,
        html: baseLayout(
          "Transfer Sent",
          `<h1>Transfer completed</h1>
          <p>Hi ${name}, your transfer was processed successfully.</p>
          <div class="detail-row"><strong>Amount:</strong> ${formatAmount(p.amount)}</div>
          <div class="detail-row"><strong>Recipient:</strong> ${escapeHtml(p.recipient)} (${escapeHtml(p.recipient_email)})</div>
          ${p.note ? `<div class="detail-row"><strong>Note:</strong> ${escapeHtml(p.note)}</div>` : ""}
          <div class="detail-row"><strong>Reference:</strong> ${escapeHtml(p.transaction_id)}</div>`
        ),
      };

    case "transfer_received":
      return {
        subject: row.subject,
        html: baseLayout(
          "Transfer Received",
          `<h1>You received money</h1>
          <p>Hi ${name}, a transfer has been credited to your TrustVault wallet.</p>
          <div class="detail-row"><strong>Amount:</strong> ${formatAmount(p.amount)}</div>
          <div class="detail-row"><strong>From:</strong> ${escapeHtml(p.sender)} (${escapeHtml(p.sender_email)})</div>
          ${p.note ? `<div class="detail-row"><strong>Note:</strong> ${escapeHtml(p.note)}</div>` : ""}
          <div class="detail-row"><strong>Reference:</strong> ${escapeHtml(p.transaction_id)}</div>`
        ),
      };

    case "withdrawal_submitted":
      return {
        subject: row.subject,
        html: baseLayout(
          "Withdrawal Submitted",
          `<h1>Withdrawal pending review</h1>
          <p>Hi ${name}, your withdrawal request has been submitted and is awaiting compliance review.</p>
          <div class="detail-row"><strong>Amount:</strong> ${formatAmount(p.amount)}</div>
          <div class="detail-row"><strong>Reference:</strong> ${escapeHtml(p.transaction_id)}</div>
          <p>We'll notify you once the withdrawal is processed.</p>`
        ),
      };

    case "withdrawal_approved":
      return {
        subject: row.subject,
        html: baseLayout(
          "Withdrawal Processed",
          `<h1>Withdrawal completed</h1>
          <p>Hi ${name}, your withdrawal has been approved and processed.</p>
          <div class="detail-row"><strong>Amount:</strong> ${formatAmount(p.amount)}</div>
          <div class="detail-row"><strong>Reference:</strong> ${escapeHtml(p.transaction_id)}</div>`
        ),
      };

    default:
      return {
        subject: row.subject,
        html: baseLayout(row.subject, `<h1>${escapeHtml(row.subject)}</h1><p>You have a new notification from TrustVault.</p>`),
      };
  }
}

async function sendViaBrevo(
  apiKey: string,
  to: string,
  subject: string,
  html: string
): Promise<void> {
  const senderEmail =
    Deno.env.get("BREVO_SENDER_EMAIL") ??
    Deno.env.get("EMAIL_FROM") ??
    "noreply@trustvault.app";
  const senderName = Deno.env.get("BREVO_SENDER_NAME") ?? "TrustVault";

  const response = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: {
      "api-key": apiKey,
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: JSON.stringify({
      sender: { name: senderName, email: senderEmail },
      to: [{ email: to }],
      subject,
      htmlContent: html,
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Brevo error (${response.status}): ${body}`);
  }
}

function appUrl(): string {
  return Deno.env.get("APP_URL") ?? "http://localhost:3000";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const body = await req.json();
    const outboxId = body.outbox_id as string | undefined;

    if (!outboxId) {
      return new Response(JSON.stringify({ error: "outbox_id required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: row, error: fetchError } = await supabase
      .from("email_outbox")
      .select("id, recipient_email, template_key, subject, payload, status")
      .eq("id", outboxId)
      .maybeSingle();

    if (fetchError || !row) {
      return new Response(JSON.stringify({ error: "Outbox row not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (row.status === "sent") {
      return new Response(JSON.stringify({ ok: true, skipped: true }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { subject, html } = renderTemplate(row as OutboxRow);
    const brevoKey = Deno.env.get("BREVO_API_KEY");

    try {
      if (!brevoKey) {
        throw new Error(
          "BREVO_API_KEY is not configured. Set it via: supabase secrets set BREVO_API_KEY=your_key"
        );
      }

      await sendViaBrevo(brevoKey, row.recipient_email, subject, html);

      await supabase.rpc("mark_email_sent", {
        p_outbox_id: outboxId,
        p_success: true,
      });

      return new Response(JSON.stringify({ ok: true }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    } catch (sendError) {
      const message = sendError instanceof Error ? sendError.message : String(sendError);
      await supabase.rpc("mark_email_sent", {
        p_outbox_id: outboxId,
        p_success: false,
        p_error_message: message,
      });
      throw sendError;
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
