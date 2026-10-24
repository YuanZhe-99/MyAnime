import Flutter
import UIKit
import WidgetKit

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
  /// Notes: Needed for implicit engine startup paths on iOS. Also installs
  /// the home-widget channel, which needs the same engine messenger.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MyAnimeHomeWidget") {
      registerHomeWidgetChannel(messenger: registrar.messenger())
    }
  }

  /// Purpose: Receive widget snapshots from `HomeWidgetService` and reload the widgets.
  /// Inputs: `messenger` — the Flutter engine's binary messenger.
  /// Returns: None.
  /// Side effects: Writes `myanime_widget_snapshot` into the App Group
  /// `UserDefaults` and asks WidgetKit to reload every timeline.
  /// Notes: The App Group must match `UpNextWidget/UpNextWidget.swift` and both
  /// entitlements files. WidgetKit needs iOS 14; older systems only store.
  private func registerHomeWidgetChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "com.yuanzhe.my_anime/home_widget", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "update" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let args = call.arguments as? [String: Any]
      let snapshot = args?["snapshot"] as? String ?? ""
      UserDefaults(suiteName: "group.com.yuanzhe.myAnime")?.set(snapshot, forKey: "myanime_widget_snapshot")
      if #available(iOS 14.0, *) {
        WidgetCenter.shared.reloadAllTimelines()
      }
      result(nil)
    }
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
