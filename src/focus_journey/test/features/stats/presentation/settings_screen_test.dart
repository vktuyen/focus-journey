// Screen-level widget tests for the settings screen.
//
// Scope: the SettingsScreen wired to a real SettingsCubit over the in-memory
// settings fake + the injected fake StartupController — no real OS. Asserts the
// controls reflect injected state and dispatch the right Cubit writes.
//
// Covers (widget leg):
//   TC-008  idle-threshold selector (3 / 5 / 10 / custom) reflects the persisted
//           value and applies the new value to the engine seam on change
//   TC-010  launch-at-startup toggle reflects the injected OS state on open
//           (read) and writes the OS state on flip
//   TC-011  notifications master toggle gates the per-type toggles (per-type
//           switches are disabled while the master is off)
//   TC-012  the two per-type toggles (badge-earned + streak reminder) are present
//
// No real OS, no timers — FakeStartupController records reads/writes; the
// ApplyIdleThreshold seam is a recording closure (the engine is never touched).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/stats/domain/app_settings.dart';
import 'package:focus_journey/features/stats/presentation/settings_cubit.dart';
import 'package:focus_journey/features/stats/presentation/settings_screen.dart';

import 'stats_test_fakes.dart';

/// Builds the screen over a real SettingsCubit. Returns the parts under test.
Future<
  ({
    SettingsCubit cubit,
    FakeStartupController startup,
    List<Duration> appliedThresholds,
    FakeSettingsRepository repo,
  })
>
_pumpSettings(
  WidgetTester tester, {
  AppSettings? initial,
  bool osLaunchEnabled = false,
}) async {
  // Tall surface so the whole settings ListView (incl. the bottom privacy tile)
  // lays out in one frame.
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final repo = FakeSettingsRepository(initial);
  final startup = FakeStartupController(enabled: osLaunchEnabled);
  final applied = <Duration>[];
  final cubit = SettingsCubit(
    repository: repo,
    startupController: startup,
    applyIdleThreshold: applied.add,
    initialSettings: initial,
  );
  addTearDown(cubit.close);

  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<SettingsCubit>.value(
        value: cubit,
        child: const SettingsScreen(),
      ),
    ),
  );
  // initState() schedules syncLaunchAtStartupFromOs(); let it settle.
  await tester.pumpAndSettle();
  return (
    cubit: cubit,
    startup: startup,
    appliedThresholds: applied,
    repo: repo,
  );
}

