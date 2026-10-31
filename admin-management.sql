-- 在 Supabase SQL Editor 執行一次，啟用後台管理者名單功能。
-- 任何現任管理者可管理其他帳號。此功能只會授權已存在於 Supabase Auth 的帳號。

create or replace function public.admin_list_managers()
returns table(user_id uuid, email text)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (select 1 from public.admin_users a where a.user_id = auth.uid()) then
    raise exception '管理者權限不足';
  end if;
  return query
    select a.user_id, u.email::text
    from public.admin_users a
    join auth.users u on u.id = a.user_id
    order by lower(u.email);
end;
$$;

create or replace function public.admin_add_manager(manager_email text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare target_id uuid;
begin
  if not exists (select 1 from public.admin_users a where a.user_id = auth.uid()) then
    raise exception '管理者權限不足';
  end if;
  select u.id into target_id
    from auth.users u
    where lower(u.email) = lower(trim(manager_email))
    limit 1;
  if target_id is null then
    raise exception '此信箱尚未建立登入帳號，請先在 Supabase Auth 建立帳號';
  end if;
  insert into public.admin_users(user_id) values (target_id)
    on conflict (user_id) do nothing;
end;
$$;

create or replace function public.admin_remove_manager(manager_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare manager_count integer;
begin
  if not exists (select 1 from public.admin_users a where a.user_id = auth.uid()) then
    raise exception '管理者權限不足';
  end if;
  lock table public.admin_users in exclusive mode;
  select count(*) into manager_count from public.admin_users;
  if not exists (select 1 from public.admin_users a where a.user_id = manager_user_id) then
    raise exception '找不到此管理者';
  end if;
  if manager_count <= 1 then
    raise exception '至少要保留一位管理者';
  end if;
  delete from public.admin_users where user_id = manager_user_id;
end;
$$;

revoke all on function public.admin_list_managers() from public, anon;
revoke all on function public.admin_add_manager(text) from public, anon;
revoke all on function public.admin_remove_manager(uuid) from public, anon;
grant execute on function public.admin_list_managers() to authenticated;
grant execute on function public.admin_add_manager(text) to authenticated;
grant execute on function public.admin_remove_manager(uuid) to authenticated;
