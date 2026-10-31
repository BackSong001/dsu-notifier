import test from 'node:test';
import assert from 'node:assert/strict';
import { createPoller } from '../src/poller.js';

test('test poller uses a 30-second interval and detects a newly supplied notice', async () => {
  let calls = 0;
  let notices = [];
  const poller = createPoller({ intervalMs: 30_000, scrape: async () => { calls += 1; return notices; } });
  assert.equal(poller.intervalMs, 30_000);
  await poller.runOnce();
  notices = [{ sourceIdx: 'new' }];
  await poller.runOnce();
  assert.equal(calls, 2);
  assert.deepEqual(poller.latest, [{ sourceIdx: 'new' }]);
});
