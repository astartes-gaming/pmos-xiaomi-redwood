// SPDX-License-Identifier: GPL-2.0-only
/*
 * DRM driver for the Xiaomi "M20 42 0d 0b" DSC video mode AMOLED panel
 * (Novatek controller) used in the POCO X5 Pro 5G / Redmi Note 12 Pro Speed
 * (redwood).
 *
 * Init sequence, timings and DSC parameters taken from the vendor device tree
 * (dsi-panel-m20-42-0d-0b-dsc-vid.dtsi):
 *   Copyright (c) 2013, The Linux Foundation. All rights reserved.
 * Driver structure follows panel-visionox-rm692e5.c and panel-l9-42-02-0a-dsc.c.
 */

#include <linux/backlight.h>
#include <linux/delay.h>
#include <linux/gpio/consumer.h>
#include <linux/mod_devicetable.h>
#include <linux/module.h>
#include <linux/regulator/consumer.h>

#include <video/mipi_display.h>

#include <drm/display/drm_dsc.h>
#include <drm/display/drm_dsc_helper.h>
#include <drm/drm_mipi_dsi.h>
#include <drm/drm_modes.h>
#include <drm/drm_panel.h>
#include <drm/drm_probe_helper.h>

struct m20_42_0d_0b {
	struct drm_panel panel;
	struct mipi_dsi_device *dsi;
	struct drm_dsc_config dsc;
	struct regulator_bulk_data *supplies;
	struct gpio_desc *reset_gpio;
};

static const struct regulator_bulk_data m20_42_0d_0b_supplies[] = {
	{ .supply = "vdd" },	/* 3.0 V */
	{ .supply = "vddio" },	/* 1.8 V */
	{ .supply = "dvdd" },	/* 1.23 V */
};

static inline struct m20_42_0d_0b *to_m20_42_0d_0b(struct drm_panel *panel)
{
	return container_of(panel, struct m20_42_0d_0b, panel);
}

/* Vendor reset sequence: high 1 ms, low 1 ms, high 20 ms (reset is active low) */
static void m20_42_0d_0b_reset(struct m20_42_0d_0b *ctx)
{
	gpiod_set_value_cansleep(ctx->reset_gpio, 0);
	usleep_range(1000, 2000);
	gpiod_set_value_cansleep(ctx->reset_gpio, 1);
	usleep_range(1000, 2000);
	gpiod_set_value_cansleep(ctx->reset_gpio, 0);
	msleep(20);
}

