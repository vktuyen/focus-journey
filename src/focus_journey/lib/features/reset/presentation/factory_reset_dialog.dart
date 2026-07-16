/// Presentation layer. The Settings "Factory reset" action + its explicit
/// destructive confirmation dialog (AC-1/AC-2/AC-3/AC-12/NFR-3).
///
/// The wipe is gated STRICTLY behind the affirmative confirm: opening the dialog
/// touches no data (TC-701); Cancel, Esc, and scrim-tap all resolve to "not
/// confirmed" and touch nothing (TC-702/TC-702b). Only an affirmative confirm
/// calls [FactoryResetCubit.confirmReset]. The confirm action is styled + labelled
/// destructively and is textually distinct from the non-destructive Start over
/// (TC-703/TC-722).
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'factory_reset_cubit.dart';
import 'reset_copy.dart';

/// A Settings tile that opens the destructive Factory-reset confirmation and,
/// only on an affirmative confirm, runs the wipe + re-init via the injected
/// [FactoryResetCubit] (read from an ancestor provider).
class FactoryResetTile extends StatelessWidget {
  /// Creates the tile.
  const FactoryResetTile({super.key});

  @override
  Widget build(BuildContext context) {
    final Color destructive = Theme.of(context).colorScheme.error;
    return ListTile(
      key: const Key('factory-reset-tile'),
      leading: Icon(Icons.delete_forever, color: destructive),
      title: Text(
        FactoryResetCopy.actionTitle,
        style: TextStyle(color: destructive),
      ),
      subtitle: const Text(FactoryResetCopy.actionSubtitle),
      onTap: () async {
        // Read the cubit + messenger BEFORE awaiting: the re-init tears down this
        // subtree, so we must not touch `context` afterward. The messenger lives
        // at the app root and survives the reset rebuild, so it is safe to use.
        final FactoryResetCubit resetCubit = context.read<FactoryResetCubit>();
        final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
        final bool? confirmed = await showFactoryResetDialog(context);
        // Anything other than an explicit affirmative confirm is inert (AC-2).
        if (confirmed != true) {
          return;
        }
        try {
          await resetCubit.confirmReset();
        } catch (_) {
          // confirmReset already isolates the wipe and always re-inits, so a
          // throw here is only a re-init failure; the failure is surfaced below.
        }
        // Surface a partial/failed wipe so it is never silent. The re-init has
        // already run, so the app is on a rebuilt graph (never wedged).
        if (resetCubit.state == FactoryResetStatus.failed) {
          messenger.showSnackBar(
            const SnackBar(content: Text(FactoryResetCopy.errorMessage)),
          );
        }
      },
    );
  }
}

/// Shows the destructive Factory-reset confirmation. Resolves to `true` only on
/// an affirmative confirm; `false` on Cancel; `null` on Esc/scrim dismiss — the
/// caller treats every non-`true` result as "do nothing" (AC-2 / TC-702/702b).
Future<bool?> showFactoryResetDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    // Esc / tap-outside is allowed but resolves to `null` (inert), never confirm.
    barrierDismissible: true,
    builder: (BuildContext dialogContext) => const FactoryResetDialog(),
  );
}

/// The explicit destructive confirmation dialog. Keyboard-navigable +
/// screen-reader reachable (NFR-3); the confirm action is destructively styled +
/// labelled and distinct from Start over (AC-1/TC-703/TC-722).
class FactoryResetDialog extends StatelessWidget {
  /// Creates the dialog.
  const FactoryResetDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return AlertDialog(
      key: const Key('factory-reset-dialog'),
      icon: Icon(Icons.warning_amber_rounded, color: colors.error),
      title: const Text(FactoryResetCopy.dialogTitle),
      content: const SingleChildScrollView(
        child: Text(FactoryResetCopy.dialogBody),
      ),
      actions: <Widget>[
        // The destructive affirmative action is DELIBERATELY the LOWER-emphasis
        // affordance on a destructive dialog: an error-coloured outlined button
        // (not the filled primary), placed away from the primary position, so
        // "erase" is never the easy default. Still explicitly labelled for
        // screen readers and unmistakably distinct from Start over (TC-703).
        Semantics(
          button: true,
          label: FactoryResetCopy.confirmSemanticLabel,
          child: OutlinedButton(
            key: const Key('factory-reset-confirm'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.error,
              side: BorderSide(color: colors.error),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(FactoryResetCopy.confirmLabel),
          ),
        ),
        // The safe, non-destructive action is the PROMINENT, autofocused default
        // (the filled primary in the trailing position), so the keyboard /
        // primary affordance on a destructive dialog is always "keep my data"
        // (NFR-3 / TC-703).
        FilledButton(
          key: const Key('factory-reset-cancel'),
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(FactoryResetCopy.cancelLabel),
        ),
      ],
    );
  }
}
