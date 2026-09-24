/* ============================================================
   cuenta.dart — iniciar sesión, que es opcional
   ------------------------------------------------------------
   Esta pantalla se abre porque el usuario la busca, nunca se le
   pone delante. No hay muro de registro: el catálogo completo
   funciona sin cuenta.

   Por eso la pantalla dice desde la primera línea para qué sirve
   la cuenta. Pedir un correo sin explicar qué se gana a cambio
   es cómo se consigue que la gente desinstale.
   ============================================================ */

import 'package:flutter/material.dart';

import '../datos/guardadas.dart';
import '../datos/sesion.dart';
import '../datos/sincronizacion.dart';
import 'paleta.dart';

class PantallaCuenta extends StatelessWidget {
  const PantallaCuenta({
    super.key,
    required this.sesion,
    required this.guardadas,
    required this.sincronizador,
  });

  final Sesion sesion;
  final Guardadas guardadas;
  final Sincronizador sincronizador;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Paleta.blanco,
      appBar: AppBar(
        backgroundColor: Paleta.blanco,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Paleta.negro,
        elevation: 0,
        title: const Text(
          'Tu cuenta',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListenableBuilder(
        listenable: sesion,
        builder: (context, _) => switch (sesion.estado) {
          EstadoSesion.arrancando => const Center(
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          EstadoSesion.noDisponible => const _SinConfigurar(),
          EstadoSesion.fuera => _Entrar(sesion: sesion),
          EstadoSesion.dentro => _Dentro(
              sesion: sesion,
              guardadas: guardadas,
              sincronizador: sincronizador,
            ),
        },
      ),
    );
  }
}

/* ------------------------------------------------------------
   Build sin Firebase configurado.
   ------------------------------------------------------------ */

class _SinConfigurar extends StatelessWidget {
  const _SinConfigurar();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 44, color: Paleta.grisClaro),
            SizedBox(height: 16),
            Text(
              'La sincronización aún no está activa',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Paleta.negro,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Tus convocatorias guardadas siguen funcionando con normalidad: '
              'están en este teléfono y no necesitan cuenta ni conexión. Lo '
              'único que falta es poder verlas también en otro dispositivo.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.55, color: Paleta.gris),
            ),
          ],
        ),
      ),
    );
  }
}

/* ------------------------------------------------------------
   Sesión iniciada.
   ------------------------------------------------------------ */

class _Dentro extends StatelessWidget {
  const _Dentro({
    required this.sesion,
    required this.guardadas,
    required this.sincronizador,
  });

  final Sesion sesion;
  final Guardadas guardadas;
  final Sincronizador sincronizador;

  @override
  Widget build(BuildContext context) {
    final correo = sesion.usuario?.email;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        Center(
          child: CircleAvatar(
            radius: 34,
            backgroundColor: Paleta.morado100,
            child: Text(
              sesion.nombreVisible.characters.first.toUpperCase(),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Paleta.morado700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          sesion.nombreVisible,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: Paleta.negro,
          ),
        ),
        if (correo != null && correo != sesion.nombreVisible) ...[
          const SizedBox(height: 3),
          Text(
            correo,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: Paleta.gris),
          ),
        ],
        const SizedBox(height: 26),
        ListenableBuilder(
          listenable: Listenable.merge([guardadas, sincronizador]),
          builder: (context, _) => _EstadoNube(
            sincronizador: sincronizador,
            cuantas: guardadas.cuantas(Coleccion.becas) +
                guardadas.cuantas(Coleccion.voluntariados),
          ),
        ),
        const SizedBox(height: 26),
        OutlinedButton.icon(
          onPressed: () async {
            final salir = await _confirmarSalida(context);
            if (salir != true) return;
            await sesion.salir();
          },
          icon: const Icon(Icons.logout, size: 18),
          label: const Text('Cerrar sesión'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Paleta.gris,
            minimumSize: const Size.fromHeight(48),
            side: const BorderSide(color: Paleta.borde),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        const SizedBox(height: 28),
        const Divider(color: Paleta.borde),
        const SizedBox(height: 8),

        // Va al final y sin destacar: es una acción irreversible que
        // nadie debería tocar por error buscando otra cosa.
        _BotonEliminar(sesion: sesion, sincronizador: sincronizador),
      ],
    );
  }

