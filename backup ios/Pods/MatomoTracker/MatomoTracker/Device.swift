import Foundation

final public class Device: NSObject {
    /// Creates an returns a new device object representing the current device
    @objc public static func makeCurrentDevice() ->  Device {
        let platform = currentPlatform()
        let humanReadablePlatformName = humanReadablePlatformNameForCurrentDevice()
        let os = osVersionForCurrentDevice()
        let screenSize = screenSizeForCurrentDevice()
        let nativeScreenSize = nativeScreenSizeForCurrentDevice()
        return Device(platform: platform,
                      humanReadablePlatformName: humanReadablePlatformName,
                      osVersion: os,
                      screenSize: screenSize,
                      nativeScreenSize: nativeScreenSize)
    }
    
    /// The platform name of the device i.e. "iPhone1,1" or "iPad3,6"
    @objc public let platform: String
    
    /// A human readable version of the platform name i.e. "iPhone 6 Plus" or "iPad Air 2 (WiFi)"
    /// Will be nil if no human readable string was found.
    @objc public let humanReadablePlatformName: String?
    
    /// The version number of the OS as String i.e. "1.2" or "9.4"
    @objc public let osVersion: String
    
    /// The screen size
    @objc public let screenSize: CGSize
    
    /// The native screen size
    /// Will be CGSize.zero if the value is not defined on the running platorm.
    @objc public let nativeScreenSize: CGSize

    required public init(platform: String, humanReadablePlatformName: String? = nil, osVersion: String, screenSize: CGSize, nativeScreenSize: CGSize? = nil) {
        self.platform = platform
        self.humanReadablePlatformName = humanReadablePlatformName
        self.osVersion = osVersion
        self.screenSize = screenSize
        self.nativeScreenSize = nativeScreenSize != nil ? nativeScreenSize! : CGSize.zero

        super.init()
    }
}

