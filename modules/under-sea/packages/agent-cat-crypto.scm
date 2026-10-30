;;; New crypton/X.509 libraries needed by the reviewed Agent Cat source.
;;; Sources and hashes are mirrored in planning/agent-cat-tls-sources.json.

(define-module (under-sea packages agent-cat-crypto)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix build-system haskell)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages haskell-crypto)
  #:use-module (gnu packages haskell-web)
  #:use-module (gnu packages haskell-xyz)
  #:export (ghc-crypton-agent-cat
            ghc-crypton-asn1-encoding-agent-cat
            ghc-crypton-asn1-parse-agent-cat
            ghc-crypton-asn1-types-agent-cat
            ghc-crypton-pem-agent-cat
            ghc-crypton-x509-agent-cat
            ghc-crypton-x509-store-agent-cat
            ghc-crypton-x509-system-agent-cat
            ghc-crypton-x509-validation-agent-cat
            ghc-hpke-agent-cat
            ghc-ech-config-agent-cat
            ghc-tls-agent-cat
            ghc-crypton-connection-agent-cat
            ghc-http-client-tls-agent-cat
            ghc-crypto-token-agent-cat
            ghc-tls-session-manager-agent-cat
            ghc-time-manager-agent-cat
            ghc-network-run-agent-cat
            ghc-http-semantics-agent-cat
            ghc-http2-agent-cat
            ghc-wai-agent-cat
            ghc-warp-agent-cat
            ghc-warp-tls-agent-cat
            ghc-network-agent-cat
            ghc-crypton-socks-agent-cat
            ghc-simple-sendfile-agent-cat))

(define (hackage-source name version hash)
  (origin
    (method url-fetch)
    (uri (string-append "https://hackage.haskell.org/package/"
                        name "-" version "/" name "-" version ".tar.gz"))
    (sha256 (base32 hash))))

(define-public ghc-crypton-agent-cat
  (package
    (inherit ghc-crypton)
    (name "ghc-crypton")
    (version "1.1.2")
    (source (hackage-source "crypton" version
                            "17ndb7zi05gbkkf153xdwxznlqq14masaj9acv4n44hcgzdamk41"))
    (inputs (list ghc-primitive ghc-base16 ghc-memory))
    (arguments
     (list #:tests? #f
           #:phases
           #~(modify-phases %standard-phases
               (add-after 'unpack 'replace-ram-with-memory
                 (lambda _
                   (substitute* "crypton.cabal"
                     (("ram >=0.20.1 && <0.23") "memory")))))))))

