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
            case "downloadsGet":
                WatchPhoneDownloads.shared.snapshot(result)
            case "downloadsSend":
                WatchPhoneDownloads.shared.send(call.arguments as? [String: Any] ?? [:], result: result)
            case "downloadsRemove":
                WatchPhoneDownloads.shared.remove(call.arguments as? [String: Any] ?? [:], result: result)
            case "acknowledgeSessions":
                let args = call.arguments as? [String: Any] ?? [:]
                let keys = Set(args["keys"] as? [String] ?? [])
                let pending = self.takePendingSessions().filter {
                    !keys.contains("\($0["trackId"] ?? "")|\($0["timestamp"] ?? "")")
                }
                UserDefaults.standard.set(pending, forKey: self.pendingKey)
                result(true)
            case "takePendingSessions":
                result(self.takePendingSessions())
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        self.channel = channel
        FlutterEventChannel(name: "medito.app/watch/downloads", binaryMessenger: messenger)
            .setStreamHandler(WatchPhoneDownloads.shared)
    }

    private func updateContext(_ context: [String: Any]) -> Bool {
        if context["signedOut"] as? Bool == true { WatchPhoneDownloads.shared.clear() }
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
        return pending
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { WatchPhoneDownloads.shared.changed() }
    }
    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async { WatchPhoneDownloads.shared.changed() }
    }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate after the user switches watches.
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        if userInfo["type"] as? String == "downloadStatus" {
            DispatchQueue.main.async { WatchPhoneDownloads.shared.receive(userInfo) }
        } else {
            enqueue(userInfo)
        }
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

    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        DispatchQueue.main.async { WatchPhoneDownloads.shared.finished(fileTransfer, error: error) }
    }

    private func enqueue(_ payload: [String: Any]) {
        guard payload["type"] as? String == "sessionCompleted" else { return }
        DispatchQueue.main.async {
            let defaults = UserDefaults.standard
            // A live message whose reply was lost is retried as a userInfo
            // transfer; remember recent sessions so it isn't recorded twice.
            let key = "\(payload["trackId"] ?? "")|\(payload["timestamp"] ?? "")"
            var seen = defaults.stringArray(forKey: self.seenKey) ?? []
            let queued = defaults.array(forKey: self.pendingKey) as? [[String: Any]] ?? []
            if !seen.contains(key) && !queued.contains(where: {
                "\($0["trackId"] ?? "")|\($0["timestamp"] ?? "")" == key
            }) {
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

/// The phone persists intentions and only marks a download ready on a watch acknowledgement.
final class WatchPhoneDownloads: NSObject, FlutterStreamHandler {
    static let shared = WatchPhoneDownloads()

    private let key = "watch_downloads_v1"
    private var sink: FlutterEventSink?
    private var progressObservations: [String: NSKeyValueObservation] = [:]
    private var lastProgressUpdate = Date.distantPast

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        if WCSession.isSupported() {
            WCSession.default.outstandingFileTransfers.forEach(observe)
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        progressObservations.removeAll()
        sink = nil
        return nil
    }

    private func observe(_ transfer: WCSessionFileTransfer) {
        guard sink != nil, let id = transfer.file.metadata?["requestId"] as? String else { return }
        progressObservations[id] = transfer.progress.observe(\.fractionCompleted, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                guard let self, Date().timeIntervalSince(self.lastProgressUpdate) >= 0.5 else { return }
                self.lastProgressUpdate = Date()
                self.changed()
            }
        }
    }

    func changed() { sink?(nil) }

    private var items: [[String: Any]] {
        get { UserDefaults.standard.array(forKey: key) as? [[String: Any]] ?? [] }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
            changed()
        }
    }

    private var cancelled: [String] {
        get { UserDefaults.standard.stringArray(forKey: "watch_cancelled_requests") ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "watch_cancelled_requests") }
    }

    private var available: Bool {
        WCSession.isSupported() && WCSession.default.activationState == .activated &&
        WCSession.default.isPaired && WCSession.default.isWatchAppInstalled
    }

    func snapshot(_ result: @escaping FlutterResult) {
        guard available, WCSession.default.isReachable else {
            result(snapshotValue())
            return
        }
        var resolved = false
        let resolve: ([String: Any]?) -> Void = { payload in
            guard !resolved else { return }
            resolved = true
            for var entry in payload?["items"] as? [[String: Any]] ?? [] {
                if self.cancelled.contains(entry["requestId"] as? String ?? "") { continue }
                entry["state"] = "ready"
                let current = self.items.first { $0["fileId"] as? String == entry["fileId"] as? String }
                if current == nil ||
                    (current?["requestId"] as? String == entry["requestId"] as? String &&
                     current?["state"] as? String != "removing") {
                    self.put(entry, notify: false)
                }
            }
            result(self.snapshotValue())
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { resolve(nil) }
        WCSession.default.sendMessage(["type": "downloadsInventory"], replyHandler: { payload in
            DispatchQueue.main.async { resolve(payload) }
        }, errorHandler: { _ in DispatchQueue.main.async { resolve(nil) } })
    }

    private func snapshotValue() -> [String: Any] {
        var list = items
        for transfer in WCSession.default.outstandingFileTransfers {
            guard let id = transfer.file.metadata?["requestId"] as? String,
                  let index = list.firstIndex(where: { $0["requestId"] as? String == id }),
                  list[index]["state"] as? String != "removing" else { continue }
            let progress = transfer.progress.fractionCompleted
            list[index]["state"] = progress > 0 ? "sending" : "queued"
            list[index]["progress"] = progress
        }
        #if targetEnvironment(simulator)
        for index in list.indices where ["queued", "sending"].contains(list[index]["state"] as? String ?? "") {
            list[index]["state"] = "failed"
            list[index]["error"] = "simulator_transfer_unavailable"
        }
        #endif
        return ["available": available, "items": list]
    }

    func send(_ payload: [String: Any], result: @escaping FlutterResult) {
        #if targetEnvironment(simulator)
        result(FlutterError(code: "simulator_transfer_unavailable", message: nil, details: nil))
        return
        #else
        guard available else {
            result(FlutterError(code: "watch_unavailable", message: nil, details: nil))
            return
        }
        guard let fileId = payload["fileId"] as? String,
              let path = payload["path"] as? String,
              FileManager.default.fileExists(atPath: path) else {
            result(FlutterError(code: "missing_download", message: nil, details: nil))
            return
        }
        if let existing = items.first(where: { $0["fileId"] as? String == fileId }),
           ["ready", "queued", "sending"].contains(existing["state"] as? String ?? "") {
            result(nil)
            return
        }
        let queue = {
            guard self.available, WCSession.default.applicationContext["signedOut"] as? Bool != true else {
                result(FlutterError(code: "watch_unavailable", message: nil, details: nil))
                return
            }
            if self.items.contains(where: {
                $0["fileId"] as? String == fileId &&
                    ["ready", "queued", "sending"].contains($0["state"] as? String ?? "")
            }) {
                result(nil)
                return
            }
            do {
                let request = UUID().uuidString
                let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("WatchOutgoing")
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let staged = directory.appendingPathComponent(request)
                    .appendingPathExtension(URL(fileURLWithPath: path).pathExtension)
                try FileManager.default.copyItem(at: URL(fileURLWithPath: path), to: staged)
                var entry = payload
                entry.removeValue(forKey: "path")
                entry["requestId"] = request
                entry["state"] = "queued"
                entry["stagedPath"] = staged.path
                self.put(entry)
                var metadata = entry
                metadata.removeValue(forKey: "stagedPath")
                self.observe(WCSession.default.transferFile(staged, metadata: metadata))
                result(nil)
            } catch {
                result(FlutterError(code: "transfer_failed", message: error.localizedDescription, details: nil))
            }
        }
        if WCSession.default.isReachable {
            var resolved = false
            let resolve: ([String: Any]?) -> Void = { status in
                guard !resolved else { return }
                resolved = true
                if let free = (status?["freeBytes"] as? NSNumber)?.int64Value {
                    let bytes = (payload["bytes"] as? NSNumber)?.int64Value ?? 0
                    let reserved = self.items.filter { ["queued", "sending"].contains($0["state"] as? String ?? "") }
                        .reduce(Int64(0)) { $0 + (($1["bytes"] as? NSNumber)?.int64Value ?? 0) }
                    if free < (bytes + reserved) * 2 + 1_048_576 {
                        result(FlutterError(code: "storage_full", message: nil, details: nil))
                        return
                    }
                }
                queue()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { resolve(nil) }
            WCSession.default.sendMessage(["type": "downloadsInventory"], replyHandler: { status in
                DispatchQueue.main.async { resolve(status) }
            }, errorHandler: { _ in DispatchQueue.main.async { resolve(nil) } })
        } else {
            queue()
        }
        #endif
    }

    func remove(_ payload: [String: Any], result: @escaping FlutterResult) {
        guard available,
              let id = payload["fileId"] as? String,
              var entry = items.first(where: { $0["fileId"] as? String == id }) else {
            result(FlutterError(code: "watch_unavailable", message: nil, details: nil))
            return
        }
        for transfer in WCSession.default.outstandingFileTransfers
        where transfer.file.metadata?["requestId"] as? String == entry["requestId"] as? String {
            transfer.cancel()
        }
        cancelled = cancelled + [entry["requestId"] as? String ?? ""]
        #if targetEnvironment(simulator)
        cleanup(entry)
        items = items.filter { $0["fileId"] as? String != id }
        result(nil)
        return
        #else
        entry["state"] = "removing"
        put(entry)
        WCSession.default.transferUserInfo([
            "type": "downloadRemove",
            "fileId": id,
            "requestId": entry["requestId"] ?? "",
        ])
        result(nil)
        #endif
    }

    func clear() {
        let previous = items
        cancelled = cancelled + previous.compactMap { $0["requestId"] as? String }
        for transfer in WCSession.default.outstandingFileTransfers { transfer.cancel() }
        if available {
            for entry in previous {
                WCSession.default.transferUserInfo([
                    "type": "downloadRemove",
                    "fileId": entry["fileId"] ?? "",
                    "requestId": entry["requestId"] ?? "",
                ])
            }
        }
        previous.forEach(cleanup)
        items = []
    }

    func receive(_ payload: [String: Any]) {
        guard let id = payload["fileId"] as? String,
              let current = items.first(where: { $0["fileId"] as? String == id }),
              current["requestId"] as? String == payload["requestId"] as? String else { return }
        if payload["state"] as? String == "removed" {
            cleanup(current)
            items = items.filter { $0["fileId"] as? String != id }
        } else if current["state"] as? String != "removing" {
            var entry = current
            entry["state"] = payload["state"]
            entry["error"] = payload["error"]
            cleanup(entry)
            entry.removeValue(forKey: "stagedPath")
            put(entry)
        }
    }

    func finished(_ transfer: WCSessionFileTransfer, error: Error?) {
        guard let metadata = transfer.file.metadata else { return }
        if let id = metadata["requestId"] as? String { progressObservations.removeValue(forKey: id) }
        changed()
        if let error {
            receive([
                "fileId": metadata["fileId"] ?? "",
                "requestId": metadata["requestId"] ?? "",
                "state": "failed",
                "error": error.localizedDescription,
            ])
        }
        // A successful transport still waits for the watch to save and acknowledge it.
        try? FileManager.default.removeItem(at: transfer.file.fileURL)
    }

    private func cleanup(_ entry: [String: Any]) {
        if let path = entry["stagedPath"] as? String {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    private func put(_ entry: [String: Any], notify: Bool = true) {
        var all = items
        if let index = all.firstIndex(where: { $0["fileId"] as? String == entry["fileId"] as? String }) {
            all[index] = entry
        } else {
            all.append(entry)
        }
        if notify {
            items = all
        } else {
            UserDefaults.standard.set(all, forKey: key)
        }
    }
}
