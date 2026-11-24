-- Alfa - La Jauría: compartir tu plan o tu guía con un lobo (1.3.8).
-- toxic3000 / La Jauría. GPL-3.0.
--
-- Desde la ficha de un lobo (Ficha.lua): «Compartirle mi plan» (tu plan de
-- ahora de Mis planes, o el primero de tu lista) o «Compartirle mi guía»
-- (la que sigues, con el paso en que vas). Le llega por susurro oculto una
-- tarjeta con «Aceptar»: el plan queda en sus Mis planes y lo sigue; la guía
-- se abre (si la tiene) y la flecha lo lleva. Solo se acepta de alguien de
-- tu hermandad o de tu grupo (y de tu facción: Red.lua). Nada sale al chat.
-- Ajuste manada.recibirRutas (de fábrica, sí).
--
-- Mensajes (Red.lua, solo por susurro):
--   1r|g|<id de la guía>|<paso>                     mi guía
--   1r|p|<n.º>|<parte>|<de>|<trozo>                 mi plan, en trozos de TROZO letras
--      el plan: "<nombre>&<meta>&<meta>...", cada meta "tipo;campo=valor;...";
--      los textos van sin «| & ; =».
-- De la misma persona, una tarjeta cada CADA s; tú compartes con cada lobo
-- una vez cada ENVIAR s. Un plan trae a lo más METAS metas.
--
--   Co.Plan(f) -> ok, por qué   Co.Guia(f) -> ok, por qué
--   Co.PuedePlan() -> plan | nil   Co.PuedeGuia() -> guía | nil
--   Co.Codificar(nombre, metas) -> texto   Co.Decodificar(texto) -> nombre, metas

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local U, L, ID = M.U, M.L, M.ID

local type, tonumber, tostring, pairs, ipairs, pcall, format, concat = type, tonumber, tostring, pairs, ipairs, pcall, string.format, table.concat

local Co = {}
M.Compartir = Co

local V = "1"
local TROZO = 180
local PARTES = 6
local METAS = 25
local CADA = 60
local ENVIAR = 30

local function activo() return N.Get(ID, "recibirRutas") ~= false end

local function aviso(o)
	local K = N.Kit
	if K and K.Aviso then return K.Aviso(o) end
	U.Decir(o.titulo .. (o.texto and (" " .. o.texto) or ""))
end

---------------------------------------------------------------------------
-- El plan en texto
---------------------------------------------------------------------------

local CAMPOS = {
	objeto = { "item", "kind", "cantidad", "nombre" },
	oro = { "cobre" },
	prof = { "linea", "nivel" },
	lugar = { "modo", "servicio", "linea", "mapa", "x", "y", "f", "nombre" },
	mision = { "quest", "verbo", "titulo" },
	nivel = { "nivel" },
	nota = { "texto" },
}

local function limpio(v)
	if type(v) == "number" then
		if v ~= v or v == math.huge or v == -math.huge then return nil end
		return (format("%.2f", v):gsub("%.?0+$", ""))
	end
	if type(v) ~= "string" or U.Secreto(v) then return nil end
	v = v:gsub("[|&;=\n\r]", " "):gsub("^%s+", ""):gsub("%s+$", "")
	return v ~= "" and U.Cortar(v, 60) or nil
end

