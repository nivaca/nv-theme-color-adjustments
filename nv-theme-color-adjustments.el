;;; nv-theme-color-adjustments.el --- Change theme colors while running -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Nicolas Vaughan

;; Author: Nicolas Vaughan
;; Maintainer: Nicolas Vaughan
;; URL: https://github.com/nivaca/nv-theme-color-adjustments
;; Version: 1.1
;; Package-Requires: ((emacs "26.1"))
;; Keywords: faces, themes

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.


;;; Commentary:

;; nv-theme-color-adjustments v.1.1
;;
;; Runtime theme color adjustment.
;;
;;   (nv-lighten-theme 4)      ; make current theme 4% lighter
;;   (nv-darken-theme 4)       ; make current theme 4% darker
;;   (nv-lighten-theme -4)     ; make current theme 4% darker
;;   (nv-reset-theme-colors)   ; restore colors from before the first adjustment
;;
;; Adjustments are cumulative and are always recomputed from the saved
;; original colors, so they do not accumulate rounding errors.

;;; Code:

(require 'color)
(require 'pcase)

(defgroup nv-theme-color-adjustments nil
  "Runtime lightness adjustments for the current theme."
  :group 'faces
  :prefix "nv-theme-")

(defcustom nv-theme-color-adjustment-method 'scale
  "How a percentage is converted into a color change.

`scale' multiplies each RGB channel, so darkening by 8 multiplies every
channel by 0.92.  Lightening is the mirror operation, moving each
channel the given fraction of the way to full intensity.  This is what
image editors call shade and tint, and it is what you get by darkening
a theme file by hand.

`absolute' shifts HSL lightness by PERCENT/100 in absolute terms, so 4
always means \"+0.04 lightness\".

`relative' scales HSL lightness by PERCENT, as `color-lighten-name'
does.  It has almost no effect on dark colors and cannot lighten pure
black at all."
  :type '(choice (const :tag "Multiply RGB channels" scale)
                 (const :tag "Absolute lightness shift" absolute)
                 (const :tag "Relative to current lightness" relative))
  :group 'nv-theme-color-adjustments)

(defvar nv-theme-original-colors nil
  "Original face colors saved before the first runtime adjustment.
Each element has the form (FACE FOREGROUND BACKGROUND).")

(defconst nv-theme-color-adjustment-limit 100
  "Largest adjustment, in percent, that has any effect.
At 100 every color reaches white, and at -100 every color reaches
black, so the cumulative adjustment is clamped to this range.  Without
the clamp the counter could drift far past the point where it still
described what was on screen.")

(defvar nv-theme-color-adjustment 0
  "Current cumulative runtime adjustment, in percent.
Positive values mean lighter; negative values mean darker.
See `nv-set-theme-adjustment' to set this directly.")

(defvar nv-theme--baseline-themes nil
  "Value of `custom-enabled-themes' when the baseline colors were saved.")


;;; Color helpers

(defun nv-theme--color-to-rgb (color)
  "Return COLOR as a list of floats, or nil if COLOR is not a color.

Hexadecimal specifications are parsed directly rather than through
`color-name-to-rgb', because on a text terminal `color-values' snaps
colors to the terminal palette, which would corrupt them."
  (when (stringp color)
    (or (and (string-match
              "\\`#\\([[:xdigit:]]+\\)\\'" color)
             (let* ((digits (match-string 1 color))
                    (n (/ (length digits) 3)))
               (when (and (memq n '(1 2 3 4))
                          (zerop (% (length digits) 3)))
                 (let ((maxval (float (1- (expt 16 n)))))
                   (list (/ (string-to-number (substring digits 0 n) 16) maxval)
                         (/ (string-to-number (substring digits n (* 2 n)) 16) maxval)
                         (/ (string-to-number (substring digits (* 2 n)) 16) maxval))))))
        (and (not (string-prefix-p "unspecified" color))
             (ignore-errors (color-name-to-rgb color))))))

(defun nv-theme--color-attribute-p (value)
  "Return non-nil if VALUE is a usable explicit color."
  (and (nv-theme--color-to-rgb value) t))

(defun nv-theme--scale-rgb (rgb amount)
  "Scale RGB by AMOUNT percent.

A negative AMOUNT multiplies every channel by 1+AMOUNT/100, so -8 gives
the familiar \"92% of each channel\" darkening.  A positive AMOUNT is the
mirror of that, moving each channel AMOUNT percent of the remaining
distance to full intensity."
  (let ((factor (/ amount 100.0)))
    (mapcar (lambda (channel)
              (color-clamp
               (if (>= amount 0)
                   (+ channel (* (- 1.0 channel) factor))
                 (* channel (+ 1.0 factor)))))
            rgb)))

(defun nv-theme--shift-hsl (rgb amount)
  "Shift the HSL lightness of RGB by AMOUNT percent."
  (let* ((hsl (apply #'color-rgb-to-hsl rgb))
         (h (nth 0 hsl))
         (s (nth 1 hsl))
         (l (nth 2 hsl)))
    (color-hsl-to-rgb
     h s (color-clamp
          (if (eq nv-theme-color-adjustment-method 'relative)
              (+ l (* l (/ amount 100.0)))
            (+ l (/ amount 100.0)))))))

(defun nv-theme--rgb-to-hex (rgb)
  "Return RGB, a list of floats, as a \"#rrggbb\" string.

`color-rgb-to-hex' is not used here because it formats its arguments
with %x, which truncates rather than rounds, losing up to one unit per
channel."
  (apply #'format "#%02x%02x%02x"
         (mapcar (lambda (channel) (round (* 255 (color-clamp channel))))
                 rgb)))

(defun nv-theme--adjust-color (color amount)
  "Adjust COLOR by AMOUNT percent.
Positive AMOUNT lightens; negative AMOUNT darkens.
Return COLOR unchanged if it cannot be parsed."
  (let ((rgb (nv-theme--color-to-rgb color)))
    (if (null rgb)
        color
      (nv-theme--rgb-to-hex
       (if (eq nv-theme-color-adjustment-method 'scale)
           (nv-theme--scale-rgb rgb amount)
         (nv-theme--shift-hsl rgb amount))))))

;;; Attribute traversal

(defconst nv-theme--color-attributes
  '(:foreground :background :distant-foreground
    :underline :overline :strike-through :box)
  "Face attributes that can carry a color.

`:foreground', `:background' and `:distant-foreground' hold a color
directly.  `:underline', `:overline', `:strike-through' and `:box' may
hold a color string, or a plist with a `:color' member, or a value such
as t that carries no color of its own.")

(defun nv-theme--map-color (value fn)
  "Return VALUE with every color inside it replaced by (FN COLOR).

Return nil if VALUE contains no color, which is the case for
`unspecified', for t, and for a `:box' given only as a line width."
  (cond
   ((nv-theme--color-attribute-p value)
    (funcall fn value))
   ((and (consp value) (keywordp (car value)))
    (let ((color (plist-get value :color)))
      (when (nv-theme--color-attribute-p color)
        (plist-put (copy-sequence value) :color (funcall fn color)))))
   (t nil)))


;;; Baseline management

(defun nv-theme--stale-baseline-p ()
  "Return non-nil if the saved baseline no longer matches the enabled themes."
  (and nv-theme-original-colors
       (not (equal nv-theme--baseline-themes custom-enabled-themes))))

(defun nv-theme--face-colors (face)
  "Return an alist of FACE's explicit color-bearing attributes."
  (delq nil
        (mapcar (lambda (attr)
                  (let ((value (face-attribute face attr nil nil)))
                    (when (nv-theme--map-color value #'identity)
                      (cons attr value))))
                nv-theme--color-attributes)))

(defun nv-theme--save-original-colors ()
  "Save the current explicit colors of every face.

The baseline is discarded and rebuilt when the set of enabled themes
has changed.  Faces that were created after the baseline was taken are
added to it the first time they are seen, so that packages loaded
lazily are adjusted too."
  (when (nv-theme--stale-baseline-p)
    (setq nv-theme-original-colors nil
          nv-theme-color-adjustment 0))
  (unless nv-theme-original-colors
    (setq nv-theme--baseline-themes (copy-sequence custom-enabled-themes)))
  (dolist (face (face-list))
    (unless (assq face nv-theme-original-colors)
      (push (cons face (nv-theme--face-colors face))
            nv-theme-original-colors))))

(defun nv-theme--apply-adjustment ()
  "Apply `nv-theme-color-adjustment' to all recorded faces."
  (pcase-dolist (`(,face . ,attributes) nv-theme-original-colors)
    (pcase-dolist (`(,attr . ,value) attributes)
      (set-face-attribute
       face nil attr
       (nv-theme--map-color
        value (lambda (color)
                (nv-theme--adjust-color color nv-theme-color-adjustment)))))))


;;; Commands

(defun nv-theme--set-adjustment (percent)
  "Display the theme at a total adjustment of PERCENT and report it."
  (nv-theme--save-original-colors)
  (setq nv-theme-color-adjustment
        (max (- nv-theme-color-adjustment-limit)
             (min nv-theme-color-adjustment-limit percent)))
  (nv-theme--apply-adjustment)
  (message "Theme brightness adjustment: %+g%%" nv-theme-color-adjustment))

;;;###autoload
(defun nv-set-theme-adjustment (percent)
  "Set the total theme adjustment to PERCENT.

Unlike `nv-lighten-theme' and `nv-darken-theme', this replaces the
current adjustment instead of adding to it, so the result does not
depend on what was applied earlier.  Use it when you want a specific
end state rather than a relative nudge:

  (nv-set-theme-adjustment -100)  ; everything black
  (nv-set-theme-adjustment 0)     ; original colors"
  (interactive "nSet total theme adjustment to (%): ")
  (nv-theme--set-adjustment percent))

;;;###autoload
(defun nv-lighten-theme (percent)
  "Lighten the currently displayed theme by PERCENT.
The change happens immediately and is cumulative: PERCENT is added to
`nv-theme-color-adjustment', which starts at 0 and is clamped to
`nv-theme-color-adjustment-limit'.

For example:
  (nv-lighten-theme 4)   ; 4% lighter
  (nv-lighten-theme -4)  ; 4% darker

To set the total rather than adjust it, use `nv-set-theme-adjustment'."
  (interactive "nLighten theme by (%): ")
  (nv-theme--set-adjustment (+ nv-theme-color-adjustment percent)))

;;;###autoload
(defun nv-darken-theme (percent)
  "Darken the currently displayed theme by PERCENT.
The change happens immediately and is cumulative.

For example:
  (nv-darken-theme 4)    ; 4% darker
  (nv-darken-theme -4)   ; 4% lighter

To set the total rather than adjust it, use `nv-set-theme-adjustment'."
  (interactive "nDarken theme by (%): ")
  (nv-lighten-theme (- percent)))

;;;###autoload
(defun nv-reset-theme-colors ()
  "Restore the theme colors from before runtime adjustments."
  (interactive)
  (if (null nv-theme-original-colors)
      (message "No saved theme colors to restore")
    (pcase-dolist (`(,face . ,attributes) nv-theme-original-colors)
      (pcase-dolist (`(,attr . ,value) attributes)
        (set-face-attribute face nil attr value)))
    (setq nv-theme-original-colors nil
          nv-theme--baseline-themes nil
          nv-theme-color-adjustment 0)
    (message "Theme colors restored")))

(provide 'nv-theme-color-adjustments)
;;; nv-theme-color-adjustments.el ends here
