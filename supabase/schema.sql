-- CowGetsGroceries Supabase schema

-- Lists
create table public.lists (
  id         uuid        primary key default gen_random_uuid(),
  name       text        not null default 'My List',
  created_by uuid        references auth.users not null,
  created_at timestamptz not null default now()
);
alter table public.lists enable row level security;

-- List members
create table public.list_members (
  list_id   uuid        references public.lists on delete cascade not null,
  user_id   uuid        references auth.users not null,
  role      text        not null default 'member',
  joined_at timestamptz not null default now(),
  primary key (list_id, user_id)
);
alter table public.list_members enable row level security;

-- Invite tokens (one per list)
create table public.list_invites (
  id         uuid        primary key default gen_random_uuid(),
  list_id    uuid        references public.lists on delete cascade not null unique,
  created_by uuid        references auth.users not null default auth.uid(),
  created_at timestamptz not null default now()
);
alter table public.list_invites enable row level security;

-- Items (list-scoped)
create table public.items (
  id        text        primary key,
  list_id   uuid        references public.lists on delete cascade not null,
  name      text        not null,
  qty       text,
  category  text,
  recipe    text,
  note      text,
  checked   boolean     not null default false,
  added_at  timestamptz not null default now()
);
alter table public.items enable row level security;

-- Purchase history (list-scoped)
create table public.grocery_history (
  id        text        primary key,
  list_id   uuid        references public.lists on delete cascade not null,
  name      text        not null,
  qty       text,
  category  text,
  recipe    text,
  note      text,
  bought_at timestamptz not null default now()
);
alter table public.grocery_history enable row level security;

-- Recipe tags (list-scoped)
create table public.recipe_tags (
  id      uuid primary key default gen_random_uuid(),
  list_id uuid references public.lists on delete cascade not null,
  name    text not null,
  unique(list_id, name)
);
alter table public.recipe_tags enable row level security;

-- Security-definer membership check: avoids recursive RLS on list_members
create or replace function public.is_list_member(p_list_id uuid)
returns boolean language sql security definer stable as $$
  select exists (
    select 1 from public.list_members
    where list_id = p_list_id and user_id = auth.uid()
  )
$$;

-- RLS policies (all use is_list_member to prevent infinite recursion)
create policy "members can view list" on public.lists
  for select using (public.is_list_member(id));
create policy "owner can update list" on public.lists
  for update using (created_by = auth.uid());

create policy "members can view members" on public.list_members
  for select using (public.is_list_member(list_id));

create policy "anyone can read invite" on public.list_invites for select using (true);
create policy "members can create invite" on public.list_invites
  for insert with check (public.is_list_member(list_id));
create policy "creator can delete invite" on public.list_invites for delete using (created_by = auth.uid());

create policy "list members manage items" on public.items
  for all using (public.is_list_member(list_id))
  with check (public.is_list_member(list_id));

create policy "list members manage history" on public.grocery_history
  for all using (public.is_list_member(list_id))
  with check (public.is_list_member(list_id));

create policy "list members manage tags" on public.recipe_tags
  for all using (public.is_list_member(list_id))
  with check (public.is_list_member(list_id));

-- Security-definer RPCs
create or replace function public.create_list_for_user()
returns uuid language plpgsql security definer as $$
declare v_list_id uuid := gen_random_uuid();
begin
  insert into public.lists (id, name, created_by) values (v_list_id, 'My List', auth.uid());
  insert into public.list_members (list_id, user_id, role) values (v_list_id, auth.uid(), 'owner');
  return v_list_id;
end; $$;

create or replace function public.join_list_via_invite(invite_token uuid)
returns uuid language plpgsql security definer as $$
declare v_list_id uuid;
begin
  select list_id into v_list_id from public.list_invites where id = invite_token;
  if v_list_id is null then raise exception 'Invalid invite'; end if;
  insert into public.list_members (list_id, user_id, role)
  values (v_list_id, auth.uid(), 'member')
  on conflict (list_id, user_id) do nothing;
  return v_list_id;
end; $$;

-- Table access grants (RLS policies enforce row-level restrictions)
grant select, insert, update, delete on public.lists to authenticated;
grant select, insert, update, delete on public.list_members to authenticated;
grant select, insert, update, delete on public.list_invites to authenticated;
grant select, insert, update, delete on public.items to authenticated;
grant select, insert, update, delete on public.grocery_history to authenticated;
grant select, insert, update, delete on public.recipe_tags to authenticated;
grant select on public.list_invites to anon;

-- Enable realtime
alter publication supabase_realtime add table public.items;
alter publication supabase_realtime add table public.grocery_history;
alter publication supabase_realtime add table public.recipe_tags;
alter publication supabase_realtime add table public.list_members;
