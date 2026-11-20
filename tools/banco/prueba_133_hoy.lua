-- Prueba de la 1.3.3, la entrada en silencio en Hoy, Bolsas y Comercio
-- (tools/prueba.py la corre con las demás prueba_*.lua):
--   1. mientras entras, los avisos de Hoy no salen: se guardan para la fila
--      «Mientras entrabas» (N.GuardarAlEntrar), que los pinta con su acción y
--      su «Listo» y se repinta con ALFA_ALENTRAR;
--   2. al entrar, lo de ahora es la base: el equipo gastado, las bolsas llenas,
--      la mazmorra y el grupo de antes no se avisan; solo lo que empeora
--      jugando. La sesión anterior, de fábrica sin chat;
--   3. una sola voz para las bolsas: el aviso de Bolsas (id «bolsasLlenas»);
--      Hoy no repite el suyo;
--   4. «Hazlo ya» cuenta solo tus bolsas, y lo del banco aparte;
--   5. el plan de una hora que vence deja su nota en Hoy;
--   6. conjuntos: «Otro nombre…» con caja de texto y el corte por letras.
-- El Núcleo de la entrada (N.Entrando, N.GuardarAlEntrar, N.AlEntrar,
-- N.OlvidarAlEntrar) se simula aquí, como dice su contrato.
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
local function check(cond, msg) if not cond then NOTE("1.3.3 hoy", msg) end end

local N = AlfaNucleo
local A = N.A
local K = N.Kit

local NADA = {}
local function con(t, campos, fn)
  local antes = {}
  for k, v in pairs(campos) do
    antes[k] = { v = rawget(t, k) }
    if v == NADA then rawset(t, k, nil) else rawset(t, k, v) end
  end
  local ok, e = pcall(fn)
  for k, a in pairs(antes) do rawset(t, k, a.v) end
  if not ok then error(e, 0) end
end

---------------------------------------------------------------------------
-- El Núcleo de la entrada, de mentira (el contrato de la 1.3.3)
---------------------------------------------------------------------------

