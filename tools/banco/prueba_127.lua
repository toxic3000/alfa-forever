-- Prueba de la 1.2.7, lo de la bienvenida y la Enciclopedia (las de Lya, las
-- misiones y la manada están en prueba_127_lya, _rutas y _manada):
--   * los perfiles: guardar, usar, exportar como texto e importar (sin
--     ejecutar nada de lo pegado);
--   * /alfa rendimiento no falla;
--   * el recorrido avanza sus 5 pasos y se da por visto;
--   * la ficha de una zona trae lo que cuenta Lya.
SNAPSHOTS = {}
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
local function check(cond, msg) if not cond then NOTE("1.2.7", msg) end end

local A = AlfaNucleo.A
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(3)

local B = NS_OF("Alfa_Bienvenida")

step("Perfiles: guardar, usar, exportar e importar", function()
  local Pf = B.Perfiles
  check(Pf and Pf.Guardar and Pf.Exportar and Pf.Importar, "falta Perfiles.lua")
  A.Set("qol.sellJunk", false)
  A.Set("lya.letra", "enorme")
  check(Pf.Guardar("Mi prueba"), "no guardó el perfil")
  A.Set("qol.sellJunk", true)
  A.Set("lya.letra", "normal")
  check(Pf.Aplicar("Mi prueba"), "no usó el perfil")
  check(A.Get("qol.sellJunk") == false and A.Get("lya.letra") == "enorme", "el perfil no devolvió los ajustes guardados")
  local texto = Pf.Exportar()
  check(texto:find("^Alfa:perfil:1"), "el texto exportado no empieza con su cabecera")
  check(texto:find("lya.letra=s:enorme", 1, true), "el texto no trae los ajustes")
  A.Set("lya.letra", "grande")
  local ok, n = Pf.Importar(texto)
  check(ok and n > 0 and A.Get("lya.letra") == "enorme", "importar no devolvió los ajustes")
  local lista = Pf.Lista()
  local hay = false
  for _, x in ipairs(lista) do if x == "Antes de importar" then hay = true end end
  check(hay, "importar no guardó lo de antes como perfil")
  -- Basura o código: no se acepta ni se ejecuta.
  rawset(_G, "HACKEADO", nil)
  check(not Pf.Leer("print('hola')"), "aceptó un texto que no es perfil")
  check(not Pf.Leer("Alfa:perfil:1\nqol.x=s:1\n_G.HACKEADO=true"), "aceptó una línea que no es ajuste")
  check(rawget(_G, "HACKEADO") == nil, "algo del texto se ejecutó")
  Pf.Borrar("Mi prueba")
  A.Set("lya.letra", "grande")
end)

step("Rendimiento no falla", function()
  local Pf = B.Perfiles
  local ok, e = pcall(Pf.Rendimiento)
  check(ok, "/alfa rendimiento falló: " .. tostring(e))
end)

