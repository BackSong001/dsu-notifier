function toResponse(notice) {
  return {
    id: notice.id,
    board_code: notice.boardCode,
    board_name: notice.boardName,
    source_idx: notice.sourceIdx,
    number: notice.number,
    title: notice.title,
    author: notice.author,
    published_at: notice.publishedAt,
    view_count: notice.viewCount,
    url: notice.url,
    is_notice: notice.isNotice,
    importance_status: notice.importanceStatus,
  };
}

export function getNotices(store, requestUrl) {
  const url = requestUrl instanceof URL ? requestUrl : new URL(requestUrl);
  const limit = Number(url.searchParams.get('limit') ?? 20);
  const notices = store.list({
    boardCode: url.searchParams.get('board_code') || undefined,
    limit: Number.isInteger(limit) && limit > 0 ? limit : 20,
  });
  return { status: 200, body: { items: notices.map(toResponse), next_cursor: null } };
}
