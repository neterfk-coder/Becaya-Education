/* ============================================================
   perfil.dart — nombre y foto del usuario
   ------------------------------------------------------------
   Solo existe con cuenta iniciada. Sin cuenta no hay perfil que
   personalizar, y eso no es una carencia: la app entera funciona
   igual sin él.

   DÓNDE VIVE LA FOTO, y por qué no en Firebase Storage:

   Storage sería lo canónico, pero desde finales de 2024 los
   proyectos nuevos necesitan plan de pago para activarlo. Aquí
   la foto se guarda comprimida dentro del propio documento del
   usuario en Firestore, que es gratuito y sincroniza igual.

   El precio de esa decisión: un documento de Firestore no puede
   pasar de 1 MiB, así que la imagen se reduce a 256 px y se
   comprime antes de guardarla — unos 20-40 KB. Es de sobra para
   un avatar, pero si algún día hicieran falta imágenes grandes,
   ahí sí tocaría mover esto a Storage.
   ============================================================ */

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Lado máximo del avatar, en píxeles. Se muestra a 96 como mucho; 256
/// deja margen para pantallas densas sin inflar el documento.
const _ladoAvatar = 256.0;

/// Calidad JPEG al comprimir. 82 es el punto donde la pérdida deja de
/// notarse a este tamaño.
const _calidad = 82;

/// Tope de seguridad. Si tras comprimir sigue pasando de aquí, se
/// rechaza antes de intentar subirla: vale más un error claro que un
/// fallo de Firestore por documento demasiado grande.
const _maxBytes = 180 * 1024;

class Perfil extends ChangeNotifier {
  Perfil({ImagePicker? selector}) : _selector = selector ?? ImagePicker();

  final ImagePicker _selector;

  String? _nombre;
  Uint8List? _foto;
  bool _cargando = false;
  bool _guardando = false;
  String? _error;

  /// Nombre elegido por el usuario dentro de la app. Puede diferir del
  /// que venga de Google: quien entró con su cuenta del colegio quizá
  /// no quiera ver ahí su nombre completo.
  String? get nombre => _nombre;

  Uint8List? get foto => _foto;
  bool get cargando => _cargando;
  bool get guardando => _guardando;
  String? get error => _error;

  /// Lee el perfil guardado en la nube.
  Future<void> cargar(String uid) async {
    _cargando = true;
    notifyListeners();

    try {
      final doc = await _documento(uid).get();
      final datos = doc.data();
      if (datos != null) {
        _nombre = datos['nombre'] as String?;
        final foto = datos['foto'];
        _foto = foto is String && foto.isNotEmpty ? base64Decode(foto) : null;
      }
    } catch (e) {
      debugPrint('No se pudo cargar el perfil: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  /// Vacía lo cargado. Se llama al cerrar sesión, para que el perfil de
  /// una persona no se quede en pantalla cuando entra otra.
  void limpiar() {
    _nombre = null;
    _foto = null;
    _error = null;
    notifyListeners();
  }

  Future<bool> guardarNombre(String uid, String nuevo) async {
    final limpio = nuevo.trim();
    if (limpio.isEmpty) {
      _fijarError('Escribe un nombre.');
      return false;
    }
    if (limpio.length > 40) {
      _fijarError('Usa 40 caracteres o menos.');
      return false;
    }

    return _guardar(() async {
      await _documento(uid).set({'nombre': limpio}, SetOptions(merge: true));
      // También en Firebase Auth, para que displayName no se quede
      // desfasado respecto a lo que el usuario ve en la app.
      await FirebaseAuth.instance.currentUser?.updateDisplayName(limpio);
      _nombre = limpio;
    });
  }

  /// Abre la galería, comprime lo elegido y lo guarda.
  ///
  /// Devuelve false si el usuario cerró el selector sin elegir — eso no
  /// es un error y no se le muestra nada.
  Future<bool> elegirFoto(String uid) async {
    try {
      final elegida = await _selector.pickImage(
        source: ImageSource.gallery,
        // Redimensionar aquí, y no después, evita cargar en memoria una
        // foto de 12 megapíxeles solo para encogerla.
        maxWidth: _ladoAvatar,
        maxHeight: _ladoAvatar,
        imageQuality: _calidad,
      );
      if (elegida == null) return false;

      final bytes = await elegida.readAsBytes();
      if (bytes.lengthInBytes > _maxBytes) {
        _fijarError('Esa imagen es demasiado pesada. Prueba con otra.');
        return false;
      }

      return _guardar(() async {
        await _documento(uid).set(
          {'foto': base64Encode(bytes)},
          SetOptions(merge: true),
        );
        _foto = bytes;
      });
    } catch (e) {
      debugPrint('No se pudo elegir la foto: $e');
      _fijarError('No se pudo abrir la galería.');
      return false;
    }
  }

  Future<bool> quitarFoto(String uid) => _guardar(() async {
        await _documento(uid).set(
          {'foto': FieldValue.delete()},
          SetOptions(merge: true),
        );
        _foto = null;
      });

  /* ------------------------------------------------------------
     Andamiaje común.
     ------------------------------------------------------------ */

  Future<bool> _guardar(Future<void> Function() accion) async {
    _guardando = true;
    _error = null;
    notifyListeners();

    try {
      await accion();
      return true;
    } catch (e) {
      debugPrint('No se pudo guardar el perfil: $e');
      _error = 'No se pudo guardar. Revisa tu conexión.';
      return false;
    } finally {
      _guardando = false;
      notifyListeners();
    }
  }

  void _fijarError(String mensaje) {
    _error = mensaje;
    notifyListeners();
  }

  /// El mismo documento donde viven las guardadas: un usuario, un
  /// documento. Se escribe siempre con merge para no pisar los campos
  /// que gestiona el sincronizador.
  DocumentReference<Map<String, dynamic>> _documento(String uid) =>
      FirebaseFirestore.instance.collection('usuarios').doc(uid);
}
