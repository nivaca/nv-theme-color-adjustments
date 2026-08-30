# nv-theme-color-adjustments

**v.1.1**

Adjust the colors of the currently displayed Emacs theme **at runtime**, without modifying the theme file or any persistent Emacs settings.

The package is deliberately small and is intended to work with any Emacs theme whose colors are represented by ordinary face attributes.

## Features

- `nv-lighten-theme` makes the current theme lighter immediately.
- `nv-darken-theme` makes the current theme darker immediately.
- `nv-set-theme-adjustment` sets the total adjustment directly.
- `nv-reset-theme-colors` restores the colors that were present before the first adjustment.
- Adjustments are cumulative and are always recomputed from the saved original colors.
- The default method reproduces, exactly, what you get by darkening a theme file's color literals by hand.
- Colors in `:box`, `:underline`, `:overline` and `:strike-through` are adjusted along with foregrounds and backgrounds.
- Faces created after the first adjustment, for example by lazily loaded packages, are picked up automatically.
- Switching or reloading a theme discards the saved baseline, so adjustments never carry colors from one theme into another.
- No theme file is modified, and no Custom settings are changed.

## Usage

Load the package:

```elisp
(require 'nv-theme-color-adjustments)
```

Then adjust the currently displayed theme:

```elisp
(nv-lighten-theme 4)   ; 4% lighter
(nv-darken-theme 4)    ; 4% darker
(nv-lighten-theme -4)  ; 4% darker
```

The adjustments are cumulative. For example:

```elisp
(nv-lighten-theme 4)
(nv-darken-theme 2)
```

leaves the theme 2% lighter than its original state.

Because they are cumulative, the result of a call depends on what came before. To set the total directly, ignoring any earlier adjustment, use `nv-set-theme-adjustment`:

```elisp
(nv-set-theme-adjustment -100)  ; everything black
(nv-set-theme-adjustment -8)    ; 8% darker than the original
(nv-set-theme-adjustment 0)     ; original colors
```

This is usually what you want after experimenting. Note that `(nv-darken-theme 100)` does not mean "go to black"; it means "subtract 100 from the current adjustment", which reaches black only if you started at 0. The running total is shown in the echo area after every call and is held in `nv-theme-color-adjustment`.

The total is clamped to the range -100 to 100, since -100 already reaches black and 100 already reaches white. This keeps the counter from drifting to a value that no longer describes what is on screen.

To restore the original colors:

```elisp
(nv-reset-theme-colors)
```

All four functions are interactive, so they can also be invoked with `M-x`:

- `M-x nv-lighten-theme`
- `M-x nv-darken-theme`
- `M-x nv-set-theme-adjustment`
- `M-x nv-reset-theme-colors`

## How it works

Before the first adjustment, the package records the current explicit colors of all faces. Every subsequent adjustment is recalculated from those recorded originals rather than from the already modified colors, so repeated adjustments do not accumulate rounding errors.

For example:

```elisp
(nv-darken-theme 4)
(nv-lighten-theme 2)
```

produces a net adjustment of 2% darker relative to the saved original colors.

Only faces that set a color explicitly are touched; faces that inherit their colors follow along on their own.

### What a percentage means

Three methods are available through `nv-theme-color-adjustment-method`.

**`scale`** (the default) multiplies each RGB channel. Darkening by 8 multiplies every channel by 0.92:

```
#335EA8  ->  #2F569B      51*0.92 = 47    94*0.92 = 86    168*0.92 = 155
```

Lightening is the mirror operation, moving each channel that fraction of the remaining distance to full intensity. These are what image editors call shade and tint. Use this method if you want the result to look like a theme file that someone darkened by hand, because it is exactly what that operation does.

**`absolute`** shifts HSL lightness by `PERCENT/100`, so `4` always means "add 0.04 to lightness". It preserves hue and saturation, and unlike `scale` it can lighten pure black.

**`relative`** scales HSL lightness by the percentage, the way `color-lighten-name` does. It is included for compatibility. Be aware that it has almost no effect on dark colors and cannot lighten pure black at all.

| Color     | `-8` scale | `-8` absolute | `-8` relative |
|-----------|------------|---------------|---------------|
| `#335EA8` | `#2f569b`  | `#294c89`     | `#2f569b`     |
| `#EEC900` | `#dbb900`  | `#c5a700`     | `#dbb900`     |
| `#FFFFFF` | `#ebebeb`  | `#ebebeb`     | `#ebebeb`     |
| `#000000` | `#000000`  | `#000000`     | `#000000`     |

Results are rounded rather than truncated. `color-rgb-to-hex` formats its arguments with `%x`, which truncates and loses up to one unit per channel, so the package does its own conversion.

### Which attributes are adjusted

A face can carry a color in more places than its foreground and background. All of the following are adjusted:

| Attribute | Forms recognised |
|-----------|------------------|
| `:foreground` | a color |
| `:background` | a color |
| `:distant-foreground` | a color |
| `:underline` | a color, or a plist with a `:color` member |
| `:overline` | a color, or a plist with a `:color` member |
| `:strike-through` | a color, or a plist with a `:color` member |
| `:box` | a color, or a plist with a `:color` member |

This matters in practice. Leuven-derived themes draw the mode line and header line with a colored `:box`, and mark spelling and syntax errors with a colored wavy `:underline`:

```elisp
(mode-line      (:box (:line-width 1 :color "#1A2F54") :foreground "#85CEEB" :background "#335EA8"))
(flycheck-error (:underline (:color "#FE251E" :style wave) :weight bold :background "#FFE1E1"))
```

