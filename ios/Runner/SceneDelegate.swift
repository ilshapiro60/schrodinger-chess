import Flutter
import UIKit
import GoogleSignIn

class SceneDelegate: FlutterSceneDelegate {
  /// UIScene apps must forward OAuth URLs to Google Sign-In (Safari / ASWebAuthenticationSession return).
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    for context in URLContexts {
      _ = GIDSignIn.sharedInstance.handle(context.url)
    }
  }
}
