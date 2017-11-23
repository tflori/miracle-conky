require 'lib'
require 'cairo-tools'
require 'imlib2'

local settings, cache = {}, {}
local cr, width, height, updates

function generateSettings()
  if settings.generated then return end

  settings.generated = true
  settings.widgets = {
    clock = {
      hide = false,
      pos = {x = width, y = 0},
      showDate = true,
   },
    cpu = {
      hide = false,
      pos = {x = 0, y = 0},
      top = 3,
   },
   memory = {
     hide = false,
     pos = {x = width-205, y = 150},
     top = 3,
   },
   disks = {
     hide = false,
     pos = {x = 30, y = 250},
     disks = 'auto',
     exclude = {'/var/lib/docker', 'fast.workspace', '/boot/efi'},
     include = {NAS = '/media/nas/media'}
     -- disks = {Home = '/home', Root = '/'}
   },
   network = {
     hide = false,
     pos = {x = width - 210, y = 300},
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
 }
  settings.fonts = {
    default = 'Monaco',
    significant = 'GE Inspira',
 }
  settings.colors = {
    default = 0xffffff,
    highlight = 0xff7f44,
    gaugeBg = 0x000000,
    gaugeBgAlpha = 0.15,
    gauge = 0xffffff,
    gaugeAlpha = 0.9,
    gaugeInfo = 0xffbb55,
    gaugeWarn = 0xff7f44,
    gaugeCrit = 0xff3333,
 }

end

function conky_main()
  if conky_window==nil or conky_window.width == 0 then return end
  local cs = cairo_xlib_surface_create(
    conky_window.display,
    conky_window.drawable,
    conky_window.visual,
    conky_window.width,
    conky_window.height
  )

  cr = cairo_create(cs)
  width = conky_window.width
  height = conky_window.height
  generateSettings()

  updates=tonumber(conky_parse('${updates}'))

  -- helper for design
  -- roundRectangle(cr, {
  --   pos = {x = 0.5, y = 0.5},
  --   size = {width = width-1, height = height-1},
  --   stroke = {width = 1, color = 0x000000, alpha = 0.5},
  --   cornerRadius = 0,
  -- })

  for widget,config in pairs(settings.widgets) do
    if config.hide == nil or config.hide == false then
      if widget == 'clock' then updateClock(config) end
      if widget == 'cpu' then updateCPU(config) end
      if widget == 'memory' then updateMemory(config) end
      if widget == 'disks' then updateDisks(config) end
      if widget == 'network' then updateNetwork(config) end
      if widget == 'battery' then updateBattery(config) end
      if widget == 'load' then updateLoad(config) end
    end
  end
end

function updateClock(config)
  local bb = write(cr, os.date('%H:%M'), {
    pos = config.pos or {x = width, y = 0},
    font = {settings.fonts.significant, 64},
    color = settings.colors.default,
    align = {'right', 'top'},
  })
  if config.showDate == nil or config.showDate then
    write(cr, os.date('%A, %b %e'), {
      pos = {x = config.pos.x or width, y = bb.bottom + 4},
      font = {settings.fonts.significant, 18, 1},
      color = settings.colors.highlight,
      align = {'right', 'top'},
    })
  end
end

function updateCPU(config)
  local pos = config.pos or {x = 0, y = 0}
  local freq = conky_parse('${freq_g cpu0}')
  local temperature = conky_parse('${hwmon ' .. getCoreHwmon() .. ' temp 1}')
  local avgCpu = conky_parse('${cpu cpu0}')
  local warnTemp, critTemp, maxTemp = 60, 80, 110
  if (cache.cpu == nil or cache.cpu.idleTemperatureCount < 1000) and (tonumber(freq) < 1 or tonumber(avgCpu) < 10) then
    if cache.cpu == nil then cache.cpu = {} end
    cache.cpu.idleTemperatureSum = (cache.cpu.idleTemperatureSum or 0) + tonumber(temperature)
    cache.cpu.idleTemperatureCount = (cache.cpu.idleTemperatureCount or 0) + 1
  end
  if cache.cpu ~= nil and cache.cpu.idleTemperatureSum ~= nil and cache.cpu.idleTemperatureCount ~= nil then
    warnTemp = cache.cpu.idleTemperatureSum / cache.cpu.idleTemperatureCount * 1.5
    critTemp = warnTemp * 1.3
  end

  -- frequency
  write(cr, freq .. ' Ghz', {
    pos = {x = pos.x+50, y = pos.y+10},
    font = {settings.fonts.default, 10},
    color = settings.colors.default,
  })

  -- temperature
  write(cr, temperature .. ' °C', {
    pos = {x = pos.x+140, y = pos.y+10},
    font = {settings.fonts.default, 10},
    color = settings.colors.default,
    align = {'right'},
  })
  gauge(cr, tonumber(temperature), {
    pos = {x = pos.x+150, y = pos.y+120},
    radius = 114, thickness = 3,
    from = 0, to = 240,
    background = { color = settings.colors.gaugeBg, alpha = settings.colors.gaugeBgAlpha },
    color = settings.colors.gauge,
    alpha = settings.colors.gaugeAlpha,
    max = maxTemp,
    warn = {from = warnTemp, color = settings.colors.gaugeWarn},
    crit = {from = critTemp, color = settings.colors.gaugeCrit},
  })

  -- average cpu
  write(cr, 'Average CPU usage ' .. avgCpu:pad(3, ' ', 'STR_PAD_LEFT') .. '%', {
    pos = {x = pos.x+140, y = pos.y+24},
    font = {settings.fonts.default, 10},
    color = settings.colors.default,
    align = {'right'},
  })
  gauge(cr, tonumber(avgCpu), {
    pos = {x = pos.x+150, y = pos.y+120},
    radius = 101, thickness = 12,
    from = 0, to = 240,
    background = { color = settings.colors.gaugeBg, alpha = settings.colors.gaugeBgAlpha },
    color = settings.colors.gauge,
    alpha = settings.colors.gaugeAlpha,
    warn = {from = 90, color = settings.colors.gaugeWarn},
  })
  graph(cr, 'cpu', tonumber(avgCpu), {
    pos = {x = pos.x+140, y = pos.y + 90},
    direction = 'left', amplitude = 'center',
    color = settings.colors.gauge,
    alpha = 0.9, width = 140, height = 20,
  })

  -- cpus
  local cpuCount = getCpuCount()
  if cpuCount > 1 then
    local y, r = pos.y+38, 89
    for i=1,cpuCount,2 do
      local usage1 = conky_parse('${cpu cpu' .. i .. '}')
      local usage2 = conky_parse('${cpu cpu' .. i+1 .. '}')
      write(
        cr,
        'CPU ' .. i .. ' ' .. usage1:pad(3, ' ', 'STR_PAD_LEFT') .. '% | ' ..
        'CPU ' .. (i+1) .. ' ' .. usage2:pad(3, ' ', 'STR_PAD_LEFT') ..'%',
        {
          pos = {x = pos.x+140, y = y},
          font = {settings.fonts.default, 10},
          color = settings.colors.default,
          align = {'right'},
        }
      )
      gauge(cr, tonumber(usage1), {
        pos = {x = pos.x+150, y = pos.y+120},
        radius = r, thickness = 4,
        from = 0, to = 240,
        background = { color = settings.colors.gaugeBg, alpha = settings.colors.gaugeBgAlpha },
        color = settings.colors.gauge,
        alpha = settings.colors.gaugeAlpha,
        warn = {from = 90, color = settings.colors.gaugeWarn},
      })
      gauge(cr, tonumber(usage2), {
        pos = {x = pos.x+150, y = pos.y+120},
        radius = r-5, thickness = 4,
        from = 0, to = 240,
        background = { color = settings.colors.gaugeBg, alpha = settings.colors.gaugeBgAlpha },
        color = settings.colors.gauge,
        alpha = settings.colors.gaugeAlpha,
        warn = {from = 90, color = settings.colors.gaugeWarn},
      })
      y = y + 12
      r = r - 12
    end
  end

  -- top
  local y = pos.y + 115
  if config.top and config.top > 0 then
    for i=1,config.top do
      if cache.top == nil or cache.top.name[i] == nil or updates % 4 == 0 then
        if cache.top == nil then
          cache.top = { name = {}, perc = {}}
        end
        cache.top.name[i] = conky_parse('${top name ' .. i .. '}'):pad(20, ' ')
        cache.top.perc[i] = conky_parse('${top cpu ' .. i .. '}'):pad(6, ' ', 'STR_PAD_LEFT') .. '%'
      end
      write(cr, cache.top.name[i] .. cache.top.perc[i], {
        pos = { x = pos.x+2, y = y },
        font = {settings.fonts.default, 10},
        color = settings.colors.default,
      });
      y = y + 12
    end
  end

  -- label
  write(cr, 'CPU', {
    pos = {x = pos.x+2, y = y},
    font = {settings.fonts.significant, 24, 0},
    color = settings.colors.highlight,
    align = {'left', 'top'},
  })
end

function updateMemory(config)
  local pos = config.pos or {x = width-205, y = 150}
  local free = os.capture('LC_ALL=C free -m'):split('\n')
  local memTotal, memUsed, memFree, memShared, memBuffers, memAvailable =
    free[2]:match('(%d+) +(%d+) +(%d+) +(%d+) +(%d+) +(%d+)')
  local swapTotal, swapUsed, swapFree = free[3]:match('(%d+) +(%d+) +(%d+)')

  -- label
  local y = pos.y + 20
  write(cr, 'Memory', {
    pos = {x = pos.x+200, y = y},
    font = {settings.fonts.significant, 24, 0},
    color = settings.colors.highlight,
    align = {'right', 'top'},
  })
  y = y + 50


  -- memory
  local used = humanReadableBytes(memUsed + memShared, 'MiB'):pad(7, ' ', 'STR_PAD_LEFT')
  local total = humanReadableBytes(memTotal + 0, 'MiB'):pad(7, ' ', 'STR_PAD_LEFT')
  write(cr, 'RAM  ' .. used .. ' / ' .. total, {
    pos = {x = pos.x+200, y = pos.y+122},
    font = {settings.fonts.default, 10},
    color = settings.colors.default,
    align = {'right', 'top'},
  })
  gauge(cr, memUsed + memShared, {
    pos = {x = pos.x+48, y = pos.y+68},
    radius = 60, thickness = 15,
    from = 180, to = 420,
    background = { color = settings.colors.gaugeBg, alpha = settings.colors.gaugeBgAlpha },
    color = settings.colors.gauge,
    alpha = settings.colors.gaugeAlpha,
    max = memTotal,
    warn = {from = memTotal * 0.9, color = settings.colors.gaugeWarn},
    crit = {from = memTotal * 0.95, color = settings.colors.gaugeCrit},
    level2 = {
      color = settings.colors.gauge,
      alpha = 0.2,
      value = memUsed + memShared + memBuffers
    }
  })

  -- swap
  local used = humanReadableBytes(swapUsed + 0, 'MiB'):pad(7, ' ', 'STR_PAD_LEFT')
  local total = humanReadableBytes(swapTotal + 0, 'MiB'):pad(7, ' ', 'STR_PAD_LEFT')
  write(cr, 'SWAP ' .. used .. ' / ' .. total, {
    pos = {x = pos.x+200, y = pos.y+120},
    font = {settings.fonts.default, 10},
    color = settings.colors.default,
    align = {'right', 'bottom'},
  })
  gauge(cr, tonumber(swapUsed), {
    pos = {x = pos.x+48, y = pos.y+68},
    radius = 43, thickness = 11,
    from = 180, to = 420,
    background = { color = settings.colors.gaugeBg, alpha = settings.colors.gaugeBgAlpha },
    color = settings.colors.gauge,
    alpha = settings.colors.gaugeAlpha,
    max = swapTotal,
    warn = {from = swapTotal * 0.1, color = settings.colors.gaugeWarn},
    crit = {from = swapTotal * 0.2, color = settings.colors.gaugeCrit},
  })

  -- top
  if config.top and config.top > 0 then
    for i=1,config.top do
      if cache.topMem == nil or cache.topMem.name[i] == nil or updates % 4 == 0 then
        if cache.topMem == nil then
          cache.topMem = { name = {}, perc = {}}
        end
        cache.topMem.name[i] = conky_parse('${top_mem name ' .. i .. '}'):pad(20, ' ')
        cache.topMem.perc[i] = conky_parse('${top_mem mem ' .. i .. '}'):pad(6, ' ', 'STR_PAD_LEFT') .. '%'
      end
      write(cr, cache.topMem.name[i] .. cache.topMem.perc[i], {
        pos = { x = pos.x+200, y = y },
        font = {settings.fonts.default, 10},
        color = settings.colors.default,
        align = {'right'},
      });
      y = y + 12
    end
  end
end

function updateDisks(config)
  local pos = config.pos or {x = 30, y = 250}
  local disks = config.disks or 'auto'
  if disks == 'auto' then
    disks = {
      Root = '/'
    }

    if config.include ~= nil then
      for name,mount in pairs(config.include) do
        if os.capture('mount |grep \'' .. mount .. '\''):len() > 0 then
          disks[name] = mount
        end
      end
    end

    local mounts = os.capture('mount |egrep \'^/dev/\''):split("\n")
    for _,mount in pairs(mounts) do
      mount = mount:match('on (/[a-zA-Z0-9./_-]*)')
      if mount ~= nil and mount ~= '/' then
        local excluded = false
        for _,exclude in pairs(config.exclude) do
          if mount:match(exclude) then
            excluded = true
            break
          end
        end
        if not excluded then
          disks[mount:gsub('(.*/)(.*)', '%2'):gsub('[./_-]', ' '):titlecase()] = mount
        end
      end
    end
  end

  local radius, y, i = 56.5, pos.y + 8, 0
  for name,mount in pairs(disks) do
    i = i + 1
    if i > 4 then break end
    local used = conky_parse('${fs_used ' .. mount .. '}'):pad(7, ' ', 'STR_PAD_LEFT')
    local total = conky_parse('${fs_size ' .. mount .. '}'):pad(7, ' ', 'STR_PAD_LEFT')
    write(cr, name, {
      pos = {x = pos.x, y = y},
      font = {settings.fonts.default, 10},
      color = settings.colors.default,
    })
    write(cr, used .. ' / ' .. total, {
      pos = {x = pos.x+170, y = y},
      font = {settings.fonts.default, 10},
      color = settings.colors.default,
      align = {'right'},
    })
    gauge(cr, tonumber(conky_parse('${fs_used_perc ' .. mount .. '}')), {
        pos = {x = pos.x+180, y = pos.y+60},
        radius = radius, thickness = 7,
        from = 0, to = 240,
        background = { color = settings.colors.gaugeBg, alpha = settings.colors.gaugeBgAlpha },
        color = settings.colors.gauge,
        alpha = settings.colors.gaugeAlpha,
        warn = {from = 95, color = settings.colors.gaugeWarn},
        crit = {from = 98, color = settings.colors.gaugeCrit},
    })
    radius = radius - 12
    y = y + 12
  end

  -- label
  write(cr, 'Disks', {
    pos = {x = pos.x+75, y = pos.y+58},
    font = {settings.fonts.significant, 24, 0},
    color = settings.colors.highlight,
    align = {'left', 'top'},
  })
end

function updateNetwork(config)
  local pos = config.pos or {x = width - 410, y = 300}
  local network = config.network or getCurrentNetwork()
  if network == 'auto' then
    network = getCurrentNetwork()
  end

  local downspeed = tonumber(conky_parse('${downspeedf ' .. network .. '}'))
  local upspeed = tonumber(conky_parse('${upspeedf ' .. network .. '}'))
  if cache.maxDown == nil or cache.maxDown < downspeed then cache.maxDown = downspeed end
  if cache.maxUp == nil or cache.maxUp < upspeed then cache.maxUp = upspeed end
  if cache.maxDown == 0 or cache.maxUp == 0 then return end

  -- label
  write(cr, 'Network', {
    pos = {x = pos.x+195, y = pos.y+8},
    font = {settings.fonts.significant, 24, 0},
    color = settings.colors.highlight,
    align = {'right', 'top'},
  })

  y = pos.y + 87
  -- upload
  gauge(cr, upspeed, {
    pos = {x = pos.x+50, y = pos.y+50},
    radius = 35, thickness = 5,
    from = 180, to = 420,
    background = { color = settings.colors.gaugeBg, alpha = settings.colors.gaugeBgAlpha },
    color = settings.colors.gauge,
    alpha = settings.colors.gaugeAlpha,
    max = cache.maxUp,
    warn = {from = cache.maxUp * .95, color = settings.colors.gaugeWarn},
  })
  graph(cr, 'upload', upspeed, {
    pos = {x = pos.x+40, y = pos.y + 50},
    direction = 'right', amplitude = 'up',
    color = settings.colors.gauge,
    alpha = 0.9, max = 'auto',
    width = 155, height = 12,
  })
  local totalUp = conky_parse('${totalup ' .. network .. '}'):pad(7, ' ', 'STR_PAD_LEFT')
  local up = humanReadableBytes(upspeed, 'KiB'):pad(7, ' ', 'STR_PAD_LEFT')
  local upMax = humanReadableBytes(cache.maxUp, 'KiB'):pad(7, ' ', 'STR_PAD_LEFT')
  write(cr, 'Up    ' .. up .. ' / ' .. upMax, {
    pos = {x = pos.x + 60, y = y},
    font = {settings.fonts.default, 10},
    color = settings.colors.default,
  })
  y = y + 12

  -- download
  gauge(cr, downspeed, {
    pos = {x = pos.x+50, y = pos.y+50},
    radius = 45, thickness = 10,
    from = 180, to = 420,
    background = { color = settings.colors.gaugeBg, alpha = settings.colors.gaugeBgAlpha },
    color = settings.colors.gauge,
    alpha = settings.colors.gaugeAlpha,
    max = cache.maxUp,
    warn = {from = cache.maxUp * .95, color = settings.colors.gaugeWarn},
  })
  graph(cr, 'download', downspeed, {
    pos = {x = pos.x+40, y = pos.y + 53},
    direction = 'right', amplitude = 'down',
    color = settings.colors.gauge,
    alpha = 0.9, max = 'auto',
    width = 155, height = 12,
  })
  local totalDown = conky_parse('${totaldown ' .. network .. '}'):pad(7, ' ', 'STR_PAD_LEFT')
  local down = humanReadableBytes(downspeed, 'KiB'):pad(7, ' ', 'STR_PAD_LEFT')
  local downMax = humanReadableBytes(cache.maxDown, 'KiB'):pad(7, ' ', 'STR_PAD_LEFT')
  write(cr, 'Down  ' .. down .. ' / ' .. downMax, {
    pos = {x = pos.x + 60, y = y},
    font = {settings.fonts.default, 10},
    color = settings.colors.default,
  })
  y = y + 12

  -- info
  if config.hideInfo == nil or config.hideInfo == false then
    write(cr, 'Total ' .. totalUp .. ' / ' .. totalDown, {
      pos = {x = pos.x + 60, y = y},
      font = {settings.fonts.default, 10},
      color = settings.colors.default,
    })
    y = y + 12
    local localIp = conky_parse('${addr ' .. network .. '}')
    write(cr, 'LAN IP  ' .. localIp:pad(15, ' ', 'STR_PAD_LEFT'), {
      pos = {x = pos.x + 60, y = y},
      font = {settings.fonts.default, 10},
      color = settings.colors.default,
    })
    y = y + 12
    local publicIp = conky_parse('${execi 3600 wget -q -O - checkip.dyndns.org | sed -e \'s/[^[:digit:]\|.]//g\'}')
    write(cr, 'WAN IP  ' .. publicIp:pad(15, ' ', 'STR_PAD_LEFT'), {
      pos = {x = pos.x + 60, y = y},
      font = {settings.fonts.default, 10},
      color = settings.colors.default,
    })
  end
end

function updateBattery(config)
  if hasBattery() == false then return end
  local pos = config.pos or {x = width - 382, y = 88}

  local percentage = tonumber(conky_parse('${battery_percent BAT0}'))
  if hasBattery('BAT1') then
    percentage = (percentage + tonumber(conky_parse('${battery_percent BAT0}'))) / 2
  end

  bar(cr, percentage, {
    thickness = 15,
    from = {x = pos.x + 30, y = pos.y + 12},
    to = {x = pos.x + 174, y = pos.y + 12},
    background = { color = settings.colors.gaugeBg, alpha = settings.colors.gaugeBgAlpha },
    color = settings.colors.gauge,
    alpha = settings.colors.gaugeAlpha,
    warn = {to = 20, color = settings.colors.gaugeWarn},
    crit = {to = 5, color = settings.colors.gaugeCrit},
  })

  local file = 'battery.png'
  local battery_status=conky_parse('${battery_short BAT0}')
  if battery_status == 'F' or battery_status:find('C') then
    file = 'power.png'
  end
  image = imlib_load_image(file)
  if image == nil then return end
  imlib_context_set_image(image)
  imlib_render_image_on_drawable(pos.x, pos.y)
end

function updateLoad(config)
  local pos = config.pos or {x = 0, y = 340}

  local load1m = tonumber(conky_parse('${loadavg 1}'))
  local load5m = tonumber(conky_parse('${loadavg 2}'))
  local load15m = tonumber(conky_parse('${loadavg 3}'))
  local cpuCount = getCpuCount()
  local max = config.max or (cpuCount * 2)
  local warn = config.warn or cpuCount
  local crit = config.crit or (cpuCount * 1.1)

  -- gauges
  gauge(cr, load1m, {
    pos = {x = pos.x+8, y = pos.y+500},
    radius = 484, thickness = 16,
    from = 0, to = 35,
    background = { color = settings.colors.gaugeBg, alpha = settings.colors.gaugeBgAlpha },
    color = settings.colors.gauge,
    alpha = settings.colors.gaugeAlpha,
    max = max,
    warn = {from = warn, color = settings.colors.gaugeWarn},
    crit = {from = crit, color = settings.colors.gaugeCrit},
  })
  gauge(cr, load5m, {
    pos = {x = pos.x+8, y = pos.y+500},
    radius = 470, thickness = 8,
    from = 1, to = 32.5,
    background = { color = settings.colors.gaugeBg, alpha = settings.colors.gaugeBgAlpha },
    color = settings.colors.gauge,
    alpha = settings.colors.gaugeAlpha,
    max = max,
    warn = {from = warn, color = settings.colors.gaugeWarn},
    crit = {from = crit, color = settings.colors.gaugeCrit},
  })
  gauge(cr, load15m, {
    pos = {x = pos.x+8, y = pos.y+500},
    radius = 462, thickness = 4,
    from = 2, to = 30,
    background = { color = settings.colors.gaugeBg, alpha = settings.colors.gaugeBgAlpha },
    color = settings.colors.gauge,
    alpha = settings.colors.gaugeAlpha,
    max = max,
    warn = {from = warn, color = settings.colors.gaugeWarn},
    crit = {from = crit, color = settings.colors.gaugeCrit},
  })

  -- label
  write(cr, 'Load', {
    pos = {x = pos.x+25, y = pos.y+45},
    font = {settings.fonts.significant, 16, 0},
    color = settings.colors.highlight,
    align = {'left', 'top'},
  })

  -- text
  write(cr, load1m .. ' | ' .. load5m .. ' | ' .. load15m, {
    pos = {x = pos.x+25, y = pos.y+65},
    font = {settings.fonts.default, 10},
    color = settings.colors.default,
    align = {'left', 'top'},
  })
end
