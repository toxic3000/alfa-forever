-- Alfa - Bolsas: el nivel de objeto y la durabilidad sobre cada ranura de tu
-- personaje y de la inspección (toxic3000 / La Jauría). GPL-3.0. 1.3.7.
--
-- En la ventana de tu personaje (CharacterHeadSlot...) y en la de inspección
-- (InspectHeadSlot..., Blizzard_InspectUI se carga cuando hace falta): abajo
-- de cada pieza su nivel de objeto, del color de su calidad; arriba, solo si
-- se está gastando, lo que le queda («62 %»: amarillo, naranja, rojo). La
-- durabilidad de otro no se puede leer: en la inspección, solo el nivel.
-- Solo si el cliente da el nivel de objeto (C_Item.GetDetailedItemLevelInfo o
-- GetDetailedItemLevelInfo, ItemDocumentation.lua): si no, no se pinta nada.
-- Ligero: se rehace al abrir la ventana y al cambiar el equipo o la
-- durabilidad, solo con la ventana a la vista. Son textos sobre los botones
-- del juego (no atrapan clics). Ajuste bolsas.nivelPersonaje (de fábrica, encendido).
--   Ra.Nivel(link) -> nivel | nil ; Ra.Pintar("player" | unidad) ; Ra.Texto(boton) -> nivel, durabilidad

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L

local type, ipairs, tonumber, floor, format = type, ipairs, tonumber, math.floor, string.format

local Ra = {}
M.Ranuras = Ra

Ra.RANURAS = {
	{ 1, "HeadSlot" }, { 2, "NeckSlot" }, { 3, "ShoulderSlot" }, { 15, "BackSlot" }, { 5, "ChestSlot" },
	{ 9, "WristSlot" }, { 10, "HandsSlot" }, { 6, "WaistSlot" }, { 7, "LegsSlot" }, { 8, "FeetSlot" },
	{ 11, "Finger0Slot" }, { 12, "Finger1Slot" }, { 13, "Trinket0Slot" }, { 14, "Trinket1Slot" },
	{ 16, "MainHandSlot" }, { 17, "SecondaryHandSlot" }, { 18, "RangedSlot" },
}

local function encendido() return M.Get("nivelPersonaje") ~= false end

-- ¿El cliente da el nivel de objeto?
local function funcionNivel()
	local CI = rawget(_G, "C_Item")
	local f = type(CI) == "table" and CI.GetDetailedItemLevelInfo
	if type(f) == "function" then return f end
	f = rawget(_G, "GetDetailedItemLevelInfo")
	return type(f) == "function" and f or nil
end
function Ra.Disponible() return funcionNivel() ~= nil end

function Ra.Nivel(link)
	if type(link) ~= "string" then return nil end
	local O = M.Objetos
	local n = O and O.Nivel and O.Nivel(link)
	if n then return n end
	local f = funcionNivel()
	n = f and M.Num(M.Llamar(f, link))
	return (n and n > 0) and floor(n) or nil
end

local function fuente(fs, tam)
	local ruta = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
	if not pcall(fs.SetFont, fs, ruta, tam, "OUTLINE") or not fs:GetFont() then
		pcall(fs.SetFont, fs, "Fonts\\FRIZQT__.TTF", tam, "OUTLINE")
	end
end

-- Los dos textos de una ranura (se crean la primera vez).
local function capa(b)
	local c = b.alfaRanura
	if c then return c end
	c = {}
	c.Nivel = b:CreateFontString(nil, "OVERLAY")
	fuente(c.Nivel, 12)
	c.Nivel:SetPoint("BOTTOM", b, "BOTTOM", 0, 2)
	c.Dura = b:CreateFontString(nil, "OVERLAY")
	fuente(c.Dura, 10)
	c.Dura:SetPoint("TOP", b, "TOP", 0, -2)
	b.alfaRanura = c
	return c
end

local function colorDura(p)
	if p >= 50 then return 1, 0.82, 0.2 end
	if p >= 25 then return 1, 0.5, 0.1 end
	return 1, 0.2, 0.2
end

local function durabilidad(ranura)
	if type(GetInventoryItemDurability) ~= "function" then return nil end
	local cur, mx = M.Llamar(GetInventoryItemDurability, ranura)
	cur, mx = M.Num(cur), M.Num(mx)
	if not (cur and mx and mx > 0) then return nil end
	return floor(cur * 100 / mx + 0.5)
