#!/usr/bin/env python3
"""Extract every device tree blob from Android images.

Usage: extract_dtbs.py OUTDIR IMAGE [IMAGE ...]

Handles dtbo.img (DT table, magic d7b7ab1e) and anything else by scanning
for FDT headers (vendor_boot.img DTB section, boot.img, raw dtb files).
"""
import os
import struct
import sys

FDT = b"\xd0\x0d\xfe\xed"
DTBO = b"\xd7\xb7\xab\x1e"


def scan_fdts(data):
    i = data.find(FDT)
    while i != -1:
        total = struct.unpack_from(">I", data, i + 4)[0]
        if 0x40 < total <= len(data) - i:
            yield i, data[i:i + total]
            i = data.find(FDT, i + total)
        else:
            i = data.find(FDT, i + 4)


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for img in sys.argv[2:]:
        data = open(img, "rb").read()
        base = os.path.splitext(os.path.basename(img))[0]
        n = 0
        if data[:4] == DTBO:
            hdr_size, entry_size, count, entries_off = struct.unpack_from(">IIII", data, 8)[1:5] if False else (
                struct.unpack_from(">I", data, 8)[0], struct.unpack_from(">I", data, 12)[0],
                struct.unpack_from(">I", data, 16)[0], struct.unpack_from(">I", data, 20)[0])
            for k in range(count):
                size, off = struct.unpack_from(">II", data, entries_off + k * entry_size)
                open(os.path.join(out, f"{base}-{k:02d}.dtb"), "wb").write(data[off:off + size])
                n += 1
        else:
            for k, (off, blob) in enumerate(scan_fdts(data)):
                open(os.path.join(out, f"{base}-{k:02d}.dtb"), "wb").write(blob)
                n += 1
        print(f"{img}: {n} blobs")


if __name__ == "__main__":
    main()
