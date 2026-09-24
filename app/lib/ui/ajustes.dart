/* ============================================================
   ajustes.dart — información de la app
   ------------------------------------------------------------
   No hay preferencias que tocar: la app no tiene tema oscuro,
   ni idioma seleccionable, ni notificaciones todavía. Meter
   interruptores que no hacen nada sería peor que no tener la
   pantalla.

   Lo que sí hace falta, y Google Play exige que sea alcanzable:
   la política de privacidad y cómo eliminar la cuenta.
   ============================================================ */

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../datos/repositorio.dart';
import '../version.dart';
import 'paleta.dart';

class PantallaAjustes extends StatelessWidget {
  const PantallaAjustes({super.key});

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
          const _Titulo('Sobre becaya'),
          const _Fila(
            icono: Icons.info_outline,
            titulo: 'Versión',
            valor: versionApp,
          ),
          _Fila(
            icono: Icons.public,
            titulo: 'Sitio web',
            valor: 'becaya.vercel.app',
            enlace: origenDatos,
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
              color: Paleta.morado50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Paleta.morado200),
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
