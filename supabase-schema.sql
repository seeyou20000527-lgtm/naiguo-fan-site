-- 在 Supabase SQL Editor 執行。請先於 Authentication 建立管理者帳號。
create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade
);
create table if not exists public.stream_events (
  id uuid primary key default gen_random_uuid(),
  event_date date not null,
  event_time time not null default '21:00',
  title text not null,
  description text not null default '',
  is_published boolean not null default true,
  created_at timestamptz not null default now(),
  unique (event_date, title)
);
create table if not exists public.site_settings (
  id text primary key check (id = 'main'),
  profile_name text not null default '奶鍋',
  tagline text not null default '',
  bio text not null default '',
  stream_label text not null default '',
  social_url text not null default '',
  updated_at timestamptz not null default now()
);
alter table public.admin_users enable row level security;
alter table public.stream_events enable row level security;
alter table public.site_settings enable row level security;
grant select on public.stream_events, public.site_settings to anon, authenticated;
grant select on public.admin_users to authenticated;
grant insert, update, delete on public.stream_events, public.site_settings to authenticated;
drop policy if exists "admins can read own membership" on public.admin_users;
create policy "admins can read own membership" on public.admin_users for select to authenticated using (user_id = auth.uid());
drop policy if exists "public can read published events" on public.stream_events;
create policy "public can read published events" on public.stream_events for select to anon, authenticated using (is_published or exists(select 1 from public.admin_users where user_id = auth.uid()));
drop policy if exists "admins manage events" on public.stream_events;
create policy "admins manage events" on public.stream_events for all to authenticated using (exists(select 1 from public.admin_users where user_id = auth.uid())) with check (exists(select 1 from public.admin_users where user_id = auth.uid()));
drop policy if exists "public can read main settings" on public.site_settings;
create policy "public can read main settings" on public.site_settings for select to anon, authenticated using (id = 'main');
drop policy if exists "admins manage main settings" on public.site_settings;
create policy "admins manage main settings" on public.site_settings for all to authenticated using (exists(select 1 from public.admin_users where user_id = auth.uid())) with check (exists(select 1 from public.admin_users where user_id = auth.uid()));
insert into public.site_settings (id, profile_name, tagline, bio, stream_label)
values ('main', '奶鍋', '每週一至週五・21:00 開播', '喜歡唱歌、玩遊戲，也喜歡和鍋友們一起聊天。歡迎來到我的小小秘密基地！', '直播')
on conflict (id) do nothing;

insert into public.stream_events (event_date, event_time, title, description, is_published)
values ('2026-10-31', '21:00', '萬聖節回', '和奶鍋一起過萬聖節！', true)
on conflict (event_date, title) do nothing;

-- 建立帳號後，將下方 UUID 換成 Authentication > Users 中你的 User UID，再執行一次：
-- insert into public.admin_users (user_id) values ('在此填入你的-user-uuid');
