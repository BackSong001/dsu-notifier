import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/boards.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function body(request: Request) {
  try {
    return await request.json();
  } catch {
    return null;
  }
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  const path = new URL(request.url).pathname.replace(/^\/functions\/v1\/devices/, "").replace(/^\/devices/, "") || "/";

  if (request.method === "POST" && path === "/register") {
    const value = await body(request);
    if (!value?.device_id || !value?.fcm_token || !["android", "ios"].includes(value.platform)) {
      return json({ error: "INVALID_DEVICE", message: "device_id, fcm_token, and platform are required" }, 400);
    }
    const { error } = await supabase.from("devices").upsert({
      device_id: value.device_id,
      fcm_token: value.fcm_token,
      platform: value.platform,
      active: true,
      updated_at: new Date().toISOString(),
    });
    if (error) return json({ error: "DATABASE_ERROR", message: error.message }, 500);
    return json({ device_id: value.device_id, registered: true });
  }

  const preferenceMatch = path.match(/^\/([^/]+)\/preferences$/);
  if (request.method === "GET" && preferenceMatch) {
    const { data, error } = await supabase
      .from("notification_preferences")
      .select("board_code, enabled")
      .eq("device_id", preferenceMatch[1]);
    if (error) return json({ error: "DATABASE_ERROR", message: error.message }, 500);
    return json({
      boards: Object.fromEntries((data ?? []).map((item) => [item.board_code, item.enabled])),
    });
  }
  if (request.method === "PUT" && preferenceMatch) {
    const value = await body(request);
    if (!value?.boards || typeof value.boards !== "object" || Array.isArray(value.boards)) {
      return json({ error: "INVALID_PREFERENCES", message: "boards must be an object" }, 400);
    }
    const rows = Object.entries(value.boards).map(([board_code, enabled]) => ({
      device_id: preferenceMatch[1],
      board_code,
      enabled: enabled === true,
    }));
    const { error } = rows.length
      ? await supabase.from("notification_preferences").upsert(rows)
      : { error: null };
    if (error) return json({ error: "DATABASE_ERROR", message: error.message }, 500);
    return json({ saved: true });
  }

  const noticePreferenceMatch = path.match(/^\/([^/]+)\/notice-preferences$/);
  if (request.method === "GET" && noticePreferenceMatch) {
    const { data, error } = await supabase
      .from("notice_alarm_preferences")
      .select("notice_id")
      .eq("device_id", noticePreferenceMatch[1])
      .eq("enabled", true);
    if (error) return json({ error: "DATABASE_ERROR", message: error.message }, 500);
    return json({ notice_ids: (data ?? []).map((item) => item.notice_id) });
  }
  if (request.method === "PUT" && noticePreferenceMatch) {
    const value = await body(request);
    if (typeof value?.notice_id !== "string" || typeof value?.enabled !== "boolean") {
      return json({ error: "INVALID_NOTICE_PREFERENCE", message: "notice_id and enabled are required" }, 400);
    }
    const { error } = await supabase.from("notice_alarm_preferences").upsert({
      device_id: noticePreferenceMatch[1],
      notice_id: value.notice_id,
      enabled: value.enabled,
    });
    if (error) return json({ error: "DATABASE_ERROR", message: error.message }, 500);
    return json({ saved: true });
  }

  const deviceMatch = path.match(/^\/([^/]+)$/);
  if (request.method === "DELETE" && deviceMatch) {
    const { error } = await supabase.from("devices").update({ active: false }).eq("device_id", deviceMatch[1]);
    if (error) return json({ error: "DATABASE_ERROR", message: error.message }, 500);
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  return json({ error: "NOT_FOUND", message: "Device route not found" }, 404);
});
