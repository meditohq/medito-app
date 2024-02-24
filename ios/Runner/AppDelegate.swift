import UIKit
import FirebaseCore
import Flutter
import flutter_local_notifications
import workmanager

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        setupFirebase()
        setupNotifications()
        setupFlutterPlugins()
        setupCustionAudioService()
        setupBackgroundTasks()
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    private func setupFirebase() {
        FirebaseApp.configure()
    }
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().delegate = self
    }
    
    private func setupCustionAudioService() {
        if let controller = window?.rootViewController as? FlutterViewController {
            SetUpMeditoAudioServiceApi(controller.binaryMessenger, AudioService())
        }
    }
    
    private func setupFlutterPlugins() {
        GeneratedPluginRegistrant.register(with: self)
        setupFlutterLocalNotificationsPlugin()
        setupFlutterWorkManagerPlugin()
    }
    
    private func setupFlutterLocalNotificationsPlugin() {
        FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
            GeneratedPluginRegistrant.register(with: registry)
        }
    }
    
    private func setupFlutterWorkManagerPlugin() {
        WorkmanagerPlugin.registerTask(withIdentifier: "org.meditofoundation")
        WorkmanagerPlugin.setPluginRegistrantCallback { registry in
            guard let registrar = registry.registrar(forPlugin: "com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin") else { 
                print("FlutterLocalNotificationsPlugin not found")
                return
            }
            
            FlutterLocalNotificationsPlugin.register(with: registrar)
        }
    }

    private func setupBackgroundTasks() {
        UIApplication.shared.setMinimumBackgroundFetchInterval(TimeInterval(60*15))
    }
}
