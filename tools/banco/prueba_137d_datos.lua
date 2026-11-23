-- Prueba de la 1.3.7 (revisión d): los datos guardados con el reino vacío
-- (Forever da GetRealmName() vacío desde el 20/11/2026) no se mezclan ni se
-- pierden (tools/prueba.py la corre con las demás):
--   1. dos «Toxic» en dos reinos: no se supone ninguno, nada se mezcla ni se borra;
--   2. juntar «Toxic-» con «Toxic-Reino»: el banco de hace días sobrevive (y su
--      sello viene del mismo lado); con otra clase no se junta;
--   3. un personaje de otro reino entra con el reino vacío: no recibe el reino
--      de la cuenta (el último visto, de otro personaje);
--   4. una sola coincidencia (nombre, clase y facción): se supone, pero no se
--      guarda como certeza ni se junta nada;
--   5. recetas de dos personajes: cada uno conserva las suyas (se juntan por
--      receta, solo las del que entra, y solo con el reino seguro);
--   6. el nombre del pin al guardarlo como marcador (con la distancia en su cuadro);
--   7. Ctrl+1 con la barra de la mascota asignada: Alfa no se lo come.
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
local function check(cond, msg) if not cond then NOTE("1.3.7d datos", msg) end end

Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
local N, B = AlfaNucleo, AlfaBienvenida
local Mb = NS_OF("Alfa_Bienvenida")
N.Datos("bienvenida").respondio = B and B.VERSION or 99
N.Datos("bienvenida").versionVista = B and B.VersionAlfa and B.VersionAlfa() or "9.9.9"
N.Datos("bienvenida").recorrido = true
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(10)
if AlfaBienvenida then AlfaBienvenida.Pendiente = function() return false end end
local A = Alfa

local Bo = NS_OF("Alfa_Bolsas")
local D = Bo and Bo.Datos
local Co = NS_OF("Alfa_Comercio")
local Mu = NS_OF("Alfa_Mundo")

-- Entrar como otro personaje con el reino vacío (o con uno dado).
local orig = { GetRealmName = GetRealmName, GetNormalizedRealmName = GetNormalizedRealmName,
  UnitName = UnitName, UnitClass = UnitClass, UnitLevel = UnitLevel }
local function ser(nombre, reino, clase, nivel)
  GetRealmName = function() return reino or "" end
  GetNormalizedRealmName = function() return reino and reino:gsub("[%s%-]", "") or nil end
  UnitName = function(u) if u == "player" then return nombre, nil end return nil end
  UnitClass = function() return clase or "Guerrero", clase or "WARRIOR", 1 end
  UnitLevel = function() return nivel or 23 end
  if type(AlfaNucleoCharDB) == "table" then AlfaNucleoCharDB.reino = nil end
  N.ReinoOlvidar()
end
local function entrar()
  FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
  RUN_TIMERS(5)
end
local function volver()
  for k, v in pairs(orig) do _G[k] = v end
  if type(AlfaNucleoCharDB) == "table" then AlfaNucleoCharDB.reino = nil end
  N.ReinoOlvidar()
end
local function registro(t)
  local r = { nombre = "Toxic", clase = "WARRIOR", faccion = "Horde", nivel = 20, visto = 100,
    bolsas = { [0] = { n = 16, [1] = { i = 4540, c = 1 } } }, equipo = { [1] = { i = 7 } } }
  for k, v in pairs(t) do r[k] = v end
  return r
end

check(type(N.ReinoOlvidar) == "function" and D and D.JuntarSinReino and Co and Co.JuntarReinoSinNombre,
  "faltan N.ReinoOlvidar, D.JuntarSinReino o Co.JuntarReinoSinNombre")

