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

    super.awakeFromNib()
  }
}
