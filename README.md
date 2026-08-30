# nv-theme-color-adjustments

**v.1.1**

Adjust the colors of the currently displayed Emacs theme **at runtime**, without modifying the theme file or any persistent Emacs settings.

The package is deliberately small and is intended to work with any Emacs theme whose colors are represented by ordinary face foreground/background attributes.

## Features

- `nv-lighten-theme` makes the current theme lighter immediately.
- `nv-darken-theme` makes the current theme darker immediately.
- Adjustments are cumulative and are always recomputed from the saved original colors.
- `nv-reset-theme-colors` restores the colors that were present before the first adjustment.
- Colors in `:box`, `:underline`, `:overline` and `:strike-through` are adjusted along with foregrounds and backgrounds.
- Faces created after the first adjustment, for example by lazily loaded packages, are picked up automatically.
- Switching or reloading a theme discards the saved baseline, so adjustments never carry colors from one theme into another.
- No theme file is modified.
- No Custom settings are changed.

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

Because they are cumulative, the result of a call depends on what came before. To set the total directly instead, ignoring any earlier adjustment, use `nv-set-theme-adjustment`:

```elisp
(nv-set-theme-adjustment -100)  ; everything black
(nv-set-theme-adjustment 40)    ; 40% lighter than the original, whatever is current
(nv-set-theme-adjustment 0)     ; original colors
```

This is usually what you want when you have been experimenting. `(nv-darken-theme 100)` does not mean "go to black"; it means "subtract 100 from the current adjustment", which lands on black only if you started at 0. The current total is shown in the echo area after every call and is held in `nv-theme-color-adjustment`.

The total is clamped to the range -100 to 100, since -100 already reaches black and 100 already reaches white. This keeps the counter from drifting to a value that no longer describes what is on screen.

To restore the original colors:

```elisp
(nv-reset-theme-colors)
```

The same functions are interactive, so they can also be invoked with `M-x`:

- `M-x nv-lighten-theme`
- `M-x nv-darken-theme`
- `M-x nv-set-theme-adjustment`
- `M-x nv-reset-theme-colors`

## How it works

Before the first adjustment, the package records the current explicit foreground and background colors of all faces. Every subsequent adjustment is recalculated from those recorded originals rather than from the already modified colors, so repeated adjustments do not accumulate rounding errors.

For example:

```elisp
(nv-darken-theme 4)
(nv-lighten-theme 2)
```

produces a net adjustment of 2% darker relative to the saved original colors.

Each color is converted to HSL, its lightness component is changed, and the result is converted back. Only faces that set a color explicitly are touched; faces that inherit their colors follow along on their own.

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

This matters in practice. Leuven-derived themes, for example, draw the mode line and header line with a colored `:box`, and mark spelling and syntax errors with a colored wavy `:underline`:

```elisp
(mode-line     (:box (:line-width 1 :color "#1A2F54") :foreground "#85CEEB" :background "#335EA8"))
(flycheck-error (:underline (:color "#FE251E" :style wave) :weight bold :background "#FFE1E1"))
```

If only `:foreground` and `:background` were adjusted, those borders and underlines would keep their original colors while everything around them changed. At `(nv-darken-theme 100)` they would be the only colored things left on an otherwise black frame.

Values that carry no color of their own are left alone, so `:underline t` continues to follow the foreground and `:box 2` keeps its line width.

### What a percentage means

By default, a percentage is an **absolute** shift of HSL lightness: `4` always means "add 0.04 to lightness", regardless of the starting color. This behaves consistently on light and dark themes, and it can lighten pure black.

If you prefer the older behaviour, set:

```elisp
(setq nv-theme-color-adjustment-method 'relative)
```

With `relative`, lightness is scaled rather than shifted, the same way `color-lighten-name` works: the new lightness is `L + L × percent/100`. Be aware that this makes the same percentage mean very different things at different points in the range, and that it cannot lighten pure black at all:

| Color     | Lightness | `+4` absolute | `+4` relative |
|-----------|-----------|---------------|---------------|
| `#000000` | 0.000     | `#0a0a0a`     | `#000000`     |
| `#1c1e1f` | 0.116     | `#252829`     | `#1d1f20`     |
| `#fdf6e3` | 0.941     | `#fefcf6`     | `#fefbf4`     |

### Baseline handling

