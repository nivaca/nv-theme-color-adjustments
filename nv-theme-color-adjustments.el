;;; nv-theme-color-adjustments.el --- Change theme colors while running -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Nicolas Vaughan

;; Author: Nicolas Vaughan
;; Maintainer: Nicolas Vaughan
;; URL: https://github.com/nivaca/nv-theme-color-adjustments
;; Version: 0.2.0
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

(defgroup nv-theme-color-adjustments nil
  "Runtime lightness adjustments for the current theme."
  :group 'faces
  :prefix "nv-theme-")

(defcustom nv-theme-color-adjustment-method 'absolute
  "How a percentage is converted into a lightness change.

`absolute' shifts HSL lightness by PERCENT/100 in absolute terms, so
4 always means \"+0.04 lightness\".  This behaves the same way on light
and dark themes and can lighten pure black.

`relative' scales lightness by PERCENT, as `color-lighten-name' does.
This is the historical behaviour: it has almost no effect on dark
colors and cannot lighten pure black at all."
  :type '(choice (const :tag "Absolute lightness shift" absolute)
                 (const :tag "Relative to current lightness" relative))
  :group 'nv-theme-color-adjustments)

(defvar nv-theme-original-colors nil
  "Original face colors saved before the first runtime adjustment.
Each element has the form (FACE FOREGROUND BACKGROUND).")

(defvar nv-theme-color-adjustment 0
  "Current cumulative runtime adjustment, in percent.
Positive values mean lighter; negative values mean darker.")

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

(defun nv-theme--adjust-color (color amount)
  "Adjust COLOR by AMOUNT percent.
Positive AMOUNT lightens; negative AMOUNT darkens.
Return COLOR unchanged if it cannot be parsed."
  (let ((rgb (nv-theme--color-to-rgb color)))
    (if (null rgb)
        color
      (let* ((hsl (apply #'color-rgb-to-hsl rgb))
             (h (nth 0 hsl))
             (s (nth 1 hsl))
             (l (nth 2 hsl))
             (new-l (color-clamp
                     (if (eq nv-theme-color-adjustment-method 'relative)
                         (+ l (* l (/ amount 100.0)))
                       (+ l (/ amount 100.0))))))
        (apply #'color-rgb-to-hex
               (append (color-hsl-to-rgb h s new-l) (list 2)))))))


;;; Baseline management

(defun nv-theme--stale-baseline-p ()
  "Return non-nil if the saved baseline no longer matches the enabled themes."
  (and nv-theme-original-colors
       (not (equal nv-theme--baseline-themes custom-enabled-themes))))

(defun nv-theme--save-original-colors ()
  "Save the current explicit foreground and background colors.

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
      (push (list face
                  (face-attribute face :foreground nil nil)
                  (face-attribute face :background nil nil))
            nv-theme-original-colors))))

(defun nv-theme--apply-adjustment ()
  "Apply `nv-theme-color-adjustment' to all recorded faces."
  (dolist (entry nv-theme-original-colors)
    (let ((face (nth 0 entry))
          (foreground (nth 1 entry))
          (background (nth 2 entry)))
      (when (nv-theme--color-attribute-p foreground)
        (set-face-attribute
         face nil :foreground
         (nv-theme--adjust-color foreground nv-theme-color-adjustment)))
      (when (nv-theme--color-attribute-p background)
        (set-face-attribute
         face nil :background
         (nv-theme--adjust-color background nv-theme-color-adjustment))))))


;;; Commands

;;;###autoload
(defun nv-lighten-theme (percent)
  "Lighten the currently displayed theme by PERCENT.
The change happens immediately and is cumulative.

For example:
  (nv-lighten-theme 4)   ; 4% lighter
  (nv-lighten-theme -4)  ; 4% darker"
  (interactive "nLighten theme by (%): ")
  (nv-theme--save-original-colors)
  (setq nv-theme-color-adjustment (+ nv-theme-color-adjustment percent))
  (nv-theme--apply-adjustment)
  (message "Theme brightness adjustment: %+g%%" nv-theme-color-adjustment))

;;;###autoload
(defun nv-darken-theme (percent)
  "Darken the currently displayed theme by PERCENT.
The change happens immediately and is cumulative.

For example:
  (nv-darken-theme 4)    ; 4% darker
  (nv-darken-theme -4)   ; 4% lighter"
  (interactive "nDarken theme by (%): ")
  (nv-lighten-theme (- percent)))

;;;###autoload
(defun nv-reset-theme-colors ()
  "Restore the theme colors from before runtime adjustments."
  (interactive)
  (if (null nv-theme-original-colors)
      (message "No saved theme colors to restore")
    (dolist (entry nv-theme-original-colors)
      (let ((face (nth 0 entry))
            (foreground (nth 1 entry))
            (background (nth 2 entry)))
        (when (nv-theme--color-attribute-p foreground)
          (set-face-attribute face nil :foreground foreground))
        (when (nv-theme--color-attribute-p background)
          (set-face-attribute face nil :background background))))
    (setq nv-theme-original-colors nil
          nv-theme--baseline-themes nil
          nv-theme-color-adjustment 0)
    (message "Theme colors restored")))

(provide 'nv-theme-color-adjustments)
;;; nv-theme-color-adjustments.el ends here
