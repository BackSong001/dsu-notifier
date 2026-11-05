create table public.notice_alarm_preferences (
  device_id text not null references public.devices(device_id) on delete cascade,
  notice_id uuid not null references public.notices(id) on delete cascade,
  enabled boolean not null default true,
  primary key (device_id, notice_id)
);

alter table public.notice_alarm_preferences enable row level security;

create policy "service role manages notice alarm preferences"
  on public.notice_alarm_preferences for all using (false);
