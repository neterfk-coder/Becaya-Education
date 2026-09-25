/* ============================================================
   privacidad.dart — la política, dentro de la app
   ------------------------------------------------------------
   El mismo texto que privacidad.html, pero como pantalla nativa:
   se lee sin conexión, sin salir de la app y sin depender de que
   el sitio esté en pie.

   ESTÁ DUPLICADO A PROPÓSITO, igual que el motor de fechas. La
   web necesita su versión en HTML —Google Play exige una URL
   pública— y la app necesita la suya para funcionar offline.

   Si cambias una, cambia la otra Y sube [fechaPolitica]. Hay una
   prueba, privacidad_test.dart, que compara esa fecha con la de
   privacidad.html y falla si se separan: es lo único que impide
   que la app enseñe una política vieja durante meses sin que
   nadie lo note.
   ============================================================ */

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../datos/repositorio.dart';
import 'paleta.dart';

/// Última actualización de la política. Tiene que coincidir con la
/// fecha que muestra privacidad.html.
const fechaPolitica = '25 de setiembre de 2026';

class PantallaPrivacidad extends StatelessWidget {
  const PantallaPrivacidad({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Paleta.blanco,
      appBar: AppBar(
        backgroundColor: Paleta.blanco,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Paleta.negro,
        elevation: 0,
        title: const Text(
          'Política de privacidad',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Text(
            'Última actualización: $fechaPolitica',
            style: const TextStyle(fontSize: 12.5, color: Paleta.grisClaro),
          ),
          const SizedBox(height: 20),

          const _Destacado(
            'Puedes usar becaya entera sin dar ningún dato.\n\n'
            'Ver el catálogo, filtrarlo, abrir convocatorias y guardarlas en '
            'tu teléfono funciona sin cuenta, sin registro y sin conexión.\n\n'
            'La cuenta es opcional y sirve para una sola cosa: que tus '
            'convocatorias guardadas aparezcan también en otro dispositivo. '
            'Solo si decides crearla se recogen los datos que se describen '
            'más abajo.',
          ),

          const _Apartado(
            titulo: 'Qué datos se recogen, y solo con cuenta',
            cuerpo:
                'Si creas una cuenta, se guardan tres cosas y nada más:',
            puntos: [
              'Tu dirección de correo electrónico, para identificar tu cuenta '
                  'y poder iniciar sesión.',
              'Un identificador de usuario, para asociar tus guardadas a tu '
                  'cuenta.',
              'La lista de convocatorias que marcaste, para sincronizarla '
                  'entre tus dispositivos.',
            ],
            cierre:
                'Si entras con Google, recibimos de Google tu correo y tu '
                'nombre de perfil. No obtenemos tu contraseña de Google ni '
                'acceso a tu cuenta de Google: solo la confirmación de que '
                'eres tú.\n\n'
                'La autenticación y el almacenamiento los gestiona Google '
                'Firebase por cuenta nuestra. Los datos no se venden, no se '
                'comparten con anunciantes ni con ningún tercero, y no se '
                'usan para perfilar a nadie.',
          ),

          const _Apartado(
            titulo: 'Qué NO se recoge, nunca',
            puntos: [
              'Ubicación, contactos, fotos, archivos, cámara o micrófono.',
              'Identificadores de publicidad ni huella del dispositivo.',
              'Analítica de uso, eventos ni perfiles de comportamiento.',
              'Datos de pago: la app es gratuita y no tiene compras.',
            ],
            cierre:
                'La app solicita un único permiso de Android: acceso a '
                'internet, necesario para descargar el catálogo de '
                'convocatorias. Ningún otro.',
          ),

          const _Apartado(
            titulo: 'Qué se guarda en tu dispositivo',
            cuerpo: 'Estas cosas viven en tu teléfono, y sin cuenta no salen '
                'de ahí:',
            puntos: [
              'Una copia del catálogo, para que la app funcione sin conexión.',
              'Las convocatorias que marcas como guardadas. Se escriben al '
                  'instante, sin pedir cuenta ni conexión. Solo se copian a '
                  'la nube si has iniciado sesión.',
            ],
            cierre:
                'Todo eso desaparece si desinstalas la app.',
          ),

          const _Apartado(
            titulo: 'Conexiones que hace la app',
            cuerpo:
                'Sin cuenta, la app se conecta a un único sitio: '
                'becaya.vercel.app, para descargar los archivos públicos del '
                'catálogo. No envía nada tuyo en esa petición — solo pide un '
                'archivo, igual que al abrir una página web.\n\n'
                'Si inicias sesión, se añaden conexiones a Google Firebase '
                'para autenticarte y guardar la lista de convocatorias que '
                'marcaste. Nada más viaja en esas peticiones: ni qué becas '
                'miraste, ni cuándo, ni desde dónde.\n\n'
                'El sitio está alojado en Vercel, que como cualquier servidor '
                'web registra datos técnicos de las peticiones (dirección IP, '
                'tipo de dispositivo, fecha) en sus registros. Esos registros '
                'los gestiona Vercel según su propia política; nosotros no '
                'los consultamos ni los usamos para identificar a nadie.',
          ),

          const _Apartado(
            titulo: 'Enlaces a páginas oficiales',
            cuerpo:
                'Cuando tocas "Ver convocatoria oficial", se abre el navegador '
                'de tu teléfono en la página de la institución que otorga la '
                'beca. Esa página es de ellos, no nuestra: lo que hagas ahí se '
                'rige por su política de privacidad.\n\n'
                'Esos enlaces se abren en el navegador del sistema, y no '
                'dentro de la app, justamente para que puedas ver la dirección '
                'oficial antes de escribir tus datos en cualquier formulario.',
          ),

          const _Apartado(
            titulo: 'Cómo eliminar tu cuenta y tus datos',
            cuerpo:
                'Desde esta misma app: Ajustes → Tu cuenta → Eliminar mi '
                'cuenta. El borrado es inmediato y permanente, sin solicitudes '
                'ni esperas.\n\n'
                'Cerrar sesión o eliminar la cuenta no borra las convocatorias '
                'que guardaste en tu propio teléfono: esas nunca salieron del '
                'dispositivo. Para borrarlas, desinstala la app.',
          ),

          const _Apartado(
            titulo: 'Menores de edad',
            cuerpo:
                'becaya no está dirigida a menores de 13 años.',
          ),

          const _Apartado(
            titulo: 'Cambios en esta política',
            cuerpo:
                'Si en el futuro la app cambiara lo que hace con los datos, '
                'esta pantalla se actualizará antes de publicar esa versión, y '
                'cambiará la fecha de arriba.',
          ),

          const _Apartado(
            titulo: 'Contacto',
            cuerpo: 'Dudas sobre esta política o sobre los datos:\n'
                'neterfk@gmail.com',
          ),

          const SizedBox(height: 26),
          Center(
            child: TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse('$origenDatos/privacidad.html'),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new, size: 15),
              label: const Text('Ver también en la web'),
              style: TextButton.styleFrom(
                foregroundColor: Paleta.gris,
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------
   Piezas del documento.
   ------------------------------------------------------------ */

class _Destacado extends StatelessWidget {
  const _Destacado(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Paleta.morado50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Paleta.morado200),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 14,
          height: 1.6,
          color: Paleta.tinta,
        ),
      ),
    );
  }
}

class _Apartado extends StatelessWidget {
  const _Apartado({
    required this.titulo,
    this.cuerpo,
    this.puntos = const [],
    this.cierre,
  });

  final String titulo;
  final String? cuerpo;
  final List<String> puntos;
  final String? cierre;

  @override
  Widget build(BuildContext context) {
    const estiloCuerpo = TextStyle(
      fontSize: 14,
      height: 1.6,
      color: Paleta.tinta,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: Paleta.negro,
            ),
          ),
          const SizedBox(height: 10),
          if (cuerpo != null) Text(cuerpo!, style: estiloCuerpo),
          if (puntos.isNotEmpty) ...[
            if (cuerpo != null) const SizedBox(height: 10),
            for (final punto in puntos)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(top: 9, right: 10),
                      decoration: const BoxDecoration(
                        color: Paleta.morado500,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(child: Text(punto, style: estiloCuerpo)),
                  ],
                ),
              ),
          ],
          if (cierre != null) ...[
            const SizedBox(height: 10),
            Text(cierre!, style: estiloCuerpo),
          ],
        ],
      ),
    );
  }
}
