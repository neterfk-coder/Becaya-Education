/* ============================================================
   sincronizacion.dart — las guardadas, entre dispositivos
   ------------------------------------------------------------
   Une dos cosas que funcionan solas: Guardadas (el teléfono) y
   Sesion (la cuenta). Si no hay cuenta, esto no hace nada y la
   app se comporta exactamente igual que antes.

   LA REGLA: local primero, nube después. Guardar escribe en el
   teléfono al instante y responde al toque; subirlo a la nube es
   un esfuerzo aparte que puede fallar sin que el usuario lo note
   ni pierda nada.

   QUÉ PASA AL DISCREPAR: se unen, no se reemplaza. Si marcaste
   una beca en el teléfono y otra en la tablet, acabas con las
   dos. La alternativa —que gane la última escritura— borraría
   guardadas silenciosamente, y enterarte de que perdiste una
   beca cuando ya cerró es el peor resultado posible de esta app.

   El precio, dicho claro: desmarcar algo en un dispositivo no lo
   desmarca en el otro si ese otro aún no sincronizó; puede
   reaparecer. Es un intercambio deliberado — reaparecer molesta,
   desaparecer hace daño.
   ============================================================ */

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'guardadas.dart';
import 'sesion.dart';

/// Qué está pasando con la nube, para poder decirlo en pantalla.
enum EstadoSync { inactivo, sincronizando, alDia, fallo }

class Sincronizador extends ChangeNotifier {
  Sincronizador({required this.guardadas, required this.sesion}) {
    sesion.addListener(_alCambiarSesion);
    guardadas.addListener(_alCambiarGuardadas);
  }

  final Guardadas guardadas;
  final Sesion sesion;

  EstadoSync _estado = EstadoSync.inactivo;
  DateTime? _ultimaVez;
  Timer? _pendiente;
  String? _uidAnterior;

  EstadoSync get estado => _estado;
  DateTime? get ultimaVez => _ultimaVez;

  /// Subir en cada toque sería una escritura por cada marcador. Se
  /// agrupan: quien marca cinco becas seguidas genera una sola subida.
  static const _espera = Duration(milliseconds: 900);

  @override
  void dispose() {
    _pendiente?.cancel();
    sesion.removeListener(_alCambiarSesion);
    guardadas.removeListener(_alCambiarGuardadas);
    super.dispose();
  }

  void _alCambiarSesion() {
    final uid = sesion.uid;
    if (uid == _uidAnterior) return;
    _uidAnterior = uid;

    if (uid == null) {
      // Se cerró sesión. No se sube nada más, pero lo que ya está en
      // el teléfono se queda: son las guardadas de quien lo usa.
      _pendiente?.cancel();
      _fijar(EstadoSync.inactivo);
      return;
    }

    unawaited(_fusionarAlEntrar(uid));
  }

  void _alCambiarGuardadas() {
    if (!sesion.dentro || sesion.uid == null) return;
    _pendiente?.cancel();
    _pendiente = Timer(_espera, () => unawaited(_subir(sesion.uid!)));
  }

  /// Al iniciar sesión: baja lo de la cuenta, lo une con lo del
  /// teléfono, y sube la unión. Nadie pierde nada en el proceso.
  Future<void> _fusionarAlEntrar(String uid) async {
    _fijar(EstadoSync.sincronizando);
    try {
      final doc = await _documento(uid).get();
      final datos = doc.data();

      if (datos != null) {
        for (final coleccion in Coleccion.values) {
          await guardadas.fusionar(coleccion, _leerLista(datos, coleccion));
        }
      }

      await _subir(uid, avisar: false);
      _ultimaVez = DateTime.now();
      _fijar(EstadoSync.alDia);
    } catch (error) {
      debugPrint('No se pudo sincronizar al entrar: $error');
      _fijar(EstadoSync.fallo);
    }
  }

  Future<void> _subir(String uid, {bool avisar = true}) async {
    if (avisar) _fijar(EstadoSync.sincronizando);
    try {
      await _documento(uid).set(
        {
          for (final coleccion in Coleccion.values)
            coleccion.name: guardadas.de(coleccion).toList()..sort(),
          'actualizado': FieldValue.serverTimestamp(),
        },
        // merge OBLIGATORIO: el documento del usuario también guarda su
        // nombre y su foto. Sin esto, cada vez que alguien marcara una
        // beca se llevaría por delante su perfil entero.
        SetOptions(merge: true),
      );
      _ultimaVez = DateTime.now();
      if (avisar) _fijar(EstadoSync.alDia);
    } catch (error) {
      // Un fallo al subir no le quita nada al usuario: lo suyo sigue
      // guardado en el teléfono y se reintenta al próximo cambio.
      debugPrint('No se pudo subir las guardadas: $error');
      if (avisar) _fijar(EstadoSync.fallo);
    }
  }

  /// Borra de la nube todo lo asociado a la cuenta.
  ///
  /// Se llama al eliminar la cuenta, ANTES de borrar el usuario de
  /// Firebase Auth: las reglas de seguridad exigen estar autenticado
  /// para escribir, así que después ya no habría forma de hacerlo y el
  /// documento quedaría huérfano para siempre.
  ///
  /// Cancela la subida pendiente: sin eso, el temporizador podría
  /// recrear el documento justo después de borrarlo.
  Future<void> borrarTodoDeLaNube(String uid) async {
    _pendiente?.cancel();
    await _documento(uid).delete();
    _ultimaVez = null;
    _fijar(EstadoSync.inactivo);
  }

  /// Un documento por usuario, con dos listas de ids dentro. Son unas
  /// decenas de textos: no hace falta una subcolección ni paginar.
  DocumentReference<Map<String, dynamic>> _documento(String uid) =>
      FirebaseFirestore.instance.collection('usuarios').doc(uid);

  /// Lo que llega de la nube puede haberlo escrito otra versión de la
  /// app, así que se filtra a texto antes de creerse nada.
  Iterable<String> _leerLista(Map<String, dynamic> datos, Coleccion coleccion) {
    final valor = datos[coleccion.name];
    if (valor is! List) return const [];
    return valor.whereType<String>();
  }

  void _fijar(EstadoSync nuevo) {
    if (_estado == nuevo) return;
    _estado = nuevo;
    notifyListeners();
  }
}
