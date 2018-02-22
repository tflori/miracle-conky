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
  networks = os.capture('route -n|egrep \'^0.0.0.0\'|egrep -o \'[a-z0-9-]*$\''):split("\n")
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
  return io.fileExists('/sys/class/power_supply/' .. bat)
end

function getCpuCount()
  return tonumber(os.capture('nproc'))
end