static int m20_42_0d_0b_on(struct m20_42_0d_0b *ctx)
{
	struct mipi_dsi_multi_context dsi_ctx = { .dsi = ctx->dsi };

	ctx->dsi->mode_flags |= MIPI_DSI_MODE_LPM;

	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, MIPI_DCS_WRITE_CONTROL_DISPLAY, 0x20);
	/* vendor sends 0x0000 here; bring-up: start visible at ~half brightness */
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, MIPI_DCS_SET_DISPLAY_BRIGHTNESS, 0x03, 0xff);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0x6f, 0x01);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0x03, 0x01);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, MIPI_DCS_SET_TEAR_ON, 0x00);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0x6c, 0x02);	/* 120 Hz gamma */
	/* Panel-side DSC configuration (vendor PPS-like register) */
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0x70,
				     0x12, 0x00, 0x00, 0xab, 0x30, 0x80, 0x09,
				     0x60, 0x04, 0x38, 0x00, 0x0c, 0x02, 0x1c,
				     0x02, 0x1c, 0x02, 0x00, 0x02, 0x0e, 0x00,
				     0x20, 0x01, 0x1f, 0x00, 0x07, 0x00, 0x0c,
				     0x08, 0xbb, 0x08, 0x7a, 0x18, 0x00, 0x10,
				     0xf0, 0x07, 0x10, 0x20, 0x00, 0x06, 0x0f,
				     0x0f, 0x33, 0x0e, 0x1c, 0x2a, 0x38, 0x46,
				     0x54, 0x62, 0x69, 0x70, 0x77, 0x79, 0x7b,
				     0x7d, 0x7e, 0x02, 0x02, 0x22, 0x00, 0x2a,
				     0x40, 0x2a, 0xbe, 0x3a, 0xfc, 0x3a, 0xfa,
				     0x3a, 0xf8, 0x3b, 0x38, 0x3b, 0x78, 0x43,
				     0xb6, 0x4b, 0xb6, 0x4b, 0xf6, 0x4b, 0xf4,
				     0x64, 0x34, 0x84, 0x74, 0x00, 0x00, 0x00,
				     0x00, 0x00, 0x00);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0x59, 0x09);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf0, 0xaa, 0x10);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0x65, 0x04);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xcf, 0x7f);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf0, 0xaa, 0x18);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xb0, 0x13);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xb2, 0x13);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xff, 0x5a, 0x81);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0x65, 0x03);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf4, 0x03);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0x65, 0x08);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf6, 0x51, 0x44);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf0, 0xaa, 0x13);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xc8, 0x04);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xd0, 0x04);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xe0, 0x04);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xff, 0x5a, 0x80);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0x65, 0x0e);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf9, 0xb9);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, MIPI_DCS_WRITE_POWER_SAVE, 0x00);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf0, 0xaa, 0x11);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xba, 0x82, 0x10);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0x65, 0x01);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xb0, 0x81);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0x57, 0x00);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf0, 0xaa, 0x19);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xd1,
				     0x00, 0x04, 0x04, 0x06, 0x07, 0x08, 0x08, 0x09,
				     0x00, 0xfe, 0xfc, 0xfa, 0xfa, 0xf9, 0xf7, 0xf7,
				     0x00, 0x04, 0x04, 0x06, 0x07, 0x08, 0x08, 0x09,
				     0x00, 0xfe, 0xfc, 0xfa, 0xfa, 0xf9, 0xf7, 0xf7,
				     0x00, 0x04, 0x04, 0x06, 0x07, 0x08, 0x08, 0x09,
				     0x00, 0xfe, 0xfc, 0xfa, 0xfa, 0xf9, 0xf7, 0xf7);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xd2,
				     0x00, 0x04, 0x04, 0x07, 0x07, 0x09, 0x09, 0x0a,
				     0x00, 0xfc, 0xfc, 0xfa, 0xfa, 0xf9, 0xf7, 0xf7,
				     0x00, 0x04, 0x04, 0x07, 0x07, 0x09, 0x09, 0x0a,
				     0x00, 0xfc, 0xfc, 0xfa, 0xfa, 0xf9, 0xf7, 0xf7,
				     0x00, 0x04, 0x04, 0x07, 0x07, 0x09, 0x09, 0x0a,
				     0x00, 0xfc, 0xfc, 0xfa, 0xfa, 0xf9, 0xf7, 0xf7);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xd4,
				     0x00, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff,
				     0x00, 0x01, 0x01, 0x01, 0x02, 0x02, 0x03, 0x03,
				     0x00, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff,
				     0x00, 0x01, 0x01, 0x01, 0x02, 0x02, 0x03, 0x03,
				     0x00, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff,
				     0x00, 0x01, 0x01, 0x01, 0x02, 0x02, 0x03, 0x03);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xd5,
				     0x00, 0xfe, 0xfe, 0xfe, 0xff, 0xff, 0xff, 0xff,
				     0x00, 0x01, 0x01, 0x01, 0x02, 0x02, 0x03, 0x03,
				     0x00, 0xfe, 0xfe, 0xfe, 0xff, 0xff, 0xff, 0xff,
				     0x00, 0x01, 0x01, 0x01, 0x02, 0x02, 0x03, 0x03,
				     0x00, 0xfe, 0xfe, 0xfe, 0xff, 0xff, 0xff, 0xff,
				     0x00, 0x01, 0x01, 0x01, 0x02, 0x02, 0x03, 0x03);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xd6,
				     0x00, 0x03, 0x02, 0x02, 0x01, 0x00, 0x00, 0x00,
				     0x00, 0x00, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00,
				     0x00, 0x03, 0x02, 0x02, 0x01, 0x00, 0x00, 0x00,
				     0x00, 0x00, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00,
				     0x00, 0x03, 0x02, 0x02, 0x01, 0x00, 0x00, 0x00,
				     0x00, 0x00, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf0, 0xaa, 0x10);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xd0, 0x84, 0x35);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xff, 0x5a, 0x00);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf0, 0xaa, 0x00);
	mipi_dsi_dcs_exit_sleep_mode_multi(&dsi_ctx);
	mipi_dsi_msleep(&dsi_ctx, 120);
	mipi_dsi_dcs_set_display_on_multi(&dsi_ctx);

	return dsi_ctx.accum_err;
}

static int m20_42_0d_0b_off(struct m20_42_0d_0b *ctx)
{
	struct mipi_dsi_multi_context dsi_ctx = { .dsi = ctx->dsi };

	ctx->dsi->mode_flags |= MIPI_DSI_MODE_LPM;

	mipi_dsi_dcs_set_display_off_multi(&dsi_ctx);
	mipi_dsi_msleep(&dsi_ctx, 10);
	mipi_dsi_dcs_enter_sleep_mode_multi(&dsi_ctx);
	mipi_dsi_msleep(&dsi_ctx, 120);

	return dsi_ctx.accum_err;
}

