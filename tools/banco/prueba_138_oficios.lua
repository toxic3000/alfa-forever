-- Prueba de la 1.3.8, oficios y ventana (tools/prueba.py la corre con las demás):
--  16. recetas de vendedor que te faltan cerca (Codex): índice en tarea, sin las
--      que ya tienes, las de tu zona primero; la sección en la ventana de Oficios;
--  17. lista de compras: lo de tus otros personajes se descuenta (y se apaga),
--      y «hasta tu tope» pide menos que hasta 300;
--  18. bolsas «Separar»: subasta / comerciante, la marca y el atenuado, se apaga
--      al cerrar; el botón de la cabecera;
--  19. el jefe en una línea: lo más importante (interrumpir), sin ratón, sin
--      cortarse; «tarjeta» sigue siendo la de antes;
--  20. el resumen al terminar una mazmorra: tiempo, récord, daño, botín, se va
--      al entrar en combate;
--  21. la escala de las ventanas del Kit (no las de la capa MEDIUM);
--  22. modo Zen: esconde Alfa con la flecha y devuelve el ajuste de la flecha;
--  23. «Lo más usado»: cuenta lo que cambias tú y lo pone en Estilo y sonido;
--  24. temporada: fechas, adorno en las ventanas solo prendido;
--  y el resumen de cada pelea, apagado de fábrica (pedido de Toxic), guardado igual.
SNAPSHOTS = {}
local function SNAP(name, root, extra)
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS["138-oficios-" .. name] = { entries = entries, l = l, b = b, w = w, h = h }
end
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
local function check(cond, msg) if not cond then NOTE("1.3.8 oficios", msg) end end
local function T(n) RUN_TIMERS(n or 2) end

local N = AlfaNucleo
local A = Alfa
local K = N.Kit
Alfa.Hidden = Alfa.Hidden or function() return false end
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(10)
if A.UI and A.UI.Options and A.UI.Options.frame then A.UI.Options.frame:Hide() end

local Co = NS_OF("Alfa_Comercio")
local B = NS_OF("Alfa_Bolsas")
local Mz = NS_OF("Alfa_Mazmorras")
local Bv = NS_OF("Alfa_Bienvenida")
local Cb = NS_OF("Alfa_Combate")

