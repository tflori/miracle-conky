conky.config = {
  -- Conky settings #
	background = false,
	update_interval = 0.5,

	cpu_avg_samples = 2,
	net_avg_samples = 2,

	override_utf8_locale = true,

	double_buffer = true,
	no_buffers = true,

	text_buffer_size = 2048,
  --imlib_cache_size 0

	temperature_unit = 'celsius',

  -- XFCE lightdm and gnome backround issue
	own_window_argb_visual = true,
	own_window_argb_value = 0,

-- Window specifications #
	own_window_class = 'Conky',
	own_window = true,
	own_window_type = 'desktop',
	own_window_hints = 'undecorated,below,sticky,skip_taskbar,skip_pager',
	own_window_transparent = false,

	border_inner_margin = 0,
	border_outer_margin = 0,

	minimum_width = 480,
	minimum_height = 450,

	alignment = 'bottom_left',
	gap_x = 32,
	gap_y = 32,

	lua_load = 'miracle.lua',
	lua_draw_hook_pre = 'conky_main',
}

conky.text = [[]]
