require 'cairo'
require 'lib'

--[[
Convert hexadezimal colors to rgba values

e.g. cairo_set_source_rgba(cr, rgbToRgba(0xff7f00, 0.8))
]]
function rgbToRgba(color, alpha)
  return ((color / 0x10000) % 0x100) / 255.0,
  ((color / 0x100) % 0x100) / 255.0,
  (color % 0x100) / 255.0,
  alpha
end

--[[
Write text on cr by definition (def)

def = {
  color = 0xffffff,
  alpha = 1,
  pos = {x = 23, y = 42},
  font = {'Open Sans', 12, 0|1|2|3},
  align = {'LEFT|right|center', 'BASELINE|bottom|middle|top'},
}

font[3] are bit flags where first bit is bold and second bit is italic. So:
  0 is normal,
  1 is bold,
  2 is italic,
  3 is bold+italic

returns the boundingBox = {
  left = %d,
  top = %d,
  width = %d,
  height = %d,
  right = %d,
  bottom = %d,
}
]]
function write(cr, text, def)
  local font = def.font[1] or 'Open Sans'
  local fontSize = def.font[2] or 12
  local fontSlant = CAIRO_FONT_SLANT_NORMAL
  local fontWeight = CAIRO_FONT_WEIGHT_NORMAL

  if def.font[3] and def.font[3] % 2 == 1 then
    fontWeight = CAIRO_FONT_WEIGHT_BOLD
  end
  if def.font[3] and def.font[3] / 2 >= 1 then
    fontWeight = CAIRO_FONT_SLANT_ITALIC
  end

  cairo_select_font_face(cr, font, fontSlant, fontWeight)
  cairo_set_font_size(cr, fontSize)

  cairo_set_source_rgba(cr, rgbToRgba( def.color or 0xffffff, def.alpha or 1))

  local x = def.pos.x
  local y = def.pos.y
  local te = cairo_text_extents_t:create()
  local fe = cairo_font_extents_t:create()
  cairo_text_extents(cr, text, te)
  cairo_font_extents(cr, fe)

  if def.align ~= nil then
    if def.align[1] == 'right' then
      x = x - te.width - te.x_bearing
    elseif def.align[1] == 'center' then
      x = x - te.width/2 - te.x_bearing
    end

    if def.align[2] == 'bottom' then
      y = y - fe.descent
    elseif def.align[2] == 'middle' then
      y = y + te.height/2
    elseif def.align[2] == 'top' then
      y = y + fe.ascent
    end
  end

  cairo_move_to(cr, x, y)
  cairo_show_text(cr, text)
  cairo_new_path(cr)

  local boundingBox = {
    x = x + te.x_bearing,
    y = y + te.y_bearing,
    width = te.width,
    height = te.height,
    right = x + te.x_bearing + te.width,
    bottom = y + te.y_bearing + te.height
  }
  return boundingBox
end

--[[
Draw a rectangle on cr by definition (def)

def = {
  pos = {x = 10, y = 10},
  size = {width = 200, height = 100},
  fill = {color = 0x000000, alpha = 0.2},
  stroke = {width = 2, color = 0x000000, alpha = 0.5},
  cornerRadius = 0,
}
]]
function roundRectangle(cr, def)
  local pos, size = def.pos, def.size;
  local double radius = def.cornerRadius or 0;
  local double degrees = math.pi / 180.0;

  cairo_new_sub_path(cr)
  cairo_arc(
    cr,
    pos.x + size.width - radius,
    pos.y + radius,
    radius,
    -90 * degrees,
    0 * degrees
  )
  cairo_arc(
    cr,
    pos.x + size.width - radius,
    pos.y + size.height - radius,
    radius,
    0 * degrees,
    90 * degrees
  )
  cairo_arc(
    cr,
    pos.x + radius,
    pos.y + size.height - radius,
    radius,
    90 * degrees,
    180 * degrees
  )
  cairo_arc(
    cr,
    pos.x + radius,
    pos.y + radius,
    radius,
    180 * degrees,
    270 * degrees
  )
  cairo_close_path(cr)

  if def.fill then
    cairo_set_source_rgba(
      cr,
      rgbToRgba(def.fill.color, def.fill.alpha or 1)
    )
    cairo_fill_preserve(cr)
  end

  if def.stroke ~= nil then
    cairo_set_source_rgba(
      cr,
      rgbToRgba(def.stroke.color, def.stroke.alpha or 1)
    )
    cairo_set_line_width(cr, def.stroke.width)
    cairo_stroke_preserve(cr)
  end

  cairo_new_path(cr)
end

--[[
Draw a ring on cr by definition (def)

def = {
  pos = {x = 100, y = 100},
  radius = 85,
  thickness = 10,
  from = 0, -- top
  to = 270, -- left
  color = 0xffffff,
  alpha = 0.8,
}
]]
function ring(cr, def)
  local pos, radius, thickness, from, to, color, alpha =
    def.pos, def.radius, def.thickness, def.from, def.to, def.color, def.alpha

  from = from * (2*math.pi/360) - math.pi/2
  to = to * (2*math.pi/360) - math.pi/2

  cairo_set_line_width(cr, thickness)
  cairo_set_line_cap(cr, CAIRO_LINE_CAP_ROUND)
  cairo_set_source_rgba(cr, rgbToRgba(color, alpha))
  cairo_arc(cr, pos.x, pos.y, radius, from, to)
  cairo_stroke(cr)
  cairo_new_path(cr)
