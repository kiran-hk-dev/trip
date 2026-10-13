// Emergency + visa reference synchronisation.
//
// This function NEVER invents data. It reads from a configured list of
// official source URLs, records what it found, and updates verification
// metadata. Anything it cannot confirm is left as `unverified`.
//
// Run it from Supabase cron (see README) or manually from the dashboard. It
// requires the service role and refuses non-service callers.

import {
  type Env,
  authenticate,
  fail,
  getEnv,
  isResponse,
  json,
  preflight,
  withCors,
} from "../_shared/mod.ts";

interface OfficialSource {
  country_code: string;
  country_name: string;
  category: string;
  service_name: string;
  phone?: string | null;
  address?: string | null;
  official_url: string;
  source_url: string;
  source_org: string;
  hours?: string | null;
  languages?: string[];
  availability_note?: string | null;
}

/**
 * The curated registry of official publishers.
 *
 * Adding a country means adding an entry here with a real, traceable official
 * URL. There is no "unknown" bucket — if a country is not listed, the app
 * shows no number rather than a guess.
 */
const OFFICIAL_SOURCES: OfficialSource[] = [
  {
    country_code: "HK",
    country_name: "Hong Kong SAR",
    category: "police",
    service_name: "Police (999 — emergency)",
    phone: "999",
    official_url: "https://www.police.gov.hk/en/contact/index.html",
    source_url: "https://www.police.gov.hk/en/contact/index.html",
    source_org: "Hong Kong Police Force",
    hours: "24 hours",
    languages: ["English", "中文", "繁體"],
    availability_note:
      "999 reaches police, fire services and ambulance in the Hong Kong SAR. 112 also connects to emergency services.",
  },
  {
    country_code: "HK",
    country_name: "Hong Kong SAR",
    category: "ambulance",
    service_name: "Ambulance (999 — emergency)",
    phone: "999",
    official_url: "https://www.hkfsd.gov.hk/english/contactus/contactus.html",
    source_url: "https://www.hkfsd.gov.hk/english/contactus/contactus.html",
    source_org: "Hong Kong Fire Services Department",
    hours: "24 hours",
    languages: ["English", "中文", "繁體"],
  },
  {
    country_code: "HK",
    country_name: "Hong Kong SAR",
    category: "immigration",
    service_name: "Immigration Department enquiries",
    phone: "2824 6111",
    official_url: "https://www.immd.gov.hk/eng/services/contact.html",
    source_url: "https://www.immd.gov.hk/eng/services/contact.html",
    source_org: "Hong Kong Immigration Department",
    hours: "24 hours for the general enquiries line",
    languages: ["English", "中文", "繁體"],
  },
  {
    country_code: "GB",
    country_name: "United Kingdom",
    category: "emergency",
    service_name: "Police, ambulance and fire",
    phone: "999",
    official_url: "https://www.gov.uk/guidance/999-and-112-the-uks-national-emergency-numbers",
    source_url: "https://www.gov.uk/guidance/999-and-112-the-uks-national-emergency-numbers",
    source_org: "UK Government (GOV.UK)",
    hours: "24 hours",
    languages: ["English"],
    availability_note: "112 also connects to the same emergency services.",
  },
  {
    country_code: "US",
    country_name: "United States",
    category: "police",
    service_name: "Police, ambulance and fire",
    phone: "911",
    official_url: "https://www.911.gov/",
    source_url: "https://www.911.gov/",
    source_org: "National Emergency Number System",
    hours: "24 hours",
    languages: ["English", "Español"],
  },
  {
    country_code: "IN",
    country_name: "India",
    category: "emergency",
    service_name: "Police, ambulance, fire and disaster",
    phone: "112",
    official_url: "https://www.indiacode.nic.in/",
    source_url: "https://www.indiacode.nic.in/",
    source_org: "Government of India",
    hours: "24 hours",
    languages: ["English", "हिन्दी"],
    availability_note: "Integrated national emergency number; state coverage varies.",
  },
  {
    country_code: "JP",
    country_name: "Japan",
    category: "police",
    service_name: "Police (110)",
    phone: "110",
    official_url: "https://www.npa.go.jp/english/",
    source_url: "https://www.npa.go.jp/english/",
    source_org: "National Police Agency of Japan",
    hours: "24 hours",
    languages: ["日本語", "English"],
  },
  {
    country_code: "JP",
    country_name: "Japan",
    category: "ambulance",
    service_name: "Fire and ambulance (119)",
    phone: "119",
    official_url: "https://www.fdma.go.jp/mission/prepare/119/english/index.html",
    source_url: "https://www.fdma.go.jp/mission/prepare/119/english/index.html",
    source_org: "Japan Fire and Disaster Management Agency",
    hours: "24 hours",
    languages: ["日本語", "English"],
  },
  {
    country_code: "SG",
    country_name: "Singapore",
    category: "police",
    service_name: "Police (999)",
    phone: "999",
    official_url: "https://www.police.gov.sg/Contact-Us",
    source_url: "https://www.police.gov.sg/Contact-Us",
    source_org: "Singapore Police Force",
    hours: "24 hours",
    languages: ["English", "中文", "Bahasa Melayu", "தமிழ்"],
    availability_note: "Ambulance and fire services in Singapore use 995.",
  },
  {
    country_code: "AU",
    country_name: "Australia",
    category: "police",
    service_name: "Police, ambulance and fire (000)",
    phone: "000",
    official_url: "https://www.triplezero.gov.au/",
    source_url: "https://www.triplezero.gov.au/",
    source_org: "Australian Government — Triple Zero",
    hours: "24 hours",
    languages: ["English"],
    availability_note: "112 also works from mobile phones in Australia.",
  },
  {
    country_code: "DE",
    country_name: "Germany",
    category: "police",
    service_name: "Police (110)",
    phone: "110",
    official_url: "https://www.bundespolizei.de/EN/Websites/contact/contact-node.html",
    source_url: "https://www.bundespolizei.de/EN/Websites/contact/contact-node.html",
    source_org: "Federal Criminal Police Office (BKA)",
    hours: "24 hours",
    languages: ["Deutsch", "English"],
    availability_note: "Emergency medical and fire services in Germany use 112.",
  },
];

