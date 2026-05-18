import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    // PowerShell Set-Content UTF8 adds a BOM; strip it so storePassword parses correctly.
    val text = keystorePropertiesFile.readText(Charsets.UTF_8).trimStart('\uFEFF')
    keystoreProperties.load(text.byteInputStream(Charsets.UTF_8))
}

fun Properties.requireProperty(name: String): String =
    getProperty(name) ?: error("key.properties is missing or invalid: $name")

android {
    namespace = "com.example.schroedinger_chess"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.schroedinger_chess"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties.requireProperty("keyAlias")
                keyPassword = keystoreProperties.requireProperty("keyPassword")
                storePassword = keystoreProperties.requireProperty("storePassword")
                storeFile = rootProject.file(keystoreProperties.requireProperty("storeFile"))
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
        }
    }
}

flutter {
    source = "../.."
}

// Apply Google Services only when google-services.json is present.
// Add the file (via `flutterfire configure`) to enable online multiplayer.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}
