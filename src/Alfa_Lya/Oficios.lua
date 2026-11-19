-- Alfa - Lya y tus oficios (1.2.8). toxic3000 / La Jauría. GPL-3.0.
--
--   Cuando una profesión llega al tope de su rango (75/75, 150/150, 225/225),
--   Lya te dice que ya puedes aprender el siguiente y dónde está el
--   instructor más cercano (Alfa.Nav.nearby.Find("trainer", línea), con
--   «Llévame con el instructor» de AlfaCerca); si no lo sabe, te dice la
--   ciudad. Una vez por rango y profesión (N.DatosPersonaje("lya").oficios).
--   Al llegar a 300/300, lo festeja y lo apunta en tu historia (TuHistoria.lua).
--   Nunca en combate: espera a que termines. lya.oficios lo apaga.
--
--   Of.Leer() -> { { linea, nombre, rank, max }, ... }   (las profesiones de M.OFICIO)
--   Of.Revisar()   Of.Avisar(o) -> bool

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID

local type, tonumber, ipairs, pcall, rawget, format = type, tonumber, ipairs, pcall, rawget, string.format

local Of = {}
M.Oficios = Of

-- El rango que sigue a cada tope y el nivel que pide (el Clásico).
local SIGUIENTE = {
	[75] = { nombre = "Oficial", nivel = 10 },
	[150] = { nombre = "Experto", nivel = 20 },
	[225] = { nombre = "Artesano", nivel = 35 },
}
local MAXIMO = 300

local function secreto(v) return issecretvalue ~= nil and v ~= nil and issecretvalue(v) and true or false end
local function num(v) if secreto(v) then return nil end return tonumber(v) end
local function texto(v) if secreto(v) or type(v) ~= "string" or v == "" then return nil end return v end

local function datos()
	local d = N.DatosPersonaje(ID)
	d.oficios = type(d.oficios) == "table" and d.oficios or {}
	return d
end

local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end

local function nombreOficio(linea, nombre)
	local E = rawget(_G, "AlfaEnciclopedia")
	if texto(nombre) then return nombre end
	if type(E) == "table" and type(E.NombreProfesion) == "function" then
		local ok, n = pcall(E.NombreProfesion, linea)
		if ok and texto(n) then return n end
	end
	return L["tu oficio"]
end

function Of.Leer()
	local lista = {}
	local S = C_SkillInfo
	if not (S and S.GetNumSkillLines and S.GetSkillLineInfo) then return lista end
	local ok, n = pcall(S.GetNumSkillLines)
	n = ok and num(n) or 0
	for i = 1, n do
		local bien, info = pcall(S.GetSkillLineInfo, i)
		if bien and type(info) == "table" and info.isHeader ~= true then
			local linea = num(info.skillID)
			if linea and M.OFICIO and M.OFICIO[linea] then
				local rank, mx = num(info.rank), num(info.maxRank)
				if rank and mx and mx > 0 then
					lista[#lista + 1] = { linea = linea, nombre = nombreOficio(linea, texto(info.name)), rank = rank, max = mx }
				end
			end
		end
	end
	return lista
end

-- El instructor más cercano: "Nombre, en Zona" o nil.
local function instructor(linea)
	local Nav = A.Nav
	local nb = type(Nav) == "table" and Nav.nearby
	if enCombate() or type(nb) ~= "table" or type(nb.Find) ~= "function" then return nil end
	local ok, place = pcall(nb.Find, "trainer", linea)
	if not ok or type(place) ~= "table" then return nil end
	local nombre = texto(place.name)
	if not nombre then return nil end
	local C = A.Compat
	local zona
	if C and type(C.GetMapName) == "function" and num(place.map) then
		local bien, z = pcall(C.GetMapName, place.map)
		zona = bien and texto(z) or nil
	end
	if zona then return format(L["Tu instructor más cercano: %s, en %s."], nombre, zona) end
	return format(L["Tu instructor más cercano: %s."], nombre)
end

local function ciudad()
	local f = UnitFactionGroup and UnitFactionGroup("player")
	if secreto(f) then f = nil end
	if f == "Alliance" then return L["Ventormenta"] end
	if f == "Horde" then return L["Orgrimmar"] end
	return L["la capital"]
end

function Of.Avisar(o)
	local Ce = M.Cerebro
	local sig = SIGUIENTE[o.max]
	local t
	local acciones
	if o.max >= MAXIMO then
		t = format(L["¡%s al máximo: %d/%d! Ya no hay nada que te enseñen. Qué orgullo, de verdad."], o.nombre, o.rank, o.max)
	elseif sig then
		t = format(L["¡Tu %s llegó a %d/%d! Ya puedes aprender el rango %s."], o.nombre, o.rank, o.max, L[sig.nombre])
		local lv = tonumber(UnitLevel and num(UnitLevel("player"))) or 0
		if lv > 0 and lv < sig.nivel then
			t = t .. " " .. format(L["Te lo enseñan desde el nivel %d."], sig.nivel)
		else
			t = t .. " " .. (instructor(o.linea) or format(L["Búscalo en %s."], ciudad()))
		end
		local Cerca = rawget(_G, "AlfaCerca")
		if type(Cerca) == "table" and type(Cerca.Ir) == "function" then
			acciones = { { texto = L["Llévame con el instructor"], fn = function()
				local ok, puesto = pcall(Cerca.Ir, "trainer", o.linea)
				if ok and puesto then N.EmpezarRuta() end
			end } }
		end
	else
		return false
	end
	local dijo = Ce and Ce.Decir({ texto = t, clase = "oficios", cara = "atenta", salto = o.max >= MAXIMO,
		aullar = o.max >= MAXIMO, importante = o.max >= MAXIMO, lineas = 5, ancho = 360, segundos = 12, acciones = acciones })
	if dijo ~= true and dijo ~= "espera" then N.Imprimir(t) end
	return true
end

function Of.Revisar()
	if N.Get(ID, "oficios") == false then return end
	local d = datos()
	for _, o in ipairs(Of.Leer()) do
		local clave = tostring(o.linea)
		if o.rank >= o.max and (SIGUIENTE[o.max] or o.max >= MAXIMO) and (tonumber(d.oficios[clave]) or 0) < o.max then
			d.oficios[clave] = o.max
			if o.max >= MAXIMO and M.Diario then
				M.Diario.Anotar({ clave = "oficioMax", icono = "ic-oficios", t = "%s al máximo", a = { o.nombre },
					l = "Trescientos puntos. Eres maestro de tu oficio.", festejo = false })
			end
			Of.Avisar(o)
			return -- uno a la vez; el siguiente, en la próxima revisión
		end
	end
end

local pendiente = false
local function pronto()
	if pendiente then return end
	pendiente = true
	A.After(2, function()
		pendiente = false
		N.FueraDeCombate("lya.oficios", function()
			local ok, e = pcall(Of.Revisar)
			if not ok and geterrorhandler then geterrorhandler()(e) end
		end)
	end)
end

A.RegisterEvent("SKILL_LINES_CHANGED", pronto)
A.OnLogin(function() A.After(30, pronto) end)