-- (1.3.8 revisión) tope: el largo máximo (en bytes). Una meta que ya no cabe
-- no se corta a la mitad: se deja fuera (y las siguientes).
-- -> texto, metas puestas, metas que se podían compartir
function Co.Codificar(nombre, metas, tope)
	local partes = { limpio(nombre) or L["Plan de la manada"] }
	local largo, puestas, total, lleno = #partes[1], 0, 0, false
	for _, m in ipairs(metas or {}) do
		local campos = type(m) == "table" and CAMPOS[m.tipo]
		if campos then
			total = total + 1
			if not lleno and puestas < METAS then
				local t = { m.tipo }
				for _, c in ipairs(campos) do
					local v = limpio(m[c])
					if v then t[#t + 1] = c .. "=" .. v end
				end
				local s = concat(t, ";")
				if tope and largo + 1 + #s > tope then
					lleno = true
				else
					partes[#partes + 1] = s
					largo = largo + 1 + #s
					puestas = puestas + 1
				end
			end
		end
	end
	return concat(partes, "&"), puestas, total
end

local NUMEROS = { item = true, cantidad = true, cobre = true, linea = true, nivel = true, mapa = true, x = true, y = true, quest = true }

function Co.Decodificar(texto)
	if type(texto) ~= "string" then return nil end
	local nombre, metas = nil, {}
	for trozo in (texto .. "&"):gmatch("([^&]*)&") do
		if not nombre then
			nombre = limpio(trozo) or L["Plan de la manada"]
		elseif #metas < METAS then
			local tipo, resto = trozo:match("^(%a+);?(.*)$")
			local campos = tipo and CAMPOS[tipo]
			if campos then
				local m, validos = { tipo = tipo }, {}
				for _, c in ipairs(campos) do validos[c] = true end
				for c, v in resto:gmatch("(%a+)=([^;]*)") do
					if validos[c] then
						if NUMEROS[c] then
							if v:match("^%-?%d+%.?%d*$") then m[c] = tonumber(v) end
						else
							m[c] = limpio(v)
						end
					end
				end
				metas[#metas + 1] = m
			end
		end
	end
	return nombre, metas
end

---------------------------------------------------------------------------
-- Compartir
---------------------------------------------------------------------------

local enviados = {} -- clave -> GetTime

function Co.PuedePlan()
	local P = rawget(_G, "AlfaPlanes")
	if type(P) ~= "table" then return nil end
	local pl = type(P.Activo) == "function" and P.Activo() or nil
	if not pl and type(P.Lista) == "function" then pl = (P.Lista() or {})[1] end
	return type(pl) == "table" and type(pl.metas) == "table" and #pl.metas > 0 and pl or nil
end

function Co.PuedeGuia()
	local R = rawget(_G, "AlfaRuta")
	if type(R) ~= "table" or type(R.GuiaActual) ~= "function" then return nil end
	return R.GuiaActual()
end

local function destinoDe(f)
	local d = f and (f.envio or f.nombre)
	return d, f and (f.clave or U.Clave(d))
end

local function frenar(clave)
	local ahora = U.Ahora()
	if enviados[clave] and ahora - enviados[clave] < ENVIAR then return true end
	U.Podar(enviados, ENVIAR, ahora)
	enviados[clave] = ahora
	return false
end

Co.MOTIVOS = {
	sinPlan = "No tienes un plan con metas para compartir (Mis planes).",
	sinGuia = "No estás siguiendo ninguna guía.",
	espera = "Ya se lo compartiste hace un momento.",
	red = "Ahora no se puede hablar con la manada. Prueba en un rato.",
}
local function decir(por) if Co.MOTIVOS[por] then U.Decir(L[Co.MOTIVOS[por]]) end end

function Co.Plan(f)
	local destino, clave = destinoDe(f)
	if not (destino and clave) then return false, "red" end
	local pl = Co.PuedePlan()
	if not pl then decir("sinPlan") return false, "sinPlan" end
	if frenar("p:" .. clave) then decir("espera") return false, "espera" end
	local texto, puestas, total = Co.Codificar(pl.nombre, pl.metas, PARTES * TROZO)
	local n = math.min(PARTES, math.ceil(#texto / TROZO))
	local id = tostring(math.random(1000, 9999))
	for i = 1, n do
		local trozo = texto:sub((i - 1) * TROZO + 1, i * TROZO)
		if not M.Red.EnviarLibre(format("rp%s:%s:%d", id, clave, i), format("%sr|p|%s|%d|%d|%s", V, id, i, n, trozo), destino) then
			decir("red")
			return false, "red"
		end
	end
	U.Decir(format(L["Le compartiste tu plan «%s» a %s."], pl.nombre or "?", f.nombre or "?"))
	if puestas < total then
		U.Decir(format(L["Tu plan es largo: se compartieron %d de %d metas."], puestas, total))
	end
	return true, puestas, total
end

function Co.Guia(f)
	local destino, clave = destinoDe(f)
	if not (destino and clave) then return false, "red" end
	local g = Co.PuedeGuia()
	if not g then decir("sinGuia") return false, "sinGuia" end
	if frenar("g:" .. clave) then decir("espera") return false, "espera" end
	local E = A.Engine
	local paso = E and E.GetStepIndex and tonumber(E.GetStepIndex()) or 0
	local id = tostring(g.id):gsub("|", "")
	if not M.Red.EnviarLibre("rg:" .. clave, format("%sr|g|%s|%d", V, id, paso), destino) then decir("red") return false, "red" end
	U.Decir(format(L["Le compartiste tu guía «%s» a %s."], g.nombre or "?", f.nombre or "?"))
	return true
end

---------------------------------------------------------------------------
-- Recibir
---------------------------------------------------------------------------

local tarjetas = {} -- clave -> GetTime de la última
local trozos = {}   -- clave .. ":" .. id -> { n, partes = {}, at }

local function puedeRecibir(clave, remitente)
	if not activo() then return false end
	if not (U.EnMiGrupo(remitente) or (M.Ficha and M.Ficha.DeMiHermandad(remitente))) then return false end
	local ahora = U.Ahora()
	if tarjetas[clave] and ahora - tarjetas[clave] < CADA then return false end
	return true
end

function Co.AceptarPlan(nombre, metas, de)
	local P = rawget(_G, "AlfaPlanes")
	if type(P) ~= "table" or type(P.Recibir) ~= "function" then return false end
	local pl = P.Recibir(format(L["%s (de %s)"], nombre or "?", de or "?"), metas)
	if not pl then U.Decir(L["Ese plan no trae metas que entienda tu Alfa."]) return false end
	if type(P.Seguir) == "function" then P.Seguir(pl.id) end
	U.Decir(format(L["Ya sigues el plan «%s»."], pl.nombre))
	return true
end

function Co.AceptarGuia(id, de)
	local R = rawget(_G, "AlfaRuta")
	if type(R) ~= "table" or type(R.SeguirGuia) ~= "function" or not R.SeguirGuia(id) then
		U.Decir(L["No tienes esa guía en tu Alfa: quizá es de otra facción o de otra versión."])
		return false
	end
	U.Decir(format(L["Ya sigues la guía que te compartió %s."], de or "?"))
	return true
end

local function tarjetaPlan(clave, remitente, nombre, metas)
	tarjetas[clave] = U.Ahora()
	local de = U.Mostrar(remitente)
	aviso({ icono = "ic-lista", tono = "acento", duracion = 30, clave = "plan:" .. clave, prioridad = 3,
		titulo = format(L["%s te comparte su plan"], de),
		texto = format(L["«%s»: %s."], nombre, N.Plural(#metas, L["%d meta"], L["%d metas"])),
		accion = { texto = L["Aceptar"], alClic = function() Co.AceptarPlan(nombre, metas, de) end } })
end

local function tarjetaGuia(clave, remitente, id)
	tarjetas[clave] = U.Ahora()
	local de = U.Mostrar(remitente)
	local R = rawget(_G, "AlfaRuta")
	local nombre = type(R) == "table" and type(R.NombreGuia) == "function" and R.NombreGuia(id) or nil
	aviso({ icono = "ic-guia", tono = "acento", duracion = 30, clave = "guia:" .. clave, prioridad = 3,
		titulo = format(L["%s te comparte su guía"], de),
		texto = nombre and format(L["«%s»: ¿la sigues tú también?"], nombre) or L["Una guía que no tienes en tu Alfa."],
		accion = nombre and { texto = L["Aceptar"], alClic = function() Co.AceptarGuia(id, de) end } or nil,
		donde = not nombre and "chat" or nil })
end

M.Red.Oyentes.r = function(clave, remitente, _, f, canal)
	if canal ~= "WHISPER" then return end
	if f[1] == "g" then
		local id = f[2]
		if type(id) ~= "string" or id == "" or #id > 120 or not puedeRecibir(clave, remitente) then return end
		tarjetaGuia(clave, remitente, id)
	elseif f[1] == "p" then
		local id, i, n = f[2], tonumber(f[3]), tonumber(f[4])
		if not (id and id:match("^%d+$") and i and n and n >= 1 and n <= PARTES and i >= 1 and i <= n) then return end
		if not activo() then return end
		local llave = clave .. ":" .. id
		local ahora = U.Ahora()
		for k, x in pairs(trozos) do if ahora - (x.at or 0) > 120 then trozos[k] = nil end end
		local t = trozos[llave]
		if not t then t = { n = n, partes = {}, at = U.Ahora() } trozos[llave] = t end
		if t.n ~= n then return end
		t.partes[i] = f[5] or ""
		for k = 1, n do if not t.partes[k] then return end end
		trozos[llave] = nil
		if not puedeRecibir(clave, remitente) then return end
		local nombre, metas = Co.Decodificar(concat(t.partes, "", 1, n))
		if not nombre or #metas == 0 then return end
		tarjetaPlan(clave, remitente, nombre, metas)
	end
end

-- Para el banco.
function Co.Olvidar() enviados, tarjetas, trozos = {}, {}, {} end