extension Device {
    /// The platform name of the current device i.e. "iPhone1,1" or "iPad3,6"
    private static func currentPlatform() -> String  {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0,  count: Int(size))
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }
    
    /// Returns a human readable version of the current platform name i.e. "iPhone 6 Plus" or "iPad Air 2 (WiFi)"
    /// Will return nil, if no human readable string could be found for the current platform
    private static func humanReadablePlatformNameForCurrentDevice() -> String? {
        let platform = currentPlatform()
        switch platform {
            
        // iPhone
        case "iPhone1,1":    return "iPhone 1G"
        case "iPhone1,2":    return "iPhone 3G"
        case "iPhone2,1":    return "iPhone 3GS"
        case "iPhone3,1":    return "iPhone 4"
        case "iPhone3,2":    return "iPhone 4 (Revision A)"
        case "iPhone3,3":    return "Verizon iPhone 4"
        case "iPhone4,1":    return "iPhone 4S"
        case "iPhone5,1":    return "iPhone 5 (GSM)"
        case "iPhone5,2":    return "iPhone 5 (GSM+CDMA)"
        case "iPhone5,3":    return "iPhone 5c (GSM)"
        case "iPhone5,4":    return "iPhone 5c (Global)"
        case "iPhone6,1":    return "iPhone 5s (GSM)"
        case "iPhone6,2":    return "iPhone 5s (Global)"
        case "iPhone7,1":    return "iPhone 6 Plus"
        case "iPhone7,2":    return "iPhone 6"
        case "iPhone8,1":    return "iPhone 6s"
        case "iPhone8,2":    return "iPhone 6s Plus"
        case "iPhone8,4":    return "iPhone SE"
        case "iPhone9,1":    return "iPhone 7 (GSM+CDMA)"
        case "iPhone9,2":    return "iPhone 7 Plus (GSM+CDMA)"
        case "iPhone9,3":    return "iPhone 7 (Global)"
        case "iPhone9,4":    return "iPhone 7 Plus (Global)"
        case "iPhone10,1":   return "iPhone 8 (GSM+CDMA)"
        case "iPhone10,2":   return "iPhone 8 Plus (GSM+CDMA)"
        case "iPhone10,3":   return "iPhone X (GSM+CDMA)"
        case "iPhone10,4":   return "iPhone 8 (Global)"
        case "iPhone10,5":   return "iPhone 8 Plus (Global)"
        case "iPhone10,6":   return "iPhone X (Global)"
        case "iPhone11,2":   return "iPhone XS"
        case "iPhone11,4":   return "iPhone XS Max"
        case "iPhone11,6":   return "iPhone XS Max (Global)"
        case "iPhone11,8":   return "iPhone XR"
        case "iPhone12,1":   return "iPhone 11"
        case "iPhone12,3":   return "iPhone 11 Pro"
        case "iPhone12,5":   return "iPhone 11 Pro Max"
            
        // iPod
        case "iPod1,1":      return "iPod Touch 1G"
        case "iPod2,1":      return "iPod Touch 2G"
        case "iPod3,1":      return "iPod Touch 3G"
        case "iPod4,1":      return "iPod Touch 4G"
        case "iPod5,1":      return "iPod Touch 5G"
        case "iPod7,1":      return "iPod Touch 6G"
        case "iPod9,1":      return "iPod Touch 7G"
            
        // iPad
        case "iPad1,1":      return "iPad 1"
        case "iPad2,1":      return "iPad 2 (WiFi)"
        case "iPad2,2":      return "iPad 2 (GSM)"
        case "iPad2,3":      return "iPad 2 (CDMA)"
        case "iPad2,4":      return "iPad 2 (WiFi)"
        case "iPad2,5":      return "iPad Mini 1 (WiFi)"
        case "iPad2,6":      return "iPad Mini 1 (GSM)"
        case "iPad2,7":      return "iPad Mini 1 (GSM+CDMA)"
        case "iPad3,1":      return "iPad 3 (WiFi)"
        case "iPad3,2":      return "iPad 3 (GSM+CDMA)"
        case "iPad3,3":      return "iPad 3 (GSM)"
        case "iPad3,4":      return "iPad 4 (WiFi)"
        case "iPad3,5":      return "iPad 4 (GSM)"
        case "iPad3,6":      return "iPad 4 (GSM+CDMA)"
        case "iPad4,1":      return "iPad Air 1 (WiFi)"
        case "iPad4,2":      return "iPad Air 1 (Cellular)"
        case "iPad4,3":      return "iPad Air"
        case "iPad4,4":      return "iPad Mini 2 (WiFi)"
        case "iPad4,5":      return "iPad Mini 2 (Cellular)"
        case "iPad4,6":      return "iPad Mini 2 (Rev)"
        case "iPad4,7":      return "iPad Mini 3 (WiFi)"
        case "iPad4,8":      return "iPad Mini 3 (A1600)"
        case "iPad4,9":      return "iPad Mini 3 (A1601)"
        case "iPad5,1":      return "iPad Mini 4 (WiFi)"
        case "iPad5,2":      return "iPad Mini 4 (Cellular)"
        case "iPad5,3":      return "iPad Air 2 (WiFi)"
        case "iPad5,4":      return "iPad Air 2 (Cellular)"
        case "iPad6,3":      return "iPad Pro 9.7 (WiFi)"
        case "iPad6,4":      return "iPad Pro 9.7 (Cellular)"
        case "iPad6,7":      return "iPad Pro 12.9 (WiFi)"
        case "iPad6,8":      return "iPad Pro 12.9 (Cellular)"
        case "iPad6,11":     return "iPad 5G (A1822)"
        case "iPad6,12":     return "iPad 5G (A1823)"
        case "iPad7,1":      return "iPad Pro 2G (WiFi)"
        case "iPad7,2":      return "iPad Pro 2G (Cellular)"
        case "iPad7,3":      return "iPad Pro 10.5 (A1701)"
        case "iPad7,4":      return "iPad Pro 10.5 (A1709)"
        case "iPad7,5":      return "iPad 6G (WiFi)"
        case "iPad7,6":      return "iPad 6G (Cellular)"
        case "iPad8,1":      return "iPad Pro 3G 11 (WiFi)"
        case "iPad8,2":      return "iPad Pro 3G 11 (1TB, WiFi)"
        case "iPad8,3":      return "iPad Pro 3G 11 (Cellular)"
        case "iPad8,4":      return "iPad Pro 3G (1TB, Cellular)"
        case "iPad8,5":      return "iPad Pro 3G 12.9 (WiFi)"
        case "iPad8,6":      return "iPad Pro 3G 12.9 (1TB, WiFi)"
        case "iPad8,7":      return "iPad Pro 3G 12.9 (Cellular)"
        case "iPad8,8":      return "iPad Pro 3G 12.9 (1TB, Cellular)"
        case "iPad11,1":     return "iPad mini 5G (WiFi)"
        case "iPad11,2":     return "iPad mini 5G"
        case "iPad11,3":     return "iPad Air 3G (WiFi)"
        case "iPad11,4":     return "iPad Air 3G"
            
        // Apple Watch
        case "Watch1,1":      return "Apple Watch 38mm"
        case "Watch1,2":      return "Apple Watch 42mm"
        case "Watch2,3":      return "Apple Watch 38mm (Series 2)"
        case "Watch2,4":      return "Apple Watch 42mm (Series 2)"
        case "Watch2,6":      return "Apple Watch 38mm (Series 1)"
        case "Watch2,7":      return "Apple Watch 42mm (Series 1)"
        case "Watch3,1":      return "Apple Watch Series 38mm (Series 3, Cellular)"
        case "Watch3,2":      return "Apple Watch 42mm (Series 3, Cellular)"
        case "Watch3,3":      return "Apple Watch 38mm (Series 3, GPS)"
        case "Watch3,4":      return "Apple Watch 42mm (Series 3, GPS)"
        case "Watch4,1":      return "Apple Watch 40mm (Series 4, GPS)"
        case "Watch4,2":      return "Apple Watch 44mm (Series 4, GPS)"
        case "Watch4,3":      return "Apple Watch 40mm (Series 4, Cellular)"
        case "Watch4,4":      return "Apple Watch 44mm (Series 4, Cellular)"
            
        // Apple TV
        case "AppleTV2,1":      return "Apple TV 2G"
        case "AppleTV3,1":      return "Apple TV 3G"
        case "AppleTV3,2":      return "Apple TV 3G (2013)"
        case "AppleTV5,3":      return "Apple TV 4G"
        case "AppleTV6,2":      return "Apple TV 4K"
            
        case "i386":         return "Simulator"
        case "x86_64":       return "Simulator"
            
        default: return nil
        }
    }
}

