-- Prueba del mapa impecable de la 1.1.7 (tools/prueba.py la corre con las
-- demás prueba_*.lua). Lo que el banco puede medir con números:
--   * la esquina del mapa cae en un píxel entero en cada cuadro (zoom y arrastre);
--   * los pines, su nombre, tu grupo y tu flecha también, y sus lados son pares;
--   * los recortes de las texturas dejan medio texel antes de la orilla;
--   * dos zonas que se tocan nunca comparten nivel de marco;
--   * los pines y los botones del mapa quedan encima de todas las capas.
-- Lo que no puede ver (filtrado, mipmaps, mezcla de alfa) se revisa en el juego.
SNAPSHOTS = {}
BANCO_LETRA = 0.64
local pasos = 0
local function step(nombre, fn, ...)
  pasos = pasos + 1
  local antes = #ERRORS
  local ok, e = xpcall(fn, debug.traceback, ...)
  if not ok then NOTE("paso " .. nombre, e) end
  if #ERRORS > antes then
    print("FALLA EN: " .. nombre)
    for i = antes + 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
  end
end
local function T(n) RUN_TIMERS(n or 2) end

Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(10)
local A = Alfa
print("errores al entrar:", #ERRORS)
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 400)) end
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end

local Mu = NS_OF("Alfa_Mundo")
local Lz, Mc, V = Mu.Lienzo, Mu.Marcas, Mu.Ventana
A.RunCommand("mapa")
T(3)
local F = _G.AlfaMundoMapa
local vista = F and F.Vista
local function cuadros(n)
  for _ = 1, n do FIRE(vista, "OnUpdate", 0.03) end
end

local function entero(v, px, que)
  local d = v * px - math.floor(v * px + 0.5)
  if math.abs(d) > 1e-6 then error(que .. string.format(": %.4f no cae en un píxel entero", v)) end
end

-- La esquina del mapa en un píxel entero.
local function revisarEsquina(que)
  local a = Lz.Ahora()
  if not (a.ox and a.px) then error("Lz.Colocar no guardó la esquina del lienzo") end
  entero(a.ox, a.px, que .. " (x)")
  entero(a.oy, a.px, que .. " (y)")
end

-- Pines, nombres, grupo y flecha: su centro en un píxel entero, lados pares.
local function revisarPines(que)
  local px = Lz.Pixeles()
  local n = 0
  for _, hijo in ipairs({ vista:GetChildren() }) do
    for _, f in ipairs({ hijo:GetChildren() }) do
      if f:IsShown() and f:GetNumPoints() > 0 then
        local p, rel, rp, x, y = f:GetPoint(1)
        if p == "CENTER" and rp == "TOPLEFT" and type(x) == "number" then
          n = n + 1
          entero(x, px, que .. ": centro x de un pin")
          entero(y, px, que .. ": centro y de un pin")
          if rawget(f, "amPin") then
            local w, h = f:GetSize()
            if math.abs(w * px / 2 - math.floor(w * px / 2 + 0.5)) > 1e-6 or math.abs(h * px / 2 - math.floor(h * px / 2 + 0.5)) > 1e-6 then
              error(que .. string.format(": un pin mide %.3f x %.3f (lados impares o fraccionarios)", w, h))
            end
          end
        end
      end
    end
  end
  return n
end

step("Recorte: medio texel antes de la orilla", function()
  local function cerca(a, b) return math.abs(a - b) < 1e-9 end
  if not cerca(Lz.Recorte(256, 256), 1) then error("un mosaico completo no se lee entero") end
  if not cerca(Lz.Recorte(200, 256), 199.5 / 256) then error("el recorte no deja medio texel: " .. Lz.Recorte(200, 256)) end
  if not cerca(Lz.Recorte(300, 256), 1) then error("un recorte más grande que el archivo") end
end)

if vista then
  step("mapa: la esquina en un píxel entero al hacer zoom y arrastrar", function()
    for i = 1, 8 do V.Rueda(nil, 1) cuadros(3) revisarEsquina("zoom adentro " .. i) end
    for i = 1, 5 do V.Rueda(nil, -1) cuadros(3) revisarEsquina("zoom afuera " .. i) end
    CX, CY = 600, 400
    BOTON = "LeftButton"
    FIRE(vista, "OnMouseDown", "LeftButton")
    for i = 1, 20 do
      CX, CY = CX + 3.37, CY - 1.91 -- pasos que no son enteros
      cuadros(1)
      revisarEsquina("arrastre " .. i)
    end
    BOTON = nil
    FIRE(vista, "OnMouseUp", "LeftButton")
    cuadros(20)
    revisarEsquina("tras soltar")
  end)

  step("mapa: pines, nombres y tu flecha en píxeles enteros", function()
    local Nav = A.Nav
    if Nav and Nav.SetTarget then Nav.SetTarget(1429, 0.42, 0.37, "Prueba") end
    T(2)
    for i = 1, 6 do
      V.Rueda(nil, i % 2 == 0 and 1 or -1)
      cuadros(4)
      revisarPines("vuelta " .. i)
    end
    if Nav and Nav.ReleaseTarget then Nav.ReleaseTarget() end
  end)

  step("mapa: dos zonas que se tocan no comparten nivel", function()
    for _, lista in ipairs({ Lz.Zonas(), Lz.Ciudades() }) do
      for i = 1, #lista do
        local a = lista[i]
        if type(a.rango) ~= "number" then error("la zona " .. tostring(a.id) .. " no tiene nivel") end
        for j = i + 1, #lista do
          local b = lista[j]
          local tocan = a.l < b.l + b.w and b.l < a.l + a.w and a.t < b.t + b.h and b.t < a.t + a.h
          if tocan and a.rango == b.rango then
            error(string.format("las zonas %s y %s se tocan y comparten nivel %d", tostring(a.id), tostring(b.id), a.rango))
          end
        end
      end
    end
  end)

  step("mapa: pines y botones encima de todas las capas", function()
    local tope = vista:GetFrameLevel() + Lz.NIVELES
    local encima
    for _, hijo in ipairs({ vista:GetChildren() }) do
      if hijo ~= Lz and hijo:GetFrameLevel() > tope then encima = true end
    end
    if not encima then error("nada queda encima de las capas del mapa (pines y botones)") end
    if F.Mas and F.Mas:GetParent():GetFrameLevel() <= tope then error("los botones de zoom quedan debajo de las capas del mapa") end
  end)
end

print("PRUEBA: mapa 1.1.7, " .. pasos .. " pasos, " .. #ERRORS .. " errores")
