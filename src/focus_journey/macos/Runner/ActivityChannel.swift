import Cocoa
import CoreGraphics
import FlutterMacOS

/// Native macOS backend for the `ActivityPlugin` Dart contract.
///
/// PRIVACY (headline, P0): this file reads ONLY two aggregate signals:
///   1. seconds since the last input event (a single counter from the HID
///      system event source), and
///   2. the OS session screen-lock boolean.
/// It does NOT install any event tap or input hook; it does NOT read keystrokes,
/// key contents, screen/display pixels, clipboard, files, mouse coordinates or
/// movement history, or window titles. Nothing is logged or persisted.
///
/// PERMISSIONS: none. `CGEventSource.secondsSinceLastEventType` reads the HID
/// idle counter and does NOT require Accessibility or Input-Monitoring
/// permission. `CGSessionCopyCurrentDictionary` reads the current session info.
/// No Info.plist usage strings, no entitlements, and no permission prompt.
enum ActivityChannel {
  static let channelName = "com.joblogic.focus_journey/activity"

  /// Registers the MethodChannel on the given Flutter binary messenger.
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getSystemIdleSeconds":
        handleIdleSeconds(result)
      case "isScreenLocked":
        handleScreenLocked(result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Aggregate idle: seconds since the last input event of any type. Climbs
  /// while untouched, resets to ~0 on real input, and is large after sleep/wake.
  private static func handleIdleSeconds(_ result: FlutterResult) {
    // kCGAnyInputEventType == 0xFFFFFFFF: counts ANY input as activity, so the
    // counter resets on key, mouse-move, or click (TC-003 / TC-005).
    let anyInputEventType = CGEventType(rawValue: ~UInt32(0)) ?? .null
    let seconds = CGEventSource.secondsSinceLastEventType(
      .combinedSessionState,
      eventType: anyInputEventType
    )
    if seconds.isFinite && seconds >= 0 {
      result(Int(seconds))
    } else {
      result(
        FlutterError(
          code: "UNAVAILABLE",
          message: "System idle counter returned an invalid value.",
          details: nil))
    }
  }

  /// OS session-lock state, read live at call time (not cached at startup).
  /// A merely sleeping/dimmed display whose session is not locked reports false.
  private static func handleScreenLocked(_ result: FlutterResult) {
    guard
      let info = CGSessionCopyCurrentDictionary() as? [String: Any]
    else {
      result(
        FlutterError(
          code: "UNAVAILABLE",
          message: "Current session dictionary is unavailable.",
          details: nil))
      return
    }
    // CGSSessionScreenIsLocked is present and true only when the session is
    // locked; absent/false otherwise.
    let locked = (info["CGSSessionScreenIsLocked"] as? Bool) ?? false
    result(locked)
  }
}
