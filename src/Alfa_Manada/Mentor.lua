-- Alfa - La Jauría: el mentor de la manada (1.3.0). toxic3000 / La Jauría.
-- GPL-3.0.
--
-- Un lobo de nivel alto «adopta» a uno más nuevo: se lo propone desde la
-- página de La Jauría y el otro acepta (o no). Desde ese momento, y solo
-- entre los dos (por susurro oculto), el aprendiz le cuenta a su mentor su
-- nivel, su zona y cómo va su misión de ahora; si lleva un rato sin ganar
-- experiencia, el mentor recibe un empujoncito: «¿Le echas la mano?» con
-- «Susurrar». Cualquiera de los dos lo termina con un clic.
--
-- Mensajes (Red.lua, solo por susurro):
--   1a|p|<nivel>     ¿te adopto? (del mentor)
--   1a|s             sí, acepto (del aprendiz)
--   1a|n             no, gracias
--   1a|x             se acabó (cualquiera de los dos)
--   1a|e|<nivel>|<xp>|<mapa>|<hechos>|<total>|<misión>
--                    cómo voy (del aprendiz a su mentor, cada ESTADO). (1.3.1)
--                    Si el juego dice que tu mentor no está conectado (el
--                    aviso se oculta: Red.lua), no sale otra vez en CALLADO
--                    segundos o hasta que se le oiga (un 1a suyo o la manada).
-- Ajuste manada.mentor (recibir propuestas y adoptar). Se guarda por
-- personaje: N.DatosPersonaje("manada").mentor y .aprendices.
--
--   Me.Candidatos() -> { { clave, nombre, destino, nivel } }   a quién adoptar
--   Me.Adoptar(destino, nivel) -> ok, por qué ; Me.Aceptar(clave) ; Me.Rechazar(clave)
--   Me.Terminar(clave) ; Me.Mentor() ; Me.Aprendices() ; Me.Propuestas()
--   Me.Estado() -> lo que el aprendiz contaría ahora

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local U, L, ID = M.U, M.L, M.ID

local Me = {}
M.Mentor = Me

local type, tonumber, tostring, pairs, ipairs, pcall, format, floor, sort = type, tonumber, tostring, pairs, ipairs, pcall, string.format, math.floor, table.sort

local V = "1"
Me.DIF = 10           -- niveles por encima para adoptar
local MAX_APRENDICES = 3
local ESTADO = 120    -- el aprendiz cuenta cómo va cada 2 minutos
local CONECTADO = 330 -- sin noticias en este tiempo, no está conectado
Me.ATORADO = 1200     -- 20 minutos sin experiencia: empujoncito
local EMPUJE = 1800   -- y no más de uno cada media hora por aprendiz
local PROPUESTA = 600 -- una propuesta vale 10 minutos
local CALLADO = 600   -- (1.3.1) tu mentor no estaba conectado: no se le cuenta nada en 10 min

local function activo() return N.Get(ID, "mentor") ~= false end

Me.version = 0
local function cambio()
	Me.version = Me.version + 1
	if M.Avisar then M.Avisar() end
end

local function aviso(o)
	local K = N.Kit
	if M.U and M.U.Aviso then return M.U.Aviso(o) end
	U.Decir(o.titulo .. (o.texto and (" " .. o.texto) or ""))
end

local function datos()
	local d = N.DatosPersonaje(ID)
	if type(d.aprendices) ~= "table" then d.aprendices = {} end
	return d
end

local function miNivel() return UnitLevel and U.Numero(UnitLevel("player")) or 0 end

Me.MOTIVOS = {
	apagado = "El mentor está apagado (Ajustes de La Jauría).",
	nivel = "Para adoptar, tu nivel debe pasar el suyo por 10 o más.",
	muchos = "Ya cuidas a 3 aprendices: termina con alguno para adoptar otro.",
	ya = "Ya es tu aprendiz.",
	red = "Ahora no se puede hablar con la manada. Prueba en un rato.",
}

local function enviar(clave, destino, texto)
	return M.Red.EnviarLibre("a:" .. clave .. ":" .. texto:sub(1, 4), V .. "a|" .. texto, destino)
end

---------------------------------------------------------------------------
-- Quién
---------------------------------------------------------------------------

function Me.Mentor()
	local m = datos().mentor
	return type(m) == "table" and m or nil
end

-- Lo de esta sesión (no se guarda: GetTime no sirve entre sesiones):
-- clave -> { estado = {...}, xpAt, visto, empuje }
local vivos = {}
local function vivo(clave)
	local v = vivos[clave]
	if not v then v = {} vivos[clave] = v end
	return v
end

