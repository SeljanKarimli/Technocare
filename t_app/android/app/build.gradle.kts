import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val codemagicKeystorePath = System.getenv("CM_KEYSTORE_PATH")
val hasCodemagicSigning = !codemagicKeystorePath.isNullOrBlank()
val hasLocalSigning = keystorePropertiesFile.exists()
val hasReleaseSigning = hasCodemagicSigning || hasLocalSigning

android {
    namespace = "com.technocare.technocare"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }
    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                if (hasCodemagicSigning) {
                    storeFile = file(requireNotNull(codemagicKeystorePath))
                    storePassword = requireNotNull(System.getenv("CM_KEYSTORE_PASSWORD")) {
                        "CM_KEYSTORE_PASSWORD is required for Codemagic release signing."
                    }
                    keyAlias = requireNotNull(System.getenv("CM_KEY_ALIAS")) {
                        "CM_KEY_ALIAS is required for Codemagic release signing."
                    }
                    keyPassword = requireNotNull(System.getenv("CM_KEY_PASSWORD")) {
                        "CM_KEY_PASSWORD is required for Codemagic release signing."
                    }
                } else {
                    keyAlias = keystoreProperties.getProperty("keyAlias")
                    keyPassword = keystoreProperties.getProperty("keyPassword")
                    storeFile = file(keystoreProperties.getProperty("storeFile"))
                    storePassword = keystoreProperties.getProperty("storePassword")
                }
            }
        }
    }
    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.technocare.technocare"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
