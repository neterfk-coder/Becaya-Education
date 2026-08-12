/* ============================================================
   construir-datos.mjs
   ------------------------------------------------------------
   Junta las fuentes del catálogo en los archivos que lee el navegador.
   Maneja DOS colecciones independientes, becas y voluntariados, que
   nunca se mezclan entre sí: cada una tiene su propia fuente, su
   propia validación y su propio archivo de salida.

   Entradas (fuentes de verdad, se editan o se generan por separado):
     data/manual.json               becas cargadas a mano
     data/pronabec.json             becas, generado por sync-pronabec.mjs
     data/voluntariados-manual.json voluntariados cargados a mano

   Salidas (generadas, NO se editan a mano):
     data/becas.json                catálogo de becas unido
     data/voluntariados.json        catálogo de voluntariados
     assets/js/datos.js             BECAS, para el navegador
     assets/js/voluntariados.js     VOLUNTARIADOS, para el navegador

   Uso:
     node scripts/construir-datos.mjs

   Por qué existe: antes el sync escribía datos.js completo, así que
   cada sincronización borraba todas las becas cargadas a mano. Ahora
   cada fuente vive en su propio archivo y este script las une.
   ============================================================ */

import { readFile, writeFile, mkdir } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const RAIZ = resolve(dirname(fileURLToPath(import.meta.url)), "..");

const NIVELES = ["pregrado", "posgrado", "ambos"];
const DESTINOS = ["peru", "extranjero"];
const COBERTURAS = ["total", "parcial"];
const MODALIDADES = ["presencial", "virtual", "hibrida"];

/* ------------------------------------------------------------
   Lectura tolerante: si una fuente no existe todavía, se ignora.
   Sirve para trabajar solo con datos manuales antes de tener la
   clave de la API, y al revés. `clave` es el nombre del arreglo
   dentro del archivo ("becas" o "voluntariados").
   ------------------------------------------------------------ */
async function leerFuente(ruta, clave) {
  try {
    const texto = await readFile(resolve(RAIZ, ruta), "utf8");
    const contenido = JSON.parse(texto);
    const items = Array.isArray(contenido) ? contenido : (contenido[clave] || []);
    return {
      items,
      actualizado: Array.isArray(contenido) ? null : contenido.actualizado || null,
      ejemplo: Array.isArray(contenido) ? false : Boolean(contenido.ejemplo)
    };
  } catch (error) {
    if (error.code === "ENOENT") {
      console.log(`(${ruta} no existe todavía, se omite)`);
      return { items: [], actualizado: null, ejemplo: false };
    }
    throw new Error(`No se pudo leer ${ruta}: ${error.message}`);
  }
}

/* ------------------------------------------------------------
   Validación.
   Una beca mal formada no se publica: rompe el calendario o, peor,
   manda al usuario a una página equivocada.
   ------------------------------------------------------------ */

/* Solo http y https llegan al href. Un enlace "javascript:..." que
   viniera de la API se ejecutaría al hacer clic. */
export function enlaceSeguro(valor) {
  if (typeof valor !== "string") return null;
  const texto = valor.trim();
  if (!texto) return null;
  try {
    const url = new URL(texto);
    return url.protocol === "http:" || url.protocol === "https:" ? url.href : null;
  } catch {
    return null;
  }
}

function esFechaISO(valor) {
  if (typeof valor !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(valor)) return false;
  const [a, m, d] = valor.split("-").map(Number);
  const fecha = new Date(a, m - 1, d);
  return fecha.getFullYear() === a && fecha.getMonth() === m - 1 && fecha.getDate() === d;
}

function listaDeTextos(valor) {
  return Array.isArray(valor) ? valor.filter((x) => typeof x === "string" && x.trim()) : [];
}

