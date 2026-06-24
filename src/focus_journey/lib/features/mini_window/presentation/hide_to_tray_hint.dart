/// Presentation layer. The one-time, in-app hide-to-tray discoverability hint
/// (AC-17): after the user closes the main window for the FIRST time and it
/// hides to the tray (keeping tracking), this hint explains the app is still
/// running. It is a plain in-app banner — NOT an OS notification (per the
/// slice's out-of-scope note) — and is shown once, then never again.
library;

import 'package:flutter/material.dart';

/// The copy shown on the first close-to-tray (AC-17).
const String kHideToTrayHintText =
    'Vietnam Focus Journey is still running in the menu bar / system tray. '
    'Your journey keeps tracking. Use the tray icon to reopen or quit.';

/// A dismissible banner shown once on the first hide-to-tray (AC-17). Real text
/// in the semantics tree so it is screen-reader discoverable (NFR-6).
class HideToTrayHint extends StatelessWidget {
  /// Creates the hint. [onDismiss] is invoked when the user dismisses it.
  const HideToTrayHint({required this.onDismiss, super.key});

  /// Called when the user taps "Got it" to dismiss the one-time hint.
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Material(
            color: Colors.black.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.info_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Semantics(
                      liveRegion: true,
                      child: const Text(
                        kHideToTrayHintText,
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(onPressed: onDismiss, child: const Text('Got it')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
