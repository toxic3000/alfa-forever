-- Alfa - Rutas: seguir la ruta de alguien de tu grupo (toxic3000 / La Jauría).
-- GPL-3.0. 1.3.3
--
-- En grupo (nunca en banda), tú sin misiones y Ana con las suyas: Alfa te
-- dice qué lleva ella que tú no («Ana lleva 3 misiones que tú no tienes»),
-- con «Pedírselas» y «Seguir su ruta». Seguirla pone tu flecha donde apunta
-- la de ella y la mueve con ella (un viaje «follow» del motor encima de tu
-- guía: «Volver a la guía» lo deja); su destino sale en tu mapa (capa
-- rutas.rutaGrupo). A Ana, tu pedido le sale como aviso con «Compartir»: el
-- clic es de ella (el botón «Compartir» del registro del juego, por misión).
--
-- Mensajes de addon ocultos por el canal del grupo (PARTY, prefijo «Alfa»,
-- el mismo de Quests/Party.lua, cuyos decodificadores tiran estos tipos):
--   3S|1|<nombre> / 3S|0|<nombre>   te sigo / ya no te sigo (a <nombre>)
--   3W|<map>|<x>|<y>|<f>|<etiqueta>  a dónde apunta mi flecha (solo con
--                                    alguien siguiéndome; «3W|-»: a nada)
--   3P|<nombre>|<id>,<id>,...        ¿me compartes estas? (a <nombre>)
-- Lo que se sabe de sus misiones sale de Quests/Party.lua (Party.Members,
-- su registro con su avance). Nada va al chat de nadie (REGLAS-BLIZZARD.md,
-- regla 3). Un freno por remitente: un 3W por segundo, un 3P cada 30 s.
-- Ajuste rutas.rutaGrupo (de fábrica, sí). En combate, nada se ofrece.
--
--   RutaGrupo.Seguir(nombre) -> ok     RutaGrupo.Dejar()
--   RutaGrupo.Siguiendo() -> nombre | nil
--   RutaGrupo.Pedir(nombre, ids) -> ok
--   RutaGrupo.QueLleva() -> { { nombre, completo, ids = { qid... } }, ... }
--   RutaGrupo.Aviso() -> el aviso del rastreador | nil
--   RutaGrupo.AlMensaje(texto, remitente)   (lo que llega; el banco lo llama)

local ADDON, M = ...
local A, L, K, N = M.A, M.L, M.K, M.N
local RG = {}
M.RutaGrupo = RG

A.RegisterDefaults(M.ID, { rutaGrupo = true })

local type, ipairs, pairs, tonumber, tostring, pcall = type, ipairs, pairs, tonumber, tostring, pcall
local format, concat = string.format, table.concat

local PREFIJO = "Alfa"
local CAPA = "rutas.rutaGrupo"
local MAX_IDS = 12
local FRENO = { W = 1, P = 30, S = 1 } -- segundos entre dos mensajes del mismo tipo y remitente
local PERDIDO = 120                    -- sin noticias del guía: se deja de seguir

local function CP() return M.Motor("Compat") end
local function secreto(v) return issecretvalue and issecretvalue(v) or false end
local function on() return A.Get(M.ID .. ".rutaGrupo") ~= false end
local function ahora() return GetTime and GetTime() or 0 end
local function enBanda() return IsInRaid and IsInRaid() and true or false end
local function enGrupo()
	if enBanda() then return false end
	return IsInGroup and IsInGroup() and true or false
end
local function activo() return on() and enGrupo() end
local function enCombate()
	local Gr = M.Grupo
	if Gr and Gr.EnPelea then return Gr.EnPelea() end
	return InCombatLockdown and InCombatLockdown() or false
end

---------------------------------------------------------------------------
-- Nombres
---------------------------------------------------------------------------

-- El nombre completo («Ana Smith» en Forever) y el corto, de una unidad.
local function nombres(u)
	local Cp = CP()
	if Cp and type(Cp.UnitFullName) == "function" then
		local ok, completo, corto = pcall(Cp.UnitFullName, u)
		if ok and type(completo) == "string" and completo ~= "" then
			return completo, (type(corto) == "string" and corto ~= "") and corto or completo
		end
		if ok and completo == false then return nil end
	end
	local n = UnitName and UnitName(u)
	if type(n) == "string" and n ~= "" and not secreto(n) then return n, n end
	return nil
