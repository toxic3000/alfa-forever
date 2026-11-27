-- Alfa - Comodidades: lo que escribiste antes, con las flechas (1.4.2).
-- toxic3000 / La Jauría. GPL-3.0.
--
-- En la caja del chat, el juego guarda lo que ya escribiste, pero para
-- recorrerlo pide Alt + flecha arriba/abajo (y Alt + izquierda/derecha para
-- mover el cursor). Con «chatFlechas» (de fábrica, apagado) basta la flecha:
-- arriba trae lo último que escribiste, otra vez lo de antes, y las flechas
-- de los lados mueven el cursor como en cualquier caja de texto. Al apagarlo
-- vuelve como estaba (solo en las cajas que Alfa cambió).
-- Es SetAltArrowKeyMode de la caja (SimpleEditBoxAPI, sin restricciones); las
-- ventanas de susurro que se abren después también (FCF_OpenTemporaryWindow).
--
--   Fl.Aplicar() ; Fl.Cajas() -> { caja } ; Fl.Cambiadas() -> { [caja] = true }

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L

local Fl = {}
M.Flechas = Fl

local type, pcall = type, pcall

local cambiadas = {}

function Fl.Cajas()
	local out = {}
	local n = tonumber(rawget(_G, "NUM_CHAT_WINDOWS")) or 10
	for i = 1, n do
		local caja = rawget(_G, "ChatFrame" .. i .. "EditBox")
		if type(caja) == "table" and type(caja.SetAltArrowKeyMode) == "function" then out[#out + 1] = caja end
	end
	return out
end

function Fl.Aplicar()
	local si = M.Get("chatFlechas")
	if si then
		for _, caja in ipairs(Fl.Cajas()) do
			if pcall(caja.SetAltArrowKeyMode, caja, false) then cambiadas[caja] = true end
		end
	else
		for caja in pairs(cambiadas) do pcall(caja.SetAltArrowKeyMode, caja, true) end
		cambiadas = {}
	end
end
function Fl.Cambiadas() return cambiadas end

local enganchado = false
M.AlCambiar({ "chatFlechas" }, function()
	if M.Get("chatFlechas") and not enganchado and type(rawget(_G, "FCF_OpenTemporaryWindow")) == "function" then
		enganchado = true
		hooksecurefunc("FCF_OpenTemporaryWindow", function() if M.Get("chatFlechas") then M.Seguro(Fl.Aplicar) end end)
	end
	if M.Get("chatFlechas") or next(cambiadas) then Fl.Aplicar() end
end)
