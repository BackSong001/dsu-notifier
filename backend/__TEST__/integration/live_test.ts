import { BOARDS } from '../../../supabase/functions/_shared/boards.ts';
import { parseBoard } from '../../../supabase/functions/_shared/scraper.ts';
for (const board of BOARDS) {
  Deno.test(`live Dongseo board: ${board.name}`, async () => {
    const response = await fetch(board.url, {signal: AbortSignal.timeout(20_000)});
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const notices = parseBoard(await response.text(), board);
    if (!notices.length || notices.some(item => item.board_code !== board.code)) throw new Error('Invalid board');
    console.log(`${board.name}: ${notices.length} notices`);
  });
}
