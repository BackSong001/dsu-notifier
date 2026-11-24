import { createClient } from 'npm:@supabase/supabase-js@2.119.0';
import { BOARDS, corsHeaders } from '../_shared/boards.ts';
import { parseListQuery, noticePage } from '../_shared/query.ts';

const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
}
async function body(request: Request) { try { return await request.json(); } catch { return null; } }
const uuid = /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;
Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  const url = new URL(request.url);
  const path = url.pathname.replace(/^\/(functions\/v1\/)?devices/, '') || '/';
  const secret = request.headers.get('x-device-secret') ?? '';
  if (!/^[A-Za-z0-9_=-]{43,128}$/.test(secret)) return json({ error: 'UNAUTHORIZED', message: '디바이스 인증이 필요합니다.' }, 401);
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(secret));
  const hash = Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2, '0')).join('');

  if (request.method === 'POST' && path === '/register') {
    const value = await body(request);
    if (!uuid.test(value?.device_id ?? '') || typeof value?.fcm_token !== 'string' || !value.fcm_token.trim() || value.fcm_token.length > 4096 || !['android', 'ios'].includes(value.platform)) {
      return json({ error: 'INVALID_DEVICE', message: '디바이스 등록 정보를 확인해 주세요.' }, 400);
    }
    const { data, error } = await supabase.rpc('register_device', { device_id_input: value.device_id, token_input: value.fcm_token, platform_input: value.platform, hash_input: hash });
    if (error) return json({ error: 'DATABASE_ERROR', message: '디바이스 등록에 실패했습니다.' }, 500);
    if (!data) return json({ error: 'UNAUTHORIZED', message: '디바이스 인증에 실패했습니다.' }, 401);
    return json({ device_id: value.device_id, registered: true });
  }
  const match = path.match(/^\/([^/]+)(?:\/(preferences|notice-preferences|saved-notices))?$/);
  if (!match || !uuid.test(match[1])) return json({ error: 'NOT_FOUND', message: '요청 경로를 확인해 주세요.' }, 404);
  const deviceId = match[1];
  const { data: device, error: authError } = await supabase.from('devices').select('device_id').eq('device_id', deviceId).eq('secret_hash', hash).eq('active', true).maybeSingle();
  if (authError) return json({ error: 'DATABASE_ERROR', message: '디바이스 확인에 실패했습니다.' }, 500);
  if (!device) return json({ error: 'UNAUTHORIZED', message: '디바이스 인증에 실패했습니다.' }, 401);
  const route = match[2];
  if (request.method === 'GET' && route === 'saved-notices') {
    let options;
    try { options = parseListQuery(url); } catch { return json({ error: 'INVALID_QUERY', message: '조회 조건을 확인해 주세요.' }, 400); }
    const { limit, after, search } = options;

    const { data: savedIdsData, error: savedIdsError } = await supabase.from('notice_alarm_preferences')
      .select('notice_id').eq('device_id', deviceId).eq('enabled', true);
    if (savedIdsError) return json({ error: 'DATABASE_ERROR', message: '저장 공지 조회에 실패했습니다.' }, 500);
    const savedIds = (savedIdsData ?? []).map((r: { notice_id: string }) => r.notice_id);
    if (savedIds.length === 0) return json({ items: [], next_cursor: null, total_count: 0 });

    const [pageRes, countRes] = await Promise.all([
      supabase.rpc('list_notice_page', {
        board_input: null, device_input: deviceId, search_input: search, after_input: after, limit_input: limit + 1,
      }),
      (() => {
        const q = supabase.from('notices').select('*', { count: 'exact', head: true })
          .in('id', savedIds)
          .or('importance_status.is.null,importance_status.neq.failed');
        if (search) q.ilike('title', `%${search}%`);
        return q;
      })(),
    ]);

    if (pageRes.error) return json({ error: 'DATABASE_ERROR', message: '저장 공지 조회에 실패했습니다.' }, 500);
    const response = noticePage(pageRes.data ?? [], limit);
    return json({ ...response, total_count: countRes.count ?? 0 });
  }
  if (route === 'preferences') {
    if (request.method === 'GET') {
      const { data, error } = await supabase.from('notification_preferences').select('board_code, enabled').eq('device_id', deviceId);
      if (error) return json({ error: 'DATABASE_ERROR', message: '알림 설정 조회에 실패했습니다.' }, 500);
      return json({ boards: Object.fromEntries((data ?? []).map(row => [row.board_code, row.enabled])) });
    }
    if (request.method === 'PUT') {
      const value = await body(request);
      if (!value?.boards || typeof value.boards !== 'object' || Array.isArray(value.boards) || Object.entries(value.boards).some(([code, enabled]) => !BOARDS.some(board => board.code === code) || typeof enabled !== 'boolean')) return json({ error: 'INVALID_PREFERENCES', message: '게시판과 알림 설정을 확인해 주세요.' }, 400);
      const rows = Object.entries(value.boards).map(([board_code, enabled]) => ({ device_id: deviceId, board_code, enabled }));
      const { error } = rows.length ? await supabase.from('notification_preferences').upsert(rows) : { error: null };
      return error ? json({ error: 'DATABASE_ERROR', message: '설정 저장에 실패했습니다.' }, 500) : json({ saved: true });
    }
  }
  if (route === 'notice-preferences') {
    if (request.method === 'GET') {
      const { data, error } = await supabase.from('notice_alarm_preferences').select('notice_id').eq('device_id', deviceId).eq('enabled', true);
      return error ? json({ error: 'DATABASE_ERROR', message: '저장 상태 조회에 실패했습니다.' }, 500) : json({ notice_ids: (data ?? []).map(row => row.notice_id) });
    }
    if (request.method === 'PUT') {
      const value = await body(request);
      if (!uuid.test(value?.notice_id ?? '') || typeof value?.enabled !== 'boolean') return json({ error: 'INVALID_NOTICE_PREFERENCE', message: '공지와 저장 상태를 확인해 주세요.' }, 400);
      const { error } = await supabase.from('notice_alarm_preferences').upsert({ device_id: deviceId, notice_id: value.notice_id, enabled: value.enabled });
      return error ? json({ error: 'DATABASE_ERROR', message: '공지 저장에 실패했습니다.' }, 500) : json({ saved: true });
    }
  }
  if (request.method === 'DELETE' && !route) {
    const { error } = await supabase.from('devices').update({ active: false }).eq('device_id', deviceId);
    return error ? json({ error: 'DATABASE_ERROR', message: '디바이스 해제에 실패했습니다.' }, 500) : new Response(null, { status: 204, headers: corsHeaders });
  }
  return json({ error: 'METHOD_NOT_ALLOWED', message: '지원하지 않는 요청입니다.' }, 405);
});