static int m20_42_0d_0b_prepare(struct drm_panel *panel)
{
	struct m20_42_0d_0b *ctx = to_m20_42_0d_0b(panel);
	struct mipi_dsi_multi_context dsi_ctx = { .dsi = ctx->dsi };
	struct drm_dsc_picture_parameter_set pps;
	int ret;

	ret = regulator_bulk_enable(ARRAY_SIZE(m20_42_0d_0b_supplies),
				    ctx->supplies);
	if (ret < 0)
		return ret;

	m20_42_0d_0b_reset(ctx);

	ret = m20_42_0d_0b_on(ctx);
	if (ret < 0) {
		dev_err(&ctx->dsi->dev, "Failed to initialize panel: %d\n", ret);
		goto err;
	}

	drm_dsc_pps_payload_pack(&pps, &ctx->dsc);
	mipi_dsi_picture_parameter_set_multi(&dsi_ctx, &pps);
	mipi_dsi_compression_mode_ext_multi(&dsi_ctx, true,
					    MIPI_DSI_COMPRESSION_DSC, 0);
	mipi_dsi_msleep(&dsi_ctx, 28);
	if (dsi_ctx.accum_err < 0) {
		ret = dsi_ctx.accum_err;
		dev_err(&ctx->dsi->dev, "Failed to enable DSC: %d\n", ret);
		goto err;
	}

	{
		u8 mode = 0;
		int r = mipi_dsi_dcs_get_power_mode(ctx->dsi, &mode);

		/* 0x9c = booster on, sleep out, normal mode, display on */
		dev_info(&ctx->dsi->dev, "panel power mode: ret=%d mode=0x%02x\n", r, mode);
	}

	return 0;

err:
	gpiod_set_value_cansleep(ctx->reset_gpio, 1);
	regulator_bulk_disable(ARRAY_SIZE(m20_42_0d_0b_supplies), ctx->supplies);
	return ret;
}

static int m20_42_0d_0b_unprepare(struct drm_panel *panel)
{
	struct m20_42_0d_0b *ctx = to_m20_42_0d_0b(panel);
	int ret;

	ret = m20_42_0d_0b_off(ctx);
	if (ret < 0)
		dev_err(&ctx->dsi->dev, "Failed to un-initialize panel: %d\n", ret);

	gpiod_set_value_cansleep(ctx->reset_gpio, 1);
	regulator_bulk_disable(ARRAY_SIZE(m20_42_0d_0b_supplies), ctx->supplies);

	return 0;
}

/* 120 Hz, porches from the vendor DT */
static const struct drm_display_mode m20_42_0d_0b_mode = {
	.clock = (1080 + 48 + 4 + 64) * (2400 + 20 + 4 + 8) * 120 / 1000,
	.hdisplay = 1080,
	.hsync_start = 1080 + 48,
	.hsync_end = 1080 + 48 + 4,
	.htotal = 1080 + 48 + 4 + 64,
	.vdisplay = 2400,
	.vsync_start = 2400 + 20,
	.vsync_end = 2400 + 20 + 4,
	.vtotal = 2400 + 20 + 4 + 8,
	.width_mm = 70,
	.height_mm = 154,
	.type = DRM_MODE_TYPE_DRIVER,
};

static int m20_42_0d_0b_get_modes(struct drm_panel *panel,
				  struct drm_connector *connector)
{
	return drm_connector_helper_get_modes_fixed(connector, &m20_42_0d_0b_mode);
}

static const struct drm_panel_funcs m20_42_0d_0b_panel_funcs = {
	.prepare = m20_42_0d_0b_prepare,
	.unprepare = m20_42_0d_0b_unprepare,
	.get_modes = m20_42_0d_0b_get_modes,
};

static int m20_42_0d_0b_bl_update_status(struct backlight_device *bl)
{
	struct mipi_dsi_device *dsi = bl_get_data(bl);
	u16 brightness = backlight_get_brightness(bl);
	int ret;

	ret = mipi_dsi_dcs_set_display_brightness_large(dsi, brightness);
	dev_info(&dsi->dev, "set brightness %u: ret=%d\n", brightness, ret);

	return ret < 0 ? ret : 0;
}

static const struct backlight_ops m20_42_0d_0b_bl_ops = {
	.update_status = m20_42_0d_0b_bl_update_status,
};

