/* ============================================================
   bienvenida.dart — la primera pantalla, una sola vez
   ------------------------------------------------------------
   Tres caminos: Google, correo, o entrar como invitado.

   "Invitado" está a la vista y con el mismo peso visual que los
   demás, no escondido en letra pequeña al fondo. Un botón de
   invitado que hay que buscar es un muro de registro disfrazado,
   y Google Play lo trata como tal: si el contenido es público,
   obligar a registrarse para verlo es motivo de rechazo.

   Elegir invitado no recorta nada. El catálogo entero, los
   filtros y las convocatorias guardadas funcionan igual. La
   cuenta solo añade que lo guardado se vea en otro dispositivo,
   y se puede crear después desde Ajustes sin perder nada.
   ============================================================ */

import 'package:flutter/material.dart';

import '../datos/sesion.dart';
import 'paleta.dart';

class PantallaBienvenida extends StatelessWidget {
  const PantallaBienvenida({
    super.key,
    required this.sesion,
    required this.onInvitado,
    required this.onAbrirCorreo,
  });

  final Sesion sesion;

  /// Continuar sin cuenta.
  final VoidCallback onInvitado;

  /// Abrir el formulario de correo y contraseña.
  final VoidCallback onAbrirCorreo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Paleta.blanco,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: sesion,
          builder: (context, _) {
            final ocupado = sesion.ocupado;
            final hayCuentas = sesion.estado != EstadoSesion.noDisponible;

            return Column(
              children: [
                Expanded(child: _Presentacion()),

                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Column(
                    children: [
                      if (hayCuentas) ...[
                        _BotonPrincipal(
                          icono: Icons.g_mobiledata,
                          texto: 'Continuar con Google',
                          ocupado: ocupado,
                          onPulsar: () => sesion.entrarConGoogle(),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: ocupado ? null : onAbrirCorreo,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Paleta.negro,
                            minimumSize: const Size.fromHeight(52),
                            side: const BorderSide(color: Paleta.borde),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Usar mi correo'),
                        ),
                        const SizedBox(height: 4),
                      ],

                      // Mismo tamaño de área táctil que los de arriba:
                      // entrar sin cuenta es una opción de primera, no
                      // una salida de emergencia.
                      TextButton(
                        onPressed: ocupado ? null : onInvitado,
                        style: TextButton.styleFrom(
                          foregroundColor: Paleta.morado700,
                          minimumSize: const Size.fromHeight(52),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Text(
                          hayCuentas ? 'Entrar como invitado' : 'Entrar',
                        ),
                      ),

                      const SizedBox(height: 6),
                      Text(
                        hayCuentas
                            ? 'Sin cuenta funciona todo: ver convocatorias, '
                                'filtrarlas y guardarlas en este teléfono. '
                                'Puedes crear una cuenta después desde Ajustes.'
                            : 'La app funciona sin cuenta: todo el catálogo '
                                'está disponible.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: Paleta.grisClaro,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/* ------------------------------------------------------------
   La mitad de arriba: marca y qué hace la app.
   ------------------------------------------------------------ */

class _Presentacion extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Paleta.morado500, Paleta.morado700],
                ),
                borderRadius: BorderRadius.circular(88 * 0.24),
              ),
              child: const Center(
                child: Text(
                  'b',
                  style: TextStyle(
                    fontFamily: 'Arial',
                    fontSize: 58,
                    fontWeight: FontWeight.w900,
                    height: 1.08,
                    color: Paleta.blanco,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'becaya',
              style: TextStyle(
                fontFamily: 'Arial',
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.1,
                color: Paleta.morado900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Becas y voluntariados con fechas verificadas, '
              'ordenados por cuándo puedes postular.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.5, height: 1.55, color: Paleta.gris),
            ),
            const SizedBox(height: 26),
            const _Punto(
              icono: Icons.event_available_outlined,
              texto: 'Mira qué está abierto hoy y qué abre esta semana',
            ),
            const _Punto(
              icono: Icons.verified_outlined,
              texto: 'Cada fecha comprobada contra la página oficial',
            ),
            const _Punto(
              icono: Icons.wifi_off_outlined,
              texto: 'Funciona sin conexión',
            ),
          ],
        ),
      ),
    );
  }
}

class _Punto extends StatelessWidget {
  const _Punto({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icono, size: 19, color: Paleta.morado500),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: Paleta.tinta,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonPrincipal extends StatelessWidget {
  const _BotonPrincipal({
    required this.icono,
    required this.texto,
    required this.ocupado,
    required this.onPulsar,
  });

  final IconData icono;
  final String texto;
  final bool ocupado;
  final VoidCallback onPulsar;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: ocupado ? null : onPulsar,
      icon: ocupado
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Paleta.blanco,
              ),
            )
          : Icon(icono, size: 26),
      label: Text(texto),
      style: FilledButton.styleFrom(
        backgroundColor: Paleta.morado500,
        foregroundColor: Paleta.blanco,
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
