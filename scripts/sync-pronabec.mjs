/* ============================================================
   sync-pronabec.mjs
   ------------------------------------------------------------
   Trae las convocatorias vigentes desde la API de datos abiertos
   de Pronabec y las deja en data/pronabec.json.

   Uso:
     PRONABEC_API_KEY=tu_clave node scripts/sync-pronabec.mjs

   Genera:
     data/pronabec-crudo.json   respuesta tal como llega, para depurar
     data/pronabec.json         convocatorias normalizadas

   Y luego llama a construir-datos.mjs, que une esto con
   data/manual.json y reescribe assets/js/datos.js.

   IMPORTANTE: este script NO toca data/manual.json. Las becas
   internacionales cargadas a mano sobreviven a cada sincronización.

   Consigue tu clave gratis en:
     https://datosabiertos.pronabec.gob.pe/developer/Api

   ANTES DEL PRIMER USO: el nombre del recurso (RECURSO) tiene que
   coincidir con el "Apiguid" de la documentación oficial. Revisa
   https://datosabiertos.pronabec.gob.pe/developer/data y ajusta la
   constante de abajo. Lo mismo con los nombres de campo dentro de
   normalizar(): la API los publica en español y varían entre datasets.
   ============================================================ */

import { writeFile, mkdir } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { construir, enlaceSeguro } from "./construir-datos.mjs";

const RAIZ = resolve(dirname(fileURLToPath(import.meta.url)), "..");

const API = "https://api.datosabiertos.pronabec.gob.pe/developer";
const RECURSO = "ConvocatoriasVigentes";
const CLAVE = process.env.PRONABEC_API_KEY;

const MAX_PAGINAS = 100;
const ESPERA_MS = 20000;

if (!CLAVE) {
  console.error("Falta la clave. Ejecuta: PRONABEC_API_KEY=tu_clave node scripts/sync-pronabec.mjs");
  process.exit(1);
}

/* La clave viaja en la URL, así que nunca imprimimos la URL completa. */
function sinClave(texto) {
  return String(texto).replaceAll(CLAVE, "***");
}

/* ---------- Descarga con paginado ---------- */

/* El corte del paginado no asume un tamaño de página fijo: la API
   podría devolver 10, 50 o 500 por página. Se detiene cuando llega
   una página vacía, cuando devuelve menos registros que la primera,
   o cuando deja de aportar ids nuevos (defensa contra una API que
   ignora el parámetro `page` y repite la primera página para siempre). */
async function descargarTodo() {
  const filas = [];
  const vistos = new Set();
  let tamañoPagina = null;

  for (let pagina = 1; pagina <= MAX_PAGINAS; pagina++) {
    const url = `${API}/${RECURSO}?apiKey=${encodeURIComponent(CLAVE)}&page=${pagina}`;

    let respuesta;
    try {
      respuesta = await fetch(url, { signal: AbortSignal.timeout(ESPERA_MS) });
    } catch (error) {
      throw new Error(`No se pudo conectar en la página ${pagina}: ${sinClave(error.message)}`);
    }

    if (!respuesta.ok) {
      throw new Error(`La API respondió ${respuesta.status} en la página ${pagina}`);
    }

    let cuerpo;
    try {
      cuerpo = await respuesta.json();
    } catch {
      throw new Error(`La página ${pagina} no devolvió JSON válido (¿la clave es correcta?)`);
    }

    const lote = Array.isArray(cuerpo) ? cuerpo : (cuerpo.results || cuerpo.data || cuerpo.items || []);
    if (!Array.isArray(lote) || lote.length === 0) break;

    /* Registros que no habíamos visto en páginas anteriores. */
    const nuevos = lote.filter((fila) => {
      const huella = JSON.stringify(fila);
      if (vistos.has(huella)) return false;
      vistos.add(huella);
      return true;
    });

    if (nuevos.length === 0) {
      console.warn(`Página ${pagina} repite registros anteriores: se corta el paginado aquí.`);
      break;
    }

    filas.push(...nuevos);
    console.log(`Página ${pagina}: ${nuevos.length} registros nuevos`);

    if (tamañoPagina === null) tamañoPagina = lote.length;
    if (lote.length < tamañoPagina) break;
  }

  return filas;
}

/* ---------- Normalización ---------- */

