import Foundation

public protocol Queue {
    
    var eventCount: Int { get }
    
    mutating func enqueue(events: [Event], completion: (()-> Void)?)
    
    /// Returns the first `limit` events ordered by Event.date
    func first(limit: Int, completion: @escaping (_ items: [Event]) -> Void)
    
    /// Removes the events from the queue
    mutating func remove(events: [Event], completion: @escaping () -> Void)
}

extension Queue {
    mutating func enqueue(event: Event, completion: (()->Void)? = nil) {
        enqueue(events: [event], completion: completion)
    }
}
