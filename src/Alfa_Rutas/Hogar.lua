-- Alfa - Rutas: «Piedra de hogar a tiempo» (toxic3000 / La Jauría). GPL-3.0.
-- 1.2.8
--
-- Si la mayoría de tus misiones listas (3 o más, y al menos el 60 %) se
-- entregan en el pueblo de tu piedra de hogar (GetBindLocation; su posada,
-- Nav.BoundInn del motor) y estás lejos de ahí, Lya te lo dice: «¿Y si usas
-- tu piedra?». Con Lya a la vista lo dice ella (K.PorLya); si no, un aviso
-- con el botón «Usar la piedra», que es un botón seguro del juego (type =
-- item, la Piedra de hogar 6948): el clic lo hace el jugador, nunca Alfa.
--
-- Nunca en combate, en una instancia ni en vuelo; no si la piedra se está
-- recargando o no la traes; una vez cada 20 minutos (rutas.piedraHogar).
--
--   Hogar.Revisar() -> dijo, por qué   lo mira ahora (el banco lo llama)
--   Hogar.Cuenta(lista) -> enPueblo, total, lugar

local ADDON, M = ...
local A, L = M.A, M.L
local N = M.N
local K = M.K
local Hg = {}
M.Hogar = Hg

A.RegisterDefaults(M.ID, { piedraHogar = true })

local type, ipairs, pairs = type, ipairs, pairs
local sqrt, format, lower = math.sqrt, string.format, string.lower

local PIEDRA = 6948
local CADA = 1200       -- segundos: una vez cada 20 minutos
local MIN_LISTAS = 3
local PARTE = 0.6
local PUEBLO = 450      -- yardas de la posada: dentro del pueblo
local LEJOS = 900       -- yardas de la posada: lejos de ahí
local GCD = 1.5

local function CP() return M.Motor("Compat") end
local function enCombate() return InCombatLockdown and InCombatLockdown() or false end
local function secreto(v) return issecretvalue and issecretvalue(v) or false end

local ultima = nil -- GetTime() del último aviso

local function texto(v)
	if type(v) ~= "string" or secreto(v) or v == "" then return nil end
	return v
end

local function lugar()
	local Cp = CP()
	local fn = Cp and Cp.GetBindLocation or rawget(_G, "GetBindLocation")
	if type(fn) ~= "function" then return nil end
	local ok, v = pcall(fn)
	return ok and texto(v) or nil
end

-- La posada de tu piedra, en el mundo: c, wx, wy | nil
local function posada()
	local Nav = A.Nav
	if not (Nav and type(Nav.BoundInn) == "function") then return nil end
	local ok, inn = pcall(Nav.BoundInn)
	if ok and type(inn) == "table" and inn.c and type(inn.wx) == "number" and type(inn.wy) == "number" then
		return inn.c, inn.wx, inn.wy
	end
	return nil
end

local function mundo(p)
	local Cp = CP()
	if not (p and p.map and p.x and p.y and Cp and Cp.MapToWorld) then return nil end
	local ok, c, wx, wy = pcall(Cp.MapToWorld, p.map, p.x, p.y, p.f)
	if ok and c and type(wx) == "number" and type(wy) == "number" then return c, wx, wy end
	return nil
end

local function yardas(c1, x1, y1, c2, x2, y2)
	if not (c1 and c2) or c1 ~= c2 then return nil end
	local dx, dy = x1 - x2, y1 - y2
	return sqrt(dx * dx + dy * dy)
end

local function mismoNombre(a, b)
	return a ~= nil and b ~= nil and lower(a) == lower(b)
end

-- ¿Ese punto está en el pueblo de tu piedra?
local function enPueblo(p, sitio, c, wx, wy)
	if c then
		local pc, px, py = mundo(p)
		local d = pc and yardas(pc, px, py, c, wx, wy)
		if d then return d <= PUEBLO end
	end
	return mismoNombre(M.Zona(p.map), sitio)
end

function Hg.Cuenta(lista)
	local sitio = lugar()
	if not sitio then return 0, 0, nil end
	local c, wx, wy = posada()
	local n, total = 0, 0
	for _, it in ipairs(lista or {}) do
		if it.p and it.p.map then
			total = total + 1
			if enPueblo(it.p, sitio, c, wx, wy) then n = n + 1 end
		end
	end
	return n, total, sitio
end

-- ¿Estás lejos del pueblo de tu piedra?
local function lejos(sitio)
	local c, wx, wy = posada()
	if c then
		local Cp = CP()
		local ok, pc, px, py = false, nil, nil, nil
		if Cp and Cp.GetPlayerWorldPosition then ok, pc, px, py = pcall(Cp.GetPlayerWorldPosition) end
		if ok and pc then
			local d = yardas(pc, px, py, c, wx, wy)
			return d == nil or d > LEJOS -- otro continente: lejos
		end
	end
	-- Sin la posada: lejos si ni tu zona ni tu subzona se llaman como el lugar.
	for _, nombre in ipairs({ "GetRealZoneText", "GetZoneText", "GetSubZoneText" }) do
		local fn = rawget(_G, nombre)
		if type(fn) == "function" then
			local ok, z = pcall(fn)
			if ok and mismoNombre(texto(z), sitio) then return false end
		end
	end
	return true
