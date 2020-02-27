import Foundation

final class EventAPISerializer {
    internal func jsonData(for events: [Event]) throws -> Data {
        let eventsAsQueryItems = events.map({ $0.queryItems })
        let serializedEvents = eventsAsQueryItems.map({ items in
            items.compactMap({ item in
                guard let value = item.value,
                    let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryParameterAllowed) else { return nil }
                return "\(item.name)=\(encodedValue)"
            }).joined(separator: "&")
        })
        let body = ["requests": serializedEvents.map({ "?\($0)" })]
        return try JSONSerialization.data(withJSONObject: body, options: [])
    }
}

fileprivate extension Event {
    
    private func customVariableParameterValue() -> String {
        let customVariableParameterValue: [String] = customVariables.map { "\"\($0.index)\":[\"\($0.name)\",\"\($0.value)\"]" }
        return "{\(customVariableParameterValue.joined(separator: ","))}"
    }
    
    private func orderItemParameterValue() -> String? {
        let serializable: [[Codable?]] = orderItems.map {
            let parameters: [Codable?] = [$0.sku, $0.name, $0.category, $0.price, $0.quantity]
            return parameters
        }
        if let data = try? JSONSerialization.data(withJSONObject: serializable, options: []) {
            return String(bytes: data, encoding: .utf8)
        } else {
            return nil
        }
    }

    var queryItems: [URLQueryItem] {
        get {
            let lastOrderTimestamp = orderLastDate != nil ? "\(Int(orderLastDate!.timeIntervalSince1970))" : nil
            
            let items = [
                URLQueryItem(name: "idsite", value: siteId),
                URLQueryItem(name: "rec", value: "1"),
                // Visitor
                URLQueryItem(name: "_id", value: visitor.id),
                URLQueryItem(name: "cid", value: visitor.forcedId),
                URLQueryItem(name: "uid", value: visitor.userId),
                
                // Session
                URLQueryItem(name: "_idvc", value: "\(session.sessionsCount)"),
                URLQueryItem(name: "_viewts", value: "\(Int(session.lastVisit.timeIntervalSince1970))"),
                URLQueryItem(name: "_idts", value: "\(Int(session.firstVisit.timeIntervalSince1970))"),
                
                URLQueryItem(name: "url", value:url?.absoluteString),
                URLQueryItem(name: "action_name", value: actionName.joined(separator: "/")),
                URLQueryItem(name: "lang", value: language),
                URLQueryItem(name: "urlref", value: referer?.absoluteString),
                URLQueryItem(name: "new_visit", value: isNewSession ? "1" : nil),
                
                URLQueryItem(name: "h", value: DateFormatter.hourDateFormatter.string(from: date)),
                URLQueryItem(name: "m", value: DateFormatter.minuteDateFormatter.string(from: date)),
                URLQueryItem(name: "s", value: DateFormatter.secondsDateFormatter.string(from: date)),

                URLQueryItem(name: "cdt", value: DateFormatter.iso8601DateFormatter.string(from: date)),
                
                //screen resolution
                URLQueryItem(name: "res", value:String(format: "%1.0fx%1.0f", screenResolution.width, screenResolution.height)),
                
                URLQueryItem(name: "e_c", value: eventCategory),
                URLQueryItem(name: "e_a", value: eventAction),
                URLQueryItem(name: "e_n", value: eventName),
                URLQueryItem(name: "e_v", value: eventValue != nil ? "\(eventValue!)" : nil),
                
                URLQueryItem(name: "_rcn", value: campaignName),
                URLQueryItem(name: "_rck", value: campaignKeyword),

                URLQueryItem(name: "search", value: searchQuery),
                URLQueryItem(name: "search_cat", value: searchCategory),
                URLQueryItem(name: "search_count", value: searchResultsCount != nil ? "\(searchResultsCount!)" : nil),
                
                URLQueryItem(name: "c_n", value: contentName),
                URLQueryItem(name: "c_p", value: contentPiece),
                URLQueryItem(name: "c_t", value: contentTarget),
                URLQueryItem(name: "c_i", value: contentInteraction),
                
                URLQueryItem(name: "idgoal", value: goalId != nil ? "\(goalId!)" : nil),
                URLQueryItem(name: "revenue", value: revenue != nil ? "\(revenue!)" : nil),

                URLQueryItem(name: "ec_id", value: orderId),
                URLQueryItem(name: "revenue", value: orderRevenue != nil ? "\(orderRevenue!)" : nil),
                URLQueryItem(name: "ec_st", value: orderSubTotal != nil ? "\(orderSubTotal!)" : nil),
                URLQueryItem(name: "ec_tx", value: orderTax != nil ? "\(orderTax!)" : nil),
                URLQueryItem(name: "ec_sh", value: orderShippingCost != nil ? "\(orderShippingCost!)" : nil),
                URLQueryItem(name: "ec_dt", value: orderDiscount != nil ? "\(orderDiscount!)" : nil),
                URLQueryItem(name: "_ects", value: lastOrderTimestamp),
                ].filter { $0.value != nil }

            let dimensionItems = dimensions.map { URLQueryItem(name: "dimension\($0.index)", value: $0.value) }
            let customItems = customTrackingParameters.map { return URLQueryItem(name: $0.key, value: $0.value) }
            let customVariableItems = customVariables.count > 0 ? [URLQueryItem(name: "_cvar", value: customVariableParameterValue())] : []
            let ecommerceOrderItemsAndFlag = orderItems.count > 0 ? [URLQueryItem(name: "ec_items", value: orderItemParameterValue()), URLQueryItem(name: "idgoal", value: "0")] : []

            return items + dimensionItems + customItems + customVariableItems + ecommerceOrderItemsAndFlag
        }
    }
}

fileprivate extension DateFormatter {
    static let hourDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH"
        return dateFormatter
    }()
    static let minuteDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "mm"
        return dateFormatter
    }()
    static let secondsDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "ss"
        return dateFormatter
    }()
    static let iso8601DateFormatter: DateFormatterProtocol = {
        if #available(iOS 10, OSX 10.12, watchOS 3.0, tvOS 10.0, *) {
            return ISO8601DateFormatter()
        } else {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .iso8601)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
            return formatter
        }
    }()
}

fileprivate protocol DateFormatterProtocol {
    func string(from date: Date) -> String
    func date(from string: String) -> Date?
}

@available(iOS 10, OSX 10.12, watchOS 3.0, tvOS 10.0, *)
extension ISO8601DateFormatter: DateFormatterProtocol {}
extension DateFormatter: DateFormatterProtocol {}

fileprivate extension CharacterSet {
    
    /// Returns the character set for characters allowed in a query parameter URL component.
    static var urlQueryParameterAllowed: CharacterSet {
        return CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&/?"))
    }
}
