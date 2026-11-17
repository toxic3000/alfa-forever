-- Alfa - Lya: las historias de tus misiones y los datos curiosos de cada zona
-- (toxic3000 / La Jauría). GPL-3.0.
--
-- Seguir la flecha hace que uno se salte la historia. Lya la guarda por ti:
--   * Guarda los textos del juego de cada misión que ves (en el idioma de tu
--     cliente): QUEST_DETAIL (título, descripción, objetivos), QUEST_PROGRESS
--     (lo que dice mientras la haces), QUEST_COMPLETE (el final) y, para las
--     que ya estaban en tu registro, GetQuestLogQuestText. Con quién la tomaste,
--     con quién la entregas, la zona y la fecha. Se salta lo que el juego
--     devuelva como valor secreto.
--   * Al tomar una misión sin leerla (aceptada al momento, o con la guía
--     andando), Lya dice un gancho corto con sus palabras y el botón
--     "Contármela", que abre la ventana Historias en esa misión. Nunca el texto
--     largo en el globo. Al entregarla, a veces, "¿Te cuento el final?".
--   * Datos curiosos (Lore.lua): uno al entrar por primera vez a una zona (no
--     siempre), al pedirlo ("Cuéntame algo de aquí") y, rara vez, en un rato
--     tranquilo; también algo del lore del mundo.
--
-- Contra el spam (además de las reglas de Cerebro.lua: nunca en combate,
-- instancias ni mientras escribes, y el espacio de lya.minutos):
--   * lya.historias: "siempre" | "aveces" (por omisión) | "pedir" | "nunca".
--   * Un globo de historia cada lya.minutosHistoria (10) como mucho; un dato
--     curioso solo cada 20 minutos. Nada se repite: cada gancho, final y
--     dato sale una vez por personaje (N.DatosPersonaje("lya").hist).
--   * Todo es por eventos: ni tickers ni OnUpdate. Un gancho que no pudo
--     salir se reintenta unas pocas veces (cada 30 s, 3 minutos a lo más).
--
-- Datos: N.Datos("lya").historias.q[questID] = { t, d, o, p, r, g, e, z, zn,
-- a, c, u, l } en la cuenta (las 500 más recientes y 450 000 letras a lo más).
--
--   M.Historias.Abrir(questID)  H.Contar()  H.Suelto()  H.Modo()  H.Todas()  H.Cuantas()
--   AlfaLya.Historias(questID)  /alfa historias

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID
local UI = M.UI
local Ce = M.Cerebro

local type, tonumber, tostring, pairs, ipairs, pcall, rawget, format = type, tonumber, tostring, pairs, ipairs, pcall, rawget, string.format
local floor, max, min, random = math.floor, math.max, math.min, math.random
local sort = table.sort

local H = {}
M.Historias = H

local MAX_MISIONES = 500
local MAX_LETRAS = 450000
local MAX_CAMPO = 4000            -- letras por texto, a lo más
local ESPACIO_DATO = 6 * 60       -- s entre un dato curioso automático y otro (habla del lugar seguido)
local REINTENTOS, CADA = 6, 30    -- un gancho que no pudo salir: cada 30 s, 6 veces

local MODOS = { siempre = true, aveces = true, pedir = true, nunca = true }

---------------------------------------------------------------------------
-- Ayudas
---------------------------------------------------------------------------
local function ahora() return GetTime and GetTime() or 0 end
local function reloj() return (GetServerTime and GetServerTime()) or (time and time()) or 0 end
local function secreto(v) return issecretvalue and issecretvalue(v) or false end
local function num(v) if v == nil or secreto(v) then return nil end v = tonumber(v) return v and v > 0 and v or nil end
local function verdad(v) return not secreto(v) and v == true end

