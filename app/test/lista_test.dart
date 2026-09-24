/* ============================================================
   lista_test.dart — pruebas de la lista
   ------------------------------------------------------------
   No tocan la red: montan la lista con fichas fabricadas a mano.
   Lo que cuidan es que la pantalla no mienta — que agrupe donde
   el motor dijo y que un catálogo vacío se explique en vez de
   quedarse en blanco.
   ============================================================ */

import 'package:becaya/datos/guardadas.dart';
import 'package:becaya/modelo/convocatoria.dart';
import 'package:becaya/ui/lista_convocatorias.dart';
import 'package:becaya/ui/paleta.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

Future<void> _montar(
  WidgetTester tester,
  List<Ficha> fichas, {
  Guardadas? guardadas,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListaConvocatorias(
          fichas: fichas,
          acento: Acento.becas,
          onTocar: (_) {},
          onRefrescar: () async {},
          guardadas: guardadas ?? Guardadas(),
          coleccion: Coleccion.becas,
        ),
      ),
    ),
  );
}

void main() {
  final referencia = DateTime(2026, 8, 12);

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

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

  testWidgets('guardar no pide cuenta: marca y persiste al instante',
      (tester) async {
    final guardadas = Guardadas();
    await guardadas.cargar();

    final fichas = aFichas([
      _beca('abierta', 'Beca en curso', '2026-08-01', '2026-09-30'),
    ], referencia);

    await _montar(tester, fichas, guardadas: guardadas);

    expect(guardadas.tiene(Coleccion.becas, 'abierta'), isFalse);
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);

    await tester.tap(find.byIcon(Icons.bookmark_border));
    await tester.pumpAndSettle();

    expect(guardadas.tiene(Coleccion.becas, 'abierta'), isTrue);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
  });

  testWidgets('los dos catálogos no comparten guardadas', (tester) async {
    /* Un id puede repetirse entre becas y voluntariados. Guardar en uno
       no puede marcar el otro: son espacios separados, igual que en la
       web y en los archivos de datos. */
    final guardadas = Guardadas();
    await guardadas.cargar();

    await guardadas.alternar(Coleccion.becas, 'mismo-id');

    expect(guardadas.tiene(Coleccion.becas, 'mismo-id'), isTrue);
    expect(guardadas.tiene(Coleccion.voluntariados, 'mismo-id'), isFalse);
  });

  testWidgets('fusionar une en vez de reemplazar', (tester) async {
    /* Al iniciar sesión se juntan las guardadas del teléfono con las de
       la cuenta. Ante la duda no se pierde nada: perder una beca y
       enterarte cuando ya cerró es el peor resultado posible. */
    final guardadas = Guardadas();
    await guardadas.cargar();

    await guardadas.alternar(Coleccion.becas, 'local');
    await guardadas.fusionar(Coleccion.becas, ['remota', 'local']);

    expect(guardadas.de(Coleccion.becas), {'local', 'remota'});
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
