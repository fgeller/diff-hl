;;; diff-hl-show-hunk-posframe.el --- posframe backend for diff-hl-show-hunk -*- lexical-binding: t -*-

;; Copyright (C) 2020  Free Software Foundation, Inc.

;; Author:   Álvaro González <alvarogonzalezsotillo@gmail.com>

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;; Provides `diff-hl-show-hunk-posframe' than can be used as
;;  `diff-hl-show-hunk-function'.  'posframe.el' is a runtime
;;  dependency, it is not required by this package, but should be
;;  installed and loaded.
;;
;;; Code:

; REMOVE BEFORE RELEASE, USED FOR FLYCHECK
; (eval-when-compile (add-to-list 'load-path "/home/alvaro/github/diff-hl"))

(require 'diff-hl)
(require 'diff-hl-show-hunk)

;; This package uses some runtime dependencies, so we need to declare
;; the external functions and variables
(declare-function posframe-workable-p "posframe")
(declare-function posframe-show "posframe")
(defvar diff-hl-show-hunk--hide-function)
(defvar posframe-mouse-banish)

(defgroup diff-hl-show-hunk-posframe-group nil
  "Show vc diffs in a posframe."
  :group 'diff-hl-show-hunk-group)

(defcustom diff-hl-show-hunk-posframe-show-header-line t
  "Show some useful buttons at the top of the diff-hl posframe."
  :type 'boolean)

(defcustom diff-hl-show-hunk-posframe-internal-border-width 2
  "Internal border width of the posframe."
  :type 'integer)

(defcustom diff-hl-show-hunk-posframe-internal-border-color "#00ffff"
  "Internal border color of the posframe.  If it doesn't work, try with `internal-border` face."
  :type 'color)

(defcustom diff-hl-show-hunk-posframe-poshandler nil
  "Poshandler of the posframe (see `posframe-show`)."
  :type 'function)

(defcustom diff-hl-show-hunk-posframe-parameters nil
  "The frame parameters used by helm-posframe."
  :type 'string)

(defvar diff-hl-show-hunk--frame nil "The postframe frame used in function `diff-hl-show-hunk-posframe'.")
(defvar diff-hl-show-hunk--original-frame nil "The frame from which the hunk is shown.")

(defun diff-hl-show-hunk--posframe-hide ()
  "Hide the posframe and clean up buffer."
  (interactive)
  (diff-hl-show-hunk-posframe--transient-mode -1)
  (when (frame-live-p diff-hl-show-hunk--frame)
    (make-frame-invisible diff-hl-show-hunk--frame))
  (when diff-hl-show-hunk--original-frame
    (when (frame-live-p diff-hl-show-hunk--original-frame)
      (select-frame-set-input-focus diff-hl-show-hunk--original-frame))
    (setq diff-hl-show-hunk--original-frame nil)))

(defvar diff-hl-show-hunk-posframe--transient-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map [escape]    #'diff-hl-show-hunk-hide)
    (define-key map (kbd "q")   #'diff-hl-show-hunk-hide)
    (define-key map (kbd "C-g") #'diff-hl-show-hunk-hide)
    (define-key map (kbd "n")   #'diff-hl-show-hunk-next)
    (define-key map (kbd "p")   #'diff-hl-show-hunk-previous)
    (define-key map (kbd "c")   #'diff-hl-show-hunk-original-text-to-kill-ring)
    map)
  "Keymap for command `diff-hl-show-hunk-posframe--transient-mode'.
Capture all the vertical movement of the point, and converts it
to scroll in the posframe")

(define-minor-mode diff-hl-show-hunk-posframe--transient-mode
  "Temporal minor mode to control diff-hl posframe."
  :group 'diff-hl-show-hunk-group
  :lighter ""
  :global t
  
  (remove-hook 'post-command-hook #'diff-hl-show-hunk--posframe-post-command-hook nil)
  (when diff-hl-show-hunk-posframe--transient-mode
    (add-hook 'post-command-hook #'diff-hl-show-hunk--posframe-post-command-hook nil)))

(defun diff-hl-show-hunk--posframe-post-command-hook ()
  "Called for each command while in `diff-hl-show-hunk-posframe--transient-mode."
  (let* ((allowed-command (or
                           (diff-hl-show-hunk-ignorable-command-p this-command)
                           (and (symbolp this-command) (string-match-p "diff-hl-" (symbol-name this-command)))))
         (event-in-frame (eq last-event-frame diff-hl-show-hunk--frame))
         (has-focus (and (frame-live-p diff-hl-show-hunk--frame)(functionp 'frame-focus-state) (eq (frame-focus-state diff-hl-show-hunk--frame) t)))
         (still-visible (or event-in-frame allowed-command has-focus)))
    (unless still-visible
      (diff-hl-show-hunk--posframe-hide))))

(defun diff-hl-show-hunk--posframe-button (text help-echo action)
  "Make a string implementing a button with TEXT and a HELP-ECHO.  The button calls an ACTION."
  (concat
   (propertize (concat " " text " ")
               'help-echo (if action help-echo "Not available")
               'face '(:height 0.7)
               'mouse-face (when action '(:box (:style released-button)))
               'keymap (when action (let ((map (make-sparse-keymap)))
                                      (define-key map (kbd "<header-line> <mouse-1>") action)
                                      map)))
   " "))

(defun diff-hl-show-hunk-posframe--header-line ()
  "Make the header line of the posframe."
  (concat
   (diff-hl-show-hunk--posframe-button
    "⨯ Close"
    "Close (\\[diff-hl-show-hunk-hide])"
    #'diff-hl-show-hunk-hide)
   (diff-hl-show-hunk--posframe-button
    "⬆ Previous change"
    "Previous change in hunk (\\[diff-hl-show-hunk-previous])"
    #'diff-hl-show-hunk-previous)
   
   (diff-hl-show-hunk--posframe-button
    "⬇ Next change"
    "Next change in hunk (\\[diff-hl-show-hunk-next])"
    #'diff-hl-show-hunk-next)

   (diff-hl-show-hunk--posframe-button
    "⊚ Copy original"
    "Copy original (\\[diff-hl-show-hunk-original-text-to-kill-ring])"
    #'diff-hl-show-hunk-original-text-to-kill-ring)

   (diff-hl-show-hunk--posframe-button
    "♻ Revert hunk"
    nil
    (lambda ()
      (interactive) (diff-hl-show-hunk-hide) (diff-hl-revert-hunk)))))

(defun diff-hl-show-hunk-posframe (buffer line)
  "Implementation to show the hunk in a posframe.  BUFFER is a buffer with the hunk, and the central line should be LINE."

  (unless (featurep 'posframe)
    (user-error "Required package for diff-hl-show-hunk-posframe not available: posframe.  Please customize diff-hl-show-hunk-function"))

  (require 'posframe)
  (unless (posframe-workable-p)
    (user-error "Package posframe is not workable.  Please customize diff-hl-show-hunk-function"))

  (diff-hl-show-hunk--posframe-hide)
  (setq diff-hl-show-hunk--hide-function #'diff-hl-show-hunk--posframe-hide)

  ;; put an overlay to override read-only-mode keymap
  (with-current-buffer buffer
    (let ((full-overlay (make-overlay 1 (1+ (buffer-size)))))
      (overlay-put full-overlay 'keymap diff-hl-show-hunk-posframe--transient-mode-map)))
  
  (setq posframe-mouse-banish nil)
  (setq diff-hl-show-hunk--original-frame last-event-frame)
  (setq
   diff-hl-show-hunk--frame
   (posframe-show buffer
                  :position (point)
                  :poshandler diff-hl-show-hunk-posframe-poshandler
                  :internal-border-width diff-hl-show-hunk-posframe-internal-border-width
                  :accept-focus t
                  ;; internal-border-color Doesn't always work, if not customize internal-border face
                  :internal-border-color diff-hl-show-hunk-posframe-internal-border-color
                  :hidehandler nil
                  ;; Sometimes, header-line is not taken into account, so put a min height and a min width
                  :min-height (when diff-hl-show-hunk-posframe-show-head-line 10)
                  :min-width (when diff-hl-show-hunk-posframe-show-head-line (length (diff-hl-show-hunk-posframe--header-line)))
                  :respect-header-line diff-hl-show-hunk-posframe-show-header-line
                  :respect-tab-line nil
                  :respect-mode-line nil
                  :override-parameters diff-hl-show-hunk-posframe-parameters))

  (set-frame-parameter diff-hl-show-hunk--frame 'drag-internal-border t)
  (set-frame-parameter diff-hl-show-hunk--frame 'drag-with-header-line t)

  ;; Recenter arround point
  (with-selected-frame diff-hl-show-hunk--frame
    (with-current-buffer buffer
      (diff-hl-show-hunk-posframe--transient-mode 1)
      (when diff-hl-show-hunk-posframe-show-header-line
        (setq header-line-format (diff-hl-show-hunk-posframe--header-line)))
      (goto-char (point-min))
      (forward-line (1- line))
      (setq buffer-quit-function #'diff-hl-show-hunk--posframe-hide)
      (select-window (window-main-window diff-hl-show-hunk--frame))
      (setq cursor-type 'box)
      (recenter)))
  (select-frame-set-input-focus diff-hl-show-hunk--frame)
  t)

(provide 'diff-hl-show-hunk-posframe)
;;; diff-hl-show-hunk-posframe.el ends here
