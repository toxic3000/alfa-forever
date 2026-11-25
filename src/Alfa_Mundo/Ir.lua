-- Alfa - Mundo: «Llévame» a quien sea, escribiendo su nombre (1.4.0, mejora
-- 39). toxic3000 / La Jauría. GPL-3.0.
--
--   /alfa ir <nombre>
-- Busca, en este orden, y la flecha te lleva al primero que encuentre:
--   1. tus marcadores (por nombre o nota);
--   2. un PNJ por su nombre (el buscador del motor sobre el Codex, en tu
--      idioma): de sus lugares, el más cercano a ti (tu continente primero);
--   3. una zona o una ciudad (el centro de su mapa).
-- Lo amistoso primero: un PNJ de la otra facción solo si no hay otro con ese
-- nombre. Sin nombre abre «Llévame a…» (Rutas). Si no encuentra nada, lo dice
-- y abre «Llévame a…» con lo que escribiste. Nunca en combate: lee el Codex
-- (lo espera y lo hace al salir).
--   Ir.Buscar(texto) -> { tipo = "marcador" | "pnj" | "zona", nombre, sub, mapa, x, y, f, z, m } | nil, por qué
--   Ir.Ir(texto) -> true | false, por qué

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)

local type, ipairs, pairs, pcall, tonumber, tostring, format = type, ipairs, pairs, pcall, tonumber, tostring, string.format

local Ir = {}
M.Ir = Ir

local FACCION = { Alliance = "A", Horde = "H" }

local function simple(t)
	local Bu = M.Buscar
	if Bu and Bu.Simple then return Bu.Simple(t) end
	return type(t) == "string" and t:lower() or ""
end

local function info()
	local C = A.Compat
	local ok, i = pcall(function() return C and C.GetPlayerInfo and C.GetPlayerInfo() end)
	return ok and type(i) == "table" and i or {}
end

-- Dónde estás, en el mundo: c, wx, wy (o nil).
local function aqui()
	local C, Mp = A.Compat, C_Map
	if not (C and C.MapToWorld and Mp and Mp.GetBestMapForUnit and Mp.GetPlayerMapPosition) then return nil end
	local ok, mapa = pcall(Mp.GetBestMapForUnit, "player")
	mapa = ok and N.Leer(mapa) or nil
	if type(mapa) ~= "number" then return nil end
	local bien, pos = pcall(Mp.GetPlayerMapPosition, mapa, "player")
	if not (bien and pos) then return nil end
	local x, y
	if type(pos.GetXY) == "function" then x, y = pos:GetXY() else x, y = pos.x, pos.y end
	x, y = N.Leer(x), N.Leer(y)
	if type(x) ~= "number" or type(y) ~= "number" then return nil end
	local c, wx, wy = C.MapToWorld(mapa, x * 100, y * 100)
	if not c then return nil end
	return { c = c, wx = wx, wy = wy }
end

-- El lugar de un PNJ más cercano a ti -> spawn | nil.
local function masCerca(spawns, yo)
	local C = A.Compat
	local mejor, nivel, dist
	for _, s in ipairs(type(spawns) == "table" and spawns or {}) do
		local map, x, y = tonumber(s.map), tonumber(s.x), tonumber(s.y)
		if map and x and y then
			local t, d = 1, 0
			if yo and C and C.MapToWorld then
				local c, wx, wy = C.MapToWorld(map, x, y, s.f)
				if c then
					d = (wx - yo.wx) ^ 2 + (wy - yo.wy) ^ 2
					t = c == yo.c and 0 or 1
				end
			end
			if not mejor or t < nivel or (t == nivel and d < dist) then mejor, nivel, dist = s, t, d end
		end
	end
	return mejor
end

local function amistoso(f)
	local mio = FACCION[info().faction or ""]
	return f == nil or f == "AH" or (mio ~= nil and type(f) == "string" and f:find(mio, 1, true) ~= nil)
end

