import Foundation
import zlib
import WatchConnectivity

/// One playable session, resolved on the iPhone (guide + duration already
/// picked from the user's preferences) so the watch only has to stream it.
struct WatchTrack: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let audioUrl: String
    let fileId: String
    let durationMs: Int
    let guide: String
    /// Set when this is a favourited pack's next session.
    let packTitle: String

    init?(_ dict: [String: Any]) {
        guard
            let id = dict["id"] as? String, !id.isEmpty,
            let title = dict["title"] as? String,
            let audioUrl = dict["audioUrl"] as? String, !audioUrl.isEmpty
        else { return nil }
        self.id = id
        self.title = title
        self.subtitle = dict["subtitle"] as? String ?? ""
        self.audioUrl = audioUrl
        self.fileId = dict["fileId"] as? String ?? ""
        self.durationMs = dict["durationMs"] as? Int ?? 0
        self.guide = dict["guide"] as? String ?? ""
        self.packTitle = dict["packTitle"] as? String ?? ""
    }

    /// A pack's next session can also be favourited on its own.
    var rowKey: String { packTitle.isEmpty ? id : "pack|\(packTitle)|\(id)" }

    var minutes: Int { max(1, Int((Double(durationMs) / 60000).rounded())) }
}

struct UpNext: Equatable {
    let track: WatchTrack
    let packTitle: String
    /// Small resized pack cover (the phone hero's image).
    let coverUrl: String
    let completed: Int
    let total: Int
    var canPlay: Bool = true
}

