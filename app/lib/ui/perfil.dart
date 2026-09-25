/* ============================================================
   perfil.dart — ver y cambiar tus datos
   ------------------------------------------------------------
   Nombre, foto y contraseña. Solo tiene sentido con sesión
   iniciada, así que se llega aquí desde la pantalla de cuenta.

   La contraseña solo aparece para quien entró con correo. Quien
   entró con Google no tiene contraseña en becaya —la gestiona
   Google— y enseñarle un campo que no puede usar solo genera la
   duda de si tiene dos contraseñas distintas.
   ============================================================ */

import 'package:flutter/material.dart';

import '../datos/perfil.dart';
import '../datos/sesion.dart';
import 'paleta.dart';

class PantallaPerfil extends StatefulWidget {
  const PantallaPerfil({
    super.key,
    required this.sesion,
    required this.perfil,
  });

  final Sesion sesion;
  final Perfil perfil;

  @override
  State<PantallaPerfil> createState() => _PantallaPerfilState();
}

class _PantallaPerfilState extends State<PantallaPerfil> {
  late final TextEditingController _nombre = TextEditingController(
    text: widget.perfil.nombre ?? widget.sesion.usuario?.displayName ?? '',
  );

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Sesion get _sesion => widget.sesion;
  Perfil get _perfil => widget.perfil;

  @override
  Widget build(BuildContext context) {
    final uid = _sesion.uid;

    return Scaffold(
      backgroundColor: Paleta.blanco,
      appBar: AppBar(
        backgroundColor: Paleta.blanco,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Paleta.negro,
        elevation: 0,
        title: const Text(
          'Tu perfil',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      body: uid == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Inicia sesión para tener perfil.',
                  style: TextStyle(fontSize: 14, color: Paleta.gris),
                ),
              ),
            )
          : ListenableBuilder(
              listenable: _perfil,
              builder: (context, _) => ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                children: [
                  _Avatar(
                    perfil: _perfil,
                    sesion: _sesion,
                    onCambiar: () => _elegirFoto(uid),
                    onQuitar: _perfil.foto == null
                        ? null
                        : () => _perfil.quitarFoto(uid),
                  ),

                  const SizedBox(height: 30),
                  const _Etiqueta('Nombre en la app'),
                  TextField(
                    controller: _nombre,
                    maxLength: 40,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      hintText: 'Cómo quieres que te llamemos',
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _guardarNombre(uid),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed:
                        _perfil.guardando ? null : () => _guardarNombre(uid),
                    style: FilledButton.styleFrom(
                      backgroundColor: Paleta.morado500,
                      foregroundColor: Paleta.blanco,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _perfil.guardando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Paleta.blanco,
                            ),
                          )
                        : const Text('Guardar nombre'),
                  ),

                  if (_perfil.error != null) ...[
                    const SizedBox(height: 12),
                    _Error(texto: _perfil.error!),
                  ],

                  const SizedBox(height: 30),
                  const _Etiqueta('Correo'),
                  _SoloLectura(
                    texto: _sesion.usuario?.email ?? 'Sin correo',
                    nota: _sesion.entroConGoogle
                        ? 'Lo gestiona tu cuenta de Google'
                        : 'El correo de una cuenta no se puede cambiar',
                  ),

                  const SizedBox(height: 30),
                  const _Etiqueta('Contraseña'),
                  if (_sesion.entroConGoogle)
                    const _SoloLectura(
                      texto: 'Entras con Google',
                      nota: 'Tu contraseña la gestiona Google, no becaya',
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: _abrirCambioClave,
                      icon: const Icon(Icons.lock_outline, size: 18),
                      label: const Text('Cambiar contraseña'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Paleta.negro,
                        minimumSize: const Size.fromHeight(46),
                        side: const BorderSide(color: Paleta.borde),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Future<void> _guardarNombre(String uid) async {
    final listo = await _perfil.guardarNombre(uid, _nombre.text);
    if (!listo || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nombre actualizado.')),
    );
  }

  Future<void> _elegirFoto(String uid) async {
    final listo = await _perfil.elegirFoto(uid);
    if (!listo || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Foto actualizada.')),
    );
  }

  Future<void> _abrirCambioClave() async {
    final cambiada = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoClave(sesion: _sesion),
    );
    if (cambiada != true || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contraseña actualizada.')),
    );
  }
}

/* ------------------------------------------------------------
   Foto de perfil.
   ------------------------------------------------------------ */

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.perfil,
    required this.sesion,
    required this.onCambiar,
    this.onQuitar,
  });

