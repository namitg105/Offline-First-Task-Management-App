# Offline storage, synchronisation and conflict resolution

The brief asks for a short technical explanation of these three things. This is
it.

---

## 1. The core decision

**The SQLite database on the device is the source of truth. Postgres is a
replica of it.**

Every other decision follows from that sentence:

- the UI reads from SQLite and only from SQLite
- a user action is finished when SQLite says so, not when the server replies
- the sync engine is allowed to be slow, because nobody is waiting for it

The opposite design — "ask the server, cache the answer" — makes every action
depend on a round trip, and offline becomes a degraded mode you bolt on
afterwards. Here, offline *is* the normal mode and the network is the optional
extra.

---

## 2. Local storage

Three tables, created in `core/database/app_database.dart`.

### `tasks`

```sql
id           TEXT    PRIMARY KEY,    -- UUID v4, generated ON THE DEVICE
user_id      TEXT    NOT NULL,
title        TEXT    NOT NULL,
description  TEXT    NOT NULL DEFAULT '',
is_completed INTEGER NOT NULL DEFAULT 0,
priority     INTEGER NOT NULL DEFAULT 1,
category     TEXT    NOT NULL DEFAULT '',
due_at       INTEGER,
created_at   INTEGER NOT NULL,
updated_at   INTEGER NOT NULL,       -- the conflict-resolution key
deleted_at   INTEGER,                -- tombstone
is_synced    INTEGER NOT NULL DEFAULT 0
```

SQLite has no `BOOLEAN` and no `DATETIME`: booleans are `0/1` and instants are
epoch milliseconds, which compare and sort correctly as integers.

**Why the id is a device-generated UUID, not an auto-increment integer.**
A task created in airplane mode needs an identity the instant it exists. If
Postgres minted the id, the same task would arrive twice under two different
ids the first time a push was retried. Device-generated ids plus upsert is what
makes "prevent duplicate records" possible at all.

### `outbox`

```sql
id            INTEGER PRIMARY KEY AUTOINCREMENT,  -- also the replay order
task_id       TEXT    NOT NULL,
operation     TEXT    NOT NULL,                   -- 'upsert' | 'delete'
payload       TEXT    NOT NULL,                   -- JSON snapshot
created_at    INTEGER NOT NULL,
attempts      INTEGER NOT NULL DEFAULT 0,
next_retry_at INTEGER NOT NULL DEFAULT 0,
last_error    TEXT
```

One row per change the server has not seen. It stores a **full snapshot**, not
just the task id, because by the time the worker reaches this row the user may
have edited the task three more times — replaying intent in order needs the
value as it was at that moment.

### `sync_meta`

A key/value table holding `last_pulled_at`, so each sync can ask the server for
a delta instead of the whole table.

---

## 3. Why a task write and a queue write are one transaction

```dart
await db.transaction((txn) async {
  await txn.insert('tasks', task.toLocalRow(), conflictAlgorithm: replace);
  await _enqueue(txn, task, OutboxOperation.upsert);
});
```

The brief asks the app to "prevent data loss if the application restarts while
synchronization is unfinished". This is where that is answered.

If these were two separate writes, killing the app in between leaves one of two
broken states: a task that will never sync, or a queued change for a task that
does not exist. Inside one transaction, SQLite guarantees both or neither. The
invariant is enforced by the database, not by hopeful Dart code.

**Outbox entries also collapse.** Ticking a checkbox ten times offline queues
one operation, not ten:

```sql
DELETE FROM outbox WHERE task_id = ? AND attempts = 0;
INSERT INTO outbox (...) VALUES (...);
```

Entries that have already been attempted are left alone — one of them may be in
flight right now.

---

## 4. Deletes are tombstones

A row that is simply `DELETE`d locally cannot tell the server it was deleted,
and a second device would happily push it back. So a delete sets `deleted_at`,
queues a `delete` operation, and the row stays. Queries filter on
`deleted_at IS NULL`, so the task disappears from the UI immediately.

The row is dropped for real only after the server acknowledges the delete.
On the server the tombstone stays, so other devices learn about it on their
next pull.

---

## 5. The sync cycle

