# becaya

Buscador de becas de pregrado y posgrado ordenado por fecha, con una sección aparte de
oportunidades de voluntariado. En vez de una lista larga que hay que filtrar a mano, la
página responde primero la pregunta que de verdad importa:
**qué puedo postular hoy, qué abre esta semana y qué viene después.**

## Cómo abrirlo

Doble clic en `index.html`. No necesita servidor, ni instalar nada, ni conexión a internet.

Si prefieres servirlo localmente:

```bash
npx serve .
```

## Qué hay dentro

```
becaya/
├── index.html                     Estructura de la página (becas + voluntariados)
├── assets/
│   ├── css/styles.css             Diseño: paleta morada (becas) + verde (voluntariados)
│   └── js/
│       ├── datos.js               GENERADO — catálogo de becas, no editar a mano
│       ├── voluntariados.js       GENERADO — catálogo de voluntariados, no editar a mano
│       ├── estado.js              Calcula si algo está abierto, próximo o cerrado
│       └── app.js                 Filtros, búsqueda, panel de detalle, guardadas — de ambos
├── data/
│   ├── manual.json                FUENTE — becas cargadas a mano
│   ├── pronabec.json              GENERADO por sync-pronabec.mjs (hoy vacío, ver docs)
│   ├── voluntariados-manual.json  FUENTE — voluntariados cargados a mano
│   ├── becas.json                 GENERADO — catálogo de becas + CONTRATO de la app
│   └── voluntariados.json         GENERADO — catálogo de voluntariados + CONTRATO
├── scripts/
│   ├── construir-datos.mjs        Une las fuentes y escribe lo que carga el navegador
│   ├── sync-pronabec.mjs          Importa el histórico del portal de datos abiertos
│   ├── vigilar-pronabec.mjs       Vigila las páginas vivas y avisa de cambios
│   └── probar.mjs                 Pruebas del motor de fechas y de ambos catálogos
├── app/                           App móvil en Flutter (Android/iOS) — ver app/README.md
├── docs/
│   ├── esquema-datos.md           Qué campo lleva cada ficha, y el contrato de datos
│   └── despliegue.md              Cómo se publica y cómo se mantienen frescos los datos
└── README.md
```

**La regla que importa:** solo se editan los archivos marcados FUENTE. Todo lo marcado
GENERADO se sobrescribe en cada build, así que cualquier cambio a mano ahí se pierde:

```bash
node scripts/construir-datos.mjs   # tras editar cualquiera de los *-manual.json
node --test scripts/probar.mjs     # comprueba el motor y los dos catálogos
```

## Dos catálogos que nunca se mezclan

**Becas** y **voluntariados** son colecciones separadas a propósito: archivos de datos
distintos, validación distinta, sección propia en la página, filtros propios y hasta
guardadas propias (localStorage con clave distinta). Una beca implica una decisión
académica y de dinero; un voluntariado no. Mezclarlos en una sola lista escondería lo uno
entre lo otro para gente que busca con una intención distinta. El detalle completo del
porqué está en `docs/esquema-datos.md`.

## De dónde salen las fechas

Todas las fechas publicadas están **verificadas contra la web oficial**, una por una, y
cada ficha guarda cuándo se comprobó y con qué evidencia (`verificadaEl` y
`notaVerificacion`). Si una fecha no se puede señalar en la página oficial, la beca no se
publica. Una fecha inventada es peor que una beca ausente.

### No existe una fuente automática. Esto se investigó a fondo:

| Vía | Qué se encontró |
|---|---|
| API de datos abiertos de Pronabec | El host de su documentación (`api.datosabiertos.pronabec.gob.pe`) **no existe en DNS**. Sus endpoints internos sí responden y no piden clave, pero los datos de convocatorias **se detienen en diciembre de 2021**. Inservible para fechas vigentes. |
| Web de Pronabec | **Viva y mantenida.** `pronabec.gob.pe/concursos-becas-creditos/` lista los concursos en proceso. Es la fuente real. |
| Chevening, DAAD, Fulbright… | Sin API. Solo páginas web. |

### Por qué no se leen las fechas automáticamente

Pronabec escribe los plazos en prosa. En su web está la frase *"la postulación es hasta el
martes 4 de noviembre"*, **sin año**. El 4 de noviembre cae martes en 2025, no en 2026: un
script que asumiera el año en curso publicaría un plazo equivocado por doce meses.

