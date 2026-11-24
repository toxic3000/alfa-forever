-- Alfa - Núcleo: «La última vez…» (1.3.8). toxic3000 / La Jauría. GPL-3.0.
--
-- Pedido de Toxic (mejora 9): al entrar, si saliste con cosas pendientes
-- (misiones listas para entregar, una guía a medias, una carta con objetos
-- por vencer), un resumen corto en la tarjeta de Hoy, no como aviso: va a la
-- fila «Mientras entrabas» (N.GuardarAlEntrar, Entrada.lua), con su botón.
--
-- Qué se guarda (por personaje, N.DatosPersonaje("ultimaVez")), al salir del
-- juego (PLAYER_LOGOUT) y al cambiar de mapa (PLAYER_LEAVING_WORLD), sin
-- nada pesado: cuántas misiones de tu registro están listas, el nombre de tu
-- guía y su avance (el motor: Engine.GetGuide / GetProgress) y, si abriste
-- el buzón, cuándo vence la primera carta con objetos o dinero (MAIL_INBOX_UPDATE).
-- Solo al entrar de verdad (no con /reload) y si saliste hace más de 10 min.
--
--   N.UltimaVez.Guardar()            lo anota ahora (el banco lo llama)
--   N.UltimaVez.Resumen([d]) -> titulo, texto, accion | nil
--   N.UltimaVez.AlEntrar()           lo pone en Hoy si hay algo
-- Ajuste: nucleo.ultimaVez (de fábrica, prendido).

local _, N = ...
local A = N.A
local K = N.Kit
local L = K and K.L or N.Textos(N.EN)

local type, pcall, tonumber, rawget, format = type, pcall, tonumber, rawget, string.format
local floor, concat = math.floor, table.concat

local U = {}
N.UltimaVez = U

local MIN_FUERA = 600        -- s fuera del juego para que valga contarlo
local CARTA_DIAS = 3         -- días: una carta que vence antes, se cuenta
local VIEJO = 30 * 86400     -- más de un mes fuera: ya no se cuenta nada

if A and A.RegisterDefaults then A.RegisterDefaults("nucleo", { ultimaVez = true }) end

local function reloj() return (GetServerTime and GetServerTime()) or (time and time()) or 0 end
local function datos() return N.DatosPersonaje("ultimaVez") end
-- (1.3.8 revisión) Todos los valores (GetInboxHeaderInfo da más de tres:
-- sin ellos, la carta por vencer nunca se anotaba).
local function devolver(ok, ...)
	if not ok then return nil end
	return ...
end
local function llamar(fn, ...)
	if type(fn) ~= "function" then return nil end
	return devolver(pcall(fn, ...))
end
local function num(v) if N.Secreto(v) then return nil end return tonumber(v) end
local function texto(v) if type(v) ~= "string" or N.Secreto(v) or v == "" then return nil end return v end

-- Cuántas misiones de tu registro están listas para entregar.
local function listas()
	local Q = C_QuestLog
	if not (Q and Q.GetNumQuestLogEntries and Q.GetInfo and Q.ReadyForTurnIn) then return 0 end
	local n = 0
	for i = 1, num(llamar(Q.GetNumQuestLogEntries)) or 0 do
		local info = llamar(Q.GetInfo, i)
		if type(info) == "table" and not N.Si(info.isHeader) then
			local q = num(info.questID)
			if q and N.Si(llamar(Q.ReadyForTurnIn, q)) then n = n + 1 end
		end
	end
	return n
end

-- Tu guía y su avance: nombre, hechos, total | nil.
local function guia()
	local E = A and A.Engine
	if not (E and E.GetGuide) then return nil end
	local g = llamar(E.GetGuide)
	if type(g) ~= "table" then return nil end
	local nombre = texto(g.title) or texto(g.name)
	local U2 = A.UI and A.UI.GuideLabel
	if type(U2) == "function" then nombre = texto(llamar(U2, g)) or nombre end
	local hechos, total = llamar(E.GetProgress)
	hechos, total = tonumber(hechos), tonumber(total)
	if not (nombre and total and total > 0 and hechos) then return nil end
	return nombre, hechos, total
