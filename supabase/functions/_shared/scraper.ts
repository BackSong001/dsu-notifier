const ALLOWED_HOST = "www.dongseo.ac.kr";

function text(value: string): string {
  return value
    .replaceAll("&amp;", "&")
    .replaceAll("&quot;", '"')
    .replaceAll("&#39;", "'")
    .replaceAll("&lt;", "<")
    .replaceAll("&gt;", ">")
    .replace(/<[^>]+>/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

function cell(row: string, className: string): string {
  const match = row.match(new RegExp(`<td[^>]*class=["'][^"']*\\b${className}\\b[^"']*["'][^>]*>([\\s\\S]*?)</td>`, "i"));
  return match ? text(match[1]) : "";
}

function publishedDate(value: string): string {
  if (!/^\d{1,2}:\d{2}$/.test(value)) return value;
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Seoul",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(new Date());
  const date = Object.fromEntries(parts.map(({ type, value: part }) => [type, part]));
  return `${date.year}-${date.month}-${date.day}`;
}

export function parseBoard(html: string, board: { code: string; name: string; url: string }) {
  const table = html.match(/<table\b[^>]*class=["'][^"']*\bboard-list-table\b[^"']*["'][^>]*>[\s\S]*?<\/table>/i)?.[0];
  if (!table) throw new Error("Invalid board markup");
  const rows = [...table.matchAll(/<tr\b[^>]*>[\s\S]*?<\/tr>/gi)].map((match) => match[0]);
  const parsedNotices = rows.flatMap((row) => {
    const link = row.match(/<a\b[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/i);
    if (!link) {
      if (/class=["'][^"']*\bsubject\b/i.test(row)) throw new Error("Missing notice link");
      return [];
    }
    const url = new URL(text(link[1]), board.url);
    const sourceIdx = url.searchParams.get("idx");
    if (!sourceIdx && !/class=["'][^"']*\bsubject\b/i.test(row)) return [];
    if (url.protocol !== "https:" || url.hostname !== ALLOWED_HOST || url.username || url.password ||
        (url.port && url.port !== "443") || !sourceIdx || !/^\d+$/.test(sourceIdx) || url.searchParams.get("pCode") !== board.code) {
      throw new Error("Invalid notice URL");
    }
    const title = text(link[2]);
    const date = publishedDate(cell(row, "date"));
    if (!title || !/^\d{4}-\d{2}-\d{2}$/.test(date) || Number.isNaN(Date.parse(date))) throw new Error("Invalid notice fields");

    const numberText = cell(row, "num").replace(/[^0-9]/g, "");
    const isNotice = /class=["'][^"']*\b(?:notice|isnotice)\b|icon-notice/i.test(row) || numberText.length === 0;
    return [{
      board_code: board.code,
      board_name: board.name,
      source_idx: sourceIdx,
      number: numberText ? Number(numberText) : null,
      title,
      author: cell(row, "writer"),
      published_at: date,
      view_count: Number(cell(row, "(?:hit|read)").replaceAll(",", "")) || 0,
      url: url.href,
      is_notice: isNotice,
      importance_status: isNotice ? "true" : null,
      last_seen_at: new Date().toISOString(),
    }];
  });
  const notices = [...parsedNotices.reduce((unique, notice) => {
    const existing = unique.get(notice.source_idx);
    if (!existing || notice.is_notice) unique.set(notice.source_idx, notice);
    return unique;
  }, new Map<string, (typeof parsedNotices)[number]>()).values()];
  if (notices.length === 0) throw new Error("No notices found");
  return notices;
}
