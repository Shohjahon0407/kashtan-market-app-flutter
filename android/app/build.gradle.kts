import java.util.Properties
import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase config bor buildda qo'llanadi, local/configsiz build esa buzilmaydi.
    id("com.google.gms.google-services") apply false
    id("com.google.firebase.crashlytics") apply false
}

// Play upload-kaliti `android/key.properties` dan o'qiladi (gitda YO'Q).
// Debug/profile buildlar kalitsiz ishlaydi, ammo release APK/AAB hech qachon
// debug kalitga tushmaydi: kalit yo'q bo'lsa packaging darhol to'xtaydi.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val releaseSigningKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val hasReleaseKeystore = releaseSigningKeys.all {
    !keystoreProperties.getProperty(it).isNullOrBlank()
}

val requestedReleasePackage = gradle.startParameter.taskNames.any { task ->
    val normalized = task.lowercase()
    normalized.contains("release") &&
        (normalized.contains("assemble") ||
            normalized.contains("bundle") ||
            normalized.contains("package"))
}

fun decodedDartDefines(): Map<String, String> {
    val raw = providers.gradleProperty("dart-defines").orNull.orEmpty()
    if (raw.isBlank()) return emptyMap()
    return raw.split(',').mapNotNull { encoded ->
        runCatching {
            String(Base64.getDecoder().decode(encoded), Charsets.UTF_8)
        }.getOrNull()?.let { value ->
            val separator = value.indexOf('=')
            if (separator <= 0) null
            else value.substring(0, separator) to value.substring(separator + 1)
        }
    }.toMap()
}

if (requestedReleasePackage && !hasReleaseKeystore) {
    throw GradleException(
        "Release signing is not configured. Add all four values to " +
            "android/key.properties; debug signing is forbidden for release builds.",
    )
}

if (requestedReleasePackage) {
    val dartDefines = decodedDartDefines()
    val appFlavor = dartDefines["APP_FLAVOR"]?.lowercase() ?: "prod"
    val mapboxToken = dartDefines["MAPBOX_ACCESS_TOKEN"].orEmpty()
    // ALLOW_OSM_TILES=true — VAQTINCHA ochiq istisno: token hali olinmagan
    // bo'lsa ilova OSM zaxirasida quriladi (foydalanuvchi ko'payguncha
    // Mapbox tokeni olinishi shart — OSM ommaviy ilovalarni bloklaydi).
    val allowOsmTiles = dartDefines["ALLOW_OSM_TILES"]?.lowercase() == "true"
    val hasMapboxToken = mapboxToken.startsWith("pk.") && mapboxToken.length >= 20
    if (appFlavor == "prod" && !hasMapboxToken && !allowOsmTiles) {
        throw GradleException(
            "Production release requires a public MAPBOX_ACCESS_TOKEN (pk.*) " +
                "provided with --dart-define (or ALLOW_OSM_TILES=true for the " +
                "temporary OSM fallback).",
        )
    }
    if (appFlavor == "prod" && !hasMapboxToken && allowOsmTiles) {
        logger.warn(
            "WARNING: building WITHOUT Mapbox token — public OSM tiles in use " +
                "(temporary; not suitable at scale).",
        )
    }
}

android {
    namespace = "uz.beshkashtan.customer"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications 22.x buni TALAB qiladi (eski Android
        // versiyalarida java.time API'laridan foydalanadi).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "uz.beshkashtan.customer"
        // Flutter 3.44 da default = 24, firebase_messaging 16.x esa 23 talab
        // qiladi — shuning uchun alohida override kerak emas. (Flutter gradle
        // plagini bu qatorni avtomatik boshqaradi, qo'lda o'zgartirmang.)
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        resourceConfigurations += listOf("uz", "ru", "en")
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    // SMS OTP autofill (SMS Retriever + SMS User Consent).
    // RECEIVE_SMS/READ_SMS ruxsatlari TALAB QILINMAYDI — xabarni Play
    // Services yetkazadi, demak Play'ning SMS deklaratsiyasi ham kerak emas.
    implementation("com.google.android.gms:play-services-auth-api-phone:18.2.0")
}

flutter {
    source = "../.."
}

if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
    apply(plugin = "com.google.firebase.crashlytics")
}
