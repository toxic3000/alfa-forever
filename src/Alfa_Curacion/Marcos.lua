-- Alfa - Curación: los marcos de grupo y banda (toxic3000 / La Jauría). GPL-3.0.
--
-- Una cabecera segura (SecureGroupHeaderTemplate) arma un botón seguro
-- (SecureUnitButtonTemplate) por compañero: tú y tu grupo, o tu banda de
-- hasta 40. La cabecera reordena y cambia de unidad sola, también en combate.
-- Los 40 botones se crean de una vez fuera de combate (startingIndex), así
-- ninguno nace en una pelea; si alguno naciera, initialConfigFunction le da
-- su tamaño y sus clics (Mapa.lua) desde el entorno seguro.
--
-- Lo que se ve (barras, textos, bordes) son marcos normales dentro de cada
-- botón y se pintan por eventos de unidad. Con valores secretos (combate,
-- mazmorras) nada se compara ni se suma:
--   * Vida y curas entrantes van directo a StatusBar:SetMinMaxValues/SetValue.
--     Las entrantes son una segunda barra pegada al final de la vida.
--   * El alcance (UnitInRange, siempre secreto) va con SetAlphaFromBoolean.
--   * El objetivo, si UnitIsUnit llega secreto, también con SetAlphaFromBoolean.
--   * Los perjuicios que puedes quitar: C_UnitAuras.GetUnitAuraInstanceIDs con
--     el filtro "HARMFUL|RAID" (los que tú puedes disipar, AuraUtil de
--     Forever) y su color con C_UnitAuras.GetAuraDispelTypeColor y una curva.
--   * Rol, amenaza y estado (muerto, desconectado) solo si llegan legibles; el
--     rol secreto usa UnitFrameUtil.UpdateUnitFrameRoleIcon, la vía de Blizzard.
-- Nada decide a quién curar: eso lo decide tu clic.
--
-- 1.3.0:
--   * El tipo de perjuicio (magia, maldición, veneno, enfermedad) con su ícono
--     arriba a la derecha, si tu clase lo quita; si ningún clic lo quita, un
--     aviso en tu chat (una vez por tipo y sesión).
--   * Un punto azul abajo a la derecha si le falta el buff de tu clase (solo
--     fuera de combate, que es cuando se reparten).
--   * El marco del tanque late en rojo bajo el 40 % de vida (con una curva de
--     color: la vida secreta nunca se compara).
--   * En banda, un marco por grupo (8 cabeceras con groupFilter), y la de
--     siempre se oculta con un controlador de estado ([group:raid]).

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local T = A.Theme
local L = M.L
local ID = M.ID
local secreto = M.Secreto

local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min

M.AJUSTES = {
	activo = true,           -- usar los marcos de Alfa
	solo = false,            -- verte a ti estando solo
	ocultarBlizzard = true,  -- ocultar los marcos de grupo de Blizzard
	ancho = 88,
	alto = 36,
	porColumna = 5,          -- miembros por columna (o por fila)
	crecer = "abajo",        -- "abajo" | "derecha"
	orden = "grupo",         -- "grupo" | "rol" | "clase" | "nombre"
	colorClase = true,
	entrantes = true,        -- curas que van llegando
	amenaza = true,
	disipar = true,          -- perjuicios que puedes quitar
	porcentaje = false,      -- porcentaje de vida
	alcance = true,          -- atenuar a quien está lejos
	descripcion = true,      -- cuadro del jugador al pasar el ratón (fuera de combate)
	-- 1.3.0
	tipoPerjuicio = true,    -- el ícono del tipo de perjuicio que puedes quitar
	buffs = true,            -- punto si le falta el buff de tu clase
	tanque = true,           -- el tanque late bajo el 40 %
	mana = true,             -- el maná de los curanderos del grupo
	porGrupos = true,        -- en banda, una columna (o fila) por grupo
}

local function opt(k) return N.Get(ID, k) end

local BLANCO = "Interface\\Buttons\\WHITE8x8"
local ROLES_TEX = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"
local ROLES = {
	TANK = { 0, 19 / 64, 22 / 64, 41 / 64 },
	HEALER = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 },
	DAMAGER = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 },
}
local VERDE = { 0.545, 0.878, 0.306 } -- #8be04e, el verde de Alfa
local GRIS = { 0.36, 0.37, 0.4 }
local DISIPAR = { 0.72, 0.38, 1 }     -- si el juego no da el color del perjuicio
local AMENAZA = { 1, 0.24, 0.2 }
local FUERA = 0.4                      -- opacidad de quien está fuera de alcance
local MAX = 40
local ESPACIO = 3
local TOPE_ALCANCE = 8                 -- botones revisados por vuelta del temporizador
local UMBRAL_TANQUE = 0.4              -- el tanque late por debajo de esto
local ROJO = { 1, 0.22, 0.2 }
local AZUL_BUFF = { 0.35, 0.75, 1 }
local GRUPOS = 8
local CADA_ALCANCE = 0.5

local porUnidad = {}                   -- "raid3" -> botón
M.porUnidad = porUnidad

---------------------------------------------------------------------------
-- Curvas: color del perjuicio (tipo de disipación -> color) y porcentaje
---------------------------------------------------------------------------

local curvaDisipar, curvaPorcentaje
do
	local CU = C_CurveUtil
	if CU and CU.CreateColorCurve and CreateColor then
		local ok, c = pcall(CU.CreateColorCurve)
		if ok and c then
			local bien = pcall(function()
				if c.SetType and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step then c:SetType(Enum.LuaCurveType.Step) end
				c:AddPoint(0, CreateColor(DISIPAR[1], DISIPAR[2], DISIPAR[3], 1))
				c:AddPoint(1, CreateColor(0.2, 0.6, 1, 1))    -- magia
				c:AddPoint(2, CreateColor(0.6, 0, 1, 1))      -- maldición
				c:AddPoint(3, CreateColor(0.6, 0.4, 0, 1))    -- enfermedad
				c:AddPoint(4, CreateColor(0, 0.6, 0, 1))      -- veneno
			end)
			if bien then curvaDisipar = c end
		end
	end
	-- 1.3.0: el tanque bajo el 40 %: rojo opaco abajo del umbral, transparente arriba.
	if CU and CU.CreateColorCurve and CreateColor then
		local ok, c = pcall(CU.CreateColorCurve)
		if ok and c then
			local bien = pcall(function()
				if c.SetType and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step then c:SetType(Enum.LuaCurveType.Step) end
				c:AddPoint(0, CreateColor(ROJO[1], ROJO[2], ROJO[3], 1))
				c:AddPoint(UMBRAL_TANQUE, CreateColor(ROJO[1], ROJO[2], ROJO[3], 0))
			end)
			if bien then M.curvaTanque = c end
		end
	end
	if CU and CU.CreateCurve then
		local ok, c = pcall(CU.CreateCurve)
		if ok and c and pcall(function() c:AddPoint(0, 0); c:AddPoint(1, 100) end) then curvaPorcentaje = c end
	end
end

---------------------------------------------------------------------------
-- Lo que se ve de un compañero (también en los marcos de prueba)
---------------------------------------------------------------------------

local function textura(padre, capa, sub)
	local t = padre:CreateTexture(nil, capa or "ARTWORK", nil, sub)
	t:SetTexture(BLANCO)
	return t
end

