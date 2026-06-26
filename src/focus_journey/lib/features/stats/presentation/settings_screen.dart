/// Presentation layer. The settings screen: idle threshold, launch-at-startup,
/// notifications, and the re-openable privacy screen.
///
/// SEPARATION INVARIANT (TC-026): reads ONLY the [SettingsCubit]'s state and
/// dispatches to it. No OS read here — the Cubit talks to the OS through the
/// injected [StartupController] interface.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../journey/domain/travel_mode.dart';
import '../domain/app_settings.dart';
import 'onboarding_screen.dart';
import 'settings_cubit.dart';
import 'vehicle_picker.dart';

/// The settings screen.
class SettingsScreen extends StatefulWidget {
  /// Creates the settings screen.
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Reflect the real OS open-at-login state when the screen opens (AC-10).
    context.read<SettingsCubit>().syncLaunchAtStartupFromOs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: BlocBuilder<SettingsCubit, AppSettings>(
        builder: (context, settings) {
          final cubit = context.read<SettingsCubit>();
          return ListView(
            children: <Widget>[
              const _SectionHeader('Focus'),
              ListTile(
                title: const Text('Idle threshold'),
                subtitle: const Text(
                  'How long without input before the journey pauses.',
                ),
                trailing: DropdownButton<int>(
                  key: const Key('idle-threshold-dropdown'),
                  value: settings.idleThreshold.inMinutes,
                  items: _thresholdItems(settings.idleThreshold),
                  onChanged: (minutes) {
                    if (minutes != null) {
                      cubit.setIdleThreshold(Duration(minutes: minutes));
                    }
                  },
                ),
              ),
              const Divider(),
              const _SectionHeader('Vehicle'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  'Pick the vehicle you ride. Cosmetic only — it changes the '
                  'look, never your distance.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: VehiclePicker(
                  key: const Key('settings-vehicle-picker'),
                  // AC-4/AC-12: pre-seed to the saved preference, falling back to
                  // the engine display default (motorbike) when "no preference".
                  selected:
                      settings.vehiclePreference ?? TravelMode.motorbike,
                  // AC-11: writes through the single SettingsCubit preference.
                  onSelected: cubit.setVehicle,
                ),
              ),
              const Divider(),
              const _SectionHeader('System'),
              SwitchListTile(
                key: const Key('launch-at-startup-switch'),
                title: const Text('Launch at startup'),
                subtitle: const Text('Open this app when you log in.'),
                value: settings.launchAtStartup,
                onChanged: cubit.setLaunchAtStartup,
              ),
              const Divider(),
              const _SectionHeader('Notifications'),
              SwitchListTile(
                key: const Key('notifications-master-switch'),
                title: const Text('Enable notifications'),
                subtitle: const Text('Local desktop toasts only.'),
                value: settings.notificationsEnabled,
                onChanged: cubit.setNotificationsEnabled,
              ),
              SwitchListTile(
                key: const Key('notifications-badge-switch'),
                title: const Text('Badge earned'),
                value: settings.badgeNotificationsEnabled,
                onChanged: settings.notificationsEnabled
                    ? cubit.setBadgeNotificationsEnabled
                    : null,
              ),
              SwitchListTile(
                key: const Key('notifications-streak-switch'),
                title: const Text('Daily streak reminder'),
                value: settings.streakReminderEnabled,
                onChanged: settings.notificationsEnabled
                    ? cubit.setStreakReminderEnabled
                    : null,
              ),
              const Divider(),
              const _SectionHeader('Privacy'),
              ListTile(
                key: const Key('view-privacy-tile'),
                leading: const Icon(Icons.shield_outlined),
                title: const Text('View privacy promise'),
                subtitle: const Text('What this app reads and never reads.'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Privacy')),
                      body: const PrivacyContent(),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<DropdownMenuItem<int>> _thresholdItems(Duration current) {
    final minutes = <int>{
      ...AppSettings.idleThresholdPresets.map((d) => d.inMinutes),
      current.inMinutes,
    }.toList()..sort();
    return <DropdownMenuItem<int>>[
      for (final m in minutes)
        DropdownMenuItem<int>(value: m, child: Text('$m min')),
    ];
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
