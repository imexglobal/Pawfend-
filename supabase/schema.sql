-- 멍냥이웃 PetNeighbor: database schema, phase 1
-- Accounts, profiles, pets, caregiver services, chat and push subscriptions.
-- Run once in Supabase: Dashboard → SQL Editor → New query → paste → Run.
--
-- Access model:
--   * profiles are visible to signed-in members (name, neighborhood, bio, prices)
--   * pet notes (allergies, care notes) are visible only to the owner
--   * other members can read a pet's name, species, breed and age via pet_directory()
--   * a chat is visible only to its two members
--   * push keys are visible only to the device's current account
--   * deleting the auth user cascades profile, pets, chats, messages and push rows

-- ---------- profiles ----------
create table public.profiles (
  id          uuid primary key references auth.users on delete cascade,
  name        text not null check (char_length(name) between 1 and 40),
  avatar      text not null default '🙂' check (char_length(avatar) between 1 and 16 and avatar !~ '[<>]'),
  district    text not null default '마포구' check (char_length(district) between 1 and 40),
  bio         text not null default '' check (char_length(bio) <= 500),
  services    jsonb not null default '[]'::jsonb,
  created_at  timestamptz not null default now()
);

-- Only the six known services, each at most once, with a whole-won price.
create function public.services_valid(s jsonb) returns boolean
language sql immutable set search_path = '' as $$
  select
    jsonb_typeof(s) = 'array'
    and jsonb_array_length(s) <= 6
    and not exists (
      select 1 from jsonb_array_elements(s) e
      where jsonb_typeof(e) <> 'object'
        or coalesce(e->>'type', '') not in ('walk', 'dropin', 'sitting', 'grooming', 'training', 'taxi')
        or coalesce(e->>'price', '') !~ '^[0-9]{1,8}$'
        or (select count(*) from jsonb_object_keys(e)) <> 2
    )
    and (
      select count(*) = count(distinct e->>'type') from jsonb_array_elements(s) e
    );
$$;

alter table public.profiles
  add constraint services_valid check (public.services_valid(services));

alter table public.profiles enable row level security;
create policy "Signed-in members can see profiles" on public.profiles
  for select to authenticated using (true);
create policy "Members create their own profile" on public.profiles
  for insert to authenticated with check (id = (select auth.uid()));
create policy "Members edit their own profile" on public.profiles
  for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));
-- No delete policy: the account is removed by deleting the auth user, which cascades.

-- ---------- pets ----------
create table public.pets (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null default auth.uid() references public.profiles on delete cascade,
  name        text not null check (char_length(name) between 1 and 40),
  species     text not null default 'dog' check (species in ('dog', 'cat', 'other')),
  breed       text not null default '' check (char_length(breed) <= 60),
  age         int  not null default 0 check (age between 0 and 40),
  notes       text not null default '' check (char_length(notes) <= 500),
  created_at  timestamptz not null default now()
);
create index pets_owner_idx on public.pets (owner_id);
alter table public.pets enable row level security;
-- Full rows, including care notes, stay with the owner.
create policy "Owners read their pets" on public.pets
  for select to authenticated using (owner_id = (select auth.uid()));
create policy "Owners add pets" on public.pets
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy "Owners edit pets" on public.pets
  for update to authenticated using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy "Owners remove pets" on public.pets
  for delete to authenticated using (owner_id = (select auth.uid()));

-- Public card: no notes. security definer so it can read past the owner-only policy,
-- and it returns only the columns other members are allowed to see.
create function public.pet_directory()
returns table (
  id uuid, owner_id uuid, name text, species text, breed text, age int, created_at timestamptz
)
language sql stable security definer set search_path = '' as $$
  select p.id, p.owner_id, p.name, p.species, p.breed, p.age, p.created_at
  from public.pets p;
$$;

-- ---------- chat ----------
-- One conversation per pair of members. user_a is always the smaller id;
-- a before-insert trigger sorts them so either order is accepted.
create table public.conversations (
  id               uuid primary key default gen_random_uuid(),
  user_a           uuid not null references public.profiles on delete cascade,
  user_b           uuid not null references public.profiles on delete cascade,
  created_at       timestamptz not null default now(),
  last_message_at  timestamptz not null default now(),
  check (user_a < user_b),
  unique (user_a, user_b)
);
create index conversations_b_idx on public.conversations (user_b);

