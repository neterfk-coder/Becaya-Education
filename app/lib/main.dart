/* ============================================================
   main.dart — el armado de la app
   ------------------------------------------------------------
   becaya: calendario de becas y voluntariados verificados.

   La app no tiene backend propio. Lee el mismo catálogo que
   publica la web (data/becas.json y data/voluntariados.json) y
   hace la clasificación por fechas en el teléfono, porque el
   resultado depende de qué día lo abras.
   ============================================================ */

import 'package:flutter/material.dart';

import 'datos/repositorio.dart';
import 'modelo/convocatoria.dart';
import 'motor/estado.dart';
import 'ui/detalle.dart';
import 'ui/lista_convocatorias.dart';
import 'ui/paleta.dart';

void main() {
  runApp(const AppBecaya());
}

class AppBecaya extends StatelessWidget {
  const AppBecaya({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'becaya',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        scaffoldBackgroundColor: Paleta.blanco,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Paleta.morado500,
          primary: Paleta.morado500,
        ),
      ),
      home: const PantallaInicio(),
    );
  }
}

class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  final _repositorio = Repositorio();

  Catalogo? _catalogo;
  Object? _error;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (mounted) setState(() => _cargando = true);
    try {
      final catalogo = await _repositorio.cargar();
      if (!mounted) return;
      setState(() {
        _catalogo = catalogo;
        _error = null;
        _cargando = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _cargando = false;
      });
    }
  }

  void _abrirDetalle(Ficha ficha, Acento acento) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaDetalle(ficha: ficha, acento: acento),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalogo = _catalogo;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Paleta.blanco,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 20,
          title: const _Marca(),
          bottom: const TabBar(
            labelColor: Paleta.negro,
            unselectedLabelColor: Paleta.grisClaro,
            indicatorColor: Paleta.morado500,
            indicatorWeight: 2.5,
            labelStyle: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: 'Becas'),
              Tab(text: 'Voluntariados'),
            ],
          ),
        ),
        body: switch ((_cargando, catalogo, _error)) {
          (true, null, _) => const _Cargando(),
          (_, null, final error?) => error is CatalogoIncompatible
              ? _DebeActualizarse(error: error)
              : _SinConexion(onReintentar: _cargar),
          (_, final c?, _) => TabBarView(
              children: [
                ListaConvocatorias(
                  fichas: aFichas(c.becas),
                  acento: Acento.becas,
                  aviso: _avisos(c),
                  onRefrescar: _cargar,
                  onTocar: (f) => _abrirDetalle(f, Acento.becas),
                ),
                ListaConvocatorias(
                  fichas: aFichas(c.voluntariados),
                  acento: Acento.voluntariados,
                  aviso: _avisos(c),
                  onRefrescar: _cargar,
                  vacioTitulo: 'Aún no hay voluntariados publicados',
                  vacioDetalle:
                      'No existe una fuente oficial única de voluntariados como '
                      'la de Pronabec, así que este catálogo se carga a mano y '
                      'solo con convocatorias confirmadas.',
                  onTocar: (f) => _abrirDetalle(f, Acento.voluntariados),
                ),
              ],
            ),
          _ => const _Cargando(),
        },
      ),
    );
  }

  /// Advertencias sobre la calidad de lo que se está mostrando.
  ///
  /// Un directorio de fechas que envejece sin decirlo es peor que uno
  /// vacío, así que estas bandas nunca se ocultan "para que se vea más
  /// limpio": si aparecen, es porque hay algo que el usuario necesita
  /// saber antes de confiar en una fecha.
  Widget? _avisos(Catalogo catalogo) {
    final bandas = <Widget>[
      if (catalogo.ejemplo)
        const _Banda(
          icono: Icons.science_outlined,
          texto: 'El sitio marcó este catálogo como datos de ejemplo: '
              'las fechas no están verificadas.',
        ),
      if (catalogo.desdeCache)
        _Banda(
          icono: Icons.cloud_off_outlined,
          texto: catalogo.descargado == null
              ? 'Sin conexión. Estás viendo la última copia guardada.'
              : 'Sin conexión. Datos descargados el '
                  '${formatoFecha(catalogo.descargado)}. Verifica las fechas '
                  'en la página oficial antes de postular.',
        ),
    ];

    if (bandas.isEmpty) return null;
    return Column(children: bandas);
  }
}

class _Banda extends StatelessWidget {
  const _Banda({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Paleta.urgenteSuave,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF1D9C0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 17, color: Paleta.urgente),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: Paleta.urgente,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Marca extends StatelessWidget {
  const _Marca();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          'becaya',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
            color: Paleta.morado900,
          ),
        ),
        SizedBox(width: 8),
        Text(
          'convocatorias verificadas',
          style: TextStyle(fontSize: 12, color: Paleta.grisClaro),
        ),
      ],
    );
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
    );
  }
}

/// No hubo red y tampoco había nada guardado. Se dice tal cual, sin
/// disfrazarlo de "algo salió mal".
class _SinConexion extends StatelessWidget {
  const _SinConexion({required this.onReintentar});

  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 44, color: Paleta.grisClaro),
            const SizedBox(height: 16),
            const Text(
              'No se pudo descargar el catálogo',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Paleta.negro,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Es la primera vez que abres la app y no hay conexión, así que '
              'todavía no hay nada guardado. Conéctate una vez y después '
              'funcionará sin internet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5, color: Paleta.gris),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: onReintentar,
              style: FilledButton.styleFrom(
                backgroundColor: Paleta.morado500,
                foregroundColor: Paleta.blanco,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// El sitio publica un catálogo más nuevo del que esta versión entiende.
///
/// No se ofrece "reintentar" porque no arreglaría nada, y no se cae a la
/// caché porque dejaría al usuario con fechas congeladas para siempre sin
/// enterarse. Se dice lo que pasa y se da la única salida real.
class _DebeActualizarse extends StatelessWidget {
  const _DebeActualizarse({required this.error});

  final CatalogoIncompatible error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.system_update_alt, size: 44, color: Paleta.grisClaro),
            const SizedBox(height: 16),
            const Text(
              'Esta versión de la app quedó desactualizada',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Paleta.negro,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'El catálogo cambió de formato y esta versión ya no puede '
              'leerlo. Actualiza la app para volver a ver las convocatorias. '
              'Mientras tanto, puedes consultarlas en becaya.vercel.app.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5, color: Paleta.gris),
            ),
            const SizedBox(height: 18),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, color: Paleta.grisClaro),
            ),
          ],
        ),
      ),
    );
  }
}
