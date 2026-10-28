import Flutter
import UIKit
import UserNotifications

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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ExpressoKeepAlive") {
      ExpressoKeepAlive.register(with: registrar)
    }
  }
}

/// iOS side of the 'espressopico/ble_keepalive' channel (Android: MainActivity +
/// BleKeepAliveService). iOS has no foreground service: the bluetooth-central
/// background mode (Info.plist) keeps the BLE link, so start/update/stop are
/// no-ops. The post-shot weight prompt is a local notification; tapping it
/// resumes the app and HomeView re-opens the weight sheet.
final class ExpressoKeepAlive: NSObject, FlutterPlugin {
  static let brewPromptId = "espressopico_brew_weight"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "espressopico/ble_keepalive", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(ExpressoKeepAlive(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start", "update", "stop":
      result(true)
    case "showBrewWeightPrompt":
      let args = call.arguments as? [String: Any]
      let title = args?["title"] as? String ?? "Uutto tallennettu"
      let body = args?["body"] as? String ?? "Avaa ja syötä toteutunut paino"
      showBrewWeightPrompt(title: title, body: body, result: result)
    case "cancelBrewWeightPrompt":
      let center = UNUserNotificationCenter.current()
      center.removePendingNotificationRequests(withIdentifiers: [Self.brewPromptId])
      center.removeDeliveredNotifications(withIdentifiers: [Self.brewPromptId])
      result(true)
    case "markBrewPromptSession", "returnToLockAfterBrew", "isKeyguardLocked":
      result(false)  // an app cannot read or set the iOS lock state
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func showBrewWeightPrompt(
    title: String, body: String, result: @escaping FlutterResult
  ) {
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound]) { granted, error in
      guard granted else {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "denied", message: error?.localizedDescription ?? "notifications off",
            details: nil))
        }
        return
      }
      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      content.sound = .default
      let request = UNNotificationRequest(
        identifier: Self.brewPromptId, content: content, trigger: nil)
      center.add(request) { addError in
        DispatchQueue.main.async {
          if let addError = addError {
            result(FlutterError(
              code: "add_failed", message: addError.localizedDescription, details: nil))
          } else {
            result(true)
          }
        }
      }
    }
  }
}
