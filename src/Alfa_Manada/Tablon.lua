-- Alfa - La Jauría: el tablón de la manada (1.3.0). toxic3000 / La Jauría.
-- GPL-3.0.
--
-- Quién busca grupo y para qué: una mazmorra, una misión o farmear, y a qué
-- nivel. Pones tu anuncio desde la página de La Jauría (o /alfa tablon
-- <texto>) y lo quitas cuando quieras; se va solo a la hora. Les llega a los
-- lobos de tu hermandad que usan Alfa (sin pedir que compartas tu
-- ubicación): nada sale al chat. En la página, «Susurrar» abre el cuadro del
-- chat con su nombre e «Invitar» lo invita a tu grupo (siempre tu clic).
--
-- Mensajes (Red.lua, solo por la hermandad):
--   1b|<tipo m/q/f>|<nivel>|<edad>|<texto>   mi anuncio (edad: segundos que
--                                             lleva puesto). Se repite cada
--                                             REPITE para quien llegó después.
--   1b|x                                      lo quité
--   1b|?                                      ¿qué hay en el tablón? (al
--                                             entrar): quien tiene uno lo repite
-- Ajuste manada.tablon (ver y poner anuncios).
--
--   Tb.Poner(tipo, texto) -> ok, por qué ; Tb.Quitar()
--   Tb.Mio() -> anuncio | nil ; Tb.Lista() -> { anuncio } (el tuyo primero)
--   Tb.TIPOS, Tb.NombreTipo(tipo)

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local U, L, ID = M.U, M.L, M.ID

local Tb = {}
M.Tablon = Tb

local type, tonumber, tostring, pairs, ipairs, format, floor, sort = type, tonumber, tostring, pairs, ipairs, string.format, math.floor, table.sort

local V = "1"
local DURA = 3600     -- un anuncio se va solo a la hora
local REPITE = 600    -- el tuyo se repite cada 10 minutos
local CADA = 120      -- segundos entre dos anuncios tuyos (1.3.8: dos minutos, contra el spam)
local CADA_TARJETA = 120 -- (1.3.8) de la misma persona, una tarjeta cada tanto
local CADA_OIDO = 5   -- de la misma persona, uno cada tanto
local TOPE = 40       -- anuncios de otros a la vez

Tb.TIPOS = { "m", "q", "f" }
local NOMBRES = { m = "Mazmorra", q = "Misión", f = "Farmear" }
function Tb.NombreTipo(t) return L[NOMBRES[t] or "Mazmorra"] end

local function activo() return N.Get(ID, "tablon") ~= false end

Tb.version = 0
local function cambio()
	Tb.version = Tb.version + 1
	if M.Avisar then M.Avisar() end
end

Tb.MOTIVOS = {
	apagado = "El tablón está apagado (Ajustes de La Jauría).",
	hermandad = "Necesitas una hermandad: el tablón es de los lobos de la tuya.",
	texto = "Escribe qué buscas: «Minas de la Muerte, falta sanador».",
	espera = "Espera un par de minutos antes de volver a poner tu anuncio.",
	red = "Ahora no se puede hablar con la manada. Prueba en un rato.",
}

local function limpiar(s)
	if type(s) ~= "string" or U.Secreto(s) then return nil end
	s = s:gsub("[|\n\r]", ""):gsub("^%s+", ""):gsub("%s+$", "")
	s = U.Cortar(s, 50) -- hasta 50 letras (1.3.1: U.Cortar)
	return s ~= "" and s or nil
end

local function miNivel()
	return UnitLevel and U.Numero(UnitLevel("player")) or 0
end

---------------------------------------------------------------------------
-- Tu anuncio (por personaje: un /reload no lo borra)
---------------------------------------------------------------------------

local function datos() return N.DatosPersonaje(ID) end

function Tb.Mio()
	local m = datos().tablon
	if type(m) ~= "table" then return nil end
	if U.Reloj() - (tonumber(m.desde) or 0) > DURA then
		datos().tablon = nil
		return nil
	end
	return m
end

local ultimoEnvio = -math.huge
local function enviarMio()
	local m = Tb.Mio()
	if not m then return false end
	local edad = math.max(0, floor(U.Reloj() - m.desde))
	local ok = M.Red.EnviarHermandad("b", format("%sb|%s|%d|%d|%s", V, m.tipo, m.nivel or 0, edad, m.texto))
	if ok then ultimoEnvio = U.Ahora() end
	return ok
end