end

function gauge(cr, value, def)
  if def.background then
    local bgDef = table.clone(def)
    bgDef.color = def.background.color
    bgDef.alpha = def.background.alpha
    ring(cr, bgDef)
  end

  if def.level2 then
    local level2Def = table.clone(def)
    level2Def.color = def.level2.color
    level2Def.alpha = def.level2.alpha
    local t = def.level2.value / (def.max or 100)
    if t > 1 then t = 1 end
    level2Def.to = def.from + t * (def.to - def.from)
    ring(cr, level2Def)
  end

  local t = value / (def.max or 100)
  if t > 1 then t = 1 end
  if t == 0.0 then return end
  def.to = def.from + t * (def.to - def.from)

  if def.warn and (def.warn.from and def.warn.from <= value or def.warn.to and def.warn.to >= value) then
    def.color = def.warn.color
  end
  if def.crit and (def.crit.from and def.crit.from <= value or def.crit.to and def.crit.to >= value) then
    def.color = def.crit.color
  end
  ring(cr, def)
end

local graphHistory = {}
--[[
Draw a graph
]]
function graph(cr, key, currentValue, def)
  if def.max == 0 then return end -- cant't draw a graph from 0 to 0

  -- fill graph history
  if graphHistory[key] == nil then graphHistory[key] = {} end
  table.insert(graphHistory[key], 1, currentValue)

  -- get defintions
  local thickness = def.thickness or 1
  local direction = def.direction or 'right'
  local amplitude = def.amplitude or 'up'
  local height = def.height or 50
  local width = def.width or 100
  local max = def.max or 100
  local count = def.count or width
  local color = def.color or 0xffffff
  local alpha = def.alpha or 1


  -- configure direction
  local incX, incY, fullX, fullY = 0, 0, 0, 0
  if direction == 'right' then
    incX = thickness
    fullY = 0 - height
  elseif direction == 'left' then
    incX = 0 - thickness
    fullY = 0 - height
  elseif direction == 'bottom' then
    incY = thickness
    fullX = width
    count = def.count or height
  elseif direction == 'top' then
    incY = 0 - thickness
    fullX = width
    count = def.count or height
  else
    print('direction has to be one of left, right, bottom, top')
    return
  end

  -- configure amplitude
  if amplitude == 'down' then
    fullY = height
  elseif amplitude == 'left' then
    fullX = width
  elseif amplitude == 'center' then
    if direction == 'right' or direction == 'left' then
      fullY = height/2
    elseif direction == 'top' or direction == 'right' then
      fullX = width/2
    end
  end

  -- remove old history
  if table.getn(graphHistory[key]) > count then table.remove(graphHistory[key]) end

  -- get the current max
  if max == 'auto' then
    max = 0
    for i,value in pairs(graphHistory[key]) do
      if max < value then
        max = value
      end
    end
    if max == 0 then return end
  end

  -- draw
  for i,value in pairs(graphHistory[key]) do
    local v = value / max
    if v > 1 then v = 1 end

    local s = {
      x = round(def.pos.x + incX * (i-1)),
      y = round(def.pos.y + incY * (i-1))
    }
    local e = {
      x = round(s.x + (v * fullX), 1),
      y = round(s.y + (v * fullY), 1)
    }

    if amplitude == 'center' then
      s = {
        x = round(s.x - (v * fullX), 1),
        y = round(s.y - (v * fullY), 1),
      }
    end

    if e.y ~= s.y or e.x ~= s.x then
      line(cr, {
        thickness = thickness, color = color, alpha = alpha,
        from = {x = s.x + thickness/2, y = s.y + thickness/2},
        to = {x = e.x + thickness/2, y = e.y + thickness/2},
      })
    end
  end
end

function bar(cr, value, def)
  def.caps = def.caps or CAIRO_LINE_CAP_ROUND

  if def.background then
    local bgDef = table.clone(def)
    bgDef.color = def.background.color
    bgDef.alpha = def.background.alpha
    line(cr, bgDef)
  end

  local t = value / (def.max or 100)
  if t > 1 then t = 1 end
  if t == 0.0 then return end
  def.to = {
    x = def.from.x + t * (def.to.x - def.from.x),
    y = def.from.y + t * (def.to.y - def.from.y),
  }

  if def.warn and (def.warn.from and def.warn.from <= value or def.warn.to and def.warn.to >= value) then
    def.color = def.warn.color
  end
  if def.crit and (def.crit.from and def.crit.from <= value or def.crit.to and def.crit.to >= value) then
    def.color = def.crit.color
  end
  line(cr, def)
end

function line(cr, def)
  local thickness = def.thickness or 1
  local color = def.color or 0xffffff
  local alpha = def.alpha or 1
  local caps = def.caps or CAIRO_LINE_CAP_BUTT

  cairo_set_line_width(cr, thickness)
  cairo_set_line_cap(cr, caps)
  cairo_set_source_rgba(cr, rgbToRgba(color, alpha))
  cairo_move_to(cr, def.from.x, def.from.y)
  cairo_line_to(cr, def.to.x, def.to.y)
  cairo_stroke(cr)
  cairo_new_path(cr) -- just to be sure
end
