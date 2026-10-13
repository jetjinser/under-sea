#!/usr/bin/env python3
"""Clear the PT_GNU_STACK execute bit on ELF shared objects.

Some packages link objects that omit the .note.GNU-stack marker, so the linker
records PT_GNU_STACK as RWE and the library fails to load on kernels that
refuse executable stacks.  Pass files or directories; every ELF shared object
found is patched in place (mode 0644).  Safe to run unconditionally.
"""
import os
import struct
import sys

PT_GNU_STACK = 0x6474E551


def clear(path):
    try:
        data = bytearray(open(path, "rb").read())
    except OSError:
        return False
    if data[:4] != b"\x7fELF" or data[4] != 2:
        return False
    phoff = struct.unpack_from("<Q", data, 0x20)[0]
    entsize = struct.unpack_from("<H", data, 0x36)[0]
    phnum = struct.unpack_from("<H", data, 0x38)[0]
    changed = False
    for i in range(phnum):
        off = phoff + i * entsize
        if struct.unpack_from("<I", data, off)[0] == PT_GNU_STACK:
            flags = struct.unpack_from("<I", data, off + 4)[0]
            if flags & 1:
                struct.pack_into("<I", data, off + 4, flags & ~1)
                changed = True
    if changed:
        os.chmod(path, 0o644)
        open(path, "wb").write(data)
    return changed


def shared_objects(root):
    if os.path.isdir(root):
        for dirpath, _, files in os.walk(root):
            for name in files:
                if name.endswith(".so") or ".so." in name:
                    yield os.path.join(dirpath, name)
    else:
        yield root


def main():
    for root in sys.argv[1:]:
        for path in shared_objects(root):
            if clear(path):
                print("clear-exec-stack: patched", path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
