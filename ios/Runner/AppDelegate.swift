import UIKit
import FirebaseCore
import Flutter
import flutter_local_notifications

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        setupFirebase()
        setupNotifications()
        setupFlutterPlugins()
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    private func setupFirebase() {
        FirebaseApp.configure()
    }
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().delegate = self
    }
    
    private func setupFlutterPlugins() {
        FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
            GeneratedPluginRegistrant.register(with: registry)
        }
        
        GeneratedPluginRegistrant.register(with: self)
    }
}
