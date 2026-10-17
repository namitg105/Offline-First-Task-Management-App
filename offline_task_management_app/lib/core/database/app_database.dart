import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Owns the SQLite file: opening it, creating the schema, migrating it.
///
/// Nothing else in the app opens a database. One owner = one place to look
/// when something is wrong with persistence.
class AppDatabase {
  static const String _fileName = 'offline_tasks.db';

  /// Bump this and add a branch in [_onUpgrade] whenever the schema changes.
  static const int _schemaVersion = 1;

  Database? _database;

  Future<Database> get database async => _database ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), _fileName);
    return openDatabase(
      path,
      version: _schemaVersion,
      onConfigure: (db) async {
        // Off by default in SQLite, and we rely on it for the outbox.
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // ---------------------------------------------------------------------
    // tasks — the app's source of truth. Supabase is a replica of this.
    //
    // id is TEXT, not an auto-increment integer, because a task created in
    // airplane mode needs an identity the instant it exists. The device
    // generates a UUID v4; the server accepts it. That single decision is
    // what makes "prevent duplicates" possible later.
    // ---------------------------------------------------------------------
    batch.execute('''
      CREATE TABLE tasks (
        id           TEXT    PRIMARY KEY,
        user_id      TEXT    NOT NULL,
        title        TEXT    NOT NULL,
        description  TEXT    NOT NULL DEFAULT '',
        is_completed INTEGER NOT NULL DEFAULT 0,
        priority     INTEGER NOT NULL DEFAULT 1,
        category     TEXT    NOT NULL DEFAULT '',
        due_at       INTEGER,
        created_at   INTEGER NOT NULL,
        updated_at   INTEGER NOT NULL,
        deleted_at   INTEGER,
        is_synced    INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // The list screen always filters by owner and hides tombstones, so that
    // pair of columns is the index worth having.
    batch.execute(
      'CREATE INDEX idx_tasks_owner ON tasks (user_id, deleted_at)',
    );
    batch.execute('CREATE INDEX idx_tasks_due ON tasks (user_id, due_at)');
    batch.execute('CREATE INDEX idx_tasks_unsynced ON tasks (is_synced)');

    // ---------------------------------------------------------------------
    // outbox — one row per change that has not reached the server yet.
    //
    // A task row and its outbox row are written in the SAME transaction.
    // So the app can be killed at any instant and the database is still
    // consistent: either the change exists and is queued, or neither.
    // That is the brief's "recovery" requirement, enforced by the DBMS
    // rather than by hopeful Dart code.
    // ---------------------------------------------------------------------
    batch.execute('''
      CREATE TABLE outbox (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id       TEXT    NOT NULL,
        operation     TEXT    NOT NULL CHECK (operation IN ('upsert','delete')),
        payload       TEXT    NOT NULL,
        created_at    INTEGER NOT NULL,
        attempts      INTEGER NOT NULL DEFAULT 0,
        next_retry_at INTEGER NOT NULL DEFAULT 0,
        last_error    TEXT,
        FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE
      )
    ''');

    // The worker asks "what is due to be sent?" — this index answers it.
    // AUTOINCREMENT id doubles as the ordering key, so changes replay in the
    // order the user made them.
    batch.execute(
      'CREATE INDEX idx_outbox_ready ON outbox (next_retry_at, id)',
    );
    batch.execute('CREATE INDEX idx_outbox_task ON outbox (task_id)');

    // ---------------------------------------------------------------------
    // sync_meta — tiny key/value table. Currently remembers the timestamp of
    // the last successful pull, so we can ask the server for "only what
    // changed since then" instead of downloading everything each time.
    // ---------------------------------------------------------------------
    batch.execute('''
      CREATE TABLE sync_meta (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v1 is the first release; nothing to migrate yet. Future versions add
    // `if (oldVersion < 2) { ... }` blocks here, never edits to _onCreate.
  }
}
