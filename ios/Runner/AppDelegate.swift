import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let channelName = "lilly/model"
  private var modelReady = false

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
          self.modelReady = true
          result(true)

        case "disposeModel":
          self.modelReady = false
          result(nil)

        case "generateResponse":
          guard self.modelReady else {
            result([
              "success": false,
              "text": "",
              "errorMessage": "Model is not initialized on iOS."
            ])
            return
          }

          guard let args = call.arguments as? [String: Any] else {
            result([
              "success": false,
              "text": "",
              "errorMessage": "Invalid arguments received."
            ])
            return
          }

          let prompt = (args["prompt"] as? String) ?? ""
          let imagePath = args["imagePath"] as? String
          let hasImage = !(imagePath?.isEmpty ?? true)

          let responseText: String
          if hasImage && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            responseText = "iOS native stub received image plus prompt: \"\(prompt)\". Replace this with Gemma 4 LiteRT inference."
          } else if hasImage {
            responseText = "iOS native stub received an image. Replace this with Gemma 4 LiteRT image inference."
          } else if !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            responseText = "iOS native stub reply for: \"\(prompt)\". Replace this with Gemma 4 LiteRT text inference."
          } else {
            responseText = "iOS native model is ready."
          }

          result([
            "success": true,
            "text": responseText,
            "errorMessage": NSNull()
          ])

        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
