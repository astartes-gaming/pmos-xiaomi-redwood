# postmarketOS for Xiaomi POCO X5 Pro 5G / Redmi Note 12 Pro Speed (redwood)

> **Unofficial port.** Please do not report bugs from this port to the postmarketOS / Nura developers. Open an issue in this repository instead.

Work-in-progress postmarketOS port for `xiaomi-redwood` (Snapdragon 778G, SM7325), using the
mainline `linux-postmarketos-qcom-sc7280` kernel.

**Status: daily-driver basics work** (Phosh / Plasma Mobile, Wi-Fi, Bluetooth, audio,
sensors, modem hardware). Calls and mobile data still need SIM testing. See
[TODO.md](TODO.md) for the full list.

| Works | Notes |
|---|---|
| Display | own DSC panel driver (`kernel/panel-xiaomi-m20-42-0d-0b.c`), 1080x2400 |
| Touch | FocalTech FT3680; firmware loaded into chip RAM at boot |
| GPU | Adreno 642L: freedreno (OpenGL ES 3.2), Turnip (Vulkan 1.3) |
| Wi-Fi, Bluetooth | WCN6750 (WPSS + ath11k, uart7 Bluetooth) |
| Speakers, microphones | 2× AW88261 on Primary MI2S; WCD938x main + secondary mic |
| Battery, charging | pmic-glink battmgr (some extended values read wrong) |
| Vibration | AW86927 |
| Sensors | ADSP sensor hub via hexagonrpcd: auto-rotate, light, proximity, compass |
| Modem | boots, IMEI, network scan without a SIM; SIM tests pending |
| IR blaster | ir-spi LED, `/dev/lirc0` |
| USB networking / SSH, UFS, buttons, reboot to bootloader | USB uses a reset-timer workaround |

| Not yet | |
|---|---|
| Calls, mobile data, SMS (need a SIM), headset jack, suspend | |
| NFC, fingerprint, cameras, USB host mode | |

Bring-up requirements found on this device:
- `dtbo_a` **and** `dtbo_b` must be erased, or the bootloader hangs.
- After any `fastboot flash`/`erase`, run `fastboot reboot bootloader` before booting.
- The proprietary firmware (touch, GPU, Wi-Fi, ADSP, modem, sensors, Bluetooth) is not part
  of this repo. `tools/collect-firmware.sh` and `tools/collect-sensors.sh` extract it from the
  stock ROM's vendor image and the phone's own partitions.

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
# install for real (WIPES userdata; erases dtbo, flashes boot + rootfs):
pmbootstrap export /tmp/redwood
tools/flash-redwood.sh /tmp/redwood
```

## References

- Wiki page: https://wiki.postmarketos.org/wiki/Xiaomi_POCO_X5_Pro_/_Redmi_Note_12_Pro_Speed_(xiaomi-redwood)
- SoC page: https://wiki.postmarketos.org/wiki/Qualcomm_Snapdragon_778G_(SM7325)
- Mainline kernel: https://github.com/sc7280-mainline/linux
- Template port: `device/testing/device-nothing-spacewar` in pmaports

## License

Packaging files: MIT. Device tree: BSD-3-Clause (kernel convention).
