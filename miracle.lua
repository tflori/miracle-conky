package.cpath = package.cpath .. ";/usr/lib/conky/lib?.so"
require 'lib'
require 'cairo-tools'
require 'imlib2'
require 'cairo_xlib'

conky = {}
require 'miracle-config'
local settings, cache = conky.miracle, {}
local cr, width, height, updates

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

  updates=tonumber(conky_parse('${updates}'))

  local start = mtime()
  for widget,config in pairs(settings.widgets) do
    updateWidget(widget, config)
  end
  print(os.date('%c') .. ' updated in ' .. string.format('%.2f seconds', mtime() - start))
end

function updateWidget(widget, config)
  if config.hide ~= nil and config.hide == true then
      return
  end
  local start = mtime()
  if widget == 'clock'   then updateClock(config)   end
  if widget == 'cpu'     then updateCpu(config)     end
  if widget == 'memory'  then updateMemory(config)  end
  if widget == 'disks'   then updateDisks(config)   end
  if widget == 'network' then updateNetwork(config) end
  if widget == 'battery' then updateBattery(config) end
  if widget == 'load'    then updateLoad(config)    end
  --print(os.date('%c') .. ' updated ' .. widget .. ' in ' .. string.format('%.2f seconds', mtime() - start))
end

function scale(n)
  return math.floor(n * (settings.scaling or 1));
end

function updateClock(config)
  local bb = write(cr, os.date(config.timeFormat or '%H:%M'), {
    pos = config.pos or {x = width, y = 0},
    font = {settings.fonts.significant, scale(64)},
    color = settings.colors.default,
    align = {'right', 'top'},
  })
  if config.showDate == nil or config.showDate then
    write(cr, os.date(config.dateFormat or '%A, %b %e'), {
      pos = {x = config.pos.x or width, y = bb.bottom + scale(4)},
      font = {settings.fonts.significant, scale(18), 1},
      color = settings.colors.highlight,
      align = {'right', 'top'},
    })
  end
end

