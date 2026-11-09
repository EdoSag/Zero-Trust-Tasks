# Zero-Trust Tasks

End-to-end encrypted tasks and reminders. Part of the Zero-Trust apps: one
account, one look, and the same security in Tasks, Notes, Fitness and
Contacts. On the phone it is called **ZT Tasks**.

Account, keys, vault lock (auto-lock, biometrics), sync, settings and theme
come from [Zero-Trust-Core](https://github.com/EdoSag/Zero-Trust-Core)
(pinned by tag in `pubspec.yaml`). This repo holds only what is Tasks':
the task model and screens, reminders, templates, smart filters, insights
and backup files.

## How data is stored

- Every task (and template) is its own encrypted, signed item in the
  shared `vault_items` table, synced by the core. On the device the core's
  encrypted SQLite store holds them; nothing readable is written to disk.
- `lib/data/task_collections.dart` defines the two collections: tasks
  (items with no `kind`) and templates (`kind: template`).

## Data from before the core

Versions before 0.1.0 kept tasks in SharedPreferences (`encrypted_tasks`)
and in the old `encrypted_tasks` / `encrypted_task_items` tables, encrypted
with PBKDF2 over `"<APP_INTERNAL_SALT>:<password>"`. That key is not the
core's legacy key (which has no prefix), so Tasks reads it itself
(`lib/legacy/`):

1. On first unlock the app reads the old local and cloud copies and merges
   them (newest copy of each task wins, cloud tombstones apply).
2. It opens them with the key the old app kept in secure storage on the same
   phone. On a new phone it asks once for the password.
3. The tasks go into the synced store through the core's `LegacyImporter`,
   once per device. The old data is only read, never changed.

`APP_INTERNAL_SALT` must stay in `.env` until the old tables are retired.

## Development

```bash
flutter pub get
flutter test
flutter analyze
```

The tests run without Supabase: `test/app_test.dart` signs up, signs in a
pre-core account (same phone and new phone), and checks the old tasks show
up and sync.
