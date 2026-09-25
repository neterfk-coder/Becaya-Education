/* ============================================================
   bienvenida_test.dart — que entrar sin cuenta sea de verdad
   ------------------------------------------------------------
   Lo que estas pruebas protegen no es la estética de la
   pantalla, es una propiedad del producto: que el catálogo sea
   accesible sin registrarse.

   Si alguien quita el botón de invitado o lo esconde, la app
   pasa a ser un muro de registro sobre información pública, y
   eso es motivo de rechazo en Google Play. Mejor enterarse aquí
   que en la revisión.
   ============================================================ */

import 'package:becaya/datos/bienvenida.dart';
import 'package:becaya/datos/sesion.dart';
import 'package:becaya/ui/bienvenida.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _montar(
  WidgetTester tester, {
  required VoidCallback onInvitado,
  VoidCallback? onAbrirCorreo,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: PantallaBienvenida(
        // Sin iniciar: se queda en "arrancando", que es como se ve
        // antes de que Firebase responda. La pantalla tiene que ser
        // usable igual.
        sesion: Sesion(),
        onInvitado: onInvitado,
        onAbrirCorreo: onAbrirCorreo ?? () {},
      ),
    ),
  );
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ofrece entrar sin cuenta, visible y sin buscarlo',
      (tester) async {
    var invitado = 0;
    await _montar(tester, onInvitado: () => invitado++);

    final boton = find.text('Entrar como invitado');
    expect(boton, findsOneWidget);

    await tester.tap(boton);
    await tester.pump();

    expect(invitado, 1);
  });

  testWidgets('deja claro que sin cuenta no se pierde nada', (tester) async {
    await _montar(tester, onInvitado: () {});

    expect(
      find.textContaining('Sin cuenta funciona todo', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('ofrece también las dos vías con cuenta', (tester) async {
    var correo = 0;
    await _montar(tester, onInvitado: () {}, onAbrirCorreo: () => correo++);

    expect(find.text('Continuar con Google'), findsOneWidget);

    await tester.tap(find.text('Usar mi correo'));
    await tester.pump();
    expect(correo, 1);
  });

  group('el recuerdo de la elección', () {
    test('la primera vez no se ha visto', () async {
      SharedPreferences.setMockInitialValues({});
      final b = Bienvenida();
      await b.cargar();

      expect(b.listo, isTrue);
      expect(b.vista, isFalse);
    });

    test('marcarla la recuerda para el siguiente arranque', () async {
      SharedPreferences.setMockInitialValues({});

      final primera = Bienvenida();
      await primera.cargar();
      await primera.marcarVista();

      /* Un objeto nuevo, como en un arranque posterior: la elección
         tiene que venir del disco, no de la memoria. */
      final segunda = Bienvenida();
      await segunda.cargar();

      expect(
        segunda.vista,
        isTrue,
        reason: 'volvería a pedir elegir cada vez que se abre la app',
      );
    });

    test('avisa a quien la escucha al marcarla', () async {
      SharedPreferences.setMockInitialValues({});
      final b = Bienvenida();
      await b.cargar();

      var avisos = 0;
      b.addListener(() => avisos++);
      await b.marcarVista();

      expect(avisos, 1);

      // Marcarla otra vez no debe repintar: ya estaba marcada.
      await b.marcarVista();
      expect(avisos, 1);
    });
  });
}
