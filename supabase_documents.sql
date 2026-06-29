-- ============================================================
--  Legodi & Co — Document uploads
--  Run in Supabase -> SQL Editor -> New query -> Run
--  Adds: a documents column, a private file bucket, and rules
--  (anyone may upload with their application; only logged-in
--   staff may view/download the files).
-- ============================================================

-- 1) Store the file references on each application
alter table public.lc_applications
  add column if not exists documents jsonb default '[]'::jsonb;

-- 2) Private bucket for uploaded files (5 MB cap, docs/images only)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('lc-documents', 'lc-documents', false, 5242880,
        array['application/pdf','image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

-- 3) Storage rules
drop policy if exists "lc doc upload"     on storage.objects;
drop policy if exists "lc doc staff read" on storage.objects;

-- Anyone may UPLOAD into this bucket (public application form)
create policy "lc doc upload" on storage.objects
  for insert to anon, authenticated
  with check (bucket_id = 'lc-documents');

-- Only LOGGED-IN staff may view / download
create policy "lc doc staff read" on storage.objects
  for select to authenticated
  using (bucket_id = 'lc-documents');
