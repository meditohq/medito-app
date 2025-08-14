# 🌍 Medito Localization Guide

## Overview

This guide explains how to use the new Spanish localization system in Medito while maintaining backward compatibility with existing `StringConstants`.

## 🚀 How It Works

We've implemented a **hybrid approach** that allows gradual migration to localized strings without breaking existing code:

1. **Automatic Fallback**: If a localized string isn't available, it falls back to `StringConstants`
2. **No Code Changes Required**: Existing code continues to work unchanged
3. **Gradual Migration**: You can migrate strings to localization one by one
4. **Full Coverage**: All existing strings have been translated to Spanish

## 📱 User Experience

- **Spanish users**: Automatically see the app in Spanish based on device language
- **All users**: Can manually change language in Settings → Language
- **Options**: System (automatic), English, Spanish (Español)

## 🛠 Usage Methods

### Method 1: Direct AppLocalizations (Recommended for new code)

```dart
import 'package:medito/l10n/app_localizations.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Text(l10n.settings); // "Settings" or "Configuración"
  }
}
```

### Method 2: String Extension (Easy migration)

```dart
import 'package:medito/utils/string_extension.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Your existing StringConstants code:
    return Text(StringConstants.settings.localized(context));
    // ↑ Just add .localized(context) to any StringConstants usage
  }
}
```

### Method 3: Context Extension (Clean syntax)

```dart
import 'package:medito/utils/string_extension.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(context.localizedString('settings', StringConstants.settings));
  }
}
```

### Method 4: S Helper Class (Global access)

```dart
import 'package:medito/utils/string_extension.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    S.init(context); // Call once in build method
    
    return Text(S.settings); // Automatically localized with fallback
  }
}
```

## 🔄 Migration Strategy

### Phase 1: No Changes (Current state)
- All existing code works unchanged
- Spanish users see Spanish automatically
- Fallback to StringConstants works everywhere

### Phase 2: Gradual Migration (Optional)
- Replace `StringConstants.xyz` with `StringConstants.xyz.localized(context)`
- Or use `AppLocalizations.of(context)!.xyz` for new code
- Test that both English and Spanish work correctly

### Phase 3: Full Migration (Future)
- Eventually replace all StringConstants usage with AppLocalizations
- Remove StringConstants file when ready

## 🎯 Key Benefits

1. **Zero Breaking Changes**: Existing code continues to work
2. **Automatic Spanish Support**: Spanish users get localized UI immediately
3. **Flexible Migration**: Migrate at your own pace
4. **Type Safety**: All strings are type-safe and validated
5. **Full Coverage**: Every string in StringConstants is translated

## 📝 Adding New Strings

When adding new UI strings:

1. **Add to ARB files** (`lib/l10n/app_en.arb` and `lib/l10n/app_es.arb`)
2. **Run** `flutter gen-l10n` to regenerate localization files
3. **Use** `AppLocalizations.of(context)!.newString` in your code

Example:
```json
// app_en.arb
{
  "newFeatureTitle": "Amazing New Feature"
}

// app_es.arb  
{
  "newFeatureTitle": "Nueva Característica Increíble"
}
```

```dart
// In your widget
Text(AppLocalizations.of(context)!.newFeatureTitle)
```

## 🔧 Available Translations

All strings from `StringConstants` are now available in both English and Spanish:

- **Navigation**: Home, Explore, Downloads, Favorites, Settings, etc.
- **Actions**: Cancel, Delete, Share, Copy, Submit, Retry, etc.
- **Errors**: Connection errors, loading states, validation messages
- **Features**: Meditation stats, streaks, notifications, donations
- **Authentication**: Sign in, sign up, account management
- **Content**: Paths, tracks, packs, journal entries

## 🌟 Examples

### Before (works as-is):
```dart
AppBar(title: Text(StringConstants.settings))
```

### After (localized):
```dart
AppBar(title: Text(StringConstants.settings.localized(context)))
// or
AppBar(title: Text(AppLocalizations.of(context)!.settings))
```

### Language Selector (already implemented):
Go to Settings → Language to switch between:
- System (follows device language)
- English  
- Español

## 🚀 Testing

1. **Change device language** to Spanish → App should show in Spanish
2. **Use language selector** in Settings → Should switch immediately
3. **Test edge cases** → Fallbacks should work if localization fails

## 🎉 Result

- **Spanish users**: Get native Spanish experience automatically
- **All users**: Can manually control language preference  
- **Developers**: Can migrate gradually without breaking changes
- **Maintainers**: Single source of truth for all translations

The system is ready to use and all existing code continues to work while gaining Spanish localization support! 🚀

