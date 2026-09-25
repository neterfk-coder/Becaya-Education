/* ============================================================
   version.dart — la versión que se muestra al usuario
   ------------------------------------------------------------
   Está aquí a mano, y no leída de pubspec.yaml en tiempo de
   ejecución, para no arrastrar una dependencia nativa entera
   (package_info_plus) solo por pintar un texto.

   El riesgo evidente de copiar un número a mano es que se quede
   viejo. Por eso hay una prueba —version_test.dart— que lee
   pubspec.yaml y falla si los dos dejan de coincidir.
   ============================================================ */

/// Lo que ve el usuario. Debe coincidir con la parte anterior al "+"
/// de `version:` en pubspec.yaml.
const versionApp = '1.1.0';

/// Quién hace la app. Aparece en Ajustes y debe coincidir con el nombre
/// de desarrollador que se muestra en la ficha de Google Play.
///
/// Ojo: el identificador del paquete es `com.netrcd.becaya`, sin la "i".
/// No es un descuido que se pueda arreglar — un applicationId no se
/// puede cambiar después de subir la app a Play, así que se queda así
/// para siempre. No afecta a nada visible: el usuario nunca lo ve.
const autorApp = 'NETRICD STUDIO';

/// Año de publicación, para el aviso de derechos.
const anioApp = 2026;

/// Identificador en Google Play. Es el mismo `applicationId` de
/// android/app/build.gradle.kts y NO se puede cambiar una vez
/// publicada la app: cambiarlo crearía una app distinta y dejaría sin
/// actualizaciones a quien ya la tenga instalada.
const idPaquete = 'com.netrcd.becaya';

/// Abre la ficha directamente en la app de Play Store, sin pasar por el
/// navegador. Si Play no está instalado —un emulador, un teléfono sin
/// servicios de Google— hay que caer a [urlPlayWeb].
const urlPlayApp = 'market://details?id=$idPaquete';

const urlPlayWeb =
    'https://play.google.com/store/apps/details?id=$idPaquete';
