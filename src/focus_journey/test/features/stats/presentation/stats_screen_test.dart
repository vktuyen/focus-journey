// Screen-level widget tests for the daily/weekly stats screen.
//
// Scope: the RENDERED stats card driven by a real StatsCubit over the in-memory
// store fakes + a fixed clock — no real engine, no OS, no timers. The pure
// projection / weekly / best-focus MATH itself is covered by the parallel
// unit-test-writer's domain suite; here we assert the SCREEN surfaces the
// honesty layout and the four headline numbers the projection produced.
//
// Covers (widget leg):
//   TC-001  daily card shows the four headline numbers (active/journey time,
//           distance, idle time, best focus period) from a fixed engine snapshot
//   TC-002  raw focus time renders as its OWN labelled value, visually distinct
//           from journey time, and is never shown >= journey time (honesty)
//   TC-003  best focus period is rendered as its own labelled value
//
// Conventions mirror test/features/journey/presentation/journey_screen_test.dart
// and route/presentation/map_surface_test.dart (pumpWidget + BlocProvider.value,
// Key-based finders, FixedClock).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/journey_progress.dart';
import 'package:focus_journey/features/journey/domain/journey_state.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/stats/presentation/stats_cubit.dart';
import 'package:focus_journey/features/stats/presentation/stats_screen.dart';

import 'stats_test_fakes.dart';

/// A fixed local day used as "today" for every projection in this file.
final DateTime _today = DateTime(2026, 6, 24, 14); // a Wednesday afternoon

JourneyProgress _snapshot({
  required Duration active,
  required Duration raw,
  required Duration idle,
  required double distanceKm,
  JourneyState state = JourneyState.active,
}) => JourneyProgress(
  distanceKm: distanceKm,
  activeTimeToday: active,
  rawActiveTime: raw,
  idleTimeToday: idle,
  state: state,
  mode: TravelMode.motorbike,
  storedDate: _today,
);

/// Builds a loaded cubit at [_today], fed one [snapshot] tick, then pumps the
/// stats screen against it. Returns the cubit for follow-up assertions.
Future<StatsCubit> _pumpStats(
  WidgetTester tester,
  JourneyProgress snapshot,
) async {
  final cubit = StatsCubit(
    clock: MutableClock(_today),
    historyRepository: FakeHistoryRepository(),
    earnedBadgesRepository: FakeEarnedBadgesRepository(),
    notifier: FakeNotifier(),
  );
  addTearDown(cubit.close);
  // Seed the day at zero distance so today's delta == snapshot.distanceKm.
  await cubit.load(
    _snapshot(
      active: Duration.zero,
      raw: Duration.zero,
      idle: Duration.zero,
      distanceKm: 0,
    ),
  );
  await cubit.onTick(snapshot);

  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<StatsCubit>.value(
        value: cubit,
        child: const StatsScreen(),
      ),
    ),
  );
  await tester.pump();
  return cubit;
}

/// Reads the value Text inside a labelled stat row by its Key.
String _valueOf(WidgetTester tester, String key) {
  final rowFinder = find.byKey(Key(key));
  expect(rowFinder, findsOneWidget, reason: 'row "$key" must be present');
  // The row is a Row(label, value); the value is the bold Text (last Text).
  final texts = find
      .descendant(of: rowFinder, matching: find.byType(Text))
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .whereType<String>()
      .toList();
  return texts.last;
}

