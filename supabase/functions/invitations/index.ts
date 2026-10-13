// Invitation creation and delivery.
//
// The invitation link token is generated here, stored only as a SHA-256 hash,
// and emailed through Resend when a key is configured. Without a key the
// function still returns a share link so a user can copy it manually — it
// simply says that no email was sent.
//
// Service-role gated, because it inserts into a table clients cannot write to.

import {
  type Env,
  authenticate,
  fail,
  getEnv,
  isResponse,
  json,
  preflight,
  rateLimit,
  withCors,
} from "../_shared/mod.ts";

async function sha256Hex(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function randomToken(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

interface EmailResult {
  sent: boolean;
  reason?: string;
}

async function sendInvitationEmail(
  env: Env,
  to: string,
  inviteeName: string,
  inviterName: string,
  tripName: string,
  role: string,
  link: string,
): Promise<EmailResult> {
  if (!env.RESEND_API_KEY) {
    return { sent: false, reason: "No email provider is configured on this deployment." };
  }

  const resp = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      authorization: `Bearer ${env.RESEND_API_KEY}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      from: env.EMAIL_FROM ?? "TripSplit World <noreply@tripsplit.example>",
      to: [to],
      subject: `${inviterName} invited you to "${tripName}" on TripSplit World`,
      html: `
        <div style="font-family:system-ui,-apple-system,Segoe UI,sans-serif;line-height:1.6;color:#0B1F3A">
          <h1 style="font-size:20px">You're invited to join "${tripName}"</h1>
          <p>${inviterName} has invited you to collaborate on a trip.</p>
          <p>Your role on this trip will be <strong>${role}</strong>.</p>
          <p>
            <a href="${link}"
               style="display:inline-block;background:#0F766E;color:#fff;padding:12px 20px;border-radius:10px;text-decoration:none;font-weight:600">
              Accept invitation
            </a>
          </p>
          <p style="color:#5A6B7F;font-size:14px">
            This link expires in 14 days and can only be used by ${to}.
            If you were not expecting this email you can ignore it.
          </p>
        </div>`,
    }),
  });

  if (!resp.ok) {
    return { sent: false, reason: `Email provider returned ${resp.status}` };
  }
  return { sent: true };
}

Deno.serve(async (req) => {
  const pre = preflight(req);
  if (pre) return withCors(pre);

  const env = getEnv();

  try {
    const auth = await authenticate(env, req);
    if (isResponse(auth)) return withCors(auth);

    const allowed = await rateLimit(auth.service, `invite:${auth.userId}`, 30, 3600);
    if (!allowed) {
      return withCors(fail("Too many invitations sent. Try again later.", 429, "rate_limited"));
    }

    let body: {
      trip_id?: string;
      email?: string;
      role?: string;
      expires_days?: number;
    };
    try {
      body = await req.json();
    } catch {
      return withCors(fail("Request body must be valid JSON."));
    }

    const tripId = body.trip_id ?? "";
    const email = (body.email ?? "").trim().toLowerCase();
    const role = body.role ?? "viewer";

    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(tripId)) {
      return withCors(fail("A valid trip is required."));
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return withCors(fail("A valid email address is required."));
    }
    if (!["owner", "admin", "editor", "viewer"].includes(role)) {
      return withCors(fail("Invalid role."));
    }
    if (role === "owner") {
      return withCors(fail("Ownership can only be transferred, not assigned by invitation."));
    }

    // Authorisation check through the caller's own RLS context.
    const { data: trip } = await auth.client
      .from("trips")
      .select("id, name, owner_id")
      .eq("id", tripId)
      .maybeSingle();

    if (!trip) {
      return withCors(fail("Trip not found or you do not have access to it.", 404, "not_found"));
    }

    const { data: membership } = await auth.client
      .from("trip_members")
      .select("role")
      .eq("trip_id", tripId)
      .eq("user_id", auth.userId)
      .eq("status", "active")
      .maybeSingle();

    if (!membership || !["owner", "admin"].includes(membership.role)) {
      return withCors(fail("Only the trip owner or an admin can invite members.", 403, "forbidden"));
    }

    // Refuse to invite someone who already has a pending or accepted invite
    // for this trip. An active membership is checked by accept_invitation(),
    // which is idempotent.
    const { data: existingInvite } = await auth.service
      .from("trip_invitations")
      .select("id, status")
      .eq("trip_id", tripId)
      .eq("invited_email", email)
      .in("status", ["pending", "accepted"])
      .maybeSingle();

    if (existingInvite?.status === "accepted") {
      return withCors(
        fail("That person has already joined this trip.", 409, "already_member"),
      );
    }

    const token = randomToken();
    const tokenHash = await sha256Hex(token);

    const expiresDays = Math.min(30, Math.max(1, Number(body.expires_days ?? 14)));
    const expiresAt = new Date(Date.now() + expiresDays * 86_400_000).toISOString();

    // Supersede any pending invitation for this address.
    await auth.service
      .from("trip_invitations")
      .update({ status: "expired" })
      .eq("trip_id", tripId)
      .eq("invited_email", email)
      .eq("status", "pending");

    // Supersede any pending invitation for this address.
    await auth.service
      .from("trip_invitations")
      .update({ status: "expired" })
      .eq("trip_id", tripId)
      .eq("invited_email", email)
      .eq("status", "pending");

    const { data: invitation, error } = await auth.service
      .from("trip_invitations")
      .insert({
        trip_id: tripId,
        invited_email: email,
        role,
        token_hash: tokenHash,
        status: "pending",
        invited_by: auth.userId,
        expires_at: expiresAt,
      })
      .select("id")
      .single();

    if (error) {
      return withCors(fail("Could not create the invitation. Try again.", 500, "internal"));
    }

    const appUrl = env.APP_URL ?? "https://app.tripsplit.example";
    const link = `${appUrl}/invite/${token}`;

    const { data: inviterProfile } = await auth.service
      .from("profiles")
      .select("full_name")
      .eq("id", auth.userId)
      .maybeSingle();

    const inviterName = (inviterProfile?.full_name as string | null) ?? "A traveller";

    const emailResult = await sendInvitationEmail(
      env,
      email,
      email.split("@")[0],
      inviterName,
      trip.name as string,
      role,
      link,
    );

    await auth.service.from("activity_logs").insert({
      trip_id: tripId,
      user_id: auth.userId,
      entity_type: "invitation",
      entity_id: invitation.id,
      action: "invitation_sent",
      summary: `Invitation sent to ${email}`,
      metadata: { email, role, emailed: emailResult.sent },
    });

    return withCors(
      json({
        invitation_id: invitation.id,
        email,
        role,
        expires_at: expiresAt,
        email_sent: emailResult.sent,
        email_note: emailResult.reason ?? null,
        // The raw token is returned once so the inviter can copy the link. It
        // is never recoverable afterwards — only its hash is stored.
        invite_link: link,
      }),
    );
  } catch (err) {
    console.error("invitations failed", err);
    return withCors(fail("Could not create the invitation.", 500, "internal"));
  }
});
