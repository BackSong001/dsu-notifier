import test from 'node:test';
import assert from 'node:assert/strict';
import { NoticeStore } from '../src/store.js';
import { makeNotice, pinnedNotice } from './fixtures/notices.js';

const normal = makeNotice();

test('upserts notices without duplicates and tracks pinned disappearance', () => {
  const store = new NoticeStore();
  assert.equal(store.saveBoard('MN2000194', [normal, pinnedNotice]).newCount, 2);
  assert.equal(store.saveBoard('MN2000194', [normal]).newCount, 0);
  assert.equal(store.get('MN2000194', '2').importanceStatus, 'failed');
  assert.equal(store.saveBoard('MN2000194', [{ ...pinnedNotice, viewCount: 3 }]).newCount, 0);
  assert.equal(store.get('MN2000194', '2').importanceStatus, 'true');
  assert.equal(store.list().length, 2);
});

test('does not change stored pinned state when scrape fails', () => {
  const store = new NoticeStore();
  store.saveBoard('MN2000194', [pinnedNotice]);
  assert.throws(() => store.saveBoard('MN2000194', [], { success: false }), /Scrape failed/);
  assert.equal(store.get('MN2000194', '2').importanceStatus, 'true');
});

test('lists pinned notices before newer normal notices', () => {
  const store = new NoticeStore();
  store.saveBoard('MN2000194', [
    { ...normal, publishedAt: '2026-10-30' },
    { ...pinnedNotice, publishedAt: '2026-10-01' },
  ]);

  assert.deepEqual(
    store.list().map((notice) => notice.title),
    ['고정 공지', '일반 공지'],
  );
});
