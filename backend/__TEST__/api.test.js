import test from 'node:test';
import assert from 'node:assert/strict';
import { NoticeStore } from '../src/store.js';
import { getNotices } from '../src/api.js';

test('GET notices returns stored fields and supports board filtering', () => {
  const store = new NoticeStore();
  store.saveBoard('MN2000194', [{
    boardCode: 'MN2000194', boardName: '학사', sourceIdx: '1', number: null,
    title: '고정 공지', author: '처', publishedAt: '2026-10-29', viewCount: 2,
    url: 'https://www.dongseo.ac.kr/kr/index.php?pCode=MN2000194&idx=1',
    isNotice: true, importanceStatus: 'true',
  }]);
  const response = getNotices(store, new URL('https://local.test/notices?board_code=MN2000194&limit=20'));
  assert.equal(response.status, 200);
  assert.equal(response.body.items[0].number, null);
  assert.equal(response.body.items[0].importance_status, 'true');
});
