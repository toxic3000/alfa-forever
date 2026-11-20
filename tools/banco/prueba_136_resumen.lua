-- Prueba de la 1.3.6: el resumen de la pelea («Tu pelea») no tapa las barras de
-- acción y se deja mover (reporte de Toxic: salía debajo de las barras de la
-- derecha y no se podía arrastrar).
local pasos = 0
local function step(nombre, fn)
  pasos = pasos + 1
  local antes = #ERRORS
  local ok, e = xpcall(fn, debug.traceback)
  if not ok then NOTE("paso " .. nombre, e) end
  if #ERRORS > antes then
    print("FALLA EN: " .. nombre)
    for i = antes + 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
  end
end
local function falla(msg) NOTE("resumen 1.3.6", msg) end

FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(10)
print("errores al entrar:", #ERRORS)

local M = NS_OF("Alfa_Combate")
local Rs = M.Resumen
local N = AlfaNucleo

-- Dos barras verticales a la derecha, como las de la captura.
local function barra(nombre, x)
  -- (En el banco, un nombre del juego que alguien ya consultó es un comodín:
  -- aquí se pone un marco de verdad.)
  local b = rawget(_G, nombre)
  if type(b) ~= "table" or tostring(b) == "comodin" or not b._scripts then
    rawset(_G, nombre, nil)
    b = CreateFrame("Frame", nombre, UIParent)
  end
  b:ClearAllPoints()
  b:SetPoint("RIGHT", UIParent, "RIGHT", x, 0)
  b:SetSize(40, 480)
  b:Show()
  return b
end
local der = barra("MultiBarRight", -4)
local izq = barra("MultiBarLeft", -48)

local function rect(fr)
  local l, b, w, h = fr:GetRect()
  return l, b, l + w, b + h
end
local function seTapan(a, b)
  local a1, a2, a3, a4 = rect(a)
  local b1, b2, b3, b4 = rect(b)
  return a1 < b3 and a3 > b1 and a2 < b4 and a4 > b2
end
local MUESTRA = { dur = 42, dano = 1652, dps = 37.5, golpe = { nombre = "Atacar", cuanto = 787 } }

step("de fábrica no tapa las barras de la derecha", function()
  N.Datos("combate").pos = nil
  Rs.Pintar(MUESTRA)
  local f = rawget(_G, "AlfaCombateResumen")
  if not (f and f:IsShown()) then falla("no salió el resumen") return end
  if seTapan(f, der) or seTapan(f, izq) then falla("el resumen tapa las barras de la derecha") end
  if not f:IsMouseEnabled() then falla("el resumen no se deja tomar con el ratón") end
end)

step("se arrastra directo y la siguiente pelea respeta dónde lo dejaste", function()
  local f = rawget(_G, "AlfaCombateResumen")
  if not f then return end
  local ini = f:GetScript("OnDragStart")
  if ini then ini(f) end
  f:ClearAllPoints()
  f:SetPoint("CENTER", UIParent, "CENTER", -300, 100)
  local fin = f:GetScript("OnDragStop")
  if fin then fin(f) end
  local p = M.Posicion and M.Posicion("Resumen")
  if type(p) ~= "table" then falla("al soltarlo no se guardó su lugar") return end
  f:Hide()
  Rs.Pintar(MUESTRA)
  local a, _, b, x, y = f:GetPoint(1)
  if a ~= "CENTER" or math.abs((x or 0) + 300) > 1 then falla("la siguiente pelea no respetó dónde lo dejaste (" .. tostring(a) .. " " .. tostring(x) .. ")") end
end)

step("sin barras a la vista, sale donde siempre", function()
  N.Datos("combate").pos = nil
  der:Hide() izq:Hide()
  for _, n in ipairs({ "MainActionBar", "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBar5", "MultiBar6", "MultiBar7" }) do
    local b = rawget(_G, n)
    if type(b) == "table" and b.Hide then b:Hide() end
  end
  local f = rawget(_G, "AlfaCombateResumen")
  f:Hide()
  f:ClearAllPoints()
  f:SetPoint("RIGHT", UIParent, "RIGHT", -60, 150)
  Rs.Pintar(MUESTRA)
  local a, _, _, x = f:GetPoint(1)
  if a ~= "RIGHT" or x ~= -60 then falla("sin barras se movió de su lugar de siempre") end
end)

print(("PRUEBA: resumen 1.3.6, %d pasos, errores: %d"):format(pasos, #ERRORS))