step("El recorrido: sus pasos y se da por visto", function()
  local Rc = B.Recorrido
  check(Rc and Rc.Empezar, "falta Recorrido.lua")
  local avisos = {}
  local K = AlfaNucleo.Kit
  local av = K.Aviso
  K.Aviso = function(o) avisos[#avisos + 1] = o return {} end
  AlfaNucleo.Datos("bienvenida").recorrido = nil
  Rc.Empezar()
  -- 1.3.6: el recorrido tiene 6 o 7 pasos (el lobo del minimapa, «¿Qué es esto?»).
  for _ = 1, 10 do

    local a = avisos[#avisos]
    if a and a.accion then a.accion.alClic() end
    if AlfaNucleo.Datos("bienvenida").recorrido == true then break end
  end
  K.Aviso = av
  check(#avisos >= 5, "el recorrido no mostró sus pasos (" .. #avisos .. ")")
  check(AlfaNucleo.Datos("bienvenida").recorrido == true, "el recorrido no quedó como visto")
end)

step("La ficha de una zona trae lo que cuenta Lya", function()
  local E = NS_OF("Alfa_Enciclopedia")
  local Lya = AlfaLya
  check(type(Lya) == "table", "no está AlfaLya")
  if type(Lya) ~= "table" then return end
  local dz = Lya.DatoDeZona
  Lya.DatoDeZona = function(id) return "Aquí aullaban los lobos de antes." end
  local f = E.F and E.F.Zona and E.F.Zona(1429)
  Lya.DatoDeZona = dz
  if f then check(f.mejor and f.mejor.texto == "Aquí aullaban los lobos de antes.", "la ficha de la zona no trae lo que cuenta Lya") end
end)

step("El anuncio animado: barco y raro", function()
  local ns = NS_OF("Alfa")
  A.Set("bienvenida.anuncios", true)
  ns.Nav.alerts.ShowSample()
  local f = _G.AlfaAnuncio
  check(f and f:IsShown(), "el aviso del barco no salió como anuncio")
  local function tiene(t) for _, h in ipairs(rawget(f, "_children") or {}) do end
    for _, k in ipairs({ "Sobre", "Titulo", "Texto", "Pista" }) do if f[k] and f[k]._text and f[k]._text:find(t, 1, true) then return true end end
    return false end
  check(tiene("LA MANADA VIAJA") or tiene("La manada viaja"), "el anuncio no dice «La manada viaja»")
  check(tiene("El barco a"), "el anuncio no dice a dónde va el barco")
  for _ = 1, 400 do FIRE(f, "OnUpdate", 0.05) end
  check(not f:IsShown(), "el anuncio no se fue solo")
  local fueA
  ns.Rares.Toast.Show({ kind = "rare", id = 61, name = "Thuros", level = 29, zone = "Bosque de Elwynn", map = 1429, x = 50, y = 50, yards = 85 })
  check(f:IsShown() and tiene("Thuros") and (tiene("LYA OLFATE") or tiene("Lya olfateó")), "el raro no salió como anuncio")
  check(tiene("Clic: ir de caza"), "el anuncio del raro no dice cómo ir de caza")
  FIRE(f.Toque, "OnClick", "LeftButton")
  local t = ns.Nav.GetTarget and ns.Nav.GetTarget()
  check(t and t.label == "Thuros", "el clic en el anuncio no puso la flecha en el raro")
  check(not (_G.AlfaRareToast and _G.AlfaRareToast:IsShown()), "además salió la tarjeta del raro")
  if ns.Nav.ReleaseTarget then ns.Nav.ReleaseTarget() end
end)

step("El menú de Lya: arriba de ella, ancho y sin textos cortados", function()
  local Ly = NS_OF("Alfa_Lya")
  local pend = AlfaBienvenida.Pendiente AlfaBienvenida.Pendiente = function() return false end A.Set("lya.mostrar", true) if Ly.Cerebro and Ly.Cerebro.Mostrar then Ly.Cerebro.Mostrar(true) end Ly.UI.Aplicar()
  RUN_TIMERS(3)
  local lya = _G.AlfaLyaLoba
  check(lya, "no está Lya") if not lya then return end
  lya:ClearAllPoints()
  lya:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -40, 20)
  FIRE(lya, "OnClick", "RightButton")
  local m = _G.AlfaKitMenu
  check(m and m:IsShown(), "el clic derecho no abrió el menú de Lya")
  if not (m and m:IsShown()) then return end
  local p, rel, rp = m:GetPoint(1)
  check(p == "BOTTOMLEFT" and rp == "TOPLEFT", "el menú de Lya no se abrió arriba de ella (" .. tostring(p) .. ")")
  local cortados = {}
  local function revisar(fr)
    for _, h in ipairs({ fr:GetRegions() }) do
      if h.IsTruncated and h:IsShown() and h:IsTruncated() then cortados[#cortados + 1] = tostring(h:GetText()) end
    end
    for _, c in ipairs({ fr:GetChildren() }) do revisar(c) end
  end
  revisar(m)
  check(#cortados == 0, "textos cortados en el menú de Lya: " .. table.concat(cortados, ", "))
  FIRE(lya, "OnClick", "RightButton")
  check(not m:IsShown(), "el segundo clic derecho no cerró el menú")
  AlfaBienvenida.Pendiente = pend
end)

print(string.format("PRUEBA: 1.2.7 perfiles, recorrido y Enciclopedia, %d pasos, %d errores", pasos, #ERRORS))
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
