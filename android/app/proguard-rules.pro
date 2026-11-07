# R8 is enabled for release builds. Flutter's own plugin contributes the rules
# for the engine; these cover this app's plugins.

# sqflite talks to SQLite through reflection-free JNI, but the Android SQLite
# support classes are referenced dynamically by the plugin.
-keep class com.tekartik.sqflite.** { *; }

# flutter_tts binds to the platform TextToSpeech service by name.
-keep class com.tundralabs.fluttertts.** { *; }
-keep class android.speech.tts.** { *; }

# Flutter's deferred components and Play Core are referenced by the embedding
# even when the app does not use dynamic feature delivery.
-dontwarn com.google.android.play.core.**
