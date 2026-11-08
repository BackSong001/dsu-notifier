import { parseListQuery } from '../../../supabase/functions/_shared/query.ts';
Deno.test('validates limits and cursors and preserves search text', () => {
  const query = parseListQuery(new URL('https://example.com?limit=19&search=a%25_b'));
  if (query.after !== null || query.limit !== 19 || query.search !== 'a%_b') throw new Error('Invalid query');
  for (const value of ['limit=NaN', 'limit=0', 'limit=101', 'cursor=-1', 'cursor=x', 'limit=1.5']) {
    let rejected = false;
    try { parseListQuery(new URL(`https://example.com?${value}`)); } catch { rejected = true; }
    if (!rejected) throw new Error(`Accepted ${value}`);
  }
});

Deno.test('pagination cursors round trip the complete ordering keys', async () => {
  const { noticePage } = await import('../../../supabase/functions/_shared/query.ts');
  const row = {id:'11111111-1111-4111-8111-111111111111', is_notice:true, published_at:'2026-11-08', source_idx:'123'};
  const page = noticePage([row,row],1);
  const query = parseListQuery(new URL('https://example.com?cursor='+encodeURIComponent(page.next_cursor!)));
  if(query.after?.id !== row.id || query.after.pinned !== true) throw new Error('Cursor lost ordering');
});

Deno.test('rejects malformed UUIDs and impossible dates inside cursors', () => {
  for (const cursor of [
    {pinned:true, date:'2026-02-30', source:'123', id:'11111111-1111-4111-8111-111111111111'},
    {pinned:true, date:'2026-11-08', source:'123', id:'------------------------------------'},
  ]) {
    let rejected = false;
    try { parseListQuery(new URL('https://example.com?cursor='+encodeURIComponent(btoa(JSON.stringify(cursor))))); } catch { rejected = true; }
    if (!rejected) throw new Error('Accepted invalid cursor');
  }
});