-- { { clave, nombre, destino, desde, estado, xpAt, visto } }
function Me.Aprendices()
	local out = {}
	for clave, a in pairs(datos().aprendices) do
		if type(a) == "table" then
			local v = vivo(clave)
			out[#out + 1] = { clave = clave, nombre = a.nombre, destino = a.destino, desde = a.desde,
				estado = v.estado, xpAt = v.xpAt, visto = v.visto }
		end
	end
	sort(out, function(a, b) return (a.nombre or "") < (b.nombre or "") end)
	return out
end

local function nAprendices()
	local n = 0
	for _ in pairs(datos().aprendices) do n = n + 1 end
	return n
end

local propuestas = {}  -- clave -> { nombre, destino, nivel, at }  (te quieren adoptar)
local propuse = {}     -- clave -> at  (tú propusiste)
local mentorFuera = -math.huge -- (1.3.1) cuándo dijo el juego que tu mentor no estaba conectado

function Me.Propuestas()
	local out, ahora = {}, U.Ahora()
	for clave, p in pairs(propuestas) do
		if ahora - p.at > PROPUESTA then propuestas[clave] = nil
		else p.clave = clave out[#out + 1] = p end
	end
	sort(out, function(a, b) return a.at > b.at end)
	return out
end

-- A quién puedes adoptar: los lobos que conoces (a la vista, en el tablón o
-- que comparten su nivel) con 10 niveles o más por debajo del tuyo.
function Me.Candidatos()
	local out, visto = {}, {}
	local yo = miNivel()
	local mia = U.MiClave()
	local function poner(clave, nombre, destino, nivel)
		if not (clave and destino and nivel) or visto[clave] or clave == mia then return end
		if datos().aprendices[clave] then return end
		if nivel + Me.DIF > yo then return end
		visto[clave] = true
		out[#out + 1] = { clave = clave, nombre = nombre or U.Mostrar(destino), destino = destino, nivel = nivel }
	end
	if M.Gente then
		for _, f in ipairs(M.Gente.Manada()) do
			if f.tipo == "manada" then poner(f.clave, f.nombre, f.envio, f.nivel) end
		end
	end
	if M.Tablon then
		for _, x in ipairs(M.Tablon.Lista()) do
			if not x.mio then poner(x.clave, x.nombre, x.destino, x.nivel) end
		end
	end
	if M.Botin then
		for _, x in ipairs(M.Botin.Conocidos()) do poner(x.clave, x.nombre, x.destino, x.nivel) end
	end
	sort(out, function(a, b)
		if a.nivel ~= b.nivel then return a.nivel > b.nivel end
		return a.nombre < b.nombre
	end)
	return out
end

---------------------------------------------------------------------------
-- Adoptar, aceptar, terminar
---------------------------------------------------------------------------

function Me.Adoptar(destino, nivel)
	if not activo() then return false, "apagado" end
	local clave = U.Clave(destino)
	if not clave then return false, "red" end
	if datos().aprendices[clave] then return false, "ya" end
	if nAprendices() >= MAX_APRENDICES then return false, "muchos" end
	if tonumber(nivel) and tonumber(nivel) + Me.DIF > miNivel() then return false, "nivel" end
	if not enviar(clave, U.Destino(destino) or destino, format("p|%d", miNivel())) then return false, "red" end
	propuse[clave] = { at = U.Ahora(), nombre = U.Mostrar(destino), destino = destino }
	cambio()
	return true
end

function Me.AdoptarYDecir(destino, nivel)
	local ok, por = Me.Adoptar(destino, nivel)
	if ok then
		U.Decir(format(L["Le propusiste a %s ser su mentor. Te aviso cuando conteste."], U.Mostrar(destino)))
	elseif Me.MOTIVOS[por] then
		U.Decir(L[Me.MOTIVOS[por]])
	end
	return ok
end

function Me.Propuesto(clave) return propuse[clave] ~= nil and U.Ahora() - propuse[clave].at <= PROPUESTA end

local enviarEstado -- forward

function Me.Aceptar(clave)
	local p = propuestas[clave]
	if not p then return false end
	propuestas[clave] = nil
	local viejo = Me.Mentor()
	if viejo and viejo.clave ~= clave then enviar(viejo.clave, viejo.destino, "x") end
	datos().mentor = { clave = clave, nombre = p.nombre, destino = p.destino, desde = U.Reloj() }
	mentorFuera = -math.huge -- (acaba de proponértelo: está conectado)
	enviar(clave, p.destino, "s")
	cambio()
	A.After(3, function() enviarEstado(true) end)
	return true
end

function Me.Rechazar(clave)
	local p = propuestas[clave]
	if not p then return false end
	propuestas[clave] = nil
	enviar(clave, p.destino, "n")
	cambio()
	return true
end

function Me.Terminar(clave)
	local m = Me.Mentor()
	if m and (clave == nil or m.clave == clave) then
		datos().mentor = nil
		enviar(m.clave, m.destino, "x")
		cambio()
		return true
	end
	local a = clave and datos().aprendices[clave]
	if a then
		datos().aprendices[clave] = nil
		vivos[clave] = nil
		enviar(clave, a.destino, "x")
		cambio()
		return true
	end
	return false
end

---------------------------------------------------------------------------
-- Cómo va el aprendiz
---------------------------------------------------------------------------

local function limpiar(s, largo)
	if type(s) ~= "string" or U.Secreto(s) then return nil end
	s = U.Cortar((s:gsub("[|\n\r]", ""):gsub("^%s+", ""):gsub("%s+$", "")), largo or 60) -- (1.3.1) letras, no bytes
	return s ~= "" and s or nil
end

-- La misión de ahora: la primera que sigues, o la primera de tu diario.
local function mision()
	local Q = C_QuestLog
	if type(Q) ~= "table" then return nil end
	local id
	if type(Q.GetQuestIDForQuestWatchIndex) == "function" then
		local ok, q = pcall(Q.GetQuestIDForQuestWatchIndex, 1)
		id = ok and U.Numero(q) or nil
	end
	if not id and M.Juntos and M.Juntos.Mias then
		for q in pairs(M.Juntos.Mias()) do if not id or q < id then id = q end end
	end
	if not id then return nil end
	local titulo
	if type(Q.GetTitleForQuestID) == "function" then
		local ok, t = pcall(Q.GetTitleForQuestID, id)
		titulo = ok and U.Texto(t) or nil
	end
	titulo = titulo or (M.Juntos and M.Juntos.Mias()[id])
	local hechos, total = 0, 0
	if type(Q.GetQuestObjectives) == "function" then
		local ok, objs = pcall(Q.GetQuestObjectives, id)
		if ok and type(objs) == "table" then
			for _, o in ipairs(objs) do
				if type(o) == "table" then
					total = total + 1
					if U.Leer(o.finished) then hechos = hechos + 1 end
				end
			end
		end
	end
	return limpiar(titulo, 50), hechos, total
end

function Me.Estado()
	local map = U.MiPosicion()
	local xp = UnitXP and U.Numero(UnitXP("player")) or 0
	local titulo, hechos, total = mision()
	return { nivel = miNivel(), xp = xp or 0, map = map and U.ZonaDe(map) or 0, mision = titulo, hechos = hechos or 0, total = total or 0 }
end

local ultimoEstado = -math.huge

-- Se le oyó a tu mentor después de eso (su Alfa en la manada): ya volvió.
local function mentorVolvio(m)
	local G = M.Gente
	local e = G and G.Alfa and G.Alfa(m.clave)
	if e and (e.oido or -math.huge) > mentorFuera then mentorFuera = -math.huge end
	return U.Ahora() - mentorFuera >= CALLADO
end

M.Red.AlNoEstar.mentor = function(clave)
	local m = Me.Mentor()
	if m and m.clave == clave then mentorFuera = U.Ahora() end
end

function Me.MentorFuera() return U.Ahora() - mentorFuera < CALLADO end

enviarEstado = function(forzar)
	local m = Me.Mentor()
	if not (m and activo()) then return false end
	local ahora = U.Ahora()
	if not mentorVolvio(m) then return false end
	if not forzar and ahora - ultimoEstado < ESTADO - 1 then return false end
	local e = Me.Estado()
	ultimoEstado = ahora
	return enviar(m.clave, m.destino, format("e|%d|%d|%d|%d|%d|%s", e.nivel, e.xp, e.map, e.hechos, e.total, e.mision or ""))
end
Me.EnviarEstado = enviarEstado

-- "Nivel 14 · Bosque de Elwynn · Lobos hambrientos (2/3) · hace 1 min"
function Me.Texto(a)
	local e = a.estado
	if not e then return L["Aún no sé cómo va."] end
	local partes = { format(L["Nivel %d"], e.nivel) }
	local zona = e.map and e.map > 0 and U.NombreMapa(e.map)
	if zona then partes[#partes + 1] = zona end
	if e.mision then
		partes[#partes + 1] = e.total > 0 and format("%s (%d/%d)", e.mision, e.hechos, e.total) or e.mision
	end
	if not Me.Conectado(a) then partes[#partes + 1] = L["no está conectado"] end
	return table.concat(partes, "  \194\183  ")
end

function Me.Conectado(a) return a.visto ~= nil and U.Ahora() - a.visto <= CONECTADO end

-- ¿Lleva un rato sin avanzar? Al mentor, un empujoncito (uno cada media hora).
function Me.Revisar()
	if not activo() then return end
	local ahora = U.Ahora()
	for clave, a in pairs(datos().aprendices) do
		local v = vivo(clave)
		if type(a) == "table" and v.xpAt and Me.Conectado(v) and ahora - v.xpAt >= Me.ATORADO
			and (not v.empuje or ahora - v.empuje >= EMPUJE) then
			v.empuje = ahora
			aviso({
				titulo = format(L["%s lleva un rato sin avanzar"], a.nombre or "?"),
				texto = L["Tu aprendiz no gana experiencia desde hace 20 minutos. ¿Le echas la mano?"],
				icono = "ic-manada",
				accion = { texto = L["Susurrar"], alClic = function() U.Susurrar(a.destino, "") end },
			})
		end
	end
end

---------------------------------------------------------------------------
-- Lo que llega
---------------------------------------------------------------------------

local function entero(s, max)
	if type(s) ~= "string" or not s:match("^%d+$") or #s > 10 then return nil end
	local n = tonumber(s)
	return n and n <= max and n or nil
end

M.Red.Oyentes.a = function(clave, remitente, _, f, canal)
	if canal ~= "WHISPER" or not activo() then return end
	local que = f[1]
	local d = datos()
	-- (1.3.1) Tu mentor habló: está conectado.
	local mio = Me.Mentor()
	if mio and mio.clave == clave then mentorFuera = -math.huge end
	if que == "p" then
		local nivel = entero(f[2], 200)
		if not nivel or nivel < miNivel() + Me.DIF then return end
		local m = Me.Mentor()
		if m and m.clave == clave then return end
		local nueva = not propuestas[clave]
		propuestas[clave] = { nombre = U.Mostrar(remitente), destino = remitente, nivel = nivel, at = U.Ahora() }
		cambio()
		if nueva then
			aviso({
				titulo = format(L["%s quiere ser tu mentor"], U.Mostrar(remitente)),
				texto = format(L["Un lobo de nivel %d te quiere echar la mano: ve tu nivel, tu zona y tu misión, solo él. Acepta aquí o en La Jauría."], nivel),
				icono = "ic-manada",
				accion = { texto = L["Aceptar"], alClic = function() Me.Aceptar(clave) end },
			})
		end
	elseif que == "s" then
		local p = propuse[clave]
		if not (p and U.Ahora() - p.at <= PROPUESTA) or nAprendices() >= MAX_APRENDICES then return end
		propuse[clave] = nil
		d.aprendices[clave] = { nombre = U.Mostrar(remitente), destino = remitente, desde = U.Reloj() }
		cambio()
		aviso({ titulo = format(L["¡%s es tu aprendiz!"], U.Mostrar(remitente)),
			texto = L["En La Jauría ves cómo va. Si se atora, te aviso."], icono = "ic-manada", lobo = "aullando" })
	elseif que == "n" then
		if not propuse[clave] then return end
		propuse[clave] = nil
		cambio()
		U.Decir(format(L["%s prefiere seguir por su cuenta por ahora."], U.Mostrar(remitente)))
	elseif que == "x" then
		local m = Me.Mentor()
		if m and m.clave == clave then d.mentor = nil cambio() end
		if d.aprendices[clave] then d.aprendices[clave] = nil vivos[clave] = nil cambio() end
		propuestas[clave] = nil
	elseif que == "e" then
		local a = d.aprendices[clave]
		if type(a) ~= "table" then return end
		local nivel, xp, map = entero(f[2], 200), entero(f[3], 100000000), entero(f[4], 100000)
		local hechos, total = entero(f[5], 50), entero(f[6], 50)
		if not (nivel and xp and map and hechos and total) then return end
		local ahora = U.Ahora()
		local v = vivo(clave)
		local e = v.estado
		if not e or e.nivel ~= nivel or e.xp ~= xp or not v.xpAt then v.xpAt = ahora end
		v.estado = { nivel = nivel, xp = xp, map = map, hechos = hechos, total = total, mision = limpiar(f[7], 50) }
		v.visto = ahora
		a.destino = remitente
		cambio()
		Me.Revisar()
	end
end

A.OnLogin(function()
	M.Cada("manada.mentor", 30, function()
		enviarEstado(false)
		Me.Revisar()
	end)
	-- 1.3.7: tras la animación del juego y escalonado con los demás mensajes de La Jauría.
	A.RegisterEvent("PLAYER_LEVEL_UP", (N.TrasNivel or function(_, f) return f end)("manada.mentor", function() A.After(1, function() enviarEstado(true) end) end))
end)
