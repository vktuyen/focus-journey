---
description: Audit the codebase to confirm the privacy promise — only aggregate idle time is read, never keystrokes/screen/clipboard/files — and that onboarding claims match the code. Produces a pass / violations-found verdict. Run during Phase 4 (Review) and before any internal release.
argument-hint: "[feature-slug | path]  (optional; defaults to all of src/)"
---

Run a privacy audit ($ARGUMENTS, or all of `src/` if empty).

Delegate to `privacy-guardian`. It performs a read-only audit:
- Native (`macos/`, `windows/`) use only idle/lock/power APIs — flag any input-event hooks (`CGEventTap`, `SetWindowsHookEx`, raw input), screen-capture, or clipboard APIs.
- `pubspec.yaml` deps that could read input contents / screen, or exfiltrate data.
- Onboarding/privacy copy matches the code (no unsupported claims).
- No analytics shipping activity detail off-device without consent.

Surface findings by severity (**Violation / Risk / Claim mismatch**) citing `path:line`; end with `pass` / `violations found`. Violations block release. Route fixes to `flutter-native-plugin-engineer` / `flutter-app-developer`. Read-only — applies no fixes.
