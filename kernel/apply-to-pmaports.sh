#!/bin/sh
# Adds the redwood DTS patch and simpledrm to the local
# linux-postmarketos-qcom-sc7280 package in pmbootstrap's pmaports checkout.
# Run again after `pmbootstrap pull` resets pmaports.
set -e
here=$(cd "$(dirname "$0")" && pwd)
K="$(pmbootstrap config aports)/device/community/linux-postmarketos-qcom-sc7280"
cp "$here/0001-arm64-dts-qcom-add-xiaomi-redwood.patch" "$K/"
grep -q 0001-arm64-dts-qcom-add-xiaomi-redwood.patch "$K/APKBUILD" || \
	sed -i 's|^\t\$_config$|\t$_config\n\t0001-arm64-dts-qcom-add-xiaomi-redwood.patch|' "$K/APKBUILD"
grep -q DRM_SIMPLEDRM "$K/APKBUILD" || \
	sed -i 's|^\tcp "\$srcdir/config-\$_flavor.\$arch" .config$|&\n\t# redwood bring-up: no panel driver yet, use the bootloader framebuffer\n\t./scripts/config --enable SYSFB_SIMPLEFB --enable DRM_SIMPLEDRM\n\tmake ARCH="$_carch" LLVM=1 olddefconfig|' "$K/APKBUILD"
echo "Patched $K/APKBUILD; now run: pmbootstrap checksum linux-postmarketos-qcom-sc7280"