local function llamar(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if ok then return a, b, c end
	return nil
end

-- Corta sin partir una letra de UTF-8 a la mitad.
local function cortar(s, n)
	if #s <= n then return s end
	local i = n
	while i > 0 do
		local b = s:byte(i + 1)
		if not b or b < 128 or b >= 192 then break end
		i = i - 1
	end
	return s:sub(1, i)
end

-- Un texto del juego que se puede guardar (nunca un valor secreto).
local function texto(v)
	if v == nil or secreto(v) or type(v) ~= "string" then return nil end
	v = v:gsub("\r\n", "\n"):gsub("^%s+", ""):gsub("%s+$", "")
	if v == "" then return nil end
	return cortar(v, MAX_CAMPO)
end

local function enCombate()
	return (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and verdad(UnitAffectingCombat("player"))) or false
end

local function al(...)
	local n = select("#", ...)
	return select(random(n), ...)
end

---------------------------------------------------------------------------
-- Lo guardado
---------------------------------------------------------------------------
local function almacen()
	local d = N.Datos(ID)
	local h = type(d.historias) == "table" and d.historias or {}
	d.historias = h
	h.q = type(h.q) == "table" and h.q or {}
	return h.q
end

local function personaje()
	local d = N.DatosPersonaje(ID)
	local h = type(d.hist) == "table" and d.hist or {}
	d.hist = h
	for _, k in ipairs({ "ganchos", "finales", "zonas", "datos" }) do
		h[k] = type(h[k]) == "table" and h[k] or {}
	end
	return h
end

local CAMPOS = { "t", "d", "o", "p", "r", "g", "e", "zn" }
local function letras(r)
	local n = 0
	for _, k in ipairs(CAMPOS) do if type(r[k]) == "string" then n = n + #r[k] end end
	return n
end

-- Las 500 más recientes y no más de 450 000 letras: se va lo más viejo.
local function podar()
	local s = almacen()
	local lista, total = {}, 0
	for q, r in pairs(s) do
		if type(r) ~= "table" then
			s[q] = nil
		else
			lista[#lista + 1] = q
			total = total + letras(r)
		end
	end
	if #lista <= MAX_MISIONES and total <= MAX_LETRAS then return end
	sort(lista, function(a, b) return (tonumber(s[a].u) or 0) < (tonumber(s[b].u) or 0) end)
	local quedan = #lista
	for _, q in ipairs(lista) do
		if quedan <= MAX_MISIONES and total <= MAX_LETRAS then break end
		total = total - letras(s[q])
		s[q] = nil
		quedan = quedan - 1
	end
end

local function registro(q, crear)
	local s = almacen()
	local r = s[q]
	if type(r) ~= "table" then
		if not crear then return nil end
		r = {}
		s[q] = r
		r.u = reloj()
		podar()
	end
	return r
end

local function poner(r, campo, valor)
	valor = texto(valor)
	if valor then r[campo] = valor return true end
	return false
end

local function tocar(r)
	r.u = reloj()
	r.l = N.locale
end

function H.Todas() return almacen() end
function H.Una(q) q = num(q) return q and almacen()[q] or nil end
function H.Cuantas()
	local n = 0
	for _, r in pairs(almacen()) do if type(r) == "table" and (r.a or r.c) then n = n + 1 end end
	return n
end

---------------------------------------------------------------------------
-- Lo que se lee del juego
---------------------------------------------------------------------------
-- La zona donde estás: su uiMapID (subiendo de una cueva o un piso a su zona) y su nombre.
local function zonaActual()
	local CM = C_Map
	local id = CM and num(llamar(CM.GetBestMapForUnit, "player"))
	local nombre
	local vueltas = 0
	while id and CM.GetMapInfo and vueltas < 6 do
		local info = llamar(CM.GetMapInfo, id)
		if type(info) ~= "table" then break end
		local tipo = num(info.mapType) or 0
		local padre = num(info.parentMapID)
		-- 3 = zona (y capitales), 4 = mazmorra: se quedan; 5 y 6 (cuevas, pisos) suben.
		if tipo <= 4 or not padre then
			nombre = texto(info.name)
			break
		end
		id = padre
		vueltas = vueltas + 1
	end
	if not nombre then nombre = texto(llamar(GetRealZoneText)) end
	return id, nombre
end
H.ZonaActual = zonaActual

local function nombrePNJ()
	for _, u in ipairs({ "questnpc", "npc" }) do
		if UnitExists and verdad(llamar(UnitExists, u)) then
			local n = texto(llamar(UnitName, u))
			if n then return n end
		end
	end
	return nil
end

local function idDelDialogo() return num(llamar(GetQuestID)) end

local function ventanaDelRegistro()
	for _, nombre in ipairs({ "QuestLogFrame", "QuestMapFrame", "WorldMapFrame" }) do
		local f = rawget(_G, nombre)
		if type(f) == "table" and f.IsShown and f:IsShown() then return true end
	end
	return false
end

local function indiceEnRegistro(q)
	local QL = C_QuestLog
	local i = QL and num(llamar(QL.GetLogIndexForQuestID, q))
	if not i then i = num(llamar(rawget(_G, "GetQuestLogIndexByID"), q)) end
	return i
end

-- La descripción y los objetivos de una misión de tu registro.
local function leerDelRegistro(q, r)
	local leer = rawget(_G, "GetQuestLogQuestText")
	if type(leer) ~= "function" then return end
	local i = indiceEnRegistro(q)
	if not i then return end
	local d, o = llamar(leer, i)
	if not texto(d) and not enCombate() and not ventanaDelRegistro() then
		-- Algunos clientes solo leen la misión elegida: se elige un instante y se devuelve.
		local QL = C_QuestLog
		if QL and QL.SetSelectedQuest and QL.GetSelectedQuest then
			local antes = num(llamar(QL.GetSelectedQuest))
			llamar(QL.SetSelectedQuest, q)
			d, o = llamar(leer)
			if antes then llamar(QL.SetSelectedQuest, antes) end
		elseif SelectQuestLogEntry and GetQuestLogSelection then
			local antes = num(llamar(GetQuestLogSelection))
			llamar(SelectQuestLogEntry, i)
			d, o = llamar(leer)
			if antes then llamar(SelectQuestLogEntry, antes) end
		end
	end
	poner(r, "d", d)
	poner(r, "o", o)
	if not r.t then
		local QL = C_QuestLog
		poner(r, "t", QL and llamar(QL.GetTitleForQuestID, q))
	end
end

local function ponerZona(r)
	if r.zn then return end
	local z, nombre = zonaActual()
	r.z = z
	r.zn = nombre
end

---------------------------------------------------------------------------
-- La guía: ¿tomaste la misión sin leerla?
---------------------------------------------------------------------------
local function deMiRuta(q)
	local R = rawget(_G, "AlfaRuta")
	if type(R) == "table" and type(R.EsDeMiRuta) == "function" then
		local ok, si = pcall(R.EsDeMiRuta, q, "accept")
		if ok and si then return true end
	end
	local E = A.Engine
	if E and type(E.WantsQuest) == "function" then
		local ok, si = pcall(E.WantsQuest, "accept", q)
		if ok and si then return true end
	end
	return false
end

local function guiaActiva()
	local E = A.Engine
	if not (E and type(E.GetGuide) == "function") then return false end
	local ok, g = pcall(E.GetGuide)
	return ok and g ~= nil and A.Get("ui.shown") ~= false
end

---------------------------------------------------------------------------
-- Modo y espacios
---------------------------------------------------------------------------
function H.Modo()
	local v = N.Get(ID, "historias")
	return MODOS[v] and v or "aveces"
end

local function espacioHistoria() return max(1, tonumber(N.Get(ID, "minutosHistoria")) or 10) * 60 end
local function puedeHistoria() return reloj() - (tonumber(personaje().ultima) or 0) >= espacioHistoria() end
local function puedeDato() return reloj() - (tonumber(personaje().ultimaDato) or 0) >= ESPACIO_DATO end

local function ventanaDeMision()
	for _, nombre in ipairs({ "QuestFrame", "GossipFrame" }) do
		local f = rawget(_G, nombre)
		if type(f) == "table" and f.IsShown and f:IsShown() then return true end
	end
	return false
end

---------------------------------------------------------------------------
-- De qué va: un tema sacado del texto (en español o en inglés)
---------------------------------------------------------------------------
local LOBOS = "los lobos"
local TEMAS = {
	{ LOBOS, { "%f[%a]lobo", "%f[%a]wol[fv]", "%f[%a]worgs?%f[%A]" } },
	{ "la Plaga", { "plaga", "scourge", "no%-muert", "undead", "zombi", "esquelet", "skeleton", "necr", "nigromant", "ghoul" } },
	{ "la Hermandad Defias", { "defias" } },
	{ "los múrlocs", { "rloc" } },
	{ "los kóbolds", { "kobold", "kóbold" } },
	{ "los gnolls", { "gnoll" } },
	{ "los trols", { "%f[%a]trol" } },
	{ "los centauros", { "centaur" } },
	{ "la Legión Ardiente", { "legión", "legion", "demoni", "demon", "sátiro", "satyr" } },
	{ "los jabaespines", { "jabaesp", "quilboar" } },
	{ "los orcos", { "%f[%a]orco", "%f[%a]orcs?%f[%A]" } },
	{ "los dragones", { "dragón", "dragon" } },
	{ "Ventura y Cía.", { "ventura", "venture" } },
	{ "el Sindicato", { "sindicato", "syndicate" } },
	{ "los Renegados", { "renegad", "forsaken" } },
	{ "el Martillo Crepuscular", { "crepuscular", "twilight" } },
	{ "los furbolgs", { "furbolg" } },
	{ "las arpías", { "arpía", "harpía", "harp[yi]" } },
	{ "los naga", { "%f[%a]naga" } },
	{ "los Hierro Negro", { "hierro negro", "dark iron" } },
	{ "los ogros", { "%f[%a]ogr[oe]" } },
	{ "la Cruzada Escarlata", { "escarlata", "scarlet" } },
	{ "los worgen", { "worgen" } },
	{ "las arañas", { "araña", "spider" } },
	{ "los piratas", { "pirat" } },
	{ "los raptores", { "raptor" } },
	{ "los elementales", { "elemental" } },
	{ "los troggs", { "trogg" } },
	{ "los silítidos", { "silít", "silithid" } },
	{ "los Roca Negra", { "roca negra", "blackrock" } },
}

-- Minúsculas solo en la A-Z: las letras con acento (UTF-8) quedan intactas
-- (string.lower puede tocar esos bytes según el cliente).
local function minus(s) return (s:gsub("[A-Z]", string.lower)) end
H.Minus = minus

local function temaDe(r)
	local t = minus((r.t or "") .. " " .. (r.d or "") .. " " .. (r.o or ""))
	local mejor, n = nil, 0
	for _, tema in ipairs(TEMAS) do
		local c = 0
		for _, p in ipairs(tema[2]) do
			local ok, _, k = pcall(string.gsub, t, p, "")
			if ok and k then c = c + k end
		end
		if c > n then mejor, n = tema[1], c end
	end
	return mejor
end
H.TemaDe = temaDe

---------------------------------------------------------------------------
-- Lo que dice Lya (con sus palabras, nunca el texto largo)
---------------------------------------------------------------------------
local GANCHO_TEMA = { -- %s: quien te la dio, %s: el tema
	"Esta va de %s y %s… ¿Te la cuento?",
	"%s te habló de %s, y hay más historia de la que dice la flecha. ¿Te la cuento?",
	"Lo de %s y %s tiene su historia. ¿Te la platico?",
}
local GANCHO_PNJ = { -- %s: quien te la dio, %s: el título
	"%s te encargó «%s». Hay toda una historia detrás… ¿Te la cuento?",
	"%s tiene sus razones para pedirte «%s». ¿Te las cuento?",
}
local GANCHO_TITULO = { -- %s: el título
	"«%s» tiene su historia. ¿Te la cuento?",
	"Detrás de «%s» hay más de lo que parece. ¿Te la cuento?",
}
local GANCHO_LOBOS = { -- %s: quien te la dio
	"Esta va de %s y de lobos… me toca de cerca. ¿Te la cuento?",
}
local FINAL = { -- %s: el título
	"Así terminó «%s»… ¿Te cuento el final?",
	"«%s» ya quedó. Su final vale la pena, ¿te lo cuento?",
}

local function elegir(lista) return L[lista[random(#lista)]] end

local function textoGancho(r)
	local tema = temaDe(r)
	local npc, titulo = r.g, r.t
	if tema == LOBOS and npc then return format(elegir(GANCHO_LOBOS), npc) end
	if tema and npc then return format(elegir(GANCHO_TEMA), npc, L[tema]) end
	if npc and titulo then return format(elegir(GANCHO_PNJ), npc, titulo) end
	if titulo then return format(elegir(GANCHO_TITULO), titulo) end
	return nil
end

-- Un globo de historia que espera su momento (uno a la vez: el más nuevo manda).
local turno = 0
local pendiente

local function intentar(mio)
	if mio ~= turno or not pendiente then return end
	local p = pendiente
	local hp = personaje()
	local lista = p.final and hp.finales or hp.ganchos
	local r = almacen()[p.q]
	if lista[p.q] or not r or not p.armar then pendiente = nil return end
	local por
	if not puedeHistoria() then
		pendiente = nil
		return
	elseif enCombate() or ventanaDeMision() then
		por = "esperar"
	else
		local c = p.armar(r)
		if not c then pendiente = nil return end
		local ok, motivo = Ce.Decir(c)
		if ok == true then
			lista[p.q] = true
			hp.ultima = reloj()
			pendiente = nil
			return
		end
		por = motivo
	end
	-- Solo se reintenta lo pasajero: combate, otro globo, el espacio entre consejos.
	if por ~= "esperar" and por ~= "ocupada" and por ~= "pronto" then pendiente = nil return end
	p.intentos = p.intentos + 1
	if p.intentos > REINTENTOS then pendiente = nil return end
	K.Despues(CADA, function() intentar(mio) end)
end

local function programar(q, final, armar, espera)
	turno = turno + 1
	local mio = turno
	pendiente = { q = q, final = final, armar = armar, intentos = 0 }
	K.Despues(espera or 3, function() intentar(mio) end)
end

local function armarGancho(q)
	return function(r)
		local t = textoGancho(r)
		if not t then return nil end
		return { texto = t, cara = "atenta", lineas = 4, segundos = 10,
			acciones = { { texto = L["Contármela"], fn = function() H.Abrir(q) end } } }
	end
end

local function armarFinal(q)
	return function(r)
		if not (r.r and r.t) then return nil end
		return { texto = format(elegir(FINAL), r.t), cara = "atenta", lineas = 4, segundos = 10,
			acciones = { { texto = L["Contármelo"], fn = function() H.Abrir(q, "final") end } } }
	end
end

---------------------------------------------------------------------------
-- Datos curiosos y lore
---------------------------------------------------------------------------
local function notaDe(lista, prefijo, hp, pedido)
	if type(lista) ~= "table" or #lista == 0 then return nil end
	local libres = {}
	for i = 1, #lista do
		if not hp.datos[prefijo .. i] then libres[#libres + 1] = i end
	end
	if #libres == 0 then
		if not pedido then return nil end
		local i = random(#lista) -- ya te las contó todas: al pedirlo, una de nuevo
		return prefijo .. i, lista[i]
	end
	local i = libres[random(#libres)]
	return prefijo .. i, lista[i]
end

local function notaDeZona(mapa, pedido)
	local lista = mapa and M.DATOS_ZONA and M.DATOS_ZONA[mapa]
	return notaDe(lista, "z" .. tostring(mapa) .. ".", personaje(), pedido)
end

local function notaDelMundo(pedido) return notaDe(M.LORE, "l", personaje(), pedido) end

function H.NotasDeZona(mapa) return mapa and M.DATOS_ZONA and M.DATOS_ZONA[mapa] or nil end
-- Lo de este personaje (hist): Charla.lua comparte hist.datos y hist.ultimaDato.
H.Personaje = personaje

local function decirNota(id, es, pedido)
	local t = L[es]
	local c = {
		texto = t, pedido = pedido, lineas = 5, ancho = 360,
		segundos = 9 + floor(#t / 28),
		alDecir = function()
			local hp = personaje()
			hp.datos[id] = true
			if not pedido then hp.ultimaDato = reloj() end
		end,
	}
	if pedido then
		c.acciones = { { texto = L["Otro dato"], fn = function() K.Despues(0.4, function() H.Contar() end) end },
			{ texto = L["Historias"], fn = function() H.Abrir() end } }
	end
	return Ce.Decir(c)
end

-- "Cuéntame algo de aquí": un dato de la zona (o del mundo, si de aquí no sabe nada).
function H.Contar()
	if not Ce.Activa() then return end
	local z = zonaActual()
	local id, es = notaDeZona(z, false)
	if not id then id, es = notaDelMundo(false) end
	if not id then id, es = notaDeZona(z, true) end
	if not id then id, es = notaDelMundo(true) end
	if id then
		decirNota(id, es, true)
		return
	end
	Ce.Decir({ texto = L["De este lugar todavía no sé mucho. ¿Vemos tus historias?"], pedido = true,
		acciones = { { texto = L["Historias"], fn = function() H.Abrir() end } } })
end

-- En un rato tranquilo (lo llama el latido de Cerebro.lua): rara vez, un dato.
-- -> true si habló.
function H.Suelto()
	local modo = H.Modo()
	local prob = (modo == "siempre" and 0.9) or (modo == "aveces" and 0.6) or 0
	if prob <= 0 or random() >= prob or not puedeDato() then return false end
	local id, es = notaDeZona(zonaActual(), false)
	if not id or random() < 0.3 then
		local i2, e2 = notaDelMundo(false)
		if i2 then id, es = i2, e2 end
	end
	if not id then return false end
	return decirNota(id, es, false) == true
end

-- Al llegar a una zona por primera vez con este personaje.
local turnoZona = 0
local function revisarZona(mio)
	if mio ~= turnoZona then return end
	local modo = H.Modo()
	if modo ~= "siempre" and modo ~= "aveces" then return end
	local z = zonaActual()
	if not (z and M.DATOS_ZONA and M.DATOS_ZONA[z]) then return end
	local hp = personaje()
	if hp.zonas[z] then
		-- De vuelta en una zona que ya conoces: si le queda algo por contarte de
		-- ahí, va primero (con el espacio entre datos, para no apurarla).
		if not puedeDato() then return end
		local id, es = notaDeZona(z, false)
		if id then decirNota(id, es, false) end
		return
	end
	-- Al llegar a una zona nueva siempre cuenta algo de ella: es lo que más se
	-- disfruta (Cerebro sigue cuidando que no hable encima de otra cosa).
	local id, es = notaDeZona(z, false)
	if not id then hp.zonas[z] = true return end
	if decirNota(id, es, false) == true then hp.zonas[z] = true end
end

local function zonaPronto(espera)
	turnoZona = turnoZona + 1
	local mio = turnoZona
	K.Despues(espera, function() revisarZona(mio) end)
end

---------------------------------------------------------------------------
-- Eventos (solo cuando pasan; nada corre solo)
---------------------------------------------------------------------------
local vistas = {} -- [questID] = { t = GetTime del diálogo, guia = la toma tu ruta }

A.RegisterEvent("QUEST_DETAIL", function(_, itemInicio)
	local q = idDelDialogo()
	if not q then return end
	local r = registro(q, true)
	poner(r, "t", llamar(GetTitleText))
	poner(r, "d", llamar(GetQuestText))
	poner(r, "o", llamar(GetObjectiveText))
	if not r.g then
		if not poner(r, "g", nombrePNJ()) then
			local item = num(itemInicio)
			local nombre = item and ((C_Item and llamar(C_Item.GetItemNameByID, item)) or llamar(GetItemInfo, item))
			poner(r, "g", nombre)
		end
	end
	ponerZona(r)
	tocar(r)
	vistas[q] = { t = ahora(), guia = deMiRuta(q) }
end)

A.RegisterEvent("QUEST_ACCEPTED", function(_, a, b)
	local q = num(b) or num(a)
	if not q then return end
	local r = registro(q, true)
	if not r.d then leerDelRegistro(q, r) end
	ponerZona(r)
	r.a = r.a or reloj()
	r.c = nil
	tocar(r)
	local v = vistas[q]
	vistas[q] = nil
	local modo = H.Modo()
	if not r.d or personaje().ganchos[q] then return end
	if modo == "siempre" then
		programar(q, false, armarGancho(q), 3)
	elseif modo == "aveces" then
		-- Sin leerla: aceptada al momento, con tu ruta o la guía andando, o sin diálogo.
		local sinLeer = (not v) or (ahora() - v.t < 4) or v.guia or guiaActiva()
		if sinLeer and random() < 0.5 then programar(q, false, armarGancho(q), 3) end
	end
end)

A.RegisterEvent("QUEST_PROGRESS", function()
	local q = idDelDialogo()
	if not q then return end
	local r = registro(q, true)
	if not r.t then poner(r, "t", llamar(GetTitleText)) end
	poner(r, "p", llamar(GetProgressText))
	poner(r, "e", nombrePNJ())
	ponerZona(r)
	tocar(r)
end)

A.RegisterEvent("QUEST_COMPLETE", function()
	local q = idDelDialogo()
	if not q then return end
	local r = registro(q, true)
	if not r.t then poner(r, "t", llamar(GetTitleText)) end
	poner(r, "r", llamar(GetRewardText))
	poner(r, "e", nombrePNJ())
	ponerZona(r)
	tocar(r)
end)

A.RegisterEvent("QUEST_TURNED_IN", function(_, a)
	local q = num(a)
	local r = q and almacen()[q]
	if not r then return end
	r.c = reloj()
	tocar(r)
	local modo = H.Modo()
	if N.Get(ID, "epilogo") == false or not r.r then return end
	local hp = personaje()
	if hp.finales[q] then return end
	-- "Siempre": cada final; "a veces": solo el de las que ya te contó.
	if modo == "siempre" or (modo == "aveces" and hp.ganchos[q]) then
		programar(q, true, armarFinal(q), 3)
	end
end)

-- Las que ya estaban en tu registro (una vez por sesión, fuera de combate).
local escaneado = false
local function escanear()
	if escaneado then return end
	if enCombate() then K.Despues(30, escanear) return end
	escaneado = true
	local QL = C_QuestLog
	if not (QL and QL.GetNumQuestLogEntries and QL.GetInfo) then return end
	local s = almacen()
	local zona
	for i = 1, num(llamar(QL.GetNumQuestLogEntries)) or 0 do
		local info = llamar(QL.GetInfo, i)
		if type(info) == "table" then
			if verdad(info.isHeader) then
				zona = texto(info.title)
			else
				local q = num(info.questID)
				if q and not (type(s[q]) == "table" and s[q].d) then
					local r = registro(q, true)
					poner(r, "t", info.title)
					if not r.zn then r.zn = zona end
					leerDelRegistro(q, r)
					r.a = r.a or reloj()
					tocar(r)
				end
			end
		end
	end
end

local entrado = false
A.RegisterEvent("PLAYER_ENTERING_WORLD", function(_, esLogin)
	if not entrado then
		entrado = true
		K.Despues(25, escanear)
		-- Al entrar, después del saludo de Lya y los avisos de Alfa.
		zonaPronto(esLogin == true and 75 or 30)
		return
	end
	zonaPronto(8)
end)
A.RegisterEvent("ZONE_CHANGED_NEW_AREA", function() zonaPronto(8) end)

---------------------------------------------------------------------------
-- Abrir la ventana, el comando y el contrato
---------------------------------------------------------------------------
-- seccion: "final" para ir directo al final.
function H.Abrir(q, seccion)
	if N.Permitido and not N.Permitido() then return end
	local V = M.VentanaHistorias
	if V and V.Abrir then V.Abrir(num(q), seccion) end
end

A.RegisterCommand("historias", function() H.Abrir() end, L["abre las historias de tus misiones que Lya te guarda"])

local API = rawget(_G, "AlfaLya")
if type(API) == "table" then
	-- AlfaLya.Historias(questID): abre la ventana Historias (en esa misión, si se da).
	function API.Historias(q) H.Abrir(q) end
	-- AlfaLya.DatoCurioso(): "Cuéntame algo de aquí".
	function API.DatoCurioso() H.Contar() end
end
