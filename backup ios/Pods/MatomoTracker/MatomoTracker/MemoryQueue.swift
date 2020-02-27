import Foundation

/// The MemoryQueue is a **not thread safe** in memory Queue.
public final class MemoryQueue: NSObject, Queue {
    private var items = [Event]()
    
    public var eventCount: Int {
        return items.count
    }
    
    public func enqueue(events: [Event], completion: (()->())?) {
        assertMainThread()
        items.append(contentsOf: events)
        completion?()
    }
    
    public func first(limit: Int, completion: (_ items: [Event])->()) {
        assertMainThread()
        let amount = [limit,eventCount].min()!
        let dequeuedItems = Array(items[0..<amount])
        completion(dequeuedItems)
    }
    
    public func remove(events: [Event], completion: ()->()) {
        assertMainThread()
        items = items.filter({ event in !events.contains(where: { eventToRemove in eventToRemove.uuid == event.uuid })})
        completion()
    }
}
