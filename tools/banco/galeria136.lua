-- Escenas de la 1.3.6 para la galería de CurseForge (tools/galeria.py):
-- el buscador que encuentra páginas, Combate, el resumen de la pelea junto a
-- las barras de acción, y «Pregúntale a Lya».
SNAPSHOTS = {}
local function SNAP(name, root, extra)
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS[name] = { entries = entries, l = l, b = b, w = w, h = h }
end
local function step(name, fn, ...)
  local ok, e = xpcall(fn, debug.traceback, ...)
  if not ok then NOTE("step " .. name, e) end
end
BANCO_LETRA = 0.64
Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
local N, B = AlfaNucleo, AlfaBienvenida
N.Datos("bienvenida").respondio = B and B.VERSION or 99
N.Datos("bienvenida").versionVista = B and B.VersionAlfa and B.VersionAlfa() or "9.9.9"
N.Datos("bienvenida").recorrido = true -- ya visto: que no tape las vistas
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(10)
if AlfaBienvenida then AlfaBienvenida.Pendiente = function() return false end end
local A = Alfa
local O = A.UI.Options
local before = #ERRORS

-- El buscador: «pesca» trae la página y sus ajustes.
step("buscador", function()
  A.Fire("SHOW_OPTIONS", "inicio")
  RUN_TIMERS(2)
  O.frame.Search:SetText("pesca")
  O.SetQuery("pesca")
  RUN_TIMERS(3)
end)
if O.frame then SNAP("136-buscador", O.frame) end
step("limpiar", function() O.SetQuery("") O.frame.Search:SetText("") end)

-- Combate
step("combate", function() A.Fire("SHOW_OPTIONS", "combate") end)
RUN_TIMERS(3)
if O.frame then SNAP("136-combate", O.frame) end
step("cerrar", function() O.frame:Hide() end)

-- El resumen de la pelea, al lado de las barras de la derecha (no encima).
step("resumen", function()
  local M = NS_OF("Alfa_Combate")
  local function barra(nombre, x)
    local b = rawget(_G, nombre)
    if type(b) ~= "table" or tostring(b) == "comodin" or not b._scripts then
      rawset(_G, nombre, nil)
      b = CreateFrame("Frame", nombre, UIParent)
    end
    b:ClearAllPoints()
    b:SetPoint("RIGHT", UIParent, "RIGHT", x, 0)
    b:SetSize(40, 480)
    -- Doce botones, como una barra de acción vertical.
    for i = 1, 12 do
      local t = b:CreateTexture(nil, "ARTWORK")
      t:SetSize(36, 36)
      t:SetPoint("TOP", b, "TOP", 0, -2 - (i - 1) * 40)
      t:SetColorTexture(0.16 + 0.02 * (i % 3), 0.18, 0.2, 0.95)
      local o = b:CreateTexture(nil, "OVERLAY")
      o:SetSize(36, 2)
      o:SetPoint("BOTTOM", t, "BOTTOM", 0, 0)
      o:SetColorTexture(0.35, 0.3, 0.2, 1)
    end
    b:Show()
  end
  barra("MultiBarRight", -4)
  barra("MultiBarLeft", -48)
  N.Datos("combate").pos = nil
  M.Resumen.Pintar({ dur = 42, dano = 1652, dps = 37.5, golpe = { nombre = "Atacar", quien = "Lobo del bosque", cuanto = 787 } })
end)
-- (Sin RUN_TIMERS aquí: el banco correría ya la espera que lo esconde.)
local res = rawget(_G, "AlfaCombateResumen")
if res then
  -- El encuadre: la parte derecha de la pantalla, con el cuadro y las barras.
  local marco = CreateFrame("Frame", nil, UIParent)
  marco:SetPoint("RIGHT", UIParent, "RIGHT", 0, 120)
  marco:SetSize(720, 600)
  marco.Fondo = marco:CreateTexture(nil, "BACKGROUND")
  marco.Fondo:SetAllPoints(marco)
  marco.Fondo:SetColorTexture(0.2, 0.27, 0.18, 1)
  marco:Show()
  SNAP("136-resumen", marco, { res, rawget(_G, "MultiBarLeft"), rawget(_G, "MultiBarRight") })
  marco:Hide()
end
step("quitar resumen", function() if res then res:Hide() end end)

-- Pregúntale a Lya
step("lya", function() if AlfaLya and AlfaLya.Guia then AlfaLya.Guia() end end)
RUN_TIMERS(3)
local g = rawget(_G, "AlfaLyaGuia")
if g then SNAP("136-lya-guia", g) end

print("errores en galeria136:", #ERRORS - before)
for i = before + 1, math.min(#ERRORS, before + 8) do print(ERRORS[i]) end