-- Cuatro texturas de `g` px por dentro del marco.
local function borde(padre, g, capa)
	local e = {}
	for i = 1, 4 do e[i] = textura(padre, capa or "OVERLAY") end
	e[1]:SetPoint("TOPLEFT", padre, "TOPLEFT", 0, 0)
	e[1]:SetPoint("TOPRIGHT", padre, "TOPRIGHT", 0, 0)
	e[1]:SetHeight(g)
	e[2]:SetPoint("BOTTOMLEFT", padre, "BOTTOMLEFT", 0, 0)
	e[2]:SetPoint("BOTTOMRIGHT", padre, "BOTTOMRIGHT", 0, 0)
	e[2]:SetHeight(g)
	e[3]:SetPoint("TOPLEFT", e[1], "BOTTOMLEFT", 0, 0)
	e[3]:SetPoint("BOTTOMLEFT", e[2], "TOPLEFT", 0, 0)
	e[3]:SetWidth(g)
	e[4]:SetPoint("TOPRIGHT", e[1], "BOTTOMRIGHT", 0, 0)
	e[4]:SetPoint("BOTTOMRIGHT", e[2], "TOPRIGHT", 0, 0)
	e[4]:SetWidth(g)
	return e
end

local function colorBorde(e, r, g, b, a)
	for i = 1, 4 do e[i]:SetVertexColor(r, g, b, a or 1) end
end

local function verBorde(e, si)
	for i = 1, 4 do
		e[i]:SetAlpha(1)
		if si then e[i]:Show() else e[i]:Hide() end
	end
end

local function texto(padre, rol)
	local fs = padre:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	if T and T.Font then T.Font(fs, rol) end
	fs:SetTextColor(1, 1, 1, 1)
	fs:SetShadowOffset(1, -1)
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetJustifyH("CENTER")
	fs:SetWordWrap(false)
	return fs
end

function M.CrearCuerpo(padre)
	local c = CreateFrame("Frame", nil, padre)
	c:SetAllPoints(padre)
	c.fondo = textura(c, "BACKGROUND")
	c.fondo:SetAllPoints(c)
	c.fondo:SetVertexColor(0.02, 0.025, 0.04, 0.92)

	local barra = CreateFrame("StatusBar", nil, c)
	barra:SetPoint("TOPLEFT", c, "TOPLEFT", 1, -1)
	barra:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -1, 1)
	barra:SetStatusBarTexture(BLANCO)
	barra:SetMinMaxValues(0, 1)
	barra:SetValue(1)
	barra:SetStatusBarColor(VERDE[1], VERDE[2], VERDE[3], 1)
	barra.fondo = textura(barra, "BACKGROUND")
	barra.fondo:SetAllPoints(barra)
	barra.fondo:SetVertexColor(VERDE[1] * 0.2, VERDE[2] * 0.2, VERDE[3] * 0.2, 1)
	-- Un brillo apenas visible arriba, para que no se vea plano.
	barra.brillo = textura(barra, "ARTWORK", 3)
	barra.brillo:SetPoint("TOPLEFT", barra, "TOPLEFT", 0, 0)
	barra.brillo:SetPoint("TOPRIGHT", barra, "TOPRIGHT", 0, 0)
	barra.brillo:SetHeight(1)
	barra.brillo:SetVertexColor(1, 1, 1, 0.18)
	c.barra = barra

	-- Las curas entrantes: otra barra que empieza donde termina la vida, recortada.
	local recorte = CreateFrame("Frame", nil, c)
	recorte:SetAllPoints(barra)
	recorte:SetFrameLevel(barra:GetFrameLevel() + 1)
	if recorte.SetClipsChildren then recorte:SetClipsChildren(true) end
	local inc = CreateFrame("StatusBar", nil, recorte)
	inc:SetStatusBarTexture(BLANCO)
	inc:SetStatusBarColor(VERDE[1], VERDE[2], VERDE[3], 0.45)
	local fin = barra:GetStatusBarTexture()
	inc:SetPoint("TOPLEFT", fin, "TOPRIGHT", 0, 0)
	inc:SetPoint("BOTTOMLEFT", fin, "BOTTOMRIGHT", 0, 0)
	inc:SetWidth(80)
	inc:SetMinMaxValues(0, 1)
	inc:SetValue(0)
	inc:Hide()
	c.entrantes = inc

	local capa = CreateFrame("Frame", nil, c)
	capa:SetAllPoints(c)
	capa:SetFrameLevel(barra:GetFrameLevel() + 3)
	c.capa = capa
	c.nombre = texto(capa, "label")
	c.estado = texto(capa, "caption")
	c.estado:SetTextColor(0.85, 0.87, 0.9, 1)
	c.rol = capa:CreateTexture(nil, "OVERLAY")
	c.rol:SetSize(11, 11)
	c.rol:SetPoint("TOPLEFT", c, "TOPLEFT", 3, -3)
	c.rol:Hide()
	c.amenaza = textura(capa, "OVERLAY")
	c.amenaza:SetPoint("TOPLEFT", c, "TOPLEFT", 1, -1)
	c.amenaza:SetPoint("TOPRIGHT", c, "TOPRIGHT", -1, -1)
	c.amenaza:SetHeight(2)
	c.amenaza:SetVertexColor(AMENAZA[1], AMENAZA[2], AMENAZA[3], 1)
	c.amenaza:Hide()
	c.disipar = borde(capa, 2, "OVERLAY")
	colorBorde(c.disipar, DISIPAR[1], DISIPAR[2], DISIPAR[3], 1)
	verBorde(c.disipar, false)
	c.objetivo = borde(capa, 1, "OVERLAY")
	colorBorde(c.objetivo, 1, 1, 1, 0.9)
	verBorde(c.objetivo, false)
	-- 1.3.0: el tipo de perjuicio, el punto del buff y el latido del tanque.
	c.perjuicio = capa:CreateTexture(nil, "OVERLAY")
	c.perjuicio:SetSize(12, 12)
	c.perjuicio:SetPoint("TOPRIGHT", c, "TOPRIGHT", -3, -3)
	c.perjuicio:Hide()
	c.punto = textura(capa, "OVERLAY")
	c.punto:SetSize(6, 6)
	c.punto:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -3, 3)
	c.punto:SetVertexColor(AZUL_BUFF[1], AZUL_BUFF[2], AZUL_BUFF[3], 1)
	c.punto:Hide()
	local pulso = CreateFrame("Frame", nil, c)
	pulso:SetAllPoints(c)
	pulso:SetFrameLevel(capa:GetFrameLevel() + 1)
	c.alerta = borde(pulso, 2, "OVERLAY")
	colorBorde(c.alerta, ROJO[1], ROJO[2], ROJO[3], 0)
	if pulso.CreateAnimationGroup then
		local ag = pulso:CreateAnimationGroup()
		if ag.SetLooping then ag:SetLooping("BOUNCE") end
		local an = ag.CreateAnimation and ag:CreateAnimation("Alpha")
		if an and an.SetFromAlpha then
			an:SetFromAlpha(1)
			an:SetToAlpha(0.25)
			an:SetDuration(0.45)
		end
		pulso.anim = ag
	end
	pulso:Hide()
	c.pulso = pulso
	return c
end

-- El tamaño de las piezas que no siguen solas al marco.
local function ajustarCuerpo(c, w, h)
	c.entrantes:SetWidth(max(1, w - 2))
	c.nombre:SetWidth(max(1, w - 8))
	c.estado:SetWidth(max(1, w - 8))
	c.nombre:ClearAllPoints()
	c.estado:ClearAllPoints()
	if h >= 30 then
		c.nombre:SetPoint("CENTER", c, "CENTER", 0, 5)
		c.estado:SetPoint("CENTER", c, "CENTER", 0, -8)
	else
		c.nombre:SetPoint("CENTER", c, "CENTER", 0, 0)
		c.estado:SetPoint("BOTTOM", c, "BOTTOM", 0, 2)
	end
end
M.AjustarCuerpo = ajustarCuerpo

---------------------------------------------------------------------------
-- Pintar con los datos de la unidad (solo lo que llega o se pasa sin leer)
---------------------------------------------------------------------------

