plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
}

val releaseStoreFile = System.getenv("BSH_SIGNING_STORE_FILE")
val releaseStorePassword = System.getenv("BSH_SIGNING_STORE_PASSWORD")
val releaseKeyAlias = System.getenv("BSH_SIGNING_KEY_ALIAS")
val releaseKeyPassword = System.getenv("BSH_SIGNING_KEY_PASSWORD")
val releaseSigningConfigured = listOf(
    releaseStoreFile, releaseStorePassword, releaseKeyAlias, releaseKeyPassword
).all { !it.isNullOrBlank() }

android {
    namespace = "com.rogueassassin.bsh"
    compileSdk = 37

    defaultConfig {
        applicationId = "com.rogueassassin.bsh"
        minSdk = 31
        targetSdk = 37
        versionCode = 1900
        versionName = "1.9.0"
    }

    signingConfigs {
        if (releaseSigningConfigured) {
            create("bshRelease") {
                storeFile = file(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
                enableV1Signing = true
                enableV2Signing = true
                enableV3Signing = true
                enableV4Signing = true
            }
        }
    }

    buildTypes {
        debug {
            if (releaseSigningConfigured) signingConfig = signingConfigs.getByName("bshRelease")
        }
        release {
            isMinifyEnabled = false
            if (releaseSigningConfigured) signingConfig = signingConfigs.getByName("bshRelease")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    buildFeatures { compose = true; buildConfig = true }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

tasks.register("verifyBshSigningConfigured") {
    doLast {
        check(releaseSigningConfigured) {
            "Persistent BSH signing is not configured. Release/package builds must provide the BSH signing environment."
        }
    }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2026.09.00")
    implementation(composeBom)
    implementation("androidx.activity:activity-compose:1.13.0")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.11.0")
    debugImplementation("androidx.compose.ui:ui-tooling")
}
