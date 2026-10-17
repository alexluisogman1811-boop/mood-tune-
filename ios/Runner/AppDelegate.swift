import Flutter
import MusicKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MusicKitBridge") {
      MusicKitBridge.register(with: registrar)
    }
  }
}

/// Exposes the MusicKit features MoodScape needs to Dart over the
/// "moodscape/musickit" channel. Tokens are returned to Dart (which stores the
/// user token in the Keychain via flutter_secure_storage) and never logged.
///
/// Requirements: iOS 15+, the MusicKit App Service enabled for this bundle ID
/// in the Apple Developer portal, and NSAppleMusicUsageDescription in
/// Info.plist. MusicKit does not work in the iOS Simulator.
final class MusicKitBridge: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "moodscape/musickit",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(MusicKitBridge(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "authorizationStatus":
      result(Self.name(of: MusicAuthorization.currentStatus))

    case "requestAuthorization":
      Task {
        let status = await MusicAuthorization.request()
        Self.reply(result, Self.name(of: status))
      }

    case "developerToken":
      Task {
        do {
          let token = try await DefaultMusicTokenProvider().developerToken(options: [])
          Self.reply(result, token)
        } catch {
          Self.reply(result, FlutterError(
            code: "DEVELOPER_TOKEN",
            message: "MusicKit could not create a developer token. Check that the "
              + "MusicKit App Service is enabled for this app.",
            details: nil))
        }
      }

    case "userToken":
      guard let args = call.arguments as? [String: Any],
            let developerToken = args["developerToken"] as? String,
            !developerToken.isEmpty
      else {
        result(FlutterError(code: "BAD_ARGS", message: "Missing developer token.", details: nil))
        return
      }
      Task {
        do {
          let token = try await DefaultMusicTokenProvider().userToken(
            for: developerToken, options: [])
          Self.reply(result, token)
        } catch {
          Self.reply(result, FlutterError(
            code: "USER_TOKEN",
            message: "Apple Music could not authorise this device. Make sure you are "
              + "signed in to Apple Music.",
            details: nil))
        }
      }

    case "subscription":
      Task {
        do {
          let subscription = try await MusicSubscription.current
          Self.reply(result, [
            "canPlayCatalogContent": subscription.canPlayCatalogContent,
            "canBecomeSubscriber": subscription.canBecomeSubscriber,
          ])
        } catch {
          Self.reply(result, FlutterError(
            code: "SUBSCRIPTION",
            message: "Could not check your Apple Music subscription.",
            details: nil))
        }
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// FlutterResult must be invoked on the main thread.
  private static func reply(_ result: @escaping FlutterResult, _ value: Any?) {
    DispatchQueue.main.async { result(value) }
  }

  private static func name(of status: MusicAuthorization.Status) -> String {
    switch status {
    case .authorized: return "authorized"
    case .denied: return "denied"
    case .restricted: return "restricted"
    case .notDetermined: return "notDetermined"
    @unknown default: return "denied"
    }
  }
}
