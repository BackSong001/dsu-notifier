create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

-- 운영 URL과 호출 비밀값은 Vault에서만 읽는다. 미설정 시 작업을 만들지 않는다.
create function public.configure_notice_cron()
returns void language plpgsql security definer set search_path = public, extensions as $$
declare functions_url text; scrape_secret text; dispatch_secret text; job record;
begin
  select decrypted_secret into functions_url from vault.decrypted_secrets where name = 'dsu_functions_url';
  select decrypted_secret into scrape_secret from vault.decrypted_secrets where name = 'dsu_scrape_cron_secret';
  select decrypted_secret into dispatch_secret from vault.decrypted_secrets where name = 'dsu_dispatch_cron_secret';
  if functions_url is null or scrape_secret is null or dispatch_secret is null then
    raise exception 'CRON_SECRETS_NOT_CONFIGURED';
  end if;
  for job in select jobid from cron.job where jobname in ('dsu-scrape-notices','dsu-dispatch-notifications') loop
    perform cron.unschedule(job.jobid);
  end loop;
  perform cron.schedule('dsu-scrape-notices','*/10 * * * *', $job$
    select net.http_post(
      url := (select decrypted_secret from vault.decrypted_secrets where name='dsu_functions_url') || '/scrape-notices',
      headers := jsonb_build_object('Content-Type','application/json','x-cron-secret',
        (select decrypted_secret from vault.decrypted_secrets where name='dsu_scrape_cron_secret')),
      body := '{}'::jsonb, timeout_milliseconds := 120000);
  $job$);
  perform cron.schedule('dsu-dispatch-notifications','* * * * *', $job$
    select net.http_post(
      url := (select decrypted_secret from vault.decrypted_secrets where name='dsu_functions_url') || '/dispatch-notifications',
      headers := jsonb_build_object('Content-Type','application/json','x-cron-secret',
        (select decrypted_secret from vault.decrypted_secrets where name='dsu_dispatch_cron_secret')),
      body := '{}'::jsonb, timeout_milliseconds := 70000);
  $job$);
end;
$$;
revoke all on function public.configure_notice_cron() from public, anon, authenticated;
