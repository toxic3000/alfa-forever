-- Alfa: la bienvenida (Toxic / La Jauria, GPL-3.0; docs/INTERFAZ.md).
-- Reemplaza la presentacion de Polestar (cielo nocturno, demostracion de
-- ruta y textos de su proyecto) por una bienvenida corta de Alfa; conserva
-- de la de Polestar (GPL-3.0, The Polestar authors) cuando se muestra y como
-- espera al combate, a las cinematicas y a la eleccion de ruta.
--
-- Una ventana de 580 centrada, en el estilo de Alfa: la marca de acento
-- arriba (W.Rim), una cabecera con el lobo, A L F A y el saludo, cuatro
-- tarjetas de esquinas cortadas en dos filas y un pie:
--
--   [lobo] A L F A  BETA                                         ✕
--          ¡Hola, Toxic! Te damos la bienvenida a Alfa...
--   ┌ Que es Alfa ───────────┐  ┌ Tu ventana de Alfa ─────┐
--   │ todo lo que usas...    │  │ /alfa o el lobo del     │
--   └────────────────────────┘  └ minimapa; /alfa guia ───┘
--   ┌ Tu primera guia ───────┐  ┌ La Jauria ──────────────┐
--   │ sugerida para ti...    │  │ Discord: [enlace]       │
--   │ [Elegir mi primera guia]  │                         │
--   └────────────────────────┘  └─────────────────────────┘
--   Version 0.1.0                  [Abrir la ventana de Alfa] [Listo]
--
-- Elegir mi primera guia abre el selector (SHOW_PICKER); el enlace de La
-- Jauria (ns.DiscordURL) va en un cuadro para copiar; Abrir la ventana de
-- Alfa la abre en Hoy (SHOW_OPTIONS).
--
-- Cuando se muestra (como siempre):
-- Por personaje: AlfaCharDB.welcomeSeen, la version de la bienvenida (SEEN).
-- Un personaje nuevo (ns.IsNewCharacter) recibe 0, asi que le toca; uno con
-- datos guardados y sin la marca recibe SEEN sin verla, asi que nadie que ya
-- juega la recibe sin pedirla. Al entrar se abre mientras la marca del
-- personaje esta por debajo de SEEN, y abrirla pone la marca, asi que un
-- /reload o salir con ella abierta no la repite; una que tocaba y no se abrio
-- (salir en combate o bajo la eleccion de ruta) sigue pendiente.
-- Por cuenta: AlfaDB.welcomeSeen, la cuenta ya tuvo su bienvenida. Cualquier
-- cierre (Listo, el ✕, Escape, elegir guia, abrir la ventana) pone las dos
-- marcas y avisa con WELCOME_CLOSED (UI/WhatsNew.lua espera ese mensaje).
--
-- Se abre un momento despues de entrar, nunca en combate (espera a que
-- termine), nunca durante una cinematica y nunca sobre la eleccion de ruta:
-- espera a que se cierre, y si la eleccion se abre sobre ella se aparta y
-- vuelve despues. Una cinematica que la cierra no la marca vista: vuelve al
-- terminar. Acerca de > Mostrar la bienvenida otra vez y /alfa welcome
-- (SHOW_WELCOME) la abren cuando sea.

local ADDON, ns = ...
local UI, Theme, W, Anim = ns.UI, ns.Theme, ns.Widgets, ns.Anim
local L = ns.L
local T = ns.T
local floor, max, ceil = math.floor, math.max, math.ceil

local WEL = {}
UI.Welcome = WEL

local SEEN = 2 -- version de la bienvenida: 2 = la de Alfa (quien vio la anterior la ve una vez)
local WIDTH = 580
local PAD = 24
local INNER = WIDTH - 2 -- inside the window's 1px edge
local CW = WIDTH - PAD * 2 -- the body's width
local GAP = 12 -- between the cards
local CARD_W = floor((CW - GAP) / 2)
local CARD_PAD = 16
local HEAD_H = 96
local FOOT_H = 56
local EMBLEM = 44
local DELAY = 2 -- seconds after login, so the world and the other windows settle first

