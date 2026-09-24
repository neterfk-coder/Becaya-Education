/* ============================================================
   guardadas.dart — las convocatorias que el usuario marcó
   ------------------------------------------------------------
   Dos espacios SEPARADOS, becas y voluntariados, con la misma
   regla que el resto del proyecto: no se mezclan nunca. Un id
   puede repetirse entre los dos catálogos sin que pase nada.

   Funciona SIN cuenta. Guardar algo no pide iniciar sesión ni
   conexión: se escribe en el teléfono y ya. La cuenta solo
   añade que lo guardado se vea también en otro dispositivo.

   Se guardan ids, no fichas completas. Si mañana una beca
   cambia de fechas, lo guardado sigue apuntando a la versión
   nueva — por eso docs/esquema-datos.md insiste en que los id
   no se reutilicen.
   ============================================================ */

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Las mismas claves que usa la web en localStorage. No comparten
/// almacenamiento —una es el navegador y otra el teléfono— pero
/// mantener el nombre evita tener dos vocabularios para lo mismo.
const _claveBecas = 'becaya:guardadas';
const _claveVoluntariados = 'becaya:voluntariados-guardados';

/// Qué catálogo. Existe para que sea imposible escribir un id de
/// voluntariado en la lista de becas por descuido.
enum Coleccion {
  becas(_claveBecas),
  voluntariados(_claveVoluntariados);

  const Coleccion(this.clave);
  final String clave;
}

class Guardadas extends ChangeNotifier {
  final Map<Coleccion, Set<String>> _ids = {
    Coleccion.becas: <String>{},
    Coleccion.voluntariados: <String>{},
  };

  bool _listo = false;

  /// Falso hasta que se leyó el disco. La interfaz lo usa para no
  /// pintar corazones vacíos durante medio segundo y luego llenarlos.
  bool get listo => _listo;

  Set<String> de(Coleccion coleccion) => Set.unmodifiable(_ids[coleccion]!);

  int cuantas(Coleccion coleccion) => _ids[coleccion]!.length;

  bool tiene(Coleccion coleccion, String id) => _ids[coleccion]!.contains(id);

  /// Se llama una vez al arrancar.
  Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    for (final coleccion in Coleccion.values) {
      _ids[coleccion] = _leer(prefs, coleccion.clave);
    }
    _listo = true;
    notifyListeners();
  }

  /// Marca o desmarca. Devuelve el estado nuevo, para que la interfaz
  /// pueda decir "Guardada" o "Quitada" sin volver a consultar.
  Future<bool> alternar(Coleccion coleccion, String id) async {
    final conjunto = _ids[coleccion]!;
    final ahoraEsta = !conjunto.contains(id);

    if (ahoraEsta) {
      conjunto.add(id);
    } else {
      conjunto.remove(id);
    }

    // Se avisa a la interfaz ANTES de escribir en disco: el corazón
    // tiene que responder al toque, no esperar al almacenamiento.
    notifyListeners();
    await _escribir(coleccion);
    return ahoraEsta;
  }

  /// Une lo que llega de otro dispositivo con lo que ya había aquí.
  ///
  /// La unión es deliberada: ante la duda, no se pierde nada de lo que
  /// el usuario marcó. Desmarcar en un dispositivo y que reaparezca es
  /// molesto; perder una beca guardada y enterarte cuando ya cerró, no.
  Future<void> fusionar(Coleccion coleccion, Iterable<String> remotos) async {
    final antes = _ids[coleccion]!.length;
    _ids[coleccion]!.addAll(remotos);
    if (_ids[coleccion]!.length == antes) return;

    notifyListeners();
    await _escribir(coleccion);
  }

  /// Vacía el espacio local. Se usa al cerrar sesión, para no dejar en
  /// el teléfono lo que otra persona guardó con su cuenta.
  Future<void> limpiar() async {
    for (final coleccion in Coleccion.values) {
      _ids[coleccion]!.clear();
      await _escribir(coleccion);
    }
    notifyListeners();
  }

  Set<String> _leer(SharedPreferences prefs, String clave) {
    final crudo = prefs.getString(clave);
    if (crudo == null) return <String>{};
    try {
      final lista = jsonDecode(crudo);
      if (lista is! List) return <String>{};
      // Se filtra a texto porque el contenido guardado lo puede haber
      // tocado otra versión de la app, o el propio usuario.
      return lista.whereType<String>().toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> _escribir(Coleccion coleccion) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(coleccion.clave, jsonEncode(_ids[coleccion]!.toList()));
  }
}
