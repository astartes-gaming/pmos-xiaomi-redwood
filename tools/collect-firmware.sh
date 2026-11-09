#!/bin/sh
# Extract the proprietary firmware this port needs into firmware-xiaomi-redwood/.
#  - vendor.img (ext4, from the ROM zip): touch firmware, GPU zap shader
#  - modem dir: a copy of the phone's modem partition "image/" folder
#    (mount /dev/disk/by-partlabel/modem_b read-only): WPSS, Wi-Fi board data
# Needs debugfs (e2fsprogs), no root.
# Usage: tools/collect-firmware.sh path/to/vendor.img path/to/modem/image
set -e
here=$(cd "$(dirname "$0")/.." && pwd)
img=$1
out=$here/firmware-xiaomi-redwood
tmp=$(mktemp -d)
for f in focaltech_ts_fw_m20.bin aw882xx_acf.bin a660_zap.mdt a660_zap.b00 a660_zap.b01 a660_zap.b02; do
	debugfs -R "dump /firmware/$f $tmp/$f" "$img" >/dev/null 2>&1
done
cp "$tmp/focaltech_ts_fw_m20.bin" "$out/"
python3 "$here/tools/squash_mdt.py" "$tmp/a660_zap.mdt" "$out/a660_zap.mbn"
modem=$2
python3 "$here/tools/squash_mdt.py" "$modem/wpss.mdt" "$out/wpss.mbn"
python3 "$here/tools/ath11k_board2.py" "$out/board-2.bin" \
	"bus=ahb,qmi-chip-id=1,qmi-board-id=255=$modem/qca6750/bd_m20gl.elf"
cp "$modem/qca6750/regdb.bin" "$out/"
python3 "$here/tools/squash_mdt.py" "$modem/adsp.mdt" "$out/adsp.mbn"
cp "$modem/adspr.jsn" "$modem/adsps.jsn" "$modem/adspua.jsn" "$modem/battmgr.jsn" "$out/"
cp "$tmp/aw882xx_acf.bin" "$out/aw88261_acf.bin"
cp "$modem/msbtfw11.mbn" "$modem/msnv11.bin" "$out/"
rm -rf "$tmp"
echo "firmware copied to $out"
echo "sensors: run tools/collect-sensors.sh vendor.img persist.img dsp.img"
