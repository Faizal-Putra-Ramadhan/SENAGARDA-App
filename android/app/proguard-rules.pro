## Ignore Missing Warnings Global (R8)
-ignorewarnings

## Ignore Play Core missing classes
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

## Flutter Keep Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.autofill.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.domains.** { *; }
-keep class io.flutter.plugin.editing.** { *; }
-keep class io.flutter.plugin.common.** { *; }
-keep class io.flutter.header.** { *; }
-keep class io.flutter.userpreferences.** { *; }
-keep class io.flutter.injector.** { *; }
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }