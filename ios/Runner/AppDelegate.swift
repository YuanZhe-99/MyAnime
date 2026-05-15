import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Purpose: Finish iOS app launch and keep Flutter's default startup behavior.
  /// Inputs: `application`, `launchOptions`.
  /// Returns: `Bool`.
  /// Side effects: Boots the Flutter app lifecycle.
  /// Notes: This override currently delegates entirely to `FlutterAppDelegate`.
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Purpose: Register generated plugins on the implicit Flutter engine bridge.
  /// Inputs: `engineBridge`.
  /// Returns: None.
  /// Side effects: Registers generated plugins with the provided engine registry.
  /// Notes: Needed for implicit engine startup paths on iOS.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  /// Purpose: Forward opened `.myanimeitem` files from iOS into Flutter.
  /// Inputs: `app`, `url`, `options`.
  /// Returns: `Bool`.
  /// Side effects: Invokes the Flutter file-open channel when the file extension matches.
  /// Notes: Falls back to the superclass handler for all other URLs.
  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    if url.pathExtension == "myanimeitem" {
      let controller = window?.rootViewController as? FlutterViewController
      let channel = FlutterMethodChannel(name: "com.yuanzhe.my_anime/file_open", binaryMessenger: controller!.binaryMessenger)
      channel.invokeMethod("openFile", arguments: url.path)
      return true
    }
    return super.application(app, open: url, options: options)
  }
}
