# Menjaga metadata Generic Type dan Annotation agar Gson tidak crash
-keepattributes Signature
-keepattributes *Annotation*

# Menjaga library Gson
-keep class com.google.gson.** { *; }

# Menjaga library flutter_local_notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class androidx.work.** { *; }

