# Publicar becaya en Google Play

## ⚠ Antes de nada: respalda el keystore

La clave de firma está en `C:\Users\Home\keystores\becaya-upload.p12`, y su
contraseña en `C:\Users\Home\keystores\becaya-clave.txt`. **Ninguno de los dos está
en git, ni puede estarlo.**

Copia los dos archivos hoy mismo a un gestor de contraseñas o a un disco aparte.
Si los pierdes:

- No puedes publicar actualizaciones firmadas con esa clave.
- Con **Play App Signing** activado (se ofrece al subir el primer AAB y conviene
  aceptarlo), Google puede reiniciar la clave de subida — pero es un trámite de
  varios días con verificación de identidad.
- Sin Play App Signing, la app queda muerta: habría que publicarla como una app
  nueva, con otro nombre de paquete, y los usuarios instalados no reciben nunca
  más una actualización.

No es una advertencia de manual. Es el error irreversible más común al publicar.

## Estado del paquete

| Dato | Valor |
|---|---|
| Nombre en Play | becaya |
| Nombre de paquete | `com.netrcd.becaya` |
| versionName | 1.0.0 |
| versionCode | 1 |
| minSdk / targetSdk | 24 / 36 |
| Firma | PKCS12 RSA 2048, válida hasta 2054 |
| Permisos | solo `INTERNET` |

El AAB firmado queda en:

```
app/build/app/outputs/bundle/release/app-release.aab
```

**Sobre el tamaño:** el AAB pesa ~39 MB porque lleva dentro todas las
arquitecturas y densidades. Eso NO es lo que descarga el usuario: Google Play
genera un APK a medida de cada teléfono, y la descarga real ronda los 10 MB.
Play Console te muestra el tamaño real estimado después de subirlo.

## 🚫 Bloqueo actual: no publiques todavía

`becaya.vercel.app/data/becas.json` **todavía sirve el formato antiguo** (un
arreglo suelto, sin el sobre versionado). La app v1 lee el sobre con `version`,
así que si publicas hoy, todo el que la instale verá la pantalla
*"esta versión de la app quedó desactualizada"* y ninguna convocatoria.

El orden correcto es:

1. Commit y push del sitio → Vercel redespliega los JSON con el sobre.
2. Comprobar que responde el formato nuevo:
   ```bash
   curl -s https://becaya.vercel.app/data/becas.json | head -c 60
   ```
   Debe empezar con `{ "version": 1` y no con `[`.
3. Instalar el AAB en un teléfono real y ver que carga las convocatorias.
4. Recién entonces, subir a producción.

Mientras tanto sí puedes subirlo a **pruebas internas**, que es justo para esto.

## Pasos en Play Console

1. **Crear la app.** Nombre `becaya`, paquete `com.netrcd.becaya`, idioma
   español, gratuita. El paquete no se puede cambiar nunca después.
2. **Play App Signing**: acéptalo. Es la red de seguridad si pierdes el keystore.
3. **Subir el AAB** en *Pruebas internas* primero. Añádete a ti mismo como
   tester; la app se instala desde Play como la vería un usuario real.
4. **Ficha de la tienda**, lo que hay que preparar a mano:
   - Descripción corta (80 caracteres) y larga (4000).
   - Icono 512×512 — se genera con `tool/generar_iconos.ps1`, mismo diseño.
   - Gráfico destacado 1024×500.
   - Mínimo 2 capturas de pantalla de teléfono.
5. **Seguridad de los datos**: esta app **no recoge ni envía ningún dato**. No
   hay cuentas, ni analítica, ni publicidad, ni identificadores. Lo único que
   sale del teléfono es la petición para descargar el catálogo público. Responde
   el formulario en consecuencia — y no marques nada de más: una respuesta
   inflada obliga a mostrar avisos de privacidad que no corresponden.
6. **Clasificación de contenido**: cuestionario. Es una app de información
   educativa, sin contenido sensible.
7. **Público objetivo**: no está dirigida a menores de 13 años.

## Publicar una versión nueva

`versionCode` solo puede subir, y Play rechaza un AAB que repita uno ya subido.
Ambos números salen de `pubspec.yaml`:

```yaml
version: 1.0.1+2
#        ^^^^^ versionName, lo que ve el usuario
#              ^ versionCode, el contador interno
```

Después:

```bash
flutter build appbundle --release
```

## Si clonas el repo en otra máquina

`android/key.properties` no está en git. Sin él, el build de debug funciona
igual, pero el de release falla con un mensaje explicando qué falta. Para
habilitarlo, copia el keystore respaldado y recrea el archivo con las cuatro
claves: `storeFile`, `storePassword`, `keyAlias`, `keyPassword`.
