;;; Exact additional crate sources required by rusty_v8 GN targets.
(define-module (under-sea packages codex-v8-lock)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16))
(define-public %codex-v8-crate-sources
 (list
  (list "either-1.16.0" "91622ff5e7162018101f2fea40d6ebf4a78bbe5a49736a2020649edf9693679e" (origin (method url-fetch) (uri "https://static.crates.io/crates/either/either-1.16.0.crate") (file-name "either-1.16.0.crate") (sha256 (base16-string->bytevector "91622ff5e7162018101f2fea40d6ebf4a78bbe5a49736a2020649edf9693679e"))))
  (list "ixdtf-0.6.5" "2ceaf4c6c48465bead8cb6a0b7c4ee0c86ecbb31239032b9c66ab9a08d2f3ee1" (origin (method url-fetch) (uri "https://static.crates.io/crates/ixdtf/ixdtf-0.6.5.crate") (file-name "ixdtf-0.6.5.crate") (sha256 (base16-string->bytevector "2ceaf4c6c48465bead8cb6a0b7c4ee0c86ecbb31239032b9c66ab9a08d2f3ee1"))))
  (list "litemap-0.8.2" "92daf443525c4cce67b150400bc2316076100ce0b3686209eb8cf3c31612e6f0" (origin (method url-fetch) (uri "https://static.crates.io/crates/litemap/litemap-0.8.2.crate") (file-name "litemap-0.8.2.crate") (sha256 (base16-string->bytevector "92daf443525c4cce67b150400bc2316076100ce0b3686209eb8cf3c31612e6f0"))))
  (list "potential_utf-0.1.5" "0103b1cef7ec0cf76490e969665504990193874ea05c85ff9bab8b911d0a0564" (origin (method url-fetch) (uri "https://static.crates.io/crates/potential_utf/potential_utf-0.1.5.crate") (file-name "potential_utf-0.1.5.crate") (sha256 (base16-string->bytevector "0103b1cef7ec0cf76490e969665504990193874ea05c85ff9bab8b911d0a0564"))))
  (list "unicode-ident-1.0.24" "e6e4313cd5fcd3dad5cafa179702e2b244f760991f45397d14d4ebf38247da75" (origin (method url-fetch) (uri "https://static.crates.io/crates/unicode-ident/unicode-ident-1.0.24.crate") (file-name "unicode-ident-1.0.24.crate") (sha256 (base16-string->bytevector "e6e4313cd5fcd3dad5cafa179702e2b244f760991f45397d14d4ebf38247da75"))))
  (list "writeable-0.6.3" "1ffae5123b2d3fc086436f8834ae3ab053a283cfac8fe0a0b8eaae044768a4c4" (origin (method url-fetch) (uri "https://static.crates.io/crates/writeable/writeable-0.6.3.crate") (file-name "writeable-0.6.3.crate") (sha256 (base16-string->bytevector "1ffae5123b2d3fc086436f8834ae3ab053a283cfac8fe0a0b8eaae044768a4c4"))))
  (list "zerofrom-0.1.8" "0ec05a11813ea801ff6d75110ad09cd0824ddba17dfe17128ea0d5f68e6c5272" (origin (method url-fetch) (uri "https://static.crates.io/crates/zerofrom/zerofrom-0.1.8.crate") (file-name "zerofrom-0.1.8.crate") (sha256 (base16-string->bytevector "0ec05a11813ea801ff6d75110ad09cd0824ddba17dfe17128ea0d5f68e6c5272"))))
  (list "zerofrom-derive-0.1.7" "11532158c46691caf0f2593ea8358fed6bbf68a0315e80aae9bd41fbade684a1" (origin (method url-fetch) (uri "https://static.crates.io/crates/zerofrom-derive/zerofrom-derive-0.1.7.crate") (file-name "zerofrom-derive-0.1.7.crate") (sha256 (base16-string->bytevector "11532158c46691caf0f2593ea8358fed6bbf68a0315e80aae9bd41fbade684a1"))))
 ))
