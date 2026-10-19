;;; Helium browser for the under-sea channel.
;;;
;;; Helium variant of GNU Guix's gnu/packages/chromium.scm
;;; (ungoogled-chromium): the ungoogler slot carries imputnet/helium plus
;;; imputnet/helium-linux, and the source assembly gained helium's name
;;; substitution, i18n, version stamping and resource replacement steps.
;;;
;;; Unlike ungoogled-chromium, the source is assembled from imputnet's
;;; prepared tarballs (see %chromium-base-tarball-origin below) instead
;;; of Google's -lite tarball, and the pipeline mirrors
;;; imputnet/helium-linux scripts/shared.sh plus nixpkgs#498572.
;;;
;;; Copyright © 2019-2023 Marius Bakke <marius@gnu.org>
;;; Copyright © 2019 Alex Griffin <a@ajgrf.com>
;;; Copyright © 2023 Andreas Enge <andreas@enge.fr>
;;; Copyright © 2023 Nicolas Graves <ngraves@ngraves.fr>
;;; Copyright © 2025 Maxim Cournoyer <maxim@guixotic.coop>
;;; Copyright © 2025 Andre Batista <nandre@riseup.net>
;;;
;;; This file is part of GNU Guix.
;;;
;;; GNU Guix is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; GNU Guix is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Guix.  If not, see <http://www.gnu.org/licenses/>.

(define-module (under-sea packages helium)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix utils)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system trivial)
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages bison)
  #:use-module (gnu packages build-tools)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages crypto)
  #:use-module (gnu packages cups)
  #:use-module (gnu packages curl)
  #:use-module (gnu packages fontutils)
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages ghostscript)
  #:use-module (gnu packages gl)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages gperf)
  #:use-module (gnu packages golang)
  #:use-module (gnu packages gtk)
  #:use-module (gnu packages icu4c)
  #:use-module (gnu packages image)
  #:use-module (gnu packages libffi)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages llvm)
  #:use-module (gnu packages kerberos)
  #:use-module (gnu packages maths)
  #:use-module (gnu packages node)
  #:use-module (gnu packages nss)
  #:use-module (gnu packages pciutils)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages pulseaudio)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-web)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages qt)
  #:use-module (gnu packages rust)
  #:use-module (gnu packages rust-apps)
  #:use-module (gnu packages serialization)
  #:use-module (gnu packages speech)
  #:use-module (gnu packages valgrind)
  #:use-module (gnu packages vulkan)
  #:use-module (gnu packages video)
  #:use-module (gnu packages xdisorg)
  #:use-module (gnu packages xiph)
  #:use-module (gnu packages xml)
  #:use-module (gnu packages xorg)
  #:use-module (ice-9 match))

;; Anchor for local-file references next to this module.
(define %source-directory (dirname (current-filename)))

