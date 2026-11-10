import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_tasks/components/linked_items_section.dart';
import 'package:zero_trust_tasks/components/quick_add_sheet.dart';
import 'package:zero_trust_tasks/models/task.dart';
import 'package:zero_trust_tasks/suite/linked_apps.dart';
import 'package:zero_trust_tasks/suite/linked_items.dart';

final _notes = [
  LinkedNote(id: 'n1', title: 'Trip plan', body: 'Trip plan\nBook the ferry', updatedAt: DateTime(2026, 11, 1)),
  LinkedNote(id: 'n2', title: '', body: 'רשימת קניות\nחלב', updatedAt: DateTime(2026, 11, 2)),
];
const _contacts = [
  LinkedContact(id: 'c1', name: 'Dana Levi', phones: ['+972 50 000 0000'], emails: ['dana@example.com']),
  LinkedContact(id: 'c2', name: 'Plumber', phones: ['03 000 0000']),
];

class _Host extends StatefulWidget {
  const _Host({required this.noteIds, required this.contactIds});
  final List<String> noteIds;
  final List<String> contactIds;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late List<String> notes = widget.noteIds;
  late List<String> contacts = widget.contactIds;
  @override
  Widget build(BuildContext context) => LinkedItemsSection(
        noteIds: notes,
        contactIds: contacts,
        onChanged: (n, c) => setState(() {
          notes = n;
          contacts = c;
        }),
      );
}

Future<void> _pump(WidgetTester tester, {List<String> noteIds = const [], List<String> contactIds = const []}) {
  return tester.pumpWidget(ProviderScope(
    overrides: [
      linkedNotesProvider.overrideWith((ref) => Stream.value(_notes)),
      linkedContactsProvider.overrideWith((ref) => Stream.value(_contacts)),
    ],
    child: MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: _Host(noteIds: noteIds, contactIds: contactIds))),
    ),
  ));
}

void main() {
  test('a task keeps its links, and writes nothing when it has none', () {
    final plain = Task.create(title: 'Plain');
    expect(plain.toJson().containsKey('noteIds'), isFalse);
    expect(plain.toJson().containsKey('contactIds'), isFalse);

    final linked = Task.create(title: 'Call Dana', noteIds: ['n1'], contactIds: ['c1', 'c2']);
    final back = Task.fromJson(linked.toJson());
    expect(back.noteIds, ['n1']);
    expect(back.contactIds, ['c1', 'c2']);
    expect(back.extra, isEmpty);
    expect(back.copyWith(noteIds: []).toJson().containsKey('noteIds'), isFalse);
    // Anything odd in the JSON is skipped rather than breaking the task.
    expect(Task.fromJson({...linked.toJson(), 'noteIds': 'n1', 'contactIds': [1, 'c2']}).contactIds, ['c2']);
  });

  test('notes and contacts are read from the other apps\' items', () {
    final at = DateTime(2026, 11, 10);
    expect(LinkedNote.fromItem('n', {'title': '', 'body': 'First line\nSecond'}, at)!.displayTitle, 'First line');
    expect(LinkedNote.fromItem('n', {'title': '', 'body': 'First line\nSecond'}, at)!.preview, 'Second');
    expect(LinkedNote.fromItem('n', {'kind': 'notebook', 'title': 'Work'}, at), isNull);
    expect(LinkedNote.fromItem('n', {'title': 'Old', 'trashedAt': '2026-11-01'}, at), isNull);

    final c = LinkedContact.fromItem('c', {
      'kind': 'contact',
      'firstName': 'Dana',
      'lastName': 'Levi',
      'phones': ['050-0000000'],
      'emails': [
        {'value': 'dana@example.com'},
      ],
    })!;
    expect(c.name, 'Dana Levi');
    expect(c.detail, '050-0000000');
    expect(c.emails, ['dana@example.com']);
    expect(LinkedContact.fromItem('c', {'kind': 'contact', 'firstName': 'X', 'trashedAt': 'now'}), isNull);
    expect(LinkedContact.fromItem('c', {'kind': 'group', 'name': 'Family'}), isNull);
  });

  testWidgets('linked notes and contacts show by name and can be removed', (tester) async {
    await _pump(tester, noteIds: ['n1', 'gone'], contactIds: ['c1']);
    await tester.pumpAndSettle();
    expect(find.text('Trip plan'), findsOneWidget);
    expect(find.text('Book the ferry'), findsOneWidget);
    expect(find.text('Dana Levi'), findsOneWidget);
    expect(find.textContaining('Note not found'), findsOneWidget);

    // The name sits above the detail, not on top of it.
    final name = tester.getRect(find.text('Dana Levi'));
    final phone = tester.getRect(find.text('+972 50 000 0000'));
    expect(name.bottom, lessThanOrEqualTo(phone.top));

    await tester.tap(find.text('Dana Levi'));
    await tester.pumpAndSettle();
    expect(find.text('Call +972 50 000 0000'), findsOneWidget);
    expect(find.text('Email dana@example.com'), findsOneWidget);
    expect(find.text('Open ZT Contacts'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Remove link').first);
    await tester.pumpAndSettle();
    expect(find.text('Trip plan'), findsNothing);
  });

  testWidgets('the picker searches and links more', (tester) async {
    await _pump(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Link a note'));
    await tester.pumpAndSettle();
    expect(find.text('Trip plan'), findsOneWidget);
    expect(find.text('רשימת קניות'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Search notes'), 'קניות');
    await tester.pumpAndSettle();
    expect(find.text('Trip plan'), findsNothing);
    await tester.tap(find.text('רשימת קניות'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();
    expect(find.text('רשימת קניות'), findsOneWidget);
    expect(find.text('חלב'), findsOneWidget);

    await tester.tap(find.text('Link a contact'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plumber'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();
    expect(find.text('Plumber'), findsOneWidget);
    expect(find.text('03 000 0000'), findsOneWidget);
  });

  test('due dates read back in plain words', () {
    final now = DateTime(2026, 11, 10, 10, 30);
    expect(describeDue(DateTime(2026, 11, 10), false, now: now), 'Today');
    expect(describeDue(DateTime(2026, 11, 11, 18), true, now: now), 'Tomorrow 18:00');
    expect(describeDue(DateTime(2026, 11, 13), false, now: now), 'Fri 13 Nov');
    expect(describeDue(DateTime(2027, 5, 12, 14), true, now: now), '12 May 2027 14:00');
  });
}
