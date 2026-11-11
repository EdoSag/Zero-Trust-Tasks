import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';
import 'package:zero_trust_tasks/models/recurrence_rule.dart';

void main() {
  test('every English string has a Hebrew translation with the same placeholders', () {
    Map<String, dynamic> read(String lang) =>
        jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;
    final en = read('en');
    final he = read('he');
    final placeholder = RegExp(r'\{(\w+)[,}]');
    Set<String?> names(String text) => placeholder.allMatches(text).map((m) => m[1]).toSet();
    for (final key in en.keys.where((k) => !k.startsWith('@'))) {
      expect(he[key], isA<String>(), reason: 'app_he.arb is missing "$key"');
      expect(names(he[key] as String), names(en[key] as String), reason: 'placeholders differ in "$key"');
    }
  });

  test('Hebrew plurals read naturally', () {
    final he = lookupAppL10n(const Locale('he'));
    expect(he.hoursAgo(1), 'לפני שעה');
    expect(he.hoursAgo(2), 'לפני שעתיים');
    expect(he.hoursAgo(5), 'לפני 5 שעות');
    expect(he.deletedDaysLeft(1, '3 בנוב׳'), 'נמחקה 3 בנוב׳ · נשאר יום אחד');
    expect(lookupAppL10n(const Locale('en')).deletedDaysLeft(4, 'Nov 3'), 'Deleted Nov 3 · 4 days left');
  });

  test('names without a BuildContext follow the app language', () {
    // English until the app loads another language.
    expect(RecurrenceFrequency.weekly.displayName, 'Weekly');
  });
}
