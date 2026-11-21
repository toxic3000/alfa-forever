-- Alfa - Comodidades: las barras de abajo con el estilo de Alfa (toxic3000 / La Jauría). GPL-3.0.
--
-- La barra de acción principal, las barras extra, la de experiencia y
-- reputación, el menú y las bolsas toman el estilo elegido (Estilo.lua).
-- Los nombres son los de la interfaz de Forever (rama forever de
-- wow-ui-source; Forever es "camelot" sobre la familia Mainline):
--
--   MainActionBar (Mainline/MainActionBar.xml): su marco café y dorado
--     (BorderArt, "UI-HUD-ActionBar-Frame") y los grifos o dragones
--     (EndCaps.LeftEndCap/RightEndCap.Texture, Camelot/MainMenuBarEndCaps.xml).
--   Los botones: ActionButton1-12 y los de MultiBarBottomLeft/BottomRight/
--     Left/Right, MultiBar5-7, StanceBar, PetActionBar y PossessActionBar
--     (bar.actionButtons, Shared/ActionBar.lua). De cada uno se tocan solo
--     regiones de arte (Mainline/ActionButtonTemplate.xml): el marco
--     (NormalTexture), la ranura vacía (SlotArt, SlotBackground), el brillo
--     al pasar el ratón y al estar activo, la máscara y el recorte del ícono
--     y la letra de la tecla, la cuenta y el nombre de la macro.
--   StatusTrackingBarManager: MainStatusTrackingBarContainer y
--     SecondaryStatusTrackingBarContainer (BarFrameTexture), con la letra de
--     su texto. El relleno conserva sus colores (descansado, reputación...).
--   MicroMenu y BagsBar (Camelot): su marco (BorderArt, BackgroundArt).
--
-- Contaminación: los botones de acción son seguros. Aquí nunca se mueven,
-- reparentan, cambian de tamaño ni se les pone atributos; no se engancha
-- ningún método suyo; solo texturas, colores, letras, transparencia y
-- Show/Hide de regiones de arte, siempre fuera de combate
-- (N.FueraDeCombate). Los marcos de fondo son de Alfa, hijos de las barras
-- (el de la principal, del contenedor de su primer botón: ver padreFondo).
-- Un botón vacío que el juego muestra (Edit Mode: "Mostrar siempre los
-- botones") se sigue viendo: su casilla es la forma y el borde de Alfa.
-- En Clásico WoW las barras son las del juego: no se toca nada (salvo
-- ocultar los grifos, si lo pides). Al apagarlo todo vuelve sin /reload.

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local K = N.Kit
local ID = M.ID

local ipairs, pairs, type, pcall = ipairs, pairs, type, pcall

local function activo() return M.Get("barras") end
local function opcion(k) return M.On("barras", k) end

local BARRAS = { "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarLeft", "MultiBarRight",
	"MultiBar5", "MultiBar6", "MultiBar7", "StanceBar", "PetActionBar", "PossessActionBar" }
local CONTENEDORES = { "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }

local toques = M.Toques()
local fondos = {}       -- marco de Blizzard -> { marco, piel }
local botones = {}      -- botón -> { forma, borde, atlas = {}, mascara }
local aplicado = false
local grifosTocados = false

local function principal() return MainActionBar or MainMenuBar end

-- Los botones de una barra (sus actionButtons, o por nombre).
local function botonesDe(nombre)
	local barra = _G[nombre]
	local lista = {}
	if type(barra) ~= "table" then return lista end
	if type(barra.actionButtons) == "table" then
		for _, b in pairs(barra.actionButtons) do lista[#lista + 1] = b end
		return lista
	end
	local prefijo = nombre == "MainActionBar" and "ActionButton" or (nombre .. "Button")
	for i = 1, 12 do
		local b = _G[prefijo .. i]
		if type(b) == "table" then lista[#lista + 1] = b end
	end
	return lista
end

---------------------------------------------------------------------------
-- Fondos: un marco de Alfa detrás de una barra, en lugar de su arte
---------------------------------------------------------------------------
-- MainActionBar es un ResizeLayoutFrame (Shared/ActionBarTemplate.xml): su
-- Layout() la mide con todos sus hijos directos a la vista, salvo los que
-- Blizzard marca con ignoreInLayout (escribir ese campo desde Alfa
-- contaminaría su Layout). Un fondo hijo directo, más grande que la barra, la
-- agrandaría y la correría de lugar. Por eso el fondo cuelga del contenedor
-- del primer botón (un marco simple que siempre se ve con la barra; su Layout
-- solo mide el contenedor) y se ancla a la barra.
local function padreFondo(dueno)
	local bs = rawget(dueno, "actionButtons")
	local b = type(bs) == "table" and bs[1]
	local c = type(b) == "table" and rawget(b, "container")
	if type(c) == "table" and c.GetObjectType and c.CreateTexture then return c end
	return dueno
end

local function fondoDe(dueno, margen, opts)
	if type(dueno) ~= "table" or not dueno.GetFrameLevel then return nil end
	local f = fondos[dueno]
	if f then return f end
	local m = CreateFrame("Frame", nil, padreFondo(dueno))
	m:SetPoint("TOPLEFT", dueno, "TOPLEFT", -margen, margen)
	m:SetPoint("BOTTOMRIGHT", dueno, "BOTTOMRIGHT", margen, -margen)
	if opts and opts.estrato then m:SetFrameStrata(opts.estrato) end
	f = { marco = m, piel = M.Piel(m, { corte = K.CORTE.panel, marca = opts and opts.marca, anchoMarca = 44 }) }
	m:Hide()
	fondos[dueno] = f
	return f
end

local function pintarFondo(f, dueno, est, e, visible)
	if not f then return end
	local ok, n = pcall(dueno.GetFrameLevel, dueno)
	f.marco:SetFrameLevel(ok and type(n) == "number" and n or 1)
	f.marco:SetShown(visible)
	f.piel:SetShown(visible)
	if visible then f.piel:Pintar(est, e) end
end

---------------------------------------------------------------------------
-- Botones de acción
---------------------------------------------------------------------------
local function piezaBoton(b)
	local p = botones[b]
	if p then return p end
	if not b.CreateTexture then return nil end
	p = { atlas = {} }
	p.forma = K.Forma(b, K.CORTE.casilla, "BACKGROUND", -8, b)
	p.borde = K.Borde(b, K.CORTE.casilla, "OVERLAY", b)
	p.forma:Hide() p.borde:Hide()
	botones[b] = p
	return p
end

-- Un brillo del botón (al pasar el ratón, activo) como color plano; su atlas
-- de Blizzard se recuerda para devolverlo.
local ATLAS_BRILLO = "UI-HUD-ActionBar-IconFrame-Mouseover" -- el de los dos en ActionButtonTemplate.xml

local function brillo(p, reg, clave, r, g, b, a)
	if type(reg) ~= "table" or not reg.SetColorTexture then return end
	if p.atlas[clave] == nil then
		local ok, at = pcall(reg.GetAtlas, reg)
		p.atlas[clave] = { reg = reg, atlas = (ok and type(at) == "string" and at ~= "") and at or ATLAS_BRILLO }
	end
	reg:SetColorTexture(r, g, b, a)
end

local function devolverBrillos(p)
	for _, x in pairs(p.atlas) do
		if x.atlas then pcall(x.reg.SetAtlas, x.reg, x.atlas) end
	end
	p.atlas = {}
end

local function pintarBoton(b, est, con)
	local p = con and piezaBoton(b) or botones[b]
	local normal = b.NormalTexture or (b.GetNormalTexture and b:GetNormalTexture())
	local icono, mascara = b.icon, b.IconMask
	if not con then
		toques:DevolverUna(normal)
		toques:DevolverUna(b.SlotArt)
		toques:DevolverUna(b.SlotBackground)
		for _, k in ipairs({ "HotKey", "Count", "Name" }) do toques:Letra(b[k], nil) end
		if p then
			p.forma:Hide() p.borde:Hide()
			devolverBrillos(p)
			if p.sinMascara and icono and mascara and icono.AddMaskTexture then pcall(icono.AddMaskTexture, icono, mascara) end
			if p.recortado and icono and icono.SetTexCoord then icono:SetTexCoord(0, 1, 0, 1) end
			p.sinMascara, p.recortado = nil, nil
		end
		return
	end
	if not p then return end
	toques:Ocultar(normal)
	toques:Ocultar(b.SlotArt)
	toques:Ocultar(b.SlotBackground)
	p.forma:Show()
	p.borde:Show()
	p.forma:RGBA(M.ColorDe(est, "hundido"))
	p.borde:Color(M.TablaColor(est, "lineaFuerte"))
	-- El ícono, cuadrado y recortado (sin las esquinas redondas de Blizzard).
	if icono and mascara and icono.RemoveMaskTexture and not p.sinMascara then
		if pcall(icono.RemoveMaskTexture, icono, mascara) then p.sinMascara = true end
	end
	if icono and icono.SetTexCoord then
		icono:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		p.recortado = true
	end
	brillo(p, b.GetHighlightTexture and b:GetHighlightTexture(), "sobre", 1, 1, 1, 0.12)
	local r, g, bl = M.ColorDe(est, "acento")
	brillo(p, b.GetCheckedTexture and b:GetCheckedTexture(), "activo", r, g, bl, 0.35)
	toques:Letra(b.HotKey, M.CaraDe(est, "semibold"))
	toques:Letra(b.Count, M.CaraDe(est, "semibold"))
	toques:Letra(b.Name, M.CaraDe(est, "medium"))
end

---------------------------------------------------------------------------
-- Grifos (o dragones): como están, del color del estilo u ocultos
---------------------------------------------------------------------------
local function grifos(est)
	local barra = principal()
	local caps = barra and barra.EndCaps
	local modo = activo() and N.Get(ID, "barrasGrifos") or "como"
	local propio = N.Get(ID, "barrasGrifos") == "ocultar" -- Marcos.lua los oculta también sin el estilo
	for _, k in ipairs({ "LeftEndCap", "RightEndCap" }) do
		local t = caps and caps[k] and caps[k].Texture
		if type(t) == "table" and t.SetVertexColor then
			if modo == "color" and est ~= "clasico" then
				t:SetDesaturated(true)
				t:SetVertexColor(M.ColorDe(est, "textoSuave"))
			else
				t:SetDesaturated(false)
				t:SetVertexColor(1, 1, 1, 1)
			end
			if modo == "ocultar" then
				t:SetAlpha(0)
				grifosTocados = true
			elseif grifosTocados and not propio then
				t:SetAlpha(1)
			end
		end
	end
	if modo ~= "ocultar" then grifosTocados = false end
end

---------------------------------------------------------------------------
-- Aplicar
---------------------------------------------------------------------------
local function arteVisible(barra)
	local arte = barra and barra.BorderArt
	if type(arte) ~= "table" or not arte.IsShown then return true end
	return arte:IsShown() and true or false
end

local function aplicar()
	local si = activo()
	if not si and not aplicado then return end
	local est = M.EstiloDe("barrasEstilo")
	local casa = si and est ~= "clasico"
	aplicado = si

	-- La barra principal: su marco.
	local barra = principal()
	if type(barra) == "table" then
		if casa then
			toques:Ocultar(barra.BorderArt)
			local f = fondoDe(barra, 5, { marca = true })
			pintarFondo(f, barra, est, { fondo = "fondo", borde = "linea", opacidad = 0.9 }, arteVisible(barra))
		else
			toques:DevolverUna(barra.BorderArt)
			pintarFondo(fondos[barra], barra, est, {}, false)
		end
	end

	-- Los botones de todas las barras.
	local conBotones = casa and opcion("barrasBotones")
	for _, nombre in ipairs(BARRAS) do
		for _, b in ipairs(botonesDe(nombre)) do M.Seguro(pintarBoton, b, est, conBotones) end
	end

	-- Experiencia y reputación.
	local conExp = casa and opcion("barrasExperiencia")
	for _, nombre in ipairs(CONTENEDORES) do
		local c = _G[nombre]
		if type(c) == "table" and c.GetChildren then
			local f = conExp and fondoDe(c, 1) or fondos[c]
			if conExp then toques:Ocultar(c.BarFrameTexture) else toques:DevolverUna(c.BarFrameTexture) end
			pintarFondo(f, c, est, { borde = "lineaFuerte" }, conExp)
			for _, hijo in ipairs({ c:GetChildren() }) do
				local texto = type(hijo) == "table" and hijo.OverlayFrame and hijo.OverlayFrame.Text
				if texto then toques:Letra(texto, conExp and M.CaraDe(est, "semibold") or nil) end
			end
		end
	end

	-- El menú y las bolsas.
	local conMenu = casa and opcion("barrasMenu")
	for _, dueno in ipairs({ MicroMenu or false, BagsBar or false }) do
		if type(dueno) == "table" then
			if conMenu then
				toques:Ocultar(dueno.BorderArt)
				toques:Ocultar(dueno.BackgroundArt)
			else
				toques:DevolverUna(dueno.BorderArt)
				toques:DevolverUna(dueno.BackgroundArt)
			end
			local f = conMenu and fondoDe(dueno, 4) or fondos[dueno]
			pintarFondo(f, dueno, est, { fondo = "panel", borde = "linea", opacidad = 0.9 }, conMenu)
		end
	end

	grifos(est)
	if not si then toques:Devolver() end
end

local function enCalma() N.FueraDeCombate(aplicar) end

M.AlCambiar({ "barras", "barrasEstilo", "barrasBotones", "barrasGrifos", "barrasExperiencia", "barrasMenu" }, enCalma)
M.AlCambiarAspecto(function() if activo() then enCalma() end end)

-- Edit Mode puede ocultar el arte de la barra o cambiar las barras: al
-- salir de él se vuelve a aplicar. También al entrar al juego (las barras
-- extra y la de experiencia se arman al cargar).
local enganchado = false
local function enganchar()
	if enganchado then return end
	enganchado = true
	if type(EventRegistry) == "table" and EventRegistry.RegisterCallback then
		pcall(EventRegistry.RegisterCallback, EventRegistry, "EditMode.Exit", function()
			if activo() then enCalma() end
		end, M)
	end
end
A.RegisterEvent("PLAYER_ENTERING_WORLD", function()
	enganchar()
	if activo() then A.After(1, enCalma) end
end)

-- 1.3.7: los botones de acción de todas las barras (los números de las
-- recargas, Recargas.lua, los usan).
function M.BotonesDeAccion()
	local lista = {}
	for _, nombre in ipairs(BARRAS) do
		for _, b in ipairs(botonesDe(nombre)) do lista[#lista + 1] = b end
	end
	return lista
end

-- Para pruebas.
M.Barras = { Aplicar = aplicar, Botones = botones, Fondos = fondos }
