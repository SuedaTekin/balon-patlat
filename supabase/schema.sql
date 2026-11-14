-- =====================================================================
-- Balon Patlat — Supabase şeması
-- Supabase panelinde: SQL Editor → New query → bu dosyanın TAMAMINI
-- yapıştır → Run. Tekrar çalıştırılabilir (idempotent).
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- Hafta anahtarı (UTC, ISO hafta): örn. 2026-W46
-- Uygulamadaki Cloud.weekKey() ile aynı biçimi üretir.
-- ---------------------------------------------------------------------
create or replace function public.current_week() returns text
language sql stable as $$
  select to_char(now() at time zone 'utc', 'IYYY-"W"IW')
$$;

-- ---------------------------------------------------------------------
-- TABLOLAR
-- ---------------------------------------------------------------------
create table if not exists public.profiles (
  id            uuid primary key references auth.users on delete cascade,
  username      text not null unique check (char_length(username) between 3 and 16),
  avatar        int  not null default 0 check (avatar between 0 and 15),
  friend_code   text not null unique default upper(substr(md5(random()::text), 1, 6)),
  level         int  not null default 1,
  total_stars   int  not null default 0,
  total_score   bigint not null default 0,
  week          text not null default '',
  weekly_score  bigint not null default 0,
  weekly_stars  int  not null default 0,
  clan_id       uuid,
  clan_role     text not null default 'member' check (clan_role in ('member', 'leader')),
  updated_at    timestamptz not null default now(),
  created_at    timestamptz not null default now()
);

