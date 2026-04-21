import Flutter
import UIKit
import Firebase
import app_links
import Intents
import IntentsUI
import AppTrackingTransparency
import FBSDKCoreKit

@main
class AppDelegate: FlutterAppDelegate {
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Initialize Firebase
        FirebaseApp.configure()
        
        // Initialize Facebook SDK
        ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )

        // Register Flutter plugins
        GeneratedPluginRegistrant.register(with: self)
        
        // Set background fetch interval
        UIApplication.shared.setMinimumBackgroundFetchInterval(TimeInterval(60 * 15)) // 15 minutes
        
        // Set notification delegate for iOS 10+
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
        }

        // Handle app links if present
        if let url = AppLinks.shared.getLink(launchOptions: launchOptions) {
            #if DEBUG
            print("[DEEPLINK] Got initial link: \(url)")
            #endif
            AppLinks.shared.handleLink(url: url)
            return true
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
    
    /// Registers method channels against a FlutterViewController's binary messenger.
    /// Called from SceneDelegate once the scene (and its FlutterViewController) is attached,
    /// because `self.window` is nil on the AppDelegate when using a UIScene lifecycle.
    func registerMethodChannels(with controller: FlutterViewController) {
        // Siri channel
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

        // Facebook SDK channel for iOS 14+ advertiser tracking
        let facebookChannel = FlutterMethodChannel(
            name: "com.medito.app/facebook",
            binaryMessenger: controller.binaryMessenger
        )

        facebookChannel.setMethodCallHandler { call, result in
            if call.method == "setAdvertiserTrackingEnabled" {
                if let enabled = call.arguments as? Bool {
                    Settings.shared.isAdvertiserTrackingEnabled = enabled
                    result(true)
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENT", message: "Expected Bool argument", details: nil))
                }
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
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

            if let controller = keyWindow()?.rootViewController {
                controller.present(viewController, animated: true, completion: nil)
            }
        }
    }

    private func keyWindow() -> UIWindow? {
        if let window = window { return window }
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })
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
