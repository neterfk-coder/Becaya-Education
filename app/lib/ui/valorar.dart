/* ============================================================
   valorar.dart — invitación a puntuar la app
   ------------------------------------------------------------
   Cinco estrellas que, al tocarlas, llevan a la ficha de Google
   Play para que el usuario deje ahí su valoración.

   Lo que NO hace, a propósito: guardar la puntuación. Tocar tres
   estrellas y ver que se pintan podría dar a entender que ya
   valoraste — y no es así, la valoración real solo cuenta cuando
   la envías en Play. Por eso las estrellas se pintan un instante
   como acuse del toque y se apagan al volver.

   Tampoco filtra por nota. Mandar solo a los contentos a Play y
   desviar a los descontentos a un formulario privado infla la
   media artificialmente, y además Google lo prohíbe.
   ============================================================ */

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../version.dart';
import 'paleta.dart';

class InvitacionValorar extends StatefulWidget {
  const InvitacionValorar({super.key});

  @override
  State<InvitacionValorar> createState() => _InvitacionValorarState();
}

class _InvitacionValorarState extends State<InvitacionValorar> {
  /// Solo para el acuse visual del toque. No se guarda en ningún sitio.
  int _marcadas = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Paleta.morado50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Paleta.morado200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¿Te está sirviendo becaya?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Paleta.morado900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Tu valoración en Google Play ayuda a que más estudiantes '
            'encuentren la app.',
            style: TextStyle(fontSize: 13, height: 1.5, color: Paleta.gris),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                _Estrella(
                  posicion: i,
                  encendida: i <= _marcadas,
                  onPulsar: () => _abrirPlay(i),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Se abrirá Google Play',
              style: TextStyle(fontSize: 11.5, color: Paleta.grisClaro),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirPlay(int estrellas) async {
    // Acuse del toque: se pintan las estrellas hasta la tocada.
    setState(() => _marcadas = estrellas);

    final abierto = await _intentarAbrir();

    if (!mounted) return;

    // Se apagan al volver: la puntuación de verdad la decide el usuario
    // en Play, y dejarlas encendidas simularía un registro que no hay.
    setState(() => _marcadas = 0);

    if (!abierto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir Google Play en este dispositivo.'),
        ),
      );
    }
  }

  /// Primero la app de Play, que lleva directo a la ficha. Si no está
  /// —emulador, teléfono sin servicios de Google— se cae al navegador.
  Future<bool> _intentarAbrir() async {
    try {
      final enApp = await launchUrl(
        Uri.parse(urlPlayApp),
        mode: LaunchMode.externalApplication,
      );
      if (enApp) return true;
    } catch (_) {
      // Sin app de Play instalada. Se prueba la web.
    }

    try {
      return await launchUrl(
        Uri.parse(urlPlayWeb),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }
}

class _Estrella extends StatelessWidget {
  const _Estrella({
    required this.posicion,
    required this.encendida,
    required this.onPulsar,
  });

  final int posicion;
  final bool encendida;
  final VoidCallback onPulsar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Valorar con $posicion ${posicion == 1 ? "estrella" : "estrellas"} '
          'en Google Play',
      child: IconButton(
        onPressed: onPulsar,
        // Sin tooltip: cinco tooltips en fila estorban más que ayudan,
        // y la etiqueta de accesibilidad ya dice lo mismo.
        iconSize: 32,
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        padding: EdgeInsets.zero,
        splashRadius: 24,
        icon: AnimatedScale(
          scale: encendida ? 1.15 : 1,
          duration: const Duration(milliseconds: 140),
          child: Icon(
            encendida ? Icons.star_rounded : Icons.star_outline_rounded,
            color: encendida ? const Color(0xFFF5A623) : Paleta.grisClaro,
          ),
        ),
      ),
    );
  }
}
