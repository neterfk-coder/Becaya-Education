/* ============================================================
   repositorio_test.dart — el contrato de datos
   ------------------------------------------------------------
   data/becas.json dejó de ser un archivo interno: un APK
   instalado lo sigue pidiendo durante meses. Estas pruebas
   cuidan las tres situaciones que de verdad importan cuando eso
   pasa:

     · el sitio publica algo más nuevo de lo que la app entiende
     · no hay red, pero sí una copia guardada
     · no hay red y es la primera vez que se abre

   Ninguna toca la red de verdad: el cliente HTTP está simulado.
   ============================================================ */

import 'dart:convert';

import 'package:becaya/datos/repositorio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _unaBeca = {
  'id': 'beca-de-prueba',
  'nombre': 'Beca Ñandú 2026',
  'institucion': 'Pronabec',
  'nivel': 'pregrado',
  'destino': 'peru',
  'pais': 'Perú',
  'cobertura': 'total',
  'areas': ['Todas las áreas'],
  'apertura': '2026-08-01',
  'cierre': '2026-12-01',
  'resumen': 'Resumen.',
  'requisitos': <String>[],
  'beneficios': <String>[],
  'enlace': 'https://www.pronabec.gob.pe/',
  'fuente': 'Prueba',
};

String _sobreBecas({
  int version = 1,
  bool ejemplo = false,
  String actualizado = '2026-08-12',
  List<Map<String, dynamic>> becas = const [_unaBeca],
}) {
  return jsonEncode({
    'version': version,
    'generado': '2026-08-12T23:27:33.387Z',
    'actualizado': actualizado,
    'ejemplo': ejemplo,
    'becas': becas,
  });
}

String _sobreVoluntariados({int version = 1, String actualizado = '2026-09-01'}) {
  return jsonEncode({
    'version': version,
    'generado': '2026-09-01T00:00:00.000Z',
    'actualizado': actualizado,
    'ejemplo': false,
    'voluntariados': <Map<String, dynamic>>[],
  });
}

/// Cliente que responde cada archivo con el cuerpo que se le indique.
http.Client _sirve(String becas, String voluntariados) {
  return MockClient((peticion) async {
    final cuerpo =
        peticion.url.path.endsWith('becas.json') ? becas : voluntariados;
    // Se responde en bytes y sin charset a propósito: así la prueba
    // también cubre que el repositorio decodifique UTF-8 por su cuenta.
    return http.Response.bytes(utf8.encode(cuerpo), 200);
  });
}

/// Cliente sin conexión.
http.Client _sinRed() {
  return MockClient((_) async => throw http.ClientException('sin red'));
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  test('abre el sobre y expone la fecha de revisión del sitio', () async {
    final repo = Repositorio(
      cliente: _sirve(_sobreBecas(), _sobreVoluntariados()),
    );

    final catalogo = await repo.cargar();

    expect(catalogo.becas, hasLength(1));
    expect(catalogo.desdeCache, isFalse);
    expect(catalogo.ejemplo, isFalse);
    /* La más antigua de las dos: decir la más reciente haría parecer el
       catálogo más fresco de lo que está. */
    expect(catalogo.actualizado, '2026-08-12');
  });

  test('las tildes y la ñ sobreviven al viaje', () async {
    final repo = Repositorio(
      cliente: _sirve(_sobreBecas(), _sobreVoluntariados()),
    );

    final catalogo = await repo.cargar();

    expect(catalogo.becas.single.nombre, 'Beca Ñandú 2026');
    expect(catalogo.becas.single.pais, 'Perú');
  });

  test('propaga la marca de datos de ejemplo del sitio', () async {
    final repo = Repositorio(
      cliente: _sirve(_sobreBecas(ejemplo: true), _sobreVoluntariados()),
    );

    expect((await repo.cargar()).ejemplo, isTrue);
  });

  test('una versión de contrato más nueva no se intenta leer', () async {
    final repo = Repositorio(
      cliente: _sirve(_sobreBecas(version: 2), _sobreVoluntariados()),
    );

    await expectLater(repo.cargar(), throwsA(isA<CatalogoIncompatible>()));
  });

  test('el formato viejo sin versión se rechaza como incompatible', () async {
    /* Antes del contrato, el archivo era un arreglo pelado. Si una app
       nueva se topa con un sitio sin redesplegar, tiene que decirlo
       claro y no fallar con un error de parseo indescifrable. */
    final repo = Repositorio(
      cliente: _sirve(jsonEncode([_unaBeca]), _sobreVoluntariados()),
    );

    await expectLater(repo.cargar(), throwsA(isA<CatalogoIncompatible>()));
  });

  test('una versión incompatible NO se disimula con la caché', () async {
    /* Primero se llena la caché con una carga buena. */
    await Repositorio(cliente: _sirve(_sobreBecas(), _sobreVoluntariados()))
        .cargar();

    /* Después el sitio publica un contrato que esta app no entiende.
       Caer a la caché dejaría al usuario con fechas congeladas para
       siempre y sin enterarse: tiene que fallar. */
    final repo = Repositorio(
      cliente: _sirve(_sobreBecas(version: 99), _sobreVoluntariados()),
    );

    await expectLater(repo.cargar(), throwsA(isA<CatalogoIncompatible>()));
  });

  test('sin red, devuelve lo guardado y lo marca como copia', () async {
    await Repositorio(cliente: _sirve(_sobreBecas(), _sobreVoluntariados()))
        .cargar();

    final catalogo = await Repositorio(cliente: _sinRed()).cargar();

    expect(catalogo.desdeCache, isTrue);
    expect(catalogo.becas, hasLength(1));
    expect(catalogo.descargado, isNotNull);
  });

  test('sin red y sin nada guardado, lo dice en vez de mostrar vacío', () async {
    /* Un catálogo vacío es un estado válido del proyecto, así que la app
       NO puede confundir "no pude descargar" con "no hay convocatorias":
       diría que no hay becas cuando en realidad no pudo mirar. */
    final repo = Repositorio(cliente: _sinRed());

    await expectLater(repo.cargar(), throwsA(isA<SinDatos>()));
  });

  test('un HTTP 500 cuenta como fallo de red, no como catálogo vacío', () async {
    final repo = Repositorio(
      cliente: MockClient((_) async => http.Response('nope', 500)),
    );

    await expectLater(repo.cargar(), throwsA(isA<SinDatos>()));
  });
}
