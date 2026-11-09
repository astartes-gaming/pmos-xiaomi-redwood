#!/bin/sh
# Build firmware-xiaomi-redwood/hexagonfs.tar.gz: the files hexagonrpcd serves
# to the ADSP sensor hub (layout as FairBlobs/FP5-firmware hexagonfs/).
#   vendor.img  (ROM zip)         -> sensors/config, sensors/sns_reg.conf
#   persist.img (phone partition) -> sensors/registry  (THIS phone's calibration)
#   dsp.img     (phone dsp_b)     -> dsp/adsp
# Images: sudo cat /dev/disk/by-partlabel/{persist,dsp_b} > ... (read-only).
# Usage: tools/collect-sensors.sh vendor.img persist.img dsp.img
set -e
D=${DEBUGFS:-/sbin/debugfs}
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d); h=$t/hexagonfs
mkdir -p $h/sensors $h/dsp $h/socinfo
"$D" -R "rdump /etc/sensors/config $h/sensors" "$1" 2>/dev/null
"$D" -R "dump /etc/sensors/sns_reg_config $h/sensors/sns_reg.conf" "$1" 2>/dev/null
"$D" -R "rdump /sensors/registry/registry $h/sensors" "$2" 2>/dev/null
"$D" -R "rdump /adsp $h/dsp" "$3" 2>/dev/null
# socinfo as the vendor libs expect it (values from /sys/devices/soc0 and
# debugfs qcom_socinfo on redwood: hardware_platform 11 = QRD)
printf 'QRD\n' > $h/socinfo/hw_platform
printf 'Unknown\n' > $h/socinfo/platform_subtype
printf '0\n' > $h/socinfo/platform_subtype_id
printf '65536\n' > $h/socinfo/platform_version
printf '1.0\n' > $h/socinfo/revision
printf '475\n' > $h/socinfo/soc_id
for d in sensors/config sensors/registry dsp/adsp; do
	[ -n "$(ls $h/$d 2>/dev/null)" ] || { echo "missing $d" >&2; exit 1; }
done
echo "config: $(ls $h/sensors/config | wc -l), registry: $(ls $h/sensors/registry | wc -l), dsp/adsp: $(ls $h/dsp/adsp | wc -l)"
tar -C $t --owner=0 --group=0 --sort=name --mtime=@0 -czf "$here/firmware-xiaomi-redwood/hexagonfs.tar.gz" hexagonfs
rm -rf $t
echo "wrote firmware-xiaomi-redwood/hexagonfs.tar.gz"
