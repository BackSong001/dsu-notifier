update public.notification_outbox
set read_at = sent_at
where status = 'sent'
  and read_at is null;
