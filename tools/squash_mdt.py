#!/usr/bin/env python3
"""Join a split Qualcomm firmware (name.mdt + name.bNN) into one .mbn,
the format mainline Linux loads (same idea as pil-squasher).

Usage: squash_mdt.py path/to/name.mdt out.mbn
"""
import os
import struct
import sys


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    mdt, out = sys.argv[1], sys.argv[2]
    base = mdt[:-4]
    hdr = open(mdt, "rb").read()
    if hdr[:4] != b"\x7fELF":
        sys.exit("not an ELF .mdt")
    is64 = hdr[4] == 2
    if is64:
        phoff = struct.unpack_from("<Q", hdr, 0x20)[0]
        phentsize, phnum = struct.unpack_from("<HH", hdr, 0x36)
    else:
        phoff = struct.unpack_from("<I", hdr, 0x1C)[0]
        phentsize, phnum = struct.unpack_from("<HH", hdr, 0x2A)

    image = bytearray(hdr[:phoff + phnum * phentsize])
    for i in range(phnum):
        o = phoff + i * phentsize
        if is64:
            p_offset = struct.unpack_from("<Q", hdr, o + 8)[0]
            p_filesz = struct.unpack_from("<Q", hdr, o + 32)[0]
        else:
            p_offset, = struct.unpack_from("<I", hdr, o + 4)
            p_filesz, = struct.unpack_from("<I", hdr, o + 16)
        if not p_filesz:
            continue
        seg = f"{base}.b{i:02d}"
        if os.path.exists(seg):
            data = open(seg, "rb").read()
        elif p_offset + p_filesz <= len(hdr):
            data = hdr[p_offset:p_offset + p_filesz]
        else:
            sys.exit(f"missing segment {seg}")
        end = p_offset + len(data)
        if len(image) < end:
            image += b"\0" * (end - len(image))
        image[p_offset:end] = data
    open(out, "wb").write(image)
    print(f"wrote {out} ({len(image)} bytes, {phnum} segments)")


if __name__ == "__main__":
    main()
