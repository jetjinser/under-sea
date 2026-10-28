;;; A small, self-contained pydantic-ai stack for the marimo AI extras.
;;; pydantic-ai 2.61 uses the newer httpx2/httpcore2 stack, provided by the
;;; sibling (under-sea packages httpx2) module.

(define-module (under-sea packages pydantic-ai)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system pyproject)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-web)
  #:use-module (gnu packages python-xyz)
  #:use-module (under-sea packages hermes-build-tools)
  #:use-module (under-sea packages python-uv)
  #:use-module (under-sea packages httpx2)
  #:export (python-logfire-api
            python-genai-prices
            python-griffelib
            python-pydantic-graph
            python-pydantic-ai-slim))

(define-public python-logfire-api
  (package
    (name "python-logfire-api")
    (version "5.4.0")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://files.pythonhosted.org/packages/10/3e/"
             "065cbc78fbfdbf96194833522c6a9a3677c67c6e66987b226eccbf0e0d0b/"
             "logfire_api-" version ".tar.gz"))
       (sha256
        (base32 "1ls35jk6l1bzf47y92yvgc8sj4xz3r95ikrraf3mbvdcdsp3z2rj"))))
    (build-system pyproject-build-system)
    (arguments '(#:tests? #f))
    (native-inputs (list python-hatchling))
    (home-page "https://github.com/pydantic/logfire")
    (synopsis "No-op OpenTelemetry API for the logfire SDK")
    (description "logfire-api provides the API surface used by libraries that
optionally emit logfire/OpenTelemetry traces without depending on the full
logfire SDK.")
    (license license:expat)))

(define-public python-genai-prices
  (package
    (name "python-genai-prices")
    (version "0.1.13")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://files.pythonhosted.org/packages/ad/de/"
             "119c7ba00b9ddbf629de34cf390ab472da6d7bc5df0c51cdbec900280a74/"
             "genai_prices-" version ".tar.gz"))
       (sha256
        (base32 "1153wfjaybsiw5vw90r2x9142f4i8my2jqn57ggsrz8p77fy5jbn"))))
    (build-system pyproject-build-system)
    (arguments (uv-dynamic-version-arguments "0.1.13"))
    (native-inputs (list python-hatchling
                         python-hermes-uv-dynamic-versioning))
    (propagated-inputs (list python-httpx2-2.16 python-pydantic))
    (home-page "https://github.com/pydantic/genai-prices")
    (synopsis "Model pricing data for generative AI APIs")
    (description "genai-prices provides a small, typed interface to model
pricing metadata used by pydantic-ai.")
    (license license:expat)))

(define-public python-griffelib
  (package
    (name "python-griffelib")
    (version "2.4.1")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://files.pythonhosted.org/packages/36/e2/"
             "0f5d8ed08766bc6dcd3eebf5a6623d83cbca33a6e4c90aef57156ce745ad/"
             "griffelib-" version ".tar.gz"))
       (sha256
        (base32 "1zq72hzdfd056yd26s0k9z7z2n1ialy1xqgh4d24cgv25vfjih20"))))
    (build-system pyproject-build-system)
    (arguments (uv-dynamic-version-arguments "2.4.1"))
    (native-inputs (list python-hatchling
                         python-pdm-backend
                         python-hermes-uv-dynamic-versioning))
    (home-page "https://github.com/griffe/griffelib")
    (synopsis "API compatibility analysis library")
    (description "griffelib detects breaking changes in Python APIs and is
used by pydantic-ai's compatibility tooling.")
    (license license:isc)))

(define-public python-pydantic-graph
  (package
    (name "python-pydantic-graph")
    (version "2.61.0")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://files.pythonhosted.org/packages/f8/45/"
             "c48137400dffe74ab0a414adb3596493890a376e96d96b5508aad80ff929/"
             "pydantic_graph-" version ".tar.gz"))
       (sha256
        (base32 "0bbmhil9i9nqisklvdbylk647i0dkf75lxibxy8brn4q743kms9h"))))
    (build-system pyproject-build-system)
    (arguments (uv-dynamic-version-arguments "2.61.0"))
    (native-inputs (list python-hatchling
                         python-hermes-uv-dynamic-versioning))
    (propagated-inputs (list python-anyio
                             python-httpx
                             python-logfire-api
                             python-pydantic
                             python-typing-inspection))
    (home-page "https://github.com/pydantic/pydantic-ai")
    (synopsis "Graph execution engine for pydantic-ai")
    (description "pydantic-graph implements the typed graph execution model
used by pydantic-ai agents.")
    (license license:expat)))

(define-public python-pydantic-ai-slim
  (package
    (name "python-pydantic-ai-slim")
    (version "2.61.0")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://files.pythonhosted.org/packages/cc/c9/"
             "a50232708b51eea19100fa515ebf2f4bcf92d1110c0cba0abd0aa1117ec6/"
             "pydantic_ai_slim-" version ".tar.gz"))
       (sha256
        (base32 "1wmq6kmvch93xnkrnqws7x16cf15v1mw9m5w0bhs2p66p1zln4zy"))))
    (build-system pyproject-build-system)
    (arguments (uv-dynamic-version-arguments "2.61.0"))
    (native-inputs (list python-hatchling
                         python-hermes-uv-dynamic-versioning))
    (propagated-inputs (list python-anyio
                             python-genai-prices
                             python-griffelib
                             python-httpx2-2.16
                             python-opentelemetry-api
                             python-pydantic
                             python-pydantic-graph
                             python-typing-inspection))
    (home-page "https://github.com/pydantic/pydantic-ai")
    (synopsis "Slim pydantic-ai agent framework")
    (description "pydantic-ai-slim is the provider-independent core of the
pydantic-ai agent framework.  Model-provider extras are intentionally not
included; the marimo AI context extension uses it as a library.")
    (license license:expat)))