static struct backlight_device *
m20_42_0d_0b_create_backlight(struct mipi_dsi_device *dsi)
{
	struct device *dev = &dsi->dev;
	/* 0x7ff is normal maximum; 0xfff is the vendor's high-brightness mode */
	const struct backlight_properties props = {
		.type = BACKLIGHT_RAW,
		.brightness = 1023,
		.max_brightness = 2047,
	};

	return devm_backlight_device_register(dev, dev_name(dev), dev, dsi,
					      &m20_42_0d_0b_bl_ops, &props);
}

static int m20_42_0d_0b_probe(struct mipi_dsi_device *dsi)
{
	struct device *dev = &dsi->dev;
	struct m20_42_0d_0b *ctx;
	int ret;

	ctx = devm_drm_panel_alloc(dev, struct m20_42_0d_0b, panel,
				   &m20_42_0d_0b_panel_funcs,
				   DRM_MODE_CONNECTOR_DSI);
	if (IS_ERR(ctx))
		return PTR_ERR(ctx);

	ret = devm_regulator_bulk_get_const(dev,
					    ARRAY_SIZE(m20_42_0d_0b_supplies),
					    m20_42_0d_0b_supplies,
					    &ctx->supplies);
	if (ret < 0)
		return dev_err_probe(dev, ret, "Failed to get regulators\n");

	ctx->reset_gpio = devm_gpiod_get(dev, "reset", GPIOD_OUT_HIGH);
	if (IS_ERR(ctx->reset_gpio))
		return dev_err_probe(dev, PTR_ERR(ctx->reset_gpio),
				     "Failed to get reset-gpios\n");

	ctx->dsi = dsi;
	mipi_dsi_set_drvdata(dsi, ctx);

	dsi->lanes = 4;
	/*
	 * 10 bpc DSC in video mode with widebus: DPU sends 30 bits per pclk, so
	 * the link (byte clock) must be sized for 30 bpp (vendor: bpp = <30>).
	 * RGB888 here under-clocks the link and floods DSI FIFO errors.
	 */
	dsi->format = MIPI_DSI_FMT_RGB101010;
	dsi->mode_flags = MIPI_DSI_MODE_VIDEO | MIPI_DSI_MODE_VIDEO_BURST |
			  MIPI_DSI_CLOCK_NON_CONTINUOUS | MIPI_DSI_MODE_LPM;

	ctx->panel.prepare_prev_first = true;

	ctx->panel.backlight = m20_42_0d_0b_create_backlight(dsi);
	if (IS_ERR(ctx->panel.backlight))
		return dev_err_probe(dev, PTR_ERR(ctx->panel.backlight),
				     "Failed to create backlight\n");

	drm_panel_add(&ctx->panel);

	/* This panel only supports DSC; unconditionally enable it */
	dsi->dsc = &ctx->dsc;
	ctx->dsc.dsc_version_major = 1;
	ctx->dsc.dsc_version_minor = 1;	/* DPU only implements DSC 1.1 RC tables */
	ctx->dsc.slice_height = 12;
	ctx->dsc.slice_width = 540;
	ctx->dsc.slice_count = 1080 / ctx->dsc.slice_width;
	ctx->dsc.bits_per_component = 10;
	ctx->dsc.bits_per_pixel = 8 << 4;	/* 4 fractional bits */
	ctx->dsc.block_pred_enable = true;

	ret = devm_mipi_dsi_attach(dev, dsi);
	if (ret < 0) {
		drm_panel_remove(&ctx->panel);
		return dev_err_probe(dev, ret, "Failed to attach to DSI host\n");
	}

	return 0;
}

static void m20_42_0d_0b_remove(struct mipi_dsi_device *dsi)
{
	struct m20_42_0d_0b *ctx = mipi_dsi_get_drvdata(dsi);

	drm_panel_remove(&ctx->panel);
}

static const struct of_device_id m20_42_0d_0b_of_match[] = {
	{ .compatible = "xiaomi,redwood-m20-42-0d-0b-panel" },
	{ /* sentinel */ }
};
MODULE_DEVICE_TABLE(of, m20_42_0d_0b_of_match);

static struct mipi_dsi_driver m20_42_0d_0b_driver = {
	.probe = m20_42_0d_0b_probe,
	.remove = m20_42_0d_0b_remove,
	.driver = {
		.name = "panel-xiaomi-m20-42-0d-0b",
		.of_match_table = m20_42_0d_0b_of_match,
	},
};
module_mipi_dsi_driver(m20_42_0d_0b_driver);

MODULE_DESCRIPTION("DRM driver for Xiaomi M20 42 0d 0b DSC video mode panel (redwood)");
MODULE_LICENSE("GPL");