  /// Se avisa de que lo guardado se queda en el teléfono. Si no, cerrar
  /// sesión da miedo: parece que vas a perder tus becas.
  Future<bool?> _confirmarSalida(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Tus convocatorias guardadas siguen en este teléfono y las seguirás '
          'viendo. Solo dejarán de sincronizarse con tus otros dispositivos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------
   Eliminar la cuenta.

   Google Play lo exige desde 2023 para cualquier app que permita
   crear cuentas, y tiene que poder hacerse desde dentro de la app,
   no solo escribiendo un correo a soporte.
   ------------------------------------------------------------ */

class _BotonEliminar extends StatelessWidget {
  const _BotonEliminar({required this.sesion, required this.sincronizador});

  final Sesion sesion;
  final Sincronizador sincronizador;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: sesion.ocupado ? null : () => _pedirConfirmacion(context),
      icon: const Icon(Icons.delete_outline, size: 18),
      label: const Text('Eliminar mi cuenta'),
      style: TextButton.styleFrom(
        foregroundColor: Paleta.urgente,
        minimumSize: const Size.fromHeight(46),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _pedirConfirmacion(BuildContext context) async {
    final uid = sesion.uid;
    if (uid == null) return;

    final clave = await showDialog<String>(
      context: context,
      builder: (_) => _DialogoEliminar(pideClave: !sesion.entroConGoogle),
    );
    // null = canceló. Cadena vacía = confirmó con Google, sin contraseña.
    if (clave == null || !context.mounted) return;

    final listo = await sesion.eliminarCuenta(
      clave: clave,
      borrarDatos: () => sincronizador.borrarTodoDeLaNube(uid),
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          listo
              ? 'Tu cuenta y sus datos se eliminaron.'
              : sesion.ultimoError ?? 'No se pudo eliminar la cuenta.',
        ),
      ),
    );

    if (listo) Navigator.of(context).pop();
  }
}

class _DialogoEliminar extends StatefulWidget {
  const _DialogoEliminar({required this.pideClave});

  /// Con Google se reautentica reabriendo el selector de cuentas; con
  /// correo hace falta la contraseña, y se pide antes de empezar para
  /// no dejar el borrado a medias.
  final bool pideClave;

  @override
  State<_DialogoEliminar> createState() => _DialogoEliminarState();
}

class _DialogoEliminarState extends State<_DialogoEliminar> {
  final _clave = TextEditingController();

  @override
  void dispose() {
    _clave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('¿Eliminar tu cuenta?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Se borrará de forma permanente:\n'
            '· tu cuenta y tu correo\n'
            '· la copia de tus guardadas en la nube\n\n'
            'Esto no se puede deshacer.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 12),
          const Text(
            'Las convocatorias que guardaste seguirán en este teléfono. '
            'Para borrarlas también, desinstala la app.',
            style: TextStyle(fontSize: 13, height: 1.45, color: Paleta.gris),
          ),
          if (widget.pideClave) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _clave,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Confirma tu contraseña',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _clave.text),
          style: TextButton.styleFrom(foregroundColor: Paleta.urgente),
          child: const Text('Eliminar'),
        ),
      ],
    );
  }
}

class _EstadoNube extends StatelessWidget {
  const _EstadoNube({required this.sincronizador, required this.cuantas});

  final Sincronizador sincronizador;
  final int cuantas;