/// Holds what the iPhone last sent (Up Next, favourites, streak) and sends
/// finished sessions back so they count towards stats and the streak.
///
/// The iPhone pushes with `updateApplicationContext`, which WatchConnectivity
/// persists — `receivedApplicationContext` restores it on launch, so the list
/// is there even when the phone is out of range.
final class WatchStore: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchStore()

    @Published private(set) var upNext: UpNext?
    /// "Your Daily": a different track each day, resolved on the phone.
    @Published private(set) var daily: WatchTrack?
    @Published private(set) var favorites: [WatchTrack] = []
    @Published private(set) var streak: Int = 0
    /// 0–100, the same number as the phone's Home stat circle.
    @Published private(set) var consistency: Int?
    /// The user ticked "Always show streak on homepage" on the phone.
    @Published private(set) var showStreak = false
    @Published private(set) var hasSynced = false
    @Published private(set) var downloads: [WatchTrack] = []

    private let defaults = UserDefaults.standard
    private let contextKey = "watch_progress_context_v2"
    private let pendingKey = "watch_progress_pending_v2"
    private let downloadEntriesKey = "watch_download_entries"
    private let cancelledDownloadsKey = "watch_cancelled_downloads"
    private var context: [String: Any] = [:]
    private var pending: [[String: Any]] = []
    private var downloadEntries: [[String: Any]] = []
    private var cancelledDownloads: [String] = []

    private override init() {
        super.init()
        context = defaults.dictionary(forKey: contextKey) ?? [:]
        pending = defaults.array(forKey: pendingKey) as? [[String: Any]] ?? []
        downloadEntries = defaults.array(forKey: downloadEntriesKey) as? [[String: Any]] ?? []
        cancelledDownloads = defaults.stringArray(forKey: cancelledDownloadsKey) ?? []
        refreshDownloads()
        render()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Sends a completed session to the iPhone so it counts towards stats.
    /// A live message when the phone is reachable (recorded straight away);
    /// otherwise — or if that fails — `transferUserInfo`, which the system
    /// delivers in the background whenever the phone is next reachable.
    func reportCompleted(_ track: WatchTrack, endedAt: Date = Date()) {
        var payload: [String: Any] = [
            "type": "sessionCompleted",
            "accountId": context["accountId"] as? String ?? "",
            "trackId": track.id,
            "fileId": track.fileId,
            "guide": track.guide,
            "duration": track.durationMs,
            "timestamp": Int(endedAt.timeIntervalSince1970 * 1000),
        ]
        // Freeze the midnight normalization at completion, before travel or a
        // timezone change can reinterpret it differently on the phone.
        payload["statsTimestamp"] = WatchProgress.recordedTimestamp(payload)
        pending.append(payload)
        defaults.set(pending, forKey: pendingKey)
        render()
        send(payload)
    }

    private func send(_ payload: [String: Any]) {
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        // Always queue a background transfer; a live message is an optional
        // fast path. Only a stats snapshot acknowledges recording, not delivery.
        let key = WatchProgress.deliveryKey(payload)
        if !session.outstandingUserInfoTransfers.contains(where: {
            WatchProgress.deliveryKey($0.userInfo) == key
        }) { session.transferUserInfo(payload) }
        if session.isReachable {
            session.sendMessage(payload, replyHandler: { _ in }, errorHandler: nil)
        }
    }

    /// Recompute date-sensitive stats when the watch becomes active again.
    func refresh() {
        render()
        resendPending()
        requestContext()
    }

    private func resendPending() {
        for payload in pending { send(payload) }
    }

    private func apply(_ incoming: [String: Any]) {
        guard !incoming.isEmpty else { return }
        DispatchQueue.main.async {
            if let sent = incoming["sentAt"] as? Int,
               let previous = self.context["sentAt"] as? Int, sent < previous { return }
            let oldAccount = self.context["accountId"] as? String ?? ""
            let newAccount = incoming["accountId"] as? String ?? ""
            if incoming["signedOut"] as? Bool == true ||
                (!oldAccount.isEmpty && oldAccount != newAccount) {
                self.pending = []
                self.clearDownloads()
            }
            self.context = incoming
            let recorded = WatchProgress.recordedKeys(incoming)
            self.pending.removeAll { recorded.contains(WatchProgress.recordKey($0)) }
            self.defaults.set(self.pending, forKey: self.pendingKey)
            self.defaults.set(incoming, forKey: self.contextKey)
            self.render()
            self.resendPending()
        }
    }

    private func render() {
        let context = WatchProgress.project(context, pending: pending)
        guard !context.isEmpty else { return }
        if context["signedOut"] as? Bool == true {
            // Signed out on the phone: show nothing from that account.
            DispatchQueue.main.async {
                self.upNext = nil
                self.daily = nil
                self.favorites = []
                self.clearDownloads()
                self.streak = 0
                self.consistency = nil
                self.showStreak = false
                self.hasSynced = false
            }
            return
        }
        let upNext: UpNext? = (context["upNext"] as? [String: Any]).flatMap { dict in
            WatchTrack(dict).map {
                UpNext(
                    track: $0,
                    packTitle: dict["packTitle"] as? String ?? "",
                    coverUrl: dict["coverUrl"] as? String ?? "",
                    completed: dict["completed"] as? Int ?? 0,
                    total: dict["total"] as? Int ?? 0,
                    canPlay: dict["canPlay"] as? Bool ?? true
                )
            }
        }
        let daily = (context["daily"] as? [String: Any]).flatMap(WatchTrack.init)
        let favorites = (context["favorites"] as? [[String: Any]] ?? []).compactMap(WatchTrack.init)
        let streak = context["streak"] as? Int ?? 0
        let consistency = context["consistency"] as? Int
        let showStreak = context["showStreak"] as? Bool ?? false

        DispatchQueue.main.async {
            self.upNext = upNext
            self.daily = daily
            self.favorites = favorites
            self.streak = streak
            self.consistency = consistency
            self.showStreak = showStreak
            self.hasSynced = true
        }
    }

    private var downloadDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads")
    }

    func localURL(_ track: WatchTrack) -> URL? {
        guard let entry = downloadEntries.first(where: { $0["fileId"] as? String == track.fileId }),
              let name = entry["localName"] as? String else { return nil }
        let url = downloadDirectory.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func refreshDownloads() {
        downloads = downloadEntries.compactMap { entry in
            guard let track = WatchTrack(entry), localURL(track) != nil else { return nil }
            return track
        }
    }

    private func saveDownloads() {
        defaults.set(downloadEntries, forKey: downloadEntriesKey)
        defaults.set(cancelledDownloads, forKey: cancelledDownloadsKey)
        refreshDownloads()
    }

    func removeDownload(_ track: WatchTrack) {
        guard let entry = downloadEntries.first(where: { $0["fileId"] as? String == track.fileId }) else { return }
        removeDownload(entry)
    }

    private func removeDownload(_ entry: [String: Any]) {
        if let request = entry["requestId"] as? String, !cancelledDownloads.contains(request) {
            cancelledDownloads.append(request)
        }
        if let existing = downloadEntries.first(where: {
            $0["requestId"] as? String == entry["requestId"] as? String
        }), let name = existing["localName"] as? String {
            try? FileManager.default.removeItem(at: downloadDirectory.appendingPathComponent(name))
            downloadEntries.removeAll { $0["requestId"] as? String == entry["requestId"] as? String }
        }
        saveDownloads()
        acknowledgeDownload(entry, state: "removed")
    }

    private func clearDownloads() {
        for entry in downloadEntries { removeDownload(entry) }
    }

    private func acknowledgeDownload(_ entry: [String: Any], state: String, error: String? = nil) {
        var payload: [String: Any] = [
            "type": "downloadStatus",
            "fileId": entry["fileId"] ?? "",
            "requestId": entry["requestId"] ?? "",
            "state": state,
        ]
        if let error { payload["error"] = error }
        WCSession.default.transferUserInfo(payload)
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        let received = session.receivedApplicationContext
        apply(received)
        if received.isEmpty { requestContext() }
        DispatchQueue.main.async { self.resendPending() }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        if !hasSynced { requestContext() }
        DispatchQueue.main.async { self.resendPending() }
    }

    /// Asks the phone for its current context. Needed after a (re)install:
    /// updateApplicationContext skips a context identical to the last one
    /// sent, so the phone wouldn't otherwise resend. Messaging the phone
    /// wakes the Medito app in the background if it isn't running.
    private func requestContext() {
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return }
        session.sendMessage(["type": "requestContext"], replyHandler: { [weak self] context in
            self?.apply(context)
        }, errorHandler: nil)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        if userInfo["type"] as? String == "downloadRemove" {
            DispatchQueue.main.async { self.removeDownload(userInfo) }
        }
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard message["type"] as? String == "downloadsInventory" else {
            replyHandler([:])
            return
        }
        DispatchQueue.main.async {
            let free = (try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
            replyHandler(["items": self.downloadEntries, "freeBytes": free])
        }
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // WCSession deletes the temporary file on return, so save it synchronously.
        DispatchQueue.main.sync {
            guard var entry = file.metadata,
                  let request = entry["requestId"] as? String,
                  UUID(uuidString: request) != nil,
                  WatchTrack(entry) != nil else { return }
            if context["signedOut"] as? Bool == true {
                acknowledgeDownload(entry, state: "removed")
                return
            }
            if cancelledDownloads.contains(request) {
                acknowledgeDownload(entry, state: "removed")
                return
            }
            do {
                let bytes = (entry["bytes"] as? NSNumber)?.int64Value ?? 0
                let free = (try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
                guard free > bytes + 1_048_576 else {
                    acknowledgeDownload(entry, state: "failed", error: "storage_full")
                    return
                }
                let received = (try FileManager.default.attributesOfItem(atPath: file.fileURL.path)[.size] as? NSNumber)?.int64Value ?? -1
                guard received == bytes else {
                    acknowledgeDownload(entry, state: "failed", error: "incomplete_file")
                    return
                }
                try FileManager.default.createDirectory(at: downloadDirectory, withIntermediateDirectories: true)
                let name = request + "." + file.fileURL.pathExtension
                let destination = downloadDirectory.appendingPathComponent(name)
                if !FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.copyItem(at: file.fileURL, to: destination)
                }
                if let old = downloadEntries.first(where: { $0["fileId"] as? String == entry["fileId"] as? String }),
                   let oldName = old["localName"] as? String, oldName != name {
                    try? FileManager.default.removeItem(at: downloadDirectory.appendingPathComponent(oldName))
                }
                entry["localName"] = name
                downloadEntries.removeAll { $0["fileId"] as? String == entry["fileId"] as? String }
                downloadEntries.append(entry)
                saveDownloads()
                acknowledgeDownload(entry, state: "ready")
            } catch {
                acknowledgeDownload(entry, state: "failed", error: "save_failed")
            }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        apply(context)
    }
}

/// Pure projection: authoritative phone snapshot plus durable local outbox.
/// Keep day bucketing in parity with StatsManager / AudioCompletionTracker.
enum WatchProgress {
    /// Dart sends gzip + base64 so a long history still fits a small WC payload.
    /// The array form is accepted for fixtures / older snapshots.
    static func recordedKeys(_ snapshot: [String: Any]) -> Set<String> {
        if let keys = snapshot["recordedSessions"] as? [String] { return Set(keys) }
        guard let encoded = snapshot["recordedSessionsGzip"] as? String,
              let compressed = Data(base64Encoded: encoded), compressed.count >= 18 else { return [] }
        // Gzip ISIZE is the little-endian uncompressed length in its footer.
        let size = compressed.suffix(4).enumerated().reduce(0) { $0 | (Int($1.element) << ($1.offset * 8)) }
        guard size > 0, size <= 16 * 1024 * 1024 else { return [] }
        var output = Data(count: size)
        var stream = z_stream()
        guard inflateInit2_(&stream, MAX_WBITS + 16, ZLIB_VERSION,
                            Int32(MemoryLayout<z_stream>.size)) == Z_OK else { return [] }
        defer { inflateEnd(&stream) }
        let status = compressed.withUnsafeBytes { input in
            output.withUnsafeMutableBytes { destination in
                stream.next_in = UnsafeMutablePointer(mutating: input.bindMemory(to: Bytef.self).baseAddress)
                stream.avail_in = uInt(compressed.count)
                stream.next_out = destination.bindMemory(to: Bytef.self).baseAddress
                stream.avail_out = uInt(size)
                return inflate(&stream, Z_FINISH)
            }
        }
        guard status == Z_STREAM_END,
              let keys = (try? JSONSerialization.jsonObject(with: output)) as? [String] else { return [] }
        return Set(keys)
    }

    static func deliveryKey(_ entry: [String: Any]) -> String {
        "\(entry["trackId"] as? String ?? "")|\(entry["timestamp"] as? Int ?? 0)"
    }

    static func recordedTimestamp(_ entry: [String: Any]) -> Int {
        if let normalized = entry["statsTimestamp"] as? Int { return normalized }
        let end = entry["timestamp"] as? Int ?? 0
        let start = end - (entry["duration"] as? Int ?? 0)
        let calendar = Calendar.current
        return calendar.startOfDay(for: Date(timeIntervalSince1970: Double(start) / 1000)) <
            calendar.startOfDay(for: Date(timeIntervalSince1970: Double(end) / 1000)) ? start : end
    }

    static func recordKey(_ entry: [String: Any]) -> String {
        "\(entry["trackId"] as? String ?? "")|\(recordedTimestamp(entry))"
    }

    static func project(_ snapshot: [String: Any], pending: [[String: Any]], now: Date = Date()) -> [String: Any] {
        if snapshot.isEmpty || snapshot["signedOut"] as? Bool == true { return snapshot }
        var result = snapshot
        let recorded = recordedKeys(snapshot)
        let outstanding = pending.filter { !recorded.contains(recordKey($0)) }
        if var pack = snapshot["upNext"] as? [String: Any],
           let ids = pack["packTrackIds"] as? [String] {
            var completed = Set(pack["completedTrackIds"] as? [String] ?? [])
            for entry in outstanding {
                if let id = entry["trackId"] as? String, ids.contains(id) { completed.insert(id) }
            }
            pack["completed"] = completed.count
            let remaining = pack["remainingTracks"] as? [[String: Any]] ?? []
            if let next = remaining.first(where: { !completed.contains($0["id"] as? String ?? "") }) {
                for (key, value) in next { pack[key] = value }
                pack["canPlay"] = true
            } else {
                // Preserve the progress card when the pack is finished or the
                // look-ahead is exhausted, without replaying its completed track.
                pack["canPlay"] = false
            }
            result["upNext"] = pack
        }
        if let timestamps = activityTimestamps(snapshot, recorded: recorded) {
            let offset = Double(snapshot["dayBoundaryOffsetMs"] as? Int ?? 0) / 1000
            let calendar = Calendar.current
            func day(_ date: Date) -> Date { calendar.startOfDay(for: date.addingTimeInterval(-offset)) }
            let today = day(now)
            let all = timestamps + outstanding.map(recordedTimestamp)
            let days = Set(all.map { day(Date(timeIntervalSince1970: Double($0) / 1000)) }.filter { $0 <= today })
            var streak = days.contains(today) ? 1 : 0
            var check = calendar.date(byAdding: .day, value: -1, to: today)!
            while days.contains(check) {
                streak += 1
                check = calendar.date(byAdding: .day, value: -1, to: check)!
            }
            result["streak"] = streak
            if snapshot["consistency"] != nil {
                let freezeTimestamps = snapshot["freezeTimestamps"] as? [Int] ?? []
                result["consistency"] = consistencyPercent(
                    meditationTimestamps: timestamps + outstanding.map(recordedTimestamp),
                    freezeTimestamps: freezeTimestamps,
                    today: today,
                    offset: offset,
                    calendar: calendar
                )
            }
        }
        return result
    }

    private static func activityTimestamps(_ snapshot: [String: Any], recorded: Set<String>) -> [Int]? {
        if let timestamps = snapshot["activityTimestamps"] as? [Int] { return timestamps }
        if snapshot["recordedSessions"] == nil && snapshot["recordedSessionsGzip"] == nil { return nil }
        return recorded.compactMap { Int($0.split(separator: "|").last ?? "") }
    }

    private static func consistencyPercent(
        meditationTimestamps: [Int],
        freezeTimestamps: [Int],
        today: Date,
        offset: TimeInterval,
        calendar: Calendar
    ) -> Int {
        func day(_ date: Date) -> Date { calendar.startOfDay(for: date.addingTimeInterval(-offset)) }
        let audioDays = Set(meditationTimestamps
            .map { day(Date(timeIntervalSince1970: Double($0) / 1000)) }
            .filter { $0 <= today })
        let freezeDays = Set(freezeTimestamps
            .map { day(Date(timeIntervalSince1970: Double($0) / 1000)) }
            .filter { $0 <= today && !audioDays.contains($0) })
        let days = (audioDays.union(freezeDays)).sorted()
        guard let first = days.first else { return 0 }
        let daysSinceFirst = calendar.dateComponents([.day], from: first, to: today).day! + 1
        if daysSinceFirst == 1 { return days.contains(today) ? 100 : 0 }
        if daysSinceFirst < 30 {
            return Int((Double(days.count) / Double(daysSinceFirst) * 100).rounded())
        }

        let alpha = 0.1
        let gracePenalty = 0.5
        let day29 = calendar.date(byAdding: .day, value: 28, to: first)!
        let activeAtDay29 = days.filter { $0 <= day29 }.count
        var ema = Double(activeAtDay29) / 29.0
        let daySet = Set(days)
        var current = calendar.date(byAdding: .day, value: 29, to: first)!
        while current <= today {
            let value: Double
            if daySet.contains(current) {
                value = 1.0
            } else {
                let previous = calendar.date(byAdding: .day, value: -1, to: current)!
                let next = calendar.date(byAdding: .day, value: 1, to: current)!
                let nextActive = next > today ? false : daySet.contains(next)
                value = (daySet.contains(previous) || nextActive) ? gracePenalty : 0.0
            }
            ema = alpha * value + (1 - alpha) * ema
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        return Int((min(max(ema, 0.0), 1.0) * 100).rounded())
    }
}
