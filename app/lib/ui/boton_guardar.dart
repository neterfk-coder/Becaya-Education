/* ============================================================
   boton_guardar.dart — el marcador de convocatorias
   ------------------------------------------------------------
   Vive aparte porque aparece en dos sitios —la tarjeta y el
   detalle— y tiene que comportarse idéntico en los dos.

   Guardar NO pide cuenta. Es una acción local e inmediata: se
   marca, se escribe en el teléfono y ya. La cuenta solo añade
   que lo marcado aparezca también en otro dispositivo.
   ============================================================ */

import 'package:flutter/material.dart';

import 'paleta.dart';

class BotonGuardar extends StatelessWidget {
  const BotonGuardar({
    super.key,
    required this.guardada,
    required this.acento,
    required this.onPulsar,
    required this.nombre,
    this.grande = false,
  });

  final bool guardada;
  final Acento acento;
  final VoidCallback onPulsar;

  /// Para el lector de pantalla: "Guardar Beca España" dice mucho más
  /// que "Guardar" repetido veinte veces en una lista.
  final String nombre;

  final bool grande;

  @override
  Widget build(BuildContext context) {
    final medida = grande ? 24.0 : 20.0;

    return Semantics(
      button: true,
      selected: guardada,
      label: guardada ? 'Quitar de guardadas: $nombre' : 'Guardar: $nombre',
      child: IconButton(
        onPressed: onPulsar,
        tooltip: guardada ? 'Quitar de guardadas' : 'Guardar',
        iconSize: medida,
        // 44 px es el mínimo cómodo para el pulgar. Sin esto el icono
        // se ve bien pero falla al tocarlo.
        constraints: BoxConstraints.tightFor(
          width: grande ? 48 : 44,
          height: grande ? 48 : 44,
        ),
        padding: EdgeInsets.zero,
        splashRadius: grande ? 26 : 22,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          transitionBuilder: (hijo, animacion) =>
              ScaleTransition(scale: animacion, child: hijo),
          child: Icon(
            guardada ? Icons.bookmark : Icons.bookmark_border,
            // La llave cambia para que AnimatedSwitcher note el cambio:
            // sin ella ve dos Icon del mismo tipo y no anima nada.
            key: ValueKey(guardada),
            color: guardada ? acento.color : Paleta.grisClaro,
          ),
        ),
      ),
    );
  }
}