local F -- the window
local pending -- nil | "login" (due at login) | "asked" (opened on request, or coming back), waiting for combat or the route choice
local stepping -- hidden to make way for the route choice, not closed
local unasked = false -- this showing came by itself (open's deferred): a gamepad waits to be asked
local hookedRC

local function inCombat()
	return InCombatLockdown and InCombatLockdown() or false
end

-- The intro cinematic or a cinematic scene is playing.
local function inCinematic()
	return (InCinematic and InCinematic()) or (IsInCinematicScene and IsInCinematicScene()) or false
end

-- This character has had its welcome.
local function seen()
	return (tonumber(ns.CharState().welcomeSeen) or 0) >= SEEN
end

local function routeChoiceUp()
	local RC = UI.RouteChoice
	return RC and RC.IsShown and RC.IsShown() or false
end

local function colored(name, text)
	return "|c" .. Theme.Hex(name) .. text .. "|r"
end

-- A command or a button's name in running text: the text colour.
local function cmd(text)
	return colored("text", text)
end

local function known(s)
	return type(s) == "string" and s ~= "" and s or nil
end

-- A wrapped block of text, `width` wide.
local function para(parent, role, color, width, spacing)
	local fs = W.Text(parent, role, color)
	fs:SetWidth(width)
	fs:SetWordWrap(true)
	fs:SetSpacing(spacing or 3)
	fs:SetJustifyH("LEFT")
	fs:SetJustifyV("TOP")
	return fs
end

local function place(region, x, y)
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", region:GetParent(), "TOPLEFT", x, -y)
end

local function close()
	if F then F:Hide() end
end

-- The guide Alfa suggests for this character, or nil: its title and levels.
local function suggested()
	local G, E = ns.Guides, ns.Engine
	local id = E and E.StartingGuide and E.StartingGuide() or (G and G.Suggest and G.Suggest())
	local g = id and G and G.Get and G.Get(id)
	if not (g and known(g.title)) then return nil end
	local lv = UI.LevelRange and UI.LevelRange(g.minLevel, g.maxLevel)
	return g.title .. (lv and (" (" .. lv .. ")") or "")
end

---------------------------------------------------------------------------
-- Cards: a panel with its corners cut (Theme.Skin "panel"), a glyph and a
-- heading, its text, and under them an action (a button or a copy box).
---------------------------------------------------------------------------

local function card(parent, glyph, color, heading)
	local c = CreateFrame("Frame", nil, parent)
	c:SetWidth(CARD_W)
	Theme.Skin(c, "panel")
	c.Glyph = W.Tex(c, "ARTWORK", glyph, color)
	c.Glyph:SetSize(18, 18)
	c.Glyph:SetPoint("TOPLEFT", c, "TOPLEFT", CARD_PAD, -CARD_PAD)
	c.Head = W.Text(c, "heading", "text")
	c.Head:SetText(heading)
	c.Head:SetPoint("LEFT", c.Glyph, "RIGHT", 10, 0)
	c.Text = para(c, "note", "textDim", CARD_W - CARD_PAD * 2, 3)
	place(c.Text, CARD_PAD, CARD_PAD + 18 + 10)
	return c
end

-- A card's height for its text and action, at least `least`.
local function cardHeight(c)
	local y = CARD_PAD + 18 + 10 + ceil(c.Text:GetStringHeight())
	if c.Extra and c.Extra:IsShown() then
		place(c.Extra, CARD_PAD, y + 8)
		y = y + 8 + ceil(c.Extra:GetStringHeight())
	end
	local a = c.Action
	if a then
		place(a, CARD_PAD, y + 12)
		y = y + 12 + a:GetHeight()
	end
	return y + CARD_PAD
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------

local function drag(frame)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function() F:StartMoving() end)
	frame:SetScript("OnDragStop", function() F:StopMovingOrSizing() end)
end

local function chooseGuide()
	close()
	ns.Fire("SHOW_PICKER")
end

local function openAlfa()
	close()
	ns.Fire("SHOW_OPTIONS")
end

