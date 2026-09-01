import Cocoa
import FlutterMacOS
import desktop_multi_window

private func applyHwAccelPref() {
  let url = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/aqloss/hw_accel")
  guard let data = try? Data(contentsOf: url),
        let text = String(data: data, encoding: .utf8),
        text.hasPrefix("0")
  else { return }
  setenv("FLUTTER_ENGINE_SWITCHES", "2", 1)
  setenv("FLUTTER_ENGINE_SWITCH_1", "enable-software-rendering", 1)
  setenv("FLUTTER_ENGINE_SWITCH_2", "disable-impeller", 1)
}

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    applyHwAccelPref()
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      RegisterGeneratedPlugins(registry: controller)
    }

    super.awakeFromNib()
  }
}
