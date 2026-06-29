-- ============================================================
--  Legodi & Co — SECURE schema for company-registration apps
--  Run in your Supabase project:  SQL Editor -> New query -> Run
--  This version is LOCKED DOWN (POPIA-friendly):
--    • Public visitors can ONLY submit (insert) — never read others' data
--    • Reading / editing / deleting requires a logged-in staff account
--    • Tracking returns ONLY company name + status for a known reference
-- ============================================================

create table if not exists public.lc_applications (
  id           bigint generated always as identity primary key,
  ref          text unique not null,
  company_name text not null,
  alt_name     text,
  entity_type  text,
  industry     text,
  description  text,
  contact_name text,
  id_number    text,
  email        text,
  phone        text,
  directors    text,
  city         text,
  services     jsonb default '[]'::jsonb,
  notes        text,
  status       text default 'New',
  submitted    timestamptz default now(),
  created_at   timestamptz default now()
);

alter table public.lc_applications enable row level security;

-- Clean slate (safe to re-run)
drop policy if exists "anon insert"   on public.lc_applications;
drop policy if exists "anon select"   on public.lc_applications;
drop policy if exists "anon update"   on public.lc_applications;
drop policy if exists "anon delete"   on public.lc_applications;
drop policy if exists "public insert" on public.lc_applications;
drop policy if exists "staff read"    on public.lc_applications;
drop policy if exists "staff update"  on public.lc_applications;
drop policy if exists "staff delete"  on public.lc_applications;

-- 1) Anyone (anon or logged-in) may SUBMIT a new application
create policy "public insert" on public.lc_applications
  for insert to anon, authenticated with check (true);

-- 2) Only LOGGED-IN staff may read / update / delete
create policy "staff read"   on public.lc_applications for select to authenticated using (true);
create policy "staff update" on public.lc_applications for update to authenticated using (true) with check (true);
create policy "staff delete" on public.lc_applications for delete to authenticated using (true);

-- ------------------------------------------------------------
-- 3) Public status tracking WITHOUT exposing the table.
--    Returns only company name + status for an exact reference.
--    SECURITY DEFINER lets it read the table on the caller's
--    behalf while RLS still blocks direct anon SELECT.
-- ------------------------------------------------------------
create or replace function public.track_application(p_ref text)
returns table (ref text, company_name text, status text, submitted timestamptz)
language sql security definer set search_path = public as $$
  select ref, company_name, status, submitted
  from public.lc_applications
  where ref = upper(trim(p_ref))
  limit 1;
$$;

revoke all on function public.track_application(text) from public;
grant execute on function public.track_application(text) to anon, authenticated;

-- ============================================================
--  CREATE A STAFF LOGIN (do this once)
--  Supabase dashboard -> Authentication -> Users -> "Add user"
--    Email:    mateteellenlegodi@hotmail.com
--    Password: (choose a strong one)
--    Tick "Auto Confirm User"
--  Anyone WITHOUT a login can submit the form but can NEVER read
--  applications. That is the real security — not the app passcode.
-- ============================================================
