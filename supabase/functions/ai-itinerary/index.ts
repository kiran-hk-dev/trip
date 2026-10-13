// AI-assisted itinerary generation.
//
// The model is called here, on the server, so AI_API_KEY never reaches the
// Flutter bundle. Generated output is validated against a strict schema before
// it is returned; anything that fails validation is rejected rather than
// silently repaired.
//
// Everything the model produces is an ESTIMATE. Opening hours, availability and
// prices are not invented: if the model does not have a verified source it
// must return null for that field.

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

const MAX_DAYS = 21;
const TIMEOUT_MS = 45_000;

interface GenerateRequest {
  trip_id?: string;
  origin: string;
  destinations: string[];
  start_date: string;
  end_date: string;
  travelers: number;
  budget_minor?: number;
  currency: string;
  travel_style: string;
  interests: string[];
  accommodation_preference?: string;
  transport_preference?: string;
  dietary_notes?: string;
  accessibility_notes?: string;
  pace?: "relaxed" | "balanced" | "packed";
  regenerate_day?: number;
}

interface GeneratedDay {
  day_number: number;
  date: string;
  title: string;
  summary: string;
  morning: GeneratedActivity[];
  afternoon: GeneratedActivity[];
  evening: GeneratedActivity[];
  estimated_cost_minor: number;
  bad_weather_alternative?: string;
  low_cost_alternative?: string;
}

interface GeneratedActivity {
  title: string;
  kind: string;
  description: string;
  estimated_cost_minor: number;
  currency: string;
  estimated_duration_minutes?: number;
  address?: string | null;
  latitude?: number | null;
  longitude?: number | null;
  // Explicitly nullable: the model must not invent live data.
  opening_hours_verified?: boolean;
  booking_url?: string | null;
  is_estimate: boolean;
}

const SYSTEM_PROMPT = `You are a careful travel planning assistant inside a budgeting app.

Hard rules you must follow:
1. Never state a current opening time, ticket price, availability, or booking
   confirmation unless it was provided to you in the request. If you do not
   know, return null for that field and set opening_hours_verified to false.
2. Every cost you return is an ESTIMATE. Always set is_estimate to true and
   put the currency code alongside the number.
3. Do not invent attraction names that do not exist. Use well-known, real
   places for the destination, or generic descriptions like "local market
   street-food district".
4. Return ONLY JSON matching the schema you are given. No prose, no markdown
   fences.
5. For each day include a bad-weather alternative and a low-cost alternative.
6. Keep the day's activity count consistent with the requested pace:
   relaxed = 2-3, balanced = 4-5, packed = 6-8.`;

function buildSchema(days: number) {
  const activity = {
    type: "object",
    additionalProperties: false,
    required: ["title", "kind", "description", "estimated_cost_minor", "currency", "is_estimate"],
    properties: {
      title: { type: "string", maxLength: 160 },
      kind: {
        type: "string",
        enum: ["attraction", "restaurant", "experience", "accommodation", "transport", "flight", "free_time", "other"],
      },
      description: { type: "string", maxLength: 2000 },
      estimated_cost_minor: { type: "integer", minimum: 0 },
      currency: { type: "string", pattern: "^[A-Z]{3}$" },
      estimated_duration_minutes: { type: "integer", minimum: 15, maximum: 720 },
      address: { type: ["string", "null"] },
      latitude: { type: ["number", "null"], minimum: -90, maximum: 90 },
      longitude: { type: ["number", "null"], minimum: -180, maximum: 180 },
      opening_hours_verified: { type: "boolean" },
      booking_url: { type: ["string", "null"] },
      is_estimate: { type: "boolean" },
    },
  };

  const day = {
    type: "object",
    additionalProperties: false,
    required: ["day_number", "date", "title", "summary", "morning", "afternoon", "evening", "estimated_cost_minor"],
    properties: {
      day_number: { type: "integer", minimum: 1, maximum: MAX_DAYS },
      date: { type: "string", pattern: "^\\d{4}-\\d{2}-\\d{2}$" },
      title: { type: "string", maxLength: 160 },
      summary: { type: "string", maxLength: 1000 },
      morning: { type: "array", items: activity },
      afternoon: { type: "array", items: activity },
      evening: { type: "array", items: activity },
      estimated_cost_minor: { type: "integer", minimum: 0 },
      bad_weather_alternative: { type: "string" },
      low_cost_alternative: { type: "string" },
    },
  };

  return {
    type: "object",
    additionalProperties: false,
    required: ["title", "overview", "days", "budget_allocation", "packing_list", "tips", "visa_reminders"],
    properties: {
      title: { type: "string", maxLength: 160 },
      overview: { type: "string", maxLength: 4000 },
      days: { type: "array", items: day, minItems: 1, maxItems: MAX_DAYS },
      budget_allocation: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: ["category", "estimated_minor", "currency"],
          properties: {
            category: { type: "string", maxLength: 60 },
            estimated_minor: { type: "integer", minimum: 0 },
            currency: { type: "string", pattern: "^[A-Z]{3}$" },
          },
        },
      },
      packing_list: { type: "array", items: { type: "string", maxLength: 120 }, maxItems: 60 },
      tips: { type: "array", items: { type: "string", maxLength: 600 }, maxItems: 30 },
      visa_reminders: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: ["message"],
          properties: {
            message: { type: "string", maxLength: 500 },
            official_source_note: { type: "string", maxLength: 300 },
          },
        },
        maxItems: 20,
      },
    },
  };
}