(define-public ghc-crypton-asn1-types-agent-cat
  (package
    (name "ghc-crypton-asn1-types")
    (version "0.4.1")
    (source (hackage-source "crypton-asn1-types" version
                            "0b9h9qzgs1afq1iiyvjs15z5kh97jjfq74x7jawxvlx0fwwcdvv1"))
    (build-system haskell-build-system)
    (inputs (list ghc-base16 ghc-time-hourglass))
    (arguments (list #:tests? #f))
    (home-page "https://github.com/mpilgrem/crypton-asn1")
    (synopsis "ASN.1 types")
    (description "This package provides types representing ASN.1 values.")
    (license license:bsd-3)))

(define-public ghc-crypton-asn1-encoding-agent-cat
  (package
    (name "ghc-crypton-asn1-encoding")
    (version "0.10.0")
    (source (hackage-source "crypton-asn1-encoding" version
                            "1li6577cpw6dsxacawqc94pba2anj1bnip82h75jixjkw873m0a9"))
    (build-system haskell-build-system)
    (inputs (list ghc-crypton-asn1-types-agent-cat ghc-time-hourglass))
    (arguments (list #:tests? #f))
    (home-page "https://github.com/mpilgrem/crypton-asn1")
    (synopsis "ASN.1 data readers and writers")
    (description "This package reads and writes ASN.1 data in raw, BER, and DER forms.")
    (license license:bsd-3)))

(define-public ghc-crypton-asn1-parse-agent-cat
  (package
    (name "ghc-crypton-asn1-parse")
    (version "0.10.0")
    (source (hackage-source "crypton-asn1-parse" version
                            "1n98fzzc1hx4jfsax83iky5hkyzpavraghl9mns21dzwv1wg5h1m"))
    (build-system haskell-build-system)
    (inputs (list ghc-crypton-asn1-types-agent-cat))
    (arguments (list #:tests? #f))
    (home-page "https://github.com/mpilgrem/crypton-asn1")
    (synopsis "Monadic ASN.1 stream parser")
    (description "This package provides a monadic parser for ASN.1 streams.")
    (license license:bsd-3)))

(define-public ghc-crypton-pem-agent-cat
  (package
    (name "ghc-crypton-pem")
    (version "0.3.0")
    (source (hackage-source "crypton-pem" version
                            "0h05hg2hxsvvg8hjad5l2r5wi9x2nhan9w3k93bsriklpa6apb8z"))
    (build-system haskell-build-system)
    (inputs (list ghc-base64))
    (arguments (list #:tests? #f))
    (home-page "https://github.com/mpilgrem/crypton-pem")
    (synopsis "PEM file format reader and writer")
    (description "This package reads and writes Privacy Enhanced Mail files.")
    (license license:bsd-3)))

(define-public ghc-crypton-x509-agent-cat
  (package
    (inherit ghc-crypton-x509)
    (name "ghc-crypton-x509")
    (version "1.9.1")
    (source (hackage-source "crypton-x509" version
                            "03mw7kdd5x8mc5gw47dk5ywvdnfh38p00lhlgcmmcwl26f8049jm"))
    (inputs (list ghc-memory ghc-time-hourglass ghc-crypton-pem-agent-cat
                  ghc-crypton-asn1-types-agent-cat
                  ghc-crypton-asn1-encoding-agent-cat
                  ghc-crypton-asn1-parse-agent-cat ghc-crypton-agent-cat))
    (arguments
     (list #:tests? #f
           #:phases
           #~(modify-phases %standard-phases
               (add-after 'unpack 'replace-ram-with-memory
                 (lambda _
                   (substitute* "crypton-x509.cabal"
                     (("ram,") "memory,")))))))))

(define-public ghc-crypton-x509-store-agent-cat
  (package
    (inherit ghc-crypton-x509-store)
    (name "ghc-crypton-x509-store")
    (version "1.9.0")
    (source (hackage-source "crypton-x509-store" version
                            "0rl7zdzgfhp1l38pbx44v67gcv3gpr32cf43004zpl8i7i0974fy"))
    (inputs (list ghc-crypton-pem-agent-cat ghc-crypton-asn1-types-agent-cat
                  ghc-crypton-asn1-encoding-agent-cat ghc-crypton-agent-cat
                  ghc-crypton-x509-agent-cat))
    (arguments (list #:tests? #f))))

(define-public ghc-crypton-x509-system-agent-cat
  (package
    (inherit ghc-crypton-x509-system)
    (name "ghc-crypton-x509-system")
    (version "1.9.0")
    (source (hackage-source "crypton-x509-system" version
                            "1znfhsdn9nzdjlmzq92gvzzc1rjbwvi81bfsby95qflng2dq3vl9"))
    (inputs (list ghc-crypton-pem-agent-cat ghc-crypton-x509-agent-cat
                  ghc-crypton-x509-store-agent-cat))
    (arguments (list #:tests? #f))))

(define-public ghc-crypton-x509-validation-agent-cat
  (package
    (inherit ghc-crypton-x509-validation)
    (name "ghc-crypton-x509-validation")
    (version "1.9.1")
    (source (hackage-source "crypton-x509-validation" version
                            "0gffxqvd6h9pj1qafc1sah6adklngy7kwm2cv2agdiql25087jwg"))
    (inputs (list ghc-memory ghc-time-hourglass ghc-data-default
                  ghc-crypton-pem-agent-cat ghc-crypton-asn1-types-agent-cat
                  ghc-crypton-asn1-encoding-agent-cat ghc-crypton-x509-agent-cat
                  ghc-crypton-x509-store-agent-cat ghc-crypton-agent-cat ghc-iproute))
    (arguments
     (list #:tests? #f
           #:phases
           #~(modify-phases %standard-phases
               (add-after 'unpack 'replace-ram-and-patch-san
                 (lambda _
                   (substitute* "crypton-x509-validation.cabal"
                     (("ram,") "memory,"))
                   (invoke "patch" "-p1" "-i"
                           #$(local-file "modules/under-sea/packages/agent-cat-crypton-x509-validation-san.patch")))))))))

(define-public ghc-hpke-agent-cat
  (package
    (name "ghc-hpke")
    (version "0.1.0")
    (source (hackage-source "hpke" version
                            "18kzr2fsar42b3w86mcr3kblihxfq9v9bqcanb9gf5sb6iff000s"))
    (build-system haskell-build-system)
    (inputs (list ghc-base16-bytestring ghc-crypton-agent-cat ghc-memory))
    (arguments
     (list #:tests? #f
           #:phases
           #~(modify-phases %standard-phases
               (add-after 'unpack 'replace-ram-with-memory
                 (lambda _
                   (substitute* "hpke.cabal" (("ram") "memory")))))))
    (home-page "https://github.com/haskell-tls/hs-tls")
    (synopsis "Hybrid public key encryption")
    (description "This package implements HPKE for TLS Encrypted Client Hello.")
    (license license:bsd-3)))

(define-public ghc-ech-config-agent-cat
  (package
    (name "ghc-ech-config")
    (version "0.0.1")
    (source (hackage-source "ech-config" version
                            "1fpynisvv87m0rfdydbvrg4k3nznv33yslb0ny0c518kxbbvcdmj"))
    (build-system haskell-build-system)
    (inputs (list ghc-base16-bytestring ghc-network-byte-order))
    (arguments (list #:tests? #f))
    (home-page "https://github.com/haskell-tls/hs-tls")
    (synopsis "TLS Encrypted Client Hello configuration")
    (description "This package reads and writes TLS ECH configuration lists.")
    (license license:bsd-3)))

(define-public ghc-tls-agent-cat
  (package
    (inherit ghc-tls)
    (name "ghc-tls")
    (version "2.3.0")
    (source (hackage-source "tls" version
                            "1zjnzj12y1mc5l0ibgc549iwasp6wp2azcgv4n0927yjrayd8gx3"))
    (inputs (list ghc-base16-bytestring ghc-cereal ghc-crypton-agent-cat
                  ghc-crypton-asn1-encoding-agent-cat
                  ghc-crypton-asn1-types-agent-cat ghc-crypton-x509-agent-cat
                  ghc-crypton-x509-store-agent-cat
                  ghc-crypton-x509-validation-agent-cat ghc-data-default
                  ghc-ech-config-agent-cat ghc-hpke-agent-cat
                  ghc-network-agent-cat ghc-random ghc-serialise ghc-transformers
                  ghc-unix-time ghc-zlib))
    (arguments
     (list #:tests? #f
           #:phases
           #~(modify-phases %standard-phases
               (add-after 'unpack 'replace-ram-with-memory
                 (lambda _
                   (substitute* "tls.cabal" (("ram,") "memory,")))))))))

(define-public ghc-crypton-connection-agent-cat
  (package
    (inherit ghc-crypton-connection)
    (name "ghc-crypton-connection")
    (version "0.4.6")
    (source (hackage-source "crypton-connection" version
                            "0d20qp4jim89s6psi0iyjwjzgbi4piw9pxyyr15qrshpb22vg1nn"))
    (inputs (list ghc-crypton-socks-agent-cat ghc-network-agent-cat
                  ghc-crypton-x509-store-agent-cat ghc-crypton-x509-system-agent-cat
                  ghc-tls-agent-cat))
    (arguments (list #:tests? #f))))

(define-public ghc-http-client-tls-agent-cat
  (package
    (inherit ghc-http-client-tls)
    (name "ghc-http-client-tls")
    (version "0.4.0")
    (source (hackage-source "http-client-tls" version
                            "0g5fhkfyc0lc2j4v2hkx0d610jqbf44sqkcag2qpnra6y16g2731"))
    (inputs (list ghc-base16-bytestring ghc-cryptohash-md5 ghc-data-default
                  ghc-http-client-agent-cat ghc-crypton-connection-agent-cat ghc-network-agent-cat
                  ghc-tls-agent-cat ghc-case-insensitive ghc-transformers
                  ghc-http-types ghc-exceptions ghc-network-uri))
    (arguments (list #:tests? #f))))

(define-public ghc-crypto-token-agent-cat
  (package
    (inherit ghc-crypto-token)
    (name "ghc-crypto-token")
    (version "0.2.0")
    (source (hackage-source "crypto-token" version
                            "0lp546cklx1sq745q0z8i27i7hqzb8bpyfk5dak43kkddvjlhy80"))
    (inputs (list ghc-crypton-agent-cat ghc-memory ghc-network-byte-order))
    (arguments
     (list #:tests? #f
           #:phases
           #~(modify-phases %standard-phases
               (add-after 'unpack 'replace-ram-with-memory
                 (lambda _
                   (substitute* "crypto-token.cabal" (("ram") "memory")))))))))

(define-public ghc-tls-session-manager-agent-cat
  (package
    (inherit ghc-tls-session-manager)
    (name "ghc-tls-session-manager")
    (version "0.1.0")
    (source (hackage-source "tls-session-manager" version
                            "07mxdw9rh74m7l3z1ibwc490kn093w1xhbdm6qi1qfnkz1b199r9"))
    (inputs (list ghc-auto-update ghc-clock ghc-crypto-token-agent-cat
                  ghc-memory ghc-psqueues ghc-serialise ghc-tls-agent-cat))
    (arguments
     (list #:tests? #f
           #:phases
           #~(modify-phases %standard-phases
               (add-after 'unpack 'replace-ram-with-memory
                 (lambda _
                   (substitute* "tls-session-manager.cabal"
                     (("ram,") "memory,")))))))))

(define-public ghc-time-manager-agent-cat
  (package
    (inherit ghc-time-manager)
    (name "ghc-time-manager")
    (version "0.3.2")
    (source (hackage-source "time-manager" version
                            "069nxlls9mswhf5xab0vnnk921a0q9v5fja72xmk170a00gfqvbp"))
    (inputs (list ghc-auto-update))
    (arguments (list #:tests? #f))))

(define-public ghc-network-run-agent-cat
  (package
    (inherit ghc-network-run)
    (name "ghc-network-run")
    (version "0.5.0")
    (source (hackage-source "network-run" version
                            "0y6wrg1cfl9yi68s6nkyv9dzxficnls73ksqr3a7w7h5jlz68p6y"))
    (inputs (list ghc-network-agent-cat ghc-time-manager-agent-cat))
    (arguments (list #:tests? #f))))

(define-public ghc-http-semantics-agent-cat
  (package
    (inherit ghc-http-semantics)
    (name "ghc-http-semantics")
    (version "0.4.1")
    (source (hackage-source "http-semantics" version
                            "1nskfiwh2x9ss6q99fkdan7fd6l8z8g2sk6f538bmsnmz0fz2bd0"))
    (inputs (list ghc-case-insensitive ghc-http-types ghc-network-byte-order
                  ghc-network-agent-cat ghc-time-manager-agent-cat ghc-utf8-string))
    (arguments (list #:tests? #f))))

(define-public ghc-http2-agent-cat
  (package
    (inherit ghc-http2)
    (name "ghc-http2")
    (version "5.4.4")
    (source (hackage-source "http2" version
                            "1phxg5didylg4mjj5m3zssv4ss5w9mg56k639cr2w01q8llwb9vj"))
    (inputs (list ghc-async ghc-case-insensitive ghc-http-semantics-agent-cat
                  ghc-http-types ghc-iproute-agent-cat ghc-network-agent-cat ghc-network-byte-order
                  ghc-network-control ghc-time-manager-agent-cat ghc-unix-time
                  ghc-utf8-string))
    (native-inputs '())
    (arguments (list #:tests? #f))))

(define-public ghc-wai-agent-cat
  (package
    (inherit ghc-wai)
    (name "ghc-wai")
    (version "3.2.5")
    (source (hackage-source "wai" version
                            "0snl3rvvqziksb21lyssfnrdyi5ixl0j9nw5szw5060s6zsikpbs"))
    (inputs (list ghc-network-agent-cat ghc-http-types ghc-vault))
    (arguments (list #:tests? #f))))

(define-public ghc-warp-agent-cat
  (package
    (inherit ghc-warp)
    (name "ghc-warp")
    (version "3.4.15")
    (source (hackage-source "warp" version
                            "0h9dkiza85bhjn3q3649j5vmqrllix7d665vq8gk53q2qn7hnm43"))
    (inputs (list ghc-auto-update ghc-async ghc-bsb-http-chunked
                  ghc-case-insensitive ghc-crypton-x509-agent-cat ghc-hashable
                  ghc-http-client-agent-cat ghc-http-date ghc-http-types
                  ghc-http2-agent-cat ghc-iproute-agent-cat
                  ghc-network-agent-cat ghc-recv-agent-cat ghc-simple-sendfile-agent-cat ghc-streaming-commons-agent-cat
                  ghc-time-manager-agent-cat ghc-vault ghc-wai-agent-cat ghc-word8))
    (native-inputs '())
    (arguments (list #:tests? #f))))

(define-public ghc-warp-tls-agent-cat
  (package
    (inherit ghc-warp-tls)
    (name "ghc-warp-tls")
    (version "3.4.16")
    (source (hackage-source "warp-tls" version
                            "11is1w21g01yxakgkjh7jdh9v82fpdjn9h4pk4xn304b2kapiha0"))
    (inputs (list ghc-wai-agent-cat ghc-warp-agent-cat ghc-tls-agent-cat
                  ghc-network-agent-cat ghc-streaming-commons-agent-cat
                  ghc-tls-session-manager-agent-cat ghc-recv-agent-cat))
    (arguments (list #:tests? #f))))

(define-public ghc-network-agent-cat
  (package
    (inherit ghc-network)
    (name "ghc-network")
    (version "3.2.11.0")
    (source (hackage-source "network" version
                            "176a321bxh944410qbn5p13phaskkdnrb10w0qslmcyjhgc0r490"))
    (arguments (list #:tests? #f))))

(define-public ghc-crypton-socks-agent-cat
  (package
    (inherit ghc-crypton-socks)
    (name "ghc-crypton-socks")
    (inputs (list ghc-cereal ghc-network-bsd-agent-cat ghc-network-agent-cat))
    (arguments (list #:tests? #f))))

(define-public ghc-simple-sendfile-agent-cat
  (package
    (inherit ghc-simple-sendfile)
    (name "ghc-simple-sendfile")
    (inputs (list ghc-network-agent-cat))
    (arguments (list #:tests? #f))))

(define-public ghc-network-bsd-agent-cat
  (package
    (inherit ghc-network-bsd)
    (name "ghc-network-bsd")
    (inputs (list ghc-network-agent-cat))
    (arguments
     (list #:tests? #f
           #:phases
           #~(modify-phases %standard-phases
               (add-after 'unpack 'relax-obsolete-compiler-bounds
                 (lambda _
                   (substitute* "network-bsd.cabal"
                     (("deepseq >= 1.3.0.0 && < 1.5") "deepseq >= 1.3.0.0 && < 2")
                     (("network >= 3.0.0.0 && < 3.0.1") "network >= 3.0.0.0 && < 4")))))))))

(define-public ghc-iproute-agent-cat
  (package
    (inherit ghc-iproute)
    (name "ghc-iproute")
    (inputs (modify-inputs (package-inputs ghc-iproute)
              (replace "ghc-network" ghc-network-agent-cat)))
    (arguments (list #:tests? #f))))

(define-public ghc-recv-agent-cat
  (package
    (inherit ghc-recv)
    (name "ghc-recv")
    (inputs (list ghc-network-agent-cat))
    (description "A small package providing network receive primitives.")
    (arguments (list #:tests? #f))))

(define-public ghc-streaming-commons-agent-cat
  (package
    (inherit ghc-streaming-commons)
    (name "ghc-streaming-commons")
    (inputs (modify-inputs (package-inputs ghc-streaming-commons)
              (replace "ghc-network" ghc-network-agent-cat)))
    (arguments (list #:tests? #f))))

(define-public ghc-http-client-agent-cat
  (package
    (inherit ghc-http-client)
    (name "ghc-http-client")
    (inputs (modify-inputs (package-inputs ghc-http-client)
              (replace "ghc-network" ghc-network-agent-cat)
              (replace "ghc-iproute" ghc-iproute-agent-cat)
              (replace "ghc-streaming-commons" ghc-streaming-commons-agent-cat)))
    (arguments (list #:tests? #f))))
