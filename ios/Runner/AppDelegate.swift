
import Flutter
import UIKit


@objc class AppDelegate: FlutterAppDelegate {
  private let channelName = "lilly/model"
  private let unsupportedMessage =
    "Lilly Gemma 4 local inference is currently implemented for Android first. iOS integration is not wired yet."

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: channelName,
        binaryMessenger: controller.binaryMessenger
      )

      channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
          result(
            FlutterError(
              code: "UNAVAILABLE",
              message: "AppDelegate deallocated",
              details: nil
            )
          )
          return
        }

        switch call.method {
        case "initializeModel":
          result([
            "success": false,
            "status": "error",
            "errorMessage": self.unsupportedMessage
          ])

        case "getModelStatus":
          result([
            "status": "error",
            "errorMessage": self.unsupportedMessage
          ])

        case "disposeModel":
          result(nil)

        case "generateResponse":
          result([
            "success": false,
            "text": "",
            "errorMessage": self.unsupportedMessage
          ])

        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
