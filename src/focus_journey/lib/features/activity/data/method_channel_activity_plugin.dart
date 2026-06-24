/// Data layer — real [ActivityPlugin] backend over a single [MethodChannel].
///
/// Privacy: this backend only invokes two channel methods that return an
/// aggregate idle-second count and a lock boolean. It sends NO arguments, reads
/// NO input content, and logs/persists nothing.
library;

import 'package:flutter/services.dart';

import '../domain/activity_plugin.dart';
import '../domain/activity_plugin_exception.dart';

/// Native-backed [ActivityPlugin] talking to the macOS (Swift) / Windows
/// (C++/Win32) runners over the `com.joblogic.focus_journey/activity` channel.
class MethodChannelActivityPlugin implements ActivityPlugin {
  /// Creates the backend. A custom [channel] may be injected for tests
  /// (e.g. fault injection — TC-016 / TC-017); otherwise the default channel
  /// is used.
  MethodChannelActivityPlugin({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  /// The platform-channel name shared with both native runners.
  static const String channelName = 'com.joblogic.focus_journey/activity';

  /// Channel method returning idle seconds as an `int`.
  static const String methodGetSystemIdleSeconds = 'getSystemIdleSeconds';

  /// Channel method returning the session-lock state as a `bool`.
  static const String methodIsScreenLocked = 'isScreenLocked';

  /// Native error code mapped to [ActivityPluginExceptionKind.denied].
  static const String _codeDenied = 'DENIED';

  final MethodChannel _channel;

  @override
  Future<int> getSystemIdleSeconds() {
    return _invoke<int>(methodGetSystemIdleSeconds, _coerceIdleSeconds);
  }

  @override
  Future<bool> isScreenLocked() {
    return _invoke<bool>(methodIsScreenLocked, _coerceLocked);
  }

  /// Invokes [method] (untyped) and maps any channel failure OR unexpected
  /// payload type to a typed [ActivityPluginException] (AC-10). All
  /// rounding/typing lives in [coerce] and runs inside the `try`, so no raw
  /// `TypeError` can escape — a type mismatch becomes `unavailable` (B1).
  Future<T> _invoke<T>(
    String method,
    T Function(Object? raw, String method) coerce,
  ) async {
    try {
      final raw = await _channel.invokeMethod<Object?>(method);
      return coerce(raw, method);
    } on MissingPluginException catch (e) {
      // No implementation on this platform/build → the signal is unavailable.
      throw ActivityPluginException.unavailable(
        message: 'No native implementation for "$method".',
        cause: e,
      );
    } on PlatformException catch (e) {
      throw ActivityPluginException(
        e.code == _codeDenied
            ? ActivityPluginExceptionKind.denied
            : ActivityPluginExceptionKind.unavailable,
        message: e.message ?? 'Native "$method" failed (${e.code}).',
        cause: e,
      );
    }
  }

  /// Idle coercion: accept any `num` (an `int`, or a `double` such as `17.0`
  /// from codec deserialization) and truncate to `int`. Anything non-numeric
  /// or `null` → `unavailable`, never a silently-wrong value (B1). Centralizing
  /// truncation here also removes any macOS/Windows rounding drift (S2).
  static int _coerceIdleSeconds(Object? raw, String method) {
    if (raw is num) {
      return raw.toInt();
    }
    throw ActivityPluginException.unavailable(
      message:
          'Native "$method" returned a non-numeric value (${raw.runtimeType}).',
    );
  }

  /// Lock coercion: accept only a `bool`. Anything else or `null` →
  /// `unavailable` (B1).
  static bool _coerceLocked(Object? raw, String method) {
    if (raw is bool) {
      return raw;
    }
    throw ActivityPluginException.unavailable(
      message:
          'Native "$method" returned a non-boolean value (${raw.runtimeType}).',
    );
  }
}
