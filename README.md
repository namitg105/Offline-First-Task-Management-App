# Offline-First Task Management App

GDG Tech Wildcard Entry — **App Development, Task 1**.

A Flutter task manager that is fully usable with no internet and reconciles
with a remote Postgres database when connectivity returns, without losing data
or creating duplicate records.

> **The one idea this app is built on:** the SQLite database on the phone is the
> source of truth. Supabase is a replica of it. No user action ever waits on the
> network — you write to SQLite, the screen updates, and a background worker
> catches up whenever it can.

---

## Implemented features

| Requirement | Where |
|---|---|
| Create, edit, delete tasks; complete/pending; priorities; deadlines; categories; search & filter | `features/tasks` |
| Offline operation with persistent SQLite storage | `core/database`, `features/tasks/data` |
| Online/offline indicator; tasks survive restart | `features/sync`, SQLite |
| Queue offline changes, retry failures, prevent duplicates, resolve conflicts | `features/sync/data/sync_service.dart` |
| Immediate UI updates, state preserved across navigation, loading/empty/error states | `features/tasks/presentation` |
| No data loss if the app restarts mid-sync | outbox + single transaction |
| Multi-device support for one account *(bonus)* | auth + per-user RLS |
| Sync activity visible to the user *(bonus)* | sync banner + per-task badge |

Authentication is included (email/password **and** Google) because the brief
requires syncing to a remote database and lists multi-device support for the
same account. Without an identity, every install would write into one shared
table. Signing in needs the internet once; after that the session is read from
disk and the app opens straight into the task list with no signal.

---

## Architecture

Three layers, feature-first, dependencies pointing inward only.

```
lib/
├── core/                     shared by every feature
│   ├── common/               User entity, AppUserBloc, shared widgets
│   ├── database/             AppDatabase — the only thing that opens SQLite
│   ├── error/                Failure (returned) and Exception (thrown)
│   ├── network/              ConnectionChecker
│   ├── theme/ usecase/ utils/ secrets/
├── features/
│   ├── auth/      domain · data · presentation
│   ├── tasks/     domain · data · presentation
│   └── sync/      domain · data · presentation
├── init_dependencies.dart    GetIt: the one place concrete classes are chosen
└── main.dart                 app shell; also where features are connected
```

Rules the codebase actually keeps to:

- **The domain layer is pure Dart.** No Flutter, no Supabase, no SQL, no JSON.
  You could run it in a console app.
- **Exceptions never escape the data layer.** Data sources throw; repositories
  catch and return `Either<Failure, T>`. There is no `try/catch` anywhere in
  the domain or presentation layers.
- **Features never import each other.** `auth` and `sync` have no knowledge of
  one another; they are wired together in `main.dart`, which is the app shell's
  job. Shared types such as `User` live in `core/common`.
- **Swapping Supabase for Firebase** would mean rewriting `data/datasources`
  and `data/models`. Zero lines of `domain/` or `presentation/` would change.
- **BLoC everywhere, no Cubits.** Every state change in the app arrives the
  same way — as a named event with a matching handler — so a bloc observer
  shows the whole app's behaviour as one readable log.
- **Events are named in the past tense**, because an event records something
  that already happened in the UI rather than ordering the bloc about:
  `AuthLoginSubmitted`, `TaskDeletionRequested`, `SyncWatchStarted`. Each has
  a handler of the same name prefixed with `_on`.
- **Blocs do not talk to other blocs.** `auth` never imports `sync`, `sync`
  never imports `auth`. Each reports what happened and `main.dart` — the app
  shell — forwards it on.

---

## Setup

### 1. Supabase

1. Create a project at <https://supabase.com>.
2. SQL Editor → run `offline_task_management_app/supabase/01_auth_schema.sql`,
   then `02_tasks_schema.sql`.
3. Project Settings → API → copy the **Project URL** and the **anon public** key.

### 2. Secrets