The recorded originals are the baseline for all subsequent adjustments. The baseline is rebuilt automatically when the set of enabled themes changes, and it is discarded by `nv-reset-theme-colors`. This means you can load a theme, adjust it, load a different theme, and adjust again without the first theme's colors leaking into the second.

Faces that did not exist when the baseline was taken are added to it the first time they are seen, so packages that define their faces lazily are adjusted on the next call rather than being left out.

## Terminal frames

Hexadecimal color specifications are parsed directly rather than through `color-values`, so the package behaves correctly on text terminals, where `color-values` would otherwise snap colors to the terminal palette before they were adjusted. Named colors on a terminal are still subject to that quantisation.

## Important limitations

Only face attributes are adjusted. A few colors live in frame parameters rather than in faces, notably `mouse-color`, `border-color` and the scroll bar colors, and those are left untouched. The cursor is a face and is adjusted normally.

The adjustments affect the **currently displayed faces**, not the theme definition itself. Consequently, if you reload or switch themes, Emacs replaces the adjusted face attributes. This is intentional: the package provides temporary runtime adjustments rather than a way to edit theme files.

## use-package

`use-package` does not install packages by itself; it configures packages that are already available to Emacs. This package can be used with `use-package` in several ways.

### Local copy

If the package directory is, for example,
`~/src/nv-theme-color-adjustments/`, use:

```elisp
(use-package nv-theme-color-adjustments
  :load-path "~/src/nv-theme-color-adjustments/"
  :demand t)
```

### With straight.el

If the package is in a Git repository, a `straight.el` recipe can be combined directly with `use-package`:

```elisp
(use-package nv-theme-color-adjustments
  :straight (nv-theme-color-adjustments
             :type git
             :host github
             :repo "nivaca/nv-theme-color-adjustments")
  :demand t)
```

Replace the host and repository with your own. For a host that straight.el does not know about, give the full clone URL instead:

```elisp
:straight (nv-theme-color-adjustments
           :type git
           :repo "https://codeberg.org/nivaca/nv-theme-color-adjustments.git")
```

## Example configuration

For example, if you load your `nivaca-leuven` theme and then want to make it slightly darker:

```elisp
(use-package nv-theme-color-adjustments
  :straight (nv-theme-color-adjustments
             :type git
             :host github
             :repo "nivaca/nv-theme-color-adjustments")
  :demand t)

(load-theme 'nivaca-leuven t)
(nv-darken-theme 4)
```

You can also bind keys for quick adjustments:

```elisp
(use-package nv-theme-color-adjustments
  :straight (nv-theme-color-adjustments
             :type git
             :host github
             :repo "nivaca/nv-theme-color-adjustments")
  :demand t
  :bind (("C-c t +" . nv-lighten-theme)
         ("C-c t -" . nv-darken-theme)
         ("C-c t 0" . nv-reset-theme-colors)))
```

## Updating an installed copy

`straight.el` builds into `~/.emacs.d/straight/build/`, and Emacs loads the built copy. Editing the source repository does not change what is loaded. After changing the package, run:

    M-x straight-rebuild-package RET nv-theme-color-adjustments RET

and restart Emacs. To confirm which file is actually in memory:

```elisp
(locate-library "nv-theme-color-adjustments")
```

## Commands and variables

| Name | Type | Description |
|------|------|-------------|
| `nv-lighten-theme` | command | Lighten the current theme by a percentage. |
| `nv-darken-theme` | command | Darken the current theme by a percentage. |
| `nv-set-theme-adjustment` | command | Set the total adjustment, replacing rather than adding. |
| `nv-reset-theme-colors` | command | Restore the saved original colors and clear the baseline. |
| `nv-theme-color-adjustment-method` | option | `absolute` (default) or `relative`. |
| `nv-theme-color-adjustment` | variable | Current cumulative adjustment, in percent. |
| `nv-theme-color-adjustment-limit` | constant | Bound on the cumulative adjustment (100). |
| `nv-theme-original-colors` | variable | Saved baseline, as `(FACE . ((ATTRIBUTE . VALUE) ...))` entries. |

## Package structure

A minimal repository can contain:

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

After that, `straight.el` can install it directly from the repository.

## Requirements

This is version v.1.1. It requires Emacs 26.1 or later, and has no dependencies beyond the built-in `color` library.

## License

Copyright (C) 2026 Nicolas Vaughan

This package is licensed under the GNU General Public License, version 3 or any later version. See [COPYING](COPYING).

The complete license text is provided in `COPYING`.
