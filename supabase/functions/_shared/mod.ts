// Shared helpers for every TripSplit World Edge Function.
// Deno + Supabase Edge Runtime.

import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";

export interface Env {
  SUPABASE_URL: string;
  SUPABASE_ANON_KEY: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  EXCHANGE_RATE_PROVIDER?: string;
  EXCHANGE_RATE_API_KEY?: string;
  AI_PROVIDER?: string;
  AI_API_KEY?: string;
  AI_MODEL?: string;
  RESEND_API_KEY?: string;
  EMAIL_FROM?: string;
  APP_URL?: string;
}

export function getEnv(): Env {
  return {
    SUPABASE_URL: Deno.env.get("SUPABASE_URL") ?? "",
    SUPABASE_ANON_KEY: Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    SUPABASE_SERVICE_ROLE_KEY: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    EXCHANGE_RATE_PROVIDER: Deno.env.get("EXCHANGE_RATE_PROVIDER"),
    EXCHANGE_RATE_API_KEY: Deno.env.get("EXCHANGE_RATE_API_KEY"),
    AI_PROVIDER: Deno.env.get("AI_PROVIDER"),
    AI_API_KEY: Deno.env.get("AI_API_KEY"),
    AI_MODEL: Deno.env.get("AI_MODEL"),
    RESEND_API_KEY: Deno.env.get("RESEND_API_KEY"),
    EMAIL_FROM: Deno.env.get("EMAIL_FROM"),
    APP_URL: Deno.env.get("APP_URL"),
  };
}

/** Service-role client. NEVER returned to a client, never logged. */
export function serviceClient(env: Env): SupabaseClient {
  return createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

/**
 * Client that carries the *caller's* JWT, so every query goes through their
 * Row Level Security policies. Use this instead of the service role whenever
 * the operation touches user data.
 */
export function userClient(env: Env, authHeader: string): SupabaseClient {
  return createClient(env.SUPABASE_URL, env.SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export function json(body: unknown, status = 200, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      ...headers,
    },
  });
}

export function fail(message: string, status = 400, code?: string): Response {
  return json({ error: { message, code: code ?? "bad_request" } }, status);
}

export interface RequestContext {
  userId: string;
  client: SupabaseClient;
  service: SupabaseClient;
  requestId: string;
}

/**
 * Verifies the bearer token and returns a context with an RLS-scoped client.
 * Anonymous callers are rejected unless `allowAnonymous` is set.
 */
export async function authenticate(
  env: Env,
  req: Request,
  options: { allowAnonymous?: boolean } = {},
): Promise<RequestContext | Response> {
  const authHeader = req.headers.get("Authorization") ?? "";
  const requestId = crypto.randomUUID();

  if (!authHeader.startsWith("Bearer ")) {
    if (options.allowAnonymous) {
      return {
        userId: "",
        client: userClient(env, "Bearer invalid-anonymous"),
        service: serviceClient(env),
        requestId,
      };
    }
    return fail("Authentication required.", 401, "unauthenticated");
  }

  const client = userClient(env, authHeader);
  const { data, error } = await client.auth.getUser();

  if (error || !data?.user) {
    if (options.allowAnonymous) {
      return {
        userId: "",
        client,
        service: serviceClient(env),
        requestId,
      };
    }
    return fail("Your session has expired. Please sign in again.", 401, "unauthenticated");
  }

  return {
    userId: data.user.id,
    client,
    service: serviceClient(env),
    requestId,
  };
}

export function isResponse(value: unknown): value is Response {
  return value instanceof Response;
}

/** Minimal fixed-window rate limiter backed by Postgres. */
export async function rateLimit(
  service: SupabaseClient,
  bucket: string,
  limit: number,
  windowSeconds: number,
): Promise<boolean> {
  const { error } = await service.rpc("check_rate_limit", {
    p_bucket: bucket,
    p_limit: limit,
    p_window_seconds: windowSeconds,
  });
  // Fail closed on error so an outage cannot open an unlimited path.
  return !error;
}

export const CORS_HEADERS: Record<string, string> = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, GET, OPTIONS",
};

export function preflight(req: Request): Response | null {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  return null;
}

export function withCors(resp: Response): Response {
  const headers = new Headers(resp.headers);
  for (const [k, v] of Object.entries(CORS_HEADERS)) headers.set(k, v);
  return new Response(resp.body, { status: resp.status, headers });
}

/** Fetches the user profile attached to an auth user id. */
export async function loadProfile(
  service: SupabaseClient,
  userId: string,
): Promise<Record<string, unknown> | null> {
  const { data, error } = await service
    .from("profiles")
    .select("*")
    .eq("id", userId)
    .maybeSingle();
  return error ? null : data;
}
