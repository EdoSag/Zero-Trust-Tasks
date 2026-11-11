import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zero_trust_tasks/app/auth_providers.dart';
import 'package:zero_trust_tasks/app/tasks_hooks.dart';
import 'package:zero_trust_tasks/app/share_intake.dart';
import 'package:zero_trust_tasks/app/widget_launch.dart';
import 'package:zero_trust_tasks/core/services/home_widget_service.dart';
import 'package:zero_trust_tasks/pages/main_screen.dart';
import 'package:zero_trust_tasks/suite/linked_apps.dart';
import 'package:zero_trust_tasks/l10n/l10n.dart';

/// Routes between the shared account screens and the app.
///
/// Signed out: sign in or create an account (accounts from the earlier
/// Tasks app sign in with the same email and password and are upgraded on
/// the way). Signed in but locked: unlock with the password or biometrics.
/// A new recovery key is always shown, and confirmed, before the vault opens.
class AppGate extends ConsumerStatefulWidget {
  const AppGate({super.key});

  @override
  ConsumerState<AppGate> createState() => _AppGateState();
}

class _AppGateState extends ConsumerState<AppGate> with WidgetsBindingObserver {
  /// Stays on the sign-in screen until it hands back a result, even though
  /// Supabase reports the session a moment earlier.
  late bool _signingIn = ref.read(currentUserProvider) == null;
  UnlockResult? _awaitingRecoveryKey;
  late final WidgetLaunchListener _widgetLaunches = WidgetLaunchListener(ref);
  late final ShareIntake _shares = ShareIntake(ref);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (ref.read(platformHooksEnabledProvider)) {
      unawaited(_widgetLaunches.start());
      unawaited(_shares.start());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _widgetLaunches.dispose();
    _shares.dispose();
    super.dispose();
  }

  /// A key still waiting behind the recovery-key screen is zeroed when the
  /// app leaves the foreground, so coming back asks for the password. The
  /// open vault itself is locked by the core's auto-lock.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      final pending = _awaitingRecoveryKey;
      if (pending != null) {
        pending.dek.fillRange(0, pending.dek.length, 0);
        setState(() => _awaitingRecoveryKey = null);
      }
    }
  }

  Future<void> _onUnlocked(UnlockResult result) async {
    // Tasks can link to notes and contacts from the same account, so it
    // also derives those apps' keys while it holds the account key.
    await ref.read(linkedKeysProvider.notifier).deriveFrom(result.dek);
    if (!mounted) return;
    if (result.newRecoveryKey != null) {
      setState(() {
        _signingIn = false;
        _awaitingRecoveryKey = result;
      });
      return;
    }
    setState(() => _signingIn = false);
    ref.read(vaultControllerProvider.notifier).unlock(result.dek, legacyDek: result.legacyDek);
  }

  void _forgotPassword() => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const ZtForgotPasswordScreen()));

  @override
  Widget build(BuildContext context) {
    ref.listen(vaultControllerProvider, (_, next) {
      // Don't leave a task or settings page open over a locked vault.
      if (next is VaultLocked) Navigator.of(context).popUntil((route) => route.isFirst);
    });
    ref.listen(currentUserProvider, (_, user) {
      if (user == null) {
        ref.read(vaultControllerProvider.notifier).lock();
        if (ref.read(platformHooksEnabledProvider)) unawaited(const HomeWidgetService().clear());
        setState(() => _signingIn = true);
      }
    });

    final pending = _awaitingRecoveryKey;
    if (pending != null) {
      return ZtRecoveryKeyScreen(
        recoveryKey: pending.newRecoveryKey!,
        onDone: () {
          setState(() => _awaitingRecoveryKey = null);
          ref.read(vaultControllerProvider.notifier).unlock(pending.dek, legacyDek: pending.legacyDek);
        },
      );
    }

    if (ref.watch(passwordRecoveryProvider)) {
      return ZtResetPasswordScreen(
        onUnlocked: (result) {
          ref.read(passwordRecoveryProvider.notifier).done();
          _onUnlocked(result);
        },
      );
    }

    final user = ref.watch(currentUserProvider);
    if (user == null || _signingIn) {
      // First launch: the three shared intro pages, once per install.
      final seen = ref.watch(ztOnboardingSeenProvider);
      if (user == null && seen == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (user == null && seen == false) {
        return ZtOnboardingScreen(onDone: () {});
      }
      return ZtSignInScreen(
        onUnlocked: _onUnlocked,
        onForgotPassword: _forgotPassword,
        offerBiometrics: true,
      );
    }

    if (ref.watch(vaultControllerProvider) is VaultLocked) {
      return ZtUnlockScreen(
        email: user.email,
        onUnlocked: _onUnlocked,
        onSignOut: () => ref.read(accountServiceProvider).signOut(),
        onForgotPassword: _forgotPassword,
      );
    }

    return const TasksHome();
  }
}

/// The app once the local store is open, which is also when sync starts.
class TasksHome extends ConsumerWidget {
  const TasksHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps sync running while the vault is open.
    ref.watch(ztSyncControllerProvider);
    return switch (ref.watch(ztLocalStoreProvider)) {
      AsyncData() => const MainScreen(),
      AsyncError(:final error) when error is! VaultIsLocked => Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.l10n.cantOpenTasks(ztErrorMessage(error)),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => ref.invalidate(ztLocalStoreProvider),
                    child: Text(context.l10n.tryAgain),
                  ),
                ],
              ),
            ),
          ),
        ),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

