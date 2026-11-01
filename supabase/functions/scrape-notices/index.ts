import { createClient } from "npm:@supabase/supabase-js@2";
import { BOARDS } from "../_shared/boards.ts";
import { parseBoard } from "../_shared/scraper.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

function authorized(request: Request): boolean {
  const secret = Deno.env.get("SCRAPE_CRON_SECRET");
  return Boolean(secret && request.headers.get("x-cron-secret") === secret);
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return new Response("POST is required", { status: 405 });
  if (!authorized(request)) return new Response("Unauthorized", { status: 401 });

  const results = [];
  for (const board of BOARDS) {
    const startedAt = new Date().toISOString();
    try {
      const response = await fetch(board.url);
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const notices = parseBoard(await response.text(), board);
      const { data, error } = await supabase
        .from("notices")
        .upsert(notices, { onConflict: "board_code,source_idx" })
        .select("id, source_idx, is_notice");
      if (error) throw error;
      for (const notice of data ?? []) {
        const { error: enqueueError } = await supabase.rpc("enqueue_notice_notifications", { notice_id_input: notice.id });
        if (enqueueError) throw enqueueError;
      }

      const seenPinned = new Set(notices.filter((notice) => notice.is_notice).map((notice) => notice.source_idx));
      const { data: existingPinned, error: existingError } = await supabase
        .from("notices")
        .select("id, source_idx")
        .eq("board_code", board.code)
        .eq("is_notice", true);
      if (existingError) throw existingError;
      for (const notice of existingPinned ?? []) {
        if (!seenPinned.has(notice.source_idx)) {
          const { error: updateError } = await supabase.from("notices").update({ importance_status: "failed" }).eq("id", notice.id);
          if (updateError) throw updateError;
        }
      }

      await supabase.from("scrape_runs").insert({ board_code: board.code, status: "success", started_at: startedAt, finished_at: new Date().toISOString() });
      results.push({ board_code: board.code, status: "success", count: data?.length ?? 0 });
    } catch (error) {
      await supabase.from("scrape_runs").insert({ board_code: board.code, status: "parse_failed", error_message: error instanceof Error ? error.message : String(error), started_at: startedAt, finished_at: new Date().toISOString() });
      results.push({ board_code: board.code, status: "failed" });
    }
  }
  return Response.json({ results });
});
