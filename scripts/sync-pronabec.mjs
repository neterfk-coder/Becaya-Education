/* ============================================================
   sync-pronabec.mjs — histórico oficial de convocatorias
   ------------------------------------------------------------
   Trae las convocatorias del portal de datos abiertos de Pronabec
   y las deja en data/pronabec.json. Luego llama a construir-datos.mjs,
   que las une con data/manual.json SIN pisarlo.

   Uso:
     node scripts/sync-pronabec.mjs

   No hace falta clave de API.

   ------------------------------------------------------------
   QUÉ TRAE Y QUÉ NO  (comprobado el 2026-08-12)
   ------------------------------------------------------------
   Trae 403 convocatorias oficiales de Pronabec, de pregrado y de
   posgrado, con fechas EXACTAS de inicio y fin de inscripción. No son
   estimaciones ni texto interpretado: vienen como campos de su propia
   base de datos.

   PERO todas son de 2012 a 2021. El portal de datos abiertos dejó de
   actualizarse en diciembre de 2021, y su dataset de convocatorias
   vigentes ("ConvocatoriaCarreraVigentes") devuelve una lista vacía.

   Por eso lo que este script importa aparece SIEMPRE en el grupo
   "Ya cerradas" de la web. Sirve para ver en qué mes suele abrir cada
   beca, no para saber qué está abierto hoy. Para eso está
   scripts/vigilar-pronabec.mjs, que vigila la web viva de Pronabec.

   ------------------------------------------------------------
   POR QUÉ NO SE USA LA API DOCUMENTADA
   ------------------------------------------------------------
   La documentación oficial manda a api.datosabiertos.pronabec.gob.pe,
   un host que NO EXISTE en DNS (NXDOMAIN desde un DNS doméstico y
   desde 8.8.8.8). Pedir una clave de API es inútil: no hay servidor al
   que presentarla. Los endpoints internos del portal, en cambio,
   responden y no piden autenticación. Son los que se usan aquí.
   ============================================================ */

import { writeFile, mkdir } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { construir } from "./construir-datos.mjs";

const RAIZ = resolve(dirname(fileURLToPath(import.meta.url)), "..");

const PORTAL = "https://datosabiertos.pronabec.gob.pe";
const LISTADO = `${PORTAL}/Dataset/ListarConvocatorias`;
const FICHA = `${PORTAL}/dataset/Convocatorias`;
const UA = "Mozilla/5.0 (compatible; becaya-bot/1.0; importa datos abiertos publicos)";
const ESPERA_MS = 45000;

/* El listado llega en formato jqGrid: filas con celdas POSICIONALES, sin
   nombre. Si Pronabec reordena las columnas, los datos saldrían mal en
   silencio, así que se comprueba la forma antes de confiar en ella. */
const COL = {
  id: 1, codigo: 2, descripcion: 3, modalidad: 4, programa: 5,
  ofertadas: 6, iniInscripcion: 9, finInscripcion: 10
};
const COLUMNAS_ESPERADAS = 19;

async function descargar() {
  const cuerpo = new URLSearchParams({ page: "1", rows: "5000", sidx: "", sord: "asc" });
  const r = await fetch(LISTADO, {
    method: "POST",
    headers: {
      "User-Agent": UA,
      "X-Requested-With": "XMLHttpRequest",
      "Content-Type": "application/x-www-form-urlencoded"
    },
    body: cuerpo,
    signal: AbortSignal.timeout(ESPERA_MS)
  });
  if (!r.ok) throw new Error(`El portal respondió ${r.status}`);

  const datos = await r.json();
  if (!Array.isArray(datos.rows)) throw new Error("La respuesta no trae filas");
  if (datos.rows.length === 0) throw new Error("El portal devolvió cero convocatorias");

  const ancho = datos.rows[0].cell?.length;
  if (ancho !== COLUMNAS_ESPERADAS) {
    throw new Error(
      `El listado cambió de forma: ${ancho} columnas en vez de ${COLUMNAS_ESPERADAS}. ` +
      `Revisa ${FICHA} y corrige el mapa COL antes de volver a importar.`
    );
  }
  if (datos.records && datos.rows.length < datos.records) {
    console.warn(`Aviso: el portal dice tener ${datos.records} y envió ${datos.rows.length}.`);
  }
  return datos.rows.map((f) => f.cell);
}

/* "25/11/2012" -> "2012-11-25". Formato peruano: día primero. */
function aISO(valor) {
  const m = String(valor ?? "").match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})/);
  if (!m) return null;
  const [, d, mes, a] = m;
  const iso = `${a}-${mes.padStart(2, "0")}-${d.padStart(2, "0")}`;
  const prueba = new Date(Number(a), Number(mes) - 1, Number(d));
  return prueba.getFullYear() === Number(a) && prueba.getMonth() === Number(mes) - 1
    ? iso : null;
}

/* El nivel sale del nombre del programa y de la modalidad, que es lo
   que Pronabec usa para distinguirlos. Ante la duda, pregrado: Beca 18
   y sus variantes son la mayor parte del histórico. */
