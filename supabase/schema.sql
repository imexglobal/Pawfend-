-- 멍냥이웃 PetNeighbor: database schema, phase 1
-- Accounts, profiles, pets, caregiver services, chat and push subscriptions.
-- Run once in Supabase: Dashboard → SQL Editor → New query → paste → Run.

-- ---------- profiles ----------
create table public.profiles (
  id          uuid primary key references auth.users on delete cascade,
  name        text not null check (char_length(name) between 1 and 40),
  avatar      text not null default '🙂' check (char_length(avatar) <= 16),
  district    text not null default '마포구',
  bio         text not null default '' check (char_length(bio) <= 500),
  services    jsonb not null default '[]'::jsonb,   -- [{"type":"walk","price":15000}, ...]
  created_at  timestamptz not null default now()
);
alter table public.profiles enable row level security;
create policy "Signed-in members can see profiles" on public.profiles
  for select to authenticated using (true);
create policy "Members create their own profile" on public.profiles
  for insert to authenticated with check (id = (select auth.uid()));
create policy "Members edit their own profile" on public.profiles
  for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));

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
create policy "Signed-in members can see pets" on public.pets
  for select to authenticated using (true);
create policy "Owners add pets" on public.pets
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy "Owners edit pets" on public.pets
  for update to authenticated using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy "Owners remove pets" on public.pets
  for delete to authenticated using (owner_id = (select auth.uid()));

-- ---------- chat ----------
-- One conversation per pair of members; user_a is always the smaller id.
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
  select exists (
    select 1 from public.conversations c
    where c.id = conv and (select auth.uid()) in (c.user_a, c.user_b)
  );
$$;

alter table public.conversations enable row level security;
create policy "Members see their conversations" on public.conversations
  for select to authenticated using ((select auth.uid()) in (user_a, user_b));
create policy "Members start conversations they are part of" on public.conversations
  for insert to authenticated with check ((select auth.uid()) in (user_a, user_b) and user_a <> user_b);

alter table public.messages enable row level security;
create policy "Members read messages in their conversations" on public.messages
  for select to authenticated using (public.is_member(conversation_id));
create policy "Members send messages as themselves" on public.messages
  for insert to authenticated with check (sender_id = (select auth.uid()) and public.is_member(conversation_id));

alter table public.conversation_reads enable row level security;
create policy "Members see their own read markers" on public.conversation_reads
  for select to authenticated using (user_id = (select auth.uid()));
create policy "Members set their own read markers" on public.conversation_reads
  for insert to authenticated with check (user_id = (select auth.uid()) and public.is_member(conversation_id));
create policy "Members move their own read markers" on public.conversation_reads
  for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

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

-- live updates for the chat screen
alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.conversations;

-- ---------- push notifications ----------
-- One row per device. Only the send-push Edge Function (service role) reads other people's rows.
create table public.push_subscriptions (
  endpoint    text primary key,
  user_id     uuid not null references auth.users on delete cascade,
  p256dh      text not null,
  auth        text not null,
  created_at  timestamptz not null default now()
);
create index push_subscriptions_user_idx on public.push_subscriptions (user_id);
alter table public.push_subscriptions enable row level security;
create policy "Members see their own devices" on public.push_subscriptions
  for select to authenticated using (user_id = (select auth.uid()));
create policy "Members remove their own devices" on public.push_subscriptions
  for delete to authenticated using (user_id = (select auth.uid()));

-- A shared phone can switch accounts, so saving moves the device to whoever is signed in now.
create function public.save_push_subscription(p_endpoint text, p_p256dh text, p_auth text) returns void
language sql security definer set search_path = '' as $$
  insert into public.push_subscriptions (endpoint, user_id, p256dh, auth)
  values (p_endpoint, (select auth.uid()), p_p256dh, p_auth)
  on conflict (endpoint) do update
    set user_id = excluded.user_id, p256dh = excluded.p256dh, auth = excluded.auth, created_at = now();
$$;
revoke execute on function public.save_push_subscription(text, text, text) from public, anon;
grant execute on function public.save_push_subscription(text, text, text) to authenticated;
