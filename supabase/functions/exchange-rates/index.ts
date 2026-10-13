// Exchange-rate proxy + cache.
//
// The provider key stays on the server. Rates are stored with a provider name
// and a fetch timestamp so the client can always say how old a rate is, and
// never labels a cached rate as live.
//
// Default provider is Frankfurter (https://frankfurter.app), which needs no
// key and publishes ECB reference rates. Set EXCHANGE_RATE_PROVIDER /
// EXCHANGE_RATE_API_KEY to use a commercial feed instead.

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

/** Rates older than this are returned but flagged stale. */
const STALE_AFTER_MS = 6 * 60 * 60 * 1000; // 6 hours
/** Rates older than this are refused for a "live" conversion. */
const MAX_AGE_MS = 30 * 24 * 60 * 60 * 1000; // 30 days

interface StoredRate {
  base_currency: string;
  quote_currency: string;
  rate: string;
  provider: string;
  fetched_at: string;
  is_indicative: boolean;
}

function cors(): Response {
  return withCors(json({}));
}

async function fetchFromFrankfurter(base: string, quotes: string[]): Promise<Record<string, number>> {
  const url = `https://api.frankfurter.app/latest?from=${base}&to=${quotes.join(",")}`;
  const resp = await fetch(url, { headers: { accept: "application/json" } });
  if (!resp.ok) throw new Error(`frankfurter returned ${resp.status}`);
  const data = await resp.json();
  const out: Record<string, number> = {};
  for (const [code, value] of Object.entries(data.rates ?? {})) {
    out[code] = Number(value);
  }
  return out;
}

async function fetchFromOpenExchangeRates(
  env: Env,
  base: string,
  quotes: string[],
): Promise<Record<string, number>> {
  if (!env.EXCHANGE_RATE_API_KEY) {
    throw new Error("EXCHANGE_RATE_API_KEY is not configured");
  }
  const url =
    `https://openexchangerates.org/api/latest.json?app_id=${env.EXCHANGE_RATE_API_KEY}` +
    `&base=${base}&symbols=${quotes.join(",")}`;
  const resp = await fetch(url);
  if (!resp.ok) throw new Error(`openexchangerates returned ${resp.status}`);
  const data = await resp.json();
  const out: Record<string, number> = {};
  for (const [code, value] of Object.entries(data.rates ?? {})) {
    out[code] = Number(value);
  }
  return out;
}

async function fetchFromFixer(env: Env, base: string, quotes: string[]): Promise<Record<string, number>> {
  if (!env.EXCHANGE_RATE_API_KEY) throw new Error("EXCHANGE_RATE_API_KEY is not configured");
  const url = `https://data.fixer.io/api/latest?access_key=${env.EXCHANGE_RATE_API_KEY}&base=${base}&symbols=${quotes.join(",")}`;
  const resp = await fetch(url);
  if (!resp.ok) throw new Error(`fixer returned ${resp.status}`);
  const data = await resp.json();
  const out: Record<string, number> = {};
  for (const [code, value] of Object.entries(data.rates ?? {})) {
    out[code] = Number(value);
  }
  return out;
}

async function fetchRates(
  env: Env,
  base: string,
  quotes: string[],
): Promise<{ rates: Record<string, number>; provider: string }> {
  const provider = (env.EXCHANGE_RATE_PROVIDER ?? "frankfurter").toLowerCase();
  switch (provider) {
    case "openexchangerates":
    case "oer":
      return { rates: await fetchFromOpenExchangeRates(env, base, quotes), provider: "openexchangerates" };
    case "fixer":
      return { rates: await fetchFromFixer(env, base, quotes), provider: "fixer" };
    case "frankfurter":
    default:
      return { rates: await fetchFromFrankfurter(base, quotes), provider: "frankfurter" };
  }
}

