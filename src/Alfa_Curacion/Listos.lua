-- Alfa - Curación: «¿Listos?» y los hechizos de apoyo que faltan en el grupo
-- (1.3.7, toxic3000 / La Jauría). GPL-3.0.
--
-- Cuando alguien lanza «¿Listos?» del juego (READY_CHECK), o con
-- /alfa curacion listos, una placa chica arriba de la pantalla dice:
--   * lo tuyo: comida y bebida, munición (cazador), cómo va tu equipo
--     (reparar) y el espacio en tus bolsas;
--   * a quién del grupo le falta Entereza, Marca de lo Salvaje o Intelecto
--     Arcano (solo si en el grupo hay quien lo pueda dar);
--   * si el que falta es tuyo, un botón «Dar <hechizo> a <nombre>». Ese botón
--     es seguro (K.Seguro: el clic lo hace el juego, como en tu barra) y se
--     prepara fuera de combate. Alfa nunca lanza nada solo.
-- Nada se manda al chat. En combate la placa se va.
--
-- Auras: C_UnitAuras.GetAuraDataBySpellName (si llega secreto, en mazmorras,
-- no se sabe: no se cuenta). Comida: C_Item.GetItemInfo classID 0 (consumible)
-- y subclase 5 (comida y bebida) (por confirmar en Forever). Munición:
-- GetInventoryItemCount("player", 0) (la ranura de munición del juego clásico).
-- Equipo: GetInventoryItemDurability. Espacio: C_Container.GetContainerNumFreeSlots.

local _, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID
local secreto = M.Secreto

local type, ipairs, pairs, floor, format, min, max = type, ipairs, pairs, math.floor, string.format, math.min, math.max

local Li = {}
M.Listos = Li

Li.BUFOS = {
	{ id = "entereza", clase = "PRIEST", claves = { "entereza", "rezoEntereza" }, nombre = "Entereza" },
	{ id = "marca", clase = "DRUID", claves = { "marcaSalvaje", "donSalvaje" }, nombre = "Marca de lo Salvaje" },
	{ id = "intelecto", clase = "MAGE", claves = { "intelectoArcano", "brillanteArcano" }, nombre = "Intelecto Arcano", mana = true },
}
Li.MUNICION_POCA = 200
Li.EQUIPO_BAJO = 0.30
Li.ESPACIO_POCO = 4

