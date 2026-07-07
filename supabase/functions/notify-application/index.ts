import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// Shared secret checked against the DB trigger's request header — this function
// has verify_jwt disabled (it's called by a Postgres trigger, not a logged-in
// user) so this is the only gate keeping random callers out.
const WEBHOOK_SECRET = "lnpbFlnuqswx10dg9x63wDOLNnWiVr6E";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
const DIRECTOR_EMAIL = "mateteellenlegodi@hotmail.com";
// Resend's shared sandbox sender — works with no domain setup, but until a
// custom domain is verified in Resend, delivery is restricted to the email
// address the Resend account itself was signed up with.
const FROM_EMAIL = "NM Legodi Consulting <onboarding@resend.dev>";

async function sendEmail(to: string, subject: string, html: string) {
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ from: FROM_EMAIL, to: [to], subject, html }),
  });
  const body = await res.text();
  return { ok: res.ok, status: res.status, body };
}

Deno.serve(async (req) => {
  if (req.headers.get("x-webhook-secret") !== WEBHOOK_SECRET) {
    return new Response("Unauthorized", { status: 401 });
  }
  if (!RESEND_API_KEY) {
    return new Response(JSON.stringify({ ok: false, error: "RESEND_API_KEY not set" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const payload = await req.json();
  const record = payload.record ?? payload;
  const { ref, company_name, contact_name, email, phone, entity_type, industry, services, submitted } = record;

  const svcList = Array.isArray(services) && services.length ? services.join(", ") : "—";
  const firstName = (contact_name || "").split(" ")[0] || "there";

  const applicantHtml = `
    <div style="font-family:Georgia,serif;color:#0e2840;max-width:520px">
      <h2>Thank you, ${firstName}</h2>
      <p>We've received your company registration application with NM Legodi Consulting. Our team will review it and be in touch shortly.</p>
      <p style="background:#eef4fb;border:1px solid #d4e2f0;padding:16px;border-radius:6px">
        <strong>Your reference number:</strong><br>
        <span style="font-size:22px">${ref}</span>
      </p>
      <p>Track your application status anytime at
        <a href="https://mohlatswa.github.io/legodi-co/">mohlatswa.github.io/legodi-co</a> — go to "Track Application" and enter this reference.</p>
      <p>— NM Legodi Consulting (Pty) Ltd</p>
    </div>`;

  const directorHtml = `
    <div style="font-family:Georgia,serif;color:#0e2840;max-width:560px">
      <h2>New company registration application</h2>
      <table style="border-collapse:collapse;font-family:Arial,sans-serif;font-size:14px">
        <tr><td style="padding:4px 12px 4px 0;color:#5d7488">Reference</td><td><strong>${ref}</strong></td></tr>
        <tr><td style="padding:4px 12px 4px 0;color:#5d7488">Company</td><td>${company_name}</td></tr>
        <tr><td style="padding:4px 12px 4px 0;color:#5d7488">Entity type</td><td>${entity_type || "—"}</td></tr>
        <tr><td style="padding:4px 12px 4px 0;color:#5d7488">Industry</td><td>${industry || "—"}</td></tr>
        <tr><td style="padding:4px 12px 4px 0;color:#5d7488">Contact</td><td>${contact_name}</td></tr>
        <tr><td style="padding:4px 12px 4px 0;color:#5d7488">Email</td><td>${email}</td></tr>
        <tr><td style="padding:4px 12px 4px 0;color:#5d7488">Phone</td><td>${phone || "—"}</td></tr>
        <tr><td style="padding:4px 12px 4px 0;color:#5d7488">Services requested</td><td>${svcList}</td></tr>
        <tr><td style="padding:4px 12px 4px 0;color:#5d7488">Submitted</td><td>${submitted}</td></tr>
      </table>
      <p><a href="https://mohlatswa.github.io/legodi-co/">Open the Staff Portal to review →</a></p>
    </div>`;

  const [applicantResult, directorResult] = await Promise.allSettled([
    email ? sendEmail(email, `Application received — ref ${ref}`, applicantHtml) : Promise.resolve({ ok: false, skipped: true }),
    sendEmail(DIRECTOR_EMAIL, `New application: ${company_name} (${ref})`, directorHtml),
  ]);

  return new Response(
    JSON.stringify({
      ok: true,
      applicant: applicantResult.status === "fulfilled" ? applicantResult.value : String(applicantResult.reason),
      director: directorResult.status === "fulfilled" ? directorResult.value : String(directorResult.reason),
    }),
    { headers: { "Content-Type": "application/json" } },
  );
});
