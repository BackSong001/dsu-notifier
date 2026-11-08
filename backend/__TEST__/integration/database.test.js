import test from 'node:test';
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
const exec = promisify(execFile);
const container = process.env.DSU_DB_CONTAINER;
if (!container?.startsWith('dsu-db-test-')) throw new Error('An isolated test container is required');
const sql = async query => (await exec('docker',['exec',container,'psql','-U','postgres','-At','-v','ON_ERROR_STOP=1','-c',query])).stdout;
test('concurrent dispatchers claim distinct rows and leave unattempted rows pending', async () => {
  await sql(`
    select register_device('22222222-2222-4222-8222-222222222222','fixture','android',repeat('a',64));
    insert into notification_preferences values('22222222-2222-4222-8222-222222222222','MN2000194',true);
    insert into notices(board_code,board_name,source_idx,title,author,published_at,url)
      select 'MN2000194','학사',i::text,'fixture','fixture','2026-11-08','https://www.dongseo.ac.kr/' from generate_series(1,3) i;
  `);
  const [first, second] = await Promise.all([
    sql('begin; select id from claim_notifications(); select pg_sleep(1); commit;'),
    sql('begin; select id from claim_notifications(); select pg_sleep(1); commit;'),
  ]);
  const id = output => output.split('\n').find(line => /^[a-f0-9-]{36}$/.test(line));
  assert.ok(id(first)); assert.ok(id(second)); assert.notEqual(id(first),id(second));
  assert.equal((await sql("select count(*) from notification_outbox where status='pending';")).trim(),'1');
});
