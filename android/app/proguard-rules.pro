## Gson rules
# Gson uses generic type information stored in a class file when working with fields. Proguard
# removes such information by default, so configure it to keep all of it.
-keepattributes Signature

# For using GSON @Expose annotation
-keepattributes *Annotation*

# Gson specific classes
-dontwarn sun.misc.**
#-keep class com.google.gson.stream.** { *; }

# Prevent proguard from stripping interface information from TypeAdapter, TypeAdapterFactory,
# JsonSerializer, JsonDeserializer instances (so they can be used in @JsonAdapter)
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Prevent R8 from leaving Data object members always null
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# Retain generic signatures of TypeToken and its subclasses with R8 version 3.0 and higher.
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

# Keep j$.util.concurrent classes
-keep class j$.util.concurrent.** { *; }

# Keep enum classes
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);     
}

# Keep j$.util statistics classes
-keep class j$.util.IntSummaryStatistics { *; }
-keep class j$.util.LongSummaryStatistics { *; }
-keep class j$.util.DoubleSummaryStatistics { *; }

# Stripe rules
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider
# Keep Stripe classes
-keep class com.stripe.** { *; }

# Keep Flutter core error class
-keep class io.flutter.plugin.common.FlutterError { *; }

# Handle Kotlin version compatibility issues
-dontwarn kotlin.**
-dontwarn kotlinx.**
-dontwarn kotlin.Metadata

# Handle Google Play Services Kotlin compatibility
-dontwarn com.google.android.gms.**
-dontwarn com.google.firebase.**

# Ignore all warnings to prevent build failure
-ignorewarnings