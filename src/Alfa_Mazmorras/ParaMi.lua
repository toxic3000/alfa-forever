-- Alfa - Mazmorras: «¿Qué cae aquí para mí?» (1.4.0, mejora 43).
-- toxic3000 / La Jauría. GPL-3.0.
--
-- El botín de cada jefe ya marca lo que es mejora (Vista.lua, pestaña
-- Botín). Aquí, todo junto y de un vistazo: lo que te sirve de esta mazmorra,
-- jefe por jefe, solo lo que todavía no tienes y es mejora para ti ahora (o
-- lo será en unos niveles):
--   * Al entrar a una mazmorra (fuera de combate, una vez por sesión y
--     mazmorra) un aviso chico: «Para ti en Las Minas de la Muerte: 3 mejoras
--     (de Rhahk'Zor y VanCleef)» con «Ver» (la pestaña Botín con «Lo mío»).
--   * La tarjeta en vivo de un jefe (EnVivo.lua) dice qué te sirve de él.
--   * /alfa mazmorras parami (dentro o fuera: la última que viste).
-- En modo historia no adelanta jefes por descubrir. Ajuste
-- mazmorras.paraMi (de fábrica, sí).
--   Pm.Lista(key) -> { { jefe, nombre, objetos = { { id, nombre, mejora, nivel } } } }
--   Pm.Resumen(key) -> texto | nil    Pm.DeJefe(key, nombreOId) -> { nombre, ... }
--   Pm.Avisar(key) -> true si avisó    Pm.Ver(key)

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = N.Textos(M.EN)
local D = M.D

local type, ipairs, pcall, format, min, tostring = type, ipairs, pcall, string.format, math.min, tostring

local Pm = {}
M.ParaMi = Pm

local ID = D.ID
local avisadas = {} -- key -> true (esta sesión)

local function activo() return N.Get(ID, "paraMi") ~= false end

function Pm.Lista(key)
	local out = {}
	if type(key) ~= "string" then return out end
	local ok, jefes = pcall(D.Jefes, key)
	if not ok or type(jefes) ~= "table" then return out end
	for _, jf in ipairs(jefes) do
		if D.Descubierto(key, jf) then
			local bien, principal = pcall(D.BotinDe, key, jf)
			local objetos = {}
			for _, e in ipairs(bien and principal or {}) do
				if type(e) == "table" and e.id and not D.Obtenido(e, key) then
					local mejora, _, nivel = D.Mejora(e.id)
					if mejora or nivel then
						local o = D.Objeto(e)
						objetos[#objetos + 1] = { id = e.id, nombre = o and o.nombre or ("#" .. tostring(e.id)), calidad = o and o.calidad,
							mejora = mejora and true or false, nivel = nivel, chance = e.chance }
					end
				end
			end
			if #objetos > 0 then
				table.sort(objetos, function(a, b) if a.mejora ~= b.mejora then return a.mejora end return (a.chance or 0) > (b.chance or 0) end)
				out[#out + 1] = { jefe = jf, nombre = jf.nombre or "?", objetos = objetos }
			end
		end
	end
	return out
end

local function cuenta(lista)
	local ya, luego = 0, 0
	for _, j in ipairs(lista) do
		for _, o in ipairs(j.objetos) do if o.mejora then ya = ya + 1 else luego = luego + 1 end end
	end
	return ya, luego
end
Pm.Cuenta = cuenta

function Pm.Resumen(key)
	local lista = Pm.Lista(key)
	local ya, luego = cuenta(lista)
	if ya + luego == 0 then return nil end
	local nombres = {}
	for i = 1, min(3, #lista) do nombres[#nombres + 1] = lista[i].nombre end
	local de = table.concat(nombres, ", ")
	if #lista > 3 then de = de .. " " .. format(L["y %d más"], #lista - 3) end
	if ya > 0 then
		return format(L["%s para ti, de %s."], N.Plural(ya, L["%d mejora"], L["%d mejoras"]), de)
	end
	return format(L["%s para dentro de unos niveles, de %s."], N.Plural(luego, L["%d mejora"], L["%d mejoras"]), de)
end

-- Lo que te sirve de un jefe (por su nombre o su id de PNJ).
function Pm.DeJefe(key, jefe)
	local out = {}
	for _, j in ipairs(Pm.Lista(key)) do
		local jf = j.jefe
		if jf == jefe or jf.nombre == jefe or (jefe ~= nil and jf.npc == jefe) or (type(jefe) == "table" and jefe.nombre == jf.nombre) then
			for _, o in ipairs(j.objetos) do if o.mejora then out[#out + 1] = o.nombre end end
		end
	end
	return out
end

function Pm.Ver(key)
	N.Set(ID, "meSirve", true)
	local V = M.V
	if V and V.AbrirMazmorra and key then V.AbrirMazmorra(key, "botin") end
end

function Pm.Avisar(key, pedido)
	if not (key and (activo() or pedido)) then return false end
	if avisadas[key] and not pedido then return false end
	local texto = Pm.Resumen(key)
	if not texto then
		if pedido then N.Imprimir(format(L["En %s no veo nada que sea mejora para ti."], D.Nombre(key) or key)) end
		return false
	end
	avisadas[key] = true
	K.Aviso({ titulo = format(L["Para ti en %s"], D.Nombre(key) or key), texto = texto, icono = "ic-mazmorra", tono = "mazmorra",
		modulo = "mazmorras", duracion = 12, prioridad = 3,
		accion = { texto = L["Ver"], alClic = function() Pm.Ver(key) end } })
	return true
end

-- Al entrar a una mazmorra: una vez, con calma y fuera de combate.
local function alEntrar()
	if not activo() then return end
	local key = D.MazmorraActual and D.MazmorraActual()
	if not key or avisadas[key] then return end
	local libre = N.AlLibre or function(_, f) f() end
	N.FueraDeCombate("mazmorras.paraMi", function() libre("mazmorras.paraMi", function() Pm.Avisar(key) end, 3) end)
end
A.RegisterEvent("PLAYER_ENTERING_WORLD", function() A.After(6, alEntrar) end)

A.OnLogin(function()
	local Lya = rawget(_G, "AlfaLya")
	if type(Lya) == "table" and type(Lya.Ensenar) == "function" then
		pcall(Lya.Ensenar, { id = "mazmorras.paraMi", icono = "ic-mazmorra", modulo = "mazmorras",
			pregunta = L["¿Qué cae aquí para mí?"],
			respuesta = L["Al entrar a una mazmorra te digo cuántas mejoras hay para ti y de qué jefes; «Ver» abre su botín con solo lo tuyo. También con /alfa mazmorras parami."] })
	end
end)
