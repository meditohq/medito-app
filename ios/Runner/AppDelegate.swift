import Flutter
import SwiftUI
import UIKit
import Firebase
import home_widget
import workmanager
import app_links

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        configureInvocableNativeViews()
        
        // Initialize Firebase
        FirebaseApp.configure()
        
        // Register Flutter plugins
        GeneratedPluginRegistrant.register(with: self)
        
        // Set background fetch interval
        UIApplication.shared.setMinimumBackgroundFetchInterval(TimeInterval(60 * 15)) // 15 minutes
        
        // Set up Workmanager callback
        // WorkmanagerPlugin.setPluginRegistrantCallback { registry in
        //   GeneratedPluginRegistrant.register(with: registry)
        // }
        
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
    
    private func configureInvocableNativeViews() {
        configureRevenueCatDebugView()
    }
    
    private func configureRevenueCatDebugView() {
        let controller = window?.rootViewController as! FlutterViewController
        let channel = FlutterMethodChannel(name: "revenue_cat_debug_view",
                                           binaryMessenger: controller.binaryMessenger)
        
        channel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { return }
            
            if call.method == "showRevenueCatNativeDebugView" {
                let swiftUIView = RevenueCatDebugView()
                let hostingController = UIHostingController(rootView: swiftUIView)
                controller.present(hostingController, animated: true)
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }
}
