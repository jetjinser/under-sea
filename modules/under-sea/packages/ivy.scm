;;; ivy - IVy protocol verification tool and its dependencies that are not
;;; yet in Guix proper.  Python-tarjan and python-z3 are build-time and run
;;; time dependencies of python-ms-ivy; the z3 bindings link against Guix's
;;; own libz3 instead of the bundled sources.

(define-module (under-sea packages ivy)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (under-sea packages ivy-pin)
  #:use-module (guix gexp)
  #:use-module (guix build-system pyproject)
  #:use-module (guix build-system cmake)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages graphviz)
  #:use-module (gnu packages maths)
  #:export (python-tarjan
            python-z3
            python-ms-ivy))

(define-public python-tarjan
  (package
    (name "python-tarjan")
    (version "0.2.4")
    (source
     (origin
       (method url-fetch)
       (uri "https://files.pythonhosted.org/packages/source/t/tarjan/tarjan-0.2.4.tar.gz")
       (sha256
        (base32 "055587l33r4pgsxbi1z418gcjnbsd3r03644n0rmviy8d0rykmx9"))))
    (build-system pyproject-build-system)
    (arguments (list #:tests? #f))
    (native-inputs (list python-setuptools python-wheel))
    (home-page "https://github.com/bwesterb/py-tarjan/")
    (synopsis "Tarjan's algorithm for resolving cyclic dependencies")
    (description
     "Implementation of Tarjan's cycle resolution algorithm operating on an
adjacency table and returning the strongly connected components.")
    (license license:lgpl3)))

(define-public python-ms-ivy
  (package
    (name "python-ms-ivy")
    (version %ivy-version)
    (source %ivy-source)
    (build-system pyproject-build-system)
    (arguments
     (list
      ;; The test suite exercises the C++ backend that is built from the
      ;; picotls/aiger/abc/z3 submodules, which this package does not include.
      #:tests? #f
      #:phases
      #~(modify-phases %standard-phases
          ;; The sanity check loads all console_scripts entry points via
          ;; pkg_resources, which re-imports modules and trips IVy's
          ;; import-time `assert key not in registry' checks.  The toolchain
          ;; is verified by running `ivy_check' on an upstream example
          ;; instead (see README).
          (delete 'sanity-check)
          ;; Guix's z3 installs the Python bindings but not the `z3-solver'
          ;; dist-info, so drop it from install_requires; the module itself
          ;; comes from the propagated z3 package (see python-claripy in
          ;; Guix proper for the same treatment).
          (add-after 'unpack 'relax-requirements
            (lambda _
              (substitute* "setup.py"
                (("^[[:space:]]*'z3-solver'\n")
                 "")))))))
    (native-inputs (list python-setuptools python-wheel))
    (propagated-inputs
     (list (list python "tk")
           python-ply
           python-pyparsing
           python-tarjan
           python-pydot
           python-ordered-set
           z3))
    (home-page "https://github.com/kenmcmil/ivy")
    (synopsis
     "Interactive protocol verification and proof development tool")
    (description
     "IVy is an interactive tool for developing protocols together with proofs
of correctness, providing visualization of automated proofs and a use model in
which the human designer and the automated backend interact to expose errors
and prove theorems.  Verification conditions are discharged with the Z3 SMT
solver.")
    ;; Upstream license.txt is the MIT license (guix calls it Expat).
    (license license:expat)))
