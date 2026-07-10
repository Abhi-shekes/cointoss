# Flutter core
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# audioplayers
-keep class xyz.luan.audioplayers.** { *; }
-dontwarn xyz.luan.audioplayers.**

# vibration
-keep class com.benjaminabel.vibration.** { *; }

# Keep annotations / native method names
-keepattributes *Annotation*
-keepclasseswithmembernames class * {
    native <methods>;
}
