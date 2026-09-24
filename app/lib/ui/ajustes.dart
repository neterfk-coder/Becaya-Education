/* ============================================================
   ajustes.dart — cuenta, datos e información de la app
   ------------------------------------------------------------
   Reúne en un sitio lo que el usuario puede querer consultar o
   cambiar: quién es, qué tiene guardado, cómo valorar la app y
   dónde están la política de privacidad y el borrado de cuenta
   —estos dos últimos, obligatorios para Google Play.

   No hay interruptores de preferencias porque no hay nada que
   configurar todavía: sin tema oscuro, sin idioma seleccionable
   y sin notificaciones. Un interruptor que no hace nada es peor
   que su ausencia.
   ============================================================ */

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../datos/guardadas.dart';
import '../datos/repositorio.dart';
import '../datos/sesion.dart';
import '../datos/sincronizacion.dart';
import '../version.dart';
import 'cuenta.dart';
import 'paleta.dart';
import 'valorar.dart';

class PantallaAjustes extends StatelessWidget {
  const PantallaAjustes({
    super.key,
    required this.sesion,
    required this.guardadas,
    required this.sincronizador,
  });

  final Sesion sesion;
  final Guardadas guardadas;
  final Sincronizador sincronizador;

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
          'Ajustes',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const _Titulo('Tu cuenta'),
          ListenableBuilder(
            listenable: sesion,
            builder: (context, _) => _BloqueCuenta(
              sesion: sesion,
              onAbrir: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PantallaCuenta(
                    sesion: sesion,
                    guardadas: guardadas,
                    sincronizador: sincronizador,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 26),
          const _Titulo('Tus datos'),
          ListenableBuilder(
            listenable: Listenable.merge([guardadas, sesion]),
            builder: (context, _) => _BloqueDatos(
              guardadas: guardadas,
              sesion: sesion,
            ),
          ),

          const SizedBox(height: 26),
          const _Titulo('Valorar'),
          const InvitacionValorar(),

          const SizedBox(height: 26),
          const _Titulo('Sobre becaya'),
          const _Fila(
            icono: Icons.info_outline,
            titulo: 'Versión',
            valor: versionApp,
          ),
          const _Fila(
            icono: Icons.public,
            titulo: 'Sitio web',
            valor: 'becaya.vercel.app',
            enlace: origenDatos,
          ),
          const _Fila(
            icono: Icons.storefront_outlined,
            titulo: 'Ver en Google Play',
            valor: 'Ficha de la app',
            enlace: urlPlayWeb,
          ),

          const SizedBox(height: 26),
          const _Titulo('Privacidad'),
          const _Fila(
            icono: Icons.shield_outlined,
            titulo: 'Política de privacidad',
            valor: 'Qué datos se manejan y por qué',
            enlace: '$origenDatos/privacidad.html',
          ),
          const _Fila(
            icono: Icons.delete_outline,
            titulo: 'Eliminar tu cuenta',
            valor: 'Cómo borrarla y qué se elimina',
            enlace: '$origenDatos/eliminar-cuenta.html',
          ),

          const SizedBox(height: 26),
          const _Titulo('De dónde salen las fechas'),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Paleta.borde),
            ),
            child: const Text(
              'Cada convocatoria se comprueba contra la página oficial de la '
              'institución antes de publicarse, y la ficha indica cuándo se '
              'hizo esa comprobación.\n\n'
              'Si una fecha no está confirmada, no se publica: es preferible '
              'mostrar menos convocatorias que arriesgarse a que alguien '
              'pierda un plazo por un dato mal verificado.',
              style: TextStyle(fontSize: 13.5, height: 1.55, color: Paleta.gris),
            ),
          ),

          const SizedBox(height: 40),
          const _Creditos(),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------
   Quién eres.
   ------------------------------------------------------------ */

class _BloqueCuenta extends StatelessWidget {
  const _BloqueCuenta({required this.sesion, required this.onAbrir});

  final Sesion sesion;
  final VoidCallback onAbrir;

