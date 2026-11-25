-- Alfa - Rutas: «Cerrar mis misiones» con la vuelta a la ciudad (toxic3000 /
-- La Jauría). GPL-3.0. 1.4.0 (30)
--
-- En el resumen de «Cerrar mis misiones», un interruptor: «Al final, a la
-- ciudad: entrenar y vender» (rutas.cerrarCiudad, de fábrica apagado; se
-- recuerda). Encendido, al cerrar la última misión de la ruta Alfa sigue
-- solo con dos paradas más:
--   1. tu entrenador de clase, si ya te puede enseñar algo (las habilidades
--      de tu nivel que aún no sabes, Alfa.QoL.Spells del motor);
--   2. quien repara y compra: vendes lo gris y reparas.
-- La flecha va con «Buscar cerca» (Cerca.lua: el más cercano por tiempo de
-- camino) y pasa a la siguiente al cerrar la ventana del entrenador
-- (TRAINER_CLOSED) o del vendedor (MERCHANT_CLOSED). Nada se hace solo: tú
-- hablas con ellos. En combate espera a que salgas.
--
--   Ciudad.Paradas() -> { "class"?, "repair" }   las que tocan ahora
--   Ciudad.Empezar() -> ok          Ciudad.Cancelar()
--   Ciudad.Estado() -> { i, paradas } | nil

local ADDON, M = ...
local A, L, N = M.A, M.L, M.N
local Cd = {}
M.Ciudad = Cd

A.RegisterDefaults(M.ID, { cerrarCiudad = false })

local type, ipairs, pairs, pcall, tonumber, format = type, ipairs, pairs, pcall, tonumber, string.format

local CIERRA = { class = "TRAINER_CLOSED", repair = "MERCHANT_CLOSED" }

function Cd.Prendido() return A.Get(M.ID .. ".cerrarCiudad") == true end

-- Las habilidades que tu entrenador ya te puede enseñar.
function Cd.PorEntrenar()
	local Q = A.QoL
	local Sp = type(Q) == "table" and Q.Spells
	local lv = UnitLevel and UnitLevel("player")
	lv = N.Leer(lv) -- 1.4.0: («Leer and Leer(x) or x» devolvía el secreto)
	if type(Sp) ~= "table" or type(Sp.NewAt) ~= "function" or type(lv) ~= "number" then return 0 end
	local n = 0
	for l = 1, lv do
		local ok, list = pcall(Sp.NewAt, l)
		if ok and type(list) == "table" then n = n + #list end
	end
	return n
end

function Cd.Paradas()
	local out = {}
	if Cd.PorEntrenar() > 0 then out[#out + 1] = "class" end
	out[#out + 1] = "repair"
	return out
end

local function est() return M.Personaje().ciudad end
function Cd.Estado() return est() end

local function cerca() return M.Cerca end

local function ir(tipo)
	local Ce = cerca()
	if not (Ce and Ce.Ir) then return false end
	local ok, r = pcall(Ce.Ir, tipo, nil, true)
	if not (ok and r) and tipo == "repair" then ok, r = pcall(Ce.Ir, "vendor", nil, true) end
	return ok and r and true or false
end

local function textoParada(tipo)
	if tipo == "class" then
		local n = Cd.PorEntrenar()
		return M.Plural(n, L["Tu entrenador: %d habilidad nueva"], L["Tu entrenador: %d habilidades nuevas"])
	end
	return L["Vende lo gris y repara"]
end

local function seguir()
	local s = est()
	if not s then return end
	local tipo = s.paradas[s.i]
	if not tipo then
		M.Personaje().ciudad = nil
		M.Aviso(L["¡Listo para seguir de caza!"], L["Entrenaste, vendiste y reparaste. La manada te espera."], { icono = "ic-exito", lobo = "aullando" })
		return
	end
	ir(tipo)
	M.Aviso(format(L["De vuelta a la ciudad (%d de %d)"], s.i, #s.paradas), textoParada(tipo),
		{ icono = tipo == "class" and "ic-nivel" or "ic-comercio", duracion = 8,
			accion = { texto = L["Saltar esta parada"], alClic = function() Cd.Siguiente() end } })
end

function Cd.Siguiente()
	local s = est()
	if not s then return end
	s.i = s.i + 1
	seguir()
end

function Cd.Empezar()
	local paradas = Cd.Paradas()
	M.Personaje().ciudad = { i = 1, paradas = paradas }
	N.FueraDeCombate("rutas.ciudad", seguir)
	return true
end

function Cd.Cancelar() M.Personaje().ciudad = nil end

for tipo, evento in pairs(CIERRA) do
	A.RegisterEvent(evento, function()
		local s = est()
		if s and s.paradas[s.i] == tipo then N.Una("rutas.ciudadSigue", 1, function() N.FueraDeCombate("rutas.ciudad", Cd.Siguiente) end) end
	end)
end
