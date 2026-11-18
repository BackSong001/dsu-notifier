import policies from './documents.json' with { type: 'json' };

export function handleLegalRequest(request: Request): Response {
  const headers = {
    'Content-Type': 'text/plain; charset=utf-8',
    'Cache-Control': 'public, max-age=3600',
    'X-Content-Type-Options': 'nosniff',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
  };
  if (request.method === 'OPTIONS') return new Response(null, { headers });
  if (!['GET', 'HEAD'].includes(request.method)) {
    return new Response('METHOD_NOT_ALLOWED', { status: 405, headers: { ...headers, Allow: 'GET, HEAD, OPTIONS' } });
  }
  const path = new URL(request.url).pathname;
  const match = path.match(/^\/(?:functions\/v1\/)?legal\/(privacy|terms|deletion)\/?$/);
  const document = policies.documents.find((document) => document.id === match?.[1]);
  if (!document) return new Response('NOT_FOUND', { status: 404, headers });
  const text = [
    `${policies.appName} — ${document.title}`,
    `시행일 ${policies.effectiveDate} · 문서 버전 ${policies.version}`,
    `운영자 ${policies.operator} · 문의 ${policies.contactEmail}`,
    ...document.sections.map((section) => `${section.heading}\n\n${section.body}`),
  ].join('\n\n') + '\n';
  return new Response(request.method === 'HEAD' ? null : text, { headers });
}
