#!/usr/bin/env python3
"""Patch the out-of-tree FocalTech driver (sc7280-mainline) so it loads the
touch firmware named by the DT "firmware-name" property via request_firmware.

FT3680 is flashless: firmware is downloaded to the chip's RAM on every boot
(no flash erase/write commands exist in this driver's FT3680 path). When a
firmware-name is given and loading fails, do NOT fall back to the bundled
image, which belongs to another phone (Nothing Phone 1).
Usage: fts-firmware-name.py <path to drivers/input/touchscreen/focaltech_touch>
"""
import sys
d = sys.argv[1]
p = d + "/focaltech_flash.c"
s = open(p).read()

s = s.replace("#define FTS_FW_REQUEST_SUPPORT\t\t0", "#define FTS_FW_REQUEST_SUPPORT\t\t1", 1)
assert "#define FTS_FW_REQUEST_SUPPORT\t\t1" in s

helper = '''
/* Firmware file: DT "firmware-name" if present, else focaltech_ts_fw_<vendor>.bin */
static bool fts_fw_name(struct fts_upgrade *upg, char *buf, size_t len)
{
	const char *dt_name = NULL;

	if (!of_property_read_string(upg->ts_data->dev->of_node,
				     "firmware-name", &dt_name)) {
		snprintf(buf, len, "%s", dt_name);
		return true;
	}
	snprintf(buf, len, "%s%s.bin", FTS_FW_NAME_PREX_WITH_REQUEST,
		 upg->module_info->vendor_name);
	return false;
}
'''
anchor = "static int fts_read_file_request_firmware("
assert anchor in s
s = s.replace(anchor, helper.lstrip("\n") + "\n" + anchor, 1)

# resume/recovery download path
old = '''		snprintf(fwname, FILE_NAME_LENGTH, "%s%s.bin",
			 FTS_FW_NAME_PREX_WITH_REQUEST,
			 upg->module_info->vendor_name);
		ret = request_firmware(&fw, fwname, upg->ts_data->dev);'''
new = '''		bool dt_fw = fts_fw_name(upg, fwname, FILE_NAME_LENGTH);

		ret = request_firmware(&fw, fwname, upg->ts_data->dev);
		if (ret && dt_fw) {
			dev_err(fts_data->dev, "firmware(%s) missing, not using bundled fw\\n", fwname);
			return ret;
		}'''
assert old in s, "resume path"
s = s.replace(old, new, 1)

# boot-time upgrade path
old = '''	snprintf(fwname, FILE_NAME_LENGTH, "%s%s.bin",
		 FTS_FW_NAME_PREX_WITH_REQUEST, upg->module_info->vendor_name);
'''
new = '''	fts_fw_name(upg, fwname, FILE_NAME_LENGTH);
'''
assert old in s, "boot path"
s = s.replace(old, new, 1)

old = '''	if (FTS_FW_REQUEST_SUPPORT) {
		msleep(500);
		ret = fts_get_fw_file_via_request_firmware(upg);
		if (ret != 0) {
			get_fw_i_flag = true;
		}
	} else {'''
new = '''	if (FTS_FW_REQUEST_SUPPORT) {
		char name[FILE_NAME_LENGTH];

		msleep(500);
		ret = fts_get_fw_file_via_request_firmware(upg);
		if (ret != 0) {
			if (fts_fw_name(upg, name, sizeof(name))) {
				dev_err(fts_data->dev, "firmware(%s) missing, not using bundled fw", name);
				return -ENOENT;
			}
			get_fw_i_flag = true;
		}
	} else {'''
assert old in s, "get_fw_file"
s = s.replace(old, new, 1)
if "#include <linux/of.h>" not in s:
    s = s.replace('#include "focaltech_core.h"', '#include <linux/of.h>\n#include "focaltech_core.h"', 1)
    assert "#include <linux/of.h>" in s, "include"
open(p, "w").write(s)
print("focaltech_flash.c patched")
