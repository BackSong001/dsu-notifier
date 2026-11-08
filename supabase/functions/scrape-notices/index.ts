import { createClient } from "npm:@supabase/supabase-js@2.119.0";
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

function errorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  if (error && typeof error === "object") {
    const value = error as Record<string, unknown>;
    return [value.message, value.details, value.hint, value.code]
      .filter(Boolean)
      .map(String)
      .join(" | ");
  }
  return String(error);
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return new Response("POST is required", { status: 405 });
  if (!authorized(request)) return new Response("Unauthorized", { status: 401 });

  const results = [];
  for (const board of BOARDS) {
    const startedAt = new Date().toISOString();
    let failureStatus = "parse_failed";
    try {
      const response = await fetch(board.url, { signal: AbortSignal.timeout(20_000) });
      if (!response.ok) {
        failureStatus = "http_failed";
        throw new Error(`HTTP ${response.status}`);
      }
      const notices = parseBoard(await response.text(), board);
      const { data: count, error } = await supabase.rpc("store_board_snapshot", {
        board_input: board.code, notices_input: notices,
      });
      if (error) throw error;

      await supabase.from("scrape_runs").insert({ board_code: board.code, status: "success", started_at: startedAt, finished_at: new Date().toISOString() });
      results.push({ board_code: board.code, status: "success", count: count ?? 0 });
    } catch (error) {
      await supabase.from("scrape_runs").insert({ board_code: board.code, status: failureStatus, error_message: errorMessage(error), started_at: startedAt, finished_at: new Date().toISOString() });
      results.push({ board_code: board.code, status: "failed" });
    }
  }
  return Response.json({ results });
});
