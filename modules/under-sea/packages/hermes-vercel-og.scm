(define-module (under-sea packages hermes-vercel-og)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module (guix gexp)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages python)
  #:use-module (under-sea packages hermes-node)
  #:use-module (under-sea packages hermes-satori)
  #:use-module (under-sea packages hermes-yoga)
  #:use-module (under-sea packages hermes-browser-wasm)
  #:use-module ((guix licenses) #:prefix license:))

(define %noto-ofl
  (origin
    (method url-fetch)
    (uri "https://raw.githubusercontent.com/notofonts/noto-fonts/ffebf8c1ee449e544955a7e813c54f9b73848eac/LICENSE")
    (file-name "noto-fonts-OFL-ffebf8c.txt")
    (sha256
     (base16-string->bytevector
      "0dab92d0544f7b233403f14b84a663bdbfa746982eda629e7f4f9ffe1b036feb"))))

(define-public vercel-og-for-hermes-browser
  (package
    (name "vercel-og-for-hermes-browser")
    (version "0.7.2")
    (source
     (origin
       (method url-fetch)
       (uri "https://registry.npmjs.org/@vercel/og/-/og-0.7.2.tgz")
       (file-name "vercel-og-0.7.2-authored-source-maps.tgz")
       (sha256
        (base16-string->bytevector
         "afa0d18b841f696e5ab85feecbad9a3bf6a79498b34b2d57d4cde4d2d297c70f"))))
    (build-system gnu-build-system)
    (native-inputs (list python-minimal esbuild-for-hermes))
    (inputs (list satori-for-hermes-browser yoga-wasm-web-for-hermes-browser
                  resvg-wasm-for-hermes-browser))
    (arguments
     (list
      #:substitutable? #f
      #:phases
      #~(modify-phases %standard-phases
          (delete 'bootstrap)
          (delete 'configure)
          (delete 'check)
          (replace 'unpack
            (lambda _
              (invoke "python3" #$(local-file "../../../scripts/recover-vercel-og-sources.py")
                      #$(package-source this-package)
                      #$(local-file "../../../planning/hermes-vercel-og-release-identity.json")
                      "og-source")
              (chdir "og-source")))
          (replace 'build
            (lambda _
              (invoke "python3" #$(local-file "../../../scripts/build-hermes-og.py")
                      #$output
                      "--satori" #$(file-append satori-for-hermes-browser "/lib/node_modules/satori")
                      "--resvg" #$(file-append resvg-wasm-for-hermes-browser "/lib/node_modules/@resvg/resvg-wasm")
                      "--yoga" #$(file-append yoga-wasm-web-for-hermes-browser "/lib/node_modules/yoga-wasm-web")
                      "--font-archive" #$(package-source this-package)
                      "--font-license" #$%noto-ofl)))
          (replace 'install (lambda _ #t)))))
    (home-page "https://github.com/vercel/og")
    (synopsis "Source-rebuilt OG Node and Edge bundles with source WASM engines")
    (description "This package authenticates the official 0.7.2 release and
recovers its verbatim first-party TypeScript from source maps, since the published
Git commit archive is unavailable.  It recompiles both Node and Edge bundles with
source-built Satori, resvg and Yoga providers.  Published compiled JavaScript and
WASM are not installed.  The unchanged original Noto font is included as static
data with its OFL text and original copyright.")
    (license (list license:mpl2.0 license:expat license:silofl1.1))))
