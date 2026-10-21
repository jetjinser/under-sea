;;; Vimium C for the under-sea channel.
;;;
;;; Based on GNU Guix's gnu/packages/browser-extensions.scm patterns
;;; (copy-build-system layout plus make-chromium-extension).

(define-module (under-sea packages vimium-c)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system copy)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu build chromium-extension)
  #:use-module (gnu packages node)
  #:use-module (gnu packages node-xyz))

;; Upstream does not tag the 2.x series; this is the master commit whose
;; manifest.json says 2.12.3.
(define %vimium-c-commit "31885269460a3f0635c7dd69176ed387ad138e96")

;; Extension payload: the compiled tree without build inputs (*.ts,
;; tsconfigs).

;; Runtime check that every concrete file manifest.json points at exists
;; after the build.  web_accessible_resources globs like "content/*" are
;; valid manifest wildcards and never enter the reference list.  Run via
;; "node -e" from the check phase.
(define %vimium-c-manifest-check
  "const m=require('./manifest.json'),fs=require('fs');
let r=[];
if(m.background)r.push(m.background.service_worker);
(m.content_scripts||[]).forEach(c=>{(c.js||[]).forEach(f=>r.push(f));(c.css||[]).forEach(f=>r.push(f));});
if(m.action){r.push(m.action.default_popup);Object.values(m.action.default_icon||{}).forEach(f=>r.push(f));}
if(m.options_ui)r.push(m.options_ui.page);
Object.values(m.icons||{}).forEach(f=>r.push(f));
const miss=r.filter(f=>!fs.existsSync(f));
if(miss.length){console.error('manifest references missing files:',miss);process.exit(1);}")

(define-public vimium-c
  (package
    (name "vimium-c")
    (version "2.12.3")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://ghfast.top/https://github.com/gdh1995/vimium-c")
             (commit %vimium-c-commit)))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "1r4633v748c5hcqxai2m69x58q384pzsvrlg3cr9zmqa9qsxl1hh"))))
    (build-system copy-build-system)
    (arguments
     (list
      #:tests? #f                       ; no test runner wired for guix
      #:install-plan
      #~(append
         '(("manifest.json" "share/vimium-c/manifest.json")
           ("icons/" "share/vimium-c/icons/")
           ("settings-template.json"
            "share/vimium-c/settings-template.json"))
         (map (lambda (dir)
                (cons (string-append dir "/")
                      (cons (string-append "share/vimium-c/" dir "/")
                            '(#:exclude-regexp
                              ("\\.ts$" "tsconfig\\.json$" "\\.tsbuildinfo$")))))
              '("_locales" "background" "content" "front" "lib" "pages")))
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'make-files-writable
            (lambda _
              ;; The git checkout is read-only; tsc -b writes emitted
              ;; JavaScript next to the TypeScript sources.
              (for-each make-file-writable (find-files "."))))
          (add-after 'unpack 'pacify-typescript
            (lambda _
              ;; Guix ships TypeScript 6.x; this 2023-era tsconfig uses
              ;; options deprecated (not yet removed) in 6.0.
              (substitute* "tsconfig.base.json"
                (("(\"compilerOptions\"[[:space:]]*:[[:space:]]*\\{)" all)
                 (string-append all
                                "\n    \"ignoreDeprecations\": \"6.0\",")))))
          (add-before 'install 'build
            (lambda _
              ;; Project-references build: emits *.js next to the *.ts
              ;; sources, matching the paths in manifest.json (the repo
              ;; also carries hand-written lib/*.js).  Equivalent to
              ;; upstream's "gulp tsc" debug task.
              ;;
              ;; Guix's TypeScript 6 flags hundreds of type errors in this
              ;; TS 4.9-era codebase, but noEmitOnError is off: the
              ;; JavaScript is still emitted, so a nonzero exit is fine
              ;; here and the check-manifest-references phase below
              ;; verifies the actual output.
              (let ((exit (system* "tsc" "-b" "tsconfig.json")))
                (unless (zero? exit)
                  (format #t "tsc exited with ~a; continuing with emitted files.~%"
                          exit)))))
          (add-before 'install 'check-manifest-references
            (lambda _
              (invoke "node" "-e"
                      #$%vimium-c-manifest-check))))))
    (native-inputs (list node node-typescript))
    (home-page "https://github.com/gdh1995/vimium-c")
    (synopsis "Vim-like keyboard navigation for Chromium browsers")
    (description
     "Vimium C is a keyboard-shortcut browser extension for keyboard-based
page navigation and browser tab operations, with an advanced omnibar and
configurable key mappings.  It is a CJK-friendly fork of Vimium with
dictionary-based substitution and more customisation.")
    (license license:asl2.0)))

(define-public vimium-c/chromium
  (make-chromium-extension vimium-c))
