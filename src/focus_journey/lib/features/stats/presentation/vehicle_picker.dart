/// Presentation layer. The reusable icon-based vehicle picker (vehicle-picker
/// AC-14 / NFR-3) and its picker-UI icon constants.
///
/// COSMETIC-ONLY (ADR-0007): this widget surfaces a choice of [TravelMode] and
/// reports it via [onSelected]; the chosen mode is a **cosmetic skin override**
/// composed at the presentation seam (`vehiclePreference ?? engineMode`). It
/// touches NO engine state — both picker entry points (the Settings row and the
/// route-start step) route through `SettingsCubit.setVehicle(...)`.
///
/// ICON ASSETS: the picker uses Flutter [AssetImage] glyphs under
/// `assets/journey/vehicle_icons/` — these are PICKER-UI assets, SEPARATE from
/// the in-scene Flame sprites in `assets/journey/vehicles/` and deliberately NOT
/// part of `JourneyAssets.all` (so the scene-asset cross-check stays scoped).
/// The path↔mode map lives here ([vehicleIconAsset]); every path is attributed
/// in `assets/CREDITS.md` (AC-15).
///
/// ACCESSIBILITY (NFR-3): each option is a focus-reachable, keyboard-operable
/// control carrying a per-mode [Semantics] label naming the mode; the mode is
/// carried by the distinct per-mode icon/silhouette + label, not by colour
/// alone (the selected state adds a ring + scale, not just a tint).
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../journey/domain/travel_mode.dart';
import '../domain/app_settings.dart';
import 'settings_cubit.dart';

/// The COSMETIC vehicle-override presentation seam (ADR-0007), in ONE place so
/// the two `applyState` drivers (`AppShell` on the production shared-game path,
/// `JourneyScreen` on the standalone path) compose it identically and cannot
/// drift.
///
/// [readVehiclePreference] reads `SettingsCubit.state.vehiclePreference` from
/// [context], degrading to `null` ("no preference" → follow the engine mode,
/// AC-4) when no [SettingsCubit] is in the tree — so the override is purely
/// additive and a host without a settings provider behaves exactly as before,
/// never crashing. This is the ONLY place display reads the preference; the
/// engine and `JourneyCubit` never see it (AC-9/AC-10 firewall).
TravelMode? readVehiclePreference(BuildContext context) {
  try {
    return context.read<SettingsCubit>().state.vehiclePreference;
  } on ProviderNotFoundException {
    return null;
  }
}

/// Composes the displayed cosmetic mode `vehiclePreference ?? engineMode` for
/// the one value handed to `JourneyGame.applyState(mode:)` (AC-1/AC-2/AC-3).
/// O(1) nullable-coalesce — no per-frame cost (NFR-1).
TravelMode composeDisplayedMode(BuildContext context, TravelMode engineMode) {
  return readVehiclePreference(context) ?? engineMode;
}

/// Whether a [SettingsCubit] is available in [context]'s tree, so callers can
/// gate the override listener / picker affordance without throwing when absent.
bool hasSettingsCubit(BuildContext context) {
  try {
    context.read<SettingsCubit>();
    return true;
  } on ProviderNotFoundException {
    return false;
  }
}

/// A [BlocListener] that re-invokes [onPreferenceChanged] within ≤1 frame when
/// `vehiclePreference` changes (AC-1), so a live pick re-applies the composed
/// mode on whichever surface is showing. No-op wrapper (just renders [child])
/// when no [SettingsCubit] is mounted, mirroring the defensive read above.
class VehiclePreferenceListener extends StatelessWidget {
  /// Creates the listener around [child].
  const VehiclePreferenceListener({
    required this.onPreferenceChanged,
    required this.child,
    super.key,
  });

  /// Invoked (with the listener's [BuildContext]) when the preference changes.
  final void Function(BuildContext context) onPreferenceChanged;

  /// The subtree to render.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!hasSettingsCubit(context)) {
      return child;
    }
    return BlocListener<SettingsCubit, AppSettings>(
      listenWhen: (AppSettings prev, AppSettings next) =>
          prev.vehiclePreference != next.vehiclePreference,
      listener: (BuildContext context, AppSettings _) =>
          onPreferenceChanged(context),
      child: child,
    );
  }
}

/// The picker-UI icon asset path for [mode] (relative to the asset root, NOT the
/// Flame `images.prefix`). One distinct flat glyph per mode (AC-14). Separate
/// from the in-scene vehicle sprites; every path is in `assets/CREDITS.md`.
String vehicleIconAsset(TravelMode mode) {
  switch (mode) {
    case TravelMode.walk:
      return 'assets/journey/vehicle_icons/walk.png';
    case TravelMode.run:
      return 'assets/journey/vehicle_icons/run.png';
    case TravelMode.bicycle:
      return 'assets/journey/vehicle_icons/bicycle.png';
    case TravelMode.motorbike:
      return 'assets/journey/vehicle_icons/motorbike.png';
    case TravelMode.car:
      return 'assets/journey/vehicle_icons/car.png';
    case TravelMode.ship:
      return 'assets/journey/vehicle_icons/ship.png';
  }
}

/// The human-readable, screen-reader label for [mode] (NFR-3 — names the mode,
/// e.g. "Car", "Motorbike").
String vehicleLabel(TravelMode mode) {
  switch (mode) {
    case TravelMode.walk:
      return 'Walk';
    case TravelMode.run:
      return 'Run';
    case TravelMode.bicycle:
      return 'Bicycle';
    case TravelMode.motorbike:
      return 'Motorbike';
    case TravelMode.car:
      return 'Car';
    case TravelMode.ship:
      return 'Ship';
  }
}

/// A reusable, icon-based, keyboard-reachable vehicle picker: a wrapping row of
/// selectable icon chips, one per [TravelMode.values] (AC-14). The [selected]
/// chip is conveyed by a ring + scale (not colour alone — NFR-3). Picking a chip
/// invokes [onSelected]; the host persists it via `SettingsCubit.setVehicle`.
class VehiclePicker extends StatelessWidget {
  /// Creates the picker. [selected] is the currently-chosen mode (pre-seeded by
  /// the host from the saved preference, defaulting to the engine display mode);
  /// [onSelected] fires with the picked mode.
  const VehiclePicker({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// The currently-selected mode (highlighted).
  final TravelMode selected;

  /// Called with the mode the user picks.
  final ValueChanged<TravelMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Choose your vehicle',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          for (final TravelMode mode in TravelMode.values)
            _VehicleChip(
              mode: mode,
              selected: mode == selected,
              onTap: () => onSelected(mode),
            ),
        ],
      ),
    );
  }
}

/// One selectable icon chip for [mode]. Focus-reachable + keyboard-operable
/// (InkWell in the focus traversal), labelled, and selection conveyed by a ring
/// + scale + the icon silhouette — never colour alone (NFR-3).
class _VehicleChip extends StatelessWidget {
  const _VehicleChip({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final TravelMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: vehicleLabel(mode),
      button: true,
      selected: selected,
      child: Tooltip(
        message: vehicleLabel(mode),
        child: InkWell(
          key: Key('vehicle-chip-${mode.name}'),
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: selected
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHighest,
              border: Border.all(
                // Selection conveyed by ring WIDTH + the scale below, not by
                // colour alone (NFR-3).
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 3 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 120),
                scale: selected ? 1.12 : 1.0,
                // ExcludeSemantics: the per-mode name is carried by the chip's
                // Semantics label above, so the decorative glyph adds no noise.
                child: ExcludeSemantics(
                  child: Image.asset(
                    vehicleIconAsset(mode),
                    fit: BoxFit.contain,
                    color: selected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
