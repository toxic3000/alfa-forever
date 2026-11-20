-- Alfa - Mundo: los peligros de tu zona (1.3.0). toxic3000 / La Jauría. GPL-3.0.
--
-- Una capa propia de Alfa.Pins, mundo.peligros: los élites y los raros
-- peligrosos de la zona donde estás, según los datos de criaturas del Codex
-- (bandera de élite, de raro y su nivel) contra el tuyo:
--   * un élite cuenta si su nivel más alto no es gris para ti (todavía pega);
--   * un raro cuenta si es élite o si te pasa por 2 niveles o más;
--   * lo de dentro de mazmorras y bandas no (eso es la página Mazmorras).
-- Rojo si te pasa por 3 niveles o más; ámbar si no. Un pin por criatura y por
-- grupo de apariciones cercanas; PINES como mucho, los más peligrosos primero.
--
-- El índice (zona -> criaturas) se arma una vez por sesión, poco a poco (LOTE
-- por cuadro, fuera de combate) y solo con el Codex ya cargado: lo carga el
-- mapa de Alfa al abrirse (Marcas.lua, Mc.PrepararDatos) o cualquier otra cosa
-- que lo use (CODEX_LOADED). Nada se arma con la capa apagada.
--
--   Pe.Indexar(listo)  Pe.Lista(zona) -> { criatura, ... }  Pe.Refrescar()
--   Pe.Peligro(c, nivel) -> "alto" | "medio" | nil

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)
local Geo = M.Geo

local type, ipairs, pairs, pcall, tonumber, format, floor, abs = type, ipairs, pairs, pcall, tonumber, string.format, math.floor, math.abs
local sort = table.sort

local Pe = {}
M.Peligros = Pe

local CAPA = "mundo.peligros"
Pe.CAPA = CAPA
local LOTE = 300
local PINES = 40
local CERCA = 4 -- % del mapa: apariciones más juntas que esto comparten pin

local login = false
local indice        -- zona -> { criatura, ... } (nil: sin armar)
local armando       -- { ids, i, porZona }

local function secreto(v) return issecretvalue ~= nil and v ~= nil and issecretvalue(v) and true or false end

local function rgb(nombre)
	local T = A.Theme
	if T and type(T.Color) == "function" then
		local ok, r, g, b = pcall(T.Color, nombre)
		if ok and type(r) == "number" then return r, g, b end
	end
	return 1, 1, 1
end
local function color(nombre) local r, g, b = rgb(nombre) return { r, g, b, 1 } end

local function activa() return A.Get(CAPA) ~= false end

local function nivelJugador()
	local n = Geo.NivelJugador and Geo.NivelJugador()
	if n then return n end
	n = UnitLevel and UnitLevel("player")
	return not secreto(n) and tonumber(n) or 1
end

-- El nivel más alto que ya no da experiencia (gris), como el motor.
local function gris(nivel)
	if nivel <= 5 then return 0 end
	if nivel <= 39 then return nivel - 5 - floor(nivel / 10) end
	if nivel <= 59 then return nivel - 1 - floor(nivel / 5) end
	return nivel - 9
end

-- -> "alto" (te pasa por 3 o más), "medio" o nil (no es peligro para ti).
function Pe.Peligro(c, nivel)
	nivel = nivel or nivelJugador()
	local hi = tonumber(c.levelMax) or tonumber(c.level)
	if not hi then return c.elite and "medio" or nil end
	if c.elite then
		if hi <= gris(nivel) then return nil end
	elseif c.rare then
		if hi < nivel + 2 then return nil end
	else
		return nil
	end
	return hi >= nivel + 3 and "alto" or "medio"
end

---------------------------------------------------------------------------
-- El índice
---------------------------------------------------------------------------
local function codex()
	local X = A.Codex
	if not (X and type(X.IsLoaded) == "function" and X.IsLoaded()) then return nil end
	return X
end

