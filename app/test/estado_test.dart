/* ============================================================
   estado_test.dart — pruebas del motor de fechas
   ------------------------------------------------------------
   Puerto de scripts/probar.mjs. Son las MISMAS pruebas que corre
   la web, a propósito: el motor está duplicado en dos lenguajes
   y estas pruebas son el único mecanismo que avisa si las dos
   copias empiezan a responder distinto.

   Si agregas un caso aquí, agrégalo también en probar.mjs.

     flutter test
   ============================================================ */

import 'dart:convert';
import 'dart:io';

import 'package:becaya/datos/repositorio.dart';
import 'package:becaya/modelo/convocatoria.dart';
import 'package:becaya/motor/estado.dart';
import 'package:flutter_test/flutter_test.dart';

/// 12 de agosto de 2026 — la misma referencia que usa probar.mjs.
final referencia = DateTime(2026, 8, 12);

/// Lo mínimo que el motor necesita: dos fechas y un nombre para los
/// mensajes de error.
class _Caso implements ConFechas {
  const _Caso(this.id, this.apertura, this.cierre);
  final String id;
  @override final String? apertura;
  @override final String? cierre;
}

String _grupoDe(String? apertura, String? cierre) =>
    calcularEstado(_Caso('x', apertura, cierre), referencia).grupo;

