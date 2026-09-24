/* ============================================================
   firebase_options.dart — MARCADOR, todavía sin configurar
   ------------------------------------------------------------
   Este archivo lo GENERA la herramienta flutterfire. Lo que hay
   aquí es un marcador para que la app compile y funcione antes
   de que exista el proyecto de Firebase.

   Para reemplazarlo de verdad:

     dart pub global activate flutterfire_cli
     flutterfire configure

   Eso lo sobrescribe entero con las claves del proyecto. No
   edites los valores a mano.

   MIENTRAS TANTO la app funciona igual: el catálogo se ve, las
   convocatorias se guardan en el teléfono y lo único que falta
   es la sincronización entre dispositivos, que se anuncia como
   no disponible en vez de fallar.

   Nota sobre estas claves cuando existan: NO son secretas. Las
   claves de Firebase para cliente van dentro del APK y cualquiera
   puede leerlas. Lo que protege los datos son las reglas de
   seguridad de Firestore, no el secreto de la clave.
   ============================================================ */

import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  /// Lanza a propósito mientras no esté configurado.
  ///
  /// Sesion.iniciar() atrapa este error y deja la app en modo local:
  /// nada se rompe, solo no hay cuenta. Cuando flutterfire genere este
  /// archivo, devolverá las opciones reales y el modo cuenta se activa
  /// solo, sin tocar ninguna otra línea del proyecto.
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
        'Firebase no está configurado todavía. Corre `flutterfire configure` '
        'en la carpeta app/. Ver docs/cuentas.md.',
      );
}
