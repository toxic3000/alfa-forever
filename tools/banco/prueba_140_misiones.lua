-- Prueba de la 1.4.0, área misiones (tools/prueba.py la corre con las demás prueba_*.lua):
--   7.  /alfa confirmar: la lista guiada, «Funciona / No funciona / Saltar»,
--       lo guardado en AlfaNucleoDB y adjunto al reporte del Lobo Malo;
--   25. el rastreador: «12 de 80 pasos · 15 % · ≈ 40 min», que quepa;
--   26. «Saltar a mi nivel»: la guía atrás de tu nivel y el salto;
--   27. abandonar una misión de una cadena valiosa: el aviso con su valor;
--   28. «Elige: …» bajo una entrega;
--   29. el PNJ de la entrega en el minimapa al acercarte;
--   30. «Cerrar mis misiones» con la vuelta a la ciudad;
--   31. «Comprar lo que falta» de una guía de oficio (sin sumar dos veces);
--   32. el historial de guías terminadas;
--   70. la banda de color del título del rastreador, completa y alineada.
-- Con BANCO_FOTOS=1 dibuja las capturas (shot-140-misiones-*.png).
SNAPSHOTS = {}
local FOTOS = os and os.getenv and os.getenv("BANCO_FOTOS")
local function SNAP(name, root, extra)
  if not FOTOS then return end
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS["140-misiones-" .. name] = { entries = entries, l = l, b = b, w = w, h = h }
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
local function check(cond, msg) if not cond then NOTE("1.4.0 misiones", msg) end end
local function T(n) RUN_TIMERS(n or 2) end

function UnitFactionGroup() return "Alliance", "Alianza" end
function UnitRace() return "Humano", "Human", 1 end
local NIVEL_PJ = 18
function UnitLevel() return NIVEL_PJ end
function UnitEffectiveLevel() return NIVEL_PJ end
C_Map.GetBestMapForUnit = function() return 1436 end
local PX, PY = 0.56, 0.47
C_Map.GetPlayerMapPosition = function() return { x = PX, y = PY, GetXY = function() return PX, PY end } end

