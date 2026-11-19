-- Alfa - Núcleo: los errores de Alfa que se atrapan (1.2.9). toxic3000 / La
-- Jauría. GPL-3.0.
--
-- Alfa se pone delante del manejador de errores del juego (el de siempre,
-- BugSack/BugGrabber o el que haya) sin quitarlo: anota el error y se lo pasa
-- tal cual. Solo se anotan los errores cuyo mensaje o cuya pila nombran una
-- carpeta de Alfa (Alfa o Alfa_*, del autor de Alfa). Con BugGrabber (que no
-- deja cambiar el manejador) se escucha su aviso BugGrabber_BugGrabbed.
--
-- Se guardan en la cuenta (AlfaNucleoDB.errores), sin repetir: cada error una
-- vez, con cuántas veces salió, la versión de Alfa y cuándo fue la última.
-- Solo los últimos 30. Nunca llevan el nombre del personaje ni el reino.
--
--   N.Errores() -> { { msg, n, v, cuando, t, addon }, ... }  el más nuevo al final
--   N.ErroresTexto() -> texto para copiar ("" si no hay)
--   N.BorrarErrores()
--   N.AnotarError(msg, pila) -> true si era de Alfa (lo usa el manejador; y las pruebas)
--   N.ManejadorErrores        el manejador que se pone delante del del juego

local ADDON, N = ...

local type, tostring, pairs, ipairs, pcall, format = type, tostring, pairs, ipairs, pcall, string.format

local MAX = 30
local MAX_LINEA = 300
local sesion = {}   -- lo que llegó antes de que el juego cargara lo guardado
local cargado = false

local function lista()
	if not cargado then return sesion end
	local d = N.Datos("errores")
	d.lista = type(d.lista) == "table" and d.lista or {}
	return d.lista
end

-- Una carpeta de Alfa: "Alfa" o "Alfa_Algo", y si el juego dice su autor,
-- que sea el de Alfa (otro autor puede tener un addon "Alfa_Lo_Que_Sea").
local nuestras = {}
local function esNuestra(carpeta)
	if nuestras[carpeta] ~= nil then return nuestras[carpeta] end
	local si = carpeta == "Alfa" or carpeta:find("^Alfa_") ~= nil
	if si then
		local get = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
		local ok, autor = pcall(get, carpeta, "Author")
		-- Los paquetes de datos dicen "Alfa"; los módulos, "toxic3000 - La Jauria".
		if ok and type(autor) == "string" and autor ~= "" and autor ~= "Alfa"
			and not autor:lower():find("toxic3000", 1, true) then si = false end
	end
	nuestras[carpeta] = si
	return si
end

local function carpetaAlfa(s)
	if type(s) ~= "string" then return nil end
	for carpeta in s:gmatch("AddOns[/\\](Alfa[%w_]*)[/\\]") do
		if esNuestra(carpeta) then return carpeta end
	end
	return nil
end

local function cortar(s, n)
	if #s <= n then return s end
	return (s:sub(1, n - 3):gsub("[\192-\255][\128-\191]*$", "")) .. "..."
end

-- La primera línea, sin la ruta larga de la carpeta de addons.
local function limpiar(msg)
	local s = msg:match("^[^\n]*") or ""
	s = s:gsub('%[string "@?([^"]*)"%]', "%1")
	s = s:gsub("Interface[/\\]AddOns[/\\]", "")
	return cortar(s, MAX_LINEA)
end

function N.AnotarError(msg, pila)
	if issecretvalue and (issecretvalue(msg) or issecretvalue(pila)) then return false end
	if type(msg) ~= "string" then
		if msg == nil then return false end
		msg = tostring(msg)
	end
	local carpeta = carpetaAlfa(msg) or carpetaAlfa(pila)
	if not carpeta then return false end
	local linea = limpiar(msg)
	local v = tostring(N.version or "dev")
	local l = lista()
	local t = time and time() or 0
	local cuando = date and date("%d/%m %H:%M") or ""
	for i = #l, 1, -1 do
		local e = l[i]
		if type(e) == "table" and e.msg == linea and e.v == v then
			table.remove(l, i)
			e.n, e.t, e.cuando = (tonumber(e.n) or 1) + 1, t, cuando
			l[#l + 1] = e
			return true
		end
	end
	l[#l + 1] = { msg = linea, n = 1, v = v, t = t, cuando = cuando, addon = carpeta }
	while #l > MAX do table.remove(l, 1) end
	return true
end

function N.Errores() return lista() end

function N.BorrarErrores()
	local l = lista()
	for i = #l, 1, -1 do l[i] = nil end
end

function N.ErroresTexto()
	local l = lista()
	if #l == 0 then return "" end
	local out = { format("Alfa %s - %d", tostring(N.version or "dev"), #l) }
	for _, e in ipairs(l) do
		if type(e) == "table" then
			out[#out + 1] = format("%dx [%s] %s  %s", tonumber(e.n) or 1, tostring(e.v or "?"), tostring(e.cuando or ""), tostring(e.msg or ""))
		end
	end
	return table.concat(out, "\n")
end

---------------------------------------------------------------------------
-- El manejador: delante del que haya, nunca en su lugar
---------------------------------------------------------------------------
local previo
local dentro = false

local function manejador(msg, ...)
	if not dentro then
		dentro = true
		local okP, pila = pcall(debugstack, 2, 20, 0)
		pcall(N.AnotarError, msg, okP and pila or nil)
		dentro = false
	end
	if previo then return previo(msg, ...) end
end
N.ManejadorErrores = manejador

local function ponerManejador()
N.PonerManejador = ponerManejador
	if not (geterrorhandler and seterrorhandler) then return end
	local ok, actual = pcall(geterrorhandler)
	if not ok or actual == manejador then return end
	previo = actual
	pcall(seterrorhandler, manejador)
end
ponerManejador()

-- Para las pruebas: el manejador que estaba antes (al que se pasa el error).
function N.ManejadorPrevio() return previo end

local function alCargar()
	if cargado then return end
	cargado = true
	local l = lista()
	for _, e in ipairs(sesion) do
		local repetido = false
		for _, x in ipairs(l) do
			if type(x) == "table" and x.msg == e.msg and x.v == e.v then
				x.n, x.t, x.cuando = (tonumber(x.n) or 1) + e.n, e.t, e.cuando
				repetido = true
			end
		end
		if not repetido then l[#l + 1] = e end
	end
	sesion = {}
	while #l > MAX do table.remove(l, 1) end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self, evento, nombre)
	if evento == "ADDON_LOADED" then
		if nombre == ADDON then alCargar() end
		return
	end
	alCargar()
	self:UnregisterEvent("ADDON_LOADED")
	-- BugGrabber no deja cambiar el manejador: se escucha su aviso. Si el
	-- nuestro sigue puesto, ya lo vimos (y no se cuenta dos veces).
	local BG = rawget(_G, "BugGrabber")
	if type(BG) == "table" and type(BG.RegisterCallback) == "function" then
		pcall(BG.RegisterCallback, N, "BugGrabber_BugGrabbed", function(_, e)
			local ok, actual = pcall(geterrorhandler)
			if ok and actual == manejador then return end
			if type(e) == "table" then pcall(N.AnotarError, e.message, e.stack) end
		end)
	end
end)
