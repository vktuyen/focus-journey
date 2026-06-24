/// Presentation layer. The first-run onboarding / privacy screen (AC-20/AC-21).
///
/// THE COPY IS THE CONTRACT: every claim below must match what the code actually
/// does — `privacy-guardian` (`/privacy-audit`) audits this copy against the
/// slice's API + dependency usage (AC-21, a release gate). Keep these claims
/// truthful: the app reads ONLY aggregate system idle time + lock/sleep state
/// (via the already-audited `ActivityPlugin`, never called from this slice); it
/// reads NONE of keystrokes/content, screen, clipboard, files, browser,
/// mouse-position history, or window titles; it is fully local/offline with no
/// account; notifications (`local_notifier`) and launch-at-startup
/// (`launch_at_startup`) are local OS capabilities that add no such surface.
library;

import 'package:flutter/material.dart';

/// What the app reads — keep in sync with the actual `ActivityPlugin` surface.
const List<String> kPrivacyReads = <String>[
  'Aggregate system idle time (how long since your last input — a single number)',
  'Screen lock / sleep state (so a locked or sleeping machine counts as idle)',
];

/// What the app never reads — the explicit non-surface the audit verifies.
const List<String> kPrivacyNeverReads = <String>[
  'Keystrokes or anything you type',
  'Your screen contents or screenshots',
  'Your clipboard',
  'Your files',
  'Your browser activity or history',
  'Mouse-position history',
  'Window titles or which apps you use',
];

/// The first-run onboarding / privacy screen. Shows the trust promise and, on
/// completion, invokes [onComplete] (the caller persists the seen-flag, AC-20).
class OnboardingScreen extends StatelessWidget {
  /// Creates the onboarding screen.
  const OnboardingScreen({required this.onComplete, super.key});

  /// Called when the user finishes onboarding (caller persists the flag).
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome to Vietnam Focus Journey')),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const Expanded(child: PrivacyContent()),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('onboarding-continue'),
                  onPressed: onComplete,
                  child: const Text('Get started'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The privacy-promise copy, reused by [OnboardingScreen] (first run) and the
/// settings "view privacy" entry (re-openable; AC-20). Stateless and pure copy.
class PrivacyContent extends StatelessWidget {
  /// Creates the privacy content block.
  const PrivacyContent({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text('Your privacy, by design', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'This app turns real focus time into a journey across Vietnam. It is '
          'built to be honest about what it can and cannot see.',
        ),
        const SizedBox(height: 24),

        _Section(
          key: const Key('privacy-reads'),
          icon: Icons.visibility,
          iconColor: Colors.teal,
          title: 'What this app reads',
          items: kPrivacyReads,
        ),
        const SizedBox(height: 16),

        _Section(
          key: const Key('privacy-never-reads'),
          icon: Icons.block,
          iconColor: Colors.red,
          title: 'What this app never reads',
          items: kPrivacyNeverReads,
        ),
        const SizedBox(height: 16),

        Card(
          key: const Key('privacy-offline'),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Fully local. Fully offline.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'There is no account and no network. Nothing you do leaves '
                  'your machine — no cloud sync, no servers, no tracking. '
                  'Notifications are local desktop toasts only.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Card(
          key: const Key('privacy-active-vs-journey'),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Active time vs journey time',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Journey time keeps your vehicle moving through a short grace '
                  'period after you stop typing, so brief pauses do not stall '
                  'the trip. Raw focus time counts only genuine input and is '
                  'always shown separately — it is never larger than journey '
                  'time, so the app can never overstate how much you focused.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.items,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('•  '),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
