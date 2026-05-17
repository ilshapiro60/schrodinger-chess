import Flutter
import UIKit
import GoogleSignIn

/// OAuth URL handling when the app uses the classic UIApplication lifecycle (no UIScene manifest).
/// Kept for builds that still route URLs through a scene delegate; AppDelegate is the primary handler.
class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    for context in URLContexts {
      _ = GIDSignIn.sharedInstance.handle(context.url)
    }
  }
}
