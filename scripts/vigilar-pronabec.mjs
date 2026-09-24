/* ============================================================
   vigilar-pronabec.mjs — el robot detecta, el humano confirma
   ------------------------------------------------------------
   Revisa las páginas de concursos de Pronabec y avisa cuáles
   cambiaron desde la última vez. NO publica nada por su cuenta.

   Uso:
     node scripts/vigilar-pronabec.mjs           revisa y reporta
     node scripts/vigilar-pronabec.mjs --guardar revisa y actualiza el estado

   Sale con código 1 si detecta cambios, para que un workflow de CI
   pueda marcar la ejecución y avisarte.

   ------------------------------------------------------------
   POR QUÉ NO PUBLICA FECHAS SOLO
   ------------------------------------------------------------
   Pronabec escribe los plazos en prosa, no en campos. Al construir
   esto encontramos en su web la frase "la postulación es hasta el
   martes 4 de noviembre", sin año. El 4 de noviembre cae martes en
   2025, no en 2026: un script que hubiera asumido el año en curso
   habría publicado un plazo equivocado por doce meses.

   Por eso aquí solo se extraen dos cosas:

     1. El contador de cuenta regresiva (data-date), que SÍ es un
        dato de máquina: un timestamp exacto. Cuando está, es fiable.
     2. Una huella del texto de la página, para saber si cambió.

   Todo lo demás es trabajo de una persona: leer y confirmar.
   ============================================================ */

import { readFile, writeFile, mkdir } from "node:fs/promises";
import { createHash } from "node:crypto";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const RAIZ = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const ESTADO = "data/vigilancia-pronabec.json";

const BASE = "https://www.pronabec.gob.pe";
const INDICE = `${BASE}/concursos-becas-creditos/`;
const UA = "Mozilla/5.0 (compatible; becaya-bot/1.0; vigila convocatorias publicas)";
const ESPERA_MS = 30000;
const PAUSA_MS = 700;          /* entre páginas, para no golpear el servidor */

/* Páginas de la web que no son convocatorias. */
const NO_SON_CONCURSOS = new Set([
  "concursos-becas-creditos", "aliados-que-transforman", "compromiso-de-servicio-al-peru",
  "materialesdedifusion", "libro-de-reclamaciones-del-pronabec", "normas-beneficiario-del-pronabec",
  "pronabec-en-linea", "pronabec-si-transforma-vidas", "becas-de-cooperacion-internacional"
]);

const dormir = (ms) => new Promise((r) => setTimeout(r, ms));

async function bajar(url) {
  const r = await fetch(url, { headers: { "User-Agent": UA }, signal: AbortSignal.timeout(ESPERA_MS) });
  if (!r.ok) throw new Error(`HTTP ${r.status}`);
  return r.text();
}

/* Texto visible, sin scripts ni estilos: es lo que se compara. Así un
   cambio de CSS o de un script de analítica no cuenta como cambio de
   la convocatoria. */
