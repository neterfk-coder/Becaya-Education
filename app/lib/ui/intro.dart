/* ============================================================
   intro.dart — la presentación al abrir
   ------------------------------------------------------------
   Muestra la marca unos segundos al arrancar.

   La decisión que importa: la pantalla de inicio se monta DEBAJO
   desde el primer instante, así que el catálogo se descarga y las
   guardadas se leen del disco MIENTRAS se ve la marca. La intro
   no le quita tiempo al usuario: ocupa un tiempo que de todas
   formas se iba en cargar.

   Por eso tampoco se espera a que termine la carga para quitarla.
   Si la red está lenta, la intro se va igual y aparece el
   indicador de carga normal: dejar la marca en pantalla hasta
   que responda el servidor convertiría un adorno en un bloqueo.
   ============================================================ */

import 'dart:async';

import 'package:flutter/material.dart';

import 'paleta.dart';

/// Cuánto dura. Suficiente para leerse, corto para no estorbar —
/// quien abre la app diez veces al día no quiere una ceremonia.
const _duracionVisible = Duration(milliseconds: 1500);
const _duracionSalida = Duration(milliseconds: 420);

/// Envuelve la app: debajo va [hijo], encima la marca, que se
/// desvanece sola y luego se quita del árbol.
class Arranque extends StatefulWidget {
  const Arranque({super.key, required this.hijo});

  final Widget hijo;

  @override
  State<Arranque> createState() => _ArranqueState();
}

class _ArranqueState extends State<Arranque> {
  bool _visible = true;
  bool _enElArbol = true;

  /// Se guarda para poder cancelarlo. Con `Future.delayed` suelto, el
  /// temporizador sigue vivo aunque el widget se destruya antes —por
  /// ejemplo si el usuario cierra la app en el primer segundo— y queda
  /// trabajo pendiente sobre un árbol que ya no existe.
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    _reloj = Timer(_duracionVisible, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.hijo,
        if (_enElArbol)
          // IgnorePointer durante el desvanecido: mientras se va, la
          // capa sigue dibujada y sin esto se tragaría el primer toque
          // sobre la lista que ya se ve debajo.
          IgnorePointer(
            ignoring: !_visible,
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: _duracionSalida,
              curve: Curves.easeOut,
              onEnd: () {
                if (!_visible && mounted) {
                  setState(() => _enElArbol = false);
                }
              },
              child: const PantallaIntro(),
            ),
          ),
      ],
    );
  }
}

class PantallaIntro extends StatefulWidget {
  const PantallaIntro({super.key});

  @override
  State<PantallaIntro> createState() => _PantallaIntroState();
}

class _PantallaIntroState extends State<PantallaIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _control = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final _entrada = CurvedAnimation(
    parent: _control,
    curve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      // El mismo degradado que el icono del lanzador, para que abrir la
      // app se vea como una continuación del toque sobre el icono.
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Paleta.morado500, Color(0xFF4C1D95)],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _entrada,
            builder: (context, hijo) => Opacity(
              opacity: _entrada.value,
              child: Transform.scale(
                // Arranca un pelo pequeña y crece: da sensación de que
                // la app se abre, no de que una imagen aparece.
                scale: 0.88 + (_entrada.value * 0.12),
                child: hijo,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _BaldosaMarca(),
                const SizedBox(height: 22),
                const Text(
                  'becaya',
                  style: TextStyle(
                    fontFamily: 'Arial',
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                    color: Paleta.blanco,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Convocatorias verificadas, por fecha',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: Paleta.blanco.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La baldosa blanca con la "b" morada — la misma composición que el
/// gráfico destacado de la ficha de Play.
class _BaldosaMarca extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const lado = 104.0;

    return Container(
      width: lado,
      height: lado,
      decoration: BoxDecoration(
        color: Paleta.blanco,
        // 0.24 del lado: el mismo radio que el icono de la app.
        borderRadius: BorderRadius.circular(lado * 0.24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E1065).withValues(alpha: 0.28),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          'b',
          style: TextStyle(
            fontFamily: 'Arial',
            fontSize: 68,
            fontWeight: FontWeight.w900,
            height: 1.08,
            color: Paleta.morado500,
          ),
        ),
      ),
    );
  }
}
