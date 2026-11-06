# Bring-up checklist

1. **Unlock the bootloader** with Xiaomi's official Mi Unlock tool. This wipes the phone.
2. **Back up** the stock `boot`, `vendor_boot`, `dtbo`, and firmware partitions.
3. **Read the stock boot.img header** (`unpack_bootimg`) and fix the TODO values in `deviceinfo`.
4. **Collect hardware info** from the downstream (Android) kernel and device tree: panel, touchscreen, regulators, reserved memory.
5. **Write the device tree** in `dts/`, starting from `sm7325-nothing-spacewar.dts` in sc7280-mainline/linux.
6. **First boot goal:** simple-framebuffer + USB networking, then `ssh user@172.16.42.1`.
7. **Extract firmware** blobs into a separate repo for `firmware-xiaomi-redwood`.
8. **Work through the rest of the hardware:** panel driver, touch, Wi-Fi, audio, modem.
9. **Upstream:** send the DT to sc7280-mainline and the packages to pmaports.

Help: Matrix `#sc7280-mainline:postmarketos.org`.
