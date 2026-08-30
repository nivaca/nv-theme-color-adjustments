# nv-theme-color-adjustments

Adjust the colors of the currently displayed Emacs theme **at runtime**, without modifying the theme file or any persistent Emacs settings.

The package is deliberately small and is intended to work with any Emacs theme whose colors are represented by ordinary face foreground/background attributes.

## Features

- `nv-lighten-theme` makes the current theme lighter immediately.
- `nv-darken-theme` makes the current theme darker immediately.
- Adjustments are cumulative.
- `nv-reset-theme-colors` restores the colors that were present before the first adjustment.
- No theme file is modified.
- No Custom settings are changed.
- Reloading a theme naturally replaces the temporary runtime adjustments.

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

To restore the original colors:

```elisp
(nv-reset-theme-colors)
```

The same functions are interactive, so they can also be invoked with `M-x`:

- `M-x nv-lighten-theme`
- `M-x nv-darken-theme`
- `M-x nv-reset-theme-colors`

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
  :straight (:type git
             :repo "https://github.com/nivaca/nv-theme-color-adjustments.git")
  :demand t)
```

Replace the repository URL with your actual GitHub, Codeberg, or other Git repository.

If the repository is public and you use a conventional straight recipe, you can also use the shorter form appropriate to your repository host.

## Example configuration

For example, if you load your `nivaca-leuven` theme and then want to make it slightly darker:

```elisp
(use-package nv-theme-color-adjustments
  :straight (:type git
             :repo "https://github.com/nivaca/nv-theme-color-adjustments.git")
  :demand t)

(load-theme 'nivaca-leuven t)
(nv-darken-theme 4)
```

You can also bind keys for quick adjustments:

```elisp
(use-package nv-theme-color-adjustments
  :straight (:type git
             :repo "https://github.com/nivaca/nv-theme-color-adjustments.git")
  :demand t
  :bind (("C-c t +" . nv-lighten-theme)
         ("C-c t -" . nv-darken-theme)
         ("C-c t 0" . nv-reset-theme-colors)))
```

## How it works

Before the first adjustment, the package records the current explicit foreground and background colors of all faces. Each subsequent adjustment is calculated from those original colors, using Emacs's `color-lighten-name` function.

This means that repeated adjustments do not accumulate rounding errors from repeatedly changing an already modified color.

For example:

```elisp
(nv-darken-theme 4)
(nv-lighten-theme 2)
```

produces a net adjustment of 2% darker relative to the saved original colors.

## Important limitation

The adjustments affect the **currently displayed faces**, not the theme definition itself. Consequently, if you reload or switch themes, Emacs may replace the adjusted face attributes. This is intentional: the package provides temporary runtime adjustments rather than a way to edit theme files.

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

## License

Copyright (C) 2026 Nicolas Vaughan

This package is licensed under the GNU General Public License, version 3 or any later version. See [COPYING](COPYING).

The complete license text is provided in `COPYING`.
