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
  - ✅ LED confirmed on hardware (seen flashing through a phone camera)
- ✅ Phosh (default), Plasma Mobile; clock clear of the camera cutout in Phosh

## Next

- ✅ **Modem** (no SIM): MPSS boots redwood's firmware, rmtfs/tqftpserv serve
  EFS and the modem_pr carrier configs, IPA up, ModemManager detects it
  (IMEI, firmware MPSS.HI.4.3.c2, carrier config Entel_CL). Radio online:
  network scan sees Claro, Movistar, WOM, Entel; camps on WCDMA for emergency.
  - ✅ SIM (Entel): registered home, LTE + 5G NR (NSA; NR leg attaches during
    traffic), mobile data via NM gsm connection (APN imovil.entelpcs.cl):
    ping OK, 6.9 Mbit/s on weak signal (RSRP -120 dBm)
  - ✅ SMS send and receive in Chats (incoming can take a few minutes on
    this weak signal). Spacebar/Plasma Dialer removed: their daemons grabbed
    incoming SMS in the Phosh session
- 🔧 **Cell broadcast**: cellbroadcastd runs; device r8 enables the test and
  AMBER levels on top of the defaults (country channel mode), so SAE test
  alerts show. ModemManager only takes channel lists on an enabled modem.
  - ✅ With SIM: modem takes the channel list 4370-4379, 4397 (Chile SAE)
  - ⬜ Log all channels for a
    few days (channel-mode none + `mmcli --cell-broadcast-set-channels=0-65535`)
    to see what Chilean carriers send
- 🔧 **Voice calls**: q6voice (q6mvm/q6cvs/q6cvp) is in the kernel; DT now
  enables it with a VoiceMMode1 link (hw:N,3), UCM "Voice Call" verb
  (earpiece = top AW88261 in Receiver profile, speakerphone, Mic1/Mic2,
  dummystreamhack). Downlink works: the other party is heard in the earpiece.
  - ⬜ Uplink silent: mic path powered identically to recording, but in call
    mode TX_CODEC_DMA_TX_3 yields zeros (also to MultiMedia2). Lost inside the
    DSP voice session; compare with dubai/fp5 (same stack, calls work)
  - ⬜ Mic level ~48 dB low everywhere (peaks capped ~1/256 FS): looks like a
    24/32-bit alignment issue on the TX codec DMA port
  - ⬜ Headphones in calls: q6routing has no RX_CODEC_DMA_RX_0 voice mixer
- ✅ **Headphones** (kernel r128, device r12): jack detection, stereo
  playback via WCD938x HPH (RX_CODEC_DMA_RX_0, SoundWire RX). Needed the
  vendor 48 kHz SoundWire sample intervals (HPH_CLH 31, LO 7); kodiak's 63/3
  gave silence. UCM "Headphones" device (JackControl), analog gain -12 dB.
  - ✅ r129/r14: headphones on their own front end (MultiMedia3, hw:N,2) so
    PulseAudio gets one profile with both outputs; Phosh switches speaker
    <-> headphones on plug/unplug (tested). The audio backend here is
    PulseAudio (postmarketos-base-ui-audio-backend-pulseaudio)
  - ⬜ Headset mic (AMIC2): needs a headset with a mic
  - ⬜ Pop/static when playback stops
- 🔧 **Suspend / battery life**: deep (PSCI) suspend works on r130/r15:
  slept a full 20 s / 60 s with all CPUs off and resumed cleanly. The
  blocker was the Bluetooth UART (99c000.serial) wake IRQ aborting every
  attempt ("Wakeup pending. Abort CPU freeze"); device r15 disables its
  wakeup via udev. Kernel r130 has PM_DEBUG / PM_SLEEP_DEBUG.
  - ⬜ Needs you: power button wake from deep sleep (first try: no wake)
  - ⬜ wake on call/SMS, battery drain

## Hardware not started

- ⬜ NFC: NXP SN1xx (vendor qcom,sn-nci) at 0x28 on **i2c4** (qupv3_se4),
  VEN gpio38, FW gpio40, CLKREQ gpio39, IRQ gpio41, 1.8 V supply. Mainline
  nxp-nci lists PN547/553/557 only and CONFIG_NFC is off; SN1xx support
  unclear, low priority (few Linux NFC apps)
- ⬜ Fingerprint reader (side key) — likely hard
- ✅ USB-C host mode / OTG: UCSI switches dwc3 to host (r125); 8BitDo USB
  keyboard works through an OTG adapter (after the ~8 s plug-in reset).