function deducirNivel(texto) {
  const t = texto.toLowerCase();
  if (/postgrado|posgrado|maestr|doctor|especializ|docente/.test(t)) return "posgrado";
  return "pregrado";
}

function deducirDestino(texto) {
  return /extranjero|internacional|exterior/i.test(texto) ? "extranjero" : "peru";
}

function babosa(texto) {
  return String(texto)
    .normalize("NFD").replace(/[\u0300-\u036f]/g, "")
    .toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 60);
}

function normalizar(cel, verificadaEl) {
  const nombre = String(cel[COL.descripcion] || "").trim();
  const modalidad = String(cel[COL.modalidad] || "").trim();
  const programa = String(cel[COL.programa] || "").trim();
  const codigo = String(cel[COL.codigo] || "").trim();
  const contexto = `${nombre} ${modalidad} ${programa}`;

  const apertura = aISO(cel[COL.iniInscripcion]);
  const cierre = aISO(cel[COL.finInscripcion]);
  const ofertadas = Number(cel[COL.ofertadas]);

  return {
    id: "pronabec-" + babosa(`${codigo}-${cel[COL.id]}-${nombre}`),
    nombre: codigo && !nombre.includes(codigo) ? `${nombre} (${codigo})` : nombre,
    institucion: "Pronabec",
    nivel: deducirNivel(contexto),
    destino: deducirDestino(contexto),
    pais: deducirDestino(contexto) === "peru" ? "Perú" : "Varios países",
    /* El dataset no publica la cobertura, y suponerla sería inventar. */
    cobertura: "parcial",
    areas: programa ? [programa] : ["Todas las áreas"],
    apertura,
    cierre,
    resumen: [
      modalidad && modalidad !== nombre ? modalidad + "." : "",
      Number.isFinite(ofertadas) && ofertadas > 0 ? `${ofertadas} becas ofertadas.` : "",
      "Convocatoria histórica del registro de datos abiertos de Pronabec."
    ].filter(Boolean).join(" "),
    requisitos: [],
    beneficios: [],
    enlace: "https://www.pronabec.gob.pe/concursos-becas-creditos/",
    fuente: "Pronabec (datos abiertos)",
    verificadaEl,
    notaVerificacion:
      `Importada de ${LISTADO} el ${verificadaEl}. Fechas exactas de inicio y fin de ` +
      `inscripción tomadas del registro oficial, sin interpretar texto. Convocatoria ` +
      `histórica: el portal no se actualiza desde diciembre de 2021.`
  };
}

function hoyISO() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

async function guardar(ruta, contenido) {
  const destino = resolve(RAIZ, ruta);
  await mkdir(dirname(destino), { recursive: true });
  await writeFile(destino, contenido, "utf8");
  console.log("Escrito: " + ruta);
}

async function principal() {
  console.log("Descargando el histórico de convocatorias de Pronabec…");
  const filas = await descargar();
  console.log(`${filas.length} registros recibidos.`);

  const hoy = hoyISO();
  const todas = filas.map((f) => normalizar(f, hoy));

  /* Sin ninguna fecha no hay nada verificable que mostrar. */
  const conFecha = todas.filter((b) => b.apertura || b.cierre);
  const sinFecha = todas.length - conFecha.length;

  /* Un id repetido rompería los favoritos del usuario. Gana el primero. */
  const porId = new Map();
  let repetidos = 0;
  for (const b of conFecha) {
    if (porId.has(b.id)) { repetidos++; continue; }
    porId.set(b.id, b);
  }
  const becas = [...porId.values()];

  if (sinFecha) console.warn(`${sinFecha} sin fecha de inscripción: fuera.`);
  if (repetidos) console.warn(`${repetidos} con id repetido: fuera.`);

  const cierres = becas.map((b) => b.cierre).filter(Boolean).sort();
  const masReciente = cierres[cierres.length - 1];
  const vigentes = becas.filter((b) => !b.cierre || b.cierre >= hoy).length;

  console.log(`\n${becas.length} convocatorias listas.`);
  console.log(`Cierre más reciente del histórico: ${masReciente}`);
  if (vigentes === 0) {
    console.log(
      "\nNinguna sigue vigente: todas entrarán en el grupo \"Ya cerradas\".\n" +
      "Es lo esperado — el portal de datos abiertos no se actualiza desde 2021.\n" +
      "Para las convocatorias vigentes usa: node scripts/vigilar-pronabec.mjs"
    );
  }

  await guardar("data/pronabec.json", JSON.stringify({
    _comentario:
      "GENERADO por scripts/sync-pronabec.mjs desde el portal de datos abiertos de Pronabec. " +
      "No editar a mano: se sobrescribe en cada importación. Histórico 2012-2021; el portal " +
      "no publica convocatorias vigentes.",
    actualizado: hoy,
    ejemplo: false,
    becas
  }, null, 2) + "\n");

  console.log("\nUniendo con las becas cargadas a mano…");
  await construir();
}

principal().catch((error) => {
  console.error("Falló la importación:", error.message);
  process.exit(1);
});
