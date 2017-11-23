function os.capture(cmd)
  local f = assert(io.popen(cmd, 'r'))
  local s = assert(f:read('*a'))
  f:close()
  return s
end

function io.fileExists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

function string:split(delimiter)
  local text = self
  local list = {}
  local pos = 1
  if string.find("", delimiter, 1) then -- this would result in endless loops
    error("delimiter matches empty string!")
  end

  while 1 do
    local first = text:find(delimiter, pos)
    if first then -- found?
      table.insert(list, text:sub(pos, first-1))
      pos = first+1
    else
      table.insert(list, text:sub(pos))
      break
    end
  end

  return list
end

function string:pad(pad_length, pad_string, pad_type)
  local output = self

  if not pad_string then pad_string = ' ' end
  if not pad_type   then pad_type   = 'STR_PAD_RIGHT' end

  if pad_type == 'STR_PAD_BOTH' then
    local j = 0
    while string.len(output) < pad_length do
      output = j % 2 == 0 and output .. pad_string or pad_string .. output
      j = j + 1
    end
  else
    while string.len(output) < pad_length do
      output = pad_type == 'STR_PAD_LEFT' and pad_string .. output or output .. pad_string
    end
  end

  return output
end

function string:titlecase()
    local str, result = self, ''
    for word in string.gfind(str, "%S+") do
        local first = string.sub(word,1,1)
        result = (result .. string.upper(first) ..
            string.lower(string.sub(word,2)) .. ' ')
    end
    return result
end