local function build()
	F = CreateFrame("Frame", "AlfaWelcome", ns.UIParent)
	F:SetFrameStrata("DIALOG")
	F:SetToplevel(true)
	F:SetClampedToScreen(true)
	F:EnableMouse(true)
	F:SetMovable(true)
	F:SetWidth(WIDTH)
	F:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	F:Hide()
	Theme.Skin(F, "window")
	drag(F)

	-- The header: the wolf, ALFA in spaced capitals (the one word set that
	-- way) and the release stage, the greeting under them; the ✕.
	local head = CreateFrame("Frame", nil, F)
	head:SetPoint("TOPLEFT", F, "TOPLEFT", 1, -1)
	head:SetPoint("TOPRIGHT", F, "TOPRIGHT", -1, -1)
	head:SetHeight(HEAD_H)
	drag(head)
	F.Head = head
	F.Emblem = W.Tex(head, "ARTWORK", "emblem", "accent")
	F.Emblem:SetSize(EMBLEM, EMBLEM)
	F.Emblem:SetPoint("TOPLEFT", head, "TOPLEFT", PAD - 1, -24)
	F.Brand = W.Text(head, "display", "text")
	F.Brand:SetText("A L F A")
	F.Brand:SetPoint("TOPLEFT", head, "TOPLEFT", PAD + EMBLEM + 14, -26)
	F.Stage = W.Chip(head)
	F.Stage:SetPoint("LEFT", F.Brand, "RIGHT", 10, 0)
	F.Hello = para(head, "note", "textDim", CW - EMBLEM - 14 - 32, 3)
	place(F.Hello, PAD + EMBLEM + 14, 52)
	F.Close = W.IconButton(head, "close", 28, L["Close"], close, 12)
	F.Close:SetPoint("TOPRIGHT", F, "TOPRIGHT", -12, -12)
	local rule = W.Divider(head)
	rule:SetPoint("BOTTOMLEFT", head, "BOTTOMLEFT", 0, 0)
	rule:SetPoint("BOTTOMRIGHT", head, "BOTTOMRIGHT", 0, 0)

	-- The cards, two by two.
	local body = CreateFrame("Frame", nil, F)
	body:SetWidth(CW)
	body:SetPoint("TOPLEFT", F, "TOPLEFT", PAD, -(1 + HEAD_H + 20))
	F.Body = body
	local what = card(body, "emblem", "accent", T("Qué es Alfa"))
	local win = card(body, "window", "accent", T("Tu ventana de Alfa"))
	local first = card(body, "guides", "accent", T("Tu primera guía"))
	first.Extra = para(first, "small", "textMuted", CARD_W - CARD_PAD * 2, 2)
	first.Action = W.Button(first, T("Elegir mi primera guía"), chooseGuide, { primary = true })
	F.Choose = first.Action
	local pack = card(body, "discord", "discord", T("La Jauría"))
	pack.Action = W.CopyBox(pack)
	pack.Action:SetWidth(CARD_W - CARD_PAD * 2)
	F.Discord = pack.Action
	F.Cards = { what, win, first, pack }

	-- The footer: the version on the left, the buttons on the right.
	local foot = CreateFrame("Frame", nil, F)
	foot:SetPoint("BOTTOMLEFT", F, "BOTTOMLEFT", 1, 1)
	foot:SetPoint("BOTTOMRIGHT", F, "BOTTOMRIGHT", -1, 1)
	foot:SetHeight(FOOT_H)
	W.Fill(foot, "footer")
	local frule = W.Divider(foot)
	frule:SetPoint("TOPLEFT", foot, "TOPLEFT", 0, 0)
	frule:SetPoint("TOPRIGHT", foot, "TOPRIGHT", 0, 0)
	F.Foot = foot
	F.Version = W.Text(foot, "small", "textMuted")
	F.Version:SetPoint("LEFT", foot, "LEFT", PAD, 0)
	F.Done = W.Button(foot, T("Listo"), close, { primary = true })
	F.Done:SetPoint("RIGHT", foot, "RIGHT", -PAD, 0)
	F.Open = W.Button(foot, T("Abrir la ventana de Alfa"), openAlfa)
	F.Open:SetPoint("RIGHT", F.Done, "LEFT", -8, 0)

	if W.Rim then F.Rim = W.Rim(F) end

	F:SetScript("OnShow", function(self)
		Anim.To(self, "alpha", 0, 1, Anim.BASE, "out")
		Anim.Anchor(body, "TOPLEFT", F, "TOPLEFT", PAD, -(1 + HEAD_H + 20))
		Anim.To(body, "offset", -6, 0, Anim.BASE, "out")
		Theme.RetextLater(self)
	end)
	-- Any close marks it seen, for the character and the account; stepping
	-- aside for the route choice does not, nor does a cinematic closing it
	-- (it comes back after the cinematic), nor Alfa hiding (its layer hides
	-- the window still open: it comes back as it was). A close tells the
	-- windows waiting for it (UI/WhatsNew.lua).
	F:SetScript("OnHide", function(self)
		if stepping or self:IsShown() then return end
		if inCinematic() then
			pending = "asked"
			return
		end
		ns.CharState().welcomeSeen = SEEN
		ns.DB().welcomeSeen = SEEN
		pending = nil
		ns.Fire("WELCOME_CLOSED")
	end)
	ns.CloseOnEscape("AlfaWelcome")
	WEL.frame = F
	-- A gamepad (UI/Gamepad.lua): A on Choose my first guide by default.
	-- Shown by itself, it waits for the player before it takes the gamepad.
	if ns.Gamepad and ns.Gamepad.Register then
		ns.Gamepad.Register(F, {
			unasked = function() return unasked end,
			initial = function(rows)
				for i, w in ipairs(rows) do if w == F.Choose then return i end end
			end,
		})
	end
