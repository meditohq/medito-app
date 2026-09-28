import Foundation
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

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Sends a completed session to the iPhone so it counts towards stats.
    /// A live message when the phone is reachable (recorded straight away);
    /// otherwise — or if that fails — `transferUserInfo`, which the system
    /// delivers in the background whenever the phone is next reachable.
    func reportCompleted(_ track: WatchTrack, endedAt: Date = Date()) {
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        let payload: [String: Any] = [
            "type": "sessionCompleted",
            "trackId": track.id,
            "fileId": track.fileId,
            "guide": track.guide,
            "duration": track.durationMs,
            "timestamp": Int(endedAt.timeIntervalSince1970 * 1000),
        ]
        guard session.isReachable else {
            session.transferUserInfo(payload)
            return
        }
        session.sendMessage(payload, replyHandler: { _ in }) { _ in
            session.transferUserInfo(payload)
        }
    }

    private func apply(_ context: [String: Any]) {
        guard !context.isEmpty else { return }
        if context["signedOut"] as? Bool == true {
            // Signed out on the phone: show nothing from that account.
            DispatchQueue.main.async {
                self.upNext = nil
                self.daily = nil
                self.favorites = []
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
                    total: dict["total"] as? Int ?? 0
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

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        let received = session.receivedApplicationContext
        apply(received)
        if received.isEmpty { requestContext() }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        if !hasSynced { requestContext() }
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

    func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        apply(context)
    }
}
