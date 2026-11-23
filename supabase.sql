-- Štamgast Simulátor 3D – online žebříček
-- Spustit v Supabase projektu "stamgast" (SQL Editor nebo migrace).

create table if not exists public.stamgast_scores (
  id          bigint generated always as identity primary key,
  name        text        not null check (char_length(btrim(name)) between 1 and 18),
  score       integer     not null check (score between 0 and 2000000),
  ending      text        not null check (ending in ('FALL','PEE','BLACKOUT','MAMKA','ZAVIRACKA')),
  drinks      integer     not null default 0 check (drinks between 0 and 500),
  max_promile numeric(4,2) not null default 0 check (max_promile between 0 and 5),
  duration    integer     not null default 0 check (duration between 0 and 600),
  created_at  timestamptz not null default now(),
  -- hrubá ochrana proti vymyšleným skóre (volnější kvůli výhrám v ruletě; hra skóre ořezává stejně)
  constraint plausible_score check (score <= duration * 15000 + 50000)
);

create index if not exists stamgast_scores_score_idx on public.stamgast_scores (score desc);

alter table public.stamgast_scores enable row level security;

-- kdokoliv může přidat skóre a číst žebříček; měnit ani mazat nejde
create policy "anyone can insert a score" on public.stamgast_scores
  for insert to anon, authenticated with check (true);
create policy "anyone can read scores" on public.stamgast_scores
  for select to anon, authenticated using (true);

-- nejlepší skóre každého jména (bez ohledu na velikost písmen)
create or replace view public.stamgast_top with (security_invoker = true) as
  select distinct on (lower(btrim(name))) btrim(name) as name, score, ending, created_at
  from public.stamgast_scores
  order by lower(btrim(name)), score desc, created_at asc;

grant select on public.stamgast_top to anon, authenticated;

-- ---------- hospodský chat ----------
create table if not exists public.stamgast_chat (
  id          bigint generated always as identity primary key,
  name        text not null check (char_length(btrim(name)) between 1 and 18),
  msg         text not null default '',
  kind        text not null default 'msg' check (kind in ('msg', 'game')),
  gif         text constraint stamgast_chat_gif_check check (gif is null or gif ~ '^[A-Za-z0-9]{5,40}$'),  -- jen GIPHY ID
  ip_hash     text,
  created_at  timestamptz not null default now(),
  constraint stamgast_chat_msg_check check (
    char_length(btrim(msg)) <= 200 and msg !~* '(https?://|www\.)'
    and (char_length(btrim(msg)) >= 1 or gif is not null))
);
alter table public.stamgast_chat enable row level security;
create policy "read recent chat" on public.stamgast_chat for select to anon, authenticated using (created_at > now() - interval '3 days');
create policy "post chat" on public.stamgast_chat for insert to anon, authenticated with check (true);
revoke all on public.stamgast_chat from anon, authenticated;
grant select (id, name, msg, kind, gif, created_at) on public.stamgast_chat to anon, authenticated;
grant insert (name, msg, kind, gif) on public.stamgast_chat to anon, authenticated;
-- + trigger stamgast_chat_guard (limit 5 zpráv / 30 s podle hashe IP), viz migrace v Supabase
grant select, insert on public.stamgast_scores to anon, authenticated;
