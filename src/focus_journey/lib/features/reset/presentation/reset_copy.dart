/// Presentation layer — the SINGLE place all journey-reset user-facing copy
/// lives, so the two OPEN product-copy questions (exact Factory-reset wording +
/// whether Start over gets its own lighter confirm) can be re-pinned in one edit
/// without hunting scattered strings.
///
// TODO(copy): re-pin once product finalises wording (spec "Open questions":
// Factory-reset confirmation wording; does Start over get a lighter confirm than
// the destructive full wipe?). These are sensible clear defaults — the
// asymmetry (AC-12 / BR-8 carve-out) is surfaced explicitly below.
library;

/// Copy for the destructive Factory-reset confirmation dialog (AC-1/AC-3/AC-12).
abstract final class FactoryResetCopy {
  /// The Settings action label that opens the confirmation.
  static const String actionTitle = 'Factory reset';

  /// The Settings action subtitle (what it does, in one line).
  static const String actionSubtitle =
      'Erase all local data and return to a fresh first-run state.';

  /// Dialog title — states the irreversible outcome plainly.
  static const String dialogTitle = 'Factory reset this app?';

  /// Dialog body — names the data loss (the BR-8 carve-out / AC-12 asymmetry):
  /// lifetime distance, streaks, and badges ARE cleared here, unlike Start over.
  static const String dialogBody =
      'This permanently erases everything stored on this device — your route, '
      'settings, and your lifetime distance, streaks, and badges. It cannot be '
      'undone, and the app returns to its first-run state.\n\n'
      'This is different from Start over, which keeps your lifetime distance, '
      'streaks, and badges.';

  /// Non-destructive dismissal (leaves all data intact — AC-2).
  static const String cancelLabel = 'Cancel';

  /// The destructive affirmative action (styled destructively — NFR-3/AC-1).
  static const String confirmLabel = 'Erase everything';

  /// Screen-reader label distinguishing this destructive action (NFR-3).
  static const String confirmSemanticLabel =
      'Erase everything. Destructive and irreversible.';

  /// Shown when the wipe did not fully succeed (one or more stores failed to
  /// clear). The app has already rebuilt to a fresh state, so this warns the
  /// user that some local data may remain rather than leaving it silent.
  static const String errorMessage =
      'Some data could not be erased. The app has restarted; please try Factory '
      'reset again.';
}

/// Copy for the launch Resume vs Start over prompt (AC-6/AC-9/AC-12).
abstract final class LaunchPromptCopy {
  /// Prompt title.
  static const String title = 'Welcome back';

  /// Prompt body — frames the choice and surfaces the asymmetry (AC-12): Start
  /// over keeps lifetime progress; only the route is replaced.
  static const String body =
      'You have a journey in progress. Resume where you left off, or start over '
      'with a new route. Start over keeps your lifetime distance, streaks, and '
      'badges — it only replaces your current route.';

  /// Continue the in-progress journey from the exact prior position (AC-8).
  static const String resumeLabel = 'Resume journey';

  /// Retire the current route and author a new one (AC-9), keeping lifetime data.
  static const String startOverLabel = 'Start over';

  /// Screen-reader label for Start over that names the retention (AC-12/NFR-3).
  static const String startOverSemanticLabel =
      'Start over. Keeps your lifetime distance, streaks, and badges; replaces '
      'only your route.';
}
