#!/bin/sh
# Redwood USB workaround. The ADSP charger firmware re-detects the USB-C port
# when it starts (~16 s into boot) and on every cable plug-in; afterwards the
# HS PHY no longer works. Rebinding dwc3-qcom re-initialises it. UCSI is then
# rebound too, as it keeps a handle to the old dwc3 role switch.
#   boot: wait for the ADSP, then reset
#   plug: (udev, typec partner added) reset unless one ran in the last 20 s
stamp=/run/redwood-usb-reset.stamp

case "$1" in
boot)
	for i in $(seq 120); do
		for r in /sys/class/remoteproc/*; do
			[ "$(cat "$r/name")" = adsp ] && [ "$(cat "$r/state")" = running ] && break 2
		done
		sleep 0.5
	done
	sleep 3
	;;
plug)
	sleep 3
	;;
*)
	echo "usage: $0 boot|plug" >&2
	exit 1
	;;
esac

# Boot and plug runs can coincide: serialise, and skip if one just ran
exec 9> /run/redwood-usb-reset.lock
flock 9
now=$(cut -d. -f1 /proc/uptime)
if [ -e $stamp ] && [ $((now - $(cat $stamp))) -lt 20 ]; then
	exit 0
fi
cut -d. -f1 /proc/uptime > $stamp
d=/sys/bus/platform/drivers/dwc3-qcom
u=/sys/bus/auxiliary/drivers/ucsi_glink.pmic_glink_ucsi
g=/sys/kernel/config/usb_gadget/g1
echo a600000.usb > $d/unbind
sleep 2
echo a600000.usb > $d/bind
sleep 2
[ -d $g ] && [ -z "$(cat $g/UDC)" ] && echo a600000.usb > $g/UDC
# UCSI init sometimes times out ("PPM init failed") and the port never
# appears; without it dwc3 gets no role. Retry until port0 shows up.
if [ -e $u/pmic_glink.ucsi.0 ]; then
	for try in 1 2 3; do
		echo pmic_glink.ucsi.0 > $u/unbind
		sleep 1
		echo pmic_glink.ucsi.0 > $u/bind
		for i in $(seq 24); do
			[ -e /sys/class/typec/port0 ] && break 2
			sleep 0.5
		done
		echo "redwood-usb-reset: UCSI port missing, retry $try" >&2
	done
fi
# The UCSI rebind re-adds the partner; keep the cooldown counting from now
cut -d. -f1 /proc/uptime > $stamp
exit 0
