-- Alfa - Paisaje y gráficos: los filtros que dibuja Alfa (toxic3000 / La Jauría). GPL-3.0.
--
-- Viñeta, grano de película, barras de cine y tintes de color. No tocan
-- ninguna variable del juego: son texturas a pantalla completa dentro de un
-- marco hijo de WorldFrame (el mundo 3D), en la capa más baja. Así quedan
-- encima del paisaje pero DETRÁS de toda la interfaz, nunca la tapan, no
-- toman el ratón y también se ven con la interfaz oculta (Alt+Z), para las
-- capturas.
--   * Nada se crea hasta que enciendes un filtro.
--   * El grano se mueve con un OnUpdate que solo corre mientras el grano está
--     a la vista (y cambia unas 14 veces por segundo, no en cada cuadro).
--   * Las barras de cine solo cambian cómo se ve: no dan más FPS.
-- Ajustes: vista.vineta, vinetaFuerza, grano, granoFuerza, granoMover,
-- barras, barrasAlto, tinte, tinteFuerza.

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local ID = M.ID

local F = {}
M.Filtros = F

local MEDIA = "Interface\\AddOns\\Alfa_Vista\\Media\\"
local BLANCO = "Interface\\Buttons\\WHITE8X8"
local TAM_GRANO = 256

-- Los tintes: multiplicar el mundo por un color y, en algunos, un velo
-- encima. Los mismos números dibujan sus miniaturas (Media/tinte-*.tga).
M.TINTES = {
	{ id = "ninguno", nombre = L["Sin tinte"], mul = { 1, 1, 1 } },
	{ id = "sepia", nombre = L["Sepia"], mul = { 1, 0.86, 0.66 }, velo = { 0.44, 0.31, 0.18, 0.22 } },
	{ id = "calido", nombre = L["Cálido"], mul = { 1, 0.9, 0.76 } },
	{ id = "frio", nombre = L["Frío"], mul = { 0.8, 0.9, 1 } },
	{ id = "noche", nombre = L["Noche"], mul = { 0.5, 0.58, 0.82 } },
	{ id = "esmeralda", nombre = L["Esmeralda"], mul = { 0.72, 1, 0.56 } },
	{ id = "atardecer", nombre = L["Atardecer"], mul = { 1, 0.78, 0.62 }, velo = { 0.9, 0.35, 0.25, 0.12 } },
}
M.TINTE = {}
for _, t in ipairs(M.TINTES) do
	t.miniatura = MEDIA .. "tinte-" .. t.id
	M.TINTE[t.id] = t
end

local function get(k) return N.Get(ID, k) end
local function num(k, d) local v = tonumber(get(k)) return v or d end

local raiz, tinte, velo, vineta, grano, arriba, abajo

local function crear()
	if raiz then return end
	local mundo = WorldFrame or UIParent
	raiz = CreateFrame("Frame", "AlfaVistaFiltros", mundo)
	raiz:SetAllPoints(mundo)
	raiz:SetFrameStrata("BACKGROUND")
	raiz:SetFrameLevel(0)
	raiz:EnableMouse(false)
	if raiz.EnableMouseWheel then raiz:EnableMouseWheel(false) end

	tinte = raiz:CreateTexture(nil, "BACKGROUND", nil, 0)
	tinte:SetTexture(BLANCO)
	tinte:SetBlendMode("MOD")
	tinte:SetAllPoints(raiz)

	velo = raiz:CreateTexture(nil, "BACKGROUND", nil, 1)
	velo:SetColorTexture(1, 1, 1, 1)
	velo:SetBlendMode("BLEND")
	velo:SetAllPoints(raiz)

	vineta = raiz:CreateTexture(nil, "BORDER")
	vineta:SetTexture(MEDIA .. "vineta")
	vineta:SetAllPoints(raiz)

	grano = raiz:CreateTexture(nil, "ARTWORK")
	grano:SetTexture(MEDIA .. "grano", "REPEAT", "REPEAT")
	grano:SetAllPoints(raiz)

	arriba = raiz:CreateTexture(nil, "OVERLAY")
	arriba:SetColorTexture(0, 0, 0, 1)
	arriba:SetPoint("TOPLEFT", raiz, "TOPLEFT", 0, 0)
	arriba:SetPoint("TOPRIGHT", raiz, "TOPRIGHT", 0, 0)
	abajo = raiz:CreateTexture(nil, "OVERLAY")
	abajo:SetColorTexture(0, 0, 0, 1)
	abajo:SetPoint("BOTTOMLEFT", raiz, "BOTTOMLEFT", 0, 0)
	abajo:SetPoint("BOTTOMRIGHT", raiz, "BOTTOMRIGHT", 0, 0)

	raiz:SetScript("OnSizeChanged", function() F.Aplicar() end)
