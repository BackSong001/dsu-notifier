create or replace function public.list_notice_page(board_input text, device_input text, search_input text, after_input jsonb, limit_input integer)
returns setof public.notices language sql stable security definer set search_path = public as $$
  select n.* from notices n
  where n.importance_status is distinct from 'failed'
    and (board_input is null or n.board_code = board_input)
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
