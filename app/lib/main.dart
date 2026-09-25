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

import 'datos/actualizacion.dart';
import 'datos/bienvenida.dart';
import 'datos/guardadas.dart';
import 'datos/perfil.dart';
import 'datos/repositorio.dart';
import 'datos/sesion.dart';
import 'datos/sincronizacion.dart';
import 'modelo/convocatoria.dart';
import 'motor/estado.dart';
import 'ui/ajustes.dart';
import 'ui/aviso_actualizacion.dart';
import 'ui/bienvenida.dart';
import 'ui/cuenta.dart';
import 'ui/detalle.dart';
import 'ui/intro.dart';
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
      // La pantalla de inicio se monta ya, debajo de la intro: así el
      // catálogo se descarga mientras se ve la marca, en vez de
      // empezar a cargar cuando la intro termina.
      home: const Arranque(hijo: PantallaInicio()),
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
  final _guardadas = Guardadas();
  final _sesion = Sesion();
  final _actualizacion = Actualizacion();
  final _bienvenida = Bienvenida();
  final _perfil = Perfil();
  late final _sincronizador = Sincronizador(
    guardadas: _guardadas,
    sesion: _sesion,
  );

  Catalogo? _catalogo;
  Object? _error;
  bool _cargando = true;

  /// Filtro de "solo lo guardado". Es por pestaña en la cabeza del
  /// usuario, pero una sola bandera basta: al cambiar de pestaña se
  /// mantiene, que es lo que se espera de un filtro.
  bool _soloGuardadas = false;

  @override
  void initState() {
    super.initState();
    _cargar();
    // El catálogo viene de la red; las guardadas, del disco. Van por
    // separado para que lo guardado aparezca aunque no haya señal.
    _guardadas.cargar();
    // Arrancar Firebase puede fallar —y falla mientras no esté
    // configurado— sin que eso afecte a nada de lo anterior.
    _sesion.iniciar();
    // Fuera de Google Play esto falla siempre; por eso va en silencio.
    _actualizacion.comprobar();
    _bienvenida.cargar();
    // Quien inicia sesión ya eligió cómo entrar: no tiene sentido
    // volver a preguntárselo en el siguiente arranque.
    _sesion.addListener(_alCambiarSesion);
  }

  /// El uid de la última sesión vista, para distinguir un cambio real
  /// de persona de una simple notificación repetida.
  String? _uidAnterior;

  void _alCambiarSesion() {
    if (_sesion.dentro) _bienvenida.marcarVista();

    final uid = _sesion.uid;
    if (uid == _uidAnterior) return;
    _uidAnterior = uid;

    if (uid == null) {
      // Al cerrar sesión se vacía: el perfil de una persona no puede
      // quedarse en pantalla cuando entra otra en el mismo teléfono.
      _perfil.limpiar();
    } else {
      _perfil.cargar(uid);
    }
  }

  @override
  void dispose() {
    _sesion.removeListener(_alCambiarSesion);
    _sincronizador.dispose();
    _actualizacion.dispose();
    _bienvenida.dispose();
    _perfil.dispose();
    _sesion.dispose();
    _guardadas.dispose();
    super.dispose();
  }

  void _abrirCuenta() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaCuenta(
          sesion: _sesion,
          guardadas: _guardadas,
          sincronizador: _sincronizador,
          perfil: _perfil,
        ),
      ),
    );
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

  void _abrirDetalle(Ficha ficha, Acento acento, Coleccion coleccion) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaDetalle(
          ficha: ficha,
          acento: acento,
          guardadas: _guardadas,
          coleccion: coleccion,
        ),
      ),
    );
  }

  /// Aplica el filtro de guardadas. El orden y la agrupación ya vienen
  /// hechos del motor: aquí solo se quita lo que no está marcado.
  List<Ficha> _filtrar(List<Ficha> fichas, Coleccion coleccion) {
    if (!_soloGuardadas) return fichas;
    return fichas.where((f) => _guardadas.tiene(coleccion, f.item.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _bienvenida,
      builder: (context, _) {
        // Mientras se lee el disco no se pinta nada: enseñar la
        // bienvenida medio segundo a quien ya la pasó se ve como un
        // parpadeo. La intro de marca sigue encima, así que el usuario
        // no ve un hueco.
        if (!_bienvenida.listo) return const Scaffold();

        if (!_bienvenida.vista) {
          return PantallaBienvenida(
            sesion: _sesion,
            onInvitado: _bienvenida.marcarVista,
            onAbrirCorreo: _abrirCuenta,
          );
        }

        return _catalogoCompleto(context);
      },
    );
  }

  Widget _catalogoCompleto(BuildContext context) {
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
          actions: [
            ListenableBuilder(
              listenable: _guardadas,
              builder: (context, _) => _BotonFiltroGuardadas(
                activo: _soloGuardadas,
                cuantas: _guardadas.cuantas(Coleccion.becas) +
                    _guardadas.cuantas(Coleccion.voluntariados),
                onPulsar: () =>
                    setState(() => _soloGuardadas = !_soloGuardadas),
              ),
            ),
            ListenableBuilder(
              listenable: _sesion,
              builder: (context, _) => IconButton(
                onPressed: _abrirCuenta,
                tooltip: _sesion.dentro ? 'Tu cuenta' : 'Iniciar sesión',
                icon: Icon(
                  _sesion.dentro
                      ? Icons.account_circle
                      : Icons.account_circle_outlined,
                  color: _sesion.dentro ? Paleta.morado500 : Paleta.gris,
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PantallaAjustes(
                    sesion: _sesion,
                    guardadas: _guardadas,
                    sincronizador: _sincronizador,
                    actualizacion: _actualizacion,
                    perfil: _perfil,
                  ),
                ),
              ),
              tooltip: 'Ajustes',
              icon: const Icon(Icons.more_vert, color: Paleta.gris),
            ),
          ],
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
          (_, final c?, _) => ListenableBuilder(
              listenable: _guardadas,
              builder: (context, _) => TabBarView(
                children: [
                  ListaConvocatorias(
                    fichas: _filtrar(aFichas(c.becas), Coleccion.becas),
                    acento: Acento.becas,
                    aviso: _avisos(c),
                    onRefrescar: _cargar,
                    guardadas: _guardadas,
                    coleccion: Coleccion.becas,
                    vacioTitulo: _soloGuardadas
                        ? 'No has guardado ninguna beca'
                        : 'Todavía no hay nada publicado',
                    vacioDetalle: _soloGuardadas
                        ? 'Toca el marcador de una convocatoria para tenerla '
                            'a mano. Se guarda en tu teléfono, sin cuenta ni '
                            'conexión.'
                        : 'Un catálogo vacío es preferible a fechas sin '
                            'verificar. En cuanto haya una convocatoria '
                            'confirmada, aparecerá aquí.',
                    onTocar: (f) =>
                        _abrirDetalle(f, Acento.becas, Coleccion.becas),
                  ),
                  ListaConvocatorias(
                    fichas: _filtrar(
                        aFichas(c.voluntariados), Coleccion.voluntariados),
                    acento: Acento.voluntariados,
                    aviso: _avisos(c),
                    onRefrescar: _cargar,
                    guardadas: _guardadas,
                    coleccion: Coleccion.voluntariados,
                    vacioTitulo: _soloGuardadas
                        ? 'No has guardado ningún voluntariado'
                        : 'Aún no hay voluntariados publicados',
                    vacioDetalle: _soloGuardadas
                        ? 'Toca el marcador de un voluntariado para tenerlo '
                            'a mano.'
                        : 'No existe una fuente oficial única de voluntariados '
                            'como la de Pronabec, así que este catálogo se '
                            'carga a mano y solo con convocatorias confirmadas.',
                    onTocar: (f) => _abrirDetalle(
                        f, Acento.voluntariados, Coleccion.voluntariados),
                  ),
                ],
              ),
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
      // Va primero: si hay versión nueva, es lo más accionable de todo
      // lo que puede aparecer aquí. Se pinta sola cuando no hay nada.
      AvisoActualizacion(actualizacion: _actualizacion),
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

    // Siempre hay al menos el aviso de actualización, que se encoge a
    // cero cuando no hay novedad.
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

/// Alterna entre el catálogo completo y solo lo guardado.
///
/// Lleva el contador encima porque, sin él, el filtro parece roto
/// cuando no hay nada marcado: se toca, no cambia nada visible, y no
/// queda claro si falló o si de verdad está vacío.
class _BotonFiltroGuardadas extends StatelessWidget {
  const _BotonFiltroGuardadas({
    required this.activo,
    required this.cuantas,
    required this.onPulsar,
  });

  final bool activo;
  final int cuantas;
  final VoidCallback onPulsar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: activo,
      label: activo
          ? 'Mostrando solo guardadas. Volver al catálogo completo'
          : 'Ver solo guardadas ($cuantas)',
      child: Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            onPressed: onPulsar,
            tooltip: activo ? 'Ver todo el catálogo' : 'Ver solo guardadas',
            icon: Icon(
              activo ? Icons.bookmark : Icons.bookmark_border,
              color: activo ? Paleta.morado500 : Paleta.gris,
            ),
          ),
          if (cuantas > 0 && !activo)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                constraints: const BoxConstraints(minWidth: 16),
                decoration: BoxDecoration(
                  color: Paleta.morado500,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  cuantas > 99 ? '99+' : '$cuantas',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: Paleta.blanco,
                  ),
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
