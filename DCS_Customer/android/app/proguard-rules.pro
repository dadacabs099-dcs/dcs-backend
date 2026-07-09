# Modified by Jayant Pandit on 2026-05-18 19:47:00
# Reason: Prevent OEM auto-block by keeping Firebase, Firestore, and Flutter classes intact during minification

# ── Flutter ──────────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ── Firebase Core ─────────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ── Firestore ─────────────────────────────────────────────────────────────────
-keep class com.google.firestore.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# ── Firebase Auth ─────────────────────────────────────────────────────────────
-keep class com.google.firebase.auth.** { *; }

# ── Firebase Messaging ────────────────────────────────────────────────────────
-keep class com.google.firebase.messaging.** { *; }

# ── Firebase Storage ──────────────────────────────────────────────────────────
-keep class com.google.firebase.storage.** { *; }

# ── Google Maps ───────────────────────────────────────────────────────────────
-keep class com.google.android.libraries.maps.** { *; }
-keep class com.google.maps.android.** { *; }

# ── OkHttp (used by Firebase) ─────────────────────────────────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }

# ── General Android ───────────────────────────────────────────────────────────
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
-keep class androidx.** { *; }
-dontwarn androidx.**