-- Una criatura y sus apariciones en cada zona (agrupadas).
local function anotar(porZona, id, n)
	if type(n) ~= "table" or n.instance or n.boss or not (n.elite or n.rare) then return end
	if type(n.spawns) ~= "table" then return end
	local zonas = {}
	for _, s in ipairs(n.spawns) do
		local map, x, y = tonumber(s.map), tonumber(s.x), tonumber(s.y)
		if map and x and y then
			local g = zonas[map]
			if not g then g = {} zonas[map] = g end
			local junto = false
			for _, p in ipairs(g) do
				if abs(p.x - x) < CERCA and abs(p.y - y) < CERCA then junto = true break end
			end
			if not junto then g[#g + 1] = { x = x, y = y } end
		end
	end
	for map, puntos in pairs(zonas) do
		local lista = porZona[map]
		if not lista then lista = {} porZona[map] = lista end
		lista[#lista + 1] = { id = id, name = n.name, level = n.level, levelMax = n.levelMax,
			elite = n.elite and true or false, rare = n.rare and true or false, puntos = puntos }
	end
end

local function paso()
	local b = armando
	if not b then return end
	local X = codex()
	if not X then armando = nil return end
	if InCombatLockdown and InCombatLockdown() then
		N.FueraDeCombate("mundo.peligros", function() A.After(0, paso) end)
		return
	end
	local hasta = math.min(#b.ids, b.i + LOTE - 1)
	for i = b.i, hasta do
		local id = b.ids[i]
		local ok, n = pcall(X.Npc, id)
		if ok then anotar(b.porZona, id, n) end
	end
	b.i = hasta + 1
	if b.i > #b.ids then
		indice = b.porZona
		armando = nil
		local fin = b.listo
		Pe.Refrescar()
		if fin then pcall(fin) end
	else
		A.After(0, paso)
	end
end

-- Arma el índice (una vez); `listo` al terminar.
function Pe.Indexar(listo)
	if indice then if listo then listo() end return true end
	if armando then return false end
	local X = codex()
	if not (X and type(X.Each) == "function" and type(X.Npc) == "function") then return false end
	local ids, vistos = {}, {}
	for _, tipo in ipairs({ "rare", "npc" }) do
		pcall(X.Each, tipo, function(id)
			id = tonumber(id)
			if id and not vistos[id] then vistos[id] = true ids[#ids + 1] = id end
		end)
	end
	armando = { ids = ids, i = 1, porZona = {}, listo = listo }
	A.After(0, paso)
	return false
end

function Pe.Listo() return indice ~= nil end
function Pe.Olvidar() indice, armando = nil, nil end

-- Los peligros de una zona para tu nivel, los más peligrosos primero.
function Pe.Lista(zona, nivel)
	local out = {}
	if not (indice and zona) then return out end
	nivel = nivel or nivelJugador()
	for _, c in ipairs(indice[zona] or {}) do
		local p = Pe.Peligro(c, nivel)
		if p then out[#out + 1] = { c = c, peligro = p } end
	end
	sort(out, function(a, b)
		if a.peligro ~= b.peligro then return a.peligro == "alto" end
		if a.c.rare ~= b.c.rare then return a.c.rare end
		return (tonumber(a.c.levelMax or a.c.level) or 0) > (tonumber(b.c.levelMax or b.c.level) or 0)
	end)
	return out
end

---------------------------------------------------------------------------
-- La capa
---------------------------------------------------------------------------
local function textoNivel(c)
	local lo, hi = tonumber(c.level), tonumber(c.levelMax)
	if lo and hi and hi ~= lo then return format("%d-%d", lo, hi) end
	return lo and tostring(lo) or "?"
end

local function tipo(c)
	if c.rare and c.elite then return L["Raro élite"] end
	if c.rare then return L["Raro"] end
	return L["Élite"]
end

local function pines(zona)
	local lista = {}
	local alto, medio = color("danger"), color("warning")
	for _, e in ipairs(Pe.Lista(zona)) do
		local c, p = e.c, e.peligro
		local col = p == "alto" and alto or medio
		local nombre = c.name or L["Criatura peligrosa"]
		for _, pt in ipairs(c.puntos) do
			if #lista >= PINES then return lista end
			lista[#lista + 1] = {
				map = zona, x = pt.x, y = pt.y, icon = c.rare and "map:rare" or "map:kill", size = 14, color = col, ring = col,
				priority = p == "alto" and 3 or 2, label = nombre,
				tooltip = function(tip)
					tip:SetText(nombre, rgb(p == "alto" and "danger" or "warning"))
					tip:AddLine(format(L["%s, nivel %s"], tipo(c), textoNivel(c)), rgb("textDim"))
					tip:AddLine(p == "alto" and L["Muy peligroso para tu nivel: mejor con grupo o rodéalo."]
						or L["Pega fuerte: ve con cuidado y con la vida llena."], rgb(p == "alto" and "danger" or "text"))
				end,
			}
		end
	end
	return lista
end

function Pe.Refrescar()
	local Pins = A.Pins
	if not (login and Pins and type(Pins.SetLayer) == "function") then return end
	local zona = M.Descubrir and M.Descubrir.Zona()
	if not (activa() and zona) then Pins.ClearLayer(CAPA) return end
	if not indice then
		Pins.ClearLayer(CAPA)
		Pe.Indexar()
		return
	end
	local lista = pines(zona)
	if #lista > 0 then
		Pins.SetLayer(CAPA, lista, { world = true, minimap = false, edge = false })
	else
		Pins.ClearLayer(CAPA)
	end
end

local pendiente = false
local function pronto(espera)
	if pendiente then return end
	pendiente = true
	A.After(espera or 1, function()
		pendiente = false
		local ok, e = pcall(Pe.Refrescar)
		if not ok and geterrorhandler then geterrorhandler()(e) end
	end)
end
Pe.Pronto = pronto

if type(A.OnLogin) == "function" then
	A.OnLogin(function()
		login = true
		A.After(8, Pe.Refrescar)
		local Lya = rawget(_G, "AlfaLya")
		if type(Lya) == "table" and type(Lya.Ensenar) == "function" then
			pcall(Lya.Ensenar, { id = "mundo.peligros", icono = "ic-raros", modulo = "mundo",
				pregunta = L["¿Qué es peligroso en esta zona?"],
				respuesta = L["En el mapa de Alfa, la capa «Peligros» marca los élites y los raros de tu zona que te pueden ganar: en rojo los que te pasan por mucho. Se arma al abrir el mapa."] })
		end
	end)
end

for _, ev in ipairs({ "ZONE_CHANGED_NEW_AREA", "PLAYER_LEVEL_UP" }) do
	A.RegisterEvent(ev, function() if login then pronto(2) end end)
end
if A.On then
	A.On("CODEX_LOADED", function() if login and activa() then pronto(1) end end)
	A.On("SETTING_CHANGED", function(path)
		if path == "" or path == "mundo" or path == CAPA then pronto(0) end
	end)
end