void main() {
  /* ---------- Parseo de fechas ---------- */

  test('aFecha no corre la fecha un día por la zona horaria', () {
    final f = aFecha('2026-09-15')!;
    expect(f.year, 2026);
    expect(f.month, 9);
    expect(f.day, 15);
  });

  test('aFecha devuelve null en lugar de reventar con basura', () {
    expect(aFecha(null), isNull);
    expect(aFecha(''), isNull);
    expect(aFecha('proximamente'), isNull);
    expect(aFecha('2026-13'), isNull);
  });

  /* ---------- Clasificación en grupos ---------- */

  test('una convocatoria en curso queda en abiertas', () {
    expect(_grupoDe('2026-08-01', '2026-09-30'), 'abiertas');
  });

  test('el día exacto de apertura ya cuenta como abierta', () {
    expect(_grupoDe('2026-08-12', '2026-09-30'), 'abiertas');
  });

  test('el día exacto de cierre todavía cuenta como abierta', () {
    expect(_grupoDe('2026-07-01', '2026-08-12'), 'abiertas');
  });

  test('el día siguiente al cierre ya es cerrada', () {
    expect(_grupoDe('2026-07-01', '2026-08-11'), 'cerradas');
  });

  test('los cortes de 7 y 31 días caen en el grupo correcto', () {
    expect(_grupoDe('2026-08-19', '2026-10-01'), 'esta-semana');   /* +7  */
    expect(_grupoDe('2026-08-20', '2026-10-01'), 'este-mes');      /* +8  */
    expect(_grupoDe('2026-09-12', '2026-11-01'), 'este-mes');      /* +31 */
    expect(_grupoDe('2026-09-13', '2026-11-01'), 'mas-adelante');  /* +32 */
  });

  test('sin apertura publicada se trata como abierta, no como futura', () {
    /* Caso real del catálogo: de varias becas se conoce el cierre pero
       no el día exacto en que abrieron. */
    final e = calcularEstado(const _Caso('x', null, '2026-11-14'), referencia);
    expect(e.grupo, 'abiertas');
    expect(e.detalle, 'Cierra el 14 de noviembre');
  });

  test('sin cierre publicado se dice, no se inventa una fecha', () {
    final e = calcularEstado(const _Caso('x', '2026-08-01', null), referencia);
    expect(e.grupo, 'abiertas');
    expect(e.titular, 'Abierta');
    expect(e.detalle, 'Sin fecha de cierre publicada');
  });

  /* ---------- Urgencia y progreso ---------- */

  test('una beca que cierra en 7 días o menos se marca urgente', () {
    final casi = calcularEstado(const _Caso('a', '2026-08-01', '2026-08-19'), referencia);
    final holgada = calcularEstado(const _Caso('b', '2026-08-01', '2026-08-20'), referencia);
    expect(casi.urgente, isTrue);
    expect(holgada.urgente, isFalse);
  });

  test('el progreso refleja el tiempo que queda, no el transcurrido', () {
    /* Del 2 al 22 de agosto, estamos en el día 10 de 20: queda la mitad. */
    final e = calcularEstado(const _Caso('a', '2026-08-02', '2026-08-22'), referencia);
    expect(e.progreso, 50);
  });

  test('el progreso nunca se sale de 0..100', () {
    final e = calcularEstado(const _Caso('a', '2026-08-12', '2026-08-12'), referencia);
    expect(e.progreso, inInclusiveRange(0, 100));
  });

  /* ---------- Orden ---------- */

  test('en una sola lista las abiertas van antes que las cerradas', () {
    /* Este es el bug que tenía la vista de cuadrícula de la web: las
       cerradas tienen días restantes negativos y se colaban al tope. */
    final casos = [
      const _Caso('cerrada-vieja', '2025-01-01', '2025-03-01'),
      const _Caso('abierta', '2026-08-01', '2026-09-30'),
      const _Caso('cerrada-reciente', '2026-07-01', '2026-08-05'),
      const _Caso('proxima-mes', '2026-09-01', '2026-10-01'),
      const _Caso('proxima-semana', '2026-08-15', '2026-10-01'),
    ];

    final orden = _ordenar(casos);

    expect(orden, [
      'abierta',
      'proxima-semana',
      'proxima-mes',
      'cerrada-reciente',
      'cerrada-vieja',
    ]);
  });

  test('dentro de abiertas primero va la que cierra antes', () {
    final orden = _ordenar([
      const _Caso('cierra-tarde', '2026-08-01', '2026-12-01'),
      const _Caso('cierra-pronto', '2026-08-01', '2026-08-15'),
    ]);
    expect(orden, ['cierra-pronto', 'cierra-tarde']);
  });

  test('el orden es consistente al invertir los argumentos', () {
    /* Un comparador que no cumple esto produce listas distintas según
       el orden de entrada. El de la web no lo cumplía entre grupos. */
    final estados = [
      const _Caso('a', '2026-08-01', '2026-09-30'),
      const _Caso('b', '2026-07-01', '2026-08-05'),
      const _Caso('c', '2026-09-01', '2026-10-01'),
    ].map((c) => (c.id, calcularEstado(c, referencia))).toList();

    for (final x in estados) {
      for (final y in estados) {
        final ida = ordenarPorUrgencia(x.$2, y.$2).sign;
        final vuelta = ordenarPorUrgencia(y.$2, x.$2).sign;
        expect(ida, -vuelta, reason: '${x.$1} vs ${y.$1}');
      }
    }
  });

  /* ---------- El catálogo real ---------- */

  /* Estas pruebas leen los mismos archivos que publica el sitio. No
     comprueban que HAYA becas —un catálogo vacío es un estado válido y
     deliberado— sino que el modelo de la app sepa leer lo publicado.
     Si el build de la web cambia un nombre de campo, aquí se nota. */

  test('el catálogo del repo trae la versión de contrato que la app espera', () {
    final sobre = _sobrePublicado();
    if (sobre == null) return;

    /* Si esto falla, alguien subió VERSION_CATALOGO en
       scripts/construir-datos.mjs sin actualizar la app. Publicar así
       dejaría ciegas a las versiones ya instaladas. */
    expect(
      sobre['version'],
      versionCatalogoSoportada,
      reason: 'el sitio publica la versión ${sobre['version']} y la app '
          'entiende la $versionCatalogoSoportada',
    );
  });

  test('el modelo lee el catálogo publicado sin descartar nada', () {
    final sobre = _sobrePublicado();
    if (sobre == null) return;

    final crudo = sobre['becas'] as List;
    final becas = crudo
        .cast<Map<String, dynamic>>()
        .map(Beca.desdeJson)
        .toList();

    /* Una ficha que se cae aquí es una que el usuario no vería en la
       app pero sí en la web. Esa diferencia hay que detectarla. */
    for (var i = 0; i < becas.length; i++) {
      expect(
        becas[i],
        isNotNull,
        reason: 'la app descartó ${crudo[i]['id']} — revisa enlace y fechas',
      );
    }
  });

  test('toda beca publicada trae enlace https y alguna fecha', () {
    final sobre = _sobrePublicado();
    if (sobre == null) return;

    final becas = (sobre['becas'] as List)
        .cast<Map<String, dynamic>>()
        .map(Beca.desdeJson)
        .whereType<Beca>()
        .toList();

    final ids = <String>{};
    for (final b in becas) {
      expect(b.enlace, startsWith('http'), reason: '${b.id}: enlace inválido');
      expect(b.apertura != null || b.cierre != null, isTrue,
          reason: '${b.id}: no tiene ninguna fecha');
      if (b.apertura != null && b.cierre != null) {
        expect(b.cierre!.compareTo(b.apertura!) >= 0, isTrue,
            reason: '${b.id}: cierra antes de abrir');
      }
      expect(ids.add(b.id), isTrue, reason: 'id repetido: ${b.id}');
    }
  });
}

/// El sobre real que publica el sitio, leído del repositorio.
///
/// Devuelve null —y marca la prueba como omitida— si se corrió fuera del
/// repo, por ejemplo desde una copia suelta de app/.
Map<String, dynamic>? _sobrePublicado() {
  final archivo = File('../data/becas.json');
  if (!archivo.existsSync()) {
    markTestSkipped('data/becas.json no está — se corrió fuera del repo');
    return null;
  }
  return jsonDecode(archivo.readAsStringSync(encoding: utf8)) as Map<String, dynamic>;
}

List<String> _ordenar(List<_Caso> casos) {
  final conEstado = casos.map((c) => (c.id, calcularEstado(c, referencia))).toList();
  conEstado.sort((a, b) => ordenarPorUrgencia(a.$2, b.$2));
  return conEstado.map((e) => e.$1).toList();
}
