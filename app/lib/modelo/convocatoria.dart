/* ============================================================
   convocatoria.dart — el modelo de datos
   ------------------------------------------------------------
   Refleja docs/esquema-datos.md. Becas y voluntariados son dos
   catálogos SEPARADOS a propósito: no comparten tabla, no
   comparten lista y no comparten guardados. Lo único que tienen
   en común son las fechas, y eso vive en ConFechas.

   Todo lo que entra por aquí viene de la red, así que se trata
   como hostil: campos que faltan, tipos equivocados y enlaces
   que no son http se descartan en vez de reventar la pantalla.
   ============================================================ */

import '../motor/estado.dart';

/// Lo común entre una beca y un voluntariado — lo justo para pintar
/// una tarjeta y abrir el detalle.
abstract class Convocatoria implements ConFechas {
  String get id;
  String get nombre;

  /// Quién la otorga u organiza. `institucion` en becas, `organizacion`
  /// en voluntariados: en la tarjeta ocupan el mismo lugar.
  String get entidad;

  String get pais;
  List<String> get areas;
  String get resumen;
  List<String> get requisitos;
  List<String> get beneficios;
  String get enlace;
  String? get imagen;
  String get fuente;

  /// Etiquetas cortas propias de cada tipo, para la fila de chips.
  /// Una beca muestra nivel y cobertura; un voluntariado, modalidad.
  List<String> get etiquetas;
}

/* ------------------------------------------------------------
   Lectura defensiva del JSON.
   ------------------------------------------------------------ */

String _texto(Map<String, dynamic> json, String clave, {String porDefecto = ''}) {
  final v = json[clave];
  return v is String && v.trim().isNotEmpty ? v.trim() : porDefecto;
}

String? _textoOpcional(Map<String, dynamic> json, String clave) {
  final v = json[clave];
  return v is String && v.trim().isNotEmpty ? v.trim() : null;
}

List<String> _lista(Map<String, dynamic> json, String clave) {
  final v = json[clave];
  if (v is! List) return const [];
  return v.whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
}

/// Solo http y https llegan al navegador. Un enlace `javascript:` que
/// viniera del catálogo se ejecutaría al tocarlo.
///
/// El build de la web ya filtra esto (scripts/construir-datos.mjs), pero
/// se repite aquí: la app descarga de la red y no puede dar por sentado
/// que lo que llegó pasó por ese build.
String? enlaceSeguro(Object? valor) {
  if (valor is! String) return null;
  final texto = valor.trim();
  if (texto.isEmpty) return null;
  final url = Uri.tryParse(texto);
  if (url == null || !url.hasScheme) return null;
  return (url.scheme == 'http' || url.scheme == 'https') ? url.toString() : null;
}

/* ------------------------------------------------------------
   Becas
   ------------------------------------------------------------ */

class Beca implements Convocatoria {
  const Beca({
    required this.id,
    required this.nombre,
    required this.institucion,
    required this.nivel,
    required this.destino,
    required this.pais,
    required this.cobertura,
    required this.areas,
    required this.apertura,
    required this.cierre,
    required this.resumen,
    required this.requisitos,
    required this.beneficios,
    required this.enlace,
    required this.imagen,
    required this.fuente,
    required this.verificadaEl,
    required this.notaVerificacion,
  });

  @override final String id;
  @override final String nombre;
  final String institucion;

  /// pregrado | posgrado | ambos
  final String nivel;

  /// peru | extranjero
  final String destino;

  @override final String pais;

  /// total | parcial
  final String cobertura;

  @override final List<String> areas;
  @override final String? apertura;
  @override final String? cierre;
  @override final String resumen;
  @override final List<String> requisitos;
  @override final List<String> beneficios;
  @override final String enlace;
  @override final String? imagen;
  @override final String fuente;

  /// Cuándo se comprobó esta ficha contra la web oficial. En un
  /// directorio de becas el problema no es mostrar datos, es que
  /// envejecen sin que nadie se entere.
  final String? verificadaEl;

  /// De dónde salió exactamente la fecha. Se muestra en el detalle:
  /// el usuario tiene derecho a saber por qué le decimos que cierra
  /// el 20 de octubre.
  final String? notaVerificacion;

  @override String get entidad => institucion;

  @override
  List<String> get etiquetas => [
        if (nivel.isNotEmpty) _capitalizar(nivel),
        if (destino == 'peru') 'En Perú' else if (destino == 'extranjero') 'En el extranjero',
        if (cobertura == 'total') 'Cobertura total' else if (cobertura == 'parcial') 'Cobertura parcial',
      ];