local function leer(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, v = pcall(fn, ...)
	if not ok or secreto(v) then return nil end
	return v
end

local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end

---------------------------------------------------------------------------
-- El grupo
---------------------------------------------------------------------------

function Li.Unidades()
	local out = {}
	if IsInRaid and IsInRaid() then
		local n = leer(GetNumGroupMembers) or 0
		for i = 1, n do out[#out + 1] = "raid" .. i end
	else
		out[1] = "player"
		if IsInGroup and IsInGroup() then
			local n = leer(GetNumSubgroupMembers) or 0
			for i = 1, n do out[#out + 1] = "party" .. i end
		end
	end
	return out
end

local function clase(u)
	if not UnitClass then return nil end
	local ok, _, c = pcall(UnitClass, u)
	if ok and not secreto(c) and type(c) == "string" then return c end
	return nil
end

local function nombre(u)
	local n = leer(UnitName, u)
	return type(n) == "string" and n or nil
end

local function cuenta(u)
	if leer(UnitIsConnected, u) == false then return false end
	if leer(UnitIsDeadOrGhost, u) == true then return false end
	return leer(UnitExists, u) ~= false
end

-- ¿Tiene ese apoyo? true / false / nil (no se puede saber: secreto)
function Li.Tiene(u, bufo)
	local U = C_UnitAuras
	if not (U and U.GetAuraDataBySpellName) then return nil end
	local sabe = false
	for _, k in ipairs(bufo.claves) do
		local ids = M.H[k]
		local n = ids and M.NombreHechizo(ids[1])
		if n then
			local ok, a = pcall(U.GetAuraDataBySpellName, u, n, "HELPFUL")
			if ok and not secreto(a) then
				sabe = true
				if a ~= nil then return true end
			end
		end
	end
	if sabe then return false end
	return nil
end

local function usaMana(u)
	local t = leer(UnitPowerType, u)
	return t == nil or t == 0
end

-- -> { { bufo, faltan = { { unidad, nombre } }, mio = { k, id, hechizo } | nil }, ... }
function Li.Faltan()
	local unidades = Li.Unidades()
	local clases = {}
	for _, u in ipairs(unidades) do
		local c = clase(u)
		if c and cuenta(u) then clases[c] = true end
	end
	local mia = M.Clase()
	local out = {}
	for _, bufo in ipairs(Li.BUFOS) do
		if clases[bufo.clase] then
			local faltan = {}
			for _, u in ipairs(unidades) do
				if cuenta(u) and (not bufo.mana or usaMana(u)) and Li.Tiene(u, bufo) == false then
					faltan[#faltan + 1] = { unidad = u, nombre = nombre(u) or "?" }
				end
			end
			if #faltan > 0 then
				local e = { bufo = bufo, faltan = faltan }
				if mia == bufo.clase then
					for _, k in ipairs(bufo.claves) do
						local id = M.Conocido(k)
						if id then
							e.mio = { k = k, id = id, hechizo = M.NombreHechizo(id) }
							break
						end
					end
				end
				out[#out + 1] = e
			end
		end
	end
	return out
end

---------------------------------------------------------------------------
-- Lo tuyo
---------------------------------------------------------------------------

-- 1.3.7: la cuenta de Inicio (los objetos de «Comida» y «Bebida», con su
-- lista de respaldo): en clásico la comida es un consumible genérico y la
-- clase 0 / subclase 5 casi nunca sale. La de abajo queda de respaldo.
local function comidaInicio()
	local I = rawget(_G, "AlfaInicio")
	if type(I) ~= "table" or type(I.Comida) ~= "function" then return nil end
	local ok, comida, agua = pcall(I.Comida)
	if not ok or type(comida) ~= "number" then return nil end
	return comida + (type(agua) == "number" and agua or 0)
end

function Li.Comida()
	local deInicio = comidaInicio()
	local propia = Li.ComidaPropia()
	if deInicio and propia then return math.max(deInicio, propia) end
	return deInicio or propia
end

function Li.ComidaPropia()
	local C = C_Container
	if not (C and C.GetContainerNumSlots and C.GetContainerItemInfo) then return nil end
	local get = C_Item and C_Item.GetItemInfo
	if type(get) ~= "function" then return nil end
	local n = 0
	for bolsa = 0, 4 do
		local s = leer(C.GetContainerNumSlots, bolsa) or 0
		for i = 1, s do
			local info = leer(C.GetContainerItemInfo, bolsa, i)
			local id = type(info) == "table" and info.itemID
			if type(id) == "number" then
				local ok, _, _, _, _, _, _, _, _, _, _, _, claseID, subclase = pcall(get, id)
				if ok and claseID == 0 and subclase == 5 then n = n + (info.stackCount or 1) end
			end
		end
	end
	return n
end

function Li.Municion()
	if M.Clase() ~= "HUNTER" then return nil end
	local n = leer(GetInventoryItemCount, "player", 0)
	return type(n) == "number" and n or nil
end

-- La pieza más gastada: fracción 0..1 (nil si no se sabe).
function Li.Equipo()
	if type(GetInventoryItemDurability) ~= "function" then return nil end
	local peor
	for slot = 1, 18 do
		local ok, v, mx = pcall(GetInventoryItemDurability, slot)
		if ok and type(v) == "number" and type(mx) == "number" and mx > 0 then
			local f = v / mx
			if not peor or f < peor then peor = f end
		end
	end
	return peor
end

function Li.Espacio()
	local C = C_Container
	if not (C and C.GetContainerNumFreeSlots) then return nil end
	local total = 0
	for bolsa = 0, 4 do
		local ok, libres, familia = pcall(C.GetContainerNumFreeSlots, bolsa)
		if ok and type(libres) == "number" and (familia == nil or familia == 0) then total = total + libres end
	end
	return total
end

-- -> { { texto, bien = bool }, ... }
function Li.MisCosas()
	local out = {}
	local comida = Li.Comida()
	if comida then
		out[#out + 1] = comida > 0 and { texto = format(L["Comida y bebida: %d"], comida), bien = true }
			or { texto = L["No llevas comida ni bebida"], bien = false }
	end
	local mun = Li.Municion()
	if mun then out[#out + 1] = { texto = format(L["Munición: %d"], mun), bien = mun >= Li.MUNICION_POCA } end
	local eq = Li.Equipo()
	if eq then
		local p = floor(eq * 100 + 0.5)
		out[#out + 1] = eq >= Li.EQUIPO_BAJO and { texto = format(L["Tu equipo: %d %%"], p), bien = true }
			or { texto = format(L["Repara: una pieza está al %d %%"], p), bien = false }
	end
	local esp = Li.Espacio()
	if esp then
		out[#out + 1] = { texto = N.Plural(esp, L["%d espacio libre en tus bolsas"], L["%d espacios libres en tus bolsas"]), bien = esp >= Li.ESPACIO_POCO }
	end
	return out
end

---------------------------------------------------------------------------
-- La placa
---------------------------------------------------------------------------

local ANCHO, MAX_LINEAS = 330, 9
local placa

local function nombres(faltan)
	local t = {}
	for i = 1, min(3, #faltan) do t[#t + 1] = faltan[i].nombre end
	local s = table.concat(t, ", ")
	if #faltan > 3 then s = s .. " " .. format(L["y %d más"], #faltan - 3) end
	return s
end

local function armar()
	if placa then return placa end
	placa = CreateFrame("Frame", "AlfaCuracionListos", K.Raiz())
	placa:SetWidth(ANCHO)
	placa:SetPoint("TOP", UIParent, "TOP", 0, -120)
	placa:SetFrameStrata("MEDIUM")
	placa.caja = K.Caja(placa, { fondo = "fondo", borde = "linea", corte = K.CORTE.panel })
	placa.Marca = K.Marca(placa, K.CORTE.panel, "acento")
	placa.Titulo = K.Texto(placa, "encabezado", "texto")
	placa.Titulo:SetPoint("TOPLEFT", placa, "TOPLEFT", K.ESP.m, -K.ESP.m)
	placa.Cerrar = K.BotonIcono(placa, "ic-cerrar", function() Li.Ocultar() end, { tam = 22, ayuda = L["Cerrar"] })
	placa.Cerrar:SetPoint("TOPRIGHT", placa, "TOPRIGHT", -K.ESP.s, -K.ESP.s)
	placa.lineas = {}
	for i = 1, MAX_LINEAS do
		local f = CreateFrame("Frame", nil, placa)
		f:SetSize(ANCHO - 2 * K.ESP.m, 18)
		f.Icono = K.Icono(f, "ic-exito", 12, "exito")
		f.Icono:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -2)
		f.Texto = K.Texto(f, "pequeno", "texto")
		f.Texto:SetPoint("TOPLEFT", f.Icono, "TOPRIGHT", K.ESP.s, 1)
		placa.lineas[i] = f
	end
	placa.Dar = K.Boton(placa, "", function()
		-- En combate (o con mando) el seguro no cubre: el clic normal lo dice.
		N.Imprimir(L["Dáselo al terminar el combate, con el botón de la placa o tu barra."])
	end, { tipo = "primario", tam = "chico", icono = "ic-curacion" })
	placa.Dar:Hide()
	K.Seguro(placa.Dar, function()
		local d = placa.dar
		if not (d and d.unidad and d.hechizo) or enCombate() then return nil end
		return { type = "macro", macrotext = "/cast [@" .. d.unidad .. "] " .. d.hechizo }
	end)
	placa.Dar.alfaTrasClic = function() N.Una("curacion.listosPintar", 0.6, function() Li.Pintar() end, { fueraDeCombate = true }) end
	placa:Hide()
	return placa
end

function Li.Pintar()
	if not placa or not placa:IsShown() then return end
	K.Escribir(placa.Titulo, placa.motivo == "listo" and L["¿Listos?"] or L["Antes de jalar"])
	local filas = {}
	for _, c in ipairs(Li.MisCosas()) do filas[#filas + 1] = c end
	local faltan = Li.Faltan()
	local dar
	for _, e in ipairs(faltan) do
		filas[#filas + 1] = { texto = format(L["Les falta %s: %s"], L[e.bufo.nombre], nombres(e.faltan)), bien = false, apoyo = true }
		if not dar and e.mio and e.mio.hechizo then
			dar = { unidad = e.faltan[1].unidad, nombre = e.faltan[1].nombre, hechizo = e.mio.hechizo }
		end
	end
	if #faltan == 0 and IsInGroup and IsInGroup() then
		filas[#filas + 1] = { texto = L["Nadie del grupo tiene hechizos de apoyo pendientes."], bien = true }
	end
	local ancho = ANCHO - 2 * K.ESP.m - 12 - K.ESP.s
	local y = -K.ESP.m - 22
	for i, f in ipairs(placa.lineas) do
		local d = filas[i]
		if d then
			K.SetIcono(f.Icono, d.bien and "ic-exito" or "ic-alerta", d.bien and "exito" or "aviso")
			K.Parrafo(f.Texto, ancho, 2)
			K.Escribir(f.Texto, d.texto)
			local alto = max(16, K.AltoTexto(f.Texto) + 2)
			f:SetHeight(alto)
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", placa, "TOPLEFT", K.ESP.m, y)
			f:Show()
			y = y - alto - 2
		else
			f:Hide()
		end
	end
	placa.dar = dar
	if dar and not enCombate() then
		placa.Dar:SetTexto(format(L["Dar %s a %s"], dar.hechizo, dar.nombre))
		placa.Dar:ClearAllPoints()
		placa.Dar:SetPoint("TOPLEFT", placa, "TOPLEFT", K.ESP.m, y - K.ESP.s)
		placa.Dar:Show()
		y = y - K.ESP.s - (placa.Dar:GetHeight() or 24)
	else
		placa.Dar:Hide()
	end
	placa:SetHeight(floor(-y + K.ESP.m + 0.5))
end

-- motivo: "listo" (el «¿Listos?» del juego) | "manual"
function Li.Mostrar(motivo)
	if enCombate() then return false end
	armar()
	placa.motivo = motivo or "manual"
	placa:Show()
	Li.Pintar()
	N.Una("curacion.listosCerrar", motivo == "listo" and 40 or 60, function() Li.Ocultar() end)
	return true
end

function Li.Ocultar()
	N.Quitar("curacion.listosCerrar")
	if placa then placa:Hide() end
end

function Li.Placa() return placa end
function Li.Visible() return placa and placa:IsShown() or false end

A.RegisterEvent("READY_CHECK", function()
	if N.Get(ID, "listos") == false then return end
	Li.Mostrar("listo")
end)
A.RegisterEvent("READY_CHECK_FINISHED", function()
	if placa and placa:IsShown() and placa.motivo == "listo" then
		N.Una("curacion.listosCerrar", 8, function() Li.Ocultar() end)
	end
end)
A.RegisterEvent("PLAYER_REGEN_DISABLED", function() if placa and placa:IsShown() then placa:Hide() end end)
A.RegisterEvent("UNIT_AURA", function()
	if placa and placa:IsShown() then N.Una("curacion.listosPintar", 0.4, function() Li.Pintar() end, { fueraDeCombate = true }) end
end)
A.RegisterEvent("BAG_UPDATE_DELAYED", function()
	if placa and placa:IsShown() then N.Una("curacion.listosPintar", 0.4, function() Li.Pintar() end, { fueraDeCombate = true }) end
end)