/* Devuelve la beca normalizada, o un motivo de descarte. */
function revisar(beca, origen) {
  const problemas = [];

  if (!beca || typeof beca !== "object") return { problemas: ["no es un objeto"] };
  if (!beca.id || typeof beca.id !== "string") problemas.push("sin id");
  if (!beca.nombre || typeof beca.nombre !== "string") problemas.push("sin nombre");

  if (!esFechaISO(beca.apertura)) problemas.push(`apertura inválida (${beca.apertura})`);
  if (beca.cierre !== null && beca.cierre !== undefined && !esFechaISO(beca.cierre)) {
    problemas.push(`cierre inválido (${beca.cierre})`);
  }
  if (esFechaISO(beca.apertura) && esFechaISO(beca.cierre) && beca.cierre < beca.apertura) {
    problemas.push(`cierra (${beca.cierre}) antes de abrir (${beca.apertura})`);
  }

  const enlace = enlaceSeguro(beca.enlace);
  if (!enlace) problemas.push(`enlace inválido o inseguro (${beca.enlace})`);

  if (problemas.length > 0) return { problemas };

  /* La imagen es opcional y apunta al sitio oficial de la institución.
     Si no es una URL http(s) válida se descarta sola: una beca sin foto
     se ve bien, una beca con una imagen rota se ve peor que sin nada. */
  const imagen = beca.imagen ? enlaceSeguro(beca.imagen) : null;
  if (beca.imagen && !imagen) {
    console.warn(`  ! ${beca.id}: imagen inválida o insegura (${beca.imagen}), se omite`);
  }

  /* Los campos de filtro caen a un valor por defecto en vez de descartar
     la beca: un nivel mal escrito no justifica esconder la convocatoria. */
  const nivel = NIVELES.includes(beca.nivel) ? beca.nivel : "pregrado";
  const destino = DESTINOS.includes(beca.destino) ? beca.destino : "extranjero";
  const cobertura = COBERTURAS.includes(beca.cobertura) ? beca.cobertura : "parcial";

  if (nivel !== beca.nivel) console.warn(`  ! ${beca.id}: nivel "${beca.nivel}" no válido, se usa "${nivel}"`);
  if (destino !== beca.destino) console.warn(`  ! ${beca.id}: destino "${beca.destino}" no válido, se usa "${destino}"`);
  if (cobertura !== beca.cobertura) console.warn(`  ! ${beca.id}: cobertura "${beca.cobertura}" no válida, se usa "${cobertura}"`);

  const areas = listaDeTextos(beca.areas);

  return {
    beca: {
      id: beca.id,
      nombre: beca.nombre,
      institucion: typeof beca.institucion === "string" && beca.institucion.trim()
        ? beca.institucion
        : "Institución no indicada",
      nivel,
      destino,
      pais: typeof beca.pais === "string" && beca.pais.trim() ? beca.pais : "Sin especificar",
      cobertura,
      areas: areas.length > 0 ? areas : ["Todas las áreas"],
      apertura: beca.apertura,
      cierre: esFechaISO(beca.cierre) ? beca.cierre : null,
      resumen: typeof beca.resumen === "string" ? beca.resumen : "",
      requisitos: listaDeTextos(beca.requisitos),
      beneficios: listaDeTextos(beca.beneficios),
      enlace,
      imagen,
      imagenCredito: imagen && typeof beca.imagenCredito === "string" ? beca.imagenCredito : null,
      fuente: typeof beca.fuente === "string" && beca.fuente.trim() ? beca.fuente : origen
    }
  };
}

/* Igual que revisar(), pero para voluntariados: sin nivel/destino/
   cobertura (no aplican a un voluntariado) y con "organizacion" y
   "modalidad" en su lugar. Vive aparte a propósito, para que un
   cambio en las reglas de las becas no afecte sin querer a esta
   colección, ni viceversa. */
