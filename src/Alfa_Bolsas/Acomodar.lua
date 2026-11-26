-- Alfa - Bolsas: acomodar con un clic (toxic3000 / La Jauría). GPL-3.0. 1.3.0.
--
-- Un solo botón, «Acomodar», que hace lo que toca donde estás:
--   * con un comerciante abierto, vende la chatarra (Sugerencias.lua,
--     S.VenderChatarra: la regla del motor, por lotes);
--   * con un banquero, guarda tus materiales en el banco (Banco.lua,
--     «Todos los materiales», por lotes y contando lo que cabe).
-- Siempre tras el clic del jugador, nunca en combate y nunca solo; otro clic
-- lo detiene. Lejos de ambos no hace nada (y lo dice).
-- Ajuste bolsas.acomodar (de fábrica, encendido).
--   Ac.Que() -> "vender" | "banco" | nil, cuántas casillas ; Ac.Hacer() ; Ac.Activo()

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local D = M.Datos

local format = string.format

local Ac = {}
M.Acomodar = Ac

local function encendido() return M.Get("acomodar") ~= false end

local suyo -- 1.3.2: la tanda que empezó «Acomodar» ("vender" | "depositar")

function Ac.Activo()
	return M.Lotes.Activo("vender") or M.Lotes.Activo("depositar")
end

-- 1.3.2: la tanda de «Acomodar» en curso: -> nombre, hechos, total | nil
-- (Depositar, desde su propio botón, no cuenta aquí: ese ya dice su avance).
function Ac.Avance()
	if not (suyo and M.Lotes.Activo(suyo)) then
		suyo = nil
		return nil
	end
	local hechos, total = M.Lotes.Avance(suyo)
	return suyo, hechos, total
end

function Ac.Que()
	if not encendido() then return nil, 0 end
	local S = M.Sugerencias
	if S and S.ComercianteAbierto() then
		local lista = S.ChatarraAhora()
		if #lista > 0 then return "vender", #lista end
	end
	if D.BancoAbierto() then
		local cuentas = M.Banco.Cuentas()
		local n = cuentas and cuentas.materiales or 0
		if n > 0 then return "banco", n end
	end
	return nil, 0
end

-- El texto del cuadro del botón: qué hará.
function Ac.Ayuda()
	if Ac.Activo() then return L["Clic para detener."] end
	local que, n = Ac.Que()
	if que == "vender" then return format(L["Vende tu chatarra en este comerciante (%d)."], n) end
	if que == "banco" then return format(L["Guarda tus materiales en el banco (%d)."], n) end
	return L["Con un comerciante abierto vende tu chatarra; con un banquero guarda tus materiales."]
end

-- -> true si empezó (o detuvo lo que corría)
function Ac.Hacer()
	if M.Lotes.Activo("vender") then M.Sugerencias.VenderChatarra() return true end
	if M.Lotes.Activo("depositar") then M.Banco.Depositar() return true end
	if M.EnCombate() then
		N.Imprimir(L["Se puede al salir de combate."])
		return false
	end
	local que = Ac.Que()
	if que == "vender" then
		M.Sugerencias.VenderChatarra()
		suyo = M.Lotes.Activo("vender") and "vender" or nil
		M.Avisar("LOTE", "vender")
		return true
	elseif que == "banco" then
		M.Banco.Depositar("materiales")
		suyo = M.Lotes.Activo("depositar") and "depositar" or nil
		M.Avisar("LOTE", "depositar")
		return true
	end
	N.Imprimir(L["Nada que acomodar aquí: abre un comerciante para vender tu chatarra o habla con un banquero para guardar tus materiales."])
	return false
end
