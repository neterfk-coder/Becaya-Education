/* ============================================================
   sesion.dart — la cuenta, que es OPCIONAL
   ------------------------------------------------------------
   Regla de esta pantalla y de todo lo que cuelga de ella:
   **nada del catálogo depende de iniciar sesión.** Ver becas,
   filtrarlas, abrirlas y guardarlas funciona sin cuenta y sin
   conexión. La cuenta añade una sola cosa: que lo guardado
   aparezca también en otro dispositivo.

   Eso no es una preferencia de diseño, es lo que hace que la app
   sea publicable: una app que obliga a registrarse para ver
   información pública es contenido restringido, y Google Play lo
   revisa con lupa.

   Si Firebase no está configurado (ver firebase_options.dart), la
   app entera sigue funcionando y esto reporta `disponible = false`.
   ============================================================ */

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_options.dart';

/// En qué estado está la cuenta.
enum EstadoSesion {
  /// Todavía no se sabe: se está arrancando Firebase.
  arrancando,

  /// Firebase no está configurado en este build. Modo solo local.
  noDisponible,

  /// Configurado, pero nadie ha iniciado sesión.
  fuera,

  /// Hay sesión activa.
  dentro,
}

class Sesion extends ChangeNotifier {
  EstadoSesion _estado = EstadoSesion.arrancando;
  User? _usuario;
  String? _ultimoError;
  bool _ocupado = false;

  EstadoSesion get estado => _estado;
  User? get usuario => _usuario;
  String? get ultimoError => _ultimoError;
  bool get ocupado => _ocupado;

  bool get disponible => _estado != EstadoSesion.noDisponible &&
      _estado != EstadoSesion.arrancando;
  bool get dentro => _estado == EstadoSesion.dentro;

  String? get uid => _usuario?.uid;

  /// Lo que se muestra en la pantalla de cuenta.
  String get nombreVisible {
    final u = _usuario;
    if (u == null) return '';
    final n = u.displayName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return u.email ?? 'Tu cuenta';
  }

  /// Arranca Firebase. Se llama una vez, al abrir la app.
  ///
  /// Un fallo aquí NO es un error de la app: significa que este build
  /// no tiene cuentas configuradas. Se registra y se sigue en local.
  Future<void> iniciar() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      FirebaseAuth.instance.authStateChanges().listen((usuario) {
        _usuario = usuario;
        _estado = usuario == null ? EstadoSesion.fuera : EstadoSesion.dentro;
        notifyListeners();
      });

