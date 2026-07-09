import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services") version "4.4.4" apply false
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

apply(plugin = "com.google.gms.google-services")

android {
    namespace = "dev.hyderali.DCS_user"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }
    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.hyderali.DCS_user"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Modified by Jayant Pandit on 2026-05-18 20:25:00
    // Reason: Proper release signing with the original May 6th dcs-user key to allow direct app updates
    signingConfigs {
        create("release") {
            keyAlias = project.findProperty("DCS_USER_RELEASE_KEY_ALIAS") as String? ?: "dcs-user"
            keyPassword = project.findProperty("DCS_USER_RELEASE_KEY_PASSWORD") as String? ?: "dadacabsuser2024"
            storeFile = file(project.findProperty("DCS_USER_RELEASE_KEYSTORE") as String? ?: "../../../keys/dcs-user-release.keystore")
            storePassword = project.findProperty("DCS_USER_RELEASE_STORE_PASSWORD") as String? ?: "dadacabsuser2024"
        }
    }

    buildTypes {
        release {
            // Enable obfuscation and shrinking for production security
            isMinifyEnabled = true
            isShrinkResources = true
            
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            
            // Use release signing configuration
            signingConfig = signingConfigs.getByName("release")
        }
        debug {
            // Disable obfuscation for debug builds
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // Custom APK output filename
    android.applicationVariants.all {
        val variant = this
        variant.outputs.all {
            val output = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            output.outputFileName = "DadaCabsRider.apk"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

tasks.withType<KotlinCompile>().configureEach {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}
