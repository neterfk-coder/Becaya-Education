/* ============================================================
   actualizacion.dart — avisar de versiones nuevas
   ------------------------------------------------------------
   Usa el mecanismo de actualización de Google Play (In-App
   Updates): la app pregunta a Play si hay una versión más nueva
   y, si la hay, la descarga en segundo plano sin sacar al
   usuario de lo que estaba haciendo.

   SOLO FUNCIONA instalada desde Play. En un APK puesto a mano,
   en un emulador o durante el desarrollo, la consulta falla —y
   eso NO es un error que haya que mostrar. Se ignora en
   silencio: un aviso de "no se pudo comprobar actualizaciones"
   cada vez que abres la app en desarrollo es ruido puro.

   Se usa la modalidad FLEXIBLE y no la inmediata: la inmediata
   bloquea la app con una pantalla a pantalla completa hasta que
   termina, y eso solo se justifica cuando la versión vieja está
   rota o es insegura. Para un catálogo de becas, obligar a
   actualizar antes de poder mirar una fecha es desproporcionado.
   ============================================================ */

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// En qué punto está la actualización.
enum EstadoActualizacion {
  /// Aún no se ha preguntado, o no se pudo (fuera de Play).
  desconocido,

  /// Play dice que esta es la última versión.
  alDia,

  /// Hay una versión nueva y se puede descargar.
  disponible,

  /// Descargando en segundo plano. La app sigue usable.
  descargando,

  /// Descargada. Falta reiniciar para aplicarla.
  listaParaInstalar,

  /// Algo falló al descargar. Se puede reintentar.
  fallo,
}

class Actualizacion extends ChangeNotifier {
  EstadoActualizacion _estado = EstadoActualizacion.desconocido;
  bool _comprobando = false;

  EstadoActualizacion get estado => _estado;
  bool get comprobando => _comprobando;

  /// true cuando hay algo que enseñarle al usuario.
  bool get hayNovedad =>
      _estado == EstadoActualizacion.disponible ||
      _estado == EstadoActualizacion.descargando ||
      _estado == EstadoActualizacion.listaParaInstalar;

  /// Pregunta a Play si hay versión nueva.
  ///
  /// [silencioso] distingue la comprobación automática del arranque de
  /// la que pide el usuario desde Ajustes: la primera no debe dejar
  /// rastro si falla, la segunda sí, porque alguien está esperando una
  /// respuesta.
  Future<void> comprobar({bool silencioso = true}) async {
    if (_comprobando) return;

    _comprobando = true;
    if (!silencioso) notifyListeners();

    try {
      final info = await InAppUpdate.checkForUpdate();

      _estado = info.updateAvailability == UpdateAvailability.updateAvailable
          ? EstadoActualizacion.disponible
          : EstadoActualizacion.alDia;
    } catch (error) {
      // Lo normal fuera de Play. No se toca el estado en la
      // comprobación automática para no enseñar un fallo que al usuario
      // no le dice nada ni puede resolver.
      debugPrint('No se pudo comprobar actualizaciones: $error');
      if (!silencioso) _estado = EstadoActualizacion.fallo;
    } finally {
      _comprobando = false;
      notifyListeners();
    }
  }

  /// Descarga la versión nueva en segundo plano. La app sigue usable
  /// mientras tanto; al terminar hay que llamar a [instalar].
  Future<void> descargar() async {
    _fijar(EstadoActualizacion.descargando);
    try {
      await InAppUpdate.startFlexibleUpdate();
      _fijar(EstadoActualizacion.listaParaInstalar);
    } catch (error) {
      // Incluye el caso de que el usuario cancele el diálogo de Play,
      // que no es un fallo: simplemente decidió que ahora no.
      debugPrint('Actualización no completada: $error');
      _fijar(EstadoActualizacion.disponible);
    }
  }

  /// Reinicia la app con la versión nueva ya descargada.
  Future<void> instalar() async {
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } catch (error) {
      debugPrint('No se pudo instalar la actualización: $error');
      _fijar(EstadoActualizacion.fallo);
    }
  }

  void _fijar(EstadoActualizacion nuevo) {
    if (_estado == nuevo) return;
    _estado = nuevo;
    notifyListeners();
  }
}
