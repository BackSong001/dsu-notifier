import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { parseBoard } from '../src/scraper.js';

const fixture = await readFile(new URL('./fixtures/board.html', import.meta.url), 'utf8');

test('parses a normal notice and a pinned notice from a board page', () => {
  const notices = parseBoard(fixture, {
    boardCode: 'MN2000194',
    boardName: '학사',
    pageUrl: 'https://www.dongseo.ac.kr/kr/?pCode=MN2000194',
  });

  assert.deepEqual(notices, [
    {
      boardCode: 'MN2000194',
      boardName: '학사',
      sourceIdx: '103653',
      number: 831,
      title: '수강신청 안내',
      author: '교무처',
      publishedAt: '2026-10-29',
      viewCount: 1234,
      url: 'https://www.dongseo.ac.kr/kr/index.php?pCode=MN2000194&mode=view&idx=103653',
      isNotice: false,
      importanceStatus: null,
    },
    {
      boardCode: 'MN2000194',
      boardName: '학사',
      sourceIdx: '103600',
      number: null,
      title: '중요 학사 공지',
      author: '교무처',
      publishedAt: '2026-10-20',
      viewCount: 999,
      url: 'https://www.dongseo.ac.kr/kr/index.php?pCode=MN2000194&mode=view&idx=103600',
      isNotice: true,
      importanceStatus: 'true',
    },
  ]);
});

test('rejects malformed board markup', () => {
  assert.throws(
    () => parseBoard('<html><body><table></table></body></html>', {
      boardCode: 'MN2000194',
      boardName: '학사',
      pageUrl: 'https://www.dongseo.ac.kr/kr/?pCode=MN2000194',
    }),
    /No notices found/,
  );
});

test('deduplicates repeated source indexes', () => {
  const notices = parseBoard(`${fixture}${fixture}`, {
    boardCode: 'MN2000194',
    boardName: '학사',
    pageUrl: 'https://www.dongseo.ac.kr/kr/?pCode=MN2000194',
  });

  assert.equal(notices.length, 2);
  assert.deepEqual(notices.map((notice) => notice.sourceIdx), ['103653', '103600']);
});
