import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/boards.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "GET") return json({ error: "METHOD_NOT_ALLOWED", message: "GET is required" }, 405);

  const url = new URL(request.url);
  const limit = Math.min(Math.max(Number(url.searchParams.get("limit") ?? "20"), 1), 100);
  const boardCode = url.searchParams.get("board_code");
  let query = supabase.from("notices").select("*").order("published_at", { ascending: false }).limit(limit);
  if (boardCode) query = query.eq("board_code", boardCode);

  const { data, error } = await query;
  if (error) return json({ error: "DATABASE_ERROR", message: error.message }, 500);
  return json({ items: data, next_cursor: null });
});