const REVIEW_INTERVAL_DAYS = 90;

Deno.serve(async (req) => {
  const pre = preflight(req);
  if (pre) return withCors(pre);

  const env: Env = getEnv();

  try {
    const auth = await authenticate(env, req);
    if (isResponse(auth)) return withCors(auth);

    // Service-role only. A normal user must not be able to edit the registry.
    const { data: claims } = await auth.service.auth.getUser(auth.userId);
    const role = claims?.app_metadata?.role;
    if (role !== "service_role") {
      return withCors(
        fail("Only the service role may run reference synchronisation.", 403, "forbidden"),
      );
    }

    const now = new Date();
    const reviewDue = new Date(now.getTime() + REVIEW_INTERVAL_DAYS * 86_400_000).toISOString();

    const results: Record<string, number> = {
      checked: 0,
      unreachable: 0,
      created: 0,
      updated: 0,
      unchanged: 0,
    };

    for (const source of OFFICIAL_SOURCES) {
      results.checked += 1;

      // A successful fetch means the official page is reachable. It does NOT
      // prove the phone number printed there is correct, so the row is marked
      // 'needs_review' for a human to confirm rather than auto-verified.
      let reachable = false;
      try {
        const controller = new AbortController();
        const timer = setTimeout(() => controller.abort(), 10_000);
        const resp = await fetch(source.source_url, {
          method: "HEAD",
          redirect: "follow",
          signal: controller.signal,
          headers: { "user-agent": "TripSplitWorld/1.0 (+reference-sync)" },
        });
        reachable = resp.ok;
        clearTimeout(timer);
      } catch {
        reachable = false;
      }

      if (!reachable) results.unreachable += 1;

      const verification = reachable ? "needs_review" : "unverified";

      const { data: existing } = await auth.service
        .from("emergency_resources")
        .select("id, phone, official_url, verification, last_verified_at")
        .eq("country_code", source.country_code)
        .eq("category", source.category)
        .eq("service_name", source.service_name)
        .maybeSingle();

      const row = {
        country_code: source.country_code,
        country_name: source.country_name,
        category: source.category,
        service_name: source.service_name,
        phone: source.phone ?? null,
        address: source.address ?? null,
        official_url: source.official_url,
        languages: source.languages ?? ["English"],
        hours: source.hours ?? null,
        availability_note: source.availability_note ?? null,
        source_url: source.source_url,
        source_org: source.source_org,
        verification,
        last_verified_at: now.toISOString(),
        review_due_at: reviewDue,
        updated_at: now.toISOString(),
      };

      if (!existing) {
        await auth.service.from("emergency_resources").insert(row);
        results.created += 1;
        await auth.service.from("source_verification_log").insert({
          table_name: "emergency_resources",
          source_url: source.source_url,
          source_org: source.source_org,
          previous_state: null,
          new_state: verification,
          changed_by: "sync-resources",
          notes: reachable ? "Created from registry; URL reachable, awaiting manual review." : "Created from registry; source URL unreachable.",
        });
        continue;
      }

      const changed = existing.phone !== row.phone || existing.official_url !== row.official_url;
      await auth.service.from("emergency_resources").update(row).eq("id", existing.id);

      if (changed) {
        results.updated += 1;
        await auth.service.from("source_verification_log").insert({
          table_name: "emergency_resources",
          record_id: existing.id,
          source_url: source.source_url,
          source_org: source.source_org,
          previous_state: existing.verification,
          new_state: verification,
          changed_by: "sync-resources",
          notes: "Details changed during sync.",
        });
      } else {
        results.unchanged += 1;
      }
    }

    // Flag anything past its review date so the app can warn the user.
    const { data: overdue } = await auth.service
      .from("emergency_resources")
      .select("id")
      .lt("review_due_at", now.toISOString())
      .eq("verification", "verified");

    if (overdue?.length) {
      await auth.service
        .from("emergency_resources")
        .update({ verification: "stale" })
        .in("id", overdue.map((r) => r.id));
      results.updated += overdue.length;
    }

    return withCors(
      json({
        results,
        ran_at: now.toISOString(),
        note:
          "Reachability checks do not verify content. Rows are marked 'needs_review' until a reviewer confirms the details against the official page.",
      }),
    );
  } catch (err) {
    console.error("sync-resources failed", err);
    return withCors(fail("Reference synchronisation failed.", 500, "internal"));
  }
});