      _usuario = FirebaseAuth.instance.currentUser;
      _estado = _usuario == null ? EstadoSesion.fuera : EstadoSesion.dentro;
    } catch (error) {
      debugPrint('Sesión no disponible (Firebase sin configurar): $error');
      _estado = EstadoSesion.noDisponible;
    }
    notifyListeners();
  }

  /* ------------------------------------------------------------
     Entradas
     ------------------------------------------------------------ */

  Future<bool> entrarConGoogle() => _intentar(() async {
        final cuenta = await GoogleSignIn().signIn();
        // El usuario cerró el selector de cuentas. No es un error: no
        // se le muestra nada, simplemente no pasó nada.
        if (cuenta == null) return false;

        final auth = await cuenta.authentication;
        await FirebaseAuth.instance.signInWithCredential(
          GoogleAuthProvider.credential(
            accessToken: auth.accessToken,
            idToken: auth.idToken,
          ),
        );
        return true;
      });

  Future<bool> entrarConCorreo(String correo, String clave) =>
      _intentar(() async {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: correo.trim(),
          password: clave,
        );
        return true;
      });

  Future<bool> crearCuenta(String correo, String clave) => _intentar(() async {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: correo.trim(),
          password: clave,
        );
        return true;
      });

  Future<bool> recuperarClave(String correo) => _intentar(() async {
        await FirebaseAuth.instance.sendPasswordResetEmail(
          email: correo.trim(),
        );
        return true;
      });

  Future<void> salir() async {
    // Se cierra también la sesión de Google: si no, el siguiente
    // "Entrar con Google" reusa la misma cuenta sin preguntar, y quien
    // presta el teléfono a otra persona se lleva una sorpresa.
    try {
      await GoogleSignIn().signOut();
    } catch (_) {
      // No había sesión de Google. Da igual.
    }
    await FirebaseAuth.instance.signOut();
  }

  /// Con qué método entró el usuario. La pantalla lo necesita para
  /// saber si tiene que pedir la contraseña antes de borrar la cuenta.
  String? get metodoDeAcceso {
    final proveedores = _usuario?.providerData;
    if (proveedores == null || proveedores.isEmpty) return null;
    return proveedores.first.providerId;
  }

  bool get entroConGoogle => metodoDeAcceso == 'google.com';

  /// Borra la cuenta y todo lo asociado, sin intermediarios ni esperas:
  /// el propio cliente elimina el documento de Firestore y después la
  /// cuenta de Firebase Auth.
  ///
  /// El orden importa. Primero los datos, luego la cuenta: al revés, el
  /// documento quedaría huérfano para siempre, porque las reglas de
  /// seguridad exigen estar autenticado para escribir y ya no habría
  /// sesión con la que hacerlo.
  ///
  /// Firebase exige haber iniciado sesión hace poco para borrar. Cuando
  /// no es el caso responde `requires-recent-login`, y entonces se
  /// reautentica —pidiendo la contraseña otra vez, o reabriendo el
  /// selector de Google— y se reintenta.
  Future<bool> eliminarCuenta({
    required Future<void> Function() borrarDatos,
    String? clave,
  }) =>
      _intentar(() async {
        final usuario = FirebaseAuth.instance.currentUser;
        if (usuario == null) return false;

        try {
          await borrarDatos();
          await usuario.delete();
          return true;
        } on FirebaseAuthException catch (e) {
          if (e.code != 'requires-recent-login') rethrow;

          final sigue = await _reautenticar(usuario, clave);
          if (!sigue) return false;

          await borrarDatos();
          await usuario.delete();
          return true;
        }
      });

  /// Devuelve false si el usuario canceló. Cancelar no es un error: no
  /// se le enseña nada, simplemente no se borra la cuenta.
  Future<bool> _reautenticar(User usuario, String? clave) async {
    if (metodoDeAcceso == 'google.com') {
      final cuenta = await GoogleSignIn().signIn();
      if (cuenta == null) return false;

      final auth = await cuenta.authentication;
      await usuario.reauthenticateWithCredential(
        GoogleAuthProvider.credential(
          accessToken: auth.accessToken,
          idToken: auth.idToken,
        ),
      );
      return true;
    }

    final correo = usuario.email;
    if (clave == null || clave.isEmpty || correo == null) {
      // La pantalla pide la contraseña antes de llamar aquí, así que
      // esto solo pasa si la interfaz se saltó ese paso.
      throw FirebaseAuthException(
        code: 'falta-contrasena',
        message: 'Hace falta la contraseña para confirmar el borrado.',
      );
    }

    await usuario.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: correo, password: clave),
    );
    return true;
  }

  /* ------------------------------------------------------------
     Envoltorio común: ocupado, errores y mensajes en castellano.
     ------------------------------------------------------------ */

  Future<bool> _intentar(Future<bool> Function() accion) async {
    _ocupado = true;
    _ultimoError = null;
    notifyListeners();

    try {
      return await accion();
    } on FirebaseAuthException catch (e) {
      _ultimoError = _mensaje(e);
      return false;
    } catch (e) {
      _ultimoError = 'No se pudo completar. Revisa tu conexión.';
      debugPrint('Error de sesión: $e');
      return false;
    } finally {
      _ocupado = false;
      notifyListeners();
    }
  }

  /// Los códigos de Firebase llegan en inglés y de cara al usuario no
  /// significan nada. Se traducen solo los que puede provocar él.
  String _mensaje(FirebaseAuthException e) {
    return switch (e.code) {
      'invalid-email' => 'Ese correo no tiene un formato válido.',
      'user-disabled' => 'Esta cuenta está deshabilitada.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' =>
        'Correo o contraseña incorrectos.',
      'email-already-in-use' =>
        'Ya existe una cuenta con ese correo. Inicia sesión.',
      'weak-password' => 'La contraseña debe tener al menos 6 caracteres.',
      'network-request-failed' => 'Sin conexión. Inténtalo más tarde.',
      'too-many-requests' =>
        'Demasiados intentos. Espera un momento y vuelve a probar.',
      'operation-not-allowed' =>
        'Este método de acceso no está habilitado en el proyecto.',
      'requires-recent-login' =>
        'Por seguridad, vuelve a iniciar sesión antes de borrar la cuenta.',
      'falta-contrasena' =>
        'Escribe tu contraseña para confirmar el borrado.',
      _ => 'No se pudo completar (${e.code}).',
    };
  }
}
