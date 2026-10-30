;;; Agent Cat - a mathematical framework for modeling agentic workflows
;;; (Haskell), packaged from jwiegley/agent-cat.  MIT licensed per the cabal
;;; file (the repository ships no LICENSE file).
;;;
;;; Production tracks reviewed upstream main at e6d0cad. The refreshed
;;; crypton/TLS/X.509 and network family provides the API and socket ABI needed
;;; by this revision; build and installed scripted workflow smoke passed.

(define-module (under-sea packages agent-cat)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix build-system haskell)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages haskell-check)
  #:use-module (gnu packages haskell-web)
  #:use-module (gnu packages haskell-crypto)
  #:use-module (gnu packages haskell-xyz)
  #:use-module (under-sea packages agent-cat-pin)
  #:use-module (under-sea packages agent-cat-crypto)
  #:export (ghc-direct-sqlite agent-cat))

;; Low-level SQLite3 binding; bundles the sqlite3 C amalgamation.
(define-public ghc-direct-sqlite
  (package
    (name "ghc-direct-sqlite")
    (version "2.3.29")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://hackage.haskell.org/package/direct-sqlite-" version
             "/direct-sqlite-" version ".tar.gz"))
       (sha256
        (base32
         "1byhnk4jcv83iw7rqw48p8xk6s2dfs1dh6ibwwzkc9m9lwwcwajz"))))
    (build-system haskell-build-system)
    (arguments (list #:tests? #f))  ; the test-suite needs HUnit
    (home-page "https://hackage.haskell.org/package/direct-sqlite")
    (synopsis "Low-level binding to SQLite3 with UTF8 and BLOB support")
    (description "This package provides a low-level binding to SQLite3, less
high-level than other bindings but fixing a few deficiencies: it supports
marshalling of UTF8-encoded strings and BLOB values to and from the database.
The sqlite3 C amalgamation is bundled.")
    (license license:bsd-3)))

(define-public agent-cat
  (package
    (name "agent-cat")
    (version %agent-cat-version)
    (source %agent-cat-source)
    (build-system haskell-build-system)
    (inputs
     (list ghc-aeson
           ghc-async
           ghc-brick
           ghc-case-insensitive
           ghc-crypton-agent-cat
           ghc-crypton-connection-agent-cat
           ghc-crypton-x509-agent-cat
           ghc-crypton-x509-store-agent-cat
           ghc-direct-sqlite
           ghc-http-client-agent-cat
           ghc-http-client-tls-agent-cat
           ghc-http-types
           ghc-libyaml
           ghc-memory
           ghc-quickcheck
           ghc-scientific
           ghc-tls-agent-cat
           ghc-vty
           ghc-vty-unix
           ghc-vector
           ghc-warp-agent-cat
           ghc-warp-tls-agent-cat
           ghc-yaml))
    (arguments
     (list
      #:tests? #f  ; the test-suite fixtures exercise the unpackaged CLI
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'prepare-build
            (lambda _
              ;; Hash through cryptonite: the hashing helpers (Crypto.Hash,
              ;; Data.ByteArray.Encoding) are written against the memory
              ;; byte-array API; with the ram fork that API has no instance
              ;; for crypton's Digest, and cryptonite provides it.
              (substitute* "agentic.cabal"
                ((", ram") ", memory"))
              ;; The repository has no Setup.hs (it builds with
              ;; cabal-install); add the trivial default driver.
              (unless (file-exists? "Setup.hs")
                (call-with-output-file "Setup.hs"
                  (lambda (p)
                    (display
                     "import Distribution.Simple\nmain = defaultMain\n" p))))))
          ;; The upstream suite contains repository fixtures and is disabled
          ;; above. Exercise the installed executable against its packaged,
          ;; deterministic scripted workflow instead.
          (add-after 'install 'smoke-agentic-run
            (lambda _
              (invoke (string-append #$output "/bin/agentic-run")
                      "run" "hello" "--scripted"))))))
    (home-page "https://github.com/jwiegley/agent-cat")
    (synopsis "Mathematical framework for modeling agentic workflows")
    (description "Agent Cat models agentic workflows as a typed DSL: a
first-order tree frontend with de Bruijn indices, a verifying compiler that
emits a checking builder, and a memoizing interpreter with versioned NDJSON
machine traces.  Includes tiered verification executables, a bisimulation
checker and a policy probe.  MIT licensed per the cabal file; the repository
currently ships no LICENSE file.")
    (license license:expat)))