function table.clone(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == 'table' then
    copy = {}
    for orig_key, orig_value in next, orig, nil do
      copy[table.clone(orig_key)] = table.clone(orig_value)
    end
    setmetatable(copy, table.clone(getmetatable(orig)))
  else -- number, string, boolean, etc
    copy = orig
  end
  return copy
end

function table.contains(table, element)
  for _, value in pairs(table) do
    if value == element then
      return true
    end
  end
  return false
end

local units = {'B', 'KiB', 'MiB', 'GiB', 'TiB'}
function humanReadableBytes(bytes, current)
  if current == nil then current = 'B' end
  for i,unit in pairs(units) do
    if current == unit then
      if bytes > 99 then
        bytes = round(bytes / 1024, 1)
        current = units[i+1]
      else
        return bytes .. unit
      end
    end
  end

  return bytes .. 'PiB'
end

function round(num, numDecimalPlaces)
  if numDecimalPlaces and numDecimalPlaces>0 then
    local mult = 10^numDecimalPlaces
    return math.floor(num * mult + 0.5) / mult
  end
  return math.floor(num + 0.5)
end

function interp(s, tab)
  return (s:gsub('($%b{})', function(w) return tab[w:sub(3, -2)] or w end))
end

function getCoreHwmon()
  local output = os.capture('ls -l /sys/class/hwmon|grep coretemp')
  return tonumber(output:match(' hwmon%d '):sub(-2, -1));
end

function getCurrentNetwork()
  networks = os.capture('route|grep default|egrep -o \'[a-z0-9-]*$\''):split("\n")
  return networks[1]
end

function isWifi()
  local p = getCurrentNetwork():find('wl')
  return p ~= nil and p == 1
end

local lastSpeedTest = {
  download = 3000,
  upload = 1000,
  at = 0
}

local function speedtest()
  if lastSpeedTest.at > os.time() - 3600 then
    return lastSpeedTest;
  end

  local output = os.capture('speedtest'):split("\n")

  lastSpeedTest.at = os.time()
  lastSpeedTest.download = tonumber(output[1]:gsub(".%d+ KiB/s", ''), 10)
  lastSpeedTest.upload = tonumber(output[2]:gsub(".%d+ KiB/s", ''), 10)
  print('speedtest at ', lastSpeedTest.at, lastSpeedTest.download, lastSpeedTest.upload)
  return lastSpeedTest
end

function getDownloadSpeed()
  return speedtest().download
end

function getUploadSpeed()
  return speedtest().upload
end

function hasBattery(bat)
  bat = bat or 'BAT0'
  return io.fileExists('/sys/class/power_supply/BAT0')
end

function getCpuCount()
  return tonumber(os.capture('nproc'))
end

-- require "cairo"
--
-- local cs, colors, fonts
--
-- function initConky(fontSettings, colorSettings)
--     colors = colorSettings
--     fonts = fontSettings
--
--     cs = cairo_xlib_surface_create(
--         conky_window.display,
--         conky_window.drawable,
--         conky_window.visual,
--         conky_window.width,
--         conky_window.height
--     )
-- end
--
-- function pW(percentage)
--     return conky_window.width/100 * percentage
-- end
--
-- function pH(percentage)
--     return conky_window.height/100 * percentage
-- end
--
-- function drawBackground(settings)
--     local s = settings --alias for settings
--     local distance = 0
--     if s.stroke ~= nil then
--         distance = s.stroke[1]/2
--     end
--     roundRectangle(
--         {x = distance, y = distance},
--         {width = pW(100) - distance*2, height = pH(100) - distance*2},
--         {
--             fill = s.fill or nil,
--             stroke = s.stroke or nil,
--         },
--         s.rounded or 0
--     )
--     --local cr = cairo_create(cs)
--     --cairo_move_to(cr, pW(50), 0)
--     --cairo_line_to(cr, pW(50), pH(100))
--     --cairo_stroke(cr)
-- end
--
-- function drawTime(settings)
--     local s = settings --alias for settings
--     local y = 10
--     local bb --bounding box
--
--     if s.line1 ~= nil then
--         bb = write(os.date(s.line1.format), {
--             font = fonts.large,
--             color = colors[s.line1.color],
--             pos = {x = pW(50), y = y},
--             align = {'center', 'bottom'}
--         })
--         y = bb.bottom + 5
--     end
--
--     if s.line2 ~= nil then
--         bb = write(os.date(s.line2.format), {
--             font = fonts.default,
--             color = colors[s.line2.color],
--             pos = {x = pW(50), y = y},
--             align = {'center', 'bottom'}
--         });
--         y = bb.bottom + 5
--     end
-- end
--
-- function write(text, definition)
--     color = definition.color or colors.default
--     local x = definition.pos.x;
--     local y = definition.pos.y;
--     local cr = cairo_create(cs)
--
--     cairo_select_font_face(cr, definition.font[1], CAIRO_FONT_SLANT_NORMAL, definition.font[2])
--     cairo_set_font_size(cr, definition.font[3])
--     cairo_set_source_rgba(cr, unpack(color))
--
--     local te = cairo_text_extents_t:create()
--     local fe = cairo_font_extents_t:create()
--     cairo_text_extents(cr, text, te)
--     cairo_font_extents(cr, fe)
--
--     if definition.align ~= nil then
--         if definition.align[1] == 'right' then
--             x = x - te.width - te.x_bearing
--         elseif definition.align[1] == 'center' then
--             x = x - te.width/2 - te.x_bearing
--         end
--
--         if definition.align[2] == 'bottom' then
--             y = y + fe.ascent
--         elseif definition.align[2] == 'middle' then
--             y = y + te.height/2
--         elseif definition.align[2] == 'top' then
--             y = y - fe.descent
--         end
--     end
--
--     cairo_move_to(cr, x, y)
--     cairo_show_text(cr, text)
--
--     local boundingBox = {
--         x = x + te.x_bearing,
--         y = y + te.y_bearing,
--         width = te.width,
--         height = te.height,
--         right = x + te.x_bearing + te.width,
--         bottom = y + te.y_bearing + te.height
--     }
--     return boundingBox
-- end
--
-- function roundRectangle(pos, size, style, corner_radius)
--     local cr = cairo_create(cs)
--     local double radius = corner_radius or 0;
--     local double degrees = math.pi / 180.0;
--
--     cairo_new_sub_path(cr);
--     cairo_arc(
--         cr,
--         pos.x + size.width - radius,
--         pos.y + radius,
--         radius,
--         -90 * degrees,
--         0 * degrees
--     );
--     cairo_arc(
--         cr,
--         pos.x + size.width - radius,
--         pos.y + size.height - radius,
--         radius,
--         0 * degrees,
--         90 * degrees
--     );
--     cairo_arc(
--         cr,
--         pos.x + radius,
--         pos.y + size.height - radius,
--         radius,
--         90 * degrees,
--         180 * degrees
--     );
--     cairo_arc(
--         cr,
--         pos.x + radius,
--         pos.y + radius,
--         radius,
--         180 * degrees,
--         270 * degrees
--     );
--     cairo_close_path(cr);
--
--     if style.fill ~= nil then
--         cairo_set_source_rgba(
--             cr,
--             style.fill[1],
--             style.fill[2],
--             style.fill[3],
--             style.fill[4] or 1
--         );
--         cairo_fill_preserve(cr);
--     end
--
--     if style.stroke ~= nil then
--         cairo_set_source_rgba(
--             cr,
--             style.stroke[2],
--             style.stroke[3],
--             style.stroke[4],
--             style.stroke[5] or 1
--         );
--         cairo_set_line_width(cr, style.stroke[1]);
--         cairo_stroke(cr);
--     end
-- end
--
