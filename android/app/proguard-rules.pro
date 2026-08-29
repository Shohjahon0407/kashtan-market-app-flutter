# Flutter engine o'zi kerakli qoidalarni qo'shadi; bu yerda faqat plagin-maxsuslari.

# flutter_local_notifications — GSON orqali schedule ma'lumotini serialize qiladi
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-dontwarn com.google.gson.**

# Firebase / FCM
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# R8 ba'zan Play Core stub'lariga shikoyat qiladi (deferred components ishlatmaymiz)
-dontwarn com.google.android.play.core.**
