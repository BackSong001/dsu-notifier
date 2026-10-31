const ALLOWED_HOST = 'www.dongseo.ac.kr';

export async function checkNoticeUrl(value, fetchImpl = fetch) {
  const url = new URL(value);
  if (url.protocol !== 'https:' || url.hostname !== ALLOWED_HOST) throw new Error('Invalid notice host');
  const response = await fetchImpl(url, { method: 'GET' });
  return { accessible: response.ok, status: response.status };
}
