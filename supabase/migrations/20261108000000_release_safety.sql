-- 클라이언트는 Edge API를 통해서만 디바이스 데이터에 접근한다.
alter table public.devices add column secret_hash text;
alter table public.devices enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.notification_outbox enable row level security;
alter table public.scrape_runs enable row level security;
revoke all on public.devices, public.notification_preferences, public.notification_outbox,
  public.scrape_runs, public.notice_alarm_preferences from anon, authenticated;
revoke execute on function public.enqueue_notice_notifications(uuid) from public, anon, authenticated;
grant execute on function public.enqueue_notice_notifications(uuid) to service_role;

create function public.register_device(device_id_input text, token_input text, platform_input text, hash_input text)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  if device_id_input !~* '^[a-f0-9-]{36}$' or length(token_input) not between 1 and 4096
    or platform_input not in ('android', 'ios') or hash_input !~ '^[a-f0-9]{64}$' then
    raise exception 'INVALID_DEVICE';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(token_input, 1));
  if exists(select 1 from devices where fcm_token = token_input and device_id <> device_id_input and active) then
    return false;
  end if;
  insert into devices(device_id, fcm_token, platform, secret_hash)
    values(device_id_input, token_input, platform_input, hash_input)
    on conflict (device_id) do update set fcm_token = excluded.fcm_token,
      platform = excluded.platform, active = true, updated_at = now()
      where devices.secret_hash = excluded.secret_hash;
  if not found then return false; end if;
  return true;
end;
$$;
revoke all on function public.register_device(text, text, text, text) from public, anon, authenticated;
grant execute on function public.register_device(text, text, text, text) to service_role;

-- 공지와 outbox는 같은 트랜잭션에서 저장한다.
create function public.enqueue_inserted_notice() returns trigger language plpgsql
  security definer set search_path = public as $$
begin
  perform enqueue_notice_notifications(new.id);
  return new;
end;
$$;
revoke all on function public.enqueue_inserted_notice() from public, anon, authenticated;
create trigger enqueue_inserted_notice after insert on public.notices
  for each row execute function public.enqueue_inserted_notice();

create function public.store_board_snapshot(board_input text, notices_input jsonb)
returns integer language plpgsql security definer set search_path = public as $$
declare inserted_count integer;
begin
  if board_input not in ('MN2000194','MN2000191','job_plus','MN2000197','MN2000195','MN2000196')
    or jsonb_typeof(notices_input) <> 'array' or jsonb_array_length(notices_input) = 0 then
    raise exception 'INVALID_SNAPSHOT';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(board_input, 0));
  if exists(select 1 from jsonb_array_elements(notices_input) n
    where n->>'board_code' is distinct from board_input or coalesce(n->>'source_idx','') !~ '^[0-9]+$'
      or coalesce(n->>'title','') = '' or coalesce(n->>'published_at','') !~ '^\d{4}-\d{2}-\d{2}$') then
    raise exception 'INVALID_SNAPSHOT';
  end if;
  insert into notices(board_code, board_name, source_idx, number, title, author, published_at, view_count, url, is_notice, importance_status)
    select board_code, board_name, source_idx, number, title, author, published_at, view_count, url, is_notice,
      case when is_notice then 'true' else null end
    from jsonb_to_recordset(notices_input) as n(board_code text, board_name text, source_idx text, number integer,
      title text, author text, published_at date, view_count integer, url text, is_notice boolean)
    on conflict (board_code, source_idx) do nothing;
  get diagnostics inserted_count = row_count;
  update notices n set is_notice = s.is_notice, number = s.number,
    importance_status = case when s.is_notice then 'true' else null end
    from jsonb_to_recordset(notices_input) as s(source_idx text, number integer, is_notice boolean)
    where n.board_code = board_input and n.source_idx = s.source_idx
      and (n.is_notice is distinct from s.is_notice
        or n.importance_status is distinct from case when s.is_notice then 'true' else null end);
  update notices n set importance_status = case when exists(
      select 1 from jsonb_array_elements(notices_input) s where s->>'source_idx' = n.source_idx and (s->>'is_notice')::boolean
    ) then 'true' else 'failed' end
    where n.board_code = board_input and n.is_notice
      and n.importance_status is distinct from case when exists(
        select 1 from jsonb_array_elements(notices_input) s where s->>'source_idx' = n.source_idx and (s->>'is_notice')::boolean
      ) then 'true' else 'failed' end;
  return inserted_count;
end;
$$;
revoke all on function public.store_board_snapshot(text,jsonb) from public, anon, authenticated;
grant execute on function public.store_board_snapshot(text,jsonb) to service_role;

alter table public.notification_outbox drop constraint notification_outbox_status_check;
alter table public.notification_outbox add constraint notification_outbox_status_check
  check(status in ('pending','sending','sent','failed'));
alter table public.notification_outbox add column next_attempt_at timestamptz not null default now();
create index notification_outbox_pending on public.notification_outbox(next_attempt_at) where status = 'pending';

-- FCM 수락 여부가 불명확한 sending 작업은 중복 방지를 위해 자동 재획득하지 않는다.
create function public.claim_notifications()
returns table(id uuid, notice_id uuid, device_id text, attempts integer, title text, url text, fcm_token text)
language sql security definer set search_path = public as $$
  with candidates as (
    select o.id from notification_outbox o
    join devices d on d.device_id = o.device_id and d.active
    join notices n on n.id = o.notice_id
    join notification_preferences p on p.device_id = d.device_id and p.board_code = n.board_code and p.enabled
    where o.status = 'pending' and o.attempts < 3 and o.next_attempt_at <= now()
    order by o.created_at limit 1 for update of o skip locked
  ), claimed as (
    update notification_outbox o set status = 'sending', attempts = o.attempts + 1
    from candidates c where o.id = c.id returning o.*
  )
  select c.id, c.notice_id, c.device_id, c.attempts, n.title, n.url, d.fcm_token
    from claimed c join notices n on n.id = c.notice_id join devices d on d.device_id = c.device_id;
$$;
revoke all on function public.claim_notifications() from public, anon, authenticated;
grant execute on function public.claim_notifications() to service_role;

-- 고정 여부와 고유 키로 페이지를 이어 신규 삽입에 따른 offset 중복을 피한다.
create function public.list_notice_page(board_input text, device_input text, search_input text, after_input jsonb, limit_input integer)
returns setof public.notices language sql stable security definer set search_path = public as $$
  select n.* from notices n
  where (board_input is null or n.board_code = board_input)
    and (device_input is null or exists(select 1 from notice_alarm_preferences s
      where s.device_id = device_input and s.notice_id = n.id and s.enabled))
    and (search_input = '' or strpos(lower(n.title), lower(search_input)) > 0)
    and (after_input is null or (n.is_notice, n.published_at, n.source_idx, n.id) <
      ((after_input->>'pinned')::boolean, (after_input->>'date')::date, after_input->>'source', (after_input->>'id')::uuid))
  order by n.is_notice desc, n.published_at desc, n.source_idx desc, n.id desc
  limit least(greatest(limit_input,1),101);
$$;
revoke all on function public.list_notice_page(text,text,text,jsonb,integer) from public, anon, authenticated;
grant execute on function public.list_notice_page(text,text,text,jsonb,integer) to service_role;
