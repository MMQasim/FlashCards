import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Upload-key credentials, kept outside version control. See
// android/key.properties.example and AGENTS.md for how to create the keystore.
// When the file is absent the release build falls back to the debug key so that
// `flutter run --release` keeps working for local testing; such a build cannot
// be uploaded to Play.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}
val hasUploadKey = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "com.ekko.deutschcards"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.ekko.deutschcards"
        // 23 is the floor for a dependable text-to-speech API surface and keeps
        // the app on devices that still receive security updates.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // The app ships every string it needs; no other locales to split on.
        resourceConfigurations += listOf("en")
    }

    signingConfigs {
        if (hasUploadKey) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasUploadKey) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "key.properties not found - signing the release build with the " +
                        "debug key. This build cannot be uploaded to Google Play."
                )
                signingConfigs.getByName("debug")
            }

            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    // content.db is deliberately left compressed in the package: it shrinks
    // from 13 MB to about 2 MB, and the app copies it out to app storage on
    // first launch anyway, so nothing is gained by storing it uncompressed.

    bundle {
        language {
            // Keep all languages in the base module: the app is English-only UI
            // but the TTS locale must not be stripped per-install.
            enableSplit = false
        }
    }
}

flutter {
    source = "../.."
}
