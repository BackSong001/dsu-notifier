begin;
-- 비밀값 없이 내부 테이블/RPC에 접근할 수 없어야 한다.
do $$
begin
  if has_table_privilege('anon', 'public.devices', 'SELECT')
    or has_function_privilege('anon', 'public.claim_notifications()', 'EXECUTE')
    or has_function_privilege('authenticated', 'public.store_board_snapshot(text,jsonb)', 'EXECUTE') then
    raise exception 'Public access to private data';
  end if;
  if not register_device('11111111-1111-4111-8111-111111111111', 'fixture-token', 'android', repeat('a',64)) then
    raise exception 'Registration failed';
  end if;
  if register_device('11111111-1111-4111-8111-111111111111', 'hijacked-token', 'android', repeat('b',64)) then
    raise exception 'Device hijacked';
  end if;
end $$;
insert into notification_preferences values ('11111111-1111-4111-8111-111111111111','MN2000194',true);
select store_board_snapshot('MN2000194', '[{"board_code":"MN2000194","board_name":"학사","source_idx":"100","number":null,"title":"fixture pinned","author":"fixture","published_at":"2026-11-08","view_count":1,"url":"https://www.dongseo.ac.kr/kr/?pCode=MN2000194&idx=100","is_notice":true}]');
select store_board_snapshot('MN2000194', '[{"board_code":"MN2000194","board_name":"학사","source_idx":"100","number":null,"title":"fixture pinned","author":"fixture","published_at":"2026-11-08","view_count":1,"url":"https://www.dongseo.ac.kr/kr/?pCode=MN2000194&idx=100","is_notice":true}]');
do $$ begin
  if (select count(*) from notification_outbox) <> 1 then raise exception 'Outbox not idempotent'; end if;
  if (select count(*) from claim_notifications()) <> 1 then raise exception 'Claim missing'; end if;
  if (select count(*) from claim_notifications()) <> 0 then raise exception 'Claim duplicated'; end if;
end $$;
select store_board_snapshot('MN2000194', '[{"board_code":"MN2000194","board_name":"학사","source_idx":"101","number":1,"title":"fixture regular","author":"fixture","published_at":"2026-11-08","view_count":1,"url":"https://www.dongseo.ac.kr/kr/?pCode=MN2000194&idx=101","is_notice":false}]');
do $$ begin
  if (select importance_status from notices where source_idx='100') <> 'failed' then raise exception 'Pinned disappearance not tracked'; end if;
  begin
    perform store_board_snapshot('MN2000194','[]');
    raise exception 'Empty snapshot accepted';
  exception when raise_exception then
    if SQLERRM <> 'INVALID_SNAPSHOT' then raise; end if;
  end;
  if (select count(*) from notices) <> 2 then raise exception 'Data lost'; end if;
  update devices set active=false;
  if (select count(*) from claim_notifications()) <> 0 then raise exception 'Inactive device claimed'; end if;
end $$;
-- 일반 공지의 고정 전환도 신규 공지/알림으로 재생성하지 않는다.
select store_board_snapshot('MN2000194', '[{"board_code":"MN2000194","board_name":"학사","source_idx":"101","number":null,"title":"fixture regular","author":"fixture","published_at":"2026-11-08","view_count":1,"url":"https://www.dongseo.ac.kr/kr/?pCode=MN2000194&idx=101","is_notice":true}]');
do $$ begin
  if (select is_notice from notices where source_idx='101') is not true then raise exception 'Pin transition lost'; end if;
  if (select number from notices where source_idx='101') is not null then raise exception 'Pinned number not cleared'; end if;
  if (select count(*) from notification_outbox) <> 2 then raise exception 'Pin transition duplicated outbox'; end if;
end $$;
do $$ begin
  perform vault.create_secret('https://example.invalid/functions/v1','dsu_functions_url');
  perform vault.create_secret('fixture-cron-scrape','dsu_scrape_cron_secret');
  perform vault.create_secret('fixture-cron-dispatch','dsu_dispatch_cron_secret');
  perform configure_notice_cron();
  perform configure_notice_cron();
  if (select count(*) from cron.job where jobname like 'dsu-%') <> 2 then raise exception 'Cron duplication'; end if;
  if not exists(select 1 from cron.job where jobname='dsu-scrape-notices' and schedule='*/10 * * * *') then raise exception 'Wrong production cadence'; end if;
  if exists(select 1 from cron.job where command like '%fixture-cron%') then raise exception 'Cron leaked a secret'; end if;
end $$;
rollback;
