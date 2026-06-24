// Screen-level widget tests for the badges / achievements screen.
//
// Scope: the RENDERED earned-vs-locked list across the four families, driven by
// a StatsViewState pushed into a scriptable cubit — no real engine, no OS. The
// badge EVALUATION math (threshold crossing, windowed-vs-permanent reset) is
// covered by the parallel unit-test-writer's evaluator suite + the integration
// tests; here we assert the SCREEN presents earned vs locked correctly and the
// four families are all representable.
//
// Covers (widget leg):
//   TC-013  data-driven catalogue spanning all four families renders earned vs
//           locked; an earned badge appears under "Earned", a locked one under
//           "Locked"
//   TC-014/TC-015/TC-017  the distance / journey-progress / focus-time families
//           each render a tile (family label visible)
//   TC-016  a streak-family badge renders
//   TC-018  windowed and permanent badges are both renderable; a windowed badge
//           that is currently locked appears under "Locked" (re-earnable view)
//
// Keys off catalogue STRUCTURE + the earned set, not literal thresholds — the
// pending-OQ discipline. Uses a small fixed test catalogue so the assertions
// survive catalogue re-tuning.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/clock.dart';
import 'package:focus_journey/features/stats/domain/badge.dart';
import 'package:focus_journey/features/stats/domain/badge_catalogue.dart';
import 'package:focus_journey/features/stats/presentation/badges_screen.dart';
import 'package:focus_journey/features/stats/presentation/stats_cubit.dart';
import 'package:focus_journey/features/stats/presentation/stats_view_state.dart';

import 'stats_test_fakes.dart';

/// A StatsCubit whose emitted StatsViewState we drive directly (scriptable —
/// no engine/OS). Subclasses StatsCubit so `BlocProvider<StatsCubit>` accepts
/// it, mirroring `ScriptableJourneyCubit` in the journey widget tests.
class _ScriptableStatsCubit extends StatsCubit {
  _ScriptableStatsCubit(Clock clock)
    : super(
        clock: clock,
        historyRepository: FakeHistoryRepository(),
        earnedBadgesRepository: FakeEarnedBadgesRepository(),
        notifier: FakeNotifier(),
      );
  void push(StatsViewState state) => emit(state);
}

/// A minimal test catalogue with exactly one badge per family + one windowed +
/// one permanent so structure assertions don't depend on the v1 literals.
final List<BadgeDefinition> _testCatalogue = <BadgeDefinition>[
  BadgeDefinition(
    id: 'd1',
    title: 'Test Distance',
    description: 'distance badge',
    family: BadgeFamily.distance,
    scope: BadgeScope.permanent,
    isEarned: (c) => c.cumulativeDistanceKm >= 10,
  ),
  BadgeDefinition(
    id: 'w1',
    title: 'Test Week Distance',
    description: 'windowed distance badge',
    family: BadgeFamily.distance,
    scope: BadgeScope.weekly,
    isEarned: (c) => c.weekDistanceKm >= 10,
  ),
  BadgeDefinition(
    id: 'j1',
    title: 'Test Journey',
    description: 'journey-progress badge',
    family: BadgeFamily.journeyProgress,
    scope: BadgeScope.permanent,
    isEarned: (c) => c.percentOfCountry >= 50,
  ),
  BadgeDefinition(
    id: 's1',
    title: 'Test Streak',
    description: 'streak badge',
    family: BadgeFamily.focusStreak,
    scope: BadgeScope.permanent,
    isEarned: (c) => c.currentStreakDays >= 3,
  ),
  BadgeDefinition(
    id: 'f1',
    title: 'Test Focus',
    description: 'focus-time badge',
    family: BadgeFamily.focusTime,
    scope: BadgeScope.permanent,
    isEarned: (c) => c.todayRawActive >= const Duration(hours: 1),
  ),
];

StatsViewState _state(Set<String> earned, {List<BadgeDefinition>? catalogue}) =>
    StatsViewState.initial().copyWith(
      earnedBadgeIds: earned,
      catalogue: catalogue ?? _testCatalogue,
    );