local LOG, ORDEN, HECHAS = {}, {}, {}
local function poner(q, listo)
  if not LOG[q] then ORDEN[#ORDEN + 1] = q end
  LOG[q] = { listo = listo, objs = { { text = "Algo: 0/5", type = "monster", finished = listo, numFulfilled = listo and 5 or 0, numRequired = 5 } } }
end
local QL = C_QuestLog
QL.IsOnQuest = function(q) return LOG[q] ~= nil end
QL.ReadyForTurnIn = function(q) return LOG[q] ~= nil and LOG[q].listo or false end
QL.IsComplete = function(q) return LOG[q] ~= nil and LOG[q].listo or false end
QL.IsFailed = function() return false end
QL.GetQuestObjectives = function(q) return LOG[q] and LOG[q].objs or {} end
QL.GetNumQuestLogEntries = function() return #ORDEN, #ORDEN end
QL.GetInfo = function(i) local q = ORDEN[i] return q and { questID = q, title = "Misión " .. q, isHeader = false, isHidden = false, level = 18 } or nil end
QL.GetLogIndexForQuestID = function(q) for i, x in ipairs(ORDEN) do if x == q then return i end end return nil end
QL.IsQuestFlaggedCompleted = function(q) return HECHAS[q] or false end
QL.GetTitleForQuestID = function(q) return LOG[q] and ("Misión " .. q) or nil end
QL.GetQuestDifficultyLevel = function() return 18 end
local function registro() FIRE_EVENT("QUEST_LOG_UPDATE") T(3) end

Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(10)
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
registro()

local A = Alfa
local N = AlfaNucleo
local K = AlfaNucleo.Kit
local E = A.Engine
local Ru = NS_OF("Alfa_Rutas")
local Rs = Ru.Rastreador

-- Los avisos que salen (título y texto), para revisarlos.
local avisos = {}
local avisoReal = K.Aviso
K.Aviso = function(o)
  avisos[#avisos + 1] = o
  return avisoReal(o)
end
local function ultimoAviso() return avisos[#avisos] end

-- Todas las letras a la vista bajo un marco.
local function letras(f, out)
  out = out or {}
  if not f:IsShown() then return out end
  if f._kind == "FontString" and f._text then out[#out + 1] = f._text end
  for _, h in ipairs(rawget(f, "_children") or {}) do letras(h, out) end
  for _, r in ipairs(rawget(f, "_regions") or {}) do if r._kind == "FontString" and r:IsShown() and r._text then out[#out + 1] = r._text end end
  return out
end
local function dice(f, s)
  for _, t in ipairs(letras(f)) do if t:find(s, 1, true) then return true end end
  return false
end

-- Una guía de prueba (en «Mis rutas»).
local function guia(nombre, pasosGuia)
  local id = Ru.Guias.IdRuta(nombre)
  local def = Ru.Guias.Def(id, nombre, pasosGuia)
  local ok, err = Ru.Guias.Instalar(def)
  check(ok, "no se instaló la guía " .. nombre .. ": " .. tostring(err))
  Ru.Guias.Abrir(id) T(3)
  return id
end

-- Un paso de ir a un lugar lejos de ti (queda abierto).
local function va(i) return { t = "goto", map = 1436, x = 10 + (i % 20) * 3, y = 85, text = "Ve al lugar " .. i } end
local function acepta(q) return { t = "accept", quest = q, title = "Misión " .. q, npc = 100 + q, npcName = "PNJ " .. q, map = 1436, x = 50, y = 50 } end

---------------------------------------------------------------------------
step("25: el avance y el tiempo que falta en la cabecera", function()
  local p = {}
  for i = 1, 10 do p[i] = { title = "Paso " .. i, goals = { va(i) } } end
  guia("prueba140-avance", p)
  local done, total = E.GetProgress()
  check(total == 10, "la guía de prueba no tiene 10 pasos: " .. tostring(total))
  local largo, medio = Rs.AvanceTexto(3, 10)
  check(medio and medio:find("30 %", 1, true), "sin el %: " .. tostring(medio))
  check(largo == medio, "sin medidas no debe decir el tiempo: " .. tostring(largo))
  for _ = 1, 6 do Ru.Hora.Muestra(120) end
  largo = Rs.AvanceTexto(3, 10)
  check(largo and largo:find("≈", 1, true) and largo:find("más", 1, true), "con tu ritmo no dice el tiempo: " .. tostring(largo))
  check(Rs.AvanceTexto(9, 10):find("90 %", 1, true), "el 90 % no sale")
  check(not Rs.AvanceTexto(0, 0), "sin pasos no debe decir nada")
  A.Set("rutas.avanceTiempo", false)
  check(not Rs.AvanceTexto(3, 10), "apagado sigue saliendo")
  A.Set("rutas.avanceTiempo", true)
  Rs.Mostrar() T(2) Rs.Pintar()
  local c = Rs.Piezas().cab
  check(c and c.Sub:GetText() and c.Sub:GetText():find("%", 1, true), "la cabecera no dice el %: " .. tostring(c and c.Sub:GetText()))
  check(K.AnchoTexto(c.Sub) <= (c.alfaAnchoTitulo or 224) + 0.5, "la línea de la cabecera no cabe: " .. tostring(c.Sub:GetText()))
  -- Un nombre de guarida largo: se quita lo que no cabe, nunca se corta.
  AlfaManada = AlfaManada or {}
  local guarida = AlfaManada.Guarida
  AlfaManada.Guarida = function() return "Guarida del Colmillo Plateado de la Montaña" end
  Rs.Pintar()
  check(K.AnchoTexto(c.Sub) <= (c.alfaAnchoTitulo or 224) + 0.5, "con la guarida no cabe: " .. tostring(c.Sub:GetText()))
  AlfaManada.Guarida = guarida
end)

step("70: la banda del título, completa y alineada", function()
  local F = rawget(_G, "AlfaRastreador")
  check(F and F.Marca == nil, "sigue la rayita corta del rastreador")
  local c = Rs.Piezas().cab
  local b = c and c.Banda
  check(b ~= nil, "la cabecera no tiene banda")
  if not b then return end
  check(math.abs(b:GetWidth() - (F:GetWidth() - 2)) < 1, "la banda no va de lado a lado: " .. b:GetWidth() .. " de " .. F:GetWidth())
  check(math.abs(b:GetHeight() - (c:GetHeight() - 1)) < 1, "la banda no cubre la cabecera: " .. b:GetHeight() .. " / " .. c:GetHeight())
  check(b.Arriba and b.Arriba:IsShown(), "sin la línea de acento arriba")
  -- El título y sus datos adentro de la banda.
  local _, bt = b:GetCenter()
  local bTop, bBot = b:GetTop(), b:GetBottom()
  for _, fs in ipairs({ c.Titulo, c.Sub }) do
    if fs:IsShown() and fs:GetText() and fs:GetText() ~= "" then
      check(fs:GetTop() <= bTop + 0.5 and fs:GetBottom() >= bBot - 0.5, "un texto se sale de la banda: " .. tostring(fs:GetText()))
    end
  end
  -- El avance, en el borde de abajo de la banda y de lado a lado.
  if c.Avance:IsShown() then
    check(math.abs(c.Avance:GetBottom() - bBot) < 1 and math.abs(c.Avance:GetWidth() - b:GetWidth()) < 1, "el avance no va en el borde de la banda")
  end
  -- El ícono y los botones, centrados en la banda.
  local _, iy = c.Icono:GetCenter()
  local _, cy = c.Cerrar:GetCenter()
  check(math.abs(iy - cy) < 1.5 and math.abs(iy - bt) < 2, "el ícono y los botones no van alineados")
  SNAP("rastreador", F)
  -- Repintar con una guía sin nombre (GuideLabel nil y sin título) no da
  -- errores (el agente de bolsas vio K.Escribir(nil) a medio cambio).
  local gl = A.UI.GuideLabel
  A.UI.GuideLabel = function() return nil end
  local gg = E.GetGuide
  E.GetGuide = function() local g = gg() if g then return setmetatable({ title = false }, { __index = g }) end end
  local antesE = #ERRORS
  Rs.Pintar()
  E.GetGuide, A.UI.GuideLabel = gg, gl
  check(#ERRORS == antesE, "repintar una guía sin nombre da error")
  -- «Buscar cerca» también.
  Ru.Cerca.Menu(nil) T(2)
  local C = rawget(_G, "AlfaCercaMenu")
  check(C and C.Banda and C.Marca == nil, "«Buscar cerca» sin su banda")
  if C then SNAP("cerca", C) end
  Ru.Cerca.Cerrar()
end)

---------------------------------------------------------------------------
step("26: «Saltar a mi nivel»", function()
  local p = {}
  -- (entregas de misiones que llevas sin terminar: el motor no las da por pasadas)
  for i = 1, 14 do
    poner(9100 + i, false)
    p[i] = { title = "Paso " .. i, goals = { { t = "kill", target = "Jabalí " .. i, count = 5, map = 1436, x = 10 + i * 3, y = 85 } } }
  end
  registro()
  p[4].goals[#p[4].goals + 1] = { t = "level", level = 12 }
  p[9].goals[#p[9].goals + 1] = { t = "level", level = 15 }
  p[12].goals[#p[12].goals + 1] = { t = "level", level = 22 }
  guia("prueba140-nivel", p)
  Ru.MiNivel.Olvidar()
  local live = E.GetLiveStep()
  check(live == 1, "la guía no empieza en el 1: " .. tostring(live))
  local d = Ru.MiNivel.Destino()
  check(d and d.paso == 10 and d.meta == 15 and d.nivel == 18, "el destino no es el paso 10: " .. tostring(d and d.paso))
  local av = Rs.AvisoDeAhora()
  check(av and av.titulo and av.titulo:find("atrás de tu nivel", 1, true), "el rastreador no lo ofrece: " .. tostring(av and av.titulo))
  check(av and av.uno and av.uno[1] == "Saltar a mi nivel", "sin el botón «Saltar a mi nivel»")
  if av and av.uno then av.uno[2]() end
  T(3)
  check(E.GetLiveStep() == 10, "no saltó al paso 10: " .. tostring(E.GetLiveStep()))
  Ru.MiNivel.Olvidar()
  check(Ru.MiNivel.Destino() == nil, "después de saltar lo sigue ofreciendo")
  -- A tu nivel justo, no ofrece nada.
  NIVEL_PJ = 12
  if Ru.Restablecer.PuedeDeshacer() then Ru.Restablecer.Deshacer() end
  T(3)
  Ru.MiNivel.Olvidar()
  check(Ru.MiNivel.Destino() == nil, "a nivel 12 no debe ofrecer saltar (la meta de 12 es justo tu nivel)")
  NIVEL_PJ = 18
  Ru.MiNivel.Olvidar()
end)

---------------------------------------------------------------------------
step("27: abandonar una misión de una cadena valiosa", function()
  local Ch = Ru.Cadenas
  local sig, val, de = Ch.Siguiente, Ch.Valor, Ru.Cadena.De
  Ch.Siguiente = function() return 9201, "La segunda" end
  Ru.Cadena.De = function(q)
    return { lista = { { qid = 9200, estado = "esta" }, { qid = 9201, estado = "falta" }, { qid = 9202, estado = "falta" } }, premio = {} }
  end
  local v = Ch.Valor(9200)
  check(v and v.siguen == 2 and v.valiosa, "la cadena de 2 no es valiosa: " .. tostring(v and v.siguen))
  check(v and v.texto:find("Abre 2 misiones más", 1, true), "no dice cuántas abre: " .. tostring(v and v.texto))
  local get = QL.GetAbandonQuest
  QL.GetAbandonQuest = function() return 9200 end
  local antes = #avisos
  Ch.AlAbandonar()
  local o = ultimoAviso()
  check(#avisos > antes and o.titulo:find("valiosa", 1, true), "el aviso no dice que es valiosa: " .. tostring(o and o.titulo))
  check(o and o.texto:find("La segunda", 1, true) and o.texto:find("Abre 2", 1, true), "el aviso no dice el valor: " .. tostring(o and o.texto))
  check(o and o.accion and o.accion.texto == "Ver la cadena", "sin «Ver la cadena»")
  -- Apagado, no avisa.
  A.Set("rutas.avisoCadena", false)
  QL.GetAbandonQuest = function() return 9300 end
  antes = #avisos
  Ch.AlAbandonar()
  check(#avisos == antes, "apagado sigue avisando")
  A.Set("rutas.avisoCadena", true)
  QL.GetAbandonQuest = get
  Ch.Siguiente, Ru.Cadena.De = sig, de
end)

---------------------------------------------------------------------------
step("28: qué recompensa elegir", function()
  local u = A.UI
  local gp = u.GearPick
  u.GearPick = { PickFor = function(g)
    if g.quest == 9400 then return { upgrade = true, entry = { id = 2488, upgrade = true, pct = 0.12 } } end
    if g.quest == 9401 and g.t == "turnin" then return { upgrade = false, entry = { id = 2489, upgrade = false } } end
    return nil
  end }
  Ru.Recompensa.Olvidar()
  local t1 = Ru.Recompensa.Texto({ t = "turnin", quest = 9400 })
  check(t1 and t1:find("Elige:", 1, true), "no dice qué elegir: " .. tostring(t1))
  local t2 = Ru.Recompensa.Texto({ t = "turnin", quest = 9401 })
  check(t2 and t2:find("Elige:", 1, true) and not t2:find("(", 1, true), "sin mejora no debe decir ganancia: " .. tostring(t2))
  check(Ru.Recompensa.Texto({ t = "turnin", quest = 9402 }) == nil, "sin elección no debe decir nada")
  -- En el rastreador, bajo la entrega de ahora.
  poner(9400, true)
  registro()
  guia("prueba140-recompensa", { { title = "Entrega la 9400", goals = { { t = "turnin", quest = 9400, title = "Misión 9400", npc = 200, npcName = "Gryan Mantorrecio", map = 1436, x = 56.2, y = 47.1 } } } })
  Rs.Mostrar() T(2) Rs.Pintar()
  check(dice(rawget(_G, "AlfaRastreador"), "Elige:"), "el rastreador no dice «Elige: …» bajo la entrega")
  A.Set("rutas.recompensaGuia", false) T(1)
  check(Ru.Recompensa.Texto({ t = "turnin", quest = 9400 }) == nil, "apagado sigue diciendo qué elegir")
  A.Set("rutas.recompensaGuia", true) T(1)
  u.GearPick = gp
end)

---------------------------------------------------------------------------
step("29: el PNJ de la entrega en el minimapa", function()
  -- (sigue la guía de la entrega de 9400, junto a ti)
  local g = Ru.Entrega.Meta()
  check(g and g.quest == 9400, "no encuentra la entrega de ahora")
  -- (el banco no trae los límites de los mapas: yardas a mano)
  local Cp = A.Compat
  local m2w, pwp = Cp.MapToWorld, Cp.GetPlayerWorldPosition
  Cp.MapToWorld = function(_, x, y) return 0, x * 10, y * 10 end
  Cp.GetPlayerWorldPosition = function() return 0, PX * 1000, PY * 1000 end
  local puesto = Ru.Entrega.Revisar()
  local pin, quien = Ru.Entrega.Pin()
  check(puesto and pin and pin.icon == "map:quest-turnin", "cerca de la entrega no hay marca en el minimapa")
  check(quien == "Gryan Mantorrecio", "la marca no sabe a quién: " .. tostring(quien))
  -- Lejos: se quita.
  PX, PY = 0.20, 0.20
  check(not Ru.Entrega.Revisar(), "lejos sigue la marca")
  -- Posición secreta (combate o mazmorra): sin errores, se queda como estaba.
  PX, PY = 0.56, 0.47
  Ru.Entrega.Revisar()
  local real = C_Map.GetPlayerMapPosition
  C_Map.GetPlayerMapPosition = function() return { x = SECRETO(0.3), y = SECRETO(0.3), GetXY = function() return SECRETO(0.3), SECRETO(0.3) end } end
  Ru.Entrega.Revisar()
  C_Map.GetPlayerMapPosition = real
  A.Set("rutas.entregaMinimapa", false) T(1)
  check(not Ru.Entrega.Revisar(), "apagado sigue la marca")
  A.Set("rutas.entregaMinimapa", true)
  Cp.MapToWorld, Cp.GetPlayerWorldPosition = m2w, pwp
end)

---------------------------------------------------------------------------
step("30: al final, a la ciudad: entrenar y vender", function()
  local Cd = Ru.Ciudad
  local fuimos = {}
  local ir = Ru.Cerca.Ir
  Ru.Cerca.Ir = function(tipo) fuimos[#fuimos + 1] = tipo return true end
  A.QoL = A.QoL or {}
  local sp = A.QoL.Spells
  A.QoL.Spells = { NewAt = function(l) if l == 18 then return { { cost = 100 }, { cost = 200 } } end return {} end }
  check(Cd.PorEntrenar() == 2, "no cuenta las habilidades por entrenar")
  -- Del festejo de «Cerrar mis misiones» con el interruptor prendido.
  A.Set("rutas.cerrarCiudad", true)
  Ru.Personaje().cerrarCuenta = { inicio = time() - 300, xp = 0, n = 2, dentro = {}, hechas = {}, ciudad = true }
  Ru.CerrarTodo.Festejar(Ru.Personaje().cerrarCuenta)
  T(12)
  check(fuimos[1] == "class", "no fue primero al entrenador: " .. tostring(fuimos[1]))
  FIRE_EVENT("TRAINER_CLOSED") T(3)
  check(fuimos[2] == "repair", "no pasó a reparar y vender: " .. tostring(fuimos[2]))
  FIRE_EVENT("MERCHANT_CLOSED") T(3)
  check(Cd.Estado() == nil, "la vuelta a la ciudad no terminó")
  -- Sin nada que entrenar: solo reparar.
  A.QoL.Spells = { NewAt = function() return {} end }
  local par = Cd.Paradas()
  check(#par == 1 and par[1] == "repair", "sin nada que entrenar no debe ir al entrenador")
  A.QoL.Spells = sp
  Ru.Cerca.Ir = ir
  A.Set("rutas.cerrarCiudad", false)
end)

---------------------------------------------------------------------------
step("31: «Comprar lo que falta» en una guía de oficio", function()
  local Of = Ru.OficiosGuia
  local linea, aqui, precio = Of.LineaDe, Of.Aqui, Of.Precio
  local id = Ru.Guias.IdRuta("prueba140-oficio")
  Of.LineaDe = function(x) if x == id then return 164 end return linea(x) end
  Of.Aqui = function(item) if item == 2840 then return 6 end return 0 end
  Of.Precio = function(item) if item == 2840 then return 50 end if item == 2589 then return 20 end return nil end
  guia("prueba140-oficio", {
    { title = "Tus materiales para 1–75", section = 1, goals = {
      { t = "collect", item = 2840, itemName = "Barra de cobre", count = 24 },
      { t = "collect", item = 2589, itemName = "Paño de lino", count = 10 },
    } },
    { title = "Haz 20 Cinturón de cobre", section = 1, goals = { { t = "note", text = "Fabrica" } } },
  })
  local f, total = Ru.Comprar.Faltan()
  check(f and #f == 2, "no encuentra los 2 materiales: " .. tostring(f and #f))
  check(f and f[1].faltan == 18, "no descuenta lo que traes: " .. tostring(f and f[1] and f[1].faltan))
  check(total == 18 * 50 + 10 * 20, "el costo no cuadra: " .. tostring(total))
  local av = Rs.AvisoDeAhora()
  check(av and av.uno and av.uno[1] == "Comprar lo que falta", "el rastreador no ofrece «Comprar lo que falta»: " .. tostring(av and av.titulo))
  local Li = AlfaComercio and AlfaComercio.Lista
  check(Li ~= nil, "no está la lista de Comercio")
  if Li then
    Li.Vaciar()
    check(Ru.Comprar.Agregar() == 2, "no pasó los 2 a la lista")
    Ru.Comprar.Agregar()
    local n, cobre = 0, nil
    for _, m in ipairs(Li.Metas()) do
      if m.id == 2840 then n = n + 1 cobre = m.n end
    end
    check(n == 1 and cobre == 18, "pedirlo dos veces sumó o repitió: " .. n .. " · " .. tostring(cobre))
    Li.Vaciar()
  end
  Of.LineaDe, Of.Aqui, Of.Precio = linea, aqui, precio
end)

---------------------------------------------------------------------------
step("32: el historial de guías terminadas", function()
  local Hi = Ru.Historial
  local x = Hi.Anotar({ id = "mis-rutas/prueba140-hecha", title = "Bosque de Elwynn (1–10)" })
  check(x and x.nombre and x.fin, "no anotó la guía terminada")
  check(Hi.Anotar({ id = "mis-rutas/prueba140-hecha", title = "Bosque de Elwynn (1–10)" }) == nil, "la anotó dos veces")
  check(Hi.Anotar({ id = Ru.Guias.IdLiberar(), title = "Cerrar mis misiones" }) == nil, "anotó un plan de un clic")
  x.seg, x.nivel0, x.nivel1, x.pasos = 4500, 6, 10, 80
  local t = Hi.TextoDe(x)
  check(t:find("del nivel 6 al 10", 1, true) and t:find("80 pasos", 1, true) and t:find("1 h", 1, true), "el renglón no dice nivel, pasos y tiempo: " .. t)
  -- Una guía de verdad que se termina: se anota sola.
  HECHAS[9501], HECHAS[9502] = true, true
  guia("prueba140-hecha2", { { title = "Uno", goals = { acepta(9501) } }, { title = "Dos", goals = { acepta(9502) } } })
  Hi.Revisar()
  local ultimo = Hi.Lista()[#Hi.Lista()]
  check(ultimo and ultimo.id == Ru.Guias.IdRuta("prueba140-hecha2"), "la guía terminada no se anotó sola: " .. tostring(ultimo and ultimo.id))
  -- La tarjeta de «¡Terminaste!» del rastreador, con su banda (70).
  Rs.Mostrar() T(2) Rs.Pintar()
  local fin = Rs.Piezas().fin
  if fin and fin:IsShown() then
    check(fin.Banda and fin.Banda:GetHeight() > 40 and fin.Marca == nil, "la tarjeta de fin sin su banda completa")
    SNAP("fin", rawget(_G, "AlfaRastreador"))
  end
  local v = Hi.Abrir() T(2)
  check(v and v:IsShown(), "no abre «Guías terminadas»")
  SNAP("historial", v)
  v:Cerrar()
  -- En la página Ruta y el menú del rastreador.
  local hay = false
  for _, o in ipairs(Ru.OpcionesPagina()) do if o.titulo == "Guías terminadas" then hay = true end end
  check(hay, "la página Ruta no ofrece «Guías terminadas»")
end)

---------------------------------------------------------------------------
step("7: /alfa confirmar", function()
  local Cf = AlfaConfirmar
  check(Cf and Cf.Abrir, "falta AlfaConfirmar")
  local lista = Cf.Lista()
  check(#lista >= 30, "la lista guiada tiene menos de 30: " .. #lista)
  for _, it in ipairs(lista) do
    check(it.texto:find("Funciona si:", 1, true), "«" .. it.titulo .. "» no dice cuándo funciona")
  end
  local v = Cf.Abrir()
  T(2)
  check(v:IsShown(), "no abre la ventana")
  local _, ui = Ru.Confirmar.Ventana()
  SNAP("confirmar", v)
  FIRE(v.Si, "OnClick") T(1)
  check(Cf.Lista()[1].estado == "si", "«Funciona» no guardó")
  FIRE(v.No, "OnClick") T(1)
  check(Cf.Lista()[2].estado == "no", "«No funciona» no guardó")
  check(v.Reportar:IsShown(), "tras «No funciona» no ofrece reportarlo")
  SNAP("confirmar-no", v)
  FIRE(v.Saltar, "OnClick") T(1)
  check(Cf.Lista()[2].estado == "salto", "«Saltar» no guardó")
  check(type(AlfaNucleoDB.confirmar) == "table" and AlfaNucleoDB.confirmar.r["cerrar.hoy"].e == "si", "no quedó en AlfaNucleoDB")
  Cf.Marcar("viaje.barco", "no")
  local r = Cf.Resumen()
  check(r and r:find("1 funcionan", 1, true) and r:find("viaje.barco", 1, true), "el resumen no dice lo confirmado: " .. tostring(r))
  -- La lista entera, con sus marcas.
  FIRE(v.VerLista, "OnClick") T(1)
  check(ui.vista == "lista" and dice(v, "La tarjeta del barco"), "«Ver la lista» no enseña la lista")
  SNAP("confirmar-lista", v)
  -- Nada se corta: cada título cabe en su renglón de la lista.
  for _, f in ipairs(ui.filas) do
    if f:IsShown() and f.Texto:GetText() then
      check(K.AnchoTexto(f.Texto) <= f.Texto:GetWidth() + 1, "un renglón se corta: " .. f.Texto:GetText())
    end
  end
  FIRE(v.VerLista, "OnClick") T(1)
  v:Cerrar()
  -- En el reporte del Lobo Malo.
  local B = NS_OF("Alfa_Bienvenida")
  local texto = B.ComponerReporte and B.ComponerReporte() or ""
  check(texto:find("Confirmado en el juego", 1, true), "el reporte no lleva lo confirmado")
  A.RunCommand("confirmar") T(1)
  check(v:IsShown(), "/alfa confirmar no la abre")
  v:Cerrar()
end)

print(("1.4.0 misiones: %d pasos, %d errores"):format(pasos, #ERRORS))
