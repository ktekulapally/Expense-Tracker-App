# Flutter & ML Kit Proguard Rules
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**
-dontwarn com.google_mlkit_text_recognition.**

-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }

# Prevent obfuscation of models
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}
