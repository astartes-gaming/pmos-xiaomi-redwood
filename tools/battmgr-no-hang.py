#!/usr/bin/env python3
"""Patch qcom_battmgr.c: never leave a request waiting on a bad-size reply.

redwood's (Xiaomi) charger firmware numbers some battery properties
differently from mainline; e.g. it answers property 19 (TTF_AVG) with a
132-byte string reply. Mainline then logs "invalid payload length" and
returns WITHOUT complete(), so every such request blocks for its full 1 s
timeout (-110). Under upower's polling these pile up and the ADSP charger
firmware eventually wedges; unplugging USB then resets the phone.

Fix: in the sm8350 callback, finish the request with -ENODATA instead.
Usage: battmgr-no-hang.py qcom_battmgr.c   (edits in place)
"""
import re
import sys

p = sys.argv[1]
s = open(p).read()
start = s.index("static void qcom_battmgr_sm8350_callback(")
end = s.index("\n}\n", start)
body, n = re.subn(r"(battmgr->error = -ENODATA;\n\t+)return;",
                  r"\1goto out_complete;", s[start:end])
if n != 4:
    sys.exit(f"expected 4 bad-length returns, found {n}")
open(p, "w").write(s[:start] + body + s[end:])
print("qcom_battmgr: bad-length replies now complete the request")
