plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter plugin'i
    id("dev.flutter.flutter-gradle-plugin")
    // Google Services (Firebase için)
    id("com.google.gms.google-services")
}

// --- 1. local.properties Dosyasını Okuma Mantığı (YENİ EKLENDİ) ---
val localProperties = java.util.Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { stream ->
        localProperties.load(stream)
    }
}
// API Key'i çekiyoruz, eğer yoksa boş string döner
val mapsApiKey = localProperties.getProperty("MAPS_API_KEY") ?: ""

android {
    namespace = "com.example.ertu_mobile_uni"
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
        // Application ID
        applicationId = "com.example.ertu_mobile_uni"
        
        // ÖNEMLİ GÜNCELLEME:
        // Firebase kullanıldığı için minSdk'yı manuel olarak 21'e çekiyoruz.
        minSdk = flutter.minSdkVersion
        
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // --- 2. Manifest'e Gönderme İşlemi (YENİ EKLENDİ) ---
        // AndroidManifest.xml içinde ${mapsApiKey} olarak kullanılacak
        manifestPlaceholders["mapsApiKey"] = mapsApiKey
    }

    buildTypes {
        release {
            // Release modunda şimdilik debug imzasını kullanıyoruz
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}