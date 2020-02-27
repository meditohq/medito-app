import Foundation

struct Session: Codable {
    /// The number of sessions of the current user.
    /// api-key: _idvc
    let sessionsCount: Int
    
    /// The timestamp of the previous visit.
    /// Discussion: Should this be now for the first request?
    /// api-key: _viewts
    let lastVisit: Date
    
    /// The timestamp of the fist visit.
    /// Discussion: Should this be now for the first request?
    /// api-key: _idts
    let firstVisit: Date
}

extension Session {
    static func current(in matomoUserDefaults: MatomoUserDefaults) -> Session {
        let firstVisit: Date
        var matomoUserDefaults = matomoUserDefaults
        if let existingFirstVisit = matomoUserDefaults.firstVisit {
            firstVisit = existingFirstVisit
        } else {
            firstVisit = Date()
            matomoUserDefaults.firstVisit = firstVisit
        }
        let sessionCount = matomoUserDefaults.totalNumberOfVisits
        let lastVisit = matomoUserDefaults.previousVisit ?? Date()
        return Session(sessionsCount: sessionCount, lastVisit: lastVisit, firstVisit: firstVisit)
    }
}
