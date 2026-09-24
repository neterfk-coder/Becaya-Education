/* ============================================================
   estado.dart — el motor del calendario
   ------------------------------------------------------------
   Puerto de assets/js/estado.js. Aquí vive la única regla
   importante del proyecto: comparar la apertura y el cierre con
   el día de hoy para saber en qué grupo cae cada convocatoria.

   ESTE ARCHIVO ESTÁ DUPLICADO A PROPÓSITO. No se puede calcular
   en el servidor porque el resultado depende de "hoy", así que
   web y app tienen que hacer la misma cuenta cada una por su
   lado. Si cambias uno, cambia el otro: test/estado_test.dart
   son las mismas pruebas de scripts/probar.mjs y existen para
   que las dos versiones no se separen en silencio.

   No depende de Flutter: es Dart puro y se prueba sin widgets.
   ============================================================ */

const _meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'setiembre', 'octubre', 'noviembre', 'diciembre',
];

const _diaEnMs = 86400000;

/// Fecha de hoy, a las 00:00, para que las comparaciones no dependan
/// de la hora a la que el usuario abra la app.
DateTime hoy() {
  final d = DateTime.now();
  return DateTime(d.year, d.month, d.day);
}

/// Convierte "2026-09-15" en una fecha local.
///
/// Ojo: `DateTime.parse("2026-09-15")` la interpreta como UTC y en Perú
/// se corre un día hacia atrás — el mismo bug que tenía la web. Por eso
/// se parte el texto a mano, igual que en estado.js.
DateTime? aFecha(String? texto) {
  if (texto == null || texto.isEmpty) return null;
  final partes = texto.split('-');
  if (partes.length != 3) return null;
  final a = int.tryParse(partes[0]);
  final m = int.tryParse(partes[1]);
  final d = int.tryParse(partes[2]);
  if (a == null || m == null || d == null) return null;
  return DateTime(a, m, d);
}

/// Días enteros entre dos fechas. Se calcula sobre milisegundos y se
/// redondea, igual que la web, para que las dos den el mismo número.
int diasEntre(DateTime desde, DateTime hasta) {
  final ms = hasta.millisecondsSinceEpoch - desde.millisecondsSinceEpoch;
  return (ms / _diaEnMs).round();
}

/// "15 de setiembre" — agrega el año solo si no es el año en curso.
String formatoFecha(DateTime? fecha) {
  if (fecha == null) return 'Sin fecha';
  final base = '${fecha.day} de ${_meses[fecha.month - 1]}';
  return fecha.year == hoy().year ? base : '$base de ${fecha.year}';
}

/// Texto para cantidades de días, sin sonar a robot.
String enDias(int n) {
  if (n == 0) return 'hoy';
  if (n == 1) return 'mañana';
  if (n < 7) return 'en $n días';
  if (n < 14) return 'en una semana';
  if (n < 31) return 'en ${(n / 7).round()} semanas';
  if (n < 60) return 'en un mes';
  return 'en ${(n / 30).round()} meses';
}

String quedanDias(int n) {
  if (n == 0) return 'Cierra hoy';
  if (n == 1) return 'Cierra mañana';
  if (n <= 45) return 'Quedan $n días';
  final meses = (n / 30).round();
  return meses == 1 ? 'Queda un mes' : 'Quedan $meses meses';
}

/// Todo lo que la interfaz necesita saber de una convocatoria para
/// pintarla, sin que la interfaz tenga que hacer cuentas.
class Estado {
  const Estado({
    required this.grupo,
    required this.clave,
    required this.titular,
    required this.detalle,
    required this.urgente,
    required this.progreso,
    this.apertura,
    this.cierre,
    this.faltanParaAbrir,
    this.faltanParaCerrar,
  });

  /// Grupo del calendario: abiertas, esta-semana, este-mes, mas-adelante, cerradas.
  final String grupo;

  /// Estado visual: abierta, proxima, cerrada.
  final String clave;

  /// Línea grande: "Quedan 5 días", "Abre en 2 semanas".
  final String titular;

  /// Línea de apoyo: "Cierra el 20 de octubre".
  final String detalle;

  /// Cierra dentro de 7 días o menos. Único caso que pinta en naranja.
  final bool urgente;

  /// Porcentaje de plazo que QUEDA (no el transcurrido): 100 recién
  /// abierta, 0 el día del cierre.
  final int progreso;

  final DateTime? apertura;
  final DateTime? cierre;
  final int? faltanParaAbrir;
  final int? faltanParaCerrar;

  bool get abierta => grupo == 'abiertas';
  bool get cerrada => grupo == 'cerradas';
}

/// Algo con fechas publicadas. Lo cumplen tanto las becas como los
/// voluntariados: el motor no sabe ni le importa cuál le mandes.
abstract class ConFechas {
  String? get apertura;
  String? get cierre;
}

