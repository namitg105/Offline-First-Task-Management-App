-- Tasks table: the SERVER-SIDE REPLICA. The device's SQLite file is the source of
-- truth; this table is a mirror that lets a second device catch up.

create table if not exists public.tasks (
  id           uuid        primary key,                  -- generated ON THE DEVICE
  user_id      uuid        not null references auth.users (id) on delete cascade,
  title        text        not null,
  description  text        not null default '',
  is_completed boolean     not null default false,
  priority     smallint    not null default 1,           -- 0 low, 1 medium, 2 high
  category     text        not null default '',
  due_at       timestamptz,
  created_at   timestamptz not null,
  updated_at   timestamptz not null,
  deleted_at   timestamptz                                -- tombstone
);

-- Why the id is NOT `uuid default gen_random_uuid()`:
-- a task created in airplane mode already has an id. If Postgres minted its
-- own, the same task would arrive twice under two different ids the moment a
-- retry happened. Device-generated ids + upsert = replay-safe.

-- Delta-pull index. Every sync asks for "this user's rows changed since <timestamp>":
--   SELECT * FROM tasks WHERE user_id = $1 AND updated_at > $2;
-- Without it that is a full scan of every user's tasks.
create index if not exists idx_tasks_user_updated
  on public.tasks (user_id, updated_at desc);

create index if not exists idx_tasks_user_due
  on public.tasks (user_id, due_at);

-- Row Level Security: auth.uid() comes from the caller's JWT `sub`, so a user cannot
-- read or write another user's tasks even with a hand-crafted request.
alter table public.tasks enable row level security;

drop policy if exists "tasks_select_own" on public.tasks;
create policy "tasks_select_own" on public.tasks
  for select using (auth.uid() = user_id);

drop policy if exists "tasks_insert_own" on public.tasks;
create policy "tasks_insert_own" on public.tasks
  for insert with check (auth.uid() = user_id);

drop policy if exists "tasks_update_own" on public.tasks;
create policy "tasks_update_own" on public.tasks
  for update using (auth.uid() = user_id)
             with check (auth.uid() = user_id);

drop policy if exists "tasks_delete_own" on public.tasks;
create policy "tasks_delete_own" on public.tasks
  for delete using (auth.uid() = user_id);

-- NOTE: deliberately NO `before update set updated_at = now()` trigger, unlike on
-- public.profiles. Conflict resolution is last-write-wins on updated_at; if
-- Postgres restamped it, an offline change made at 9:00 would arrive stamped 17:00
-- and beat an edit genuinely made at 11:00 on another device. The device that made
-- the change owns the timestamp.
--
-- Trade-off: a device with a badly wrong clock can win conflicts it should lose. A
-- production app would send device time AND a server-assigned sequence number and
-- break ties on the latter.
