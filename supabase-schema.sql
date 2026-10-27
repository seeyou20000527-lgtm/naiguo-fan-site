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
  stream_days integer[] not null default ARRAY[1,2,3,4,5],
  stream_time time not null default '21:00',
  social_url text not null default '',
  updated_at timestamptz not null default now()
);
alter table public.admin_users enable row level security;
alter table public.stream_events enable row level security;
alter table public.site_settings enable row level security;
grant select on public.stream_events, public.site_settings to anon, authenticated;
grant select on public.admin_users to anon, authenticated;
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

-- 粉絲投稿審核：投稿先進入 pending，只有管理員可改狀態；核准稿才可讀取。
create table if not exists public.fan_submissions (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 1 and 100),
  author_name text not null check (char_length(author_name) between 1 and 40),
  storage_path text not null unique,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);
alter table public.fan_submissions enable row level security;
grant insert on public.fan_submissions to anon, authenticated;
grant select on public.fan_submissions to anon, authenticated;
grant select, update, delete on public.fan_submissions to authenticated;
drop policy if exists "fans submit pending works" on public.fan_submissions;
create policy "fans submit pending works" on public.fan_submissions for insert to anon, authenticated with check (status = 'pending');
drop policy if exists "public read approved submissions" on public.fan_submissions;
create policy "public read approved submissions" on public.fan_submissions for select to anon, authenticated using (status = 'approved' or exists(select 1 from public.admin_users where user_id = auth.uid()));
drop policy if exists "admins review submissions" on public.fan_submissions;
create policy "admins review submissions" on public.fan_submissions for update to authenticated using (exists(select 1 from public.admin_users where user_id = auth.uid())) with check (exists(select 1 from public.admin_users where user_id = auth.uid()));
drop policy if exists "admins delete submissions" on public.fan_submissions;
create policy "admins delete submissions" on public.fan_submissions for delete to authenticated using (exists(select 1 from public.admin_users where user_id = auth.uid()));

-- Private bucket: approved work is served through short-lived signed URLs; no public bucket URLs.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('fan-submissions', 'fan-submissions', false, 5242880, array['image/png','image/jpeg','image/webp','image/gif'])
on conflict (id) do update set public=false, file_size_limit=5242880, allowed_mime_types=array['image/png','image/jpeg','image/webp','image/gif'];
drop policy if exists "fans upload artwork" on storage.objects;
create policy "fans upload artwork" on storage.objects for insert to anon, authenticated with check (bucket_id = 'fan-submissions');
drop policy if exists "read approved artwork or admin" on storage.objects;
create policy "read approved artwork or admin" on storage.objects for select to anon, authenticated using (
  bucket_id = 'fan-submissions' and (
    exists(select 1 from public.fan_submissions f where f.storage_path = name and f.status = 'approved')
    or exists(select 1 from public.admin_users where user_id = auth.uid())
  )
);
drop policy if exists "admins manage submitted artwork" on storage.objects;
create policy "admins manage submitted artwork" on storage.objects for all to authenticated using (
  bucket_id = 'fan-submissions' and exists(select 1 from public.admin_users where user_id = auth.uid())
) with check (bucket_id = 'fan-submissions' and exists(select 1 from public.admin_users where user_id = auth.uid()));


