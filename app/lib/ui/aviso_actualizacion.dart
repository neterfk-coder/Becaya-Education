/* ============================================================
   aviso_actualizacion.dart — la banda de versión nueva
   ------------------------------------------------------------
   Aparece arriba de la lista cuando Play informa de una versión
   más reciente. No interrumpe, no tapa nada y no se puede
   quedar atascada: si no hay novedad, no ocupa ni un píxel.
   ============================================================ */

import 'package:flutter/material.dart';

import '../datos/actualizacion.dart';
import 'paleta.dart';

class AvisoActualizacion extends StatelessWidget {
  const AvisoActualizacion({super.key, required this.actualizacion});

  final Actualizacion actualizacion;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: actualizacion,
      builder: (context, _) {
        if (!actualizacion.hayNovedad) return const SizedBox.shrink();

        final (icono, texto, etiquetaBoton, accion) = switch (
            actualizacion.estado) {
          EstadoActualizacion.disponible => (
              Icons.system_update,
              'Hay una versión nueva de becaya.',
              'Actualizar',
              actualizacion.descargar,
            ),
          EstadoActualizacion.descargando => (
              Icons.downloading,
              'Descargando la actualización… puedes seguir usando la app.',
              null,
              null,
            ),
          EstadoActualizacion.listaParaInstalar => (
              Icons.check_circle_outline,
              'Actualización lista.',
              'Reiniciar',
              actualizacion.instalar,
            ),
          _ => (Icons.info_outline, '', null, null),
        };

        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            color: Paleta.morado50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Paleta.morado200),
          ),
          child: Row(
            children: [
              Icon(icono, size: 18, color: Paleta.morado700),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  texto,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: Paleta.morado900,
                  ),
                ),
              ),
              if (etiquetaBoton != null && accion != null)
                TextButton(
                  onPressed: accion,
                  style: TextButton.styleFrom(
                    foregroundColor: Paleta.morado700,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 36),
                  ),
                  child: Text(etiquetaBoton),
                ),
            ],
          ),
        );
      },
    );
  }
}
