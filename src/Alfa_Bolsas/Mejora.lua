-- Alfa - Bolsas: «Ponte esto», el equipo nuevo que es mejor (toxic3000 / La Jauría). GPL-3.0. 1.2.9.
--
-- Cuando te llega a las bolsas una pieza de equipo que es mejor que lo que
-- llevas puesto para tu clase (botín, comerciante, correo, misión), un aviso
-- «Ponte esto» con lo que ganas y el botón «Ponérmelo»: solo con tu clic y
-- fuera de combate (en combate, se pone al terminar).
--
-- Quién decide si es mejor: el motor (Alfa.Gear, el mismo orden que usa la
-- mejor recompensa de 1.2.8 en Alfa_Comodidades/Misiones.lua). La oferta sale
-- de su vigía de equipo (QoL/Wear.lua: Wear.Offer, el evento WEAR_OFFER), que
-- ya sabe qué es nuevo, la ranura (el anillo o abalorio más flojo, una mano
-- contra un arma de dos) y lo que no quieres; si ese vigía está apagado
-- (qol.wearOffer), Alfa mira por su cuenta lo nuevo de tus bolsas con
-- Gear.IsUpgrade y Gear.CompareToEquipped.
--
-- Ponerse equipo: C_Item.EquipItemByName(objeto, ranura)
-- (ItemDocumentation.lua; sin HasRestrictions, pero el juego no deja cambiar
-- la armadura en combate). Una pieza que se liga al equiparla trae la
-- confirmación del propio juego.
-- Ajuste bolsas.ponteEsto (de fábrica, encendido).
--   Mj.Oferta() -> { id, link, slot, pct } | nil ; Mj.Poner(o) ; Mj.Revisar()

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local K = N.Kit

local type, pairs, ipairs, tonumber, format = type, pairs, ipairs, tonumber, string.format

local Mj = {}
M.Mejora = Mj

local avisados = {}   -- itemID -> true: ya se avisó en esta sesión
local propias = {}    -- las ofertas de Alfa cuando el vigía del motor está apagado
local cuentas         -- itemID -> cuántos había en las bolsas la última vez
local aviso, turno    -- el aviso a la vista

local function encendido() return M.Get("ponteEsto") ~= false end

local function gear()
	local G = A.Gear
	if not (G and type(G.IsUpgrade) == "function") then return nil end
	if type(G.IsEnabled) == "function" and not M.Leer(M.Llamar(G.IsEnabled)) then return nil end
	return G
end

-- El vigía del motor, si está encendido.
local function vigia()
	local Q = A.QoL
	local W = Q and Q.Wear
	if not (W and type(W.Offer) == "function") then return nil end
	if A.Get("qol.wearOffer") == false then return nil end
	return W
end

local function idDe(link) return M.ItemID(link) end

-- La ranura y la ganancia de una pieza (como el motor): -> ranura, pct | nil
local function lugar(G, link)
	local Q = A.QoL
	local E = Q and Q.Equip
	if E and type(E.Placement) == "function" then
		local slot, pct = M.Llamar(E.Placement, G, link)
		if slot then return slot, pct end
		return nil
	end
	local up, _, pct = M.Llamar(G.IsUpgrade, link)
	if not up then return nil end
	local r = M.Llamar(G.CompareToEquipped, link)
	return type(r) == "table" and r.slot or nil, pct
end

local function equipable(id)
	local CI = C_Item
	if not (CI and CI.GetItemInfoInstant) then return false end
	local _, _, _, loc = M.Llamar(CI.GetItemInfoInstant, id)
	loc = M.Texto(loc)
	return loc ~= nil and loc ~= "" and loc ~= "INVTYPE_NON_EQUIP_IGNORE" and loc ~= "INVTYPE_BAG"
end