If only `:foreground` and `:background` were adjusted, those borders and underlines would keep their original colors while everything around them changed.

Values that carry no color of their own are left alone, so `:underline t` continues to follow the foreground and `:box 2` keeps its line width.

### Baseline handling

The recorded originals are the baseline for all subsequent adjustments. The baseline is rebuilt automatically when the set of enabled themes changes, and it is discarded by `nv-reset-theme-colors`. This means you can load a theme, adjust it, load a different theme, and adjust again without the first theme's colors leaking into the second.

Faces that did not exist when the baseline was taken are added to it the first time they are seen, so packages that define their faces lazily are adjusted on the next call rather than being left out.

## Terminal frames

Hexadecimal color specifications are parsed directly rather than through `color-values`, so the package behaves correctly on text terminals, where `color-values` would otherwise snap colors to the terminal palette before they were adjusted. Named colors on a terminal are still subject to that quantisation.

## Important limitations

Only face attributes are adjusted. A few colors live in frame parameters rather than in faces, notably `mouse-color`, `border-color` and the scroll bar colors, and those are left untouched. The cursor is a face and is adjusted normally.

The adjustments affect the **currently displayed faces**, not the theme definition itself. If you reload or switch themes, Emacs replaces the adjusted face attributes. This is intentional: the package provides temporary runtime adjustments rather than a way to edit theme files.

## use-package

`use-package` does not install packages by itself; it configures packages that are already available to Emacs.

### Local copy

If the package directory is, for example, `~/src/nv-theme-color-adjustments/`, use:

```elisp
(use-package nv-theme-color-adjustments
  :load-path "~/src/nv-theme-color-adjustments/"
  :demand t)
```

This loads the file directly, with no build step in between, which is the most convenient arrangement while you are still changing the package.

### With straight.el

```elisp
(use-package nv-theme-color-adjustments
  :straight (nv-theme-color-adjustments
             :type git
             :host github
             :repo "nivaca/nv-theme-color-adjustments")
  :demand t)
```

For a host that straight.el does not know about, give the full clone URL instead:

```elisp
:straight (nv-theme-color-adjustments
           :type git
           :repo "https://codeberg.org/nivaca/nv-theme-color-adjustments.git")
```

## Updating an installed copy

`straight.el` clones into `~/.emacs.d/straight/repos/` and builds into `~/.emacs.d/straight/build/`. Emacs loads the built copy, so editing a file anywhere else has no effect. After changing the package:

```sh
cp nv-theme-color-adjustments.el ~/.emacs.d/straight/repos/nv-theme-color-adjustments/
```

then run

    M-x straight-rebuild-package RET nv-theme-color-adjustments RET

and restart Emacs, since a rebuild writes a new `.elc` but does not reload the running session. To confirm which file is actually in memory:

```elisp
(locate-library "nv-theme-color-adjustments")
```

To try a change without rebuilding, `M-x load-file` on the new `.el` redefines the functions in the running session.

## Example configuration

To load a theme and then darken it by 8%, which is the adjustment that reproduces a hand-darkened Leuven:

```elisp
(use-package nv-theme-color-adjustments
  :load-path "~/src/nv-theme-color-adjustments/"
  :demand t)

(load-theme 'leuven t)
(nv-darken-theme 8)
```

You can also bind keys for quick adjustments:

```elisp
(use-package nv-theme-color-adjustments
  :load-path "~/src/nv-theme-color-adjustments/"
  :demand t
  :bind (("C-c t +" . nv-lighten-theme)
         ("C-c t -" . nv-darken-theme)
         ("C-c t =" . nv-set-theme-adjustment)
         ("C-c t 0" . nv-reset-theme-colors)))
```

On `emacs --daemon` there is no graphical frame while your init file runs, so faces read as `unspecified` and nothing is captured. Defer the call until a frame exists:

```elisp
(add-hook 'server-after-make-frame-hook
          (lambda () (nv-set-theme-adjustment -8)))
```

## Commands and variables

| Name | Type | Description |
|------|------|-------------|
| `nv-lighten-theme` | command | Lighten the current theme by a percentage. |
| `nv-darken-theme` | command | Darken the current theme by a percentage. |
| `nv-set-theme-adjustment` | command | Set the total adjustment, replacing rather than adding. |
| `nv-reset-theme-colors` | command | Restore the saved original colors and clear the baseline. |
| `nv-theme-color-adjustment-method` | option | `scale` (default), `absolute`, or `relative`. |
| `nv-theme-color-adjustment` | variable | Current cumulative adjustment, in percent. |
| `nv-theme-color-adjustment-limit` | constant | Bound on the cumulative adjustment (100). |
| `nv-theme-original-colors` | variable | Saved baseline, as `(FACE . ((ATTRIBUTE . VALUE) ...))` entries. |

## Package structure

```text
nv-theme-color-adjustments/
├── nv-theme-color-adjustments.el
├── README.md
└── COPYING
```

`COPYING` contains the GNU General Public License version 3.

## Creating the Git repository

From the package directory:

```sh
git init
git add nv-theme-color-adjustments.el README.md COPYING
git commit -m "Initial release"
```

Then create an empty repository on your preferred Git hosting service and add it as the remote:

```sh
git remote add origin https://github.com/nivaca/nv-theme-color-adjustments.git
git branch -M main
git push -u origin main
```

## Requirements

This is version v.1.1. It requires Emacs 26.1 or later, and has no dependencies beyond the built-in `color` library.

## License

Copyright (C) 2026 Nicolas Vaughan

This package is licensed under the GNU General Public License, version 3 or any later version. See [COPYING](COPYING).
