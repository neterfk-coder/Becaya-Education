/* ============================================================
   app.js — interfaz
   ------------------------------------------------------------
   Todo lo que el usuario toca: buscar, filtrar, cambiar de vista,
   abrir el detalle y guardar becas. El cálculo de fechas no vive
   aquí, vive en estado.js.
   ============================================================ */

(function () {
  "use strict";

  /* ---------- Estado de la interfaz: becas ---------- */
  const filtros = { nivel: "todos", destino: "todos", cobertura: "todos", area: "todos" };
  let busqueda = "";
  let vista = "calendario";
  let modo = "catalogo";          /* "catalogo" o "guardadas" */
  let guardadas = cargarGuardadas();

  /* ---------- Estado de la interfaz: voluntariados ----------
     Deliberadamente aparte de lo de arriba: su propio filtro, su
     propia búsqueda y sus propias guardadas, para que nunca se
     mezclen con el catálogo de becas ni en los datos ni en pantalla. */
  const filtrosVol = { modalidad: "todos", area: "todos" };
  let busquedaVol = "";
  let modoVol = "catalogo";       /* "catalogo" o "guardados" */
  let guardadasVol = cargarGuardadasVol();

  /* El día de referencia se calcula una vez por dibujado y se comparte
     entre todas las becas: así no puede pasar que la lista se pinte a
     caballo entre dos días, y permite refrescar el calendario cuando el
     usuario deja la pestaña abierta y cruza la medianoche. */
  let diaDeReferencia = hoy();

  /* ---------- Referencias del DOM ---------- */
  const $ = (sel) => document.querySelector(sel);
  const zona = $("#zonaResultados");
  const sinResultados = $("#sinResultados");
  const conteoResultados = $("#conteoResultados");
  const campoBusqueda = $("#campoBusqueda");
  const btnLimpiarBusqueda = $("#limpiarBusqueda");
  const btnLimpiarFiltros = $("#limpiarFiltros");
  const panel = $("#panelDetalle");
  const panelCuerpo = $("#panelCuerpo");
  const fondoModal = $("#fondoModal");
  const aviso = $("#aviso");

  const zonaVol = $("#zonaVoluntariados");
  const sinResultadosVol = $("#sinResultadosVol");
  const conteoResultadosVol = $("#conteoResultadosVol");
  const campoBusquedaVol = $("#campoBusquedaVol");
  const btnLimpiarBusquedaVol = $("#limpiarBusquedaVol");
  const btnLimpiarFiltrosVol = $("#limpiarFiltrosVol");
  const badgeGuardadosVol = $("#conteoGuardadosVol");

  let temporizadorCierrePanel;
  let elementoQueAbrioElPanel = null;

  /* A qué colección pertenece la beca/voluntariado que el panel de
     detalle tiene abierto ahora mismo, y cuál es su id. El panel es un
     único componente compartido; esto es lo que necesita saber para
     pintar las etiquetas correctas, guardar en el sitio correcto y
     armar el enlace para compartir. */
  let tipoPanelActual = "beca";
  let idPanelActual = null;

  /* ============================================================
     ARRANQUE
     ============================================================ */
  function iniciar() {
    mostrarFechaDeDatos();
    mostrarAnioActual();
    construirFiltroAreas();
    construirFiltroAreasVol();
    conectarEventos();
    conectarEventosVoluntariados();
    vigilarCambioDeDia();
    dibujar();
    dibujarVoluntariados();
    animarReloj();
    observarRevelados();
    actualizarConteoGuardadas(false);
    actualizarConteoGuardadosVol(false);
    /* Si la URL trae ?beca=id o ?voluntariado=id, se abre ese detalle
       directo: es lo que permite que un enlace compartido lleve a la
       convocatoria exacta y no solo a la portada. */
    sincronizarPanelConURL();
  }

  /* El año del pie de página, calculado, no escrito a mano: así nunca
     queda desactualizado un 1 de enero. */
  function mostrarAnioActual() {
    const nodo = $("#anioActual");
    if (nodo) nodo.textContent = diaDeReferencia.getFullYear();
  }

  /* La fecha de la portada es la de la última revisión de los datos,
     no la de hoy. Poner "Datos al <hoy>" sobre un catálogo de hace
     meses es exactamente la mentira que este proyecto quiere evitar. */
  function mostrarFechaDeDatos() {
    const nodo = $("#fechaHoy");
    const revisado = typeof DATOS_ACTUALIZADOS !== "undefined" ? aFecha(DATOS_ACTUALIZADOS) : null;
    nodo.textContent = revisado ? formatoFecha(revisado) : formatoFecha(diaDeReferencia);

    if (typeof DATOS_DE_EJEMPLO !== "undefined" && DATOS_DE_EJEMPLO) {
      nodo.insertAdjacentHTML("afterend",
        " · <b>Fechas de ejemplo</b>, verifica en la web oficial de cada institución");
    }
  }

  /* ============================================================
     DATOS DERIVADOS
     ============================================================ */

  /* Une cada beca con su estado calculado, todas contra el mismo día. */
  function becasConEstado() {
    return BECAS.map((b) => ({ ...b, estado: calcularEstado(b, diaDeReferencia) }));
  }

  /* Mismo cálculo, misma referencia de día, otra colección. calcularEstado()
     no distingue una beca de un voluntariado: solo mira apertura y cierre. */
  function voluntariadosConEstado() {
    return VOLUNTARIADOS.map((v) => ({ ...v, estado: calcularEstado(v, diaDeReferencia) }));
  }

  /* Compara ignorando mayúsculas y acentos: en un sitio en español la
     gente escribe "peru" y "educacion", y antes eso no encontraba nada. */
  function normalizarTexto(texto) {
    return String(texto)
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .toLowerCase();
  }

  function pasaFiltros(beca) {
    if (filtros.nivel !== "todos" && beca.nivel !== filtros.nivel && beca.nivel !== "ambos") return false;
    if (filtros.destino !== "todos" && beca.destino !== filtros.destino) return false;
    if (filtros.cobertura !== "todos" && beca.cobertura !== filtros.cobertura) return false;
    if (filtros.area !== "todos") {
      const areas = Array.isArray(beca.areas) ? beca.areas : [];
      const cubreTodo = areas.includes("Todas las áreas");
      if (!cubreTodo && !areas.includes(filtros.area)) return false;
    }
    if (busqueda) {
      const texto = normalizarTexto([
        beca.nombre, beca.institucion, beca.pais, beca.resumen,
        (Array.isArray(beca.areas) ? beca.areas : []).join(" ")
      ].join(" "));
      if (!texto.includes(normalizarTexto(busqueda))) return false;
    }
    return true;
  }

  function hayFiltrosActivos() {
    return busqueda !== "" || Object.values(filtros).some((v) => v !== "todos");
  }

  function pasaFiltrosVol(v) {
    if (filtrosVol.modalidad !== "todos" && v.modalidad !== filtrosVol.modalidad) return false;
    if (filtrosVol.area !== "todos") {
      const areas = Array.isArray(v.areas) ? v.areas : [];
      if (!areas.includes(filtrosVol.area)) return false;
    }
    if (busquedaVol) {
      const texto = normalizarTexto([
        v.nombre, v.organizacion, v.pais, v.resumen,
        (Array.isArray(v.areas) ? v.areas : []).join(" ")
      ].join(" "));
      if (!texto.includes(normalizarTexto(busquedaVol))) return false;
    }
    return true;
  }

  function hayFiltrosActivosVol() {
    return busquedaVol !== "" || Object.values(filtrosVol).some((v) => v !== "todos");
  }

  /* ============================================================
     DIBUJAR RESULTADOS
     ============================================================ */
  function dibujar() {
    if (modo === "guardadas") { dibujarGuardadas(); return; }

    const lista = becasConEstado().filter(pasaFiltros).sort(ordenarPorUrgencia);

    btnLimpiarFiltros.hidden = !hayFiltrosActivos();
    conteoResultados.innerHTML = lista.length === 1
      ? "<b>1</b> convocatoria encontrada"
      : `<b>${lista.length}</b> convocatorias encontradas`;

    if (lista.length === 0) {
      zona.innerHTML = "";
      sinResultados.hidden = false;
      return;
    }
    sinResultados.hidden = true;

    zona.innerHTML = vista === "calendario" ? htmlCalendario(lista) : htmlCuadricula(lista);
    animarBarrasProgreso();
  }

  /* Vista de guardadas. Vive dentro de dibujar() y no aparte para que
     desmarcar una beca desde aquí vuelva a pintar esta misma vista; antes
     llamaba al dibujado normal y te sacaba de golpe al catálogo completo. */
  function dibujarGuardadas() {
    const lista = becasConEstado()
      .filter((b) => guardadas.includes(b.id))
      .sort(ordenarPorUrgencia);

    btnLimpiarFiltros.hidden = true;
    conteoResultados.innerHTML = lista.length === 1
      ? "<b>1</b> beca guardada"
      : `<b>${lista.length}</b> becas guardadas`;

    /* Si quitaste la última, no tiene sentido quedarse en una vista
       vacía: se vuelve al catálogo. */
    if (lista.length === 0) {
      volverAlCatalogo();
      mostrarAviso("Ya no tienes becas guardadas");
      dibujar();
      return;
    }
    sinResultados.hidden = true;

    zona.innerHTML = `
      <section class="grupo grupo--destacado">
        <header class="grupo__cabecera">
          <h2 class="grupo__titulo">Tus becas guardadas</h2>
          <span class="grupo__conteo">${lista.length}</span>
          <span class="grupo__nota">Se quedan en este navegador</span>
        </header>
        <div class="rejilla">${lista.map((b, i) => htmlTarjeta(b, i)).join("")}</div>
      </section>`;
    animarBarrasProgreso();
  }

  /* Vuelve al catálogo completo. Cualquier filtro, búsqueda o cambio de
     vista implica salir del modo guardadas. */
  function volverAlCatalogo() {
    modo = "catalogo";
  }

  function cambiarVista(nueva) {
    vista = nueva;
    document.querySelectorAll(".conmutador__btn").forEach((b) => {
      const activo = b.dataset.vista === nueva;
      b.classList.toggle("conmutador__btn--activo", activo);
      b.setAttribute("aria-selected", String(activo));
    });
    dibujar();
  }

  function htmlCalendario(lista) {
    return GRUPOS.map((grupo) => {
      const delGrupo = lista.filter((b) => b.estado.grupo === grupo.id);
      if (delGrupo.length === 0) return "";

      const clases = ["grupo"];
      if (grupo.destacado) clases.push("grupo--destacado");
      if (grupo.apagado) clases.push("grupo--apagado");

      return `
        <section class="${clases.join(" ")}" id="grupo-${grupo.id}">
          <header class="grupo__cabecera">
            <h2 class="grupo__titulo">${grupo.titulo}</h2>
            <span class="grupo__conteo">${delGrupo.length}</span>
            <span class="grupo__nota">${grupo.nota}</span>
          </header>
          <div class="rejilla">
            ${delGrupo.map((b, i) => htmlTarjeta(b, i)).join("")}
          </div>
        </section>`;
    }).join("");
  }

  function htmlCuadricula(lista) {
    return `<div class="rejilla">${lista.map((b, i) => htmlTarjeta(b, i)).join("")}</div>`;
  }

  function htmlTarjeta(beca, indice) {
    const e = beca.estado;
    const cerrada = e.clave === "cerrada";
    const guardada = guardadas.includes(beca.id);
    const retraso = Math.min(indice, 11) * 0.045;

    const claseTexto = cerrada ? "texto-gris" : e.urgente ? "texto-urgente" : "texto-abierta";
    const clasePunto = cerrada ? "punto-estado--gris" : e.urgente ? "punto-estado--urgente" : "";

    const pie = e.clave === "abierta"
      ? `<div class="tarjeta__estado">
           <b class="${claseTexto}"><span class="punto-estado ${clasePunto}"></span>${e.titular}</b>
           <span class="texto-gris">${e.detalle}</span>
         </div>
         <div class="progreso ${cerrada ? "progreso--gris" : ""}"
              role="progressbar" aria-valuenow="${e.progreso}" aria-valuemin="0" aria-valuemax="100"
              title="Tiempo que queda de esta convocatoria">
           <div class="progreso__barra ${e.urgente ? "progreso__barra--urgente" : ""}" data-ancho="${e.progreso}"></div>
         </div>`
      : `<div class="tarjeta__estado">
           <b class="${claseTexto}"><span class="punto-estado ${clasePunto}"></span>${e.titular}</b>
         </div>
         <p class="fecha-apertura">${e.detalle}</p>`;

    return `
      <article class="tarjeta ${cerrada ? "tarjeta--cerrada" : ""}"
               style="--retraso:${retraso}s"
               data-id="${escapar(beca.id)}"
               tabindex="0" role="button"
               aria-label="Ver detalle de ${escapar(beca.nombre)}">
        <div class="tarjeta__alto">
          <span class="tarjeta__institucion">${escapar(beca.institucion)}</span>
          <button class="marcador ${guardada ? "marcador--activo" : ""}"
                  data-guardar="${escapar(beca.id)}"
                  aria-label="${guardada ? "Quitar de guardadas" : "Guardar esta beca"}"
                  aria-pressed="${guardada}">
            <svg viewBox="0 0 24 24"><path d="M6 3h12a1 1 0 0 1 1 1v17l-7-4.5L5 21V4a1 1 0 0 1 1-1z"/></svg>
          </button>
        </div>
        <h3 class="tarjeta__nombre">${escapar(beca.nombre)}</h3>
        <p class="tarjeta__resumen">${escapar(beca.resumen)}</p>
        <div class="etiquetas">
          <span class="etiqueta etiqueta--fuerte">${beca.nivel === "ambos" ? "Pregrado y posgrado" : capital(beca.nivel)}</span>
          <span class="etiqueta">${escapar(beca.pais)}</span>
          <span class="etiqueta">Cobertura ${beca.cobertura}</span>
        </div>
        <div class="tarjeta__pie">${pie}</div>
      </article>`;
  }

  /* Las barras crecen después de pintar, para que se vea el movimiento.
     Selector global a propósito: sirve tanto para las tarjetas de becas
     como para las de voluntariados, no hace falta duplicarla. */
  function animarBarrasProgreso() {
    requestAnimationFrame(() => {
      document.querySelectorAll(".progreso__barra").forEach((barra) => {
        barra.style.width = barra.dataset.ancho + "%";
      });
    });
  }

  /* ============================================================
     VOLUNTARIADOS — DIBUJAR
     ------------------------------------------------------------
     Sin calendario agrupado a propósito: es una cuadrícula simple
     ordenada por urgencia. Esa diferencia de forma con la sección
     de becas también ayuda a que nunca se confundan una con otra.
     ============================================================ */
  function dibujarVoluntariados() {
    const base = voluntariadosConEstado();
    const lista = modoVol === "guardados"
      ? base.filter((v) => guardadasVol.includes(v.id)).sort(ordenarPorUrgencia)
      : base.filter(pasaFiltrosVol).sort(ordenarPorUrgencia);

    btnLimpiarFiltrosVol.hidden = modoVol === "guardados" || !hayFiltrosActivosVol();

    if (modoVol === "guardados" && lista.length === 0) {
      /* Igual que con las becas: si ya no queda ninguna guardada, no
         tiene sentido quedarse mirando una vista vacía. */
      modoVol = "catalogo";
      actualizarBadgeModoVol();
      mostrarAviso("Ya no tienes voluntariados guardados");
      dibujarVoluntariados();
      return;
    }

    conteoResultadosVol.innerHTML = modoVol === "guardados"
      ? (lista.length === 1 ? "<b>1</b> voluntariado guardado" : `<b>${lista.length}</b> voluntariados guardados`)
      : (lista.length === 1 ? "<b>1</b> voluntariado encontrado" : `<b>${lista.length}</b> voluntariados encontrados`);

    if (lista.length === 0) {
      zonaVol.innerHTML = "";
      sinResultadosVol.hidden = false;
      return;
    }
    sinResultadosVol.hidden = true;
    zonaVol.innerHTML = `<div class="rejilla">${lista.map((v, i) => htmlTarjetaVoluntariado(v, i)).join("")}</div>`;
    animarBarrasProgreso();
  }

  function volverAlCatalogoVol() {
    modoVol = "catalogo";
    actualizarBadgeModoVol();
  }

  function htmlTarjetaVoluntariado(v, indice) {
    const e = v.estado;
    const cerrada = e.clave === "cerrada";
    const guardada = guardadasVol.includes(v.id);
    const retraso = Math.min(indice, 11) * 0.045;

    const claseTexto = cerrada ? "texto-gris" : e.urgente ? "texto-urgente" : "texto-abierta";
    const clasePunto = cerrada ? "punto-estado--gris" : e.urgente ? "punto-estado--urgente" : "";

    const pie = e.clave === "abierta"
      ? `<div class="tarjeta__estado">
           <b class="${claseTexto}"><span class="punto-estado ${clasePunto}"></span>${e.titular}</b>
           <span class="texto-gris">${e.detalle}</span>
         </div>
         <div class="progreso ${cerrada ? "progreso--gris" : ""}"
              role="progressbar" aria-valuenow="${e.progreso}" aria-valuemin="0" aria-valuemax="100"
              title="Tiempo que queda de esta convocatoria">
           <div class="progreso__barra ${e.urgente ? "progreso__barra--urgente" : ""}" data-ancho="${e.progreso}"></div>
         </div>`
      : `<div class="tarjeta__estado">
           <b class="${claseTexto}"><span class="punto-estado ${clasePunto}"></span>${e.titular}</b>
         </div>
         <p class="fecha-apertura">${e.detalle}</p>`;

    return `
      <article class="tarjeta tarjeta--vol ${cerrada ? "tarjeta--cerrada" : ""}"
               style="--retraso:${retraso}s"
               data-id-vol="${escapar(v.id)}"
               tabindex="0" role="button"
               aria-label="Ver detalle de ${escapar(v.nombre)}">
        <div class="tarjeta__alto">
          <span class="tarjeta__institucion">${escapar(v.organizacion)}</span>
          <button class="marcador ${guardada ? "marcador--activo" : ""}"
                  data-guardar-vol="${escapar(v.id)}"
                  aria-label="${guardada ? "Quitar de guardados" : "Guardar este voluntariado"}"
                  aria-pressed="${guardada}">
            <svg viewBox="0 0 24 24"><path d="M6 3h12a1 1 0 0 1 1 1v17l-7-4.5L5 21V4a1 1 0 0 1 1-1z"/></svg>
          </button>
        </div>
        <h3 class="tarjeta__nombre">${escapar(v.nombre)}</h3>
        <p class="tarjeta__resumen">${escapar(v.resumen)}</p>
        <div class="etiquetas">
          <span class="etiqueta etiqueta--vol-fuerte">${capital(v.modalidad)}</span>
          <span class="etiqueta">${escapar(v.pais)}</span>
          <span class="etiqueta">${escapar(v.areas[0])}</span>
        </div>
        <div class="tarjeta__pie">${pie}</div>
      </article>`;
  }

  /* ============================================================
     PANEL DE DETALLE
     ============================================================ */
  /* Solo http y https llegan al href. El campo `enlace` puede venir de la
     API de Pronabec, y un "javascript:..." ahí se ejecutaría al hacer clic.
     El build ya lo valida, pero el navegador no debe confiar en eso. */
  function enlaceSeguro(valor) {
    try {
      const url = new URL(String(valor), window.location.href);
      return url.protocol === "http:" || url.protocol === "https:" ? url.href : null;
    } catch {
      return null;
    }
  }

  /* El panel es un solo componente compartido entre las dos colecciones.
     `tipo` es "beca" o "voluntariado"; decide de qué arreglo se busca el
     id, qué etiquetas mostrar y en qué lista de guardadas escribir.
     `actualizarUrl` es false cuando el panel se abre para reflejar una
     URL que ya trae el id (al cargar la página o con atrás/adelante del
     navegador): en ese caso no hay que volver a tocar el historial. */
  function abrirPanel(id, tipo, origen, actualizarUrl = true) {
    const esVol = tipo === "voluntariado";
    const item = esVol
      ? voluntariadosConEstado().find((v) => v.id === id)
      : becasConEstado().find((b) => b.id === id);
    if (!item) return;

    tipoPanelActual = tipo;
    idPanelActual = item.id;
    const e = item.estado;
    const guardada = esVol ? guardadasVol.includes(item.id) : guardadas.includes(item.id);
    const enlace = enlaceSeguro(item.enlace);
    const imagen = item.imagen ? enlaceSeguro(item.imagen) : null;
    const nombreEntidad = esVol ? item.organizacion : item.institucion;

    /* Para devolver el foco al cerrar. Si el panel se está refrescando
       (por ejemplo al guardar desde dentro) se conserva el origen previo. */
    if (origen) elementoQueAbrioElPanel = origen;

    /* La imagen se carga desde el servidor de la institución, no se copia
       aquí. Es decorativa (alt vacío): el nombre ya está en el título
       justo debajo, repetirlo solo estorba a un lector de pantalla. */
    const bloqueImagen = imagen
      ? `<figure class="panel__imagen">
           <img src="${escapar(imagen)}" alt="" loading="lazy" referrerpolicy="no-referrer">
           ${item.imagenCredito
             ? `<figcaption>${escapar(item.imagenCredito)}</figcaption>`
             : ""}
         </figure>`
      : "";

    /* Los datos de la caja de estado difieren según la colección: una
       beca muestra nivel y cobertura, un voluntariado muestra modalidad. */
    const datosEstado = esVol
      ? `<span class="dato"><span class="dato__clave">Apertura</span><span class="dato__valor">${formatoFecha(e.apertura)}</span></span>
         <span class="dato"><span class="dato__clave">Cierre</span><span class="dato__valor">${formatoFecha(e.cierre)}</span></span>
         <span class="dato"><span class="dato__clave">Modalidad</span><span class="dato__valor">${capital(item.modalidad)}</span></span>`
      : `<span class="dato"><span class="dato__clave">Apertura</span><span class="dato__valor">${formatoFecha(e.apertura)}</span></span>
         <span class="dato"><span class="dato__clave">Cierre</span><span class="dato__valor">${formatoFecha(e.cierre)}</span></span>
         <span class="dato"><span class="dato__clave">Nivel</span><span class="dato__valor">${item.nivel === "ambos" ? "Pregrado y posgrado" : capital(item.nivel)}</span></span>
         <span class="dato"><span class="dato__clave">Cobertura</span><span class="dato__valor">${capital(item.cobertura)}</span></span>`;

    panelCuerpo.innerHTML = `
      ${bloqueImagen}
      <p class="panel__institucion">${escapar(nombreEntidad)}</p>
      <h2 class="panel__titulo" id="panelTitulo">${escapar(item.nombre)}</h2>
      <p class="panel__resumen">${escapar(item.resumen)}</p>

      <div class="panel__estado ${e.clave === "cerrada" ? "panel__estado--cerrada" : ""}">
        <p class="panel__estado-titulo ${e.clave === "cerrada" ? "texto-gris" : e.urgente ? "texto-urgente" : "texto-abierta"}">
          <span class="punto-estado ${e.clave === "cerrada" ? "punto-estado--gris" : e.urgente ? "punto-estado--urgente" : ""}"></span>${e.titular}
        </p>
        <div class="panel__fechas">${datosEstado}</div>
      </div>

      <div class="panel__seccion">
        <h4>${esVol ? "Qué ofrece" : "Qué cubre"}</h4>
        <ul class="lista-requisitos">${item.beneficios.map((x) => `<li>${escapar(x)}</li>`).join("")}</ul>
      </div>

      <div class="panel__seccion">
        <h4>Requisitos principales</h4>
        <ul class="lista-requisitos">${item.requisitos.map((x) => `<li>${escapar(x)}</li>`).join("")}</ul>
      </div>

      <div class="panel__seccion">
        <h4>${esVol ? "Temas" : "Áreas de estudio"}</h4>
        <div class="etiquetas">${item.areas.map((a) => `<span class="etiqueta">${escapar(a)}</span>`).join("")}</div>
      </div>

      <div class="panel__acciones">
        ${enlace
          ? `<a class="btn btn--principal" href="${escapar(enlace)}" target="_blank" rel="noopener noreferrer">
               ${esVol ? "Ir a la organización" : "Ir a la convocatoria oficial"}
               <svg viewBox="0 0 24 24"><path d="M7 17L17 7M9 7h8v8"/></svg>
             </a>`
          : `<p class="panel__sin-enlace">${esVol ? "Este voluntariado" : "Esta convocatoria"} no tiene un enlace oficial verificado.</p>`}
        <button class="btn btn--fantasma" data-guardar-panel="${escapar(item.id)}">
          <svg viewBox="0 0 24 24"><path d="M6 3h12a1 1 0 0 1 1 1v17l-7-4.5L5 21V4a1 1 0 0 1 1-1z"/></svg>
          ${guardada ? "Quitar de guardadas" : "Guardar"}
        </button>
        <button class="btn btn--fantasma" type="button" data-compartir-panel
                aria-label="Compartir el enlace directo a ${esVol ? "este voluntariado" : "esta convocatoria"}">
          <svg viewBox="0 0 24 24"><path d="M4 12v6a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-6M16 6l-4-4-4 4M12 2v13"/></svg>
          Compartir
        </button>
      </div>`;

    /* Las imágenes viven en el servidor de cada institución, así que se
       caen solas: cambian la ruta, bloquean el enlace desde fuera o
       retiran la convocatoria. Cuando eso pasa se quita el bloque entero
       en vez de dejar el ícono de imagen rota. */
    const nodoImagen = panelCuerpo.querySelector(".panel__imagen img");
    if (nodoImagen) {
      nodoImagen.addEventListener("error", () => {
        const figura = nodoImagen.closest(".panel__imagen");
        if (figura) figura.remove();
      });
    }

    /* Si el panel venía cerrándose, se cancela el ocultado pendiente.
       Sin esto, abrir una tarjeta justo después de cerrar otra dejaba
       el panel invisible: el temporizador anterior le ponía hidden. */
    clearTimeout(temporizadorCierrePanel);

    panel.hidden = false;
    fondoModal.hidden = false;
    requestAnimationFrame(() => {
      panel.classList.add("panel--visible");
      fondoModal.classList.add("fondo-modal--visible");
    });
    document.body.style.overflow = "hidden";
    $("#cerrarPanel").focus();

    /* La URL pasa a reflejar esta convocatoria: es lo que hace que
       copiar el enlace, compartirlo o simplemente recargar la página
       lleve exactamente aquí. */
    if (actualizarUrl) actualizarURLPanel(tipo, item.id);
  }

  /* `actualizarUrl` en false se usa cuando el cierre viene de sincronizar
     con la URL (por ejemplo, el usuario presionó "atrás" y ya no hay
     ningún id en ella): el navegador ya movió el historial solo, y
     tocarlo de nuevo aquí sería redundante. */
  function cerrarPanel(actualizarUrl = true) {
    if (panel.hidden) return;

    panel.classList.remove("panel--visible");
    fondoModal.classList.remove("fondo-modal--visible");
    document.body.style.overflow = "";

    clearTimeout(temporizadorCierrePanel);
    temporizadorCierrePanel = setTimeout(() => {
      panel.hidden = true;
      fondoModal.hidden = true;
    }, 420);

    /* El foco vuelve a la tarjeta desde la que se abrió el panel. Sin esto
       quien navega con teclado quedaba al inicio del documento. */
    if (elementoQueAbrioElPanel && document.contains(elementoQueAbrioElPanel)) {
      elementoQueAbrioElPanel.focus();
    }
    elementoQueAbrioElPanel = null;
    idPanelActual = null;

    if (actualizarUrl) limpiarURLPanel();
  }

  /* ------------------------------------------------------------
     COMPARTIR
     ------------------------------------------------------------
     La URL de una convocatoria abierta es la misma que ve la barra de
     direcciones (?beca=id o ?voluntariado=id), así que "compartir" es
     literalmente pasar esa URL a quien la reciba: por el sistema
     operativo si hay Web Share, o copiada al portapapeles si no.
     ------------------------------------------------------------ */
  function construirURLPanel(tipo, id) {
    const parametros = new URLSearchParams();
    parametros.set(tipo === "voluntariado" ? "voluntariado" : "beca", id);
    return `${window.location.origin}${window.location.pathname}?${parametros.toString()}`;
  }

  function actualizarURLPanel(tipo, id) {
    try {
      history.pushState({ panelTipo: tipo, panelId: id }, "", construirURLPanel(tipo, id));
    } catch (e) {
      /* history.pushState puede fallar si la página se abrió como
         archivo local (file://): el panel sigue funcionando igual,
         solo que compartir queda limitado a la propia URL de la beca. */
    }
  }

  function limpiarURLPanel() {
    try {
      history.replaceState(null, "", `${window.location.origin}${window.location.pathname}`);
    } catch (e) {
      /* Mismo caso que arriba. */
    }
  }

  /* Abre, cierra o cambia el panel según lo que diga la URL en este
     momento. Se usa al cargar la página (para enlaces compartidos) y
     cada vez que el usuario navega con atrás/adelante. */
  function sincronizarPanelConURL() {
    let parametros;
    try {
      parametros = new URLSearchParams(window.location.search);
    } catch (e) {
      return;
    }

    const idBeca = parametros.get("beca");
    const idVol = parametros.get("voluntariado");

    if (idBeca && BECAS.some((b) => b.id === idBeca)) {
      abrirPanel(idBeca, "beca", null, false);
    } else if (idVol && VOLUNTARIADOS.some((v) => v.id === idVol)) {
      abrirPanel(idVol, "voluntariado", null, false);
    } else if (!panel.hidden) {
      cerrarPanel(false);
    }
  }

  async function compartirActual() {
    if (!idPanelActual) return;
    const esVol = tipoPanelActual === "voluntariado";
    const item = esVol
      ? VOLUNTARIADOS.find((v) => v.id === idPanelActual)
      : BECAS.find((b) => b.id === idPanelActual);
    if (!item) return;

    const url = construirURLPanel(tipoPanelActual, idPanelActual);

    /* En el celular, esto abre la hoja de compartir nativa (WhatsApp,
       correo, etc.) en vez de solo copiar el texto. */
    if (navigator.share) {
      try {
        await navigator.share({ title: `${item.nombre} · becaya`, url });
        return;
      } catch (e) {
        /* AbortError = el usuario cerró la hoja de compartir sin elegir
           nada: no es un error, no hace falta avisar ni caer al copiado. */
        if (e && e.name === "AbortError") return;
      }
    }

    try {
      await navigator.clipboard.writeText(url);
      mostrarAviso("Enlace copiado. Pégalo donde quieras compartirlo.");
    } catch (e) {
      mostrarAviso("No se pudo copiar. Copia el enlace desde la barra de direcciones.");
    }
  }

  /* El panel es modal: mientras está abierto, el tabulador no debe
     escaparse al contenido de atrás. */
  function atraparFoco(ev) {
    if (ev.key !== "Tab" || panel.hidden) return;
    const focuseables = panel.querySelectorAll(
      'a[href], button:not([disabled]), input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );
    if (focuseables.length === 0) return;

    const primero = focuseables[0];
    const ultimo = focuseables[focuseables.length - 1];

    if (ev.shiftKey && document.activeElement === primero) {
      ev.preventDefault();
      ultimo.focus();
    } else if (!ev.shiftKey && document.activeElement === ultimo) {
      ev.preventDefault();
      primero.focus();
    }
  }

  /* ============================================================
     GUARDADAS
     ============================================================ */
  /* Se filtra a texto porque el contenido de localStorage lo puede haber
     dejado una versión anterior del sitio, o directamente estar corrupto. */
  function cargarGuardadas() {
    try {
      const leido = JSON.parse(localStorage.getItem("becaya:guardadas"));
      return Array.isArray(leido) ? leido.filter((x) => typeof x === "string") : [];
    } catch (e) {
      return [];
    }
  }

  function persistirGuardadas() {
    try {
      localStorage.setItem("becaya:guardadas", JSON.stringify(guardadas));
    } catch (e) {
      /* Modo privado o almacenamiento lleno: la sesión sigue funcionando igual. */
    }
  }

  function alternarGuardada(id) {
    const beca = BECAS.find((b) => b.id === id);
    if (!beca) return;

    const yaEstaba = guardadas.includes(id);
    guardadas = yaEstaba ? guardadas.filter((x) => x !== id) : guardadas.concat(id);
    persistirGuardadas();
    actualizarConteoGuardadas(true);
    mostrarAviso(yaEstaba
      ? `Quitaste ${beca.nombre} de tus guardadas`
      : `Guardaste ${beca.nombre}`);
    dibujar();

    /* El panel abierto muestra el botón "Guardar/Quitar", así que hay que
       refrescarlo. Si dibujar() ya nos sacó del modo guardadas, el panel
       pudo cerrarse: por eso se comprueba de nuevo. */
    if (!panel.hidden && tipoPanelActual === "beca") abrirPanel(id, "beca");
  }

  function actualizarConteoGuardadas(animar) {
    const pastilla = $("#conteoGuardadas");
    pastilla.textContent = guardadas.length;
    if (animar) {
      pastilla.classList.remove("pastilla-conteo--late");
      void pastilla.offsetWidth;
      pastilla.classList.add("pastilla-conteo--late");
    }
  }

  function verGuardadas() {
    /* Una beca guardada puede haber desaparecido del catálogo (cambió de id
       o se retiró). Se limpian aquí para que el contador no mienta. */
    const vigentes = guardadas.filter((id) => BECAS.some((b) => b.id === id));
    if (vigentes.length !== guardadas.length) {
      guardadas = vigentes;
      persistirGuardadas();
      actualizarConteoGuardadas(false);
    }

    if (guardadas.length === 0) {
      mostrarAviso("Todavía no guardas ninguna beca. Toca el marcador de una tarjeta.");
      return;
    }

    limpiarTodo(false);
    modo = "guardadas";
    dibujar();
    document.getElementById("calendario").scrollIntoView({ behavior: "smooth", block: "start" });
  }

  /* ============================================================
     VOLUNTARIADOS — GUARDADOS
     ------------------------------------------------------------
     Clave de localStorage propia: nunca comparte espacio con las
     becas guardadas, ni en el navegador ni en la interfaz.
     ============================================================ */
  function cargarGuardadasVol() {
    try {
      const leido = JSON.parse(localStorage.getItem("becaya:voluntariados-guardados"));
      return Array.isArray(leido) ? leido.filter((x) => typeof x === "string") : [];
    } catch (e) {
      return [];
    }
  }

  function persistirGuardadasVol() {
    try {
      localStorage.setItem("becaya:voluntariados-guardados", JSON.stringify(guardadasVol));
    } catch (e) {
      /* Modo privado o almacenamiento lleno: la sesión sigue funcionando igual. */
    }
  }

  function alternarGuardadaVol(id) {
    const v = VOLUNTARIADOS.find((x) => x.id === id);
    if (!v) return;

    const yaEstaba = guardadasVol.includes(id);
    guardadasVol = yaEstaba ? guardadasVol.filter((x) => x !== id) : guardadasVol.concat(id);
    persistirGuardadasVol();
    actualizarConteoGuardadosVol(true);
    mostrarAviso(yaEstaba
      ? `Quitaste ${v.nombre} de tus guardados`
      : `Guardaste ${v.nombre}`);
    dibujarVoluntariados();

    if (!panel.hidden && tipoPanelActual === "voluntariado") abrirPanel(id, "voluntariado");
  }

  /* La insignia hace de contador y de interruptor: muestra cuántos hay
     guardados y, si hay al menos uno, se puede tocar para filtrar la
     cuadrícula a solo esos. Vive junto al buscador de la sección, no en
     la cabecera — ahí solo están las becas guardadas. */
  function actualizarConteoGuardadosVol(animar) {
    badgeGuardadosVol.hidden = guardadasVol.length === 0;
    badgeGuardadosVol.textContent = guardadasVol.length === 1
      ? "1 guardado"
      : `${guardadasVol.length} guardados`;
    if (animar) {
      badgeGuardadosVol.classList.remove("pastilla-conteo--late");
      void badgeGuardadosVol.offsetWidth;
      badgeGuardadosVol.classList.add("pastilla-conteo--late");
    }
    actualizarBadgeModoVol();
  }

  function actualizarBadgeModoVol() {
    badgeGuardadosVol.classList.toggle("pastilla-conteo--vol-activa", modoVol === "guardados");
  }

  /* ============================================================
     FILTROS
     ============================================================ */
  function construirFiltroAreas() {
    const areas = new Set();
    BECAS.forEach((b) => b.areas.forEach((a) => { if (a !== "Todas las áreas") areas.add(a); }));
    const contenedor = $("#filtroAreas");
    contenedor.innerHTML =
      `<button class="ficha ficha--activa" data-valor="todos">Todas</button>` +
      Array.from(areas).sort().map((a) => `<button class="ficha" data-valor="${escapar(a)}">${escapar(a)}</button>`).join("");
  }

  function construirFiltroAreasVol() {
    const areas = new Set();
    VOLUNTARIADOS.forEach((v) => v.areas.forEach((a) => areas.add(a)));
    const contenedor = $("#filtroAreasVol");
    contenedor.innerHTML =
      `<button class="ficha ficha--activa" data-valor="todos">Todas</button>` +
      Array.from(areas).sort().map((a) => `<button class="ficha" data-valor="${escapar(a)}">${escapar(a)}</button>`).join("");
  }

  function limpiarTodoVol(redibujar) {
    filtrosVol.modalidad = filtrosVol.area = "todos";
    busquedaVol = "";
    campoBusquedaVol.value = "";
    btnLimpiarBusquedaVol.hidden = true;
    $("#filtrosVol").querySelectorAll(".filtro__opciones").forEach((grupo) => {
      grupo.querySelectorAll(".ficha").forEach((f) => {
        f.classList.toggle("ficha--activa", f.dataset.valor === "todos");
      });
    });
    if (redibujar !== false) dibujarVoluntariados();
  }

  function limpiarTodo(redibujar) {
    filtros.nivel = filtros.destino = filtros.cobertura = filtros.area = "todos";
    busqueda = "";
    campoBusqueda.value = "";
    btnLimpiarBusqueda.hidden = true;
    /* Acotado a #filtrosBecas por la misma razón que en conectarEventos():
       no tocar las fichas de la sección de voluntariados. */
    $("#filtrosBecas").querySelectorAll(".filtro__opciones").forEach((grupo) => {
      grupo.querySelectorAll(".ficha").forEach((f) => {
        f.classList.toggle("ficha--activa", f.dataset.valor === "todos");
      });
    });
    if (redibujar !== false) dibujar();
  }

  /* ============================================================
     EVENTOS
     ============================================================ */
  function conectarEventos() {

    /* Fichas de filtro. Acotado a #filtrosBecas: la sección de
       voluntariados tiene su propio contenedor de fichas más abajo, y
       sus grupos usan data-filtro-vol en vez de data-filtro. Sin este
       límite, este mismo listener también procesaría —mal— los clics
       de los filtros de voluntariados. */
    $("#filtrosBecas").querySelectorAll(".filtro__opciones").forEach((grupo) => {
      grupo.addEventListener("click", (ev) => {
        const ficha = ev.target.closest(".ficha");
        if (!ficha) return;
        grupo.querySelectorAll(".ficha").forEach((f) => f.classList.remove("ficha--activa"));
        ficha.classList.add("ficha--activa");
        filtros[grupo.dataset.filtro] = ficha.dataset.valor;
        volverAlCatalogo();
        dibujar();
      });
    });

    /* Búsqueda con pequeño retardo para no redibujar en cada tecla */
    let temporizador;
    campoBusqueda.addEventListener("input", (ev) => {
      busqueda = ev.target.value.trim();
      /* El botón de limpiar mira el campo, no el texto ya recortado:
         escribir solo espacios también tiene que poder deshacerse. */
      btnLimpiarBusqueda.hidden = ev.target.value === "";
      clearTimeout(temporizador);
      temporizador = setTimeout(() => { volverAlCatalogo(); dibujar(); }, 160);
    });

    btnLimpiarBusqueda.addEventListener("click", () => {
      busqueda = "";
      campoBusqueda.value = "";
      btnLimpiarBusqueda.hidden = true;
      campoBusqueda.focus();
      volverAlCatalogo();
      dibujar();
    });

    btnLimpiarFiltros.addEventListener("click", () => { volverAlCatalogo(); limpiarTodo(true); });
    $("#reiniciarBusqueda").addEventListener("click", () => { volverAlCatalogo(); limpiarTodo(true); });

    /* Cambio de vista */
    document.querySelectorAll(".conmutador__btn").forEach((btn) => {
      btn.addEventListener("click", () => cambiarVista(btn.dataset.vista));
    });

    /* Clic en tarjetas y en marcadores (delegación) */
    zona.addEventListener("click", (ev) => {
      const marcador = ev.target.closest("[data-guardar]");
      if (marcador) {
        ev.stopPropagation();
        alternarGuardada(marcador.dataset.guardar);
        return;
      }
      const tarjeta = ev.target.closest(".tarjeta");
      if (tarjeta) abrirPanel(tarjeta.dataset.id, "beca", tarjeta);
    });

    zona.addEventListener("keydown", (ev) => {
      if (ev.key !== "Enter" && ev.key !== " ") return;
      /* El marcador es un botón dentro de la tarjeta: el navegador ya
         dispara su click. Sin esta salida, Enter sobre el marcador
         guardaba la beca Y abría el panel de detalle encima. */
      if (ev.target.closest("[data-guardar]")) return;
      const tarjeta = ev.target.closest(".tarjeta");
      if (tarjeta) { ev.preventDefault(); abrirPanel(tarjeta.dataset.id, "beca", tarjeta); }
    });

    /* El botón "Guardar" del panel escribe en la lista correcta según
       de qué colección sea el detalle abierto en este momento; el botón
       "Compartir" arma el enlace directo a esa misma convocatoria. */
    panelCuerpo.addEventListener("click", (ev) => {
      const botonGuardar = ev.target.closest("[data-guardar-panel]");
      if (botonGuardar) {
        if (tipoPanelActual === "voluntariado") alternarGuardadaVol(botonGuardar.dataset.guardarPanel);
        else alternarGuardada(botonGuardar.dataset.guardarPanel);
        return;
      }
      if (ev.target.closest("[data-compartir-panel]")) compartirActual();
    });

    /* Cerrar el panel. Se envuelve en una función en vez de pasar
       cerrarPanel directo: si no, el objeto Event del clic llegaría
       como su parámetro `actualizarUrl`. */
    $("#cerrarPanel").addEventListener("click", () => cerrarPanel());
    fondoModal.addEventListener("click", () => cerrarPanel());
    document.addEventListener("keydown", (ev) => {
      if (ev.key === "Escape" && !panel.hidden) cerrarPanel();
      else atraparFoco(ev);
    });

    /* Atrás/adelante del navegador: si el usuario llegó aquí con el
       panel abierto (por ejemplo, tras abrir dos convocatorias seguidas)
       y presiona "atrás", el panel debe cerrarse o cambiar de acuerdo
       con lo que quede en la URL. */
    window.addEventListener("popstate", sincronizarPanelConURL);

    $("#btnGuardadas").addEventListener("click", verGuardadas);

    /* Bloques del reloj: llevan al grupo correspondiente */
    document.querySelectorAll("[data-salto]").forEach((bloque) => {
      bloque.addEventListener("click", () => {
        const destino = bloque.dataset.salto === "cierran-pronto" ? "abiertas" : bloque.dataset.salto;

        /* Los grupos solo existen en el catálogo y en vista calendario.
           Si el usuario está en otra parte, se lo devuelve primero. */
        if (modo !== "catalogo" || vista !== "calendario") {
          volverAlCatalogo();
          cambiarVista("calendario");
        }

        const seccion = document.getElementById("grupo-" + destino);
        if (seccion) seccion.scrollIntoView({ behavior: "smooth", block: "start" });
        else mostrarAviso("No hay convocatorias en ese grupo por ahora");
      });
    });

    /* Sombra de la cabecera al bajar */
    window.addEventListener("scroll", () => {
      $("#cabecera").classList.toggle("cabecera--pegada", window.scrollY > 12);
    }, { passive: true });
  }

  /* Eventos de la sección de voluntariados. Función aparte (no dentro de
     conectarEventos) para que quede claro de un vistazo qué pertenece a
     cada colección — el mismo espíritu de "no mezclar" en el código. */
  function conectarEventosVoluntariados() {

    $("#filtrosVol").querySelectorAll(".filtro__opciones").forEach((grupo) => {
      grupo.addEventListener("click", (ev) => {
        const ficha = ev.target.closest(".ficha");
        if (!ficha) return;
        grupo.querySelectorAll(".ficha").forEach((f) => f.classList.remove("ficha--activa"));
        ficha.classList.add("ficha--activa");
        filtrosVol[grupo.dataset.filtroVol] = ficha.dataset.valor;
        volverAlCatalogoVol();
        dibujarVoluntariados();
      });
    });

    let temporizadorVol;
    campoBusquedaVol.addEventListener("input", (ev) => {
      busquedaVol = ev.target.value.trim();
      btnLimpiarBusquedaVol.hidden = ev.target.value === "";
      clearTimeout(temporizadorVol);
      temporizadorVol = setTimeout(() => { volverAlCatalogoVol(); dibujarVoluntariados(); }, 160);
    });

    btnLimpiarBusquedaVol.addEventListener("click", () => {
      busquedaVol = "";
      campoBusquedaVol.value = "";
      btnLimpiarBusquedaVol.hidden = true;
      campoBusquedaVol.focus();
      volverAlCatalogoVol();
      dibujarVoluntariados();
    });

    btnLimpiarFiltrosVol.addEventListener("click", () => { volverAlCatalogoVol(); limpiarTodoVol(true); });
    $("#reiniciarBusquedaVol").addEventListener("click", () => { volverAlCatalogoVol(); limpiarTodoVol(true); });

    /* Clic en tarjetas y marcadores, delegado sobre la zona propia. */
    zonaVol.addEventListener("click", (ev) => {
      const marcador = ev.target.closest("[data-guardar-vol]");
      if (marcador) {
        ev.stopPropagation();
        alternarGuardadaVol(marcador.dataset.guardarVol);
        return;
      }
      const tarjeta = ev.target.closest(".tarjeta");
      if (tarjeta) abrirPanel(tarjeta.dataset.idVol, "voluntariado", tarjeta);
    });

    zonaVol.addEventListener("keydown", (ev) => {
      if (ev.key !== "Enter" && ev.key !== " ") return;
      if (ev.target.closest("[data-guardar-vol]")) return;
      const tarjeta = ev.target.closest(".tarjeta");
      if (tarjeta) { ev.preventDefault(); abrirPanel(tarjeta.dataset.idVol, "voluntariado", tarjeta); }
    });

    /* Tocar la insignia de guardados filtra la cuadrícula a solo esos,
       y tocarla de nuevo (o cualquier búsqueda/filtro) vuelve al catálogo. */
    badgeGuardadosVol.addEventListener("click", () => {
      if (modoVol === "guardados") {
        volverAlCatalogoVol();
      } else {
        limpiarTodoVol(false);
        modoVol = "guardados";
        actualizarBadgeModoVol();
      }
      dibujarVoluntariados();
    });
  }

  /* ============================================================
     CAMBIO DE DÍA
     ------------------------------------------------------------
     Todo el sitio se apoya en "hoy", pero antes ese valor se fijaba
     al cargar la página y no se movía nunca. Una pestaña abierta
     desde ayer seguía diciendo que una beca cerraba "mañana" cuando
     ya había cerrado. Se revisa al volver a la pestaña y también con
     un temporizador, para el caso de una pantalla siempre visible.
     ============================================================ */
  function vigilarCambioDeDia() {
    const revisar = () => {
      const ahora = hoy();
      if (ahora.getTime() === diaDeReferencia.getTime()) return;

      diaDeReferencia = ahora;
      dibujar();
      dibujarVoluntariados();
      actualizarReloj();
      mostrarAnioActual();
    };

    document.addEventListener("visibilitychange", () => {
      if (!document.hidden) revisar();
    });
    window.addEventListener("focus", revisar);
    setInterval(revisar, 60000);
  }

  /* ============================================================
     ANIMACIONES
     ============================================================ */

  /* Cuenta cuántas becas caen en cada bloque del reloj de la portada. */
  function conteosDelReloj() {
    const lista = becasConEstado();
    return [
      lista.filter((b) => b.estado.grupo === "abiertas").length,
      lista.filter((b) => b.estado.grupo === "abiertas" && b.estado.urgente).length,
      lista.filter((b) => b.estado.grupo === "esta-semana").length,
      lista.filter((b) => b.estado.grupo === "este-mes").length
    ];
  }

  /* Al cambiar de día los números se corrigen sin volver a animar. */
  function actualizarReloj() {
    const valores = conteosDelReloj();
    document.querySelectorAll("[data-contador]").forEach((nodo, i) => {
      nodo.textContent = valores[i];
    });
  }

  /* Los cuatro números de la portada suben desde cero. */
  function animarReloj() {
    const valores = conteosDelReloj();
    const reducido = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    document.querySelectorAll("[data-contador]").forEach((nodo, i) => {
      const meta = valores[i];
      if (reducido) { nodo.textContent = meta; return; }
      let actual = 0;
      const paso = Math.max(1, Math.ceil(meta / 18));
      const reloj = setInterval(() => {
        actual = Math.min(meta, actual + paso);
        nodo.textContent = actual;
        if (actual >= meta) clearInterval(reloj);
      }, 42);
    });
  }

  /* Aparición progresiva de los bloques al hacer scroll. */
  function observarRevelados() {
    const objetivos = document.querySelectorAll(".revelar");
    if (!("IntersectionObserver" in window)) {
      objetivos.forEach((o) => o.classList.add("revelar--visible"));
      return;
    }
    const observador = new IntersectionObserver((entradas) => {
      entradas.forEach((entrada) => {
        if (entrada.isIntersecting) {
          entrada.target.classList.add("revelar--visible");
          observador.unobserve(entrada.target);
        }
      });
    }, { threshold: 0.15 });
    objetivos.forEach((o) => observador.observe(o));
  }

  let avisoTemporizador;
  function mostrarAviso(texto) {
    aviso.textContent = texto;
    aviso.classList.add("aviso--visible");
    clearTimeout(avisoTemporizador);
    avisoTemporizador = setTimeout(() => aviso.classList.remove("aviso--visible"), 2800);
  }

  /* ============================================================
     UTILIDADES
     ============================================================ */
  function escapar(texto) {
    return String(texto).replace(/[&<>"']/g, (c) => ({
      "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
    })[c]);
  }

  function capital(texto) {
    return texto.charAt(0).toUpperCase() + texto.slice(1);
  }

  document.addEventListener("DOMContentLoaded", iniciar);
})();
