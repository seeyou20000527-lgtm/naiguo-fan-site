-- 在 Supabase SQL Editor 執行一次，啟用官方物料上傳、上下架與刪除。
-- 只有 public.admin_users 內已授權的管理者能管理或讀取未上架物料。

create table if not exists public.site_materials (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 100),
  file_name text not null,
  description text not null default '',
  storage_path text not null unique,
  content_type text not null check (content_type in ('image/png','image/jpeg','image/webp','image/gif','application/pdf')),
  is_published boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.site_materials enable row level security;
grant select on public.site_materials to anon, authenticated;
grant insert, update, delete on public.site_materials to authenticated;

drop policy if exists "public read published materials" on public.site_materials;
create policy "public read published materials" on public.site_materials
  for select to anon, authenticated
  using (is_published or exists (
    select 1 from public.admin_users a where a.user_id = auth.uid()
  ));

drop policy if exists "admins manage materials" on public.site_materials;
create policy "admins manage materials" on public.site_materials
  for all to authenticated
  using (exists (select 1 from public.admin_users a where a.user_id = auth.uid()))
  with check (exists (select 1 from public.admin_users a where a.user_id = auth.uid()));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'official-materials', 'official-materials', false, 20971520,
  array['image/png','image/jpeg','image/webp','image/gif','application/pdf']
)
on conflict (id) do update set
  public = false,
  file_size_limit = 20971520,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "admins manage official materials" on storage.objects;
create policy "admins manage official materials" on storage.objects
  for all to authenticated
  using (
    bucket_id = 'official-materials'
    and exists (select 1 from public.admin_users a where a.user_id = auth.uid())
  )
  with check (
    bucket_id = 'official-materials'
    and exists (select 1 from public.admin_users a where a.user_id = auth.uid())
  );

drop policy if exists "public read published official materials" on storage.objects;
create policy "public read published official materials" on storage.objects
  for select to anon, authenticated
  using (
    bucket_id = 'official-materials'
    and exists (
      select 1 from public.site_materials m
      where m.storage_path = name and m.is_published
    )
  );
