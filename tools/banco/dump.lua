-- Every visible region under a frame, in draw order, for the PNG renderer.
local LAYER = { BACKGROUND = 1, BORDER = 2, ARTWORK = 3, OVERLAY = 4, HIGHLIGHT = 9 }
local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }

function DUMP(root, extra)
  local out = {}
  local seq = 0
  local function strataOf(f)
    while f do
      local s = rawget(f, "_strata")
      if s then return STRATA[s] or 3 end
      f = rawget(f, "_parent")
    end
    return 3
  end
  local function clipOf(f)
    while f do
      if rawget(f, "_kind") == "ScrollFrame" or rawget(f, "_clips") then
        local l, b, w, h = f:GetRect()
        return { l, b, w, h }
      end
      f = rawget(f, "_parent")
    end
    return nil
  end
  local function walk(f, levelBase)
    if not f:IsShown() then return end
    for _, c in ipairs(f._children) do
      local k = c._kind
      if k == "Texture" or k == "FontString" then
        if c._shown and (c._layer ~= "HIGHLIGHT") then
          local l, b, w, h = c:GetRect()
          seq = seq + 1
          local e = { kind = k, l = l, b = b, w = w, h = h, strata = strataOf(f), level = f:GetFrameLevel(), layer = LAYER[c._layer or "ARTWORK"] or 3,
            sub = c._sub or 0, seq = seq, alpha = (c._alpha or 1) * (f:GetEffectiveAlpha() or 1) }
          if k == "Texture" then
            local vc = c._vc or { 1, 1, 1, 1 }
            e.r, e.g, e.bb, e.a = vc[1], vc[2], vc[3], vc[4] or 1
            e.tex = type(c._tex) == "string" and c._tex or tostring(c._tex)
            local tc = c._tc4
            e.tc = tc
            e.flip = tc and tc[1] == 1 and tc[2] == 0 or false
            e.half = tc and ((tc[1] == 0 and tc[2] == 0.5) and "L" or (tc[1] == 0.5 and tc[2] == 1) and "R") or nil
            local gr = c._grad
            if gr then e.gorient, e.g1, e.g2 = gr[1], gr[2], gr[3] end
          else
            local tc = c._tc or { 1, 1, 1, 1 }
            e.r, e.g, e.bb, e.a = tc[1], tc[2], tc[3], tc[4] or 1
            e.text = c._text or ""
            e.size = c._font and c._font[2] or 12
            e.fontpath = c._font and c._font[1] or ""
            e.jh, e.jv = c._jh or "CENTER", c._jv or "MIDDLE"
            e.wrap = c._wrap and true or false
            e.setw = c._w or 0
            e.maxl = c._max or 0
            -- la caja del texto: el marco que lo contiene (para avisar si se sale)
            local pl, pb, pw, ph = f:GetRect()
            e.pl, e.pb, e.pw, e.ph = pl, pb, pw, ph
          end
          local clip = clipOf(c)
          if clip then e.cl, e.cb, e.cw, e.ch = clip[1], clip[2], clip[3], clip[4] end
          out[#out + 1] = e
        end
      else
        walk(c)
      end
    end
  end
  walk(root)
  for _, f in ipairs(extra or {}) do if f and f:IsShown() then walk(f) end end
  local l, b, w, h = root:GetRect()
  return out, l, b, w, h
end
