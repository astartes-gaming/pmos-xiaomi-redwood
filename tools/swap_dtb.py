#!/usr/bin/env python3
"""Replace the device tree in an Android boot image (header v2).

Usage: swap_dtb.py IN_boot.img NEW.dtb OUT_boot.img

Handles both places pmbootstrap puts the DTB for redwood: appended to the
kernel (deviceinfo_append_dtb) and the separate v2 DTB section.
"""
import struct
import sys

FDT_MAGIC = b"\xd0\x0d\xfe\xed"


def align(n, page):
    return (n + page - 1) // page * page


def pad(b, page):
    return b + b"\0" * (align(len(b), page) - len(b))


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    img = open(sys.argv[1], "rb").read()
    new_dtb = open(sys.argv[2], "rb").read()
    if img[:8] != b"ANDROID!":
        sys.exit("not an Android boot image")
    if new_dtb[:4] != FDT_MAGIC:
        sys.exit("new DTB has no FDT magic")

    (kernel_size, kernel_addr, ramdisk_size, ramdisk_addr, second_size,
     second_addr, tags_addr, page, version, os_version) = struct.unpack_from("<10I", img, 8)
    if version != 2:
        sys.exit(f"header v{version} not supported, need v2")
    # v2 extra fields after id[32] + extra_cmdline[1024] (offset 1632)
    off = 8 + 40 + 16 + 512 + 32 + 1024
    rdtbo_size, rdtbo_off, header_size, dtb_size, dtb_addr = struct.unpack_from("<IQIIQ", img, off)

    pos = page
    kernel = img[pos:pos + kernel_size]; pos += align(kernel_size, page)
    ramdisk = img[pos:pos + ramdisk_size]; pos += align(ramdisk_size, page)
    second = img[pos:pos + second_size]; pos += align(second_size, page)
    rdtbo = img[pos:pos + rdtbo_size]; pos += align(rdtbo_size, page)

    # Strip the appended DTB: last FDT whose totalsize reaches the end of the kernel
    idx = kernel.rfind(FDT_MAGIC)
    while idx > 0:
        total = struct.unpack_from(">I", kernel, idx + 4)[0]
        if idx + total == len(kernel):
            break
        idx = kernel.rfind(FDT_MAGIC, 0, idx)
    if idx <= 0:
        sys.exit("could not find the DTB appended to the kernel")
    kernel = kernel[:idx] + new_dtb

    header = bytearray(img[:header_size])
    struct.pack_into("<I", header, 8, len(kernel))
    struct.pack_into("<I", header, off + 16, len(new_dtb))
    out = (pad(bytes(header), page) + pad(kernel, page) + pad(ramdisk, page)
           + pad(second, page) + pad(rdtbo, page) + pad(new_dtb, page))
    open(sys.argv[3], "wb").write(out)
    print(f"wrote {sys.argv[3]}: kernel {len(kernel)} B, dtb {len(new_dtb)} B (was {dtb_size} B)")


if __name__ == "__main__":
    main()
