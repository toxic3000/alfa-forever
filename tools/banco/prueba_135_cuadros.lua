-- Prueba de la 1.3.5: nada corre en cada cuadro si no hace falta.
--
-- Abre y cierra lo que tiene animaciones o trabajo por cuadro (las bolsas, la
-- pesca, la ventana de Alfa y sus páginas, Lya, la intro) y después cuenta
-- los OnUpdate que siguen vivos: con todo cerrado y sin guía en marcha, la
-- lista debe quedar vacía (los de la flecha y la guía en pantalla, que se ven
-- mientras sigues una guía, se cuentan aparte).
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
local function falla(msg) NOTE("cuadros", msg) end

local reloj = 1000
GetTime = function() return reloj end
local vistos = {} -- los OnUpdate que llegaron a correr (para saber que la prueba prueba algo)
local function cuadros(n, dt)
  dt = dt or (1 / 60)
  for _ = 1, n do
    reloj = reloj + dt
    for _, f in ipairs(ALL_FRAMES()) do
      if f._scripts and f._scripts.OnUpdate and f:IsVisible() then
        vistos[(f._name or "?") .. " " .. PERFIL_CLAVE(f._scripts.OnUpdate)] = true
        FIRE(f, "OnUpdate", dt)
      end
    end
  end
  RUN_TIMERS(5)
end

FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(10)
print("errores al entrar:", #ERRORS)

local function nombre(f)
  local fn = f._scripts.OnUpdate
  local clave = PERFIL_CLAVE and PERFIL_CLAVE(fn) or tostring(fn)
  return (f._name or "?") .. " " .. clave
end

-- Lo que puede seguir vivo mientras la guía está en marcha (la flecha y la
-- ventana de la guía se ven a propósito).
local PERMITIDOS = { ["Arrow.lua"] = true, ["GuideFrame.lua"] = true }

local function vivos()
  local out = {}
  for _, f in ipairs(ALL_FRAMES()) do
    if f._scripts and f._scripts.OnUpdate and f:IsVisible() then
      local n = nombre(f)
      local archivo = n:match("([%w_]+%.lua)")
      if not PERMITIDOS[archivo] then out[#out + 1] = n end
    end
  end
  table.sort(out)
  return out
end

step("la intro termina y se apaga", function()
  cuadros(60 * 15, 1 / 30) -- 15 segundos
end)

step("abrir y cerrar lo que anima", function()
  local B = rawget(_G, "AlfaBolsas")
  if B and B.Abrir then B.Abrir(); cuadros(30) end
  local Bv = rawget(_G, "AlfaBolsasFrame") or (B and B.Ventana)
  if B and B.Cerrar then B.Cerrar() end
  for _, f in ipairs(ALL_FRAMES()) do
    -- Toda ventana de Alfa abierta se cierra, como al pulsar Esc.
    if f._name and f._name:find("^Alfa") and f:IsShown() and f._name ~= "AlfaMinimapButton" then
      local p = f.GetParent and f:GetParent()
      if p == UIParent or p == nil then f:Hide() end
    end
  end
  local P = rawget(_G, "AlfaPesca")
  if P and P.Abrir then P.Abrir(); cuadros(30) end
  if P and P.Cerrar then P.Cerrar() end
  local N = AlfaNucleo
  if N and N.Abrir then N.Abrir("inicio"); cuadros(30) end
  for _, f in ipairs(ALL_FRAMES()) do
    if f._name and f._name:find("^Alfa") and f:IsShown() and f._name ~= "AlfaMinimapButton" then
      local p = f.GetParent and f:GetParent()
      if p == UIParent or p == nil then f:Hide() end
    end
  end
  cuadros(60 * 10, 1 / 30)
end)

step("con todo cerrado, nada corre en cada cuadro", function()
  local n = 0
  for _ in pairs(vistos) do n = n + 1 end
  print(("  OnUpdate que corrieron mientras había algo abierto: %d"):format(n))
  if n < 2 then falla("casi nada se animó: la prueba no abrió lo que debía") end
  local l = vivos()
  print(("  OnUpdate vivos con todo cerrado: %d"):format(#l))
  for i = 1, #l do print("    " .. l[i]) end
  if #l > 0 then falla(("%d OnUpdate siguen vivos con todo cerrado: %s"):format(#l, table.concat(l, "; "):sub(1, 400))) end
end)

print(("PRUEBA: cuadros, %d pasos, errores: %d"):format(pasos, #ERRORS))
