;; BSD license
;; Author: Marcin Koziej
;; marcin at lolownia dot org
;; website: https://github.com/lolownia/org-pomodoro

(require 'timer)
(require 'org)
(require 'org-timer)
(require 'notify)

(defgroup org-pomodoro nil
  "Org pomodoro customization"
  :tag "Org Pomodoro"
  :group 'org-progress)

(defvar org-pomodoro-timer nil
  "The timer while a pomodoro or a break.")

(defvar org-pomodoro-countdown 0
  "The actual countdown value for a phase in seconds.")

(defvar org-pomodoro-state :none
  "The current state of `org-pomodoro`. It changes to :pomodoro when starting
a pomodoro and to :longbreak or :break when starting a break.")

(defvar org-pomodoro-count 0
  "The number of pomodoros since the last long break.")

(defvar org-pomodoro-long-break-frequency 4
  "The maximum number of pomodoros until a long break is started.")

(defvar org-pomodoro-mode-line "")
(put 'org-pomodoro-mode-line 'risky-local-variable t)

(defvar org-pomodoro-play-sounds t
  "Determines whether sounds are played or not.")

;; POMODORO VALUES
(defvar org-pomodoro-length 25
  "The length of a pomodoro in minutes.")

(defvar org-pomodoro-format "Pomodoro~%s"
  "The format of the mode line string during a long break.")

(defvar org-pomodoro-sound
  (concat (file-name-directory load-file-name)
          "/resources/bell.wav")
  "The path to a sound file that´s to be played when a pomodoro was finished.")

(defvar org-pomodoro-killed-sound nil
  "The path to a sound file, that´s to be played when a pomodoro is killed.")

;; SHORT BREAK VALUES
(defvar org-pomodoro-short-break-length 5
  "The length of a break in minutes.")

(defvar org-pomodoro-short-break-format "Short Break~%s"
  "The format of the mode line string during a long break.")

(defvar org-pomodoro-short-break-sound
  (concat (file-name-directory load-file-name)
          "/resources/bell.wav")
  "The path to a sound file that´s to be played when a break was finished.")

;; LONG BREAK VALUES
(defvar org-pomodoro-long-break-length 20
  "The length of a long break in minutes.")

(defvar org-pomodoro-long-break-format "Long Break~%s"
  "The format of the mode line string during a long break.")

(defvar org-pomodoro-long-break-sound
  (concat (file-name-directory load-file-name)
          "/resources/bell_multiple.wav")
  "The path to a sound file that´s to be played when a long break is finished.")


(defface org-pomodoro-mode-line
  '((t (:foreground "tomato1")))
  "Org Pomodoro mode line color"
  :group 'faces)


(defun org-pomodoro-play-sound (sound)
  "Plays a sound."
  (when (and org-pomodoro-play-sounds sound)
    (play-sound-file sound)))


(defun org-pomodoro-minutes ()
  "Returns the current countdown value in minutes as string."
  (let ((hms (org-timer-secs-to-hms org-pomodoro-countdown)))
    (substring hms (- (length hms) 5))))


(defun org-pomodoro-update-mode-line ()
  "Sets the modeline accordingly to the current state."
  (setq org-pomodoro-mode-line
        (propertize (format (case org-pomodoro-state
                              (:none "")
                              (:pomodoro org-pomodoro-format)
                              (:short-break org-pomodoro-short-break-format)
                              (:long-break org-pomodoro-long-break-format))
                            (org-pomodoro-minutes))
                    'face 'org-pomodoro-mode-line))
  (force-mode-line-update))


(defun org-pomodoro-kill ()
  "Kills the current timer, resets the phase and updates the modeline."
  (org-pomodoro-reset)
  (org-pomodoro-killed))

(defun org-pomodoro-tick ()
  "A callback that is invoked by the running timer each second.
It checks whether we reached the duration of the current phase, when 't it
invokes the handlers for finishing."
  (if (and (equal org-pomodoro-state :none) org-pomodoro-timer)
      (org-pomodoro-reset)
    (progn
      (setq org-pomodoro-countdown (- org-pomodoro-countdown 1))
      (when (< org-pomodoro-countdown 1)
        (case org-pomodoro-state
          (:pomodoro
           (org-pomodoro-finished))
          (:short-break
           (org-pomodoro-short-break-finished))
          (:long-break
           (org-pomodoro-long-break-finished))))))
  (org-pomodoro-update-mode-line))


(defun org-pomodoro-start (&optional state)
  "Start the `org-pomodoro` timer. The argument is optional.
The default state is `:pomodoro`."
  (when org-pomodoro-timer (cancel-timer org-pomodoro-timer))

  ;; add the org-pomodoro-mode-line to the global-mode-string
  (unless global-mode-string (setq global-mode-string '("")))
  (unless (memq 'org-pomodoro-mode-line global-mode-string)
    (setq global-mode-string (append global-mode-string
                                     '(org-pomodoro-mode-line))))
  (unless state (setq state :pomodoro))
  (setq org-pomodoro-state state
        org-pomodoro-countdown (case state
                                 (:pomodoro (* 60 org-pomodoro-length))
                                 (:short-break (* 60 org-pomodoro-short-break-length))
                                 (:long-break (* 60 org-pomodoro-long-break-length)))
        org-pomodoro-timer (run-with-timer t 1 'org-pomodoro-tick))
  (org-pomodoro-update-mode-line))

(defun org-pomodoro-reset ()
  "Resets the org-pomodoro state."
  (when org-pomodoro-timer
    (cancel-timer org-pomodoro-timer))
  (setq org-pomodoro-state :none
        org-pomodoro-countdown 0)
  (org-pomodoro-update-mode-line))

;; -----------------------------
;; Handlers for pomodoro events.
;; -----------------------------

(defun org-pomodoro-finished ()
  "Is invoked when a pomodoro was finished successfully. This may send a
notification, play a sound and start a pomodoro break."
  (org-clock-out)
  (org-pomodoro-play-sound org-pomodoro-sound)
  (setq org-pomodoro-count (+ org-pomodoro-count 1))
  (if (> org-pomodoro-count org-pomodoro-long-break-frequency)
      (progn
        (notify "Pomodoro finished" "Pomodoro completed! Time for a long break.")
        (org-pomodoro-start :long-break))
    (progn
      (notify "Pomodoro finished" "Pomodoro completed! Time for a short break.")
      (org-pomodoro-start :short-break)))
  (run-hooks 'org-pomodoro-finished-hook)
  (org-pomodoro-update-mode-line))


(defun org-pomodoro-killed ()
  "Is invoked when a pomodoro was killed. This may send a notification,
play a sound and adds log."
  (notify "Pomodoro killed" "One does not simply kill a pomodoro!")
  (org-clock-cancel)
  (org-pomodoro-reset)
  (run-hooks 'org-pomodoro-killed-hook)
  (org-pomodoro-update-mode-line))


(defun org-pomodoro-short-break-finished ()
  "Is invoked when a break is finished. This may send a notification and play
a sound."
  (notify "Break finished" "Short break finished. Ready for another pomodoro?")
  (org-pomodoro-play-sound org-pomodoro-short-break-sound)
  (org-pomodoro-reset))


(defun org-pomodoro-long-break-finished ()
  "Is invoked when a long break is finished. This may send a notification
and play a sound."
  (notify "Break finished" "Long break finished. Ready for another pomodoro?")
  (org-pomodoro-play-sound org-pomodoro-long-break-sound)
  (org-pomodoro-reset))

;; ---------------------------------------
;; The actual function to handle pomodoros
;; ---------------------------------------

(defun org-pomodoro (&optional abc)
  "When no timer is running for `org-pomodoro` a new pomodoro is started and
the current task is clocked in. Otherwise emacs will ask whether we´d like to
kill the current timer, this may be a break or a running pomodoro."
  (interactive "p")
  (if (equal org-pomodoro-state :none)
      (progn
        (cond
         ((eq major-mode 'org-mode)
          (call-interactively 'org-clock-in))
         ((eq major-mode 'org-agenda-mode)
          (org-with-point-at (org-get-at-bol 'org-hd-marker)
            (call-interactively 'org-clock-in)))
         (t (let ((current-prefix-arg '(4)))
              (call-interactively 'org-clock-in))))
        (org-pomodoro-start :pomodoro))
    (if (y-or-n-p "There is already a running timer. Would You like to stop it?")
        (org-pomodoro-kill)
      (message "Alright, keep up the good work!"))))

(provide 'org-pomodoro)
