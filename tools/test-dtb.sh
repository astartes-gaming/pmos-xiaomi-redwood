#!/bin/sh
# Build a test boot image: current /boot/boot.img from the phone with the DTB
# rebuilt from dts/ (FocalTech -ft variant, which the phone uses). Compiles
# with the phone's dtc. Usage: tools/test-dtb.sh OUT.img [ssh-host]
set -e
R=$(cd "$(dirname "$0")/.." && pwd); ML=${ML:-$HOME/.cache/redwood-ml}
H=${2:-redwood}; T=$(mktemp -d); Q=arch/arm64/boot/dts/qcom
cp "$R"/dts/sm7325-xiaomi-redwood.dts "$R"/dts/sm7325-xiaomi-redwood-ft.dts "$ML/$Q/"
(cd "$ML" && cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp -I $Q -I arch/arm64/boot/dts \
	-I scripts/dtc/include-prefixes -I include $Q/sm7325-xiaomi-redwood-ft.dts -o "$T/pre.dts")
rm "$ML/$Q/sm7325-xiaomi-redwood.dts" "$ML/$Q/sm7325-xiaomi-redwood-ft.dts"
scp -q "$T/pre.dts" "$H:/tmp/test.pre.dts"
ssh "$H" 'dtc -q -I dts -O dtb -o /tmp/test.dtb /tmp/test.pre.dts && cp /boot/boot.img /tmp/boot-cur.img'
scp -q "$H:/tmp/test.dtb" "$H:/tmp/boot-cur.img" "$T/"
python3 -I "$R/tools/swap_dtb.py" "$T/boot-cur.img" "$T/test.dtb" "$1"
rm -rf "$T"
