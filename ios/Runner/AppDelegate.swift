import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let controller = window?.rootViewController as! FlutterViewController
    let messenger = controller.binaryMessenger

    let storageChannel = FlutterMethodChannel(
      name: "horceracing_ticket_qr_reader/storage",
      binaryMessenger: messenger
    )
    storageChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard call.method == "getStorageDirectory" else {
        result(FlutterMethodNotImplemented)
        return
      }
      do {
        let path = try Self.applicationSupportPath()
        result(path)
      } catch {
        result(
          FlutterError(
            code: "STORAGE_UNAVAILABLE",
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    }

    let urlChannel = FlutterMethodChannel(
      name: "horceracing_ticket_qr_reader/url",
      binaryMessenger: messenger
    )
    urlChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard call.method == "launchUrl" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let args = call.arguments as? [String: Any],
        let urlString = args["url"] as? String,
        let url = URL(string: urlString)
      else {
        result(
          FlutterError(code: "INVALID_URL", message: "url is required", details: nil)
        )
        return
      }
      UIApplication.shared.open(url, options: [:]) { success in
        result(success)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Android の filesDir 相当。サンドボックス内の Application Support を返す。
  private static func applicationSupportPath() throws -> String {
    let urls = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    )
    guard let supportURL = urls.first else {
      throw NSError(
        domain: "horceracing_ticket_qr_reader",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Application Support directory is unavailable."]
      )
    }

    let appURL = supportURL.appendingPathComponent(
      "horceracing_ticket_qr_reader",
      isDirectory: true
    )
    try FileManager.default.createDirectory(
      at: appURL,
      withIntermediateDirectories: true
    )
    return appURL.path
  }
}