local ultimoPuesto = -math.huge
function Tb.Poner(tipo, texto)
	if not activo() then return false, "apagado" end
	if not NOMBRES[tipo] then tipo = "m" end
	texto = limpiar(texto)
	if not texto then return false, "texto" end
	if not U.EnHermandad() then return false, "hermandad" end
	local ahora = U.Ahora()
	if ahora - ultimoPuesto < CADA then return false, "espera" end
	local antes = datos().tablon
	datos().tablon = { tipo = tipo, texto = texto, nivel = miNivel(), desde = U.Reloj() }
	if not enviarMio() then
		datos().tablon = antes
		return false, "red"
	end
	ultimoPuesto = ahora
	cambio()
	return true
end

function Tb.PonerYDecir(tipo, texto)
	local ok, por = Tb.Poner(tipo, texto)
	if ok then
		U.Decir(L["Tu anuncio ya está en el tablón de la manada. Se quita solo en una hora."])
	elseif Tb.MOTIVOS[por] then
		U.Decir(L[Tb.MOTIVOS[por]])
	end
	return ok
end

function Tb.Quitar()
	if not datos().tablon then return false end
	datos().tablon = nil
	if U.EnHermandad() then M.Red.EnviarHermandad("b", V .. "b|x") end
	cambio()
	return true
end

---------------------------------------------------------------------------
-- Los anuncios de la manada
---------------------------------------------------------------------------

local suyos = {} -- clave -> { clave, nombre, destino, tipo, nivel, texto, at (GetTime al ponerlo) }
local oidos = {}

