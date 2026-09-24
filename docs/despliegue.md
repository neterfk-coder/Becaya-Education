# Publicar la web

El proyecto es HTML, CSS y JavaScript sin compilación ni dependencias. Cualquier hosting
estático sirve, y no hay nada que se rompa cuando una librería cambie de versión.

Hoy está en **Vercel**, conectado al repositorio: cada push a `main` redespliega solo.
No hay configuración de build — `vercel.json` declara que la raíz se sirve tal cual.

## La web también alimenta la app

Desde que existe `app/`, el sitio dejó de ser solo un sitio: **es el backend de la app
móvil.** Los archivos `data/becas.json` y `data/voluntariados.json` que se despliegan
aquí son los que descarga cada teléfono con becaya instalada.

Dos consecuencias prácticas:

- **No puedes borrar el sitio** sin dejar la app sin datos.
- **El formato de esos JSON es un contrato.** Está versionado y documentado en
  `esquema-datos.md`. Un APK instalado hace meses sigue pidiendo ese mismo archivo, así
  que renombrar un campo deja ciegas a las versiones ya instaladas.

## Mantener los datos frescos

Este es el punto que decide si el proyecto sirve o no. Un directorio de becas con fechas
vencidas es peor que no tener directorio.

### Lo que corre solo

`.github/workflows/vigilar-convocatorias.yml` revisa cada lunes las páginas de concursos
de Pronabec y abre un issue cuando algo cambió: convocatorias nuevas, plazos movidos o
páginas cuyo texto cambió. También avisa de las fichas que llevan más de 30 días sin
revisarse.

**Nunca publica una fecha por su cuenta.** Pronabec escribe los plazos en prosa y a
menudo sin año; interpretarlos automáticamente es exactamente cómo se terminan
publicando fechas equivocadas. El workflow te dice dónde mirar, y la confirmación la
hace una persona.

### Lo que se hace a mano

```bash
# 1. Editar la fuente con las fechas confirmadas en la web oficial
#    data/manual.json  o  data/voluntariados-manual.json

# 2. Regenerar lo que leen el navegador y la app
node scripts/construir-datos.mjs

# 3. Comprobar antes de publicar
node --test scripts/probar.mjs

# 4. Publicar (Vercel redespliega solo)
git add . && git commit -m "Actualiza convocatorias" && git push
```

Nunca edites `assets/js/datos.js`, `assets/js/voluntariados.js` ni los `data/*.json`
generados: el siguiente build los sobrescribe enteros.

## Sobre el histórico de Pronabec

`scripts/sync-pronabec.mjs` importa convocatorias del portal de datos abiertos. Funciona
y no necesita clave de API, pero **hoy no aporta nada al catálogo**, y conviene entender
por qué antes de tocarlo:

- El portal trae 403 convocatorias reales con fechas exactas, pero todas son de
  **2012 a 2021**: dejó de actualizarse en diciembre de 2021.
- El script tiene un corte, `DESDE_ANIO = 2025`, que las descarta todas. Por eso
  `data/pronabec.json` queda vacío.

Ese corte es deliberado: sin él, el catálogo se llenaría de convocatorias cerradas hace
años. Si alguna vez quieres el histórico —para ver en qué mes suele abrir cada beca—
baja `DESDE_ANIO` y vuelve a correrlo. Lo que sí está muerto es la API *documentada*
(`api.datosabiertos.pronabec.gob.pe`), un host que no resuelve en DNS; el script usa los
endpoints internos del portal, que sí responden.

## Cuándo dejar de usar archivos y pasar a base de datos

Mientras el catálogo sea de decenas o unos pocos cientos de becas, un archivo JSON es
suficiente y más rápido que cualquier base de datos. Considera migrar cuando aparezca:

- Varias personas cargando becas a la vez y necesidad de un panel de administración.
- Cuentas de usuario, para que las guardadas sigan al usuario entre dispositivos.
- Alertas por correo cuando se acerque la apertura de una beca guardada.

Ojo: si migras, el contrato de `data/*.json` tiene que seguir publicándose igual, o las
apps instaladas dejan de funcionar. La base de datos iría detrás, no en lugar de.
