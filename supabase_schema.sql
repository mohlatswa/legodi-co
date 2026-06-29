-- ============================================================
--  Legodi & Co — company-registration applications
--  Run this in your Supabase project:  SQL Editor → New query → Run
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

-- ------------------------------------------------------------
--  MVP policies (KNOWN-OPEN — see security note below).
--  These let the public site work with no login yet.
-- ------------------------------------------------------------
drop policy if exists "anon insert" on public.lc_applications;
drop policy if exists "anon select" on public.lc_applications;
drop policy if exists "anon update" on public.lc_applications;
drop policy if exists "anon delete" on public.lc_applications;

create policy "anon insert" on public.lc_applications for insert to anon with check (true);
create policy "anon select" on public.lc_applications for select to anon using (true);
create policy "anon update" on public.lc_applications for update to anon using (true) with check (true);
create policy "anon delete" on public.lc_applications for delete to anon using (true);

-- ============================================================
--  SECURITY NOTE (read me)
--  The policies above allow ANY visitor to read/update/delete
--  rows. The staff passcode in the app is UI-only deterrence,
--  NOT real protection. Fine for launch/testing, but before
--  storing real client ID numbers at scale, move the staff
--  portal behind Supabase Auth and restrict select/update/
--  delete to authenticated staff only (Phase 2 lockdown).
-- ============================================================