create table if not exists public.saves (
  user_id    uuid primary key references auth.users on delete cascade,
  data       jsonb not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.clans (
  id          uuid primary key default gen_random_uuid(),
  name        text not null unique check (char_length(name) between 3 and 20),
  description text not null default '' check (char_length(description) <= 80),
  badge       int  not null default 0,
  owner_id    uuid not null references public.profiles(id) on delete cascade,
  created_at  timestamptz not null default now()
);

do $$ begin
  alter table public.profiles
    add constraint profiles_clan_fk foreign key (clan_id)
    references public.clans(id) on delete set null;
exception when duplicate_object then null; end $$;

create index if not exists profiles_clan_idx on public.profiles (clan_id);
create index if not exists profiles_week_idx on public.profiles (week, weekly_score desc);
create index if not exists profiles_stars_idx on public.profiles (total_stars desc, total_score desc);

create table if not exists public.clan_messages (
  id         bigint generated always as identity primary key,
  clan_id    uuid not null references public.clans on delete cascade,
  user_id    uuid references public.profiles on delete cascade,
  kind       text not null default 'chat' check (kind in ('chat', 'life', 'system')),
  body       text not null default '' check (char_length(body) <= 200),
  helpers    uuid[] not null default '{}',
  claimed    int not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists clan_messages_idx on public.clan_messages (clan_id, created_at desc);

create table if not exists public.chest_claims (
  user_id uuid references public.profiles on delete cascade,
  week    text,
  tier    int,
  primary key (user_id, week, tier)
);

create table if not exists public.friendships (
  user_id    uuid references public.profiles on delete cascade,
  friend_id  uuid references public.profiles on delete cascade,
  status     text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  primary key (user_id, friend_id),
  check (user_id <> friend_id)
);

-- ---------------------------------------------------------------------
-- Yeni kullanıcı (misafir dahil) → otomatik profil
-- ---------------------------------------------------------------------
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, username)
  values (new.id, 'Oyuncu' || upper(substr(replace(new.id::text, '-', ''), 1, 6)))
  on conflict do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Takım alanları sadece RPC fonksiyonlarıyla değişebilir.
create or replace function public.guard_profile() returns trigger
language plpgsql as $$
begin
  if (new.clan_id is distinct from old.clan_id or new.clan_role is distinct from old.clan_role)
     and coalesce(current_setting('app.clan_rpc', true), '') <> '1' then
    raise exception 'Takım bilgisi doğrudan değiştirilemez';
  end if;
  if new.id <> old.id or new.friend_code <> old.friend_code then
    raise exception 'Bu alan değiştirilemez';
  end if;
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists profiles_guard on public.profiles;
create trigger profiles_guard before update on public.profiles
  for each row execute function public.guard_profile();

create or replace function public.my_clan() returns uuid
language sql stable security definer set search_path = public as $$
  select clan_id from profiles where id = auth.uid()
$$;

-- ---------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------
alter table public.profiles      enable row level security;
alter table public.saves         enable row level security;
alter table public.clans         enable row level security;
alter table public.clan_messages enable row level security;
alter table public.chest_claims  enable row level security;
alter table public.friendships   enable row level security;

drop policy if exists profiles_read   on public.profiles;
drop policy if exists profiles_insert on public.profiles;
drop policy if exists profiles_update on public.profiles;
create policy profiles_read   on public.profiles for select to authenticated using (true);
create policy profiles_insert on public.profiles for insert to authenticated
  with check (id = auth.uid() and clan_id is null);
create policy profiles_update on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists saves_own on public.saves;
create policy saves_own on public.saves for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists clans_read on public.clans;
create policy clans_read on public.clans for select to authenticated using (true);

drop policy if exists msgs_read   on public.clan_messages;
drop policy if exists msgs_insert on public.clan_messages;
create policy msgs_read on public.clan_messages for select to authenticated
  using (clan_id = public.my_clan());
create policy msgs_insert on public.clan_messages for insert to authenticated
  with check (user_id = auth.uid() and clan_id = public.my_clan()
              and kind = 'chat' and helpers = '{}' and claimed = 0);

drop policy if exists chest_read on public.chest_claims;
create policy chest_read on public.chest_claims for select to authenticated
  using (user_id = auth.uid());

drop policy if exists fr_read   on public.friendships;
drop policy if exists fr_insert on public.friendships;
drop policy if exists fr_accept on public.friendships;
drop policy if exists fr_delete on public.friendships;
create policy fr_read on public.friendships for select to authenticated
  using (auth.uid() in (user_id, friend_id));
create policy fr_insert on public.friendships for insert to authenticated
  with check (user_id = auth.uid() and status = 'pending');
create policy fr_accept on public.friendships for update to authenticated
  using (friend_id = auth.uid()) with check (friend_id = auth.uid() and status = 'accepted');
create policy fr_delete on public.friendships for delete to authenticated
  using (auth.uid() in (user_id, friend_id));

-- ---------------------------------------------------------------------
-- RPC: TAKIM
-- ---------------------------------------------------------------------
create or replace function public.create_clan(p_name text, p_desc text, p_badge int)
returns uuid language plpgsql security definer set search_path = public as $$
declare cid uuid; uname text;
begin
  if auth.uid() is null then raise exception 'Giriş gerekli'; end if;
  if (select clan_id from profiles where id = auth.uid()) is not null then
    raise exception 'Zaten bir takımdasın';
  end if;
  insert into clans (name, description, badge, owner_id)
  values (trim(p_name), coalesce(trim(p_desc), ''), coalesce(p_badge, 0), auth.uid())
  returning id into cid;
  perform set_config('app.clan_rpc', '1', true);
  update profiles set clan_id = cid, clan_role = 'leader' where id = auth.uid()
  returning username into uname;
  insert into clan_messages (clan_id, kind, body) values (cid, 'system', uname || ' takımı kurdu! 🎉');
  return cid;
end $$;

create or replace function public.join_clan(p_clan uuid)
returns void language plpgsql security definer set search_path = public as $$
declare n int; uname text;
begin
  if auth.uid() is null then raise exception 'Giriş gerekli'; end if;
  if (select clan_id from profiles where id = auth.uid()) is not null then
    raise exception 'Zaten bir takımdasın';
  end if;
  select count(*) into n from profiles where clan_id = p_clan;
  if n >= 30 then raise exception 'Takım dolu (30/30)'; end if;
  perform set_config('app.clan_rpc', '1', true);
  update profiles set clan_id = p_clan, clan_role = 'member' where id = auth.uid()
  returning username into uname;
  insert into clan_messages (clan_id, kind, body) values (p_clan, 'system', uname || ' takıma katıldı. Hoş geldin! 👋');
end $$;

create or replace function public.leave_clan()
returns void language plpgsql security definer set search_path = public as $$
declare cid uuid; role text; uname text; heir uuid;
begin
  select clan_id, clan_role, username into cid, role, uname from profiles where id = auth.uid();
  if cid is null then return; end if;
  perform set_config('app.clan_rpc', '1', true);
  update profiles set clan_id = null, clan_role = 'member' where id = auth.uid();
  if role = 'leader' then
    select id into heir from profiles where clan_id = cid
      order by weekly_stars desc, created_at limit 1;
    if heir is null then
      delete from clans where id = cid;
      return;
    end if;
    update profiles set clan_role = 'leader' where id = heir;
    update clans set owner_id = heir where id = cid;
  end if;
  insert into clan_messages (clan_id, kind, body) values (cid, 'system', uname || ' takımdan ayrıldı.');
end $$;

create or replace function public.list_clans(p_search text default '')
returns table (id uuid, name text, description text, badge int, members bigint, weekly_stars bigint)
language sql stable security definer set search_path = public as $$
  select c.id, c.name, c.description, c.badge,
         count(p.id) as members,
         coalesce(sum(p.weekly_stars) filter (where p.week = current_week()), 0) as weekly_stars
  from clans c left join profiles p on p.clan_id = c.id
  where p_search = '' or c.name ilike '%' || p_search || '%'
  group by c.id
  order by weekly_stars desc, members desc
  limit 30
$$;

create or replace function public.clan_weekly_stars(p_clan uuid)
returns bigint language sql stable security definer set search_path = public as $$
  select coalesce(sum(weekly_stars), 0) from profiles
  where clan_id = p_clan and week = current_week()
$$;

-- Can isteği: aynı anda tek açık istek (5 yardım dolana kadar)
create or replace function public.request_lives()
returns bigint language plpgsql security definer set search_path = public as $$
declare cid uuid; mid bigint;
begin
  cid := my_clan();
  if cid is null then raise exception 'Önce bir takıma katıl'; end if;
  if exists (select 1 from clan_messages where user_id = auth.uid() and kind = 'life'
             and cardinality(helpers) < 5 and created_at > now() - interval '8 hours') then
    raise exception 'Zaten açık bir can isteğin var';
  end if;
  insert into clan_messages (clan_id, user_id, kind, body)
  values (cid, auth.uid(), 'life', 'Can lazım! Yardım eder misiniz? ❤️')
  returning id into mid;
  return mid;
end $$;

-- Takım arkadaşına can gönder (+5 altın teşekkür ödülü uygulamada verilir)
create or replace function public.help_life(p_msg bigint)
returns boolean language plpgsql security definer set search_path = public as $$
declare m clan_messages;
begin
  select * into m from clan_messages where id = p_msg for update;
  if m.id is null or m.kind <> 'life' or m.clan_id is distinct from my_clan()
     or m.user_id = auth.uid() or auth.uid() = any(m.helpers)
     or cardinality(m.helpers) >= 5 then
    return false;
  end if;
  update clan_messages set helpers = helpers || auth.uid() where id = p_msg;
  return true;
end $$;

-- Gelen yardımları topla → kaç can kazanıldığını döndürür
create or replace function public.claim_life_helps()
returns int language plpgsql security definer set search_path = public as $$
declare total int;
begin
  select coalesce(sum(cardinality(helpers) - claimed), 0) into total
  from clan_messages where user_id = auth.uid() and kind = 'life';
  update clan_messages set claimed = cardinality(helpers)
  where user_id = auth.uid() and kind = 'life' and claimed < cardinality(helpers);
  return total;
end $$;

-- Haftalık takım sandığı: 1=100, 2=250, 3=500 yıldız
create or replace function public.claim_chest(p_tier int)
returns boolean language plpgsql security definer set search_path = public as $$
declare cid uuid; need int; have bigint;
begin
  cid := my_clan();
  if cid is null then return false; end if;
  need := case p_tier when 1 then 100 when 2 then 250 when 3 then 500 else null end;
  if need is null then return false; end if;
  have := clan_weekly_stars(cid);
  if have < need then return false; end if;
  insert into chest_claims (user_id, week, tier) values (auth.uid(), current_week(), p_tier)
  on conflict do nothing;
  return found;
end $$;

-- ---------------------------------------------------------------------
-- RPC: SIRALAMA
-- ---------------------------------------------------------------------
create or replace function public.my_ranks()
returns table (global_rank bigint, weekly_rank bigint)
language sql stable security definer set search_path = public as $$
  with me as (select * from profiles where id = auth.uid())
  select
    (select count(*) + 1 from profiles p, me
      where p.total_stars > me.total_stars
         or (p.total_stars = me.total_stars and p.total_score > me.total_score)),
    (select count(*) + 1 from profiles p, me
      where p.week = current_week() and p.weekly_score >
            case when me.week = current_week() then me.weekly_score else 0 end)
$$;

-- ---------------------------------------------------------------------
-- Gerçek zamanlı sohbet
-- ---------------------------------------------------------------------
do $$ begin
  alter publication supabase_realtime add table public.clan_messages;
exception when duplicate_object then null; end $$;

-- Hesap silme (Play Store şartı): önce takımdan ayrılır (liderlik devredilir,
-- takım silinmez), sonra kullanıcı silinir; profil/kayıt/mesajlar kaskadla gider.
create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Giriş gerekli'; end if;
  if public.my_clan() is not null then perform public.leave_clan(); end if;
  delete from auth.users where id = auth.uid();
end $$;

grant execute on all functions in schema public to authenticated;
