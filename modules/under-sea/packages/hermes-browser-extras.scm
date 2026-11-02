;;; Source-built components reused from the fixed channel for browser extras.
(define-module (under-sea packages hermes-browser-extras)
  #:use-module (guix packages)
  #:use-module (gnu packages geo)
  #:use-module (gnu packages qt))

;; Camoufox optional extras: geoip (maxminddb) and gui (PySide6 + shiboken6).
;; Guix ships PySide as a source-built package and keeps it in sync with its Qt
;; stack. Follow that package's version instead of pinning the Guix channel to
;; the version that happened to be current when this lock was written. The
;; resolver marks these as channel-versioned and records the selected version
;; in Hermes's component manifest.
(define-public maxminddb-for-hermes python-maxminddb)
(define-public pyside6-for-hermes
  (package
    (inherit python-pyside-6)
    (name "pyside6-for-hermes")
    (properties (acons 'hermes-channel-versioned? #t
                       (package-properties python-pyside-6)))))
;; Guix builds PySide6 from its upstream unified source tree, which provides
;; the three wheel distributions selected separately by PyPI's metadata.
(define-public pyside6-essentials-for-hermes
  (package
    (inherit pyside6-for-hermes)
    (name "pyside6-essentials-for-hermes")))
(define-public pyside6-addons-for-hermes
  (package
    (inherit pyside6-for-hermes)
    (name "pyside6-addons-for-hermes")))
(define-public shiboken6-for-hermes
  (package
    (inherit python-shiboken-6)
    (name "shiboken6-for-hermes")
    (properties (acons 'hermes-channel-versioned? #t
                       (package-properties python-shiboken-6)))))
