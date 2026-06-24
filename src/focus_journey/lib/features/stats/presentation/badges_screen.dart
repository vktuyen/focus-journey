/// Presentation layer. The badges / achievements screen — lists earned + locked
/// badges from the data-driven catalogue (AC-13).
///
/// SEPARATION INVARIANT (TC-026): reads ONLY the [StatsCubit]'s view state. No
/// OS read, no badge math (the evaluator is pure `domain/`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/badge.dart';
import 'stats_cubit.dart';
import 'stats_view_state.dart';

/// The achievements screen.
class BadgesScreen extends StatelessWidget {
  /// Creates the badges screen.
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Achievements')),
      body: BlocBuilder<StatsCubit, StatsViewState>(
        builder: (context, state) {
          final earned = state.earnedBadges;
          final locked = state.lockedBadges;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              if (earned.isNotEmpty) ...<Widget>[
                Text('Earned', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                ...earned.map((b) => _BadgeTile(badge: b, earned: true)),
                const SizedBox(height: 16),
              ],
              Text('Locked', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              ...locked.map((b) => _BadgeTile(badge: b, earned: false)),
            ],
          );
        },
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, required this.earned});

  final BadgeDefinition badge;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('badge-${badge.id}'),
      child: ListTile(
        leading: Icon(
          earned ? Icons.emoji_events : Icons.lock_outline,
          color: earned ? Colors.amber : Colors.grey,
        ),
        title: Text(badge.title),
        subtitle: Text(badge.description),
        trailing: Text(_familyLabel(badge.family)),
      ),
    );
  }

  static String _familyLabel(BadgeFamily family) => switch (family) {
    BadgeFamily.distance => 'Distance',
    BadgeFamily.journeyProgress => 'Journey',
    BadgeFamily.focusStreak => 'Streak',
    BadgeFamily.focusTime => 'Focus',
  };
}