function aTexto(html) {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<!--[\s\S]*?-->/g, " ")
    .replace(/<[^>]*>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function huella(texto) {
  return createHash("sha256").update(texto).digest("hex").slice(0, 16);
}

/* El contador de la página trae un timestamp exacto: el único dato de
   fecha que se puede leer sin adivinar. Perú es UTC-5 todo el año. */
function plazoDelContador(html) {
  const m = html.match(/data-date="(\d{9,11})"/);
  if (!m) return null;
  const ms = Number(m[1]) * 1000;
  if (!Number.isFinite(ms)) return null;
  const enPeru = new Date(ms - 5 * 3600 * 1000);
  return {
    timestamp: Number(m[1]),
    cierre: enPeru.toISOString().slice(0, 10),
    hora: enPeru.toISOString().slice(11, 16)
  };
}

async function listarConcursos() {
  const html = await bajar(INDICE);
  const slugs = new Set();
  for (const m of html.matchAll(/href="https:\/\/www\.pronabec\.gob\.pe\/([a-z0-9-]{6,60})\/"/g)) {
    const slug = m[1];
    if (NO_SON_CONCURSOS.has(slug)) continue;
    if (/^(wp|category|author|feed|tag)/.test(slug)) continue;
    if (!/^(beca|credito)/.test(slug)) continue;
    slugs.add(slug);
  }
  return [...slugs].sort();
}

async function leerEstado() {
  try {
    return JSON.parse(await readFile(resolve(RAIZ, ESTADO), "utf8"));
  } catch (e) {
    if (e.code === "ENOENT") return { revisadoEl: null, paginas: {} };
    throw e;
  }
}

async function principal() {
  const guardar = process.argv.includes("--guardar");
  const previo = await leerEstado();

  console.log("Consultando la lista de concursos de Pronabec…");
  const slugs = await listarConcursos();
  console.log(`${slugs.length} concursos publicados.\n`);

  const paginas = {};
  const nuevos = [], cambiados = [], plazoMovido = [], fallidos = [];

  for (const slug of slugs) {
    await dormir(PAUSA_MS);
    let html;
    try {
      html = await bajar(`${BASE}/${slug}/`);
    } catch (e) {
      fallidos.push(`${slug}: ${e.message}`);
      /* Se conserva lo que ya sabíamos: un fallo de red no debe borrar
         el historial ni disfrazarse de "cambió". */
      if (previo.paginas[slug]) paginas[slug] = previo.paginas[slug];
      continue;
    }

    const plazo = plazoDelContador(html);
    const actual = { huella: huella(aTexto(html)), cierre: plazo?.cierre ?? null };
    paginas[slug] = actual;

    const antes = previo.paginas[slug];
    if (!antes) {
      nuevos.push(`${slug}${plazo ? `  (cierra ${plazo.cierre})` : ""}`);
    } else if (antes.cierre !== actual.cierre) {
      plazoMovido.push(`${slug}: ${antes.cierre ?? "sin plazo"} → ${actual.cierre ?? "sin plazo"}`);
    } else if (antes.huella !== actual.huella) {
      cambiados.push(slug);
    }
  }

  /* ---------- Informe ---------- */
  const linea = (t) => console.log(t);
  linea("═".repeat(58));
  if (previo.revisadoEl) linea(`Última revisión: ${previo.revisadoEl}`);
  else linea("Primera revisión: se registra el estado actual como punto de partida.");
  linea("═".repeat(58));

  if (plazoMovido.length) {
    linea("\n⚠  CAMBIÓ EL PLAZO — revisa y actualiza data/manual.json:");
    plazoMovido.forEach((x) => linea("   " + x));
  }
  if (nuevos.length) {
    linea("\n+  CONVOCATORIAS NUEVAS — decide si entran al catálogo:");
    nuevos.forEach((x) => linea("   " + x));
  }
  if (cambiados.length) {
    linea("\n·  Cambió el contenido (puede ser solo redacción):");
    cambiados.forEach((x) => linea(`   ${x}  ${BASE}/${x}/`));
  }
  if (fallidos.length) {
    linea("\n✗  No se pudieron revisar:");
    fallidos.forEach((x) => linea("   " + x));
  }

  const hayNovedad = plazoMovido.length + nuevos.length + cambiados.length > 0;
  if (!hayNovedad && previo.revisadoEl) linea("\nSin novedades. Ninguna página cambió.");

  /* Recordatorio de frescura: aunque nada cambie, un catálogo que nadie
     mira envejece igual. */
  try {
    const catalogo = JSON.parse(await readFile(resolve(RAIZ, "data/becas.json"), "utf8"));
    const becas = catalogo.becas ?? [];
    const hoy = new Date().toISOString().slice(0, 10);
    const viejas = becas.filter((b) => {
      if (!b.verificadaEl) return true;
      const dias = (new Date(hoy) - new Date(b.verificadaEl)) / 86400000;
      return dias > 30;
    });
    if (viejas.length) {
      linea(`\n⏳ ${viejas.length} beca(s) sin verificar hace más de 30 días:`);
      viejas.forEach((b) => linea(`   ${b.id}  (última: ${b.verificadaEl ?? "nunca"})`));
    }
  } catch (e) { /* si no hay catálogo todavía, no pasa nada */ }

  if (guardar) {
    const destino = resolve(RAIZ, ESTADO);
    await mkdir(dirname(destino), { recursive: true });
    await writeFile(destino, JSON.stringify({
      _comentario: "GENERADO por scripts/vigilar-pronabec.mjs. Huella del contenido de cada página de concurso, para detectar cambios. No editar a mano.",
      revisadoEl: new Date().toISOString().slice(0, 10),
      paginas
    }, null, 2) + "\n", "utf8");
    linea(`\nEstado guardado en ${ESTADO}`);
  } else if (hayNovedad) {
    linea("\n(Corre con --guardar para dar por vistos estos cambios.)");
  }

  if (hayNovedad && previo.revisadoEl) process.exitCode = 1;
}

principal().catch((e) => {
  console.error("Falló la vigilancia:", e.message);
  process.exit(2);
});