local entrando = true
local guardados = {}
local olvidados = {}
local NucleoFalso = {
  Entrando = function() return entrando end,
  GuardarAlEntrar = function(o)
    for i, x in ipairs(guardados) do if x.id == o.id then table.remove(guardados, i) break end end
    guardados[#guardados + 1] = o
    A.Fire("ALFA_ALENTRAR")
  end,
  AlEntrar = function() return guardados end,
  OlvidarAlEntrar = function(id)
    olvidados[#olvidados + 1] = id
    for i, x in ipairs(guardados) do if x.id == id then table.remove(guardados, i) break end end
    A.Fire("ALFA_ALENTRAR")
  end,
}
for k, v in pairs(NucleoFalso) do rawset(N, k, v) end

---------------------------------------------------------------------------
-- El juego de mentira: tu equipo gastado, tus bolsas casi llenas y una mazmorra
---------------------------------------------------------------------------

local dur = { [5] = { 25, 100 } } -- el pecho al 25 %
GetInventoryItemDurability = function(slot) local d = dur[slot] if d then return d[1], d[2] end return nil end

local OBJ = { [2589] = { "Lino", "" }, [2996] = { "Rollo de lino", "" }, [4865] = { "Garra rota", "" },
  [9101] = { "Anillo del lobo", "INVTYPE_FINGER" } }
local function idDe(x) return tonumber(tostring(x):match("item:(%d+)") or x) end
local function enlace(id) return "|cff1eff00|Hitem:" .. id .. "::::::::|h[" .. ((OBJ[id] and OBJ[id][1]) or "?") .. "]|h|r" end
C_Item.GetItemInfo = function(x)
  local id = idDe(x)
  local o = OBJ[id]
  if not o then return nil end
  return o[1], enlace(id), 1, 20, 1, "Tipo", "Subtipo", 20, o[2], 134400, 10, 7, 5, 0
end
local TAM = { [0] = 16 }
local bolsas = { [0] = {} }
local function poner(s, id, n, calidad)
  bolsas[0][s] = { itemID = id, stackCount = n or 1, quality = calidad or 1, hyperlink = enlace(id), isBound = false }
end
for s = 1, 13 do poner(s, 2589, 1) end -- 3 casillas libres: casi llenas ya al entrar
local falso = {
  GetContainerNumSlots = function(b) return TAM[b] or 0 end,
  GetContainerNumFreeSlots = function(b)
    local t = bolsas[b]
    if not t then return 0, 0 end
    local n = 0
    for s = 1, TAM[b] do if not t[s] then n = n + 1 end end
    return n, 0
  end,
  CalculateTotalNumberOfFreeBagSlots = function() return 10 end,
  GetContainerItemInfo = function(b, s) return bolsas[b] and bolsas[b][s] end,
  GetContainerItemQuestInfo = function() return { isQuestItem = false } end,
  GetContainerItemLink = function(b, s) local i = bolsas[b] and bolsas[b][s] return i and i.hyperlink end,
  GetContainerItemID = function(b, s) local i = bolsas[b] and bolsas[b][s] return i and i.itemID end,
  ContainerIDToInventoryID = function(b) return b + 19 end,
  GetBagName = function() return nil end,
  GetContainerItemCooldown = function() return 0, 0, 0 end,
}
C_Container = C_Container or {}
for k, v in pairs(falso) do C_Container[k] = v end

local equipo = { [11] = { id = 9101, link = enlace(9101) } }
GetInventoryItemID = function(u, r) local e = equipo[r] return e and e.id end
GetInventoryItemLink = function(u, r) local e = equipo[r] return e and e.link end

-- Entras al juego dentro de una mazmorra, con tu grupo de 5.
local instancia = "party"
IsInInstance = function() return instancia ~= "none", instancia end
GetNumGroupMembers = function() return 5 end
IsInRaid = function() return false end
GetRealZoneText = function() return instancia == "party" and "Sima ígnea" or "Durotar" end

-- Lo que sale: los avisos de Hoy (M.Aviso.Mostrar) y los del Kit (K.Aviso).
local avisosHoy, avisosKit = {}, {}
local avisoReal = K.Aviso
K.Aviso = function(o) avisosKit[#avisosKit + 1] = o return {} end

if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
Alfa.Hidden = function() return false end

local I = NS_OF("Alfa_Inicio")
local mostrarReal = I.Aviso.Mostrar
I.Aviso.Mostrar = function(spec) avisosHoy[#avisosHoy + 1] = spec return mostrarReal(spec) end

-- Entras (fuera del «entrando» del Núcleo, para ver la base de cada módulo).
entrando = false
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("GROUP_ROSTER_UPDATE")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
FIRE_EVENT("BAG_UPDATE", 0)
FIRE_EVENT("BAG_UPDATE_DELAYED")
RUN_TIMERS(14)

local B = NS_OF("Alfa_Bolsas")
local C = NS_OF("Alfa_Comercio")
local R, Li, TM = I.Rec, I.Listo, I.Tiempo
local Cj = B.Conjuntos

local function claves(lista, campo)
  local t = {}
  for _, o in ipairs(lista) do t[#t + 1] = tostring(o[campo] or o.titulo) end
  return table.concat(t, ", ")
end

---------------------------------------------------------------------------
-- 2. La base al entrar
---------------------------------------------------------------------------

step("Al entrar: el equipo gastado, las bolsas, la mazmorra y el grupo de antes no se avisan", function()
  check(#avisosHoy == 0, "al entrar Hoy avisó: " .. claves(avisosHoy, "clave"))
  check(#avisosKit == 0, "al entrar salieron avisos: " .. claves(avisosKit, "titulo"))
  check(A.GetDefault("inicio.resumen") == "aviso", "de fábrica la sesión anterior sigue saliendo en el chat: " .. tostring(A.GetDefault("inicio.resumen")))
end)

step("Jugando: lo que empeora sí se avisa (el equipo, las bolsas, la mazmorra)", function()
  avisosHoy, avisosKit = {}, {}
  -- El pecho baja al 5 %: urgente.
  dur[5] = { 5, 100 }
  FIRE_EVENT("UPDATE_INVENTORY_DURABILITY")
  RUN_TIMERS(3)
  local rep
  for _, s in ipairs(avisosHoy) do if s.clave == "durabilidad" then rep = s end end
  check(rep and rep.tipo == "peligro", "el equipo que empeoró jugando no se avisó: " .. claves(avisosHoy, "clave"))
  -- Las bolsas se llenan: un solo aviso, el de Bolsas («bolsasLlenas»).
  avisosHoy, avisosKit = {}, {}
  for s = 14, 16 do poner(s, 2589, 1) end
  FIRE_EVENT("BAG_UPDATE", 0)
  FIRE_EVENT("BAG_UPDATE_DELAYED")
  RUN_TIMERS(3)
  local deBolsas = 0
  for _, o in ipairs(avisosKit) do if o.id == "bolsasLlenas" then deBolsas = deBolsas + 1 end end
  check(deBolsas == 1, "al llenarse no salió (una vez) el aviso de Bolsas: " .. claves(avisosKit, "titulo"))
  for _, s in ipairs(avisosHoy) do check(s.clave ~= "bolsas", "Hoy repitió el aviso de bolsas llenas") end
  check(R.BolsasHablan(), "con Bolsas, Hoy no sabe que el aviso es de Bolsas")
  -- Lo que se dijo queda anotado para Lya (una sola voz).
  local dichos = rawget(N, "dichosSesion") or {}
  check(dichos.reparar ~= nil, "el aviso de reparar no quedó en AlfaNucleo.dichosSesion")
  check(dichos.bolsasLlenas ~= nil, "el aviso de bolsas llenas no quedó en AlfaNucleo.dichosSesion")
  check(R.UmbralBolsas() == (tonumber(A.Get("bolsas.avisoLibres")) or 4), "Hoy no usa el umbral de Bolsas")
  -- Sales de la mazmorra y vuelves a entrar: ahora sí, «Antes de…».
  avisosKit = {}
  instancia = "none"
  FIRE_EVENT("ZONE_CHANGED_NEW_AREA")
  RUN_TIMERS(4)
  instancia = "party"
  FIRE_EVENT("PLAYER_ENTERING_WORLD", false, false)
  RUN_TIMERS(5)
  local antes
  for _, o in ipairs(avisosKit) do if tostring(o.titulo):find("^Antes de") then antes = o end end
  check(antes, "al entrar a la mazmorra desde fuera no salió «Antes de…»: " .. claves(avisosKit, "titulo"))
  -- Un /reload dentro: base otra vez, sin aviso.
  avisosKit = {}
  Li.Reiniciar()
  FIRE_EVENT("PLAYER_ENTERING_WORLD", false, true)
  RUN_TIMERS(5)
  for _, o in ipairs(avisosKit) do check(not tostring(o.titulo):find("^Antes de"), "tras /reload en la mazmorra salió «Antes de…»") end
  instancia = "none"
  FIRE_EVENT("ZONE_CHANGED_NEW_AREA")
  RUN_TIMERS(2)
  dur[5] = { 100, 100 }
  FIRE_EVENT("UPDATE_INVENTORY_DURABILITY")
  for s = 10, 16 do bolsas[0][s] = nil end
  FIRE_EVENT("BAG_UPDATE", 0)
  FIRE_EVENT("BAG_UPDATE_DELAYED")
  RUN_TIMERS(3)
end)

step("Una sola voz: lo que ya se dijo (Lya o Hoy) no se repite; lo que empeora, sí", function()
  -- Lya acaba de decir «reparar» y «bolsasLlenas»: ni Hoy ni Bolsas lo repiten.
  rawset(N, "dichosSesion", { reparar = GetTime(), bolsasLlenas = GetTime() })
  avisosHoy, avisosKit = {}, {}
  dur[5] = { 25, 100 }
  FIRE_EVENT("UPDATE_INVENTORY_DURABILITY")
  RUN_TIMERS(3)
  for s = 1, 14 do poner(s, 2589, 1) end -- 2 casillas libres: casi llenas
  FIRE_EVENT("BAG_UPDATE", 0)
  FIRE_EVENT("BAG_UPDATE_DELAYED")
  RUN_TIMERS(3)
  for _, s in ipairs(avisosHoy) do check(s.clave ~= "durabilidad" and s.clave ~= "bolsas", "Hoy repitió lo que Lya ya dijo: " .. tostring(s.clave)) end
  for _, o in ipairs(avisosKit) do check(o.id ~= "bolsasLlenas", "Bolsas repitió lo que Lya ya dijo") end
  -- Lo que empeora sí sale: el equipo a punto de romperse.
  dur[5] = { 5, 100 }
  FIRE_EVENT("UPDATE_INVENTORY_DURABILITY")
  RUN_TIMERS(3)
  local urg = false
  for _, s in ipairs(avisosHoy) do if s.clave == "durabilidad" and s.tipo == "peligro" then urg = true end end
  check(urg, "lo urgente no salió porque Lya ya había dicho «reparar»")
  -- Pasados 10 minutos, se puede volver a decir.
  avisosHoy = {}
  NOW = NOW + 700
  dur[5] = { 100, 100 }
  FIRE_EVENT("UPDATE_INVENTORY_DURABILITY")
  RUN_TIMERS(3)
  dur[5] = { 25, 100 }
  FIRE_EVENT("UPDATE_INVENTORY_DURABILITY")
  RUN_TIMERS(3)
  local otraVez = false
  for _, s in ipairs(avisosHoy) do if s.clave == "durabilidad" then otraVez = true end end
  check(otraVez, "pasados 10 minutos no volvió a avisar de reparar")
  check(N.dichosSesion.reparar and GetTime() - N.dichosSesion.reparar < 5, "Hoy avisó de reparar y no lo anotó")
  dur[5] = { 100, 100 }
  FIRE_EVENT("UPDATE_INVENTORY_DURABILITY")
  for s = 1, 16 do bolsas[0][s] = nil end
  FIRE_EVENT("BAG_UPDATE", 0)
  FIRE_EVENT("BAG_UPDATE_DELAYED")
  RUN_TIMERS(3)
end)

---------------------------------------------------------------------------
-- 1. Mientras entras: a la fila «Mientras entrabas»
---------------------------------------------------------------------------

step("Mientras entras: el aviso de Hoy se guarda para «Mientras entrabas», con su acción", function()
  -- Lya a la vista cuenta lo guardado sola (su latido) y se queda con los avisos
  -- (K.PorLya): aquí se mira la fila de Hoy, así que Lya calla.
  N.Quitar("lya.latido")
  local porLya = K.PorLya
  K.PorLya = nil
  guardados, olvidados = {}, {}
  entrando = true
  local pulsado = false
  I.Aviso.Mostrar({ clave = "prueba133", tipo = "aviso", icono = "ic-oficios", titulo = "Tu equipo se está gastando", linea = "Pecho: 25%",
    texto = "Repara pronto.", botones = { { texto = "Llévame a reparar", fn = function() pulsado = true end } } })
  check(I.Aviso.Visible() == nil, "mientras entrabas, el aviso salió en pantalla")
  local g = guardados[1]
  check(g and g.id == "inicio.prueba133" and g.titulo == "Tu equipo se está gastando", "no se guardó para «Mientras entrabas»")
  check(g and g.accion and g.accion.texto == "Llévame a reparar", "se guardó sin su acción")
  check(g and tostring(g.texto):find("Pecho: 25%", 1, true), "se guardó sin su línea")
  -- Con alEntrar = true sale igual.
  I.Aviso.Mostrar({ clave = "prueba133b", titulo = "Sale igual", texto = "Ya", alEntrar = true, segundos = 1 })
  check(I.Aviso.Visible() == "prueba133b", "con alEntrar = true no salió")
  I.Aviso.Ocultar(true)
  entrando = false
  -- La fila en Hoy: cada cosa con su acción y su «Listo».
  AlfaNucleo.Abrir("inicio")
  RUN_TIMERS(3)
  local P = I.Pagina
  check(P.alEntrar and P.alEntrar:IsShown(), "con algo guardado, la fila «Mientras entrabas» no sale en Hoy")
  local t = P.TarjetasAlEntrar()
  check(#t == 1 and t[1].accion and t[1].accion.texto == "Llévame a reparar" and t[1].secundaria and t[1].secundaria.texto == "Listo",
    "la tarjeta no trae su acción y su «Listo»")
  if t[1] and t[1].accion then t[1].accion.alClic() end
  check(pulsado, "la acción de la tarjeta no hizo lo del aviso")
  check(olvidados[1] == "inicio.prueba133", "la acción no la quitó de la fila")
  RUN_TIMERS(3)
  check(not P.alEntrar:IsShown(), "sin nada guardado, la fila sigue en Hoy")
  -- Otra, y su «Listo».
  NucleoFalso.GuardarAlEntrar({ id = "lya.hola", titulo = "Lya te esperaba", texto = "Hay algo nuevo.", origen = "lya" })
  RUN_TIMERS(3)
  check(P.alEntrar:IsShown(), "con ALFA_ALENTRAR la fila no se repintó")
  local t2 = P.TarjetasAlEntrar()
  if t2[1] and t2[1].secundaria then t2[1].secundaria.alClic() end
  RUN_TIMERS(3)
  check(#guardados == 0 and not P.alEntrar:IsShown(), "«Listo» no la quitó")
  K.PorLya = porLya
end)

---------------------------------------------------------------------------
-- 4. «Hazlo ya» con lo de tus bolsas
---------------------------------------------------------------------------

step("Hazlo ya: cuenta lo de tus bolsas, y lo del banco aparte", function()
  for s = 1, 16 do bolsas[0][s] = nil end
  poner(1, 2589, 4)
  FIRE_EVENT("BAG_UPDATE", 0)
  FIRE_EVENT("BAG_UPDATE_DELAYED")
  RUN_TIMERS(3)
  local D = B.Datos
  local r = D.Actual()
  r.banco = { [6] = { n = 28, [1] = { i = 2589, c = 6 } } }
  r.v = (r.v or 0) + 1
  local cd = N.Datos("comercio")
  cd.recetas = type(cd.recetas) == "table" and cd.recetas or {}
  cd.recetas[C.ClavePersonaje()] = { rk = C.ClaveReino(), nombre = "Lobato", profs = {},
    r = { [2963] = { o = 2996, q = 1, n = "Rollo de lino", p = "Sastrería", r = { 2589, 2 } } } }
  local reino = C.Reino()
  reino.p[2996] = { 5000, C.Ahora(), 10, 1 }
  cd.comprar = cd.comprar or {}
  cd.comprar[2589] = 10
  C.RecetasCambiaron()
  local lista = C.Fabricar()
  local x
  for _, y in ipairs(lista) do if y.e.rec.o == 2996 then x = y end end
  check(x, "la receta no salió en «Fabricar»") if not x then return end
  check(x.veces == 2, "«Hazlo ya» contó lo del banco: " .. tostring(x.veces) .. " (con 4 linos en tus bolsas son 2)")
  check(x.conBanco == 3, "no dijo cuántas más con el banco: " .. tostring(x.conBanco))
  cd.recetas[C.ClavePersonaje()] = nil
  reino.p[2996] = nil
  cd.comprar[2589] = nil
  C.RecetasCambiaron()
  r.banco = {}
  r.v = r.v + 1
end)

---------------------------------------------------------------------------
-- 5. El plan que vence
---------------------------------------------------------------------------

step("El plan de una hora que vence deja su nota en Hoy", function()
  local plan = { total = 60, pasos = { { tipo = "recoger", min = 20 }, { tipo = "guia", min = 20 }, { tipo = "recoger", min = 20 } } }
  con(_G, { AlfaRuta = { Recoger = function() end } }, function()
    check(TM.Empezar(plan), "no empezó el plan")
    TM.Siguiente(false)
  end)
  local h = N.DatosPersonaje("inicio").hora
  h.t0 = time() - 4 * 3600
  check(TM.Actual() == nil, "un plan de hace 4 h sigue en marcha")
  local v = TM.Vencido()
  check(v and v.hechos == 1 and v.pasos == 3, "el plan vencido no dejó cuántos pasos llevabas")
  check(TM.TextoVencido() == "Tu plan de 1 h quedó sin terminar: llevabas 1 de 3 pasos.", "la nota no dice lo que llevabas: " .. tostring(TM.TextoVencido()))
  A.Set("inicio.horaPlan", true)
  AlfaNucleo.Abrir("inicio")
  RUN_TIMERS(3)
  local P = I.Pagina
  check(P.hora and P.hora.Vencido and P.hora.Vencido:IsShown(), "la nota del plan vencido no sale en Hoy")
  TM.OlvidarVencido()
  RUN_TIMERS(3)
  check(TM.Vencido() == nil and not P.hora.Vencido:IsShown(), "«Listo» no quitó la nota")
end)

---------------------------------------------------------------------------
-- 6. Conjuntos: «Otro nombre…» y el corte por letras
---------------------------------------------------------------------------

step("Conjuntos: «Otro nombre…» con caja de texto y el corte por letras completas", function()
  local corto = Cj.Cortar("Curación de la manada élite y más", 10)
  check(corto == "Curación d", "no cortó por letras: " .. corto)
  local largo = Cj.Cortar(string.rep("ñ", 50))
  check(#largo == 2 * Cj.MAX_LETRAS, "cortó una letra a medias: " .. #largo .. " bytes")
  local c = Cj.Guardar("  Curación de la manada élite de la Jauría  ")
  check(c and not c.n:find("[\194-\244]$") and select(2, c.n:gsub("[%z\1-\127\194-\244][\128-\191]*", "")) <= Cj.MAX_LETRAS,
    "el nombre guardado quedó con media letra o muy largo: " .. tostring(c and c.n))
  if c then Cj.Olvidar(c.n) end
  -- El menú de guardar trae «Otro nombre…»; abre la caja y Enter guarda.
  local ops, alElegir
  con(K, { Menu = function(_, o, _, fn) ops, alElegir = o, fn end }, function() Cj.MenuGuardar(UIParent) end)
  local otro
  for _, o in ipairs(ops or {}) do if o.texto == "Otro nombre…" then otro = o end end
  check(otro, "el menú de guardar no trae «Otro nombre…»")
  if otro and alElegir then alElegir(otro.valor) end
  RUN_TIMERS(2)
  local v = rawget(_G, "AlfaBolsasNombreConjunto")
  check(v and v:IsShown(), "no se abrió la caja para escribir el nombre")
  if v then
    v.Campo:SetTexto("Tanque Vael", true)
    v.Guardar.alClic(v.Guardar)
    check(Cj.Buscar("Tanque Vael"), "no guardó «Tanque Vael»")
    check(not v:IsShown(), "la caja no se cerró al guardar")
    Cj.Olvidar("Tanque Vael")
  end
end)

K.Aviso = avisoReal
I.Aviso.Mostrar = mostrarReal
for k in pairs(NucleoFalso) do if rawget(N, k) == NucleoFalso[k] then rawset(N, k, nil) end end
print(string.format("PRUEBA: 1.3.3 Hoy, bolsas y comercio, %d pasos, %d errores", pasos, #ERRORS))
for i = 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
