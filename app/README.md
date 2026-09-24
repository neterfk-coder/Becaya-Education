# becaya — app móvil

Cliente Android/iOS del catálogo de becas y voluntariados. Vive dentro del mismo
repositorio que la web a propósito: comparten los datos y comparten la regla de
fechas, y tenerlos juntos hace que cualquier divergencia aparezca en un solo diff.

## No tiene backend

La app descarga el catálogo que ya publica el sitio:

```
https://becaya.vercel.app/data/becas.json
https://becaya.vercel.app/data/voluntariados.json
```

Son unos pocos KB, así que se bajan enteros y se guardan completos: la app abre sin
conexión. El formato de esos archivos es un **contrato público** — ver
`../docs/esquema-datos.md` antes de cambiar cualquier campo, porque un APK instalado
sigue pidiendo ese mismo archivo durante meses.

## El motor está duplicado a propósito

`lib/motor/estado.dart` es el puerto de `../assets/js/estado.js`. No se puede calcular
en el servidor porque el resultado depende de qué día abras la app, así que web y app
hacen la misma cuenta cada una por su lado.

`test/estado_test.dart` son las mismas pruebas que `../scripts/probar.mjs`. Existen
para que las dos copias no empiecen a decir cosas distintas en silencio. **Si tocas
una, toca la otra.**

## Estructura

```
app/
├── lib/
│   ├── main.dart                    Armado, pestañas y estados de carga
│   ├── motor/estado.dart            La regla de fechas (puerto de estado.js)
│   ├── modelo/convocatoria.dart     Beca y Voluntariado, lectura defensiva del JSON
│   ├── datos/repositorio.dart       Descarga, caché offline y versión del contrato
│   └── ui/                          Paleta, lista, tarjetas y detalle
├── test/                            Motor, contrato de datos y lista
├── tool/
│   ├── generar_iconos.ps1           Regenera todos los iconos (Windows)
│   ├── becaya-marca.svg             La marca en curvas, sin depender de fuentes
│   └── play-icono-512.png           Icono de la ficha de Google Play
└── docs/publicar.md                 Cómo firmar y subir a Google Play
```

## Comandos

```bash
flutter test                  # motor, contrato y lista
flutter analyze               # debe quedar limpio
flutter run                   # con un teléfono conectado por USB
flutter build appbundle --release   # AAB firmado para Play
```

El build de release necesita `android/key.properties`, que no está en git. Sin él el
debug funciona igual y el release falla con una explicación. Ver `docs/publicar.md`.
