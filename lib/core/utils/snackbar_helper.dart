import 'package:flutter/material.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';

/// Shared helpers for showing consistent success/error feedback.
class SnackbarHelper {
  SnackbarHelper._();

  static void showError(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        // Flutter keeps a snackbar with a button until dismissed unless told
        // otherwise.
        persist: false,
        action: onRetry == null
            ? null
            : SnackBarAction(
                label: currentL10n.retry,
                onPressed: onRetry,
              ),
      ),
    );
  }

  static void showInfo(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        // Flutter keeps a snackbar with a button until dismissed unless told
        // otherwise.
        persist: false,
        action: actionLabel == null || onAction == null
            ? null
            : SnackBarAction(label: actionLabel, onPressed: onAction),
      ),
    );
  }
}
