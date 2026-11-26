-- El barrido del ratón (1.4.1). Lo carga run.py en todas las escenas.
--
-- Bug de Toxic con la 1.4.0: «no le puedo picar a un enemigo lejos, la
-- cámara no se mueve, no puedo clicar las pestañas de profesiones ni el
-- volumen». Un ancla invisible de Alfa (560x150, arriba del centro) tomaba el
-- ratón porque se le enganchó OnMouseDown (en el juego eso prende el ratón;
-- mock.lua ya lo imita). La prueba de antes miraba solo un momento (al entrar);
-- este barrido se corre en muchos momentos y revisa la pantalla punto por punto.
--
--   RATON_DE_ALFA(f)        -> true si el marco salió de un archivo de Alfa
--   RATON_ARRIBA(x, y, que) -> el marco que se queda con el ratón en ese punto
--                              (que: "clic" | "rueda"), el de más arriba
--   RATON_BARRIDO(momento, permitidos) -> lista de problemas (textos):
--     * un marco de Alfa a la vista que toma el clic o la rueda y no dibuja
--       nada que se vea (o con alfa casi 0): una pared invisible
--     * la pantalla «de juego» (sin ventanas de Alfa abiertas): ningún punto
--       de la franja del mundo queda bajo un marco de Alfa que no se ve
--   RATON_RESUMEN() -> texto con lo que toma el ratón ahora (para depurar)

local ESTRATOS = { WORLD = 0, BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6,
  FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }

function RATON_DE_ALFA(f)
  local o = rawget(f, "_origen")
  if type(o) ~= "string" then return false end
  o = o:gsub("\\", "/")
  -- Lo de Alfa se carga desde su carpeta (dist/Alfa*/...); las escenas y el
  -- juego simulado del banco, como trozos sueltos ("api.lua", "drive.lua").
  return (o:find("^Alfa") or o:find("/Alfa", 1, true)) ~= nil and not o:find("tools/banco", 1, true)
end

local function estrato(f)
  local x = f
  for _ = 1, 40 do
    if not x then break end
    local s = rawget(x, "_strata")
    if s then return ESTRATOS[s] or 3 end
    x = rawget(x, "_parent")
  end
  return 3
end

local function alfaEfectiva(f)
  local a, x = 1, f
  for _ = 1, 40 do
    if not x then break end
    a = a * (tonumber(rawget(x, "_alpha")) or 1)
    x = rawget(x, "_parent")
  end
  return a
end
RATON_ALFA = alfaEfectiva

