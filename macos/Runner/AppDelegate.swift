import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func application(_ sender: NSApplication, openFile filename: String) -> Bool {
    if filename.hasSuffix(".myanimeitem") {
      let controller = mainFlutterWindow?.contentViewController as? FlutterViewController
      if let messenger = controller?.engine.binaryMessenger {
        let channel = FlutterMethodChannel(name: "com.yuanzhe.my_anime/file_open", binaryMessenger: messenger)
        channel.invokeMethod("openFile", arguments: filename)
      }
      return true
    }
    return false
  }
}
