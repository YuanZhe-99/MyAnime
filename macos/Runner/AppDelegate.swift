import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    let controller = mainFlutterWindow?.contentViewController as? FlutterViewController
    if let messenger = controller?.engine.binaryMessenger {
      FlutterMethodChannel(name: "com.yuanzhe.my_anime/dock", binaryMessenger: messenger)
        .setMethodCallHandler { (_ call: FlutterMethodCall, result: @escaping FlutterResult) in
          switch call.method {
          case "setDockIconVisible":
            if let args = call.arguments as? [String: Any],
               let visible = args["visible"] as? Bool {
              NSApp.setActivationPolicy(visible ? .regular : .accessory)
              if visible {
                NSApp.activate(ignoringOtherApps: true)
              }
            }
            result(nil)
          default:
            result(FlutterMethodNotImplemented)
          }
        }
    }
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
