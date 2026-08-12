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
│   ├── pronabec.json              GENERADO por sync-pronabec.mjs
│   ├── voluntariados-manual.json  FUENTE — voluntariados cargados a mano
│   ├── becas.json                 GENERADO — catálogo de becas unido
│   └── voluntariados.json         GENERADO — catálogo de voluntariados
├── scripts/
│   ├── construir-datos.mjs        Une las fuentes y escribe lo que carga el navegador
│   ├── sync-pronabec.mjs          Trae convocatorias reales desde la API de Pronabec
│   └── probar.mjs                 Pruebas del motor de fechas y de ambos catálogos
├── docs/
│   ├── esquema-datos.md           Qué campo lleva cada beca/voluntariado y por qué
│   └── despliegue.md              Cómo publicarlo gratis y cómo automatizar la actualización
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

## Los datos que trae son de ejemplo

Las instituciones y organizaciones son reales, y sus enlaces oficiales están verificados,
pero **todas las fechas son inventadas**: se pusieron a mano para que el calendario tenga
contenido en todos sus grupos y se pueda ver cómo se comporta la interfaz. Ninguna
corresponde a una convocatoria real.

Mientras `data/manual.json` siga marcado con `"ejemplo": true`, la web muestra una franja
roja fija arriba advirtiéndolo, y en la portada dice "Fechas de ejemplo, sin verificar" en
lugar de una fecha de actualización. Ese aviso desaparece solo al cargar datos verificados
y poner `"ejemplo": false` — no hay que acordarse de quitarlo a mano.

**El sync de Pronabec nunca se ha ejecutado**, así que hoy el 100% del catálogo es carga
manual. Por eso ninguna beca lleva `"fuente": "Pronabec"`: ese valor queda reservado para
lo que de verdad venga de su API.

Para las becas hay dos caminos, y lo razonable es usar los dos:

**1. Automático, para las becas del Estado peruano.** Pronabec publica una API de datos
abiertos gratuita que incluye las convocatorias vigentes. Pide tu clave en
<https://datosabiertos.pronabec.gob.pe/developer/Api> y corre:

```bash
PRONABEC_API_KEY=tu_clave node scripts/sync-pronabec.mjs
```

Esto escribe `data/pronabec.json` y llama automáticamente a `construir-datos.mjs`, que lo
une con `data/manual.json` sin pisarlo. Antes del primer uso, abre el script y confirma que
el nombre del recurso y los nombres de campo coincidan con lo que muestra la documentación
oficial: la API los publica en español y varían entre datasets.

**2. Manual, para las becas internacionales y para todos los voluntariados.** Chevening,
Fulbright, DAAD, Erasmus Mundus, Eiffel y compañía no tienen API, y tampoco la tiene
ninguna organización de voluntariado. Se cargan editando `data/manual.json` (becas) o
`data/voluntariados-manual.json` (voluntariados) siguiendo `docs/esquema-datos.md`, y
corriendo `node scripts/construir-datos.mjs`. Son unas cuantas decenas, y sus fechas
cambian una o dos veces al año: es perfectamente manejable.

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