  /// Devuelve null si la ficha no es publicable. Una beca sin enlace o
  /// sin ninguna fecha no se muestra: mandaría al usuario a ningún lado
  /// o le mentiría sobre el plazo.
  static Beca? desdeJson(Map<String, dynamic> json) {
    final id = _texto(json, 'id');
    final enlace = enlaceSeguro(json['enlace']);
    final apertura = _textoOpcional(json, 'apertura');
    final cierre = _textoOpcional(json, 'cierre');

    if (id.isEmpty || enlace == null) return null;
    if (apertura == null && cierre == null) return null;

    return Beca(
      id: id,
      nombre: _texto(json, 'nombre', porDefecto: 'Convocatoria sin nombre'),
      institucion: _texto(json, 'institucion'),
      nivel: _texto(json, 'nivel'),
      destino: _texto(json, 'destino'),
      pais: _texto(json, 'pais'),
      cobertura: _texto(json, 'cobertura'),
      areas: _lista(json, 'areas'),
      apertura: apertura,
      cierre: cierre,
      resumen: _texto(json, 'resumen'),
      requisitos: _lista(json, 'requisitos'),
      beneficios: _lista(json, 'beneficios'),
      enlace: enlace,
      imagen: enlaceSeguro(json['imagen']),
      fuente: _texto(json, 'fuente', porDefecto: 'Sin fuente'),
      verificadaEl: _textoOpcional(json, 'verificadaEl'),
      notaVerificacion: _textoOpcional(json, 'notaVerificacion'),
    );
  }
}

/* ------------------------------------------------------------
   Voluntariados
   ------------------------------------------------------------ */

class Voluntariado implements Convocatoria {
  const Voluntariado({
    required this.id,
    required this.nombre,
    required this.organizacion,
    required this.pais,
    required this.modalidad,
    required this.areas,
    required this.apertura,
    required this.cierre,
    required this.resumen,
    required this.requisitos,
    required this.beneficios,
    required this.enlace,
    required this.imagen,
    required this.fuente,
  });

  @override final String id;
  @override final String nombre;
  final String organizacion;

  /// presencial | virtual | hibrida
  final String modalidad;

  @override final String pais;
  @override final List<String> areas;
  @override final String? apertura;
  @override final String? cierre;
  @override final String resumen;
  @override final List<String> requisitos;
  @override final List<String> beneficios;
  @override final String enlace;
  @override final String? imagen;
  @override final String fuente;

  @override String get entidad => organizacion;

  /// No hay "cobertura": un voluntariado no paga, y llamar "cobertura
  /// parcial" a un certificado sería engañoso.
  @override
  List<String> get etiquetas => [
        if (modalidad == 'hibrida') 'Híbrida' else if (modalidad.isNotEmpty) _capitalizar(modalidad),
        if (pais.isNotEmpty) pais,
      ];

  static Voluntariado? desdeJson(Map<String, dynamic> json) {
    final id = _texto(json, 'id');
    final enlace = enlaceSeguro(json['enlace']);
    final apertura = _textoOpcional(json, 'apertura');
    final cierre = _textoOpcional(json, 'cierre');

    if (id.isEmpty || enlace == null) return null;
    if (apertura == null && cierre == null) return null;

    return Voluntariado(
      id: id,
      nombre: _texto(json, 'nombre', porDefecto: 'Voluntariado sin nombre'),
      organizacion: _texto(json, 'organizacion'),
      pais: _texto(json, 'pais'),
      modalidad: _texto(json, 'modalidad'),
      areas: _lista(json, 'areas'),
      apertura: apertura,
      cierre: cierre,
      resumen: _texto(json, 'resumen'),
      requisitos: _lista(json, 'requisitos'),
      beneficios: _lista(json, 'beneficios'),
      enlace: enlace,
      imagen: enlaceSeguro(json['imagen']),
      fuente: _texto(json, 'fuente', porDefecto: 'Sin fuente'),
    );
  }
}

String _capitalizar(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/* ------------------------------------------------------------
   Una convocatoria ya clasificada, lista para pintar.
   ------------------------------------------------------------ */

class Ficha {
  Ficha(this.item, [DateTime? referencia])
      : estado = calcularEstado(item, referencia);

  final Convocatoria item;
  final Estado estado;
}

/// Clasifica y ordena un catálogo entero. El orden se calcula una vez
/// por carga, no en cada repintado de la lista.
List<Ficha> aFichas(List<Convocatoria> items, [DateTime? referencia]) {
  final fichas = items.map((i) => Ficha(i, referencia)).toList();
  fichas.sort((a, b) => ordenarPorUrgencia(a.estado, b.estado));
  return fichas;
}
