import UIKit
import Flutter
import Firebase
import app_links
import workmanager

@main
class AppDelegate: FlutterAppDelegate {
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FirebaseApp.configure()
        
        GeneratedPluginRegistrant.register(with: self)
        WorkmanagerPlugin.setPluginRegistrantCallback { registry in
            GeneratedPluginRegistrant.register(with: registry)
        }

        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
        }

        // Retrieve the link from parameters
        if let url = AppLinks.shared.getLink(launchOptions: launchOptions) {
            AppLinks.shared.handleLink(url: url)
            return true
        }
                
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}