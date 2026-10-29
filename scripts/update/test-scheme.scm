#!/usr/bin/env guile
!#
(use-modules (common)
             (srfi srfi-64))

(test-begin "update-scheme")

(test-equal "manifest package count" 26 (length (manifest-packages)))
(test-equal "marimo current version" "0.25.2"
            (current-version (assoc-ref (manifest-packages) "marimo")))
(test-assert "audit is clean" (null? (assoc-ref (audit-report) 'errors)))
(test-equal "tag selection" "v2.1.4"
            (select-tag '("v1.19.4" "v2.1.4" "v2.0.0") "^v2\\."))
(test-assert "version ordering" (version< "1.9.0" "1.10.0"))
(test-equal "tag version" "14.0.9"
            (tag-version "v14.0.9-server" "^v([0-9.]+)-server$"))
(test-equal "coverage inventory" 44
            (assoc-ref (coverage-report) 'inventory))
(let* ((pkg '(("pin_module" . "demo-pin")
              ("version_symbol" . "%demo-version")
              ("source_symbol" . "%demo-source")
              ("hash_format" . "base32")))
       (text (render-pin pkg "1.2.3" "https://example.invalid/demo.tgz"
                         "demo.tgz" "abc")))
  (test-assert "pin module" (string-contains text "demo-pin"))
  (test-assert "pin version" (string-contains text "%demo-version \"1.2.3\""))
  (test-assert "pin hash" (string-contains text "(base32 \"abc\")")))

(test-end "update-scheme")
