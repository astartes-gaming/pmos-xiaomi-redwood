# postmarketOS for Xiaomi POCO X5 Pro 5G / Redmi Note 12 Pro Speed (redwood)

> **Unofficial port.** Please do not report bugs from this port to the postmarketOS / Nura developers. Open an issue in this repository instead.

Work-in-progress postmarketOS port for `xiaomi-redwood` (Snapdragon 778G, SM7325), using the
mainline `linux-postmarketos-qcom-sc7280` kernel.

**Status: boots to a working console with display and touch (RAM boot via `fastboot boot`).**

| Works | Notes |
|---|---|
| Display | own DSC panel driver (`kernel/panel-xiaomi-m20-42-0d-0b.c`), 1080x2400@120 |
| Touch | FocalTech FT3680; firmware loaded into chip RAM at boot (see below) |
| USB networking / SSH, UFS, buttons | |

| Not yet | |
|---|---|
| GPU, audio, Wi-Fi/BT, modem, battery/charging, cameras | |

Bring-up requirements found on this device:
- `dtbo_a` **and** `dtbo_b` must be erased, or the bootloader hangs.
- After any `fastboot flash`/`erase`, run `fastboot reboot bootloader` before `fastboot boot`.
- Touch firmware `focaltech_ts_fw_m20.bin` (from the stock vendor partition, `/vendor/firmware`) must be in `/lib/firmware` on the rootfs. It is proprietary and not part of this repo.

## Layout

| Path | Purpose |
|---|---|
| `device-xiaomi-redwood/` | pmaports device package, based on `device-nothing-spacewar` |
| `firmware-xiaomi-redwood/` | firmware package (blobs repo still to be created) |
| `dts/` | mainline device tree for sc7280-mainline/linux |
| `kernel/` | patch adding the DTS to the kernel, plus a script to apply it (and simpledrm) to pmaports |
| `docs/BRINGUP.md` | step-by-step bring-up checklist |

## Using with pmbootstrap

```sh
pmbootstrap init                       # pick any device first so pmaports is cloned
cp -r device-xiaomi-redwood firmware-xiaomi-redwood "$(pmbootstrap config aports)/device/testing/"
kernel/apply-to-pmaports.sh
pmbootstrap checksum device-xiaomi-redwood linux-postmarketos-qcom-sc7280
pmbootstrap init                       # now choose vendor "xiaomi", device "redwood"
pmbootstrap install
pmbootstrap flasher boot               # RAM-only test boot, nothing written
# once it works:
pmbootstrap flasher flash_rootfs       # overwrites userdata!
pmbootstrap flasher flash_kernel
```

## References

- Wiki page: https://wiki.postmarketos.org/wiki/Xiaomi_POCO_X5_Pro_/_Redmi_Note_12_Pro_Speed_(xiaomi-redwood)
- SoC page: https://wiki.postmarketos.org/wiki/Qualcomm_Snapdragon_778G_(SM7325)
- Mainline kernel: https://github.com/sc7280-mainline/linux
- Template port: `device/testing/device-nothing-spacewar` in pmaports

## License

Packaging files: MIT. Device tree: BSD-3-Clause (kernel convention).