---------------------------------------------------------------------------
step("1. dos «Toxic» en dos reinos no se mezclan", function()
  local lista = D.Raiz().personajes
  lista["Toxic-Uno"] = registro({ reino = "Uno", dinero = 111, banco = { [6] = { n = 28, [1] = { i = 2589, c = 20 } } }, bancoVisto = 90 })
  lista["Toxic-Dos"] = registro({ reino = "Dos", dinero = 222, banco = { [6] = { n = 28, [3] = { i = 2592, c = 5 } } }, bancoVisto = 95 })
  AlfaNucleoDB.reino = { nombre = "Uno", normal = "Uno" } -- el último que vio la cuenta
  ser("Toxic", nil)
  local reino, seguro = N.Reino()
  check(reino == nil and not seguro, "con dos «Toxic» supuso un reino: " .. tostring(reino))
  entrar()
  local uno, dos = lista["Toxic-Uno"], lista["Toxic-Dos"]
  check(uno and uno.dinero == 111 and uno.banco[6][1].i == 2589 and uno.reino == "Uno", "se tocó a Toxic de Uno")
  check(dos and dos.dinero == 222 and dos.banco[6][3].i == 2592 and dos.reino == "Dos", "se tocó a Toxic de Dos")
  check(D.Clave() == "Toxic-", "la clave sin reino seguro: " .. tostring(D.Clave()))
  local suelto = lista["Toxic-"]
  check(suelto and (suelto.reino == nil or suelto.reino == ""), "el registro sin reino recibió un reino: " .. tostring(suelto and suelto.reino))
  check(not (AlfaNucleoCharDB.reino and AlfaNucleoCharDB.reino.nombre), "se guardó un reino como certeza")
  lista["Toxic-Uno"], lista["Toxic-Dos"], lista["Toxic-"] = nil, nil, nil
  AlfaNucleoDB.reino = nil
  volver()
end)

---------------------------------------------------------------------------
step("2. juntar no pierde el banco", function()
  local lista = D.Raiz().personajes
  -- El viejo con su reino y el banco lleno; el nuevo «Toxic-» con las tablas
  -- vacías que crea D.Actual.
  lista["Toxic-Uno"] = registro({ reino = "Uno", dinero = 10, visto = 100,
    banco = { [6] = { n = 28, [1] = { i = 2589, c = 20 } }, [7] = { n = 10 } }, bancoVisto = 100,
    compra = { c = 2, m = 6, t = 100 } })
  lista["Toxic-"] = registro({ reino = "", dinero = 50, visto = 200, banco = {}, equipo = {},
    bolsas = { [0] = { n = 16, [1] = { i = 118, c = 3 } } } })
  D.JuntarSinReino("Toxic", "Toxic-Uno")
  local r = lista["Toxic-Uno"]
  check(lista["Toxic-"] == nil, "quedó el registro sin reino")
  check(r and r.banco and r.banco[6] and r.banco[6][1] and r.banco[6][1].i == 2589, "se perdió el banco al juntar")
  check(r and r.bancoVisto == 100, "el sello del banco no vino con su banco: " .. tostring(r and r.bancoVisto))
  check(r and r.compra and r.compra.c == 2, "se perdió la compra del banco")
  check(r and r.dinero == 50 and r.bolsas[0][1].i == 118, "no ganó lo más nuevo (dinero, bolsas)")
  check(r and r.equipo and r.equipo[1] and r.equipo[1].i == 7, "se perdió el equipo")
  check(r and r.reino == "Uno", "se perdió el reino: " .. tostring(r and r.reino))

  -- Al revés: el sin reino es el viejo con el banco; el bueno, nuevo y vacío.
  lista["Toxic-Uno"] = registro({ reino = "Uno", dinero = 70, visto = 300, banco = {}, equipo = {} })
  lista["Toxic-"] = registro({ reino = "", visto = 150, banco = { [6] = { n = 28, [2] = { i = 2840, c = 4 } } }, bancoVisto = 150 })
  D.JuntarSinReino("Toxic", "Toxic-Uno")
  r = lista["Toxic-Uno"]
  check(r and r.banco[6] and r.banco[6][2] and r.banco[6][2].i == 2840 and r.bancoVisto == 150, "el banco del viejo sin reino se perdió")
  check(r and r.dinero == 70, "no ganó el dinero más nuevo")

  -- Dos bancos: gana el visto más nuevo, con su sello.
  lista["Toxic-Uno"] = registro({ reino = "Uno", visto = 300, banco = { [6] = { n = 28, [1] = { i = 1 } } }, bancoVisto = 50 })
  lista["Toxic-"] = registro({ reino = "", visto = 150, banco = { [6] = { n = 28, [1] = { i = 2 } } }, bancoVisto = 140 })
  D.JuntarSinReino("Toxic", "Toxic-Uno")
  r = lista["Toxic-Uno"]
  check(r and r.banco[6][1].i == 2 and r.bancoVisto == 140, "no ganó el banco visto más reciente con su sello")

  -- Otra clase: no es el mismo personaje y no se junta.
  lista["Toxic-Uno"] = registro({ reino = "Uno", dinero = 1 })
  lista["Toxic-"] = registro({ reino = "", clase = "MAGE", dinero = 2, visto = 999 })
  D.JuntarSinReino("Toxic", "Toxic-Uno")
  check(lista["Toxic-"] and lista["Toxic-"].dinero == 2 and lista["Toxic-Uno"].dinero == 1, "juntó a un Toxic de otra clase")
  lista["Toxic-Uno"], lista["Toxic-"] = nil, nil
end)