function revisarVoluntariado(v, origen) {
  const problemas = [];

  if (!v || typeof v !== "object") return { problemas: ["no es un objeto"] };
  if (!v.id || typeof v.id !== "string") problemas.push("sin id");
  if (!v.nombre || typeof v.nombre !== "string") problemas.push("sin nombre");

  if (!esFechaISO(v.apertura)) problemas.push(`apertura inválida (${v.apertura})`);
  if (v.cierre !== null && v.cierre !== undefined && !esFechaISO(v.cierre)) {
    problemas.push(`cierre inválido (${v.cierre})`);
  }
  if (esFechaISO(v.apertura) && esFechaISO(v.cierre) && v.cierre < v.apertura) {
    problemas.push(`cierra (${v.cierre}) antes de abrir (${v.apertura})`);
  }

  const enlace = enlaceSeguro(v.enlace);
  if (!enlace) problemas.push(`enlace inválido o inseguro (${v.enlace})`);

  if (problemas.length > 0) return { problemas };

  const imagen = v.imagen ? enlaceSeguro(v.imagen) : null;
  if (v.imagen && !imagen) {
    console.warn(`  ! ${v.id}: imagen inválida o insegura (${v.imagen}), se omite`);
  }

  const modalidad = MODALIDADES.includes(v.modalidad) ? v.modalidad : "presencial";
  if (modalidad !== v.modalidad) {
    console.warn(`  ! ${v.id}: modalidad "${v.modalidad}" no válida, se usa "${modalidad}"`);
  }

  const areas = listaDeTextos(v.areas);

  return {
    beca: {
      id: v.id,
      nombre: v.nombre,
      organizacion: typeof v.organizacion === "string" && v.organizacion.trim()
        ? v.organizacion
        : "Organización no indicada",
      pais: typeof v.pais === "string" && v.pais.trim() ? v.pais : "Sin especificar",
      modalidad,
      areas: areas.length > 0 ? areas : ["General"],
      apertura: v.apertura,
      cierre: esFechaISO(v.cierre) ? v.cierre : null,
      resumen: typeof v.resumen === "string" ? v.resumen : "",
      requisitos: listaDeTextos(v.requisitos),
      beneficios: listaDeTextos(v.beneficios),
      enlace,
      imagen,
      imagenCredito: imagen && typeof v.imagenCredito === "string" ? v.imagenCredito : null,
      fuente: typeof v.fuente === "string" && v.fuente.trim() ? v.fuente : origen
    }
  };
}

/* ------------------------------------------------------------
   Fusión.
   Las manuales pisan a las automáticas cuando comparten id: si
   alguien se tomó el trabajo de revisar una ficha a mano, esa
   versión gana sobre la que llega cruda de la API.

   `revisor` es revisar() o revisarVoluntariado(), según la colección:
   esta función no sabe ni le importa qué campos tiene cada una.
   ------------------------------------------------------------ */
function fusionar(fuentes, revisor) {
  const porId = new Map();
  const repetidas = [];

  for (const { items, origen } of fuentes) {
    for (const cruda of items) {
      const { beca, problemas } = revisor(cruda, origen);
      if (problemas) {
        console.warn(`  ✗ Descartada [${origen}] ${cruda?.id || cruda?.nombre || "sin id"}: ${problemas.join(", ")}`);
        continue;
      }
      if (porId.has(beca.id)) repetidas.push(beca.id);
      porId.set(beca.id, beca);
    }
  }

  for (const id of new Set(repetidas)) {
    console.log(`  · ${id}: presente en más de una fuente, se conserva la última`);
  }

  /* Orden estable por apertura: así el diff del repositorio es legible
     y no cambia de un día para otro sin motivo. */
  return Array.from(porId.values()).sort((a, b) =>
    a.apertura === b.apertura ? a.id.localeCompare(b.id) : a.apertura.localeCompare(b.apertura)
  );
}

/* ------------------------------------------------------------
   Escritura
   ------------------------------------------------------------ */
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

