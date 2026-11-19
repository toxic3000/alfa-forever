-- Alfa - La Jauría: marcar el raro para todos (1.2.7). toxic3000 / La
-- Jauría. GPL-3.0.
--
-- En grupo, al seleccionar un raro (o raro élite) sin marca, Alfa te ofrece
-- ponerle la calavera: el juego se la muestra a todo tu grupo.
--
-- SetRaidTarget tiene restricciones (RaidMarkersDocumentation: HasRestrictions):
-- llamada desde Alfa saldría «Alfa se ha bloqueado de una acción...». Por eso
-- Alfa no marca solo: el aviso trae «Marcar con calavera», y ese botón lo
-- cubre el botón seguro del Kit (K.Seguro, type "click") que pulsa un botón
-- seguro de Blizzard (SecureActionButtonTemplate, acción "raidtarget",
-- "set-unmarked", marca 8): el clic es tuyo y lo hace el juego.
-- Solo fuera de combate (en combate el botón seguro no se puede armar ni
-- cubrir). En banda, solo si eres líder o ayudante. Una vez por criatura en
-- la sesión. Se apaga con manada.marcarRaro.
--
--   Ra.Revisar() -> nombre | nil, por qué    (lo llama PLAYER_TARGET_CHANGED)
--   Ra.Boton()                               el botón seguro (o nil en combate)

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local U, L, ID = M.U, M.L, M.ID

local Ra = {}
M.Raro = Ra

local type, pcall, format = type, pcall, string.format

local CALAVERA = 8
local RARO = { rare = true, rareelite = true }

local function on(clave) return N.Get(ID, clave) ~= false end
local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end

local function leer(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, v = pcall(fn, ...)
	if not ok then return nil end
	return U.Leer(v)
end

-- El botón seguro de Blizzard que pone la calavera (se arma fuera de combate).
local boton
function Ra.Boton()
	if boton then return boton end
	if enCombate() or type(CreateFrame) ~= "function" then return nil end
	local ok, b = pcall(CreateFrame, "Button", "AlfaManadaCalavera", UIParent, "SecureActionButtonTemplate")
	if not ok or type(b) ~= "table" then return nil end
	b:Hide()
	b:SetAttribute("type", "raidtarget")
	b:SetAttribute("unit", "target")
	b:SetAttribute("marker", CALAVERA)
	b:SetAttribute("action", "set-unmarked")
	-- delegate:Click() llega sin "down": la acción va al soltar.
	b:SetAttribute("useOnKeyDown", false)
	boton = b
	return b
end

-- ¿Puedo marcar? En grupo; en banda, líder o ayudante.
local function puedoMarcar()
	if not (leer(IsInGroup)) then return false end
	if leer(IsInRaid) then
		return (leer(UnitIsGroupLeader, "player") or leer(UnitIsGroupAssistant, "player")) and true or false
	end
	return true
end

local vistos = {} -- guid (o nombre) -> true: ya se ofreció en esta sesión

local function aviso(o)
	local K = N.Kit
	if K and K.Aviso then return K.Aviso(o) end
end

-- Revisa tu objetivo: si es un raro sin marca, el aviso con el botón.
function Ra.Revisar()
	if not on("marcarRaro") then return nil, "apagado" end
	if enCombate() then return nil, "combate" end
	if U.EnInstancia() then return nil, "instancia" end
	if not leer(UnitExists, "target") then return nil, "nadie" end
	if leer(UnitIsPlayer, "target") then return nil, "jugador" end
	if leer(UnitIsDeadOrGhost, "target") then return nil, "muerto" end
	local c = leer(UnitClassification, "target")
	if not RARO[c] then return nil, "comun" end
	if not puedoMarcar() then return nil, "grupo" end
	if type(CanBeRaidTarget) == "function" and leer(CanBeRaidTarget, "target") == false then return nil, "nomarca" end
	local marca = leer(GetRaidTargetIndex, "target")
	if marca ~= nil then return nil, "marcado" end
	local nombre = U.Texto(leer(UnitName, "target"))
	if not nombre then return nil, "nombre" end
	local guid = U.Texto(leer(UnitGUID, "target")) or nombre
	if vistos[guid] then return nil, "visto" end
	local b = Ra.Boton()
	if not b then return nil, "combate" end
	vistos[guid] = true
	aviso({
		titulo = format(L["Un raro: %s"], nombre),
		texto = L["Márcalo con la calavera y todo tu grupo lo verá."],
		icono = "ic-raros", duracion = 12,
		accion = {
			texto = L["Marcar con calavera"],
			seguro = { type = "click", clickbutton = b },
			-- Sin el botón seguro (en combate o con mando): se dice cómo.
			alClic = function() U.Decir(L["Para marcarlo, clic derecho en su retrato y elige la calavera."]) end,
		},
	})
	return nombre
end

-- Para el banco: olvidar lo ya ofrecido.
function Ra.Olvidar() vistos = {} end

A.RegisterEvent("PLAYER_TARGET_CHANGED", function() pcall(Ra.Revisar) end)
-- El botón seguro, listo antes de hacer falta (fuera de combate).
A.OnLogin(function() A.After(5, function() if not enCombate() then Ra.Boton() end end) end)
