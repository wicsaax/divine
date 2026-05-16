import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// 读 key.properties (本地手填) 或环境变量 (CI 注入).
// 优先级: 环境变量 > key.properties > 无 (回退 debug)
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun resolveKey(envName: String, propName: String): String? {
    val env = System.getenv(envName)
    if (!env.isNullOrEmpty()) return env
    val prop = keystoreProperties.getProperty(propName)
    if (!prop.isNullOrEmpty()) return prop
    return null
}

val releaseKeystorePath = resolveKey("DIVINE_KEYSTORE_PATH", "storeFile")
val releaseKeystorePassword = resolveKey("DIVINE_KEYSTORE_PASSWORD", "storePassword")
val releaseKeyAlias = resolveKey("DIVINE_KEY_ALIAS", "keyAlias")
val releaseKeyPassword = resolveKey("DIVINE_KEY_PASSWORD", "keyPassword")

val hasReleaseSigning = releaseKeystorePath != null &&
        releaseKeystorePassword != null &&
        releaseKeyAlias != null &&
        releaseKeyPassword != null &&
        file(releaseKeystorePath).exists()

android {
    namespace = "com.divine.divine"
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
        applicationId = "com.divine.divine"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    if (hasReleaseSigning) {
        signingConfigs {
            create("release") {
                storeFile = file(releaseKeystorePath!!)
                storePassword = releaseKeystorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // 没配 release signing → 回退 debug 签名 (开发用)
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