-- El resultado de fn(...) si se puede leer; nil si falla o es secreto.
local function leer(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, v = pcall(fn, ...)
	if not ok or secreto(v) then return nil end
	return v
end

local function colorDeClase(clase)
	local t = type(RAID_CLASS_COLORS) == "table" and RAID_CLASS_COLORS[clase]
	if type(t) == "table" and type(t.r) == "number" then return t.r, t.g, t.b end
	local CC = C_ClassColor
	if CC and CC.GetClassColor then
		local ok, c = pcall(CC.GetClassColor, clase)
		if ok and type(c) == "table" and type(c.r) == "number" then return c.r, c.g, c.b end
	end
	return nil
end
M.ColorDeClase = colorDeClase

local function pintarBarra(c, r, g, b)
	c.barra:SetStatusBarColor(r, g, b, 1)
	c.barra.fondo:SetVertexColor(r * 0.22, g * 0.22, b * 0.22, 1)
end
M.PintarBarra = pintarBarra

local function vida(b)
	local c, u = b.cuerpo, b.unidad
	local okM, mx = pcall(UnitHealthMax, u)
	local okV, v = pcall(UnitHealth, u)
	if okM and okV then
		c.barra:SetMinMaxValues(0, mx)
		c.barra:SetValue(v)
	end
	if opt("entrantes") and UnitGetIncomingHeals and okM then
		local okI, inc = pcall(UnitGetIncomingHeals, u)
		if okI then
			c.entrantes:SetMinMaxValues(0, mx)
			if secreto(inc) or type(inc) == "number" then c.entrantes:SetValue(inc) else c.entrantes:SetValue(0) end
			c.entrantes:Show()
		end
	else
		c.entrantes:Hide()
	end
	if opt("porcentaje") and not b.alfaEstado and curvaPorcentaje and UnitHealthPercent then
		local ok, p = pcall(UnitHealthPercent, u, true, curvaPorcentaje)
		if ok then
			c.estado:SetFormattedText("%.0f%%", p)
			c.estado:Show()
		end
	elseif not b.alfaEstado then
		c.estado:Hide()
	end
end

-- Muerto, fantasma o desconectado: barra gris y su palabra. Color de clase.
local function aspecto(b, forzar)
	local c, u = b.cuerpo, b.unidad
	local conectado = leer(UnitIsConnected, u)
	local fantasma = leer(UnitIsGhost, u)
	local muerto = leer(UnitIsDeadOrGhost, u)
	local estado
	if conectado == false then
		estado = L["Desconectado"]
	elseif fantasma == true then
		estado = L["Fantasma"]
	elseif muerto == true then
		estado = L["Muerto"]
	end
	if not forzar and estado == b.alfaEstado and b.alfaPintado then return end
	b.alfaEstado, b.alfaPintado = estado, true
	if estado then
		c.estado:SetText(estado)
		c.estado:Show()
		pintarBarra(c, GRIS[1], GRIS[2], GRIS[3])
		c.nombre:SetTextColor(0.7, 0.7, 0.72, 1)
		return
	end
	c.estado:Hide()
	local okC, _, clase = pcall(UnitClass, u)
	local r, g, bb
	if okC and not secreto(clase) and type(clase) == "string" then r, g, bb = colorDeClase(clase) end
	if opt("colorClase") then
		if r then
			pintarBarra(c, r, g, bb)
		elseif okC and secreto(clase) then
			-- Un compañero cuya clase llega secreta: el color va sin leerse.
			local bien = pcall(function()
				local col = C_ClassColor.GetClassColor(clase)
				c.barra:SetStatusBarColor(col.r, col.g, col.b, 1)
				c.barra.fondo:SetVertexColor(0.1, 0.1, 0.12, 1)
			end)
			if not bien then pintarBarra(c, VERDE[1], VERDE[2], VERDE[3]) end
		else
			pintarBarra(c, VERDE[1], VERDE[2], VERDE[3])
		end
		c.nombre:SetTextColor(1, 1, 1, 1)
	else
		pintarBarra(c, VERDE[1], VERDE[2], VERDE[3])
		if r then c.nombre:SetTextColor(r, g, bb, 1) else c.nombre:SetTextColor(1, 1, 1, 1) end
	end
end

local function nombre(b)
	local ok, n = pcall(UnitName, b.unidad)
	if ok then b.cuerpo.nombre:SetText(n) end
end

local OPC_ROL = { displayRoleIcon = true }
local function rol(b)
	local c, u = b.cuerpo, b.unidad
	if not UnitGroupRolesAssigned then return c.rol:Hide() end
	local ok, r = pcall(UnitGroupRolesAssigned, u)
	if not ok then return c.rol:Hide() end
	if not secreto(r) then
		local coords = ROLES[r or ""]
		if coords then
			c.rol:SetTexture(ROLES_TEX)
			c.rol:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
			c.rol:SetSize(11, 11)
			c.rol:Show()
		else
			c.rol:Hide()
		end
		return
	end
	-- Rol secreto: Blizzard lo pinta por su vía segura.
	local U = rawget(_G, "UnitFrameUtil")
	if type(U) == "table" and type(U.UpdateUnitFrameRoleIcon) == "function" then
		if not pcall(U.UpdateUnitFrameRoleIcon, { roleIcon = c.rol, unit = u, optionTable = OPC_ROL }) then c.rol:Hide() end
	else
		c.rol:Hide()
	end
end

local function amenaza(b)
	local c = b.cuerpo
	if not opt("amenaza") then return c.amenaza:Hide() end
	local s = leer(UnitThreatSituation, b.unidad)
	if type(s) == "number" and s >= 2 then c.amenaza:Show() else c.amenaza:Hide() end
end

local function objetivo(b)
	local c = b.cuerpo
	local ok, es = pcall(UnitIsUnit, b.unidad, "target")
	if not ok then return verBorde(c.objetivo, false) end
	if secreto(es) then
		for i = 1, 4 do
			local t = c.objetivo[i]
			t:Show()
			if not pcall(t.SetAlphaFromBoolean, t, es, 1, 0) then t:Hide() end
		end
		return
	end
	verBorde(c.objetivo, es == true)
end

-- El perjuicio que tú puedes quitar: -> hay, auraInstanceID (si se puede usar)
local FILTRO = "HARMFUL|RAID"
local function disipable(u)
	local U = C_UnitAuras
	if not U then return false end
	if U.GetUnitAuraInstanceIDs then
		local ok, ids = pcall(U.GetUnitAuraInstanceIDs, u, FILTRO, 1)
		if ok and not secreto(ids) and type(ids) == "table" then
			local id = ids[1]
			if secreto(id) then return true, nil end
			if id ~= nil then return true, id end
			return false
		end
	end
	if U.GetAuraDataByIndex then
		local ok, aura = pcall(U.GetAuraDataByIndex, u, 1, FILTRO)
		if ok and not secreto(aura) and type(aura) == "table" then
			local id = aura.auraInstanceID
			return true, (not secreto(id) and type(id) == "number") and id or nil
		end
	end
	return false
end

-- El tipo del perjuicio ("Magic"...) si se puede leer, y el aura.
local function tipoDe(u, id)
	local U = C_UnitAuras
	if not (id and U and U.GetAuraDataByAuraInstanceID) then return nil end
	local ok, a = pcall(U.GetAuraDataByAuraInstanceID, u, id)
	if not ok or secreto(a) or type(a) ~= "table" then return nil end
	local t = a.dispelName
	if secreto(t) or type(t) ~= "string" or not M.TIPOS[t] then return nil, a end
	return t, a
end
M.TipoDe = tipoDe

-- Una vez por tipo y sesión: lo puedes quitar, pero ningún clic lo quita.
local avisados = {}
function M.AvisarSinQuitar(tipo)
	if avisados[tipo] or not M.TIPOS[tipo] then return false end
	local k = M.TiposQuePuedesQuitar()[tipo]
	if not k or M.RanuraQueQuita(tipo) then return false end
	avisados[tipo] = true
	N.Imprimir(string.format(L["Un compañero tiene %s y tú lo puedes quitar, pero ningún clic lo hace. Elige «%s» en Tus clics, en la página Curación."],
		M.TIPOS[tipo].nombre:lower(), M.NombreHechizo(M.Conocido(k)) or "?"))
	return true
end

local function disipar(b)
	local c, u = b.cuerpo, b.unidad
	b.alfaTipo = nil
	if not opt("disipar") then c.perjuicio:Hide() return verBorde(c.disipar, false) end
	local hay, id = disipable(u)
	if not hay then c.perjuicio:Hide() return verBorde(c.disipar, false) end
	local tipo, aura = tipoDe(u, id)
	b.alfaTipo = tipo
	if opt("tipoPerjuicio") and tipo then
		c.perjuicio:SetTexture(M.TIPOS[tipo].icono)
		c.perjuicio:Show()
	elseif opt("tipoPerjuicio") and aura and pcall(c.perjuicio.SetTexture, c.perjuicio, aura.icon) then
		c.perjuicio:Show()
	else
		c.perjuicio:Hide()
	end
	if tipo then M.AvisarSinQuitar(tipo) end
	local pintado = false
	if id and curvaDisipar and C_UnitAuras.GetAuraDispelTypeColor then
		pintado = pcall(function()
			local col = C_UnitAuras.GetAuraDispelTypeColor(u, id, curvaDisipar)
			local r, g, bb = col:GetRGB()
			colorBorde(c.disipar, r, g, bb, 1)
		end)
	end
	if not pintado and tipo then
		local col = M.TIPOS[tipo].color
		colorBorde(c.disipar, col[1], col[2], col[3], 1)
		pintado = true
	end
	if not pintado then colorBorde(c.disipar, DISIPAR[1], DISIPAR[2], DISIPAR[3], 1) end
	verBorde(c.disipar, true)
end

-- ¿Le falta tu buff de clase? Solo fuera de combate (en combate se queda como
-- estaba) y solo si el juego lo deja leer.
local function buffFalta(b)
	local c, u = b.cuerpo, b.unidad
	if not opt("buffs") or b.alfaEstado then b.alfaSinBuff = nil return c.punto:Hide() end
	if M.EnCombate() then return end
	local info = M.BuffDeClase()
	local U = C_UnitAuras
	if not (info and U and U.GetAuraDataBySpellName) then b.alfaSinBuff = nil return c.punto:Hide() end
	local tiene, sabe = false, false
	for _, k in ipairs(info.grupo) do
		local ids = M.H[k]
		local n = ids and M.NombreHechizo(ids[1])
		if n then
			local ok, a = pcall(U.GetAuraDataBySpellName, u, n, "HELPFUL")
			if ok and not secreto(a) then
				sabe = true
				if a ~= nil then tiene = true break end
			end
		end
	end
	b.alfaSinBuff = (sabe and not tiene) or nil
	c.punto:SetShown(b.alfaSinBuff and true or false)
end
M.BuffFalta = buffFalta

-- El tanque bajo el 40 %: su borde rojo late. Con la curva de color la vida
-- secreta va directo al color; sin ella, solo si la vida se puede leer.
local function tanque(b)
	local c, u = b.cuerpo, b.unidad
	local p = c.pulso
	if not (opt("tanque") and b.esTanque) or b.alfaEstado then
		b.alfaTanqueBajo = nil
		if p.anim then p.anim:Stop() end
		return p:Hide()
	end
	local pintado = false
	if M.curvaTanque and UnitHealthPercent then
		pintado = pcall(function()
			local col = UnitHealthPercent(u, true, M.curvaTanque)
			local r, g, bb, a = col:GetRGBA()
			colorBorde(c.alerta, r, g, bb, a)
		end)
	end
	if not pintado then
		local v, mx = leer(UnitHealth, u), leer(UnitHealthMax, u)
		if type(v) ~= "number" or type(mx) ~= "number" or mx <= 0 then
			b.alfaTanqueBajo = nil
			if p.anim then p.anim:Stop() end
			return p:Hide()
		end
		b.alfaTanqueBajo = (v / mx) < UMBRAL_TANQUE
		colorBorde(c.alerta, ROJO[1], ROJO[2], ROJO[3], b.alfaTanqueBajo and 1 or 0)
	end
	p:Show()
	if p.anim and not p.anim:IsPlaying() then p.anim:Play() end
end
M.Tanque = tanque

-- ¿Es el tanque? Rol asignado (buscador o líder) o tanque principal de la
-- banda. (En un grupo sin roles, M.RevisarTanques toma al único guerrero.)
function M.EsTanque(u)
	local r = leer(UnitGroupRolesAssigned, u)
	if r == "TANK" then return true end
	if GetPartyAssignment then
		local ok, es = pcall(GetPartyAssignment, "MAINTANK", u)
		if ok and not secreto(es) and es then return true end
	end
	return false
end

local function alcancePor(b, dentro, revisado)
	local c = b.cuerpo
	if not opt("alcance") or b.esJugador then return c:SetAlpha(1) end
	if secreto(dentro) then
		if not pcall(c.SetAlphaFromBoolean, c, dentro, 1, FUERA) then c:SetAlpha(1) end
		return
	end
	if dentro == nil or revisado == false then return c:SetAlpha(1) end
	c:SetAlpha(dentro == true and 1 or FUERA)
end

local function alcance(b)
	if not UnitInRange then
		-- Sin UnitInRange: la distancia de seguir (28 m), solo fuera de combate.
		if CheckInteractDistance and not M.EnCombate() and not b.esJugador then
			local ok, dentro = pcall(CheckInteractDistance, b.unidad, 4)
			if ok and not secreto(dentro) then alcancePor(b, dentro and true or false) end
		end
		return
	end
	local ok, dentro, revisado = pcall(UnitInRange, b.unidad)
	if not ok then return b.cuerpo:SetAlpha(1) end
	if secreto(revisado) then revisado = nil end
	alcancePor(b, dentro, revisado)
end

function M.ActualizarTodo(b)
	if not (b and b.cuerpo and b.unidad) then return end
	nombre(b)
	aspecto(b, true)
	vida(b)
	rol(b)
	disipar(b)
	buffFalta(b)
	tanque(b)
	amenaza(b)
	objetivo(b)
	alcance(b)
end

-- Quién es el tanque, de todos los marcos (en un rato, no por cada botón).
local tanquesPendiente = false
function M.RevisarTanques()
	local hay, guerreros, ultimo = false, 0, nil
	local enBanda = IsInRaid and IsInRaid() and true or false
	for _, b in ipairs(M.botones) do
		if b.unidad and b.cuerpo then
			b.esTanque = M.EsTanque(b.unidad)
			if b.esTanque then hay = true end
			local okC, _, clase = pcall(UnitClass, b.unidad)
			if okC and not secreto(clase) and clase == "WARRIOR" and b:IsVisible() then
				guerreros = guerreros + 1
				ultimo = b
			end
		end
	end
	if not hay and not enBanda and guerreros == 1 and ultimo then ultimo.esTanque = true end
	for _, b in ipairs(M.botones) do
		if b.unidad and b.cuerpo then tanque(b) end
	end
end
function M.ProgramarTanques()
	if tanquesPendiente then return end
	tanquesPendiente = true
	A.After(0.3, function()
		tanquesPendiente = false
		M.RevisarTanques()
	end)
end

---------------------------------------------------------------------------
-- Los botones seguros
---------------------------------------------------------------------------

local function soltar(b)
	local viejo = b.unidad
	if viejo and porUnidad[viejo] == b then porUnidad[viejo] = nil end
	if b.esJugador and porUnidad.player == b then porUnidad.player = nil end
	b.unidad, b.esJugador = nil, false
end

local function asignar(b, u)
	soltar(b)
	if type(u) ~= "string" or u == "" then return end
	b.unidad = u
	porUnidad[u] = b
	if u == "player" then
		b.esJugador = true
	else
		local ok, es = pcall(UnitIsUnit, u, "player")
		if ok and not secreto(es) and es == true then
			b.esJugador = true
			porUnidad.player = b
		end
	end
	b.alfaPintado = false
	M.ActualizarTodo(b)
	M.ProgramarTanques()
end

local function alCambiarAtributo(self, nombreAtributo, valor)
	if nombreAtributo == "unit" then asignar(self, valor) end
end

local function alEntrar(self)
	if M.EnCombate() or not opt("descripcion") or not self.unidad or not GameTooltip then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	if not pcall(GameTooltip.SetUnit, GameTooltip, self.unidad) then return GameTooltip:Hide() end
	-- 1.3.0: qué clic quita su perjuicio y qué clic le da tu buff.
	local tipo = self.alfaTipo
	if tipo and M.TIPOS[tipo] then
		local r = M.RanuraQueQuita(tipo)
		local col = M.TIPOS[tipo].color
		GameTooltip:AddLine(r and string.format(L["%s: quítalo con %s."], M.TIPOS[tipo].nombre, M.NombreRanura(r):lower())
			or string.format(L["%s: ningún clic lo quita."], M.TIPOS[tipo].nombre), col[1], col[2], col[3], true)
	end
	if self.alfaSinBuff then
		local info = M.BuffDeClase()
		local r = M.RanuraDelBuff()
		local n = info and M.NombreHechizo(info.id) or "?"
		GameTooltip:AddLine(r and string.format(L["Le falta %s: dáselo con %s."], n, M.NombreRanura(r):lower())
			or string.format(L["Le falta %s."], n), AZUL_BUFF[1], AZUL_BUFF[2], AZUL_BUFF[3], true)
	end
	GameTooltip:Show()
end

local function alSalir(self)
	if GameTooltip and GameTooltip:GetOwner() == self then GameTooltip:Hide() end
end

local function registrarClics(b)
	if b.RegisterForClicks then pcall(b.RegisterForClicks, b, "AnyUp") end
end

function M.PrepararBoton(b)
	if not b or rawget(b, "alfaListo") then return end
	b.alfaListo = true
	if M.EnCombate() then N.FueraDeCombate(function() registrarClics(b) end) else registrarClics(b) end
	b.cuerpo = M.CrearCuerpo(b)
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetTexture(BLANCO)
	hl:SetAllPoints(b)
	hl:SetVertexColor(1, 1, 1, 0.08)
	local w, h = M.Medidas()
	ajustarCuerpo(b.cuerpo, w, h)
	b:HookScript("OnAttributeChanged", alCambiarAtributo)
	b:HookScript("OnEnter", alEntrar)
	b:HookScript("OnLeave", alSalir)
	M.botones[#M.botones + 1] = b
	if not M.EnCombate() then M.AplicarABoton(b) end
	local ok, u = pcall(b.GetAttribute, b, "unit")
	if ok then asignar(b, u) end
end

---------------------------------------------------------------------------
-- El ancla (lo que se mueve), la cabecera y el asa para moverlos
---------------------------------------------------------------------------

local ancla, cabecera, asa, prueba
local moviendo, enPrueba = false, nil

function M.Medidas()
	local w = tonumber(opt("ancho")) or 88
	local h = tonumber(opt("alto")) or 36
	local porCol = tonumber(opt("porColumna")) or 5
	w = max(40, min(240, floor(w + 0.5)))
	h = max(16, min(100, floor(h + 0.5)))
	porCol = max(1, min(MAX, floor(porCol + 0.5)))
	return w, h, ESPACIO, porCol, opt("crecer") == "derecha" and "derecha" or "abajo"
end

local POS = { punto = "TOPLEFT", rel = "TOPLEFT", x = 24, y = -260 }

local function posicion()
	local d = N.Datos(ID)
	local p = type(d.pos) == "table" and d.pos or POS
	local x, y = tonumber(p.x) or POS.x, tonumber(p.y) or POS.y
	return type(p.punto) == "string" and p.punto or POS.punto, type(p.rel) == "string" and p.rel or POS.rel, x, y
end

local function colocarAncla()
	if not ancla or M.EnCombate() then return end
	local punto, rel, x, y = posicion()
	ancla:ClearAllPoints()
	ancla:SetPoint(punto, UIParent, rel, x, y)
end

local function guardarPosicion()
	if not ancla then return end
	local punto, _, rel, x, y = ancla:GetPoint(1)
	if type(punto) ~= "string" or type(x) ~= "number" then return end
	N.Datos(ID).pos = { punto = punto, rel = rel or punto, x = floor(x + 0.5), y = floor(y + 0.5) }
end

-- El ancla es protegida: si empieza un combate mientras la arrastras, se
-- suelta en PLAYER_REGEN_DISABLED (aún se puede) y se guarda donde quedó.
local arrastrando = false

local function empezarArrastre()
	if M.EnCombate() or not ancla then return end
	ancla:StartMoving()
	arrastrando = true
end

local function terminarArrastre()
	if not ancla then return end
	arrastrando = false
	if not M.EnCombate() then ancla:StopMovingOrSizing() end
	guardarPosicion()
	M.Avisar()
end

-- 1.3.2: el asa, hecha con el Kit: su texto y su botón «Listo» se miden, y el
-- asa crece con lo que dice (en alemán o ruso el texto es más largo).
local function crearAsa()
	local K = N.Kit
	asa = CreateFrame("Button", nil, ancla)
	asa:SetHeight(30)
	asa:SetPoint("BOTTOMLEFT", ancla, "TOPLEFT", 0, 4)
	asa:SetWidth(240)
	asa:EnableMouse(true)
	asa:RegisterForDrag("LeftButton")
	asa:SetScript("OnDragStart", empezarArrastre)
	asa:SetScript("OnDragStop", terminarArrastre)
	asa.caja = K.Caja(asa, { fondo = "fondo", alfaFondo = 0.92, borde = "linea", corte = K.CORTE.chico })
	asa.raya = K.Plano(asa, "acento", "ARTWORK", 1)
	asa.raya:SetPoint("TOPLEFT", asa, "TOPLEFT", 0, -K.CORTE.chico)
	asa.raya:SetPoint("BOTTOMLEFT", asa, "BOTTOMLEFT", 0, K.CORTE.chico)
	asa.raya:SetWidth(3)
	asa.texto = K.Texto(asa, "pequeno", "texto")
	asa.texto:SetPoint("LEFT", asa, "LEFT", 10, 0)
	asa.listo = K.Boton(asa, L["Listo"], function()
		M.Prueba(nil)
		M.Mover(false)
	end, { tipo = "primario", tam = "chico" })
	asa.listo:SetPoint("RIGHT", asa, "RIGHT", -3, 0)
	asa:Hide()
	M.asa = asa
end

-- Lo que dice el asa; el asa toma el ancho del texto más el de «Listo».
local function textoAsa(t)
	if not asa then return end
	local K = N.Kit
	K.Escribir(asa.texto, t)
	local w = K.Ajustar(asa.texto)
	asa:SetWidth(max(160, 10 + w + 12 + K.num(asa.listo:GetWidth(), 50) + 3))
end
M.TextoAsa = textoAsa

-- Se ejecuta en el entorno seguro al crear un botón nuevo (aunque sea en combate).
local INICIAL = [[
	local h = self:GetParent()
	self:SetWidth(h:GetAttribute("alfa-ancho") or 88)
	self:SetHeight(h:GetAttribute("alfa-alto") or 36)
	h:CallMethod("alfaNuevoBoton", self:GetName())
]]

local function nuevaCabecera(nombre, grupo)
	local h = CreateFrame("Frame", nombre, ancla, "SecureGroupHeaderTemplate")
	h:SetPoint("TOPLEFT", ancla, "TOPLEFT", 0, 0)
	h.alfaNuevoBoton = function(_, nombreBoton)
		local b = type(nombreBoton) == "string" and rawget(_G, nombreBoton) or nil
		if b then M.PrepararBoton(b) end
	end
	h:SetAttribute("template", "SecureUnitButtonTemplate")
	h:SetAttribute("templateType", "Button")
	h:SetAttribute("showRaid", true)
	h:SetAttribute("showParty", not grupo)
	h:SetAttribute("showPlayer", true)
	h:SetAttribute("initialConfigFunction", INICIAL)
	h.alfaGrupo = grupo
	h.alfaMax = grupo and 5 or MAX
	M.cabeceras[#M.cabeceras + 1] = h
	return h
end

M.cabeceras = {}
M.porGrupo = {}
local function crearCabecera()
	cabecera = nuevaCabecera("AlfaCuracionGrupo", nil)
	M.cabecera = cabecera
	-- 1.3.0: una cabecera por grupo de la banda (solo muestran gente en banda).
	for g = 1, GRUPOS do
		local h = nuevaCabecera("AlfaCuracionBanda" .. g, g)
		h:SetAttribute("groupFilter", tostring(g))
		M.porGrupo[g] = h
	end
end

-- ¿En banda, un marco por grupo? (con el orden por grupo y si el juego lo permite)
function M.ModoGrupos()
	return opt("porGrupos") and (opt("orden") or "grupo") == "grupo"
		and type(RegisterStateDriver) == "function" and type(UnregisterStateDriver) == "function" or false
end

local ORDENES = {
	grupo = { groupBy = "GROUP", groupingOrder = "1,2,3,4,5,6,7,8", sortMethod = "INDEX" },
	rol = { groupBy = "ASSIGNEDROLE", groupingOrder = "TANK,HEALER,DAMAGER,NONE", sortMethod = "NAME" },
	clase = { groupBy = "CLASS", groupingOrder = "WARRIOR,PALADIN,PRIEST,DRUID,SHAMAN,HUNTER,ROGUE,MAGE,WARLOCK", sortMethod = "NAME" },
	nombre = { sortMethod = "NAME" },
}

-- Los atributos de una cabecera de grupo de banda. Solo fuera de combate.
local function configurarGrupo(hd, g)
	local w, h, esp, _, crecer = M.Medidas()
	hd:SetAttribute("_ignore", "alfa")
	hd:SetAttribute("alfa-ancho", w)
	hd:SetAttribute("alfa-alto", h)
	hd:SetAttribute("showSolo", false)
	hd:ClearAllPoints()
	if crecer == "derecha" then
		hd:SetPoint("TOPLEFT", ancla, "TOPLEFT", 0, -(g - 1) * (h + esp))
		hd:SetAttribute("point", "LEFT")
		hd:SetAttribute("xOffset", esp)
		hd:SetAttribute("yOffset", 0)
	else
		hd:SetPoint("TOPLEFT", ancla, "TOPLEFT", (g - 1) * (w + esp), 0)
		hd:SetAttribute("point", "TOP")
		hd:SetAttribute("xOffset", 0)
		hd:SetAttribute("yOffset", -esp)
	end
	hd:SetAttribute("unitsPerColumn", 5)
	hd:SetAttribute("maxColumns", 1)
	hd:SetAttribute("sortMethod", "INDEX")
	hd:SetAttribute("_ignore", nil)
	hd:SetAttribute("alfa-revision", (hd:GetAttribute("alfa-revision") or 0) + 1)
end

-- Los atributos de la cabecera desde tus ajustes. Solo fuera de combate.
local revision = 0
local function configurarCabecera()
	local w, h, esp, porCol, crecer = M.Medidas()
	local orden = ORDENES[opt("orden") or ""] or ORDENES.grupo
	cabecera:SetAttribute("_ignore", "alfa")
	cabecera:SetAttribute("showSolo", opt("solo") and true or false)
	cabecera:SetAttribute("alfa-ancho", w)
	cabecera:SetAttribute("alfa-alto", h)
	if crecer == "derecha" then
		cabecera:SetAttribute("point", "LEFT")
		cabecera:SetAttribute("xOffset", esp)
		cabecera:SetAttribute("yOffset", 0)
		cabecera:SetAttribute("columnAnchorPoint", "TOP")
	else
		cabecera:SetAttribute("point", "TOP")
		cabecera:SetAttribute("xOffset", 0)
		cabecera:SetAttribute("yOffset", -esp)
		cabecera:SetAttribute("columnAnchorPoint", "LEFT")
	end
	cabecera:SetAttribute("columnSpacing", esp)
	cabecera:SetAttribute("unitsPerColumn", porCol)
	cabecera:SetAttribute("maxColumns", ceil(MAX / porCol))
	cabecera:SetAttribute("groupBy", orden.groupBy)
	cabecera:SetAttribute("groupingOrder", orden.groupingOrder)
	cabecera:SetAttribute("sortMethod", orden.sortMethod)
	for _, b in ipairs(M.botones) do
		b:SetSize(w, h)
		if b.cuerpo then ajustarCuerpo(b.cuerpo, w, h) end
	end
	cabecera:SetAttribute("_ignore", nil)
	revision = revision + 1
	cabecera:SetAttribute("alfa-revision", revision)
end

-- Los botones de una vez, fuera de combate (con la cabecera a la vista):
-- 40 en la de siempre y 5 en cada una de grupo.
local function crearBotones(h)
	h = h or cabecera
	if h.alfaCreados or not h:IsVisible() then return end
	h.alfaCreados = true
	local n = h.alfaMax or MAX
	h:SetAttribute("startingIndex", 1 - n)
	h:SetAttribute("startingIndex", 1)
	for i = 1, n do
		local ok, b = pcall(h.GetAttribute, h, "child" .. i)
		if ok and b then M.PrepararBoton(b) end
	end
end

-- Quién se ve: la cabecera de siempre (fuera de banda, o en banda sin el modo
-- por grupos) y las de grupo (en banda). El controlador de estado sigue
-- funcionando en combate: entrar o salir de una banda en pelea no rompe nada.
local conDriver = false
local function visibilidad()
	local activo = opt("activo") and true or false
	local grupos = activo and M.ModoGrupos()
	if conDriver then
		UnregisterStateDriver(cabecera, "visibility")
		conDriver = false
	end
	if activo then cabecera:Show() else cabecera:Hide() end
	if activo then crearBotones(cabecera) end
	for g, hd in ipairs(M.porGrupo) do
		if grupos then
			configurarGrupo(hd, g)
			hd:Show()
			crearBotones(hd)
		else
			hd:Hide()
		end
	end
	if grupos then
		RegisterStateDriver(cabecera, "visibility", "[group:raid] hide; show")
		conDriver = true
	end
	M.conDriver = conDriver
end

local iniciado = false
function M.Iniciar()
	N.FueraDeCombate(function()
		if not iniciado then
			iniciado = true
			ancla = CreateFrame("Frame", "AlfaCuracionAncla", UIParent)
			ancla:SetSize(10, 10)
			ancla:SetMovable(true)
			ancla:SetClampedToScreen(true)
			ancla:SetFrameStrata("LOW")
			M.ancla = ancla
			colocarAncla()
			crearAsa()
			crearCabecera()
		end
		M.Disponer()
	end)
end

-- Tus ajustes, en los marcos. Fuera de combate (si no, una vez al salir).
local disponerPendiente = false
function M.Disponer()
	if disponerPendiente then return end
	disponerPendiente = true
	N.FueraDeCombate(function()
		disponerPendiente = false
		if not cabecera then return end
		for _, h in ipairs(M.cabeceras) do M.AplicarACabecera(h) end
		configurarCabecera()
		visibilidad()
		M.Blizzard()
		if enPrueba then M.Prueba(enPrueba) end
		for _, b in ipairs(M.botones) do
			if b.unidad then
				b.alfaPintado = false
				M.ActualizarTodo(b)
			end
		end
		M.Avisar()
	end)
end

function M.Mover(si)
	if M.EnCombate() then
		N.Imprimir(L["Los marcos se mueven fuera de combate."])
		return
	end
	moviendo = si and true or false
	if asa then
		textoAsa(L["Curación: arrastra para mover"])
		if moviendo or enPrueba then asa:Show() else asa:Hide() end
	end
	M.Avisar()
end

function M.Moviendo() return moviendo end

function M.ReiniciarPosicion()
	N.Datos(ID).pos = nil
	N.FueraDeCombate(colocarAncla)
	M.Avisar()
end

---------------------------------------------------------------------------
-- Modo prueba: marcos de ejemplo, no seguros, para acomodarlos estando solo
---------------------------------------------------------------------------

local EJEMPLOS = {
	{ "Toxic", "PRIEST", 1.0, "HEALER" }, { "Colmillo", "WARRIOR", 0.62, "TANK", amenaza = true },
	{ "Luna", "DRUID", 0.35, nil, disipar = { 0.2, 0.6, 1 }, tipo = "Magic" }, { "Aullido", "MAGE", 0.9, "DAMAGER", lejos = true },
	{ "Sombra", "ROGUE", 0, "DAMAGER", muerto = true }, { "Garra", "HUNTER", 0.78, sinBuff = true },
	{ "Brasa", "WARLOCK", 0.55, nil, disipar = { 0.6, 0, 1 }, tipo = "Curse" }, { "Trueno", "SHAMAN", 0.84, "HEALER" },
	{ "Escudo", "PALADIN", 0.97, "TANK" }, { "Niebla", "MAGE", 0.4, nil, entrantes = 0.3 },
	{ "Hoja", "ROGUE", 1.0 }, { "Ceniza", "WARLOCK", 0.7, nil, desconectado = true },
	{ "Rocío", "DRUID", 0.88, "HEALER" }, { "Acero", "WARRIOR", 0.5, "DAMAGER", entrantes = 0.25 },
	{ "Ámbar", "PALADIN", 0.66 }, { "Rayo", "SHAMAN", 0.92 },
	{ "Eco", "HUNTER", 0.25, nil, disipar = { 0, 0.6, 0 }, tipo = "Poison" }, { "Lince", "DRUID", 0.32, "TANK", tanqueBajo = true },
	{ "Nube", "PRIEST", 0.81, "HEALER" }, { "Vela", "MAGE", 0.58, nil, lejos = true },
}

local falsos = {}

local function falso(i)
	local f = falsos[i]
	if f then return f end
	f = CreateFrame("Button", nil, prueba)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
	f:SetScript("OnDragStart", empezarArrastre)
	f:SetScript("OnDragStop", terminarArrastre)
	-- Un clic en un marco de prueba no lanza nada: dice qué lanzaría (el
	-- asistente lo muestra, M.alProbarClic).
	f:SetScript("OnClick", function(self, boton) M.ProbarClic(boton, self) end)
	f:SetScript("OnEnter", function(self)
		if not GameTooltip then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(L["Marco de prueba"], 1, 1, 1)
		GameTooltip:AddLine(L["Arrastra para mover tus marcos. Haz clic (con o sin Mayús, Ctrl o Alt) para ver qué lanzaría."], 0.8, 0.82, 0.86, true)
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", function(self) if GameTooltip and GameTooltip:GetOwner() == self then GameTooltip:Hide() end end)
	f.cuerpo = M.CrearCuerpo(f)
	falsos[i] = f
	return f
end

local function pintarFalso(f, e)
	local c = f.cuerpo
	c.nombre:SetText(e[1])
	c.barra:SetMinMaxValues(0, 1)
	c.barra:SetValue(e[3])
	local r, g, b = colorDeClase(e[2])
	if e.muerto or e.desconectado then
		pintarBarra(c, GRIS[1], GRIS[2], GRIS[3])
		c.estado:SetText(e.muerto and L["Muerto"] or L["Desconectado"])
		c.estado:Show()
		c.nombre:SetTextColor(0.7, 0.7, 0.72, 1)
	else
		if opt("colorClase") and r then
			pintarBarra(c, r, g, b)
			c.nombre:SetTextColor(1, 1, 1, 1)
		else
			pintarBarra(c, VERDE[1], VERDE[2], VERDE[3])
			if r then c.nombre:SetTextColor(r, g, b, 1) end
		end
		if opt("porcentaje") then
			c.estado:SetFormattedText("%.0f%%", e[3] * 100)
			c.estado:Show()
		else
			c.estado:Hide()
		end
	end
	local coords = ROLES[e[4] or ""]
	if coords then
		c.rol:SetTexture(ROLES_TEX)
		c.rol:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
		c.rol:Show()
	else
		c.rol:Hide()
	end
	if e.amenaza and opt("amenaza") then c.amenaza:Show() else c.amenaza:Hide() end
	if e.disipar and opt("disipar") then
		colorBorde(c.disipar, e.disipar[1], e.disipar[2], e.disipar[3], 1)
		verBorde(c.disipar, true)
	else
		verBorde(c.disipar, false)
	end
	if e.entrantes and opt("entrantes") then
		c.entrantes:SetMinMaxValues(0, 1)
		c.entrantes:SetValue(e.entrantes)
		c.entrantes:Show()
	else
		c.entrantes:Hide()
	end
	verBorde(c.objetivo, e[1] == "Colmillo")
	-- 1.3.0: el tipo de perjuicio, el punto del buff y el tanque que late.
	if e.tipo and opt("disipar") and opt("tipoPerjuicio") then
		c.perjuicio:SetTexture(M.TIPOS[e.tipo].icono)
		c.perjuicio:Show()
	else
		c.perjuicio:Hide()
	end
	c.punto:SetShown(e.sinBuff and opt("buffs") and true or false)
	if e.tanqueBajo and opt("tanque") then
		colorBorde(c.alerta, ROJO[1], ROJO[2], ROJO[3], 1)
		c.pulso:Show()
		if c.pulso.anim then c.pulso.anim:Play() end
	else
		if c.pulso.anim then c.pulso.anim:Stop() end
		c.pulso:Hide()
	end
	c:SetAlpha((e.lejos and opt("alcance")) and FUERA or 1)
end

-- Un clic sobre un marco de prueba: la ranura que tocó (botón y tecla) y lo
-- que haría de verdad. Lo cuenta M.alProbarClic(ranura, entrada, marco).
local SUFIJO = { LeftButton = "1", RightButton = "2", MiddleButton = "3" }
function M.ProbarClic(boton, marco)
	local s = SUFIJO[boton or ""]
	if not s then return end
	local p = ""
	if IsShiftKeyDown and IsShiftKeyDown() then p = "shift-"
	elseif IsControlKeyDown and IsControlKeyDown() then p = "ctrl-"
	elseif IsAltKeyDown and IsAltKeyDown() then p = "alt-" end
	local r = p .. s
	local e = M.Mapa()[r]
	if marco and marco.cuerpo and marco.cuerpo.estado then
		local c = marco.cuerpo
		c.estado:SetText(M.NombreAccion and M.NombreAccion(e) or "")
		c.estado:Show()
		local token = (marco.alfaToque or 0) + 1
		marco.alfaToque = token
		A.After(1.6, function()
			if marco.alfaToque == token and enPrueba then
				local i
				for k, x in ipairs(falsos) do if x == marco then i = k break end end
				if i and EJEMPLOS[i] then pintarFalso(marco, EJEMPLOS[i]) end
			end
		end)
	end
	if M.alProbarClic then M.alProbarClic(r, e, marco) end
end

-- n = 5 o 20 muestra la prueba; nil la quita.
function M.Prueba(n)
	if n and M.EnCombate() then
		N.Imprimir(L["El modo prueba se usa fuera de combate."])
		return
	end
	if not ancla then return end
	enPrueba = n
	if not prueba then
		prueba = CreateFrame("Frame", nil, ancla)
		prueba:SetPoint("TOPLEFT", ancla, "TOPLEFT", 0, 0)
		prueba:SetSize(10, 10)
		prueba:SetFrameStrata("MEDIUM")
	end
	if not n then
		prueba:Hide()
		if asa and not moviendo then asa:Hide() end
		M.Avisar()
		return
	end
	local w, h, esp, porCol, crecer = M.Medidas()
	for i = 1, #EJEMPLOS do
		local f = falso(i)
		if i <= n then
			local col, fila = floor((i - 1) / porCol), (i - 1) % porCol
			local x, y
			if crecer == "derecha" then
				x, y = fila * (w + esp), -col * (h + esp)
			else
				x, y = col * (w + esp), -fila * (h + esp)
			end
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", prueba, "TOPLEFT", x, y)
			f:SetSize(w, h)
			ajustarCuerpo(f.cuerpo, w, h)
			pintarFalso(f, EJEMPLOS[i])
			f:Show()
		else
			f:Hide()
		end
	end
	prueba:Show()
	if asa then
		textoAsa(string.format(L["Prueba con %d: arrastra para mover"], n))
		asa:Show()
	end
	M.Avisar()
end

function M.EnPrueba() return enPrueba end

---------------------------------------------------------------------------
-- Ocultar los marcos de grupo de Blizzard (fuera de combate)
---------------------------------------------------------------------------

local oculto = CreateFrame("Frame")
oculto:Hide()
local padres = {}
local BLIZZARD = { "PartyFrame", "CompactRaidFrameContainer" }

local blizzardPendiente = false
function M.Blizzard()
	if blizzardPendiente then return end
	blizzardPendiente = true
	N.FueraDeCombate(function()
		blizzardPendiente = false
		local quiere = opt("activo") and opt("ocultarBlizzard") and true or false
		for _, nombreMarco in ipairs(BLIZZARD) do
			local f = rawget(_G, nombreMarco)
			if type(f) == "table" and f.GetParent and f.SetParent then
				if quiere and not padres[f] then
					local okP, p = pcall(f.GetParent, f)
					padres[f] = okP and p or UIParent
					pcall(f.SetParent, f, oculto)
				elseif not quiere and padres[f] then
					pcall(f.SetParent, f, padres[f])
					padres[f] = nil
				end
			end
		end
	end)
end

---------------------------------------------------------------------------
-- Eventos de unidad y el temporizador de alcance
---------------------------------------------------------------------------

local sucias, flushPendiente = {}, false
local function limpiarAuras()
	flushPendiente = false
	for b in pairs(sucias) do
		sucias[b] = nil
		if b.unidad then
			disipar(b)
			buffFalta(b)
		end
	end
end

local function boton(u)
	if type(u) ~= "string" then return nil end
	local b = porUnidad[u]
	if b and b.unidad and b.cuerpo then return b end
	return nil
end

local POR_UNIDAD = {
	UNIT_HEALTH = function(b) aspecto(b) vida(b) if b.esTanque then tanque(b) end end,
	UNIT_MAXHEALTH = function(b) vida(b) end,
	UNIT_HEAL_PREDICTION = function(b) vida(b) end,
	UNIT_CONNECTION = function(b) aspecto(b, true) vida(b) end,
	UNIT_FLAGS = function(b) aspecto(b) end,
	UNIT_NAME_UPDATE = function(b) nombre(b) aspecto(b, true) end,
	UNIT_THREAT_SITUATION_UPDATE = function(b) amenaza(b) end,
	UNIT_AURA = function(b)
		sucias[b] = true
		if not flushPendiente then
			flushPendiente = true
			A.After(0.1, limpiarAuras)
		end
	end,
	UNIT_IN_RANGE_UPDATE = function(b, dentro) alcancePor(b, dentro) end,
}

for ev, fn in pairs(POR_UNIDAD) do
	A.RegisterEvent(ev, function(_, u, ...)
		local b = boton(u)
		if b then fn(b, ...) end
	end)
end

local function todos(fn)
	for _, b in ipairs(M.botones) do
		if b.unidad and b.cuerpo then fn(b) end
	end
end

A.RegisterEvent("PLAYER_TARGET_CHANGED", function() todos(objetivo) end)
A.RegisterEvent("PLAYER_ROLES_ASSIGNED", function() todos(rol) M.ProgramarTanques() end)
A.RegisterEvent("GROUP_ROSTER_UPDATE", function()
	M.RelojAlcance()
	todos(rol)
	M.ProgramarTanques()
	M.Blizzard()
	M.Avisar()
end)
A.RegisterEvent("PLAYER_REGEN_DISABLED", function()
	-- Un arrastre a medias se termina ahora, antes del bloqueo del combate.
	if arrastrando and ancla then
		arrastrando = false
		ancla:StopMovingOrSizing()
		guardarPosicion()
	end
	-- La prueba no sirve en una pelea: se quita y quedan tus marcos de verdad.
	if enPrueba and prueba then
		enPrueba = nil
		prueba:Hide()
		if asa and not moviendo then asa:Hide() end
	end
	M.Avisar()
end)
A.RegisterEvent("PLAYER_REGEN_ENABLED", function()
	todos(buffFalta) -- al salir de la pelea, a quién le falta tu buff
	M.Avisar()
end)
-- Aprendiste tu buff de clase (o cambió tu libro): el punto se revisa.
A.RegisterEvent("SPELLS_CHANGED", function() if not M.EnCombate() then todos(buffFalta) end end)
A.RegisterEvent("ADDON_LOADED", function(_, nombreAddon)
	if nombreAddon == "Blizzard_CompactRaidFrames" then M.Blizzard() end
end)

-- El alcance cambia sin evento si el cliente no trae UNIT_IN_RANGE_UPDATE:
-- cada medio segundo se revisan unos pocos botones (TOPE_ALCANCE) por turno.
local turno = 0
local function revisarAlcance() -- un solo reloj (1.2.9)
	local lista = M.botones
	local n = #lista
	if n == 0 or not opt("alcance") or not (ancla and ancla:IsVisible()) then return end
	local hechos, vistos = 0, 0
	while hechos < TOPE_ALCANCE and vistos < n do
		turno = turno % n + 1
		vistos = vistos + 1
		local b = lista[turno]
		if b.unidad and b.cuerpo and b:IsVisible() then
			alcance(b)
			hechos = hechos + 1
		end
	end
end

-- 1.3.2: el reloj del alcance solo corre con marcos a la vista (en grupo, o
-- solo con «Verte a ti estando solo»); sin marcos ni grupo se quita.
function M.RelojAlcance()
	local enGrupo = IsInGroup and IsInGroup() and true or false
	local quiere = opt("activo") and opt("alcance") and (enGrupo or opt("solo")) and true or false
	if quiere and not N.HayTarea("curacion.alcance") then
		N.Cada("curacion.alcance", CADA_ALCANCE, revisarAlcance)
	elseif not quiere and N.HayTarea("curacion.alcance") then
		N.Quitar("curacion.alcance")
	end
	return quiere
end
-- (Se decide al entrar al mundo: al cargar todavía no están tus ajustes.)

A.RegisterEvent("PLAYER_ENTERING_WORLD", function()
	M.RelojAlcance()
	M.Iniciar()
	A.After(3, function() M.Inicial() end)
end)

-- Tus ajustes: los marcos se rehacen (fuera de combate).
A.On("SETTING_CHANGED", function(path)
	path = type(path) == "string" and path or ""
	if path ~= "" and path ~= ID and path:sub(1, #ID + 1) ~= ID .. "." then return end
	M.RelojAlcance()
	M.Disponer()
end)
