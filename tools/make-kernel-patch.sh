#!/bin/sh
# Regenerate kernel/0001-*.patch from this repo against a sparse checkout of
# sc7280-mainline/linux (default ~/.cache/redwood-ml), then refresh the local
# pmaports kernel package (copy patch, update checksum, bump pkgrel).
# Usage: tools/make-kernel-patch.sh [pkgrel]
set -e
R=$(cd "$(dirname "$0")/.." && pwd)
ML=${ML:-$HOME/.cache/redwood-ml}
P=$R/kernel/0001-arm64-dts-qcom-add-xiaomi-redwood.patch
Q=arch/arm64/boot/dts/qcom
F=drivers/input/touchscreen/focaltech_touch/focaltech_common.h
PN=drivers/gpu/drm/panel
cd "$ML"
git checkout -q -- $Q/Makefile $F $PN/Kconfig $PN/Makefile
cp "$R"/dts/sm7325-xiaomi-redwood.dts "$R"/dts/sm7325-xiaomi-redwood-ft.dts $Q/
cp "$R"/kernel/panel-xiaomi-m20-42-0d-0b.c $PN/
sed -i 's|^dtb-$(CONFIG_ARCH_QCOM)\t+= sm7325-xiaomi-taoyao.dtb|&\ndtb-$(CONFIG_ARCH_QCOM)\t+= sm7325-xiaomi-redwood.dtb\ndtb-$(CONFIG_ARCH_QCOM)\t+= sm7325-xiaomi-redwood-ft.dtb|' $Q/Makefile
sed -i 's/^#define FTS_AUTO_UPGRADE_EN 1$/#define FTS_AUTO_UPGRADE_EN 0 \/* never flash the bundled (Nothing Phone 1) touch firmware onto other devices *\//' $F
python3 - $PN/Kconfig $PN/Makefile <<'PY'
import sys
k, m = sys.argv[1], sys.argv[2]
s = open(k).read()
anchor = 'config DRM_PANEL_XINPENG_XPP055C272\n'
new = '''config DRM_PANEL_XIAOMI_M20_42_0D_0B
	tristate "Xiaomi redwood M20 42 0d 0b DSC panel"
	depends on OF
	depends on DRM_MIPI_DSI
	depends on BACKLIGHT_CLASS_DEVICE
	select DRM_DISPLAY_DSC_HELPER
	select DRM_DISPLAY_HELPER
	help
	  Say Y or M here if you want to enable support for the 1080x2400
	  120 Hz DSC video mode AMOLED panel of the Xiaomi POCO X5 Pro 5G /
	  Redmi Note 12 Pro Speed (redwood).

'''
open(k, 'w').write(s.replace(anchor, new + anchor, 1))
s = open(m).read()
a = 'obj-$(CONFIG_DRM_PANEL_XIAOMI_42_02_0A) += panel-l9-42-02-0a-dsc.o\n'
open(m, 'w').write(s.replace(a, a + 'obj-$(CONFIG_DRM_PANEL_XIAOMI_M20_42_0D_0B) += panel-xiaomi-m20-42-0d-0b.o\n', 1))
PY
git add -N $Q/sm7325-xiaomi-redwood.dts $Q/sm7325-xiaomi-redwood-ft.dts $PN/panel-xiaomi-m20-42-0d-0b.c
{ sed -n '1,/^---$/p' "$P"; git diff; } > "$P.new"
mv "$P.new" "$P"
git reset -q
git checkout -q -- $Q/Makefile $F $PN/Kconfig $PN/Makefile
rm $Q/sm7325-xiaomi-redwood.dts $Q/sm7325-xiaomi-redwood-ft.dts $PN/panel-xiaomi-m20-42-0d-0b.c

K="$(pmbootstrap config aports)/device/community/linux-postmarketos-qcom-sc7280"
cp "$P" "$K/"
h=$(sha512sum "$P" | cut -d' ' -f1)
sed -i "s/^[0-9a-f]\{128\}  0001-arm64-dts-qcom-add-xiaomi-redwood.patch/$h  0001-arm64-dts-qcom-add-xiaomi-redwood.patch/" "$K/APKBUILD"
[ -n "$1" ] && sed -i "s/^pkgrel=[0-9]*$/pkgrel=$1/" "$K/APKBUILD"
echo "patch regenerated; $(grep '^pkgrel' "$K/APKBUILD")"
