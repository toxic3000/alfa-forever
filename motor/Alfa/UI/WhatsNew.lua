-- Alfa: las novedades (Toxic / La Jauria, GPL-3.0; docs/INTERFAZ.md). Las
-- notas de Polestar cambian por las de Alfa; el mecanismo de cuando se
-- muestran es el de Polestar (GPL-3.0, The Polestar authors).
--
-- Una ventana de 580 centrada, con las piezas de la bienvenida
-- (UI/Welcome.lua, WEL.Kit): la marca de acento arriba, una cabecera con el
-- lobo, "Novedades de Alfa 0.1.0" y una linea; las notas de la version en dos
-- columnas, cada una un recuadro de esquinas cortadas con su icono, un titulo
-- y una linea (una lista que se desplaza si no cabe en MAX_H); un pie con una
-- linea a la izquierda y "Abrir la ventana de Alfa" y "Entendido" a la
-- derecha.
--
-- NOTES guarda las notas de cada version, la mas nueva primero: una version
-- con algo que contar agrega su entrada, y la ventana muestra la mas nueva.
--
-- Cuando se muestran (como siempre):
-- Por cuenta: AlfaDB.whatsNewSeen, la version de las ultimas notas vistas.
-- Las notas son del addon, no de un personaje: con alts se leen una vez. Una
-- instalacion nueva (ns.IsNewAccount) recibe la bienvenida, y las notas mas
-- nuevas quedan vistas sin mostrarse; una cuenta de antes de esta ventana (sin
-- marca) actualizo, asi que le tocan. Al entrar se abren mientras la marca
-- difiere de la version de las notas mas nuevas; abrirlas pone la marca, asi
-- que un /reload o salir con ellas abiertas no las repite.
--
-- Se abren unos segundos despues de entrar, nunca en combate, durante una
-- cinematica, en una instancia o campo de batalla, sobre la eleccion de ruta
-- ni mientras la bienvenida esta abierta o pendiente: esperan a que termine
-- cada cosa (WELCOME_CLOSED, PLAYER_REGEN_ENABLED, CINEMATIC_STOP,
-- PLAYER_ENTERING_WORLD, el cierre de la eleccion de ruta). /alfa whatsnew
-- (SHOW_WHATSNEW) y Acerca de las abren cuando sea, fuera de combate.

local ADDON, ns = ...
local UI, Theme, W, Anim = ns.UI, ns.Theme, ns.Widgets, ns.Anim
local L = ns.L
local T = ns.T
local floor, max, min, ceil = math.floor, math.max, math.min, math.ceil

local WN = {}
UI.WhatsNew = WN

local function cmd(text)
	return "|c" .. Theme.Hex("text") .. text .. "|r"
end