;; Kept for reference: this is the Guix-side list of third_party paths to
;; preserve when pruning bundled libraries.  The prune itself is skipped
;; in the source snippet below (see the "guix note" there).
(define %preserved-third-party-files
  '("base/third_party/cityhash" ;Expat
    "base/third_party/double_conversion" ;BSD-3
    "base/third_party/icu" ;Unicode, X11-style
    "base/third_party/superfasthash" ;BSD-3
    "base/third_party/symbolize" ;BSD-3
    "base/third_party/xdg_user_dirs" ;Expat
    "third_party/typescript" ;DevTools build scripts (typescript.py)
    "third_party/ublock" ;Helium deps: uBlock0.chromium sources
    "third_party/search_engines_data" ;Helium deps: search engine resources
    "third_party/rust-toolchain" ;bundled rustc/stdlib/crubit build inputs
    "third_party/devtools-frontend" ;DevTools sources, protocol defs
    ;; remove_bundled_libraries.py ignores exclusions that lie entirely
    ;; before the RIGHT-MOST third_party component; devtools has its own
    ;; nested third_party, so these need the longer prefix to stick.
    "third_party/devtools-frontend/src/third_party/esbuild"
    "third_party/devtools-frontend/src/third_party/blink"
    "net/third_party/mozilla_security_manager" ;MPL-1.1/GPL2+/LGPL2.1+
    "net/third_party/quiche" ;BSD-3
    "net/third_party/uri_template" ;ASL2.0
    "third_party/abseil-cpp" ;ASL2.0
    "third_party/angle" ;BSD-3
    "third_party/angle/src/common/third_party/xxhash" ;BSD-2
    "third_party/angle/src/third_party/ceval" ;Expat
    "third_party/angle/src/third_party/libXNVCtrl" ;Expat
    "third_party/angle/src/third_party/volk" ;Expat
    "third_party/anonymous_tokens" ;ASL2.0
    "third_party/apple_apsl" ;APSL2.0
    "third_party/axe-core" ;MPL2.0
    "third_party/bidimapper" ;ASL2.0
    "third_party/blink" ;BSD-3, LGPL2+
    "third_party/boringssl" ;OpenSSL/ISC (Google additions are ISC)
    "third_party/boringssl/src/third_party/fiat" ;Expat
    "third_party/breakpad" ;BSD-3
    "third_party/catapult" ;BSD-3
    "third_party/catapult/common/py_vulcanize/third_party/rcssmin" ;ASL2.0
    "third_party/catapult/common/py_vulcanize/third_party/rjsmin" ;ASL2.0
    "third_party/catapult/third_party/beautifulsoup4-4.9.3" ;Expat
    "third_party/catapult/third_party/html5lib-1.1" ;Expat
    "third_party/catapult/third_party/polymer" ;BSD-3
    "third_party/catapult/third_party/six" ;Expat
    "third_party/catapult/third_party/typ" ;ASL2.0
    ;; XXX: This is a minified version of <https://d3js.org/>.
    "third_party/catapult/tracing/third_party/d3" ;BSD-3
    "third_party/catapult/tracing/third_party/gl-matrix" ;Expat
    "third_party/catapult/tracing/third_party/jpeg-js" ;ASL2.0
    ;; XXX: Minified version of <https://github.com/Stuk/jszip>.
    "third_party/catapult/tracing/third_party/jszip" ;Expat or GPL3
    "third_party/catapult/tracing/third_party/mannwhitneyu" ;Expat
    "third_party/catapult/tracing/third_party/oboe" ;BSD-2
    ;; XXX: Minified version of <https://github.com/nodeca/pako>.
    "third_party/catapult/tracing/third_party/pako" ;Expat
    "third_party/ced" ;BSD-3
    "third_party/cld_3" ;ASL2.0
    "third_party/closure_compiler" ;ASL2.0
    "third_party/compiler-rt" ;ASL2.0
    "third_party/content_analysis_sdk" ;BSD-3
    "third_party/cpuinfo" ;BSD-2
    "third_party/crabbyavif" ;ASL2.0
    "third_party/crashpad" ;ASL2.0
    "third_party/crashpad/crashpad/third_party/lss" ;ASL2.0
    "third_party/crashpad/crashpad/third_party/zlib" ;Zlib
    "third_party/cros_system_api" ;BSD-3
    "third_party/dawn" ;ASL2.0
    ;; TODO: can likely be unbundled when Vulkan is updated.
    "third_party/dawn/third_party/EGL-Registry/src/sdk" ; ASL2.0
    "third_party/dawn/third_party/OpenGL-Registry" ;ASL2.0
    "third_party/dawn/third_party/gn/webgpu-cts" ;BSD-3
    "third_party/dawn/third_party/renderdoc" ;Expat
    "third_party/dawn/third_party/webgpu-headers" ;BSD-3
    "third_party/depot_tools" ;BSD-3
    "third_party/devscripts" ;GPL2.0
    "third_party/devtools-frontend" ;BSD-3
    "third_party/devtools-frontend/src/front_end"
    "third_party/devtools-frontend/src/front_end/third_party"
    "third_party/devtools-frontend/src/front_end/third_party/acorn" ;Expat
    "third_party/devtools-frontend/src/front_end/third_party\
/additional_readme_paths.json" ;no explicit license; trivial
    "third_party/devtools-frontend/src/front_end/third_party/axe-core" ;MPL2.0
    "third_party/devtools-frontend/src/front_end/third_party/chromium" ;BSD-3
    "third_party/devtools-frontend/src/front_end/third_party/codemirror" ;Expat
    "third_party/devtools-frontend/src/front_end/third_party/csp_evaluator" ;BSD-3
    "third_party/devtools-frontend/src/front_end/third_party/diff" ;ASL2.0
    "third_party/devtools-frontend/src/front_end/third_party/i18n" ;ASL2.0
    "third_party/devtools-frontend/src/front_end/third_party/intl-messageformat" ;BSD-3
    "third_party/devtools-frontend/src/front_end/third_party/json5" ;Expat
    "third_party/devtools-frontend/src/front_end/third_party/legacy-javascript" ;ASL-2.0
    "third_party/devtools-frontend/src/front_end/third_party/lighthouse" ;ASL2.0
    "third_party/devtools-frontend/src/front_end/third_party/lit" ;BSD-3
    "third_party/devtools-frontend/src/front_end/third_party/marked" ;Expat, BSD-3
    "third_party/devtools-frontend/src/front_end/third_party/puppeteer" ;ASL2.0
    "third_party/devtools-frontend/src/front_end/third_party/puppeteer/package/lib/third_party"
    "third_party/devtools-frontend/src/front_end/third_party/puppeteer\
/package/lib/third_party/mitt" ;Expat
    "third_party/devtools-frontend/src/front_end/third_party/puppeteer/third_party/mitt" ; Expat
    "third_party/devtools-frontend/src/front_end/third_party/puppeteer/third_party/parsel" ; Expat
    "third_party/devtools-frontend/src/front_end/third_party/puppeteer/third_party/rxjs" ; ASL2.0
    "third_party/devtools-frontend/src/front_end/third_party/puppeteer-replay" ;ASL2.0
    "third_party/devtools-frontend/src/front_end/third_party/source-map-scopes-codec" ;BSD-3
    "third_party/devtools-frontend/src/front_end/third_party\
/vscode.web-custom-data" ;Expat
    "third_party/devtools-frontend/src/front_end/third_party/third-party-web" ;Expat
    "third_party/devtools-frontend/src/front_end/third_party/wasmparser" ;ASL2.0
    "third_party/devtools-frontend/src/front_end/third_party/web-vitals" ;Expat
    "third_party/devtools-frontend/src/third_party/i18n" ;ASL2.0
    "third_party/devtools-frontend/src/third_party/pyjson5" ;ASL2.0

    "third_party/dom_distiller_js" ;BSD-3
    "third_party/dragonbox" ;ASL2.0, Boost1.0
    "third_party/d3" ;Non-copyleft
    "third_party/eigen3" ;MPL2.0
    "third_party/emoji-segmenter" ;ASL2.0
    "third_party/farmhash" ;Expat
    "third_party/fast_float" ;ASL2.0, Boost1.0, Expat
    "third_party/fdlibm" ;non-copyleft
    "third_party/federated_compute/chromium/fcp/confidentialcompute" ;ASL2.0
    "third_party/federated_compute/chromium/fcp/protos" ;ASL2.0
    ;no explicit license; trivial
    "third_party/federated_compute/chromium/fcp/protos/confidentialcompute"
    "third_party/federated_compute/chromium/fcp/secagg" ;ASL2.0
    "third_party/federated_compute/chromium/fcp/client" ;ASL2.0
    "third_party/federated_compute/src/fcp/base" ;ASL2.0
    "third_party/federated_compute/src/fcp/confidentialcompute" ;ASL2.0
    "third_party/federated_compute/src/fcp/client" ;ASL2.0
    "third_party/federated_compute/src/fcp/protos" ;ASL2.0
    "third_party/federated_compute/src/fcp/protos/confidentialcompute" ;ASL2.0
    "third_party/federated_compute/src/fcp/protos/federatedcompute" ;ASL2.0
    "third_party/federated_compute/src/fcp/secagg" ;ASL2.0
    "third_party/federated_compute/third_party/googleapis/src/google/rpc" ;ASL2.0
    ;ASL2.0
    "third_party/federated_compute/third_party/googleapis/src/google/longrunning"
    "third_party/federated_compute/third_party/googleapis/src/google/type" ;ASL2.0
    "third_party/federated_compute/third_party/protodatastore-cpp" ;ASL2.0
    ;ASL2.0
    "third_party/federated_compute/third_party/tensorflow-federated/src/tensorflow_federated"
    "third_party/ffmpeg" ; LGPL2.1+, GPL2.0+, Expat and BSD
    "third_party/fft2d" ;non-copyleft
    "third_party/flatbuffers" ;ASL2.0
    "third_party/fp16" ;Expat
    "third_party/freetype" ;GPL2.0
    "third_party/fusejs" ;ASL2.0
    "third_party/fxdiv" ;Expat
    "third_party/gemmlowp" ;ASL2.0
    "third_party/google_input_tools" ;ASL2.0
    "third_party/google_input_tools/third_party/closure_library" ;ASL2.0
    "third_party/google_input_tools/third_party/closure_library/third_party/closure" ;Expat
    "third_party/googletest" ;BSD-3
    "third_party/harfbuzz" ;Expat
    "third_party/highway" ;ASL2.0
    "third_party/hunspell" ;MPL1.1/GPL2+/LGPL2.1+
    "third_party/hyphenation-patterns" ;Expat
    ;; FIXME: Our icu does not have some headers such as udatamem.h.
    "third_party/icu" ;Unicode3.0
    "third_party/ink" ;ASL2.0
    "third_party/inspector_protocol" ;BSD-3
    "third_party/ipcz" ;BSD-3
    "third_party/jinja2" ;BSD-3
    "third_party/jsoncpp" ; Public domain, Expat
    "third_party/khronos" ;Expat, SGI
    "third_party/lens_server_proto" ;Non-copyleft
    "third_party/leveldatabase" ;BSD-3
    "third_party/libaddressinput" ;ASL2.0
    "third_party/libaom" ;BSD-2 or "Alliance for Open Media Patent License 1.0"
    "third_party/libaom/source/libaom/third_party/fastfeat" ;BSD-3
    "third_party/libaom/source/libaom/third_party/vector" ;Expat
    "third_party/libaom/source/libaom/third_party/x86inc" ;ISC
    "third_party/libgav1" ;ASL2.0
    "third_party/libjingle_xmpp" ;BSD-3
    "third_party/libpfm4" ;BSD
    "third_party/libpng" ;PNG2.0
    "third_party/libphonenumber" ;ASL2.0
    "third_party/libsecret" ;LGPL2.1+
    "third_party/libsrtp" ;BSD-3
    "third_party/libsync" ;ASL2.0
    "third_party/libtess2" ;SGIFreeB2.0
    "third_party/liburlpattern" ;Expat
    "third_party/libva_protected_content" ;Expat

    ;; FIXME: build/linux/unbundle/libvpx.gn does not work for all users.
    "third_party/libvpx" ;BSD-3
    "third_party/libvpx/source/libvpx/third_party/x86inc" ;Expat

    "third_party/libwebm" ;BSD-3
    "third_party/libx11" ;BSD
    "third_party/libxcb-keysyms" ;BSD
    "third_party/libxml/chromium" ;BSD-3
    "third_party/libyuv" ;BSD-3
    "third_party/libzip" ;BSD-3
    "third_party/lit" ;BSD-3
    "third_party/lit/v3_0" ;BSD-3
    "third_party/lottie" ;Expat
    "third_party/lss" ;BSD-3
    "third_party/lzma_sdk" ;public domain
    "third_party/mako" ;Expat
    "third_party/markupsafe" ;BSD-3
    "third_party/material_color_utilities" ;ASL2.0
    "third_party/metrics_proto" ;BSD-3
    "third_party/minigbm" ;BSD-3
    "third_party/ml_dtypes" ;ASL2.0
    "third_party/modp_b64" ;BSD-3
    "third_party/nasm" ;BSD-2
    "third_party/nearby" ;ASL2.0
    "third_party/neon_2_sse" ;BSD-2
    "third_party/node" ;Expat
    "third_party/oak/chromium/proto" ;ASL2.0
    "third_party/oak/chromium/proto/attestation" ;ASL2.0
    "third_party/omnibox_proto" ;BSD-3
    "third_party/one_euro_filter" ;BSD-3
    "third_party/openscreen" ;BSD-3
    "third_party/openscreen/src/third_party/tinycbor" ;Expat
    "third_party/opus" ;BSD-3
    "third_party/ots" ;BSD-3
    "third_party/pdfium" ;BSD-3
    "third_party/pdfium/third_party/agg23" ;Expat
    "third_party/pdfium/third_party/bigint" ;Public domain, BSD-3
    "third_party/pdfium/third_party/lcms" ;Expat
    "third_party/pdfium/third_party/libopenjpeg" ;BDS-2
    "third_party/pdfium/third_party/libtiff" ;non-copyleft
    "third_party/pdfium/third_party/freetype/include/pstables.h" ;FreeType
    "third_party/perfetto" ;ASL2.0
    "third_party/perfetto/protos/third_party/android" ;ASL2.0
    "third_party/perfetto/protos/third_party/chromium" ;BSD-3
    "third_party/perfetto/protos/third_party/pprof" ;ASL2.0
    "third_party/perfetto/protos/third_party/primes" ;ASL2.0
    "third_party/perfetto/protos/third_party/simpleperf" ;ASL2.0
    "third_party/pffft" ;the "FFTPACK" license
    "third_party/ply" ;BSD-3
    "third_party/polymer" ;BSD-3
    "third_party/private_membership" ;ASL2.0
    "third_party/private-join-and-compute" ;ASL2.0
    "third_party/protobuf" ;BSD-3
    "third_party/protobuf/third_party/utf8_range" ; Expat
    "third_party/pthreadpool" ;BSD-2
    "third_party/puffin" ;Non-copyleft
    "third_party/pyyaml" ;Expat
    "third_party/pyjson5" ;ASL2.0
    "third_party/rapidhash" ;BSD-2
    "third_party/readability" ;ASL2.0
    "third_party/re2" ;Non-copyleft
    "third_party/rnnoise" ;BSD-3
    "third_party/rust" ; Expat
    "third_party/ruy" ;ASL2.0
    "third_party/s2cellid" ;ASL2.0
    "third_party/search_engines_data" ;BSD-3
    "third_party/securemessage" ;ASL2.0
    "third_party/selenium-atoms" ;ASL2.0
    "third_party/sentencepiece" ;ASL2.0
    "third_party/sentencepiece/src/third_party/darts_clone" ;BSD-3
    "third_party/shell-encryption" ;ASL2.0
    "third_party/simdutf" ;Non-copyleft
    "third_party/simplejson" ; Non-copyleft
    "third_party/six" ;Expat
    "third_party/skia" ;BSD-3
    "third_party/skia/include/third_party/vulkan" ;BSD-3
    "third_party/smhasher" ;Expat, public domain

    ;; FIXME: the snappy "replacement" shim (see replace_gn_files.py below) does
    ;; not declare a library dependency added in M93, causing a link failure.
    "third_party/snappy" ;BSD-3

    "third_party/speech-dispatcher" ;GPL2+
    "third_party/spirv-headers" ;ASL2.0
    "third_party/spirv-tools" ;ASL2.0
    "third_party/sqlite" ;Public domain
    "third_party/swiftshader" ;ASL2.0
    "third_party/swiftshader/third_party/astc-encoder" ;ASL2.0
    "third_party/swiftshader/third_party/llvm-10.0" ;ASL2.0, with LLVM exception
    "third_party/swiftshader/third_party/llvm-subzero" ;NCSA
    "third_party/swiftshader/third_party/marl" ;ASL2.0
    "third_party/swiftshader/third_party/subzero" ;NCSA
    "third_party/swiftshader/third_party/SPIRV-Headers" ;X11-style
    "third_party/swiftshader/third_party/SPIRV-Tools" ;ASL2.0
    "third_party/tensorflow-text" ;ASL2.0
    "third_party/tensorflow_models" ;ASL2.0
    "third_party/tflite" ;ASL2.0
    "third_party/tflite/src/third_party/fft2d" ;ASL2.0
    "third_party/tflite/src/third_party/xla" ;ASL2.0
    "third_party/tflite/src/third_party/xla/xla" ;ASL2.0
    "third_party/tflite/src/third_party/xla/xla/tsl/framework" ;ASL2.0
    "third_party/tflite/src/third_party/xla/xla/tsl/lib/random" ;ASL2.0
    "third_party/tflite/src/third_party/xla/xla/tsl/platform" ;ASL2.0
    "third_party/tflite/src/third_party/xla/xla/tsl/protobuf" ;ASL2.0
    "third_party/tflite/src/third_party/xla/xla/tsl/util" ;ASL2.0
    "third_party/tflite/src/third_party/xla/third_party/tsl" ;ASL2.0
    "third_party/tflite/src/third_party/xla/third_party/tsl/tsl" ;ASL2.0
    "third_party/tflite/src/third_party/xla/third_party/tsl/tsl/platform" ;ASL2.0
    "third_party/tflite/src/third_party/xla/third_party/tsl/tsl/profiler" ;ASL2.0
    "third_party/ukey2" ;ASL2.0
    "third_party/ungoogled-chromium" ;BSD-3
    "third_party/usb_ids" ;BSD-3
    "third_party/utf" ;Expat
    "third_party/vulkan-deps" ;ASL2.0, BSD-3, Expat
    "third_party/vulkan-headers" ;ASL2.0
    "third_party/vulkan-loader" ;ASL2.0
    "third_party/vulkan_memory_allocator" ;Expat
    "third_party/vulkan-tools" ;ASL2.0
    "third_party/vulkan-validation-layers" ;ASL2.0
    "third_party/vulkan-utility-libraries" ;ASL2.0
    "third_party/wayland" ;BSD-3, Expat
    "third_party/wayland-protocols" ;Expat
    "third_party/webdriver" ;ASL2.0
    "third_party/webgpu-cts" ;BSD-3
    "third_party/webrtc" ;BSD-3
    "third_party/webrtc/common_audio/third_party/ooura" ;Non-copyleft
    "third_party/webrtc/common_audio/third_party/spl_sqrt_floor" ;Public domain
    "third_party/webrtc/modules/third_party/fft" ;Non-copyleft
    "third_party/webrtc/modules/third_party/g711" ;Public domain
    "third_party/webrtc/modules/third_party/g722" ;Public domain
    "third_party/widevine/cdm/widevine_cdm_common.h" ;BSD-3
    "third_party/woff2" ;ASL2.0
    "third_party/wuffs" ;ASL2.0
    "third_party/xcbproto" ;X11
    "third_party/xnnpack" ;BSD-3

    ;; These are forked components of the X11 keybinding code.
    "third_party/libxcb-keysyms" ;X11
    "third_party/libx11/src/KeyBind.c" ;X11
    "third_party/libx11/src/xkb/XKBBind.c" ;X11
    "third_party/x11proto/keysymdef.h" ;X11

    "third_party/zlib/google" ;BSD-3
    "third_party/zxcvbn-cpp" ;Expat
    "url/third_party/mozilla" ;BSD-3, MPL1.1/GPL2+/LGPL2.1+
    "v8/third_party/glibc/src/sysdeps/ieee754/dbl-64" ;LGPL2.1+
    "v8/third_party/inspector_protocol" ;BSD-3
    "v8/third_party/rapidhash-v8" ;BSD-2
    "v8/third_party/siphash" ;CC0 1.0
    "v8/third_party/utf8-decoder" ;Non-copyleft
    "v8/third_party/valgrind" ;BSD
    "v8/third_party/v8/builtins" ;PSFL2.0
    "v8/third_party/v8/codegen")) ;Expat