Deno.serve(async (req) => {
  const pre = preflight(req);
  if (pre) return withCors(pre);

  const env = getEnv();

  try {
    const auth = await authenticate(env, req, { allowAnonymous: true });
    if (isResponse(auth)) return withCors(auth);

    const url = new URL(req.url);
    const action = url.searchParams.get("action") ?? "rates";

    // ---- GET /?action=rates&base=USD&quotes=EUR,GBP -----------------------
    if (req.method === "GET" && action === "rates") {
      const base = (url.searchParams.get("base") ?? "USD").toUpperCase();
      const quotes = (url.searchParams.get("quotes") ?? "")
        .split(",")
        .map((q) => q.trim().toUpperCase())
        .filter(Boolean)
        .slice(0, 60);

      if (!/^[A-Z]{3}$/.test(base) || quotes.some((q) => !/^[A-Z]{3}$/.test(q))) {
        return withCors(fail("Currencies must be three-letter ISO 4217 codes."));
      }

      const allowed = await rateLimit(auth.service, "fx:rates", 120, 3600);
      if (!allowed) {
        return withCors(fail("Too many rate requests. Try again shortly.", 429, "rate_limited"));
      }

      // 1. Try the database cache first.
      const { data: cached } = await auth.service
        .from("exchange_rates")
        .select("base_currency, quote_currency, rate, provider, fetched_at, is_indicative")
        .eq("base_currency", base)
        .in("quote_currency", quotes.length ? quotes : ["USD"])
        .order("fetched_at", { ascending: false });

      const byQuote = new Map<string, StoredRate>();
      for (const row of cached ?? []) {
        if (!byQuote.has(row.quote_currency)) byQuote.set(row.quote_currency, row as StoredRate);
      }

      const wanted = quotes.length ? quotes : [base];
      const missing = wanted.filter((q) => !byQuote.has(q) || q === base);
      const allPresent = wanted.every((q) => byQuote.has(q));
      const oldest = [...byQuote.values()]
        .map((r) => new Date(r.fetched_at).getTime())
        .sort((a, b) => a - b)[0];

      const cacheIsFresh =
        allPresent && oldest != null && Date.now() - oldest < STALE_AFTER_MS;

      if (!cacheIsFresh && missing.length > 0) {
        try {
          const { rates, provider } = await fetchRates(env, base, missing);
          const rows = Object.entries(rates).map(([quote, rate]) => ({
            base_currency: base,
            quote_currency: quote,
            rate,
            provider,
            is_indicative: true,
            fetched_at: new Date().toISOString(),
          }));
          if (rows.length) {
            await auth.service.from("exchange_rates").insert(rows);
            for (const row of rows) byQuote.set(row.quote_currency, row as unknown as StoredRate);
          }
        } catch (err) {
          // The provider is down. Fall back to whatever we already have, and
          // say so plainly rather than pretending the data is fresh.
          console.warn("fx provider unavailable, serving cache", err);
          if (!allPresent) {
            return withCors(
              fail(
                "Live exchange rates are unavailable and no recent cached rate exists for this pair. Offline conversion is disabled until the app next connects.",
                503,
                "provider_unavailable",
              ),
            );
          }
        }
      }

      const results = wanted.map((quote) => {
        if (quote === base) {
          return {
            quote,
            rate: 1,
            provider: "identity",
            fetched_at: new Date().toISOString(),
            is_indicative: true,
            is_cached: false,
          };
        }
        const row = byQuote.get(quote);
        if (!row) return null;
        const age = Date.now() - new Date(row.fetched_at).getTime();
        return {
          quote,
          rate: Number(row.rate),
          provider: row.provider,
          fetched_at: row.fetched_at,
          is_indicative: row.is_indicative ?? true,
          is_cached: true,
          is_stale: age > STALE_AFTER_MS,
          age_minutes: Math.round(age / 60_000),
        };
      }).filter(Boolean);

      return withCors(
        json({
          base,
          rates: results,
          fetched_at: new Date().toISOString(),
          notice:
            "Reference mid-market rate. Your bank, card issuer or exchange counter may apply a different rate and fees.",
        }),
      );
    }

    // ---- POST /  { conversion, persist to history } -----------------------
    if (req.method === "POST") {
      if (!auth.userId) {
        return withCors(fail("Sign in to save conversion history.", 401, "unauthenticated"));
      }
      const allowed = await rateLimit(auth.service, `fx:convert:${auth.userId}`, 300, 3600);
      if (!allowed) {
        return withCors(fail("Too many conversions. Try again shortly.", 429, "rate_limited"));
      }

      let body: {
        from?: string;
        to?: string;
        amount_minor?: number;
        save?: boolean;
        fee_estimate_pct?: number;
      };
      try {
        body = await req.json();
      } catch {
        return withCors(fail("Request body must be valid JSON."));
      }

      const from = (body.from ?? "").toUpperCase();
      const to = (body.to ?? "").toUpperCase();
      const amount = Number(body.amount_minor ?? 0);

      if (!/^[A-Z]{3}$/.test(from) || !/^[A-Z]{3}$/.test(to)) {
        return withCors(fail("Currencies must be three-letter ISO 4217 codes."));
      }
      if (!Number.isFinite(amount) || amount <= 0) {
        return withCors(fail("Amount must be greater than zero."));
      }

      let rate = 1;
      let provider = "identity";
      let fetchedAt = new Date().toISOString();
      let isCached = false;
      let isStale = false;

      if (from !== to) {
        const { data } = await auth.service
          .from("exchange_rates")
          .select("rate, provider, fetched_at")
          .eq("base_currency", from)
          .eq("quote_currency", to)
          .order("fetched_at", { ascending: false })
          .limit(1)
          .maybeSingle();

        if (!data) {
          return withCors(
            fail(
              "No exchange rate is available for this pair yet. Connect and try again, or use the converter once the app has synced rates.",
              404,
              "rate_unavailable",
            ),
          );
        }
        const age = Date.now() - new Date(data.fetched_at).getTime();
        if (age > MAX_AGE_MS) {
          return withCors(
            fail(
              "The cached rate for this pair is too old to convert against. Reconnect to refresh it.",
              409,
              "rate_too_old",
            ),
          );
        }
        rate = Number(data.rate);
        provider = data.provider;
        fetchedAt = data.fetched_at;
        isCached = true;
        isStale = age > STALE_AFTER_MS;

        // Also try an inverse quote before giving up.
        if (Number.isNaN(rate) || rate <= 0) {
          const { data: inverse } = await auth.service
            .from("exchange_rates")
            .select("rate, provider, fetched_at")
            .eq("base_currency", to)
            .eq("quote_currency", from)
            .order("fetched_at", { ascending: false })
            .limit(1)
            .maybeSingle();
          if (inverse) {
            rate = 1 / Number(inverse.rate);
            provider = inverse.provider;
            fetchedAt = inverse.fetched_at;
          }
        }
      }

      // Rounding to the destination's minor units happens client-side with
      // exact decimal arithmetic; here we return the unrounded major value.
      const convertedMajor = (amount / 100) * rate;

      if (body.save) {
        await auth.service.from("currency_conversion_history").insert({
          user_id: auth.userId,
          from_currency: from,
          to_currency: to,
          input_minor: Math.round(amount),
          output_minor: Math.round(convertedMajor * 100),
          rate,
          provider,
          is_indicative: true,
          is_offline_cached: isCached,
          fee_estimate_pct: body.fee_estimate_pct ?? null,
        });
      }

      return withCors(
        json({
          from,
          to,
          input_minor: Math.round(amount),
          converted_major: convertedMajor,
          rate,
          provider,
          fetched_at: fetchedAt,
          is_cached: isCached,
          is_stale: isStale,
          notice: isCached
            ? isStale
              ? "This is a cached rate, not a live quote. Your bank or exchange counter may differ."
              : "Cached reference rate. Fees and spreads from your provider are not included."
            : "Identity conversion — no exchange needed.",
        }),
      );
    }

    void cors;
    return withCors(fail("Unsupported request.", 405, "method_not_allowed"));
  } catch (err) {
    console.error("exchange-rates failed", err);
    return withCors(fail("Currency service is temporarily unavailable.", 500, "internal"));
  }
});