local function buscarPnj(texto)
	local S, X = A.Search, A.Codex
	if not (S and type(S.Query) == "function" and X and type(X.Npc) == "function") then return nil end
	local ok, res = pcall(S.Query, texto, { kinds = { npc = true }, limit = 12, subtitles = false })
	if not (ok and type(res) == "table") then return nil end
	local q = simple(texto)
	local yo = aqui()
	local otro -- uno de la otra facción, por si no hay más
	for _, r in ipairs(res) do
		local bien, n = pcall(X.Npc, r.id)
		if bien and type(n) == "table" and not n.instance and type(n.spawns) == "table" and #n.spawns > 0 then
			local s = masCerca(n.spawns, yo)
			local nombre = type(r.title) == "string" and r.title or n.name
			if s and type(nombre) == "string" then
				local e = { tipo = "pnj", nombre = nombre, sub = type(n.subName) == "string" and n.subName ~= "" and n.subName or nil,
					mapa = tonumber(s.map), x = tonumber(s.x), y = tonumber(s.y), f = s.f, z = tonumber(s.z), id = r.id,
					exacto = simple(nombre) == q }
				if amistoso(n.faction) then return e end
				otro = otro or e
			end
		end
	end
	return otro
end

function Ir.Buscar(texto)
	texto = type(texto) == "string" and texto:match("^%s*(.-)%s*$") or ""
	if texto == "" then return nil, "vacio" end
	local Bu = M.Buscar
	local lugares = Bu and Bu.Buscar and Bu.Buscar(texto) or {}
	-- 1. Tus marcadores.
	for _, l in ipairs(lugares) do
		if l.tipo == "marcador" and l.m then
			return { tipo = "marcador", nombre = l.nombre, mapa = l.m.mapa, x = l.m.x, y = l.m.y, m = l.m }
		end
	end
	-- 2. Un PNJ (lee el Codex: nunca en combate).
	if InCombatLockdown and InCombatLockdown() then return nil, "combate" end
	local p = buscarPnj(texto)
	-- Una zona o ciudad con ese nombre gana a un PNJ que solo se le parece.
	local zona
	for _, l in ipairs(lugares) do
		if (l.tipo == "zona" or l.tipo == "ciudad") and l.mapa then zona = l break end
	end
	if p and (p.exacto or not zona) then return p end
	-- 3. Una zona o una ciudad.
	if zona then return { tipo = "zona", nombre = zona.nombre, sub = zona.sub, mapa = zona.mapa, x = 50, y = 50 } end
	if p then return p end
	return nil, "nada"
end

local function llevar(e)
	local Mk = M.Marcadores
	if e.tipo == "marcador" and Mk and Mk.Seguir then return Mk.Seguir(e.m) end
	local nombre = e.nombre
	if e.tipo == "pnj" and e.sub then nombre = format("%s (%s)", e.nombre, e.sub) end
	if Mk and Mk.SeguirPunto then return Mk.SeguirPunto(e.mapa, e.x, e.y, nombre, e.f) end
	local Nav = A.Nav
	return Nav and Nav.SetTarget and Nav.SetTarget(e.mapa, e.x, e.y, nombre, e.f) and true or false
end

local function abrirLlevame()
	local R = rawget(_G, "AlfaRuta")
	if type(R) == "table" and type(R.AbrirLlevame) == "function" then pcall(R.AbrirLlevame) return true end
	return false
end

function Ir.Ir(texto)
	local e, por = Ir.Buscar(texto)
	if e then return llevar(e) end
	if por == "vacio" then
		if not abrirLlevame() then N.Imprimir(L["Escribe a quién o a dónde: /alfa ir <nombre>."]) end
		return false, por
	end
	if por == "combate" then
		N.Imprimir(L["En combate no busco: en cuanto termine la pelea te llevo."])
		N.FueraDeCombate("mundo.ir", function() Ir.Ir(texto) end)
		return false, por
	end
	N.Imprimir(format(L["No encontré «%s». Prueba con parte del nombre, o elige en «Llévame a…»."], texto))
	abrirLlevame()
	return false, por
end

A.RegisterCommand("ir", function(resto) Ir.Ir(resto) end)

-- Que Lya sepa contarlo.
if type(A.OnLogin) == "function" then
	A.OnLogin(function()
		local Lya = rawget(_G, "AlfaLya")
		if type(Lya) == "table" and type(Lya.Ensenar) == "function" then
			pcall(Lya.Ensenar, { id = "mundo.ir", icono = "ic-huella", modulo = "mundo",
				pregunta = L["¿Cómo llego con alguien sin saber dónde está?"],
				respuesta = L["Escribe /alfa ir y su nombre (un PNJ, una zona, una ciudad o uno de tus marcadores): la flecha te lleva al más cercano."] })
		end
	end)
end