-- The releases' notes, newest first. Each note: its glyph and colour, its
-- heading and its line (functions, so they are read in the player's
-- language and the commands they name take the theme's colours when shown).
local NOTES = {
	{
		version = "0.1.0",
		notes = {
			{ glyph = "window", color = "accent", head = function() return T("Ventana principal nueva") end, text = function()
				return string.format(T("Hoy, Aventura, Personaje, Mundo, Oficios y Manada en una sola ventana: %s o el lobo del minimapa."), cmd("/alfa"))
			end },
			{ glyph = "sec-hoy", color = "accent", head = function() return T("Hoy, a tu clase") end, text = function()
				return T("Tu sesión, tu diario, recordatorios y tu siguiente paso, con el color de tu clase.")
			end },
			{ glyph = "guides", color = "accent", head = function() return T("Ventana de guía propia") end, text = function()
				return T("Tu avance arriba, el paso en una tarjeta, los dos siguientes a la vista y los botones abajo.")
			end },
			{ glyph = "sec-personaje", color = "accent", head = function() return T("Curación con clic") end, text = function()
				return T("Marcos de grupo y banda para curar con un clic, con preajustes por clase.")
			end },
			{ glyph = "sec-aventura", color = "accent", head = function() return T("Rutas propias") end, text = function()
				return T("El árbol de ruta de Alfa, misiones que se liberan y un catálogo de objetos.")
			end },
			{ glyph = "sec-manada", color = "accent", head = function() return T("La Jauría en el mapa") end, text = function()
				return T("Tu grupo, tu hermandad y tus amigos en el mapa, con Seguir y la página del clan.")
			end },
			{ glyph = "icon-talk", color = "accent", head = function() return T("En 9 idiomas") end, text = function()
				return T("Español, inglés y siete idiomas más, en toda la interfaz.")
			end },
			{ glyph = "check", color = "success", head = function() return T("¿Algo raro?") end, text = function()
				return string.format(T("Escribe %s y cuéntanos en el Discord de La Jauría."), cmd("/alfa report"))
			end },
		},
	},
}
WN.NOTES = NOTES
WN.LATEST = NOTES[1].version

local DELAY = 3 -- seconds after login: after the welcome's own delay, so a due welcome goes first
local MAX_H = 600 -- the window's height at most; more notes scroll
local TILE = 32 -- a note's glyph tile
local ROW_GAP = 10 -- between the notes' rows
local HERO_H = 80 -- the header
local BODY_GAP = 16 -- between the header and the notes, and under them

local F
local pending -- nil | "login" | "asked": waiting for the moment it may open
local hookedRC

local function seen()
	return ns.DB().whatsNewSeen == WN.LATEST
end

local function inCinematic()
	return (InCinematic and InCinematic()) or (IsInCinematicScene and IsInCinematicScene()) or false
end

local function welcomeBusy()
	local Wel = UI.Welcome
	return Wel and Wel.Busy and Wel.Busy() or false
end

local function routeChoiceUp()
	local RC = UI.RouteChoice
	return RC and RC.IsShown and RC.IsShown() or false
end

local function close()
	if F then F:Hide() end
end

local function openAlfa()
	close()
	ns.Fire("SHOW_OPTIONS")
end

-- A note: a panel with its corners cut, its glyph on a tile at the left, its
-- heading and its line beside it.
local function noteBox(parent, K)
	local n = CreateFrame("Frame", nil, parent)
	n:SetWidth(K.CARD_W)
	Theme.Skin(n, "panel")
	n.Tile = W.Tag(n, TILE, TILE, Theme.CUT.small)
	n.Tile:SetPoint("TOPLEFT", n, "TOPLEFT", 12, -12)
	W.Painter(n.Tile, function(t) t:SetColor(Theme.Color("panelAlt")) end)
	n.Glyph = W.Tex(n.Tile, "OVERLAY", "check", "accent")
	n.Glyph:SetSize(16, 16)
	n.Glyph:SetPoint("CENTER", n.Tile, "CENTER", 0, 0)
	local x = 12 + TILE + 12
	n.Head = W.Text(n, "heading", "text")
	n.Head:SetWidth(K.CARD_W - x - 12)
	K.place(n.Head, x, 12)
	n.Text = K.para(n, "note", "textDim", K.CARD_W - x - 12, 2)
	return n
end

local function build()
	local K = UI.Welcome.Kit
	F = CreateFrame("Frame", "AlfaWhatsNew", ns.UIParent)
	F:SetFrameStrata("DIALOG")
	F:SetToplevel(true)
	F:SetClampedToScreen(true)
	F:EnableMouse(true)
	F:SetMovable(true)
	F:SetWidth(K.WIDTH)
	F:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	F:Hide()
	Theme.Skin(F, "window")
	local function drag(frame)
		frame:EnableMouse(true)
		frame:RegisterForDrag("LeftButton")
		frame:SetScript("OnDragStart", function() F:StartMoving() end)
		frame:SetScript("OnDragStop", function() F:StopMovingOrSizing() end)
	end
	drag(F)

	-- The header: the wolf, the title and its line; the ✕. It drags the window.
	local h = CreateFrame("Frame", nil, F)
	h:SetWidth(K.INNER)
	h:SetPoint("TOPLEFT", F, "TOPLEFT", 1, -1)
	h:SetHeight(HERO_H)
	drag(h)
	h.Emblem = W.Tex(h, "ARTWORK", "emblem", "accent")
	h.Emblem:SetSize(36, 36)
	h.Emblem:SetPoint("TOPLEFT", h, "TOPLEFT", K.PAD - 1, -22)
	h.Title = W.Text(h, "title", "text")
	h.Title:SetPoint("TOPLEFT", h, "TOPLEFT", K.PAD + 36 + 14, -22)
	h.Sub = W.Text(h, "note", "textDim")
	h.Sub:SetPoint("TOPLEFT", h.Title, "BOTTOMLEFT", 0, -5)
	local rule = W.Divider(h)
	rule:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 0, 0)
	rule:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 0, 0)
	F.Hero = h
	F.Close = W.IconButton(F, "close", 28, L["Close"], close, 12)
	F.Close:SetPoint("TOPRIGHT", F, "TOPRIGHT", -12, -12)
	F.Close:SetFrameLevel(F:GetFrameLevel() + 40)

	-- The notes, two by two, in a list that scrolls when they don't fit.
	local sf = W.Scroll(F)
	F.Scroll = sf
	local p = sf.Child
	p:SetWidth(K.CW)
	F.Body = p
	p.Notes = {}

	-- The footer: a line on the left, the buttons on the right.
	local foot = CreateFrame("Frame", nil, F)
	foot:SetPoint("BOTTOMLEFT", F, "BOTTOMLEFT", 1, 1)
	foot:SetPoint("BOTTOMRIGHT", F, "BOTTOMRIGHT", -1, 1)
	foot:SetHeight(K.FOOT_H)
	foot:SetFrameLevel(F:GetFrameLevel() + 30)
	W.Fill(foot, "footer")
	local frule = W.Divider(foot)
	frule:SetPoint("TOPLEFT", foot, "TOPLEFT", 0, 0)
	frule:SetPoint("TOPRIGHT", foot, "TOPRIGHT", 0, 0)
	F.Foot = foot
	F.GotIt = W.Button(foot, T("Entendido"), close, { primary = true })
	F.GotIt:SetPoint("RIGHT", foot, "RIGHT", -K.PAD, 0)
	F.OpenAlfa = W.Button(foot, T("Abrir la ventana de Alfa"), openAlfa)
	F.OpenAlfa:SetPoint("RIGHT", F.GotIt, "LEFT", -8, 0)
	F.Site = W.Text(foot, "small", "textMuted")
	F.Site:SetPoint("LEFT", foot, "LEFT", K.PAD, 0)
	F.Site:SetPoint("RIGHT", F.OpenAlfa, "LEFT", -12, 0)

	if W.Rim then F.Rim = W.Rim(F) end
	F:SetScript("OnShow", function(self)
		Anim.To(self, "alpha", 0, 1, Anim.BASE, "out")
		Anim.Anchor(h, "TOPLEFT", F, "TOPLEFT", 1, -1)
		Anim.To(h, "alpha", 0, 1, Anim.BASE, "out")
		Anim.To(h, "offset", -6, 0, Anim.BASE, "out")
		Theme.RetextLater(self)
	end)
	ns.CloseOnEscape("AlfaWhatsNew")
	WN.frame = F
	if ns.Gamepad and ns.Gamepad.Register then
		ns.Gamepad.Register(F, {
			initial = function(rows)
				for i, w in ipairs(rows) do if w == F.GotIt then return i end end
			end,
		})
	end
