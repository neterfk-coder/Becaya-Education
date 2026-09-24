/* ============================================================
   version_test.dart — que la versión no mienta
   ------------------------------------------------------------
   version.dart lleva el número a mano para no depender de un
   plugin nativo. Esta prueba es lo que hace que esa copia sea
   segura: si alguien sube la versión en pubspec.yaml y se olvida
   de version.dart, falla aquí y no en la pantalla de Ajustes de
   un usuario.
   ============================================================ */

import 'dart:io';

import 'package:becaya/version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la versión mostrada coincide con la de pubspec.yaml', () {
    final pubspec = File('pubspec.yaml');
    if (!pubspec.existsSync()) {
      markTestSkipped('pubspec.yaml no está — se corrió fuera del paquete');
      return;
    }

    // `version: 1.0.0+1` → la parte anterior al "+" es el versionName,
    // que es lo que ve el usuario. El número tras el "+" es el
    // versionCode de Android y no se muestra en ningún sitio.
    final linea = pubspec
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'), orElse: () => '');

    expect(linea, isNotEmpty, reason: 'pubspec.yaml no declara "version:"');

    final declarada = linea.split(':')[1].trim().split('+').first;

    expect(
      versionApp,
      declarada,
      reason: 'version.dart dice "$versionApp" y pubspec.yaml dice '
          '"$declarada". Actualiza los dos.',
    );
  });

  test('el autor no está vacío', () {
    /* Aparece en Ajustes y tiene que coincidir con el nombre de
       desarrollador de Play. Un valor vacío pasaría desapercibido
       hasta que un usuario abriera la pantalla. */
    expect(autorApp.trim(), isNotEmpty);
  });
}