(define %denied-files
  ;; 'third_party/blink/perf_tests/resources/svg/HarveyRayner.svg' carries a
  ;; nonfree license according to LICENSES in the same directory.  As we don't
  ;; run the Blink performance tests, just remove everything to save ~70MiB.
  '("third_party/blink/perf_tests"))

(define %chromium-version "155.0.8059.84")
(define %helium-version "0.19.4.1")
;; imputnet/helium pinned by the helium-linux 0.19.4.1 submodule pointer.
(define %helium-revision "832faa7822566270e10c0d3262f702f9d0fea81f")
(define %helium-linux-revision "cf878d4aaff58d063beada276c437ae756a142aa") ;tag 0.19.4.1
;; Debian patches were picked for chromium 151 and stay pinned there;
;; revisit this tag when porting the patch set to 155.
(define %debian-revision "debian/151.0.7922.137-1")

(define %helium-origin
  (origin
    (method git-fetch)
    (uri (git-reference (url "https://ghfast.top/https://github.com/imputnet/helium")
                        (commit %helium-revision)))
    (file-name (git-file-name "helium" %helium-version))
    (sha256
     (base32
      "0fj7my8nmpaxpisscbdzlqyfrq1lhclc50rknj4p0qdazkd9qy6b"))))

(define %helium-linux-origin
  (origin
    (method git-fetch)
    (uri (git-reference (url "https://ghfast.top/https://github.com/imputnet/helium-linux")
                        (commit %helium-linux-revision)))
    (file-name (git-file-name "helium-linux" %helium-version))
    (sha256
     (base32
      "10pq1kpz48hmagvjcihlzv111m8l2p84m2xd6nmhgc5px5znfyhj"))))

;; Helium-specific tree additions from helium's deps.ini; all three pin
;; their sha256 upstream.  They are unpacked into the chromium tree by
;; the source snippet before the patch pipeline runs.
(define %search-engines-origin
  (origin
    (method url-fetch)
    (uri (string-append "https://github.com/imputnet/helium-nonfree-assets"
                        "/releases/download/202609082320"
                        "/nonfree-search-engines-data-202609082320.tar.gz"))
    (sha256
     (base32
      "19siv868wb8khzqazbajy5jr4h88v639gwdm9gb4ci2586pn739a"))))

(define %onboarding-origin
  (origin
    (method url-fetch)
    (uri (string-append "https://github.com/imputnet/helium-onboarding"
                        "/releases/download/202610161403"
                        "/helium-onboarding-202610161403.tar.gz"))
    (sha256
     (base32
      "1b00d79bg9nn1ni1h19v7a24dkff364flw0a7bsn824ynzgfcpdk"))))

(define %ublock-origin
  (origin
    (method url-fetch)
    (uri (string-append "https://github.com/imputnet/uBlock"
                        "/releases/download/1.75.0"
                        "/uBlock0_1.75.0.chromium.zip"))
    (sha256
     (base32
      "1ipkggprglp9ac52najvlpvv2qw4s9dw0ix61pk79i66yxs4c8a9"))))

;; DevTools bundles its own esbuild launcher binary (an ELF that cannot
;; execute inside the guix sandbox, which has no /lib64 loader).  Fetch
;; the matching upstream esbuild 0.28.2 and swap it in during prep.
(define %esbuild-origin
  (origin
    (method url-fetch)
    (uri (list "https://registry.npmjs.org/@esbuild/linux-x64/-/linux-x64-0.28.2.tgz"
               "https://registry.npmmirror.com/@esbuild/linux-x64/-/linux-x64-0.28.2.tgz"))
    (sha256
     (base32
      "1xl88jw4szr62xmxcqfyd0bwq4v1falwrma7fvmgkc5a6cibnwwm"))))

(define %debian-origin
  (origin
    (method git-fetch)
    (uri (git-reference
          (url "https://salsa.debian.org/chromium-team/chromium.git")
          (commit %debian-revision)))
    (file-name (git-file-name "debian-chromium-patches"
                              (match (string-split %debian-revision #\/)
                                ((_ version) version))))
    (sha256
     (base32
      "07ja5wk9p3vcak8czjn70cqg0x7pkwkm2yk9z9fz6925mipnl6yg"))))

(define (origin-file origin file)
  (computed-file
   (basename file)
   #~(symlink (string-append #$origin "/" #$file)
              #$output)))

(define (debian-patch name)
  (origin-file %debian-origin (string-append "/debian/patches/" name)))

(define %debian-patches
  ;; Chromium 155 with clang 22: Debian's llvm-19 series is only kept
  ;; where it still applies; the clang19-specific workarounds (0007,
  ;; 0011, clang19, value-or, libcpp-headers) are gone, and the
  ;; nodejs-main workaround moved to an adapted local patch.
  (map debian-patch
       '("bookworm/foreach.patch"
         "debianization/safe-libcxx.patch"
         "disable/enterprise-tests.patch"
         "disable/node-version-ck.patch"
         "disable/rustc-allow-features.patch"
         "fixes/bytemuck.patch"
         "fixes/gentoo-stylesheet.patch"
         "fixes/libpng-testonly.patch"
         "fixes/rust-clanglib.patch"
         "llvm-19/0001-revert-v8-libm.patch"
         "llvm-19/0002-revert-v8-libm.patch"
         "llvm-19/0003-revert-v8-libm.patch"
         "llvm-19/0004-revert-v8-libm.patch"
         "llvm-19/0005-revert-v8-libm.patch"
         "llvm-19/0009-revert-v8-libm.patch"
         "llvm-19/clone-traits.patch"
         "llvm-19/constexpr.patch"
         "llvm-19/i18n-builder-enum.patch"
         "llvm-19/const-profile.patch"
         "llvm-19/iota.patch"
         "llvm-19/keyfactory.patch"
         "llvm-19/raw-ref-map-find.patch"
         "llvm-22/ignore-for-ubsan.patch"
         "system/openjpeg.patch"
         "trixie/bindgen-boringssl.patch"
         "trixie/cookie-string-view.patch"
         "trixie/revert-v8-sanitize.patch")))

(define %guix-patches
  (map (lambda (patch)
         (local-file
          (assume-valid-file-name
           (string-append %source-directory "/patches/" patch))))
       (list
        "ungoogled-chromium-custom-compiler.patch"
        "ungoogled-chromium-empty-parsed-rustc-args.patch"
        "ungoogled-chromium-extension-search-path.patch"
        "ungoogled-chromium-golang.patch"
        "ungoogled-chromium-increase-fortify-level.patch"
        "ungoogled-chromium-RUNPATH.patch"
        "ungoogled-chromium-system-nspr.patch"
        "helium-libdrm-assertion.patch"
        "helium-buildconfig-unused-var.patch"
        "helium-proto-library-unused-var.patch"
        "helium-devtools-copy-unused-var.patch"
        "helium-devtools-unused-vars.patch"
        "helium-skills-unused-var.patch"
        "helium-rust-prebuilt-stubs.patch"
        "helium-no-fno-lifetime-dse.patch"
        "helium-disable-cbor-rust.patch"
        "helium-libcxx19-value-or.patch"
        "helium-libcxx19-value-or-2.patch"
        "helium-font-format-cpp.patch"
        "helium-disable-ift.patch"
        "helium-nodejs-main.patch"
        "helium-rust-toolchain-var.patch")))

(define %patches
  (append %debian-patches
          %guix-patches))

(define %chromium-base-tarball-origin
  (origin
    (method url-fetch)
    (uri (string-append "https://tarballs.imput.net"
                        "/chromium-" %chromium-version
                        "/chromium-" %chromium-version "-base.tar.zst"))
    (sha256
     (base32
      "1i56njrm2g5qf5pads55w2q8j7vb5hzlp7v97plzzyini2scxkw9"))))

(define %chromium-linux-x64-tarball-origin
  (origin
    (method url-fetch)
    (uri (string-append "https://tarballs.imput.net"
                        "/chromium-" %chromium-version
                        "/chromium-" %chromium-version "-linux-x64.tar.zst"))
    (sha256
     (base32
      "1ydjlzx1v9vs4ny3ryhq6ll4ixhk43pyl0f2yqxfkr5gijxs1rmz"))))

;; The Helium source is assembled from imputnet's prepared tarballs (a
;; 'base' layer shared by every host plus a 'linux-x64' layer with host
;; files and toolchains), rather than from Google's -lite tarball, whose
;; host (commondatastorage.googleapis.com) is unreachable from this
;; network.  The two hash-pinned layers are extracted into a shared root
;; and then the full ungoogled + helium pipeline runs over the tree.
;;
;; The pipeline does the following:
;; *) Unpacks the two prepared tarball layers and helium's tree additions
;;    (deps.ini resources), and swaps the bundled devtools esbuild
;;    launcher for our own.
;; *) Applies assorted build fixes (Debian + Guix patches).
;; *) Runs the ungoogled prune-, patch- and domain substitution scripts,
;;    followed by helium's own substitution, i18n, version stamping and
;;    resource replacement steps (the order of helium-linux's
;;    scripts/shared.sh).
;; *) Removes a few denied files; the Debian-style third_party pruning is
;;    deliberately skipped (see the "guix note" below).
;; *) Adjusts "GN" build files such that system libraries are preferred.
(define helium-chromium-source
  ;; Note: delay, mirroring gnu/packages/chromium.scm.
  (delay
    (computed-file
     (string-append "chromium-" %chromium-version "-helium-patched")
     #~(begin
         (use-modules (guix build utils) (ice-9 ftw))
         ;; The prepared chromium tree *is* the output: build everything
         ;; in place, otherwise the derivation ends up with no outputs.
         (mkdir-p #$output)
         (chdir #$output)
         (let ((chromium-dir (getcwd)))
           (set-path-environment-variable
            "PATH" '("bin")
            (list #+patch #+python-wrapper #+xz #+zstd #+tar #+unzip #+gzip))
           ;; generate_resources.py needs Pillow for icon generation.
           ;; find-files already returns the site-packages directory
           ;; itself; that is the PYTHONPATH, no dirname wanted.
           (setenv "PYTHONPATH"
                   (car (find-files #+python-pillow
                                    "^site-packages$"
                                    #:directories? #t)))

           ;; Unpack the base layer then overlay the linux-x64 layer;
           ;; both tarballs carry a single chromium-<version>/ top-level
           ;; directory.
           (format #t "Unpacking prepared Chromium layers...~%")
           (force-output)
           (invoke "tar" "--use-compress-program=zstd" "-xf"
                   #+%chromium-base-tarball-origin "--strip-components=1")
           (invoke "tar" "--use-compress-program=zstd" "-xf"
                   #+%chromium-linux-x64-tarball-origin "--strip-components=1")

           ;; Helium's tree additions from deps.ini.
           (format #t "Unpacking Helium tree additions...~%")
           (force-output)
           (mkdir-p "third_party/search_engines_data/resources_internal")
           (invoke "tar" "-xzf" #+%search-engines-origin
                   "-C" "third_party/search_engines_data/resources_internal")
           (mkdir-p "components/helium_onboarding")
           (invoke "tar" "-xzf" #+%onboarding-origin
                   "-C" "components/helium_onboarding")
           (invoke "unzip" "-q" #+%ublock-origin "-d" "third_party/ublock")
           ;; deps.ini: strip_leading_dirs = uBlock0.chromium
           (let ((inner "third_party/ublock/uBlock0.chromium"))
             (for-each
              (lambda (file)
                (rename-file (string-append inner "/" file)
                             (string-append "third_party/ublock/" file)))
              (scandir inner
                       (lambda (entry)
                         (not (member entry '("." ".."))))))
             (delete-file-recursively inner))

           ;; Swap the bundled devtools esbuild launcher (which cannot
           ;; run in the sandbox) for the matching upstream esbuild.
           (let ((esbuild-dir "/tmp/esbuild"))
             (mkdir-p esbuild-dir)
             (with-directory-excursion esbuild-dir
               (invoke "tar" "-xzf" #+%esbuild-origin))
             (mkdir-p "third_party/devtools-frontend/src/third_party/esbuild")
             (copy-file (string-append esbuild-dir "/package/bin/esbuild")
                        "third_party/devtools-frontend/src/third_party/esbuild/esbuild"))

           ;; Apply patches before running the ungoogled scripts because
           ;; domain substitution may break some of the patches.
           (format #t "Applying assorted build fixes...~%")
           (force-output)
           (for-each (lambda (patch)
                       (invoke "patch" "-p1" "--force" "--input"
                               patch "--no-backup-if-mismatch"))
                     '#+%patches)

           ;; Copy the helium trees somewhere writable: the helium
           ;; scripts generate files inside their own tree (resources).
           (copy-recursively #+%helium-origin "/tmp/helium")
           (copy-recursively #+%helium-linux-origin "/tmp/helium-linux")

           (format #t "Ungooglifying...~%")
           (force-output)
           (with-directory-excursion "/tmp/helium"
             (invoke "python" "utils/prune_binaries.py"
                     "--keep-build-dependencies"
                     chromium-dir "pruning.list")
             ;; Both quilt directories are applied in order: helium's
             ;; own series first, then helium-linux's platform series.
             ;; The latter must run before name substitution, as its
             ;; patch context expects "Chromium" not "Helium".
             (invoke "python" "utils/patches.py" "apply" chromium-dir
                     "patches" "/tmp/helium-linux/patches")
             (invoke "python" "utils/domain_substitution.py" "apply" "-r"
                     "domain_regex.list" "-f" "domain_substitution.list"
                     chromium-dir)

             ;; Helium's own substitution, i18n, version stamping and
             ;; resource replacement steps.
             (format #t "Applying Helium substitutions...~%")
             (force-output)
             (invoke "python" "utils/name_substitution.py" "--sub"
                     "-t" chromium-dir)
             (invoke "python" "utils/i18n_apply.py" "-t" chromium-dir)
             (invoke "python" "utils/helium_version.py"
                     "--tree" "/tmp/helium"
                     "--platform-tree" "/tmp/helium-linux"
                     "--chromium-tree" chromium-dir)
             (invoke "python" "utils/generate_resources.py"
                     "resources/generate_resources.txt" "resources")
             (invoke "python" "utils/replace_resources.py"
                     "resources/helium_resources.txt" "resources"
                     chromium-dir))

           ;; Run after the ungoogled scripts to avoid interfering with
           ;; patches or file lists.  Entries may already be gone in this
           ;; Chromium version (upstream deletions or pruning); tolerate
           ;; misses.
           (format #t "Removing denied files...~%")
           (force-output)
           (for-each
            (lambda (file)
              (false-if-exception (delete-file-recursively file)))
            '#$%denied-files)

           (format #t "Pruning third party files...~%")
           (force-output)
           ;; guix note: we deliberately skip Debian-style
           ;; `remove_bundled_libraries.py --do-remove` here.  nixpkgs'
           ;; helium packaging (nixpkgs#498572) proved that helium's own
           ;; prune_binaries pass is sufficient; the extra Debian-style
           ;; trim only ever deleted build-time inputs (esbuild, crubit
           ;; sources, typescript.py, ublock scripts) whose exclusion
           ;; rules cannot express nested third_party paths, and each
           ;; removal broke the ninja plan downstream.

           (format #t "Replacing GN files...~%")
           (force-output)
           (substitute* "tools/generate_shim_headers/generate_shim_headers.py"
             ;; The "is_official_build" configure option enables certain
             ;; release optimizations like those used in the commercial
             ;; Chrome browser.  Unfortunately it also requires using the
             ;; bundled libraries: lose that restriction.
             (("#if defined\\(OFFICIAL_BUILD\\)") "#if 0"))
           ;; The complete list of replacement system libraries can be
           ;; found at this file.
           (invoke "python" "build/linux/unbundle/replace_gn_files.py"
                   "--system-libraries"
                   "brotli"
                   "crc32c"
                   "dav1d"
                   "flac"
                   "fontconfig"
                   "freetype"
                   "harfbuzz"
                   "libdrm"
                   "libjpeg"
                   "libpng"
                   "libwebp"
                   "libxml"
                   "libxslt"
                   "openh264"
                   "opus"
                   "zlib"
                   "zstd")))
     #:options '(#:modules ((guix build utils))))))

(define opus+custom
  (package/inherit opus
    (name "opus+custom")
    (arguments
     (substitute-keyword-arguments arguments
       ((#:configure-flags flags ''())
        ;; Opus Custom is an optional extension of the Opus
        ;; specification that allows for unsupported frame
        ;; sizes.  Chromium requires that this is enabled.
        `(cons "--enable-custom-modes"
               ,flags))))))

(define-public helium
  (package
    (name "helium")
    (version %helium-version)
    (synopsis "Private, fast, and honest web browser")
    (source (force helium-chromium-source))
    (build-system gnu-build-system)
    (arguments
     (list
      #:tests? #f
      #:modules '((guix build gnu-build-system)
                  (guix build utils)
                  (srfi srfi-26))
      #:configure-flags
      ;; See tools/gn/docs/cookbook.md and
      ;; https://www.chromium.org/developers/gn-build-configuration
      ;; for usage.  Run "gn args . --list" in the Release
      ;; directory for an exhaustive list of supported flags.
      ;; (Note: The 'configure' phase will do that for you.)
      #~(list "is_debug=false"
              "is_component_build=false"
              ;; Use the "official" release optimizations, as opposed to
              ;; a developer build.
              "is_official_build=true"
              "clang_use_chrome_plugins=false"
              "use_clang_modules=false"          ;support for this is deprecated and to be removed.
              "use_custom_libcxx=false"
              "use_unified_system_module=false"  ;requires the libc++/sysroot module machinery
              "optimize_webui=false"
              "webnn_use_tflite=false"
              "webnn_use_litert=false"
              "build_tflite_with_xnnpack=false"
              "safe_browsing_use_unrar=false"
              "chrome_pgo_phase=0"
              "use_sysroot=false"
              "goma_dir=\"\""
              "use_unofficial_version_number=false"
              "treat_warnings_as_errors=false"
              "use_official_google_api_keys=false"
              "disable_fieldtrial_testing_config=true"
              "safe_browsing_mode=0"
              "enable_mdns=false"
              "enable_remoting=false"
              "enable_reporting=false"
              "enable_service_discovery=false"
              "enable_vr=false"
              "enable_enterprise_companion=false"
              "enable_iterator_debugging=false"
              "enable_hangout_services_extension=false"
              "enable_widevine=true"
              ;; Helium flags.gn additions:
              "exclude_unwind_tables=true"
              "google_api_key=\"\""
              "google_default_client_id=\"\""
              "google_default_client_secret=\"\""
              "use_kerberos=false"
              ;; Helium enables PGO in CI; we skip it, and skip thinLTO
              ;; too: the chrome link step would need ~30 GB of RAM.
              "use_thin_lto=false"
              "fatal_linker_warnings=false"
              ;; Avoid dependency on code formatting tools.
              "blink_enable_generated_code_formatting=false"
              ;; Don't bother building Dawn tests.
              "build_dawn_tests=false"

              "angle_has_histograms=false"
              "angle_build_tests=false"
              "build_angle_perftests=false"
              "enable_perfetto_unittests=false"
              "skia_enable_skshapper_tests=false"
              "tint_build_unittests=false"
              "enable_nocompile_tests=false"
              "enable_screen_ai_browsertests=false"

              "clang_warning_suppression_file=\"\""

              "use_qt5=false"
              "use_qt6=false"
              "is_cfi=false"

              "symbol_level=0"
              "blink_symbol_level=0"
              "v8_symbol_level=0"
              "v8_enable_backtrace=false"
              "v8_drumbrake_bounds_checks=true"

              ;; Define a custom toolchain that simply looks up CC, AR and
              ;; friends from the environment.
              "custom_toolchain=\"//build/toolchain/linux/unbundle:default\""
              "host_toolchain=\"//build/toolchain/linux/unbundle:default\""

              (string-append "clang_base_path=\""
                             (dirname (dirname (search-input-file %build-inputs
                                                                  "/bin/clang")))
                             "\"")

              (string-append "clang_version="
                             #$(version-major (package-version clang)))

              (string-append "rust_sysroot_absolute=\""
                             (dirname (dirname (search-input-file %build-inputs
                                                                  "/bin/rustc")))
                             "\"")
              (string-append "rust_bindgen_root=\""
                             (dirname (dirname (search-input-file %build-inputs
                                                                  "/bin/bindgen")))
                             "\"")

              (string-append "rustc_version=\"rustc "
                             #$(package-version rust)
                             ;; These are 'don't care', but chromium's build parses
                             ;; the whole string as if returned from 'rustc --version'
                             ;; invokation and fails if it's just the version number.
                             " (f6e511eec 2024-10-15) (built from a source tarball)\"")

              ;; Prefer system libraries.
              "use_system_freetype=true"
              "use_system_harfbuzz=true"
              "use_system_icu=false"
              "use_system_lcms2=true"
              "use_system_libdrm=true"
              "use_system_libffi=true"
              "use_system_libjpeg=true"
              "use_system_libopenjpeg2=true"
              "use_system_libpng=true"

              "use_system_zlib=true"
              "use_gnome_keyring=false" ;deprecated by libsecret
              "use_pulseaudio=true"
              "link_pulseaudio=true"
              "icu_use_data_file=true"

              ;; VA-API acceleration is currently only supported on x86_64-linux.
              #$@(if (string-prefix? "x86_64" (or (%current-target-system)
                                                  (%current-system)))
                     '("use_vaapi=true")
                     '())

              #$@(if (string-prefix? "aarch64" (or (%current-target-system)
                                                   (%current-system)))
                     '("use_v4l2_codec=true"
                       "use_vaapi=false"
                       "use_av1_hw_decoder=true")
                     '())

              ;; Do not artificially restrict formats supported by system ffmpeg.
              "proprietary_codecs=true"
              "ffmpeg_branding=\"Chrome\""

              "rtc_use_pipewire=true")
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'patch-stuff
            (lambda* (#:key inputs native-inputs #:allow-other-keys)
              (let* ((brotli (search-input-file inputs
                                                "/bin/brotli"))
                     (libopenjp2 (search-input-file inputs "lib/libopenjp2.so"))
                     (openjpeg (dirname (dirname libopenjp2)))
                     (gperf (search-input-file (or native-inputs inputs)
                                               "/bin/gperf"))
                     (compiler-rt-path (dirname
                                        (dirname
                                         (search-input-file (or native-inputs inputs)
                                                            "/bin/hwasan_symbolize")))))
                (substitute* "third_party/brotli/BUILD.gn"
                  (("/usr/bin/brotli")
                   brotli))

                ;; This works on top of debian's 'rust-clanglib.patch'.
                (substitute* "build/config/clang/BUILD.gn"
                  (("\\$clang_base_path/lib/clang/\\$clang_version")
                   compiler-rt-path))

                (substitute* "third_party/pdfium/BUILD.gn"
                  ;; This include path is added by Debians openjpeg patch.
                  (("/usr/include/openjpeg-")
                   (string-append openjpeg "/include/openjpeg-")))

                (substitute*
                    (append
                     '("media/audio/audio_opus_encoder.h")
                     (find-files (string-append "third_party/webrtc/modules"
                                                "/audio_coding/codecs/opus")))
                  ;; Fix opus include path.
                  ;; Do not substitute opus_private.h.
                  (("#include \"opus\\.h\"")
                   "#include \"opus/opus.h\"")
                  (("#include \"opus_custom\\.h\"")
                   "#include \"opus/opus_custom.h\"")
                  (("#include \"opus_defines\\.h\"")
                   "#include \"opus/opus_defines.h\"")
                  (("#include \"opus_multistream\\.h\"")
                   "#include \"opus/opus_multistream.h\"")
                  (("#include \"opus_types\\.h\"")
                   "#include \"opus/opus_types.h\"")
                  (("\"third_party/opus/src/include/([a-z_-]+\\.h)\"" _ header)
                   (string-append "<opus/" header ">")))

                ;; Many files try to include ICU headers from "third_party/icu/...".
                ;; Remove the "third_party/" prefix to use system headers instead.
                ;(substitute* (find-files "chrome" "\\.cc$")
                ;  (("third_party/icu/source/(common|i18n)/")
                ;   ""))

                ;; XXX: Should be unnecessary when use_system_lcms2=true.
                (substitute* "third_party/pdfium/core/fxcodec/icc/icc_transform.h"
                  (("include \"third_party/lcms/include/lcms2\\.h\"")
                   "include \"lcms2.h\""))

                ;; The unbundling script leaves behind an empty pyyaml directory
                ;; which prevents the code that tries to use it from falling
                ;; back to the pyyaml provided by Guix.
                (delete-file-recursively "third_party/pyyaml")

                ;; Since M148, gperf binary is bundled upstream and expected to
                ;; be available here.  The imput tarball ships the cipd
                ;; copy; replace it with our own, deterministically.
                (mkdir-p "third_party/gperf/cipd")
                (false-if-exception
                 (delete-file-recursively "third_party/gperf/cipd/bin"))
                (symlink (dirname gperf) "third_party/gperf/cipd/bin")

                (substitute*
                    "third_party/breakpad/breakpad/src/common/linux/libcurl_wrapper.h"
                  (("include \"third_party/curl")
                   "include \"curl"))

                ;; Our clang libs and rustfmt are not under bindgen root directory.
                (substitute* '("build/rust/rust_bindgen_generator.gni"
                               "build/rust/rust_bindgen.gni")
                  (("(_libclang_path = )rust_bindgen_root" _ libclang)
                   (string-append libclang "clang_base_path"))
                  (("(_rustfmt_path = \")\\$\\{rust_bindgen_root\\}" _ rustfmt)
                   (string-append rustfmt "${rust_sysroot_absolute}"))))))
          (add-after 'patch-stuff 'add-absolute-references
            (lambda* (#:key inputs #:allow-other-keys)
              (let ((cups-config (search-input-file inputs "/bin/cups-config"))
                    (libnssckbi.so (search-input-file inputs
                                                      "/lib/nss/libnssckbi.so"))
                    (gtk-libs '("libgio-2.0.so.0"
                                "libgdk_pixbuf-2.0.so.0"
                                "libgdk-3.so.0"
                                "libgtk-3.so.0")))
                (for-each (lambda (lib)
                            (substitute* "ui/gtk/gtk_compat.cc"
                              ((lib) (search-input-file
                                      inputs (string-append "lib/" lib)))))
                          gtk-libs)
                (substitute* "printing/cups_config_helper.py"
                  (("cups_config =.*")
                   (string-append "cups_config = '" cups-config "'\n")))
                (substitute* "crypto/nss_util.cc"
                  (("libnssckbi\\.so") libnssckbi.so)))))
          (add-after 'add-absolute-references 'adjust-CPLUS_INCLUDE_PATH
            ;; The libcxx include/c++/v1 directory is not exposed via
            ;; CPLUS_INCLUDE_PATH by default, causing errors like
            ;; "fatal error: 'format' file not found".  Also clang is
            ;; unable to find gcc's bits/c++config.h which is machine
            ;; dependent.
            (lambda* (#:key native-inputs inputs #:allow-other-keys)
              (let* ((libcxx-v1 (search-input-directory inputs
                                                        "include/c++/v1"))
                     (target-system #$(nix-system->gnu-triplet
                                       (or (%current-target-system)
                                           (%current-system))))
                     (target-include (string-append "include/c++/"
                                                    target-system))
                     (gcc-bits (search-input-directory inputs
                                                       target-include)))
                (setenv "CPLUS_INCLUDE_PATH"
                        (string-append libcxx-v1 ":" gcc-bits ":"
                                       (getenv "CPLUS_INCLUDE_PATH"))))))
          (add-before 'configure 'prepare-build-environment
            (lambda* (#:key native-inputs inputs #:allow-other-keys)
              (let ((node (search-input-file (or native-inputs inputs)
                                             "/bin/node")))
                ;; Define the GN toolchain.
                (setenv "AR" "llvm-ar") (setenv "NM" "llvm-nm")
                (setenv "CC" "clang") (setenv "CXX" "clang++")

                (setenv "CXXFLAGS"
                        (string-append " -Wno-conversion"
                                       " -Wno-unused-function"
                                       " -Wno-unused-variable"
                                       " -Wno-unused-private-field"
                                       " -Wno-deprecated-declarations"
                                       " -Wno-unknown-pragmas"
                                       " -fno-delete-null-pointer-checks"
                                       " -stdlib=libc++"))
                (setenv "LDFLAGS"
                        (string-append " -stdlib=libc++"
                                       " -Wl,--stats"))
                (setenv "CLANG_MVERS" #$(version-major
                                         (package-version clang)))
                (setenv "RUSTC_BOOTSTRAP" "1")

                ;; TODO: pre-compile instead. Avoids a race condition.
                (setenv "PYTHONDONTWRITEBYTECODE" "1")

                ;; Go compiler creates a build cache directory at home.
                (setenv "HOME" "/tmp")
                ;; Avoid checking for go modules online.
                (setenv "GOPROXY" "off")
                ;; dawn's go.mod wants go >= 1.26; never try to fetch
                ;; toolchains online.
                (setenv "GOTOOLCHAIN" "local")

                ;; XXX: How portable is this.  The imput tarball ships
                ;; its own bundled node; replace it with ours.
                (mkdir-p "third_party/node/linux/node-linux-x64")
                (false-if-exception
                 (delete-file-recursively
                  "third_party/node/linux/node-linux-x64/bin"))
                (symlink (dirname node)
                         "third_party/node/linux/node-linux-x64/bin")
                ;; Same for the bundled prebuilt gn: v8's metagen tool
                ;; invokes it, but the ELF cannot execute in the sandbox.
                (false-if-exception
                 (delete-file "buildtools/linux64/gn"))
                (false-if-exception
                 (symlink (search-input-file (or native-inputs inputs)
                                             "/bin/gn")
                          "buildtools/linux64/gn")))))
          (replace 'configure
            (lambda* (#:key configure-flags #:allow-other-keys)
              (let ((args (string-join configure-flags " ")))
                ;; Generate ninja build files.
                (invoke "gn" "gen" "out/Release"
                        (string-append "--args=" args))

                ;; Print the full list of supported arguments as well as
                ;; their current status for convenience.
                (format #t "Dumping configure flags...\n")
                (invoke "gn" "args" "out/Release" "--list"))))
          (add-before 'build 'increase-resource-limits
            (lambda _
              ;; XXX: Chromiums linking step requires a lot of simultaneous file
              ;; accesses.  Having a too low ulimit will result in bogus linker
              ;; errors such as "foo.a: error adding symbols: malformed archive".

              ;; Try increasing the soft resource limit of max open files to 2048,
              ;; or equal to the hard limit, whichever is lower.
              (call-with-values (lambda () (getrlimit 'nofile))
                (lambda (soft hard)
                  (when (and soft (< soft 2048))
                    (if hard
                        (setrlimit 'nofile (min hard 2048) hard)
                        (setrlimit 'nofile 2048 #f))
                    (format #t
                            "increased maximum number of open files from ~d to ~d~%"
                            soft (if hard (min hard 2048) 2048)))))))
          (replace 'build
            (lambda* (#:key (parallel-build? #t) #:allow-other-keys)
              (invoke "ninja" "-C" "out/Release"
                      "-j" (if parallel-build?
                               (number->string (parallel-job-count))
                               "1")
                      "chrome"
                      "chromedriver")))
          (replace 'install
            (lambda* (#:key inputs outputs #:allow-other-keys)
              (let* ((out          (assoc-ref outputs "out"))
                     (bin          (string-append out "/bin"))
                     (exe          (string-append bin "/helium"))
                     (lib          (string-append out "/lib"))
                     (man          (string-append out "/share/man/man1"))
                     (applications (string-append out "/share/applications"))
                     (libs         '("chrome_100_percent.pak"
                                     "chrome_200_percent.pak"
                                     "resources.pak"
                                     "v8_context_snapshot.bin"
                                     "icudtl.dat"

                                     ;; Swiftshader ICD.
                                     "libvk_swiftshader.so"
                                     "vk_swiftshader_icd.json"

                                     ;; Chromium ships its own libGL and
                                     ;; vulkan implementation called ANGLE.
                                     "libvulkan.so.1"
                                     "libEGL.so" "libGLESv2.so"))
                     (locales      (string-append lib "/locales"))
                     (resources    (string-append lib "/resources"))
                     (preferences
                      ;; This file contains defaults for new user profiles.
                      #$(local-file
                         (string-append %source-directory
                                        "/helium-master-preferences.json")))
                     (gtk (dirname (dirname
                                    (search-input-file inputs "lib/libgtk-3.so"))))
                     (mesa (dirname (search-input-file inputs "lib/libGL.so")))
                     (xdg-utils (dirname (search-input-file inputs "bin/xdg-open"))))

                (substitute* '("chrome/app/resources/manpage.1.in"
                               "chrome/installer/linux/common/desktop.template")
                  (("@@MENUNAME") "Helium")
                  (("@@PACKAGE") "helium")
                  (("/usr/bin/@@usr_bin_symlink_name") exe)
                  (("@@uri_scheme") "x-scheme-handler/helium;")
                  (("@@extra_desktop_entries") "")
                  (("@@startup_wm_class") "helium-browser"))

                (mkdir-p man)
                (copy-file "chrome/app/resources/manpage.1.in"
                           (string-append man "/helium.1"))

                (mkdir-p applications)
                (copy-file "chrome/installer/linux/common/desktop.template"
                           (string-append applications "/helium.desktop"))

                (mkdir-p lib)
                (copy-file preferences (string-append lib "/master_preferences"))

                (with-directory-excursion "out/Release"
                  (for-each (cut install-file <> lib) libs)
                  ;; name_substitution may or may not have renamed the
                  ;; crashpad handler, accept both spellings.
                  (install-file (if (file-exists? "helium_crashpad_handler")
                                    "helium_crashpad_handler"
                                    "chrome_crashpad_handler")
                                lib)
                  (copy-file "helium" (string-append lib "/helium"))

                  (copy-recursively "locales" locales)
                  (copy-recursively "resources" resources)

                  (mkdir-p bin)
                  (symlink "../lib/helium" exe)
                  (install-file "chromedriver" bin)

                  (wrap-program exe
                    ;; Avoid file manager crash.  See <https://bugs.gnu.org/26593>.
                    `("XDG_DATA_DIRS" ":" prefix (,(string-append gtk "/share")))
                    ;; Provide libGL and libvulkan without patching all references.
                    ;; XXX: How to add on RUNPATH instead of this hack?
                    `("LD_LIBRARY_PATH" ":" prefix
                      (,mesa))
                    ;; Ensure xdg-open et al. is found.
                    `("PATH" ":" prefix (,xdg-utils))))

                (with-directory-excursion "chrome/app/theme/chromium"
                  (for-each
                   (lambda (size)
                     (let ((icons (string-append out "/share/icons/hicolor/"
                                                 size "x" size "/apps")))
                       (mkdir-p icons)
                       (copy-file (string-append "product_logo_" size ".png")
                                  (string-append icons "/chromium.png"))))
                   '("24" "48" "64" "128" "256")))))))))
    (native-inputs
     (list bison
           clang
           clang-runtime
           clang-toolchain
           gn
           gperf
           go-1.26
           lld-as-ld-wrapper
           llvm
           ninja
           node-lts
           pkg-config
           which
           python-beautifulsoup4
           python-html5lib
           python-pillow
           python-pyyaml
           python-wrapper
           rust
           rust-bindgen-cli
           rust-cbindgen
           unzip
           wayland))
    (inputs
     (list alsa-lib
           at-spi2-core
           bash-minimal
           brotli
           crc32c
           cups
           curl
           dav1d
           dbus
           expat
           flac
           fontconfig
           fp16
           freetype
           fxdiv
           gdk-pixbuf
           glib
           gtk+
           harfbuzz
           icu4c-77
           lcms
           libcxx
           libdrm
           libffi
           libjpeg-turbo
           libpng
           libva
           libvpx
           libwebp
           libx11
           libxcb
           libxcomposite
           libxcursor
           libxdamage
           libxext
           libxfixes
           libxi
           libxml2
           libxrandr
           libxrender
           libxscrnsaver
           libxslt
           libxtst
           mesa
           minizip
           mit-krb5
           nss
           openh264
           openjpeg                     ;PDFium only
           opus+custom
           pango
           pciutils
           pipewire
           pulseaudio
           qtbase
           snappy
           speech-dispatcher
           eudev
           valgrind/pinned
           wayland
           xdg-utils
           `(,zstd "lib")))
    (native-search-paths
     (list (search-path-specification
            (variable "CHROMIUM_EXTENSION_DIRECTORY")
            (separator #f)              ;single entry
            (files '("share/chromium/extensions")))))

    ;; Building Chromium takes ... a very long time.  On a single core, a busy
    ;; mid-end x86 system may need more than 24 hours to complete the build.
    (properties '((timeout . 144000)    ;40 hours
                  ;; The linking step may take more than an hour on some hardware.
                  (max-silent-time . 7200)
                  (cpe-name . "chrome")))

    (home-page "https://helium.computer/")
    (description
     "Helium is a Chromium-based web browser focused on privacy, consent and
comfort.  It started as a fork of ungoogled-chromium, removes dependencies on
Google web services, bundles uBlock Origin and its own onboarding experience,
and replaces Chromium branding.  This package also includes the
@command{chromedriver} command, which can be useful for automated web
testing.")
    ;; Chromium is developed as BSD-3, but bundles a large number of
    ;; third-party components with other licenses; helium's own patches are
    ;; GPL-3.0.  For full information, see chrome://credits.
    (license (list license:gpl3
                   license:bsd-3
                   license:bsd-2
                   license:expat
                   license:asl2.0
                   license:mpl1.1
                   license:mpl2.0
                   license:public-domain
                   license:isc
                   (license:non-copyleft "chrome://credits"
                                         "See chrome://credits for more information.")
                   license:lgpl2.1+))))