end

-- Lays the newest notes out, two by two, each row as tall as its tallest
-- note; the window takes their height up to MAX_H.
local function render()
	local K = UI.Welcome.Kit
	local entry = NOTES[1]
	local h, p = F.Hero, F.Body
	h.Title:SetText(string.format(T("Novedades de Alfa %s"), entry.version))
	h.Sub:SetText(T("Lo nuevo de esta versión, en pocas palabras."))
	local heroH = HERO_H

	for _, n in pairs(p.Notes) do n:Hide() end
	local y, x0 = 0, 12 + TILE + 12
	local list = entry.notes
	for i = 1, #list, 2 do
		local rowH = 0
		for k = i, min(i + 1, #list) do
			local note = list[k]
			local n = p.Notes[k]
			if not n then
				n = noteBox(p, K)
				p.Notes[k] = n
			end
			n.Glyph:SetTexture(Theme.Media(note.glyph))
			W.Color(n.Glyph, note.color)
			n.Head:SetText(note.head())
			n.Text:SetText(note.text())
			K.place(n.Text, x0, 12 + ceil(n.Head:GetStringHeight()) + 4)
			local nh = max(12 + TILE + 12, 12 + ceil(n.Head:GetStringHeight()) + 4 + ceil(n.Text:GetStringHeight()) + 12)
			rowH = max(rowH, nh)
			n:Show()
		end
		for k = i, min(i + 1, #list) do
			local n = p.Notes[k]
			n:SetHeight(rowH)
			Theme.Repaint(n)
			K.place(n, (k - i) * (K.CARD_W + K.GAP), y)
		end
		y = y + rowH + ROW_GAP
	end
	local bodyH = max(1, y - ROW_GAP)
	local fixed = 1 + heroH + BODY_GAP + BODY_GAP + K.FOOT_H + 1
	local viewH = min(bodyH, MAX_H - fixed)
	local sf = F.Scroll
	sf:ClearAllPoints()
	sf:SetPoint("TOPLEFT", F, "TOPLEFT", K.PAD, -(1 + heroH + BODY_GAP))
	sf:SetPoint("TOPRIGHT", F, "TOPRIGHT", -(K.PAD - 8), -(1 + heroH + BODY_GAP))
	sf:SetHeight(viewH)
	W.SetScrollContent(sf, bodyH, viewH)
	W.ScrollTo(sf, 0)
	F.Site:SetText(T("Cuéntanos qué te parece en La Jauría."))
	F:SetHeight(ceil(fixed + viewH))
	if F.Rim and W.LayoutRim then W.LayoutRim(F) end
end

local try -- forward

-- Wait for the route choice to close (not for Alfa hiding it with the
-- rest: it stays open then), then try again.
local function afterRouteChoice()
	local RC = UI.RouteChoice
	if not hookedRC and RC and RC.frame then
		hookedRC = true
		RC.frame:HookScript("OnHide", function(self) if not self:IsShown() then try() end end)
	end
end

-- Open now, or once the fight, the cinematic, the instance, the route choice
-- or the welcome allows. A request opens anywhere out of combat.
local function open(why)
	if ns.Compat.InCombat() or inCinematic() then
		pending = pending == "asked" and "asked" or why
		return
	end
	if why == "login" then
		if ns.Compat.IsInInstance() or welcomeBusy() then
			pending = "login"
			return
		end
		if routeChoiceUp() then
			pending = "login"
			afterRouteChoice()
			return
		end
	end
	pending = nil
	ns.DB().whatsNewSeen = WN.LATEST -- shown: a reload or logout from here does not repeat it
	if not F then build() end
	render()
	F:Show()
	F:Raise()
end

function try()
	if pending == "asked" or (pending == "login" and not seen()) then open(pending) end
end

function WN.Show()
	open("asked")
end

function WN.Hide()
	pending = nil
	close()
end

function WN.IsShown()
	return F ~= nil and F:IsShown()
end

-- A fresh install marks the newest notes seen: it gets the welcome instead.
ns.OnInit(function()
	local db = ns.DB()
	if db.whatsNewSeen == nil and ns.IsNewAccount() then db.whatsNewSeen = WN.LATEST end
end)

ns.OnLogin(function()
	if seen() then return end
	pending = "login"
	if C_Timer and C_Timer.After then ns.After(DELAY, try) else try() end
end)

ns.RegisterEvent("PLAYER_REGEN_ENABLED", function() try() end)
ns.RegisterEvent("CINEMATIC_STOP", function()
	if C_Timer and C_Timer.After then ns.After(1, try) else try() end
end)
-- Out of an instance or battleground.
ns.RegisterEvent("PLAYER_ENTERING_WORLD", function()
	if pending and C_Timer and C_Timer.After then ns.After(DELAY, try) end
end)
ns.On("WELCOME_CLOSED", function() try() end)
ns.On("SHOW_WHATSNEW", function() WN.Show() end)
Theme.OnChanged(function()
	if F and F:IsShown() then render() end
end)
