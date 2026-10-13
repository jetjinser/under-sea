#!/bin/sh
# Build quickjs.wasm and its C extensions from source using Guix's wasi toolchain.
#
# Usage: build-quickjs-wasi.sh <wasi-libc> <wasi-compiler-rt> <binaryen> <src> <out>
#
# Guix ships clang/lld/wasi-libc/binaryen but not wasi-sdk, and its clang wrapper
# injects host headers.  We construct a wasi-sdk-compatible shim (clang wrapper
# with -nostdlibinc + the WASI sysroot, plus the wasm compiler-rt builtins under
# the wasm32-unknown-wasip1 resource layout) and drive the upstream Makefile with
# it.  The URL extension needs libc++ and is not built here.
set -eu
WASI_LIBC=$1
WASI_RT=$2
BINARYEN=$3
SRC=$4
OUT=$5
cd "$SRC"
# wasi-libc 28 declares __wasi_random_get (returning __wasi_errno_t) in
# <wasi/api.h>; the upstream extension re-declares it as returning int, which is
# a conflicting type.  Drop the local declaration and use the libc one.
python3 - <<'PY'
path = 'extensions/crypto/crypto.c'
text = open(path).read()
old = '''extern int __wasi_random_get(void *buf, size_t buf_len)
    __attribute__((__import_module__("wasi_snapshot_preview1"),
                   __import_name__("random_get")));'''
if old not in text:
    raise SystemExit('wasi random_get declaration not found')
open(path, 'w').write(text.replace(old, '#include <wasi/api.h>'))
PY
ROOT=$(pwd)/.wasi-sdk-shim
SYSROOT=$ROOT/share/wasi-sysroot
RES=$ROOT/res
CLANG_INC=$(clang -print-resource-dir)/include
SH=$(command -v sh)
rm -rf "$ROOT"
mkdir -p "$SYSROOT/include" "$SYSROOT/lib" "$ROOT/bin" \
         "$RES/lib/wasm32-unknown-wasip1" "$OUT/extensions"
ln -s "$WASI_LIBC/share/wasi-sysroot/include/wasm32-wasi" \
      "$SYSROOT/include/wasm32-wasip1"
ln -s "$WASI_LIBC/share/wasi-sysroot/lib/wasm32-wasi" \
      "$SYSROOT/lib/wasm32-wasip1"
ln -s "$CLANG_INC" "$RES/include"
ln -s "$WASI_RT/lib/wasm32-unknown-wasi/libclang_rt.builtins.a" \
      "$RES/lib/wasm32-unknown-wasip1/libclang_rt.builtins.a"
cat > "$ROOT/bin/clang" <<EOF
#!$SH
exec clang --sysroot="$SYSROOT" -nostdlibinc \
  -isystem "$SYSROOT/include/wasm32-wasip1" -resource-dir "$RES" \
  -L"$SYSROOT/lib/wasm32-wasip1" "\$@"
EOF
sed 's/exec clang /exec clang++ /' "$ROOT/bin/clang" > "$ROOT/bin/clang++"
printf '#!%s\nexec wasm-ld "$@"\n' "$SH" > "$ROOT/bin/wasm-ld"
printf '#!%s\nexec llvm-ar "$@"\n' "$SH" > "$ROOT/bin/llvm-ar"
chmod +x "$ROOT/bin/clang" "$ROOT/bin/clang++" "$ROOT/bin/wasm-ld" "$ROOT/bin/llvm-ar"
echo 32 > "$ROOT/VERSION"
PATH="$BINARYEN/bin:$PATH"
export PATH
make -j"${JOBCOUNT:-2}" WASI_SDK="$ROOT" OPT=-Oz \
  quickjs.wasm \
  extensions/encoding/encoding.so \
  extensions/headers/headers.so \
  extensions/structured-clone/structured-clone.so \
  extensions/crypto/crypto.so
cp quickjs.wasm "$OUT/quickjs.wasm"
for e in encoding headers structured-clone crypto; do
  cp "extensions/$e/$e.so" "$OUT/extensions/$e.so"
done
