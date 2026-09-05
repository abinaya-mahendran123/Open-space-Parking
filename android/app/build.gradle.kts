plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

val localProperties = Properties().apply {
    val localPropertiesFile = rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        localPropertiesFile.inputStream().use { load(it) }
    }
}
val mapsApiKey: String = localProperties.getProperty("MAPS_API_KEY") ?: ""

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists().also { exists ->
    if (exists) {
        keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
    }
}

android {
    namespace = "com.estar.openspaceparking"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.estar.openspaceparking"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Optional: put MAPS_API_KEY=AIza... in android/local.properties
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // Local/dev fallback until android/key.properties + upload-keystore.jks exist.
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_11)
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}

// android/build.gradle.kts sends Gradle outputs to %LOCALAPPDATA% so OneDrive
// does not lock merge* tasks. Flutter still looks for the APK under
// <project>/build/app/outputs/flutter-apk/.
fun copyApksForFlutterTool() {
    val dest = rootProject.projectDir.resolve("../build/app/outputs/flutter-apk")
    dest.mkdirs()
    val sources =
        listOf(
            layout.buildDirectory.get().asFile.resolve("outputs/flutter-apk"),
            layout.buildDirectory.get().asFile.resolve("outputs/apk/debug"),
            layout.buildDirectory.get().asFile.resolve("outputs/apk/release"),
        )
    sources.filter { it.isDirectory }.forEach { dir ->
        dir.listFiles()?.filter { it.extension == "apk" }?.forEach { apk ->
            apk.copyTo(dest.resolve(apk.name), overwrite = true)
        }
    }
}

afterEvaluate {
    tasks.matching { it.name.startsWith("assemble") }.configureEach {
        doLast { copyApksForFlutterTool() }
    }
}
