plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.pulse.pulse"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications needs java.time on older Android.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.pulse.pulse"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Beta key for friends-and-family builds so every CI build installs over the previous
        // one. Never committed: CI writes android/app/pulse-beta.keystore from the
        // ANDROID_KEYSTORE_B64 secret and passes ANDROID_KEYSTORE_PASSWORD. Without them
        // (local builds, fork pull requests) the debug key is used.
        val betaStore = file("pulse-beta.keystore")
        val betaPassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
        if (betaStore.exists() && !betaPassword.isNullOrEmpty()) {
            create("beta") {
                storeFile = betaStore
                storePassword = betaPassword
                keyAlias = "pulsebeta"
                keyPassword = betaPassword
            }
        }
    }

    buildTypes {
        release {
            // Beta key when present (CI), else the debug keys so `flutter run --release` works.
            signingConfig = signingConfigs.findByName("beta") ?: signingConfigs.getByName("debug")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
