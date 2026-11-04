const ALLOWED_HOST = 'www.dongseo.ac.kr';

function decodeHtml(value) {
  return value
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replace(/<[^>]+>/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function cell(row, name) {
  const match = row.match(new RegExp(`<td[^>]*class=["'][^"']*\\b${name}\\b[^"']*["'][^>]*>([\\s\\S]*?)</td>`, 'i'));
  return match ? decodeHtml(match[1]) : '';
}

function publishedDate(value) {
  if (!/^\d{1,2}:\d{2}$/.test(value)) return value;
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Seoul',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(new Date());
  const date = Object.fromEntries(parts.map(({ type, value: part }) => [type, part]));
  return `${date.year}-${date.month}-${date.day}`;
}

export function parseBoard(html, { boardCode, boardName, pageUrl }) {
  const rows = [...html.matchAll(/<tr\b[^>]*>([\s\S]*?)<\/tr>/gi)].map((match) => match[0]);
  const parsedNotices = rows.flatMap((row) => {
    const link = row.match(/<a\b[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/i);
    if (!link) return [];

    const url = new URL(decodeHtml(link[1]), pageUrl);
    if (url.hostname !== ALLOWED_HOST || !url.searchParams.get('idx')) return [];

    const numberText = cell(row, 'num').replace(/[^0-9]/g, '');
    const isNotice = /class=["'][^"']*\b(?:notice|isnotice)\b|icon-notice/i.test(row) || numberText.length === 0;
    return [{
      boardCode,
      boardName,
      sourceIdx: url.searchParams.get('idx'),
      number: numberText ? Number(numberText) : null,
      title: decodeHtml(link[2]),
      author: cell(row, 'writer'),
      publishedAt: publishedDate(cell(row, 'date')),
      viewCount: Number(cell(row, '(?:hit|read)').replaceAll(',', '')) || 0,
      url: url.href,
      isNotice,
      importanceStatus: isNotice ? 'true' : null,
    }];
  });
  const notices = [...parsedNotices.reduce((unique, notice) => {
    const existing = unique.get(notice.sourceIdx);
    if (!existing || notice.isNotice) unique.set(notice.sourceIdx, notice);
    return unique;
  }, new Map()).values()];

  if (notices.length === 0) throw new Error('No notices found');
  return notices;
}

export async function fetchBoard(board, fetchImpl = fetch) {
  const response = await fetchImpl(board.url);
  if (!response.ok) throw new Error(`HTTP ${response.status}`);
  return parseBoard(await response.text(), {
    boardCode: board.code,
    boardName: board.name,
    pageUrl: board.url,
  });
}
