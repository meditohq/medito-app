# MatomoTracker (former PiwikTracker) iOS SDK

The MatomoTracker is an iOS, tvOS and macOS SDK for sending app analytics to a Matomo server. MatomoTracker can be used from Swift and [Objective-C](https://github.com/matomo-org/matomo-sdk-ios/wiki/FAQ#how-to-use-the-matomotracker-from-objective-c).

**Fancy help improve this SDK? Check [this list](https://github.com/matomo-org/matomo-sdk-ios/issues?utf8=✓&q=is%3Aopen+is%3Aissue) to see what is left and can be improved.**

[![Build Status](https://travis-ci.org/matomo-org/matomo-sdk-ios.svg?branch=develop)](https://travis-ci.org/matomo-org/matomo-sdk-ios)

## Installation
### [CocoaPods](https://cocoapods.org)

Use the following in your Podfile.

```
pod 'MatomoTracker', '~> 7.2'
```

Then run `pod install`. In every file you want to use the MatomoTracker, don't forget to import the framework with `import MatomoTracker`.

### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a non intrusive way to install MatomoTracker to your project. It makes no changes to your Xcode project and workspace. Add the following to your Cartfile:

```
github "matomo-org/matomo-sdk-ios"
```

## Usage
### Matomo Instance

The Matomo iOS SDK doesn't provide a instance of the PiwikTracker. In order to be able to track data you have to create an instance first.

```Swift
let matomoTracker = MatomoTracker(siteId: "23", baseURL: URL(string: "https://demo2.matomo.org/piwik.php")!)
```


The `siteId` is the ID that you can get if you [add a website](https://matomo.org/docs/manage-websites/#add-a-website) within the Matomo web interface. The `baseURL` it the URL to your Matomo web instance and has to include the "piwik.php" or "matomo.php" string.

You can either pass around this instance, or add an extension to the `MatomoTracker` class and add a shared instance property.

```Swift
extension MatomoTracker {
    static let shared: MatomoTracker = MatomoTracker(siteId: "1", baseURL: URL(string: "https://example.com/piwik.php")!)
}
```

The `siteId` is the ID that you can get if you [add a website](https://matomo.org/docs/manage-websites/#add-a-website) within the Matomo web interface. The `baseURL` is the URL to your Matomo web instance and has to include the "piwik.php" or "matomo.php" string.

You can use multiple instances within one application.

#### Opting Out

The MatomoTracker SDK supports opting out of tracking. Please use the `isOptedOut` property of the MatomoTracker to define if the user opted out of tracking.

```Swift
matomoTracker.isOptedOut = true
```

### Tracking Page Views

The MatomoTracker can track hierarchical screen names, e.g. screen/settings/register. Use this to create a hierarchical and logical grouping of screen views in the Matomo web interface.

```Swift
matomoTracker.track(view: ["path","to","your","page"])
```

You can also set the url of the page.
```Swift
let url = URL(string: "https://matomo.org/get-involved/")
matomoTracker.track(view: ["community","get-involved"], url: url)
```

### Tracking Events

Events can be used to track user interactions such as taps on a button. An event consists of four parts:

- Category
- Action
- Name (optional, recommended)
- Value (optional)

```Swift
matomoTracker.track(eventWithCategory: "player", action: "slide", name: "volume", value: 35.1)
```

This will log that the user slid the volume slider on the player to 35.1%.

### Tracking search

The `MatomoTracker` can track how users use your app internal search. You can track what keywords were searched for, what categories they use, the number of results for a certain search and what searches resulted in no results.

```Swift
matomoTracker.trackSearch(query: "Best mobile tracking", category: "Technology", resultCount: 15)
```

### Custom Dimension

The Matomo SDK currently supports Custom Dimensions for the Visit Scope. Using Custom Dimensions you can add properties to the whole visit, such as "Did the user finish the tutorial?", "Is the user a paying user?" or "Which version of the Application is being used?" and such. Before sending custom dimensions please make sure Custom Dimensions are [properly installed and configured](https://matomo.org/docs/custom-dimensions/). You will need the `ID` of your configured Dimension.

After that you can set a new Dimension,

```Swift
matomoTracker.set(value: "1.0.0-beta2", forIndex: 1)
```

or remove an already set dimension.

```Swift
matomoTracker.remove(dimensionAtIndex: 1)
```

Dimensions in the Visit Scope will be sent along every Page View or Event. Custom Dimensions are not persisted by the SDK and have to be re-configured upon application startup.

### Custom User ID

To add a [custom User ID](https://matomo.org/docs/user-id/), simply set the value you'd like to use on the `userId` field of the tracker:

```Swift
matomoTracker.userId = "coolUsername123"
```

All future events being tracked by the SDK will be associated with this userID, as opposed to the default UUID created for each Visitor.

### Custom Visitor ID

MatomoTracker will generate an `_id` upon first usage and will use this value to recognize the current visitor. If you want to set your own visitor id you can set your own visitor id. Make sure you use a 16 character long hexadecimal string. The `forcedVisitorId` is persisted over app starts.

```Swift
matomoTracker.forcedVisitorId = "0123456789abcdef"
```

### Campaign Tracking

The Matomo iOS SDK supports [campaign tracking](https://matomo.org/docs/tracking-campaigns/).

```Swift
matomoTracker.trackCampaign(name: @"campaign_name", keyword: @"campaign_keyword")
```

### Content Tracking

The Matomo iOS SDK supports [content tracking](https://matomo.org/docs/content-tracking/).

```Swift
matomoTracker.trackContentImpression(name: "preview-liveaboard", piece: "Malaysia", target: "https://dummy.matomo.org/liveaboard/malaysia")
matomoTracker.trackContentInteraction(name: "preview-liveaboard", interaction: "tap", piece: "Malaysia", target: "https://dummy.matomo.org/liveaboard/malaysia")
```

### Goal Tracking

The Matomo iOS SDK supports [goal tracking](https://matomo.org/docs/tracking-goals-web-analytics/).

```Swift
matomoTracker.trackGoal(id: 1, revenue: 99.99)
```

### Order Tracking

The Matomo iOS SDK supports [order tracking](https://matomo.org/docs/ecommerce-analytics/#tracking-ecommerce-orders-items-purchased-required).

```Swift
let items = [
  OrderItem(sku: "product_sku_1", name: "iPhone Xs", category: "phone", price: 999.99, quantity: 1),
  OrderItem(sku: "product_sku_2", name: "iPhone Xs Max", category: "phone", price: 1199.99, quantity: 1)
]

matomoTracker.trackOrder(id: "order_id_1234", items: items, revenue: 2199.98, subTotal: 2000, tax: 190.98, shippingCost: 9)
```

## Advanced Usage
### Manual dispatching

The MatomoTracker will dispatch events every 30 seconds automatically. If you want to dispatch events manually, you can use the `dispatch()` function. You can, for example, dispatch whenever the application enter the background.

```Swift
func applicationDidEnterBackground(_ application: UIApplication) {
  matomoTracker.dispatch()
}
```

### Session Management

The MatomoTracker starts a new session whenever the application starts. If you want to start a new session manually, you can use the `startNewSession()` function. You can, for example, start a new session whenever the user enters the application.

```Swift
func applicationWillEnterForeground(_ application: UIApplication) {
  matomoTracker.startNewSession()
}
```

### Logging

The MatomoTracker per default logs `warning` and `error` messages to the console. You can change the `LogLevel`.

```Swift
matomoTracker.logger = DefaultLogger(minLevel: .verbose)
matomoTracker.logger = DefaultLogger(minLevel: .debug)
matomoTracker.logger = DefaultLogger(minLevel: .info)
matomoTracker.logger = DefaultLogger(minLevel: .warning)
matomoTracker.logger = DefaultLogger(minLevel: .error)
```

You can also write your own `Logger` and send the logs wherever you want. Just write a new class/struct and let it conform to the `Logger` protocol.

### Custom User Agent
The `MatomoTracker` will create a default user agent derived from the WKWebView user agent.
You can instantiate the `MatomoTracker` using your own user agent.

```Swift
let matomoTracker = MatomoTracker(siteId: "5", baseURL: URL(string: "http://your.server.org/path-to-matomo/piwik.php")!, userAgent: "Your custom user agent")
```

### Sending custom events

Instead of using the convenience functions for events and screen views for example you can create your event manually and even send custom tracking parameters. This feature isn't available from Objective-C.

```Swift
func sendCustomEvent() {
  guard let matomoTracker = MatomoTracker.shared else { return }
  let downloadURL = URL(string: "https://builds.matomo.org/piwik.zip")!
  let event = Event(tracker: matomoTracker, action: ["menu", "custom tracking parameters"], url: downloadURL, customTrackingParameters: ["download": downloadURL.absoluteString])
  matomoTracker.track(event)
}
```

All custom events will be URL-encoded and dispatched along with the default Event parameters. Please read the [Tracking API Documentation](https://developer.matomo.org/api-reference/tracking-api) for more information on which parameters can be used.

Also: You cannot override Custom Parameter keys that are already defined by the Event itself. If you set those keys in the `customTrackingParameters` they will be discarded.

### Automatic url generation

You can define the url property on every `Event`. If none is defined, the SDK will try to generate a url based on the `contentBase` of the `MatomoTracker`. If the `contentBase` is nil, no url will be generated. If the `contentBase` is set, it will append the actions of the event to it and use it as the url. Per default the `contentBase` is generated using the application bundle identifier. For example `http://org.matomo.skd`. This will not result in resolvable urls, but enables the backend to analyse and structure them.

### Event dispatching

Whenever you track an event or a page view it is stored in memory first. In every dispatch run a batch of those events are sent to the server. If the device is offline or the server doesn't respond these events will be kept and resent at a later time. Events currently aren't stored on disk and will be lost if the application is terminated. [#137](https://github.com/matomo-org/matomo-sdk-ios/issues/137)

## Contributing
Please read [CONTRIBUTING.md](https://github.com/matomo-org/matomo-sdk-ios/blob/develop/CONTRIBUTING.md) for details.

## ToDo
### These features aren't implemented yet

- Tracking of more things
  - Social Interactions
  - Goals and Conversions
  - Outlinks
  - Downloads
- Customizing the tracker
  - use different dispatchers (Alamofire)

## License

MatomoTracker is available under the [MIT license](LICENSE.md).
