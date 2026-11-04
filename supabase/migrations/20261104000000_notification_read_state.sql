alter table public.notification_outbox
  add column if not exists read_at timestamptz;
