#!/bin/sh
# Install postmarketOS on a Xiaomi redwood (POCO X5 Pro 5G) in fastboot mode.
#
#   pmbootstrap install
#   pmbootstrap export /tmp/redwood        # boot.img + xiaomi-redwood.img
#   tools/flash-redwood.sh /tmp/redwood
#
# WIPES userdata (all Android data). Needs an unlocked bootloader and the
# phone in fastboot (Volume Down + Power). Writes boot to the active slot.
# Redwood quirks handled here:
#   - dtbo_a and dtbo_b must be erased, or the bootloader hangs
#   - after flash/erase, `fastboot reboot bootloader` before booting
set -eu

dir=${1:?usage: $0 EXPORT_DIR (from pmbootstrap export)}
boot=$dir/boot.img
rootfs=$dir/xiaomi-redwood.img
for f in "$boot" "$rootfs"; do
	[ -e "$f" ] || { echo "missing $f" >&2; exit 1; }
done

product=$(fastboot getvar product 2>&1 | sed -n 's/^product: *//p')
[ "$product" = redwood ] || { echo "fastboot device is '$product', not redwood" >&2; exit 1; }
slot=$(fastboot getvar current-slot 2>&1 | sed -n 's/^current-slot: *//p')
[ -n "$slot" ] || { echo "could not read current slot" >&2; exit 1; }

echo "Flashing to slot $slot. This erases userdata. Ctrl+C within 10 s to abort."
sleep 10

fastboot erase dtbo_a
fastboot erase dtbo_b
fastboot flash "boot_$slot" "$boot"
fastboot flash userdata "$rootfs"
fastboot reboot bootloader
echo "Waiting for the bootloader..."
fastboot getvar product >/dev/null 2>&1
fastboot reboot
echo "Done. First boot can take a minute; USB networking: ssh user@172.16.42.1"
