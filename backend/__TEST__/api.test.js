import test from 'node:test';
import assert from 'node:assert/strict';
import { NoticeStore } from '../src/store.js';
import { getNotices } from '../src/api.js';
import { pinnedNotice } from './fixtures/notices.js';

test('GET notices returns stored fields and supports board filtering', () => {
  const store = new NoticeStore();
  store.saveBoard('MN2000194', [pinnedNotice]);
  const response = getNotices(store, new URL('https://local.test/notices?board_code=MN2000194&limit=20'));
  assert.equal(response.status, 200);
  assert.equal(response.body.items[0].number, null);
  assert.equal(response.body.items[0].importance_status, 'true');
});
