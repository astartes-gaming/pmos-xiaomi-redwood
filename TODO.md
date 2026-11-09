# redwood TODO

Status of the port, roughly in priority order. ✅ done · 🔧 in progress · ⬜ not started.
"Needs you" = something only a person with the phone can do.

## Working

- ✅ Display (DSC panel), touch (FocalTech), GPU (freedreno / Turnip)
- ✅ Wi-Fi, Bluetooth (WCN6750)
- ✅ Speakers (2× AW88261), microphones: main (AMIC1) and secondary (AMIC5)
- ✅ Battery readout (pmic-glink battmgr), charging
- ✅ Vibration (AW86927)
- ✅ Sensors: accelerometer / auto-rotate, light, proximity, magnetometer
- ✅ USB networking (with a reset-timer workaround, see below)
- ✅ Modem hardware (see Next for SIM tests)
- ✅ IR blaster: ir-spi LED on spi15, /dev/lirc0 transmits (`ir-ctl -S nec:0x04`);
  logged-in user gets access via uaccess
  - ⬜ Needs you: confirm the LED lights (another phone's camera shows IR)
    or that it controls a TV
- ✅ Phosh (default), Plasma Mobile; clock clear of the camera cutout in Phosh

## Next

- ✅ **Modem** (no SIM): MPSS boots redwood's firmware, rmtfs/tqftpserv serve
  EFS and the modem_pr carrier configs, IPA up, ModemManager detects it
  (IMEI, firmware MPSS.HI.4.3.c2, carrier config Entel_CL). Radio online:
  network scan sees Claro, Movistar, WOM, Entel; camps on WCDMA for emergency.
  - ⬜ Needs you: insert a SIM for registration, LTE/5G, data, SMS
- 🔧 **Cell broadcast**: cellbroadcastd runs; device r8 enables the test and
  AMBER levels on top of the defaults (country channel mode), so SAE test
  alerts show. ModemManager only takes channel lists on an enabled modem.
  - ⬜ Needs a SIM: confirm channels get set; then log all channels for a
    few days (channel-mode none + `mmcli --cell-broadcast-set-channels=0-65535`)
    to see what Chilean carriers send
- ⬜ **Voice calls**: earpiece + mic routing for calls
  - ⬜ Needs you: make and talk on a test call
- ⬜ **Headset jack**: plug detection, headphone playback (WCD938x RX side),
  headset mic (AMIC2, already in UCM, untested)
  - ⬜ Needs you: plug in wired headphones
- ⬜ **Suspend / battery life**: sleep, wake on call/SMS

## Hardware not started

- ⬜ NFC: NXP SN1xx (vendor qcom,sn-nci) at 0x28 on **i2c4** (qupv3_se4),
  VEN gpio38, FW gpio40, CLKREQ gpio39, IRQ gpio41, 1.8 V supply. Mainline
  nxp-nci lists PN547/553/557 only and CONFIG_NFC is off; SN1xx support
  unclear, low priority (few Linux NFC apps)
- ⬜ Fingerprint reader (side key) — likely hard
- 🔧 USB-C: role switching wired (UCSI, r125); host mode / OTG untested,
  video out if supported
- ⬜ CDSP
- ⬜ Cameras — hardest, long term

## Fixes and polish

- ✅ `reboot bootloader` (NVMEM reboot-mode, kernel r118+): works, the phone
  lands in fastboot. But after a warm reboot from Linux the fastboot USB
  device does not enumerate on the PC until the cable is replugged
  (likely the same USB PHY state as the boot-time drop below)

- 🔧 USB drop: the ADSP charger firmware re-detects the port at ADSP start
  (~16 s into boot) and on every plug-in, leaving the HS PHY dead. Role
  toggle / gadget rebind don't recover; rebinding dwc3-qcom (PHY re-init)
  plus UCSI (stale role-switch handle) does. Device r11: boot run after the
  ADSP is up, udev-triggered run on typec partner add, 20 s cooldown
  (~8 s outage). UCSI role switch wired in DTS (kernel r125).
  - ⬜ Needs you: unplug/replug once on r11 (simulated plug event works)
  - ⬜ Real fix: re-init the PHY in-kernel on the charger's port event
- ⬜ Battery: Xiaomi firmware numbers properties differently from ~12 on
  (temperature, technology, cycle count read wrong)
- ⬜ Compass: calibration / mount matrix (readings ~300 µT)
- ⬜ AMIC3: silent on every route; believed unpopulated, confirm
- ⬜ Plasma Mobile: clock under the camera cutout
- ⬜ Display: 120 Hz mode
- ⬜ Waydroid (last)

## Release

- 🔧 Fastboot installer: `tools/flash-redwood.sh` written (export images, erase
  dtbo, flash boot + userdata, reboot-bootloader quirk); not yet run on a phone
- ⬜ Recovery-flashable zip (`pmbootstrap install --android-recovery-zip`);
  needs deviceinfo partition settings and a working redwood recovery
- ⬜ Public builds: fetch firmware from the user's own phone/ROM at install
  time; never ship one phone's persist calibration
- ⬜ GitHub Release with the installer files (ask before publishing: public)