local function texto(fs) return fs and fs.GetText and (fs:GetText() or "") or "" end
local function todoTexto(f, out)
  out = out or {}
  if not f then return out end
  for _, c in ipairs(rawget(f, "_children") or {}) do
    if c._kind == "FontString" then
      if c._shown then out[#out + 1] = c:GetText() or "" end
    elseif c._kind ~= "Texture" and c:IsShown() then
      todoTexto(c, out)
    end
  end
  return out
end

---------------------------------------------------------------------------
-- 16. Recetas cerca de ti
---------------------------------------------------------------------------
step("16. recetas de vendedor que te faltan cerca, sin las que ya tienes", function()
  local Rz = Co.RecetasZona
  check(type(Rz) == "table", "falta RecetasZona.lua")
  if not Rz then return end
  -- Alquimia en 60: lo que da el Codex de verdad (la tarea cede: se bombea).
  local habilidad = A.Compat.GetSkillRank
  A.Compat.GetSkillRank = function(l) if l == 171 then return 60, 150 end return nil end
  Rz.Olvidar()
  local lista, motivo = Rz.Buscar(171, 60)
  check(#lista == 0 and (motivo == "cargando" or motivo == "codex"), "sin índice no dijo que está cargando: " .. tostring(motivo))
  for _ = 1, 400 do
    if Rz.Listo() then break end
    Co.motorTareas:GetScript("OnUpdate")(Co.motorTareas, 0.02)
  end
  check(Rz.Listo(), "el índice de recetas no terminó")
  -- Un vendedor de mentira en tu zona (Durotar, 1411) y otro en otra zona.
  local C = A.Codex
  local npcReal, itemReal, eachReal = C.Npc, C.Item, C.Each
  C.Npc = function(id)
    if id == 900001 then return { name = "Vendedora Sheena", faction = "H", spawns = { { map = 1411, x = 50, y = 50 } } } end
    if id == 900002 then return { name = "Vendedor Lejano", faction = "H", spawns = { { map = 1454, x = 40, y = 40 } } } end
    if id == 900003 then return { name = "Vendedor Alianza", faction = "A", spawns = { { map = 1411, x = 10, y = 10 } } } end
    return npcReal(id)
  end
  C.Each = function(kind, fn)
    if kind ~= "recipe" then return eachReal(kind, fn) end
    fn(800001, "Recipe: A", 2) fn(800002, "Recipe: B", 2) fn(800003, "Recipe: C", 2) fn(800004, "Recipe: D", 2)
  end
  C.Item = function(id)
    local r = {
      [800001] = { reqSkill = 171, reqSkillRank = 50, spell = 70001, sources = { { type = "vendor", npc = 900002 } } },
      [800002] = { reqSkill = 171, reqSkillRank = 80, spell = 70002, sources = { { type = "vendor", npc = 900001, limited = true } } },
      [800003] = { reqSkill = 171, reqSkillRank = 40, spell = 70003, sources = { { type = "vendor", npc = 900003 } } },
      [800004] = { reqSkill = 171, reqSkillRank = 200, spell = 70004, sources = { { type = "vendor", npc = 900001 } } },
    }
    return r[id] or itemReal(id)
  end
  local mundoReal = A.Compat.MapToWorld
  local posReal = A.Compat.GetPlayerWorldPosition
  A.Compat.MapToWorld = function(map, x, y) return 1, x * 10 + (map == 1454 and 1000 or 0), y * 10 end
  A.Compat.GetPlayerWorldPosition = function() return 1, 500, 500 end
  Rz.Olvidar()
  Rz.Preparar()
  for _ = 1, 50 do
    if Rz.Listo() then break end
    Co.motorTareas:GetScript("OnUpdate")(Co.motorTareas, 0.02)
  end
  lista = Rz.Buscar(171, 60)
  local ids = {}
  for i, x in ipairs(lista) do ids[i] = x.id end
  check(#lista == 2, "esperaba 2 recetas (la de la Alianza y la de 200 no van): " .. table.concat(ids, ","))
  check(lista[1] and lista[1].id == 800002 and lista[1].aqui and not lista[1].puede and lista[1].limitada, "la de tu zona no va primero (con «Con habilidad 80» y edición limitada)")
  check(lista[2] and lista[2].id == 800001 and lista[2].puede and not lista[2].aqui, "la de otra zona que ya puedes no va segunda")
  -- Ya la tienes (Recetas.lua la guardó por su hechizo): no sale.
  local todas = Co.TodasLasRecetas
  Co.TodasLasRecetas = function() return { { propio = true, id = 70002, rec = {} } } end
  lista = Rz.Buscar(171, 60)
  check(#lista == 1 and lista[1].id == 800001, "salió una receta que ya tienes")
  Co.TodasLasRecetas = todas
  -- La ventana de Oficios: la sección y la flecha al clic.
  local puesta
  local st = A.Nav.SetTarget
  A.Nav.SetTarget = function(map, x, y, titulo) puesta = { map, x, y, titulo } return true end
  Co.VentanaOficios.Abrir(171)
  T(1)
  local v = Co.VentanaOficios.Ventana()
  local todo = table.concat(todoTexto(v), " | ")
  check(todo:find("Recetas que te faltan cerca de ti", 1, true), "la ventana no tiene la sección de recetas cerca")
  check(todo:find("Vendedora Sheena", 1, true) and todo:find("Con habilidad 80", 1, true), "la tarjeta no dice el vendedor ni la habilidad: " .. todo:sub(1, 300))
  Rz.Ir(lista[1])
  check(puesta and puesta[1] == 1454 and puesta[2] == 40, "el clic no puso la flecha en su vendedor")
  -- Captura con lo de abajo a la vista.
  if v.Desplazable then v.Desplazable:SetVerticalScroll(0) end
  SNAP("ventana", v, {})
  if v.Desplazable then
    local d = v.Desplazable
    d:SetVerticalScroll(math.max(0, (d.alfaAltoContenido or 0) - (d:GetHeight() or 0)))
    SNAP("ventana-recetas", v, {})
    d:SetVerticalScroll(0)
  end
  v:Cerrar()
  A.Nav.SetTarget = st
  C.Npc, C.Item, C.Each = npcReal, itemReal, eachReal
  A.Compat.MapToWorld, A.Compat.GetPlayerWorldPosition = mundoReal, posReal
  A.Compat.GetSkillRank = habilidad
  Rz.Olvidar()
end)

---------------------------------------------------------------------------
-- 17. Lista de compras con tus otros personajes
---------------------------------------------------------------------------
step("17. lista de compras: lo de tus otros personajes y hasta tu tope", function()
  local Li = Co.Lista
  Li.Vaciar()
  local qt = AlfaBolsas.QuienTiene
  local cuantos = AlfaBolsas.Cuantos
  AlfaBolsas.Cuantos = function(id) if id == 2589 then return 3, 3, 0, 10 end return 0, 0, 0, 0 end
  AlfaBolsas.QuienTiene = function(id) if id == 2589 then return { { nombre = "Alt", bolsas = 4, banco = 3, equipo = 0 } } end return {} end
  Li.Agregar(2589, 20)
  local mats = Li.Materiales()
  local x
  for _, m in ipairs(mats) do if m.id == 2589 then x = m end end
  check(x and x.tienes == 3 and x.otros == 7 and x.faltan == 10, "no descontó lo de tu alt: " .. tostring(x and x.faltan))
  check(Co.TextoTienes(x):find("Alt: 7", 1, true), "no dice quién lo tiene: " .. Co.TextoTienes(x))
  N.Set("comercio", "listaCuenta", false)
  mats = Li.Materiales()
  for _, m in ipairs(mats) do if m.id == 2589 then x = m end end
  check(x.faltan == 17 and not Co.TextoOtros(2589), "apagado, siguió contando a tu alt")
  N.Set("comercio", "listaCuenta", nil)
  check(A.Get("comercio.listaCuenta") == true, "comercio.listaCuenta no viene prendido")
  Li.Vaciar()
  -- Hasta tu tope pide menos que hasta 300.
  local Of = Co.Oficios
  local a300, a150 = 0, 0
  for _, m in ipairs(Of.Faltan(171, 60)) do a300 = a300 + m.necesita end
  for _, m in ipairs(Of.Faltan(171, 60, 150)) do a150 = a150 + m.necesita end
  check(a150 > 0 and a150 < a300, "hasta 150 no pidió menos que hasta 300: " .. a150 .. " / " .. a300)
  local habilidad = A.Compat.GetSkillRank
  A.Compat.GetSkillRank = function(l) if l == 171 then return 60, 150 end return nil end
  check(Li.AgregarOficio(171, 150), "no agregó el oficio hasta 150")
  local m = Li.Metas()[1]
  check(m and m.hasta == 150 and Li.NombreMeta(m):find("150", 1, true), "la meta no dice hasta 150")
  Li.Vaciar()
  A.Compat.GetSkillRank = habilidad
  AlfaBolsas.QuienTiene, AlfaBolsas.Cuantos = qt, cuantos
end)

---------------------------------------------------------------------------
-- 18. Bolsas: «Separar»
---------------------------------------------------------------------------
step("18. bolsas: separar subasta y comerciante", function()
  local Sp = B.Separar
  check(type(Sp) == "table", "falta Separar.lua")
  if not Sp then return end
  local S = B.Sugerencias
  local estado = S.Estado
  local est = { vender = { { id = 4865, valor = 50, casillas = 1 } },
    conservar = { { id = 9200, valor = 12000, casillas = 1, mejor = "subastar" }, { id = 7777, valor = 300, mejor = "desencantar" } } }
  S.Estado = function() return est end
  check(Sp.Clase(9200) == "subasta" and Sp.Clase(4865) == "vendedor" and Sp.Clase(7777) == nil, "no separó subasta / comerciante")
  local c = Sp.Cuentas()
  check(c.subasta == 1 and c.vendedor == 1 and c.sinMarcar == 1, "las cuentas no cuadran")
  check(Sp.TextoCorto():find("1 subasta", 1, true), "el texto corto no dice cuántos: " .. Sp.TextoCorto())
  -- La marca en una casilla: con clase, la marca; sin clase, atenuada.
  local f = CreateFrame("Button", nil, UIParent)
  local p = { capa = CreateFrame("Frame", nil, f), icono = f:CreateTexture(), tam = 36 }
  Sp.Alternar(nil, true)
  Sp.Pintar(f, p, { rec = { i = 9200 } })
  check(p.separa and p.separa:IsShown(), "no salió la marca de subasta")
  Sp.Pintar(f, p, { rec = { i = 1234 } })
  check(p.separaAtenuado and not p.separa:IsShown(), "lo que no va a ningún lado no se atenuó")
  Sp.Alternar(nil, false)
  Sp.Pintar(f, p, { rec = { i = 1234 } })
  check(not p.separaAtenuado, "apagado, se quedó atenuado")
  -- La ventana de bolsas (tres objetos de mentira): el botón en la cabecera,
  -- la marca de cada casilla y se apaga al cerrar.
  local OBJ = { [2589] = { "Lino", 7, 1 }, [9200] = { "Espada del oso", 2, 2 }, [4865] = { "Garra rota", 15, 0 }, [1234] = { "Pan", 0, 1 } }
  local function enlace(id) return "|cffffffff|Hitem:" .. id .. "::::::::|h[" .. OBJ[id][1] .. "]|h|r" end
  local bolsa = {
    [1] = { itemID = 2589, stackCount = 5, quality = 1, hyperlink = enlace(2589) },
    [2] = { itemID = 9200, stackCount = 1, quality = 2, hyperlink = enlace(9200) },
    [3] = { itemID = 4865, stackCount = 1, quality = 0, hyperlink = enlace(4865) },
    [4] = { itemID = 1234, stackCount = 3, quality = 1, hyperlink = enlace(1234) },
  }
  local CC = {}
  for k, v in pairs(C_Container) do CC[k] = v end
  C_Container.GetContainerNumSlots = function(b) return b == 0 and 16 or 0 end
  C_Container.GetContainerNumFreeSlots = function(b) if b == 0 then return 12, 0 end return 0, 0 end
  C_Container.GetContainerItemInfo = function(b, s) return b == 0 and bolsa[s] or nil end
  C_Container.GetContainerItemLink = function(b, s) local i = b == 0 and bolsa[s] return i and i.hyperlink or nil end
  C_Container.GetContainerItemID = function(b, s) local i = b == 0 and bolsa[s] return i and i.itemID or nil end
  C_Container.GetContainerItemQuestInfo = function() return { isQuestItem = false } end
  C_Container.GetContainerItemCooldown = function() return 0, 0, 0 end
  B.Ventana.MostrarBolsas(true)
  local w = B.Ventana.Ventana("bolsas")
  local function bombear()
    for _ = 1, 80 do
      local fn = w:GetScript("OnUpdate")
      if not fn then break end
      fn(w, 0.02)
    end
  end
  bombear()
  check(w.Separar and w.Separar:IsShown(), "no está el botón «Separar» en tus bolsas")
  if w.Separar then w.Separar:Click() end
  check(Sp.Activo(), "el botón no prendió «Separar»")
  bombear()
  local marcas = 0
  for b2 in pairs(w.puestos or {}) do
    local p2 = B.Botones.Partes[b2]
    if p2 and p2.separa and p2.separa:IsShown() then marcas = marcas + 1 end
  end
  check(marcas == 2, "no salieron las 2 marcas en tus bolsas: " .. marcas)
  check(w.SepTexto and w.SepTexto:IsShown() and (w.SepTexto:GetText() or ""):find("1 subasta", 1, true), "el pie no dice cuántos van a cada lado")
  check(w.SepMarcar and w.SepMarcar:IsShown(), "no salió «Marcar 1 para vender»")
  w:ClearAllPoints()
  w:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  SNAP("bolsas", w, {})
  B.Ventana.MostrarBolsas(false)
  for k, v in pairs(CC) do C_Container[k] = v end
  check(not Sp.Activo(), "«Separar» siguió prendido al cerrar las bolsas")
  S.Estado = estado
end)

---------------------------------------------------------------------------
-- 19. El jefe en una línea
---------------------------------------------------------------------------
step("19. el jefe en una línea: lo más importante, sin ratón", function()
  local Ev = Mz.EnVivo
  check(A.Get("mazmorras.enVivoForma") == "linea", "la forma de fábrica no es la línea")
  local jefe = { nombre = "Comandante Vallefont", consejos = {
    { "Aturde al tanque con su martillo: mantén la vida del tanque alta.", "x", rol = "cura" },
    { "Es un paladín: se cura con luz sagrada. Interrumpe su curación.", "He is a paladin. Interrupt his heal." },
  } }
  local c = Ev.LoMasImportante(jefe, "dano")
  check(c and c:find("Interrumpe", 1, true), "lo más importante no es interrumpir: " .. tostring(c))
  local papel = Ev.Papel
  Ev.Papel = function() return "dano" end
  check(Ev.Mostrar("shadowfang-keep", jefe), "no salió la línea")
  local tl = Ev.Linea()
  check(tl and tl:IsShown() and tl:IsMouseEnabled() == false, "la línea no salió o atrapa clics")
  check(not (Ev.Marco() and Ev.Marco():IsShown()), "con la línea salió también la tarjeta")
  local s = texto(tl and tl.Texto)
  check(s:find("Vallefont", 1, true) and s:find("Interrumpe", 1, true), "la línea no dice jefe y consejo: " .. s)
  check(tl:GetWidth() <= 440 + 0.5, "la línea es más ancha de la cuenta")
  SNAP("jefe", tl, {})
  -- Un consejo largo baja a dos líneas sin salirse.
  jefe.consejos[2][1] = "Es un paladín muy terco que se cura con luz sagrada cada pocos segundos durante toda la pelea: interrumpe su curación siempre que puedas."
  Ev.Mostrar("shadowfang-keep", jefe)
  check(tl:GetHeight() > 30, "el consejo largo no bajó de línea")
  Ev.Ocultar()
  check(not Ev.Visible(), "la línea no se fue")
  A.Set("mazmorras.enVivoForma", "tarjeta")
  Ev.Mostrar("shadowfang-keep", jefe)
  check(Ev.Marco() and Ev.Marco():IsShown() and not tl:IsShown(), "con «tarjeta» no salió la de antes")
  Ev.Ocultar()
  A.Set("mazmorras.enVivoForma", nil)
  Ev.Papel = papel
end)

---------------------------------------------------------------------------
-- 20. El resumen al terminar una mazmorra
---------------------------------------------------------------------------
step("20. resumen de la mazmorra: tiempo, récord, daño y botín", function()
  local Rs = Mz.ResumenVuelta
  check(type(Rs) == "table", "falta Mazmorras/Resumen.lua")
  if not Rs then return end
  local d = N.DatosPersonaje("mazmorras")
  d.vuelta = { key = "deadmines", inicio = (Mz.D.Ahora() or 0) - 1500, visto = Mz.D.Ahora(), dano0 = 1000, cura0 = 0 }
  local lsi = rawget(_G, "LOOT_ITEM_SELF")
  LOOT_ITEM_SELF = "Recibes botín: %s."
  check(Rs.Anotar("Recibes botín: |cff1eff00|Hitem:5191::::::::|h[Hacha de Cruel]|h|r."), "no anotó tu botín")
  Rs.Anotar("Recibes botín: |cff9d9d9d|Hitem:4865::::::::|h[Garra rota]|h|r.")
  check(not Rs.Anotar("Bigotes recibe botín: |cff0070dd|Hitem:5193::::::::|h[Capa]|h|r."), "anotó el botín de otro")
  d.crono = d.crono or {}
  d.crono.deadmines = { mejor = 1800, veces = 2 }
  local r = Mz.Crono.Fin("deadmines")
  check(r and r.record and r.vuelta and r.vuelta.objetos == 2 and #r.vuelta.botin == 1, "Cr.Fin no trae la vuelta con su botín")
  local C = rawget(_G, "AlfaCombate")
  local leer = C and C.LeerMedidor
  if C then C.LeerMedidor = function(s, tipo) return { ok = true, filas = { { yo = true, valor = tipo == "dano" and 46000 or 0 } } } end end
  check(Rs.Mostrar("deadmines", r, 3, { texto = "Ver tu progreso", alClic = function() end }), "no quiso mostrar el resumen")
  -- (Sin RUN_TIMERS: el banco correría ya la espera que la esconde.)
  local t = Rs.Marco()
  check(t and t:IsShown(), "no salió la tarjeta del resumen")
  local todo = table.concat(todoTexto(t), " | ")
  check(todo:find("Récord", 1, true) and todo:find("Vuelta 3", 1, true), "no dice récord ni la vuelta: " .. todo)
  check(todo:find("Tu daño", 1, true) and todo:find("45", 1, true), "no dice tu daño de la vuelta (46000 - 1000): " .. todo)
  check(todo:find("objetos de botín", 1, true), "no dice tu botín: " .. todo)
  -- Nada se sale de la tarjeta.
  for _, c2 in ipairs(t.Cifras) do
    if c2:IsShown() then check(c2:GetRight() <= t:GetRight() + 0.5, "una cifra se sale de la tarjeta") end
  end
  t:SetAlpha(1) -- (la entrada animada: el banco no la corre)
  SNAP("mazmorra", t, {})
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  check(not t:IsShown(), "la tarjeta siguió al entrar en combate")
  A.Set("mazmorras.resumenFin", false)
  check(not Rs.Mostrar("deadmines", r, 3), "apagado, quiso mostrar el resumen")
  A.Set("mazmorras.resumenFin", nil)
  if C then C.LeerMedidor = leer end
  LOOT_ITEM_SELF = lsi
end)

---------------------------------------------------------------------------
-- 21. La escala de las ventanas
---------------------------------------------------------------------------
step("21. la escala de las ventanas de Alfa", function()
  check(K.EscalaVentanas() == 1, "la escala de fábrica no es 100 %")
  A.Set("nucleo.escalaVentanas", 1.2)
  local v = K.Ventana({ nombre = "AlfaPrueba138Escala", titulo = "Prueba" })
  check(math.abs(v:GetScale() - 1.2) < 0.001, "una ventana nueva no tomó la escala")
  local m = K.Ventana({ nombre = "AlfaPrueba138Medio", titulo = "Medio", capa = "MEDIUM" })
  check(math.abs(m:GetScale() - 1) < 0.001, "una pieza de la capa MEDIUM cambió de escala")
  A.Set("nucleo.escalaVentanas", 0.9)
  check(math.abs(v:GetScale() - 0.9) < 0.001, "al cambiar el ajuste, la ventana no se reescaló")
  A.Set("nucleo.escalaVentanas", 5)
  check(K.EscalaVentanas() == 1.3, "la escala no tiene tope")
  A.Set("nucleo.escalaVentanas", nil)
  check(math.abs(v:GetScale() - 1) < 0.001, "al volver a 100 % la ventana no volvió")
end)

---------------------------------------------------------------------------
-- 22. Modo Zen
---------------------------------------------------------------------------
step("22. modo Zen: solo la flecha y luego todo como estaba", function()
  check(type(AlfaZen) == "table", "falta AlfaZen")
  if not AlfaZen then return end
  local oculto, flecha = false, false
  local h, sh, kf, skf = A.Hidden, A.SetHidden, A.HideKeepsArrow, A.SetHideKeepsArrow
  A.Hidden = function() return oculto end
  A.HideKeepsArrow = function() return flecha end
  A.SetHidden = function(on) oculto = on and true or false A.Fire("ALFA_HIDDEN", oculto) end
  A.SetHideKeepsArrow = function(on) flecha = on and true or false end
  AlfaZen.Alternar()
  check(oculto and flecha and AlfaZen.Activo(), "el Zen no escondió Alfa con la flecha")
  check(AlfaZen.TextoMenu():find("Salir", 1, true), "el menú no dice «Salir del modo Zen»")
  AlfaZen.Alternar()
  check(not oculto and not flecha and not AlfaZen.Activo(), "al salir no volvió todo (ni el ajuste de la flecha)")
  -- Mostrar Alfa por otro camino termina el Zen.
  AlfaZen.Alternar(true)
  A.SetHidden(false)
  check(not AlfaZen.Activo() and not flecha, "mostrar Alfa de otra forma no terminó el Zen")
  -- El menú de Alfa lo trae.
  local O = A.UI and A.UI.Options
  local hay = false
  for _, it in ipairs(O and O.MenuItems and O.MenuItems(UIParent) or {}) do
    if type(it.text) == "string" and it.text:find("Zen", 1, true) then hay = true end
  end
  check(hay, "el menú de Alfa no trae el modo Zen")
  check(rawget(_G, "BINDING_NAME_ALFA_ZEN") ~= nil, "falta el nombre de la tecla del Zen")
  A.Hidden, A.SetHidden, A.HideKeepsArrow, A.SetHideKeepsArrow = h, sh, kf, skf
end)

---------------------------------------------------------------------------
-- 23. Lo más usado
---------------------------------------------------------------------------
step("23. «Lo más usado»: lo que cambias tú, arriba", function()
  local Us = Bv.Usados
  check(type(Us) == "table", "falta Usados.lua")
  if not Us then return end
  Us.Olvidar()
  -- Lo que cambia Alfa sola no cuenta.
  A.Set("comercio.gangas", false)
  check(#Us.Lista() == 0, "contó un cambio que no hiciste tú")
  A.Set("comercio.gangas", nil)
  Us.Anotar("comercio.gangas")
  Us.Anotar("comercio.gangas")
  Us.Anotar("comercio.comision")
  Us.Anotar("no.existe")
  local l = Us.Lista()
  check(#l == 2 and l[1].clave == "comercio.gangas" and l[2].clave == "comercio.comision", "el orden de lo más usado no cuadra")
  check(l[1] and l[1].c.kind == "toggle" and l[2].c.kind == "slider" and l[1].c.page, "no trae el control de cada ajuste")
  local g = Us.Grupo(UIParent)
  g:Refrescar()
  check(g:IsShown(), "con ajustes usados no salió la tarjeta")
  local h = g:Acomodar(600)
  check(h > 40, "la tarjeta no tiene alto")
  SNAP("usados", g, {})
  Us.Olvidar()
  g:Refrescar()
  check(not g:IsShown() or g.alfaOculto, "sin nada usado salió la tarjeta")
  g:Hide()
end)

---------------------------------------------------------------------------
-- 24. Temporada
---------------------------------------------------------------------------
step("24. temporada: fechas y el adorno solo prendido", function()
  check(K.TemporadaDe(10, 31) and K.TemporadaDe(10, 31).clave == "brujas", "el 31 de octubre no es Noche de Brujas")
  check(K.TemporadaDe(12, 31).clave == "invierno" and K.TemporadaDe(1, 1).clave == "invierno", "la Fiesta de Invierno no cruza el año")
  check(K.TemporadaDe(2, 14).clave == "amor" and K.TemporadaDe(6, 24).clave == "fuego", "faltan Amor en el aire o el Fuego")
  check(K.TemporadaDe(11, 23) == nil, "el 23 de noviembre salió una fiesta")
  check(A.Get("nucleo.temporada") == false, "la temporada viene prendida de fábrica")
  K.fechaPrueba = { 10, 31 }
  local v = K.Ventana({ nombre = "AlfaPrueba138Temp", titulo = "Temporada" })
  check(not (v.Cabecera.alfaAdorno and v.Cabecera.alfaAdorno:IsShown()), "apagado salió el adorno")
  A.Set("nucleo.temporada", true)
  check(v.Cabecera.alfaAdorno and v.Cabecera.alfaAdorno:IsShown() and v.Cabecera.alfaTemporada == "brujas", "prendido no salió la calabaza")
  v:Abrir()
  SNAP("temporada", v, {})
  v:Cerrar()
  -- La pregunta, una sola vez por fiesta.
  A.Set("nucleo.temporada", nil)
  N.Datos("kit").temporadaElegida, N.Datos("kit").temporadaPreguntada = nil, nil
  check(K.PreguntarTemporada() == true, "no preguntó al llegar la fiesta")
  check(K.PreguntarTemporada() == false, "preguntó dos veces")
  K.fechaPrueba = nil
  K.AdornarTodas()
end)

---------------------------------------------------------------------------
-- El resumen de cada pelea: apagado de fábrica, guardado igual
---------------------------------------------------------------------------
step("resumen de cada pelea: apagado de fábrica y se guarda igual", function()
  check(A.Get("combate.resumen") == false, "el resumen de cada pelea viene prendido")
  local Rs = Cb.Resumen
  local d = N.DatosPersonaje("combate")
  d.ultimaPelea = nil
  local f = rawget(_G, "AlfaCombateResumen")
  if f then f:Hide() end
  Rs.Empieza()
  local GT = GetTime
  local t0 = GT()
  GetTime = function() return t0 + 40 end
  Rs.Termina()
  T(3)
  GetTime = GT
  f = rawget(_G, "AlfaCombateResumen")
  check(not (f and f:IsShown()), "apagado, salió la tarjeta tras la pelea")
  check(type(d.ultimaPelea) == "table", "apagado, no guardó la última pelea")
  local hay = false
  for _, o in ipairs(Cb.Ventana and Cb.Ventana.Opciones and Cb.Ventana.Opciones() or {}) do
    if o.valor == "pelea" and not o.apagada then hay = true end
  end
  check(hay, "el menú del medidor no trae «Ver mi última pelea»")
end)

print(("PRUEBA: 1.3.8 oficios, %d pasos, errores: %d"):format(pasos, #ERRORS))