function buildUserPrompt(req: GenerateRequest, dayCount: number): string {
  const pace = req.pace ?? "balanced";
  const activityRange = pace === "relaxed" ? "2-3" : pace === "packed" ? "6-8" : "4-5";

  const scope = req.regenerate_day
    ? `Regenerate ONLY day ${req.regenerate_day} of the trip. Return a plan with exactly one day object.`
    : `Plan ${dayCount} day${dayCount === 1 ? "" : "s"}. Return exactly ${dayCount} day objects, numbered 1 to ${dayCount}.`;

  return `${scope}

Trip details:
- Origin: ${req.origin}
- Destinations: ${req.destinations.join(", ")}
- Dates: ${req.start_date} to ${req.end_date} (${dayCount} days)
- Travelers: ${req.travelers}
- Travel style: ${req.travel_style}
- Pace: ${pace} (${activityRange} activities per day)
- Interests: ${req.interests.join(", ") || "general sightseeing"}
- Accommodation preference: ${req.accommodation_preference ?? "not specified"}
- Transport preference: ${req.transport_preference ?? "not specified"}
- Dietary requirements: ${req.dietary_notes ?? "none stated"}
- Accessibility requirements: ${req.accessibility_notes ?? "none stated"}
${req.budget_minor != null ? `- Budget: ${req.budget_minor} minor units in ${req.currency}` : "- Budget: not specified"}

Generate a complete plan. Amounts must be in minor units of ${req.currency}
(for example 5000 means ${req.currency === "JPY" ? "5,000" : "50.00"}).
Leave latitude, longitude, address and booking_url null unless you are confident
they are correct. Set opening_hours_verified to false for everything unless
the request supplied verified opening hours.`;
}

async function callProvider(
  env: Env,
  req: GenerateRequest,
  dayCount: number,
): Promise<unknown> {
  const provider = (env.AI_PROVIDER ?? "openai").toLowerCase();
  const apiKey = env.AI_API_KEY;
  if (!apiKey) {
    throw new ProviderUnavailable("No AI provider key is configured on the server.");
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);

  try {
    if (provider === "anthropic") {
      const model = env.AI_MODEL ?? "claude-sonnet-5";
      const resp = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        signal: controller.signal,
        headers: {
          "content-type": "application/json",
          "x-api-key": apiKey,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({
          model,
          max_tokens: 8000,
          system: SYSTEM_PROMPT,
          messages: [{ role: "user", content: buildUserPrompt(req, dayCount) }],
        }),
      });
      if (!resp.ok) throw new ProviderError(`Anthropic returned ${resp.status}`);
      const data = await resp.json();
      const text = (data.content ?? []).map((c: { text?: string }) => c.text ?? "").join("");
      return JSON.parse(stripFences(text));
    }

    if (provider === "gemini") {
      const model = env.AI_MODEL ?? "gemini-2.5-pro";
      const resp = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
        {
          method: "POST",
          signal: controller.signal,
          headers: { "content-type": "application/json" },
          body: JSON.stringify({
            systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
            contents: [{ role: "user", parts: [{ text: buildUserPrompt(req, dayCount) }] }],
            generationConfig: { responseMimeType: "application/json" },
          }),
        },
      );
      if (!resp.ok) throw new ProviderError(`Gemini returned ${resp.status}`);
      const data = await resp.json();
      const text = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
      return JSON.parse(stripFences(text));
    }

    // OpenAI-compatible (also the default fallback).
    const model = env.AI_MODEL ?? "gpt-4o-mini";
    const resp = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      signal: controller.signal,
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model,
        response_format: {
          type: "json_schema",
          json_schema: { name: "itinerary", strict: true, schema: buildSchema(dayCount) },
        },
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: buildUserPrompt(req, dayCount) },
        ],
      }),
    });
    if (!resp.ok) throw new ProviderError(`AI provider returned ${resp.status}`);
    const data = await resp.json();
    const text = data?.choices?.[0]?.message?.content ?? "{}";
    return JSON.parse(stripFences(text));
  } finally {
    clearTimeout(timer);
  }
}

