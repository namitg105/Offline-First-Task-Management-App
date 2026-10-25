-- Auth feature schema. Run in Supabase Dashboard -> SQL Editor.
-- Supabase owns auth.users and you can't add columns to it, so app-level user data
-- lives in public.profiles, keyed by the same uuid.

create table if not exists public.profiles (
  id          uuid        primary key references auth.users (id) on delete cascade,
  name        text        not null default '',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Row Level Security: the real lock on the data. Without it anybody holding the
-- public key could read every profile. auth.uid() is read from the caller's JWT `sub`.
alter table public.profiles enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
  on public.profiles for select
  using (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Trigger: every new auth user automatically gets a profile row, so the app never
-- INSERTs one itself (one less network call, and no window where a user has no
-- profile). `security definer` lets it bypass RLS, which it must: at INSERT time
-- nobody is authenticated yet.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, name)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data ->> 'name',       -- email/password sign-up
      new.raw_user_meta_data ->> 'full_name',  -- Google sign-in
      split_part(coalesce(new.email, ''), '@', 1)
    )
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Keep updated_at honest.
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_touch_updated_at on public.profiles;
create trigger profiles_touch_updated_at
  before update on public.profiles
  for each row execute function public.touch_updated_at();
