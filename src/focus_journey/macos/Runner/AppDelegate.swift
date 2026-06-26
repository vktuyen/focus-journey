import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // Hide-to-tray (AC-15): this app survives its window being closed/hidden — the
  // close button hides the window to the menu-bar tray and tracking continues;
  // the ONLY full-exit path is the tray "Quit". If this returned `true`, macOS
  // would terminate the process as soon as the last window is closed/hidden,
  // defeating close-to-tray. (This — not the engine's merged platform/UI thread
  // — is what was terminating the process on the real run.)
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
