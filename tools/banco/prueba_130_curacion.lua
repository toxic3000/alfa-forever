-- Prueba de la 1.3.0, Curación (tools/prueba.py la corre con las demás prueba_*.lua):
--   * «Curar y seleccionar»: cada clic que cura es una macro "/target u\n/cast [@u] Hechizo"
--     (atributos seguros, también el fragmento seguro REFRESCO con otra unidad), apagado
--     vuelve a "spell", y nada cambia en combate (se aplica al salir);
--   * la venda (preajuste de quien no cura) y «Tus clics» con los hechizos por tipo;
--   * perjuicios: tipo con ícono y color, el aviso si ningún clic lo quita;
--   * el punto del buff que falta, el tanque bajo el 40 %, el alcance sin UnitInRange;
--   * la banda por grupos (8 cabeceras y el controlador de estado), el maná de los
--     curanderos (destacado tras la pelea), la página y el asistente.
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
local function check(cond, msg) if not cond then NOTE("1.3.0 curacion", msg) end end
local function T(n) RUN_TIMERS(n or 2) end

---------------------------------------------------------------------------
-- El juego simulado: un sacerdote en grupo (fakes de esta escena)
---------------------------------------------------------------------------
local NOMBRES = {
  [2050] = "Sanar inferior", [2054] = "Sanar", [2060] = "Sanación superior", [2061] = "Curación relámpago",
  [139] = "Renovar", [17] = "Palabra de poder: escudo", [527] = "Disipar magia", [528] = "Curar enfermedad",
  [552] = "Suprimir enfermedad", [2006] = "Resurrección", [596] = "Rezo de sanación",
  [1243] = "Palabra de poder: entereza", [21562] = "Rezo de entereza", [14752] = "Espíritu divino",
}
local SABE = { [2050] = true, [2054] = true, [2061] = true, [139] = true, [17] = true, [527] = true, [528] = true,
  [2006] = true, [596] = true, [1243] = true }
C_Spell.GetSpellName = function(id) return NOMBRES[id] end
C_SpellBook = C_SpellBook or {}
C_SpellBook.IsSpellKnown = function(id) return SABE[id] == true end

local CLASES = { player = "PRIEST", party1 = "WARRIOR", party2 = "DRUID", party3 = "MAGE" }
local NOMBRE_U = { player = "Lobato", party1 = "Colmillo", party2 = "Luna", party3 = "Aullido" }
local vida = { player = 100, party1 = 100, party2 = 100, party3 = 100 }
local mana = { player = 50, party2 = 20 }
UnitClass = function(u) local c = CLASES[u] if c then return c, c, 1 end return nil end
UnitName = function(u) return NOMBRE_U[u], nil end
UnitExists = function(u) return CLASES[u] ~= nil end
UnitHealth = function(u) return vida[u] or 0 end
UnitHealthMax = function() return 100 end
UnitPower = function(u) return mana[u] or 0 end
UnitPowerMax = function() return 100 end
UnitIsUnit = function(a, b) return a == b end
local roles = {}
UnitGroupRolesAssigned = function(u) return roles[u] or "NONE" end
IsInGroup = function() return true end
local principal = {}
GetPartyAssignment = function(tipo, u) return tipo == "MAINTANK" and principal[u] == true end
GetNumGroupMembers = function() return 4 end