end

function U.Guardar()
	local d = datos()
	d.t = reloj()
	d.listas = listas()
	local nombre, hechos, total = guia()
	if nombre and hechos < total then
		d.guia, d.hechos, d.total = nombre, hechos, total
	else
		d.guia, d.hechos, d.total = nil, nil, nil
	end
	return d
end

-- El buzón abierto: la carta con objetos o dinero que vence antes.
local function leerBuzon()
	local n = num(llamar(rawget(_G, "GetInboxNumItems")))
	if not n then return end
	local menor
	for i = 1, n do
		local _, _, _, _, dinero, cobro, dias, objetos = llamar(rawget(_G, "GetInboxHeaderInfo"), i)
		dias, dinero, cobro = num(dias), num(dinero) or 0, num(cobro) or 0
		local conAlgo = (objetos ~= nil and not N.Secreto(objetos) and objetos ~= false and objetos ~= 0) or dinero > 0
		if dias and conAlgo and cobro == 0 and (not menor or dias < menor) then menor = dias end
	end
	datos().carta = menor and (reloj() + floor(menor * 86400)) or nil
end
U.LeerBuzon = leerBuzon

local function dias(seg)
	local d = seg / 86400
	if d >= 2 then return N.Plural(floor(d), L["%d día"], L["%d días"]) end
	if d >= 1 then return L["un día"] end
	return L["menos de un día"]
end

-- -> titulo, texto, accion | nil
function U.Resumen(d)
	d = d or datos()
	local ahora = reloj()
	if not tonumber(d.t) or ahora - d.t > VIEJO then return nil end
	local partes = {}
	local n = tonumber(d.listas) or 0
	if n > 0 then
		partes[#partes + 1] = N.Plural(n, L["Dejaste %d misión lista para entregar."], L["Dejaste %d misiones listas para entregar."])
	end
	local accion
	if type(d.guia) == "string" and tonumber(d.hechos) and tonumber(d.total) then
		partes[#partes + 1] = format(L["Tu guía «%s» iba en %d de %d pasos."], d.guia, d.hechos, d.total)
		accion = { texto = L["Seguir mi guía"], alClic = function() N.Abrir("rutas") end }
	end
	local c = tonumber(d.carta)
	if c and c > ahora and c - ahora < CARTA_DIAS * 86400 then
		partes[#partes + 1] = format(L["Una carta con objetos vence en %s."], dias(c - ahora))
	end
	if #partes == 0 then return nil end
	if not accion and n > 0 then accion = { texto = L["Ver mi ruta"], alClic = function() N.Abrir("rutas") end } end
	return L["La última vez…"], concat(partes, "\n"), accion
end

function U.AlEntrar()
	if A and A.Get and A.Get("nucleo.ultimaVez") == false then return false end
	local d = datos()
	if not tonumber(d.t) or reloj() - d.t < MIN_FUERA then return false end
	local titulo, txt, accion = U.Resumen(d)
	if not titulo or not N.GuardarAlEntrar then return false end
	N.GuardarAlEntrar({ id = "ultimaVez", titulo = titulo, texto = txt, icono = "ic-reloj", accion = accion, origen = "ultimaVez" })
	return true
end

if A and A.RegisterEvent then
	local entro = false
	A.RegisterEvent("PLAYER_ENTERING_WORLD", function(_, esLogin, esRecarga)
		if entro then return end
		entro = true
		if esLogin == true and esRecarga ~= true then pcall(U.AlEntrar) end
	end)
	A.RegisterEvent("PLAYER_LOGOUT", function() pcall(U.Guardar) end)
	A.RegisterEvent("PLAYER_LEAVING_WORLD", function() pcall(U.Guardar) end)
	A.RegisterEvent("MAIL_INBOX_UPDATE", function() pcall(leerBuzon) end)
end
