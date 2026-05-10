import Flutter
import UIKit
import GoogleSignIn

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configure before any sign-in attempt (avoids crashes when presenting on iPad / scene-based apps).
    if let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
       !clientID.isEmpty {
      let serverID = Bundle.main.object(forInfoDictionaryKey: "GIDServerClientID") as? String
      GIDSignIn.sharedInstance.configuration = GIDConfiguration(
        clientID: clientID,
        serverClientID: serverID
      )
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Fallback URL handler when the OS delivers the OAuth callback to the app delegate.
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if GIDSignIn.sharedInstance.handle(url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
