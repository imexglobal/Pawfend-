-- Legal consents, booking acknowledgement, blocks, and reports.
-- Run this once if you already applied an older supabase/schema.sql.
-- A brand-new database only needs schema.sql (this section is included at the end of that file).
-- Safe to run again.

create table if not exists public.legal_consents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles on delete cascade,
  terms_version text not null,
  privacy_version text not null,
  location_terms_version text not null,
  age_14 boolean not null check (age_14),
  caregiver_age_19 boolean not null default false,
  accepted_at timestamptz not null default now()
);
create index if not exists legal_consents_user_idx on public.legal_consents (user_id, accepted_at desc);

create table if not exists public.booking_acknowledgements (
  user_id uuid primary key references public.profiles on delete cascade,
  terms_version text not null,
  acknowledged_at timestamptz not null default now()
);

create table if not exists public.user_blocks (
  blocker_id uuid not null references public.profiles on delete cascade,
  blocked_id uuid not null references public.profiles on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create table if not exists public.user_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null default auth.uid() references public.profiles on delete cascade,
  reported_user_id uuid references public.profiles on delete set null,
  context text not null check (context in ('profile','chat','post','place','message')),
  context_id text not null default '',
  reason text not null check (char_length(reason) between 1 and 40),
  detail text not null default '' check (char_length(detail) <= 1000),
  created_at timestamptz not null default now()
);
create index if not exists user_reports_reporter_idx on public.user_reports (reporter_id, created_at desc);

alter table public.legal_consents enable row level security;
alter table public.booking_acknowledgements enable row level security;
alter table public.user_blocks enable row level security;
alter table public.user_reports enable row level security;

drop policy if exists "Members read their own consent rows" on public.legal_consents;
create policy "Members read their own consent rows" on public.legal_consents
  for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists "Members insert their own consent rows" on public.legal_consents;
create policy "Members insert their own consent rows" on public.legal_consents
  for insert to authenticated with check (user_id = (select auth.uid()) and age_14);

drop policy if exists "Members read their booking acknowledgement" on public.booking_acknowledgements;
create policy "Members read their booking acknowledgement" on public.booking_acknowledgements
  for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists "Members insert their booking acknowledgement" on public.booking_acknowledgements;
create policy "Members insert their booking acknowledgement" on public.booking_acknowledgements
  for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists "Members update their booking acknowledgement" on public.booking_acknowledgements;
create policy "Members update their booking acknowledgement" on public.booking_acknowledgements
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists "Members see who they blocked" on public.user_blocks;
create policy "Members see who they blocked" on public.user_blocks
  for select to authenticated using (blocker_id = (select auth.uid()));
drop policy if exists "Members block another member" on public.user_blocks;
create policy "Members block another member" on public.user_blocks
  for insert to authenticated with check (
    blocker_id = (select auth.uid()) and blocker_id <> blocked_id
  );
drop policy if exists "Members unblock" on public.user_blocks;
create policy "Members unblock" on public.user_blocks
  for delete to authenticated using (blocker_id = (select auth.uid()));

drop policy if exists "Members read their own reports" on public.user_reports;
create policy "Members read their own reports" on public.user_reports
  for select to authenticated using (reporter_id = (select auth.uid()));
drop policy if exists "Members file a report" on public.user_reports;
create policy "Members file a report" on public.user_reports
  for insert to authenticated with check (reporter_id = (select auth.uid()));

-- A block in either direction stops a new conversation and a new message.
-- security definer reads user_blocks even though each member can only select their own rows.
create or replace function public.conversations_normalize() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  tmp uuid;
begin
  if (select auth.uid()) is null or (select auth.uid()) not in (new.user_a, new.user_b) then
    raise exception 'not a member';
  end if;
  if new.user_a = new.user_b then
    raise exception 'cannot chat with yourself';
  end if;
  if new.user_a > new.user_b then
    tmp := new.user_a;
    new.user_a := new.user_b;
    new.user_b := tmp;
  end if;
  if exists (
    select 1 from public.user_blocks
    where (blocker_id = new.user_a and blocked_id = new.user_b)
       or (blocker_id = new.user_b and blocked_id = new.user_a)
  ) then
    raise exception 'blocked';
  end if;
  new.created_at := now();
  new.last_message_at := now();
  return new;
end;
$$;

create or replace function public.messages_normalize() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null then
    raise exception 'not authenticated';
  end if;
  if exists (
    select 1 from public.conversations c
    join public.user_blocks b
      on (b.blocker_id = c.user_a and b.blocked_id = c.user_b)
      or (b.blocker_id = c.user_b and b.blocked_id = c.user_a)
    where c.id = new.conversation_id
  ) then
    raise exception 'blocked';
  end if;
  new.sender_id := (select auth.uid());
  new.created_at := now();
  return new;
end;
$$;

revoke execute on function public.conversations_normalize() from public, anon;
revoke execute on function public.messages_normalize() from public, anon;
grant execute on function public.conversations_normalize() to authenticated;
grant execute on function public.messages_normalize() to authenticated;

revoke all on public.legal_consents from public, anon;
grant select, insert on public.legal_consents to authenticated;

revoke all on public.booking_acknowledgements from public, anon;
grant select, insert, update on public.booking_acknowledgements to authenticated;

revoke all on public.user_blocks from public, anon;
grant select, insert, delete on public.user_blocks to authenticated;

revoke all on public.user_reports from public, anon;
grant select, insert on public.user_reports to authenticated;
