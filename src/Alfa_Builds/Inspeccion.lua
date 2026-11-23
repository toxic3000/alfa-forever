-- Alfa - Talentos: ver el equipo de un compañero (1.3.7, toxic3000 / La Jauría). GPL-3.0.
--
-- En el clic derecho de otro jugador (su retrato, tu objetivo, tu foco, tu
-- grupo, tu banda) sale «Ver su equipo (Alfa)». Ese clic le pide su equipo
-- al juego (NotifyInspect) y, cuando llega (INSPECT_READY), Alfa pone una
-- placa chica (junto a la inspección del juego si la abriste tú con su
-- «Inspeccionar»; 1.3.7: Alfa ya no la abre desde su menú) con:
--   * su nivel de objeto medio;
--   * sus piezas flojas (las de menos nivel y las ranuras vacías);
--   * si algo de tus bolsas le sirve (sin ligar, de su tipo de armadura y
--     con más nivel que lo que trae en esa ranura): para regalárselo.
-- Nada se manda al chat ni a nadie.
--
-- API (referencia/.../PlayerScriptDocumentation.lua): CanInspect y
-- NotifyInspect no tienen restricciones (solo SecretArguments
-- "AllowedWhenUntainted"); InspectUnit (la del menú del juego) no se llama
-- desde el menú de Alfa (camino contaminado). Fuera de combate y no en la
-- interfaz de mando. GetInventoryItemLink(unidad, ranura) después de
-- INSPECT_READY; nivel con C_Item.GetDetailedItemLevelInfo (o el de
-- C_Item.GetItemInfo). Lo secreto (en mazmorras) no se lee.

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local K = N.Kit

local type, ipairs, pairs, floor, format, min, max = type, ipairs, pairs, math.floor, string.format, math.min, math.max

local In = {}
M.Inspeccion = In

