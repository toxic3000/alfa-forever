-- Alfa - Mazmorras: «Reiniciar la mazmorra» al salir (toxic3000 / La Jauría).
-- GPL-3.0. 1.4.0 (diario, 91)
--
-- Para repetir una mazmorra (subir de nivel, buscar una pieza) hay que
-- reiniciarla, y el juego lo esconde en el menú del clic derecho de tu
-- retrato. Al salir de una mazmorra de grupo, si vas solo o eres el líder,
-- un aviso chico lo ofrece con un botón: «Reiniciar». Dice cuántas instancias
-- llevas en esta hora (el límite del juego, Cronometro.lua) para que no te
-- quedes fuera. También `/alfa mazmorras reiniciar`.
-- Nunca solo (es tu clic), nunca en combate ni dentro de la instancia.
-- Ajuste mazmorras.ofrecerReiniciar (sí).
--
-- API: ResetInstances() y CanShowResetInstances() (InstanceDocumentation.lua,
-- sin restricciones; el menú del retrato del juego los usa:
-- Blizzard_UnitPopup/Camelot/UnitPopupMenus.lua), IsInGroup,
-- UnitIsGroupLeader, IsInInstance. El juego responde en el chat
-- (INSTANCE_RESET_SUCCESS), que Cronometro.lua ya lee.
--
--   Re.Puede() -> ok, motivo     ("combate" | "dentro" | "grupo" | "juego")
--   Re.Reiniciar() -> ok, motivo
--   Re.AlSalir(nombre) -> aviso | nil   (lo llama la salida de una instancia)

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)
local D = M.D
local K = N.Kit

local Re = {}
M.Reiniciar = Re

local ID = D.ID
A.RegisterDefaults(ID, { ofrecerReiniciar = true })

local type, pcall, format = type, pcall, string.format

local function encendido() return N.Get(ID, "ofrecerReiniciar") ~= false end
local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end

local function dentro()
	local Cr = M.Crono
	if Cr and Cr.Instancia then
		local ok, si = pcall(Cr.Instancia)
		return ok and si == true
	end
	return N.SiJuego(IsInInstance)
end

-- ¿Puedes reiniciar? Solo o como líder (el juego lo pide), fuera de la instancia.
function Re.Puede()
	if enCombate() then return false, "combate" end
	if dentro() then return false, "dentro" end
	if N.SiJuego(rawget(_G, "IsInGroup")) and not N.SiJuego(rawget(_G, "UnitIsGroupLeader"), "player") then return false, "grupo" end
	local puede = rawget(_G, "CanShowResetInstances")
	if type(puede) == "function" and not N.SiJuego(puede) then return false, "juego" end
	if type(rawget(_G, "ResetInstances")) ~= "function" then return false, "juego" end
	return true
end

local MOTIVO = {
	combate = "Se puede al salir de combate.",
	dentro = "Sal de la mazmorra para reiniciarla.",
	grupo = "En grupo, solo quien lo dirige puede reiniciar las mazmorras.",
	juego = "Ahora no hay ninguna mazmorra que reiniciar.",
}

function Re.Reiniciar()
	local ok, motivo = Re.Puede()
	if not ok then
		if K and K.Aviso then
			K.Aviso({ titulo = L["Reiniciar la mazmorra"], texto = L[MOTIVO[motivo] or MOTIVO.juego], icono = "ic-aviso", tono = "aviso", pedido = true })
		end
		return false, motivo
	end
	local bien = pcall(ResetInstances)
	return bien and true or false, bien and nil or "juego"
end

-- La línea de la hora (el límite del juego), si ya entraste a alguna.
local function lineaHora()
	local Cr = M.Crono
	if not (Cr and Cr.Estado) then return nil end
	local ok, e = pcall(Cr.Estado)
	if not ok or type(e) ~= "table" or not e.hora or e.hora == 0 then return nil end
	return format(L["Esta hora llevas %d de %d instancias."], e.hora, e.limite or 5)
end

local ultima -- el nombre de la última mazmorra que se ofreció (una vez por salida)

function Re.AlSalir(nombre)
	if not encendido() or not (K and K.Aviso) then return nil end
	if not Re.Puede() then return nil end
	local t = nombre and format(L["Si vas a repetir %s, reiníciala: los enemigos y el botín vuelven."], nombre)
		or L["Si vas a repetir la mazmorra, reiníciala: los enemigos y el botín vuelven."]
	local h = lineaHora()
	if h then t = t .. " " .. h end
	return K.Aviso({
		id = "mazmorras.reiniciar", titulo = L["¿Reiniciar la mazmorra?"], texto = t, icono = "ic-mazmorra",
		tono = "acento", duracion = 15, prioridad = "util", caduca = 120,
		acciones = { { texto = L["Reiniciar"], alClic = function() Re.Reiniciar() end } },
	})
end

-- Saliste de una mazmorra de grupo (o de banda): se ofrece al llegar afuera.
local estaba -- nombre de la instancia de grupo donde estabas | false
A.RegisterEvent("PLAYER_ENTERING_WORLD", function()
	N.Una("mazmorras.reiniciar", 2, function()
		local si = dentro()
		if si then
			local nombre
			if GetInstanceInfo then
				local ok, n = pcall(GetInstanceInfo)
				nombre = ok and D.Legible(n) or nil
			end
			estaba = type(nombre) == "string" and nombre ~= "" and nombre or true
			return
		end
		if estaba then
			local nombre = type(estaba) == "string" and estaba or nil
			estaba = false
			if ultima ~= nombre or nombre == nil then
				ultima = nombre
				N.FueraDeCombate("mazmorras.reiniciar", function() Re.AlSalir(nombre) end)
			end
		end
	end)
end)
-- Al entrar de nuevo, se puede volver a ofrecer al salir.
A.RegisterEvent("PLAYER_LEAVING_WORLD", function() if dentro() then ultima = nil end end)