-- Auras: "u" -> { perjuicio = { id, tipo }, buffs = { [nombre] = true } }
local auras = {}
C_UnitAuras = {
  GetUnitAuraInstanceIDs = function(u, filtro)
    local a = auras[u]
    if a and a.perjuicio then return { a.perjuicio.id } end
    return {}
  end,
  GetAuraDataByAuraInstanceID = function(u, id)
    local a = auras[u]
    if a and a.perjuicio and a.perjuicio.id == id then return { auraInstanceID = id, dispelName = a.perjuicio.tipo, icon = 136071 } end
    return nil
  end,
  GetAuraDataBySpellName = function(u, nombre)
    local a = auras[u]
    if a and a.buffs and a.buffs[nombre] then return { name = nombre } end
    return nil
  end,
}
-- Las bolsas: una venda de seda.
C_Container = C_Container or {}
C_Container.GetContainerNumSlots = function(b) return b == 0 and 4 or 0 end
C_Container.GetContainerItemID = function(b, i) if b == 0 and i == 2 then return 6450 end return nil end
-- El controlador de estado (lo registra la banda por grupos).
local drivers = {}
RegisterStateDriver = function(f, estado, valores) drivers[#drivers + 1] = { f = f, estado = estado, valores = valores, alta = true } end
UnregisterStateDriver = function(f, estado) drivers[#drivers + 1] = { f = f, estado = estado, alta = false } end

local combate = false
InCombatLockdown = function() return combate end

local A = AlfaNucleo.A
local K = AlfaNucleo.Kit
local N = AlfaNucleo
Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(10)
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end

local Cu = NS_OF("Alfa_Curacion")

-- Corre el fragmento seguro REFRESCO sobre un botón falso con estos atributos.
local function correrRefresco(attrs)
  local b = { a = {} }
  for k, v in pairs(attrs) do b.a[k] = v end
  function b:GetAttribute(k) return self.a[k] end
  function b:SetAttribute(k, v) self.a[k] = v end
  local fn = assert(loadstring(Cu.REFRESCO))
  setfenv(fn, { self = b, gmatch = string.gmatch })
  fn()
  return b.a
end

local boton
step("Los ajustes de fábrica y el preajuste del sacerdote", function()
  for _, k in ipairs({ "tipoPerjuicio", "buffs", "tanque", "mana", "porGrupos" }) do
    check(N.Get("curacion", k) == true, "curacion." .. k .. " no viene prendido de fábrica")
  end
  check(Cu.CurarSelecciona() == true, "«Curar y seleccionar» no viene prendido")
  check(type(AlfaCuracion.CurarSelecciona) == "function" and type(AlfaCuracion.QuitarSinClic) == "function", "faltan las API públicas nuevas")
  Cu.AplicarPreajuste("curar", true)
  local m = Cu.Mapa()
  check(m["1"] and m["1"].t == "spell" and m["1"].id == 2061, "el izquierdo del sacerdote no es Curación relámpago")
  check(m["shift-1"] and m["shift-1"].id == 527, "Mayús + izquierdo no es Disipar magia")
end)

step("Curar y seleccionar: atributos seguros del botón", function()
  boton = CreateFrame("Button", "AlfaPruebaCuracion1", UIParent, "SecureUnitButtonTemplate")
  boton:SetSize(88, 36)
  boton:SetAttribute("unit", "party1")
  Cu.PrepararBoton(boton)
  local a = function(k) return boton:GetAttribute(k) end
  check(a("type1") == "macro", "el izquierdo no es una macro: " .. tostring(a("type1")))
  check(a("macrotext1") == "/target party1\n/cast [@party1] Curación relámpago", "macro del izquierdo: " .. tostring(a("macrotext1")))
  check(a("spell1") == nil, "sobra spell1 con la macro")
  check(a("shift-type1") == "macro" and a("shift-macrotext1") == "/target party1\n/cast [@party1] Disipar magia", "Mayús + izquierdo no quita y selecciona")
  check(a("alfa-cmd-1") == "/cast" and a("alfa-arg-1") == "Curación relámpago", "faltan alfa-cmd/alfa-arg para el fragmento seguro")
  check(type(a("alfa-objetivos")) == "string" and a("alfa-objetivos"):find(":1", 1, true), "la ranura no está en alfa-objetivos")
  check(a("refreshUnitChange") == Cu.REFRESCO, "falta el fragmento seguro")
  -- El derecho (Renovar) también; ninguna macro pasa de 255 letras.
  check(a("macrotext2") == "/target party1\n/cast [@party1] Renovar", "el derecho no cura y selecciona")
  for _, r in ipairs(Cu.RANURAS) do
    local p, s = Cu.Partes(r)
    local t = a(p .. "macrotext" .. s)
    check(t == nil or #t <= 255, "macro de más de 255 letras en " .. r)
  end
end)

step("Curar y seleccionar: el fragmento seguro con otra unidad", function()
  local attrs = {}
  for k, v in pairs(boton._attr) do attrs[k] = v end
  attrs.unit = "raid17"
  local r = correrRefresco(attrs)
  check(r.macrotext1 == "/target raid17\n/cast [@raid17] Curación relámpago", "el fragmento no rehízo la macro: " .. tostring(r.macrotext1))
  check(r.macrotext1 == Cu.Macro("raid17", "/cast", "Curación relámpago"), "el fragmento y Lua no arman la misma macro")
  check(r["shift-macrotext1"] == "/target raid17\n/cast [@raid17] Disipar magia", "Mayús en el fragmento: " .. tostring(r["shift-macrotext1"]))
  attrs.unit = nil
  r = correrRefresco(attrs)
  check(r.macrotext1 == nil, "sin unidad la macro debe quedar vacía")
end)

step("Curar y seleccionar: apagado, en combate y al salir", function()
  Cu.FijarCurarSelecciona(false)
  check(boton:GetAttribute("type1") == "spell" and boton:GetAttribute("spell1") == "Curación relámpago", "apagado, el izquierdo no lanza el hechizo")
  check(boton:GetAttribute("macrotext1") == nil, "apagado, sobra la macro")
  -- En combate nada se toca.
  combate = true
  local orig, cambios = boton.SetAttribute, 0
  boton.SetAttribute = function(self, k, v) cambios = cambios + 1 return orig(self, k, v) end
  Cu.FijarCurarSelecciona(true)
  T(2)
  check(cambios == 0, "se cambiaron " .. cambios .. " atributos en combate")
  check(boton:GetAttribute("type1") == "spell", "en combate cambió el izquierdo")
  combate = false
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  T(2)
  boton.SetAttribute = nil
  check(boton:GetAttribute("type1") == "macro", "al salir de combate no se aplicó «Curar y seleccionar»")
  check(Cu.Frase(Cu.Mapa()["1"]):find("lo selecciona", 1, true), "la frase no dice que selecciona: " .. Cu.Frase(Cu.Mapa()["1"]))
end)

step("La venda: preajuste de quien no cura y su macro", function()
  local mg = Cu.Resolver("buffs", false, "WARRIOR")
  check(mg["shift-1"] and mg["shift-1"].t == "venda", "el guerrero no tiene la venda en Mayús + izquierdo")
  check(mg["1"] and mg["1"].t == "target" and mg["2"].t == "menu", "Básico perdió seleccionar y menú")
  Cu.FijarRanura("ctrl-3", { t = "venda" })
  check(Cu.venda == 6450, "no encontró la venda de seda: " .. tostring(Cu.venda))
  check(boton:GetAttribute("ctrl-macrotext3") == "/target party1\n/use [@party1] item:6450", "macro de la venda: " .. tostring(boton:GetAttribute("ctrl-macrotext3")))
  Cu.FijarRanura("ctrl-3", { t = "nada" })
  check(boton:GetAttribute("ctrl-type3") == nil, "sin acción quedó un tipo en ctrl-3")
end)

step("Tus clics: los hechizos por tipo", function()
  local cats = {}
  for _, c in ipairs(Cu.HechizosPorCategoria()) do cats[c.categoria] = c end
  check(cats.cura and cats.quitar and cats.buff and cats.revivir, "faltan categorías en la lista")
  local op = Cu.OpcionesDe("1")
  local sep, disipar, venda = false, false, false
  for _, o in ipairs(op) do
    if o.separador then sep = true end
    if o.valor == "spell:527" then disipar = true end
    if o.valor == "venda" then venda = true end
  end
  check(sep and disipar and venda, "la lista de un clic no trae separadores, Disipar magia o la venda")
end)

step("Perjuicios: tipo, ícono, color y aviso sin clic", function()
  auras.party1 = { perjuicio = { id = 77, tipo = "Magic" } }
  Cu.ActualizarTodo(boton)
  local c = boton.cuerpo
  check(boton.alfaTipo == "Magic", "no leyó el tipo del perjuicio")
  check(c.perjuicio:IsShown() and c.perjuicio:GetTexture() == Cu.TIPOS.Magic.icono, "no sale el ícono de magia")
  local r = c.disipar[1]:GetVertexColor()
  check(math.abs(r - 0.2) < 0.01, "el borde no tiene el color de la magia")
  check(#Cu.QuitarSinClic() == 0, "con Disipar magia en Mayús no debería avisar")
  -- Quitamos Disipar magia de Mayús: aviso una sola vez.
  Cu.FijarRanura("shift-1", { t = "nada" })
  local dichos = {}
  local imp = N.Imprimir
  N.Imprimir = function(t) dichos[#dichos + 1] = t end
  Cu.ActualizarTodo(boton)
  Cu.ActualizarTodo(boton)
  N.Imprimir = imp
  local n = 0
  for _, t in ipairs(dichos) do if t:find("ningún clic", 1, true) then n = n + 1 end end
  check(n == 1, "el aviso de perjuicio sin clic salió " .. n .. " veces")
  check(Cu.QuitarSinClic()[1] == "Magic", "QuitarSinClic no dice magia")
  Cu.FijarRanura("shift-1", { t = "spell", id = 527 })
  check(Cu.RanuraQueQuita("Magic") == "shift-1", "Mayús + izquierdo no quita la magia")
  auras.party1 = nil
  Cu.ActualizarTodo(boton)
  check(not c.perjuicio:IsShown(), "el ícono no se quitó sin perjuicio")
end)

step("El punto del buff que falta", function()
  Cu.ActualizarTodo(boton)
  check(boton.alfaSinBuff == true and boton.cuerpo.punto:IsShown(), "no sale el punto sin Entereza")
  check(Cu.RanuraDelBuff() == "alt-1", "la ranura del buff no es Alt + izquierdo: " .. tostring(Cu.RanuraDelBuff()))
  auras.party1 = { buffs = { ["Rezo de entereza"] = true } }
  Cu.ActualizarTodo(boton)
  check(not boton.cuerpo.punto:IsShown(), "con Rezo de entereza sigue el punto")
  -- En combate se queda como estaba.
  auras.party1 = nil
  combate = true
  Cu.BuffFalta(boton)
  check(not boton.cuerpo.punto:IsShown(), "en combate cambió el punto")
  combate = false
  Cu.BuffFalta(boton)
  check(boton.cuerpo.punto:IsShown(), "fuera de combate no volvió el punto")
  N.Set("curacion", "buffs", false)
  Cu.BuffFalta(boton)
  check(not boton.cuerpo.punto:IsShown(), "apagado sigue el punto")
  N.Set("curacion", "buffs", true)
end)

step("El tanque bajo el 40 %", function()
  roles.party1 = "TANK"
  vida.party1 = 30
  Cu.RevisarTanques()
  check(boton.esTanque == true, "no reconoció al tanque por su rol")
  check(boton.alfaTanqueBajo == true and boton.cuerpo.pulso:IsShown(), "el tanque al 30 % no late")
  vida.party1 = 80
  FIRE_EVENT("UNIT_HEALTH", "party1")
  check(boton.alfaTanqueBajo == false, "al 80 % sigue en apuros")
  -- Sin roles, el único guerrero es el tanque.
  roles.party1 = nil
  Cu.RevisarTanques()
  check(boton.esTanque == true, "sin roles, el único guerrero no es el tanque")
  -- El tanque principal de la banda también cuenta.
  CLASES.party1 = "PALADIN"
  Cu.RevisarTanques()
  check(boton.esTanque == false, "sin rol ni guerrero, sigue siendo tanque")
  principal.party1 = true
  Cu.RevisarTanques()
  check(boton.esTanque == true, "el tanque principal no cuenta")
  principal.party1 = nil
  CLASES.party1 = "WARRIOR"
  N.Set("curacion", "tanque", false)
  T(1)
  Cu.Tanque(boton)
  check(not boton.cuerpo.pulso:IsShown(), "apagado, el tanque sigue latiendo")
  N.Set("curacion", "tanque", true)
end)

step("El alcance sin UnitInRange", function()
  local uir = rawget(_G, "UnitInRange")
  UnitInRange = false -- el banco responde con un comodín a lo que no existe
  CheckInteractDistance = function() return false end
  Cu.ActualizarTodo(boton)
  check(math.abs(boton.cuerpo:GetAlpha() - 0.4) < 0.01, "lejos no se atenúa sin UnitInRange")
  CheckInteractDistance = function() return true end
  Cu.ActualizarTodo(boton)
  check(boton.cuerpo:GetAlpha() == 1, "cerca sigue atenuado")
  UnitInRange = uir
end)

step("La banda por grupos", function()
  check(#Cu.porGrupo == 8, "no hay 8 cabeceras de grupo")
  drivers = {}
  Cu.Disponer()
  T(1)
  for g, h in ipairs(Cu.porGrupo) do
    check(h:GetAttribute("groupFilter") == tostring(g), "la cabecera " .. g .. " no filtra su grupo")
    check(h:GetAttribute("showParty") == false and h:GetAttribute("showRaid") == true, "la cabecera " .. g .. " no es solo de banda")
    check(h:IsShown(), "la cabecera " .. g .. " no se ve")
  end
  local alta
  for _, d in ipairs(drivers) do if d.f == Cu.cabecera and d.alta then alta = d end end
  check(alta and alta.estado == "visibility" and alta.valores == "[group:raid] hide; show", "la cabecera de siempre no se oculta en banda")
  -- Columna por grupo: la del grupo 2 a un marco de distancia.
  local _, _, _, x2 = Cu.porGrupo[2]:GetPoint(1)
  local w = Cu.Medidas()
  check(x2 == w + 3, "el grupo 2 no está en la segunda columna: " .. tostring(x2))
  -- Apagado: sin controlador y sin cabeceras de grupo. En combate, nada cambia.
  drivers = {}
  combate = true
  N.Set("curacion", "porGrupos", false)
  T(1)
  check(#drivers == 0, "en combate se tocó el controlador de estado")
  combate = false
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  T(1)
  local baja = false
  for _, d in ipairs(drivers) do if d.f == Cu.cabecera and not d.alta then baja = true end end
  check(baja, "apagado no quitó el controlador")
  check(not Cu.porGrupo[1]:IsShown(), "apagado sigue la cabecera del grupo 1")
  N.Set("curacion", "porGrupos", true)
  T(1)
end)

step("El maná de los curanderos", function()
  local Mn = Cu.Mana
  local lista = Mn.Lista()
  check(#lista == 2, "la lista de curanderos no tiene 2 (sacerdote y druida): " .. #lista)
  Mn.Refrescar()
  check(Mn.filas == 2 and AlfaCuracionMana and AlfaCuracionMana:IsShown(), "no se ve el maná del grupo")
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  check(Mn.destacado == true and AlfaCuracionMana.titulo:GetText() == "Maná tras la pelea", "tras la pelea no se destaca")
  local fila = AlfaCuracionMana.filas[2]
  check(fila.valor:GetText() == "20%", "el maná del druida dice " .. tostring(fila.valor:GetText()))
  local r = fila.valor:GetTextColor()
  check(r == 1, "el maná bajo no sale en rojo")
  N.Set("curacion", "mana", false)
  check(not AlfaCuracionMana:IsShown(), "apagado se sigue viendo el maná")
  N.Set("curacion", "mana", true)
end)

local function visible(texto)
  for _, f in ipairs(ALL_FRAMES()) do
    if f.GetText and f:IsVisible() and f:GetText() == texto then return true end
  end
  return false
end

step("La página: Tus clics primero, con sus listas", function()
  A.Fire("SHOW_OPTIONS", "curacion") T(2)
  check(visible("Curar y seleccionar"), "no sale «Curar y seleccionar» en la página")
  check(visible("Clic izquierdo") and visible("Mayús + clic izquierdo") and visible("Ctrl + clic derecho"), "faltan filas de Tus clics")
  check(visible("En banda, un grupo por columna") and visible("Tanque en apuros") and visible("Le falta tu buff"), "faltan ajustes nuevos")
  local d
  for _, f in ipairs(ALL_FRAMES()) do if f.alfaRanura == "1" and f:IsVisible() then d = f end end
  check(d and d.Texto:GetText():find("Curación relámpago", 1, true), "el desplegable del izquierdo no dice su hechizo")
  -- Elegir otro hechizo en la lista cambia el clic.
  if d then
    d.alfaSet("spell:139")
    check(Cu.Mapa()["1"].id == 139, "elegir en la lista no cambió el clic")
    check(boton:GetAttribute("macrotext1") == "/target party1\n/cast [@party1] Renovar", "el atributo no siguió a la lista")
  end
  local f = A.UI and A.UI.Options and A.UI.Options.frame
  if f then f:Hide() end
end)

step("El asistente: «Curar y seleccionar» en el paso 1", function()
  Cu.AbrirAsistente(1) T(1)
  check(visible("Curar y seleccionar"), "el asistente no ofrece «Curar y seleccionar»")
  local v = rawget(_G, "AlfaCuracionAsistente")
  if v and v.Hide then v:Hide() end
end)

print(("PRUEBA: %d pasos, %d errores"):format(pasos, #ERRORS))
