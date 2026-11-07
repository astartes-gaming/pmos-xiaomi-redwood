#!/usr/bin/env python3
"""Teach the out-of-tree FocalTech driver Xiaomi's "super resolution" touch
report format (DT: focaltech,super-resolution-factors = <10>).

In that mode each coordinate is a 15-bit value at 10x resolution:
  x = XH[3:0]<<11 | XL<<3 | PRE[7:6]<<1 | XH[5]
  y = YH[3:0]<<11 | YL<<3 | PRE[5:4]<<1 | YH[4]
pressure = PRE[3:0], area = AREA[6:0]  (from the Xiaomi FT3680 driver).
Usage: fts-super-resolution.py <path to focaltech_touch>
"""
import sys
d = sys.argv[1]

h = d + "/focaltech_core.h"
s = open(h).read()
old = "\tu32 max_touch_number;\n};"
assert old in s, "pdata"
s = s.replace(old, "\tu32 max_touch_number;\n\tu32 super_resolution;\n};", 1)
open(h, "w").write(s)

c = d + "/focaltech_core.c"
s = open(c).read()

helper = '''
static void fts_decode_point(struct fts_ts_data *ts_data, const u8 *b,
			     struct ts_event *ev)
{
	if (ts_data->pdata->super_resolution == 10) {
		ev->x = ((b[FTS_TOUCH_OFF_E_XH] & 0x0F) << 11) |
			(b[FTS_TOUCH_OFF_XL] << 3) |
			(((b[FTS_TOUCH_OFF_PRE] & 0xC0) >> 6) << 1) |
			((b[FTS_TOUCH_OFF_E_XH] & 0x20) >> 5);
		ev->y = ((b[FTS_TOUCH_OFF_ID_YH] & 0x0F) << 11) |
			(b[FTS_TOUCH_OFF_YL] << 3) |
			(((b[FTS_TOUCH_OFF_PRE] & 0x30) >> 4) << 1) |
			((b[FTS_TOUCH_OFF_ID_YH] & 0x10) >> 4);
		ev->p = b[FTS_TOUCH_OFF_PRE] & 0x0F;
		ev->area = b[FTS_TOUCH_OFF_AREA] & 0x7F;
	} else {
		ev->x = ((b[FTS_TOUCH_OFF_E_XH] & 0x0F) << 8) + b[FTS_TOUCH_OFF_XL];
		ev->y = ((b[FTS_TOUCH_OFF_ID_YH] & 0x0F) << 8) + b[FTS_TOUCH_OFF_YL];
		ev->p = b[FTS_TOUCH_OFF_PRE];
		ev->area = b[FTS_TOUCH_OFF_AREA];
	}
}
'''
anchor = "static int fts_irq_read_report(struct fts_ts_data *ts_data)"
assert anchor in s, "anchor"
# insert before the first function that parses points (read_report or its callee)
first_parse = s.find("events[i].x =")
fn_start = s.rfind("\nstatic ", 0, first_parse)
s = s[:fn_start] + "\n" + helper + s[fn_start:]

old = '''			events[i].x =
				((touch_buf[FTS_TOUCH_OFF_E_XH + base] & 0x0F)
				 << 8) +
				(touch_buf[FTS_TOUCH_OFF_XL + base] & 0xFF);
			events[i].y =
				((touch_buf[FTS_TOUCH_OFF_ID_YH + base] & 0x0F)
				 << 8) +
				(touch_buf[FTS_TOUCH_OFF_YL + base] & 0xFF);
			events[i].p = touch_buf[FTS_TOUCH_OFF_PRE + base];
			events[i].area = touch_buf[FTS_TOUCH_OFF_AREA + base];
'''
new = '''			fts_decode_point(ts_data, &touch_buf[base], &events[i]);
'''
n = s.count(old)
assert n >= 2, f"parse sites: {n}"
s = s.replace(old, new)

old = '''	ret = of_property_read_u32(np, "focaltech,max-touch-number", &temp_val);'''
new = '''	if (of_property_read_u32(np, "focaltech,super-resolution-factors",
				 &pdata->super_resolution))
		pdata->super_resolution = 1;

	ret = of_property_read_u32(np, "focaltech,max-touch-number", &temp_val);'''
assert old in s, "dt parse"
s = s.replace(old, new, 1)
open(c, "w").write(s)
print("focaltech super-resolution patched")
