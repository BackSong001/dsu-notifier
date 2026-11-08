import { parseBoard } from '../../../supabase/functions/_shared/scraper.ts';
const board = {code:'MN2000194',name:'학사',url:'https://www.dongseo.ac.kr/kr/?pCode=MN2000194'};
const fixture = await Deno.readTextFile(new URL('../fixtures/board.html', import.meta.url));
Deno.test('deployed parser reads fixture and rejects a partially corrupt snapshot', () => {
  const notices = parseBoard(fixture,board);
  if(notices.length !== 2 || notices[1].number !== null || notices[0].view_count !== 1234) throw new Error('Fixture mismatch');
  for(const html of [fixture.replace('2026-10-29','invalid'), fixture.replace('/kr/index.php?pCode=MN2000194&amp;mode=view&amp;idx=103653','https://evil.example/?idx=103653'), fixture.replace('<td class="subject">','<td class="subject">').replace('수강신청 안내','')]) {
    let rejected = false;
    try { parseBoard(html, board); } catch { rejected = true; }
    if(!rejected) throw new Error('Accepted a partial snapshot');
  }
});
