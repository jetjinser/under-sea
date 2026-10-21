;;; Optional: reuse files downloaded during dependency locking.
;;; Invoke with the pinned Guix:
;;; guix time-machine -C channels.scm -- repl -- \
;;;   scripts/seed-source-cache.scm /tmp/under-sea-sing-box-lock/inputs
(use-modules (guix store) (ice-9 ftw))

(let ((directory (cadr (command-line))))
  (with-store store
    (for-each
     (lambda (name)
       (let ((file (string-append directory "/" name)))
         (when (eq? 'regular (stat:type (stat file)))
           (display (add-to-store store name #f "sha256" file))
           (newline))))
     (scandir directory (lambda (name) (not (member name '("." ".."))))))))
