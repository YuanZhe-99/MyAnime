#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#endif
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// The bridge to Apple's Foundation Models framework, on the method channel
/// `com.yuanzhe.my_anime/genai` — the same name Android's `GenAiChannel` uses.
///
/// Policy — whether the feature is on, what the prompt says, how the answer is
/// validated — lives on the Dart side. This class is a pipe. Every
/// FoundationModels reference sits behind `#if canImport(FoundationModels)` and
/// `@available(iOS 26.0, macOS 26.0, *)`; older systems answer `unsupported`.
/// Written against the Xcode 26 SDK and not yet run on a device; see
/// `doc/en-us/on-device-ai.md` for the device checklist.
public class OnDeviceAiApplePlugin: NSObject, FlutterPlugin {
  /// The channel name, matched by `MethodChannelGenAiBackend` in Dart.
  static let channelName = "com.yuanzhe.my_anime/genai"

  /// The one request allowed to be in flight.
  private var inFlight: Task<Void, Never>?

  /// Purpose: Register the method channel.
  /// Inputs: `registrar`.
  /// Returns: None.
  /// Side effects: Installs the channel handler.
  /// Notes: Called by the generated plugin registrant on both platforms.
  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
    let messenger = registrar.messenger()
    #else
    let messenger = registrar.messenger
    #endif
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    let instance = OnDeviceAiApplePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  /// Purpose: Route one method call.
  /// Inputs: `call`, `result`.
  /// Returns: None.
  /// Side effects: May run the model on the device.
  /// Notes: Every failure is a `FlutterError` whose code is one the Dart
  /// `GenAiFailure` mapping knows.
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "status":
      result(Self.status())
    case "info":
      result(Self.info(locale: args["locale"] as? String))
    case "download":
      // The system manages Apple Intelligence's model; there is nothing for
      // the app to download.
      result(FlutterError(code: "unavailable", message: "managed by the system", details: nil))
    case "prewarm":
      prewarm()
      result(nil)
    case "generate":
      run(result) {
        try await Self.generate(
          instructions: args["instructions"] as? String ?? "",
          prompt: args["prompt"] as? String ?? "",
          maxOutputTokens: args["maxOutputTokens"] as? Int ?? 256,
          temperature: args["temperature"] as? Double ?? 0
        )
      }
    case "choose":
      run(result) {
        try await Self.choose(
          instructions: args["instructions"] as? String ?? "",
          prompt: args["prompt"] as? String ?? "",
          options: args["options"] as? [String] ?? [],
          maxItems: args["maxItems"] as? Int ?? 3
        )
      }
    case "cancel":
      inFlight?.cancel()
      inFlight = nil
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Purpose: Run one async body as the single in-flight request.
  /// Inputs: `result`, `body`.
  /// Returns: None.
  /// Side effects: Starts a task; replies exactly once, on the main thread.
  /// Notes: A second request while one runs is refused as `busy`, as on
  /// Android; the framework also rejects concurrent requests per session.
  private func run(_ result: @escaping FlutterResult, _ body: @escaping () async throws -> Any?) {
    if let task = inFlight, !task.isCancelled {
      result(FlutterError(code: "busy", message: "Another request is already running", details: nil))
      return
    }
    inFlight = Task {
      let reply: Any?
      do {
        reply = try await body()
      } catch is CancellationError {
        reply = FlutterError(code: "cancelled", message: "The request was cancelled", details: nil)
      } catch {
        reply = FlutterError(code: Self.code(for: error), message: String(describing: error), details: nil)
      }
      await MainActor.run {
        self.inFlight = nil
        result(reply)
      }
    }
  }

