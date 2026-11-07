#!/usr/bin/env python3
"""Extract partition images from an Android OTA zip (payload.bin), standard library only.

Usage: payload_extract.py ROM.zip OUTDIR partition [partition ...]

Supports full OTAs (REPLACE, REPLACE_BZ, REPLACE_XZ, ZERO operations), which is what
custom ROM zips such as Evolution X ship. Incremental OTAs are not supported.
"""
import bz2
import lzma
import os
import struct
import sys
import zipfile


def varint(buf, i):
    shift = val = 0
    while True:
        b = buf[i]
        i += 1
        val |= (b & 0x7F) << shift
        if not b & 0x80:
            return val, i
        shift += 7


def fields(buf):
    """Yield (field_number, wire_type, value) for a protobuf message."""
    i = 0
    while i < len(buf):
        key, i = varint(buf, i)
        num, wt = key >> 3, key & 7
        if wt == 0:
            v, i = varint(buf, i)
        elif wt == 1:
            v = buf[i:i + 8]
            i += 8
        elif wt == 2:
            ln, i = varint(buf, i)
            v = buf[i:i + ln]
            i += ln
        elif wt == 5:
            v = buf[i:i + 4]
            i += 4
        else:
            raise ValueError(f"unsupported wire type {wt}")
        yield num, wt, v


def parse_extent(buf):
    start = count = 0
    for n, _, v in fields(buf):
        if n == 1:
            start = v
        elif n == 2:
            count = v
    return start, count


def parse_op(buf):
    op = {"type": 0, "offset": 0, "length": 0, "dst": []}
    for n, _, v in fields(buf):
        if n == 1:
            op["type"] = v
        elif n == 2:
            op["offset"] = v
        elif n == 3:
            op["length"] = v
        elif n == 6:
            op["dst"].append(parse_extent(v))
    return op


def parse_manifest(buf):
    block_size = 4096
    parts = {}
    for n, _, v in fields(buf):
        if n == 3:
            block_size = v
        elif n == 13:
            name, ops = None, []
            for pn, _, pv in fields(v):
                if pn == 1:
                    name = pv.decode()
                elif pn == 8:
                    ops.append(parse_op(pv))
            parts[name] = ops
    return block_size, parts


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    rom, outdir, wanted = sys.argv[1], sys.argv[2], sys.argv[3:]
    os.makedirs(outdir, exist_ok=True)
    with zipfile.ZipFile(rom) as z, z.open("payload.bin") as f:
        magic, version, msize = struct.unpack(">4sQQ", f.read(20))
        if magic != b"CrAU":
            sys.exit("not an Android payload")
        sig_size = struct.unpack(">I", f.read(4))[0] if version >= 2 else 0
        block_size, parts = parse_manifest(f.read(msize))
        f.read(sig_size)
        data_start = 20 + (4 if version >= 2 else 0) + msize + sig_size
        print("partitions in payload:", " ".join(sorted(parts)))
        for name in wanted:
            if name not in parts:
                print(f"skip {name}: not in payload")
                continue
            path = os.path.join(outdir, name + ".img")
            with open(path, "wb") as out:
                for op in parts[name]:
                    f.seek(data_start + op["offset"])
                    data = f.read(op["length"])
                    t = op["type"]
                    if t == 0:
                        pass
                    elif t == 1:
                        data = bz2.decompress(data)
                    elif t == 8:
                        data = lzma.decompress(data)
                    elif t == 6:
                        data = None
                    else:
                        sys.exit(f"{name}: unsupported op type {t}")
                    pos = 0
                    for start, count in op["dst"]:
                        out.seek(start * block_size)
                        n = count * block_size
                        out.write(b"\0" * n if data is None else data[pos:pos + n])
                        pos += n
            print(f"wrote {path} ({os.path.getsize(path)} bytes)")


if __name__ == "__main__":
    main()
