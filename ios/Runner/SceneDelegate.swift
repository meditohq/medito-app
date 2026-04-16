import Flutter
import UIKit
import app_links

@available(iOS 13.0, *)
class SceneDelegate: FlutterSceneDelegate {

    override func scene(
        _ scene: UIScene,
        continue userActivity: NSUserActivity
    ) {
        #if DEBUG
        print("[DEEPLINK] Handling user activity: \(userActivity.activityType)")
        print("[DEEPLINK] User info: \(String(describing: userActivity.userInfo))")
        #endif

        if let url = userActivity.userInfo?["url"] as? String,
           let uri = URL(string: url) {
            #if DEBUG
            print("[DEEPLINK] Converting Siri shortcut to deep link: \(url)")
            #endif
            AppLinks.shared.handleLink(url: uri)
        }

        super.scene(scene, continue: userActivity)
    }
}
