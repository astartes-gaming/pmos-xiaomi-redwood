#!/bin/sh
# Extract the proprietary firmware this port needs from a vendor.img (ext4)
# into firmware-xiaomi-redwood/. Needs debugfs (e2fsprogs), no root.
# Usage: tools/collect-firmware.sh path/to/vendor.img
set -e
here=$(cd "$(dirname "$0")/.." && pwd)
img=$1
out=$here/firmware-xiaomi-redwood
tmp=$(mktemp -d)
for f in focaltech_ts_fw_m20.bin a660_zap.mdt a660_zap.b00 a660_zap.b01 a660_zap.b02; do
	debugfs -R "dump /firmware/$f $tmp/$f" "$img" >/dev/null 2>&1
done
cp "$tmp/focaltech_ts_fw_m20.bin" "$out/"
python3 "$here/tools/squash_mdt.py" "$tmp/a660_zap.mdt" "$out/a660_zap.mbn"
rm -rf "$tmp"
echo "firmware copied to $out"