end

local function yo()
	local completo = nombres("player")
	return completo
end

-- Los de tu grupo: { { u, completo, corto } }.
local function miembros()
	local out = {}
	for i = 1, 4 do
		local u = "party" .. i
		if UnitExists and UnitExists(u) then
			local completo, corto = nombres(u)
			if completo then out[#out + 1] = { u = u, completo = completo, corto = corto } end
		end
	end
	return out
end
RG.Miembros = miembros

local function miembro(nombre)
	for _, m in ipairs(miembros()) do
		if m.completo == nombre or m.corto == nombre then return m end
	end
	return nil
end

-- El remitente de un mensaje, como lo da el juego, -> completo | nil
local function remitenteDe(s)
	local Cp = CP()
	if type(s) ~= "string" or secreto(s) then return nil end
	if Cp and type(Cp.SenderIsMe) == "function" then
		local ok, mio = pcall(Cp.SenderIsMe, s)
		if ok and mio then return nil end
	end
	local k = s
	if Cp and type(Cp.SenderName) == "function" then
		local ok, n = pcall(Cp.SenderName, s)
		if ok and type(n) == "string" then k = n end
	end
	local m = miembro(k)
	return m and m.completo or nil, m
end

---------------------------------------------------------------------------
-- Mandar
---------------------------------------------------------------------------

local registrado = false
local function mandar(texto)
	if not activo() or #texto > 250 then return false end
	local C = C_ChatInfo
	if not (C and type(C.SendAddonMessage) == "function") then return false end
	if not registrado and type(C.RegisterAddonMessagePrefix) == "function" then
		pcall(C.RegisterAddonMessagePrefix, PREFIJO)
		registrado = true
	end
	local ok = pcall(C.SendAddonMessage, PREFIJO, texto, "PARTY")
	return ok
end
RG.Mandar = mandar

local function limpio(s)
	return (tostring(s or ""):gsub("[|\n\r]", " "):sub(1, 60))
end

---------------------------------------------------------------------------
-- El que guía: a dónde apunta su flecha, solo si alguien lo sigue
---------------------------------------------------------------------------

local seguidores = {} -- completo -> true

local function miPunto()
	local Nav = A.Nav
	local ok, t = pcall(function() return Nav and Nav.GetTarget and Nav.GetTarget() end)
	if not (ok and type(t) == "table" and t.map and t.x and t.y) then return nil end
	return t
end

local function textoPunto()
	local t = miPunto()
	if not t then return "3W|-" end
	local label = t.label
	if type(label) ~= "string" or secreto(label) then label = "" end
	return format("3W|%d|%.2f|%.2f|%s|%s", t.map, t.x, t.y, t.f == "e" and "e" or "", limpio(label))
end

local ultimoW
local programado = false
function RG.Anunciar(forzar)
	if not (activo() and next(seguidores)) then return false end
	local texto = textoPunto()
	if texto == ultimoW and not forzar then return false end
	ultimoW = texto
	return mandar(texto)
end

local function anunciarLuego()
	if programado or not next(seguidores) then return end
	programado = true
	A.After(2, function() programado = false RG.Anunciar() end)
end

---------------------------------------------------------------------------
-- El que sigue: su flecha, la tuya
---------------------------------------------------------------------------

local sig -- { completo, corto, objetivo, at }

function RG.Siguiendo() return sig and sig.completo or nil end

local function pinta()
	local P = A.Pins
	if not (P and P.SetLayer and P.ClearLayer) then return end
	local t = sig and sig.punto
	if not t then P.ClearLayer(CAPA) return end
	local r, g, b = K.Color("acento")
	P.SetLayer(CAPA, { {
		map = t.map, x = t.x, y = t.y, f = t.f, icon = "map:flightmaster", size = 16, priority = 3,
		color = { r, g, b, 1 }, ring = { r, g, b, 1 }, label = format(L["La ruta de %s"], sig.corto),
		tooltip = function(tip)
			tip:SetText(format(L["La ruta de %s"], sig and sig.corto or ""), K.Color("texto"))
			if t.label and t.label ~= "" then tip:AddLine(t.label, K.Color("acento")) end
			tip:AddLine(L["Tu flecha va al mismo lugar."], K.Color("textoTenue"))
		end,
	} }, { world = true, minimap = true, edge = false })
end
RG.Pintar = pinta

local function soltarFlecha()
	local Nav = A.Nav
	local t = sig and sig.objetivo
	if not (t and Nav and Nav.GetTarget) then return end
	local ok, actual = pcall(Nav.GetTarget)
	if ok and actual == t then
		if Nav.Trip and Nav.Trip() and Nav.EndTrip then pcall(Nav.EndTrip)
		elseif Nav.ReleaseTarget then pcall(Nav.ReleaseTarget) end
	end
end

function RG.Dejar(callado)
	if not sig then return false end
	local nombre, corto = sig.completo, sig.corto
	soltarFlecha()
	sig = nil
	N.Quitar("rutas.rutaGrupo")
	pinta()
	mandar("3S|0|" .. limpio(nombre))
	if not callado then M.Aviso(L["Seguir su ruta"], format(L["Ya no sigues la ruta de %s: la flecha vuelve a tu guía."], corto), { icono = "ic-manada" }) end
	if M.Rastreador and M.Rastreador.Luego then M.Rastreador.Luego() end
	return true
end

-- ¿La flecha sigue siendo la nuestra? (otro destino la tomó: se deja)
local function vigilar()
	if not sig then N.Quitar("rutas.rutaGrupo") return end
	if not activo() or not miembro(sig.completo) or ahora() - sig.at > PERDIDO then RG.Dejar() return end
	local Nav = A.Nav
	if sig.objetivo and Nav and Nav.GetTarget then
		local ok, actual = pcall(Nav.GetTarget)
		if ok and actual ~= sig.objetivo then RG.Dejar(true) end
	end
end

function RG.Seguir(nombre)
	if not activo() then return false end
	local m = miembro(nombre)
	if not m then return false end
	if sig and sig.completo ~= m.completo then RG.Dejar(true) end
	sig = sig or { completo = m.completo, corto = m.corto }
	sig.at = ahora()
	mandar("3S|1|" .. limpio(m.completo))
	N.Cada("rutas.rutaGrupo", 5, vigilar)
	M.Aviso(L["Seguir su ruta"], format(L["Tu flecha irá a donde apunte la de %s."], m.corto), { icono = "ic-manada" })
	if M.Rastreador and M.Rastreador.Luego then M.Rastreador.Luego() end
	return true
end

-- Llegó a dónde apunta la flecha del que sigues.
local function alPunto(completo, map, x, y, f, label)
	if not (sig and sig.completo == completo) then return end
	sig.at = ahora()
	local Nav = A.Nav
	if not (Nav and Nav.SetTarget) then return end
	if not map then
		sig.punto = nil
		soltarFlecha()
		sig.objetivo = nil
		pinta()
		return
	end
	local etiqueta = (label and label ~= "") and label or format(L["La ruta de %s"], sig.corto)
	sig.punto = { map = map, x = x, y = y, f = f, label = label }
	local t = sig.objetivo
	local okA, actual = pcall(Nav.GetTarget)
	if t and okA and actual == t and t.f == f and Nav.MoveTarget then
		pcall(Nav.MoveTarget, t, map, x, y)
		t.label = etiqueta
	else
		local ok, nuevo = pcall(Nav.SetTarget, map, x, y, etiqueta, f)
		if ok and nuevo then
			sig.objetivo = nuevo
			if Nav.StartTrip then pcall(Nav.StartTrip, nuevo, sig.corto, L["Con tu grupo"], "follow") end
		end
	end
	pinta()
end

---------------------------------------------------------------------------
-- Lo que lleva cada uno y pedírselas
---------------------------------------------------------------------------

local function party() local P = A.Party return type(P) == "table" and P or nil end

-- ¿Te sirve esa misión? (no la tienes, no la hiciste, te alcanza el nivel)
local function teSirve(qid)
	local Cp = CP()
	if Cp and Cp.IsOnQuest and Cp.IsOnQuest(qid) then return false end
	if Cp and Cp.IsQuestCompleted and Cp.IsQuestCompleted(qid) then return false end
	local Q = M.Motor("QuestDB")
	if Q and Q.IsLoaded and Q.IsLoaded() and Q.QuestRecord and Q.F then
		local ok, r = pcall(Q.QuestRecord, qid)
		local minimo = ok and type(r) == "table" and tonumber(r[Q.F.MIN])
		local I = M.Indice
		local p = I and I.Jugador and I.Jugador()
		if minimo and p and p.level and p.level < minimo then return false end
	end
	return true
end

function RG.QueLleva()
	local out = {}
	local P = party()
	if not (activo() and P and type(P.Members) == "function") then return out end
	local ok, lista = pcall(P.Members)
	if not (ok and type(lista) == "table") then return out end
	for _, m in ipairs(miembros()) do
		for _, pm in ipairs(lista) do
			if type(pm) == "table" and (pm.name == m.corto or pm.name == m.completo) and type(pm.quests) == "table" then
				local ids = {}
				for qid in pairs(pm.quests) do
					qid = tonumber(qid)
					if qid and teSirve(qid) then ids[#ids + 1] = qid end
				end
				table.sort(ids)
				if #ids > 0 then out[#out + 1] = { nombre = m.corto, completo = m.completo, ids = ids } end
			end
		end
	end
	return out
end

local pedidas = {} -- completo -> true: ya pedidas o «Ahora no» (esta sesión)

function RG.Pedir(nombre, ids)
	local m = miembro(nombre)
	if not (m and type(ids) == "table" and #ids > 0) then return false end
	local lista = {}
	for i = 1, math.min(#ids, MAX_IDS) do lista[i] = tostring(ids[i]) end
	local ok = mandar("3P|" .. limpio(m.completo) .. "|" .. concat(lista, ","))
	pedidas[m.completo] = true
	if ok then
		M.Aviso(L["Pedírselas"], format(L["Le pediste a %s que te las comparta."], m.corto), { icono = "ic-manada" })
	end
	return ok
end

-- El aviso del rastreador (Grupo.Aviso lo pregunta después de los suyos).
function RG.Aviso()
	if not activo() or enCombate() then return nil end
	if sig then
		return { tono = "acento", icono = "ic-manada", titulo = format(L["Sigues la ruta de %s"], sig.corto),
			texto = L["Tu flecha va a donde apunta la suya."],
			uno = { L["Dejar de seguir"], function() RG.Dejar() end } }
	end
	for _, c in ipairs(RG.QueLleva()) do
		if not pedidas[c.completo] then
			local n = #c.ids
			return { tono = "acento", icono = "ic-manada",
				titulo = format(n == 1 and L["%s lleva 1 misión que tú no tienes"] or L["%s lleva %d misiones que tú no tienes"], c.nombre, n == 1 and nil or n),
				texto = L["Pídeselas y, si quieres, sigue su ruta: tu flecha irá con la suya."],
				uno = { L["Pedírselas"], function() RG.Pedir(c.completo, c.ids) if M.Rastreador then M.Rastreador.Luego() end end },
				dos = { L["Seguir su ruta"], function() pedidas[c.completo] = true RG.Seguir(c.completo) end } }
		end
	end
	return nil
end

---------------------------------------------------------------------------
-- Al que le piden: «Compartir» con su clic
---------------------------------------------------------------------------

local porCompartir = {} -- completo -> { corto, ids } (esperando a salir de combate)

local function titulo(qid) return M.TituloMision(qid) end

local function ofrecer(completo)
	local p = porCompartir[completo]
	if not p then return end
	if enCombate() then return end -- sale al terminar la pelea
	porCompartir[completo] = nil
	local Gr = M.Grupo
	local nombres = {}
	for i, q in ipairs(p.ids) do
		if i > 3 then break end
		nombres[#nombres + 1] = M.Citar(titulo(q))
	end
	local texto = #p.ids == 1 and format(L["%s te pide %s."], p.corto, nombres[1])
		or format(L["%s te pide %d misiones: %s."], p.corto, #p.ids, concat(nombres, ", "))
	M.Aviso(L["Te piden tus misiones"], texto, { icono = "ic-manada", duracion = 20,
		accion = { texto = L["Compartir"], alClic = function()
			for _, q in ipairs(p.ids) do
				if Gr and Gr.Compartir then Gr.Compartir(q) end
			end
		end } })
end

local function alPedido(completo, corto, destino, cuerpo)
	if destino ~= yo() then return end
	local Cp = CP()
	local ids = {}
	for s in tostring(cuerpo or ""):gmatch("%d+") do
		local q = tonumber(s)
		if q and #ids < MAX_IDS and Cp and Cp.IsOnQuest and Cp.IsOnQuest(q) then
			local QL = C_QuestLog
			local ok, si = false, nil
			if QL and type(QL.IsPushableQuest) == "function" then ok, si = pcall(QL.IsPushableQuest, q) end
			if ok and si == true then ids[#ids + 1] = q end
		end
	end
	if #ids == 0 then return end
	porCompartir[completo] = { corto = corto, ids = ids }
	ofrecer(completo)
end

---------------------------------------------------------------------------
-- Lo que llega
---------------------------------------------------------------------------

local ultimo = {} -- completo .. tipo -> GetTime()

function RG.AlMensaje(texto, remitente)
	if type(texto) ~= "string" or #texto > 255 or secreto(texto) then return false end
	local tipo = texto:match("^3([SWP])|")
	if not tipo or not activo() then return false end
	local completo, m = remitenteDe(remitente)
	if not completo then return false end
	-- El freno: un mensaje de cada tipo por remitente cada tanto.
	local k = completo .. tipo
	local t = ahora()
	if ultimo[k] and t - ultimo[k] < FRENO[tipo] then return false end
	ultimo[k] = t
	if tipo == "S" then
		local si, a = texto:match("^3S|([01])|(.*)$")
		if a ~= yo() then return false end
		seguidores[completo] = si == "1" or nil
		if si == "1" then RG.Anunciar(true) end
		return true
	elseif tipo == "W" then
		if texto == "3W|-" then alPunto(completo) return true end
		local map, x, y, f, label = texto:match("^3W|(%d+)|([%d%.]+)|([%d%.]+)|(e?)|(.*)$")
		map, x, y = tonumber(map), tonumber(x), tonumber(y)
		if not (map and x and y and x >= 0 and x <= 100 and y >= 0 and y <= 100) then return false end
		alPunto(completo, map, x, y, f == "e" and "e" or nil, label)
		return true
	elseif tipo == "P" then
		local destino, cuerpo = texto:match("^3P|([^|]*)|([%d,]*)$")
		if not destino then return false end
		alPedido(completo, m and m.corto or completo, destino, cuerpo)
		return true
	end
	return false
end

local function alAddon(_, prefijo, texto, canal, remitente)
	if secreto(prefijo) or secreto(canal) then return end
	if prefijo ~= PREFIJO or canal ~= "PARTY" then return end
	RG.AlMensaje(texto, remitente)
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------

-- Para el banco.
function RG.Reiniciar() sig, seguidores, ultimo, pedidas, porCompartir, ultimoW = nil, {}, {}, {}, {}, nil N.Quitar("rutas.rutaGrupo") end

AlfaNucleo.PorPrefijo(PREFIJO, alAddon)
A.On("WAYPOINT_CHANGED", anunciarLuego)
A.RegisterEvent("GROUP_ROSTER_UPDATE", function()
	-- Fuera del grupo (o ya en banda), todo se deja.
	if not activo() then
		seguidores = {}
		if sig then RG.Dejar(true) end
		return
	end
	for nombre in pairs(seguidores) do if not miembro(nombre) then seguidores[nombre] = nil end end
end)
A.RegisterEvent("PLAYER_REGEN_ENABLED", function()
	for completo in pairs(porCompartir) do ofrecer(completo) end
end)
A.On("SETTING_CHANGED", function(ruta)
	if ruta == M.ID .. ".rutaGrupo" and not on() then
		if sig then RG.Dejar(true) end
		seguidores = {}
	end
end)
