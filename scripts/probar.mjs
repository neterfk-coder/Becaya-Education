/* ============================================================
   probar.mjs — pruebas del motor de fechas
   ------------------------------------------------------------
   Sin dependencias: usa el runner que ya trae Node.

     node --test scripts/probar.mjs

   Cubre estado.js, que es donde vive la única regla importante del
   proyecto. La interfaz no se prueba aquí porque necesitaría un DOM;
   estas pruebas cuidan el cálculo, que es lo que puede equivocarse en
   silencio y mandar a alguien a una convocatoria cerrada.
   ============================================================ */

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const RAIZ = resolve(dirname(fileURLToPath(import.meta.url)), "..");

/* estado.js es un script clásico que define globales para el navegador.
   Se evalúa y se devuelven las funciones que expone. */
function cargarMotor() {
  const fuente = readFileSync(resolve(RAIZ, "assets/js/estado.js"), "utf8");
  const fabrica = new Function(
    fuente + `
    return { calcularEstado, ordenarPorUrgencia, aFecha, formatoFecha, GRUPOS, ORDEN_GRUPOS };`
  );
  return fabrica();
}

const motor = cargarMotor();
const REF = new Date(2026, 7, 12);   /* 12 de agosto de 2026 */

function beca(id, apertura, cierre) {
  return { id, nombre: id, apertura, cierre };
}

function grupoDe(apertura, cierre) {
  return motor.calcularEstado(beca("x", apertura, cierre), REF).grupo;
}

/* ---------- Parseo de fechas ---------- */

test("aFecha no corre la fecha un día por la zona horaria", () => {
  const f = motor.aFecha("2026-09-15");
  assert.equal(f.getFullYear(), 2026);
  assert.equal(f.getMonth(), 8);
  assert.equal(f.getDate(), 15);
});

/* ---------- Clasificación en grupos ---------- */

test("una convocatoria en curso queda en abiertas", () => {
  assert.equal(grupoDe("2026-08-01", "2026-09-30"), "abiertas");
});

test("el día exacto de apertura ya cuenta como abierta", () => {
  assert.equal(grupoDe("2026-08-12", "2026-09-30"), "abiertas");
});

test("el día exacto de cierre todavía cuenta como abierta", () => {
  assert.equal(grupoDe("2026-07-01", "2026-08-12"), "abiertas");
});

test("el día siguiente al cierre ya es cerrada", () => {
  assert.equal(grupoDe("2026-07-01", "2026-08-11"), "cerradas");
});

test("los cortes de 7 y 31 días caen en el grupo correcto", () => {
  assert.equal(grupoDe("2026-08-19", "2026-10-01"), "esta-semana");    /* +7  */
  assert.equal(grupoDe("2026-08-20", "2026-10-01"), "este-mes");       /* +8  */
  assert.equal(grupoDe("2026-09-12", "2026-11-01"), "este-mes");       /* +31 */
  assert.equal(grupoDe("2026-09-13", "2026-11-01"), "mas-adelante");   /* +32 */
});

/* ---------- Urgencia y progreso ---------- */

test("una beca que cierra en 7 días o menos se marca urgente", () => {
  const casi = motor.calcularEstado(beca("a", "2026-08-01", "2026-08-19"), REF);
  const holgada = motor.calcularEstado(beca("b", "2026-08-01", "2026-08-20"), REF);
  assert.equal(casi.urgente, true);
  assert.equal(holgada.urgente, false);
});

test("el progreso refleja el tiempo que queda, no el transcurrido", () => {
  /* Del 2 al 22 de agosto, estamos en el día 10 de 20: queda la mitad. */
  const e = motor.calcularEstado(beca("a", "2026-08-02", "2026-08-22"), REF);
  assert.equal(e.progreso, 50);
});

test("el progreso nunca se sale de 0..100", () => {
  const e = motor.calcularEstado(beca("a", "2026-08-12", "2026-08-12"), REF);
  assert.ok(e.progreso >= 0 && e.progreso <= 100);
});

/* ---------- Orden ---------- */

