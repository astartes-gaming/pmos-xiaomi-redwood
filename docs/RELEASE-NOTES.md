# postmarketOS for Xiaomi redwood — pre-release 2026-11-09

POCO X5 Pro 5G / Redmi Note 12 Pro Speed (SM7325), mainline kernel 7.2.9
(sc7280-mainline) with the redwood device tree. Phosh, with Plasma Mobile
installable.

> Unofficial port. Do **not** report bugs to the postmarketOS developers;
> use this repository's issue tracker.

## Install

Unlocked bootloader required. Installing **wipes userdata** (Android data).

1. Download `boot.img`, `xiaomi-redwood.img.zst`, `flash-redwood.sh` and
   `SHA256SUMS` into one folder; check them with `sha256sum -c SHA256SUMS`
   and decompress: `zstd -d xiaomi-redwood.img.zst`.
2. Boot the phone into fastboot (Volume Down + Power), connect USB and run
   `sh flash-redwood.sh .` in that folder.
3. First boot copies the phone's firmware from its own partitions and
   reboots once, so it takes a little longer. Log in as `user`, password
   `147147`, and change it (`passwd`).

The images contain no proprietary firmware: each phone provides its own
(modem, Wi-Fi, Bluetooth, DSP, sensor calibration).

## Working

- Display (120 Hz, DSC), touch, GPU (freedreno / Turnip)
- Wi-Fi, Bluetooth
- Speakers, main and secondary microphones
- Headphones (3.5 mm): detection, stereo playback, automatic switching
- Battery and charging readout (temperature, cycle count, health)
- Vibration, IR blaster
- Sensors: accelerometer / auto-rotate, light, proximity
- USB networking (SSH), USB host mode (OTG keyboards etc.)
- Modem: firmware boots, networks found, emergency camping (SIM features
  untested, see below)
- Deep suspend (RTC wake tested)
- Reboot to bootloader

## Known issues

- USB drops ~16 s into boot and on every plug-in and is re-initialised
  automatically (~8 s outage). After `reboot bootloader`, replug the cable
  for fastboot to show up on the PC.
- Bluetooth cannot wake the phone from suspend (its wake IRQ aborted every
  suspend attempt, so it is disabled).
- Compass heading under-reports turns (~half); magnetometer calibration
  is not applied by the sensor DSP yet.
- Small pop when headphone playback stops.

## Not tested / not working

- SIM features: calls, SMS, mobile data, cell broadcast channels
- Headset microphone, wake on call/SMS, power-button wake from suspend
- Not supported: cameras, fingerprint reader, NFC, USB-C video out, CDSP
