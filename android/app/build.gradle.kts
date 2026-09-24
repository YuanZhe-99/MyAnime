import java.util.Properties

plugins {
    id("com.android.application")
    // Built-in Kotlin: the app no longer applies the Kotlin Gradle Plugin
    // itself (Flutter/AGP provide Kotlin support). The KGP version stays
    // declared in settings.gradle.kts because several Flutter plugins still
    // apply KGP and resolve it from there.
    // The Flutter Gradle Plugin must be applied after the Android plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.yuanzhe.my_anime"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.yuanzhe.my_anime"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // 26, not flutter.minSdkVersion (24): the ML Kit GenAI library below
        // requires API 26. Nothing else in the app does. Approved for 1.6.0,
        // which drops Android 7.0 and 7.1. See doc/en-us/on-device-ai.md.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"]!!)
                storePassword = keystoreProperties["storePassword"] as String?
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // Additive to the rules the libraries and AGP contribute. The file
            // exists only for ML Kit GenAI, which R8 otherwise shrinks into a
            // runtime failure that looks like an unsupported device. See the
            // comments in proguard-rules.pro.
            proguardFiles("proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // On-device generative AI through Android AICore (Gemini Nano), used
    // only when the user turns on "Use on-device AI". A beta API with no
    // deprecation policy, so the version is exact rather than dynamic.
    // 1.0.0-beta4 is the first client that can ask for a named model variant
    // (ModelReleaseStage x ModelPreference) and that returns a status on a
    // Gemini Nano v4 device instead of throwing. Which model a device serves
    // is decided at run time by GenAiChannel.probePrompt, never here.
    // Checked against the Google Maven index on 2026-09-24; see
    // doc/en-us/on-device-ai.md.
    implementation("com.google.mlkit:genai-prompt:1.0.0-beta4")
    // The Prompt API suspends and returns a Flow; the coroutine runtime is
    // not pulled in by the Flutter Android embedding, so it is declared here.
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
}

// Built-in Kotlin migration: align the Kotlin jvmTarget with the Java 17
// compileOptions above. Without this, Kotlin defaults to the running JDK's
// target and the build fails with an Inconsistent JVM Target error.
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}
