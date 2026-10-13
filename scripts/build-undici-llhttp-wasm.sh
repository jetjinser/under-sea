#!/bin/sh
# Rebuild undici's llhttp WASM modules from source with the Guix wasi toolchain.
#
# Usage: build-undici-llhttp-wasm.sh <wasi-libc> <wasi-compiler-rt> <binaryen> <src> <out>
#
# Mirrors undici's build/wasm.js (which uses wasi-sdk in a container) without
# Docker: a wasi-sdk-compatible shim is built from clang/lld/wasi-libc and the
# wasm compiler-rt builtins, then llhttp and its SIMD variant are compiled and
# wrapped as base64 CommonJS modules.  The npm prebuilt wasm is not used.
set -eu
WASI_LIBC=$1
WASI_RT=$2
BINARYEN=$3
SRC=$4
OUT=$5
cd "$SRC"
ROOT=$(pwd)/.wasi-sdk-shim
SYSROOT=$ROOT/share/wasi-sysroot
RES=$ROOT/res
SH=$(command -v sh)
CLANG_INC=$(clang -print-resource-dir)/include
rm -rf "$ROOT"
mkdir -p "$SYSROOT/include" "$SYSROOT/lib" "$RES/lib/wasm32-unknown-wasip1" "$OUT"
ln -s "$WASI_LIBC/share/wasi-sysroot/include/wasm32-wasi" "$SYSROOT/include/wasm32-wasip1"
ln -s "$WASI_LIBC/share/wasi-sysroot/lib/wasm32-wasi" "$SYSROOT/lib/wasm32-wasip1"
ln -s "$CLANG_INC" "$RES/include"
ln -s "$WASI_RT/lib/wasm32-unknown-wasi/libclang_rt.builtins.a" \
      "$RES/lib/wasm32-unknown-wasip1/libclang_rt.builtins.a"
PATH="$BINARYEN/bin:$PATH"
export PATH
COMMON="--target=wasm32-wasip1 --sysroot=$SYSROOT -resource-dir=$RES -nostdlibinc \
  -isystem $SYSROOT/include/wasm32-wasip1 -L$SYSROOT/lib/wasm32-wasip1 \
  -O3 -fno-exceptions -fvisibility=hidden -mexec-model=reactor \
  -Wl,-error-limit=0 -Wl,-O3 -Wl,--lto-O3 -Wl,--strip-all \
  -Wl,--allow-undefined -Wl,--export-dynamic -Wl,--export-table \
  -Wl,--export=malloc -Wl,--export=free -Wl,--no-entry \
  deps/llhttp/src/*.c -Ideps/llhttp/include"
# shellcheck disable=SC2086
clang $COMMON -o "$OUT/llhttp.wasm"
wasm-opt -O4 --converge --strip-debug --strip-dwarf --strip-producers \
  -o "$OUT/llhttp.wasm" "$OUT/llhttp.wasm"
# shellcheck disable=SC2086
clang $COMMON -msimd128 -o "$OUT/llhttp_simd.wasm"
wasm-opt -O4 --converge --strip-debug --strip-dwarf --strip-producers --enable-simd \
  -o "$OUT/llhttp_simd.wasm" "$OUT/llhttp_simd.wasm"
python3 - "$OUT" <<'PY'
import base64, sys
from pathlib import Path
out = Path(sys.argv[1])
template = """'use strict'

const { Buffer } = require('node:buffer')

const wasmBase64 = '__DATA__'

let wasmBuffer

Object.defineProperty(module, 'exports', {
  get: () => {
    return wasmBuffer
      ? wasmBuffer
      : (wasmBuffer = Buffer.from(wasmBase64, 'base64'))
  }
})
"""
for wasm, js in (('llhttp.wasm', 'llhttp-wasm.js'),
                 ('llhttp_simd.wasm', 'llhttp_simd-wasm.js')):
    data = base64.b64encode((out / wasm).read_bytes()).decode()
    (out / js).write_text(template.replace('__DATA__', data))
PY
