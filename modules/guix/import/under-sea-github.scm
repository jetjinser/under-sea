;;; under-sea-github updater --- property-driven GitHub release/tag checks.
;;;
;;; Packages opt in by declaring an `upstream-github' property:
;;;
;;;   (properties '((upstream-github "SagerNet/sing-box")))
;;;   (properties '((upstream-github "openai/codex")))          ;tag fallback
;;;   (properties '((upstream-github "Tencent/ncnn"
;;;                                 #:tag->version "^[0-9]+"))) ;custom mapping
;;;
;;; The updater queries /releases/latest (which already excludes drafts and
;;; prereleases) and falls back to the newest tag for repositories that ship
;;; no releases.  Tag names are turned into versions by stripping a
;;; non-digit prefix (v2.12.3, rust-v0.163.0, bun-v1.3.4), or by the optional
;;; #:tag->version regular expression whose first group becomes the version.
;;;
;;; Discovered as (guix import under-sea-github) per the updater naming
;;; convention, e.g.:
;;;
;;;   guix refresh -t under-sea-github -L modules sing-box

(define-module (guix import under-sea-github)
  #:use-module (guix http-client)
  #:use-module (guix memoization)
  #:use-module (guix packages)
  #:use-module (guix upstream)
  #:use-module (guix git-download)
  #:use-module (json)
  #:use-module (ice-9 match)
  #:use-module (ice-9 regex)
  #:use-module (ice-9 textual-ports)
  #:use-module (srfi srfi-11)
  #:export (%under-sea-github-updater))

(define %api "https://api.github.com/repos")

(define http-fetch*
  ;; Memoized http-fetch returning the response body as a string.
  (memoize (lambda args
             (call-with-port (apply http-fetch args) get-string-all))))

(define (json-fetch* url)
  (json-string->scm (http-fetch* url #:text? #t)))

(define (repo+options package)
  "Return two values, the OWNER/REPO string and its option list, from
PACKAGE's upstream-github property, or #f twice when absent."
  (let ((value (assq-ref (package-properties package) 'upstream-github)))
    (cond ((string? value) (values value '()))
          ((list? value) (values (car value) (cdr value)))
          (else (values #f #f)))))

(define (latest-release-tag repo)
  "Return TAG_NAME of the latest stable GitHub release of REPO, or #f:
/releases/latest is consulted first; when the repository marks no
release as latest (or marks them all as prereleases), the /releases
list is scanned for the first non-draft, non-prerelease entry."
  (or (false-if-exception
       (assoc-ref (json-fetch* (string-append %api "/" repo "/releases/latest"))
                  "tag_name"))
      (false-if-exception
       (let ((doc (json-fetch* (string-append %api "/" repo "/releases?per_page=20"))))
         (and (vector? doc)
              (let loop ((i 0))
                (and (< i (vector-length doc))
                     (let ((entry (vector-ref doc i)))
                       (if (or (assoc-ref entry "draft")
                               (assoc-ref entry "prerelease"))
                           (loop (1+ i))
                           (assoc-ref entry "tag_name"))))))))))

(define (latest-tag repo)
  "Return the name of the newest tag of REPO."
  (let ((doc (json-fetch* (string-append %api "/" repo "/tags?per_page=100"))))
    (and (vector? doc) (> (vector-length doc) 0)
         (assoc-ref (vector-ref doc 0) "name"))))

(define (tag->version tag options)
  "Turn TAG into a version string per OPTIONS."
  (let ((rx (assq-ref options #:tag->version)))
    (cond (rx
           (let ((m (string-match rx tag)))
             (or (and m (or (match:substring m 1) (match:substring m 0)))
                 tag)))
          (else
           ;; Strip a non-digit prefix such as "v", "rust-v" or "bun-v".
           (let ((m (string-match "^[^0-9]*([0-9].*)" tag)))
             (if m (match:substring m 1) tag))))))

(define* (latest-release package #:key version partial-version?
                         #:allow-other-keys)
  "Return an <upstream-source> for the newest release or tag of the
repository PACKAGE tracks, or #f when it cannot be determined.  VERSION
and PARTIAL-VERSION? are hints from guix refresh and are ignored."
  (let-values (((repo options) (repo+options package)))
    (if (not repo)
        #f
        (catch #t
          (lambda ()
            (let* ((tag (or (latest-release-tag repo)
                            (latest-tag repo)))
                   (version (and tag (tag->version tag options))))
              (and version
                   (upstream-source
                    (package (package-name package))
                    (version version)
                    (urls
                     (list (git-reference
                            (url (string-append "https://github.com/" repo))
                            (commit tag))))))))
          (lambda (key . args)
            (format (current-error-port)
                    "under-sea-github: ~a lookup failed (~a): ~s~%"
                    repo (package-name package) key)
            #f)))))

(define (under-sea-github-package? package)
  "Return #t if PACKAGE declares an upstream-github property."
  (and (assq-ref (package-properties package) 'upstream-github) #t))

(define %under-sea-github-updater
  (upstream-updater
    (name 'under-sea-github)
    (description "Updater for under-sea packages pinned to GitHub releases or tags")
    (pred under-sea-github-package?)
    (import latest-release)))

;;; under-sea-github.scm ends here.
