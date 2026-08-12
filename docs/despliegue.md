# Publicar la web

El proyecto es HTML, CSS y JavaScript sin compilación ni dependencias. Eso significa que
cualquier hosting estático gratuito sirve, y que no hay nada que se rompa cuando una
librería cambie de versión.

## Opción rápida: GitHub Pages

1. Crea un repositorio y sube toda la carpeta.
2. En el repositorio, ve a **Settings → Pages**.
3. En "Source" elige la rama `main` y la carpeta `/ (root)`.
4. Guarda. En un par de minutos la web queda en `https://tuusuario.github.io/becaya/`.

Costo: cero. Sirve para dominios personalizados también.

## Opción con más margen: Netlify o Vercel

Ambos tienen plan gratuito generoso para sitios estáticos. Arrastras la carpeta a la web de
Netlify y queda publicada, sin configuración. Vercel funciona igual conectando el repositorio.

La ventaja frente a GitHub Pages aparece cuando quieras automatizar la actualización de datos:
ambos permiten ejecutar funciones programadas.

## Mantener los datos frescos

Este es el punto que decide si el proyecto sirve o no. Un directorio de becas con fechas
vencidas es peor que no tener directorio.

### Sincronización manual

```bash
PRONABEC_API_KEY=tu_clave node scripts/sync-pronabec.mjs
git add . && git commit -m "Actualiza convocatorias" && git push
```

Con GitHub Pages eso ya publica los cambios.

### Sincronización automática con GitHub Actions

Crea `.github/workflows/sincronizar.yml`:

```yaml
name: Sincronizar convocatorias

on:
  schedule:
    - cron: "0 11 * * *"   # todos los días a las 6:00 en Perú
  workflow_dispatch:        # y también con un botón, cuando quieras

jobs:
  actualizar:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "20"
      - run: node scripts/sync-pronabec.mjs
        env:
          PRONABEC_API_KEY: ${{ secrets.PRONABEC_API_KEY }}
      - run: |
          git config user.name "becaya bot"
          git config user.email "bot@becaya.pe"
          git add data assets/js/datos.js assets/js/voluntariados.js
          git diff --staged --quiet || git commit -m "Convocatorias al $(date +%F)"
          git push
```

Nota: este workflow solo toca becas (`sync-pronabec.mjs` no tiene equivalente para
voluntariados todavía, porque no existe una API pública de voluntariados como la de
Pronabec). Aun así se sube `voluntariados.js` junto con lo demás porque
`sync-pronabec.mjs` llama a `construir-datos.mjs` al final, y ese script reescribe los
dos catálogos aunque solo haya cambiado uno.

La clave se guarda en **Settings → Secrets and variables → Actions**.

## Cuándo dejar de usar archivos y pasar a base de datos

Mientras el catálogo sea de decenas o unos pocos cientos de becas, un archivo JSON es
suficiente y más rápido que cualquier base de datos. Considera migrar cuando aparezca alguna
de estas necesidades:

- Varias personas cargando becas al mismo tiempo y necesitas un panel de administración.
- Cuentas de usuario, para que las becas guardadas los sigan entre dispositivos.
- Alertas por correo cuando se acerque la apertura de una beca guardada.

Para los tres casos, Supabase tiene un plan gratuito que cubre Postgres, autenticación y
envío de correos, y encaja bien con esta arquitectura sin obligarte a reescribir el frontend.

## Antes de publicar de verdad

- [ ] Reemplaza el contenido de `data/manual.json` y `data/voluntariados-manual.json` con
      datos reales y verificados (no edites `datos.js` ni `voluntariados.js` a mano: se
      sobrescriben en el siguiente build).
- [ ] Cambia `"ejemplo": false` en ambos archivos `*-manual.json`, y en `data/pronabec.json`
      si lo generaste.
- [ ] Corre `node scripts/construir-datos.mjs` y confirma que la advertencia de "fechas de
      ejemplo" ya no aparece en la página.
- [ ] Revisa que cada `enlace` apunte a la página oficial de la institución u organización.
- [ ] Si agregaste `imagen`, verifica cada URL con el comando de `docs/esquema-datos.md`
      antes de publicar: una imagen rota se nota, aunque la web la esconda sola.
- [ ] Corre `node --test scripts/probar.mjs` — debe pasar todo antes de publicar.
- [ ] Agrega una página de "Acerca de" que diga quién mantiene el sitio y con qué frecuencia.
- [ ] Define y publica cada cuánto revisas las fechas. La confianza del usuario se construye ahí.
