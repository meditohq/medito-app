import Foundation

// Built alongside the production WatchProgress enum by tools/test_watch_progress.py.
NSTimeZone.default = TimeZone(secondsFromGMT: 0)!
let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
let cases = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]
for fixture in cases {
    let result = WatchProgress.project(fixture["snapshot"] as! [String: Any],
        pending: fixture["pending"] as! [[String: Any]],
        now: Date(timeIntervalSince1970: Double(fixture["now"] as! Int) / 1000))
    let pack = result["upNext"] as! [String: Any]
    let expected = fixture["expected"] as! [String: Any]
    for key in ["completed", "id"] {
        precondition(String(describing: pack[key]!) == String(describing: expected[key]!),
            "\(fixture["name"]!): \(key)")
    }
    precondition(pack["canPlay"] as! Bool == expected["canPlay"] as! Bool,
        "\(fixture["name"]!): canPlay")
    precondition(result["streak"] as! Int == expected["streak"] as! Int,
        "\(fixture["name"]!): streak")
    if let consistency = expected["consistency"] as? Int {
        precondition(result["consistency"] as! Int == consistency,
            "\(fixture["name"]!): consistency")
    }
}
print("Swift: \(cases.count) watch progress cases passed")
