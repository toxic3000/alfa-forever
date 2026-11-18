-- A mocked WoW client for loading Alfa's engine and driving its windows.
-- Frames keep their anchors and sizes and resolve real rectangles; font
-- strings measure text roughly; unknown globals are "comodin" stand-ins.

local real = { string=string, table=table, math=math, pairs=pairs, ipairs=ipairs,
  type=type, tostring=tostring, tonumber=tonumber, select=select, next=next,
  pcall=pcall, xpcall=xpcall, error=error, assert=assert, unpack=unpack,
  setmetatable=setmetatable, getmetatable=getmetatable, rawget=rawget,
  rawset=rawset, rawequal=rawequal, coroutine=coroutine, loadstring=loadstring,
  print=print, debug=debug, os={time=os.time, date=os.date, clock=os.clock} }

ERRORS = {}
local function note(where, e) ERRORS[#ERRORS + 1] = where .. ": " .. tostring(e) end
NOTE = note

local comodin_mt = {}
local function Comodin() return setmetatable({}, comodin_mt) end
comodin_mt.__index = function(t, k) local c = Comodin(); rawset(t, k, c); return c end
comodin_mt.__call = function() return nil end
comodin_mt.__tostring = function() return "comodin" end
COMODIN = Comodin

---------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------
local Frame = {}
local frame_mt = {}
local allFrames = {}
local eventFrames = {}
local named = {}
UIP = nil

local function newObj(kind, parent)
  local o = { _kind = kind, _parent = parent, _points = {}, _shown = true, _alpha = 1, _scripts = {}, _hooks = {},
    _events = {}, _level = parent and (rawget(parent, "_level") or 0) + 1 or 0, _children = {}, _scale = 1,
    _text = nil, _enabled = true }
  setmetatable(o, frame_mt)
  if parent and rawget(parent, "_children") then table.insert(parent._children, o) end
  allFrames[#allFrames + 1] = o
  return o
end

MISSING = {}
frame_mt.__index = function(t, k)
  return Frame[k]
end

local function fire(self, script, ...)
  local fn = self._scripts[script]
  if fn then
    local ok, e = pcall(fn, self, ...)
    if not ok then note("script " .. script, e) end
  end
  for _, h in ipairs(self._hooks[script] or {}) do
    local ok, e = pcall(h, self, ...)
    if not ok then note("hook " .. script, e) end
  end
end
FIRE = fire

function Frame:GetObjectType() return self._kind end
function Frame:IsObjectType(k) return self._kind == k end
function Frame:GetName() return self._name end
function Frame:IsForbidden() return false end
function Frame:SetParent(p)
  local old = self._parent
  if old and old._children then for i = #old._children, 1, -1 do if old._children[i] == self then table.remove(old._children, i) end end end
  self._parent = p
  if p and p._children then table.insert(p._children, self) end
end
function Frame:GetParent() return self._parent end
function Frame:GetChildren() local out = {} for _, c in ipairs(self._children) do if c._kind ~= "Texture" and c._kind ~= "FontString" then out[#out+1] = c end end return unpack(out) end
function Frame:GetRegions() local out = {} for _, c in ipairs(self._children) do if c._kind == "Texture" or c._kind == "FontString" then out[#out+1] = c end end return unpack(out) end
function Frame:SetSize(w, h) self._w, self._h = w, h end
function Frame:SetWidth(w) self._w = w end
function Frame:SetHeight(h) self._h = h end
function Frame:SetPoint(point, rel, relPoint, x, y)
  if type(rel) == "number" then rel, relPoint, x, y = nil, nil, rel, relPoint end
  if type(rel) == "string" then rel = named[rel] end
  if rel == nil then rel = self._parent end
  if type(relPoint) == "number" then relPoint, x, y = nil, relPoint, x end
  relPoint = relPoint or point
  for i = #self._points, 1, -1 do if self._points[i][1] == point then table.remove(self._points, i) end end
  self._points[#self._points + 1] = { point, rel, relPoint, x or 0, y or 0 }
end
function Frame:ClearAllPoints() self._points = {} end
function Frame:SetAllPoints(rel)
  rel = rel or self._parent
  if type(rel) == "string" then rel = named[rel] end
  self._points = { { "TOPLEFT", rel, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", rel, "BOTTOMRIGHT", 0, 0 } }
end
function Frame:GetNumPoints() return #self._points end
function Frame:GetPoint(i)
  local p = self._points[i or 1]
  if not p then return nil end
  return p[1], p[2], p[3], p[4], p[5]
end

local HX = { TOPLEFT = 0, LEFT = 0, BOTTOMLEFT = 0, TOP = 0.5, CENTER = 0.5, BOTTOM = 0.5, TOPRIGHT = 1, RIGHT = 1, BOTTOMRIGHT = 1 }
local HY = { TOPLEFT = 1, TOP = 1, TOPRIGHT = 1, LEFT = 0.5, CENTER = 0.5, RIGHT = 0.5, BOTTOMLEFT = 0, BOTTOM = 0, BOTTOMRIGHT = 0 }

local depth = 0
local function rect(self)
  if self == UIP then return 0, 0, 1920, 1080 end
  depth = depth + 1
  if depth > 60 then depth = depth - 1; return 0, 0, self._w or 0, self._h or 0 end
  local left, right, cx, top, bottom, cy
  for _, p in ipairs(self._points) do
    local rel = p[2]
    local rl, rb, rw, rh = 0, 0, 1920, 1080
    if rel and rel ~= self then rl, rb, rw, rh = rect(rel) end
    local ax = rl + rw * (HX[p[3]] or 0.5) + p[4]
    local ay = rb + rh * (HY[p[3]] or 0.5) + p[5]
    local hx, hy = HX[p[1]] or 0.5, HY[p[1]] or 0.5
    if hx == 0 then left = ax elseif hx == 1 then right = ax else cx = ax end
    if hy == 0 then bottom = ay elseif hy == 1 then top = ay else cy = ay end
  end
  local w, h = self._w, self._h
  if self._kind == "FontString" and (not w or w == 0) then w = self:GetStringWidth() end
  if self._kind == "FontString" and (not h or h == 0) then h = self:GetStringHeight() end
  w, h = w or 0, h or 0
  local l, b
  if left and right then l, w = left, right - left
  elseif left then l = left
  elseif right then l = right - w
  elseif cx then l = cx - w / 2
  else l = 0 end
  if bottom and top then b, h = bottom, top - bottom
  elseif bottom then b = bottom
  elseif top then b = top - h
  elseif cy then b = cy - h / 2
  else b = 0 end
  depth = depth - 1
  return l, b, w, h
end
function Frame:GetWidth() local _, _, w = rect(self) return w end
function Frame:GetHeight() local _, _, _, h = rect(self) return h end
function Frame:GetSize() local _, _, w, h = rect(self) return w, h end
function Frame:GetLeft() local l = rect(self) return l end
function Frame:GetBottom() local _, b = rect(self) return b end
function Frame:GetRight() local l, _, w = rect(self) return l + w end
function Frame:GetTop() local _, b, _, h = rect(self) return b + h end
function Frame:GetCenter() local l, b, w, h = rect(self) return l + w / 2, b + h / 2 end
function Frame:GetRect() return rect(self) end

function Frame:Show()
  local was = self:IsVisible()
  self._shown = true
  if not was and self:IsVisible() then fire(self, "OnShow") end
end
function Frame:Hide()
  local was = self:IsVisible()
  self._shown = false
  if was then fire(self, "OnHide") end
end
function Frame:SetShown(on) if on then self:Show() else self:Hide() end end
function Frame:IsShown() return self._shown end
function Frame:IsVisible()
  -- rawget: un padre "comodín" (marco de Blizzard que el banco no simula) crea
  -- otro comodín en cada lectura y la cadena de padres no terminaría nunca.
  local f = self
  while f do
    if not rawget(f, "_shown") then return false end
    f = rawget(f, "_parent")
  end
  return true
end
function Frame:SetAlpha(a) self._alpha = a end
function Frame:GetAlpha() return self._alpha end
function Frame:GetEffectiveAlpha() return self._alpha end
function Frame:SetScale(s) self._scale = s end
function Frame:GetScale() return self._scale end
function Frame:GetEffectiveScale() return 1 end
function Frame:SetFrameLevel(l) self._level = l end
function Frame:GetFrameLevel() return self._level or 0 end
function Frame:SetFrameStrata(s) self._strata = s end
function Frame:GetFrameStrata() return self._strata or "MEDIUM" end
function Frame:SetScript(s, fn) self._scripts[s] = fn end
function Frame:GetScript(s) return self._scripts[s] end
function Frame:HasScript(s) return true end
function Frame:HookScript(s, fn) self._hooks[s] = self._hooks[s] or {}; table.insert(self._hooks[s], fn) end
function Frame:RegisterEvent(ev) self._events[ev] = true; eventFrames[self] = true end
function Frame:RegisterUnitEvent(ev) self._events[ev] = true; eventFrames[self] = true end
function Frame:UnregisterEvent(ev) self._events[ev] = nil end
function Frame:UnregisterAllEvents() self._events = {} end
function Frame:IsEventRegistered(ev) return self._events[ev] == true end
function Frame:EnableMouse(on) self._mouse = on end
function Frame:IsMouseEnabled() return self._mouse end
function Frame:IsMouseOver() return false end
function Frame:SetEnabled(on) self._enabled = on and true or false end
function Frame:Enable() self._enabled = true end
function Frame:Disable() self._enabled = false end
function Frame:IsEnabled() return self._enabled end
function Frame:Click(button) fire(self, "PreClick", button or "LeftButton"); fire(self, "OnClick", button or "LeftButton", false); fire(self, "PostClick", button or "LeftButton") end
function Frame:IsProtected() return false end
function Frame:CreateTexture(name, layer, tmpl, sub)
  local t = newObj("Texture", self)
  t._layer, t._sub = layer, sub
  t._vc = { 1, 1, 1, 1 }
  if name then named[name] = t; _G[name] = t end
  return t
end
function Frame:CreateMaskTexture() return self:CreateTexture() end
-- Las líneas (las de la ruta en los mapas): una textura con sus dos puntas.
function Frame:CreateLine(name, layer, tmpl, sub)
  local t = self:CreateTexture(name, layer, tmpl, sub)
  t._kind = "Line"
  return t
end
function Frame:SetStartPoint(p, rel, x, y) self._ini = { p, rel, x, y } end
function Frame:SetEndPoint(p, rel, x, y) self._fin = { p, rel, x, y } end
function Frame:SetThickness(t) self._grueso = t end
function Frame:CreateFontString(name, layer, template)
  local t = newObj("FontString", self)
  t._layer = layer
  -- Como el juego: sin plantilla, el texto no tiene letra hasta SetFont o
  -- SetFontObject, y un SetText antes es un error ("Font not set").
  t._letra = template ~= nil
  t._wrap = true
  t._font = { "Fonts\\FRIZQT__.TTF", 12, "" }
  t._tc = { 1, 1, 1, 1 }
  if name then named[name] = t; _G[name] = t end
  return t
end
function Frame:CreateAnimationGroup()
  local g = Comodin()
  rawset(g, "CreateAnimation", function() return Comodin() end)
  rawset(g, "IsPlaying", function() return false end)
  return g
end
-- Textures
function Frame:SetTexture(t) self._tex = t; return true end
function Frame:GetTexture() return self._tex end
function Frame:SetColorTexture(r, g, b, a) self._tex = "color"; self._vc = { r, g, b, a or 1 } end
function Frame:SetVertexColor(r, g, b, a)
  if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then note("SetVertexColor", "bad colour " .. tostring(r) .. "," .. tostring(g) .. "," .. tostring(b) .. "\n" .. debug.traceback()) end
  self._vc = { r, g, b, a or 1 }
end
function Frame:GetVertexColor() local c = self._vc or { 1, 1, 1, 1 } return c[1], c[2], c[3], c[4] end
function Frame:SetTexCoord(...) self._tc4 = { ... } end
function Frame:GetTexCoord() return 0, 0, 0, 1, 1, 0, 1, 1 end
function Frame:SetGradient(orient, c1, c2)
  if type(c1) == "table" and type(c2) == "table" then self._grad = { orient, { c1.r, c1.g, c1.b, c1.a or 1 }, { c2.r, c2.g, c2.b, c2.a or 1 } } end
end
function Frame:SetBlendMode() end
function Frame:SetDesaturated() end
function Frame:SetDrawLayer(l, s) self._layer, self._sub = l, s end
function Frame:GetDrawLayer() return self._layer or "ARTWORK", self._sub or 0 end
function Frame:SetHorizTile() end
function Frame:SetVertTile() end
function Frame:SetSnapToPixelGrid() end
function Frame:SetTexelSnappingBias() end
function Frame:SetRotation() end
function Frame:AddMaskTexture() end
-- Font strings
function Frame:SetText(t)
  if self._kind == "FontString" and not rawget(self, "_letra") then
    note("SetText", "Font not set (el texto no tiene letra)\n" .. debug.traceback())
  end
  if t ~= nil and type(t) ~= "string" and type(t) ~= "number" then note("SetText", "bad text " .. type(t) .. "\n" .. debug.traceback()) end
  self._text = t ~= nil and tostring(t) or nil
  if self._kind == "EditBox" then fire(self, "OnTextChanged", false) end
end
function Frame:SetFormattedText(f, ...)
  if self._kind == "FontString" and not rawget(self, "_letra") then
    note("SetFormattedText", "Font not set (el texto no tiene letra)\n" .. debug.traceback())
  end
  self._text = string.format(f, ...)
end
function Frame:GetText() return self._text end
function Frame:SetFont(path, size, flags) self._font = { path, size or 12, flags or "" }; self._letra = true; return true end
function Frame:GetFont() local f = self._font or { "Fonts\\FRIZQT__.TTF", 12, "" } return f[1], f[2], f[3] end
function Frame:SetFontObject(o) if o ~= nil then self._letra = true end end
function Frame:SetTextColor(r, g, b, a)
  if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then note("SetTextColor", "bad colour\n" .. debug.traceback()) end
  self._tc = { r, g, b, a or 1 }
end
function Frame:GetTextColor() local c = self._tc or { 1, 1, 1, 1 } return c[1], c[2], c[3], c[4] end
function Frame:SetShadowColor() end
function Frame:SetShadowOffset() end
function Frame:SetJustifyH(j) self._jh = j end
function Frame:SetJustifyV(j) self._jv = j end
function Frame:SetWordWrap(on) self._wrap = on and true or false end
function Frame:SetNonSpaceWrap() end
function Frame:SetMaxLines(n) self._max = n end
function Frame:SetSpacing() end
function Frame:SetIndentedWordWrap() end
local function plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "XX")) end
local function textW(self)
  local size = (self._font and self._font[2]) or 12
  local longest = 0
  for line in (plain(self._text) .. "\n"):gmatch("(.-)\n") do
    local n = #line:gsub("[\128-\191]", "")
    if n > longest then longest = n end
  end
  -- ancho medio de una letra; una escena puede subirlo (BANCO_LETRA) para dejar margen
  return longest * size * (rawget(_G, "BANCO_LETRA") or 0.57)
end
function Frame:GetUnboundedStringWidth() return textW(self) end
function Frame:GetStringWidth()
  local w = textW(self)
  if self._w and self._w > 0 and w > self._w then return self._w end
  return w
end
function Frame:GetNumLines()
  local w = textW(self)
  local lines = 0
  for _ in (plain(self._text) .. "\n"):gmatch("(.-)\n") do lines = lines + 1 end
  if self._wrap and self._w and self._w > 0 and w > self._w then lines = lines + math.floor(w / self._w) end
  if self._max and self._max > 0 and lines > self._max then lines = self._max end
  if (self._text or "") == "" then return 0 end
  return lines
end
function Frame:GetStringHeight()
  local size = (self._font and self._font[2]) or 12
  return math.max(1, self:GetNumLines()) * (size + 3)
end
function Frame:GetLineHeight() return 14 end
function Frame:IsTruncated() return false end
-- Buttons
function Frame:SetNormalTexture() end
function Frame:SetHighlightTexture() end
function Frame:SetPushedTexture() end
function Frame:SetDisabledTexture() end
function Frame:SetCheckedTexture() end
function Frame:GetNormalTexture() return self:CreateTexture() end
function Frame:GetHighlightTexture() return self:CreateTexture() end
function Frame:GetPushedTexture() return self:CreateTexture() end
function Frame:SetChecked(on) self._checked = on end
function Frame:GetChecked() return self._checked end
function Frame:RegisterForClicks() end
function Frame:RegisterForDrag() end
function Frame:SetMotionScriptsWhileDisabled() end
function Frame:LockHighlight() end
function Frame:UnlockHighlight() end
-- Scroll frames
function Frame:SetScrollChild(c)
  self._child = c
  c._scrollOf = self
  c._points = { { "TOPLEFT", self, "TOPLEFT", 0, self._vs or 0 } }
end
function Frame:GetScrollChild() return self._child end
function Frame:SetVerticalScroll(v)
  self._vs = v
  if self._child then self._child._points = { { "TOPLEFT", self, "TOPLEFT", 0, v or 0 } } end
  fire(self, "OnVerticalScroll", v)
end
function Frame:GetVerticalScroll() return self._vs or 0 end
function Frame:SetHorizontalScroll(v) self._hs = v end
function Frame:GetHorizontalScroll() return self._hs or 0 end
function Frame:GetVerticalScrollRange() return 0 end
function Frame:UpdateScrollChildRect() end
function Frame:EnableMouseWheel() end
function Frame:SetClipsChildren() end
-- Edit boxes
function Frame:SetAutoFocus() end
function Frame:SetFocus() self._focus = true; fire(self, "OnEditFocusGained") end
function Frame:ClearFocus() self._focus = false; fire(self, "OnEditFocusLost") end
function Frame:HasFocus() return self._focus end
function Frame:SetTextInsets() end
function Frame:HighlightText() end
function Frame:SetCursorPosition() end
function Frame:SetMultiLine() end
function Frame:SetMaxLetters() end
function Frame:SetMaxBytes() end
function Frame:GetNumLetters() return #(self._text or '') end
function Frame:SetCountInvisibleLetters() end
function Frame:SetNumeric() end
function Frame:SetAltArrowKeyMode() end
-- Movement
function Frame:SetMovable() end
function Frame:SetResizable() end
function Frame:StartMoving() end
function Frame:StopMovingOrSizing() end
function Frame:SetClampedToScreen() end
function Frame:SetClampRectInsets() end
function Frame:SetToplevel() end
function Frame:Raise() end
function Frame:Lower() end
function Frame:SetUserPlaced() end
function Frame:SetDontSavePosition() end
function Frame:SetIgnoreParentAlpha() end
function Frame:SetIgnoreParentScale() end
function Frame:SetFixedFrameStrata() end
function Frame:SetFixedFrameLevel() end
function Frame:SetPropagateKeyboardInput() end
function Frame:EnableKeyboard() end
function Frame:SetHitRectInsets() end
function Frame:SetAttribute(k, v) self._attr = self._attr or {}; self._attr[k] = v end
function Frame:GetAttribute(k) return self._attr and self._attr[k] end
function Frame:SetMinMaxValues(a, b) self._min, self._max2 = a, b end
function Frame:GetMinMaxValues() return self._min or 0, self._max2 or 1 end
function Frame:SetValue(v) self._value = v; fire(self, "OnValueChanged", v, false) end
function Frame:GetValue() return self._value or 0 end
function Frame:SetValueStep() end
function Frame:SetObeyStepOnDrag() end
function Frame:SetOrientation() end
function Frame:SetThumbTexture() end
function Frame:SetStatusBarTexture() end
function Frame:SetStatusBarColor() end
function Frame:GetStatusBarTexture() return self:CreateTexture() end
function Frame:SetModel() end
function Frame:SetUnit() end
function Frame:SetCamera() end
function Frame:SetBackdrop() end
function Frame:SetBackdropColor() end
function Frame:SetBackdropBorderColor() end

function CreateFrame(kind, name, parent, template)
  if type(parent) == "string" then parent = named[parent] end
  local f = newObj(kind or "Frame", parent or UIP)
  if name then f._name = name; named[name] = f; _G[name] = f end
  return f
end

function FIRE_EVENT(ev, ...)
  local list = {}
  for f in pairs(eventFrames) do if f._events[ev] then list[#list + 1] = f end end
  for _, f in ipairs(list) do fire(f, "OnEvent", ev, ...) end
end

function ALL_FRAMES() return allFrames end