create table public.messages (
  id               bigint generated always as identity primary key,
  conversation_id  uuid not null references public.conversations on delete cascade,
  sender_id        uuid not null default auth.uid() references public.profiles on delete cascade,
  body             text not null check (char_length(body) between 1 and 2000),
  created_at       timestamptz not null default now()
);
create index messages_conversation_idx on public.messages (conversation_id, created_at);

create table public.conversation_reads (
  conversation_id  uuid not null references public.conversations on delete cascade,
  user_id          uuid not null default auth.uid() references public.profiles on delete cascade,
  read_at          timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

create function public.is_member(conv uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select (select auth.uid()) is not null and exists (
    select 1 from public.conversations c
    where c.id = conv and (select auth.uid()) in (c.user_a, c.user_b)
  );
$$;

alter table public.conversations enable row level security;
create policy "Members see their conversations" on public.conversations
  for select to authenticated using ((select auth.uid()) in (user_a, user_b));
create policy "Members start conversations they are part of" on public.conversations
  for insert to authenticated with check (
    (select auth.uid()) in (user_a, user_b) and user_a <> user_b
  );

alter table public.messages enable row level security;
create policy "Members read messages in their conversations" on public.messages
  for select to authenticated using (public.is_member(conversation_id));
create policy "Members send messages as themselves" on public.messages
  for insert to authenticated with check (
    sender_id = (select auth.uid()) and public.is_member(conversation_id)
  );

alter table public.conversation_reads enable row level security;
create policy "Members see their own read markers" on public.conversation_reads
  for select to authenticated using (user_id = (select auth.uid()));
create policy "Members set their own read markers" on public.conversation_reads
  for insert to authenticated with check (
    user_id = (select auth.uid()) and public.is_member(conversation_id)
  );
create policy "Members move their own read markers" on public.conversation_reads
  for update to authenticated
  using (user_id = (select auth.uid()) and public.is_member(conversation_id))
  with check (user_id = (select auth.uid()) and public.is_member(conversation_id));

-- Canonical pair order, and timestamps the client cannot forge.
create function public.conversations_normalize() returns trigger
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
  new.created_at := now();
  new.last_message_at := now();
  return new;
end;
$$;
create trigger conversations_normalize before insert on public.conversations
  for each row execute function public.conversations_normalize();

create function public.messages_normalize() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null then
    raise exception 'not authenticated';
  end if;
  new.sender_id := (select auth.uid());
  new.created_at := now();
  return new;
end;
$$;
create trigger messages_normalize before insert on public.messages
  for each row execute function public.messages_normalize();

-- keep conversations sorted by latest message
create function public.touch_conversation() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.conversations set last_message_at = new.created_at where id = new.conversation_id;
  return new;
end;
$$;
create trigger messages_touch_conversation after insert on public.messages
  for each row execute function public.touch_conversation();

-- live updates for the chat screen. INSERT filtering uses the select policy.
alter table public.messages replica identity full;
alter table public.conversations replica identity full;
do $$
begin
  alter publication supabase_realtime add table public.messages;
exception when duplicate_object then null;
end $$;
do $$
begin
  alter publication supabase_realtime add table public.conversations;
exception when duplicate_object then null;
end $$;

-- ---------- push notifications ----------
-- One row per device. Web rows store a Web Push subscription.
-- ios/android rows store the native device token in endpoint (p256dh and auth stay empty).
-- Only the send-push Edge Function (service role) reads other people's rows.
create table public.push_subscriptions (
  endpoint    text primary key check (char_length(endpoint) between 10 and 4096),
  user_id     uuid not null references auth.users on delete cascade,
  p256dh      text not null default '',
  auth        text not null default '',
  platform    text not null default 'web' check (platform in ('web', 'ios', 'android')),
  created_at  timestamptz not null default now(),
  constraint push_subscription_shape check (
    (platform = 'web' and char_length(p256dh) between 1 and 200 and char_length(auth) between 1 and 200)
    or (platform <> 'web' and char_length(p256dh) <= 200 and char_length(auth) <= 200)
  )
);
create index push_subscriptions_user_idx on public.push_subscriptions (user_id);
alter table public.push_subscriptions enable row level security;
create policy "Members see their own devices" on public.push_subscriptions
  for select to authenticated using (user_id = (select auth.uid()));
create policy "Members remove their own devices" on public.push_subscriptions
  for delete to authenticated using (user_id = (select auth.uid()));

-- A shared phone can switch accounts, so saving moves the device to whoever is signed in now.
create function public.save_push_subscription(
  p_endpoint text,
  p_p256dh text,
  p_auth text,
  p_platform text default 'web'
) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null then
    raise exception 'not authenticated';
  end if;
  if p_platform is null or p_platform not in ('web', 'ios', 'android') then
    raise exception 'bad platform';
  end if;
  if p_endpoint is null or char_length(p_endpoint) < 10 or char_length(p_endpoint) > 4096 then
    raise exception 'bad endpoint';
  end if;
  if p_platform = 'web' and (
    p_p256dh is null or char_length(p_p256dh) < 1 or char_length(p_p256dh) > 200
    or p_auth is null or char_length(p_auth) < 1 or char_length(p_auth) > 200
  ) then
    raise exception 'bad keys';
  end if;
  if p_platform <> 'web' and (
    char_length(coalesce(p_p256dh, '')) > 200 or char_length(coalesce(p_auth, '')) > 200
  ) then
    raise exception 'bad keys';
  end if;
  insert into public.push_subscriptions (endpoint, user_id, p256dh, auth, platform)
  values (p_endpoint, (select auth.uid()), coalesce(p_p256dh, ''), coalesce(p_auth, ''), p_platform)
  on conflict (endpoint) do update
    set user_id = excluded.user_id,
        p256dh = excluded.p256dh,
        auth = excluded.auth,
        platform = excluded.platform,
        created_at = now();
end;
$$;

-- ---------- privileges ----------
-- Functions used by triggers or checks need EXECUTE for the signed-in role.
-- They are not granted to anonymous visitors. security definer functions that
-- only run as triggers are revoked from everyone; trigger execution does not
-- require the session user to hold EXECUTE when the function owner is the
-- table owner (Supabase runs this script as the migration owner).
revoke execute on function public.services_valid(jsonb) from public, anon;
grant execute on function public.services_valid(jsonb) to authenticated;

revoke execute on function public.pet_directory() from public, anon;
grant execute on function public.pet_directory() to authenticated;

revoke execute on function public.is_member(uuid) from public, anon;
grant execute on function public.is_member(uuid) to authenticated;

-- Trigger functions can only be invoked by a trigger, but the session user
-- still needs EXECUTE or the insert is rejected. Anonymous visitors do not.
revoke execute on function public.conversations_normalize() from public, anon;
revoke execute on function public.messages_normalize() from public, anon;
revoke execute on function public.touch_conversation() from public, anon;
grant execute on function public.conversations_normalize() to authenticated;
grant execute on function public.messages_normalize() to authenticated;
grant execute on function public.touch_conversation() to authenticated;

revoke execute on function public.save_push_subscription(text, text, text, text) from public, anon;
grant execute on function public.save_push_subscription(text, text, text, text) to authenticated;

revoke all on public.profiles from public, anon;
grant select, insert, update on public.profiles to authenticated;

revoke all on public.pets from public, anon;
grant select, insert, update, delete on public.pets to authenticated;

revoke all on public.conversations from public, anon;
grant select, insert on public.conversations to authenticated;

revoke all on public.messages from public, anon;
grant select, insert on public.messages to authenticated;

revoke all on public.conversation_reads from public, anon;
grant select, insert, update on public.conversation_reads to authenticated;

revoke all on public.push_subscriptions from public, anon;
grant select, delete on public.push_subscriptions to authenticated;

grant usage, select on all sequences in schema public to authenticated;
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