```bash
cd offline_task_management_app
cp lib/core/secrets/app_secrets.example.dart lib/core/secrets/app_secrets.dart
```

Fill in the Supabase URL, anon key, and your Google **Web** OAuth client ID.
The real file is gitignored.

### 3. Google sign-in

Two OAuth clients in one Google Cloud project:

| Client type | Used as |
|---|---|
| **Web** | `googleWebClientId`, **and** pasted into Supabase → Auth → Providers → Google |
| **Android** | package name + SHA-1; not referenced in code, but must exist |

Get the debug SHA-1:

```bat
keytool -list -v -alias androiddebugkey -keystore %USERPROFILE%\.android\debug.keystore -storepass android -keypass android
```

Release builds are signed with a different key — register that fingerprint too
before producing the submission APK, or Google sign-in works in debug and fails
in release.

### 4. Run

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Build the APK:

```bash
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

---

## How to test the offline behaviour

This is the part worth demonstrating, in this order:

1. **Sign in once with internet on.** Create two or three tasks and watch the
   banner go quiet as they sync.
2. **Turn on airplane mode.** The banner turns amber: *"Offline — your tasks
   still work."*
3. **Create, edit, complete and delete tasks offline.** Everything responds
   instantly. Unsynced rows show a small cloud-off icon. The banner counts the
   queued changes.
4. **Force-kill the app and reopen it** while still offline. Everything is
   still there, including the queue — nothing was held in memory.
5. **Turn airplane mode off and do nothing.** The queue drains by itself within
   a couple of seconds. No retry button needed.
6. **Check Supabase** → Table Editor → `tasks`. The rows are there with the
   same ids the device generated.
7. **Multi-device:** sign in on a second device and watch the tasks arrive.
   Edit the same task on both while offline, then reconnect both — the later
   edit wins and neither device ends up with a duplicate.

---

## Technical decisions

**SQLite via `sqflite`, with hand-written SQL, rather than Hive or Drift.**
The sync design needs real transactions (a task row and its queue row must
commit together), ordered queue processing, and indexed queries for search and
filtering. Hive is a key-value store and gives none of those. Drift would work
but adds a code-generation step; raw SQL keeps the schema and every query
visible in one file.

**Device-generated UUIDs instead of database-generated ids.** A task created in
airplane mode needs an identity the moment it exists. It is also what makes
retries safe: every push is an upsert keyed on that id, so sending the same
change twice lands on the same row instead of creating a second task.

**Soft deletes (tombstones).** A row that is simply gone cannot tell the server
it was deleted. The row is dropped for real only once the server has
acknowledged it.

**`updated_at` is set by the device, not by Postgres.** Conflict resolution
compares it, so a server-side trigger overwriting it would make a change made
at 9:00 offline arrive stamped 17:00 and beat an edit genuinely made at 11:00.

---

## Known limitations

- Conflict resolution is last-write-wins on `updated_at`, so a device with a
  badly wrong clock can win a conflict it should lose. A production version
  would send the device timestamp *and* a server-assigned sequence number and
  break ties on the latter.
- Sync runs while the app is alive. Backgrounded sync would need WorkManager
  (Android) / BGTaskScheduler (iOS).
- Tombstones accumulate in Postgres; a scheduled job should purge ones older
  than the longest plausible offline period.
- Tests cover the model layer. The local data source and sync engine are
  written against interfaces and are testable with `sqflite_common_ffi` and
  fakes, but those tests are not written yet.

---

## Documentation

- [`docs/SYNC.md`](offline_task_management_app/docs/SYNC.md) — offline storage,
  synchronisation and conflict resolution in detail
- [`docs/AUTH_SETUP.md`](offline_task_management_app/docs/AUTH_SETUP.md) — auth
  setup and the full token flow
- [`clean_architecture_guide_code_reference.md`](clean_architecture_guide_code_reference.md)
  — the architecture reference this project follows
