/// Central registry of SharedPreferences keys used across the app.
class PreferenceKeys {
  PreferenceKeys._();

  static const String themeMode = 'settings_theme_mode';
  static const String lastSelectedTab = 'settings_last_selected_tab';
  static const String taskFilterState = 'settings_task_filter_state';
  static const String taskSectionsCollapsed = 'settings_task_sections_collapsed';
  static const String lastSyncedAt = 'sync_last_synced_at';
  static const String autoBackupFrequency = 'sync_auto_backup_frequency';
  static const String autoLockDuration = 'security_auto_lock_duration';
  static const String showTaskDetailsInNotifications =
      'security_show_task_details_in_notifications';
}
