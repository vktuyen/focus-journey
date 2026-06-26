/// Data layer — real [WindowVisibilityController] over a MethodChannel
/// (start/snapshot) + an EventChannel (occlusion change stream), mirroring the
/// `ActivityChannel` platform-channel pattern.
///
/// Privacy (NFR-2): this backend only asks the native side to report whether
/// the app's OWN window has pixels on screen. It sends NO arguments that could
/// leak user data, reads NO input content, and logs/persists nothing.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/surface_visibility.dart';
import '../domain/window_visibility_controller.dart';

/// Native-backed [WindowVisibilityController] talking to the macOS (Swift) /
/// Windows (C++/Win32) runners.
///
/// - macOS reports a TRUE occlusion signal via `NSWindow.occlusionState`
///   (`+ isMiniaturized` / app-hidden), observed from
///   `NSWindowDidChangeOcclusionStateNotification`.
/// - Windows has no reliable arbitrary-window occlusion API, so it reports a
///   minimized/hidden fallback (`IsWindowVisible` + `IsIconic`, plus DWM
///   cloaking) — see the native header. The Dart side is identical for both;
///   the fallback is documented natively and in this feature's README.
///
/// Channel payload contract (kept tiny + non-sensitive): a visibility event is
/// a map `{ 'surface': 'main' | 'pip', 'visible': bool }`. The MethodChannel
/// `snapshot` returns a `List` of such maps for the initial state.
class MethodChannelWindowVisibilityController
    implements WindowVisibilityController {
  /// Creates the backend. Custom channels may be injected for tests
  /// (fault/payload injection); otherwise the default channels are used.
  MethodChannelWindowVisibilityController({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _method = methodChannel ?? const MethodChannel(methodChannelName),
       _event = eventChannel ?? const EventChannel(eventChannelName);

  /// MethodChannel name (start + snapshot). Mirrors the activity channel
  /// naming convention.
  static const String methodChannelName =
      'com.joblogic.focus_journey/window_visibility';

  /// EventChannel name (occlusion change stream).
  static const String eventChannelName =
      'com.joblogic.focus_journey/window_visibility/events';

  /// MethodChannel method that begins native observation and returns the
  /// initial per-surface snapshot.
  static const String methodStart = 'start';

  static const String _keySurface = 'surface';
  static const String _keyVisible = 'visible';
  static const String _surfaceMain = 'main';
  static const String _surfacePip = 'pip';

  final MethodChannel _method;
  final EventChannel _event;

  final _changes = StreamController<SurfaceVisibility>.broadcast();
  final Map<WindowSurface, SurfaceVisibility> _latest =
      <WindowSurface, SurfaceVisibility>{};
  StreamSubscription<dynamic>? _eventSub;
  bool _started = false;

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;

    // Subscribe to the live occlusion stream first so we miss no transition
    // between the snapshot and stream attach.
    _eventSub = _event.receiveBroadcastStream().listen(
      _onEvent,
      onError: (Object error, StackTrace stack) {
        // A stream error must never crash the app. The scene keeps its last
        // reading (defaulting to visible), erring toward animating (AC-3).
        debugPrint(
          'MethodChannelWindowVisibilityController stream error: $error',
        );
      },
    );

    try {
      final raw = await _method.invokeMethod<Object?>(methodStart);
      _ingestSnapshot(raw);
    } on MissingPluginException {
      // No native implementation on this platform/build → leave defaults
      // (all surfaces visible). The scene animates; pause-when-hidden then
      // relies on the existing WindowModeController fallback. Documented in the
      // feature README (Windows / unsupported builds).
    } on PlatformException catch (e) {
      debugPrint(
        'MethodChannelWindowVisibilityController start failed: ${e.code}',
      );
    }
  }

  @override
  SurfaceVisibility visibilityOf(WindowSurface surface) {
    return _latest[surface] ?? SurfaceVisibility.visible(surface);
  }

  @override
  bool isVisible(WindowSurface surface) => visibilityOf(surface).visible;

  @override
  Stream<SurfaceVisibility> get changes => _changes.stream;

  @override
  Future<void> dispose() async {
    await _eventSub?.cancel();
    _eventSub = null;
    if (!_changes.isClosed) {
      await _changes.close();
    }
  }

  // --- internals ---

  void _ingestSnapshot(Object? raw) {
    if (raw is! List) return;
    for (final entry in raw) {
      final reading = _decode(entry);
      if (reading != null) {
        _apply(reading);
      }
    }
  }

  void _onEvent(dynamic event) {
    final reading = _decode(event);
    if (reading != null) {
      _apply(reading);
    }
  }

  /// Decodes one `{surface, visible}` map into a [SurfaceVisibility]. Returns
  /// `null` (ignored) for any malformed payload, so a bad event can never throw
  /// or feed the scene a wrong type.
  SurfaceVisibility? _decode(Object? raw) {
    if (raw is! Map) return null;
    final surfaceName = raw[_keySurface];
    final visible = raw[_keyVisible];
    if (visible is! bool) return null;
    final surface = switch (surfaceName) {
      _surfaceMain => WindowSurface.main,
      _surfacePip => WindowSurface.pip,
      _ => null,
    };
    if (surface == null) return null;
    return SurfaceVisibility(surface: surface, visible: visible);
  }

  /// De-duplicated apply: updates the cache and emits only on a real change for
  /// that surface (NFR-1 — no redundant pause/resume churn).
  void _apply(SurfaceVisibility reading) {
    final prior = _latest[reading.surface];
    if (prior != null && prior.visible == reading.visible) return;
    _latest[reading.surface] = reading;
    if (!_changes.isClosed) {
      _changes.add(reading);
    }
  }
}
