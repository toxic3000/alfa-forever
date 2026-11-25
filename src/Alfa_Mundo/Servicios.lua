-- Alfa - Mundo: tus entrenadores y tus provisiones en el mapa (1.4.0, mejoras
-- 35 y 36). toxic3000 / La Jauría. GPL-3.0.
--
-- Dos capas propias de Alfa.Pins, solo de la zona donde estás:
--   mundo.entrenadores  el entrenador de tu clase y los de TUS oficios (si
--                       aún no tienes ninguno, los de todos, para elegir);
--   mundo.provisiones   quien vende comida y agua y quien repara.
-- Son las que pide el jugador al llegar a un pueblo («¿dónde entreno?»,
-- «¿dónde compro agua?»), sin prender toda la capa de servicios del motor.
-- Si esa capa ya pinta la misma categoría (maps.servicePins con su filtro),
-- aquí no se repite.
--
-- Los datos son los papeles de los PNJ del Codex ("class:MAGE",
-- "trainer:186", "sells:food", "repair"): solo los amistosos para tu
-- facción y fuera de mazmorras. Se leen una vez por sesión, poco a poco (LOTE
-- por cuadro, fuera de combate) y solo con el Codex ya cargado (lo carga el
-- mapa de Alfa al abrirse, Marcas.lua). Nada se arma con las capas apagadas.
--
--   Sv.Indexar(listo)  Sv.Listo()  Sv.Refrescar()
--   Sv.Entrenadores(zona) -> { { id, nombre, sub, que, puntos = { { x, y, f, z } } } }
--   Sv.Provisiones(zona)  -> lo mismo, con { comida, reparar }

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)

local type, ipairs, pairs, pcall, tonumber, tostring, format, abs = type, ipairs, pairs, pcall, tonumber, tostring, string.format, math.abs
local sort = table.sort

local Sv = {}
M.Servicios = Sv

local CAPA_E, CAPA_P = "mundo.entrenadores", "mundo.provisiones"
Sv.CAPA_E, Sv.CAPA_P = CAPA_E, CAPA_P
local LOTE = 120
local CERCA = 3   -- % del mapa: dos apariciones del mismo PNJ así de juntas son una
local RIDING = 762
local FACCION = { Alliance = "A", Horde = "H" }

local login = false
local datos   -- papel -> { { id, nombre, sub, spawns, otros = { papel = true } } } (nil: sin leer)
local leyendo -- { cola = { papel, ... }, i, ids, papel, porPapel, listo }

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

local function prendida(capa) return A.Get(capa) ~= false end

local function info()
	local C = A.Compat
	local ok, i = pcall(function() return C and C.GetPlayerInfo and C.GetPlayerInfo() end)
	return ok and type(i) == "table" and i or {}
end

