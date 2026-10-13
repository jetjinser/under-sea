;;; Ghidra software reverse-engineering suite (official prebuilt distribution).
;;;
;;; Upstream builds with Gradle.  A fully offline source build would require
;;; vendoring the whole Gradle plugin/Maven dependency graph plus the external
;;; ghidra.bin repository, which is impractical here (this host's direct access
;;; to GitHub and the Gradle plugin portal is throttled to a few KB/s).  So this
;;; package deploys the official hash-pinned, Apache-2.0 release distribution and
;;; adapts it to Guix: the store interpreter (plus libstdc++/libgcc_s) for the
;;; bundled native helpers, store bash for the launcher scripts, and a pinned
;;; OpenJDK for the launchers.
(define-module (under-sea packages ghidra)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages base)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages java)
  #:use-module (gnu packages python))

(define %ghidra-version "12.1.4")

(define-public ghidra
  (package
    (name "ghidra")
    (version %ghidra-version)
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://github.com/NationalSecurityAgency/ghidra/releases/download/"
             "Ghidra_" version "_build/ghidra_" version "_PUBLIC_20260921.zip"))
       (file-name (string-append "ghidra_" version "_PUBLIC.zip"))
       (sha256
        (base16-string->bytevector
         "ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db"))))
    (build-system gnu-build-system)
    (native-inputs (list patchelf unzip tar gzip xz bzip2
                         coreutils-minimal findutils grep sed))
    (inputs (list (list (specification->package "openjdk@21") "jdk")
                  bash-minimal coreutils-minimal python (list gcc "lib")))
    (arguments
     (list
      #:validate-runpath? #f
      #:modules '((guix build gnu-build-system) (guix build utils)
                  (ice-9 binary-ports) (srfi srfi-13))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (delete 'build)
          (delete 'check)
          (add-after 'install 'check-native
            (lambda _
              ;; A patchelf-corrupted ELF dies with SIGSEGV (shell exit >= 128)
              ;; before loading libraries, which plain analysis does not catch;
              ;; actually run each native helper.
              (define (run-ok? rel)
                (let ((f (string-append #$output "/libexec/ghidra/" rel)))
                  (and (file-exists? f)
                       (let ((st (system* "bash" "-c"
                                          (string-append "'" f "' </dev/null >/dev/null 2>&1"))))
                         (and (status:exit-val st)
                              (< (status:exit-val st) 128))))))
              (for-each
               (lambda (rel)
                 (unless (run-ok? rel)
                   (error "native helper crashed (SIGSEGV?):" rel)))
               '("Ghidra/Features/Decompiler/os/linux_x86_64/decompile"
                 "Ghidra/Features/Decompiler/os/linux_x86_64/sleigh"
                 "GPL/DemanglerGnu/os/linux_x86_64/demangler_gnu_v2_24"
                 "GPL/DemanglerGnu/os/linux_x86_64/demangler_gnu_v2_41"
                 "Ghidra/Features/FileFormats/os/linux_x86_64/lzfse"))))
          (replace 'install
             (lambda* (#:key inputs outputs #:allow-other-keys)
              (define (elf-file? file)
                (catch #t
                  (lambda ()
                    (call-with-input-file file
                      (lambda (port)
                        (equal? (get-bytevector-n port 4) #vu8(127 69 76 70)))))
                  (lambda _ #f)))
              (let* ((out #$output)
                     ;; Ghidra's LaunchSupport requires a full JDK (javac), not
                     ;; just the JRE; use the openjdk "jdk" output.
                     (jdk (dirname (dirname (search-input-file inputs "bin/javac"))))
                     (py #$(this-package-input "python"))
                     (bash #$(file-append bash-minimal "/bin/bash"))
                     (core (dirname (search-input-file inputs "bin/readlink")))
                     (loader #$(file-append glibc "/lib/ld-linux-x86-64.so.2"))
                     (glibc-lib #$(file-append glibc "/lib"))
                     (gcc-lib (dirname (search-input-file inputs "lib/libstdc++.so.6")))
                     ;; %standard-phases' unpack enters the sole top directory.
                     (root (getcwd))
                     (install (string-append out "/libexec/ghidra")))
                (copy-recursively root install)
                ;; Zip entries are read-only; make the tree writable so the
                ;; shebang patching and wrapping below can modify it.
                (invoke "chmod" "-R" "u+w" install)

                ;; The launchers and helpers start with #!/usr/bin/env bash or
                ;; #!/bin/bash, neither of which exists on Guix.
                (for-each (lambda (f)
                            (catch #t (lambda () (patch-shebang f)) (lambda _ #t)))
                          (find-files install ".*"))

                ;; patchelf rewrites these two native helpers' ELF segments and
                ;; corrupts them: they SIGSEGV before loading any library.  Keep
                ;; pristine copies and exec them through the store loader, which
                ;; is equivalent to a patched interpreter+rpath.
                (let ((ddir (string-append install
                                           "/Ghidra/Features/Decompiler/os/linux_x86_64")))
                  (for-each
                   (lambda (name)
                     (let ((real (string-append ddir "/" name))
                           (orig (string-append ddir "/" name ".orig")))
                       (when (file-exists? real)
                         (copy-file real orig)
                         (delete-file real)
                         (call-with-output-file real
                           (lambda (port)
                             (display (string-append
                                       "#!" bash "\n"
                                       "exec " loader " --library-path "
                                       gcc-lib ":" glibc-lib " "
                                       orig " \"$@\"\n")
                                      port)))
                         (chmod real #o555))))
                   '("decompile" "sleigh")))

                ;; The remaining native helpers (demanglers, lzfse) tolerate
                ;; patchelf; point them at the store loader and libstdc++/
                ;; libgcc_s (from gcc:lib).  Skip the pristine .orig copies.
                (for-each
                 (lambda (f)
                   (when (and (elf-file? f)
                              (not (string-suffix? ".orig" f))
                              (zero? (status:exit-val
                                      (system* "patchelf" "--print-interpreter" f))))
                     (invoke "patchelf" "--set-interpreter" loader
                             "--set-rpath" (string-append gcc-lib ":" glibc-lib)
                             f)))
                 (find-files install ".*"))

                ;; Pin the JDK so the launcher does not search and does not try
                ;; to rewrite launch.properties inside the read-only store.
                (substitute* (string-append install "/support/launch.properties")
                  (("^JAVA_HOME_OVERRIDE=.*")
                   (string-append "JAVA_HOME_OVERRIDE=" jdk "\n")))

                (mkdir-p (string-append out "/bin"))
                ;; Entry points: ghidraRun at the root, the rest under support/.
                ;; Generate small wrappers (wrap-program's hard link is refused
                ;; in this sandbox); they exec the real script, whose
                ;; "readlink -f $0" then resolves support/ next to libexec.
                (for-each
                 (lambda (entry)
                   (let* ((rel (car entry))
                          (names (cdr entry)))
                     (for-each
                      (lambda (name)
                        (let ((f (string-append install "/" rel name)))
                          (when (file-exists? f)
                            (let ((wrapper (string-append out "/bin/" name)))
                              (call-with-output-file wrapper
                                (lambda (port)
                                  (display (string-append
                                            "#!" bash "\n"
                                            "export JAVA_HOME=" jdk "\n"
                                            "export PATH=" jdk "/bin:"
                                            py "/bin:" core "/bin:$PATH\n"
                                            "exec " f " \"$@\"\n")
                                           port)))
                              (chmod wrapper #o555)))))
                      names)))
                 '(("" "ghidraRun")
                   ("support/" "ghidraClean" "ghidraDebug" "GhidraGo"
                    "analyzeHeadless" "bsim" "bsim_ctl" "buildGhidraJar"
                    "pyghidraRun")))))))))
    (supported-systems '("x86_64-linux"))
    (properties '((max-silent-time . 7200)))
    (home-page "https://github.com/NationalSecurityAgency/ghidra")
    (synopsis "Software reverse engineering (SRE) suite")
    (description "Ghidra is a software reverse engineering framework that
includes a decompiler, a disassembler and a large collection of analysis and
scripting tools.  This package deploys the official upstream release
distribution and adapts its launchers and native helpers to Guix.")
    (license license:asl2.0)))
