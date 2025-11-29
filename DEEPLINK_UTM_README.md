# Deep Link UTM Parameter Guide

This guide explains how to use UTM parameters in deep links for tracking user acquisition sources (e.g., Apple Ads, marketing campaigns).

## Overview

The Medito app supports UTM parameters in deep links, which are automatically stored and attributed to users in Firebase Analytics. This allows you to track which marketing campaigns, sources, and channels are driving app installs and user engagement.

## Supported UTM Parameters

The following standard UTM parameters are supported:

- `utm_source` - The source of the traffic (e.g., "apple_ads", "facebook", "email")
- `utm_medium` - The marketing medium (e.g., "cpc", "social", "email")
- `utm_campaign` - The campaign name (e.g., "summer2024", "new_user_promo")
- `utm_term` - The search term or keyword (optional)
- `utm_content` - Additional content identifier (optional)

## URL Format

### Custom URL Scheme

For iOS custom URL scheme deep links, use one of these formats:

**Recommended format (with path separator):**
```
org.meditofoundation:///?utm_source=campaign1&utm_campaign=summer2024
```

**Alternative format (with host):**
```
org.meditofoundation://medito?utm_source=campaign1&utm_campaign=summer2024
```

### Universal Links (HTTPS)

For universal links that work on both iOS and Android:

```
https://medito.app/?utm_source=campaign1&utm_campaign=summer2024
```

## Usage Examples

### Apple Ads Campaign

```
org.meditofoundation:///?utm_source=apple_ads&utm_medium=cpc&utm_campaign=summer_meditation&utm_content=ad_variant_1
```

### Social Media Campaign

```
org.meditofoundation:///?utm_source=facebook&utm_medium=social&utm_campaign=mindfulness_week
```

### Email Campaign

```
org.meditofoundation:///?utm_source=email&utm_medium=newsletter&utm_campaign=monthly_digest&utm_content=cta_button
```

### Custom Store Page

```
org.meditofoundation:///?utm_source=website&utm_medium=web&utm_campaign=landing_page_v2
```

## How It Works

1. **User clicks deep link** - The link contains UTM parameters in the query string
2. **App opens** - The app extracts and stores UTM parameters in local storage
3. **User initialization** - Once the user is initialized (anonymous or logged in), UTM parameters are applied as Firebase Analytics user properties
4. **Attribution** - The UTM parameters are now associated with the user and can be used for analytics and segmentation

## Important Notes

- **First launch only**: UTM parameters are captured on the first app launch from the deep link
- **One-time storage**: UTM parameters are stored once and applied after user initialization, then removed from storage
- **No navigation required**: UTM-only links (with no path) will simply open the app without navigating to a specific screen
- **Case sensitive**: UTM parameter names are case-sensitive - use lowercase (e.g., `utm_source`, not `UTM_SOURCE`)

## Testing

### iOS Simulator/Device

1. Open Safari on your iOS device/simulator
2. Enter the deep link URL in the address bar:
   ```
   org.meditofoundation:///?utm_source=test&utm_campaign=testing
   ```
3. Press Go - the app should open
4. Check the debug logs for confirmation:
   - Look for `[DEEPLINK]` log entries showing stored UTM parameters
   - After user initialization, look for `[FIREBASE_ANALYTICS]` entries showing applied UTM parameters

### Android Device

1. Use ADB to test:
   ```bash
   adb shell am start -W -a android.intent.action.VIEW -d "org.meditofoundation:///?utm_source=test&utm_campaign=testing"
   ```
2. Or use a browser/QR code scanner to open the universal link:
   ```
   https://medito.app/?utm_source=test&utm_campaign=testing
   ```

## Best Practices

1. **Always include utm_source**: This is the most important parameter for identifying traffic sources
2. **Use consistent naming**: Use lowercase, underscores, and consistent naming conventions (e.g., `apple_ads` not `AppleAds` or `apple-ads`)
3. **Keep it simple**: Avoid special characters that need URL encoding when possible
4. **Test before launch**: Always test deep links before using them in production campaigns
5. **Document campaigns**: Keep a record of which UTM parameters you use for each campaign

## URL Encoding

If you need to include special characters in UTM parameter values, they must be URL-encoded:

- Space: `%20` or `+`
- Ampersand: `%26`
- Equals: `%3D`
- Hash: `%23`

Example:
```
org.meditofoundation:///?utm_source=email&utm_campaign=summer%202024
```

## Troubleshooting

### UTM Parameters Not Appearing in Analytics

1. **Check the URL format**: Ensure you're using the correct format with `:///?` or `://host?`
2. **Verify user initialization**: UTM parameters are only applied after user initialization - check logs for user ID
3. **Check Firebase Analytics**: Verify Firebase Analytics is initialized and enabled
4. **Review debug logs**: Look for `[DEEPLINK]` and `[FIREBASE_ANALYTICS]` log entries

### App Not Opening from Deep Link

1. **Verify URL scheme**: Ensure `org.meditofoundation` is registered in the app's Info.plist (iOS) or AndroidManifest.xml (Android)
2. **Check URL format**: Use the recommended format `org.meditofoundation:///?...`
3. **Test in Safari/Chrome**: Try opening the link in a browser first to verify it's valid

## Support

For technical questions or issues, contact the development team.

For marketing campaign questions, refer to your campaign manager.

