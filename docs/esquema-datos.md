# Esquema de datos

Este documento cubre dos catálogos independientes, con sus propios archivos y su propia
sección en la web: **becas** y **voluntariados**. No se mezclan a propósito — ni en los
datos, ni en la interfaz, ni en las becas guardadas.

## El contrato público

`data/becas.json` y `data/voluntariados.json` **ya no son archivos internos**: la app de
Android (`app/`) los descarga directamente desde el sitio publicado. Eso los convierte en
una API pública, aunque no lo parezcan.

La consecuencia práctica: cuando alguien instala el APK, su teléfono sigue pidiendo estos
mismos archivos durante meses o años, aunque nunca actualice la app. Un campo renombrado
hoy deja ciega mañana a una versión instalada que nadie va a volver a tocar.

Los dos archivos vienen envueltos así:

```json
{
  "version": 1,
  "generado": "2026-08-12T23:27:33.387Z",
  "actualizado": "2026-08-12",
  "ejemplo": false,
  "becas": [ ... ]
}
```

| Campo | Qué es |
|---|---|
| `version` | Versión del contrato. Ver reglas abajo. |
| `generado` | Marca de tiempo del build. Sirve para depurar, no para decidir nada. |
| `actualizado` | Fecha de revisión de la fuente menos reciente, en `AAAA-MM-DD`. Es lo que se le muestra al usuario. |
| `ejemplo` | Si es `true`, las fechas no están verificadas y tanto la web como la app lo advierten en pantalla. |
| `becas` / `voluntariados` | La colección. Va bajo su propio nombre, no bajo una clave genérica, para que un archivo suelto se pueda identificar. |

**Las reglas, dentro de una misma `version`:**

- **Se pueden agregar campos nuevos.** Los lectores viejos los ignoran sin enterarse.
- **No se renombra, no se borra y no se cambia el significado** de un campo existente.
- **No se reutiliza un `id`** para otra convocatoria. Los guardados del usuario y, más
  adelante, sus notificaciones programadas, cuelgan de ese `id`.

Solo se sube `VERSION_CATALOGO` (en `scripts/construir-datos.mjs`) cuando se rompe algo a
propósito. Al verlo subir, la app deja de leer el catálogo y pide actualizarse, en vez de
mostrar datos que ya no entiende. Hay tres pruebas que vigilan esto y fallan si el número
del sitio y el de la app se separan:

- `scripts/probar.mjs` → "el catálogo publicado viene en el sobre que espera la app"
- `app/test/estado_test.dart` → "el catálogo del repo trae la versión de contrato que la app espera"
- `app/test/repositorio_test.dart` → el comportamiento de la app ante una versión más nueva

**El navegador no lee estos archivos.** La web usa `assets/js/datos.js`, que el mismo build
genera con los mismos datos. Por eso un cambio en el sobre no afecta al sitio, solo a la app
y a los scripts de Node.

## Becas

Cada convocatoria es un objeto con estos campos, dentro del arreglo `becas` del sobre
descrito arriba. El archivo que lee el navegador es `assets/js/datos.js`, con la misma
información.

| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `id` | texto | sí | Único. Se usa para guardar favoritos, así que no lo cambies una vez publicado. |
| `nombre` | texto | sí | Nombre oficial de la convocatoria, con el año. |
| `institucion` | texto | sí | Quién la otorga. Aparece arriba en la tarjeta. |
| `nivel` | `pregrado` \| `posgrado` \| `ambos` | sí | Controla el filtro de nivel. |
| `destino` | `peru` \| `extranjero` | sí | Controla el filtro de destino. |
| `pais` | texto | sí | Texto libre para mostrar: "Perú", "Reino Unido", "Varios países". |
| `cobertura` | `total` \| `parcial` | sí | Total = matrícula y manutención. Parcial = cualquier cosa menor. |
| `areas` | lista de textos | sí | Usa `["Todas las áreas"]` si no restringe carrera. Alimenta el filtro de áreas. |
| `apertura` | `AAAA-MM-DD` | sí | Sin esta fecha la beca no puede entrar al calendario. |
| `cierre` | `AAAA-MM-DD` o `null` | sí | Si es `null` se muestra "sin fecha de cierre publicada". |
| `resumen` | texto | sí | Dos o tres líneas. En la tarjeta se recorta a dos. |
| `requisitos` | lista de textos | sí | Frases cortas, una condición por elemento. |
| `beneficios` | lista de textos | sí | Qué cubre la beca. |
| `enlace` | URL | sí | Siempre a la página oficial, nunca a un intermediario. |
| `imagen` | URL o `null` | no | Imagen alojada en el sitio oficial. Ver más abajo. |
| `imagenCredito` | texto o `null` | no | Atribución que aparece bajo la imagen. Se ignora si no hay `imagen`. |
| `fuente` | texto | sí | De dónde salió el dato: `Pronabec`, `Carga manual`, etc. Sirve para auditar. |

## Sobre el campo `imagen`

La imagen **no se copia a este repositorio**: se enlaza la que ya publica la institución en su
propio servidor. Eso evita alojar material de terceros, pero tiene tres consecuencias que
conviene tener claras antes de llenar el campo:

1. **Se puede caer sin aviso.** Si la institución cambia la ruta o retira la convocatoria, la
   imagen deja de cargar. La web lo maneja: cuando falla, el bloque desaparece y el detalle se
   ve como si nunca hubiera tenido foto. Nunca queda un ícono roto.
2. **Algunos sitios bloquean el enlace externo.** Verifica antes de agregarla:

   ```bash
   curl -sL -o /dev/null -w "%{http_code} %{content_type}\n" \
     -H "Referer: https://becaya.vercel.app/" "<URL de la imagen>"
   ```

   Debe responder `200` y un `content_type` que empiece por `image/`. Si devuelve 403 o HTML,
   ese sitio no permite enlazar sus imágenes desde fuera: deja el campo en `null`.
3. **Consume ancho de banda ajeno.** Para logos y fotos institucionales es práctica aceptada,
   pero no enlaces imágenes pesadas ni las uses como fondo decorativo masivo.

Una forma fiable de encontrar la URL es leer la etiqueta `og:image` de la página oficial:

```bash
curl -sL "<URL de la convocatoria>" | grep -oiE '<meta[^>]+og:image[^>]*>'
```

El build descarta sola cualquier `imagen` que no sea `http://` o `https://` y avisa por consola,
así que un valor mal puesto nunca llega a la página publicada.

## Voluntariados

Catálogo separado, en `data/voluntariados-manual.json` (fuente) y `data/voluntariados.json` /
`assets/js/voluntariados.js` (generados). Comparte motor de fechas con las becas —
`calcularEstado()` no sabe ni le importa qué colección le mandes— pero tiene sus propios
campos de filtro, porque "nivel" o "cobertura" no significan nada para un voluntariado.

| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `id` | texto | sí | Único dentro de voluntariados. Puede repetir un id de becas sin problema: son espacios separados. |
| `nombre` | texto | sí | Nombre del programa de voluntariado. |
| `organizacion` | texto | sí | Quién lo organiza. Equivalente a `institucion` en becas. |
| `pais` | texto | sí | Texto libre para mostrar. |
| `modalidad` | `presencial` \| `virtual` \| `hibrida` | sí | Controla el filtro de modalidad. |
| `areas` | lista de textos | sí | Temas del voluntariado: "Salud", "Medioambiente", etc. Alimenta el filtro de áreas. |
| `apertura` | `AAAA-MM-DD` | sí | Igual que en becas: sin esta fecha, no se publica. |
| `cierre` | `AAAA-MM-DD` o `null` | sí | `null` para inscripción permanente — se muestra como "Abierta, sin fecha de cierre". |
| `resumen` | texto | sí | Dos o tres líneas. |
| `requisitos` | lista de textos | sí | Frases cortas. |
| `beneficios` | lista de textos | sí | Qué recibe quien participa: certificado, capacitación, etc. — no es dinero, por eso no hay campo `cobertura`. |
| `enlace` | URL | sí | A la página oficial de la organización. |
| `imagen` | URL o `null` | no | Mismas reglas que en becas: se enlaza, no se copia; se verifica igual con `curl`. |
| `imagenCredito` | texto o `null` | no | |
| `fuente` | texto | sí | Por ahora siempre `Carga manual`: no existe (todavía) una API pública de voluntariados como la de Pronabec. |