void main() {
  group('TC-008 idle-threshold selector reflects + applies', () {
    testWidgets('dropdown shows the persisted threshold value', (tester) async {
      await _pumpSettings(
        tester,
        initial: const AppSettings(idleThreshold: Duration(minutes: 10)),
      );
      final dropdown = tester.widget<DropdownButton<int>>(
        find.byKey(const Key('idle-threshold-dropdown')),
      );
      expect(dropdown.value, 10);
      // The presets 3 / 5 / 10 are all offered.
      final values = dropdown.items!.map((i) => i.value).toSet();
      expect(values.containsAll(<int>{3, 5, 10}), isTrue);
    });

    testWidgets('a custom persisted value is added to the selector', (
      tester,
    ) async {
      await _pumpSettings(
        tester,
        initial: const AppSettings(idleThreshold: Duration(minutes: 7)),
      );
      final dropdown = tester.widget<DropdownButton<int>>(
        find.byKey(const Key('idle-threshold-dropdown')),
      );
      expect(dropdown.value, 7); // custom value surfaces
      expect(dropdown.items!.map((i) => i.value), contains(7));
    });

    testWidgets(
      'changing the threshold applies it to the engine seam + persists',
      (tester) async {
        final ctx = await _pumpSettings(
          tester,
          initial: const AppSettings(idleThreshold: Duration(minutes: 5)),
        );
        // The cubit applies the restored threshold once at construction.
        expect(ctx.appliedThresholds, contains(const Duration(minutes: 5)));

        await tester.tap(find.byKey(const Key('idle-threshold-dropdown')));
        await tester.pumpAndSettle();
        // Pick the 10-minute item from the opened menu (last match is the menu).
        await tester.tap(find.text('10 min').last);
        await tester.pumpAndSettle();

        // Applied to the engine seam AND persisted to settings.
        expect(ctx.appliedThresholds.last, const Duration(minutes: 10));
        expect(ctx.cubit.state.idleThreshold, const Duration(minutes: 10));
        expect(ctx.repo.saveCount, greaterThan(0));
      },
    );
  });

  group('TC-010 launch-at-startup reflects OS state then writes it', () {
    testWidgets('reads the injected OS state on open', (tester) async {
      final ctx = await _pumpSettings(tester, osLaunchEnabled: true);
      // syncLaunchAtStartupFromOs() read the OS once and reconciled the toggle.
      expect(ctx.startup.readCount, greaterThanOrEqualTo(1));
      final sw = tester.widget<SwitchListTile>(
        find.byKey(const Key('launch-at-startup-switch')),
      );
      expect(sw.value, isTrue, reason: 'toggle reflects real OS open-at-login');
    });

    testWidgets('flipping the toggle writes the OS state', (tester) async {
      final ctx = await _pumpSettings(tester, osLaunchEnabled: false);
      expect(ctx.startup.osState, isFalse);

      await tester.tap(find.byKey(const Key('launch-at-startup-switch')));
      await tester.pumpAndSettle();

      // The real OS state was written via the controller and stays consistent.
      expect(ctx.startup.writes.last, isTrue);
      expect(ctx.startup.osState, isTrue);
      expect(ctx.cubit.state.launchAtStartup, isTrue);
    });
  });

  group('TC-011/TC-012 notifications master gates per-type toggles', () {
    testWidgets('per-type switches are enabled when master is on', (
      tester,
    ) async {
      await _pumpSettings(
        tester,
        initial: const AppSettings(notificationsEnabled: true),
      );
      final badge = tester.widget<SwitchListTile>(
        find.byKey(const Key('notifications-badge-switch')),
      );
      final streak = tester.widget<SwitchListTile>(
        find.byKey(const Key('notifications-streak-switch')),
      );
      // onChanged != null => interactive (not gated off).
      expect(badge.onChanged, isNotNull);
      expect(streak.onChanged, isNotNull);
    });

    testWidgets('per-type switches are disabled when master is off', (
      tester,
    ) async {
      await _pumpSettings(
        tester,
        initial: const AppSettings(notificationsEnabled: false),
      );
      final badge = tester.widget<SwitchListTile>(
        find.byKey(const Key('notifications-badge-switch')),
      );
      final streak = tester.widget<SwitchListTile>(
        find.byKey(const Key('notifications-streak-switch')),
      );
      // Master off => per-type toggles are gated (onChanged == null).
      expect(badge.onChanged, isNull);
      expect(streak.onChanged, isNull);
    });

    testWidgets('toggling the master switch persists the new value', (
      tester,
    ) async {
      final ctx = await _pumpSettings(
        tester,
        initial: const AppSettings(notificationsEnabled: true),
      );
      await tester.tap(find.byKey(const Key('notifications-master-switch')));
      await tester.pumpAndSettle();
      expect(ctx.cubit.state.notificationsEnabled, isFalse);
      expect(ctx.repo.saveCount, greaterThan(0));
    });
  });

  group('TC-021 settings re-opens the privacy promise', () {
    testWidgets('the view-privacy tile pushes the privacy content', (
      tester,
    ) async {
      await _pumpSettings(tester);
      expect(find.byKey(const Key('view-privacy-tile')), findsOneWidget);
      await tester.tap(find.byKey(const Key('view-privacy-tile')));
      await tester.pumpAndSettle();
      // The re-openable privacy screen renders its claim sections.
      expect(find.byKey(const Key('privacy-reads')), findsOneWidget);
      expect(find.byKey(const Key('privacy-never-reads')), findsOneWidget);
    });
  });
}
