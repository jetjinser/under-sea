;;; Agent Cat - a mathematical framework for modeling agentic workflows
;;; (Haskell), packaged from jwiegley/agent-cat.  MIT licensed per the cabal
;;; file (the repository ships no LICENSE file).

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
  #:export (ghc-ram agent-cat))

;; A maintained fork of the `memory` package; only GHC boot libraries are
;; needed to build it.
(define-public ghc-ram
  (package
    (name "ghc-ram")
    (version "0.22.1")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://hackage.haskell.org/package/ram-" version
             "/ram-" version ".tar.gz"))
       (sha256
        "0w4z2lki9y243agvbrr8s88p77vrdk0bqincf2wh3lcx6ii4jivj")))
    (build-system haskell-build-system)
    (arguments (list #:tests? #f))  ; the test-suite needs QuickCheck/tasty
    (home-page "https://hackage.haskell.org/package/ram")
    (synopsis "Fork of the memory package: polymorphic byte arrays")
    (description "This package provides a chunk of memory, polymorphic byte
array management and manipulation, raw memory IO operations and encoding
helpers (Base16, Base32, Base64).  It is a fork of @code{memory} that is open
to changes from anyone.")
    (license license:bsd-3)))


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
    (version "0.0.0-0.c90ce63")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/jwiegley/agent-cat")
             (commit "c90ce63bc18d50f54dc76d7961a16e2bb8ea74a2")))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "0jhiravlvv56my6rkrmayarql5h0155xy14mxjna6k07ybk82n93"))))
    (build-system haskell-build-system)
    (arguments
     (list
      ;; The repository has no Setup.hs (it builds with cabal-install); add
      ;; the trivial default driver for the guix build system.
      #:phases
      #~(modify-phases %standard-phases
          (add-before 'configure 'generate-setup
            (lambda _
              (unless (file-exists? "Setup.hs")
                (call-with-output-file "Setup.hs"
                  (lambda (p)
                    (display "import Distribution.Simple\nmain = defaultMain\n"
                             p)))))))))
    (inputs
     (list ghc-aeson
           ghc-async
           ghc-brick
           ghc-case-insensitive
           ghc-crypton
           ghc-crypton-connection
           ghc-crypton-x509
           ghc-crypton-x509-store
           ghc-direct-sqlite
           ghc-http-client
           ghc-http-client-tls
           ghc-http-types
           ghc-libyaml
           ghc-ram
           ghc-quickcheck
           ghc-scientific
           ghc-tls
           ghc-vty
           ghc-vty-unix
           ghc-vector
           ghc-warp
           ghc-warp-tls
           ghc-yaml))
    (home-page "https://github.com/jwiegley/agent-cat")
    (synopsis "Mathematical framework for modeling agentic workflows")
    (description "Agent Cat models agentic workflows as a typed DSL: a
first-order tree frontend with de Bruijn indices, a verifying compiler that
emits a checking builder, and a memoizing interpreter with versioned NDJSON
machine traces.  Includes tiered verification executables, a bisimulation
checker and a policy probe.  MIT licensed per the cabal file; the repository
currently ships no LICENSE file.")
    (license license:expat)))