  @override
  Widget build(BuildContext context) {
    if (sesion.estado == EstadoSesion.noDisponible) {
      return const _Nota(
        'La sincronización entre dispositivos no está activa en esta '
        'versión. Tus convocatorias guardadas funcionan igual: están en '
        'este teléfono.',
      );
    }

    if (!sesion.dentro) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Paleta.morado50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Paleta.morado200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No has iniciado sesión',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Paleta.morado900,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'La cuenta es opcional. Solo sirve para que tus guardadas '
              'aparezcan también en otro dispositivo.',
              style: TextStyle(fontSize: 13, height: 1.5, color: Paleta.gris),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onAbrir,
              style: FilledButton.styleFrom(
                backgroundColor: Paleta.morado500,
                foregroundColor: Paleta.blanco,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Iniciar sesión'),
            ),
          ],
        ),
      );
    }

    final correo = sesion.usuario?.email;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onAbrir,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Paleta.borde),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Paleta.morado100,
                child: Text(
                  sesion.nombreVisible.characters.first.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Paleta.morado700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sesion.nombreVisible,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Paleta.negro,
                      ),
                    ),
                    if (correo != null && correo != sesion.nombreVisible) ...[
                      const SizedBox(height: 2),
                      Text(
                        correo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Paleta.gris,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      sesion.entroConGoogle
                          ? 'Conectado con Google'
                          : 'Conectado con correo',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Paleta.grisClaro,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Paleta.grisClaro),
            ],
          ),
        ),
      ),
    );
  }
}

/* ------------------------------------------------------------
   Qué tienes guardado, y dónde vive.
   ------------------------------------------------------------ */

class _BloqueDatos extends StatelessWidget {
  const _BloqueDatos({required this.guardadas, required this.sesion});

  final Guardadas guardadas;
  final Sesion sesion;

  @override
  Widget build(BuildContext context) {
    final becas = guardadas.cuantas(Coleccion.becas);
    final voluntariados = guardadas.cuantas(Coleccion.voluntariados);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _Contador(
                numero: becas,
                etiqueta: becas == 1 ? 'beca guardada' : 'becas guardadas',
                acento: Paleta.morado500,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Contador(
                numero: voluntariados,
                etiqueta: voluntariados == 1
                    ? 'voluntariado guardado'
                    : 'voluntariados guardados',
                acento: Paleta.verde600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Nota(
          sesion.dentro
              ? 'Guardadas en este teléfono y sincronizadas con tu cuenta.'
              : 'Guardadas en este teléfono. Sin cuenta no salen de aquí, '
                  'y se pierden si desinstalas la app.',
        ),
      ],
    );
  }
}

class _Contador extends StatelessWidget {
  const _Contador({
    required this.numero,
    required this.etiqueta,
    required this.acento,
  });

  final int numero;
  final String etiqueta;
  final Color acento;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Paleta.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$numero',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: -0.5,
              color: acento,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            etiqueta,
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: Paleta.gris,
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------
   Créditos y derechos.
   ------------------------------------------------------------ */

class _Creditos extends StatelessWidget {
  const _Creditos();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(color: Paleta.borde),
        const SizedBox(height: 22),
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Paleta.morado500, Paleta.morado700],
            ),
            borderRadius: BorderRadius.circular(46 * 0.24),
          ),
          child: const Center(
            child: Text(
              'b',
              style: TextStyle(
                fontFamily: 'Arial',
                fontSize: 30,
                fontWeight: FontWeight.w900,
                height: 1.08,
                color: Paleta.blanco,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Creado por $autorApp',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: Paleta.negro,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '© $anioApp becaya. Todos los derechos reservados.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: Paleta.grisClaro),
        ),
        const SizedBox(height: 14),
        const Text(
          'becaya no es un portal oficial de ninguna institución. '
          'Cada convocatoria enlaza a su fuente original.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, height: 1.5, color: Paleta.grisClaro),
        ),
      ],
    );
  }
}

/* ------------------------------------------------------------
   Piezas de la lista.
   ------------------------------------------------------------ */

class _Nota extends StatelessWidget {
  const _Nota(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Paleta.borde),
      ),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 12.5, height: 1.5, color: Paleta.gris),
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 6),
      child: Text(
        texto.toUpperCase(),
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
          color: Paleta.grisClaro,
        ),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.icono,
    required this.titulo,
    required this.valor,
    this.enlace,
  });

  final IconData icono;
  final String titulo;
  final String valor;

  /// Si hay enlace, la fila se puede tocar y abre el navegador del
  /// sistema. Igual que con las convocatorias: nada importante se
  /// muestra dentro de la app sin que se vea la dirección real.
  final String? enlace;

  @override
  Widget build(BuildContext context) {
    final destino = enlace;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: destino == null ? null : () => _abrir(context, destino),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              Icon(icono, size: 20, color: Paleta.grisClaro),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: Paleta.negro,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      valor,
                      style: const TextStyle(fontSize: 12.5, color: Paleta.gris),
                    ),
                  ],
                ),
              ),
              if (destino != null)
                const Icon(Icons.open_in_new, size: 15, color: Paleta.grisClaro),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _abrir(BuildContext context, String url) async {
    final abierto = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!abierto && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir $url')),
      );
    }
  }
}
