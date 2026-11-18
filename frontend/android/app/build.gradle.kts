import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val releaseSigning = Properties().apply {
    val propertiesFile = rootProject.file("key.properties")
    if (propertiesFile.exists()) propertiesFile.inputStream().use { load(it) }
}
val buildingRelease = gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }
if (buildingRelease) {
    check(releaseSigning.keys.containsAll(listOf("storeFile", "storePassword", "keyAlias", "keyPassword"))) {
        "Release signing requires android/key.properties"
    }
    check(file("src/release/google-services.json").exists()) { "Release Firebase configuration is required" }
}

android {
    namespace = "com.dsu.notifier"
    compileSdk = 36
    ndkVersion = "28.2.13676358"
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
    defaultConfig {
        applicationId = "com.dsu.notifier"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    signingConfigs {
        create("release") {
            if (releaseSigning.isNotEmpty()) {
                storeFile = rootProject.file(releaseSigning.getProperty("storeFile"))
                storePassword = releaseSigning.getProperty("storePassword")
                keyAlias = releaseSigning.getProperty("keyAlias")
                keyPassword = releaseSigning.getProperty("keyPassword")
            }
        }
    }
    buildTypes { release { signingConfig = signingConfigs.getByName("release") } }
}

kotlin { jvmToolchain(17) }
flutter { source = "../.." }
