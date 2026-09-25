/* ============================================================
   bienvenida.dart — si ya se eligió cómo entrar
   ------------------------------------------------------------
   La pantalla de bienvenida se muestra UNA VEZ, en el primer
   arranque. Después no vuelve a aparecer, se haya elegido cuenta
   o invitado.

   Eso no es un detalle cosmético: una pantalla de acceso que
   sale cada vez que abres la app es una barrera, aunque tenga
   botón de invitado. Quien viene a mirar si su beca ya abrió
   quiere ver la lista, no decidir otra vez algo que ya decidió.

   Elegir invitado no es un estado especial ni limitado: es
   exactamente como funciona la app sin cuenta. La única
   diferencia con haber iniciado sesión es que las guardadas no
   viajan a otro dispositivo.
   ============================================================ */

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _clave = 'becaya:bienvenida-vista';

class Bienvenida extends ChangeNotifier {
  bool _vista = false;
  bool _listo = false;

  /// Falso hasta leer el disco. Mientras tanto no se pinta ni la
  /// bienvenida ni el catálogo: enseñar la bienvenida medio segundo a
  /// alguien que ya la pasó se ve como un parpadeo raro.
  bool get listo => _listo;

  bool get vista => _vista;

  Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    _vista = prefs.getBool(_clave) ?? false;
    _listo = true;
    notifyListeners();
  }

  /// Se llama al elegir invitado, y también al iniciar sesión: en los
  /// dos casos el usuario ya decidió y no hay que volver a preguntar.
  Future<void> marcarVista() async {
    if (_vista) return;
    _vista = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_clave, true);
  }
}
