import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID, randomBytes } from 'node:crypto';

const base = process.env.DSU_TEST_URL;
const serviceKey = process.env.DSU_TEST_SERVICE_KEY;
const anonKey = process.env.DSU_TEST_ANON_KEY;
if (!base || !['127.0.0.1', 'localhost'].includes(new URL(base).hostname)) {
  throw new Error('DSU_TEST_URL must point to an isolated local Supabase project');
}
const deviceId = randomUUID();
const duplicateDeviceId = randomUUID();
const secret = randomBytes(32).toString('base64url');
const ids = Array.from({length: 25}, () => randomUUID());
async function api(path, {method = 'GET', body, secret: credential = secret, admin = false} = {}) {
  const response = await fetch(`${base}${path}`, {
    method, headers: {apikey: admin ? serviceKey : anonKey,
      Authorization: `Bearer ${admin ? serviceKey : anonKey}`,
      'Content-Type': 'application/json', 'x-device-secret': credential},
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  return {status: response.status, body: text ? (response.headers.get('content-type')?.includes('application/json') ? JSON.parse(text) : text) : null};
}

test('deployed Edge APIs enforce ownership and page/search saved notices', async () => {
  try {
    const notices = ids.map((id, i) => ({id, board_code:'MN2000194', board_name:'학사',
      source_idx: String(900000000 + i), title:`integration-${id}`, author:'fixture',
      published_at: i === 0 ? '2020-01-01' : '2026-11-08', view_count:0,
      url:`https://www.dongseo.ac.kr/kr/?pCode=MN2000194&idx=${900000000+i}`, is_notice:false}));
    assert.equal((await api('/rest/v1/notices', {method:'POST', body:notices, admin:true})).status,201);
    const register = {device_id:deviceId, fcm_token:`fixture-${deviceId}`, platform:'android'};
    assert.equal((await api('/functions/v1/devices/register',{method:'POST',body:register})).status,200);
    assert.equal((await api('/functions/v1/devices/register',{method:'POST',body:register,secret:randomBytes(32).toString('base64url')})).status,401);
    assert.equal((await api(`/functions/v1/devices/${deviceId}/preferences`, {secret:'wrong'})).status,401);
    assert.equal((await api('/functions/v1/devices/register',{method:'POST',body:{...register,device_id:duplicateDeviceId}})).status,401);
    assert.ok([401,403].includes((await api('/rest/v1/devices')).status));
    assert.equal((await api(`/functions/v1/devices/${deviceId}/preferences`, {method:'PUT',body:{boards:{MN2000194:'true'}}})).status,400);
    const list = await api('/functions/v1/notices?board_code=MN2000194&search=integration-&limit=19');
    assert.equal(list.status,200);
    assert.equal(list.body.items.length,19);
    assert.ok(list.body.next_cursor);
    const next = await api(`/functions/v1/notices?board_code=MN2000194&search=integration-&limit=19&cursor=${encodeURIComponent(list.body.next_cursor)}`);
    assert.equal(next.status,200);
    assert.equal(next.body.items.length,6);
    assert.equal(new Set([...list.body.items,...next.body.items].map(n=>n.id)).size,25);
    assert.equal((await api('/functions/v1/notices?cursor=bad')).status,400);
    assert.equal((await api(`/functions/v1/notices/${ids[0]}`)).body.id,ids[0]);
    assert.equal((await api(`/functions/v1/devices/${deviceId}/notice-preferences`,{method:'PUT',body:{notice_id:ids[0],enabled:true}})).status,200);
    const saved = await api(`/functions/v1/devices/${deviceId}/saved-notices?limit=19`);
    assert.equal(saved.status,200);
    assert.equal(saved.body.items[0].id,ids[0]);
    assert.equal((await api(`/functions/v1/notices?search=${ids[0]}`)).body.items.length,1);
    assert.equal((await api(`/functions/v1/devices/${deviceId}/saved-notices?search=missing`)).body.items.length,0);
    assert.equal((await api('/functions/v1/scrape-notices',{method:'POST'})).status,401);
    assert.equal((await api('/functions/v1/dispatch-notifications',{method:'POST'})).status,401);
  } finally {
    await api(`/rest/v1/devices?device_id=eq.${duplicateDeviceId}`,{method:'DELETE',admin:true});
    await api(`/rest/v1/devices?device_id=eq.${deviceId}`,{method:'DELETE',admin:true});
    await api(`/rest/v1/notices?id=in.(${ids.join(',')})`,{method:'DELETE',admin:true});
  }
});
