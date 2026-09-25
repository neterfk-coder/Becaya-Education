/* ============================================================
   paleta.dart — los colores de becaya
   ------------------------------------------------------------
   Los mismos valores de assets/css/styles.css. Si cambias la
   marca en la web, cámbiala aquí: la app y el sitio se abren
   desde el mismo enlace y tienen que parecer lo mismo.
   ============================================================ */

import 'package:flutter/material.dart';

abstract final class Paleta {
  /* Morados — color de marca y de la sección de becas */
  static const morado900 = Color(0xFF2E1065);
  static const morado700 = Color(0xFF5B21B6);
  static const morado500 = Color(0xFF7C3AED);
  static const morado200 = Color(0xFFDDD3FB);
  static const morado100 = Color(0xFFEDE9FE);
  static const morado50 = Color(0xFFF7F4FF);

  /* Neutros */
  static const negro = Color(0xFF0A0A0A);

  /// Texto largo. Un negro puro cansa en párrafos de varias líneas;
  /// este es el `--tinta` que la web usa para el cuerpo.
  static const tinta = Color(0xFF141317);

  static const gris = Color(0xFF56535F);
  static const grisClaro = Color(0xFF8A8794);
  static const borde = Color(0xFFE8E3F5);
  static const blanco = Color(0xFFFFFFFF);

  /* Señal de urgencia. Uso mínimo: solo cuando el cierre es inminente.
     Si todo grita, nada grita. */
  static const urgente = Color(0xFFB4530A);
  static const urgenteSuave = Color(0xFFFFF4E8);

  /* Verde de voluntariados. Color propio para que esa sección se lea
     como "otra cosa" y nunca se confunda con el catálogo de becas. */
  static const verde700 = Color(0xFF0F766E);
  static const verde600 = Color(0xFF0D9488);
  static const verde100 = Color(0xFFCCFBF1);
  static const verde50 = Color(0xFFF0FDFA);
}

/// Cada sección tiene su acento. Se pasa hacia abajo en vez de leer una
/// variable global, para que una tarjeta de voluntariado nunca pueda
/// pintarse de morado por descuido.
enum Acento {
  becas(Paleta.morado500, Paleta.morado700, Paleta.morado100, Paleta.morado50),
  voluntariados(Paleta.verde600, Paleta.verde700, Paleta.verde100, Paleta.verde50);

  const Acento(this.color, this.oscuro, this.suave, this.fondo);

  final Color color;
  final Color oscuro;
  final Color suave;
  final Color fondo;
}