---------------------------------------------------------------------------
step("3. un personaje de otro reino no recibe el reino de la cuenta", function()
  local lista = D.Raiz().personajes
  AlfaNucleoDB.reino = { nombre = "Uno", normal = "Uno" }
  ser("Pequeno", nil, "MAGE")
  check(N.Reino() == nil, "tomó el reino de la cuenta: " .. tostring(N.Reino()))
  entrar()
  local r = lista["Pequeno-"]
  check(lista["Pequeno-Uno"] == nil, "se guardó como si fuera de Uno")
  check(r and (r.reino == nil or r.reino == ""), "su registro dice el reino de otro: " .. tostring(r and r.reino))
  check(Co.ClavePersonaje() == "Pequeno-?", "Comercio le dio un reino ajeno: " .. tostring(Co.ClavePersonaje()))
  lista["Pequeno-"] = nil
  AlfaNucleoDB.reino = nil
  volver()
end)

---------------------------------------------------------------------------
step("4. una sola coincidencia se supone, sin certeza ni juntar", function()
  local lista = D.Raiz().personajes
  lista["Solo-Tres"] = registro({ nombre = "Solo", reino = "Tres", dinero = 5, nivel = 10 })
  lista["Solo-"] = registro({ nombre = "Solo", reino = "", dinero = 6, visto = 999 })
  ser("Solo", nil)
  local reino, seguro = N.Reino()
  check(reino == "Tres" and seguro == false, "la suposición: " .. tostring(reino) .. " " .. tostring(seguro))
  entrar()
  check(D.Clave() == "Solo-Tres", "la clave con el reino supuesto: " .. tostring(D.Clave()))
  check(lista["Solo-"] and lista["Solo-"].dinero == 6, "con un reino supuesto se juntó (o borró) el registro sin reino")
  check(not (AlfaNucleoCharDB.reino and AlfaNucleoCharDB.reino.nombre), "la suposición se guardó como certeza")
  check(Co.JuntarReinoSinNombre() == 0, "Comercio juntó con un reino supuesto")
  -- Con otra clase ya no es una coincidencia.
  ser("Solo", nil, "MAGE")
  check(N.Reino() == nil, "supuso el reino de un «Solo» de otra clase")
  -- Con más nivel que tú, tampoco.
  ser("Solo", nil, "WARRIOR", 5)
  check(N.Reino() == nil, "supuso el reino de un «Solo» con más nivel")
  -- La consulta no recorre todo cada vez: se busca una vez por sesión.
  ser("Solo", nil)
  N.Reino()
  lista["Solo-Cuatro"] = registro({ nombre = "Solo", reino = "Cuatro" })
  check(N.Reino() == "Tres", "la suposición se volvió a buscar en la misma sesión")
  -- En cuanto el juego da el reino, ese es seguro y se recuerda.
  ser("Solo", "Tres")
  local r2, s2 = N.Reino()
  check(r2 == "Tres" and s2 == true and AlfaNucleoCharDB.reino and AlfaNucleoCharDB.reino.nombre == "Tres", "el reino del juego no quedó como seguro")
  GetRealmName = function() return "" end
  local r3, s3 = N.Reino()
  check(r3 == "Tres" and s3 == true, "el reino seguro no duró la sesión")
  lista["Solo-Tres"], lista["Solo-"], lista["Solo-Cuatro"] = nil, nil, nil
  volver()
end)

