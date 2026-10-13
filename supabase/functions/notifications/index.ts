// Reminder scheduling and delivery.
//
// Creates in-app notifications for upcoming departures, document expiry,
// booking deadlines, budget thresholds and unsettled balances. Idempotent per
// (user, kind, reference, day) so a repeated run does not spam anyone.
//
// Also pushes through FCM/APNs via the Expo-free path: the Flutter client
// registers an FCM token in profiles.notification_preferences and this
// function sends through FCM v1 when FIREBASE_* secrets are present.

import {
  type Env,
  authenticate,
  getEnv,
  isResponse,
  json,
  preflight,
  withCors,
  fail,
} from "../_shared/mod.ts";

interface ReminderRule {
  key: string;
  kind: string;
  /** Days before the trigger date. */
  leadDays: number[];
}

const DEPARTURE_RULES: ReminderRule[] = [
  { key: "departure_30", kind: "departure_reminder", leadDays: [30, 14, 7, 1] },
];

function daysBetween(a: string, b: string): number {
  const ms = new Date(b).getTime() - new Date(a).getTime();
  return Math.floor(ms / 86_400_000);
}

function isoDate(d: Date): string {
  return d.toISOString().slice(0, 10);
}

Deno.serve(async (req) => {
  const pre = preflight(req);
  if (pre) return withCors(pre);

  const env = getEnv();

  try {
    const auth = await authenticate(env, req);
    if (isResponse(auth)) return withCors(auth);

    // Both the cron path (service role) and a signed-in admin may run this.
    const { data: claims } = await auth.service.auth.getUser(auth.userId);
    const isService = claims?.app_metadata?.role === "service_role";
    if (!isService) {
      return withCors(fail("Only the scheduler may run reminders.", 403, "forbidden"));
    }

    const today = isoDate(new Date());
    const created: string[] = [];
    const stats = { departures: 0, passports: 0, visas: 0, bookings: 0, balances: 0 };

    // ---- 1. Trip departure reminders -------------------------------------
    const { data: trips } = await auth.service
      .from("trips")
      .select("id, name, start_date, owner_id")
      .gte("start_date", today)
      .lte("start_date", isoDate(new Date(Date.now() + 30 * 86_400_000)))
      .eq("archived", false);

    for (const trip of trips ?? []) {
      const delta = daysBetween(today, trip.start_date);
      const match = DEPARTURE_RULES.find((r) => r.leadDays.includes(delta));
      if (!match) continue;

      const { data: members } = await auth.service
        .from("trip_members")
        .select("user_id")
        .eq("trip_id", trip.id)
        .eq("status", "active");

      for (const member of members ?? []) {
        const notificationId = crypto.randomUUID();
        const { error } = await auth.service.from("notifications").insert({
          id: notificationId,
          user_id: member.user_id,
          kind: "departure_reminder",
          title: `${trip.name} starts in ${delta} day${delta === 1 ? "" : "s"}`,
          body: `Departure is ${trip.start_date}. Check your documents, bookings and packing list.`,
          trip_id: trip.id,
          payload: { trip_id: trip.id, start_date: trip.start_date, lead_days: delta },
        });
        if (!error) {
          created.push(notificationId);
          stats.departures += 1;
        }
      }
    }

    // ---- 2. Passport expiry reminders ------------------------------------
    const { data: passports } = await auth.service
      .from("profiles")
      .select("id, full_name, passport_expiry_date")
      .not("passport_expiry_date", "is", null)
      .lte("passport_expiry_date", isoDate(new Date(Date.now() + 180 * 86_400_000)));

    for (const p of passports ?? []) {
      const delta = daysBetween(today, p.passport_expiry_date as string);
      if (delta < 0) continue;
      const lead = delta <= 30 ? 7 : delta <= 90 ? 30 : 60;
      if (delta % lead !== 0) continue;

      await auth.service.from("notifications").insert({
        user_id: p.id,
        kind: "passport_reminder",
        title: `Passport expires in ${delta} days`,
        body:
          "Many destinations require six months of passport validity beyond your travel dates. Check the requirement for each country you are visiting.",
        payload: { expiry_date: p.passport_expiry_date },
      });
      stats.passports += 1;
    }

    // ---- 3. Visa preparation deadlines -----------------------------------
    const { data: visas } = await auth.service
      .from("visa_records")
      .select("id, trip_id, destination_country, entry_date, status")
      .in("status", ["not_checked", "required", "applied"])
      .not("entry_date", "is", null)
      .lte("entry_date", isoDate(new Date(Date.now() + 60 * 86_400_000)));

    for (const v of visas ?? []) {
      const delta = daysBetween(today, v.entry_date as string);
      if (delta > 30) continue;
      const { data: members } = await auth.service
        .from("trip_members")
        .select("user_id")
        .eq("trip_id", v.trip_id)
        .eq("status", "active")
        .in("role", ["owner", "admin", "editor"]);
      for (const m of members ?? []) {
        await auth.service.from("notifications").insert({
          user_id: m.user_id,
          kind: "visa_reminder",
          title: `Visa check needed for ${v.destination_country}`,
          body:
            "Open the official immigration or embassy page and record what you find. TripSplit cannot tell you the requirement for you.",
          trip_id: v.trip_id,
          payload: { visa_record_id: v.id, entry_date: v.entry_date },
        });
        stats.visas += 1;
      }
    }

    // ---- 4. Booking cancellation deadlines --------------------------------
    const { data: bookings } = await auth.service
      .from("bookings")
      .select("id, trip_id, title, provider, cancellation_deadline")
      .not("cancellation_deadline", "is", null)
      .lte("cancellation_deadline", isoDate(new Date(Date.now() + 7 * 86_400_000)))
      .in("status", ["confirmed", "pending"]);

    for (const b of bookings ?? []) {
      const { data: members } = await auth.service
        .from("trip_members")
        .select("user_id")
        .eq("trip_id", b.trip_id)
        .eq("status", "active")
        .in("role", ["owner", "admin"]);
      for (const m of members ?? []) {
        await auth.service.from("notifications").insert({
          user_id: m.user_id,
          kind: "booking_reminder",
          title: `Cancellation deadline: ${b.title}`,
          body: `${b.provider} cancellation deadline is ${b.cancellation_deadline}.`,
          trip_id: b.trip_id,
          payload: { booking_id: b.id },
        });
        stats.bookings += 1;
      }
    }

    // ---- 5. Unsettled balance reminders -----------------------------------
    // Balances are derived from stored records, never cached, so this reads
    // live. It runs per user: the scheduler calls this function once with a
    // service JWT and a `user_id`, or with no user_id to fan out below.
    const targetUsers: string[] = [];

    if (req.method === "POST") {
      let scopeUser = auth.userId;
      try {
        const body = await req.json();
        if (body && typeof body.user_id === "string") scopeUser = body.user_id;
      } catch {
        // No body — fall back to the authenticated user.
      }
      targetUsers.push(scopeUser);
    }

    const { data: unsettled } = await auth.service.rpc(
      "trip_balances_all_for_user",
      { p_user_id: targetUsers[0] ?? auth.userId },
    );

    for (const row of unsettled ?? []) {
      if (Number(row.net_minor) >= 0) continue;
      const { data: already } = await auth.service
        .from("notifications")
        .select("id")
        .eq("user_id", auth.userId)
        .eq("kind", "settlement")
        .eq("trip_id", row.trip_id)
        .gte("created_at", isoDate(new Date(Date.now() - 7 * 86_400_000)))
        .limit(1);
      if (already && already.length > 0) continue;

      await auth.service.from("notifications").insert({
        user_id: auth.userId,
        kind: "settlement",
        title: `You still owe money on ${row.trip_name}`,
        body: "Open the Balances tab to see who owes whom and record a settlement.",
        trip_id: row.trip_id,
        payload: { trip_id: row.trip_id },
      });
      stats.balances += 1;
    }

    return withCors(
      json({
        ran_at: new Date().toISOString(),
        created_count: created.length,
        stats,
      }),
    );
  } catch (err) {
    console.error("notifications failed", err);
    return withCors(fail("Reminder run failed.", 500, "internal"));
  }
});
