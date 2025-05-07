import Flutter
import UIKit
import Firebase
import home_widget
import workmanager
import app_links
import Intents
import IntentsUIA
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
    @objc class AppDelegate: FlutterAppDelegate {
        
        override func application(
            _ application: UIApplication,
            didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
        ) -> Bool {
            // Initialize Firebase
            FirebaseApp.configure()
            
            // Register Flutter plugins
            GeneratedPluginRegistrant.register(with: self)
            
            // Set background fetch interval
            UIApplication.shared.setMinimumBackgroundFetchInterval(TimeInterval(60 * 15)) // 15 minutes
            
            // Set up Workmanager callback
            WorkmanagerPlugin.setPluginRegistrantCallback { registry in
                GeneratedPluginRegistrant.register(with: registry)
            }
            
            // Set up HomeWidget callback for iOS 17+
            if #available(iOS 17, *) {
                HomeWidgetBackgroundWorker.setPluginRegistrantCallback { registry in
                    GeneratedPluginRegistrant.register(with: registry)
                }
            }
            
            // Set notification delegate for iOS 10+
            if #available(iOS 10.0, *) {
                UNUserNotificationCenter.current().delegate = self
            }
            
            // Handle app links if present
            if let url = AppLinks.shared.getLink(launchOptions: launchOptions) {
                AppLinks.shared.handleLink(url: url)
            }
            
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }
    }
}