end

-- La piedra en tus bolsas y lista para usarse.
local function piedraLista()
	local Cp = CP()
	local cuenta = 0
	if Cp and Cp.GetItemCount then
		local ok, n = pcall(Cp.GetItemCount, PIEDRA)
		cuenta = ok and M.num(n, 0) or 0
	end
	if cuenta < 1 then return false end
	local fn = (C_Container and C_Container.GetItemCooldown) or (C_Item and C_Item.GetItemCooldown) or rawget(_G, "GetItemCooldown")
	if type(fn) ~= "function" then return true end
	local ok, inicio, dura = pcall(fn, PIEDRA)
	if not ok or secreto(inicio) or secreto(dura) then return true end
	inicio, dura = M.num(inicio, 0), M.num(dura, 0)
	if inicio > 0 and dura > GCD and inicio + dura > GetTime() then return false end
	return true
end

local function enInstancia()
	if not IsInInstance then return false end
	local ok, dentro = pcall(IsInInstance)
	return ok and N.Si(dentro) -- 1.3.7: secretos
end

local function enVuelo()
	return N.SiJuego(rawget(_G, "UnitOnTaxi"), "player")
end

function Hg.Revisar()
	if A.Get(M.ID .. ".piedraHogar") == false then return false, "apagado" end
	if enCombate() then return false, "combate" end
	if enInstancia() or enVuelo() then return false, "lugar" end
	-- 1.3.3: al entrar, en silencio (N.Entrando): su aviso trae un botón
	-- seguro, que K.Aviso sí mostraría; se vuelve a mirar después.
	local Nu = M.N
	if type(Nu) == "table" and type(rawget(Nu, "Entrando")) == "function" and Nu.Entrando() then return false, "entrando" end
	if ultima and GetTime() - ultima < CADA then return false, "pronto" end
	-- 1.3.3: la ruta ya va por la piedra: lo dice la placa de la flecha.
	if Hg.RutaConPiedra() then return false, "ruta" end
	if (M.Cerrar and M.Cerrar.ListasAhora() or 0) < MIN_LISTAS then return false, "pocas" end
	if not lugar() then return false, "sinLugar" end
	local V = M.Vuelta
	local lista = V and V.Listas(true)
	if not lista or #lista < MIN_LISTAS then return false, "pocas" end
	local n, total, sitio = Hg.Cuenta(lista)
	if not sitio then return false, "sinLugar" end
	if total < MIN_LISTAS or n < MIN_LISTAS or n < total * PARTE then return false, "pocas" end
	if not lejos(sitio) then return false, "cerca" end
	if not piedraLista() then return false, "recargando" end
	ultima = GetTime()
	local o = { lobo = "atento", tono = "acento", duracion = 12,
		titulo = L["Piedra de hogar a tiempo"],
		texto = format(L["%d de tus %d misiones listas se entregan en %s. ¿Y si usas tu piedra de hogar?"], n, total, sitio) }
	-- Con Lya a la vista lo dice ella; si no, el aviso con el botón seguro.
	if K and K.PorLya and K.PorLya(o) then return true, "lya" end
	o.accion = { texto = L["Usar la piedra"], seguro = { type = "item", item = "item:" .. PIEDRA } }
	M.Aviso(o.titulo, o.texto, o)
	return true, "aviso"
end

-- 1.3.3: ¿la ruta del motor va ahora por la piedra (un tramo `hearth`)?
function Hg.RutaConPiedra()
	local T = A.Nav and A.Nav.travel
	if not (T and type(T.CurrentLeg) == "function") then return false end
	local ok, leg = pcall(T.CurrentLeg)
	return ok and type(leg) == "table" and leg.kind == "hearth" or false
end

-- 1.3.3: cuántas de tus misiones listas se entregan en el pueblo de tu piedra
-- (sin cargar el Codex: Vuelta.Listas(true) usa la base de misiones). -> n, lugar
function Hg.Entregas()
	if enCombate() then return 0 end
	local V = M.Vuelta
	local lista = V and V.Listas(true)
	if not lista then return 0 end
	local n, _, sitio = Hg.Cuenta(lista)
	return n, sitio
end

-- Para el banco.
function Hg.Reiniciar() ultima = nil end

local pendiente = false
local function pronto(seg)
	if pendiente then return end
	pendiente = true
	A.After(seg or 3, function()
		pendiente = false
		pcall(Hg.Revisar)
	end)
end

A.RegisterEvent("QUEST_LOG_UPDATE", function() pronto(3) end)
A.RegisterEvent("ZONE_CHANGED_NEW_AREA", function() pronto(5) end)
A.RegisterEvent("PLAYER_REGEN_ENABLED", function() pronto(3) end)
