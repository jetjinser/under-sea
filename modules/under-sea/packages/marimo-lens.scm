;;; Dependencies for marimo's AI/lens extra.  These are pure-Python packages
;;; except psygnal, whose optional C extension is not required for anywidget.

(define-module (under-sea packages marimo-lens)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix base16)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system pyproject)
  #:use-module (gnu packages jupyter)
  #:use-module (gnu packages build-tools)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-xyz)
  #:export (python-psygnal
            python-anywidget
            python-agent-plugins
            marimo-lens))

(define-public python-psygnal
  (package
    (name "python-psygnal")
    (version "0.16.1")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://files.pythonhosted.org/packages/75/df/"
             "2a94607af05d91638646339acfc02d7c865821c21356ddcfef3d6b4c7fb6/"
             "psygnal-" version ".tar.gz"))
       (sha256
        (base16-string->bytevector
         "8e30df5e8f2a927191afacd22653924ba5ec54ca00f965f4af3ed38e37b727a9"))))
    (build-system pyproject-build-system)
    (native-inputs (list python-hatchling python-hatch-vcs))
    (arguments (list #:tests? #f))
    (home-page "https://github.com/pyapp-kit/psygnal")
    (synopsis "Python signal/event dispatcher")
    (description "psygnal provides a pure-Python event/signal dispatcher with
optional compiled acceleration.")
    (license license:bsd-3)))

(define-public python-anywidget
  (package
    (name "python-anywidget")
    (version "0.11.0")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://files.pythonhosted.org/packages/79/31/"
             "0491d707c674b34267f55d96d6a7148e55e7b6718a271686232cf295fbe2/"
             "anywidget-" version ".tar.gz"))
       (sha256
        (base16-string->bytevector
         "6695fbef9449cf8c27f421b96c5837aa37f909ec1f60cfa33add333e1b70b169"))))
    (build-system pyproject-build-system)
    (native-inputs (list python-hatchling python-hatch-jupyter-builder))
    (propagated-inputs (list python-ipywidgets
                             python-psygnal
                             python-typing-extensions))
    (arguments (list #:tests? #f))
    (home-page "https://github.com/manzt/anywidget")
    (synopsis "Custom Jupyter widgets from Python")
    (description "anywidget lets you create custom Jupyter widgets with plain
Python and JavaScript files.")
    (license license:expat)))


(define-public python-agent-plugins
  (package
    (name "python-agent-plugins")
    (version "0.2.4")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://files.pythonhosted.org/packages/73/a7/"
             "f0a0f42623958323c466f8208793d500642e3653440cc43676a021f97c94/"
             "agent_plugins-" version ".tar.gz"))
       (sha256
        (base16-string->bytevector
         "cde29a40ba26dfa0fe7a978d18abb2cb724168efefb03423fcae93b06258c4bf"))))
    (build-system pyproject-build-system)
    (native-inputs (list python-uv-build))
    (arguments
     (list
      #:tests? #f
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'relax-uv-build
            (lambda _
              ;; Guix's uv-build is slightly older than the exact pin.
              (substitute* "pyproject.toml"
                (("uv_build==0\\.12\\.2") "uv_build>=0.11.25")))))))
    (home-page "https://github.com/peter-gy/agent-plugins")
    (synopsis "Ship agent plugins with Python packages")
    (description "agent-plugins discovers, reads and packages agent plugin
directories and provides the build backends used by marimo-lens.")
    (license license:asl2.0)))

(define-public marimo-lens
  (package
    (name "marimo-lens")
    (version "0.2.4")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://files.pythonhosted.org/packages/2d/1d/"
             "3bc7ce08070794c8b83d89f3872b269c29cfd8a0f89c9f448a32b637c018/"
             "marimo_lens-" version ".tar.gz"))
       (sha256
        (base16-string->bytevector
         "79e1498b2d1ec706591391d2f851b84cdd94f4573169f96d2fb2d2808336c418"))))
    (build-system pyproject-build-system)
    (native-inputs (list python-hatchling python-agent-plugins))
    (propagated-inputs (list python-agent-plugins
                             python-anywidget
                             python-pydantic
                             python-traitlets
                             python-typing-extensions))
    (arguments (list #:tests? #f))
    (home-page "https://github.com/marimo-team/marimo-lens")
    (synopsis "Ground agent work in marimo notebook context")
    (description "marimo-lens connects an agent's work to the code and context
behind a selected marimo notebook output.  Install it alongside marimo; this
package intentionally does not propagate marimo to avoid a package cycle.")
    (license license:asl2.0)))