**Por qué no comparten catálogo con las becas:** una beca implica una decisión académica y de
dinero; un voluntariado no. Mezclarlos en una sola lista obligaría a inventar campos que no
significan lo mismo en los dos casos (¿qué sería "cobertura total" en un voluntariado?), y
escondería los voluntariados entre resultados que la mayoría de gente busca con otra intención.

## Reglas que conviene respetar

**Las fechas mandan.** Si una convocatoria no tiene apertura y cierre confirmados, no la
publiques: una fecha inventada es peor que una beca ausente. El script de sincronización
ya descarta automáticamente las que llegan incompletas.

**Formato de fecha siempre `AAAA-MM-DD`.** El motor parte el texto a mano justamente para
evitar que el navegador interprete la fecha como UTC y la corra un día hacia atrás.

**Un `id` estable.** Los favoritos del usuario se guardan por `id`. Si renombras el `id` de
"Beca 18 — 2027", quien la tenía guardada la pierde.

**Las áreas deben repetirse tal cual.** El filtro de áreas se construye leyendo los valores
que existen en los datos. Si escribes "Ingenieria" en una beca e "Ingeniería y tecnología"
en otra, saldrán dos filtros distintos.

## Si mueves esto a una base de datos

El esquema se traduce casi directo a una tabla. Lo único que conviene separar es `areas`,
que es de muchos a muchos:

```sql
create table becas (
  id            text primary key,
  nombre        text not null,
  institucion   text not null,
  nivel         text not null check (nivel in ('pregrado','posgrado','ambos')),
  destino       text not null check (destino in ('peru','extranjero')),
  pais          text not null,
  cobertura     text not null check (cobertura in ('total','parcial')),
  apertura      date not null,
  cierre        date,
  resumen       text not null,
  requisitos    jsonb not null default '[]',
  beneficios    jsonb not null default '[]',
  enlace        text not null,
  fuente        text not null,
  verificada_el date,
  activa        boolean not null default true
);

create index becas_apertura on becas (apertura);
create index becas_cierre   on becas (cierre);

create table voluntariados (
  id            text primary key,
  nombre        text not null,
  organizacion  text not null,
  pais          text not null,
  modalidad     text not null check (modalidad in ('presencial','virtual','hibrida')),
  apertura      date not null,
  cierre        date,
  resumen       text not null,
  requisitos    jsonb not null default '[]',
  beneficios    jsonb not null default '[]',
  enlace        text not null,
  fuente        text not null,
  verificada_el date,
  activa        boolean not null default true
);

create index voluntariados_apertura on voluntariados (apertura);
create index voluntariados_cierre   on voluntariados (cierre);
```

Nota el campo extra `verificada_el`. En un directorio de becas el problema real no es
mostrar datos, es que envejecen. Guardar cuándo revisaste cada ficha por última vez te
permite ordenar el trabajo de mantenimiento por antigüedad. Lo mismo aplica a voluntariados.

Nótese que `voluntariados` es una tabla separada de `becas`, no la misma tabla con una
columna `tipo`: los campos no coinciden (una tiene `nivel`/`cobertura`, la otra `modalidad`)
y forzarlos a un esquema común obligaría a columnas nulas sin sentido en un lado o el otro.
