import test from 'node:test';
import assert from 'node:assert/strict';
import { checkNoticeUrl } from '../src/url.js';

test('checks that a notice URL is an accessible Dongseo URL', async () => {
  const response = await checkNoticeUrl(
    'https://www.dongseo.ac.kr/kr/index.php?pCode=MN2000194&idx=1',
    async () => new Response('', { status: 200 }),
  );
  assert.deepEqual(response, { accessible: true, status: 200 });
});

test('rejects a URL outside the allowed host', async () => {
  await assert.rejects(() => checkNoticeUrl('https://example.com/notice'), /Invalid notice host/);
});
