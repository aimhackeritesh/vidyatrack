# Flutter engine + embedding
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Plugins that use reflection / native bridges
-keep class androidx.lifecycle.** { *; }

# Keep annotations & signatures used by JSON/reflection paths
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod

# Suppress warnings for optional desugaring classes
-dontwarn java.lang.invoke.**