function Tb.Lista()
	local out = {}
	if not activo() then return out end
	local m = Tb.Mio()
	if m then
		out[1] = { mio = true, nombre = L["Tú"], tipo = m.tipo, nivel = m.nivel, texto = m.texto,
			edad = U.Reloj() - m.desde }
	end
	local ahora = U.Ahora()
	local otros = {}
	for clave, x in pairs(suyos) do
		local edad = ahora - x.at
		if edad > DURA then suyos[clave] = nil
		else
			x.edad = edad
			otros[#otros + 1] = x
		end
	end
	sort(otros, function(a, b)
		if a.edad ~= b.edad then return a.edad < b.edad end
		return a.nombre < b.nombre
	end)
	for _, x in ipairs(otros) do out[#out + 1] = x end
	return out
end

-- "Mazmorra · nivel 24 · hace 5 min"
function Tb.Dato(x)
	local partes = { Tb.NombreTipo(x.tipo) }
	if (x.nivel or 0) > 0 then partes[#partes + 1] = format(L["nivel %d"], x.nivel) end
	local hace = U.Hace(x.edad or 0)
	if hace then partes[#partes + 1] = hace end
	return table.concat(partes, "  \194\183  ")
end

function Tb.Susurrar(x) return x and x.destino and U.Susurrar(x.destino, "") or false end
function Tb.Invitar(x) return x and x.destino and U.Invitar(x.destino) or false end

local function numero(s, max)
	if type(s) ~= "string" or not s:match("^%d+$") or #s > 7 then return nil end
	local n = tonumber(s)
	return n and n <= max and n or nil
end

---------------------------------------------------------------------------
-- 1.3.8: «Busco grupo»: la tarjeta con «Me apunto» y quién se apunta
---------------------------------------------------------------------------

local function aviso(o)
	local K = N.Kit
	if M.U and M.U.Aviso then return M.U.Aviso(o) end
	U.Decir(o.titulo .. (o.texto and (" " .. o.texto) or ""))
end

local tarjetas = {} -- clave -> GetTime de la última tarjeta suya
local apuntados = {} -- clave -> m.desde del anuncio al que se apuntó

function Tb.MeApunto(x)
	if not (x and x.destino) then return false end
	local ok = M.Red.EnviarLibre("bs:" .. tostring(x.clave), V .. "b|s", x.destino)
	if ok then U.Decir(format(L["Le avisé a %s que te apuntas."], x.nombre or "?")) end
	return ok
end

-- Un anuncio nuevo de un lobo: la tarjeta (manada.tablonAviso), una cada CADA_TARJETA por persona.
local function tarjeta(x)
	if N.Get(ID, "tablonAviso") == false then return false end
	local ahora = U.Ahora()
	if tarjetas[x.clave] and ahora - tarjetas[x.clave] < CADA_TARJETA then return false end
	U.Podar(tarjetas, CADA_TARJETA, ahora)
	tarjetas[x.clave] = ahora
	aviso({ icono = "ic-manada", tono = "acento", duracion = 20, clave = "tablon:" .. x.clave, prioridad = 3,
		titulo = format(L["%s busca grupo: %s"], x.nombre or "?", Tb.NombreTipo(x.tipo)),
		texto = x.nivel and format(L["«%s» · nivel %d"], x.texto, x.nivel) or format(L["«%s»"], x.texto),
		accion = { texto = L["Me apunto"], alClic = function() Tb.MeApunto(x) end },
		acciones = { { texto = L["Susurrar"], alClic = function() Tb.Susurrar(x) end } } })
	return true
end
Tb.Tarjeta = tarjeta

-- Alguien se apuntó a tu anuncio: «Invitar» (tu clic). Una vez por persona y anuncio.
local function seApunta(clave, remitente)
	local m = Tb.Mio()
	if not m or apuntados[clave] == m.desde then return false end
	-- (1.3.8 revisión) Tu anuncio es para tu hermandad: un «me apunto» de
	-- cualquier otro no se toma. Lo de anuncios viejos se poda.
	if not (M.Ficha and M.Ficha.DeMiHermandad and M.Ficha.DeMiHermandad(remitente)) then return false end
	local n = 0
	for k, desde in pairs(apuntados) do
		if desde ~= m.desde then apuntados[k] = nil else n = n + 1 end
	end
	if n >= 40 then return false end
	apuntados[clave] = m.desde
	local nombre = U.Mostrar(remitente)
	aviso({ icono = "ic-manada", tono = "exito", duracion = 25, clave = "apunta:" .. clave, prioridad = 2,
		titulo = format(L["%s se apunta"], nombre or "?"), texto = format(L["A tu anuncio: «%s»."], m.texto),
		accion = { texto = L["Invitar"], alClic = function() U.Invitar(remitente) end },
		acciones = { { texto = L["Susurrar"], alClic = function() U.Susurrar(remitente, "") end } } })
	return true
end
Tb.SeApunta = seApunta

local repetirPedido = false
M.Red.Oyentes.b = function(clave, remitente, _, f, canal)
	-- 1.3.8: «me apunto», por susurro, a quien puso el anuncio.
	if canal == "WHISPER" then
		if f[1] == "s" and activo() then seApunta(clave, remitente) end
		return
	end
	if canal ~= "GUILD" or not activo() then return end
	if f[1] == "?" then
		-- Alguien entró: si tengo anuncio, lo repito (una vez, al rato).
		if Tb.Mio() and not repetirPedido and U.Ahora() - ultimoEnvio > 30 then
			repetirPedido = true
			A.After(2 + math.random() * 6, function()
				repetirPedido = false
				enviarMio()
			end)
		end
		return
	end
	if f[1] == "x" then
		if suyos[clave] then suyos[clave] = nil cambio() end
		return
	end
	local tipo = NOMBRES[f[1]] and f[1]
	local nivel, edad, texto = numero(f[2], 200), numero(f[3], DURA * 2), limpiar(f[4])
	if not (tipo and nivel and edad and texto) or edad > DURA then return end
	local ahora = U.Ahora()
	local antes = suyos[clave]
	if oidos[clave] and ahora - oidos[clave] < CADA_OIDO and antes then return end
	U.Podar(oidos, CADA_OIDO, ahora) -- (1.3.1)
	oidos[clave] = ahora
	if not antes then
		local n = 0
		for _ in pairs(suyos) do n = n + 1 end
		if n >= TOPE then return end
	end
	suyos[clave] = { clave = clave, nombre = U.Mostrar(remitente), destino = remitente, tipo = tipo,
		nivel = nivel > 0 and nivel or nil, texto = texto, at = ahora - edad }
	-- 1.3.8: un anuncio nuevo (no el mismo que se repite) trae su tarjeta.
	if (not antes or antes.texto ~= texto) and edad < REPITE then tarjeta(suyos[clave]) end
	cambio()
end
M.Red.Libres.b = true

function Tb.Olvidar() wipe(suyos) wipe(oidos) wipe(tarjetas) wipe(apuntados) ultimoPuesto = -math.huge cambio() end

---------------------------------------------------------------------------
-- Repetir el tuyo y preguntar al entrar
---------------------------------------------------------------------------

function Tb.Repetir()
	if not (activo() and U.EnHermandad() and Tb.Mio()) then return end
	if U.Ahora() - ultimoEnvio >= REPITE then enviarMio() end
end

A.OnLogin(function()
	M.Cada("manada.tablon", 60, function()
		Tb.Repetir()
		-- Los que caducan se van de la página.
		local antes = 0
		for _ in pairs(suyos) do antes = antes + 1 end
		local despues = #Tb.Lista() - (Tb.Mio() and 1 or 0)
		if despues ~= antes then cambio() end
	end)
	A.After(25, function()
		if activo() and U.EnHermandad() then
			M.Red.EnviarHermandad("b?", V .. "b|?")
			A.After(5, enviarMio)
		end
	end)
end)
