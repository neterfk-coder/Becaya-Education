/* ============================================================
   privacidad_test.dart — que las dos políticas no se separen
   ------------------------------------------------------------
   La política vive dos veces: como pantalla nativa en la app
   (para leerse sin conexión) y como privacidad.html en la web
   (porque Google Play exige una URL pública).

   Estas pruebas son lo único que impide que se separen en
   silencio. Sin ellas, alguien actualizaría el HTML, se
   olvidaría del Dart, y la app enseñaría una política vieja
   durante meses sin que nadie se enterara.
   ============================================================ */

import 'dart:convert';
import 'dart:io';

import 'package:becaya/ui/privacidad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monta la pantalla en un lienzo alto.
///
/// Es un ListView: con el tamaño de pantalla normal solo construye lo
/// visible, y las secciones de abajo no existirían para las búsquedas.
Future<void> _montarEntera(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 8000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(const MaterialApp(home: PantallaPrivacidad()));
  await tester.pumpAndSettle();
}

void main() {
  test('la fecha de la app coincide con la de privacidad.html', () {
    final html = File('../privacidad.html');
    if (!html.existsSync()) {
      markTestSkipped('privacidad.html no está — se corrió fuera del repo');
      return;
    }

    final texto = html.readAsStringSync(encoding: utf8);

    expect(
      texto.contains(fechaPolitica),
      isTrue,
      reason: 'La app dice "$fechaPolitica" pero privacidad.html no. '
          'Si cambiaste una política, actualiza la otra y sube la fecha en '
          'las dos.',
    );
  });

  testWidgets('la política declara lo mismo que el formulario de Play',
      (tester) async {
    /* No comprueba la redacción, solo que no falte ninguno de los
       puntos declarados en Data Safety. Si el texto se recorta y se cae
       uno, la app contradiría lo declarado en Play — motivo de rechazo. */
    await _montarEntera(tester);

    for (final termino in [
      'correo electrónico',
      'identificador de usuario',
      'Firebase',
      'Eliminar mi cuenta',
      'internet',
    ]) {
      expect(
        find.textContaining(termino, findRichText: true),
        findsWidgets,
        reason: 'la política ya no menciona "$termino"',
      );
    }
  });

  testWidgets('deja claro que la cuenta es opcional', (tester) async {
    /* Es la afirmación que sostiene todo lo demás: que la app no es un
       muro de registro. Si desapareciera del texto, habría que revisar
       también la ficha de Play y el formulario de datos. */
    await _montarEntera(tester);

    expect(
      find.textContaining('sin dar ningún dato', findRichText: true),
      findsWidgets,
    );
    expect(
      find.textContaining('opcional', findRichText: true),
      findsWidgets,
    );
  });
}
