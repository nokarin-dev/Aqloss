# Flutter core
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
-keep class * extends io.flutter.embedding.engine.plugins.FlutterPlugin { *; }
-dontwarn io.flutter.embedding.**

# Flutter Pigeon
-keep class ** implements dev.flutter.pigeon.** { *; }
-keepclassmembers class ** implements dev.flutter.pigeon.** { *; }

# shared_preferences_android
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keepclassmembers class io.flutter.plugins.sharedpreferences.** { *; }

# SharedPreferences Pigeon API
-keep class dev.flutter.pigeon.shared_preferences_android.** { *; }
-keepclassmembers class dev.flutter.pigeon.shared_preferences_android.** { *; }

# Pigeon interface
-keep interface dev.flutter.pigeon.** { *; }
-keepclassmembers interface dev.flutter.pigeon.** { *; }

# Pigeon implements
-keep class * implements dev.flutter.pigeon.** { *; }

# file_picker
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Kotlin
-keep class kotlin.** { *; }
-dontwarn kotlin.**