end

local function limpiar(prefijo)
	for _, x in ipairs(Ra.RANURAS) do
		local b = rawget(_G, prefijo .. x[2])
		local c = type(b) == "table" and b.alfaRanura
		if c then
			c.Nivel:SetText("")
			c.Dura:SetText("")
			c.Nivel:Hide()
			c.Dura:Hide()
		end
	end
end

-- unidad: "player" (tu personaje) u otra (la inspección). -> cuántas ranuras se pintaron
function Ra.Pintar(unidad)
	local prefijo = unidad == "player" and "Character" or "Inspect"
	if not (encendido() and Ra.Disponible()) then
		limpiar(prefijo)
		return 0
	end
	local hechas = 0
	for _, x in ipairs(Ra.RANURAS) do
		local b = rawget(_G, prefijo .. x[2])
		if type(b) == "table" and b.CreateFontString then
			local c = capa(b)
			local link = GetInventoryItemLink and M.Texto(M.Llamar(GetInventoryItemLink, unidad, x[1]))
			local nivel = link and Ra.Nivel(link)
			if nivel then
				local q = GetInventoryItemQuality and M.Num(M.Llamar(GetInventoryItemQuality, unidad, x[1]))
				local K = N.Kit
				local r, g, bb = K and K.ColorDeCalidad and K.ColorDeCalidad(q)
				c.Nivel:SetText(tostring(nivel))
				c.Nivel:SetTextColor(r or 1, g or 1, bb or 1)
				c.Nivel:Show()
				hechas = hechas + 1
			else
				c.Nivel:SetText("")
				c.Nivel:Hide()
			end
			local p = unidad == "player" and link and durabilidad(x[1]) or nil
			if p and p < 100 then
				c.Dura:SetText(format("%d%%", p))
				c.Dura:SetTextColor(colorDura(p))
				c.Dura:Show()
			else
				c.Dura:SetText("")
				c.Dura:Hide()
			end
		end
	end
	return hechas
end

-- Lo que dice una ranura (para la prueba): -> nivel, durabilidad (textos)
function Ra.Texto(b)
	local c = type(b) == "table" and b.alfaRanura
	if not c then return nil end
	local n, d = c.Nivel:GetText(), c.Dura:GetText()
	return (n ~= "" and n) or nil, (d ~= "" and d) or nil
end

local function visible(nombre)
	local f = rawget(_G, nombre)
	return type(f) == "table" and f.IsShown and f:IsShown() and f or nil
end

local function tuyo()
	if visible("CharacterFrame") then Ra.Pintar("player") end
end

local function inspeccion()
	local f = visible("InspectFrame")
	if not f then return end
	local u = f.unit
	if type(u) ~= "string" or (issecretvalue and issecretvalue(u)) then u = "target" end
	Ra.Pintar(u)
end

-- Un cambio que llega en ráfaga (varias piezas a la vez): una sola vez.
local function luego(clave, fn)
	if N.Una then N.Una(clave, 0.1, fn) else fn() end
end

local enganchados = {}
local function enganchar(nombre, fn)
	if enganchados[nombre] then return end
	local f = rawget(_G, nombre)
	if type(f) ~= "table" or not f.HookScript then return end
	enganchados[nombre] = true
	f:HookScript("OnShow", function() luego("bolsas.ranuras." .. nombre, fn) end)
end

local function engancharTodo()
	enganchar("CharacterFrame", tuyo)
	enganchar("PaperDollFrame", tuyo)
	enganchar("InspectFrame", inspeccion)
end

A.RegisterEvent("PLAYER_LOGIN", engancharTodo)
A.RegisterEvent("ADDON_LOADED", function(_, nombre)
	if nombre == "Blizzard_InspectUI" then engancharTodo() end
end)
A.RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function() if visible("CharacterFrame") then luego("bolsas.ranuras.tuyo", tuyo) end end)
A.RegisterEvent("UPDATE_INVENTORY_DURABILITY", function() if visible("CharacterFrame") then luego("bolsas.ranuras.tuyo", tuyo) end end)
A.RegisterEvent("INSPECT_READY", function() luego("bolsas.ranuras.inspeccion", inspeccion) end)
A.On("SETTING_CHANGED", function(ruta)
	if ruta == M.ID .. ".nivelPersonaje" or ruta == "" or ruta == M.ID then
		tuyo()
		inspeccion()
	end
end)
