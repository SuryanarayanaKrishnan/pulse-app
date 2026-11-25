# ML Kit text recognition: the Flutter plugin references the optional script
# recognisers (Chinese, Devanagari, Japanese, Korean). Pulse bundles only the
# Latin model, so R8 must not fail on the absent classes.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
