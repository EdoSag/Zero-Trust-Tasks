import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zero_trust_tasks/encryption_service.dart';
import 'package:zero_trust_tasks/models/task_template.dart';

/// Manages [TaskTemplate]s — encrypted, stored in SharedPreferences (item 32).
class TemplateProvider extends ChangeNotifier {
  TemplateProvider(this._prefs);

  factory TemplateProvider.of(BuildContext context, {bool listen = true}) {
    return Provider.of<TemplateProvider>(context, listen: listen);
  }

  static const _key = 'encrypted_templates_v1';

  final SharedPreferences _prefs;
  List<TaskTemplate> _templates = [];
  bool _isLoading = false;
  String? _error;

  List<TaskTemplate> get templates => List.unmodifiable(_templates);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadTemplates() async {
    if (!EncryptionService.isUnlocked) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final encrypted = _prefs.getString(_key);
      if (encrypted != null && encrypted.isNotEmpty) {
        final json = await EncryptionService.decryptData(encrypted);
        final list = jsonDecode(json) as List<dynamic>;
        _templates = list
            .map((e) => TaskTemplate.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      _error = 'Failed to load templates: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addTemplate(TaskTemplate template) async {
    _templates.add(template);
    notifyListeners();
    await _persist();
  }

  Future<void> removeTemplate(String id) async {
    _templates.removeWhere((t) => t.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    if (!EncryptionService.isUnlocked) return;
    final json = jsonEncode(_templates.map((t) => t.toJson()).toList());
    final encrypted = await EncryptionService.encryptData(json);
    await _prefs.setString(_key, encrypted);
  }
}
