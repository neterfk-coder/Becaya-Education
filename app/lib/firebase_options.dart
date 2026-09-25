/* ============================================================
   firebase_options.dart — claves del proyecto de Firebase
   ------------------------------------------------------------
   Proyecto: becaya-c2931

   Normalmente lo genera `flutterfire configure`. Aquí está
   escrito a partir de android/app/google-services.json, porque
   la CLI de Firebase está autenticada con una cuenta que todavía
   no tiene permiso sobre este proyecto. Los valores son los
   mismos que habría generado la herramienta.

   Si algún día vuelves a correr `flutterfire configure`, este
   archivo se sobrescribe entero y no pasa nada: la forma de la
   clase es la que espera el resto del código.

   ESTAS CLAVES NO SON SECRETAS. Van dentro del APK y cualquiera
   puede extraerlas; Google las documenta como públicas. Lo que
   protege los datos son las reglas de seguridad de Firestore
   —que solo dejan a cada usuario tocar su propio documento— y
   no el secreto de la clave. Por eso el archivo va a git.

   Solo está configurado Android. iOS necesitará su propia app
   en el proyecto de Firebase antes de poder compilarse con
   cuentas.
   ============================================================ */

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'becaya no tiene app web en Firebase: la web usa el catálogo '
        'público, sin cuentas.',
      );
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => throw UnsupportedError(
          'Falta registrar la app de iOS en el proyecto de Firebase. '
          'Corre `flutterfire configure` cuando exista.',
        ),
      _ => throw UnsupportedError(
          'becaya solo tiene Firebase configurado para Android.',
        ),
    };
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDlfWVmntEV6NFX9VlTelT-uTuhCHIUDXI',
    appId: '1:1027111709320:android:fd89b17c6f5e3155facd3d',
    messagingSenderId: '1027111709320',
    projectId: 'becaya-c2931',
    databaseURL: 'https://becaya-c2931-default-rtdb.firebaseio.com',
    storageBucket: 'becaya-c2931.firebasestorage.app',
  );

}