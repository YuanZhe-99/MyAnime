# R8 rules for the release build.
#
# Only one thing needs them: the ML Kit GenAI client library behind Android
# AICore (on-device AI, off by default). These rules are copied from
# MyNihongo!!!!!, where both failures below were found on a real Pixel 10 in
# release builds; the debug build, which is not minified, worked perfectly in
# both cases. Without the rules the failure appears only in a release build on
# a real device, and it looks like "this device does not support AI" rather
# than like a build problem.
#
# 1. R8 shrinking ML Kit's shared SDK internals turned every AICore call into a
#    NullPointerException thrown from
#    `com.google.mlkit.common.sdkinternal.LazyInstanceMap`, so keeping only
#    `com.google.mlkit.genai.**` is not enough.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-dontwarn com.google.mlkit.**

# 2. Tapping Download threw NoSuchMethodError for the synthetic
#    `Job.cancel$default` bridge, which ML Kit's dexed code calls and this app
#    never does, so R8 removed it. The bridges are generated, so the package is
#    kept whole rather than method by method.
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**