-- Lo nuevo de tus bolsas, sin el vigía del motor.
local function mirarBolsas()
	local G = gear()
	local C = C_Container
	if not (G and C) then return end
	local ahora, enlaces = {}, {}
	for _, bolsa in ipairs({ 0, 1, 2, 3, 4 }) do
		for s = 1, M.Num(M.Llamar(C.GetContainerNumSlots, bolsa)) or 0 do
			local info = M.Llamar(C.GetContainerItemInfo, bolsa, s)
			local id = type(info) == "table" and M.Num(info.itemID)
			if id then
				ahora[id] = (ahora[id] or 0) + (M.Num(info.stackCount) or 1)
				enlaces[id] = enlaces[id] or M.Texto(info.hyperlink)
			end
		end
	end
	local antes = cuentas
	cuentas = ahora
	if not antes then return end
	for id, n in pairs(ahora) do
		if n > (antes[id] or 0) and enlaces[id] and equipable(id) then
			local slot, pct = lugar(G, enlaces[id])
			if slot then
				local ya = false
				for _, o in ipairs(propias) do if o.id == id then ya = true end end
				if not ya then propias[#propias + 1] = { id = id, link = enlaces[id], slot = slot, pct = pct } end
			end
		end
	end
	-- Lo que ya no está en tus bolsas, o ya no es mejor, se va.
	local quedan = {}
	for _, o in ipairs(propias) do
		if ahora[o.id] and lugar(G, o.link) then quedan[#quedan + 1] = o end
	end
	propias = quedan
end

function Mj.Oferta()
	if not encendido() then return nil end
	local W = vigia()
	if W then
		local o = M.Llamar(W.Offer)
		if type(o) == "table" and o.id and o.link then return { id = o.id, link = o.link, slot = o.slot, pct = o.pct, motor = true } end
		return nil
	end
	return propias[1]
end

local function cerrarAviso()
	if aviso and aviso.Cerrar and turno then aviso:Cerrar(turno) end
	aviso, turno = nil, nil
end

function Mj.Poner(o)
	o = o or Mj.Oferta()
	if not (o and o.link) then return false end
	if M.EnCombate() then
		N.Imprimir(L["En combate no se puede cambiar el equipo: te lo pongo al terminar."])
		N.FueraDeCombate("bolsas.ponteEsto", function() Mj.Poner(o) end)
		return "espera"
	end
	-- 1.3.0: lo que se pidió en combate se pone al terminar, pero si ya lo
	-- llevas en esa ranura (te lo pusiste tú, o el motor) no se toca: ponerlo
	-- otra vez movía anillos y abalorios de una ranura a la otra.
	if o.slot and o.id and GetInventoryItemID and M.Num(M.Llamar(GetInventoryItemID, "player", o.slot)) == o.id then
		for i, x in ipairs(propias) do
			if x.id == o.id then table.remove(propias, i) break end
		end
		return false
	end
	-- Del vigía del motor: él lo pone (y sabe cuándo quedó puesto).
	if o.motor then
		local W = vigia()
		local ahora = W and M.Llamar(W.Offer)
		if W and type(W.Take) == "function" and type(ahora) == "table" and ahora.id == o.id then
			M.Seguro(W.Take)
			return true
		end
	end
	local CI = C_Item
	if not (CI and CI.EquipItemByName) then return false end
	M.Seguro(CI.EquipItemByName, o.link, o.slot)
	for i, x in ipairs(propias) do
		if x.id == o.id then table.remove(propias, i) break end
	end
	return true
end

local function textoGanancia(o)
	local G = A.Gear
	if o.pct and G and type(G.GainText) == "function" then
		local t = M.Texto(M.Llamar(G.GainText, o.pct))
		if t then return t end
	end
	if type(o.pct) == "number" and o.pct > 0 then return format(L["+%d %%"], math.floor(o.pct + 0.5)) end
	return nil
end

local function mostrar(o)
	if not (o and encendido()) then return end
	if M.EnCombate() then
		N.FueraDeCombate("bolsas.ponteEstoAviso", function() mostrar(Mj.Oferta()) end)
		return
	end
	avisados[o.id] = true
	local gana = textoGanancia(o)
	local texto = gana and format(L["%s es mejor que lo que llevas puesto (%s)."], o.link, gana)
		or format(L["%s es mejor que lo que llevas puesto."], o.link)
	local a = K.Aviso({
		titulo = L["Ponte esto"], texto = texto, icono = "ic-nivel", tono = "exito", duracion = 15,
		accion = { texto = L["Ponérmelo"], alClic = function() Mj.Poner(o) end },
	})
	if type(a) == "table" and a.Cerrar then aviso, turno = a, a.turno else aviso, turno = nil, nil end
	Mj.ultimo = o
end

function Mj.Revisar()
	if not encendido() then return cerrarAviso() end
	if not vigia() then mirarBolsas() end
	local o = Mj.Oferta()
	if not o then return cerrarAviso() end
	if avisados[o.id] then return end
	mostrar(o)
end

local pendiente = false
local function revisarLuego()
	if pendiente then return end
	pendiente = true
	M.Luego(0.3, function()
		pendiente = false
		Mj.Revisar()
	end)
end

A.On("WEAR_OFFER", revisarLuego)
A.RegisterEvent("BAG_UPDATE_DELAYED", function() if not vigia() then revisarLuego() end end)
A.OnLogin(function()
	-- La foto de lo que ya llevabas al entrar: eso no es nuevo.
	if not vigia() then mirarBolsas() end
end)
A.On("SETTING_CHANGED", function(ruta)
	if ruta == M.ID .. ".ponteEsto" or ruta == "qol.wearOffer" then
		cuentas = nil
		propias = {}
		if not vigia() then mirarBolsas() end
		if not encendido() then cerrarAviso() end
	end
end)