function updateCpu(config)
  local pos = config.pos or {x = 0, y = 0}
  local freq = conky_parse('${freq_g cpu0}')
  local hwmon = config.hwmon or getCoreHwmon()
  local tempSensor = config.tempSensor or 1
  local temperature = conky_parse('${hwmon ' .. hwmon .. ' temp '  .. tempSensor .. '}')
  local avgCpu = conky_parse('${cpu cpu0}')
  local cpuCount = getCpuCount()
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
    pos = {x = pos.x+scale(50), y = pos.y+scale(10)},
    font = {settings.fonts.default, scale(10)},
    color = settings.colors.default,
  })

  -- temperature
  write(cr, temperature .. ' °C', {
    pos = {x = pos.x+scale(140), y = pos.y+scale(10)},
    font = {settings.fonts.default, scale(10)},
    color = settings.colors.default,
    align = {'right'},
  })
  gauge(cr, tonumber(temperature), {
    pos = {x = pos.x+scale(150), y = pos.y+scale(120)},
    radius = scale(112), thickness = scale(3),
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
    pos = {x = pos.x+scale(140), y = pos.y+scale(24)},
    font = {settings.fonts.default, scale(10)},
    color = settings.colors.default,
    align = {'right'},
  })
  gauge(cr, tonumber(avgCpu), {
    pos = {x = pos.x+scale(150), y = pos.y+scale(120)},
    radius = scale(100), thickness = scale(11),
    from = 2, to = 238,
    background = { color = settings.colors.gaugeBg, alpha = settings.colors.gaugeBgAlpha },
    color = settings.colors.gauge,
    alpha = settings.colors.gaugeAlpha,
    warn = {from = 100/cpuCount, color = settings.colors.gaugeInfo},
    crit = {from = 90, color = settings.colors.gaugeWarn},
  })
  graph(cr, 'cpu', tonumber(avgCpu), {
    pos = {x = pos.x+scale(163), y = pos.y + scale(90)},
    direction = 'left', amplitude = 'center',
    color = settings.colors.gauge,
    alpha = 0.9, width = scale(163), height = scale(20),
  })

  -- cpus
  if cpuCount > 1 then
    local y, r = pos.y+scale(38), scale(89)
    local perRow = math.ceil(cpuCount/4)
    local minCoresPerRow = config.minCoresPerRow or 2
    if perRow < minCoresPerRow then
        perRow = minCoresPerRow
    end
    local s = ''
    for i=1,cpuCount,1 do
      s = s .. '${cpu cpu' .. i .. '},'
    end
    local cpuUsage = conky_parse(s):split(',')
    local leftPos = nil;
    for i=1,cpuCount,perRow do
      local usages = {}
      local sum = 0
      local j
      for j=i,i+perRow-1,1 do
        if j > cpuCount then
          break
        end
        table.insert(usages, tonumber(cpuUsage[j]))
        sum = sum + cpuUsage[j]
      end

      --local max = tostring(math.max(table.unpack(usages)))
      --local min = tostring(math.min(table.unpack(usages)))
      local avg = round(sum/perRow,1)

      local text
      if perRow == 1 then
        text = avg .. '% on Core ' .. i
      else
        text = ('' .. avg .. '%'):pad(7, ' ', 'STR_PAD_LEFT') ..
          ' on Cores ' .. (i .. '-' .. i+perRow-1):pad(5, ' ', 'STR_PAD_LEFT')
      end

      local bb = write(
        cr,
        text,
        {
          pos = {x = (leftPos and leftPos or pos.x+scale(140)), y = y},
          font = {settings.fonts.default, scale(10)},
          color = settings.colors.default,
          align = {(leftPos and 'left' or 'right')},
        }
      )
      leftPos = bb.x

      local thickness = math.floor(scale(12) / perRow)                   -- 4 = 3 / 6 = 2 / 8 = 1   / 12 = 1 / 16 = 0
      local rDec = thickness + (scale(12) - thickness * perRow) / perRow -- 4 = 3 / 6 = 2 / 8 = 1.5 / 12 = 0 / 16 = 0.75
      if thickness == 0 then
        thickness = 1
      elseif thickness > 2 then
        rDec = thickness
        thickness = math.ceil(thickness / 2 )
      end
      local usage
      for j,usage in ipairs(usages) do
        gauge(cr, usage, {
          pos = {x = pos.x+scale(150), y = pos.y+scale(120)},
          radius = r - rDec * (j-1), thickness = thickness,
          from = 0, to = 240,
          background = { color = settings.colors.gaugeBg, alpha = settings.colors.gaugeBgAlpha },
          color = settings.colors.gauge,
          alpha = settings.colors.gaugeAlpha,
          warn = {from = 50, color = settings.colors.gaugeInfo},
        })
      end

      y = y + scale(12)
      r = r - scale(12)
    end
  end

  -- top
  local y = pos.y + scale(115)
  if config.top and config.top > 0 then
    if cache.top == nil or updates % 4 == 0 then
      -- local topCpu = os.capture('LC_ALL=C ps -eo comm,%cpu --sort=-%cpu --no-headers|head -4'):split('\n')
      local topCpu = os.capture(
        'LC_ALL=C top -w 512 -bn 1 -d 1 -o %CPU|grep -A40 "PID USER"|tail -40|' ..
        'tr -s " "|cut -d " " -f10,13-'
      ):split('\n')
      topCpu = table.map(topCpu, function (row)
        local cpu, cmd = row:match('^([%d.]+) +(.-)$')
        if cmd == nil then return {cmd = '', cpu = 0} end
        return {
          cmd = string.sub(cmd, 1, 20),
          cpu = cpu,
        }
      end)
      topCpu = table.group(
        topCpu,
        function (row) return row.cmd end,
        {
          sum = function (sum, row)
            if sum == nil then
              return tonumber(row.cpu)
            end
            return sum + tonumber(row.cpu)
          end,
        }
      )

      topCpu = table.values(table.filter(topCpu, function (row)
        return row.sum > 0.0
      end))
      table.sort(topCpu, function (row1, row2)
        return row1.sum > row2.sum
      end)

      cache.top = {}
      table.move(topCpu, 1, config.top, 1, cache.top)
    end

    local firstRow = y;
    for _, data in pairs(cache.top) do
      write(cr, data.key:pad(20) .. tostring(round(data.sum/cpuCount, 1)):pad(7, ' ', 'STR_PAD_LEFT') .. '%', {
        pos = { x = pos.x+2, y = y },
        font = {settings.fonts.default, scale(10)},
        color = settings.colors.default,
      });
      y = y + scale(12)
    end
    y = firstRow + scale(12) * config.top
  end

  -- cpu info
  --write(cr, 'AMD Ryzen 7 9700X', {
  --    pos = {x = pos.x, y = y},
  --    font = {settings.fonts.default, scale(10)},
  --    color = settings.colors.default,
  --    align = {'left', 'top'},
  --})
  --y = y + scale(10+4);

  -- label
  write(cr, 'CPU', {
    pos = {x = pos.x+2, y = y},
    font = {settings.fonts.significant, scale(24), 0},
    color = settings.colors.highlight,
    align = {'left', 'top'},
  })
