#!/bin/sh
# Adds the redwood DTS patch and simpledrm to the local
# linux-postmarketos-qcom-sc7280 package in pmbootstrap's pmaports checkout.
# Run again after `pmbootstrap pull` resets pmaports.
set -e
here=$(cd "$(dirname "$0")" && pwd)
K="$(pmbootstrap config aports)/device/community/linux-postmarketos-qcom-sc7280"
cp "$here/0001-arm64-dts-qcom-add-xiaomi-redwood.patch" "$K/"
python3 - "$K/APKBUILD" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
patch = "0001-arm64-dts-qcom-add-xiaomi-redwood.patch"
if patch not in s:
    s = s.replace("\t$_config\n", "\t$_config\n\t" + patch + "\n", 1)
anchor = '\tcp "$srcdir/config-$_flavor.$arch" .config\n'
if "DRM_SIMPLEDRM" not in s:
    s = s.replace(anchor, anchor +
        "\t# redwood bring-up: no panel driver yet, use the bootloader framebuffer\n"
        "\tsed -i '/CONFIG_SYSFB_SIMPLEFB/d; /CONFIG_DRM_SIMPLEDRM/d' .config\n"
        "\tprintf 'CONFIG_SYSFB_SIMPLEFB=y\\nCONFIG_DRM_SIMPLEDRM=y\\nCONFIG_DRM_PANEL_XIAOMI_M20_42_0D_0B=m\\nCONFIG_NVMEM_REBOOT_MODE=y\\nCONFIG_NVMEM_SPMI_SDAM=y\\n' >> .config\n"
        '\tmake ARCH="$_carch" LLVM=1 olddefconfig\n', 1)
# Bump pkgrel far above upstream so pmbootstrap builds this locally
# instead of installing the prebuilt kernel (which lacks the redwood DTB).
import re
s = re.sub(r"(?m)^pkgrel=\d+$", "pkgrel=100", s)
open(p, "w").write(s)
PY
echo "Patched $K/APKBUILD; now run: pmbootstrap checksum linux-postmarketos-qcom-sc7280"
