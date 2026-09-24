/* ============================================================
   repositorio.dart — de dónde salen las convocatorias
   ------------------------------------------------------------
   El catálogo publicado ya es JSON plano (data/becas.json y
   data/voluntariados.json del sitio), así que la app no necesita
   backend propio: descarga los dos archivos y listo.

   Pesan unos pocos KB, por eso se bajan enteros y se guardan
   completos. Nada de paginación: el usuario al que apuntamos
   paga los datos móviles y merece que la app abra sin conexión.

   Orden de preferencia: red fresca > caché > pantalla honesta de
   error. Lo que NUNCA hace es inventar o rellenar datos.
   ============================================================ */

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../modelo/convocatoria.dart';

/// De dónde se descarga el catálogo.
///
/// Si algún día el sitio cambia de dominio, esta constante es lo único
/// que hay que tocar — pero ojo: las versiones ya instaladas seguirán
/// pidiendo la vieja. Conviene dejar redirección en el dominio anterior.
const origenDatos = 'https://becaya.vercel.app';

/// Versión del contrato de datos que esta app sabe leer.
///
/// Tiene que coincidir con VERSION_CATALOGO de scripts/construir-datos.mjs.
/// Mientras el número no cambie, el sitio puede agregar campos nuevos sin
/// romper nada: los lectores viejos los ignoran. Cuando sube, significa que
/// algo cambió de nombre o de significado, y entonces esta app prefiere
/// decir "actualízame" antes que mostrar datos que ya no entiende.
const versionCatalogoSoportada = 1;

/// Cuánto se espera a la red antes de rendirse y usar la caché. Corto a
/// propósito: más vale mostrar datos de ayer al instante que dejar un
/// spinner girando medio minuto con mala señal.
const _esperaRed = Duration(seconds: 8);

const _claveBecas = 'becaya:cache:becas';
const _claveVoluntariados = 'becaya:cache:voluntariados';
const _claveDescargado = 'becaya:cache:descargado';

/// El catálogo completo, más de dónde salió.
class Catalogo {
  const Catalogo({
    required this.becas,
    required this.voluntariados,
    required this.desdeCache,
    this.actualizado,
    this.descargado,
    this.ejemplo = false,
  });

  final List<Beca> becas;
  final List<Voluntariado> voluntariados;

  /// true = no hubo red y esto es lo último que se alcanzó a guardar.
  /// La interfaz lo avisa; un catálogo de fechas que envejece en
  /// silencio es exactamente el problema que esta app quiere evitar.
  final bool desdeCache;

  /// Cuándo se revisó el catálogo contra las fuentes oficiales, en
  /// AAAA-MM-DD. Viene del sitio, no del teléfono.
  final String? actualizado;

  /// Cuándo se descargó de verdad (no cuándo se leyó de la caché).
  final DateTime? descargado;

  /// El sitio marcó estos datos como no verificados. Si es true hay que
  /// decirlo en pantalla, no disimularlo.
  final bool ejemplo;

  bool get vacio => becas.isEmpty && voluntariados.isEmpty;
}

/// No hubo red y tampoco había nada guardado. Es la única situación en
/// la que la app no puede mostrar absolutamente nada.
class SinDatos implements Exception {
  const SinDatos(this.causa);
  final Object causa;

  @override
  String toString() => 'Sin datos descargados y sin conexión: $causa';
}

/// El sitio publica un contrato más nuevo del que esta app entiende.
///
/// No se trata como un fallo de red a propósito: la caché no lo arregla
/// y reintentar tampoco. Lo único que lo resuelve es actualizar la app,
/// y eso hay que decírselo al usuario en vez de dejarlo con datos viejos
/// para siempre sin explicación.
class CatalogoIncompatible implements Exception {
  const CatalogoIncompatible(this.encontrada);
  final Object? encontrada;

  @override
  String toString() =>
      'El catálogo usa la versión $encontrada y esta app entiende '
      'hasta la $versionCatalogoSoportada.';
}

class Repositorio {
  Repositorio({http.Client? cliente}) : _cliente = cliente ?? http.Client();

  final http.Client _cliente;

  /// Intenta red; si falla, cae a la caché; si tampoco hay, lanza
  /// [SinDatos]. Nunca devuelve una lista a medias.
  Future<Catalogo> cargar() async {
    try {
      // Los dos archivos en paralelo: son independientes y así la espera
      // es la del más lento, no la suma.
      final cuerpos = await Future.wait([
        _bajar('$origenDatos/data/becas.json'),
        _bajar('$origenDatos/data/voluntariados.json'),
      ]).timeout(_esperaRed);

      final catalogo = _construir(cuerpos[0], cuerpos[1], desdeCache: false);
      // Se guarda después de parsear: así nunca se cachea un archivo
      // que resultó ilegible.
      await _guardarEnCache(cuerpos[0], cuerpos[1]);
      return catalogo;
    } on CatalogoIncompatible {
      rethrow;
    } catch (error) {
      final guardado = await _desdeCache();
      if (guardado != null) return guardado;
      throw SinDatos(error);
    }
  }

