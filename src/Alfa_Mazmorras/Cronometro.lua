-- Alfa - Mazmorras: el cronómetro de las mazmorras (1.3.7). toxic3000 /
-- La Jauría. GPL-3.0.
--
-- Dos cosas que el juego no te dice:
--   * cuánto tardas en cada mazmorra: la vuelta empieza al entrar y termina
--     al vencer a su último jefe (Datos.lua llama a Cr.Fin). Se guarda tu
--     récord por mazmorra (por personaje), y la vuelta en curso sobrevive a
--     un /reload y a salir un momento (hasta VUELTA segundos fuera);
--   * el límite de instancias por hora del juego (LIMITE por cuenta): cada
--     instancia nueva en la que entras cuenta una hora. Volver a la misma
--     (sin reiniciarla) no cuenta otra vez. Con el límite lleno: «Puedes
--     entrar a otra en 12 min».
-- Solo se leen los eventos de entrar y salir y el aviso del juego al
-- reiniciar una instancia (CHAT_MSG_SYSTEM, INSTANCE_RESET_SUCCESS). Nada
-- en combate y nada se manda a nadie.
--
-- Datos: por personaje N.DatosPersonaje("mazmorras").crono[key] =
-- { mejor, ultima, veces } y .vuelta = { key, inicio, visto }; por cuenta
-- N.Datos("mazmorras").horas = { { t, m }, ... } (m: el mapa de la instancia).
--
--   Cr.Estado() -> { hora, limite, libreEn, dentro = { key, seg } | nil }
--   Cr.Record(key) -> segundos | nil ; Cr.Datos(key) -> { mejor, ultima, veces } | nil
--   Cr.Fin(key) -> { seg, record, antes } | nil
--   Cr.Linea() -> texto | nil   (para la página: «Esta hora: 3 de 5 instancias»)

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)
local D = M.D

local type, pairs, ipairs, tonumber, pcall, format = type, pairs, ipairs, tonumber, pcall, string.format
local max, min, floor = math.max, math.min, math.floor

local Cr = {}
M.Crono = Cr

local ID = D.ID
Cr.LIMITE = 5      -- instancias por hora (Clásico; Forever usa la misma regla)
Cr.HORA = 3600
local VUELTA = 1800 -- media hora fuera y la vuelta se olvida
local MAX_HORAS = 20

local function ahora() return D.Ahora() end
local function leer(v) return D.Legible(v) end

local function prog()
	local d = N.DatosPersonaje(ID)
	if type(d.crono) ~= "table" then d.crono = {} end
	return d
end

local function cuenta()
	local d = N.Datos(ID)
	if type(d.horas) ~= "table" then d.horas = {} end
	return d
end

-- -> dentro, tipo, mapa de la instancia
local function instancia()
	if not IsInInstance then return false end
	local ok, dentro, tipo = pcall(IsInInstance)
	dentro, tipo = ok and leer(dentro), ok and leer(tipo)
	if dentro ~= true or (tipo ~= "party" and tipo ~= "raid") then return false end
	local mapa
	if GetInstanceInfo then
		local ok2, _, _, _, _, _, _, _, m = pcall(GetInstanceInfo)
		mapa = ok2 and tonumber(leer(m)) or nil
	end
	return true, tipo, mapa
end
Cr.Instancia = instancia

---------------------------------------------------------------------------
-- El límite por hora
---------------------------------------------------------------------------

