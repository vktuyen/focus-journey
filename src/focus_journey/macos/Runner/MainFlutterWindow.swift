import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Register the privacy-scoped activity channel (idle seconds + lock state).
    ActivityChannel.register(with: flutterViewController.engine.binaryMessenger)

    // Register the per-surface window-visibility (occlusion) channel
    // (journey-scene-v2 #5). Reads ONLY this window's own occlusion/minimized/
    // hidden state — no other-app or input data (NFR-2).
    WindowVisibilityChannel.register(
      with: flutterViewController.engine.binaryMessenger, window: self)

    super.awakeFromNib()
  }
}
