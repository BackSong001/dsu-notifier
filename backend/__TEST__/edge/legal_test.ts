import { handleLegalRequest } from '../../../supabase/functions/legal/handler.ts';

Deno.test('public policies are available without credentials and contain operator details', async () => {
  for (const id of ['privacy', 'terms', 'deletion']) {
    const response = handleLegalRequest(new Request(`https://example.test/functions/v1/legal/${id}`));
    if (response.status !== 200 || !response.headers.get('content-type')?.includes('text/plain')) throw new Error('Public readable policy required');
    const text = await response.text();
    for (const expected of ['동서알리미', '백송', 'jhgu2014@gmail.com', '2026-11-18']) {
      if (!text.includes(expected)) throw new Error(`Missing ${expected}`);
    }
  }
});
Deno.test('policy routes reject unknown documents and mutations', async () => {
  const url = 'https://example.test/functions/v1/legal/privacy';
  if (handleLegalRequest(new Request(url, { method: 'POST' })).status !== 405) throw new Error('Mutation allowed');
  if (handleLegalRequest(new Request(url + '/unexpected')).status !== 404) throw new Error('Unknown path allowed');
  const head = handleLegalRequest(new Request(url, { method: 'HEAD' }));
  if (head.status !== 200 || (await head.text()) !== '') throw new Error('HEAD failed');
});