void main() {
  group('TC-001 daily card shows the four headline numbers', () {
    testWidgets('active/journey time, distance, idle, best focus all render', (
      tester,
    ) async {
      await _pumpStats(
        tester,
        _snapshot(
          active: const Duration(hours: 1, minutes: 30), // 90 min journey
          raw: const Duration(hours: 1, minutes: 10), // 70 min raw
          idle: const Duration(minutes: 20),
          distanceKm: 12.0,
        ),
      );

      // Each headline number renders against its own label (not a derived blob).
      expect(_valueOf(tester, 'stat-active-time'), '1h 30m');
      expect(_valueOf(tester, 'stat-raw-active-time'), '1h 10m');
      expect(_valueOf(tester, 'stat-distance'), '12.0 km');
      expect(_valueOf(tester, 'stat-idle-time'), '20m');
      // Best focus period has its own labelled value (TC-003).
      expect(find.byKey(const Key('stat-best-focus')), findsOneWidget);
    });
  });

  group(
    'TC-002 honesty: raw focus time is a distinct value, never >= journey',
    () {
      testWidgets('raw and journey are separate labelled rows, raw < journey', (
        tester,
      ) async {
        await _pumpStats(
          tester,
          _snapshot(
            active: const Duration(minutes: 90),
            raw: const Duration(minutes: 70),
            idle: const Duration(minutes: 10),
            distanceKm: 5,
          ),
        );

        // Two DISTINCT rows exist (the UI never conflates them into one number).
        expect(find.byKey(const Key('stat-active-time')), findsOneWidget);
        expect(find.byKey(const Key('stat-raw-active-time')), findsOneWidget);

        // The labels are visibly different — journey vs raw focus.
        expect(find.text('Active (journey) time'), findsWidgets);
        expect(find.text('Raw focus time'), findsWidgets);

        // Rendered raw (70m) is strictly less than journey (1h 30m): not shown
        // as >= journey time on the honest path.
        expect(_valueOf(tester, 'stat-active-time'), '1h 30m');
        expect(_valueOf(tester, 'stat-raw-active-time'), '1h 10m');
      });

      testWidgets('raw == journey (zero grace) renders as equal — allowed', (
        tester,
      ) async {
        await _pumpStats(
          tester,
          _snapshot(
            active: const Duration(minutes: 45),
            raw: const Duration(minutes: 45), // no grace consumed
            idle: Duration.zero,
            distanceKm: 3,
          ),
        );

        // Equal is allowed by AC-2; both rows still present + distinct labels.
        expect(_valueOf(tester, 'stat-active-time'), '45m');
        expect(_valueOf(tester, 'stat-raw-active-time'), '45m');
      });
    },
  );

  group('TC-003 best focus period rendered as its own labelled value', () {
    testWidgets('a non-zero best-focus run surfaces in its own row', (
      tester,
    ) async {
      // Two ascending raw-active ticks build a continuous run; the screen shows
      // the resulting best-focus value (the run math itself is unit-tested).
      final cubit = StatsCubit(
        clock: MutableClock(_today),
        historyRepository: FakeHistoryRepository(),
        earnedBadgesRepository: FakeEarnedBadgesRepository(),
        notifier: FakeNotifier(),
      );
      addTearDown(cubit.close);
      await cubit.load(
        _snapshot(
          active: Duration.zero,
          raw: Duration.zero,
          idle: Duration.zero,
          distanceKm: 0,
        ),
      );
      await cubit.onTick(
        _snapshot(
          active: const Duration(minutes: 10),
          raw: const Duration(minutes: 10),
          idle: Duration.zero,
          distanceKm: 1,
        ),
      );
      await cubit.onTick(
        _snapshot(
          active: const Duration(minutes: 25),
          raw: const Duration(minutes: 25),
          idle: Duration.zero,
          distanceKm: 3,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<StatsCubit>.value(
            value: cubit,
            child: const StatsScreen(),
          ),
        ),
      );
      await tester.pump();

      // The best-focus row exists and shows a non-zero run (25 min continuous).
      expect(find.byKey(const Key('stat-best-focus')), findsOneWidget);
      expect(cubit.state.daily.bestFocusPeriod, const Duration(minutes: 25));
      expect(_valueOf(tester, 'stat-best-focus'), '25m');
    });
  });

  group('TC-001/TC-026 the screen originates no engine/state write', () {
    testWidgets('rendering does not mutate the projected view state', (
      tester,
    ) async {
      final cubit = await _pumpStats(
        tester,
        _snapshot(
          active: const Duration(minutes: 30),
          raw: const Duration(minutes: 30),
          idle: Duration.zero,
          distanceKm: 2,
        ),
      );
      final before = cubit.state;
      // Pumping more frames (re-render) must not change the state — the screen
      // is a pure consumer (TC-026).
      await tester.pump();
      await tester.pump();
      expect(cubit.state, equals(before));
    });
  });
}