  /// Purpose: Report the model's availability.
  /// Inputs: None.
  /// Returns: A map with `status`, `code` and an optional `detail`.
  /// Side effects: None.
  /// Notes: `appleIntelligenceNotEnabled` becomes `notEnabled`, which the user
  /// can fix in system settings; `modelNotReady` becomes `downloading`.
  static func status() -> [String: Any?] {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, macOS 26.0, *) {
      switch SystemLanguageModel.default.availability {
      case .available:
        return ["status": "available", "code": 0]
      case .unavailable(let reason):
        switch reason {
        case .deviceNotEligible:
          return ["status": "unavailable", "code": 1, "detail": "deviceNotEligible"]
        case .appleIntelligenceNotEnabled:
          return ["status": "notEnabled", "code": 2, "detail": "appleIntelligenceNotEnabled"]
        case .modelNotReady:
          return ["status": "downloading", "code": 3, "detail": "modelNotReady"]
        @unknown default:
          return ["status": "unknown", "code": -1, "detail": String(describing: reason)]
        }
      @unknown default:
        return ["status": "unknown", "code": -1]
      }
    }
    #endif
    return ["status": "unsupported", "code": -1, "detail": "needs iOS 26 or macOS 26"]
  }

  /// Purpose: Describe the system the model runs on.
  /// Inputs: `locale` — the app's locale tag, such as `zh_TW`.
  /// Returns: A map with `platform`, `installed`, `osVersion` and
  /// `localeSupported`.
  /// Side effects: None.
  /// Notes: `installed` means the framework exists on this OS.
  static func info(locale: String?) -> [String: Any?] {
    var out: [String: Any?] = [
      "platform": "apple",
      "installed": false,
      "osVersion": ProcessInfo.processInfo.operatingSystemVersionString,
    ]
    #if canImport(FoundationModels)
    if #available(iOS 26.0, macOS 26.0, *) {
      out["installed"] = true
      if let tag = locale {
        out["localeSupported"] = SystemLanguageModel.default.supportsLocale(Locale(identifier: tag))
      }
    }
    #endif
    return out
  }

  /// Purpose: Load the model ahead of a batch.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May page the model in.
  /// Notes: Best effort.
  private func prewarm() {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, macOS 26.0, *) {
      LanguageModelSession().prewarm()
    }
    #endif
  }

  /// Purpose: Generate one answer in a fresh session.
  /// Inputs: `instructions`, `prompt`, `maxOutputTokens`, `temperature`.
  /// Returns: `String`.
  /// Side effects: Runs the model on the device.
  /// Notes: A new session per request, so earlier turns cannot leak into later
  /// answers. Temperature 0 means greedy sampling.
  static func generate(
    instructions: String,
    prompt: String,
    maxOutputTokens: Int,
    temperature: Double
  ) async throws -> String {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, macOS 26.0, *) {
      let session = LanguageModelSession(instructions: instructions)
      let options = temperature <= 0
        ? GenerationOptions(sampling: .greedy, maximumResponseTokens: maxOutputTokens)
        : GenerationOptions(temperature: temperature, maximumResponseTokens: maxOutputTokens)
      let response = try await session.respond(to: prompt, options: options)
      return response.content
    }
    #endif
    throw PluginFailure.unavailable
  }

  /// Purpose: Pick up to `maxItems` of `options` with constrained decoding.
  /// Inputs: `instructions`, `prompt`, `options`, `maxItems`.
  /// Returns: `[String]` — the chosen options.
  /// Side effects: Runs the model on the device.
  /// Notes: The schema is an array of an `anyOf` string choice, so the model
  /// cannot answer outside the list. The Dart side validates again anyway.
  static func choose(
    instructions: String,
    prompt: String,
    options: [String],
    maxItems: Int
  ) async throws -> [String] {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, macOS 26.0, *) {
      if options.isEmpty { return [] }
      let item = DynamicGenerationSchema(
        name: "Choice",
        description: "One of the allowed ids",
        anyOf: options
      )
      let list = DynamicGenerationSchema(
        arrayOf: item,
        minimumElements: 0,
        maximumElements: maxItems
      )
      let schema = try GenerationSchema(root: list, dependencies: [])
      let session = LanguageModelSession(instructions: instructions)
      let response = try await session.respond(
        to: prompt,
        schema: schema,
        options: GenerationOptions(sampling: .greedy)
      )
      let json = response.content.jsonString
      guard let data = json.data(using: .utf8),
        let parsed = try? JSONSerialization.jsonObject(with: data) as? [Any]
      else {
        throw PluginFailure.failed
      }
      return parsed.compactMap { $0 as? String }
    }
    #endif
    throw PluginFailure.unavailable
  }

  /// Purpose: Turn a thrown error into one of the codes Dart knows.
  /// Inputs: `error`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Maps the 26 SDK's `LanguageModelSession.GenerationError`, which
  /// apps built with Xcode 26 keep receiving on OS 27.
  static func code(for error: Error) -> String {
    if let failure = error as? PluginFailure {
      return failure.rawValue
    }
    #if canImport(FoundationModels)
    if #available(iOS 26.0, macOS 26.0, *) {
      if let generation = error as? LanguageModelSession.GenerationError {
        switch generation {
        case .rateLimited: return "quota"
        case .concurrentRequests: return "busy"
        case .guardrailViolation, .refusal: return "guardrail"
        case .unsupportedLanguageOrLocale: return "unsupportedLanguage"
        case .exceededContextWindowSize: return "tooLong"
        case .assetsUnavailable: return "unavailable"
        default: return "failed"
        }
      }
    }
    #endif
    return "failed"
  }
}

/// Failures raised by the plugin itself rather than the framework.
enum PluginFailure: String, Error {
  /// The framework is not available on this system.
  case unavailable
  /// The model's answer could not be read.
  case failed
}