function stripFences(text: string): string {
  return text.trim().replace(/^```(?:json)?\s*/i, "").replace(/```$/, "").trim();
}

class ProviderError extends Error {}
class ProviderUnavailable extends Error {}

/**
 * Hand-rolled validation. The client also validates, but the server is the
 * authority: a malformed generation must never be persisted.
 */
function validatePlan(raw: unknown, dayCount: number, currency: string): Record<string, unknown> {
  if (typeof raw !== "object" || raw === null) throw new ValidationFailure("AI returned a non-object plan.");
  const plan = raw as Record<string, unknown>;

  if (typeof plan.title !== "string" || !plan.title.trim()) {
    throw new ValidationFailure("AI plan is missing a title.");
  }
  if (!Array.isArray(plan.days) || plan.days.length === 0) {
    throw new ValidationFailure("AI plan contains no days.");
  }
  if (plan.days.length > dayCount + 1) {
    throw new ValidationFailure("AI plan contains more days than requested.");
  }

  for (const day of plan.days as Record<string, unknown>[]) {
    for (const slot of ["morning", "afternoon", "evening"] as const) {
      const activities = day[slot];
      if (!Array.isArray(activities)) {
        throw new ValidationFailure(`Day ${day.day_number} is missing ${slot}.`);
      }
      for (const a of activities as Record<string, unknown>[]) {
        if (typeof a.title !== "string" || !a.title.trim()) {
          throw new ValidationFailure(`An activity on day ${day.day_number} has no title.`);
        }
        if (typeof a.estimated_cost_minor !== "number" || a.estimated_cost_minor < 0) {
          throw new ValidationFailure(`Activity "${a.title}" has an invalid cost.`);
        }
        if (typeof a.kind !== "string") {
          throw new ValidationFailure(`Activity "${a.title}" has no kind.`);
        }
        // Any cost the model returns is an estimate. Force the flag on rather
        // than trusting it, so nothing can be mislabelled as a live price.
        a.is_estimate = true;
        if (a.opening_hours_verified !== true) {
          a.opening_hours_verified = false;
          // Do not let an unverified claim of opening hours survive.
          delete a.opening_hours;
        }
        if (a.currency !== currency) a.currency = currency;
      }
    }
    if (typeof day.estimated_cost_minor !== "number" || day.estimated_cost_minor < 0) {
      throw new ValidationFailure(`Day ${day.day_number} has an invalid estimated cost.`);
    }
  }

  if (plan.budget_allocation != null && !Array.isArray(plan.budget_allocation)) {
    throw new ValidationFailure("budget_allocation must be an array.");
  }
  if (plan.packing_list != null && !Array.isArray(plan.packing_list)) {
    throw new ValidationFailure("packing_list must be an array.");
  }
  if (plan.tips != null && !Array.isArray(plan.tips)) {
    throw new ValidationFailure("tips must be an array.");
  }

  plan.disclaimer =
    "AI-generated. Prices, durations and recommendations are estimates, not confirmed quotes. " +
    "Opening hours, availability and entry requirements change — verify everything with official sources before you travel.";

  return plan;
}

