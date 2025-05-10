import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mun09.got"
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
        applicationId = "com.mun09.got"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["mapsApiKey"] = getApiKey()
        manifestPlaceholders["mapId"] = getMapId()
        manifestPlaceholders["mapRendererMode"] = "latest" // 또는 "legacy"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}
dependencies {
    implementation("androidx.camera:camera-core:1.4.2")
    implementation("androidx.camera:camera-camera2:1.4.2")
    implementation("androidx.camera:camera-lifecycle:1.4.2")
    implementation("androidx.camera:camera-view:1.4.2")
    implementation("androidx.lifecycle:lifecycle-runtime:2.8.7")

    // Guava 의존성 추가
    implementation("com.google.guava:guava:33.0.0-android")

}

flutter {
    source = "../.."
}

// API 키를 local.properties 파일에서 가져오는 함수
fun getApiKey(): String {
    val propFile = rootProject.file("local.properties")
    return if (propFile.exists()) {
        val properties = Properties()
        propFile.inputStream().use {
            properties.load(it)
        }
        properties.getProperty("mapsApiKey") ?: "demo"
    } else {
        "demo"
    }
}

// Map ID 가져오는 함수 추가
fun getMapId(): String {
    val propFile = rootProject.file("local.properties")
    return if (propFile.exists()) {
        val properties = Properties()
        propFile.inputStream().use { properties.load(it) }
        properties.getProperty("mapId") ?: ""
    } else {
        ""
    }
}