#if os(OSX)
    import AppKit
    extension Device {
        /// Returns the version number of the current OS as String i.e. "1.2" or "9.4"
        internal static func osVersionForCurrentDevice() -> String  {
            let version = ProcessInfo.processInfo.operatingSystemVersion
            return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        }
        
        // Returns the screen size in points
        internal static func screenSizeForCurrentDevice() ->  CGSize {
            guard let mainScreen = NSScreen.main else { return CGSize.zero }
            return mainScreen.visibleFrame.size
        }
        
        // Returns the screen size in pixels
        internal static func nativeScreenSizeForCurrentDevice() ->  CGSize? {
            return nil
        }
    }
#elseif os(iOS) || os(tvOS)
    import UIKit
    extension Device {
        
        /// Returns the version number of the current OS as String i.e. "1.2" or "9.4"
        internal static func osVersionForCurrentDevice() -> String  {
            return UIDevice.current.systemVersion
        }
        
        // Returns the screen size in points
        internal static func screenSizeForCurrentDevice() ->  CGSize {
            let bounds = UIScreen.main.bounds
            return bounds.size
        }
        
        // Returns the screen size in pixels
        internal static func nativeScreenSizeForCurrentDevice() ->  CGSize {
            let bounds = UIScreen.main.nativeBounds
            return bounds.size
        }
    }
#endif
