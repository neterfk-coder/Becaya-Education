/* ============================================================
   estado.js — el motor del calendario
   ------------------------------------------------------------
   Aquí vive la única regla importante del proyecto: comparar la
   fecha de apertura y la de cierre con el día de hoy para saber
   en qué grupo cae cada convocatoria.

   No depende de ninguna librería ni de ninguna API. Si mañana
   cambias de fuente de datos, este archivo sigue funcionando
   igual mientras cada beca traiga sus dos fechas.
   ============================================================ */

const MESES = [
  "enero", "febrero", "marzo", "abril", "mayo", "junio",
  "julio", "agosto", "setiembre", "octubre", "noviembre", "diciembre"
];

const DIA_EN_MS = 86400000;

/* Fecha de hoy, a las 00:00, para que las comparaciones no dependan de la hora. */
function hoy() {
  const d = new Date();
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

/* Convierte "2026-09-15" en una fecha local.
   Ojo: new Date("2026-09-15") la interpreta como UTC y en Perú
   se corre un día hacia atrás. Por eso se parte el texto a mano. */
function aFecha(texto) {
  if (!texto) return null;
  const [a, m, d] = texto.split("-").map(Number);
  return new Date(a, m - 1, d);
}

function diasEntre(desde, hasta) {
  return Math.round((hasta - desde) / DIA_EN_MS);
}

/* "15 de setiembre" — agrega el año solo si no es el año en curso. */
function formatoFecha(fecha) {
  if (!fecha) return "Sin fecha";
  const base = `${fecha.getDate()} de ${MESES[fecha.getMonth()]}`;
  return fecha.getFullYear() === hoy().getFullYear()
    ? base
    : `${base} de ${fecha.getFullYear()}`;
}

/* Texto para cantidades de días, sin sonar a robot. */
function enDias(n) {
  if (n === 0) return "hoy";
  if (n === 1) return "mañana";
  if (n < 7) return `en ${n} días`;
  if (n < 14) return "en una semana";
  if (n < 31) return `en ${Math.round(n / 7)} semanas`;
  if (n < 60) return "en un mes";
  return `en ${Math.round(n / 30)} meses`;
}

function quedanDias(n) {
  if (n === 0) return "Cierra hoy";
  if (n === 1) return "Cierra mañana";
  if (n <= 45) return `Quedan ${n} días`;
  const meses = Math.round(n / 30);
  return meses === 1 ? "Queda un mes" : `Quedan ${meses} meses`;
}

/* ------------------------------------------------------------
   El cálculo central.
   Devuelve todo lo que la interfaz necesita saber de una beca
   para pintarla, sin que la interfaz tenga que hacer cuentas.
   ------------------------------------------------------------ */
function calcularEstado(beca, referencia) {
  const ahora = referencia || hoy();
  const apertura = aFecha(beca.apertura);
  const cierre = aFecha(beca.cierre);

  const faltanParaAbrir = apertura ? diasEntre(ahora, apertura) : null;
  const faltanParaCerrar = cierre ? diasEntre(ahora, cierre) : null;

  /* Ya cerró */
  if (cierre && faltanParaCerrar < 0) {
    return {
      grupo: "cerradas",
      clave: "cerrada",
      titular: "Convocatoria cerrada",
      detalle: `Cerró el ${formatoFecha(cierre)}`,
      urgente: false,
      progreso: 0,
      apertura, cierre,
      faltanParaAbrir, faltanParaCerrar
    };
  }

  /* Aún no abre */
  if (apertura && faltanParaAbrir > 0) {
    let grupo = "mas-adelante";
    if (faltanParaAbrir <= 7) grupo = "esta-semana";
    else if (faltanParaAbrir <= 31) grupo = "este-mes";

    return {
      grupo,
      clave: "proxima",
      titular: `Abre ${enDias(faltanParaAbrir)}`,
      detalle: `Apertura: ${formatoFecha(apertura)}`,
      urgente: false,
      progreso: 0,
      apertura, cierre,
      faltanParaAbrir, faltanParaCerrar
    };
  }

  /* Está abierta ahora mismo */
  const total = apertura && cierre ? Math.max(diasEntre(apertura, cierre), 1) : null;
  const progreso = total !== null
    ? Math.max(0, Math.min(100, Math.round((faltanParaCerrar / total) * 100)))
    : 100;

  return {
    grupo: "abiertas",
    clave: "abierta",
    titular: cierre ? quedanDias(faltanParaCerrar) : "Abierta",
    detalle: cierre
      ? `Cierra el ${formatoFecha(cierre)}`
      : "Sin fecha de cierre publicada",
    urgente: faltanParaCerrar !== null && faltanParaCerrar <= 7,
    progreso,
    apertura, cierre,
    faltanParaAbrir, faltanParaCerrar
  };
}

/* Definición de los grupos del calendario, en el orden en que se muestran. */
const GRUPOS = [
  {
    id: "abiertas",
    titulo: "Abiertas ahora",
    nota: "Puedes postular hoy mismo",
    destacado: true
  },
  {
    id: "esta-semana",
    titulo: "Abren esta semana",
    nota: "Ten los documentos listos",
    destacado: false
  },
  {
    id: "este-mes",
    titulo: "Abren este mes",
    nota: "Dentro de los próximos 31 días",
    destacado: false
  },
  {
    id: "mas-adelante",
    titulo: "Más adelante",
    nota: "Para ir planificando",
    destacado: false
  },
  {
    id: "cerradas",
    titulo: "Ya cerradas",
    nota: "Sirven para anticipar el próximo ciclo",
    destacado: false,
    apagado: true
  }
];

/* Posición de cada grupo, para poder ordenar sin depender del orden
   en que vengan las becas. */
const ORDEN_GRUPOS = new Map(GRUPOS.map((grupo, i) => [grupo.id, i]));

/* ------------------------------------------------------------
   Orden de la lista.

   Primero por grupo y después por urgencia dentro del grupo. El
   grupo tiene que entrar en la comparación: en la vista de
   cuadrícula todas las becas van en una sola lista, y sin esto
   las cerradas (que tienen días restantes negativos) se colaban
   arriba de las que están abiertas.
   ------------------------------------------------------------ */
function ordenarPorUrgencia(a, b) {
  const grupoA = ORDEN_GRUPOS.get(a.estado.grupo) ?? 99;
  const grupoB = ORDEN_GRUPOS.get(b.estado.grupo) ?? 99;
  if (grupoA !== grupoB) return grupoA - grupoB;

  /* Abiertas: primero la que cierra antes. */
  if (a.estado.grupo === "abiertas") {
    return (a.estado.faltanParaCerrar ?? 9999) - (b.estado.faltanParaCerrar ?? 9999);
  }

  /* Cerradas: primero la que cerró hace menos tiempo. */
  if (a.estado.grupo === "cerradas") {
    return (b.estado.faltanParaCerrar ?? -9999) - (a.estado.faltanParaCerrar ?? -9999);
  }

  /* Próximas: primero la que abre antes. */
  return (a.estado.faltanParaAbrir ?? 9999) - (b.estado.faltanParaAbrir ?? 9999);
}