local function secreto(v) return type(v) ~= "nil" and issecretvalue ~= nil and issecretvalue(v) and true or false end
local function leer(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, v = pcall(fn, ...)
	if not ok or secreto(v) then return nil end
	return v
end
local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end

-- Las ranuras que cuentan (sin camisa ni tabardo) y su nombre.
In.RANURAS = {
	{ 1, "Cabeza" }, { 2, "Cuello" }, { 3, "Hombros" }, { 15, "Espalda" }, { 5, "Pecho" }, { 9, "Muñecas" },
	{ 10, "Manos" }, { 6, "Cintura" }, { 7, "Piernas" }, { 8, "Pies" }, { 11, "Anillo" }, { 12, "Anillo" },
	{ 13, "Abalorio" }, { 14, "Abalorio" }, { 16, "Mano principal" }, { 17, "Mano secundaria" }, { 18, "A distancia" },
}
-- equipLoc -> ranuras donde va
In.DONDE = {
	INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CLOAK = { 15 },
	INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
	INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_FINGER = { 11, 12 },
	INVTYPE_TRINKET = { 13, 14 }, INVTYPE_WEAPON = { 16 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 },
	INVTYPE_SHIELD = { 17 }, INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_HOLDABLE = { 17 },
	INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}
-- La armadura más pesada de cada clase (subclase de armadura: 1 tela, 2 cuero,
-- 3 malla, 4 placas), con el nivel desde el que la usa (el juego clásico).
In.ARMADURA = {
	WARRIOR = { 3, 4, 40 }, PALADIN = { 3, 4, 40 }, HUNTER = { 2, 3, 40 }, SHAMAN = { 2, 3, 40 },
	ROGUE = { 2 }, DRUID = { 2 }, PRIEST = { 1 }, MAGE = { 1 }, WARLOCK = { 1 },
}

local function nivelDe(link)
	if type(link) ~= "string" then return nil end
	local CI = C_Item
	if CI and CI.GetDetailedItemLevelInfo then
		local n = leer(CI.GetDetailedItemLevelInfo, link)
		if type(n) == "number" and n > 0 then return n end
	end
	local get = (CI and CI.GetItemInfo) or rawget(_G, "GetItemInfo")
	if type(get) == "function" then
		local ok, _, _, _, n = pcall(get, link)
		if ok and type(n) == "number" and n > 0 then return n end
	end
	return nil
end

local function infoDe(link)
	local get = (C_Item and C_Item.GetItemInfo) or rawget(_G, "GetItemInfo")
	if type(get) ~= "function" then return nil end
	local ok, nombre, enlace, calidad, nivel, _, _, _, _, equipLoc, _, _, clase, subclase, ligado = pcall(get, link)
	if not ok or type(nombre) ~= "string" then return nil end
	return { nombre = nombre, link = enlace or link, calidad = calidad, nivel = nivel, equipLoc = equipLoc, clase = clase, subclase = subclase, ligado = ligado }
end

-- ¿Esa armadura la puede usar su clase (a su nivel)?
function In.ArmaduraValida(claseJugador, nivelJugador, info)
	if not info or info.clase ~= 4 then return true end -- no es armadura: armas, anillos...
	local sub = info.subclase
	if sub == nil or sub == 0 or sub > 4 then return true end -- varios, escudos, reliquias
	local a = In.ARMADURA[claseJugador or ""]
	if not a then return true end
	local tope = a[1]
	if a[2] and (nivelJugador or 0) >= (a[3] or 40) then tope = a[2] end
	return sub <= tope
end

-- Lo que trae puesto: { [ranura] = { link, nivel } } , medio, flojas, vacias
function In.Leer(unidad)
	local puesto = {}
	local suma, n = 0, 0
	local dosManos = false
	for _, r in ipairs(In.RANURAS) do
		local slot = r[1]
		local link = leer(GetInventoryItemLink, unidad, slot)
		if type(link) == "string" then
			local nv = nivelDe(link)
			puesto[slot] = { link = link, nivel = nv }
			if nv then suma, n = suma + nv, n + 1 end
			if slot == 16 then
				local inf = infoDe(link)
				dosManos = inf and inf.equipLoc == "INVTYPE_2HWEAPON" or false
			end
		end
	end
	-- Con un arma de dos manos, la secundaria vacía no cuenta como floja (y el arma vale por dos).
	if dosManos and puesto[16] and puesto[16].nivel and not puesto[17] then
		suma, n = suma + puesto[16].nivel, n + 1
	end
	local medio = n > 0 and suma / n or nil
	local flojas, vacias = {}, {}
	for _, r in ipairs(In.RANURAS) do
		local slot = r[1]
		local p = puesto[slot]
		if not p then
			if not (slot == 17 and dosManos) and slot ~= 18 then vacias[#vacias + 1] = r[2] end
		elseif p.nivel and medio and p.nivel < medio - 5 then
			flojas[#flojas + 1] = { slot = slot, nombre = r[2], nivel = p.nivel }
		end
	end
	table.sort(flojas, function(a, b) return a.nivel < b.nivel end)
	return puesto, medio, flojas, vacias, dosManos
end

-- Lo de tus bolsas que le sirve: { { link, nivel, ranura, mejora } }
function In.LeSirve(unidad, puesto)
	local out = {}
	local C = C_Container
	if not (C and C.GetContainerNumSlots and C.GetContainerItemInfo) then return out end
	local okC, _, claseJ = pcall(UnitClass, unidad)
	if not okC or secreto(claseJ) then claseJ = nil end
	local nivelJ = leer(UnitLevel, unidad)
	for bolsa = 0, 4 do
		local s = leer(C.GetContainerNumSlots, bolsa) or 0
		for i = 1, s do
			local ci = leer(C.GetContainerItemInfo, bolsa, i)
			if type(ci) == "table" and ci.hyperlink and ci.isBound ~= true then
				local info = infoDe(ci.hyperlink)
				local donde = info and In.DONDE[info.equipLoc or ""]
				local pide = info and type(info.nivel) == "number" and info.nivel or nil
				if donde and (info.calidad or 0) >= 2 and In.ArmaduraValida(claseJ, nivelJ, info) then
					local nv = nivelDe(ci.hyperlink) or pide
					-- Contra la peor de sus ranuras para ese tipo.
					local peor, ranura
					for _, slot in ipairs(donde) do
						local p = puesto[slot]
						local suyo = p and p.nivel or 0
						if not peor or suyo < peor then peor, ranura = suyo, slot end
					end
					if nv and peor and nv > peor + 2 then
						out[#out + 1] = { link = ci.hyperlink, nivel = nv, ranura = ranura, mejora = nv - peor }
					end
				end
			end
		end
	end
	table.sort(out, function(a, b) return a.mejora > b.mejora end)
	return out
end

local function nombreRanura(slot)
	for _, r in ipairs(In.RANURAS) do if r[1] == slot then return L[r[2]] end end
	return "?"
end

---------------------------------------------------------------------------
-- La placa junto a la inspección
---------------------------------------------------------------------------

local ANCHO = 260
local placa, pedido -- pedido = { unidad, guid, nombre, t }

local function armar()
	if placa then return placa end
	placa = CreateFrame("Frame", "AlfaBuildsInspeccion", K.Raiz())
	placa:SetWidth(ANCHO)
	placa:SetFrameStrata("HIGH")
	placa.caja = K.Caja(placa, { fondo = "fondo", borde = "linea", corte = K.CORTE.panel })
	placa.Marca = K.Marca(placa, K.CORTE.panel, "acento")
	placa.Titulo = K.Texto(placa, "encabezado", "texto")
	placa.Titulo:SetPoint("TOPLEFT", placa, "TOPLEFT", K.ESP.m, -K.ESP.m)
	placa.Cerrar = K.BotonIcono(placa, "ic-cerrar", function() placa:Hide() end, { tam = 22, ayuda = L["Cerrar"] })
	placa.Cerrar:SetPoint("TOPRIGHT", placa, "TOPRIGHT", -K.ESP.s, -K.ESP.s)
	placa.Texto = K.Texto(placa, "pequeno", "texto")
	placa.Texto:SetPoint("TOPLEFT", placa.Titulo, "BOTTOMLEFT", 0, -K.ESP.s)
	placa.Texto:SetJustifyH("LEFT")
	placa:Hide()
	return placa
end

-- Las líneas de la placa (también para las pruebas). -> titulo, lineas
function In.Resumen(unidad)
	local puesto, medio, flojas, vacias = In.Leer(unidad)
	local lineas = {}
	if medio then
		lineas[#lineas + 1] = format(L["Nivel de objeto medio: %d"], floor(medio + 0.5))
	else
		lineas[#lineas + 1] = L["No se pudo leer su equipo."]
	end
	local f = {}
	for i = 1, min(3, #flojas) do f[#f + 1] = format(L["%s (%d)"], L[flojas[i].nombre], flojas[i].nivel) end
	for i = 1, min(3, #vacias) do f[#f + 1] = format(L["%s (vacío)"], L[vacias[i]]) end
	if #f > 0 then
		lineas[#lineas + 1] = L["Piezas flojas:"] .. " " .. table.concat(f, ", ")
	elseif medio then
		lineas[#lineas + 1] = L["Su equipo va parejo: ninguna pieza floja."]
	end
	local sirve = In.LeSirve(unidad, puesto)
	if #sirve > 0 then
		lineas[#lineas + 1] = L["De tus bolsas le sirve:"]
		for i = 1, min(3, #sirve) do
			local s = sirve[i]
			lineas[#lineas + 1] = "  " .. s.link .. " " .. format(L["(+%d en %s)"], s.mejora, nombreRanura(s.ranura))
		end
	end
	local nombre = leer(UnitName, unidad) or "?"
	return format(L["El equipo de %s"], nombre), lineas
end

function In.Pintar(unidad)
	local p = armar()
	local titulo, lineas = In.Resumen(unidad)
	K.Escribir(p.Titulo, titulo)
	K.Parrafo(p.Texto, ANCHO - 2 * K.ESP.m, 12)
	K.Escribir(p.Texto, table.concat(lineas, "\n"))
	local alto = K.ESP.m + 18 + K.ESP.s + K.AltoTexto(p.Texto) + K.ESP.m
	p:SetHeight(floor(alto + 0.5))
	p:ClearAllPoints()
	local f = rawget(_G, "InspectFrame")
	-- 1.3.7: al cerrar la inspección del juego, la placa se va con ella.
	if type(f) == "table" and type(f.HookScript) == "function" and not f.alfaPlacaGancho then
		f.alfaPlacaGancho = true
		f:HookScript("OnHide", function() if placa and placa.alfaJunto then placa:Hide() end end)
	end
	p.alfaJunto = nil
	if type(f) == "table" and type(f.IsShown) == "function" and f:IsShown() then
		p.alfaJunto = true
		p:SetPoint("TOPLEFT", f, "TOPRIGHT", 4, -24)
	else
		p:SetPoint("LEFT", UIParent, "LEFT", 380, 80)
	end
	p:Show()
	return p
end

-- El clic del menú: le pide su equipo al juego (sin abrir su ventana).
function In.Ver(unidad)
	if enCombate() then
		N.Imprimir(L["Se puede al salir de combate."])
		return false
	end
	if type(unidad) ~= "string" or not leer(UnitIsPlayer, unidad) then return false end
	if leer(CanInspect, unidad) == false then
		N.Imprimir(L["Está muy lejos para ver su equipo. Acércate un poco."])
		return false
	end
	pedido = { unidad = unidad, guid = leer(UnitGUID, unidad), t = GetTime and GetTime() or 0 }
	local pedir = rawget(_G, "NotifyInspect")
	if type(pedir) ~= "function" then pedido = nil return false end
	pcall(pedir, unidad)
	return true
end

function In.Pedido() return pedido end
function In.Placa() return placa end

A.RegisterEvent("INSPECT_READY", function(_, guid)
	local p = pedido
	if not p then return end
	if p.guid and guid and not secreto(guid) and guid ~= p.guid then return end
	pedido = nil
	-- La ventana del juego llega un instante después: se pinta en el siguiente cuadro.
	N.Una("builds.inspeccion", 0.1, function() pcall(In.Pintar, p.unidad) end, { fueraDeCombate = true })
end)
A.RegisterEvent("PLAYER_REGEN_DISABLED", function() if placa then placa:Hide() end end)

---------------------------------------------------------------------------
-- El menú del clic derecho
---------------------------------------------------------------------------

In.MENUS = { "MENU_UNIT_PLAYER", "MENU_UNIT_FOCUS", "MENU_UNIT_PARTY", "MENU_UNIT_RAID_PLAYER", "MENU_UNIT_RAID", "MENU_UNIT_TARGET" }

function In.Armar(raiz, contexto)
	if N.Get(M.ID, "inspeccion") == false or enCombate() then return end
	if type(raiz) ~= "table" or type(raiz.CreateButton) ~= "function" or type(contexto) ~= "table" then return end
	local unidad = contexto.unit
	if secreto(unidad) or type(unidad) ~= "string" then return end
	if not leer(UnitIsPlayer, unidad) or leer(UnitIsUnit, unidad, "player") then return end
	if raiz.CreateDivider then raiz:CreateDivider() end
	raiz:CreateButton(L["Ver su equipo (Alfa)"], function() In.Ver(unidad) end)
end

local enganchado = false
function In.Enganchar()
	if enganchado then return end
	if A.GamepadUI and A.GamepadUI() then return end
	if not (Menu and type(Menu.ModifyMenu) == "function") then return end
	enganchado = true
	for _, etiqueta in ipairs(In.MENUS) do
		Menu.ModifyMenu(etiqueta, function(_, raiz, contexto) pcall(In.Armar, raiz, contexto) end)
	end
end
A.OnLogin(In.Enganchar)
