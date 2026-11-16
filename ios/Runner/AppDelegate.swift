import Flutter
import UIKit
import Firebase
import app_links
import Intents
import IntentsUI
import AppTrackingTransparency
import AdServices
import FBSDKCoreKit
import WatchConnectivity
import HealthKit

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

        // Apple Ads attribution token; Dart exchanges it with Apple's
        // AdServices API (see AppleAdsAttributionService). Needs no ATT consent.
        let adServicesChannel = FlutterMethodChannel(
            name: "com.medito.app/adservices",
            binaryMessenger: controller.binaryMessenger
        )

        adServicesChannel.setMethodCallHandler { call, result in
            guard call.method == "attributionToken" else {
                result(FlutterMethodNotImplemented)
                return
            }
            // attributionToken() can block, so keep it off the main thread.
            DispatchQueue.global(qos: .utility).async {
                do {
                    let token = try AAAttribution.attributionToken()
                    DispatchQueue.main.async { result(token) }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "token_failed", message: error.localizedDescription, details: nil))
                    }
                }
            }
        }

        WatchPresence.shared.register(with: controller.binaryMessenger)
        MindfulnessHealthWriter.shared.register(with: controller.binaryMessenger)
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

/// Writes mindfulness metadata that the health plugin cannot currently export.
/// Dart uses the plugin's existing authorization flow before calling this writer.
final class MindfulnessHealthWriter {
    static let shared = MindfulnessHealthWriter()
    private let healthStore = HKHealthStore()

    func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: "com.medito.app/health",
            binaryMessenger: messenger
        )
        channel.setMethodCallHandler { [self] call, result in
            guard call.method == "writeMindfulnessSession" else {
                result(FlutterMethodNotImplemented)
                return
            }
            guard HKHealthStore.isHealthDataAvailable() else {
                result(false)
                return
            }
            guard let arguments = call.arguments as? [String: Any],
                  let sample = Self.makeSample(arguments: arguments) else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid mindfulness session", details: nil))
                return
            }

            healthStore.save(sample) { success, error in
                DispatchQueue.main.async {
                    if let error = error {
                        result(FlutterError(code: "HEALTH_WRITE_FAILED", message: error.localizedDescription, details: nil))
                    } else {
                        result(success)
                    }
                }
            }
        }
    }

    static func makeSample(arguments: [String: Any]) -> HKCategorySample? {
        guard let startEpochMs = arguments["startEpochMs"] as? Int64,
              let endEpochMs = arguments["endEpochMs"] as? Int64,
              startEpochMs <= endEpochMs,
              let type = HKCategoryType.categoryType(forIdentifier: .mindfulSession) else {
            return nil
        }

        let title = (arguments["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        var metadata: [String: Any] = [
            "org.meditofoundation.title": title.flatMap { $0.isEmpty ? nil : $0 } ?? "Medito",
            HKMetadataKeyWasUserEntered: false,
            // HealthKit deduplicates samples with the same sync identifier/version.
            HKMetadataKeySyncIdentifier: "medito-\(endEpochMs)",
            HKMetadataKeySyncVersion: 1,
        ]
        for key in ["trackId", "fileId"] {
            if let value = arguments[key] as? String, !value.isEmpty {
                metadata["org.meditofoundation.\(key)"] = value
            }
        }

        return HKCategorySample(
            type: type,
            value: HKCategoryValue.notApplicable.rawValue,
            start: Date(timeIntervalSince1970: Double(startEpochMs) / 1000),
            end: Date(timeIntervalSince1970: Double(endEpochMs) / 1000),
            metadata: metadata
        )
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

/// Tells Dart whether an Apple Watch is paired (and whether the Medito watch
/// app is on it) so analytics can size the audience for a watch app.
///
/// Both flags are only valid once WCSession has activated. If nothing else
/// has claimed the session it activates it itself; if another delegate owns
/// it (the watch app's WatchSessionManager), it just waits for that
/// activation and reads the state.
final class WatchPresence: NSObject, WatchPresenceApi, WCSessionDelegate {
    static let shared = WatchPresence()
    private typealias Completion = (Result<WatchStatus, Error>) -> Void
    private var waiting: [Completion] = []

    func register(with messenger: FlutterBinaryMessenger) {
        WatchPresenceApiSetup.setUp(binaryMessenger: messenger, api: self)
    }

    func getStatus(completion: @escaping (Result<WatchStatus, Error>) -> Void) {
        guard WCSession.isSupported() else {
            return completion(.success(WatchStatus(paired: false, appInstalled: false)))
        }
        let session = WCSession.default
        if session.activationState == .activated { return completion(.success(snapshot(session))) }
        waiting.append(completion)
        if session.delegate == nil {
            session.delegate = self
            session.activate()
        } else {
            // Someone else activates it; read once they have.
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.flush() }
        }
    }

    private func snapshot(_ session: WCSession) -> WatchStatus {
        WatchStatus(paired: session.isPaired, appInstalled: session.isWatchAppInstalled)
    }

    private func flush() {
        let session = WCSession.default
        // If activation didn't succeed, report an error (Dart skips the update)
        // rather than a false "no watch" that would skew the audience count.
        let pending = waiting
        waiting.removeAll()
        let result: Result<WatchStatus, Error> = session.activationState == .activated
            ? .success(snapshot(session))
            : .failure(WatchPresencePigeonError(code: "activation_failed", message: "WCSession not activated", details: nil))
        pending.forEach { $0(result) }
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { self.flush() }
    }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}