  final Perfil perfil;
  final Sesion sesion;
  final VoidCallback onCambiar;
  final VoidCallback? onQuitar;

  @override
  Widget build(BuildContext context) {
    final foto = perfil.foto;
    final inicial = (perfil.nombre?.trim().isNotEmpty ?? false)
        ? perfil.nombre!.trim()
        : sesion.nombreVisible;

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: Paleta.morado100,
              backgroundImage: foto == null ? null : MemoryImage(foto),
              child: foto != null
                  ? null
                  : Text(
                      inicial.isEmpty
                          ? '?'
                          : inicial.characters.first.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        color: Paleta.morado700,
                      ),
                    ),
            ),
            Material(
              color: Paleta.morado500,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: perfil.guardando ? null : onCambiar,
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    Icons.photo_camera_outlined,
                    size: 18,
                    color: Paleta.blanco,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: perfil.guardando ? null : onCambiar,
          child: const Text(
            'Elegir de la galería',
            style: TextStyle(fontSize: 13.5, color: Paleta.morado700),
          ),
        ),
        if (onQuitar != null)
          TextButton(
            onPressed: perfil.guardando ? null : onQuitar,
            child: const Text(
              'Quitar foto',
              style: TextStyle(fontSize: 12.5, color: Paleta.gris),
            ),
          ),
      ],
    );
  }
}

/* ------------------------------------------------------------
   Cambio de contraseña.
   ------------------------------------------------------------ */

class _DialogoClave extends StatefulWidget {
  const _DialogoClave({required this.sesion});

  final Sesion sesion;

  @override
  State<_DialogoClave> createState() => _DialogoClaveState();
}

class _DialogoClaveState extends State<_DialogoClave> {
  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  String? _aviso;

  @override
  void dispose() {
    _actual.dispose();
    _nueva.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cambiar contraseña'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _actual,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Contraseña actual',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nueva,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Contraseña nueva',
              helperText: 'Mínimo 6 caracteres',
              border: OutlineInputBorder(),
            ),
          ),
          if (_aviso != null) ...[
            const SizedBox(height: 12),
            _Error(texto: _aviso!),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: widget.sesion.ocupado ? null : _enviar,
          child: const Text('Cambiar'),
        ),
      ],
    );
  }

  Future<void> _enviar() async {
    if (_nueva.text.length < 6) {
      setState(() => _aviso = 'La contraseña nueva necesita 6 caracteres.');
      return;
    }

    final listo = await widget.sesion.cambiarClave(
      actual: _actual.text,
      nueva: _nueva.text,
    );

    if (!mounted) return;

    if (listo) {
      Navigator.pop(context, true);
    } else {
      setState(() => _aviso = widget.sesion.ultimoError);
    }
  }
}

/* ------------------------------------------------------------
   Piezas.
   ------------------------------------------------------------ */

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texto.toUpperCase(),
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
          color: Paleta.grisClaro,
        ),
      ),
    );
  }
}

class _SoloLectura extends StatelessWidget {
  const _SoloLectura({required this.texto, required this.nota});

  final String texto;
  final String nota;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Paleta.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            texto,
            style: const TextStyle(fontSize: 14.5, color: Paleta.negro),
          ),
          const SizedBox(height: 3),
          Text(
            nota,
            style: const TextStyle(fontSize: 12, color: Paleta.grisClaro),
          ),
        ],
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
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Paleta.urgenteSuave,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFF1D9C0)),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 12.5,
          height: 1.45,
          color: Paleta.urgente,
        ),
      ),
    );
  }
}
