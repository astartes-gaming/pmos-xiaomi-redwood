#!/usr/bin/env python3
"""Patch qcom_battmgr.c: Xiaomi's battery property numbering (redwood).

Xiaomi's charger firmware inserts BATT_CONSTANT_CURRENT at 12 (see
qti_battery_charger.c in MiCode/Xiaomi_Kernel_OpenSource redwood-s-oss),
so every battery property from BATT_TEMP on is one higher than mainline:
mainline read the 2 A constant current as temperature, the temperature as
technology, the charge counter as cycle count and so on. Units match
mainline (temperature in 1/100 degC, divided to 1/10 as before).

Shift battery property IDs >= BATT_TEMP by one on request and back on
reply when the machine is xiaomi,redwood. USB/wireless IDs match mainline.
Usage: battmgr-xiaomi-props.py qcom_battmgr.c   (edits in place)
"""
import sys

p = sys.argv[1]
s = open(p).read()


def sub(old, new):
    global s
    if s.count(old) != 1:
        sys.exit(f"expected one match for: {old[:60]!r}")
    s = s.replace(old, new)


sub("#include <linux/of_device.h>\n",
    "#include <linux/of.h>\n#include <linux/of_device.h>\n")
sub("\tenum qcom_battmgr_variant variant;\n",
    "\tenum qcom_battmgr_variant variant;\n"
    "\t/* Xiaomi firmware: battery IDs >= BATT_TEMP are one higher */\n"
    "\tbool xiaomi_bat_props;\n")
sub("""					 int property, u32 value)
{
""", """					 int property, u32 value)
{
	if (battmgr->xiaomi_bat_props &&
	    (opcode == BATTMGR_BAT_PROPERTY_GET || opcode == BATTMGR_BAT_PROPERTY_SET) &&
	    property >= BATT_TEMP && property <= BATT_POWER_AVG)
		property++;

""")
start = s.index("static void qcom_battmgr_sm8350_callback(")
cb = s[start:]
old = """	case BATTMGR_BAT_PROPERTY_GET:
		property = le32_to_cpu(resp->intval.property);
"""
if cb.count(old) < 1:
    sys.exit("BAT_PROPERTY_GET case not found")
cb = cb.replace(old, old + """		if (battmgr->xiaomi_bat_props &&
		    property > BATT_TEMP && property <= BATT_POWER_AVG + 1)
			property--;
""", 1)
s = s[:start] + cb
sub("""		battmgr->variant = QCOM_BATTMGR_SM8350;
""", """		battmgr->variant = QCOM_BATTMGR_SM8350;
	battmgr->xiaomi_bat_props = of_machine_is_compatible("xiaomi,redwood");
""")
open(p, "w").write(s)
