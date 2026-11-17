-- Alfa - Comodidades: el chat con el estilo de Alfa (toxic3000 / La Jauría). GPL-3.0.
--
-- Viste las ventanas de chat (ChatFrame1..N y las temporales de susurros)
-- con el estilo elegido (Estilo.lua): Alfa, Clásico WoW o Cristal.
--
--   Panel: los fondos y bordes de Blizzard (CHAT_FRAME_TEXTURES, también los
--     de la columna de botones) se ocultan con :Hide() -Blizzard solo funde
--     los que están a la vista (FCF_FadeInChatFrame)- y detrás del texto va
--     un marco propio en la capa BACKGROUND con la forma de Alfa (o el marco
--     de los cuadros de información en Clásico WoW), del tamaño del fondo de
--     Blizzard (FloatingChatFrame_UpdateBackgroundAnchors).
--   Pestañas (ChatFrameNTab): su arte se vuelve transparente (Blizzard lo
--     muestra y oculta en FCFTab_UpdateColors) y se dibuja el propio: la
--     elegida con su fondo y una línea de acento. En Clásico WoW quedan las
--     de Blizzard, que ya son el juego.
--   Caja para escribir (ChatFrameNEditBox): igual, con el borde de acento
--     mientras escribes.
--   Letra: la del estilo (Inter en Alfa y Cristal), solo la cara; el tamaño
--     lo sigue poniendo Blizzard (menú de la pestaña > Tamaño de letra).
--   Botones: la columna de botones (ChatFrameNButtonFrame) se puede ocultar.
--
-- Contaminación: nada se reemplaza. Solo hooksecurefunc y HookScript, texturas
-- y marcos propios, transparencias, Show/Hide de regiones de arte y SetFont.
-- No se escribe ningún campo en los marcos de Blizzard (la caja para escribir
-- ejecuta comandos seguros como /cast). Al apagarlo todo vuelve sin /reload.

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local K = N.Kit
local ID = M.ID

local ipairs, pairs, type, tonumber, max = ipairs, pairs, type, tonumber, math.max

local function on(k) return M.On("chat", k) end

