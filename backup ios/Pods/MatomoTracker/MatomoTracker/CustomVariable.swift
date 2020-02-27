import Foundation

/// See Custom Variable documentation here: https://piwik.org/docs/custom-variables/
public struct CustomVariable: Codable {
    /// The index of the variable.
    let index: UInt

    /// The name of the variable.
    let name: String
    
    /// The value of the variable.
    let value: String
    
    public init(index: UInt, name: String, value: String) {
        self.index = index
        self.name = name
        self.value = value
    }
}
