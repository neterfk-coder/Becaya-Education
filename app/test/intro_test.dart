/* ============================================================
   intro_test.dart — que la presentación se quite
   ------------------------------------------------------------
   Una intro que no desaparece deja la app inutilizable, y es un
   fallo que no se nota escribiéndola: se nota al abrirla. Estas
   pruebas fijan las dos cosas que importan — que la pantalla de
   debajo esté viva desde el primer frame, y que la marca se
   quite sola y salga del árbol.
   ============================================================ */

import 'package:becaya/ui/intro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('la pantalla de debajo se monta desde el primer frame',
      (tester) async {
    /* Esto es lo que hace que la intro no cueste tiempo: si el hijo no
       se montara hasta el final, la descarga del catálogo empezaría
       segundo y medio tarde. */
    await tester.pumpWidget(
      const MaterialApp(home: Arranque(hijo: Text('contenido'))),
    );

    expect(find.text('contenido'), findsOneWidget);
    expect(find.text('becaya'), findsOneWidget);
  });

  testWidgets('la intro se desvanece y sale del árbol', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Arranque(hijo: Text('contenido'))),
    );

    expect(find.byType(PantallaIntro), findsOneWidget);

    // Más que la suma de visible + salida, para cubrir las dos fases.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(
      find.byType(PantallaIntro),
      findsNothing,
      reason: 'la intro sigue en el árbol: taparía la app para siempre',
    );
    expect(find.text('contenido'), findsOneWidget);
  });

  testWidgets('mientras se desvanece no se traga los toques',
      (tester) async {
    var toques = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Arranque(
          hijo: Center(
            child: ElevatedButton(
              onPressed: () => toques++,
              child: const Text('tocar'),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await tester.tap(find.text('tocar'));
    expect(toques, 1);
  });
}