end

function updateMemory(config)
  local pos = config.pos or {x = width-scale(205), y = scale(150)}
  local free = os.capture('LC_ALL=C free -m'):split('\n')
  local memTotal, memUsed, memFree, memShared, memBuffers, memAvailable =
    free[2]:match('(%d+) +(%d+) +(%d+) +(%d+) +(%d+) +(%d+)')
  local swapTotal, swapUsed, swapFree = free[3]:match('(%d+) +(%d+) +(%d+)')

  -- label
  local y = pos.y + scale(20)
  write(cr, 'Memory', {
    pos = {x = pos.x+scale(200), y = y},
    font = {settings.fonts.significant, scale(24), 0},
    color = settings.colors.highlight,
    align = {'right', 'top'},
  })
  y = y + scale(50)


  -- memory
  local used = humanReadableBytes(memUsed + memShared, 'MiB'):pad(7, ' ', 'STR_PAD_LEFT')
  local total = humanReadableBytes(memTotal + 0, 'MiB'):pad(7, ' ', 'STR_PAD_LEFT')
  write(cr, 'RAM', {
    pos = {x = pos.x+scale(58), y = pos.y+scale(131)},
    font = {settings.fonts.default, scale(10)},
    color = settings.colors.default,
  })
  write(cr, used .. ' / ' .. total, {
    pos = {x = pos.x+scale(200), y = pos.y+scale(131)},
    font = {settings.fonts.default, scale(10)},
    color = settings.colors.default,
    align = {'right', 'center'},
  })
  gauge(cr, memUsed + memShared, {
    pos = {x = pos.x+scale(48), y = pos.y+scale(68)},
    radius = scale(60), thickness = scale(15),
    from = 184, to = 416,
    background = { color = settings.colors.gaugeBg, alpha = settings.colors.gaugeBgAlpha },
    color = settings.colors.gauge,
    alpha = settings.colors.gaugeAlpha,
    max = memTotal,
    warn = {from = memTotal * 0.5, color = settings.colors.gaugeInfo},
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
  write(cr, 'Swap', {
    pos = {x = pos.x+scale(58), y = pos.y+scale(115)},
    font = {settings.fonts.default, scale(10)},
    color = settings.colors.default,
  })
  write(cr, used .. ' / ' .. total, {
    pos = {x = pos.x+scale(200), y = pos.y+scale(115)},
    font = {settings.fonts.default, scale(10)},
    color = settings.colors.default,
    align = {'right', 'center'},
  })
  gauge(cr, tonumber(swapUsed), {
    pos = {x = pos.x+scale(48), y = pos.y+scale(68)},
    radius = scale(43), thickness = scale(11),
    from = 182, to = 418,
    background = { color = settings.colors.gaugeBg, alpha = settings.colors.gaugeBgAlpha },
    color = settings.colors.gauge,
    alpha = settings.colors.gaugeAlpha,
    max = swapTotal,
    warn = {from = swapTotal * 0.1, color = settings.colors.gaugeWarn},
    crit = {from = swapTotal * 0.2, color = settings.colors.gaugeCrit},
  })

  -- caches
  local buffer = humanReadableBytes(memBuffers + 0, 'MiB'):pad(7, ' ', 'STR_PAD_LEFT')
  write(cr, 'Cache', {
    pos = {x = pos.x+scale(58), y = pos.y+scale(142)},
    font = {settings.fonts.default, scale(10)},
    color = settings.colors.default,
  })
  write(cr, buffer, {
    pos = {x = pos.x+scale(200), y = pos.y+scale(142)},
    font = {settings.fonts.default, scale(10)},
    color = settings.colors.default,
    align = {'right', 'center'},
  })

  -- top
  if config.top and config.top > 0 then
    if cache.topMem == nil or updates % 4 == 0 then
      local topMem = os.capture('LC_ALL=C ps -eo comm,%mem --sort=-%mem --no-headers|head -40'):split('\n')
      topMem = table.map(topMem, function (row)
        local cmd, mem = row:match('^(.-) +([%d.]+)$')
        return {
          cmd = cmd,
          mem = tonumber(mem),
        }
      end)
      topMem = table.group(
        topMem,
        function (row) return row.cmd end,
        {
          sum = function (sum, row)
            if sum == nil then
              return row.mem
            end
            return sum + row.mem
          end,
        }
      )
      topMem = table.values(topMem)


      table.sort(topMem, function (row1, row2)
        return tonumber(row1.sum) > tonumber(row2.sum)
      end)
      cache.topMem = {}
      table.move(topMem, 1, config.top, 1, cache.topMem)
    end

    for _, data in pairs(cache.topMem) do
      write(cr, data.key:pad(20, ' ') .. tostring(data.sum):pad(6, ' ', 'STR_PAD_LEFT') .. '%', {
        pos = { x = pos.x+scale(200), y = y },
        font = {settings.fonts.default, scale(10)},
        color = settings.colors.default,
        align = {'right'},
      });
      y = y + scale(12)
    end
  end
end

function updateDisks(config)
  local pos = config.pos or {x = 0, y = scale(250)}
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
      mount = mount:match('on (/[a-zA-Z0-9 ./_-]*) type')
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

  local sort, i = {}, 0
  if not config.sort or config.sort == 'size' then
    local sizes, j = {}, 0
    for name,mount in pairs(disks) do
      j = j + 1
      sizes[j] = {tonumber(os.capture('df -P ' .. mount .. '|tail -1|awk \'{print $2}\'')), name}
    end
    table.sort(sizes, function (a, b) return a[1] > b[1]; end)
    for _,size in pairs(sizes) do
      i = i + 1
      sort[i] = size[2]
    end
  elseif type(config.sort) == "table" then
    sort = config.sort
  end

  local radius, y, i = scale(56.5), pos.y + scale(8), 0
  for _,name in pairs(sort) do
    local mount = disks[name]
    i = i + 1
    if i > 4 then break end
    local used = conky_parse('${fs_used ' .. mount .. '}'):pad(7, ' ', 'STR_PAD_LEFT')
    local total = conky_parse('${fs_size ' .. mount .. '}'):pad(7, ' ', 'STR_PAD_LEFT')
    write(cr, name, {
      pos = {x = pos.x + 2, y = y},
      font = {settings.fonts.default, scale(10)},
      color = settings.colors.default,
    })
    write(cr, used .. ' / ' .. total, {
      pos = {x = pos.x+scale(200), y = y},
      font = {settings.fonts.default, scale(10)},
      color = settings.colors.default,
      align = {'right'},
    })
    gauge(cr, tonumber(conky_parse('${fs_used_perc ' .. mount .. '}')), {
        pos = {x = pos.x+scale(210), y = pos.y+scale(60)},
        radius = radius, thickness = scale(7),
        from = 0, to = 180,
        background = { color = settings.colors.gaugeBg, alpha = settings.colors.gaugeBgAlpha },
        color = settings.colors.gauge,
        alpha = settings.colors.gaugeAlpha,
        warn = {from = 85, color = settings.colors.gaugeInfo},
        crit = {from = 98, color = settings.colors.gaugeCrit},
    })
    radius = radius - scale(12)
    y = y + scale(12)
  end

  -- label
  write(cr, 'Disks', {
    pos = {x = pos.x + 2, y = pos.y+scale(58)},
    font = {settings.fonts.significant, scale(18), 0},
    color = settings.colors.highlight,
    align = {'left', 'top'},
  })
end

function updateNetwork(config)
  local pos = config.pos or {x = width - scale(210), y = scale(315)}
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
    pos = {x = pos.x+scale(195), y = pos.y+scale(8)},
    font = {settings.fonts.significant, scale(18), 0},
    color = settings.colors.highlight,
    align = {'right', 'top'},
  })

  y = pos.y + scale(87)
  -- upload
  gauge(cr, upspeed, {
    pos = {x = pos.x+scale(50), y = pos.y+scale(50)},
    radius = scale(35), thickness = scale(5),
    from = 240, to = 419,
    background = { color = settings.colors.gaugeBg, alpha = settings.colors.gaugeBgAlpha },
    color = settings.colors.gauge,
    alpha = settings.colors.gaugeAlpha,
    max = cache.maxUp,
    warn = {from = cache.maxUp * .50, color = settings.colors.gaugeInfo},
  })
  graph(cr, 'upload', upspeed, {
    pos = {x = pos.x+scale(35), y = pos.y + scale(50)},
    direction = 'right', amplitude = 'up',
    color = settings.colors.gauge,
    alpha = 0.9, max = 'auto',
    width = scale(160), height = scale(12),
  })
  path(cr, {
    pos = {x = pos.x+scale(30), y = y-scale(7)},
    points = {
        { x = pos.x+scale(35), y = y},
        { x = pos.x+scale(25), y = y},
    },
    fill = { color = upspeed > 0.1 and settings.colors.highlight or settings.colors.default },
  })
  local totalUp = conky_parse('${totalup ' .. network .. '}'):pad(7, ' ', 'STR_PAD_LEFT')
  local up = humanReadableBytes(upspeed, 'KiB'):pad(7, ' ', 'STR_PAD_LEFT')
  local upMax = humanReadableBytes(cache.maxUp, 'KiB'):pad(7, ' ', 'STR_PAD_LEFT')
  write(cr, up .. ' / ' .. upMax .. ' ' .. totalUp, {
    pos = {x = pos.x + scale(195), y = y},
    font = {settings.fonts.default, scale(10)},
    color = settings.colors.default,
    align = {'right'},
  })
  y = y + scale(12)

  -- download
  gauge(cr, downspeed, {
    pos = {x = pos.x+scale(50), y = pos.y+scale(50)},
    radius = scale(45), thickness = scale(10),
    from = 242, to = 418,
    background = { color = settings.colors.gaugeBg, alpha = settings.colors.gaugeBgAlpha },
    color = settings.colors.gauge,
    alpha = settings.colors.gaugeAlpha,
    max = cache.maxUp,
    warn = {from = cache.maxUp * .50, color = settings.colors.gaugeInfo},
  })
  graph(cr, 'download', downspeed, {
    pos = {x = pos.x+scale(35), y = pos.y + scale(53)},
    direction = 'right', amplitude = 'down',
    color = settings.colors.gauge,
    alpha = 0.9, max = 'auto',
    width = scale(160), height = scale(12),
  })
  path(cr, {
    pos = {x = pos.x+scale(30), y = y},
    points = {
        { x = pos.x+scale(35), y = y-scale(7)},
        { x = pos.x+scale(25), y = y-scale(7)},
    },
    fill = { color = downspeed > 0.1 and settings.colors.highlight or settings.colors.default },
  })
  local totalDown = conky_parse('${totaldown ' .. network .. '}'):pad(7, ' ', 'STR_PAD_LEFT')
  local down = humanReadableBytes(downspeed, 'KiB'):pad(7, ' ', 'STR_PAD_LEFT')
  local downMax = humanReadableBytes(cache.maxDown, 'KiB'):pad(7, ' ', 'STR_PAD_LEFT')
  write(cr, down .. ' / ' .. downMax .. ' ' .. totalDown, {
    pos = {x = pos.x + scale(195), y = y},
    font = {settings.fonts.default, scale(10)},
    color = settings.colors.default,
    align = {'right'},
  })
  y = y + scale(12)

  -- info
  if config.hideInfo == nil or config.hideInfo == false then
    local localIp = conky_parse('${addr ' .. network .. '}')
    write(cr, 'LAN IP  ' .. localIp:pad(15, ' ', 'STR_PAD_LEFT'), {
      pos = {x = pos.x + scale(195), y = y},
      font = {settings.fonts.default, scale(10)},
      color = settings.colors.default,
      align = {'right'},
    })
    y = y + scale(12)
    local publicIp = conky_parse('${execi 3600 wget -q -O - checkip.dyndns.org | sed -e \'s/[^[:digit:]\\|.]//g\'}')
    write(cr, 'WAN IP  ' .. publicIp:pad(15, ' ', 'STR_PAD_LEFT'), {
      pos = {x = pos.x + scale(195), y = y},
      font = {settings.fonts.default, scale(10)},
      color = settings.colors.default,
      align = {'right'},
    })
  end