-- Tus oficios: las líneas que ya aprendiste (sin la equitación).
function Sv.MisOficios()
	local C = A.Compat
	local out = {}
	if not (C and type(C.SKILL_LINES) == "table" and type(C.GetSkillRank) == "function") then return out end
	for _, linea in pairs(C.SKILL_LINES) do
		if linea ~= RIDING then
			local ok, r = pcall(C.GetSkillRank, linea)
			if ok and tonumber(r) then out[#out + 1] = linea end
		end
	end
	sort(out)
	return out
end

local function nombreOficio(linea)
	local Nb = A.Nav and A.Nav.nearby
	if Nb and type(Nb.ProfessionName) == "function" then
		local ok, n = pcall(Nb.ProfessionName, linea)
		if ok and type(n) == "string" then return n end
	end
	return tostring(linea)
end

-- Los papeles que hay que leer.
local function papeles()
	local lista = {}
	if prendida(CAPA_E) then
		local i = info()
		if type(i.class) == "string" then lista[#lista + 1] = "class:" .. i.class end
		local C = A.Compat
		for _, linea in pairs(C and C.SKILL_LINES or {}) do
			if linea ~= RIDING then lista[#lista + 1] = "trainer:" .. linea end
		end
	end
	if prendida(CAPA_P) then
		lista[#lista + 1] = "sells:food"
		lista[#lista + 1] = "repair"
	end
	return lista
end

---------------------------------------------------------------------------
-- La lectura (una vez, poco a poco)
---------------------------------------------------------------------------
local function codex()
	local X = A.Codex
	if not (X and type(X.IsLoaded) == "function" and X.IsLoaded() and type(X.WithRole) == "function" and type(X.Npc) == "function") then return nil end
	return X
end

local function amistoso(f)
	local mio = FACCION[info().faction or ""]
	return f == nil or f == "AH" or (mio ~= nil and type(f) == "string" and f:find(mio, 1, true) ~= nil)
end

-- Un PNJ y sus apariciones (agrupadas), o nil.
local function leerPnj(X, id)
	local ok, n = pcall(X.Npc, id)
	if not (ok and type(n) == "table") or n.instance or not amistoso(n.faction) then return nil end
	local pts = {}
	for _, s in ipairs(type(n.spawns) == "table" and n.spawns or {}) do
		local map, x, y = tonumber(s.map), tonumber(s.x), tonumber(s.y)
		if map and x and y and x >= 0 and x <= 100 and y >= 0 and y <= 100 then
			local f = s.f == "e" and "e" or nil
			local junto = false
			for _, p in ipairs(pts) do
				if p.map == map and p.f == f and abs(p.x - x) < CERCA and abs(p.y - y) < CERCA then junto = true break end
			end
			if not junto then pts[#pts + 1] = { map = map, x = x, y = y, f = f, z = tonumber(s.z) } end
		end
	end
	if #pts == 0 then return nil end
	local nombre = n.name
	if type(nombre) ~= "string" or nombre == "" or secreto(nombre) then nombre = nil end
	local sub = type(n.subName) == "string" and n.subName ~= "" and not secreto(n.subName) and n.subName or nil
	return { id = id, nombre = nombre, sub = sub, puntos = pts }
end

local function paso()
	local b = leyendo
	if not b then return end
	local X = codex()
	if not X then leyendo = nil return end
	if InCombatLockdown and InCombatLockdown() then
		N.FueraDeCombate("mundo.servicios", function() A.After(0, paso) end)
		return
	end
	local hechos = 0
	while hechos < LOTE do
		if not b.ids then
			b.papel = b.cola[b.i]
			if not b.papel then break end
			local ok, ids = pcall(X.WithRole, b.papel)
			b.ids, b.j, b.porPapel[b.papel] = ok and type(ids) == "table" and ids or {}, 1, {}
		end
		local id = b.ids[b.j]
		if id then
			local p = leerPnj(X, id)
			if p then local l = b.porPapel[b.papel] l[#l + 1] = p end
			b.j = b.j + 1
			hechos = hechos + 1
		else
			b.ids, b.i = nil, b.i + 1
		end
	end
	if b.cola[b.i] then A.After(0, paso) return end
	-- Los entrenadores que también son vendedores venden lo de su oficio: fuera de «comida».
	local entrenan = {}
	for papel, l in pairs(b.porPapel) do
		if papel:sub(1, 8) == "trainer:" or papel:sub(1, 6) == "class:" then for _, p in ipairs(l) do entrenan[p.id] = true end end
	end
	if b.porPapel["sells:food"] then
		local quedan = {}
		for _, p in ipairs(b.porPapel["sells:food"]) do if not entrenan[p.id] then quedan[#quedan + 1] = p end end
		b.porPapel["sells:food"] = quedan
	end
	datos = b.porPapel
	leyendo = nil
	local fin = b.listo
	Sv.Refrescar()
	if fin then pcall(fin) end
end

-- Lee los papeles (una vez por sesión); `listo` al terminar. -> true si ya estaban.
function Sv.Indexar(listo)
	local quiero = papeles()
	if datos then
		local falta = false
		for _, p in ipairs(quiero) do if not datos[p] then falta = true end end
		if not falta then if listo then listo() end return true end
	end
	if leyendo then return false end
	if not codex() or #quiero == 0 then return false end
	local cola = {}
	for _, p in ipairs(quiero) do if not (datos and datos[p]) then cola[#cola + 1] = p end end
	leyendo = { cola = cola, i = 1, porPapel = datos or {}, listo = listo }
	A.After(0, paso)
	return false
end

function Sv.Listo() return datos ~= nil end
function Sv.Olvidar() datos, leyendo = nil, nil end

---------------------------------------------------------------------------
-- Lo de una zona
---------------------------------------------------------------------------
local function deZona(lista, zona, que, out, visto)
	for _, p in ipairs(lista or {}) do
		local pts = {}
		for _, s in ipairs(p.puntos) do if s.map == zona then pts[#pts + 1] = s end end
		if #pts > 0 then
			local e = visto[p.id]
			if e then
				e.que[que] = true
			else
				e = { id = p.id, nombre = p.nombre, sub = p.sub, puntos = pts, que = { [que] = true } }
				visto[p.id] = e
				out[#out + 1] = e
			end
		end
	end
end

local function ordenar(out)
	sort(out, function(a, b) return (a.nombre or "") < (b.nombre or "") end)
	return out
end

-- ¿La capa de servicios del motor ya pinta esta categoría?
local function delMotor(cat)
	return A.Get("maps.servicePins") == true and A.Get("maps.serviceFilters." .. cat) == true
end

function Sv.Entrenadores(zona)
	local out, visto = {}, {}
	if not (datos and zona) then return out end
	local i = info()
	if type(i.class) == "string" and not delMotor("class") then deZona(datos["class:" .. i.class], zona, "clase", out, visto) end
	if not delMotor("trainer") then
		local mios = Sv.MisOficios()
		-- Sin oficios todavía: todos, para que elijas.
		local C = A.Compat
		local lineas = mios
		if #mios == 0 then
			lineas = {}
			for _, l in pairs(C and C.SKILL_LINES or {}) do if l ~= RIDING then lineas[#lineas + 1] = l end end
		end
		for _, linea in ipairs(lineas) do deZona(datos["trainer:" .. linea], zona, linea, out, visto) end
	end
	return ordenar(out)
end

function Sv.Provisiones(zona)
	local out, visto = {}, {}
	if not (datos and zona) then return out end
	if not delMotor("vendor") then deZona(datos["sells:food"], zona, "comida", out, visto) end
	if not delMotor("repair") then deZona(datos["repair"], zona, "reparar", out, visto) end
	return ordenar(out)
end

---------------------------------------------------------------------------
-- Las capas
---------------------------------------------------------------------------
local function llevar(e, s)
	local Nav = A.Nav
	if not (Nav and type(Nav.SetTarget) == "function") then return end
	pcall(Nav.SetTarget, s.map, s.x, s.y, e.nombre or L["Tu destino"], s.f, "npc", s.z)
end

local function queHace(e)
	local partes = {}
	if e.que.clase then partes[#partes + 1] = L["Entrenador de tu clase"] end
	local lineas = {}
	for k in pairs(e.que) do if type(k) == "number" then lineas[#lineas + 1] = k end end
	sort(lineas)
	for _, l in ipairs(lineas) do partes[#partes + 1] = format(L["Entrenador de %s"], nombreOficio(l)) end
	if e.que.comida then partes[#partes + 1] = L["Vende comida y agua"] end
	if e.que.reparar then partes[#partes + 1] = L["Repara tu equipo"] end
	return table.concat(partes, " \194\183 ")
end
Sv.QueHace = queHace

local function pines(lista, icono, tono, prioridad)
	local out = {}
	local col = color(tono)
	for _, e in ipairs(lista) do
		local que = queHace(e)
		local nombre = e.nombre or que
		for _, s in ipairs(e.puntos) do
			out[#out + 1] = {
				map = s.map, x = s.x, y = s.y, f = s.f, icon = type(icono) == "function" and icono(e) or icono, size = 15,
				color = col, priority = prioridad, label = nombre,
				tooltip = function(tip)
					tip:SetText(nombre, rgb("text"))
					if e.sub then tip:AddLine(e.sub, rgb("textDim")) end
					tip:AddLine(que, rgb(tono))
					tip:AddLine(L["Clic: la flecha te lleva."], rgb("textDim"))
				end,
				onClick = function(boton) if boton == "LeftButton" then llevar(e, s) end end,
			}
		end
	end
	return out
end

local function iconoEntrenador(e) return e.que.clase and "map:trainer-class" or "map:trainer-profession" end
local function iconoProvision(e) return e.que.reparar and not e.que.comida and "map:repair" or "map:vendor" end

local function poner(Pins, capa, lista)
	if lista and #lista > 0 then
		Pins.SetLayer(capa, lista, { world = true, minimap = false, edge = false })
	else
		Pins.ClearLayer(capa)
	end
end

function Sv.Refrescar()
	local Pins = A.Pins
	if not (login and Pins and type(Pins.SetLayer) == "function") then return end
	local zona = M.Descubrir and M.Descubrir.Zona()
	local e, p = prendida(CAPA_E), prendida(CAPA_P)
	if not ((e or p) and zona) then Pins.ClearLayer(CAPA_E) Pins.ClearLayer(CAPA_P) return end
	if not Sv.Indexar() then
		if not datos then Pins.ClearLayer(CAPA_E) Pins.ClearLayer(CAPA_P) return end
	end
	poner(Pins, CAPA_E, e and pines(Sv.Entrenadores(zona), iconoEntrenador, "npc", 2) or nil)
	poner(Pins, CAPA_P, p and pines(Sv.Provisiones(zona), iconoProvision, "place", 1) or nil)
end

local pendiente = false
local function pronto(espera)
	if pendiente then return end
	pendiente = true
	A.After(espera or 1, function()
		pendiente = false
		local ok, err = pcall(Sv.Refrescar)
		if not ok and geterrorhandler then geterrorhandler()(err) end
	end)
end
Sv.Pronto = pronto

if type(A.OnLogin) == "function" then
	A.OnLogin(function()
		login = true
		A.After(9, Sv.Refrescar)
		local Lya = rawget(_G, "AlfaLya")
		if type(Lya) == "table" and type(Lya.Ensenar) == "function" then
			pcall(Lya.Ensenar, { id = "mundo.servicios", icono = "ic-mundo", modulo = "mundo",
				pregunta = L["¿Dónde entreno y dónde compro agua?"],
				respuesta = L["En el mapa de Alfa, «Tus entrenadores» marca al de tu clase y a los de tus oficios en tu zona, y «Comida, agua y reparación» a quien te vende provisiones y te repara. Clic en uno y la flecha te lleva."] })
		end
	end)
end

for _, ev in ipairs({ "ZONE_CHANGED_NEW_AREA", "SKILL_LINES_CHANGED" }) do
	A.RegisterEvent(ev, function() if login then pronto(2) end end)
end
if A.On then
	A.On("CODEX_LOADED", function() if login and (prendida(CAPA_E) or prendida(CAPA_P)) then pronto(1) end end)
	A.On("SETTING_CHANGED", function(path)
		if path == "" or path == "mundo" or path == CAPA_E or path == CAPA_P or path == "maps.servicePins"
			or (type(path) == "string" and path:find("^maps%.serviceFilters")) then
			pronto(0)
		end
	end)
end
