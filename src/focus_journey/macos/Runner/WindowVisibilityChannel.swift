import Cocoa
import FlutterMacOS

/// Native macOS backend for the `WindowVisibilityController` Dart contract
/// (journey-scene-v2 #5: animate when visible, pause when not).
///
/// PRIVACY (headline, P0 — NFR-2): this file reads ONLY the app's OWN window
/// visibility state — whether THIS window currently has pixels on screen. It
/// uses three own-window signals:
///   1. `NSWindow.occlusionState` (`NSWindowOcclusionState.visible`) — a TRUE
///      occlusion read (works for a frameless, always-on-top PiP window too,
///      because occlusionState is a per-window property independent of style or
///      window level),
///   2. `NSWindow.isMiniaturized` (minimized to the Dock), and
///   3. `NSApplication.isHidden` (the whole app hidden).
/// It installs NO event tap / input hook and reads NO keystrokes, screen
/// pixels, clipboard, files, mouse coordinates/history, OTHER apps' focus, or
/// any window titles. It deliberately does NOT use focus (`isKeyWindow`): the
/// scene must keep animating while visible-but-unfocused (AC-3).
///
/// PERMISSIONS: none. Observing your own window's occlusion state needs no
/// entitlement, no Info.plist usage string, and shows no permission prompt.
///
/// PER-SURFACE (AC-5): the app is single-window two-mode (ADR-0003), so one
/// `NSWindow` is observed. Its surface tag (`main` vs `pip`) follows the
/// window's current frameless/always-on-top mode, so the Dart side still
/// receives a per-surface event and the seam stays per-surface-ready.
final class WindowVisibilityChannel: NSObject, FlutterStreamHandler {
  static let methodChannelName = "com.joblogic.focus_journey/window_visibility"
  static let eventChannelName = "com.joblogic.focus_journey/window_visibility/events"
  static let methodStart = "start"

  private weak var window: NSWindow?
  private var eventSink: FlutterEventSink?
  private var observers: [NSObjectProtocol] = []
  // Last emitted value, to de-duplicate (no redundant pause/resume churn).
  private var lastVisible: Bool?

  /// Registers the method + event channels for the given window.
  static func register(with messenger: FlutterBinaryMessenger, window: NSWindow) {
    let instance = WindowVisibilityChannel(window: window)
    // Retain for the app's lifetime via the method-channel handler closure.
    let methodChannel = FlutterMethodChannel(
      name: methodChannelName, binaryMessenger: messenger)
    let eventChannel = FlutterEventChannel(
      name: eventChannelName, binaryMessenger: messenger)
    eventChannel.setStreamHandler(instance)
    methodChannel.setMethodCallHandler { call, result in
      switch call.method {
      case methodStart:
        instance.startObserving()
        // Return the current snapshot so Dart has an immediate reading.
        result([instance.currentReading()])
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private init(window: NSWindow) {
    self.window = window
    super.init()
  }

  // MARK: FlutterStreamHandler

  func onListen(
    withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    startObserving()
    // Emit the current state immediately so a fresh listener is in sync.
    emitIfChanged(force: true)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  // MARK: Observation

  private func startObserving() {
    guard observers.isEmpty else { return }
    let center = NotificationCenter.default
    let wsCenter = NSWorkspace.shared.notificationCenter

    // The headline signal: occlusion changes (covered / uncovered).
    addObserver(center, NSWindow.didChangeOcclusionStateNotification)
    // Minimize / restore to-from the Dock.
    addObserver(center, NSWindow.didMiniaturizeNotification)
    addObserver(center, NSWindow.didDeminiaturizeNotification)
    // Order in/out of the screen (e.g. window_manager hide()/show()).
    addObserver(center, NSWindow.didChangeScreenNotification)

    // Whole-app hide/unhide (Cmd-H).
    wsCenter.addObserver(
      forName: NSWorkspace.didHideApplicationNotification, object: nil,
      queue: .main
    ) { [weak self] _ in self?.emitIfChanged() }
    wsCenter.addObserver(
      forName: NSWorkspace.didUnhideApplicationNotification, object: nil,
      queue: .main
    ) { [weak self] _ in self?.emitIfChanged() }
  }

  private func addObserver(_ center: NotificationCenter, _ name: Notification.Name) {
    let token = center.addObserver(
      forName: name, object: window, queue: .main
    ) { [weak self] _ in self?.emitIfChanged() }
    observers.append(token)
  }

  /// Computes whether THIS window currently has any pixels on screen.
  /// `true` when the window's occlusionState contains `.visible` AND it is not
  /// miniaturized AND the app is not hidden. Note: occlusionState is `.visible`
  /// even when another app holds keyboard focus, so this stays true for the
  /// visible-but-unfocused case (AC-3).
  private func isVisible() -> Bool {
    guard let window = window else { return false }
    if NSApp.isHidden { return false }
    if window.isMiniaturized { return false }
    return window.occlusionState.contains(.visible)
  }

  /// The current surface tag. The single window is tagged `pip` while it is in
  /// the frameless always-on-top compact mode, else `main`. We infer compact
  /// mode from the window level being above normal (window_manager raises it
  /// for always-on-top) combined with a missing titlebar.
  private func surfaceTag() -> String {
    guard let window = window else { return "main" }
    let isAlwaysOnTop = window.level.rawValue > NSWindow.Level.normal.rawValue
    let isFrameless = !window.styleMask.contains(.titled)
    return (isAlwaysOnTop && isFrameless) ? "pip" : "main"
  }

  private func currentReading() -> [String: Any] {
    return ["surface": surfaceTag(), "visible": isVisible()]
  }

  private func emitIfChanged(force: Bool = false) {
    let visible = isVisible()
    if !force, let last = lastVisible, last == visible { return }
    lastVisible = visible
    eventSink?(currentReading())
  }
}
