#!/bin/sh
# SPDX-License-Identifier: MIT
# Install redwood's firmware from the phone's own partitions (public builds
# ship no blobs). Same files and paths as firmware-xiaomi-redwood, so it is a
# no-op when that package is installed. Partitions are mounted read-only.
#   modem_X     -> ADSP, WPSS, MPSS, Wi-Fi board/regdb, carrier configs
#   bluetooth_X -> WCN6750 Bluetooth patch + NVM
#   vendor_X    -> touch, GPU zap, speaker amp, IPA (via super, debugfs)
#   dsp_X, persist, vendor -> files hexagonrpcd serves to the sensor hub
# Usage: redwood-firmware-setup [--force]   (ROOT=dir installs under dir)
set -eu

R=${ROOT:-}
F=$R/lib/firmware
Q=$F/qcom/sm7325/xiaomi/redwood
H=$R/usr/share/qcom/sm7325/Xiaomi/redwood
T=${TOOLS:-/usr/libexec/redwood-fw}
STAMP=$R/var/lib/redwood-firmware-setup.done

if [ "${1:-}" != --force ] && [ -e "$Q/modem.mbn" ] && [ -e "$Q/adsp.mbn" ]; then
	exit 0
fi

slot=$(grep -o 'androidboot\.slot_suffix=_[ab]' /proc/cmdline | cut -d= -f2) || slot=
hwc=$(grep -o 'androidboot\.hwc=[A-Z]*' /proc/cmdline | cut -d= -f2) || hwc=GL
case "$hwc" in
GL) bd=bd_m20gl.elf ;;
IN) bd=bd_m20in.elf ;;
*) bd=bd_m20.elf ;;
esac

w=$(mktemp -d)
before=$(ls /dev/mapper)
cleanup() {
	for m in "$w"/mnt/*; do
		mountpoint -q "$m" 2>/dev/null && umount "$m"
	done
	# remove only the dynamic-partition mappings this run created
	for d in $(ls /dev/mapper); do
		case " $(echo $before) " in *" $d "*) ;; *) dmsetup remove "$d" 2>/dev/null || : ;; esac
	done
	rm -rf "$w"
}
trap cleanup EXIT

part() { echo "/dev/disk/by-partlabel/$1"; }
mnt() {
	mkdir -p "$w/mnt/$1"
	mount -o ro,nodev,noexec,nosuid "$(part "$1")" "$w/mnt/$1"
}

mnt "modem$slot"
mnt "bluetooth$slot"
mnt "dsp$slot"
mnt persist
M=$w/mnt/modem$slot/image
B=$w/mnt/bluetooth$slot/image

# vendor lives inside the dynamic "super" partition
# (super may only describe one slot, so take whichever vendor exists)
ls /dev/mapper/vendor_* >/dev/null 2>&1 || make-dynpart-mappings "$(part super)"
V=
for v in "/dev/mapper/vendor$slot" /dev/mapper/vendor_a /dev/mapper/vendor_b /dev/mapper/vendor; do
	[ -e "$v" ] && { V=$v; break; }
done
[ -n "$V" ] || { echo "redwood-firmware-setup: no vendor partition in super" >&2; exit 1; }
vdump() { debugfs -R "dump $1 $2" "$V" >/dev/null 2>&1; [ -s "$2" ]; }

o=$w/out
mkdir -p "$o/q" "$o/ath" "$o/qca" "$o/v"

for f in adsp wpss modem; do
	python3 "$T/squash_mdt.py" "$M/$f.mdt" "$o/q/$f.mbn"
done
cp "$M/adspr.jsn" "$M/adsps.jsn" "$M/adspua.jsn" "$M/battmgr.jsn" \
	"$M/modemr.jsn" "$o/q/"
cp -r "$M/modem_pr" "$o/q/"
python3 "$T/ath11k_board2.py" "$o/ath/board-2.bin" \
	"bus=ahb,qmi-chip-id=1,qmi-board-id=255=$M/qca6750/$bd"
cp "$M/qca6750/regdb.bin" "$o/ath/"
cp "$B/msbtfw11.mbn" "$B/msnv11.bin" "$o/qca/"

vdump /firmware/focaltech_ts_fw_m20.bin "$o/v/focaltech_ts_fw_m20.bin"
vdump /firmware/aw882xx_acf.bin "$o/q/aw88261_acf.bin"
for f in a660_zap yupik_ipa_fws; do
	vdump "/firmware/$f.mdt" "$o/v/$f.mdt"
	for i in 00 01 02 03 04 05 06 07 08 09; do
		debugfs -R "dump /firmware/$f.b$i $o/v/$f.b$i" "$V" >/dev/null 2>&1 || :
		[ -s "$o/v/$f.b$i" ] || rm -f "$o/v/$f.b$i"
	done
done
python3 "$T/squash_mdt.py" "$o/v/a660_zap.mdt" "$o/q/a660_zap.mbn"
python3 "$T/squash_mdt.py" "$o/v/yupik_ipa_fws.mdt" "$o/q/ipa_fws.mbn"

# Sensor hub files (hexagonfs), as tools/collect-sensors.sh builds them
h=$o/h
mkdir -p "$h/sensors" "$h/dsp" "$h/socinfo"
debugfs -R "rdump /etc/sensors/config $h/sensors" "$V" >/dev/null 2>&1
debugfs -R "dump /etc/sensors/sns_reg_config $h/sensors/sns_reg.conf" "$V" >/dev/null 2>&1
cp -r "$w/mnt/persist/sensors/registry/registry" "$h/sensors/"
cp -r "$w/mnt/dsp$slot/adsp" "$h/dsp/"
printf 'QRD\n' > "$h/socinfo/hw_platform"
printf 'Unknown\n' > "$h/socinfo/platform_subtype"
printf '0\n' > "$h/socinfo/platform_subtype_id"
printf '65536\n' > "$h/socinfo/platform_version"
printf '1.0\n' > "$h/socinfo/revision"
printf '475\n' > "$h/socinfo/soc_id"

for f in q/adsp.mbn q/wpss.mbn q/modem.mbn q/a660_zap.mbn q/ipa_fws.mbn \
	q/aw88261_acf.bin ath/board-2.bin qca/msbtfw11.mbn \
	v/focaltech_ts_fw_m20.bin h/sensors/sns_reg.conf; do
	[ -s "$o/$f" ] || { echo "redwood-firmware-setup: missing $f" >&2; exit 1; }
done

install -d "$Q" "$F/postmarketos/ath11k/WCN6750/hw1.0" "$F/postmarketos/qca" "$H"
cp -r "$o/q/." "$Q/"
cp "$o/ath/board-2.bin" "$o/ath/regdb.bin" "$F/postmarketos/ath11k/WCN6750/hw1.0/"
cp "$o/qca/msbtfw11.mbn" "$o/qca/msnv11.bin" "$F/postmarketos/qca/"
cp "$o/v/focaltech_ts_fw_m20.bin" "$F/"
cp -r "$h/." "$H/"
chmod -R u=rwX,go=rX "$Q" "$H" "$F/postmarketos"
mkdir -p "$(dirname "$STAMP")"
date > "$STAMP"
echo "redwood-firmware-setup: installed firmware (slot ${slot:-none}, hwc $hwc)"
