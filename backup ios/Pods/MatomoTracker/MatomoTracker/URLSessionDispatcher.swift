import Foundation

#if os(OSX)
    import WebKit
#elseif os(iOS)
    import WebKit
#endif

public final class URLSessionDispatcher: Dispatcher {
    
    private let serializer = EventAPISerializer()
    private let timeout: TimeInterval
    private let session: URLSession
    public let baseURL: URL

    public private(set) var userAgent: String?

    #if os(iOS)
    private static var webView: WKWebView?
    #endif
    
    /// Generate a URLSessionDispatcher instance
    ///
    /// - Parameters:
    ///   - baseURL: The url of the Matomo server. This url has to end in `piwik.php`.
    ///   - userAgent: An optional parameter for custom user agent.
    ///   - timeout: The timeout interval for the request. The default is 5.0.
    public init(baseURL: URL, userAgent: String? = nil, timeout: TimeInterval = 5.0) {
        self.baseURL = baseURL
        self.timeout = timeout
        self.session = URLSession.shared
        if let userAgent = userAgent {
            self.userAgent = userAgent
        } else {
            URLSessionDispatcher.generateDefaultUserAgent() { [weak self] userAgent in
                self?.userAgent = userAgent
            }
        }
    }
    
    private static func generateDefaultUserAgent(_ completion: @escaping (String) -> Void) {
        let useragentSuffix = " MatomoTracker SDK URLSessionDispatcher"
        DispatchQueue.main.async {
            #if os(OSX)
            let webView = WebView(frame: .zero)
            let userAgent = webView.stringByEvaluatingJavaScript(from: "navigator.userAgent") ?? ""
            completion(userAgent.appending(useragentSuffix))
            #elseif os(iOS)
            webView = WKWebView(frame: .zero)
            webView?.evaluateJavaScript("navigator.userAgent") { (result, error) -> Void in
                if let userAgent = result as? String {
                    completion(userAgent.appending(useragentSuffix))
                } else {
                    completion(useragentSuffix)
                }

                webView = nil
            }
            #elseif os(tvOS)
            completion(useragentSuffix)
            #endif
        }
    }
    
    public func send(events: [Event], success: @escaping ()->(), failure: @escaping (_ error: Error)->()) {
        let jsonBody: Data
        do {
            jsonBody = try serializer.jsonData(for: events)
        } catch  {
            failure(error)
            return
        }
        let request = buildRequest(baseURL: baseURL, method: "POST", contentType: "application/json; charset=utf-8", body: jsonBody)
        send(request: request, success: success, failure: failure)
    }
    
    private func buildRequest(baseURL: URL, method: String, contentType: String? = nil, body: Data? = nil) -> URLRequest {
        var request = URLRequest(url: baseURL, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: timeout)
        request.httpMethod = method
        body.map { request.httpBody = $0 }
        contentType.map { request.setValue($0, forHTTPHeaderField: "Content-Type") }
        userAgent.map { request.setValue($0, forHTTPHeaderField: "User-Agent") }
        return request
    }
    
    private func send(request: URLRequest, success: @escaping ()->(), failure: @escaping (_ error: Error)->()) {
        let task = session.dataTask(with: request) { data, response, error in
            // should we check the response?
            // let dataString = String(data: data!, encoding: String.Encoding.utf8)
            if let error = error {
                failure(error)
            } else {
                success()
            }
        }
        task.resume()
    }
    
}

