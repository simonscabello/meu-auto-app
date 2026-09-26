import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "br.com.meuauto.meu_auto"
    // flutter_secure_storage 11 compiles against Android SDK 37.
    compileSdk = maxOf(flutter.compileSdkVersion, 37)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications uses java.time, which only exists from
        // Android 8; desugaring rewrites those calls for older phones. Without it
        // the build fails at checkReleaseAarMetadata, and the message does not
        // say which dependency asked.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "br.com.meuauto.meu_auto"
        // flutter_secure_storage requires API 23+.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Upload key, read from android/key.properties, which is gitignored and
    // never committed. See docs/RODANDO.md for how to generate the keystore.
    //
    // The file is deliberately optional: without it `flutter build apk
    // --release` still produces an installable APK signed with the debug key,
    // which is what you want for testing a release build on your own phone.
    // What it is not is publishable - Play rejects a debug-signed upload - so
    // the build prints which key it used rather than leaving it a guess.
    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")
    val hasUploadKey = keystorePropertiesFile.exists()
    if (hasUploadKey) {
        keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
    }

    signingConfigs {
        if (hasUploadKey) {
            create("upload") {
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
                signingConfigs.getByName("upload")
            } else {
                logger.lifecycle(
                    "meu_auto: android/key.properties nao encontrado: assinando o " +
                        "release com a chave de debug. Nao publicavel."
                )
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

// Push reminders need the Firebase project's google-services.json in this
// folder. It is not a secret and is committed once it exists; until then the
// plugin is not applied, the app builds and runs, and push simply stays off
// (PushService degrades in silence). Applying it unconditionally would fail
// every build — CI included — for want of a file.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.lifecycle(
        "meu_auto: android/app/google-services.json nao encontrado: push desligado neste build."
    )
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
