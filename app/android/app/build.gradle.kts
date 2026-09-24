import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Datos de la clave de firma. Viven en android/key.properties, que está
// en .gitignore junto con el keystore: ni la contraseña ni la clave
// entran nunca al repositorio.
//
// Si el archivo no existe —por ejemplo en una máquina recién clonada—
// el build de debug sigue funcionando y solo falla el de release, con
// un mensaje que explica qué falta.
val clavesRelease = Properties().apply {
    val archivo = rootProject.file("key.properties")
    if (archivo.exists()) archivo.inputStream().use { load(it) }
}
val hayFirmaRelease = clavesRelease.getProperty("storeFile") != null

android {
    namespace = "com.netrcd.becaya"
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
        // Identidad de la app en Google Play. NO se puede cambiar nunca
        // después de publicar: cambiarlo crea una app distinta y los
        // usuarios instalados se quedan sin actualizaciones.
        applicationId = "com.netrcd.becaya"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Ambos salen de `version:` en pubspec.yaml (1.0.0+1):
        // versionName = "1.0.0" es lo que ve el usuario,
        // versionCode = 1 es el número interno, que solo puede subir.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hayFirmaRelease) {
            create("release") {
                storeFile = file(clavesRelease.getProperty("storeFile"))
                storePassword = clavesRelease.getProperty("storePassword")
                keyAlias = clavesRelease.getProperty("keyAlias")
                keyPassword = clavesRelease.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (!hayFirmaRelease) {
                // Antes esto firmaba con la clave de debug. Un AAB así
                // lo rechaza Play Console, pero recién al subirlo: es
                // mejor fallar aquí, con una explicación.
                throw GradleException(
                    "Falta android/key.properties: sin él no se puede firmar el release. " +
                    "Ver docs/publicar.md."
                )
            }
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
