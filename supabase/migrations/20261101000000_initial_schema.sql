create extension if not exists pgcrypto;

create table public.notices (
  id uuid primary key default gen_random_uuid(),
  board_code text not null,
  board_name text not null,
  source_idx text not null,
  number integer,
  title text not null,
  author text not null,
  published_at date not null,
  view_count integer not null default 0 check (view_count >= 0),
  url text not null,
  is_notice boolean not null default false,
  importance_status text check (importance_status in ('true', 'failed')),
  first_collected_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  unique (board_code, source_idx)
);

create table public.devices (
  device_id text primary key,
  fcm_token text not null,
  platform text not null check (platform in ('android', 'ios')),
  active boolean not null default true,
  updated_at timestamptz not null default now()
);

create table public.notification_preferences (
  device_id text not null references public.devices(device_id) on delete cascade,
  board_code text not null,
  enabled boolean not null default false,
  primary key (device_id, board_code)
);

create table public.notification_outbox (
  id uuid primary key default gen_random_uuid(),
  notice_id uuid not null references public.notices(id) on delete cascade,
  device_id text not null references public.devices(device_id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'sent', 'failed')),
  attempts integer not null default 0 check (attempts >= 0),
  last_error text,
  sent_at timestamptz,
  created_at timestamptz not null default now(),
  unique (notice_id, device_id)
);

create table public.scrape_runs (
  id uuid primary key default gen_random_uuid(),
  board_code text not null,
  status text not null check (status in ('success', 'http_failed', 'parse_failed')),
  error_message text,
  started_at timestamptz not null default now(),
  finished_at timestamptz
);

alter table public.notices enable row level security;
create policy "public can read notices" on public.notices for select using (true);

create or replace function public.enqueue_notice_notifications(notice_id_input uuid)
returns integer
language sql
security definer
set search_path = public
as $$
  with inserted as (
    insert into notification_outbox (notice_id, device_id)
    select notice_id_input, p.device_id
    from notification_preferences p
    join devices d on d.device_id = p.device_id and d.active
    where p.enabled
      and p.board_code = (select board_code from notices where id = notice_id_input)
    on conflict (notice_id, device_id) do nothing
    returning 1
  )
  select count(*)::integer from inserted;
$$;