- ⬜ USB-C: video out, if the port supports it
- ⬜ CDSP
- ⬜ Cameras — hardest, long term

## Fixes and polish

- ✅ `reboot bootloader` (NVMEM reboot-mode, kernel r118+): works, the phone
  lands in fastboot. But after a warm reboot from Linux the fastboot USB
  device does not enumerate on the PC until the cable is replugged
  (likely the same USB PHY state as the boot-time drop below)

- ✅ USB drop (worked around): the ADSP charger firmware re-detects the port at ADSP start
  (~16 s into boot) and on every plug-in, leaving the HS PHY dead. Role
  toggle / gadget rebind don't recover; rebinding dwc3-qcom (PHY re-init)
  plus UCSI (stale role-switch handle) does. Device r11: boot run after the
  ADSP is up, udev-triggered run on typec partner add, 20 s cooldown
  (~8 s outage). UCSI role switch wired in DTS (kernel r125).
  - ✅ Physical replug on r11: USB back ~8 s after plug-in
  - ✅ r13: UCSI rebind occasionally times out (PPM init failed); the
    script now retries until typec port0 appears
  - ⬜ Real fix: re-init the PHY in-kernel on the charger's port event
- ✅ Battery: Xiaomi firmware inserts BATT_CONSTANT_CURRENT at 12, shifting
  IDs >= TEMP by one (MiCode redwood-s-oss qti_battery_charger.c). Kernel
  r127 maps them: temp, technology, charge counter, cycle count, model now
  correct. power_now reads 10 W at 0 A (meaning unclear); charge_full and
  charge_full_design: firmware returns no data
- 🔧 Compass: the compass (iio-sensor-proxy / libssc) uses the DSP's fused
  'rotv' rotation vector, which calibrates internally. Only the raw 'mag'
  magnetometer shows the hard-iron offset (~320 uT; figure-8 fit gives
  offset (-257, -194, +31) uT, radius 19.8 uT vs ~23 uT in Santiago). libssc
  could subtract SSC 'mag_cal' bias (sns_mag_cal.json ships) for raw users.
  - ❌ 90 deg turn test: heading moves the right way but only ~40-50%
    (48 deg cw, 36 deg ccw), so rotv is NOT removing the hard-iron offset.
    Writing the fitted offset into ak0991x fac_cal.bias (registry) did not
    change raw mag and made the turn test worse (15 deg); reverted.
    Next: find how the DSP fusion gets mag calibration (mag_cal anomaly
    threshold is 200 uT, below the ~320 uT raw field), else correct in libssc
- ⬜ AMIC3: silent on every route; believed unpopulated, confirm
- ⬜ Plasma Mobile: no notch support upstream (plasma-mobile#276); its clock
  sits at the left, so the centre punch-hole may not cover anything
  - ⬜ Needs you: look at Plasma's status bar once
- ✅ Display: 120 Hz (vendor's single timing, video mode + DSC); measured
  120 vblank IRQs/s with the screen on
- ⬜ Waydroid (last)

## Release

- ✅ Fastboot installer: `tools/flash-redwood.sh` tested end to end on
  hardware (erase dtbo, flash boot + userdata, reboot bootloader, boot)
- ⬜ Recovery-flashable zip (`pmbootstrap install --android-recovery-zip`);
  needs deviceinfo partition settings and a working redwood recovery
- 🔧 Public builds: device r17 no longer depends on firmware-xiaomi-redwood
  (opt-in: add it to pmbootstrap extra_packages for a personal build; leave
  it out for public images; pmbootstrap always installs -nonfree-*
  subpackages, so it is not one). redwood-firmware-setup runs
  on first boot when firmware is missing: mounts modem/bluetooth/dsp/persist
  and vendor (super) read-only, builds the same files (squash_mdt,
  ath11k_board2 with the hwc board file), reboots once. Verified: generated
  606 files byte-identical to the firmware package (ROOT= test run)
  - ✅ Fresh install of a blob-free image via tools/flash-redwood.sh: first
    boot installed the firmware (slot _b, hwc GL) and rebooted once; second
    boot: modem/ADSP/WPSS running, touch fw, GPU, Wi-Fi, BT, sound card,
    modem, battery, sensors, IR all up, no failed units
- ⬜ GitHub Release with the installer files (ask before publishing: public)
