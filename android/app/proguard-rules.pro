# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Suppress missing Play Core classes (deferred components not used)
-dontwarn com.google.android.play.core.**

# audioplayers
-keep class xyz.luan.audioplayers.** { *; }

# camera
-keep class io.flutter.plugins.camera.** { *; }

# shared_preferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# Keep all native method names
-keepclasseswithmembernames class * {
    native <methods>;
}