end

function updateBattery(config)
  if hasBattery() == false then return end
  local pos = config.pos or {x = width - scale(382), y = scale(88)}

  local percentage = tonumber(conky_parse('${battery_percent BAT0}'))
  -- I'm not really sure how to handle two batteries. Here I just create an average over both batteries
  if hasBattery('BAT1') then
    percentage = (percentage + tonumber(conky_parse('${battery_percent BAT1}'))) / 2
  end

  bar(cr, percentage, {
    thickness = scale(15),
    from = {x = pos.x + scale(30), y = pos.y + scale(12)},
    to = {x = pos.x + scale(174), y = pos.y + scale(12)},
    background = { color = settings.colors.gaugeBg, alpha = settings.colors.gaugeBgAlpha },
    color = settings.colors.gauge,
    alpha = settings.colors.gaugeAlpha,
    warn = {to = 20, color = settings.colors.gaugeWarn},
    crit = {to = 5, color = settings.colors.gaugeCrit},
  })

  local file = 'assets/battery.png'
  local battery_status=conky_parse('${battery_short BAT0}')
  if battery_status == 'F' or battery_status:find('C') then
    file = 'assets/power.png'
  end
  image = imlib_load_image(file)
  if image == nil then return end
  imlib_context_set_image(image)
  imlib_render_image_on_drawable(pos.x, pos.y)
