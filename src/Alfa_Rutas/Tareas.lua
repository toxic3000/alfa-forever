-- Alfa - Rutas: trabajo en segundo plano. Leer miles de misiones u objetos
-- de una vez congelaría el juego, así que cada trabajo corre en una
-- corrutina que se reparte en pedacitos de pocos milisegundos por cuadro.
-- Toxic / La Jauría. GPL-3.0.
--
--   Tareas.Lanzar(clave, fn(ceder), alTerminar(resultado | nil, error), alAvanzar?(fraccion))
--     una tarea por clave: lanzar otra con la misma clave cancela la anterior.
--     Dentro de fn se llama ceder() a menudo (nunca dentro de pcall ni de
--     funciones de comparación de table.sort: Lua 5.1 no deja ceder ahí).
--   Tareas.Corriendo(clave) -> bool
--   Tareas.Avance(clave, fraccion)  -- desde fn, para la barra de progreso

local ADDON, M = ...
local T = {}
M.Tareas = T

local type, pairs, next = type, pairs, next
local co_create, co_resume, co_status, co_yield, co_running = coroutine.create, coroutine.resume, coroutine.status, coroutine.yield, coroutine.running

local PRESUPUESTO = 8 -- milisegundos por cuadro, entre todas las tareas
local PASOS_SIN_RELOJ = 150 -- sin reloj fino: cede cada tantas llamadas

local reloj = type(debugprofilestop) == "function" and debugprofilestop or nil
local tareas = {} -- clave -> { co, fin, avance }
local inicio, cuenta = 0, 0
local marco

local function ceder()
	if not co_running() then return end
	if reloj then
		if reloj() - inicio >= PRESUPUESTO then co_yield() end
	else
		cuenta = cuenta + 1
		if cuenta >= PASOS_SIN_RELOJ then
			cuenta = 0
			co_yield()
		end
	end
end
T.Ceder = ceder

local function paso()
	for clave, t in pairs(tareas) do
		inicio, cuenta = reloj and reloj() or 0, 0
		local ok, res = co_resume(t.co, ceder)
		if co_status(t.co) == "dead" then
			if tareas[clave] == t then tareas[clave] = nil end
			if t.fin then
				local bien, err = pcall(t.fin, ok and res or nil, not ok and res or nil)
				if not bien and geterrorhandler then geterrorhandler()(err) end
			end
			if not ok and geterrorhandler then geterrorhandler()(res) end
		end
		break -- una tarea por cuadro: el presupuesto es de todas
	end
	if next(tareas) == nil and marco then marco:Hide() end
end

function T.Lanzar(clave, fn, alTerminar, alAvanzar)
	if not marco then
		marco = CreateFrame("Frame")
		marco:Hide()
		marco:SetScript("OnUpdate", paso)
	end
	tareas[clave] = { co = co_create(fn), fin = alTerminar, avance = alAvanzar }
	marco:Show()
end

function T.Corriendo(clave)
	return tareas[clave] ~= nil
end

-- ¿Queda alguna tarea en marcha?
function T.Alguna()
	return next(tareas) ~= nil
end

function T.Cancelar(clave)
	tareas[clave] = nil
end

function T.Avance(clave, frac)
	local t = tareas[clave]
	if t and t.avance then
		local ok, err = pcall(t.avance, frac)
		if not ok and geterrorhandler then geterrorhandler()(err) end
	end
end
