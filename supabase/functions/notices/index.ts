import { createClient } from 'npm:@supabase/supabase-js@2.119.0';
import { BOARDS, corsHeaders } from '../_shared/boards.ts';
import { parseListQuery, noticePage } from '../_shared/query.ts';

const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
}
Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'GET') return json({ error: 'METHOD_NOT_ALLOWED', message: 'GET 요청만 가능합니다.' }, 405);
  const url = new URL(request.url);
  const path = url.pathname.replace(/^\/(functions\/v1\/)?notices/, '');
  if (path && path !== '/') {
    const id = path.slice(1);
    if (!/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(id)) return json({ error: 'INVALID_ID', message: '공지 ID를 확인해 주세요.' }, 400);
    const { data, error } = await supabase.from('notices').select('*').eq('id', id).maybeSingle();
    if (error) return json({ error: 'DATABASE_ERROR', message: '공지 조회에 실패했습니다.' }, 500);
    return data ? json(data) : json({ error: 'NOT_FOUND', message: '공지를 찾을 수 없습니다.' }, 404);
  }
  let options;
  try { options = parseListQuery(url); } catch { return json({ error: 'INVALID_QUERY', message: '조회 조건을 확인해 주세요.' }, 400); }
  const { limit, after, search } = options;
  const board = url.searchParams.get('board_code');
  if (board && !BOARDS.some(item => item.code === board)) return json({ error: 'INVALID_BOARD', message: '게시판을 확인해 주세요.' }, 400);
  const { data, error } = await supabase.rpc('list_notice_page', {
    board_input: board, device_input: null, search_input: search, after_input: after, limit_input: limit + 1,
  });
  if (error) return json({ error: 'DATABASE_ERROR', message: '목록 조회에 실패했습니다.' }, 500);
  return json(noticePage(data ?? [], limit));
});
