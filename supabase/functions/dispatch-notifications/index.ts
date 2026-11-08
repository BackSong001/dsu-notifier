import { createClient } from 'npm:@supabase/supabase-js@2.119.0';
import { importPKCS8, SignJWT } from 'npm:jose@5.10.0';
import { classifyFcmError } from '../_shared/fcm.ts';
const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
async function accessToken() {
  const key = await importPKCS8(Deno.env.get('FCM_PRIVATE_KEY')!.replaceAll('\\n', '\n'), 'RS256');
  const assertion = await new SignJWT({ scope: 'https://www.googleapis.com/auth/firebase.messaging' })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' }).setIssuer(Deno.env.get('FCM_CLIENT_EMAIL')!)
    .setAudience('https://oauth2.googleapis.com/token').setIssuedAt().setExpirationTime('1h').sign(key);
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
    signal: AbortSignal.timeout(15_000),
  });
  if (!response.ok) throw new Error('FCM_AUTH_FAILED');
  return (await response.json()).access_token as string;
}
Deno.serve(async (request) => {
  if (request.method !== 'POST') return new Response('POST is required', { status: 405 });
  const secret = Deno.env.get('DISPATCH_CRON_SECRET') ?? Deno.env.get('SCRAPE_CRON_SECRET');
  if (!secret || request.headers.get('x-cron-secret') !== secret) return new Response('Unauthorized', { status: 401 });
  try {
    const { count, error: countError } = await supabase.from('notification_outbox').select('id', { count: 'exact', head: true }).eq('status', 'pending');
    if (countError) throw new Error('DATABASE_ERROR');
    if (!count) return Response.json({ processed: 0, sent: 0, failed: 0 });
    // 인증 실패는 작업을 획득하기 전에 처리해 정상 기기와 대기열을 보존한다.
    const token = await accessToken();
    const deadline = Date.now() + 45_000;
    let processed = 0;
    let sent = 0;
    let failed = 0;
    while (processed < 20 && Date.now() < deadline) {
      const { data: pending, error } = await supabase.rpc('claim_notifications');
      if (error) throw new Error('DATABASE_ERROR');
      const item = pending?.[0];
      if (!item) break;
      processed++;
      let update: Record<string, unknown>;
      let invalidToken = false;
      try {
        const response = await fetch(`https://fcm.googleapis.com/v1/projects/${Deno.env.get('FCM_PROJECT_ID')}/messages:send`, {
          method: 'POST', headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
          signal: AbortSignal.timeout(15_000),
          body: JSON.stringify({ message: {
            token: item.fcm_token, notification: { title: item.title, body: '새 공지사항이 등록되었습니다.' },
            data: { url: item.url, notice_id: item.notice_id },
            android: { notification: { channel_id: 'new_notices', tag: item.notice_id } },
          } }),
        });
        if (response.ok) {
          update = { status: 'sent', sent_at: new Date().toISOString(), last_error: null };
          sent++;
        } else {
          const result = await response.json().catch(() => ({}));
          const classification = classifyFcmError(response.status, result);
          invalidToken = classification.invalidToken;
          const retry = classification.retry && item.attempts < 3;
          const retrySeconds = Math.max(60 * 2 ** (item.attempts - 1), Number(response.headers.get('retry-after')) || 0);
          update = { status: retry ? 'pending' : 'failed', last_error: classification.code,
            next_attempt_at: new Date(Date.now() + retrySeconds * 1000).toISOString() };
          failed++;
        }
      } catch (_) {
        // 응답을 잃은 요청은 이미 FCM에 수락됐을 수 있으므로 자동 재전송하지 않는다.
        update = { status: 'failed', last_error: 'DELIVERY_UNKNOWN' };
        failed++;
      }
      const { error: updateError } = await supabase.from('notification_outbox').update(update).eq('id', item.id).eq('status', 'sending');
      if (updateError) throw new Error('DELIVERY_RECORD_FAILED');
      if (invalidToken) {
        const { error: deviceError } = await supabase.from('devices').update({ active: false }).eq('device_id', item.device_id).eq('fcm_token', item.fcm_token);
        if (deviceError) throw new Error('DEVICE_UPDATE_FAILED');
      }
    }
    return Response.json({ processed, sent, failed });
  } catch (_) {
    return Response.json({ error: 'DISPATCH_FAILED' }, { status: 500 });
  }
});
