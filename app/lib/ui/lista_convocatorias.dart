/* ============================================================
   lista_convocatorias.dart — el calendario en pantalla
   ------------------------------------------------------------
   La lista no ordena ni clasifica nada: recibe las fichas ya
   calculadas por el motor y solo las pinta. Toda la regla de
   negocio vive en motor/estado.dart.
   ============================================================ */

import 'package:flutter/material.dart';

import '../datos/guardadas.dart';
import '../modelo/convocatoria.dart';
import '../motor/estado.dart';
import 'boton_guardar.dart';
import 'paleta.dart';

/// Una fila de la lista: o es un encabezado de grupo, o es una ficha.
sealed class _Fila {
  const _Fila();
}

class _Encabezado extends _Fila {
  const _Encabezado(this.grupo, this.cuantas);
  final Grupo grupo;
  final int cuantas;
}

class _Tarjeta extends _Fila {
  const _Tarjeta(this.ficha);
  final Ficha ficha;
}

class ListaConvocatorias extends StatelessWidget {
  const ListaConvocatorias({
    super.key,
    required this.fichas,
    required this.acento,
    required this.onTocar,
    required this.onRefrescar,
    required this.guardadas,
    required this.coleccion,
    this.aviso,
    this.vacioTitulo = 'Todavía no hay nada publicado',
    this.vacioDetalle =
        'Un catálogo vacío es preferible a fechas sin verificar. '
        'En cuanto haya una convocatoria confirmada, aparecerá aquí.',
  });

  final List<Ficha> fichas;
  final Acento acento;
  final void Function(Ficha) onTocar;
  final Future<void> Function() onRefrescar;

  final Guardadas guardadas;
  final Coleccion coleccion;

  /// Banda superior opcional: "sin conexión, datos del 12 de agosto".
  final Widget? aviso;

  final String vacioTitulo;
  final String vacioDetalle;

  @override
  Widget build(BuildContext context) {
    final filas = _armarFilas(fichas);

    return RefreshIndicator(
      color: acento.color,
      onRefresh: onRefrescar,
      child: filas.isEmpty
          ? _vacio(context)
          : ListView.builder(
              // Siempre desplazable, para que el gesto de refrescar
              // funcione aunque la lista quepa entera en pantalla.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: filas.length + (aviso != null ? 1 : 0),
              itemBuilder: (context, i) {
                if (aviso != null) {
                  if (i == 0) return aviso!;
                  i -= 1;
                }
                final fila = filas[i];
                return switch (fila) {
                  _Encabezado() => _EncabezadoGrupo(
                      grupo: fila.grupo,
                      cuantas: fila.cuantas,
                      acento: acento,
                    ),
                  _Tarjeta() => TarjetaConvocatoria(
                      ficha: fila.ficha,
                      acento: acento,
                      onTocar: () => onTocar(fila.ficha),
                      guardadas: guardadas,
                      coleccion: coleccion,
                    ),
                };
              },
            ),
    );
  }

  /// Intercala encabezados. Un grupo sin fichas no aparece: un título
  /// "Abiertas ahora" seguido de nada se lee como un error.
  List<_Fila> _armarFilas(List<Ficha> fichas) {
    final filas = <_Fila>[];
    for (final grupo in grupos) {
      final delGrupo = fichas.where((f) => f.estado.grupo == grupo.id).toList();
      if (delGrupo.isEmpty) continue;
      filas.add(_Encabezado(grupo, delGrupo.length));
      filas.addAll(delGrupo.map(_Tarjeta.new));
    }
    return filas;
  }

  Widget _vacio(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(28, 80, 28, 28),
      children: [
        ?aviso,
        Icon(Icons.event_note_outlined, size: 48, color: acento.color),
        const SizedBox(height: 16),
        Text(
          vacioTitulo,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: Paleta.negro,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          vacioDetalle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14.5, color: Paleta.gris, height: 1.5),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            'Desliza hacia abajo para volver a buscar',
            style: TextStyle(fontSize: 13, color: Paleta.grisClaro),
          ),
        ),
      ],
    );
  }
}

