local width, height = 480, 450
local default, primary, warn, crit = 0xffffff, 0x00bfa5, 0xfbc02d, 0xdd2c00

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

	minimum_width = width,
	minimum_height = height,

	alignment = 'bottom_left',
	gap_x = 32,
	gap_y = 32,

    lua_load = 'miracle.lua',
	lua_draw_hook_pre = 'conky_main',
}

conky.text = [[]]

conky.miracle = {
	widgets = {
		clock = {
			hide = false,
			pos = {x = width, y = 0},
			showDate = true,
			timeFormat = '%H:%M',
			dateFormat = '%A, %e. %B'
		},
		cpu = {
			hide = false,
			pos = {x = 0, y = 0},
			top = 3,
			-- hwmon = 0,
			-- tempSensor = 1,
		},
		memory = {
			hide = false,
			pos = {x = width-205, y = 150},
			top = 3,
		},
		disks = {
			hide = false,
			pos = {x = 0, y = 250},
			-- disks = {Home = '/home', Root = '/'}
			disks = 'auto',
			exclude = {'/var/lib/docker', 'fast.workspace', '/boot/efi'},
			include = {NAS = '/media/nas/media'}
	 },
	 network = {
		 hide = false,
		 pos = {x = width - 210, y = 315},
		 network = 'auto', -- network name 'eth0'
	 },
	 battery = {
		 hide = false,
		 pos = {x = width - 182, y = 88},
	 },
	 load = {
		 hide = false,
		 pos = {x = 0, y = 340},
		},
	},
	fonts = {
		default = 'Monaco', -- suggestion: use a mono spaced font
		significant = 'GE Inspira',
	},
	colors = {
		default = default,
		highlight = primary,
		gaugeBg = default,
		gaugeBgAlpha = 0.1,
		gauge = default,
		gaugeAlpha = 0.8,
		gaugeInfo = primary,
		gaugeWarn = warn,
		gaugeCrit = crit,
	}
}
