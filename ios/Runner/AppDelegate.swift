import UIKit
import Flutter
import Firebase
import app_links
import Intents
import IntentsUI
import AppTrackingTransparency

@main
class AppDelegate: FlutterAppDelegate {
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FirebaseApp.configure()
        
        let controller = window?.rootViewController as! FlutterViewController
        let siriChannel = FlutterMethodChannel(
            name: "com.medito.app/siri",
            binaryMessenger: controller.binaryMessenger
        )
        
        siriChannel.setMethodCallHandler { [weak self] call, result in
            guard call.method == "donateShortcut" else {
                result(FlutterMethodNotImplemented)
                return
            }
            
            guard let args = call.arguments as? [String: Any],
                  let title = args["title"] as? String,
                  let id = args["id"] as? String,
                  let url = args["url"] as? String else {
                result(false)
                return
            }
            
            self?.presentAddVoiceShortcutUI(title: title, id: id, url: url)
            result(true)
        }
        
        GeneratedPluginRegistrant.register(with: self)

        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
        }

        // Retrieve the link from parameters
        if let url = AppLinks.shared.getLink(launchOptions: launchOptions) {
            #if DEBUG
            print("[DEEPLINK] Got initial link: \(url)")
            #endif
            AppLinks.shared.handleLink(url: url)
            return true
        }
        
        // Request tracking authorization after a delay to ensure it doesn't interfere with app launch
        if #available(iOS 14.5, *) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                ATTrackingManager.requestTrackingAuthorization { status in
                    // The status will be reported to the TikTok SDK automatically
                    print("ATT authorization status: \(status.rawValue)")
                }
            }
        }
                
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    override func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
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
        
        return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }
    
    private func presentAddVoiceShortcutUI(title: String, id: String, url: String) {
        let activity = NSUserActivity(activityType: "org.meditofoundation")
        activity.title = title
        activity.userInfo = ["url": url]
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        
        if #available(iOS 12.0, *) {
            activity.isEligibleForHandoff = true
            activity.suggestedInvocationPhrase = title
            
            let shortcut = INShortcut(userActivity: activity)
            let viewController = INUIAddVoiceShortcutViewController(shortcut: shortcut)
            viewController.delegate = self
            
            if let controller = window?.rootViewController {
                controller.present(viewController, animated: true, completion: nil)
            }
        }
    }
}

extension AppDelegate: INUIAddVoiceShortcutViewControllerDelegate {
    @available(iOS 12.0, *)
    func addVoiceShortcutViewController(_ controller: INUIAddVoiceShortcutViewController, didFinishWith voiceShortcut: INVoiceShortcut?, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
    
    @available(iOS 12.0, *)
    func addVoiceShortcutViewControllerDidCancel(_ controller: INUIAddVoiceShortcutViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
}
