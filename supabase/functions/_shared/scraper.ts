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

export function parseBoard(html: string, board: { code: string; name: string; url: string }) {
  const rows = [...html.matchAll(/<tr\b[^>]*>[\s\S]*?<\/tr>/gi)].map((match) => match[0]);
  const notices = rows.flatMap((row) => {
    const link = row.match(/<a\b[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/i);
    if (!link) return [];
    const url = new URL(text(link[1]), board.url);
    const sourceIdx = url.hostname === ALLOWED_HOST ? url.searchParams.get("idx") : null;
    if (!sourceIdx) return [];

    const numberText = cell(row, "num").replace(/[^0-9]/g, "");
    const isNotice = /class=["'][^"']*\b(?:notice|isnotice)\b|icon-notice/i.test(row) || numberText.length === 0;
    return [{
      board_code: board.code,
      board_name: board.name,
      source_idx: sourceIdx,
      number: numberText ? Number(numberText) : null,
      title: text(link[2]),
      author: cell(row, "writer"),
      published_at: cell(row, "date"),
      view_count: Number(cell(row, "(?:hit|read)").replaceAll(",", "")) || 0,
      url: url.href,
      is_notice: isNotice,
      importance_status: isNotice ? "true" : null,
      last_seen_at: new Date().toISOString(),
    }];
  });
  if (notices.length === 0) throw new Error("No notices found");
  return notices;
}