`features/sync/data/sync_service.dart`. **Push first, then pull** — our own
pending changes reach the server before we ask what the server has, so we never
pull a stale row over an edit that was about to overwrite it.

### What triggers it

| Trigger | Why |
|---|---|
| A local write, debounced 2s | changes start travelling almost immediately, but editing a title is one push, not one per keystroke |
| Connectivity returning | the case that matters most: the queue drains by itself, with no retry button to hunt for |
| A 2-minute heartbeat | catches changes made while the app was closed, and servers that came back quietly |
| Pull-to-refresh / tapping the banner | the user asked |

A **single-flight guard** means connectivity returning mid-heartbeat cannot
push the same rows twice.

### Push

```
loop:
  entries = SELECT * FROM outbox WHERE next_retry_at <= now ORDER BY id LIMIT 25
  for each entry:
      upsert payload to Postgres
      success -> delete the outbox row; mark the task synced if nothing else
                 is queued for it
      failure -> attempts++, next_retry_at = now + backoff, record the error,
                 CONTINUE WITH THE NEXT ENTRY
```

Three things are deliberate here:

1. **Ordered by `id`** — changes replay in the order the user made them.
2. **Upsert, never insert** — `INSERT ... ON CONFLICT (id) DO UPDATE`. If the
   app died after the server committed but before we deleted the outbox row,
   the retry lands on the same row. Idempotency is what makes retrying safe.
3. **One failure never blocks the others.** A single task rejected by a
   constraint must not freeze every other change behind it.

### Backoff

`2s, 4s, 8s … capped at 5 minutes`, plus up to 1s of random jitter.

The jitter is not decoration. Without it, every phone that lost signal in the
same tunnel retries at the same instant and stampedes the server the moment the
train comes out.

### Pull

```sql
SELECT * FROM tasks
WHERE user_id = $1 AND updated_at > $2
ORDER BY updated_at ASC;
```

Indexed by `(user_id, updated_at DESC)` on the server.

The watermark then advances to **the newest `updated_at` the server reported**,
not this device's clock. If the two clocks disagree, using local time here
would make the app silently skip rows forever.

---

## 6. Conflict resolution

Two devices edit the same task while both are offline. Both reconnect.

```
for each row the server sent:
    if we have no local copy          -> insert it
    else if the local copy is unsynced -> KEEP LOCAL, skip
    else if remote.updated_at > local.updated_at -> overwrite local
    else                                         -> keep local
```

**Rule 1 (unsynced local wins) is the important one.** A local row that is not
yet synced has a matching entry sitting in the outbox that is about to
overwrite the server anyway. Letting the server's older copy win here would
silently destroy work the user has already done, and then the outbox would push
the destroyed version up. So pending local changes are never clobbered.

**Rule 2 is last-write-wins on `updated_at`**, which is why `updated_at` is
stamped by the device in exactly one place (`TaskRepositoryImpl.updateTask`)
and why there is deliberately **no** `BEFORE UPDATE SET updated_at = now()`
trigger on the Postgres table. If the server overwrote that value, a change
made at 09:00 offline would arrive stamped 17:00 and beat an edit genuinely
made at 11:00 on another device.

**The honest trade-off:** last-write-wins loses the other edit, and a device
with a badly wrong clock can win a conflict it should lose. A production
version would send the device timestamp *and* a server-assigned sequence
number, break ties on the sequence number, and for text fields consider a CRDT
rather than whole-row replacement.

---

## 7. What the user sees

- a banner: *Offline* / *Syncing…* / *N changes waiting to sync* / *Sync failed*
- nothing at all when everything is synced — a permanent status bar is one
  people learn to look straight past, which is exactly where you do not want
  them when it says "offline"
- a small cloud-off icon on any task that exists only on this device

---

## 8. Where to look in the code

| Concern | File |
|---|---|
| Schema, indexes, migrations | `core/database/app_database.dart` |
| Transactions, outbox, conflict merge | `features/tasks/data/datasources/task_local_data_source.dart` |
| Push, pull, retry, backoff | `features/sync/data/sync_service.dart` |
| Upsert and delta fetch | `features/tasks/data/datasources/task_remote_data_source.dart` |
| Server schema and RLS | `supabase/02_tasks_schema.sql` |
