/// Presentation layer. The start-province + direction selector.
///
/// PRIVACY (AC-16): reads no OS signal — it only lets the user pick from the
/// static chain and calls back with the chosen (start, direction).
///
/// OFF-DIRECTION TIP BLOCK (locked decision 4 / AC-15 / TC-015): for a chain-tip
/// province, the direction that points OFF the chain is **disabled** (the radio
/// is non-selectable) so the user can never commit a route that begins
/// already-finished. The model-level [RouteSelection.create] guard is the
/// defensive backstop.
library;

import 'package:flutter/material.dart';

import '../domain/journey_direction.dart';
import '../domain/province.dart';
import '../domain/province_chain.dart';

/// A dialog/inline selector for a route start + direction. Calls [onConfirm]
/// with the chosen pair (which is guaranteed valid — off-direction tips are
/// disabled).
class StartPicker extends StatefulWidget {
  /// Creates the picker over [chain]. [onConfirm] fires when the user confirms a
  /// valid (start, direction) pair.
  const StartPicker({
    required this.chain,
    required this.onConfirm,
    this.initialStart,
    this.initialDirection,
    super.key,
  });

  /// The province chain to pick from.
  final ProvinceChain chain;

  /// Called with the confirmed valid selection.
  final void Function(Province start, JourneyDirection direction) onConfirm;

  /// Optional pre-selected start (e.g. when changing an existing route).
  final Province? initialStart;

  /// Optional pre-selected direction.
  final JourneyDirection? initialDirection;

  @override
  State<StartPicker> createState() => _StartPickerState();
}

class _StartPickerState extends State<StartPicker> {
  late Province _start;
  JourneyDirection? _direction;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart ?? widget.chain.nodes.first;
    _direction = widget.initialDirection;
    _coerceDirection();
  }

  /// Ensures the chosen direction is valid for the chosen start; clears it if
  /// the current selection became off-direction after a start change.
  void _coerceDirection() {
    final dir = _direction;
    if (dir != null && widget.chain.isOffDirectionTip(_start, dir)) {
      _direction = null;
    }
  }

  bool _directionEnabled(JourneyDirection dir) =>
      !widget.chain.isOffDirectionTip(_start, dir);

  @override
  Widget build(BuildContext context) {
    final canConfirm = _direction != null && _directionEnabled(_direction!);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Choose your starting point',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          DropdownButton<Province>(
            key: const Key('start_picker_province_dropdown'),
            value: _start,
            isExpanded: true,
            items: <DropdownMenuItem<Province>>[
              for (final province in widget.chain.nodes)
                DropdownMenuItem<Province>(
                  value: province,
                  child: Text(province.name),
                ),
            ],
            onChanged: (province) {
              if (province == null) return;
              setState(() {
                _start = province;
                _coerceDirection();
              });
            },
          ),
          const SizedBox(height: 16),
          Text('Direction', style: Theme.of(context).textTheme.titleMedium),
          RadioGroup<JourneyDirection>(
            groupValue: _direction,
            onChanged: (v) => setState(() => _direction = v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _DirectionTile(
                  key: const Key('direction_toward_ha_giang'),
                  label: 'Toward ${widget.chain.northTip.name} (north)',
                  value: JourneyDirection.towardHaGiang,
                  enabled: _directionEnabled(JourneyDirection.towardHaGiang),
                ),
                _DirectionTile(
                  key: const Key('direction_toward_mui_ca_mau'),
                  label: 'Toward ${widget.chain.southTip.name} (south)',
                  value: JourneyDirection.towardMuiCaMau,
                  enabled: _directionEnabled(JourneyDirection.towardMuiCaMau),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('start_picker_confirm'),
            onPressed: canConfirm
                ? () => widget.onConfirm(_start, _direction!)
                : null,
            child: const Text('Start journey'),
          ),
        ],
      ),
    );
  }
}

/// A single selectable direction row inside the enclosing [RadioGroup]; renders
/// disabled (non-selectable) when [enabled] is false — the off-chain direction
/// for a tip province (locked decision 4 / TC-015).
class _DirectionTile extends StatelessWidget {
  const _DirectionTile({
    required this.label,
    required this.value,
    required this.enabled,
    super.key,
  });

  final String label;
  final JourneyDirection value;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<JourneyDirection>(
      title: Text(enabled ? label : '$label — unavailable from this start'),
      value: value,
      // `enabled: false` makes the tile non-selectable within the RadioGroup,
      // so an off-direction tip can never be committed (TC-015).
      enabled: enabled,
    );
  }
}
