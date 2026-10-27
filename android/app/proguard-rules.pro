# flutter_local_notifications — no renombrar receivers ni plugin
-keep class com.dexterous.** { *; }

# Firebase — no renombrar clases de inicialización
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Kotlin coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
