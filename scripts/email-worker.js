#!/usr/bin/env node

/**
 * TrustVault Local Email Outbox Worker
 * Watches public.email_outbox for pending emails, attempts Brevo delivery,
 * and logs OTP verification codes directly to console if Brevo SMTP requires activation.
 */

const SUPABASE_URL = process.env.SUPABASE_URL || 'http://127.0.0.1:54321';
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';
const BREVO_API_KEY = process.env.BREVO_API_KEY || '';
const SENDER_EMAIL = process.env.BREVO_SENDER_EMAIL || 'emmanuelocheme86@gmail.com';
const SENDER_NAME = process.env.BREVO_SENDER_NAME || 'TrustVault';

async function fetchPendingEmails() {
  try {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/email_outbox?status=eq.pending&order=created_at.asc`, {
      headers: {
        'apikey': SERVICE_ROLE_KEY,
        'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
      },
    });
    if (!res.ok) return [];
    return await res.json();
  } catch (err) {
    return [];
  }
}

async function markOutboxStatus(id, status, errorMessage = null) {
  try {
    await fetch(`${SUPABASE_URL}/rest/v1/email_outbox?id=eq.${id}`, {
      method: 'PATCH',
      headers: {
        'apikey': SERVICE_ROLE_KEY,
        'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=minimal',
      },
      body: JSON.stringify({
        status,
        error_message: errorMessage,
        sent_at: status === 'sent' ? new Date().toISOString() : null,
      }),
    });
  } catch (err) {}
}

async function sendViaBrevo(email) {
  const otp = email.payload?.otp;
  const htmlContent = email.template_key === 'registration_otp'
    ? `<h1>TrustVault Verification Code</h1><p>Hi, your verification code is: <strong>${otp}</strong></p>`
    : `<p>${email.subject}</p>`;

  const response = await fetch('https://api.brevo.com/v3/smtp/email', {
    method: 'POST',
    headers: {
      'api-key': BREVO_API_KEY,
      'accept': 'application/json',
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      sender: { name: SENDER_NAME, email: SENDER_EMAIL },
      to: [{ email: email.recipient_email }],
      subject: email.subject,
      htmlContent,
    }),
  });

  const data = await response.json();
  if (!response.ok) {
    throw new Error(data.message || `Brevo Error ${response.status}`);
  }
  return data;
}

async function processOutbox() {
  const pending = await fetchPendingEmails();
  for (const email of pending) {
    const otp = email.payload?.otp;
    console.log(`\n======================================================`);
    console.log(`📧 OUTBOX EMAIL DETECTED [#${email.id}]`);
    console.log(`  Recipient: ${email.recipient_email}`);
    console.log(`  Subject:   ${email.subject}`);
    if (otp) {
      console.log(`  🔑 VERIFICATION CODE (OTP): [ ${otp} ]`);
    }
    console.log(`======================================================`);

    try {
      await sendViaBrevo(email);
      console.log(`  ✅ Successfully delivered via Brevo API!`);
      await markOutboxStatus(email.id, 'sent');
    } catch (err) {
      console.log(`  ⚠️ Brevo Delivery Note: ${err.message}`);
      if (otp) {
        console.log(`  ℹ️ You can use OTP code [ ${otp} ] above directly in the app!`);
      }
      await markOutboxStatus(email.id, 'failed', err.message);
    }
  }
}

console.log('🚀 TrustVault Email Outbox Worker started...');
processOutbox();
setInterval(processOutbox, 3000);