test("en una sola lista las abiertas van antes que las cerradas", () => {
  /* Este es el bug que tenía la vista de cuadrícula: las cerradas tienen
     días restantes negativos y se colaban al tope de la lista. */
  const lista = [
    beca("cerrada-vieja", "2025-01-01", "2025-03-01"),
    beca("abierta", "2026-08-01", "2026-09-30"),
    beca("cerrada-reciente", "2026-07-01", "2026-08-05"),
    beca("proxima-mes", "2026-09-01", "2026-10-01"),
    beca("proxima-semana", "2026-08-15", "2026-10-01")
  ].map((b) => ({ ...b, estado: motor.calcularEstado(b, REF) }));

  const orden = lista.sort(motor.ordenarPorUrgencia).map((b) => b.id);

  assert.deepEqual(orden, [
    "abierta",
    "proxima-semana",
    "proxima-mes",
    "cerrada-reciente",
    "cerrada-vieja"
  ]);
});

test("dentro de abiertas primero va la que cierra antes", () => {
  const lista = [
    beca("cierra-tarde", "2026-08-01", "2026-12-01"),
    beca("cierra-pronto", "2026-08-01", "2026-08-15")
  ].map((b) => ({ ...b, estado: motor.calcularEstado(b, REF) }));

  const orden = lista.sort(motor.ordenarPorUrgencia).map((b) => b.id);
  assert.deepEqual(orden, ["cierra-pronto", "cierra-tarde"]);
});

test("el orden es consistente al invertir los argumentos", () => {
  /* Un comparador que no cumple esto produce listas distintas según el
     orden de entrada. El anterior no lo cumplía entre grupos. */
  const casos = [
    beca("a", "2026-08-01", "2026-09-30"),
    beca("b", "2026-07-01", "2026-08-05"),
    beca("c", "2026-09-01", "2026-10-01")
  ].map((x) => ({ ...x, estado: motor.calcularEstado(x, REF) }));

  for (const x of casos) {
    for (const y of casos) {
      const ida = Math.sign(motor.ordenarPorUrgencia(x, y));
      const vuelta = Math.sign(motor.ordenarPorUrgencia(y, x));
      /* Con == y no assert.equal, porque el estricto distingue 0 de -0. */
      assert.ok(ida === -vuelta, `${x.id} vs ${y.id}: ${ida} y ${vuelta}`);
    }
  }
});

/* ---------- Catálogo publicado ---------- */

/* Un catálogo vacío es un estado VÁLIDO y deliberado: es preferible no
   mostrar nada a mostrar fechas sin verificar. Por eso estas pruebas
   comprueban que lo publicado esté bien, no que haya algo publicado. */
const ISO = /^\d{4}-\d{2}-\d{2}$/;

/* La versión de contrato que esperan estas pruebas. Si alguien sube
   VERSION_CATALOGO en construir-datos.mjs, esta prueba falla y obliga a
   revisar qué se rompió y a actualizar también la app antes de publicar. */
const VERSION_ESPERADA = 1;

/* Lee el sobre público y devuelve la colección de adentro. */
function leerCatalogo(ruta, clave) {
  const sobre = JSON.parse(readFileSync(resolve(RAIZ, ruta), "utf8"));
  return sobre[clave];
}

test("el catálogo publicado viene en el sobre que espera la app", () => {
  /* data/becas.json ya no es un archivo interno: lo descarga la app de
     Android. Un APK instalado hace meses sigue pidiendo este archivo,
     así que la forma del sobre es un contrato, no un detalle. */
  for (const [ruta, clave] of [
    ["data/becas.json", "becas"],
    ["data/voluntariados.json", "voluntariados"]
  ]) {
    const sobre = JSON.parse(readFileSync(resolve(RAIZ, ruta), "utf8"));

    assert.equal(sobre.version, VERSION_ESPERADA,
      `${ruta}: cambió la versión del contrato — actualiza también la app`);
    assert.ok(Array.isArray(sobre[clave]),
      `${ruta}: la colección debe ir bajo la clave "${clave}"`);
    assert.equal(typeof sobre.ejemplo, "boolean", `${ruta}: falta la marca "ejemplo"`);
    assert.match(String(sobre.actualizado), ISO, `${ruta}: "actualizado" no es AAAA-MM-DD`);
  }
});