/// El cálculo central.
///
/// [referencia] existe solo para las pruebas: permite preguntar "¿en qué
/// grupo caería esto el 12 de agosto?" sin depender del reloj real.
Estado calcularEstado(ConFechas item, [DateTime? referencia]) {
  final ahora = referencia ?? hoy();
  final apertura = aFecha(item.apertura);
  final cierre = aFecha(item.cierre);

  final faltanParaAbrir = apertura == null ? null : diasEntre(ahora, apertura);
  final faltanParaCerrar = cierre == null ? null : diasEntre(ahora, cierre);

  /* Ya cerró */
  if (cierre != null && faltanParaCerrar! < 0) {
    return Estado(
      grupo: 'cerradas',
      clave: 'cerrada',
      titular: 'Convocatoria cerrada',
      detalle: 'Cerró el ${formatoFecha(cierre)}',
      urgente: false,
      progreso: 0,
      apertura: apertura,
      cierre: cierre,
      faltanParaAbrir: faltanParaAbrir,
      faltanParaCerrar: faltanParaCerrar,
    );
  }

  /* Aún no abre */
  if (apertura != null && faltanParaAbrir! > 0) {
    var grupo = 'mas-adelante';
    if (faltanParaAbrir <= 7) {
      grupo = 'esta-semana';
    } else if (faltanParaAbrir <= 31) {
      grupo = 'este-mes';
    }

    return Estado(
      grupo: grupo,
      clave: 'proxima',
      titular: 'Abre ${enDias(faltanParaAbrir)}',
      detalle: 'Apertura: ${formatoFecha(apertura)}',
      urgente: false,
      progreso: 0,
      apertura: apertura,
      cierre: cierre,
      faltanParaAbrir: faltanParaAbrir,
      faltanParaCerrar: faltanParaCerrar,
    );
  }

  /* Está abierta ahora mismo */
  final total = (apertura != null && cierre != null)
      ? (diasEntre(apertura, cierre) < 1 ? 1 : diasEntre(apertura, cierre))
      : null;

  final progreso = total != null
      ? ((faltanParaCerrar! / total) * 100).round().clamp(0, 100)
      : 100;

  return Estado(
    grupo: 'abiertas',
    clave: 'abierta',
    titular: cierre != null ? quedanDias(faltanParaCerrar!) : 'Abierta',
    detalle: cierre != null
        ? 'Cierra el ${formatoFecha(cierre)}'
        : 'Sin fecha de cierre publicada',
    urgente: faltanParaCerrar != null && faltanParaCerrar <= 7,
    progreso: progreso,
    apertura: apertura,
    cierre: cierre,
    faltanParaAbrir: faltanParaAbrir,
    faltanParaCerrar: faltanParaCerrar,
  );
}

/// Un grupo del calendario, en el orden en que se muestra.
class Grupo {
  const Grupo({
    required this.id,
    required this.titulo,
    required this.nota,
    this.destacado = false,
    this.apagado = false,
  });

  final String id;
  final String titulo;
  final String nota;
  final bool destacado;
  final bool apagado;
}

const grupos = <Grupo>[
  Grupo(
    id: 'abiertas',
    titulo: 'Abiertas ahora',
    nota: 'Puedes postular hoy mismo',
    destacado: true,
  ),
  Grupo(
    id: 'esta-semana',
    titulo: 'Abren esta semana',
    nota: 'Ten los documentos listos',
  ),
  Grupo(
    id: 'este-mes',
    titulo: 'Abren este mes',
    nota: 'Dentro de los próximos 31 días',
  ),
  Grupo(
    id: 'mas-adelante',
    titulo: 'Más adelante',
    nota: 'Para ir planificando',
  ),
  Grupo(
    id: 'cerradas',
    titulo: 'Ya cerradas',
    nota: 'Sirven para anticipar el próximo ciclo',
    apagado: true,
  ),
];

/// Posición de cada grupo, para ordenar sin depender del orden en que
/// vengan las convocatorias.
final ordenGrupos = {
  for (var i = 0; i < grupos.length; i++) grupos[i].id: i,
};

/// Orden de la lista: primero por grupo, después por urgencia dentro
/// del grupo.
///
/// El grupo TIENE que entrar en la comparación. En una sola lista, las
/// cerradas tienen días restantes negativos y sin esto se colaban
/// arriba de las que están abiertas — el bug que tenía la cuadrícula
/// de la web.
///
/// A diferencia de la web, aquí el comparador recibe los estados y no
/// las becas: en Dart es más limpio y la regla es idéntica.
int ordenarPorUrgencia(Estado a, Estado b) {
  final grupoA = ordenGrupos[a.grupo] ?? 99;
  final grupoB = ordenGrupos[b.grupo] ?? 99;
  if (grupoA != grupoB) return grupoA - grupoB;

  /* Abiertas: primero la que cierra antes. */
  if (a.grupo == 'abiertas') {
    return (a.faltanParaCerrar ?? 9999) - (b.faltanParaCerrar ?? 9999);
  }

  /* Cerradas: primero la que cerró hace menos tiempo. */
  if (a.grupo == 'cerradas') {
    return (b.faltanParaCerrar ?? -9999) - (a.faltanParaCerrar ?? -9999);
  }

  /* Próximas: primero la que abre antes. */
  return (a.faltanParaAbrir ?? 9999) - (b.faltanParaAbrir ?? 9999);
}
