-- Cart&Co Supabase schema
-- Run this in the Supabase SQL editor for your project.

-- Items
create table public.items (
  id          text        primary key,
  user_id     uuid        references auth.users not null default auth.uid(),
  name        text        not null,
  qty         text,
  category    text,
  recipe      text,
  note        text,
  checked     boolean     not null default false,
  added_at    timestamptz not null default now()
);
alter table public.items enable row level security;
create policy "users manage own items" on public.items
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Purchase history
create table public.grocery_history (
  id          text        primary key,
  user_id     uuid        references auth.users not null default auth.uid(),
  name        text        not null,
  qty         text,
  category    text,
  recipe      text,
  note        text,
  bought_at   timestamptz not null default now()
);
alter table public.grocery_history enable row level security;
create policy "users manage own history" on public.grocery_history
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Recipe tags
create table public.recipe_tags (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        references auth.users not null default auth.uid(),
  name        text        not null,
  unique(user_id, name)
);
alter table public.recipe_tags enable row level security;
create policy "users manage own tags" on public.recipe_tags
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Enable realtime for all three tables (run in Supabase dashboard → Database → Replication)
-- or via SQL:
begin;
  select realtime.quote_wal2json('{}'::jsonb);
commit;
alter publication supabase_realtime add table public.items;
alter publication supabase_realtime add table public.grocery_history;
alter publication supabase_realtime add table public.recipe_tags;
