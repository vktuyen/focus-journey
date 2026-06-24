/// Presentation layer. The daily + weekly stats screen.
///
/// SEPARATION INVARIANT (TC-026): reads ONLY the [StatsCubit]'s view state.
/// Imports NO `ActivityPlugin`, NO `MethodChannel`, NO OS/idle/lock API, and
/// performs NO stat math (all in pure `domain/` functions). It only formats and
/// renders.
///
/// HONESTY RULE (AC-2 / TC-002): **raw active time** is rendered as its **own
/// labelled value, visually distinct** from "active (journey) time" — never
/// conflated into one number, never shown greater (the projection enforces
/// `raw <= journey`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/daily_stats.dart';
import '../domain/weekly_stats.dart';
import 'stats_cubit.dart';
import 'stats_view_state.dart';

/// The daily + weekly stats screen.
class StatsScreen extends StatelessWidget {
  /// Creates the stats screen.
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your focus stats')),
      body: BlocBuilder<StatsCubit, StatsViewState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _DailyCard(daily: state.daily),
              const SizedBox(height: 16),
              _WeeklyCard(
                weekly: state.weekly,
                streakDays: state.currentStreakDays,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({required this.daily});

  final DailyStats daily;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Today', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            // Two DISTINCT labelled values — journey time and raw focus time
            // are never merged into one number (AC-2 / TC-002).
            _StatRow(
              key: const Key('stat-active-time'),
              label: 'Active (journey) time',
              value: _fmtDuration(daily.activeTime),
            ),
            _StatRow(
              key: const Key('stat-raw-active-time'),
              label: 'Raw focus time',
              value: _fmtDuration(daily.rawActiveTime),
            ),
            _StatRow(
              key: const Key('stat-distance'),
              label: 'Distance today',
              value: '${daily.distanceKm.toStringAsFixed(1)} km',
            ),
            _StatRow(
              key: const Key('stat-idle-time'),
              label: 'Idle time',
              value: _fmtDuration(daily.idleTime),
            ),
            _StatRow(
              key: const Key('stat-best-focus'),
              label: 'Best focus period',
              value: _fmtDuration(daily.bestFocusPeriod),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyCard extends StatelessWidget {
  const _WeeklyCard({required this.weekly, required this.streakDays});

  final WeeklyStats weekly;
  final int streakDays;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('This week', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _StatRow(
              label: 'Active (journey) time',
              value: _fmtDuration(weekly.activeTime),
            ),
            _StatRow(
              label: 'Raw focus time',
              value: _fmtDuration(weekly.rawActiveTime),
            ),
            _StatRow(
              label: 'Distance',
              value: '${weekly.distanceKm.toStringAsFixed(1)} km',
            ),
            _StatRow(label: 'Idle time', value: _fmtDuration(weekly.idleTime)),
            _StatRow(label: 'Days active', value: '${weekly.daysActive}'),
            _StatRow(
              label: 'Best focus period',
              value: _fmtDuration(weekly.bestFocusPeriod),
            ),
            _StatRow(
              key: const Key('stat-streak'),
              label: 'Current streak',
              value: '$streakDays ${streakDays == 1 ? 'day' : 'days'}',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

String _fmtDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  return '${minutes}m';
}
