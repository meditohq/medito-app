# Deep Link UTM Parameter Guide

This guide explains how to use UTM parameters in deep links for tracking user acquisition sources (e.g., Apple Ads, marketing campaigns).

## Overview

The Medito app supports UTM parameters in deep links, which are automatically stored and attributed to users in Firebase Analytics and Stripe payment metadata. This allows you to track which marketing campaigns, sources, and channels are driving app installs, user engagement, and payments. 

## Supported UTM Parameters

The following standard UTM parameters are supported:

- `utm_source` - The source of the traffic (e.g., "apple_ads", "facebook", "email")
- `utm_medium` - The marketing medium (e.g., "cpc", "social", "email")
- `utm_campaign` - The campaign name (e.g., "summer2024", "new_user_promo")
- `utm_term` - The search term or keyword (optional, useful for Apple Ads keyword tracking)
- `utm_content` - Additional content identifier (optional, useful for CPP ID or creative variant tracking)

## URL Format

### Custom URL Scheme (iOS only)

**iOS:** Use either format:
- `org.meditofoundation:///?utm_source=campaign1&utm_campaign=summer2024` (with path separator)
- `org.meditofoundation://medito?utm_source=campaign1&utm_campaign=summer2024` (with host)

### Universal Links (HTTPS)

**Recommended for both iOS and Android:**

```
https://medito.app/?utm_source=campaign1&utm_campaign=summer2024
```

**Android:** Use universal links (`https://medito.app`) for UTM tracking.

## Usage Examples

### Apple Ads Campaign

**iOS (custom scheme):**
```
org.meditofoundation:///?utm_source=apple_ads&utm_medium=cpc&utm_campaign=summer_meditation&utm_term=meditation_app&utm_content=ad_variant_1
```

**Universal link (both platforms):**
```
https://medito.app/?utm_source=apple_ads&utm_medium=cpc&utm_campaign=summer_meditation&utm_term=meditation_app&utm_content=ad_variant_1
```

**Note**: `utm_term` is useful for tracking Apple Ads keywords, and `utm_content` can be used for CPP ID or creative variant tracking.

### Social Media Campaign

**iOS (custom scheme):**
```
org.meditofoundation:///?utm_source=facebook&utm_medium=social&utm_campaign=mindfulness_week
```

**Universal link (both platforms):**
```
https://medito.app/?utm_source=facebook&utm_medium=social&utm_campaign=mindfulness_week
```

### Email Campaign

**iOS (custom scheme):**
```
org.meditofoundation:///?utm_source=email&utm_medium=newsletter&utm_campaign=monthly_digest&utm_content=cta_button
```

**Universal link (both platforms):**
```
https://medito.app/?utm_source=email&utm_medium=newsletter&utm_campaign=monthly_digest&utm_content=cta_button
```

### Custom Store Page

**iOS (custom scheme):**
```
org.meditofoundation:///?utm_source=website&utm_medium=web&utm_campaign=landing_page_v2
```

**Universal link (both platforms):**
```
https://medito.app/?utm_source=website&utm_medium=web&utm_campaign=landing_page_v2
```

## How It Works

1. **User clicks deep link** - The link contains UTM parameters in the query string
2. **App opens** - The app extracts and stores UTM parameters in local storage
3. **User initialization** - Once the user is initialized (anonymous or logged in), UTM parameters are applied as Firebase Analytics user properties
4. **Attribution** - The UTM parameters are now associated with the user and can be used for analytics and segmentation
5. **Payment tracking** - When a user makes a payment (one-time donation or subscription), any stored UTM parameters are automatically included in the Stripe payment metadata for attribution and revenue tracking

## Stripe Payment Metadata

UTM parameters stored from deep links are automatically included in Stripe payment metadata for all payment types (one-time donations, monthly subscriptions, and yearly subscriptions). This allows you to:

- Track which marketing campaigns drive revenue
- Attribute payments to specific traffic sources
- Analyse conversion rates by campaign, source, or medium
- Use Stripe's reporting tools to segment revenue by UTM parameters

The following UTM parameters are included in Stripe metadata (if available):
- `utm_source`
- `utm_medium`
- `utm_campaign`
- `utm_term` (useful for Apple Ads keyword tracking)
- `utm_content` (useful for CPP ID or creative variant tracking)

## Important Notes

- **First launch only**: UTM parameters are captured on the first app launch from the deep link
- **One-time storage**: UTM parameters are stored once and applied after user initialization, then removed from storage
- **Payment attribution**: UTM parameters persist until a payment is made, ensuring proper attribution even if the user makes a payment later
- **No navigation required**: UTM-only links (with no path) will simply open the app without navigating to a specific screen
- **Case sensitive**: UTM parameter names are case-sensitive - use lowercase (e.g., `utm_source`, not `UTM_SOURCE`)

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
