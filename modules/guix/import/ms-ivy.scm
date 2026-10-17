;;; ms-ivy updater --- track the tip of kenmcmil/ivy's master branch.
;;;
;;; IVy ships no upstream releases, so python-ms-ivy pins a master commit.
;;; This updater reports when that tip moves, and carries the version declared
;;; in the tip's setup.py so `guix refresh' can compare like with like.
;;;
;;; Discovered as (guix import ms-ivy) per the updater naming convention, e.g.:
;;;
;;;   guix refresh -t ms-ivy -L modules python-ms-ivy

(define-module (guix import ms-ivy)
  #:use-module (guix http-client)
  #:use-module (guix memoization)
  #:use-module (guix packages)
  #:use-module (guix upstream)
  #:use-module (guix git-download)
  #:use-module (json)
  #:use-module (ice-9 match)
  #:use-module (ice-9 regex)
  #:use-module (ice-9 textual-ports)
  #:use-module (rnrs bytevectors)
  #:use-module (gcrypt base64)
  #:export (%ms-ivy-updater))

(define %ivy-repository "https://github.com/kenmcmil/ivy")
(define %ivy-api "https://api.github.com/repos/kenmcmil/ivy")

(define http-fetch*
  ;; Memoized http-fetch returning the response body as a string.
  (memoize (lambda args
             (call-with-port (apply http-fetch args) get-string-all))))

(define (json-fetch* url)
  (json-string->scm (http-fetch* url #:text? #t)))

(define (latest-commit)
  "Return (COMMIT . DATE-COMPACT) for the tip of IVy's master branch."
  (let* ((doc (json-fetch* (string-append %ivy-api "/commits/master")))
         (commit (assoc-ref doc "sha"))
         (date (assoc-ref (assoc-ref (assoc-ref doc "commit") "committer")
                          "date")))
    (cons commit
          (string-append (substring date 0 4)
                         (substring date 5 7)
                         (substring date 8 10)))))

(define (tip-version)
  "Return the version number declared in the tip's setup.py, or #f."
  (catch #t
    (lambda ()
      (let* ((doc (json-fetch* (string-append %ivy-api "/contents/setup.py")))
             (b64 (string-filter (lambda (c) (not (char-whitespace? c)))
                                 (assoc-ref doc "content")))
             (text (utf8->string (base64-decode b64)))
             (m (string-match "version=['\"]([^'\"]+)['\"]" text)))
        (and m (match:substring m 1))))
    (lambda (key . args)
      (format (current-error-port)
              "ms-ivy updater: tip-version lookup failed: ~a ~s~%" key args)
      #f)))

(define (latest-release package)
  "Return an <upstream-source> for the tip of IVy's master branch."
  (let* ((tip (latest-commit))
         (version (or (tip-version) (cdr tip))))
    (upstream-source
      (package (package-name package))
      (version version)
      (urls
       (list (git-reference
               (url %ivy-repository)
               (commit (car tip))))))))

(define (ms-ivy-package? package)
  "Return #t if PACKAGE is the IVy tool."
  (string=? (package-name package) "python-ms-ivy"))

(define %ms-ivy-updater
  (upstream-updater
    (name 'ms-ivy)
    (description "Updater for the IVy protocol verification tool")
    (pred ms-ivy-package?)
    (import latest-release)))

;;; ms-ivy.scm ends here.