end

function updateLoad(config)
  local pos = config.pos or {x = 0, y = scale(340)}

  local load1m = conky_parse('${loadavg 1}')
  local load5m = conky_parse('${loadavg 2}')
  local load15m = conky_parse('${loadavg 3}')
  local cpuCount = getCpuCount()
  local max = config.max or (cpuCount * 2)
  local warn = config.warn or cpuCount
  local crit = config.crit or (cpuCount * 1.1)

  -- gauges
  gauge(cr, tonumber(load1m), {
    pos = {x = pos.x+scale(8), y = pos.y+scale(500)},
    radius = scale(484), thickness = scale(16),
    from = 0.4, to = 35,
    background = { color = settings.colors.gaugeBg, alpha = settings.colors.gaugeBgAlpha },
    color = settings.colors.gauge,
    alpha = settings.colors.gaugeAlpha,
    max = max,
    warn = {from = warn, color = settings.colors.gaugeWarn},
    crit = {from = crit, color = settings.colors.gaugeCrit},
  })
  gauge(cr, tonumber(load5m), {
    pos = {x = pos.x+scale(8), y = pos.y+scale(500)},
    radius = scale(470), thickness = scale(8),
    from = 0.1, to = 33,
    background = { color = settings.colors.gaugeBg, alpha = settings.colors.gaugeBgAlpha },
    color = settings.colors.gauge,
    alpha = settings.colors.gaugeAlpha,
    max = max,
    warn = {from = warn, color = settings.colors.gaugeWarn},
    crit = {from = crit, color = settings.colors.gaugeCrit},
  })
  gauge(cr, tonumber(load15m), {
    pos = {x = pos.x+scale(8), y = pos.y+scale(500)},
    radius = scale(462), thickness = scale(4),
    from = 0, to = 31,
    background = { color = settings.colors.gaugeBg, alpha = settings.colors.gaugeBgAlpha },
    color = settings.colors.gauge,
    alpha = settings.colors.gaugeAlpha,
    max = max,
    warn = {from = warn, color = settings.colors.gaugeWarn},
    crit = {from = crit, color = settings.colors.gaugeCrit},
  })

  -- label
  write(cr, 'Load average', {
    pos = {x = pos.x+scale(2), y = pos.y+scale(58)},
    font = {settings.fonts.significant, scale(18), 0},
    color = settings.colors.highlight,
    align = {'left', 'top'},
  })

  -- text
  -- load1m = load1m:pad(5, ' ')
  -- load5m = load5m:pad(5, ' ')
  -- load15m = load15m:pad(5, ' ')
  write(cr, '1m ' .. load1m .. ' | 5m ' .. load5m .. ' | 15m ' .. load15m, {
    pos = {x = pos.x+scale(2), y = pos.y + scale(94)},
    font = {settings.fonts.default, scale(10)},
    color = settings.colors.default,
    align = {'left', 'top'},
  })
end
