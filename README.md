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
- `lib/data/task_collections.dart` defines the collections: tasks (items
  with no `kind`), templates (`kind: template`) and task lists
  (`kind: task_list`). A task's `listId`, `starred` and `position` keys are
  written only when set, and keys a newer version adds are kept as they are,
  so tasks still open in earlier builds.

## Quick add

The "New Task" button opens one line (`QuickAddSheet`). `QuickAddParser`
reads dates, times, repeats, `!priority` and `#tags` from it, in English
and Hebrew ("call mum tomorrow 6pm", "להתקשר לאמא מחר ב-18:00"), all on
the device. A time of day also sets the reminder. "Keep as typed" turns
the reading off; "More options" opens the full editor.

## Links to ZT Notes and ZT Contacts

A task can link to notes and contacts from the same account (`noteIds`,
`contactIds`, the key names ZT Calendar uses). At unlock the app derives
the Notes and Contacts keys from the account key (`lib/suite/linked_apps.dart`)
and keeps its own encrypted, read-only copy of those items; it never
writes to the other apps. The keys are zeroed when the vault locks.

## Outside the vault

Three things work while the vault is locked, and keep as little as possible
unencrypted on the phone:

- **Reminder buttons** (Complete, Snooze 1 hour) and **widget ticks** only
  queue the task id (`PendingActionsStore`); the app applies them at the
  next unlock.
- **Home-screen widget** (`TaskListWidgetProvider.kt`): counts only by
  default. Task titles are written for the launcher only when "Show details
  on the home screen" is on, and cleared on sign-out. It uses the shared
  widget look from Zero-Trust-Core's `android-widget-kit` and shows more
  rows as it is made taller.
- **Reminder text** is generic unless "Show task details in notifications"
  is on.

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

The old pepper (`APP_INTERNAL_SALT`) is a constant in
`lib/legacy/legacy_tasks_import.dart`, so it no longer has to live in `.env`.

## Configuration

`.env` is not committed. Copy `.env.example` to `.env` for local builds. CI
writes the same public Supabase values itself, or uses an `ENV_FILE` secret if
one is set. Never put a service-role key or any other server secret in `.env`:
it is bundled into the APK.

## Development

```bash
flutter pub get
flutter test
flutter analyze
```

The tests run without Supabase: `test/app_test.dart` signs up, signs in a
pre-core account (same phone and new phone), and checks the old tasks show
up and sync.