end

-- Fills the texts (the theme's colours, the player's name, the suggested
-- guide) and lays the cards out, each row as tall as its tallest card.
local function render()
	local name = UnitName and UnitName("player")
	local hello = known(name) and string.format(T("¡Hola, %s!"), name) or T("¡Hola!")
	F.Hello:SetText(hello .. " " .. T("Te damos la bienvenida a Alfa, el todo en uno de La Jauría."))
	local stageW = W.SetStageChip(F.Stage)
	F.Stage:SetShown(stageW > 0)

	local what, win, first, pack = F.Cards[1], F.Cards[2], F.Cards[3], F.Cards[4]
	what.Text:SetText(T("Un solo addon con todo lo que usas al jugar: guías paso a paso con flecha y ruta, mapa, bolsas, builds, curación con clic, recolección, mazmorras, pesca y comercio. Todo con el mismo estilo."))
	win.Text:SetText(string.format(T("Escribe %s o haz clic en el lobo del minimapa para abrirla. Empieza en Hoy, con lo que toca a tu clase; %s muestra u oculta la ventana de guía."),
		cmd("/alfa"), cmd("/alfa guia")))
	first.Text:SetText(T("Alfa te lleva paso a paso, con la flecha y la ruta en el mapa. Elige la de tu zona y tu nivel."))
	local sug = suggested()
	first.Extra:SetText(sug and string.format(T("Sugerida para ti: %s"), cmd(sug)) or "")
	first.Extra:SetShown(sug ~= nil)
	pack.Text:SetText(T("Nuestra manada en Discord: ayuda, avisos y reportes. Haz clic en el enlace y cópialo con Ctrl+C."))
	W.SetCopyText(pack.Action, ns.DiscordURL or "")
	pack.Action:SetHeight(30)

	local y = 0
	for row = 0, 1 do
		local a, b = F.Cards[row * 2 + 1], F.Cards[row * 2 + 2]
		local h = max(cardHeight(a), cardHeight(b))
		for i, c in ipairs({ a, b }) do
			c:SetHeight(h)
			Theme.Repaint(c)
			place(c, (i - 1) * (CARD_W + GAP), y)
		end
		y = y + h + GAP
	end
	local bodyH = y - GAP
	F.Body:SetHeight(max(1, bodyH))
	F.Version:SetText(L["Version"] .. " " .. tostring(ns.version or "dev"))
	F:SetHeight(1 + HEAD_H + 20 + bodyH + 24 + FOOT_H + 1)
	if F.Rim and W.LayoutRim then W.LayoutRim(F) end
end

local try -- forward; defined below

-- Wait for the route choice to close (not for Alfa hiding it with the
-- rest: it stays open then), then try again.
local function afterRouteChoice()
	local RC = UI.RouteChoice
	if not hookedRC and RC and RC.frame then
		hookedRC = true
		RC.frame:HookScript("OnHide", function(self) if not self:IsShown() then try() end end)
	end
end

