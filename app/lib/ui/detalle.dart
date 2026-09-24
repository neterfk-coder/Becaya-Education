/* ============================================================
   detalle.dart — la ficha completa de una convocatoria
   ------------------------------------------------------------
   Regla de la pantalla: nada de lo que se muestra aquí se
   inventa. Si el catálogo no trae requisitos, no se listan
   requisitos genéricos — se dice que no están publicados y se
   manda a la fuente oficial.
   ============================================================ */

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../datos/guardadas.dart';
import '../modelo/convocatoria.dart';
import '../motor/estado.dart';
import 'boton_guardar.dart';
import 'paleta.dart';

class PantallaDetalle extends StatelessWidget {
  const PantallaDetalle({
    super.key,
    required this.ficha,
    required this.acento,
    required this.guardadas,
    required this.coleccion,
  });

  final Ficha ficha;
  final Acento acento;
  final Guardadas guardadas;
  final Coleccion coleccion;

  @override
  Widget build(BuildContext context) {
    final item = ficha.item;
    final estado = ficha.estado;

    return Scaffold(
      backgroundColor: Paleta.blanco,
      appBar: AppBar(
        backgroundColor: Paleta.blanco,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Paleta.negro,
        elevation: 0,
        title: Text(
          item.entidad.isEmpty ? 'Convocatoria' : item.entidad,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        actions: [
          // Se reconstruye solo este botón cuando cambian las guardadas,
          // no la pantalla entera.
          ListenableBuilder(
            listenable: guardadas,
            builder: (context, _) => BotonGuardar(
              guardada: guardadas.tiene(coleccion, item.id),
              acento: acento,
              nombre: item.nombre,
              grande: true,
              onPulsar: () => guardadas.alternar(coleccion, item.id),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      bottomNavigationBar: _BarraAccion(item: item, acento: acento),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Text(
            item.nombre,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.18,
              letterSpacing: -0.6,
              color: Paleta.negro,
            ),
          ),
          const SizedBox(height: 16),
          _PanelEstado(estado: estado, acento: acento),
          if (item.resumen.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              item.resumen,
              style: const TextStyle(
                fontSize: 15.5,
                height: 1.55,
                color: Paleta.gris,
              ),
            ),
          ],
          const SizedBox(height: 22),
          _Datos(item: item),
          _Seccion(
            titulo: 'Requisitos',
            items: item.requisitos,
            vacio: 'Los requisitos no están publicados en el catálogo. '
                'Revísalos en la convocatoria oficial.',
            acento: acento,
          ),
          _Seccion(
            titulo: 'Beneficios',
            items: item.beneficios,
            vacio: 'Los beneficios no están publicados en el catálogo. '
                'Revísalos en la convocatoria oficial.',
            acento: acento,
          ),
          const SizedBox(height: 8),
          _Procedencia(item: item),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------
   Panel de estado: la respuesta a "¿puedo postular?"
   ------------------------------------------------------------ */

class _PanelEstado extends StatelessWidget {
  const _PanelEstado({required this.estado, required this.acento});

  final Estado estado;
  final Acento acento;

  @override
  Widget build(BuildContext context) {
    final cerrada = estado.cerrada;
    final urgente = estado.urgente;

    final fondo = cerrada
        ? const Color(0xFFF7F7F9)
        : (urgente ? Paleta.urgenteSuave : acento.fondo);
    final borde = cerrada
        ? Paleta.borde
        : (urgente ? const Color(0xFFF1D9C0) : acento.suave);
    final color = cerrada
        ? Paleta.gris
        : (urgente ? Paleta.urgente : acento.oscuro);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            estado.titular,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            estado.detalle,
            style: const TextStyle(fontSize: 14, color: Paleta.gris),
          ),
          if (estado.abierta && estado.cierre != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: estado.progreso / 100,
                minHeight: 6,
                backgroundColor: Paleta.blanco,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
          if (estado.apertura != null) ...[
            const SizedBox(height: 12),
            Text(
              'Abrió el ${formatoFecha(estado.apertura)}',
              style: const TextStyle(fontSize: 13, color: Paleta.gris),
            ),
          ],
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------
   Datos duros en dos columnas
   ------------------------------------------------------------ */

class _Datos extends StatelessWidget {
  const _Datos({required this.item});

  final Convocatoria item;

  @override
  Widget build(BuildContext context) {
    final datos = <String, String>{
      if (item.entidad.isNotEmpty) 'Convoca': item.entidad,
      if (item.pais.isNotEmpty) 'Dónde': item.pais,
      if (item is Beca) ...{
        if ((item as Beca).nivel.isNotEmpty) 'Nivel': (item as Beca).nivel,
        if ((item as Beca).cobertura.isNotEmpty) 'Cobertura': (item as Beca).cobertura,
      },
      if (item is Voluntariado && (item as Voluntariado).modalidad.isNotEmpty)
        'Modalidad': (item as Voluntariado).modalidad,
      if (item.areas.isNotEmpty) 'Áreas': item.areas.join(' · '),
    };

    if (datos.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Paleta.borde),
      ),
      child: Column(
        children: [
          for (final entrada in datos.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(
                      entrada.key,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Paleta.grisClaro,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entrada.value,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Paleta.negro,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------
   Requisitos / beneficios
   ------------------------------------------------------------ */

class _Seccion extends StatelessWidget {
  const _Seccion({
    required this.titulo,
    required this.items,
    required this.vacio,
    required this.acento,
  });

  final String titulo;
  final List<String> items;
  final String vacio;
  final Acento acento;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
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
          if (items.isEmpty)
            Text(
              vacio,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Paleta.grisClaro,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            for (final texto in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(top: 8, right: 10),
                      decoration: BoxDecoration(
                        color: acento.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        texto,
                        style: const TextStyle(
                          fontSize: 14.5,
                          height: 1.5,
                          color: Paleta.gris,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------
   De dónde salió este dato.
   ------------------------------------------------------------ */

class _Procedencia extends StatelessWidget {
  const _Procedencia({required this.item});

  final Convocatoria item;

  @override
  Widget build(BuildContext context) {
    final beca = item is Beca ? item as Beca : null;
    final verificada = beca?.verificadaEl;
    final nota = beca?.notaVerificacion;

    return Container(
      margin: const EdgeInsets.only(top: 26),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Paleta.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_outlined, size: 16, color: Paleta.grisClaro),
              const SizedBox(width: 6),
              Text(
                'Fuente: ${item.fuente}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Paleta.gris,
                ),
              ),
            ],
          ),
          if (verificada != null) ...[
            const SizedBox(height: 6),
            Text(
              'Verificada el ${formatoFecha(aFecha(verificada))}',
              style: const TextStyle(fontSize: 12.5, color: Paleta.gris),
            ),
          ],
          if (nota != null) ...[
            const SizedBox(height: 8),
            Text(
              nota,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: Paleta.grisClaro,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------
   El botón que importa.
   ------------------------------------------------------------ */

class _BarraAccion extends StatelessWidget {
  const _BarraAccion({required this.item, required this.acento});

  final Convocatoria item;
  final Acento acento;

  Future<void> _abrir(BuildContext context) async {
    final url = Uri.parse(item.enlace);
    // externalApplication y no una vista dentro de la app: el usuario
    // tiene que poder ver la barra de direcciones oficial antes de
    // escribir sus datos en ningún formulario.
    final abierto = await launchUrl(url, mode: LaunchMode.externalApplication);

    if (!abierto && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir ${item.enlace}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Paleta.blanco,
        border: Border(top: BorderSide(color: Paleta.borde)),
      ),
      child: FilledButton.icon(
        onPressed: () => _abrir(context),
        icon: const Icon(Icons.open_in_new, size: 18),
        label: const Text('Ver convocatoria oficial'),
        style: FilledButton.styleFrom(
          backgroundColor: acento.color,
          foregroundColor: Paleta.blanco,
          minimumSize: const Size.fromHeight(50),
          textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