Deno.serve(async (req) => {
  const pre = preflight(req);
  if (pre) return withCors(pre);

  const env = getEnv();

  try {
    const auth = await authenticate(env, req);
    if (isResponse(auth)) return withCors(auth);

    const allowed = await rateLimit(auth.service, `ai:${auth.userId}`, 10, 3600);
    if (!allowed) {
      return withCors(
        fail("You have reached the hourly AI generation limit. Try again later.", 429, "rate_limited"),
      );
    }

    let body: GenerateRequest;
    try {
      body = await req.json();
    } catch {
      return withCors(fail("Request body must be valid JSON."));
    }

    if (!Array.isArray(body.destinations) || body.destinations.length === 0) {
      return withCors(fail("At least one destination is required."));
    }
    if (!body.start_date || !body.end_date) {
      return withCors(fail("Start and end dates are required."));
    }

    const start = new Date(body.start_date);
    const end = new Date(body.end_date);
    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()) || end < start) {
      return withCors(fail("End date must be on or after the start date."));
    }
    const dayCount = Math.min(MAX_DAYS, Math.round((end.getTime() - start.getTime()) / 86_400_000) + 1);
    if (dayCount < 1 || dayCount > MAX_DAYS) {
      return withCors(fail(`Trips must be between 1 and ${MAX_DAYS} days for AI planning.`));
    }

    // If the request names a trip, confirm membership before generating so the
    // result can be saved against it.
    if (body.trip_id) {
      const { data: member } = await auth.client
        .from("trip_members")
        .select("trip_id")
        .eq("trip_id", body.trip_id)
        .eq("user_id", auth.userId)
        .eq("status", "active")
        .maybeSingle();
      if (!member) {
        return withCors(fail("You are not a member of that trip.", 403, "forbidden"));
      }
    }

    const startedAt = Date.now();
    const jobId = crypto.randomUUID();

    await auth.service.from("itinerary_generation_jobs").insert({
      id: jobId,
      user_id: auth.userId,
      trip_id: body.trip_id ?? null,
      status: "running",
      provider: env.AI_PROVIDER ?? "openai",
      model: env.AI_MODEL ?? null,
      request: {
        origin: body.origin,
        destinations: body.destinations,
        start_date: body.start_date,
        end_date: body.end_date,
        travelers: body.travelers,
        currency: body.currency,
        travel_style: body.travel_style,
      },
    });

    let raw: unknown;
    try {
      raw = await callProvider(env, body, dayCount);
    } catch (err) {
      const message = err instanceof Error ? err.message : "Unknown provider error";
      await auth.service
        .from("itinerary_generation_jobs")
        .update({ status: "failed", error_message: message, duration_ms: Date.now() - startedAt })
        .eq("id", jobId);

      if (err instanceof ProviderUnavailable) {
        return withCors(
          fail(
            "AI planning is not configured on this deployment. You can build the itinerary manually — every field is editable.",
            503,
            "ai_not_configured",
          ),
        );
      }
      if (err instanceof Error && err.name === "AbortError") {
        return withCors(fail("The AI request timed out. Try a shorter trip or build the itinerary manually.", 504, "timeout"));
      }
      return withCors(fail("The AI provider could not generate a plan. Try again, or build the itinerary manually.", 502, "provider_error"));
    }

    let plan: Record<string, unknown>;
    try {
      plan = validatePlan(raw, dayCount, body.currency.toUpperCase());
    } catch (err) {
      const message = err instanceof Error ? err.message : "Validation failed";
      await auth.service
        .from("itinerary_generation_jobs")
        .update({ status: "failed", error_message: `schema: ${message}`, duration_ms: Date.now() - startedAt })
        .eq("id", jobId);
      return withCors(
        fail(
          "The AI response did not match the expected format. Nothing was saved — try generating again.",
          502,
          "schema_validation_failed",
        ),
      );
    }

    await auth.service
      .from("itinerary_generation_jobs")
      .update({ status: "succeeded", result: plan, duration_ms: Date.now() - startedAt })
      .eq("id", jobId);

    return withCors(
      json({
        job_id: jobId,
        plan,
        generated_at: new Date().toISOString(),
      }),
    );
  } catch (err) {
    console.error("ai-itinerary failed", err);
    return withCors(fail("Something went wrong generating your itinerary.", 500, "internal"));
  }
});

class ValidationFailure extends Error {}