  @override
  Widget build(BuildContext context) {
    final (icono, texto, color) = switch (sincronizador.estado) {
      EstadoSync.sincronizando => (
          Icons.sync,
          'Sincronizando…',
          Paleta.gris,
        ),
      EstadoSync.alDia => (
          Icons.cloud_done_outlined,
          '$cuantas guardadas, sincronizadas con tu cuenta',
          Paleta.verde700,
        ),
      EstadoSync.fallo => (
          Icons.cloud_off_outlined,
          'No se pudo sincronizar. Tus guardadas están a salvo en este '
              'teléfono y se reintentará solo.',
          Paleta.urgente,
        ),
      EstadoSync.inactivo => (
          Icons.cloud_queue,
          '$cuantas guardadas en este teléfono',
          Paleta.gris,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Paleta.morado50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Paleta.morado200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(fontSize: 13.5, height: 1.45, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------
   Sin sesión: entrar o crear cuenta.
   ------------------------------------------------------------ */

class _Entrar extends StatefulWidget {
  const _Entrar({required this.sesion});

  final Sesion sesion;

  @override
  State<_Entrar> createState() => _EntrarState();
}

class _EntrarState extends State<_Entrar> {
  final _formulario = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _clave = TextEditingController();

  bool _creando = false;
  bool _verClave = false;

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  Sesion get _sesion => widget.sesion;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      children: [
        const _PorQueUnaCuenta(),
        const SizedBox(height: 22),

        _BotonGoogle(
          ocupado: _sesion.ocupado,
          onPulsar: () => _tras(_sesion.entrarConGoogle()),
        ),

        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(child: Divider(color: Paleta.borde)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'o con tu correo',
                style: TextStyle(fontSize: 12.5, color: Paleta.grisClaro),
              ),
            ),
            const Expanded(child: Divider(color: Paleta.borde)),
          ],
        ),
        const SizedBox(height: 18),

        Form(
          key: _formulario,
          child: Column(
            children: [
              TextFormField(
                controller: _correo,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: _decoracion('Correo electrónico'),
                validator: (v) {
                  final texto = (v ?? '').trim();
                  if (texto.isEmpty) return 'Escribe tu correo';
                  // Comprobación mínima: que haya algo, arroba y punto.
                  // Validar correos a fondo con una expresión regular
                  // rechaza direcciones válidas y no aporta nada: quien
                  // manda es el servidor.
                  if (!texto.contains('@') || !texto.contains('.')) {
                    return 'Ese correo no parece válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _clave,
                obscureText: !_verClave,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                decoration: _decoracion('Contraseña').copyWith(
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _verClave = !_verClave),
                    tooltip: _verClave ? 'Ocultar' : 'Mostrar',
                    icon: Icon(
                      _verClave ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                      color: Paleta.grisClaro,
                    ),
                  ),
                ),
                validator: (v) {
                  if ((v ?? '').isEmpty) return 'Escribe tu contraseña';
                  if (_creando && v!.length < 6) {
                    return 'Usa al menos 6 caracteres';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),

        if (_sesion.ultimoError != null) ...[
          const SizedBox(height: 14),
          _Error(texto: _sesion.ultimoError!),
        ],

        const SizedBox(height: 18),
        FilledButton(
          onPressed: _sesion.ocupado ? null : _enviar,
          style: FilledButton.styleFrom(
            backgroundColor: Paleta.morado500,
            foregroundColor: Paleta.blanco,
            minimumSize: const Size.fromHeight(50),
            textStyle: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _sesion.ocupado
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Paleta.blanco,
                  ),
                )
              : Text(_creando ? 'Crear cuenta' : 'Iniciar sesión'),
        ),

        const SizedBox(height: 6),
        TextButton(
          onPressed: _sesion.ocupado
              ? null
              : () => setState(() => _creando = !_creando),
          child: Text(
            _creando
                ? '¿Ya tienes cuenta? Inicia sesión'
                : '¿No tienes cuenta? Créala',
            style: const TextStyle(fontSize: 13.5, color: Paleta.morado700),
          ),
        ),

        if (!_creando)
          TextButton(
            onPressed: _sesion.ocupado ? null : _recuperar,
            child: const Text(
              'Olvidé mi contraseña',
              style: TextStyle(fontSize: 13, color: Paleta.gris),
            ),
          ),
      ],
    );
  }

  InputDecoration _decoracion(String etiqueta) => InputDecoration(
        labelText: etiqueta,
        filled: true,
        fillColor: Paleta.morado50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Paleta.borde),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Paleta.borde),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Paleta.morado500, width: 1.6),
        ),
      );

  Future<void> _enviar() async {
    if (!_formulario.currentState!.validate()) return;
    await _tras(
      _creando
          ? _sesion.crearCuenta(_correo.text, _clave.text)
          : _sesion.entrarConCorreo(_correo.text, _clave.text),
    );
  }

  Future<void> _recuperar() async {
    final correo = _correo.text.trim();
    if (correo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escribe tu correo arriba y vuelve a tocar aquí.'),
        ),
      );
      return;
    }

    final listo = await _sesion.recuperarClave(correo);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          listo
              ? 'Te enviamos un correo para restablecer la contraseña.'
              : _sesion.ultimoError ?? 'No se pudo enviar el correo.',
        ),
      ),
    );
  }

  /// Cierra la pantalla si la acción salió bien. El usuario vino a
  /// entrar, no a quedarse mirando un formulario ya resuelto.
  Future<void> _tras(Future<bool> accion) async {
    final listo = await accion;
    if (listo && mounted) Navigator.of(context).pop();
  }
}

class _PorQueUnaCuenta extends StatelessWidget {
  const _PorQueUnaCuenta();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Paleta.morado50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Paleta.morado200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.devices, size: 18, color: Paleta.morado700),
              const SizedBox(width: 8),
              const Text(
                'Para qué sirve la cuenta',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: Paleta.morado900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Solo para que tus convocatorias guardadas aparezcan también en '
            'otro teléfono o en la web, y no se pierdan si cambias de equipo.\n\n'
            'Todo lo demás funciona sin cuenta: ver el catálogo, filtrarlo y '
            'guardar convocatorias en este teléfono.',
            style: TextStyle(fontSize: 13.5, height: 1.55, color: Paleta.gris),
          ),
        ],
      ),
    );
  }
}

class _BotonGoogle extends StatelessWidget {
  const _BotonGoogle({required this.ocupado, required this.onPulsar});

  final bool ocupado;
  final VoidCallback onPulsar;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: ocupado ? null : onPulsar,
      icon: const Icon(Icons.g_mobiledata, size: 28, color: Paleta.negro),
      label: const Text('Continuar con Google'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Paleta.negro,
        minimumSize: const Size.fromHeight(50),
        side: const BorderSide(color: Paleta.borde),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Paleta.urgenteSuave,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF1D9C0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 17, color: Paleta.urgente),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 13,
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