-- Las entradas de la última hora (lo viejo se borra).
local function recientes()
	local c = cuenta()
	local t = ahora()
	local out = {}
	for _, e in ipairs(c.horas) do
		if type(e) == "table" and type(e.t) == "number" and t - e.t < Cr.HORA then out[#out + 1] = e end
	end
	while #out > MAX_HORAS do table.remove(out, 1) end
	c.horas = out
	return out
end

-- Entraste a una instancia: cuenta si es nueva (otra, o la misma reiniciada).
local function contarEntrada(mapa)
	local lista = recientes()
	local c = cuenta()
	local t = ahora()
	local ultima
	for _, e in ipairs(lista) do
		if e.m == mapa and (not ultima or e.t > ultima.t) then ultima = e end
	end
	if ultima and not (c.reinicio and c.reinicio > ultima.t) then
		ultima.visto = t
		return false
	end
	lista[#lista + 1] = { t = t, m = mapa or 0 }
	return true
end
Cr.ContarEntrada = contarEntrada

function Cr.Estado()
	local lista = recientes()
	local n = #lista
	local libre
	if n >= Cr.LIMITE then
		local mas = lista[n - Cr.LIMITE + 1]
		libre = max(0, (mas.t + Cr.HORA) - ahora())
	end
	local v = prog().vuelta
	local dentro
	if type(v) == "table" and v.key and instancia() then
		dentro = { key = v.key, seg = max(0, ahora() - (v.inicio or ahora())) }
	end
	return { hora = n, limite = Cr.LIMITE, libreEn = libre, dentro = dentro }
end

-- «Esta hora: 3 de 5 instancias» / «Puedes entrar a otra en 12 min».
function Cr.Linea()
	local e = Cr.Estado()
	if e.hora == 0 then return nil end
	if e.libreEn then
		local min_ = max(1, floor(e.libreEn / 60 + 0.5))
		return format(L["Llegaste al límite del juego (%d instancias por hora): puedes entrar a otra en %d min."], e.limite, min_), "aviso"
	end
	return format(L["Esta hora: %d de %d instancias que deja el juego."], e.hora, e.limite), e.hora >= e.limite - 1 and "aviso" or "neutro"
end

---------------------------------------------------------------------------
-- La vuelta
---------------------------------------------------------------------------

function Cr.Datos(key)
	local r = prog().crono[key]
	return type(r) == "table" and r or nil
end
function Cr.Record(key)
	local r = Cr.Datos(key)
	return r and type(r.mejor) == "number" and r.mejor or nil
end

local function empezar(key)
	local d = prog()
	local v = d.vuelta
	local t = ahora()
	local visto = type(v) == "table" and (v.visto or v.inicio) or 0
	-- 1.3.7: la instancia se reinició después de la última vez que te vimos: vuelta nueva.
	local reinicio = tonumber(cuenta().reinicio)
	if type(v) == "table" and v.key == key and (t - visto) < VUELTA and not (reinicio and reinicio > visto) then
		v.visto = t
		return v
	end
	d.vuelta = { key = key, inicio = t, visto = t }
	return d.vuelta
end
Cr.Empezar = empezar

-- El último jefe cayó: -> { seg, record (true si es el mejor), antes (el récord de antes) }
function Cr.Fin(key)
	local d = prog()
	local v = d.vuelta
	if type(v) ~= "table" or v.key ~= key or type(v.inicio) ~= "number" then return nil end
	local seg = max(1, ahora() - v.inicio)
	d.vuelta = nil
	local r = d.crono[key]
	if type(r) ~= "table" then
		r = { veces = 0 }
		d.crono[key] = r
	end
	local antes = r.mejor
	r.veces = (r.veces or 0) + 1
	r.ultima = seg
	local record = not antes or seg < antes
	if record then r.mejor = seg end
	D.Avisar("crono")
	return { seg = seg, record = record and antes ~= nil, antes = antes, primera = antes == nil }
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------

local fuera = true
local function alEntrar()
	local dentro, _, mapa = instancia()
	if not dentro then
		local v = prog().vuelta
		if not fuera and type(v) == "table" then v.visto = ahora() end
		fuera = true
		return
	end
	fuera = false
	contarEntrada(mapa)
	if not D.Listo() then return end
	local key = D.MazmorraActual()
	if key then empezar(key) end
	-- 1.3.7: dentro, «te vimos» cada minuto: un /reload o una reconexión tras
	-- media hora adentro no reinicia la vuelta.
	if N.Cada then
		N.Cada("mazmorras.cronoVisto", 60, function()
			local v = prog().vuelta
			if not instancia() then
				if N.Quitar then N.Quitar("mazmorras.cronoVisto") end
				return
			end
			if type(v) == "table" then v.visto = ahora() end
		end)
	end
	D.Avisar("crono")
end
Cr.AlEntrar = alEntrar

A.RegisterEvent("PLAYER_LEAVING_WORLD", function()
	local v = prog().vuelta
	if not fuera and type(v) == "table" then v.visto = ahora() end
end)

A.RegisterEvent("PLAYER_ENTERING_WORLD", function()
	local f = function() N.FueraDeCombate("mazmorras.crono", function() pcall(alEntrar) end) end
	if N.Una then N.Una("mazmorras.crono", 3, f) elseif A.After then A.After(3, f) else f() end
end)

-- «Minas de la Muerte se ha reiniciado.»: la siguiente entrada cuenta como nueva.
local reinicio
A.RegisterEvent("CHAT_MSG_SYSTEM", function(_, texto)
	if type(texto) ~= "string" or D.Legible(texto) == nil then return end
	if not reinicio then reinicio = D.Patron(rawget(_G, "INSTANCE_RESET_SUCCESS")) end
	if reinicio and texto:find(reinicio) then cuenta().reinicio = ahora() end
end)
