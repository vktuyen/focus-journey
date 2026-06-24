/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

/// The kind of failure surfaced by an [ActivityPlugin] read.
///
/// Distinguishing the cause is part of the contract (AC-10): the caller
/// (`journey-engine`) owns the fallback policy and needs to tell a hard
/// "the signal is not available / was denied" condition apart from an
/// otherwise-unexpected read error.
enum ActivityPluginExceptionKind {
  /// The underlying OS API exists but reported no usable value, or the
  /// platform channel has no implementation on this platform/build.
  unavailable,

  /// The OS denied access (e.g. a permission was refused). Note: on macOS the
  /// idle/lock APIs used here require no permission, so this kind is not
  /// expected there; it exists for platforms/APIs that can deny.
  denied,

  /// Any other unexpected failure while reading the signal.
  unknown,
}

/// Typed failure thrown (as a `Future` error) by an [ActivityPlugin] when a
/// signal cannot be read.
///
/// Per the contract the plugin never returns a sentinel/garbage value and
/// never crashes the process on a failed read — it surfaces this exception so
/// the caller can decide what to do (AC-10 / TC-016 / TC-017).
class ActivityPluginException implements Exception {
  /// Creates an exception describing why a signal read failed.
  const ActivityPluginException(this.kind, {this.message, this.cause});

  /// Convenience constructor for the "unavailable" case.
  const ActivityPluginException.unavailable({String? message, Object? cause})
    : this(
        ActivityPluginExceptionKind.unavailable,
        message: message,
        cause: cause,
      );

  /// Convenience constructor for the "denied" case.
  const ActivityPluginException.denied({String? message, Object? cause})
    : this(ActivityPluginExceptionKind.denied, message: message, cause: cause);

  /// Convenience constructor for the "unknown" case.
  const ActivityPluginException.unknown({String? message, Object? cause})
    : this(ActivityPluginExceptionKind.unknown, message: message, cause: cause);

  /// Why the read failed.
  final ActivityPluginExceptionKind kind;

  /// Optional human-readable detail. Must never contain user input content;
  /// only API/diagnostic text.
  final String? message;

  /// Optional underlying error (e.g. the original `PlatformException`).
  final Object? cause;

  @override
  String toString() {
    final detail = message == null ? '' : ': $message';
    return 'ActivityPluginException(${kind.name})$detail';
  }
}