-- Open now, or as soon as combat and the route choice allow. deferred:
-- opened by itself (at login, or after the fight or the route choice that
-- held it back), not on request.
local function open(why, deferred)
	if inCombat() or inCinematic() then
		pending = pending == "asked" and "asked" or why
		return
	end
	if routeChoiceUp() then
		pending = pending == "asked" and "asked" or why
		afterRouteChoice()
		return
	end
	pending = nil
	if why == "login" then
		ns.CharState().welcomeSeen = SEEN -- shown: a reload or logout from here does not repeat it
	end
	-- Alfa: con la bienvenida reemplazada (SHOW_WELCOME, Core/Reemplazos.lua)
	-- se abre la de Alfa; al cerrarse llama a pedido.Listo() (WELCOME_CLOSED).
	local R = ns.Reemplazos
	if R and R.Llamar("SHOW_WELCOME", { motivo = why, solo = deferred and true or false,
		Listo = function() ns.Fire("WELCOME_CLOSED") end }) then
		if F then F:Hide() end
		return
	end
	if not F then build() end
	unasked = deferred and true or false
	render()
	F:Show()
	F:Raise()
end

-- Open the welcome (About, /alfa welcome, the preview), even when already
-- seen. `page` is kept for its callers: the welcome is one page now.
function WEL.Show(page)
	open("asked")
end

function WEL.Hide()
	pending = nil
	if F then F:Hide() end
end

function WEL.IsShown()
	return (F ~= nil and F:IsShown()) or ns.ReemplazoVisible("SHOW_WELCOME") == true
end

-- Up, or due and waiting (for the login delay, a fight, a cinematic or the
-- route choice): a window that must not open over it waits for
-- WELCOME_CLOSED.
function WEL.Busy()
	return WEL.IsShown() or pending ~= nil
end

-- The welcome's pieces, for the windows in its look (UI/WhatsNew.lua): its
-- cards, wrapped text, placing, colours and measures.
WEL.Kit = {
	card = card, cardHeight = cardHeight, para = para, place = place, colored = colored, cmd = cmd,
	WIDTH = WIDTH, INNER = INNER, CW = CW, PAD = PAD, GAP = GAP, CARD_W = CARD_W, CARD_PAD = CARD_PAD,
	HEAD_H = HEAD_H, FOOT_H = FOOT_H, EMBLEM = EMBLEM,
}

-- The page shown: its key, its place and the number of pages, its title.
function WEL.Page()
	if not F then return nil end
	return "welcome", 1, 1, T("Bienvenida a Alfa")
end

function try()
	if pending == "asked" or (pending and not seen()) then open(pending, true) end
end

-- A route choice opened over the welcome: step aside, come back after it.
local function yieldToRouteChoice()
	if not (F and F:IsShown() and routeChoiceUp()) then return end
	stepping = true
	F:Hide()
	stepping = nil
	pending = "asked"
	afterRouteChoice()
end

-- The character's flag, set as the addon loads: due (0) for a new character,
-- seen for one Alfa already knew, so only new characters get it unasked.
ns.OnInit(function()
	local s = ns.CharState()
	if s.welcomeSeen == nil then s.welcomeSeen = ns.IsNewCharacter() and 0 or SEEN end
end)

ns.OnLogin(function()
	local db = ns.DB()
	db.betaNoticeSeen = nil -- the old beta notice's flag; the welcome has its own
	if seen() then return end
	pending = "login"
	if C_Timer and C_Timer.After then ns.After(DELAY, try) else try() end
end)

-- RouteChoice.lua registers first, so its window is already up (or still
-- waiting out combat) when these run.
ns.RegisterEvent("PLAYER_REGEN_ENABLED", function()
	yieldToRouteChoice()
	try()
end)
-- After a cinematic, once the UI is back.
ns.RegisterEvent("CINEMATIC_STOP", function()
	if C_Timer and C_Timer.After then ns.After(1, try) else try() end
end)
ns.On("ROUTE_CHOICE", yieldToRouteChoice)
-- Una eleccion de ruta de Alfa (ROUTE_CHOICE reemplazada) que se cierra: la
-- bienvenida que esperaba sale ahora.
ns.On("ROUTE_CHOICE_HIDDEN", function() try() end)
ns.On("SHOW_WELCOME", function(page) WEL.Show(page) end)
-- A theme or language change: the texts and the cards again.
Theme.OnChanged(function()
	if F and F:IsShown() then render() end
end)
