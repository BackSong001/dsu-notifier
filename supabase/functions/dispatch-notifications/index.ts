import { createClient } from "npm:@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "npm:jose@5";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

function authorized(request: Request): boolean {
  const secret = Deno.env.get("DISPATCH_CRON_SECRET") ?? Deno.env.get("SCRAPE_CRON_SECRET");
  return Boolean(secret && request.headers.get("x-cron-secret") === secret);
}

async function accessToken(projectId: string, email: string, privateKey: string): Promise<string> {
  const key = await importPKCS8(privateKey.replaceAll("\\n", "\n"), "RS256");
  const assertion = await new SignJWT({ scope: "https://www.googleapis.com/auth/firebase.messaging" })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(email)
    .setSubject(email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt()
    .setExpirationTime("1h")
    .sign(key);
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion }),
  });
  if (!response.ok) throw new Error(`FCM OAuth HTTP ${response.status}`);
  return (await response.json()).access_token;
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return new Response("POST is required", { status: 405 });
  if (!authorized(request)) return new Response("Unauthorized", { status: 401 });

  const { data: pending, error } = await supabase
    .from("notification_outbox")
    .select("id, notice_id, device_id, attempts, notices(title, url), devices(fcm_token)")
    .eq("status", "pending")
    .lt("attempts", 3)
    .limit(100);
  if (error) return Response.json({ error: error.message }, { status: 500 });

  const projectId = Deno.env.get("FCM_PROJECT_ID")!;
  const token = await accessToken(projectId, Deno.env.get("FCM_CLIENT_EMAIL")!, Deno.env.get("FCM_PRIVATE_KEY")!);
  let sent = 0;
  let failed = 0;
  for (const item of pending ?? []) {
    const notice = Array.isArray(item.notices) ? item.notices[0] : item.notices;
    const device = Array.isArray(item.devices) ? item.devices[0] : item.devices;
    const response = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({ message: { token: device.fcm_token, notification: { title: notice.title, body: "새 공지사항이 등록되었습니다." }, data: { url: notice.url, notice_id: item.notice_id } } }),
    });
    if (response.ok) {
      await supabase.from("notification_outbox").update({ status: "sent", attempts: item.attempts + 1, sent_at: new Date().toISOString() }).eq("id", item.id);
      sent += 1;
    } else {
      const lastError = `FCM HTTP ${response.status}`;
      await supabase.from("notification_outbox").update({ status: item.attempts + 1 >= 3 ? "failed" : "pending", attempts: item.attempts + 1, last_error: lastError }).eq("id", item.id);
      if (response.status === 401 || response.status === 404) await supabase.from("devices").update({ active: false }).eq("device_id", item.device_id);
      failed += 1;
    }
  }
  return Response.json({ processed: (pending ?? []).length, sent, failed });
});