local TEXTURAS = {
	"Background", "TopLeftTexture", "BottomLeftTexture", "TopRightTexture", "BottomRightTexture",
	"LeftTexture", "RightTexture", "BottomTexture", "TopTexture",
	"ButtonFrameBackground", "ButtonFrameTopLeftTexture", "ButtonFrameBottomLeftTexture",
	"ButtonFrameTopRightTexture", "ButtonFrameBottomRightTexture", "ButtonFrameLeftTexture",
	"ButtonFrameRightTexture", "ButtonFrameBottomTexture", "ButtonFrameTopTexture",
}
local PESTANA = { "Left", "Middle", "Right", "ActiveLeft", "ActiveMiddle", "ActiveRight", "HighlightLeft", "HighlightMiddle", "HighlightRight" }
local ESCRIBIR = { "Left", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight" }
local CABECERAS = { "header", "headerSuffix", "languageHeader", "prompt", "NewcomerHint" }

local pieles = {}       -- marco de chat -> registro
local porPestana = {}   -- pestaña -> registro
local porCaja = {}      -- caja para escribir -> registro

local function nombreDe(f)
	if type(f) ~= "table" or not f.GetName then return nil end
	local ok, n = pcall(f.GetName, f)
	return ok and type(n) == "string" and n or nil
end

-- Todos los marcos de chat que existen (los fijos y los temporales).
local function marcos()
	local lista, visto = {}, {}
	local function agregar(f)
		if type(f) == "table" and f.GetObjectType and not visto[f] then
			visto[f] = true
			lista[#lista + 1] = f
		end
	end
	for i = 1, tonumber(NUM_CHAT_WINDOWS) or 10 do agregar(_G["ChatFrame" .. i]) end
	if type(CHAT_FRAMES) == "table" then
		for _, n in ipairs(CHAT_FRAMES) do if type(n) == "string" then agregar(_G[n]) end end
	end
	return lista
end

---------------------------------------------------------------------------
-- Las piezas propias de cada ventana
---------------------------------------------------------------------------
local function crear(cf)
	local r = pieles[cf]
	if r then return r end
	local nombre = nombreDe(cf)
	if not nombre then return nil end
	r = { cf = cf, nombre = nombre, toques = M.Toques() }

	-- El panel, detrás del texto: un marco hijo en la capa más baja.
	local p = CreateFrame("Frame", nil, cf)
	p:SetFrameStrata("BACKGROUND")
	local fondo = _G[nombre .. "Background"]
	if fondo then
		p:SetPoint("TOPLEFT", fondo, "TOPLEFT", -2, 2)
		p:SetPoint("BOTTOMRIGHT", fondo, "BOTTOMRIGHT", 2, -2)
	else
		p:SetPoint("TOPLEFT", cf, "TOPLEFT", -4, 5)
		p:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", 17, -8)
	end
	r.panel = p
	r.piel = M.Piel(p, { corte = K.CORTE.panel, marca = true })

	-- La pestaña: sus texturas son de la pestaña (bajo su texto), en la
	-- parte de abajo, que es la que se ve.
	local tab = _G[nombre .. "Tab"]
	if type(tab) == "table" and tab.CreateTexture then
		r.tab = tab
		local ancla = CreateFrame("Frame", nil, tab)
		ancla:SetPoint("TOPLEFT", tab, "TOPLEFT", 2, -9)
		ancla:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -2, 0)
		r.tabForma = K.Forma(ancla, K.CORTE.chico, "BACKGROUND", -7, tab)
		r.tabBorde = K.Borde(ancla, K.CORTE.chico, "BACKGROUND", tab)
		r.tabLinea = tab:CreateTexture(nil, "BORDER", nil, 2)
		r.tabLinea:SetColorTexture(1, 1, 1, 1)
		r.tabLinea:SetHeight(2)
		r.tabLinea:SetPoint("BOTTOMLEFT", ancla, "BOTTOMLEFT", 6, 0)
		r.tabLinea:SetPoint("BOTTOMRIGHT", ancla, "BOTTOMRIGHT", -6, 0)
		r.tabForma:Hide() r.tabBorde:Hide() r.tabLinea:Hide()
		porPestana[tab] = r
	end

	-- La caja para escribir.
	local caja = _G[nombre .. "EditBox"]
	if type(caja) == "table" and caja.CreateTexture then
		r.caja, r.nombreCaja = caja, nombreDe(caja)
		local ancla = CreateFrame("Frame", nil, caja)
		ancla:SetPoint("TOPLEFT", caja, "TOPLEFT", 4, -4)
		ancla:SetPoint("BOTTOMRIGHT", caja, "BOTTOMRIGHT", -4, 4)
		r.cajaForma = K.Forma(ancla, K.CORTE.control, "BACKGROUND", -7, caja)
		r.cajaBorde = K.Borde(ancla, K.CORTE.control, "BORDER", caja)
		r.cajaForma:Hide() r.cajaBorde:Hide()
		porCaja[caja] = r
	end

	pieles[cf] = r
	return r
end

---------------------------------------------------------------------------
-- Pintar
---------------------------------------------------------------------------
local function opacidad()
	local v = tonumber(N.Get(ID, "chatOpacidad"))
	if not v then return 0.7 end
	return v < 0 and 0 or (v > 1 and 1 or v)
end

local function elegida(tab)
	local t = tab and tab.ActiveMiddle
	return t and t.IsShown and t:IsShown() and true or false
end

-- El color del texto de la pestaña como lo pone Blizzard (FCFTab_UpdateColors).
local function textoBlizzard(tab)
	local fs = tab.GetFontString and tab:GetFontString()
	if not fs then return end
	local c = tab.selectedColorTable or NORMAL_FONT_COLOR
	if type(c) == "table" and type(c.r) == "number" then fs:SetTextColor(c.r, c.g, c.b) end
end

local function pintarPestana(r)
	local tab = r.tab
	if not tab then return end
	local estilo = r.estilo
	local fs = tab.GetFontString and tab:GetFontString()
	if not (r.activo and on("chatPestanas") and estilo ~= "clasico") then
		for _, k in ipairs(PESTANA) do r.toques:DevolverUna(tab[k]) end
		r.tabForma:Hide() r.tabBorde:Hide() r.tabLinea:Hide()
		r.toques:Letra(fs, nil)
		if r.tabPintada then textoBlizzard(tab) r.tabPintada = nil end
		return
	end
	for _, k in ipairs(PESTANA) do r.toques:Ocultar(tab[k]) end
	local sel = elegida(tab)
	r.tabForma:SetShown(sel)
	r.tabBorde:SetShown(sel)
	r.tabLinea:SetShown(sel)
	if sel then
		r.tabForma:RGBA(M.ColorDe(estilo, "panel"))
		r.tabBorde:Color(M.TablaColor(estilo, "linea"))
		r.tabLinea:SetVertexColor(M.ColorDe(estilo, "acento"))
	end
	r.toques:Letra(fs, on("chatLetra") and M.CaraDe(estilo, "semibold") or nil)
	-- Los susurros llevan su color propio (selectedColorTable): se respeta.
	if fs and not tab.selectedColorTable then
		fs:SetTextColor(M.ColorDe(estilo, sel and "texto" or "textoSuave"))
	end
	r.tabPintada = true
end

local function pintarCaja(r)
	local caja = r.caja
	if not caja then return end
	local estilo = r.estilo
	local nc = r.nombreCaja
	if not (r.activo and on("chatEscribir") and estilo ~= "clasico") then
		for _, k in ipairs(ESCRIBIR) do r.toques:DevolverUna(nc and _G[nc .. k]) end
		r.toques:DevolverUna(caja.focusLeft) r.toques:DevolverUna(caja.focusMid) r.toques:DevolverUna(caja.focusRight)
		r.cajaForma:Hide() r.cajaBorde:Hide()
		return
	end
	for _, k in ipairs(ESCRIBIR) do r.toques:Ocultar(nc and _G[nc .. k]) end
	r.toques:Ocultar(caja.focusLeft) r.toques:Ocultar(caja.focusMid) r.toques:Ocultar(caja.focusRight)
	r.cajaForma:Show()
	r.cajaBorde:Show()
	r.cajaForma:RGBA(unpack(M.TablaColor(estilo, "hundido", max(opacidad(), 0.85))))
	local foco = caja.HasFocus and caja:HasFocus()
	r.cajaBorde:Color(M.TablaColor(estilo, foco and "acento" or "lineaFuerte"))
end

local function letras(r)
	local cara = r.activo and on("chatLetra") and M.CaraDe(r.estilo, "regular") or nil
	r.toques:Letra(r.cf, cara)
	if r.caja then
		r.toques:Letra(r.caja, cara)
		for _, k in ipairs(CABECERAS) do r.toques:Letra(r.caja[k], cara) end
	end
end

-- La columna de botones (menú, canales, voz): oculta mientras se pida.
local function botones(r)
	local bf = r.cf.buttonFrame or _G[r.nombre .. "ButtonFrame"]
	if type(bf) ~= "table" or not bf.Hide then return end
	if r.activo and on("chatBotones") then
		if not r.botonesOcultos then r.botonesVisibles = bf:IsShown() end
		r.botonesOcultos = true
		bf:Hide()
		if not r.botonesEnganchados and bf.HookScript then
			r.botonesEnganchados = true
			bf:HookScript("OnShow", function(self)
				if r.botonesOcultos then self:Hide() end
			end)
		end
	elseif r.botonesOcultos then
		r.botonesOcultos = nil
		if r.botonesVisibles then bf:Show() end
	end
end

local function pintar(r)
	r.estilo = M.EstiloDe("chatEstilo")
	for _, s in ipairs(TEXTURAS) do r.toques:Esconder(_G[r.nombre .. s]) end
	r.panel:SetFrameStrata("BACKGROUND")
	r.panel:Show()
	r.piel:SetShown(true)
	r.piel:Pintar(r.estilo, { fondo = "fondo", borde = "linea", opacidad = opacidad() })
	pintarPestana(r)
	pintarCaja(r)
	letras(r)
	botones(r)
end

local function quitar(r)
	r.activo = false
	pintarPestana(r)
	pintarCaja(r)
	letras(r)
	botones(r)
	r.piel:SetShown(false)
	r.panel:Hide()
	r.toques:Devolver()
	-- Los fondos vuelven con la transparencia de la ventana (Blizzard la
	-- vuelve a fundir al pasar el ratón).
	local a = tonumber(r.cf.oldAlpha) or tonumber(DEFAULT_CHATFRAME_ALPHA) or 0.25
	for _, s in ipairs(TEXTURAS) do
		local t = _G[r.nombre .. s]
		if type(t) == "table" and t.SetAlpha then pcall(t.SetAlpha, t, a) end
	end
end

---------------------------------------------------------------------------
-- Aplicar, y seguir a las ventanas nuevas
---------------------------------------------------------------------------
local enganchado = false
local aplicar

local function enganchar()
	if enganchado or type(hooksecurefunc) ~= "function" then return end
	enganchado = true
	local function otraVez() if M.Get("chat") then N.FueraDeCombate(aplicar) end end
	for _, f in ipairs({ "FCF_OpenNewWindow", "FCF_OpenTemporaryWindow", "FCF_DockUpdate" }) do
		if type(_G[f]) == "function" then hooksecurefunc(f, otraVez) end
	end
	if type(FCFTab_UpdateColors) == "function" then
		hooksecurefunc("FCFTab_UpdateColors", function(tab)
			local r = porPestana[tab]
			if r and r.activo then M.Seguro(pintarPestana, r) end
		end)
	end
end

local function engancharCaja(r)
	local caja = r.caja
	if not caja or r.cajaEnganchada or not caja.HookScript then return end
	r.cajaEnganchada = true
	local function foco() if r.activo then M.Seguro(pintarCaja, r) end end
	caja:HookScript("OnEditFocusGained", foco)
	caja:HookScript("OnEditFocusLost", foco)
end

aplicar = function()
	local si = M.Get("chat")
	if si then enganchar() end
	for _, cf in ipairs(marcos()) do
		local r = si and crear(cf) or pieles[cf]
		if r then
			if si then
				r.activo = true
				engancharCaja(r)
				pintar(r)
			elseif r.activo then
				quitar(r)
			end
		end
	end
end

M.AlCambiar({ "chat", "chatEstilo", "chatOpacidad", "chatPestanas", "chatEscribir", "chatLetra", "chatBotones" },
	function() N.FueraDeCombate(aplicar) end)

M.AlCambiarAspecto(function()
	if M.Get("chat") then N.FueraDeCombate(aplicar) end
end)

-- Para pruebas.
M.Chat = { Aplicar = function() aplicar() end, Pieles = pieles }