---------------------------------------------------------------------------
step("5. recetas de dos personajes: cada uno conserva las suyas", function()
  local d = Co.Datos()
  d.recetas = d.recetas or {}
  d.reinos["?-Alliance"] = { p = { [2589] = { 50, 9e9, 3, 1 } } }
  d.recetas["Toxic-?"] = { rk = "?-Horde", nombre = "Toxic", r = { [101] = { p = "Alquimia" }, [102] = { p = "Alquimia" } }, profs = { Alquimia = 100 } }
  d.recetas["Toxic-Forever"] = { rk = "Forever-Horde", nombre = "Toxic",
    r = { [201] = { p = "Herreria" }, [202] = { p = "Herreria" }, [203] = { p = "Alquimia" } }, profs = { Alquimia = 150, Herreria = 60 } }
  d.recetas["Otra-?"] = { rk = "?-Horde", nombre = "Otra", r = { [301] = { p = "Sastreria" } }, profs = {} }
  ser("Toxic", "Forever")
  Co.JuntarReinoSinNombre()
  local f = d.recetas["Toxic-Forever"]
  local n = 0
  for _ in pairs(f and f.r or {}) do n = n + 1 end
  check(n == 5, "las recetas no se juntaron una por una: " .. n)
  check(f and f.profs.Alquimia == 150 and f.profs.Herreria == 60, "se perdió el nivel de un oficio")
  check(f and f.rk == "Forever-Horde", "la ficha no quedó en su reino: " .. tostring(f and f.rk))
  check(d.recetas["Toxic-?"] == nil, "quedó la ficha de «Toxic-?»")
  check(d.recetas["Otra-?"] and d.recetas["Otra-?"].r[301], "se mudaron las recetas de otro personaje")
  check(d.recetas["Otra-Forever"] == nil, "las recetas de otro personaje fueron a tu reino")
  check(d.reinos["?-Alliance"] ~= nil and d.reinos["Forever-Alliance"] == nil, "se juntaron precios de la otra facción")
  d.recetas["Toxic-Forever"], d.recetas["Otra-?"], d.reinos["?-Alliance"], d.reinos["Forever-Alliance"] = nil, nil, nil, nil
  volver()
end)

---------------------------------------------------------------------------
step("6. el nombre del pin al guardarlo como marcador", function()
  local DP, Mk = Mu and Mu.DistanciaPines, Mu and Mu.Marcadores
  check(DP and DP.Envolver and Mk and Mk.NombreDePin, "faltan DistanciaPines.Envolver o Marcadores.NombreDePin")
  if not (DP and DP.Envolver and Mk and Mk.NombreDePin) then return end
  local p = { tooltip = "|cffffd100Herrera Ana|r\nVende armas", c = 0, wx = 1, wy = 1 }
  DP.Envolver(p)
  check(type(p.tooltip) == "function", "el cuadro del pin no se envolvió")
  check(Mk.NombreDePin(p) == "Herrera Ana", "el pin perdió su nombre: " .. tostring(Mk.NombreDePin(p)))
  -- Una función desde antes: no hay texto que inventar.
  local q = { tooltip = function(tt) tt:SetText("x") end }
  DP.Envolver(q)
  check(q.alfaTipTexto == nil, "se inventó un texto de un cuadro que era función")
end)

---------------------------------------------------------------------------
step("7. Ctrl+1 con la barra de la mascota no se lo come Alfa", function()
  local Vt = Mb.Ventana
  local O = A.UI.Options
  A.Fire("SHOW_OPTIONS", "inicio")
  RUN_TIMERS(3)
  local ctrl = false
  local ick, iak, gba = IsControlKeyDown, IsAltKeyDown, rawget(_G, "GetBindingAction")
  IsControlKeyDown = function() return ctrl end
  IsAltKeyDown = function() return false end
  GetBindingAction = function(k) if k == "CTRL-1" then return "BONUSACTIONBUTTON1" end return "" end
  ctrl = true
  check(Vt.Tecla("1") == false, "Ctrl+1 se lo comió Alfa con la mascota asignada")
  check(Vt.Tecla("2") == true, "Ctrl+2 (libre) no fue de Alfa")
  ctrl = false
  O.RefreshNav()
  for _, b in ipairs(O.frame.sectionButtons or {}) do
    if b:IsShown() and b.psKey == "hoy" then
      check(b.psTipLines == nil, "el botón de Hoy dice «Ctrl+1» aunque es de la mascota")
    end
  end
  IsControlKeyDown, IsAltKeyDown, GetBindingAction = ick, iak, gba
  if O.frame then O.frame:Hide() end
end)

print(("1.3.7d datos: %d pasos, %d errores"):format(pasos, #ERRORS))
