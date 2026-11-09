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
- ✅ Phosh (default), Plasma Mobile; clock clear of the camera cutout in Phosh

## Next

- 🔧 **Modem**: firmware, MPSS remoteproc, rmtfs, IPA, ModemManager.
  Without a SIM: boot, IMEI, firmware version, network scan, signal.
  Identity partitions (modemst1/2, fsg, persist) are backed up.
  - ⬜ Needs you: insert a SIM for registration, data, SMS
- ⬜ **Cell broadcast**: cellbroadcastd listening on emergency (SAE) channels;
  log all channels for a few days to see what Chilean carriers send
- ⬜ **Voice calls**: earpiece + mic routing for calls
  - ⬜ Needs you: make and talk on a test call
- ⬜ **Headset jack**: plug detection, headphone playback (WCD938x RX side),
  headset mic (AMIC2, already in UCM, untested)
  - ⬜ Needs you: plug in wired headphones
- ⬜ **Suspend / battery life**: sleep, wake on call/SMS

## Hardware not started

- ⬜ IR blaster
- ⬜ NFC (nq@28 on i2c9 in the stock DT)
- ⬜ Fingerprint reader (side key) — likely hard
- ⬜ USB-C: host mode, video out if supported, role switching
- ⬜ CDSP
- ⬜ Cameras — hardest, long term

## Fixes and polish

- ⬜ USB drop ~16 s into boot: find the real cause, drop redwood-usb-reset.timer
- ⬜ Battery: Xiaomi firmware numbers properties differently from ~12 on
  (temperature, technology, cycle count read wrong)
- ⬜ Compass: calibration / mount matrix (readings ~300 µT)
- ⬜ AMIC3: silent on every route; believed unpopulated, confirm
- ⬜ Plasma Mobile: clock under the camera cutout
- ⬜ Display: 120 Hz mode
- ⬜ Waydroid (last)
