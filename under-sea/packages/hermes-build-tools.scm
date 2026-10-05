;;; Source-built build plugins required by the locked Hermes components.
(define-module (under-sea packages hermes-build-tools)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system pyproject)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-xyz))

(define-public python-hermes-uv-dynamic-versioning
  (package
    (name "python-hermes-uv-dynamic-versioning")
    (version "0.8.2")
    (source
     (origin
       (method url-fetch)
       (uri "https://files.pythonhosted.org/packages/9a/9e/1cf1ddf02e5459076b6fe0e90e1315df461b94c0db6c09b07e5730a0e0fb/uv_dynamic_versioning-0.8.2.tar.gz")
       (sha256 (base16-string->bytevector "a9c228a46f5752d99cfead1ed83b40628385cbfb537179488d280853c786bf82"))))
    (build-system pyproject-build-system)
    (arguments '(#:tests? #f))
    (native-inputs (list python-hatchling))
    (propagated-inputs (list python-dunamai python-hatchling python-jinja2
                             python-pydantic python-tomlkit))
    (home-page "https://github.com/ninoseki/uv-dynamic-versioning")
    (synopsis "Dynamic version build plugin for Hermes dependencies")
    (description "This Hatch plugin derives package versions from VCS metadata
and supports the published source archives used by Hermes dependencies.")
    (license license:expat)))

(define-public python-hermes-hatch-teams-build
  (package
    (name "python-hermes-hatch-teams-build")
    (version "0.1.0")
    (source
     (origin
       (method url-fetch)
       (uri "https://codeload.github.com/microsoft/teams.py/tar.gz/d4c86b1c65113c27de0356d6a2447661a24123cc")
       (file-name "teams-python-d4c86b1.tar.gz")
       (sha256 (base16-string->bytevector
                "53b44a312b66a188678c7f3d25702a608691180647622ec56ebbc4f3e4198357"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:tests? #f
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'enter-plugin
            (lambda _
              (chdir "tools/hatch-teams-build")
              ;; Source releases have an authoritative locked version but no
              ;; Git history. Do not invoke nbgv or silently emit 0.0.0.
              (substitute* "src/hatch_teams_build/version_source.py"
                (("        try:")
                 (string-append
                  "        fixed = os.environ.get('GUIX_PROJECT_VERSION')\n"
                  "        if fixed:\n"
                  "            return {'version': _normalize_version(fixed)}\n"
                  "        try:"))))))))
    (native-inputs (list python-hatchling))
    (propagated-inputs (list python-hatchling python-packaging))
    (home-page "https://github.com/microsoft/teams.py")
    (synopsis "Hatch build plugin for Microsoft Teams SDK")
    (description "This plugin provides version and workspace dependency metadata
for the Teams SDK.  Guix builds can supply the authoritative source release
version without requiring Git history or the .NET versioning tool.")
    (license license:expat)))

(define-public python-hermes-coherent-licensed
  (package
    (name "python-hermes-coherent-licensed")
    (version "0.5.2")
    (source
     (origin
       (method url-fetch)
       (uri "https://files.pythonhosted.org/packages/cd/e9/63d2dcccb5496cc99d96f29a8a5f3e2c6ed0bba7fedb840862f92816ee17/coherent_licensed-0.5.2.tar.gz")
       (sha256 (base16-string->bytevector "d8071403ce742d3ac3592ddc4fb7057a46caffb415b928b4d52802e5f208416d"))))
    (build-system pyproject-build-system)
    (arguments '(#:tests? #f))
    (native-inputs (list python-flit-core))
    (home-page "https://github.com/coherent-oss/coherent.licensed")
    (synopsis "License metadata build plugin")
    (description "Coherent Licensed supplies the setuptools license metadata
plugin required when building Hermes's locked importlib dependencies.")
    (license license:expat)))
