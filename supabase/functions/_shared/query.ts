type Cursor = { pinned: boolean; date: string; source: string; id: string };
export function parseListQuery(url: URL) {
  const limit = Number(url.searchParams.get('limit') ?? 20);
  const search = (url.searchParams.get('search') ?? '').trim();
  if (!Number.isSafeInteger(limit) || limit < 1 || limit > 100 || search.length > 200) throw new Error('INVALID_QUERY');
  let after: Cursor | null = null;
  const cursor = url.searchParams.get('cursor');
  if (cursor !== null) {
    try {
      if (cursor.length > 512) throw new Error();
      after = JSON.parse(atob(cursor));
      if (!after || typeof after.pinned !== 'boolean' || !/^\d{4}-\d{2}-\d{2}$/.test(after.date) || !/^\d+$/.test(after.source) || !/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(after.id) || !Number.isFinite(Date.parse(after.date)) || new Date(after.date).toISOString().slice(0,10) !== after.date || after.source.length > 32) throw new Error();
    } catch { throw new Error('INVALID_CURSOR'); }
  }
  return { limit, after, search };
}
export function noticePage(items: Record<string, unknown>[], limit: number) {
  const page = items.slice(0, limit);
  const last = page.at(-1);
  return { items: page, next_cursor: items.length > limit && last ? btoa(JSON.stringify({ pinned: last.is_notice, date: last.published_at, source: last.source_idx, id: last.id })) : null };
}