/* Convierte cualquier formato de fecha razonable a AAAA-MM-DD. */
function aISO(valor) {
  if (!valor) return null;
  const texto = String(valor).trim();

  const iso = texto.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (iso) return `${iso[1]}-${iso[2]}-${iso[3]}`;

  /* Formato peruano: día primero. */
  const latino = texto.match(/^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})/);
  if (latino) {
    const d = latino[1].padStart(2, "0");
    const m = latino[2].padStart(2, "0");
    return `${latino[3]}-${m}-${d}`;
  }

  /* Último recurso. Se arma con los componentes locales, no con
     toISOString(), que en Perú (UTC-5) puede correr la fecha un día. */
  const fecha = new Date(texto);
  if (isNaN(fecha.getTime())) return null;
  const mes = String(fecha.getMonth() + 1).padStart(2, "0");
  const dia = String(fecha.getDate()).padStart(2, "0");
  return `${fecha.getFullYear()}-${mes}-${dia}`;
}

function deducirNivel(texto = "") {
  const t = texto.toLowerCase();
  if (/maestr|doctor|posgrad|postgrad|especializ/.test(t)) return "posgrado";
  return "pregrado";
}

function aBabosa(texto) {
  return String(texto)
    .normalize("NFD").replace(/[\u0300-\u036f]/g, "")
    .toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
}

function normalizar(fila) {
  const nombre = fila.NombreConvocatoria || fila.Convocatoria || fila.Nombre || "Convocatoria sin nombre";

  return {
    id: "pronabec-" + aBabosa(fila.IdConvocatoria || fila.Id || nombre),
    nombre,
    institucion: "Pronabec",
    nivel: deducirNivel(nombre + " " + (fila.Modalidad || "")),
    destino: "peru",
    pais: "Perú",
    cobertura: "total",
    areas: fila.Carrera ? [fila.Carrera] : ["Todas las áreas"],
    apertura: aISO(fila.FechaInicio || fila.FechaApertura),
    cierre: aISO(fila.FechaFin || fila.FechaCierre),
    resumen: fila.Descripcion || `Convocatoria de Pronabec${fila.Sede ? " — sede " + fila.Sede : ""}.`,
    requisitos: [],
    beneficios: [],
    enlace: enlaceSeguro(fila.Enlace) || "https://www.pronabec.gob.pe/",
    fuente: "Pronabec"
  };
}

/* Sin las dos fechas la beca no puede entrar al calendario. */
function tieneFechas(beca) {
  return Boolean(beca.apertura && beca.cierre);
}

/* Dos convocatorias con el mismo id romperían los favoritos del
   usuario, que se guardan justamente por id. Gana la primera. */
function sinRepetidos(becas) {
  const porId = new Map();
  let repetidos = 0;
  for (const beca of becas) {
    if (porId.has(beca.id)) { repetidos++; continue; }
    porId.set(beca.id, beca);
  }
  if (repetidos > 0) console.warn(`${repetidos} convocatorias con id repetido quedaron fuera.`);
  return Array.from(porId.values());
}

/* ---------- Escritura ---------- */
async function guardar(ruta, contenido) {
  const destino = resolve(RAIZ, ruta);
  await mkdir(dirname(destino), { recursive: true });
  await writeFile(destino, contenido, "utf8");
  console.log("Escrito: " + ruta);
}

function hoyISO() {
  const d = new Date();
  const mes = String(d.getMonth() + 1).padStart(2, "0");
  const dia = String(d.getDate()).padStart(2, "0");
  return `${d.getFullYear()}-${mes}-${dia}`;
}

async function principal() {
  console.log("Consultando la API de Pronabec…");
  const crudo = await descargarTodo();
  console.log(`Total de registros recibidos: ${crudo.length}`);

  if (crudo.length === 0) {
    throw new Error("La API no devolvió ningún registro. Revisa el nombre del recurso antes de continuar; " +
      "no se sobrescribe nada para no vaciar el catálogo por un error de configuración.");
  }

  const normalizadas = sinRepetidos(crudo.map(normalizar));
  const utiles = normalizadas.filter(tieneFechas);
  const descartadas = normalizadas.length - utiles.length;

  if (descartadas > 0) {
    console.warn(`${descartadas} convocatorias quedaron fuera por no traer fecha de apertura y cierre.`);
  }

  await guardar("data/pronabec-crudo.json", JSON.stringify(crudo, null, 2) + "\n");
  await guardar("data/pronabec.json", JSON.stringify({
    _comentario: "GENERADO por scripts/sync-pronabec.mjs. No editar a mano: se sobrescribe en cada sincronización.",
    actualizado: hoyISO(),
    ejemplo: false,
    becas: utiles
  }, null, 2) + "\n");

  console.log(`${utiles.length} convocatorias de Pronabec con fechas completas.`);
  console.log("\nUniendo con las becas cargadas a mano…");
  await construir();
}

principal().catch((error) => {
  console.error("Falló la sincronización:", sinClave(error.message));
  process.exit(1);
});
