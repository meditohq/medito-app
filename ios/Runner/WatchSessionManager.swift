import Flutter
import Foundation
import WatchConnectivity

/// Bridges the Apple Watch app and Dart over `medito.app/watch`.
///
/// Dart → watch: `updateContext` pushes Up Next / favourites / streak with
/// `updateApplicationContext` (latest-wins, persisted by the system).
///
/// Watch → Dart: completed sessions arrive via `transferUserInfo`, possibly
/// while Flutter isn't running, so they are queued in UserDefaults until Dart
/// drains them with `takePendingSessions` (it is nudged with
/// `sessionsAvailable` when the channel is live).
final class WatchSessionManager: NSObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    private let pendingKey = "watch_pending_sessions"
    private let seenKey = "watch_seen_sessions"
    private var channel: FlutterMethodChannel?

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "medito.app/watch", binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else { return }
            switch call.method {
            case "updateContext":
                result(self.updateContext(call.arguments as? [String: Any] ?? [:]))
            case "takePendingSessions":
                result(self.takePendingSessions())
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        self.channel = channel
    }

    private func updateContext(_ context: [String: Any]) -> Bool {
        let session = WCSession.default
        guard WCSession.isSupported(), session.activationState == .activated,
              session.isPaired, session.isWatchAppInstalled
        else { return false }
        do {
            try session.updateApplicationContext(context)
            return true
        } catch {
            NSLog("[WATCH] updateApplicationContext failed: \(error)")
            return false
        }
    }

    private func takePendingSessions() -> [[String: Any]] {
        let defaults = UserDefaults.standard
        let pending = defaults.array(forKey: pendingKey) as? [[String: Any]] ?? []
        defaults.removeObject(forKey: pendingKey)
        return pending
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate after the user switches watches.
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        enqueue(userInfo)
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        if message["type"] as? String == "requestContext" {
            // A watch with nothing to show (fresh install / reinstall). The
            // system only delivers a context that differs from the last one
            // sent, so hand it the persisted one directly.
            replyHandler(session.applicationContext)
            return
        }
        enqueue(message)
        replyHandler(["ok": true])
    }

    private func enqueue(_ payload: [String: Any]) {
        guard payload["type"] as? String == "sessionCompleted" else { return }
        DispatchQueue.main.async {
            let defaults = UserDefaults.standard
            // A live message whose reply was lost is retried as a userInfo
            // transfer; remember recent sessions so it isn't recorded twice.
            let key = "\(payload["trackId"] ?? "")|\(payload["timestamp"] ?? "")"
            var seen = defaults.stringArray(forKey: self.seenKey) ?? []
            if !seen.contains(key) {
                seen = Array((seen + [key]).suffix(50))
                defaults.set(seen, forKey: self.seenKey)
                var pending = defaults.array(forKey: self.pendingKey) as? [[String: Any]] ?? []
                pending.append(payload)
                defaults.set(pending, forKey: self.pendingKey)
            }
            self.channel?.invokeMethod("sessionsAvailable", arguments: nil)
        }
    }
}
