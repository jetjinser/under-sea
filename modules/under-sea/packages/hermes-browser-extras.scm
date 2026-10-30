;;; Source-built components reused from the fixed channel for browser extras.
(define-module (under-sea packages hermes-browser-extras)
  #:use-module (guix packages)
  #:use-module (gnu packages geo)
  #:use-module (gnu packages qt))

;; Camoufox optional extras: geoip (maxminddb) and gui (PySide6 + shiboken6).
;; These are aliases to the channel's source-built packages so the runtime
;; reuses the existing derivation (no Qt rebuild).
(define-public maxminddb-for-hermes python-maxminddb)
(define-public pyside6-for-hermes python-pyside-6)
;; Guix builds PySide6 from its upstream unified source tree, which provides
;; the three wheel distributions selected separately by PyPI's metadata.
(define-public pyside6-essentials-for-hermes python-pyside-6)
(define-public pyside6-addons-for-hermes python-pyside-6)
(define-public shiboken6-for-hermes python-shiboken-6)
