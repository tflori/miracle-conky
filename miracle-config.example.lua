local scaling = 1
function scale(n)
    return math.floor(n * scaling)
end

local width, height, dpi = scale(480), scale(450), 96
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

    -- Window specifications
	own_window_argb_visual = true,
	own_window_argb_value = 0,
	own_window_class = 'Conky',
	own_window = true,
	own_window_type = 'desktop', -- for kde use dock and add window rules
	own_window_hints = 'undecorated,below,sticky,skip_taskbar,skip_pager',
	-- own_window_transparent = false, -- I don't know if this helps

	border_inner_margin = 0,
	border_outer_margin = 0,

    minimum_width = math.ceil(width / dpi * 96),
    minimum_height = math.ceil(height / dpi * 96),

	alignment = 'bottom_left',
	gap_x = 32,
	gap_y = 32,

    lua_load = 'miracle.lua',
	lua_draw_hook_pre = 'conky_main',
}

conky.text = [[]]

conky.miracle = {
    scaling = scaling,
	widgets = {
		clock = {
			hide = false,
			pos = {x = width, y = 0},
			showDate = true,
			timeFormat = '%H:%M',
			dateFormat = '%A, %e. %B',
		},
		cpu = {
			hide = false,
			pos = {x = 0, y = 0},
			top = 3,
			-- hwmon = 0,
			-- tempSensor = 1,
			-- minCoresPerRow = 2,
		},
		memory = {
			hide = false,
            pos = {x = width-scale(201), y = scale(150)},
			top = 3,
		},
		disks = {
			hide = false,
			pos = {x = 0, y = scale(250)},
			-- disks = {Home = '/home', Root = '/'}
			disks = 'auto',
			exclude = {'/var/lib/docker', 'fast.workspace', '/boot/efi'},
			include = {NAS = '/media/nas/media'}
			-- sort = {NAS, Home, Root}
	 },
	 network = {
		 hide = false,
		 pos = {x = width - scale(196), y = scale(315)},
		 network = 'auto', -- network name 'eth0'
	 },
	 battery = {
		 hide = false,
		 pos = {x = width - scale(182), y = scale(88)},
	 },
	 load = {
		 hide = false,
           pos = {x = 0, y = scale(340)},
           --max = 2,
           --warn = 2,
           --crit = 4,
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
