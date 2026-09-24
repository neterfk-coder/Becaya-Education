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
const versionApp = '1.0.0';

/// Quién hace la app. Aparece en Ajustes y tiene que coincidir con el
/// nombre de desarrollador de Google Play y con el certificado de
/// firma: si no coinciden, al usuario le queda la duda de si la app
/// que instaló es la que cree.
const autorApp = 'NETRCD STUDIO';

/// Año de publicación, para el aviso de derechos.
const anioApp = 2026;
