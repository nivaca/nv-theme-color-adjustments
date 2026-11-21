# Registro de cambios

Los cambios notables de nv-theme-color-adjustments. El proyecto no tiene
etiquetas de versión ni publicaciones, así que las entradas llevan fecha;
el código está en [GitHub](https://github.com/nivaca/nv-theme-color-adjustments)
y en [Codeberg](https://codeberg.org/nivaca/nv-theme-color-adjustments).
La cabecera del paquete le da la versión 1.1.

## 2026-08-30

Todo el trabajo hasta ahora se hizo este día, en estos pasos.

- **El método de ajuste.** `nv-theme-color-adjustment-method` decide
  cómo cambia un porcentaje un color. El predeterminado, `scale`,
  multiplica cada canal RGB (oscurecer en 8 multiplica cada canal por
  0,92), y aclarar acerca cada canal la misma fracción de la distancia
  que lo separa de la intensidad plena: el resultado es exactamente el
  de oscurecer a mano los colores del archivo de un tema. `absolute`
  desplaza la luminosidad HSL en PERCENT/100, y `relative` la escala,
  como hace `color-lighten-name`, que apenas cambia los colores oscuros
  y no puede aclarar el negro puro. Los colores se escriben como
  `#rrggbb`, redondeados, no truncados.
- `nv-set-theme-adjustment` fija el ajuste total en lugar de sumarle. El
  total se mantiene entre -100 y 100 (`nv-theme-color-adjustment-limit`),
  donde todos los colores ya son negros o blancos.
- Versión 1.1: además de los colores de primer plano y de fondo, se
  ajustan los de `:distant-foreground`, `:underline`, `:overline`,
  `:strike-through` y `:box`, también cuando vienen en una plist con
  `:color`.
- Versión 0.2.0: los colores guardados se descartan cuando se activa
  otro tema, de modo que los ajustes nunca llevan colores de un tema a
  otro, y las caras creadas después del primer ajuste, por paquetes
  cargados más tarde, se suman a ellos. `nv-reset-theme-colors` olvida
  los colores guardados después de restaurarlos. Los colores
  hexadecimales se leen directamente: en una terminal de texto,
  `color-values` los ajustaba a su paleta. Las órdenes se cargan con
  autoload; hay un grupo de personalización, la cabecera de la GPL y las
  cabeceras del paquete (Emacs 26.1 o posterior).
- Primera versión: `nv-lighten-theme`, `nv-darken-theme` y
  `nv-reset-theme-colors` cambian los colores del tema actual de Emacs
  mientras Emacs corre, sin tocar el archivo del tema ni ningún ajuste
  de Custom. Los ajustes son acumulativos y siempre se calculan de nuevo
  a partir de los colores guardados antes del primero.