/* Junta cualquier número de fuentes ya leídas en un solo resultado:
   la lista fusionada, si hay que mostrar el aviso de "datos de
   ejemplo", y la fecha de la fuente menos reciente. Se usa igual
   para becas que para voluntariados. */
function combinar(fuentesConOrigen, revisor) {
  const items = fusionar(fuentesConOrigen, revisor);
  const ejemplo = fuentesConOrigen.some((f) => f.ejemplo);
  const fechas = fuentesConOrigen.map((f) => f.actualizado).filter(Boolean).sort();
  const actualizado = fechas[0] || hoyISO();
  return { items, ejemplo, actualizado };
}

export async function construir() {
  const fuenteManual = await leerFuente("data/manual.json", "becas");
  const fuentePronabec = await leerFuente("data/pronabec.json", "becas");
  const fuenteVoluntariados = await leerFuente("data/voluntariados-manual.json", "voluntariados");

  console.log(`Becas — Manual: ${fuenteManual.items.length} · Pronabec: ${fuentePronabec.items.length}`);
  console.log(`Voluntariados — Manual: ${fuenteVoluntariados.items.length}`);

  const becas = combinar(
    [
      { ...fuentePronabec, origen: "Pronabec" },
      { ...fuenteManual, origen: "Carga manual" }
    ],
    revisar
  );

  const voluntariados = combinar(
    [{ ...fuenteVoluntariados, origen: "Carga manual" }],
    revisarVoluntariado
  );

  await guardar("data/becas.json", JSON.stringify(becas.items, null, 2) + "\n");
  await guardar("data/voluntariados.json", JSON.stringify(voluntariados.items, null, 2) + "\n");

  const encabezado = (nombreArchivo, nombreFuente) => `/* ============================================================
   ${nombreArchivo} — GENERADO AUTOMÁTICAMENTE, NO EDITAR A MANO
   ------------------------------------------------------------
   Lo escribe scripts/construir-datos.mjs y se sobrescribe entero
   en cada build. Para cambiar un registro cargado a mano edita
   ${nombreFuente} y vuelve a correr:

     node scripts/construir-datos.mjs

   Generado el ${new Date().toISOString()}.
   ============================================================ */`;

  await guardar("assets/js/datos.js", `${encabezado("datos.js", "data/manual.json")}

const BECAS = ${JSON.stringify(becas.items, null, 2)};

/* Si es true, la web muestra un aviso de que las fechas no están
   verificadas. Sale de la marca "ejemplo" de data/manual.json. */
const DATOS_DE_EJEMPLO = ${becas.ejemplo};

/* Última revisión de la fuente menos reciente, en AAAA-MM-DD. */
const DATOS_ACTUALIZADOS = ${JSON.stringify(becas.actualizado)};
`);

  /* Colección aparte, en su propio archivo y con su propia bandera de
     "ejemplo": la sección de voluntariados no debe mezclarse con la
     de becas ni depender de que ambas se actualicen juntas. */
  await guardar("assets/js/voluntariados.js", `${encabezado("voluntariados.js", "data/voluntariados-manual.json")}

const VOLUNTARIADOS = ${JSON.stringify(voluntariados.items, null, 2)};

const VOLUNTARIADOS_DE_EJEMPLO = ${voluntariados.ejemplo};

const VOLUNTARIADOS_ACTUALIZADOS = ${JSON.stringify(voluntariados.actualizado)};
`);

  console.log(`Listo. ${becas.items.length} convocatorias${becas.ejemplo ? " (ejemplo)" : ""} · ` +
    `${voluntariados.items.length} voluntariados${voluntariados.ejemplo ? " (ejemplo)" : ""}.`);

  return { becas: becas.items, voluntariados: voluntariados.items };
}

/* Solo corre si se invoca directamente, no cuando sync-pronabec lo importa. */
if (process.argv[1] && resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url))) {
  construir().catch((error) => {
    console.error("Falló la construcción:", error.message);
    process.exit(1);
  });
}