local function nombreDe(f)
  local partes, x = {}, f
  for _ = 1, 4 do
    if not x then break end
    local n = x.GetName and x:GetName()
    partes[#partes + 1] = (type(n) == "string" and n) or ("<" .. tostring(rawget(x, "_kind")) .. ">")
    x = rawget(x, "_parent")
  end
  local o = tostring(rawget(f, "_origen") or "?"):gsub("\\", "/"):match("([^/]+/[^/]+)$") or "?"
  return table.concat(partes, " < ") .. " [" .. o .. "]"
end
RATON_NOMBRE = nombreDe

-- ¿Dibuja algo que se vea? Una textura con algo puesto y alfa, o un texto.
local function texturaSeVe(t)
  if not rawget(t, "_shown") or (tonumber(rawget(t, "_alpha")) or 1) <= 0.02 then return false end
  local tex = rawget(t, "_tex") or rawget(t, "_atlas")
  if tex == nil or tex == "" then return false end
  local vc = rawget(t, "_vc")
  if type(vc) == "table" and (tonumber(vc[4]) or 1) <= 0.02 then return false end
  return true
end
local function seVe(f, prof)
  prof = prof or 0
  if tostring(rawget(f, "_text") or "") ~= "" then return true end
  if prof > 5 then return false end
  for _, c in ipairs(rawget(f, "_children") or {}) do
    if rawget(c, "_shown") and (tonumber(rawget(c, "_alpha")) or 1) > 0.02 then
      local k = rawget(c, "_kind")
      if (k == "Texture" or k == "Line") and texturaSeVe(c) then return true end
      if k == "FontString" and tostring(rawget(c, "_text") or "") ~= "" then return true end
      if k ~= "Texture" and k ~= "FontString" and k ~= "Line" and seVe(c, prof + 1) then return true end
    end
  end
  return false
end
RATON_SE_VE = seVe

-- Una zona de clic transparente dentro de un panel que sí se ve (la cabecera
-- del rastreador) no tapa nada nuevo: el panel ya está ahí.
local function dentroDeAlgoVisible(f)
  local l, b, w, h = f:GetRect()
  local x = rawget(f, "_parent")
  for _ = 1, 8 do
    if not x or x == UIParent then return false end
    local n = x.GetName and x:GetName()
    if n == "AlfaUIParent" then return false end
    if x:IsVisible() and alfaEfectiva(x) > 0.05 and seVe(x) then
      local pl, pb, pw, ph = x:GetRect()
      if l >= pl - 1 and b >= pb - 1 and l + w <= pl + pw + 1 and b + h <= pb + ph + 1 then return true end
    end
    x = rawget(x, "_parent")
  end
  return false
end

local function tomaClic(f)
  if not rawget(f, "_mouse") then return false end
  local c = rawget(f, "_clic")
  return c == nil or c == true
end
local function tomaRueda(f) return rawget(f, "_rueda") == true end
-- El paso del ratón: sin él no sale el nombre de lo que está debajo (las
-- pestañas de profesiones de Toxic) ni el del enemigo al que apuntas.
local function tomaPaso(f)
  if not rawget(f, "_mouse") then return false end
  local m = rawget(f, "_movim")
  return m == nil or m == true
end
local function toma(f, que)
  if que == "rueda" then return tomaRueda(f) end
  if que == "paso" then return tomaPaso(f) end
  return tomaClic(f)
end

local function esMarco(f)
  local k = rawget(f, "_kind")
  return k ~= "Texture" and k ~= "FontString" and k ~= "Line" and k ~= "MaskTexture"
end

function RATON_ARRIBA(x, y, que)
  local mejor, me, ml
  for _, f in ipairs(ALL_FRAMES()) do
    if esMarco(f) and f:IsVisible() and toma(f, que) then
      local l, b, w, h = f:GetRect()
      if w > 0 and h > 0 and x >= l and x <= l + w and y >= b and y <= b + h then
        local e, lv = estrato(f), f:GetFrameLevel()
        if not mejor or e > me or (e == me and lv >= ml) then mejor, me, ml = f, e, lv end
      end
    end
  end
  return mejor
end

-- Las paredes invisibles de Alfa que hay ahora (clic o rueda).
local function paredes(permitidos)
  local out = {}
  for _, f in ipairs(ALL_FRAMES()) do
    if esMarco(f) and f:IsVisible() and RATON_DE_ALFA(f) and (tomaClic(f) or tomaRueda(f) or tomaPaso(f)) then
      local w, h = f:GetWidth(), f:GetHeight()
      local n = nombreDe(f)
      local ok = permitidos and permitidos(f, n)
      if not ok and w > 0 and h > 0 then
        local a = alfaEfectiva(f)
        local que = tomaClic(f) and "clic" or (tomaRueda(f) and "rueda" or "paso del ratón")
        -- (una × que se asoma al pasar el ratón, dentro de un anuncio que se ve, no estorba)
        if a < 0.05 and not dentroDeAlgoVisible(f) then
          out[#out + 1] = ("%s toma el %s con alfa %.2f (%dx%d)"):format(n, que, a, w, h)
        elseif not seVe(f) and not dentroDeAlgoVisible(f) then
          out[#out + 1] = ("%s toma el %s sin dibujar nada (%dx%d)"):format(n, que, w, h)
        end
      end
    end
  end
  return out
end
RATON_PAREDES = paredes

-- ¿Hay una ventana de Alfa abierta? (entonces es normal que tape el mundo)
local function ventanaAbierta()
  local o = Alfa and Alfa.UI and Alfa.UI.Options and Alfa.UI.Options.frame
  return o and o.IsVisible and o:IsVisible()
end

function RATON_BARRIDO(momento, permitidos)
  local out = {}
  for _, p in ipairs(paredes(permitidos)) do out[#out + 1] = momento .. ": " .. p end
  -- La franja del mundo (de 15 % a 85 % de alto, todo el ancho): sin ventana
  -- de Alfa abierta, ningún punto cae bajo un marco de Alfa que no se ve.
  if not ventanaAbierta() then
    local W, H = UIParent:GetWidth(), UIParent:GetHeight()
    local vistos = {}
    for gy = 0.15, 0.851, 0.05 do
      for gx = 0.02, 0.981, 0.04 do
        for _, que in ipairs({ "clic", "rueda", "paso" }) do
          local f = RATON_ARRIBA(W * gx, H * gy, que)
          if f and RATON_DE_ALFA(f) and not vistos[f] then
            vistos[f] = true
            if alfaEfectiva(f) < 0.05 or not (seVe(f) or dentroDeAlgoVisible(f)) then
              if not (permitidos and permitidos(f, nombreDe(f))) then
                out[#out + 1] = ("%s: en (%d,%d) el %s va a %s, que no se ve"):format(momento, W * gx, H * gy, que, nombreDe(f))
              end
            end
          end
        end
      end
    end
  end
  return out
end

function RATON_RESUMEN()
  local t = {}
  for _, f in ipairs(ALL_FRAMES()) do
    if esMarco(f) and f:IsVisible() and RATON_DE_ALFA(f) and (tomaClic(f) or tomaRueda(f)) then
      local l, b, w, h = f:GetRect()
      t[#t + 1] = ("%s %dx%d en %d,%d%s"):format(nombreDe(f), w, h, l, b, tomaRueda(f) and " (rueda)" or "")
    end
  end
  return table.concat(t, "\n")
end

-- El tiempo pasa (1.4.1): el reloj del juego avanza y cada marco a la vista
-- con OnUpdate recibe sus cuadros (las animaciones de entrada y salida).
-- sinRelojes: solo el reloj del juego y los OnUpdate (RUN_TIMERS corre TODOS los
-- temporizadores al instante, también el que cierra un aviso a los 30 s).
function RATON_ADELANTAR(seg, paso, sinRelojes)
  paso = paso or 0.05
  local n = math.floor((seg or 1) / paso + 0.5)
  for _ = 1, n do
    NOW = (NOW or 0) + paso
    local lista = {}
    for _, f in ipairs(ALL_FRAMES()) do
      local s, h = rawget(f, "_scripts"), rawget(f, "_hooks")
      if ((s and s.OnUpdate) or (h and h.OnUpdate)) and f:IsVisible() then lista[#lista + 1] = f end
    end
    for _, f in ipairs(lista) do if f:IsVisible() then FIRE(f, "OnUpdate", paso) end end
  end
  if not sinRelojes then RUN_TIMERS(2) end
end

-- 1.4.1: un texto con bytes rotos (un «…» o un acento cortado a la mitad) en
-- el juego sale como cuadritos. Antes de dibujar las capturas, run.py llama
-- esto: cada texto roto sale como ERROR con su escena y se limpia.
local function utf8Valido(s)
  local i, n = 1, #s
  while i <= n do
    local c = s:byte(i)
    local largo = c < 0x80 and 1 or (c >= 0xC2 and c <= 0xDF and 2) or (c >= 0xE0 and c <= 0xEF and 3) or (c >= 0xF0 and c <= 0xF4 and 4) or nil
    if not largo or i + largo - 1 > n then return false end
    for j = i + 1, i + largo - 1 do
      local d = s:byte(j)
      if d < 0x80 or d > 0xBF then return false end
    end
    i = i + largo
  end
  return true
end
UTF8_VALIDO = utf8Valido
function SNAP_UTF8()
  local rotos = 0
  for nombre, snap in pairs(rawget(_G, "SNAPSHOTS") or {}) do
    for _, e in pairs(snap.entries or {}) do
      for k, v in pairs(e) do
        if type(v) == "string" and not utf8Valido(v) then
          rotos = rotos + 1
          local muestra = v:gsub("[\128-\255]", function(c) return ("<%d>"):format(c:byte()) end)
          print(("ERROR texto con bytes rotos en %s (%s): %s"):format(tostring(nombre), tostring(k), muestra:sub(1, 160)))
          e[k] = v:gsub("[\128-\255]", "?")
        end
      end
    end
  end
  return rotos
end