class _EncabezadoGrupo extends StatelessWidget {
  const _EncabezadoGrupo({
    required this.grupo,
    required this.cuantas,
    required this.acento,
  });

  final Grupo grupo;
  final int cuantas;
  final Acento acento;

  @override
  Widget build(BuildContext context) {
    final color = grupo.apagado ? Paleta.grisClaro : Paleta.negro;

    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (grupo.destacado)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: acento.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Flexible(
                      child: Text(
                        grupo.titulo,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  grupo.nota,
                  style: const TextStyle(fontSize: 13, color: Paleta.gris),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: grupo.apagado ? const Color(0xFFF2F1F5) : acento.suave,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$cuantas',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: grupo.apagado ? Paleta.gris : acento.oscuro,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TarjetaConvocatoria extends StatelessWidget {
  const TarjetaConvocatoria({
    super.key,
    required this.ficha,
    required this.acento,
    required this.onTocar,
    required this.guardadas,
    required this.coleccion,
  });

  final Ficha ficha;
  final Acento acento;
  final VoidCallback onTocar;

  /// La tarjeta se suscribe ella misma a las guardadas en vez de recibir
  /// un booleano ya resuelto. Antes dependía de que algún ancestro la
  /// reconstruyera, y el marcador no reaccionaba al toque cuando no lo
  /// había — un acoplamiento invisible que solo aparecía en pruebas.
  final Guardadas guardadas;
  final Coleccion coleccion;

  @override
  Widget build(BuildContext context) {
    final item = ficha.item;
    final estado = ficha.estado;
    final apagada = estado.cerrada;

    // El naranja de urgencia le gana al acento de la sección: cuando
    // algo cierra en días, eso es lo único que importa en la tarjeta.
    final colorEstado = estado.urgente
        ? Paleta.urgente
        : (apagada ? Paleta.grisClaro : acento.color);

    return Opacity(
      opacity: apagada ? 0.62 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Paleta.blanco,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: estado.urgente ? const Color(0xFFF1D9C0) : Paleta.borde,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D2E1065),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTocar,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.entidad.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: apagada ? Paleta.grisClaro : acento.oscuro,
                          ),
                        ),
                      ),
                      // Sube un poco sobre el texto para que el área
                      // táctil no coma el margen de la tarjeta.
                      Transform.translate(
                        offset: const Offset(6, -6),
                        // Solo el marcador se repinta al guardar, no la
                        // tarjeta entera ni la lista.
                        child: ListenableBuilder(
                          listenable: guardadas,
                          builder: (context, _) => BotonGuardar(
                            guardada: guardadas.tiene(coleccion, item.id),
                            acento: acento,
                            nombre: item.nombre,
                            onPulsar: () =>
                                guardadas.alternar(coleccion, item.id),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    item.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      height: 1.22,
                      letterSpacing: -0.3,
                      color: Paleta.negro,
                    ),
                  ),
                  if (item.resumen.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.resumen,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Paleta.gris,
                        height: 1.45,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colorEstado,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        estado.titular,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: estado.urgente ? Paleta.urgente : Paleta.negro,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          estado.detalle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Paleta.gris,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (estado.abierta && estado.cierre != null) ...[
                    const SizedBox(height: 9),
                    // La barra mide lo que QUEDA, no lo transcurrido:
                    // se vacía a medida que se acerca el cierre.
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: estado.progreso / 100,
                        minHeight: 5,
                        backgroundColor: const Color(0xFFF0EDF7),
                        valueColor: AlwaysStoppedAnimation(colorEstado),
                      ),
                    ),
                  ],
                  if (item.etiquetas.isNotEmpty) ...[
                    const SizedBox(height: 11),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final etiqueta in item.etiquetas)
                          _Chip(texto: etiqueta, acento: acento, apagado: apagada),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.texto, required this.acento, this.apagado = false});

  final String texto;
  final Acento acento;
  final bool apagado;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: apagado ? const Color(0xFFF4F3F7) : acento.fondo,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: apagado ? const Color(0xFFE8E7EC) : acento.suave,
        ),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: apagado ? Paleta.gris : acento.oscuro,
        ),
      ),
    );
  }
}
