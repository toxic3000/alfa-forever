-- Alfa - Bolsas: mover objetos por lotes, siempre tras un clic. GPL-3.0.
--
-- Un clic del jugador arma la lista de casillas (bolsa, casilla, objeto) y
-- Lotes la recorre de a pocas por vez (el servidor frena las ráfagas, como
-- en la venta de chatarra del motor: QoL/Vendor.lua). Antes de cada
-- movimiento vuelve a leer la casilla (si ya no tiene ese objeto, la salta;
-- si está bloqueada, la deja para después) y comprueba que todo siga en orden
-- (fuera de combate y con el banco o el comerciante abierto). Al terminar
-- avisa. Nunca empieza ni se repite solo: cada tanda es un clic del jugador.
--
--   Lotes.Iniciar({ nombre, lista = { { bolsa, casilla, id }, ... },
--                   puede = fn() -> true | false, por qué,
--                   mover = fn(bolsa, casilla, info),
--                   alAvanzar = fn(hechos, total), alTerminar = fn(hechos, total, corte) })
--   Lotes.Activo(nombre) -> bool ; Lotes.Cancelar(nombre) ; Lotes.Avance(nombre) -> hechos, total
-- Cliente: C_Container.GetContainerItemInfo (ContainerDocumentation.lua).

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L

local type, ipairs, pairs = type, ipairs, pairs

local Lotes = {}
M.Lotes = Lotes

local POR_VEZ = 6
local CADA = 0.2
local REINTENTOS = 3

local tandas = {} -- nombre -> tanda

local function terminar(t, corte)
	if t.ticker then t.ticker:Cancel() t.ticker = nil end
	tandas[t.nombre] = nil
	if t.alTerminar then M.Seguro(t.alTerminar, t.hechos, t.total, corte) end
	M.Avisar("LOTE", t.nombre)
end

local function paso(t)
	if tandas[t.nombre] ~= t then return end
	if M.EnCombate() then return terminar(t, "combate") end
	if t.puede then
		local ok, por = t.puede()
		if not ok then return terminar(t, por or "cerrado") end
	end
	local C = C_Container
	local hechos = 0
	-- 1.3.0: lo bloqueado espera a la siguiente vuelta (antes se reintentaba en
	-- la misma y gastaba sus intentos antes de que el juego lo soltara).
	local luego = {}
	local fin = #t.lista
	while t.i <= fin and hechos < POR_VEZ do
		local e = t.lista[t.i]
		t.i = t.i + 1
		local info = C and M.Llamar(C.GetContainerItemInfo, e[1], e[2])
		local id = type(info) == "table" and M.Num(info.itemID)
		if id and id == e[3] then
			if M.Leer(info.isLocked) then
				e[4] = (e[4] or 0) + 1
				if e[4] <= REINTENTOS then luego[#luego + 1] = e end
			else
				M.Seguro(t.mover, e[1], e[2], info)
				t.hechos = t.hechos + 1
				hechos = hechos + 1
			end
		end
	end
	for _, e in ipairs(luego) do t.lista[#t.lista + 1] = e end
	if t.alAvanzar then M.Seguro(t.alAvanzar, t.hechos, t.total) end
	M.Avisar("LOTE", t.nombre)
	if t.i > #t.lista then terminar(t, nil) end
end

-- -> true si empezó
function Lotes.Iniciar(o)
	if type(o) ~= "table" or type(o.nombre) ~= "string" or type(o.lista) ~= "table" then return false end
	if tandas[o.nombre] then return false end
	if M.EnCombate() then
		N.Imprimir(L["No se puede en combate."])
		return false
	end
	local t = {
		nombre = o.nombre, lista = o.lista, i = 1, hechos = 0, total = #o.lista,
		puede = o.puede, mover = o.mover, alAvanzar = o.alAvanzar, alTerminar = o.alTerminar,
	}
	if t.total == 0 then
		if t.alTerminar then M.Seguro(t.alTerminar, 0, 0, nil) end
		return false
	end
	tandas[t.nombre] = t
	paso(t)
	if tandas[t.nombre] == t and C_Timer and C_Timer.NewTicker then
		t.ticker = C_Timer.NewTicker(CADA, function() paso(t) end)
	elseif tandas[t.nombre] == t then
		-- Sin temporizador (pruebas): todo de una vez.
		while tandas[t.nombre] == t do paso(t) end
	end
	return true
end

function Lotes.Activo(nombre) return tandas[nombre] ~= nil end

function Lotes.Avance(nombre)
	local t = tandas[nombre]
	if not t then return nil end
	return t.hechos, t.total
end

function Lotes.Cancelar(nombre)
	local t = tandas[nombre]
	if t then terminar(t, "cancelado") end
end

-- Entrar en combate corta toda tanda en curso.
A.RegisterEvent("PLAYER_REGEN_DISABLED", function()
	for _, t in pairs(tandas) do terminar(t, "combate") end
end)
