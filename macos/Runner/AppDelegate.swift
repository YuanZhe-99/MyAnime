import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  /// Purpose: Keep the macOS app alive after the last window closes.
  /// Inputs: `sender` when AppKit asks about shutdown behavior.
  /// Returns: `false`.
  /// Side effects: None.
  /// Notes: Supports tray-style behavior instead of quitting immediately.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  /// Purpose: Opt into secure state restoration support for the app.
  /// Inputs: `app` when AppKit checks restoration support.
  /// Returns: `true`.
  /// Side effects: None.
  /// Notes: Keep this enabled unless macOS restoration requirements change.
  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// Purpose: Register the dock-visibility bridge after the Flutter engine starts.
  /// Inputs: `notification` from the macOS launch lifecycle.
  /// Returns: None.
  /// Side effects: Installs a Flutter method-channel handler and may change dock activation policy later.
  /// Notes: The handler only supports dock visibility requests for the desktop tray workflow.
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

  /// Purpose: Forward opened `.myanimeitem` files from Finder into Flutter.
  /// Inputs: `sender`, `filename`.
  /// Returns: `Bool`.
  /// Side effects: Invokes the Flutter file-open channel for supported files.
  /// Notes: Returns `false` for unsupported filenames so AppKit can continue default handling.
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
