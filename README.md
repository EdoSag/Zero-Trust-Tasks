# Zero-Trust Tasks

End-to-end encrypted tasks and reminders: to-dos, errands and plans in
simple lists, with reminders that arrive on time. On the phone it is called
**ZT Tasks**; in stores and on release pages, **Zero-Trust Tasks**. Same
account, settings and look as the other Zero-Trust apps, built on
[Zero-Trust-Core](https://github.com/EdoSag/Zero-Trust-Core). Part of the
[Zero-Trust suite](https://zerotrust.bz).

Account, keys, vault lock (auto-lock, biometrics), sync, settings and theme
come from Zero-Trust-Core (pinned in `pubspec.yaml`). This repo holds only
what is Tasks': the task model and screens, reminders, templates, smart
filters, insights and backup files.

## What it does

- **Lists** with their own colours; move tasks between them. View a list as
  a list, a board or a calendar.
- **Subtasks:** drag a task onto another to indent it, and drag to reorder.
  Star the important ones and see them in one Starred view.
- **Quick add** in plain words, English and Hebrew ("call mum tomorrow
  6pm"); see [Quick add](#quick-add).
- **Reminders** with Complete and Snooze buttons on the notification, and
  **place reminders** when you arrive at or leave a place (Core's
  `zt_places`, watched by the phone itself, no Google Play services).
- **Repeating tasks** and due dates, which also show in ZT Calendar.
- **Priorities, tags, search and smart filters**, templates for tasks you
  make often, and an Insights dashboard.
- **Focus timer:** time a task while you work on it; the minutes are added
  to the task, and can be logged to ZT Time.
- **Shared lists** with family or friends who use Zero-Trust, end-to-end
  encrypted (Core's shared spaces): invite by link or QR code, assign tasks
  to people and comment on them.
- **Linked with the other apps:** link a task to notes and contacts, let ZT
  Calendar's Planner find time for it, show a list in a ZT Family circle,
  count ticked tasks in ZT Quests, and pick a task's text from ZT Keyboard
  ("Insert from ZT apps").
- **Home screen widget** (Android): your list, tick off tasks and add new
  ones.
- **Import** from Google Tasks (Google Takeout), Todoist (CSV or backup
  .zip), Microsoft To Do (.json) and TickTick (.csv).
- **Backup file:** export every task to a password-protected file and
  import it again, with a preview of what will change.

## Privacy

Like every Zero-Trust app, it is zero-knowledge: your data is encrypted on
your device, with keys made from your password, before anything is sent.
The server stores only ciphertext and your password itself is never
sent, so neither we nor anyone who breaks into the server can read your
data. The recovery key shown at sign-up is the only way back in if you
forget the password. How the keys work:
[Zero-Trust-Core](https://github.com/EdoSag/Zero-Trust-Core#key-hierarchy) and
[zerotrust.bz/security](https://zerotrust.bz/security/).

What works while the vault is locked, and what that leaves on the phone, is
under [Outside the vault](#outside-the-vault).

## One account, one core

One Zero-Trust account opens every app in the suite. Sign-in, unlock
(fingerprint or face, auto-lock), the recovery key, settings, the look,
sync and languages come from
[Zero-Trust-Core](https://github.com/EdoSag/Zero-Trust-Core), so they work
the same in every app. Accounts made before the core still sign in and
see their data.

## Install

Android: get the latest signed APK from this repository's
[Releases](https://github.com/EdoSag/Zero-Trust-Tasks/releases/latest),
or from [zerotrust.bz/install](https://zerotrust.bz/install/#tasks),
which also shows each file's SHA-256, the signing fingerprint and an
Obtainium link. GitHub Releases are the main way the apps are published.

Builds from GitHub check for a newer release themselves (Settings > About,
one anonymous request a day, can be turned off). Every Zero-Trust app is signed
with the same key, and Android only installs an update signed with it.

## Languages

English and Hebrew, with right-to-left layout. Choose under
Settings > Appearance > Language.

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
the device. A time of day also sets the reminder. A length ("2h", "45 min",
"שעה וחצי") is kept for ZT Calendar's Planner. "Keep as typed" turns the
reading off; "More options" opens the full editor.

## ZT Calendar's Planner

ZT Calendar can plan time for tasks in its calendar. The task editor has
**Length** and **Auto-schedule**, and under "Planner options" the shortest
and longest block and work or personal hours. A list can plan every new
task added to it (list options, "Plan new tasks in ZT Calendar"; not for
shared lists, which the Planner doesn't read yet).

These are the keys `planMinutes`, `planAuto`, `planMinChunk`,
`planMaxChunk` and `planHours` on the task (`lib/models/task_plan.dart`).
They are written only when set and kept with the keys an older version
doesn't know, so tasks that never used them are unchanged. ZT Calendar
writes the same keys from its own Planner screen.

Once a task has one of them, Tasks also reads ZT Calendar's Planned
calendar, read-only like Notes and Contacts (`lib/suite/planned_times.dart`),
and shows "Planned: Tomorrow 10:00 · 1 h of 3 h done" on the task and its
page.

## Links to ZT Notes and ZT Contacts (and the Planner's times)

A task can link to notes and contacts from the same account (`noteIds`,
`contactIds`, the key names ZT Calendar uses). At unlock the app derives
the Notes and Contacts keys from the account key (`lib/suite/linked_apps.dart`)
and keeps its own encrypted, read-only copy of those items; it never
writes to the other apps. The keys are zeroed when the vault locks.

## Lists in the ZT Family hub

A list's options have **Show in family circle**. When it is on, the phone
copies that list into the chosen ZT Family circle's family space
(`lib/suite/family_circle.dart`): one `tasks.list` item for the list and a
`tasks.item` item per task, keyed `tasks/<kind>/<user id>/<id>` (list ids
such as `default` are only unique per account), each with the short
summary the Family hub reads (title, due date, done). Open tasks are copied,
and done ones for 7 days. The copy is one-way and read-only: edits still
happen in Tasks, and turning the switch off or deleting the list removes
its items from the circle. Other members' items are never touched. Everyone in the circle can read the copied titles.

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

## Build from source

Flutter 3.47.9, the version CI pins (3.50 deprecates `material.dart` and
fails analyze).

```bash
# .env (not committed; CI writes its own). Public client values only:
# never a service-role key, because .env is bundled into the APK.
SUPABASE_URL=https://<project>.supabase.co
SUPABASE_ANON_KEY=<publishable key>

flutter pub get
dart run zt_release_checks --app tasks   # shared release checks
flutter analyze && flutter test
flutter run
```

Never add `cryptography_flutter`: it breaks the core's key derivation and
sign-in fails.

`.env.example` has the same lines to copy. CI writes the public Supabase
values itself, or uses an `ENV_FILE` secret if one is set.

The tests run without Supabase: `test/app_test.dart` signs up, signs in a
pre-core account (same phone and new phone), and checks the old tasks show
up and sync.

## Branches and releases

Work happens on `Dev`: pull requests target `Dev`, never `main`, and get a
test build. A release is one `Dev` → `main` pull request. Every push to
`main` runs the suite's release checks, builds a signed APK and a Google Play bundle
and publishes them as a GitHub Release named "Zero-Trust Tasks"
(`.github/workflows/android-apk.yml`). The workflow needs the repository
secrets `ANDROID_KEYSTORE_BASE64` and `ANDROID_KEYSTORE_PASSWORD`, the
keystore shared by all Zero-Trust apps.

## Support and security

- Help centre: [zerotrust.bz/help](https://zerotrust.bz/help/). Questions and
  account deletion: support@zerotrust.bz.
- Security problems: please report them privately to cyber@zerotrust.bz. What
  the encryption does and doesn't protect against is on
  [zerotrust.bz/security](https://zerotrust.bz/security/).
- [Privacy policy](https://zerotrust.bz/privacy/) and
  [terms](https://zerotrust.bz/terms/).

## License

Copyright (C) 2026 Edo Sagron (https://zerotrust.bz)

Zero-Trust is open source under the [GNU Affero General Public License v3.0](LICENSE)
(AGPL-3.0-only), the same licence Signal uses.

- You may use, study, change and share the code, including in your own projects.
- If you share a changed version, or run it for other people over a network, you must
  publish your full source code under the same licence.
- This program comes with no warranty; see the licence for details.

Third-party libraries keep their own licences; the app lists them under
Settings > Open-source licences.

### Name and logo

The AGPL covers the code, not the brand. "Zero-Trust", "ZT", the app names and icons are
reserved. If you publish a fork, give it a different name and icon so nobody mistakes it
for an official Zero-Trust app.

### Servers

The official apps use the Zero-Trust servers. A fork must use its own backend (for
example its own Supabase project) and must not connect to the official servers.

### Contributing

Pull requests are welcome. By sending one you agree that your contribution is licensed
under the AGPL-3.0 and that the copyright holder may also license it under other terms,
including commercially. This keeps the project able to offer paid plans and other licences.
