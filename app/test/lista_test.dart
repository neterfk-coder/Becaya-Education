/* ============================================================
   lista_test.dart — pruebas de la lista
   ------------------------------------------------------------
   No tocan la red: montan la lista con fichas fabricadas a mano.
   Lo que cuidan es que la pantalla no mienta — que agrupe donde
   el motor dijo y que un catálogo vacío se explique en vez de
   quedarse en blanco.
   ============================================================ */

import 'package:becaya/modelo/convocatoria.dart';
import 'package:becaya/ui/lista_convocatorias.dart';
import 'package:becaya/ui/paleta.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Beca _beca(String id, String nombre, String? apertura, String? cierre) {
  return Beca.desdeJson({
    'id': id,
    'nombre': nombre,
    'institucion': 'Pronabec',
    'nivel': 'pregrado',
    'destino': 'peru',
    'pais': 'Perú',
    'cobertura': 'total',
    'areas': ['Todas las áreas'],
    'apertura': apertura,
    'cierre': cierre,
    'resumen': 'Resumen de prueba.',
    'requisitos': <String>[],
    'beneficios': <String>[],
    'enlace': 'https://www.pronabec.gob.pe/',
    'fuente': 'Prueba',
  })!;
}

Future<void> _montar(WidgetTester tester, List<Ficha> fichas) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListaConvocatorias(
          fichas: fichas,
          acento: Acento.becas,
          onTocar: (_) {},
          onRefrescar: () async {},
        ),
      ),
    ),
  );
}

void main() {
  final referencia = DateTime(2026, 8, 12);

  testWidgets('agrupa cada convocatoria bajo su encabezado', (tester) async {
    final fichas = aFichas([
      _beca('abierta', 'Beca en curso', '2026-08-01', '2026-09-30'),
      _beca('cerrada', 'Beca vencida', '2026-06-01', '2026-07-01'),
    ], referencia);

    await _montar(tester, fichas);

    expect(find.text('Abiertas ahora'), findsOneWidget);
    expect(find.text('Ya cerradas'), findsOneWidget);
    expect(find.text('Beca en curso'), findsOneWidget);
    expect(find.text('Beca vencida'), findsOneWidget);
  });

  testWidgets('no dibuja encabezados de grupos sin convocatorias', (tester) async {
    final fichas = aFichas([
      _beca('abierta', 'Beca en curso', '2026-08-01', '2026-09-30'),
    ], referencia);

    await _montar(tester, fichas);

    expect(find.text('Abiertas ahora'), findsOneWidget);
    expect(find.text('Ya cerradas'), findsNothing);
    expect(find.text('Abren esta semana'), findsNothing);
  });

  testWidgets('un catálogo vacío se explica en vez de quedar en blanco',
      (tester) async {
    await _montar(tester, []);

    expect(find.textContaining('Todavía no hay nada publicado'), findsOneWidget);
    expect(find.textContaining('preferible a fechas sin verificar'), findsOneWidget);
  });

  testWidgets('el cierre inminente se muestra con su aviso', (tester) async {
    /* Cierra en 3 días desde la referencia: es el único caso que la
       interfaz pinta en naranja. */
    final fichas = aFichas([
      _beca('urgente', 'Cierra pronto', '2026-08-01', '2026-08-15'),
    ], referencia);

    await _montar(tester, fichas);

    expect(fichas.single.estado.urgente, isTrue);
    expect(find.text('Quedan 3 días'), findsOneWidget);
  });
}
