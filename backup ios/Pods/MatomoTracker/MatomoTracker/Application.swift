#if SWIFT_PACKAGE
import Foundation
#endif

public struct Application {
    /// Creates an returns a new application object representing the current application
    public static func makeCurrentApplication() -> Application {
        let displayName = bundleDisplayNameForCurrentApplication()
        let name = bundleNameForCurrentApplication()
        let identifier = bundleIdentifierForCurrentApplication()
        let version = bundleVersionForCurrentApplication()
        let shortVersion = bundleShortVersionForCurrentApplication()
        return Application(bundleDisplayName: displayName, bundleName: name, bundleIdentifier: identifier, bundleVersion: version, bundleShortVersion: shortVersion)
    }
    
    /// The name of your app as displayed on the homescreen i.e. "My App"
    public let bundleDisplayName: String?
    
    /// The bundle name of your app i.e. "my-app"
    public let bundleName: String?
    
    /// The bundle identifier of your app i.e. "com.my-company.my-app"
    public let bundleIdentifier: String?
    
    /// The bundle version a.k.a. build number as String i.e. "149"
    public let bundleVersion: String?
    
    /// The app version as String i.e. "1.0.1"
    public let bundleShortVersion: String?
}

extension Application {
    /// Returns the name of the app as displayed on the homescreen
    private static func bundleDisplayNameForCurrentApplication() -> String? {
        return Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
    }
    
    /// Returns the bundle name of the app
    private static func bundleNameForCurrentApplication() -> String? {
        return Bundle.main.infoDictionary?["CFBundleName"] as? String
    }
    
    /// Returns the bundle identifier
    private static func bundleIdentifierForCurrentApplication() -> String? {
        return Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String
    }
    
    /// Returns the bundle version
    private static func bundleVersionForCurrentApplication() -> String? {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    }
    
    /// Returns the app version
    private static func bundleShortVersionForCurrentApplication() -> String? {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
}
