plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "app.bantudigital.dompet_digital"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Enable core library desugaring for libraries that require Java 8+ APIs
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "app.bantudigital.dompet_digital"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required for core library desugaring (e.g. flutter_local_notifications)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")
}

tasks.whenTaskAdded {
    if (name == "assembleRelease") {
        finalizedBy("renameReleaseApk")
    }
}

tasks.register("renameReleaseApk") {
    doLast {
        val candidates = listOf(
            file("$buildDir/outputs/flutter-apk"),
            file("$buildDir/outputs/apk/release")
        )
        for (apkDir in candidates) {
            val releaseApk = File(apkDir, "app-release.apk")
            if (releaseApk.exists()) {
                val destDir = file("$buildDir/outputs/flutter-apk")
                destDir.mkdirs()
                val namedApk = File(destDir, "DompetDigital-v${android.defaultConfig.versionName}.apk")
                releaseApk.copyTo(namedApk, overwrite = true)
            }
        }
    }
}