Lo único legible por máquina es el contador de cuenta regresiva de algunas páginas
(`data-date`), que trae un timestamp exacto. De ahí salieron las fechas de este catálogo,
contrastadas además con el texto de la página.

### El flujo real: el robot detecta, el humano confirma

```bash
node scripts/vigilar-pronabec.mjs            # ¿cambió alguna convocatoria?
node scripts/vigilar-pronabec.mjs --guardar  # darlas por vistas
```

Recorre las páginas de concursos, guarda una huella del contenido y avisa de tres cosas:
convocatorias **nuevas**, **plazos que se movieron**, y páginas cuyo texto cambió. Además
recuerda qué fichas del catálogo llevan más de 30 días sin revisarse.

Corre solo cada lunes con `.github/workflows/vigilar-convocatorias.yml` y abre un issue
cuando hay novedades. **Nunca publica una fecha por su cuenta**: solo te dice dónde mirar.

Los voluntariados y las becas internacionales se cargan igual, a mano, editando
`data/voluntariados-manual.json` y `data/manual.json` según `docs/esquema-datos.md`.

### El histórico de Pronabec

`scripts/sync-pronabec.mjs` sí funciona y no necesita clave de API, pero **hoy no aporta
nada**: el portal de datos abiertos solo llega hasta 2021, y el corte `DESDE_ANIO = 2025`
descarta todo lo anterior para que el catálogo no se llene de convocatorias cerradas hace
años. Por eso `data/pronabec.json` queda vacío. Si quieres el histórico, baja ese número.
El detalle está en `docs/despliegue.md`.

## Cómo funciona el calendario

Todo se reduce a comparar dos fechas con el día de hoy. Eso ocurre en `estado.js`, en la
función `calcularEstado()`, y de ahí salen los cinco grupos:

| Grupo | Condición |
|---|---|
| Abiertas ahora | La apertura ya pasó y el cierre todavía no |
| Abren esta semana | Faltan 7 días o menos para la apertura |
| Abren este mes | Faltan entre 8 y 31 días |
| Más adelante | Faltan más de 31 días |
| Ya cerradas | El cierre ya pasó |

Dentro de "abiertas", una beca a la que le quedan 7 días o menos se marca como urgente y
cambia de color. El resto de la interfaz no hace cuentas: solo pinta lo que este archivo
le entrega.

## Lo que ya funciona

- Buscador por nombre, institución, país, carrera o descripción (sin distinguir acentos)
- Filtros combinables por nivel, destino, cobertura y área de estudio
- Dos vistas de becas: calendario agrupado por fecha, y cuadrícula plana
- Sección aparte de voluntariados, con su propio buscador, filtro por modalidad y área
- Panel de detalle compartido, con requisitos, beneficios, imagen oficial (opcional) y
  enlace verificado — adapta sus etiquetas según sea una beca o un voluntariado
- Guardar becas y guardar voluntariados por separado, cada uno con su contador
- Barra de progreso que muestra cuánto queda de cada convocatoria abierta
- El calendario se recalcula solo si dejas la pestaña abierta y cruza la medianoche
- Responsive hasta móvil, navegación por teclado, y animaciones que se desactivan solas
  si el sistema tiene activado "reducir movimiento"

## Siguientes pasos naturales

1. **Alertas por correo** cuando se acerque la apertura de una beca guardada. Es la función
   que convierte el sitio en algo que la gente vuelve a abrir.
2. **Cuentas de usuario**, para que las guardadas sigan al usuario entre su teléfono y su
   computadora.
3. **Panel de administración** para cargar becas sin editar archivos.
4. **Perfil de postulante** (nivel, área, región) que ordene los resultados por afinidad.

Los tres primeros caben en el plan gratuito de Supabase sin cambiar la arquitectura.

## Una advertencia honesta

El reto de este proyecto no es técnico. El código de arriba lo puede sostener una sola
persona. Lo difícil es mantener las fechas al día: esa es la razón por la que casi todos los
directorios de becas terminan llenos de convocatorias vencidas. Si vas a lanzarlo, define
desde el inicio cada cuánto revisas los datos y publícalo en la página. Es lo que va a
diferenciarte de verdad.
