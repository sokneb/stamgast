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
grant select, insert on public.stamgast_scores to anon, authenticated;
