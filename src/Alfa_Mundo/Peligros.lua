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
local GRUPO = 6 -- 1.4.0 (72): % del mapa: los peligros más juntos que esto van en un solo pin con su número
local CERCA = 4 -- % del mapa: apariciones más juntas que esto comparten pin

local login = false
local indice        -- zona -> { criatura, ... } (nil: sin armar)
local armando       -- { ids, i, porZona }

local function secreto(v) return issecretvalue ~= nil and type(v) ~= "nil" and issecretvalue(v) and true or false end

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
-- 1.3.1: cada punto lleva su marco (f = "e": Era, como casi todo el Codex).
-- Sin él, el mapa leía el punto como del juego y en las zonas que Forever
-- movió el pin salía corrido. Solo se juntan puntos del mismo marco.
-- 1.4.0 (72): un PNJ de tu facción (o de las dos) no es un peligro: en
-- Forjaz salían decenas de calaveras sobre los guardias y los entrenadores
-- (élites amistosos). Solo cuentan los que no te son amistosos.
local FACCION = { Alliance = "A", Horde = "H" }
local function amistoso(f)
	if type(f) ~= "string" or f == "" then return false end
	if f == "AH" then return true end
	local mia = UnitFactionGroup and UnitFactionGroup("player")
	mia = not secreto(mia) and FACCION[mia] or nil
	return mia ~= nil and f:find(mia, 1, true) ~= nil
end
Pe.Amistoso = amistoso

local function anotar(porZona, id, n)
	if type(n) ~= "table" or n.instance or n.boss or not (n.elite or n.rare) then return end
	if amistoso(n.faction) or (type(n.roles) == "table" and #n.roles > 0) then return end
	if type(n.spawns) ~= "table" then return end
	local zonas = {}
	for _, s in ipairs(n.spawns) do
		local map, x, y = tonumber(s.map), tonumber(s.x), tonumber(s.y)
		local f = s.f == "e" and "e" or nil
		if map and x and y then
			local g = zonas[map]
			if not g then g = {} zonas[map] = g end
			local junto = false
			for _, p in ipairs(g) do
				if p.f == f and abs(p.x - x) < CERCA and abs(p.y - y) < CERCA then junto = true break end
			end
			if not junto then g[#g + 1] = { x = x, y = y, f = f } end
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
-- (para el banco) anotar una criatura del Codex y poner un índice armado a mano.
Pe.Anotar = anotar
function Pe.PonerIndice(t) indice = t end
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

-- 1.4.0 (72): los peligros cercanos van juntos en un pin con su número
-- (insignia), del color del peor; el cuadro dice quiénes son. Primero los
-- de cerca de ti. Como mucho PINES pines.
local function aqui(zona)
	local Mp = C_Map
	if not (Mp and Mp.GetPlayerMapPosition) then return nil end
	local ok, pos = pcall(Mp.GetPlayerMapPosition, zona, "player")
	if not (ok and pos) then return nil end
	local x, y
	if type(pos.GetXY) == "function" then x, y = pos:GetXY() else x, y = pos.x, pos.y end
	if secreto(x) or secreto(y) or type(x) ~= "number" or type(y) ~= "number" then return nil end
	return x * 100, y * 100
end

function Pe.Grupos(zona, nivel)
	local grupos = {}
	for _, e in ipairs(Pe.Lista(zona, nivel)) do
		for _, pt in ipairs(e.c.puntos) do
			local g
			for _, h in ipairs(grupos) do
				if h.f == pt.f and abs(h.x - pt.x) < GRUPO and abs(h.y - pt.y) < GRUPO then g = h break end
			end
			if g then
				g.n = g.n + 1
				if e.peligro == "alto" then g.peligro = "alto" end
				if e.c.rare then g.raro = true end
				local ya = false
				for _, c in ipairs(g.criaturas) do if c == e.c then ya = true break end end
				if not ya then g.criaturas[#g.criaturas + 1] = e.c end
			else
				grupos[#grupos + 1] = { x = pt.x, y = pt.y, f = pt.f, n = 1, peligro = e.peligro, raro = e.c.rare, criaturas = { e.c } }
			end
		end
	end
	local px, py = aqui(zona)
	sort(grupos, function(a, b)
		if a.peligro ~= b.peligro then return a.peligro == "alto" end
		if px then
			local da = (a.x - px) ^ 2 + (a.y - py) ^ 2
			local db = (b.x - px) ^ 2 + (b.y - py) ^ 2
			if da ~= db then return da < db end
		end
		return a.n > b.n
	end)
	return grupos
end

local function pines(zona)
	local lista = {}
	local alto, medio = color("danger"), color("warning")
	for _, g in ipairs(Pe.Grupos(zona)) do
		if #lista >= PINES then break end
		local p = g.peligro
		local col = p == "alto" and alto or medio
		local primera = g.criaturas[1]
		local nombre = g.n > 1 and format(L["%d peligros aquí"], g.n) or (primera.name or L["Criatura peligrosa"])
		lista[#lista + 1] = {
			map = zona, x = g.x, y = g.y, f = g.f, icon = g.raro and "map:rare" or "map:kill", size = g.n > 1 and 16 or 14,
			color = col, ring = col, badge = g.n > 1 and g.n or nil,
			priority = p == "alto" and 3 or 2, label = nombre,
			tooltip = function(tip)
				tip:SetText(nombre, rgb(p == "alto" and "danger" or "warning"))
				for i, c in ipairs(g.criaturas) do
					if i > 6 then
						tip:AddLine(format(L["y %d más"], #g.criaturas - 6), rgb("textDim"))
						break
					end
					tip:AddLine(format("%s  \194\183  %s", c.name or L["Criatura peligrosa"], format(L["%s, nivel %s"], tipo(c), textoNivel(c))), rgb("textDim"))
				end
				tip:AddLine(p == "alto" and L["Muy peligroso para tu nivel: mejor con grupo o rodéalo."]
					or L["Pega fuerte: ve con cuidado y con la vida llena."], rgb(p == "alto" and "danger" or "text"))
			end,
		}
	end
	return lista
end
Pe.Pines = pines

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
	-- 1.3.7: al subir de nivel, tras la animación del juego (N.TrasNivel).
	local fn = function() if login then pronto(2) end end
	A.RegisterEvent(ev, ev == "PLAYER_LEVEL_UP" and N.TrasNivel and N.TrasNivel("mundo.peligros", fn) or fn)
end
if A.On then
	A.On("CODEX_LOADED", function() if login and activa() then pronto(1) end end)
	A.On("SETTING_CHANGED", function(path)
		if path == "" or path == "mundo" or path == CAPA then pronto(0) end
	end)
end
