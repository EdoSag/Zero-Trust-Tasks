import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zero_trust_tasks/models/smart_filter.dart';

/// Persists named [SmartFilter] presets in SharedPreferences (item 28).
class SmartFilterProvider extends ChangeNotifier {
  SmartFilterProvider(this._prefs) {
    _load();
  }

  factory SmartFilterProvider.of(BuildContext context, {bool listen = true}) {
    return Provider.of<SmartFilterProvider>(context, listen: listen);
  }

  static const _key = 'smart_filters_v1';

  final SharedPreferences _prefs;
  List<SmartFilter> _filters = [];

  List<SmartFilter> get filters => List.unmodifiable(_filters);

  void _load() {
    final stored = _prefs.getString(_key);
    if (stored == null) return;
    try {
      final list = jsonDecode(stored) as List<dynamic>;
      _filters = list
          .map((e) => SmartFilter.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _filters = [];
    }
  }

  Future<void> addFilter(SmartFilter filter) async {
    _filters.add(filter);
    notifyListeners();
    await _persist();
  }

  Future<void> removeFilter(String id) async {
    _filters.removeWhere((f) => f.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    await _prefs.setString(
      _key,
      jsonEncode(_filters.map((f) => f.toJson()).toList()),
    );
  }
}
