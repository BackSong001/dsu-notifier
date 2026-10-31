import test from 'node:test';
import assert from 'node:assert/strict';
import { NoticeStore } from '../src/store.js';

const normal = {
  boardCode: 'MN2000194', boardName: '학사', sourceIdx: '1', number: 1,
  title: '일반 공지', author: '처', publishedAt: '2026-10-29', viewCount: 1,
  url: 'https://www.dongseo.ac.kr/kr/index.php?pCode=MN2000194&idx=1',
  isNotice: false, importanceStatus: null,
};

const pinned = { ...normal, sourceIdx: '2', number: null, title: '고정 공지', isNotice: true, importanceStatus: 'true' };

test('upserts notices without duplicates and tracks pinned disappearance', () => {
  const store = new NoticeStore();
  assert.equal(store.saveBoard('MN2000194', [normal, pinned]).newCount, 2);
  assert.equal(store.saveBoard('MN2000194', [normal]).newCount, 0);
  assert.equal(store.get('MN2000194', '2').importanceStatus, 'failed');
  assert.equal(store.saveBoard('MN2000194', [{ ...pinned, viewCount: 3 }]).newCount, 0);
  assert.equal(store.get('MN2000194', '2').importanceStatus, 'true');
  assert.equal(store.list().length, 2);
});

test('does not change stored pinned state when scrape fails', () => {
  const store = new NoticeStore();
  store.saveBoard('MN2000194', [pinned]);
  assert.throws(() => store.saveBoard('MN2000194', [], { success: false }), /Scrape failed/);
  assert.equal(store.get('MN2000194', '2').importanceStatus, 'true');
});
