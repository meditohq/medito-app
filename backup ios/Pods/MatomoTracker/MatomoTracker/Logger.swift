import Foundation

@objc public enum LogLevel: Int {
    case verbose = 10
    case debug = 20
    case info = 30
    case warning = 40
    case error = 50
    
    var shortcut: String {
        switch self {
        case .error: return "E"
        case .warning: return "W"
        case .info: return "I"
        case .debug: return "D"
        case .verbose: return "V"
        }
    }
}

/// The Logger protocol defines a common interface that is used to log every message from the sdk.
/// You can easily writer your own to perform custom logging.
@objc public protocol Logger {
    /// This method should perform the logging. It can be called from every thread. The implementation has
    /// to handle synchronizing different threads.
    ///
    /// - Parameters:
    ///   - message: A closure that produces the message itself.
    ///   - level: The loglevel of the message.
    ///   - file: The filename where the log was created.
    ///   - function: The funciton where the log was created.
    ///   - line: Then line where the log was created.
    func log(_ message: @autoclosure () -> String, with level: LogLevel, file: String, function: String, line: Int)
}

extension Logger {
    func verbose(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message(), with: .verbose, file: file, function: function, line: line)
    }
    func debug(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message(), with: .debug, file: file, function: function, line: line)
    }
    func info(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message(), with: .info, file: file, function: function, line: line)
    }
    func warning(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message(), with: .warning, file: file, function: function, line: line)
    }
    func error(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message(), with: .error, file: file, function: function, line: line)
    }
}

/// This Logger does nothing and skips every logging.
public final class DisabledLogger: Logger {
    public func log(_ message: @autoclosure () -> String, with level: LogLevel, file: String = #file, function: String = #function, line: Int = #line) { }
}

/// This Logger loggs every message to the console with a `print` statement.
@objc public final class DefaultLogger: NSObject, Logger {
    private let dispatchQueue = DispatchQueue(label: "DefaultLogger", qos: .background)
    private let minLevel: LogLevel
    
    @objc public init(minLevel: LogLevel) {
        self.minLevel = minLevel
        super.init()
    }
    
    public func log(_ message: @autoclosure () -> String, with level: LogLevel, file: String = #file, function: String = #function, line: Int = #line) {
        guard level.rawValue >= minLevel.rawValue else { return }
        let messageToPrint = message()
        dispatchQueue.async {
            print("MatomoTracker [\(level.shortcut)] \(messageToPrint)")
        }
    }
}