Future<_ScriptableStatsCubit> _pumpBadges(
  WidgetTester tester,
  StatsViewState state,
) async {
  // Tall surface so the lazy ListView lays out every badge tile in one frame
  // (a short default viewport would leave below-the-fold tiles un-built).
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final cubit = _ScriptableStatsCubit(MutableClock(DateTime(2026, 6, 24)));
  addTearDown(cubit.close);
  cubit.push(state);
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<StatsCubit>.value(
        value: cubit,
        child: const BadgesScreen(),
      ),
    ),
  );
  await tester.pump();
  return cubit;
}

void main() {
  group('TC-013 earned vs locked rendering across four families', () {
    testWidgets('an earned badge shows under Earned, others under Locked', (
      tester,
    ) async {
      await _pumpBadges(tester, _state(<String>{'d1'}));

      // The "Earned" and "Locked" section headers both render.
      expect(find.text('Earned'), findsOneWidget);
      expect(find.text('Locked'), findsOneWidget);

      // Every catalogue badge has a tile (data-driven render).
      for (final b in _testCatalogue) {
        expect(
          find.byKey(Key('badge-${b.id}')),
          findsOneWidget,
          reason: 'badge ${b.id} must render a tile',
        );
      }

      // The earned tile shows the trophy icon; a locked tile shows the lock.
      final earnedTile = tester.widget<Card>(find.byKey(const Key('badge-d1')));
      expect(earnedTile, isNotNull);
      expect(
        find.descendant(
          of: find.byKey(const Key('badge-d1')),
          matching: find.byIcon(Icons.emoji_events),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('badge-j1')),
          matching: find.byIcon(Icons.lock_outline),
        ),
        findsOneWidget,
      );
    });

    testWidgets('all four family labels are representable in the view', (
      tester,
    ) async {
      await _pumpBadges(tester, _state(const <String>{}));
      // The badges screen labels every family (Distance / Journey / Streak /
      // Focus) — proves the four-family catalogue surface (AC-13).
      expect(find.text('Distance'), findsWidgets);
      expect(find.text('Journey'), findsOneWidget);
      expect(find.text('Streak'), findsOneWidget);
      expect(find.text('Focus'), findsOneWidget);
    });

    testWidgets('no Earned header when nothing is earned', (tester) async {
      await _pumpBadges(tester, _state(const <String>{}));
      expect(find.text('Earned'), findsNothing);
      expect(find.text('Locked'), findsOneWidget);
    });
  });

  group('TC-018 windowed vs permanent presentation', () {
    testWidgets('an earned windowed badge appears under Earned', (
      tester,
    ) async {
      await _pumpBadges(tester, _state(<String>{'w1'}));
      // The windowed badge w1 is currently earned -> trophy.
      expect(
        find.descendant(
          of: find.byKey(const Key('badge-w1')),
          matching: find.byIcon(Icons.emoji_events),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a windowed badge reset to locked shows under Locked', (
      tester,
    ) async {
      // After a week rollover the evaluator drops the windowed id; the view
      // then renders it as locked (re-earnable that window) while a permanent
      // earned badge stays under Earned.
      await _pumpBadges(tester, _state(<String>{'d1'})); // d1 permanent earned
      expect(
        find.descendant(
          of: find.byKey(const Key('badge-w1')),
          matching: find.byIcon(Icons.lock_outline),
        ),
        findsOneWidget,
        reason: 'reset windowed badge renders as locked / re-earnable',
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('badge-d1')),
          matching: find.byIcon(Icons.emoji_events),
        ),
        findsOneWidget,
        reason: 'permanent badge stays earned across the rollover',
      );
    });
  });

  group('TC-013 production catalogue renders end-to-end', () {
    testWidgets('every v1 catalogue badge has a tile', (tester) async {
      await _pumpBadges(
        tester,
        _state(const <String>{}, catalogue: BadgeCatalogue.badges),
      );
      for (final b in BadgeCatalogue.badges) {
        expect(
          find.byKey(Key('badge-${b.id}')),
          findsOneWidget,
          reason: 'production badge ${b.id} must render',
        );
      }
      // All four families present in the production catalogue.
      final families = BadgeCatalogue.badges.map((b) => b.family).toSet();
      expect(families, BadgeFamily.values.toSet());
    });
  });
}
