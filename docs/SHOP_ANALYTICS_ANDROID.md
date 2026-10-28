# Shop analytics on Android: the `items` param

## What broke

Every shop event that sent `items` as a number never reached GA4 from
Android, from 2609.27.0 up to 2610.17.1. Those events are `shop_bag_viewed`,
`shop_checkout_started`, `shop_checkout_returned` and `shop_bag_cleared`.
Over Sep 27 – Oct 27 there was 1 bag view and 1 checkout from about 96
Android users who added to bag.

GA4 reserves `items` for a list of item bundles. On Android, Play services'
measurement service throws while it processes such an event, and the event is
lost:

```
E FA-SVC: Task exception on worker thread: java.lang.NullPointerException: null reference
```

iOS accepts it, so iOS data was fine. The checkout itself worked: the bag
opened and Checkout opened the Custom Tab. Only the analytics were lost. The
shop's own GA4 does see `medito_app / app` checkouts.

**Fix:** the param is now `line_items`, on both platforms.
`FirebaseAnalyticsService.logEvent` asserts in debug builds that `items` is
never a non-list. Queries over these events must read `line_items` for builds
after this fix and `items` for iOS builds before it.

## How to verify

### Real device or prod internal build (preferred)

Dev builds send no analytics: the dev manifest sets
`firebase_analytics_collection_deactivated` and `FirebaseAnalyticsService`
uses a no-op in the dev flavor. So verify on a prod-flavor build, such as an
internal-testing build:

```bash
adb shell setprop debug.firebase.analytics.app meditofoundation.medito
adb shell setprop log.tag.FA VERBOSE
adb shell setprop log.tag.FA-SVC VERBOSE
adb logcat -s FA FA-SVC | grep -E "name=shop_|Task exception"
```

Open Shop, add something, open the bag, tap Checkout. You should see
`Logging event: ... name=shop_bag_viewed` with `line_items=1` and then
`name=shop_checkout_started`. You should see no `Task exception` line. The
events also show up in Firebase DebugView.

### Emulator, without sending anything to prod

Use this only to repro: the dev app shares the prod Firebase app ID.

1. Build a dev APK with two local, uncommitted changes. In the dev
   `AndroidManifest.xml`, set `firebase_analytics_collection_deactivated` to
   `false`. In `FirebaseAnalyticsService.initialize`, skip the `isDevFlavor`
   no-op branch.
2. On a Google APIs emulator image (rootable), block Play services' network so
   nothing uploads. The app itself stays online, so the shop still loads:
   ```bash
   adb root
   GMS=$(adb shell stat -c %u /data/data/com.google.android.gms | tr -d '\r')
   adb shell iptables -I OUTPUT -m owner --uid-owner $GMS -j REJECT
   adb shell ip6tables -I OUTPUT -m owner --uid-owner $GMS -j REJECT
   ```
3. Run the flow and read logcat as above.
4. Purge the queued events **before** you unblock the network. Uninstalling the
   app does not purge them:
   ```bash
   adb shell "sqlite3 /data/data/com.google.android.gms/databases/google_app_measurement.db \"delete from queue where app_id='meditofoundation.medito.dev'; delete from raw_events where app_id='meditofoundation.medito.dev';\""
   adb shell iptables -D OUTPUT -m owner --uid-owner $GMS -j REJECT
   adb shell ip6tables -D OUTPUT -m owner --uid-owner $GMS -j REJECT
   ```
5. Revert the two local changes.

### After release (BigQuery)

```sql
SELECT event_name, COUNT(DISTINCT user_pseudo_id) users
FROM `medito-9165c.analytics_451310720.events_*`
WHERE _TABLE_SUFFIX >= '<release date>' AND platform = 'ANDROID'
  AND app_info.version >= '<fixed version>'
  AND event_name IN ('shop_add_to_bag', 'shop_bag_viewed', 'shop_checkout_started')
GROUP BY 1
```

`shop_bag_viewed` and `shop_checkout_started` users should now be a large share
of `shop_add_to_bag` users. On iOS, 43 of 65 add-to-bag users started checkout.
