-- Alfa - Curación: las medidas de tus marcos según el tamaño del grupo
-- (1.4.0, mejora 40). toxic3000 / La Jauría. GPL-3.0.
--
-- Con curacion.porTamano (de fábrica, sí) cada situación guarda sus propias
-- medidas: solo (tu marco con «Verte a ti estando solo»), en grupo (hasta 5)
-- y en banda. Lo que ajustas (ancho, alto, compañeros por columna y hacia
-- dónde crecen) se guarda en la situación en la que estás, y al cambiar de
-- situación se ponen solas las de la nueva (fuera de combate; si cambias en
-- una pelea, al terminarla). La primera vez cada situación empieza con tus
-- medidas de siempre: nada cambia hasta que ajustes algo estando ahí, o hasta
-- que uses «Banda compacta». Se guarda por personaje (M.Datos().tamanos).
--   Tm.Contexto() -> "solo" | "grupo" | "banda"
--   Tm.Medidas(ctx) -> { ancho, alto, porColumna, crecer } | nil
--   Tm.Cambiar(ctx)   Tm.BandaCompacta()   Tm.Texto() -> «Solo 84×32 · Grupo 84×32 · Banda 72×26»

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = M.L
local ID = M.ID

local type, pairs, ipairs, tonumber, format = type, pairs, ipairs, tonumber, string.format

local Tm = {}
M.Tamanos = Tm

local CLAVES = { "ancho", "alto", "porColumna", "crecer" }
local ES_CLAVE = { ancho = true, alto = true, porColumna = true, crecer = true }
Tm.COMPACTA = { ancho = 72, alto = 26, porColumna = 5, crecer = "abajo" }

local poniendo = false
local actual -- la situación cuyas medidas están puestas ahora

local function opt(k) return N.Get(ID, k) end
local function activo() return opt("porTamano") ~= false end

local function tabla()
	local d = M.Datos()
	if type(d.tamanos) ~= "table" then d.tamanos = {} end
	return d.tamanos
end

function Tm.Contexto()
	if IsInRaid and N.Si(IsInRaid()) then return "banda" end
	if IsInGroup and N.Si(IsInGroup()) then return "grupo" end
	return "solo"
end

local function vivas()
	local m = {}
	for _, k in ipairs(CLAVES) do m[k] = opt(k) end
	return m
end

function Tm.Medidas(ctx) return tabla()[ctx or Tm.Contexto()] end

-- Guarda las medidas de ahora en la situación en que se pusieron.
local function guardar()
	if not actual then return end
	tabla()[actual] = vivas()
end

local function poner(m)
	poniendo = true
	for _, k in ipairs(CLAVES) do
		if m[k] ~= nil and opt(k) ~= m[k] then N.Set(ID, k, m[k]) end
	end
	poniendo = false
end

-- Cambia a las medidas de `ctx` (fuera de combate).
function Tm.Cambiar(ctx)
	ctx = ctx or Tm.Contexto()
	if not activo() then actual = ctx return false end
	if M.EnCombate() then
		N.FueraDeCombate("curacion.tamanos", function() Tm.Cambiar() end)
		return false
	end
	if ctx == actual then return false end
	if actual then guardar() end
	local t = tabla()
	if not t[ctx] then t[ctx] = vivas() end -- la primera vez: tus medidas de siempre
	actual = ctx
	poner(t[ctx])
	return true
end

-- «Banda compacta»: para la banda, marcos chicos (y ya, si estás en una).
function Tm.BandaCompacta()
	local t = tabla()
	local m = {}
	for k, v in pairs(Tm.COMPACTA) do m[k] = v end
	t.banda = m
	if actual == "banda" and not M.EnCombate() then poner(m) end
	return m
end

local NOMBRE = { solo = "Solo", grupo = "En grupo", banda = "En banda" }
function Tm.Texto()
	local partes = {}
	for _, ctx in ipairs({ "solo", "grupo", "banda" }) do
		local m = ctx == actual and vivas() or tabla()[ctx]
		if type(m) == "table" and tonumber(m.ancho) and tonumber(m.alto) then
			partes[#partes + 1] = format("%s %d\195\151%d", L[NOMBRE[ctx]], tonumber(m.ancho), tonumber(m.alto))
		end
	end
	return table.concat(partes, "  \194\183  ")
end
function Tm.Actual() return actual end

-- 1.4.0 (revisión): «Restablecer» de la página Curación (y «Restablecer todos
-- los ajustes») también olvida las medidas de cada situación: si no, al pasar
-- de solo a grupo volvían solas las que acababas de restablecer.
function Tm.Restablecer()
	M.Datos().tamanos = {}
	actual = nil
	if activo() and not M.EnCombate() then Tm.Cambiar() end
end

-- Lo que ajustas va a la situación en que estás.
A.On("SETTING_CHANGED", function(path)
	if poniendo or type(path) ~= "string" then return end
	-- Todos los ajustes de Curación (o de Alfa) de vuelta a los de fábrica.
	if path == ID or path == "" then Tm.Restablecer() return end
	local k = path:match("^" .. ID .. "%.(.+)$")
	if k and ES_CLAVE[k] and activo() and actual then
		tabla()[actual] = vivas()
	elseif k == "porTamano" then
		actual = nil
		if activo() then Tm.Cambiar() end
	end
end)

A.RegisterEvent("GROUP_ROSTER_UPDATE", function() if activo() then Tm.Cambiar() end end)
A.RegisterEvent("PLAYER_ENTERING_WORLD", function() A.After(2, function() if activo() then Tm.Cambiar() else actual = Tm.Contexto() end end) end)
