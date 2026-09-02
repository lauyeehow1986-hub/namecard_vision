# google_mlkit_text_recognition bundles only the Latin script model in this app,
# but its Java initialize() references the Chinese/Devanagari/Japanese/Korean
# recognizer option classes too. Those artifacts aren't on the classpath, so R8
# would fail the release build on the missing classes. We never invoke them
# (TextRecognitionScript.latin only), so it's safe to tell R8 to ignore them.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Keep ML Kit's own classes intact.
-keep class com.google.mlkit.** { *; }