  Future<String> _bajar(String url) async {
    final r = await _cliente.get(Uri.parse(url));
    if (r.statusCode != 200) {
      throw http.ClientException('HTTP ${r.statusCode} al pedir $url');
    }
    // utf8.decode explícito: el JSON trae tildes y ñ, y si el servidor
    // no manda charset, http asume latin-1 y llegan "Espa??a".
    return utf8.decode(r.bodyBytes);
  }

  Catalogo _construir(
    String cuerpoBecas,
    String cuerpoVoluntariados, {
    required bool desdeCache,
    DateTime? descargado,
  }) {
    final sobreBecas = _Sobre.leer(cuerpoBecas, 'becas');
    final sobreVoluntariados = _Sobre.leer(cuerpoVoluntariados, 'voluntariados');

    return Catalogo(
      becas: sobreBecas.convertir(Beca.desdeJson),
      voluntariados: sobreVoluntariados.convertir(Voluntariado.desdeJson),
      desdeCache: desdeCache,
      // La fecha de revisión más antigua de las dos: decir la más
      // reciente haría parecer el catálogo más fresco de lo que está.
      actualizado: _masAntigua(sobreBecas.actualizado, sobreVoluntariados.actualizado),
      ejemplo: sobreBecas.ejemplo || sobreVoluntariados.ejemplo,
      descargado: descargado ?? DateTime.now(),
    );
  }

  Future<void> _guardarEnCache(String cuerpoBecas, String cuerpoVoluntariados) async {
    final prefs = await SharedPreferences.getInstance();
    // Se guarda el archivo tal como llegó, no los objetos ya parseados:
    // si mañana el modelo gana un campo, la caché vieja se sigue leyendo
    // sin migración ni conversores que mantener.
    await prefs.setString(_claveBecas, cuerpoBecas);
    await prefs.setString(_claveVoluntariados, cuerpoVoluntariados);
    await prefs.setString(_claveDescargado, DateTime.now().toIso8601String());
  }

  Future<Catalogo?> _desdeCache() async {
    final prefs = await SharedPreferences.getInstance();
    final becas = prefs.getString(_claveBecas);
    final voluntariados = prefs.getString(_claveVoluntariados);
    if (becas == null || voluntariados == null) return null;

    try {
      return _construir(
        becas,
        voluntariados,
        desdeCache: true,
        descargado: DateTime.tryParse(prefs.getString(_claveDescargado) ?? ''),
      );
    } catch (_) {
      // Caché corrupta o de un contrato que ya no se entiende: mejor
      // tratarla como inexistente que reventar al abrir.
      return null;
    }
  }
}

String? _masAntigua(String? a, String? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.compareTo(b) <= 0 ? a : b;
}

/* ------------------------------------------------------------
   El sobre público del catálogo.

   Forma esperada, documentada en docs/esquema-datos.md:

     { "version": 1, "generado": "...", "actualizado": "AAAA-MM-DD",
       "ejemplo": false, "becas": [ ... ] }
   ------------------------------------------------------------ */

class _Sobre {
  const _Sobre({
    required this.items,
    required this.actualizado,
    required this.ejemplo,
  });

  final List<dynamic> items;
  final String? actualizado;
  final bool ejemplo;

  static _Sobre leer(String cuerpo, String clave) {
    final crudo = jsonDecode(cuerpo);

    // Un arreglo pelado es el formato viejo, anterior al contrato
    // versionado. Se rechaza explícitamente para que el fallo se lea
    // como "hay que actualizar" y no como un error raro de parseo.
    if (crudo is! Map<String, dynamic>) {
      throw CatalogoIncompatible(crudo is List ? 'sin versión (formato antiguo)' : null);
    }

    final version = crudo['version'];
    if (version is! int) throw CatalogoIncompatible(version);

    // Una versión MAYOR trae cambios que esta app no conoce. Una menor
    // se acepta: dentro de una versión solo se agregan campos, y los
    // que falten ya los tolera el modelo. Pasa cuando el sitio todavía
    // no se ha redesplegado.
    if (version > versionCatalogoSoportada) throw CatalogoIncompatible(version);

    final items = crudo[clave];
    if (items is! List) throw CatalogoIncompatible('falta la clave "$clave"');

    return _Sobre(
      items: items,
      actualizado: crudo['actualizado'] is String ? crudo['actualizado'] as String : null,
      ejemplo: crudo['ejemplo'] == true,
    );
  }

  /// Convierte las fichas, descartando en silencio las que no son
  /// publicables. Una ficha rota no puede tumbar el catálogo entero.
  List<T> convertir<T>(T? Function(Map<String, dynamic>) desdeJson) {
    return items
        .whereType<Map<String, dynamic>>()
        .map(desdeJson)
        .whereType<T>()
        .toList();
  }
}