test("todas las becas publicadas tienen fecha y enlace válidos", async () => {
  const becas = leerCatalogo("data/becas.json", "becas");

  const ids = new Set();
  for (const b of becas) {
    /* La apertura puede ser null: lo habitual es conocer el plazo de
       cierre y no la fecha exacta en que se abrió. Lo que no puede
       faltar son las dos a la vez. */
    if (b.apertura !== null) assert.match(b.apertura, ISO, `${b.id}: apertura inválida`);
    if (b.cierre !== null) assert.match(b.cierre, ISO, `${b.id}: cierre inválido`);
    assert.ok(b.apertura || b.cierre, `${b.id}: no tiene ninguna fecha`);
    if (b.apertura && b.cierre) {
      assert.ok(b.cierre >= b.apertura, `${b.id}: cierra antes de abrir`);
    }
    assert.match(b.enlace, /^https?:\/\//, `${b.id}: enlace no es http(s)`);
    assert.ok(!ids.has(b.id), `id repetido: ${b.id}`);
    ids.add(b.id);
  }
});

test("toda beca publicada deja constancia de cuándo se verificó", async () => {
  /* La regla central del proyecto: si está publicada, alguien la
     comprobó contra la web oficial y anotó cuándo. Sin esto, el
     catálogo envejece sin que nadie pueda saber cuánto. */
  const becas = leerCatalogo("data/becas.json", "becas");
  for (const b of becas) {
    assert.match(String(b.verificadaEl), ISO, `${b.id}: sin fecha de verificación`);
    assert.ok(
      typeof b.notaVerificacion === "string" && b.notaVerificacion.length > 20,
      `${b.id}: sin nota que explique de dónde salió la fecha`
    );
  }
});

test("todos los voluntariados publicados tienen fecha y enlace válidos", async () => {
  const voluntariados = leerCatalogo("data/voluntariados.json", "voluntariados");

  const MODALIDADES = ["presencial", "virtual", "hibrida"];
  const ids = new Set();
  for (const v of voluntariados) {
    if (v.apertura !== null) assert.match(v.apertura, ISO, `${v.id}: apertura inválida`);
    if (v.cierre !== null) assert.match(v.cierre, ISO, `${v.id}: cierre inválido`);
    assert.ok(v.apertura || v.cierre, `${v.id}: no tiene ninguna fecha`);
    if (v.apertura && v.cierre) {
      assert.ok(v.cierre >= v.apertura, `${v.id}: cierra antes de abrir`);
    }
    assert.match(v.enlace, /^https?:\/\//, `${v.id}: enlace no es http(s)`);
    assert.ok(MODALIDADES.includes(v.modalidad), `${v.id}: modalidad inválida (${v.modalidad})`);
    assert.ok(!ids.has(v.id), `id repetido: ${v.id}`);
    ids.add(v.id);
  }
});

test("becas y voluntariados son catálogos separados (sin campos cruzados)", async () => {
  /* Verifica que la separación sea real y no solo de nombre: un
     voluntariado no debe traer campos de becas (nivel/cobertura) y
     viceversa, porque eso indicaría que en algún punto se mezclaron. */
  const becas = leerCatalogo("data/becas.json", "becas");
  const voluntariados = leerCatalogo("data/voluntariados.json", "voluntariados");

  for (const b of becas) {
    assert.ok(!("modalidad" in b), `${b.id}: una beca no debería tener "modalidad"`);
    assert.ok(!("organizacion" in b), `${b.id}: una beca no debería tener "organizacion"`);
  }
  for (const v of voluntariados) {
    assert.ok(!("nivel" in v), `${v.id}: un voluntariado no debería tener "nivel"`);
    assert.ok(!("cobertura" in v), `${v.id}: un voluntariado no debería tener "cobertura"`);
  }
});
