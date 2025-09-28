plugins {
    id("com.android.application")
    // FlutterFire (Google Services) en Kotlin DSL va aquí:
    id("com.google.gms.google-services")
    id("kotlin-android")
    // El plugin de Flutter debe ir al final:
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

android {
    // Cambia esto por tu paquete real y úsalo igual en Firebase:
    namespace = "com.example.proyectomovil"

    // Usar las versiones que define Flutter (están bien):
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        // Debe coincidir con Firebase (google-services.json):
        applicationId = "com.example.proyectomovil"
        minSdk = maxOf(23, flutter.minSdkVersion) // fuerza 23 si fuera menor
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        multiDexEnabled = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    // Firma release desde key.properties (si existe)
    val keystoreProperties = Properties()
    val keystoreFile = rootProject.file("key.properties")
    if (keystoreFile.exists()) {
        keystoreProperties.load(FileInputStream(keystoreFile))
    }

    signingConfigs {
        // Usa la release firmada si tienes key.properties; si no, se puede omitir
        create("release") {
            if (keystoreFile.exists()) {
                storeFile = file(keystoreProperties["storeFile"] ?: "")
                storePassword = keystoreProperties["storePassword"] as String?
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
            }
        }
    }

    buildTypes {
        getByName("debug") {
            // sin cambios
        }
        getByName("release") {
            // Si NO tienes key.properties, quita la línea de signing y compilará con debug key
            signingConfig = if (keystoreFile.exists()) signingConfigs.getByName("release")
                            else signingConfigs.getByName("debug")

            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android.txt"),
                file("proguard-rules.pro")
            )
        }
    }

    packaging {
        // Ayuda a evitar conflictos de licencias/meta
        resources {
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/LICENSE/*",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt",
                "META-INF/NOTICE/*"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Recomendado con Firebase/varios plugins
    implementation("androidx.multidex:multidex:2.0.1")
}
