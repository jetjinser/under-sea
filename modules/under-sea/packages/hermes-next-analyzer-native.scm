(define-module (under-sea packages hermes-next-analyzer-native)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (under-sea packages hermes-node-native)
  #:use-module ((under-sea packages hermes-next-analyzer-native-lock) #:prefix analyzer:))

(define-public tailwind-oxide-for-hermes-next-analyzer
  (native-binding "tailwind-oxide-for-hermes-next-analyzer" "4.1.13"
                  analyzer:%hermes-tailwind-source analyzer:%hermes-tailwind-crates
                  "tailwind-oxide" "libtailwind_oxide.so"
                  "@tailwindcss/oxide-linux-x64-gnu" license:expat))

(define-public lightningcss-for-hermes-next-analyzer
  (native-binding "lightningcss-for-hermes-next-analyzer" "1.30.1"
                  analyzer:%hermes-lightningcss-source analyzer:%hermes-lightningcss-crates
                  "lightningcss_node" "liblightningcss_node.so"
                  "lightningcss-linux-x64-gnu" license:mpl2.0))
