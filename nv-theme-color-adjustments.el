;;; nv-theme-color-adjustments.el --- Change theme colors while running -*- lexical-binding: t; -*-


;;; Commentary:

;;; Runtime theme color adjustment
;;;
;;; (nv-lighten-theme 4)  => make current theme 4% lighter
;;; (nv-darken-theme 4)   => make current theme 4% darker
;;; (nv-lighten-theme -4) => make current theme 4% darker
;;; (nv-reset-theme-colors) => restore colors from before the first adjustment


;;; Code:

(require 'color)

(defvar nv-theme-original-colors nil
  "Original face colors saved before the first runtime adjustment.")

(defvar nv-theme-color-adjustment 0
  "Current cumulative runtime adjustment, in percent.
Positive values mean lighter; negative values mean darker.")

(defun nv-theme--color-attribute-p (value)
  "Return non-nil if VALUE is a usable explicit color."
  (and (stringp value)
       (not (string= value "unspecified"))
       (condition-case nil
           (color-name-to-rgb value)
         (error nil))))

(defun nv-theme--save-original-colors ()
  "Save the current explicit foreground and background colors."
  (unless nv-theme-original-colors
    (setq nv-theme-original-colors
          (mapcar
           (lambda (face)
             (list face
                   (face-attribute face :foreground nil nil)
                   (face-attribute face :background nil nil)))
           (face-list)))))

(defun nv-theme--adjust-color (color amount)
  "Adjust COLOR by AMOUNT percent.
Positive AMOUNT lightens; negative AMOUNT darkens."
  (if (nv-theme--color-attribute-p color)
      (condition-case nil
          (color-lighten-name color amount)
        (error color))
    color))

(defun nv-theme--apply-adjustment ()
  "Apply `nv-theme-color-adjustment' to all current faces."
  (dolist (entry nv-theme-original-colors)
    (let ((face (nth 0 entry))
          (foreground (nth 1 entry))
          (background (nth 2 entry)))
      (when (nv-theme--color-attribute-p foreground)
        (set-face-attribute
         face nil
         :foreground
         (nv-theme--adjust-color
          foreground nv-theme-color-adjustment)))
      (when (nv-theme--color-attribute-p background)
        (set-face-attribute
         face nil
         :background
         (nv-theme--adjust-color
          background nv-theme-color-adjustment))))))

(defun nv-lighten-theme (percent)
  "Lighten the currently displayed theme by PERCENT.
The change happens immediately and is cumulative.

For example:
  (nv-lighten-theme 4)   ; 4% lighter
  (nv-lighten-theme -4)  ; 4% darker"
  (interactive "nLighten theme by (%): ")
  (nv-theme--save-original-colors)
  (setq nv-theme-color-adjustment
        (+ nv-theme-color-adjustment percent))
  (nv-theme--apply-adjustment)
  (message "Theme brightness adjustment: %+d%%"
           nv-theme-color-adjustment))

(defun nv-darken-theme (percent)
  "Darken the currently displayed theme by PERCENT.
The change happens immediately and is cumulative.

For example:
  (nv-darken-theme 4)    ; 4% darker
  (darken-theme -4)   ; 4% lighter"
  (interactive "nDarken theme by (%): ")
  (nv-lighten-theme (- percent)))

(defun nv-reset-theme-colors ()
  "Restore the theme colors from before runtime adjustments."
  (interactive)
  (when nv-theme-original-colors
    (dolist (entry nv-theme-original-colors)
      (let ((face (nth 0 entry))
            (foreground (nth 1 entry))
            (background (nth 2 entry)))
        (when (nv-theme--color-attribute-p foreground)
          (set-face-attribute face nil :foreground foreground))
        (when (nv-theme--color-attribute-p background)
          (set-face-attribute face nil :background background))))
    (setq nv-theme-color-adjustment 0)
    (message "Theme colors restored"))
  (unless nv-theme-original-colors
    (message "No saved theme colors to restore")))


(provide 'nv-theme-color-adjustments)
;;; nv-theme-color-adjustments.el ends here
