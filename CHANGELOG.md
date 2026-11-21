# Changelog

All notable changes to nv-theme-color-adjustments. The project has no
version tags and no published releases, so the entries are dated; the
code is on [GitHub](https://github.com/nivaca/nv-theme-color-adjustments)
and [Codeberg](https://codeberg.org/nivaca/nv-theme-color-adjustments).
The package header gives its version as 1.1.

## 2026-08-30

All the work so far was done on this day, in these steps.

- **The adjustment method.** `nv-theme-color-adjustment-method` chooses
  how a percentage changes a color. The default, `scale`, multiplies each
  RGB channel (darkening by 8 multiplies every channel by 0.92), and
  lightening moves each channel the same fraction of the way to full
  intensity: this gives exactly what darkening a theme file's colors by
  hand gives. `absolute` shifts HSL lightness by PERCENT/100, and
  `relative` scales it, as `color-lighten-name` does, which hardly
  changes dark colors and cannot lighten pure black. Colors are written
  as `#rrggbb` with rounding, not truncation.
- `nv-set-theme-adjustment` sets the total adjustment instead of adding
  to it. The total is kept between -100 and 100
  (`nv-theme-color-adjustment-limit`), where every color is already black
  or white.
- Version 1.1: besides foregrounds and backgrounds, the colors of
  `:distant-foreground`, `:underline`, `:overline`, `:strike-through` and
  `:box` are adjusted, also when they are given as a plist with
  `:color`.
- Version 0.2.0: the saved colors are discarded when another theme is
  enabled, so adjustments never carry colors from one theme into another,
  and faces created after the first adjustment, by packages loaded later,
  are added to them. `nv-reset-theme-colors` forgets the saved colors
  after restoring them. Hexadecimal colors are read directly: on a
  text terminal, `color-values` snapped them to its palette. The
  commands are autoloaded; a customization group, the GPL header and the
  package headers (Emacs 26.1 or later).
- First version: `nv-lighten-theme`, `nv-darken-theme` and
  `nv-reset-theme-colors` change the colors of the current Emacs theme
  while Emacs runs, without changing the theme file or any Custom
  setting. Adjustments are cumulative and always computed again from the
  colors saved before the first one.