end

-- El grano cubre la pantalla repitiendo su textura; moverlo es solo correr
-- sus coordenadas a un lugar al azar.
local function coordenadasGrano(dx, dy)
	local w = tonumber(raiz:GetWidth()) or 1024
	local h = tonumber(raiz:GetHeight()) or 768
	grano:SetTexCoord(dx, dx + w / TAM_GRANO, dy, dy + h / TAM_GRANO)
end

local acumulado = 0
local function moverGrano(_, dt)
	acumulado = acumulado + (dt or 0)
	if acumulado < 0.07 then return end
	acumulado = 0
	coordenadasGrano(math.random(), math.random())
end

function F.Activos()
	return get("vineta") == true or get("grano") == true or get("barras") == true
		or (M.TINTE[get("tinte")] and get("tinte") ~= "ninguno")
end

function F.Aplicar()
	if not F.Activos() then
		if raiz then
			raiz:SetScript("OnUpdate", nil)
			raiz:Hide()
		end
		return
	end
	crear()
	-- Tinte
	local t = M.TINTE[get("tinte")] or M.TINTE.ninguno
	local fuerza = math.max(0, math.min(1, num("tinteFuerza", 0.5)))
	local hayTinte = t.id ~= "ninguno" and fuerza > 0
	tinte:SetShown(hayTinte)
	velo:SetShown(hayTinte and t.velo ~= nil)
	if hayTinte then
		local m = t.mul
		tinte:SetVertexColor(1 - (1 - m[1]) * fuerza, 1 - (1 - m[2]) * fuerza, 1 - (1 - m[3]) * fuerza, 1)
		if t.velo then velo:SetVertexColor(t.velo[1], t.velo[2], t.velo[3], t.velo[4] * fuerza) end
	end
	-- Viñeta
	local hayVineta = get("vineta") == true
	vineta:SetShown(hayVineta)
	if hayVineta then vineta:SetAlpha(math.max(0, math.min(1, num("vinetaFuerza", 0.45)))) end
	-- Grano
	local hayGrano = get("grano") == true
	grano:SetShown(hayGrano)
	if hayGrano then
		grano:SetAlpha(math.max(0, math.min(1, num("granoFuerza", 0.4))) * 0.35)
		coordenadasGrano(0, 0)
	end
	raiz:SetScript("OnUpdate", (hayGrano and get("granoMover") ~= false) and moverGrano or nil)
	-- Barras de cine
	local hayBarras = get("barras") == true
	arriba:SetShown(hayBarras)
	abajo:SetShown(hayBarras)
	if hayBarras then
		local alto = (tonumber(raiz:GetHeight()) or 768) * math.max(0.02, math.min(0.2, num("barrasAlto", 0.1)))
		arriba:SetHeight(alto)
		abajo:SetHeight(alto)
	end
	raiz:Show()
end

-- Apagar todos los filtros de un clic.
function F.Quitar()
	for _, k in ipairs({ "vineta", "grano", "barras" }) do N.Set(ID, k, false) end
	N.Set(ID, "tinte", "ninguno")
end

A.On("SETTING_CHANGED", function(path)
	if type(path) ~= "string" then return end
	if path == "" or path == ID or path:sub(1, #ID + 1) == ID .. "." then F.Aplicar() end
end)
A.RegisterEvent("PLAYER_ENTERING_WORLD", function() F.Aplicar() end)
