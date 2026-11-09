#!/usr/bin/env python3
"""Build an ath11k board-2.bin from board data files.

Usage: ath11k_board2.py out/board-2.bin "NAME=path/to/bdwlan" [...]

NAME is the string ath11k looks up, e.g.
  bus=ahb,qmi-chip-id=1,qmi-board-id=255
(ath11k prints chip_id/board_id at probe). Format as in qca-swiss-army-knife's
ath11k-bdencoder: magic, then BOARD IEs each holding a NAME and a DATA IE,
all little-endian u32 id/len, payloads padded to 4 bytes.
"""
import struct
import sys

MAGIC = b"QCA-ATH11K-BOARD\0"
IE_BOARD, IE_NAME, IE_DATA = 0, 0, 1


def pad4(b):
    return b + b"\0" * (-len(b) % 4)


def ie(ie_id, payload):
    return struct.pack("<II", ie_id, len(payload)) + pad4(payload)


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    out = pad4(MAGIC)
    for arg in sys.argv[2:]:
        name, path = arg.split("=", 1)[0], None
        # NAME itself contains '=' characters: split on the last '='
        name, path = arg.rsplit("=", 1)
        data = open(path, "rb").read()
        board = ie(IE_NAME, name.encode()) + ie(IE_DATA, data)
        out += ie(IE_BOARD, board)
        print(f"{name}: {path} ({len(data)} bytes)")
    open(sys.argv[1], "wb").write(out)
    print(f"wrote {sys.argv[1]} ({len(out)} bytes)")


if __name__ == "__main__":
    main()
