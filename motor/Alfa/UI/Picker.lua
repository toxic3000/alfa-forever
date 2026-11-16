-- El selector de guias y el centro de Alfa (la ventana AlfaPicker). Basado en
-- el menu de guias de Polestar (GPL-3.0, The Polestar authors); reescrito por
-- Toxic / La Jauria con la interfaz propia de Alfa (docs/INTERFAZ.md).
--
-- La ventana es el armazon de arriba, como la principal (W.Shell({ top =
-- true })): el lobo, ALFA, tu personaje con su experiencia, el buscador y la
-- X. Debajo, las secciones del centro en botones (Guias, Buscador, Mazmorras
-- y las que registren otros: Talentos, Raros, Personajes; a la derecha
-- Importar e "Inicio de Alfa", que abre la ventana principal). Bajo la
-- seccion, sus vistas en pildoras: lo que en Polestar era la barra lateral
-- de cada seccion (su `nav`); las que no caben se juntan en "Mas". Sin riel
-- ni barra lateral.
--
-- Guias (la seccion propia):
--   pildoras: Inicio (las pestanas abiertas para seguir y las recomendadas),
--     Todas, Abiertas, Recientes, Favoritas, Comunidad (los paquetes de otros
--     jugadores; con varios, un menu) y Mis rutas (el paquete "mis-rutas" de
--     Alfa - Rutas). A la derecha de las pildoras, lo que muestra la lista.
--   barra de filtros: faccion (ui.pickerFaction), zona o raza, nivel, tipo
--     (las categorias del formato de guias) y "Para tu nivel"; "Quitar
--     filtros" mientras haya alguno. Cambiar un filtro lleva a Todas.
--   la lista, en tarjetas de esquinas cortadas de dos en dos bajo carpetas
--     (subir de nivel por faccion y tramo, "Horda 30-40"; lo demas por
--     categoria): nombre (P.Titles: el de la raza o la faccion cuando dos se
--     llaman igual), rango de niveles, zona, y sus etiquetas: Recomendada
--     para ti (la primera de Guides.Suggestions), Para tu nivel, Grupo (el
--     `group` compilado), Desde el nivel N (Engine.StartGate), Terminada; a
--     la derecha, la pestana donde esta abierta. En Todas, sin busqueda, las
--     carpetas se pliegan (clic, o A en el mando; ui.pickerCollapsed, de toda
--     la cuenta; al abrir, la carpeta de la guia abierta se despliega). Solo
--     se dibujan las tarjetas a la vista.
--   Inicio: las pestanas abiertas en tarjetas con su paso y su avance (la
--     activa primero, luego las usadas hace poco; "Ver todas (N)" para el
--     resto), que se cierran con su X, su menu del clic derecho (Cerrar
--     pestana, Mover a la izquierda, a la derecha) o Y en el mando; y las
--     recomendadas (Guides.Suggestions y a donde llevan las pestanas
--     abiertas, un nivel antes).
--   la ficha, a la derecha: el arte de la zona con sus esquinas cortadas, el
--     nombre, la favorita (estrella), las etiquetas (niveles, lo que valen
--     sus entregas en niveles con su panel al pasar el raton, UI/LevelTip.lua;
--     grupo, faccion, razas, clases), el avance, los datos (lo que da una
--     guia de clase con el tooltip del juego, por que, el aviso de la
--     mision de clase, pasos, misiones, zonas en orden, lo que sigue), los
--     creditos, la presentacion, pros y contras, y los botones "Usar esta
--     guia" (en la pestana de ahora; "Continuar" en una ya abierta) y
--     "Pestana nueva".
--
-- Elegir muestra la ficha; cargar es explicito: los botones, el doble clic o
-- Enter en el buscador. Abierto desde el + de la ventana de guia
-- (UI.ShowPicker({ newTab = true })), cargar abre una pestana nueva.
--
-- Por personaje, en CharState().ui: recentGuides (las ultimas 10 cargadas),
-- favoriteGuides ({ [id] = true }) y pickerSelected (la ultima elegida).
--
-- UI.HubKit, abajo, son las piezas que comparten las secciones del centro
-- (el Buscador, las Mazmorras): tarjetas, carpetas, pildoras de filtro, la
-- rejilla de opciones y el arte con esquinas cortadas.

local ADDON, ns = ...
local UI, Theme, W = ns.UI, ns.Theme, ns.Widgets
local L = ns.L
local T = ns.T
local floor, ceil, max, min, type, ipairs, pairs, tostring, format = math.floor, math.ceil, math.max, math.min, type, ipairs, pairs, tostring, string.format
local ZoneArt = UI.ZoneArt
local readable = ns.Compat.Readable

local SH = W.SHELL

-- The hub's grid (docs/INTERFAZ.md): a window of HUB_W x HUB_H; under the
-- pills a section has HUB_W - 2 by HUB_H - 2 - header - nav - pills.
local HUB_W, HUB_H = 1120, 700
local PAD, GAP = 24, 16 -- the list's left edge; between the list and the ficha, and to the window's edge
local DETAIL_W = 352 -- the ficha, right
local TOOL_H = 44 -- the filter bar under the pills
local LIST_W = HUB_W - 2 - PAD - GAP - DETAIL_W - GAP -- the cards' column
local LIST_X = 8 -- the cards' left edge in the list's scroll child (the scroll starts PAD - LIST_X in)
local COL_GAP = 12
local CARD_H, CONT_H, FOLDER_H = 76, 80, 32
local CARD_TX = 14 -- text inset inside a card
local DPAD = 16 -- the ficha's inset
local INNER = DETAIL_W - DPAD * 2
local ART_H = 100
local FACT_W, FACT_GAP = 84, 8
local RECENT_MAX = 10
local SUGGEST_MAX = 5
local DOT = "  \194\183  "
-- "›", not "→": many fonts the window may follow have no arrow glyph.
local ARROW, ELLIPSIS = " \226\128\186 ", "\226\128\166"

local P = {}
UI.Picker = P
P.RECENT_MAX = RECENT_MAX

---------------------------------------------------------------------------
-- El kit del centro (UI.HubKit)
---------------------------------------------------------------------------

local Kit = {}
UI.HubKit = Kit
Kit.HUB_W, Kit.HUB_H = HUB_W, HUB_H
Kit.PAD, Kit.GAP, Kit.DETAIL_W, Kit.TOOL_H, Kit.COL_GAP, Kit.FOLDER_H = PAD, GAP, DETAIL_W, TOOL_H, COL_GAP, FOLDER_H
Kit.DOT = DOT

-- A card: its ground and hairline in the skin's cut, the hover wash in the
-- same shape and, on the chosen one, the accent line along its top after the
-- cut (the windows' mark). c.psRow: a list row (no ground nor line until
-- chosen); c.psGround: another resting ground than "panel".
function Kit.PaintCard(c)
	local tl, br = Theme.CutsOf(c, "tile")
	c.Ground:SetCut(tl, br)
	c.Lit:SetCut(tl, br)
	c.Lit:SetColor(Theme.Wash("hover"))
	local on, row = c.psOn, c.psRow
	if row and not on then
		c.Ground:Hide()
	else
		c.Ground:Show()
		c.Ground:SetColor(Theme.Color(on and "panelAlt" or (c.psGround or "panel")))
	end
	if on then
		local r, g, b = Theme.Accent()
		Theme.CutBorder(c, tl, br, r, g, b, row and 0.55 or 0.9)
	elseif row then
		local e = rawget(c, "psCutBorder")
		if e then
			for i = 1, 4 do e.edges[i]:Hide() end
			for i = 1, #e.diag do e.diag[i]:Hide() end
		end
	else
		local r, g, b = Theme.Color("line")
		Theme.CutBorder(c, tl, br, r, g, b, 1)
	end
	c.Mark:ClearAllPoints()
	c.Mark:SetPoint("TOPLEFT", c, "TOPLEFT", tl + 6, 0)
	c.Mark:SetShown((on and not row) and true or false)
	if c.psPicture then Kit.PaintPicture(c.psPicture) end
end

function Kit.Card(parent, frameType)
	local c = CreateFrame(frameType or "Button", nil, parent)
	c.Ground = Theme.CutShape(c, 8, 8, "BACKGROUND", -7)
	c.Lit = Theme.CutShape(c, 8, 8, "HIGHLIGHT", 0)
	c.Mark = W.Tex(c, "OVERLAY", nil, "accent")
	c.Mark:SetSize(28, 2)
	c.psOn = false
	W.Painter(c, Kit.PaintCard)
	return c
end

-- Chosen or not; painted only when that changes.
function Kit.SetCard(c, on)
	on = on and true or false
	if c.psOn == on then return end
	c.psOn = on
	Kit.PaintCard(c)
end

-- A picture (zone art) inset on a surface, with the surface's two corners
-- cut out of it: two triangles in the surface's colour (token) over it.
function Kit.PaintPicture(art)
	local o = art.psCorners
	if not o then return end
	local c = Theme.SkinKey() == "alfa" and (art.psCornerSize or Theme.CUT.control) or 0
	local r, g, b = Theme.Color(art.psCornerToken or "panel")
	for _, t in ipairs({ o.tl, o.br }) do
		t:SetSize(max(c, 0.01), max(c, 0.01))
		t:SetVertexColor(r, g, b, 1)
		t:SetShown(c > 0)
	end
end

function Kit.CutPicture(art, token, size)
	local o = art.psCorners
	if not o then
		local host = art.Over or art
		o = { tl = host:CreateTexture(nil, "OVERLAY", nil, 7), br = host:CreateTexture(nil, "OVERLAY", nil, 7) }
		o.tl:SetTexture(Theme.Media("cut"))
		o.tl:SetTexCoord(1, 0, 1, 0)
		o.tl:SetPoint("TOPLEFT", art, "TOPLEFT", 0, 0)
		o.br:SetTexture(Theme.Media("cut"))
		o.br:SetPoint("BOTTOMRIGHT", art, "BOTTOMRIGHT", 0, 0)
		art.psCorners = o
		W.Painter(o, function() Kit.PaintPicture(art) end)
	end
	art.psCornerToken, art.psCornerSize = token or "panel", size
	if art.Rule then art.Rule:Hide() end
	Kit.PaintPicture(art)
	return art
end

-- Chips in a row from x on line y of `owner` (a card), up to `right`.
-- list: { { text, kind }, ... }; pool: the owner's chips. -> the x after them
function Kit.PlaceChips(owner, pool, list, x, y, right)
	local n = 0
	for _, spec in ipairs(list) do
		local c = pool[n + 1]
		if not c then
			c = W.Chip(owner)
			pool[n + 1] = c
		end
		local w = W.SetChip(c, spec[1], spec[2])
		if x + w > right and n > 0 then
			c:Hide()
			break
		end
		n = n + 1
		c:ClearAllPoints()
		c:SetPoint("TOPLEFT", owner, "TOPLEFT", x, -y)
		x = x + w + 6
	end
	for i = n + 1, #pool do pool[i]:Hide() end
	return x
end

-- A folder header over cards: the heading, a hairline after it, the count at
-- the right; a foldable one carries a chevron (down while open, right while
-- folded) and a click.
function Kit.Folder(parent)
	local f = CreateFrame("Button", nil, parent)
	f:SetHeight(FOLDER_H)
	f.Text = W.Text(f, "heading", "textDim")
	f.Text:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 9)
	f.Count = W.Text(f, "number", "textMuted")
	f.Count:SetJustifyH("RIGHT")
	f.Chevron = W.Tex(f, "ARTWORK", "chevron-down", "textMuted")
	f.Chevron:SetSize(12, 12)
	f.Rule = W.Divider(f)
	f:SetScript("OnEnter", function(self)
		if not self.psFoldable then return end
		W.Color(self.Text, "text")
		W.Color(self.Chevron, "text")
		W.SimpleTip(self)
	end)
	f:SetScript("OnLeave", function(self)
		W.Color(self.Text, "textDim")
		W.Color(self.Chevron, "textMuted")
		W.HideTip(self)
	end)
	return f
end

function Kit.SetFolder(f, text, count, foldable, collapsed)
	f.Text:SetText(text or "")
	f.Count:SetText(count or "")
	f.psFoldable = foldable and true or false
	f.Chevron:ClearAllPoints()
	f.Count:ClearAllPoints()
	if foldable then
		f.Chevron:SetTexture(Theme.Media(collapsed and "chevron-right" or "chevron-down"))
		f.Chevron:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 10)
		f.Chevron:Show()
		f.Count:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -22, 9)
	else
		f.Chevron:Hide()
		f.Count:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 9)
	end
	f.Rule:ClearAllPoints()
	f.Rule:SetPoint("LEFT", f.Text, "RIGHT", 12, 0)
	f.Rule:SetPoint("RIGHT", f.Count, "LEFT", -10, 0)
	f.psTip = foldable and (collapsed and L["Expand"] or L["Collapse"]) or nil
	f.psPadLabel = f.psTip
	f.psPadSkip = (not foldable) or nil
	f:EnableMouse(f.psFoldable)
	W.Color(f.Text, "textDim")
	W.Color(f.Chevron, "textMuted")
end

-- A filter pill: a capsule edged in the line colour with its value and,
-- for a list, a chevron; edged in the accent while it filters (active), filled
-- with it while a toggle is on (on).
local FILTER_H = 26
local function paintFilter(b)
	local lit = b.psLit
	if b.psOn then
		local r, g, bb = Theme.Accent()
		b.Edge:SetColor(r, g, bb, 1)
		b.Inner:SetColor(r, g, bb, 1)
		local ir, ig, ib = Theme.Color("onAccent")
		W.Uncolor(b.Label)
		b.Label:SetTextColor(ir, ig, ib, 1)
		W.Uncolor(b.Icon)
		b.Icon:SetVertexColor(ir, ig, ib, 1)
		W.Uncolor(b.Chevron)
		b.Chevron:SetVertexColor(ir, ig, ib, 1)
	elseif b.psActive then
		local r, g, bb = Theme.Accent()
		b.Edge:SetColor(r, g, bb, lit and 1 or 0.8)
		b.Inner:SetColor(Theme.Color(lit and "panelAlt" or "panel"))
		W.Color(b.Label, "accent")
		W.Color(b.Icon, "accent")
		W.Color(b.Chevron, "accent")
	else
		b.Edge:SetColor(Theme.Color(lit and "lineStrong" or "line"))
		b.Inner:SetColor(Theme.Color(lit and "panelAlt" or "panel"))
		W.Color(b.Label, lit and "text" or "textDim")
		W.Color(b.Icon, lit and "text" or "textDim")
		W.Color(b.Chevron, lit and "text" or "textMuted")
	end
	Theme.SetShadow(b.Label, not b.psOn)
end

function Kit.FilterPill(parent, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(FILTER_H)
	b.psKey = "filter" -- not a guide row for the gamepad's first focus
	b.Edge = W.Pill(b, 40, FILTER_H)
	b.Edge:SetAllPoints(b)
	b.Inner = W.Pill(b, 38, FILTER_H - 2)
	b.Inner:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
	b.Inner:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
	b.Inner:SetFrameLevel(b.Edge:GetFrameLevel() + 1)
	b.Icon = b.Inner:CreateTexture(nil, "OVERLAY")
	b.Icon:SetSize(12, 12)
	b.Label = W.Text(b.Inner, "label", "textDim")
	b.Chevron = b.Inner:CreateTexture(nil, "OVERLAY")
	b.Chevron:SetTexture(Theme.Media("chevron-down"))
	b.Chevron:SetSize(10, 10)
	b.psOnClick = onClick
	b:SetScript("OnClick", function(self) if self.psOnClick then self.psOnClick(self) end end)
	b:SetScript("OnEnter", function(self)
		self.psLit = true
		paintFilter(self)
		W.SimpleTip(self)
	end)
	b:SetScript("OnLeave", function(self)
		self.psLit = false
		paintFilter(self)
		W.HideTip(self)
	end)
	W.Painter(b, paintFilter)
	return b
end

-- opts: { icon, menu (it opens a list: a chevron), active, on } -> the width
function Kit.SetFilterPill(b, text, opts)
	opts = opts or {}
	b.psActive, b.psOn = opts.active and true or false, opts.on and true or false
	local x = 12
	b.Icon:ClearAllPoints()
	if opts.icon then
		b.Icon:SetTexture(Theme.Media(opts.icon))
		b.Icon:SetPoint("LEFT", b, "LEFT", x, 0)
		b.Icon:Show()
		x = x + 12 + 6
	else
		b.Icon:Hide()
	end
	b.Label:ClearAllPoints()
	b.Label:SetPoint("LEFT", b, "LEFT", x, 0)
	x = x + ceil(W.TextWidth(b.Label, text or ""))
	b.Chevron:ClearAllPoints()
	if opts.menu then
		b.Chevron:SetPoint("LEFT", b, "LEFT", x + 6, 0)
		b.Chevron:Show()
		x = x + 6 + 10
	else
		b.Chevron:Hide()
	end
	b:SetWidth(x + 12)
	paintFilter(b)
	b:Show()
	return x + 12
end

-- The choice grid: a panel of options in columns under its pill, for lists
-- too long for the menu (zones). groups: { { title, items = { { text, count,
-- checked, onClick } } }, ... }; the columns fill top down.
local grid
local GRID_ROW, GRID_COL_MIN, GRID_COL_MAX = 24, 150, 230

function Kit.HideGrid()
	if grid and grid:IsShown() then grid:Hide() end
end

local function buildGrid()
	local catcher = CreateFrame("Button", nil, UIParent)
	catcher:SetAllPoints(UIParent)
	catcher:SetFrameStrata("FULLSCREEN_DIALOG")
	catcher:SetFrameLevel(1)
	catcher:RegisterForClicks("AnyUp")
	catcher:SetScript("OnClick", Kit.HideGrid)
	catcher:Hide()
	grid = CreateFrame("Frame", "AlfaHubGrid", UIParent)
	grid:SetFrameStrata("FULLSCREEN_DIALOG")
	grid:SetFrameLevel(20)
	grid:SetClampedToScreen(true)
	grid:EnableMouse(true)
	grid.psCut = Theme.CUT.control
	Theme.Skin(grid, "panel")
	grid.Catcher = catcher
	grid.heads, grid.items = {}, {}
	grid.Probe = W.Text(grid, "label", "text")
	grid.Probe:Hide()
	grid:SetScript("OnHide", function() catcher:Hide() end)
	grid:Hide()
	ns.CloseOnEscape("AlfaHubGrid")
	if ns.Gamepad and ns.Gamepad.Register then
		ns.Gamepad.Register(grid, {
			rows = function()
				local out = {}
				for _, b in ipairs(grid.items) do if b:IsShown() then out[#out + 1] = b end end
				return out
			end,
			initial = function(rows)
				for i, b in ipairs(rows) do if b.psItem and b.psItem.checked then return i end end
			end,
			back = Kit.HideGrid,
		})
	end
end

local function gridItem(i)
	local b = grid.items[i]
	if b then return b end
	b = CreateFrame("Button", nil, grid)
	b:SetHeight(GRID_ROW)
	W.Hover(b)
	b.Check = W.Tex(b, "ARTWORK", "check", "accent")
	b.Check:SetSize(10, 10)
	b.Check:SetPoint("LEFT", b, "LEFT", 6, 0)
	b.Text = W.Text(b, "label", "textDim")
	b.Text:SetPoint("LEFT", b, "LEFT", 22, 0)
	b.Count = W.Text(b, "number", "textMuted")
	b.Count:SetJustifyH("RIGHT")
	b.Count:SetPoint("RIGHT", b, "RIGHT", -8, 0)
	b:SetScript("OnClick", function(self)
		local it = self.psItem
		Kit.HideGrid()
		if it and it.onClick then it.onClick(it) end
	end)
	b:SetScript("OnEnter", function(self) if not (self.psItem and self.psItem.checked) then W.Color(self.Text, "text") end end)
	b:SetScript("OnLeave", function(self) W.Color(self.Text, (self.psItem and self.psItem.checked) and "accent" or "textDim") end)
	grid.items[i] = b
	return b
end

function Kit.ShowGrid(anchor, groups, opts)
	if not grid then buildGrid() end
	opts = opts or {}
	W.HideMenu()
	local total, colW = 0, GRID_COL_MIN
	for _, g in ipairs(groups) do
		for _, it in ipairs(g.items or {}) do
			total = total + 1
			colW = max(colW, ceil(W.TextWidth(grid.Probe, it.text or "")) + 22 + (it.count and 36 or 10))
		end
	end
	colW = min(colW, GRID_COL_MAX)
	local cols = opts.columns or min(4, max(1, ceil(total / 12)))
	local y, ni, nh = -10, 0, 0
	for _, g in ipairs(groups) do
		local items = g.items or {}
		if #items > 0 then
			if g.title then
				nh = nh + 1
				local h = grid.heads[nh]
				if not h then
					h = W.Text(grid, "small", "textMuted")
					grid.heads[nh] = h
				end
				h:SetText(g.title)
				h:ClearAllPoints()
				h:SetPoint("TOPLEFT", grid, "TOPLEFT", 14, y - 4)
				h:Show()
				y = y - 22
			end
			local c = min(cols, #items)
			local rows = ceil(#items / c)
			for k, it in ipairs(items) do
				ni = ni + 1
				local b = gridItem(ni)
				local col, row = floor((k - 1) / rows), (k - 1) % rows
				b.psItem = it
				b.Text:SetText(it.text or "")
				b.Text:SetWidth(colW - 22 - (it.count and 36 or 10))
				b.Count:SetText(it.count and tostring(it.count) or "")
				b.Check:SetShown(it.checked and true or false)
				W.Color(b.Text, it.checked and "accent" or "textDim")
				b:SetWidth(colW)
				b:ClearAllPoints()
				b:SetPoint("TOPLEFT", grid, "TOPLEFT", 8 + col * colW, y - row * GRID_ROW)
				b:Show()
			end
			y = y - rows * GRID_ROW - 8
		end
	end
	for i = ni + 1, #grid.items do grid.items[i]:Hide() end
	for i = nh + 1, #grid.heads do grid.heads[i]:Hide() end
	grid:SetSize(16 + cols * colW, -y + 2)
	grid:ClearAllPoints()
	grid:SetPoint(opts.point or "TOPLEFT", anchor, opts.relPoint or "BOTTOMLEFT", opts.x or 0, opts.y or -4)
	grid.psOwner = anchor
	grid.Catcher:Show()
	grid:Show()
	grid:Raise()
	return grid
end

function Kit.GridShown(owner)
	return grid and grid:IsShown() and (not owner or grid.psOwner == owner) or false
end

ns.On("ALFA_HIDDEN", function(hidden) if hidden then Kit.HideGrid() end end)

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local win, gv, details -- the hub, the Guides view, its ficha
local factCache = {} -- guide id -> { quests, zones } (guideFacts)
local folderPool, cardPool, contPool = {}, {}, {}
local query = ""
local questContext -- { id, query, steps = { [guideId] = matching steps } }
local category = "All"
local view = "home" -- "home" | "current" | "recent" | "browse"
local newTabMode = false
local visibleIds = {} -- guide ids in the list, in reading order (arrow keys)
local allCards = false -- "Show all (N)": every open tab's card, not one row; this session
local layout = {} -- the list as laid out: { t = "folder"|"card"|"cont", x, y, w, h, ... }
-- The list's filters (this session): place ("zone:<name>" | "race:<file>"),
-- the level band's key, and "for your level".
local place, lband, fits = nil, nil, false
local suggested = {} -- guide id -> its rank in Guides.Suggestions, this render
local curLevel -- the character's level, this render

local FACTIONS = { "Alliance", "Horde", "All" }
local VIEWS = { "home", "browse", "current", "recent" }
-- The views' pills, in Spanish (ns.T at render: the core's languages load after this file).
local VIEW_LABEL = { home = "Inicio", browse = "Todas", current = "Abiertas", recent = "Recientes" }

-- The guide format's categories, in the order players look for them.
local CATEGORIES = { "Leveling", "Class", "Professions", "Reputation", "Exploration", "Legacy", "Collectibles", "Miscellaneous" }
P.CATEGORIES = CATEGORIES
local CATEGORY_RANK = {}
for i, c in ipairs(CATEGORIES) do CATEGORY_RANK[c] = i end
local CATEGORY_ICON = {
	Leveling = "icon-level", Class = "icon-train", Professions = "icon-craft", Reputation = "icon-rep", Exploration = "icon-explore",
	Legacy = "icon-achieve", Collectibles = "icon-collect", Miscellaneous = "icon-treasure", Favorites = "star",
}
P.CATEGORY_ICON = CATEGORY_ICON

-- The list's level bands.
local LEVEL_BANDS = {
	{ key = "1", lo = 1, hi = 10 }, { key = "10", lo = 10, hi = 20 }, { key = "20", lo = 20, hi = 30 },
	{ key = "30", lo = 30, hi = 40 }, { key = "40", lo = 40, hi = 50 }, { key = "50", lo = 50, hi = 60 },
}
P.LEVEL_BANDS = LEVEL_BANDS

local categoryOf = UI.Category

-- Community guide packs: their guides are not in our categories but under
-- their pack (key "pack:<id>"); Alfa - Rutas' "mis-rutas" pack is "Mis rutas".
local PACK = "pack:"
local MIS_RUTAS = "mis-rutas"
P.MIS_RUTAS = MIS_RUTAS

-- The community pack a guide (header) comes from; nil for ours (`guides`)
-- and Alfa's internal packs.
local function packOf(g)
	local id = g and g.pack
	if id == nil or id == "guides" then return nil end
	local G = ns.Guides
	local r = G and G.Pack and G.Pack(id)
	if r and not r.internal then return r end
	return nil
end
P.PackOf = packOf

-- Where a guide is listed: its pack's entry, else its category.
local function bucketOf(g)
	local r = packOf(g)
	return r and (PACK .. r.id) or categoryOf(g)
end

-- The pack record behind a "pack:<id>" key, or nil.
local function packOfKey(key)
	if type(key) ~= "string" or key:sub(1, #PACK) ~= PACK then return nil end
	local G = ns.Guides
	return G and G.Pack and G.Pack(key:sub(#PACK + 1)) or nil
end

-- A category's or a pack entry's name. The "Favorites" key is shown as
-- "Favourites".
local function bucketLabel(key)
	if key == "Favorites" then return L["Favourites"] end
	local r = packOfKey(key)
	return r and (r.title or r.id) or L[key]
end

local function categoryLess(a, b)
	local ra, rb = CATEGORY_RANK[a] or 100, CATEGORY_RANK[b] or 100
	if ra ~= rb then return ra < rb end
	return a < b
end

local function factionFilter()
	local f = ns.Get("ui.pickerFaction")
	if f == "auto" or f == nil then f = UI.PlayerFaction() or "All" end
	return f
end

local function playerLevel()
	local C = ns.Compat
	if not (C and C.GetPlayerInfo) then return nil end
	local ok, info = pcall(C.GetPlayerInfo)
	return ok and type(info) == "table" and info.level or nil
end

---------------------------------------------------------------------------
-- Character state: recent guides, favourites, the last selection
---------------------------------------------------------------------------

local function uiState()
	local s = ns.CharState()
	local u = s.ui
	if type(u) ~= "table" then
		u = {}
		s.ui = u
	end
	if type(u.recentGuides) ~= "table" then u.recentGuides = {} end
	if type(u.favoriteGuides) ~= "table" then u.favoriteGuides = {} end
	return u
end

function P.Recent() return uiState().recentGuides end

local function remember(id)
	if type(id) ~= "string" then return end
	local list = uiState().recentGuides
	for i = #list, 1, -1 do
		if list[i] == id then table.remove(list, i) end
	end
	table.insert(list, 1, id)
	for i = #list, RECENT_MAX + 1, -1 do list[i] = nil end
end

function P.IsFavorite(id) return id ~= nil and uiState().favoriteGuides[id] == true end

function P.ToggleFavorite(id)
	if not id then return end
	local favs = uiState().favoriteGuides
	favs[id] = (not favs[id]) and true or nil
	P.Render()
end

---------------------------------------------------------------------------
-- Model: the browse list, grouped into folders
---------------------------------------------------------------------------

local function haystack(g)
	local c = categoryOf(g)
	local parts = { g.title or "", g.zoneName or "", c, L[c], g.id or "", g.folder or "" }
	if type(g.keywords) == "table" then
		for _, k in ipairs(g.keywords) do parts[#parts + 1] = k end
	end
	if type(g.races) == "table" then
		for _, r in ipairs(g.races) do parts[#parts + 1] = r; parts[#parts + 1] = UI.RaceName(r) end
	end
	if type(g.classes) == "table" then
		for _, cl in ipairs(g.classes) do parts[#parts + 1] = cl; parts[#parts + 1] = UI.ClassName(cl) end
	end
	return table.concat(parts, " "):lower()
end

-- Match IDs, not translated titles: two quests can share a name.
local function questSteps(g)
	local cached = questContext.steps[g.id]
	if cached then return cached end
	local G, C = ns.Guides, ns.Compat
	local full = G.Get(g.id)
	local player = C.GetPlayerInfo()
	local found = {}
	questContext.steps[g.id] = found
	if not full or (G.GuideMatches and not G.GuideMatches(g, player) and not (G.OtherStart and G.OtherStart(g, player))) then return found end
	local function applies(only) return not G.Matches or G.Matches(only, player) end
	for i, step in ipairs(full.steps or {}) do
		if applies(step.only) then
			for _, goal in ipairs(step.goals or {}) do
				if goal.quest == questContext.id and applies(goal.only) then
					found[#found + 1] = { index = i, step = step }
					break
				end
			end
		end
	end
	return found
end

local function matches(g, q)
	if questContext and q == questContext.query:lower() then return #questSteps(g) > 0 end
	if q == "" then return true end
	local hay = haystack(g)
	for word in q:gmatch("%S+") do
		if not hay:find(word, 1, true) then return false end
	end
	return true
end

-- A leveling guide's band: the id's band folder ("forever/horde/30-40/..."),
-- else from its first level (1-30, then by tens). -> low, high
local function band(g)
	for lo, hi in (g.id or ""):gmatch("/(%d+)%-(%d+)/") do return tonumber(lo), tonumber(hi) end
	local lv = g.minLevel or 1
	if lv < 30 then return 1, 30 end
	local lo = floor(lv / 10) * 10
	return lo, lo + 10
end
P.Band = band

-- Whether a guide's levels fit `level` (one level early, as the suggestions
-- come: FOLLOW_REACH).
local FOLLOW_REACH = 1 -- levels below a guide's minimum at which it shows
local function fitsLevel(g, level)
	if not level or not (g.minLevel or g.maxLevel) then return false end
	local lo = g.minLevel or g.maxLevel
	local hi = g.maxLevel or g.minLevel
	return lo <= level + FOLLOW_REACH and level <= hi
end
P.FitsLevel = fitsLevel

-- The list's filters on one guide: o = { place, band, fits, level }.
local function passes(g, o)
	if not o then return true end
	if o.place then
		local kind, v = o.place:match("^(%a+):(.*)$")
		if kind == "zone" then
			if UI.GuidePlace(g) ~= v then return false end
		elseif kind == "race" then
			local hit = false
			for _, r in ipairs(type(g.races) == "table" and g.races or {}) do if r == v then hit = true end end
			if not hit then return false end
		end
	end
	if o.band then
		local b
		for _, x in ipairs(LEVEL_BANDS) do if x.key == o.band then b = x end end
		if b then
			if not (g.minLevel or g.maxLevel) then return false end
			local lo, hi = g.minLevel or g.maxLevel, g.maxLevel or g.minLevel
			if not (lo < b.hi and hi >= b.lo) then return false end
		end
	end
	-- For your level: the guides that level you (leveling, class quests), not a
	-- profession's or a reputation's 1-60.
	if o.fits then
		local c = categoryOf(g)
		if not ((c == "Leveling" or c == "Class") and fitsLevel(g, o.level)) then return false end
	end
	return true
end

local FACTION_ORDER = { Alliance = 1, Horde = 2 }

-- The folder a guide is listed under -> label, sort key, id. A guide's own
-- `folder` wins; guides sharing it still sort by faction, then level. The
-- id names the folder whatever the client's language or the character's
-- faction (the collapsed folders are kept by it, account-wide).
local function folderOf(g, mine)
	local c = categoryOf(g)
	if type(g.folder) == "string" and g.folder ~= "" then
		return g.folder, string.format("%02d", CATEGORY_RANK[c] or 99) .. c .. "/" .. g.folder, c .. "/" .. g.folder
	end
	if c == "Leveling" then
		local lo, hi = band(g)
		local f = g.faction
		local rank = f == nil and 3 or (f == mine and 0 or (FACTION_ORDER[f] or 4))
		local label = (f and ns.FactionName(f) or L["Leveling"]) .. " " .. UI.LevelRange(lo, hi)
		return label, string.format("%02d%d%03d", CATEGORY_RANK.Leveling, rank, lo), "Leveling/" .. (f or "") .. "/" .. lo
	end
	return L[c], string.format("%02d", CATEGORY_RANK[c] or 99) .. c, c
end
local OTHER_STARTS = "Leveling/other-starts"

-- Same-titled guides in one list (#1358: the Dwarf's and the Gnome's "Dun
-- Morogh (1-12)") say whose they are: their races where those differ, else
-- their faction ("Zephras Isle (Horde)" beside the Alliance one). A title
-- with another level range needs nothing: the range tells them apart.
-- list: guide headers -> { [guide] = shown title }
local function racesOf(g)
	if type(g.races) ~= "table" or #g.races == 0 then return nil end
	local names = {}
	for i, r in ipairs(g.races) do names[i] = UI.RaceName(r) end
	local text = names[1]
	for i = 2, #names do text = string.format(L["%s, %s"], text, names[i]) end
	return text
end

function P.Titles(list)
	local same = {}
	for _, g in ipairs(list) do
		local k = (g.title or g.id or "") .. "\0" .. (g.minLevel or "") .. "-" .. (g.maxLevel or "")
		local s = same[k]
		if not s then
			s = {}
			same[k] = s
		end
		s[#s + 1] = g
	end
	local out = {}
	for _, s in pairs(same) do
		local races, factions = {}, {}
		for _, g in ipairs(s) do
			races[racesOf(g) or ""] = true
			factions[g.faction or ""] = true
		end
		local function count(t)
			local n = 0
			for _ in pairs(t) do n = n + 1 end
			return n
		end
		local byRace, byFaction = count(races) == #s, count(factions) == #s
		for _, g in ipairs(s) do
			local q = #s > 1 and ((byRace and racesOf(g)) or (byFaction and g.faction and ns.FactionName(g.faction))) or nil
			out[g] = q and string.format(L["%s (%s)"], g.title or g.id, q) or (g.title or g.id)
		end
	end
	return out
end

-- Browse folders the player folded away: { [folder id] = true }, account-wide.
function P.IsCollapsed(id)
	local t = ns.Get("ui.pickerCollapsed")
	return id ~= nil and type(t) == "table" and t[id] == true
end

function P.SetCollapsed(id, collapsed)
	if id == nil or P.IsCollapsed(id) == (collapsed and true or false) then return end
	local t, copy = ns.Get("ui.pickerCollapsed"), {}
	if type(t) == "table" then for k, v in pairs(t) do copy[k] = v end end
	copy[id] = collapsed and true or nil
	ns.Set("ui.pickerCollapsed", next(copy) and copy or nil)
end

function P.ToggleFolder(id) P.SetCollapsed(id, not P.IsCollapsed(id)) end

local function rankOfFaction(f, mine)
	if f == nil then return 3 end
	if f == mine then return 0 end
	return FACTION_ORDER[f] or 4
end

-- filter: faction ("Alliance" | "Horde" | "All"); q: search text; cat: a
-- category, "Favorites", "pack:<id>" or "All"; opts: the list's filters ({
-- place, band, fits, level }, optional). On the player's own faction only
-- the guides this character can follow are listed (none for other classes,
-- nor other races' but their starting zones: those, Guides.OtherStart, go in
-- an "Other starting zones" folder after the player's own levels 1-30); the
-- other faction and "All" list every guide.
-- -> entries { kind = "folder", text, count, id } | { kind = "guide", guide,
--    title (Titles), folder (the folder entry) },
--    number of guides listed, { [category] = matching guides, Favorites = n }
--    (before the category filter)
function P.Entries(filter, q, cat, opts)
	local G, C = ns.Guides, ns.Compat
	local list = G and G.List and G.List() or {}
	q = (q or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	cat = cat or "All"
	local mine = UI.PlayerFaction()
	local player
	if filter == mine and G and G.GuideMatches and C and C.GetPlayerInfo then
		local ok, info = pcall(C.GetPlayerInfo)
		if ok and type(info) == "table" then player = info end
	end
	local favs = uiState().favoriteGuides
	local counts, picked, other = { Favorites = 0 }, {}, {}
	for _, g in ipairs(list) do
		local hit = matches(g, q) and passes(g, opts)
		local okFaction = filter == "All" or g.faction == nil or g.faction == filter
		if okFaction and player and not G.GuideMatches(g, player) then
			if G.OtherStart and G.OtherStart(g, player) then other[g] = true else okFaction = false end
		end
		if hit and favs[g.id] then
			counts.Favorites = counts.Favorites + 1
			if cat == "Favorites" then picked[#picked + 1] = g end
		end
		if okFaction and hit then
			local c = bucketOf(g)
			counts[c] = (counts[c] or 0) + 1
			if cat == "All" or c == cat then picked[#picked + 1] = g end
		end
	end
	local key, label, fid = {}, {}, {}
	for _, g in ipairs(picked) do
		if other[g] then
			label[g], key[g], fid[g] = L["Other starting zones"], string.format("%02d0001~", CATEGORY_RANK.Leveling), OTHER_STARTS
		else
			label[g], key[g], fid[g] = folderOf(g, mine)
		end
	end
	table.sort(picked, function(a, b)
		if key[a] ~= key[b] then return key[a] < key[b] end
		local fa, fb = rankOfFaction(a.faction, mine), rankOfFaction(b.faction, mine)
		if fa ~= fb then return fa < fb end
		local la, lb = a.minLevel or 0, b.minLevel or 0
		if la ~= lb then return la < lb end
		-- Same first level: a guide that hands over to the other comes first,
		-- as it is played (a race's lead-in "(12)" before the shared "(12-16)").
		if a.next == b.id then return true end
		if b.next == a.id then return false end
		if categoryOf(a) == "Leveling" then return (a.id or "") < (b.id or "") end
		return (a.title or "") < (b.title or "")
	end)
	local titles = P.Titles(picked)
	local out, folder = {}, nil
	for _, g in ipairs(picked) do
		if label[g] ~= (folder and folder.text) then
			folder = { kind = "folder", text = label[g], count = 0, id = fid[g] }
			out[#out + 1] = folder
		end
		folder.count = folder.count + 1
		out[#out + 1] = { kind = "guide", guide = g, title = titles[g], folder = folder }
	end
	return out, #picked, counts
end

-- The id of the Browse folder a guide is listed under (every category, no
-- search, the faction filter as set), or nil where it is not listed.
function P.FolderOf(id)
	for _, e in ipairs((P.Entries(factionFilter(), "", "All"))) do
		if e.kind == "guide" and e.guide.id == id then return e.folder.id end
	end
	return nil
end

---------------------------------------------------------------------------
-- The list's filters
---------------------------------------------------------------------------

local function filterOpts()
	if not (place or lband or fits) then return nil end
	return { place = place, band = lband, fits = fits, level = playerLevel() }
end

function P.Filters() return { place = place, band = lband, fits = fits, faction = factionFilter(), category = category } end

-- Any filter of the list set (faction aside: it follows the character).
local function filtered()
	return place ~= nil or lband ~= nil or fits or (category ~= "All" and category:sub(1, #PACK) ~= PACK and category ~= "Favorites")
end

-- A filter set or cleared takes the list to Todas.
local function toBrowse()
	view = "browse"
	if win and win:IsShown() then
		W.ScrollTo(gv.List, 0)
		P.Render()
	end
end

function P.SetPlace(key)
	place = key
	toBrowse()
end

function P.SetLevelBand(key)
	lband = key
	toBrowse()
end

function P.SetFits(on)
	fits = on and true or false
	toBrowse()
end

function P.ClearFilters()
	place, lband, fits = nil, nil, false
	if category ~= "Favorites" and category:sub(1, #PACK) ~= PACK then category = "All" end
	toBrowse()
end

-- The zones and races among the guides the faction filter lists, with how
-- many guides each has (under the other filters but the place).
local function placeChoices()
	local o = { band = lband, fits = fits, level = playerLevel() }
	local zones, races = {}, {}
	local entries = P.Entries(factionFilter(), query, category ~= "Favorites" and category or "All", o)
	for _, e in ipairs(entries) do
		if e.kind == "guide" then
			local g = e.guide
			local z = UI.GuidePlace(g)
			if z then zones[z] = (zones[z] or 0) + 1 end
			for _, r in ipairs(type(g.races) == "table" and g.races or {}) do races[r] = (races[r] or 0) + 1 end
		end
	end
	local zl, rl = {}, {}
	for z, n in pairs(zones) do zl[#zl + 1] = { name = z, count = n } end
	for r, n in pairs(races) do rl[#rl + 1] = { file = r, name = UI.RaceName(r), count = n } end
	table.sort(zl, function(a, b) return a.name < b.name end)
	table.sort(rl, function(a, b) return a.name < b.name end)
	return zl, rl
end

local function placeLabel()
	if not place then return T("Zona o raza") end
	local kind, v = place:match("^(%a+):(.*)$")
	if kind == "race" then return UI.RaceName(v) end
	return v or T("Zona o raza")
end

local function bandLabel(key)
	for _, b in ipairs(LEVEL_BANDS) do
		if b.key == key then return UI.LevelRange(b.lo, b.hi) end
	end
	return T("Nivel")
end

---------------------------------------------------------------------------
-- Engine glue
---------------------------------------------------------------------------

local function tabsInfo()
	local E = ns.Engine
	if not (E and E.GetTabs) then return nil, nil end
	local ok, tabs, active = pcall(E.GetTabs, true) -- with done and total: the tab cards' progress
	if not ok or type(tabs) ~= "table" then return nil, nil end
	return tabs, active
end

local function guideState(id)
	local E = ns.Engine
	if not (E and E.GetGuideState) then return nil end
	return E.GetGuideState(id)
end

local function headersById()
	local G = ns.Guides
	local byId = {}
	for _, g in ipairs(G and G.List and G.List() or {}) do byId[g.id] = g end
	return byId
end

-- How to load from the list: a card's tooltip and the empty states.
local function loadHint()
	return newTabMode and L["Double-click a guide or press Enter to open it in a new tab."]
		or L["Double-click a guide or press Enter to load it."]
end

local mapName = ns.Compat.MapName

-- What a guide's steps hold for this character: the quests it accepts
-- (steps and goals filtered by `only`, as the route choice counts them) and
-- the zones its goals visit, in step order (its own zone without any).
-- Cached per guide until guides register again.
local function guideFacts(g)
	local f = factCache[g.id]
	if f then return f end
	f = { quests = 0, zones = {} }
	local G, C = ns.Guides, ns.Compat
	local full = G and G.Get and G.Get(g.id)
	local player
	if C and C.GetPlayerInfo then
		local ok, info = pcall(C.GetPlayerInfo)
		if ok and type(info) == "table" then player = info end
	end
	local fit = G and G.Matches
	local function applies(only)
		if type(only) ~= "table" or not fit then return true end
		return player ~= nil and fit(only, player)
	end
	local seen = {}
	for _, step in ipairs(full and type(full.steps) == "table" and full.steps or {}) do
		if applies(step.only) and type(step.goals) == "table" then
			for _, goal in ipairs(step.goals) do
				if applies(goal.only) then
					if goal.t == "accept" then f.quests = f.quests + 1 end
					local name = mapName(goal.map)
					if name and not seen[name] then
						seen[name] = true
						f.zones[#f.zones + 1] = name
					end
				end
			end
		end
	end
	if #f.zones == 0 then f.zones[1] = UI.GuidePlace(g) end
	if player then factCache[g.id] = f end
	return f
end

-- What a guide's turn-ins are worth to this character (Levels.ForGuide),
-- kept while their level and XP stay the same: a turn-in moves the XP.
local xpCache = {}
local function guideXP(id)
	local Lv = ns.Levels
	if not (Lv and Lv.ForGuide) then return nil end
	local p = Lv.Player()
	local key = (p.level or 0) .. ":" .. (p.xp or 0)
	local hit = xpCache[id]
	if hit and hit.key == key then return hit.s end
	local s = Lv.ForGuide(id, p)
	-- Nothing yet (no Codex) is asked again: the Codex may load later.
	if s then xpCache[id] = { key = key, s = s } end
	return s
end

-- Whether guide `fromId`'s `next` offers `id` now (an option with `when`
-- only while it holds: Engine.RouteOffered).
local function offered(fromId, id)
	local E = ns.Engine
	return not (E and E.RouteOffered) or E.RouteOffered(fromId, id)
end

-- Where a guide leads: "Title (lo-hi)", or "Your choice: A or B" for a
-- route choice; nil at the end of a line. Only the options offered now.
local function nextFact(g, byId)
	local function named(id)
		local h = byId[id]
		if not h then return nil end
		local lv = UI.LevelRange(h.minLevel, h.maxLevel)
		return (h.title or id) .. (lv and (" (" .. lv .. ")") or "")
	end
	if type(g.nextChoices) == "table" then
		local ids = {}
		for _, id in ipairs(g.nextChoices) do if byId[id] and offered(g.id, id) then ids[#ids + 1] = id end end
		if #ids > 1 then
			local titles = {}
			for i, id in ipairs(ids) do titles[i] = byId[id].title or id end
			local last = table.remove(titles)
			return string.format(L["Your choice: %s or %s"], table.concat(titles, ", "), last)
		elseif #ids == 1 then
			return named(ids[1])
		end
		if g.nextWhen then return nil end
	end
	return g.next and named(g.next) or nil
end

local function load(id, inNewTab)
	local E = ns.Engine
	if not (E and id) then return end
	if inNewTab and E.OpenTab then
		if not E.OpenTab(id) then
			ns.Print(L["Six tabs is the limit. Close one to open another."])
			return
		end
	elseif E.SetGuide then
		E.SetGuide(id)
	end
	ns.Set("ui.shown", true)
	if win then win:Hide() end
end
P.Load = load

function P.Selected() return uiState().pickerSelected end

function P.Select(id)
	uiState().pickerSelected = id
	P.Render()
end

-- The primary action on the selection: continue it where it is open, else
-- load it (into a new tab when the menu came from the guide window's +).
function P.LoadSelected()
	local id = P.Selected()
	if not id then return end
	local tabs = tabsInfo()
	local open = false
	for _, t in ipairs(tabs or {}) do if t.guideId == id then open = true end end
	load(id, newTabMode and not open)
end

-- "Recommended for you": every leveling guide for the player's level, best
-- first (Guides.Suggestions), open ones included (their card says "Tab N"),
-- so the list always answers "what fits me now"; then where the open tabs
-- lead (`next` and route choices) once the player is one level below them
-- (Fitz, 2026-11-10: suggestions come one level early, not several; a level
-- 10 player in a 1-12 guide is not sent on to a 12-19 one).
-- Finished guides are left out.
local function suggestions(byId, tabs, openIndex)
	local G = ns.Guides
	local level = playerLevel()
	local out, seen = {}, {}
	local function add(id, followUp)
		if #out >= SUGGEST_MAX or not id or seen[id] or not byId[id] then return end
		if followUp and (openIndex[id] or (level and level + FOLLOW_REACH < (byId[id].minLevel or 1))) then return end
		seen[id] = true
		if guideState(id) == "done" then return end
		out[#out + 1] = byId[id]
	end
	for _, id in ipairs(G and G.Suggestions and G.Suggestions() or {}) do add(id) end
	for _, t in ipairs(tabs or {}) do
		local h = byId[t.guideId]
		if h then
			for _, c in ipairs(type(h.nextChoices) == "table" and h.nextChoices or { h.next }) do
				if offered(h.id, c) then add(c, true) end
			end
		end
	end
	return out
end

-- The guides the suggestions name, this render: id -> rank (1 is "Recommended
-- for you").
local function rankSuggestions()
	suggested = {}
	local G = ns.Guides
	local ok, list = pcall(function() return G and G.Suggestions and G.Suggestions() or {} end)
	if not ok or type(list) ~= "table" then return end
	for i, id in ipairs(list) do
		if suggested[id] == nil then suggested[id] = i end
	end
end

---------------------------------------------------------------------------
-- The list: folders, guide cards, the open tabs' cards
---------------------------------------------------------------------------

local function folderClick(self)
	if self.psFolder then P.ToggleFolder(self.psFolder) end
end

local function folderRow(i)
	local f = folderPool[i]
	if f then return f end
	f = Kit.Folder(gv.List.Child)
	f:SetScript("OnClick", folderClick)
	folderPool[i] = f
	return f
end

local function cardClick(self, button)
	if button == "RightButton" and self.psCont then return P.CardMenu(self) end
	if self.psGuide then P.Select(self.psGuide.id) end
end

local function cardDoubleClick(self, button)
	if button ~= nil and button ~= "LeftButton" then return end
	if not self.psGuide then return end
	uiState().pickerSelected = self.psGuide.id
	P.LoadSelected()
end

local function guideCard(i)
	local c = cardPool[i]
	if c then return c end
	c = Kit.Card(gv.List.Child)
	c:SetHeight(CARD_H)
	c.Icon = c:CreateTexture(nil, "ARTWORK")
	c.Icon:SetSize(14, 14)
	c.Icon:SetPoint("TOPLEFT", c, "TOPLEFT", CARD_TX, -14)
	c.Title = W.Text(c, "heading", "text")
	c.Title:SetPoint("TOPLEFT", c, "TOPLEFT", CARD_TX + 22, -14)
	-- The tab it is open in, at the top right; a finished guide's check.
	c.Note = W.Text(c, "small", "textMuted")
	c.Note:SetJustifyH("RIGHT")
	c.Note:SetPoint("TOPRIGHT", c, "TOPRIGHT", -CARD_TX, -15)
	c.Check = W.Tex(c, "ARTWORK", "check", "success")
	c.Check:SetSize(12, 12)
	c.Check:SetPoint("TOPRIGHT", c, "TOPRIGHT", -CARD_TX, -15)
	c.Fav = W.Tex(c, "ARTWORK", "star", "accent")
	c.Fav:SetSize(11, 11)
	c.Meta = W.Text(c, "small", "textMuted")
	c.Meta:SetPoint("TOPLEFT", c, "TOPLEFT", CARD_TX + 22, -34)
	c.Chips = {}
	c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	c:SetScript("OnClick", cardClick)
	c:SetScript("OnDoubleClick", cardDoubleClick)
	c:SetScript("OnEnter", W.SimpleTip)
	c:SetScript("OnLeave", W.HideTip)
	cardPool[i] = c
	return c
end

-- The words under a guide's name: "Levels 1–12 · Durotar", its category
-- outside leveling, its pack outside that pack's own list.
local function metaOf(g, shownTitle)
	local parts = {}
	local lv = UI.LevelRange(g.minLevel, g.maxLevel)
	if lv then parts[#parts + 1] = L["Levels"] .. " " .. lv end
	local where = UI.GuidePlace(g)
	if where and where ~= shownTitle and where ~= g.title then parts[#parts + 1] = where end
	local pack = packOf(g)
	local cat = categoryOf(g)
	if pack then
		if not (view == "browse" and category == PACK .. pack.id) then parts[#parts + 1] = pack.title or pack.id end
	elseif cat ~= "Leveling" then
		parts[#parts + 1] = L[cat]
	end
	return table.concat(parts, DOT)
end

-- A guide's chips on its card: Recommended for you (the first suggestion),
-- For your level, Group, From level N (a Class guide not open yet), Finished.
local function chipsOf(g, done, gate)
	local list = {}
	local rank = suggested[g.id]
	if not done then
		if rank == 1 then
			list[#list + 1] = { T("Recomendada para ti"), "accent" }
		elseif categoryOf(g) == "Leveling" and fitsLevel(g, curLevel) then
			list[#list + 1] = { T("Para tu nivel"), "success" }
		end
	end
	if g.group == true then list[#list + 1] = { L["Group"], "dungeon" } end
	if gate then list[#list + 1] = { gate.level and string.format(L["From level %d"], gate.level) or L["Not available yet"], "warning" } end
	if done then list[#list + 1] = { L["Finished"], "success" } end
	return list
end

local function paintGuideCard(c, e)
	local g = e.guide
	c.psGuide = g
	c.psTip = e.tip or loadHint()
	c.psTipLines = nil
	local sel = P.Selected() == g.id
	Kit.SetCard(c, sel)
	local done = guideState(g.id) == "done"
	local E = ns.Engine
	local gate = not done and E and E.StartGate and E.StartGate(g.id) or nil
	c.Icon:SetTexture(Theme.Media(CATEGORY_ICON[categoryOf(g)] or (packOf(g) and "layers") or "icon-level"))
	W.Color(c.Icon, sel and "accent" or "textDim")
	local w = e.w
	c:SetWidth(w)
	local note = e.note
	c.Note:SetWidth(0)
	c.Note:SetText(note or "")
	c.Note:SetShown(note ~= nil)
	c.Check:SetShown(done and note == nil)
	local right = CARD_TX + (note and (ceil(c.Note:GetStringWidth()) + 8) or (done and 20 or 0))
	local fav = P.IsFavorite(g.id)
	c.Fav:ClearAllPoints()
	c.Fav:SetPoint("TOPRIGHT", c, "TOPRIGHT", -right, -16)
	c.Fav:SetShown(fav)
	if fav then right = right + 15 end
	c.Title:SetWidth(0)
	c.Title:SetText(e.title or g.title or g.id)
	c.Title:SetWidth(max(40, min(w - CARD_TX - 22 - right - 4, ceil(c.Title:GetStringWidth()) + 1)))
	W.Color(c.Title, ((done or gate) and not sel) and "textDim" or "text")
	c.Meta:SetText(metaOf(g, e.title))
	c.Meta:SetWidth(w - CARD_TX - 22 - CARD_TX)
	Kit.PlaceChips(c, c.Chips, chipsOf(g, done, gate), CARD_TX + 22, 50, w - CARD_TX)
end

-- An open tab's card: its guide, its step and progress, the tab it is in.
local function closeCard(c)
	local E = ns.Engine
	if E and E.CloseTab and c.psIndex then E.CloseTab(c.psIndex) end
end

-- A card's right-click: its tab's options, as on the guide window's strip.
function P.CardMenu(c)
	local E = ns.Engine
	local i = c.psIndex
	if not (E and E.CloseTab and i) then return end
	local tabs = tabsInfo() or {}
	W.ShowMenu(c, {
		{ text = L["Close tab"], icon = "close", onClick = function() E.CloseTab(i) end },
		{ text = L["Move left"], icon = "chevron-left", disabled = i <= 1 or not E.MoveTab, onClick = function() E.MoveTab(i, i - 1) end },
		{ text = L["Move right"], icon = "chevron-right", disabled = i >= #tabs or not E.MoveTab, onClick = function() E.MoveTab(i, i + 1) end },
	}, { point = "TOPLEFT", relPoint = "BOTTOMLEFT", x = 0, y = -2 })
end

-- The close button shows under the pointer, on the card or on itself.
local function contEnter(self)
	self.Close:SetAlpha(1)
	W.SimpleTip(self)
end

local function contLeave(self)
	if not self.Close:IsMouseOver() then self.Close:SetAlpha(0) end
	W.HideTip(self)
end

local function contCard(i)
	local c = contPool[i]
	if c then return c end
	c = Kit.Card(gv.List.Child)
	c.psCard, c.psCont = true, true
	c:SetHeight(CONT_H)
	c.Icon = c:CreateTexture(nil, "ARTWORK")
	c.Icon:SetSize(14, 14)
	c.Icon:SetPoint("TOPLEFT", c, "TOPLEFT", CARD_TX, -14)
	c.Title = W.Text(c, "heading", "text")
	c.Title:SetPoint("TOPLEFT", c, "TOPLEFT", CARD_TX + 22, -14)
	c.Note = W.Text(c, "small", "textMuted")
	c.Note:SetJustifyH("RIGHT")
	c.Note:SetPoint("TOPRIGHT", c, "TOPRIGHT", -(CARD_TX + 20), -15)
	c.Group = W.Chip(c)
	c.Group:Hide()
	c.Step = W.Text(c, "small", "textDim")
	c.Step:SetPoint("TOPLEFT", c, "TOPLEFT", CARD_TX + 22, -36)
	c.Pct = W.Text(c, "number", "textDim")
	c.Pct:SetJustifyH("RIGHT")
	c.Pct:SetPoint("TOPRIGHT", c, "TOPRIGHT", -CARD_TX, -36)
	c.Line = W.ProgressLine(c, 2)
	c.Line:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", CARD_TX + 22, 16)
	c.Line:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -CARD_TX, 16)
	-- Closes its tab; in the corner, clear of the tab note beside it.
	c.Close = W.IconButton(c, "close", 18, L["Close tab"], function(self) closeCard(self:GetParent()) end, 9)
	c.Close:SetPoint("TOPRIGHT", c, "TOPRIGHT", -6, -10)
	c.Close:SetAlpha(0)
	c.Close.psOnEnter = function(b) b:SetAlpha(1) end
	c.Close.psOnLeave = function(b) if not b:GetParent():IsMouseOver() then b:SetAlpha(0) end end
	c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	c:SetScript("OnClick", cardClick)
	c:SetScript("OnDoubleClick", cardDoubleClick)
	c:SetScript("OnEnter", contEnter)
	c:SetScript("OnLeave", contLeave)
	contPool[i] = c
	return c
end

local function paintContCard(c, e)
	local t, i, active = e.tab, e.index, e.active
	c.psIndex = i
	c.psGuide = e.guide
	c.psTip = loadHint()
	c.psTipLines = { { L["Right-click for tab options"], Theme.Accent() } }
	local sel = P.Selected() == t.guideId
	Kit.SetCard(c, sel)
	c.Icon:SetTexture(Theme.Media(CATEGORY_ICON[t.category] or "icon-level"))
	W.Color(c.Icon, i == active and "accent" or "textDim")
	local w = e.w
	c:SetWidth(w)
	c.Title:SetWidth(0)
	c.Title:SetText(t.title or t.guideId)
	local total = t.total or t.stepCount or 0
	if t.complete then
		c.Step:SetText(ns.LC("guide status", "Completed"))
	elseif t.stepIndex then
		c.Step:SetText(string.format(L["Step %d of %d"], t.stepNumber or t.stepIndex, t.stepTotal or t.stepCount or 0))
	else
		c.Step:SetText("")
	end
	local frac = total > 0 and (t.done or 0) / total or 0
	c.Pct:SetText(floor(frac * 100 + 0.5) .. "%")
	W.SetProgress(c.Line, frac, w - CARD_TX * 2 - 22)
	c.Note:SetText(string.format(L["Tab %d"], i))
	local right = CARD_TX + 20 + ceil(c.Note:GetStringWidth()) + 8
	if e.guide.group == true then
		local gw = W.SetChip(c.Group, L["Group"], "dungeon")
		c.Group:ClearAllPoints()
		c.Group:SetPoint("RIGHT", c.Note, "LEFT", -8, 0)
		right = right + gw + 8
	else
		c.Group:Hide()
	end
	c.Title:SetWidth(max(40, min(w - CARD_TX - 22 - right, ceil(c.Title:GetStringWidth()) + 1)))
end

-- The open tabs in the order their cards show: the active one, then the most
-- recently used (P.Recent, kept on GUIDE_CHANGED), then the rest as the tabs run.
local function cardOrder(tabs, active)
	local order, taken, at = {}, {}, {}
	local function take(i)
		if i and tabs[i] and not taken[i] then
			taken[i] = true
			order[#order + 1] = i
		end
	end
	for i, t in ipairs(tabs) do at[t.guideId] = at[t.guideId] or i end
	take(active)
	for _, id in ipairs(P.Recent()) do take(at[id]) end
	for i = 1, #tabs do take(i) end
	return order
end

-- Draw the entries in view (and a card's height either side), from the pools.
local function paintVisible()
	if not (gv and gv:IsShown()) then return end
	local sf = gv.List
	local top = sf:GetVerticalScroll() or 0
	local viewH = sf:GetHeight()
	if not viewH or viewH <= 0 then viewH = HUB_H - 220 end
	local lo, hi = top - CARD_H, top + viewH + CARD_H
	local nf, nc, nk = 0, 0, 0
	local child = sf.Child
	for _, e in ipairs(layout) do
		if e.y + e.h >= lo and e.y <= hi then
			local f
			if e.t == "folder" then
				nf = nf + 1
				f = folderRow(nf)
				f.psFolder = e.id
				Kit.SetFolder(f, e.text, e.count, e.id ~= nil, e.id ~= nil and P.IsCollapsed(e.id))
				f:SetWidth(e.w)
			elseif e.t == "card" then
				nc = nc + 1
				f = guideCard(nc)
				paintGuideCard(f, e)
			else
				nk = nk + 1
				f = contCard(nk)
				paintContCard(f, e)
			end
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", child, "TOPLEFT", LIST_X + e.x, -e.y)
			f:Show()
		end
	end
	for i = nf + 1, #folderPool do folderPool[i]:Hide() end
	for i = nc + 1, #cardPool do cardPool[i]:Hide() end
	for i = nk + 1, #contPool do contPool[i]:Hide() end
	P.painted = { folders = nf, cards = nc, tabs = nk }
end
P.PaintVisible = paintVisible

-- Keep the selection in view (arrow keys).
local function reveal()
	local sel = P.Selected()
	if not (sel and gv) then return end
	for _, e in ipairs(layout) do
		if (e.t == "card" or e.t == "cont") and e.guide and e.guide.id == sel then
			local sf = gv.List
			local top, viewH = sf:GetVerticalScroll() or 0, sf:GetHeight() or 0
			if e.y < top then
				W.ScrollTo(sf, e.y - 8)
			elseif viewH > 0 and e.y + e.h > top + viewH then
				W.ScrollTo(sf, e.y + e.h - viewH + 8)
			end
			paintVisible()
			return
		end
	end
end

---------------------------------------------------------------------------
-- The ficha (right)
---------------------------------------------------------------------------

local function detailChip(i)
	local c = details.Chips[i]
	if c then return c end
	c = W.Chip(details)
	details.Chips[i] = c
	return c
end

local function bullet(list, i, glyph, color, textColor, size)
	local b = list[i]
	if not b then
		local parent = details.Scroll.Child
		b = {}
		b.Glyph = W.Tex(parent, "ARTWORK", glyph, color)
		b.Glyph:SetSize(size, size)
		b.Text = W.Text(parent, "note", textColor)
		b.Text:SetWordWrap(true)
		b.Text:SetJustifyV("TOP")
		list[i] = b
	end
	return b
end

-- One fact: a muted label in a fixed column, the value beside it.
local function factRow(i)
	local f = details.Facts[i]
	if f then return f end
	local parent = details.Scroll.Child
	f = {}
	f.Label = W.Text(parent, "small", "textMuted")
	f.Label:SetWidth(FACT_W - 8) -- 8px clear of the value; a long label wraps
	f.Label:SetWordWrap(true)
	f.Label:SetJustifyH("LEFT")
	f.Label:SetJustifyV("TOP")
	f.Value = W.Text(parent, "note", "text")
	f.Value:SetJustifyH("LEFT")
	f.Value:SetJustifyV("TOP")
	f.Value:SetWordWrap(true)
	details.Facts[i] = f
	return f
end

-- The guide's reward: one tile per entry in the facts' value column, an
-- item or spell icon (a glyph for words) and its name; items in their
-- quality's colour and border. Hovering shows the game's item or spell
-- tooltip, a modified click acts as on any item or spell button
-- (W.ItemClick, W.SpellClick); the ficha asks for the items and spells as it
-- paints them, so the first hover usually finds them cached.
local REWARD_H, REWARD_GAP = 22, 4

local function rewardEnter(self)
	local e = self.psReward
	if not e then return end
	if e.item then
		W.ItemTip(self, e.item)
	elseif e.spell then
		W.SpellTip(self, e.spell)
	end
end

local function rewardClick(self)
	local e = self.psReward
	if not e then return end
	if e.item then
		W.ItemClick(e.item)
	elseif e.spell then
		W.SpellClick(e.spell)
	end
end

local function rewardTile(i)
	local t = details.Rewards[i]
	if t then return t end
	t = CreateFrame("Button", nil, details.Scroll.Child)
	t:SetHeight(REWARD_H)
	W.Hover(t)
	t.Well = CreateFrame("Frame", nil, t)
	t.Well:SetSize(REWARD_H, REWARD_H)
	t.Well:SetPoint("LEFT", t, "LEFT", 0, 0)
	t.Well.Ground = W.Fill(t.Well, "scrim", "BACKGROUND", 0)
	t.Icon = t.Well:CreateTexture(nil, "ARTWORK")
	t.Icon:SetPoint("TOPLEFT", t.Well, "TOPLEFT", 1, -1)
	t.Icon:SetPoint("BOTTOMRIGHT", t.Well, "BOTTOMRIGHT", -1, 1)
	t.Name = W.Text(t, "note", "text")
	t.Name:SetPoint("LEFT", t.Well, "RIGHT", 8, 0)
	t:SetScript("OnEnter", rewardEnter)
	t:SetScript("OnLeave", W.HideTip)
	t:SetScript("OnClick", rewardClick)
	details.Rewards[i] = t
	return t
end

-- "ffrrggbb" -> r, g, b (0-1).
local function hexRGB(hex)
	local r, g, b = hex:match("^%x%x(%x%x)(%x%x)(%x%x)$")
	if not r then return nil end
	return tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255
end

-- Paints tile t for reward entry e -> the name shown.
local function paintReward(t, e)
	local C = ns.Compat
	t.psReward = e
	local icon, name, hex
	if e.item then
		W.PrefetchItem(e.item)
		icon = C.ItemIcon and C.ItemIcon(e.item)
		name = ns.Names.Item(e.item) or e.itemName or (L["Item"] .. " " .. e.item)
		local q = (C.GetItemQuality and C.GetItemQuality(e.item)) or e.quality
		hex = q and C.ItemQualityHex and C.ItemQualityHex(q)
	elseif e.spell then
		W.PrefetchSpell(e.spell)
		icon = C.SpellIcon and C.SpellIcon(e.spell)
		name = ns.Names.Spell(e.spell) or e.spellName or (L["Spell"] .. " " .. e.spell)
	else
		name = e.text or ""
	end
	if icon then
		t.Icon:SetTexture(icon)
		t.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		W.Uncolor(t.Icon)
		t.Icon:SetVertexColor(1, 1, 1, 1)
	else
		t.Icon:SetTexture(Theme.Media(e.item and "icon-collect" or "icon-train"))
		t.Icon:SetTexCoord(0, 1, 0, 1)
		W.Color(t.Icon, "textMuted")
	end
	local r, g, b = hexRGB(hex or "")
	if r then
		Theme.Border(t.Well, r, g, b, 0.9)
		W.Uncolor(t.Name)
		t.Name:SetTextColor(Theme.Legible(r, g, b))
	else
		local br, bg, bb = Theme.Wash("border")
		Theme.Border(t.Well, br, bg, bb, 0.6)
		W.Color(t.Name, e.item and "item" or "text")
	end
	t.Name:SetText(name)
	return name
end

-- The zones in route order, as many as fit on two lines ("A › B › …").
local function fitZones(fs, zones)
	for k = #zones, 1, -1 do
		local text = table.concat(zones, ARROW, 1, k)
		if k < #zones then text = text .. ARROW .. ELLIPSIS end
		fs:SetText(text)
		if fs:GetNumLines() <= 2 then return end
	end
end

local function buildDetails()
	local d = CreateFrame("Frame", nil, gv)
	details = d
	P.details = d
	d:SetPoint("TOPRIGHT", gv, "TOPRIGHT", -GAP, -12)
	d:SetPoint("BOTTOMRIGHT", gv, "BOTTOMRIGHT", -GAP, GAP)
	d:SetWidth(DETAIL_W)
	d:EnableMouse(true)
	Theme.Skin(d, "panel")

	d.Art = ZoneArt.Create(d, DETAIL_W - 20, ART_H, "panel")
	d.Art.psZoom = 1.5 -- the wider band shows more of the zone
	d.Art:SetPoint("TOPLEFT", d, "TOPLEFT", 10, -10)
	Kit.CutPicture(d.Art, "panel", Theme.CUT.control)
	d.Star = W.IconButton(d, "star", 26, L["Add to favourites"], function() P.ToggleFavorite(P.Selected()) end, 14)
	d.Title = W.Text(d, "display", "text")
	d.Meta = W.Text(d, "small", "textMuted")
	d.Meta:SetWidth(INNER)

	d.Chips = {}
	-- What a leveling guide is worth in levels; hovering opens its panel
	-- (UI/LevelTip.lua) on the window.
	d.XP = UI.LevelTip.Chip(d, win)
	d.ProgLabel = W.Text(d, "small", "textDim")
	d.ProgPct = W.Text(d, "number", "textDim")
	d.ProgPct:SetJustifyH("RIGHT")
	d.Prog = W.ProgressLine(d, 2)
	d.Prog:SetWidth(INNER)
	d.Rule = W.Divider(d)

	-- The facts, credits, pitch, pros and cons scroll between the progress
	-- and the buttons.
	d.Scroll = W.Scroll(d)
	local child = d.Scroll.Child
	d.Facts, d.Rewards = {}, {}
	d.Credits = W.Text(child, "small", "textMuted")
	d.Credits:SetWordWrap(true)
	d.Credits:SetJustifyH("LEFT")
	d.Source = W.Text(child, "note", "textDim")
	d.Source:SetWordWrap(true)
	d.Source:SetJustifyH("LEFT")
	d.Pitch = W.Text(child, "note", "textDim")
	d.Pitch:SetWordWrap(true)
	d.Pitch:SetJustifyV("TOP")
	d.Pros, d.Cons = {}, {}

	-- Use it: into the current tab; Continue on a guide already open.
	d.Load = W.Button(d, T("Usar esta guía"), function() load(P.Selected(), false) end, { primary = true, height = 32 })
	d.NewTab = W.Button(d, T("Pestaña nueva"), function() load(P.Selected(), true) end, { height = 32, icon = "plus" })
	d.NewTab.psTip = L["Open in new tab"]
	d.NewTab:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -DPAD, DPAD)
	d.Load:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", DPAD, DPAD)

	-- Nothing selected yet: the wolf's engraving, a title and a line.
	d.Watermark = d:CreateTexture(nil, "BACKGROUND", nil, -4)
	d.Watermark:SetTexture(Theme.Media("watermark"))
	d.Watermark:SetSize(200, 200)
	d.Watermark:SetPoint("CENTER", d, "CENTER", 0, 30)
	W.Painter(d.Watermark, function(t) t:SetVertexColor(Theme.Wash("watermark")) end)
	d.EmptyTitle = W.Text(d, "display", "text")
	d.EmptyTitle:SetPoint("TOPLEFT", d, "TOPLEFT", DPAD, -(10 + ART_H + 20))
	d.EmptyTitle:SetText(L["Choose a guide"])
	d.EmptyNote = W.Text(d, "note", "textDim")
	d.EmptyNote:SetWordWrap(true)
	d.EmptyNote:SetJustifyV("TOP")
	d.EmptyNote:SetWidth(INNER)
	d.EmptyNote:SetPoint("TOPLEFT", d.EmptyTitle, "BOTTOMLEFT", 0, -10)
	d.EmptyNote:SetText(L["Select a guide to see where it goes, then load it."])
end

-- A stable stretch of sky per guide, so neighbours never look cloned.
local function skyIndex(id)
	local n = 0
	for i = 1, #id do n = (n * 31 + id:byte(i)) % 997 end
	return n + 1
end

local function setButtonWidth(b, w)
	b.psFixedWidth = w
	W.SetButtonText(b, b.Label:GetText())
end

local function setPrimary(b, on)
	b.psPrimary = on
	Theme.Repaint(b)
	W.RepaintButton(b)
end

-- A guide's credits: "By <author>" for ours; for a pack's guide "By
-- <author> · <pack title> <version> · <licence>" (an imported guide: "By
-- <author> · Imported · <its own licence>"). The author is the guide's
-- own, else its pack's. -> text or nil, the pack's source or nil
function P.Credits(g)
	if not g then return nil end
	local G = ns.Guides
	local own = g.pack and G and G.Pack and G.Pack(g.pack) or nil
	local author = type(g.author) == "string" and g.author ~= "" and g.author or (own and own.author)
	local pack = packOf(g)
	local parts = {}
	if author then parts[1] = string.format(L["By %s"], author) end
	if pack then
		parts[#parts + 1] = (pack.title or pack.id) .. (pack.version and (" " .. pack.version) or "")
		local license = pack.license or (pack.imported and type(g.license) == "string" and g.license or nil)
		if license then parts[#parts + 1] = license end
	end
	if #parts == 0 then return nil end
	return table.concat(parts, DOT), pack and pack.source or nil
end

local function renderDetails(byId, tabs)
	local d = details
	local id = P.Selected()
	local g = id and byId[id]
	local E = ns.Engine
	local parts = { d.Star, d.Title, d.Meta, d.ProgLabel, d.ProgPct, d.Prog, d.Rule, d.Scroll, d.Load, d.NewTab }
	if not g then
		d.psArt = ZoneArt.Paint(d.Art, nil, nil, nil, 1)
		d.Art:Hide()
		for _, p in ipairs(parts) do p:Hide() end
		for _, c in ipairs(d.Chips) do c:Hide() end
		UI.LevelTip.Set(d.XP, nil)
		d.Watermark:Show()
		d.EmptyTitle:Show()
		d.EmptyNote:Show()
		P.detail = nil
		d.psReadFor = nil
		return
	end
	d.Watermark:Hide()
	d.EmptyTitle:Hide()
	d.EmptyNote:Hide()
	d.Art:Show()
	for _, p in ipairs(parts) do p:Show() end
	local fx, fy
	if E and E.GuideFocus then fx, fy = E.GuideFocus(g.id) end
	d.psArt = ZoneArt.Paint(d.Art, g.zone, fx, fy, skyIndex(g.id))

	-- The name, the star at its right; the category and place under it.
	local y = 10 + ART_H + 14
	local fav = P.IsFavorite(g.id)
	W.SetIconState(d.Star, fav)
	d.Star.psTip = fav and L["Remove from favourites"] or L["Add to favourites"]
	d.Star:ClearAllPoints()
	d.Star:SetPoint("TOPRIGHT", d, "TOPRIGHT", -(DPAD - 6), -(y - 4))
	d.Title:SetWidth(0)
	d.Title:SetText(g.title or g.id)
	d.Title:SetWidth(min(INNER - 28, ceil(d.Title:GetStringWidth()) + 1))
	d.Title:ClearAllPoints()
	d.Title:SetPoint("TOPLEFT", d, "TOPLEFT", DPAD, -y)
	y = y + 24
	local pack = packOf(g)
	local metaParts = { pack and (pack.title or pack.id) or L[categoryOf(g)] }
	local where = UI.GuidePlace(g)
	if where then metaParts[#metaParts + 1] = where end
	d.Meta:SetText(table.concat(metaParts, DOT))
	d.Meta:ClearAllPoints()
	d.Meta:SetPoint("TOPLEFT", d, "TOPLEFT", DPAD, -y)
	y = y + 22

	-- Chips: levels, what a leveling guide is worth in levels, group content,
	-- faction, races, classes; on two lines at most.
	local n, x, line, full = 0, DPAD, 0, false
	local function place_(c, w)
		if full then
			c:Hide()
			return false
		end
		if x > DPAD and x + w > DPAD + INNER then
			if line == 1 then
				c:Hide()
				full = true
				return false
			end
			line, x = 1, DPAD
		end
		c:ClearAllPoints()
		c:SetPoint("TOPLEFT", d, "TOPLEFT", x, -(y + line * (W.CHIP_H + 6)))
		x = x + w + 6
		return true
	end
	local function addChip(text, kind)
		if full then return end
		local c = detailChip(n + 1)
		if place_(c, W.SetChip(c, text, kind)) then n = n + 1 end
	end
	local rank = suggested[g.id]
	if rank == 1 and guideState(g.id) ~= "done" then addChip(T("Recomendada para ti"), "accent") end
	local lv = UI.LevelRange(g.minLevel, g.maxLevel)
	if lv then addChip(L["Levels"] .. " " .. lv, rank == 1 and nil or "accent") end
	local xw = UI.LevelTip.Set(d.XP, g.category == "Leveling" and guideXP(g.id) or nil,
		{ head = L["If you finish this guide"], need = L["You are level %d. Level %d is recommended for this guide; from there:"] })
	if xw and place_(d.XP, xw) then
		-- Its panel starts on the ficha's text edge, not the chip's.
		local _, _, _, cx = d.XP:GetPoint(1)
		d.XP.psTipX = DPAD - (cx or DPAD)
	end
	if g.group == true then addChip(L["Group"], "dungeon") end
	addChip(ns.FactionName(g.faction) or L["Both factions"])
	if type(g.races) == "table" then for _, race in ipairs(g.races) do addChip(UI.RaceName(race)) end end
	if type(g.classes) == "table" then for _, cl in ipairs(g.classes) do addChip(UI.ClassName(cl)) end end
	for i = n + 1, #d.Chips do d.Chips[i]:Hide() end
	y = y + (line + 1) * W.CHIP_H + line * 6 + 14

	-- Progress: GetGuideState, plus the tab's step when it is open.
	local state, done, total = guideState(g.id)
	local tabIndex, tab
	for i, t in ipairs(tabs or {}) do if t.guideId == g.id then tabIndex, tab = i, t end end
	local label
	if state == "done" then
		label = L["Finished"]
	elseif tab then
		label = tab.stepIndex and string.format(L["Open in tab %d  \194\183  step %d of %d"], tabIndex, tab.stepNumber or tab.stepIndex, tab.stepTotal or tab.stepCount or 0)
			or string.format(L["Open in tab %d"], tabIndex)
	elseif state == "started" then
		label = L["Started"]
	else
		label = L["Not started"]
	end
	local frac
	if total and total > 0 then frac = (done or 0) / total elseif state == "done" then frac = 1 end
	d.ProgLabel:SetText(label)
	d.ProgLabel:ClearAllPoints()
	d.ProgLabel:SetPoint("TOPLEFT", d, "TOPLEFT", DPAD, -y)
	local started = frac and frac > 0
	d.ProgPct:SetText(started and (floor(frac * 100 + 0.5) .. "%") or "")
	d.ProgPct:ClearAllPoints()
	d.ProgPct:SetPoint("TOPRIGHT", d, "TOPRIGHT", -DPAD, -y)
	d.Prog:ClearAllPoints()
	d.Prog:SetPoint("TOPLEFT", d, "TOPLEFT", DPAD, -(y + 20))
	W.SetProgress(d.Prog, frac or 0, INNER)
	d.Prog:SetShown(started and true or false)
	y = y + (started and (20 + 2) or 14) + 12
	d.Rule:ClearAllPoints()
	d.Rule:SetPoint("TOPLEFT", d, "TOPLEFT", DPAD, -y)
	d.Rule:SetPoint("TOPRIGHT", d, "TOPRIGHT", -DPAD, -y)
	y = y + 1

	-- The scroll: the facts (what the guide's goal gives and why: a Class
	-- guide's `reward` and `why`; then steps, the quests this character
	-- takes, the zones in route order, where the guide leads), the credits,
	-- the pitch, pros and cons.
	local bottom = DPAD + 32 + 12
	d.Scroll:ClearAllPoints()
	d.Scroll:SetPoint("TOPLEFT", d, "TOPLEFT", DPAD, -(y + 10))
	d.Scroll:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -DPAD + 10, bottom)
	local child = d.Scroll.Child
	local cw = INNER - 4
	child:SetWidth(cw)
	local cy = 0
	local facts, info = {}, guideFacts(g)
	if type(g.reward) == "table" then
		local get, choose = {}, {}
		for _, e in ipairs(g.reward) do
			if type(e) == "table" then
				local list = e.choice and choose or get
				list[#list + 1] = e
			end
		end
		if #get > 0 then facts[#facts + 1] = { L["Reward"], rewards = get } end
		if #choose > 0 then facts[#facts + 1] = { L["Choose one"], rewards = choose } end
	end
	if type(g.why) == "string" and g.why ~= "" then facts[#facts + 1] = { L["Why"], g.why } end
	-- A Class guide: the same heads-up the class-quest card gives (QoL/ClassQuests.lua).
	local CQ, G = ns.QoL and ns.QoL.ClassQuests, ns.Guides
	local full = g.category == "Class" and CQ and CQ.Heads and G and G.Get and G.Get(g.id)
	if type(full) == "table" and type(full.steps) == "table" then
		local okP, player = pcall(ns.Compat.GetPlayerInfo)
		local heads = CQ.HeadsLine(CQ.Heads(full, okP and type(player) == "table" and player or {}), full)
		if heads then facts[#facts + 1] = { L["Heads-up"], heads } end
	end
	if g.stepCount then facts[#facts + 1] = { L["Steps"], tostring(g.stepCount) } end
	if info.quests > 0 then facts[#facts + 1] = { L["Quests"], tostring(info.quests) } end
	if #info.zones > 0 then facts[#facts + 1] = { L["Zones"], info.zones, "textDim" } end
	local nextText = nextFact(g, byId)
	if nextText then facts[#facts + 1] = { L["Next"], nextText, "textDim" } end
	local shownFacts, shownRewards, nTiles = {}, {}, 0
	-- The label column: FACT_W, or wider by what a label's longest word
	-- needs, so a label wraps between words only.
	local factW = FACT_W
	for i, f in ipairs(facts) do
		for word in f[1]:gmatch("%S+") do factW = max(factW, ceil(W.TextWidth(factRow(i).Label, word)) + 8) end
	end
	local valueW = cw - factW
	for i, f in ipairs(facts) do
		local row = factRow(i)
		row.Label:SetWidth(factW - 8)
		row.Label:SetText(f[1])
		row.Label:ClearAllPoints()
		row.Label:Show()
		row.Value:SetWidth(valueW)
		if f.rewards then
			row.Label:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -(cy + (REWARD_H - row.Label:GetStringHeight()) / 2))
			row.Value:Hide()
			local names = {}
			for k, e in ipairs(f.rewards) do
				nTiles = nTiles + 1
				local t = rewardTile(nTiles)
				t:SetWidth(valueW)
				t.Name:SetWidth(valueW - REWARD_H - 8)
				t:ClearAllPoints()
				t:SetPoint("TOPLEFT", child, "TOPLEFT", factW, -cy)
				names[k] = paintReward(t, e)
				shownRewards[#shownRewards + 1] = { kind = e.item and "item" or e.spell and "spell" or "text", id = e.item or e.spell, name = names[k], choice = e.choice and true or nil }
				t:Show()
				cy = cy + REWARD_H + (k < #f.rewards and REWARD_GAP or 0)
			end
			cy = cy + FACT_GAP
			shownFacts[i] = { f[1], table.concat(names, ", ") }
		else
			W.Color(row.Value, f[3] or "text")
			if type(f[2]) == "table" then fitZones(row.Value, f[2]) else row.Value:SetText(f[2]) end
			row.Label:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -(cy + 1))
			row.Value:ClearAllPoints()
			row.Value:SetPoint("TOPLEFT", child, "TOPLEFT", factW, -cy)
			row.Value:Show()
			cy = cy + max(row.Value:GetStringHeight(), row.Label:GetStringHeight()) + FACT_GAP
			shownFacts[i] = { f[1], row.Value:GetText() }
		end
	end
	for i = #facts + 1, #d.Facts do
		d.Facts[i].Label:Hide()
		d.Facts[i].Value:Hide()
	end
	for i = nTiles + 1, #d.Rewards do d.Rewards[i]:Hide() end
	if #facts > 0 then cy = cy - FACT_GAP + 14 end

	-- Credits, and the pack's source.
	local credits, source = P.Credits(g)
	d.Credits:SetShown(credits ~= nil)
	d.Source:SetShown(source ~= nil)
	if credits then
		d.Credits:SetWidth(cw)
		d.Credits:SetText(credits)
		d.Credits:ClearAllPoints()
		d.Credits:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -cy)
		cy = cy + d.Credits:GetStringHeight() + 6
	end
	if source then
		d.Source:SetWidth(cw)
		d.Source:SetText("\226\128\156" .. source .. "\226\128\157")
		d.Source:ClearAllPoints()
		d.Source:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -cy)
		cy = cy + d.Source:GetStringHeight() + 6
	end
	if credits or source then cy = cy + 8 end

	-- The quest's matching steps first; the guide's pitch follows them.
	local pitch = g.pitch
	if questContext then
		local text = {}
		local Eg, fullG = ns.Engine, ns.Guides.Get(g.id)
		local numbered = Eg and Eg.StepNumberOf and fullG
		for _, hit in ipairs(questSteps(g)) do
			-- As the player counts the steps (#942).
			local no = numbered and (Eg.StepNumberOf(fullG, hit.index)) or hit.index
			local tot = numbered and Eg.StepTotalOf(fullG) or g.stepCount or 0
			text[#text + 1] = string.format(L["Step %d of %d: %s"], no, tot, hit.step.title or questContext.query)
			if type(hit.step.note) == "string" and hit.step.note ~= "" then text[#text + 1] = hit.step.note end
		end
		if #text > 0 then
			if type(pitch) == "string" and pitch ~= "" then text[#text + 1] = pitch end
			pitch = table.concat(text, "\n\n")
		end
	end
	if type(pitch) == "string" and pitch ~= "" then
		d.Pitch:SetWidth(cw)
		d.Pitch:SetText(pitch)
		d.Pitch:ClearAllPoints()
		d.Pitch:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -cy)
		d.Pitch:Show()
		cy = cy + d.Pitch:GetStringHeight() + 14
	else
		d.Pitch:Hide()
	end
	local function lines(list, items, glyph, color, textColor, size)
		local k = 0
		for i, text in ipairs(type(items) == "table" and items or {}) do
			local b = bullet(list, i, glyph, color, textColor, size)
			b.Glyph:ClearAllPoints()
			b.Glyph:SetPoint("TOPLEFT", child, "TOPLEFT", (12 - size) / 2, -(cy + 2 + (12 - size) / 2))
			b.Text:SetText(text)
			b.Text:SetWidth(cw - 20)
			b.Text:ClearAllPoints()
			b.Text:SetPoint("TOPLEFT", child, "TOPLEFT", 20, -cy)
			b.Glyph:Show()
			b.Text:Show()
			cy = cy + b.Text:GetStringHeight() + 7
			k = i
		end
		for i = k + 1, #list do
			list[i].Glyph:Hide()
			list[i].Text:Hide()
		end
		return k
	end
	local pros = lines(d.Pros, g.pros, "check", "success", "text", 12)
	if pros > 0 and type(g.cons) == "table" and #g.cons > 0 then cy = cy + 4 end
	lines(d.Cons, g.cons, "cross", "textMuted", "textDim", 9)
	W.SetScrollContent(d.Scroll, cy + 8)
	-- Another guide (or another quest's search) reads from the top; the same
	-- one drawn again (a tab's progress, a guide registering) keeps the
	-- place the player scrolled to.
	local readFor = g.id .. "\0" .. (questContext and questContext.query or "")
	if d.psReadFor ~= readFor then
		d.psReadFor = readFor
		W.ScrollTo(d.Scroll, 0)
	end

	-- The buttons: Use this guide and New tab; on a guide already open,
	-- Continue alone at full width.
	local hasTabs = E and E.OpenTab and true or false
	W.SetButtonText(d.Load, tab and L["Continue"] or T("Usar esta guía"))
	d.Load.psTip = tab and string.format(L["Switch to tab %d."], tabIndex) or L["Load into the current tab."]
	if hasTabs and not tab then
		d.NewTab:Show()
		setButtonWidth(d.NewTab, nil)
		setButtonWidth(d.Load, INNER - d.NewTab:GetWidth() - 8)
		setPrimary(d.Load, not newTabMode)
		setPrimary(d.NewTab, newTabMode)
	else
		d.NewTab:Hide()
		setButtonWidth(d.Load, INNER)
		setPrimary(d.Load, true)
	end
	P.detail = { id = g.id, art = d.psArt, state = state, tab = tabIndex, label = label, frac = frac, facts = shownFacts,
		reward = #shownRewards > 0 and shownRewards or nil, credits = credits, source = source, recommended = rank == 1 }
end

---------------------------------------------------------------------------
-- The hub's sections (docs/INTERFAZ.md): Guides is the built-in one; others
-- register with
--
--   UI.RegisterSection({
--     key, label, icon, order,
--     build = fn(parent, hub), render = fn(),
--     nav = fn() -> items, activeKey,  -- optional: its views ({ key, label, icon, count, dot }), as pills
--     onNav = fn(key),                 -- with nav: set the state, then UI.Picker.Render()
--     search = fn(text), enter = fn(), step = fn(delta), -- optional: the hub search drives it
--     searchPlaceholder = "...",       -- optional; or a list of wordings, longest first (the first that fits shows)
--     foot = true,                     -- optional: at the right of the sections, beside "Inicio de Alfa"
--   })
--
-- A section's frame spans the window under its pills (and its tab row when
-- its render sets tabs: W.ShellTabs on the hub); its width is the hub's.
---------------------------------------------------------------------------

local GUIDES = { key = "Guides", label = L["Guides"], icon = "guides", order = 10, builtin = true }
local HOME = "__alfa" -- the sections' last button: the main window
local MORE = "__more" -- the pill that holds the pills that do not fit
local sections, section = { GUIDES }, nil
P.GUIDES = GUIDES.key

function UI.RegisterSection(spec)
	if type(spec) ~= "table" or type(spec.key) ~= "string" or type(spec.build) ~= "function" or type(spec.render) ~= "function" then return false end
	if spec.key == GUIDES.key or spec.key == HOME then return false end
	for i = #sections, 1, -1 do if sections[i].key == spec.key then table.remove(sections, i) end end
	sections[#sections + 1] = spec
	table.sort(sections, function(a, b) return (a.order or 100) < (b.order or 100) end)
	if win and win:IsShown() then P.Render() end
	return true
end

function P.Sections() return sections end
function P.Section() return section or GUIDES.key end

local function activeSection()
	if not section then return nil end
	for _, s in ipairs(sections) do if s.key == section and not s.builtin then return s end end
	return nil
end
P.ActiveSection = activeSection

function P.Query() return query end

-- Show a section ("Guides" or nil: the guide list). The hub search starts
-- empty in every section.
-- Alfa: una seccion cuya ventana reemplaza Alfa (Core/Reemplazos.lua) abre
-- esa ventana y cierra el centro (el centro del motor queda solo como respaldo
-- de las secciones sin ventana propia).
P.SECCION_REEMPLAZO = { Guides = "SHOW_PICKER", Lookup = "SHOW_LOOKUP", Dungeons = "SHOW_DUNGEON",
	Talents = "SHOW_TALENTS", Rares = "SHOW_RARES", Characters = "SHOW_ALTS", Import = "SHOW_IMPORT" }

function P.ShowSection(key)
	local clave = P.SECCION_REEMPLAZO[key or GUIDES.key]
	if clave and win and win:IsShown() and ns.Reemplazo and ns.Reemplazo(clave) then
		win:Hide()
		if ns.Reemplazos.Llamar(clave, {}) then return end
		win:Show()
	end
	if key == GUIDES.key then key = nil end
	Kit.HideGrid()
	if key ~= section and win then
		query = ""
		win.Search:SetText("")
	end
	section = key
	if win and win:IsShown() then P.Render() end
end

-- The section `delta` away (LB / RB on a gamepad).
function P.StepSection(delta)
	local cur = P.Section()
	for i, s in ipairs(sections) do
		if s.key == cur then
			local to = sections[i + delta]
			if to then P.ShowSection(to.key) end
			return
		end
	end
end

-- The hub's search wordings, longest first: the box shows the first that fits.
local HUB_SEARCH = { L["Search guides, items, NPCs"], L["Search guides, items"], L["Search"] }

-- The sections as the hub's buttons, and the same lists as before for the
-- code that asks for them (Polestar's rail): P.RailItems and P.FootItems.
-- A section's label may be a Spanish key of the interface's texts (ns.T at
-- render); an engine string passes through as it is.
function P.RailItems()
	local items = {}
	for _, s in ipairs(sections) do
		if not s.foot then items[#items + 1] = { key = s.key, label = T(s.label or s.key), icon = s.icon } end
	end
	return items
end

function P.FootItems(onOptions)
	local items = { { key = "Options", label = L["Options"], icon = "sliders", tip = L["Options"], onClick = onOptions } }
	for _, s in ipairs(sections) do
		if s.foot then items[#items + 1] = { key = s.key, label = s.label or s.key, icon = s.icon } end
	end
	return items
end

-- Open `to` where `from` stands when switching between the hub and the
-- main window: their top-left corners meet.
function P.TakePlace(to, from)
	local left, top = from:GetLeft(), from:GetTop()
	if not (left and top) then return end
	local k = from:GetEffectiveScale() / to:GetEffectiveScale()
	to:ClearAllPoints()
	to:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * k, top * k)
end

local function sectionItems()
	local items = P.RailItems()
	-- At the right, from the edge in: the main window, then the foot sections.
	items[#items + 1] = { key = HOME, label = T("Inicio de Alfa"), icon = "sec-hoy", right = true, tip = T("Abre la ventana principal de Alfa.") }
	for i = #sections, 1, -1 do
		local s = sections[i]
		if s.foot then items[#items + 1] = { key = s.key, label = T(s.label or s.key), icon = s.icon, right = true } end
	end
	return items
end

local function renderSections()
	W.ShellSections(win, sectionItems(), section or GUIDES.key, function(key)
		if key == HOME then
			if UI.ShowOptions then UI.ShowOptions() end
			return
		end
		P.ShowSection(key)
	end)
end

-- Pills, as many as the row holds: the rest go under "More", a menu. The
-- active one always shows. items: { { key, label, icon, count, dot, heading,
-- separator } } (a section's nav). -> the pills drawn
local pillProbe
local function pillWidth(p)
	return (p.icon and 31 or 14) + ceil(W.TextWidth(pillProbe, p.label or "")) + 14 + 6
end

local function renderPills(items, active, onSelect, reserve)
	if not pillProbe then
		pillProbe = W.Text(win.PillRow, "label", "text")
		pillProbe:Hide()
	end
	local pills = {}
	for _, it in ipairs(items or {}) do
		if not (it.heading or it.separator) and it.key ~= nil then
			local label = it.label or tostring(it.key)
			if it.count ~= nil and it.count ~= 0 and it.count ~= "" then label = label .. "  " .. tostring(it.count) end
			pills[#pills + 1] = { key = it.key, label = label, icon = it.icon, dot = it.dot, tip = it.tip }
		end
	end
	if #pills == 0 then
		W.ShellPills(win, nil)
		return 0
	end
	local full = win:GetWidth() - 2 - (SH.pad - 6) - SH.pad
	local room = full - (reserve or 0)
	local need = 0
	for _, p in ipairs(pills) do need = need + pillWidth(p) end
	-- The pills come first: they take the subtitle's room before any folds away.
	if need > room then room = full end
	local shown, rest = pills, nil
	if need > room then
		local more = { key = MORE, label = T("Más") .. "  " .. #pills, icon = "chevron-down" }
		local budget = room - pillWidth(more)
		shown, rest = {}, {}
		local activeAt
		for i, p in ipairs(pills) do if p.key == active then activeAt = i end end
		-- The active pill's room is kept from the start.
		local used = activeAt and pillWidth(pills[activeAt]) or 0
		for i, p in ipairs(pills) do
			if i == activeAt then
				shown[#shown + 1] = p
			else
				local w = pillWidth(p)
				if used + w <= budget then
					shown[#shown + 1] = p
					used = used + w
				else
					rest[#rest + 1] = p
				end
			end
		end
		more.label = T("Más") .. "  " .. #rest
		shown[#shown + 1] = more
	end
	W.ShellPills(win, shown, active, function(key)
		if key ~= MORE then
			onSelect(key)
			return
		end
		local anchor
		for _, b in ipairs(rawget(win, "pillButtons") or {}) do if b:IsShown() and b.psKey == MORE then anchor = b end end
		local menu = {}
		for _, p in ipairs(rest or {}) do
			local k = p.key
			menu[#menu + 1] = { text = p.label, icon = p.icon, checked = k == active, onClick = function() onSelect(k) end }
		end
		W.ShowMenu(anchor or win.PillRow, menu, { point = "TOPLEFT", relPoint = "BOTTOMLEFT", x = 0, y = -4 })
	end)
	return #shown
end
P.RenderPills = renderPills

-- The pills took the subtitle's room: it stays hidden rather than squeezed
-- to nothing beside them.
local function fitSubtitle()
	local last
	for _, b in ipairs(rawget(win, "pillButtons") or {}) do if b:IsShown() then last = b end end
	if not last then return end
	local right, lr = win.PillRow:GetRight(), last:GetRight()
	if right and lr and right - SH.pad - lr < 80 then win.Subtitle:Hide() end
end

local function sectionPills(s)
	if not s.nav then
		W.ShellPills(win, nil)
		return
	end
	local ok, items, activeKey = pcall(s.nav)
	if not ok or type(items) ~= "table" then items, activeKey = {}, nil end
	renderPills(items, activeKey, function(key) if s.onNav then s.onNav(key) end end, 140)
end

local function renderSection(s)
	if not s.psFrame then
		local f = CreateFrame("Frame", nil, win.Main)
		s.psFrame = f
		f:SetPoint("TOPLEFT", win.PillRow, "BOTTOMLEFT", 0, 0)
		f:SetPoint("BOTTOMRIGHT", win.Main, "BOTTOMRIGHT", 0, 0)
		s.build(f, win)
	end
	for _, o in ipairs(sections) do
		if o.psFrame then o.psFrame:SetShown(o == s) end
	end
	-- No tabs until the section sets its own (its render may); its name
	-- until it says more.
	W.ShellTabs(win, nil)
	W.ShellTitle(win, T(s.label or s.key), "")
	s.render()
	fitSubtitle()
	-- Under the tab row when the section set one, else under the pills.
	local f = s.psFrame
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", win.TabRow:IsShown() and win.TabRow or win.PillRow, "BOTTOMLEFT", 0, 0)
	f:SetPoint("BOTTOMRIGHT", win.Main, "BOTTOMRIGHT", 0, 0)
end

local function searchFor(s)
	local ph = (s and s.searchPlaceholder) or (s and s.search and L["Search"]) or HUB_SEARCH
	if type(ph) == "table" then
		local out = {}
		for i, v in ipairs(ph) do out[i] = T(v) end
		ph = out
	else
		ph = T(ph)
	end
	W.SetSearchPlaceholder(win.Search, ph)
	win.Search:SetShown(not s or s.search ~= nil)
end

---------------------------------------------------------------------------
-- Guides: the pills, the filter bar, the list
---------------------------------------------------------------------------

-- The community packs among the shown guides (Mis rutas apart), by title.
local function communityPacks()
	local packs, seen = {}, {}
	for _, g in ipairs(ns.Guides and ns.Guides.List and ns.Guides.List() or {}) do
		local r = packOf(g)
		if r and r.id ~= MIS_RUTAS and not seen[r.id] then
			seen[r.id] = true
			packs[#packs + 1] = r
		end
	end
	table.sort(packs, function(a, b) return (a.title or a.id):lower() < (b.title or b.id):lower() end)
	return packs
end

local function misRutas()
	local G = ns.Guides
	local r = G and G.Pack and G.Pack(MIS_RUTAS)
	if r and not r.internal and r.status ~= "off" then return r end
	return nil
end

-- The pill a view and category stand for.
local function activePill()
	if view ~= "browse" then return view end
	if category == "Favorites" then return "fav" end
	if category == PACK .. MIS_RUTAS then return "mine" end
	if category:sub(1, #PACK) == PACK then return "community" end
	return "all"
end

local function communityMenu(anchor, counts)
	local packs = communityPacks()
	local menu = {}
	for _, r in ipairs(packs) do
		local key = PACK .. r.id
		local text = r.title or r.id
		if r.author then text = text .. DOT .. r.author end
		local n = counts[key]
		if n and n > 0 then text = text .. "  (" .. n .. ")" end
		menu[#menu + 1] = { text = text, icon = "layers", checked = category == key, onClick = function() P.SetCategory(key) end }
	end
	if #menu > 0 then W.ShowMenu(anchor, menu, { point = "TOPLEFT", relPoint = "BOTTOMLEFT", x = 0, y = -4, minWidth = 220 }) end
end

local lastCounts = {}

local function onGuidePill(key)
	if key == "home" or key == "current" or key == "recent" then
		P.SetView(key)
	elseif key == "all" then
		if category == "Favorites" or category:sub(1, #PACK) == PACK then category = "All" end
		P.SetView("browse")
	elseif key == "fav" then
		P.SetCategory("Favorites")
	elseif key == "mine" then
		P.SetCategory(PACK .. MIS_RUTAS)
	elseif key == "community" then
		local packs = communityPacks()
		if #packs == 1 then
			P.SetCategory(PACK .. packs[1].id)
		else
			local anchor
			for _, b in ipairs(rawget(win, "pillButtons") or {}) do if b:IsShown() and b.psKey == "community" then anchor = b end end
			communityMenu(anchor or win.PillRow, lastCounts)
		end
	end
end

local function guidePills(counts, tabs)
	local open = tabs and #tabs or 0
	local items = {
		{ key = "home", label = T(VIEW_LABEL.home) },
		{ key = "all", label = T(VIEW_LABEL.browse) },
	}
	if open > 0 then items[#items + 1] = { key = "current", label = T(VIEW_LABEL.current), count = open } end
	items[#items + 1] = { key = "recent", label = T(VIEW_LABEL.recent) }
	items[#items + 1] = { key = "fav", label = L["Favourites"], count = (counts.Favorites or 0) > 0 and counts.Favorites or nil }
	local packs = communityPacks()
	if #packs > 0 then
		local n = 0
		for _, r in ipairs(packs) do n = n + (counts[PACK .. r.id] or 0) end
		local label = #packs == 1 and (packs[1].title or packs[1].id) or T("Comunidad")
		items[#items + 1] = { key = "community", label = label, count = n > 0 and n or nil, icon = #packs > 1 and "layers" or nil,
			tip = #packs > 1 and T("Guías de la comunidad") or nil }
	end
	local mine = misRutas()
	if mine then
		local n = counts[PACK .. MIS_RUTAS] or 0
		items[#items + 1] = { key = "mine", label = mine.title or T("Mis rutas"), count = n > 0 and n or nil }
	end
	renderPills(items, activePill(), onGuidePill, 200)
end

-- The filter bar: faction, zone or race, level, type, for your level; Clear.
local function factionMenu(anchor)
	local cur = ns.Get("ui.pickerFaction")
	if cur == nil then cur = "auto" end
	local mine = UI.PlayerFaction()
	local items = {}
	if mine then
		items[#items + 1] = { text = string.format(T("Tu facción (%s)"), ns.FactionName(mine)), checked = cur == "auto",
			onClick = function() ns.Set("ui.pickerFaction", "auto"); toBrowse() end }
	end
	for _, f in ipairs(FACTIONS) do
		local text = f == "All" and L["All factions"] or ns.FactionName(f)
		items[#items + 1] = { text = text, checked = cur == f, onClick = function() ns.Set("ui.pickerFaction", f); toBrowse() end }
	end
	W.ShowMenu(anchor, items, { point = "TOPLEFT", relPoint = "BOTTOMLEFT", x = 0, y = -4 })
end

local function placeGrid(anchor)
	local zones, races = placeChoices()
	local groups = { { items = { { text = T("Todas las zonas y razas"), checked = place == nil, onClick = function() P.SetPlace(nil) end } } } }
	if #races > 0 then
		local items = {}
		for _, r in ipairs(races) do
			local key = "race:" .. r.file
			items[#items + 1] = { text = r.name, count = r.count, checked = place == key, onClick = function() P.SetPlace(key) end }
		end
		groups[#groups + 1] = { title = T("Razas"), items = items }
	end
	local items = {}
	for _, z in ipairs(zones) do
		local key = "zone:" .. z.name
		items[#items + 1] = { text = z.name, count = z.count, checked = place == key, onClick = function() P.SetPlace(key) end }
	end
	-- A place no guide of this list holds any more stays choosable to clear it.
	if place and not place:find("^race:") then
		local hit = false
		for _, it in ipairs(items) do if it.checked then hit = true end end
		if not hit then items[#items + 1] = { text = placeLabel(), checked = true, onClick = function() P.SetPlace(nil) end } end
	end
	groups[#groups + 1] = { title = T("Zonas"), items = items }
	Kit.ShowGrid(anchor, groups)
end

local function bandMenu(anchor)
	local items = { { text = T("Todos los niveles"), checked = lband == nil, onClick = function() P.SetLevelBand(nil) end } }
	for _, b in ipairs(LEVEL_BANDS) do
		local key = b.key
		items[#items + 1] = { text = format(T("Niveles %s"), UI.LevelRange(b.lo, b.hi)), checked = lband == key, onClick = function() P.SetLevelBand(key) end }
	end
	W.ShowMenu(anchor, items, { point = "TOPLEFT", relPoint = "BOTTOMLEFT", x = 0, y = -4 })
end

local function typeMenu(anchor, counts)
	local exists = {}
	for _, g in ipairs(ns.Guides and ns.Guides.List and ns.Guides.List() or {}) do
		if not packOf(g) then exists[categoryOf(g)] = true end
	end
	local plain = category == "All" or category == "Favorites" or category:sub(1, #PACK) == PACK
	local items = { { text = T("Todos los tipos"), icon = "compact", checked = plain, onClick = function() P.SetCategory("All") end } }
	for _, c in ipairs(CATEGORIES) do
		if exists[c] then
			local key = c
			local n = counts[c] or 0
			items[#items + 1] = { text = L[c] .. (n > 0 and ("  (" .. n .. ")") or ""), icon = CATEGORY_ICON[c], checked = category == c,
				onClick = function() P.SetCategory(key) end }
		end
	end
	W.ShowMenu(anchor, items, { point = "TOPLEFT", relPoint = "BOTTOMLEFT", x = 0, y = -4, minWidth = 200 })
end

local function buildToolbar()
	local tb = CreateFrame("Frame", nil, gv)
	tb:SetPoint("TOPLEFT", gv, "TOPLEFT", 0, 0)
	tb:SetSize(PAD + LIST_W, TOOL_H)
	gv.Tool = tb
	tb.Faction = Kit.FilterPill(tb, function(b) factionMenu(b) end)
	tb.Faction.psTip = L["Faction filter"]
	tb.Place = Kit.FilterPill(tb, function(b) placeGrid(b) end)
	tb.Place.psTip = T("Zona o raza")
	tb.Band = Kit.FilterPill(tb, function(b) bandMenu(b) end)
	tb.Band.psTip = T("Nivel")
	tb.Type = Kit.FilterPill(tb, function(b) typeMenu(b, lastCounts) end)
	tb.Type.psTip = T("Tipo")
	tb.Fits = Kit.FilterPill(tb, function() P.SetFits(not fits) end)
	tb.Fits.psTip = T("Para tu nivel")
	tb.Clear = Kit.FilterPill(tb, function() P.ClearFilters() end)
	tb.Clear.psTip = T("Quitar filtros")
end

local function renderToolbar()
	local tb = gv.Tool
	local f = factionFilter()
	local mine = UI.PlayerFaction()
	local x = PAD
	local function put(b, w)
		b:ClearAllPoints()
		b:SetPoint("LEFT", tb, "LEFT", x, 0)
		x = x + w + 6
	end
	put(tb.Faction, Kit.SetFilterPill(tb.Faction, f == "All" and L["All factions"] or ns.FactionName(f), { menu = true, active = f ~= mine }))
	put(tb.Place, Kit.SetFilterPill(tb.Place, placeLabel(), { menu = true, active = place ~= nil }))
	put(tb.Band, Kit.SetFilterPill(tb.Band, lband and format(T("Niveles %s"), bandLabel(lband)) or T("Nivel"), { menu = true, active = lband ~= nil }))
	local typed = category ~= "All" and category ~= "Favorites" and category:sub(1, #PACK) ~= PACK
	put(tb.Type, Kit.SetFilterPill(tb.Type, typed and L[category] or T("Tipo"), { menu = true, active = typed, icon = typed and CATEGORY_ICON[category] or nil }))
	local level = playerLevel()
	local fitsText = level and format(T("Para tu nivel (%d)"), level) or T("Para tu nivel")
	put(tb.Fits, Kit.SetFilterPill(tb.Fits, fitsText, { on = fits, icon = fits and "check" or "qol-target" }))
	if filtered() then
		local w = Kit.SetFilterPill(tb.Clear, T("Quitar filtros"), { icon = "close" })
		if x + w <= PAD + LIST_W then put(tb.Clear, w) else tb.Clear:Hide() end
	else
		tb.Clear:Hide()
	end
end

-- Lay the list out: folders over cards, two to a row. -> the height
local function layoutList(view_, entries, tabs, active, byId, openIndex)
	layout = {}
	visibleIds = {}
	local CW = floor((LIST_W - COL_GAP) / 2)
	local y, col, rowH = 6, 0, CARD_H
	local nf, ng, nc = 0, 0, 0
	local function endRow()
		if col == 1 then
			y = y + rowH + COL_GAP
			col = 0
		end
	end
	local function folder(text, count, id)
		endRow()
		if nf > 0 or ng > 0 or nc > 0 then y = y + 8 end
		nf = nf + 1
		layout[#layout + 1] = { t = "folder", x = 0, y = y, w = LIST_W, h = FOLDER_H, text = text, count = count, id = id }
		y = y + FOLDER_H + 8
	end
	local function card(kind, e, h)
		e.t, e.x, e.y, e.w, e.h = kind, col * (CW + COL_GAP), y, CW, h
		layout[#layout + 1] = e
		rowH = h
		if col == 1 then
			y = y + h + COL_GAP
			col = 0
		else
			col = 1
		end
		if e.guide and e.guide.id then visibleIds[#visibleIds + 1] = e.guide.id end
	end
	-- note: the tab an open guide sits in, with its progress where asked.
	local function tabNote(id, withPct)
		local i = openIndex[id]
		if not i then return nil end
		if not withPct then return string.format(L["Tab %d"], i) end
		local t = tabs[i]
		local tot = t.total or t.stepCount or 0
		local pct = tot > 0 and floor((t.done or 0) / tot * 100 + 0.5) or 0
		return string.format(L["Tab %d  \194\183  %d%%"], i, pct)
	end
	local function guide(g, note, shownTitle)
		ng = ng + 1
		card("card", { guide = g, note = note, title = shownTitle }, CARD_H)
	end
	local empty
	local moreY
	if view_ == "browse" then
		-- A search lists every match: no folder folds then.
		local folds = query == ""
		for _, e in ipairs(entries) do
			if e.kind == "folder" then
				folder(e.text, e.count, folds and e.id or nil)
			elseif not (folds and P.IsCollapsed(e.folder.id)) then
				guide(e.guide, tabNote(e.guide.id), e.title)
			end
		end
	elseif view_ == "home" then
		if tabs and #tabs > 0 then
			folder(T("Sigue donde ibas"), #tabs)
			local order = cardOrder(tabs, active)
			local shown = allCards and #order or min(#order, 2)
			for k = 1, shown do
				local i = order[k]
				local t = tabs[i]
				nc = nc + 1
				card("cont", { tab = t, index = i, active = active, guide = byId[t.guideId] or { id = t.guideId, title = t.title } }, CONT_H)
			end
			endRow()
			if #order > 2 then moreY = y - 4; y = y + 24 end
		end
		local sugg = suggestions(byId, tabs, openIndex)
		if #sugg > 0 then
			folder(T("Recomendadas para ti"), #sugg)
			local shown = P.Titles(sugg)
			for _, g in ipairs(sugg) do guide(g, tabNote(g.id), shown[g]) end
		end
		if nc == 0 and #sugg == 0 then empty = T("Aún no tienes nada abierto. Mira Todas o usa los filtros de arriba para encontrar una guía.") end
	elseif view_ == "current" then
		if tabs and #tabs > 0 then
			folder(L["Open tabs"], #tabs)
			local open = {}
			for _, t in ipairs(tabs) do open[#open + 1] = byId[t.guideId] end
			local shown = P.Titles(open)
			for _, g in ipairs(open) do guide(g, tabNote(g.id, true), shown[g]) end
		else
			empty = L["No guide is open. Load one and it shows up here."]
		end
	else
		-- The tabs the player closed, newest first (Engine.ClosedTabs): opened
		-- again, each comes back at the step it was on. Then the last guides loaded.
		local E, shut, listed = ns.Engine, {}, {}
		for _, c in ipairs(E and E.ClosedTabs and E.ClosedTabs() or {}) do
			local g = byId[c.guideId]
			if g then
				shut[#shut + 1] = g
				listed[g.id] = true
			end
		end
		if #shut > 0 then
			folder(L["Recently closed"], #shut)
			local shown = P.Titles(shut)
			for _, g in ipairs(shut) do guide(g, nil, shown[g]) end
		end
		local recent = {}
		for _, id in ipairs(P.Recent()) do if byId[id] and not listed[id] then recent[#recent + 1] = byId[id] end end
		if #recent > 0 then
			folder(L["Recently loaded"], #recent)
			local shown = P.Titles(recent)
			for _, g in ipairs(recent) do guide(g, tabNote(g.id), shown[g]) end
		elseif #shut == 0 then
			empty = L["Guides you load show up here."]
		end
	end
	endRow()
	return y, empty, moreY, { guides = ng, folders = nf, cards = nc }
end

local function renderGuides()
	local filter = factionFilter()
	-- The other faction's guides come in when the filter asks for them
	-- (Guides.LoadFaction): their load fires GUIDES_REGISTERED, which renders.
	if filter ~= UI.PlayerFaction() and ns.Guides and ns.Guides.LoadFaction and ns.Guides.LoadFaction(filter) then return end
	-- A pack entry whose pack was hidden or holds no guides (Mis rutas may be
	-- empty: it says how to make one), or a category no shown guide is in:
	-- back to All.
	if category:sub(1, #PACK) == PACK then
		local r = packOfKey(category)
		local ok = r and r.status == "on" and ((r.guideCount or 0) > 0 or r.id == MIS_RUTAS)
		if not ok then category = "All" end
	elseif category ~= "All" and category ~= "Favorites" then
		local shown = false
		for _, g in ipairs(ns.Guides and ns.Guides.List and ns.Guides.List() or {}) do
			if not packOf(g) and categoryOf(g) == category then
				shown = true
				break
			end
		end
		if not shown then category = "All" end
	end
	rankSuggestions()
	curLevel = playerLevel()
	local entries, n, counts = P.Entries(filter, query, view == "browse" and category or "All", filterOpts())
	lastCounts = counts
	-- P.categories: every list the pills and the type menu reach (tests).
	P.categories = { "All" }
	for _, c in ipairs(CATEGORIES) do if counts[c] then P.categories[#P.categories + 1] = c end end
	P.categories[#P.categories + 1] = "Favorites"
	for _, r in ipairs(communityPacks()) do P.categories[#P.categories + 1] = PACK .. r.id end
	if misRutas() then P.categories[#P.categories + 1] = PACK .. MIS_RUTAS end

	local byId = headersById()
	local tabs, active = tabsInfo()
	local openIndex = {}
	for i, t in ipairs(tabs or {}) do openIndex[t.guideId] = i end

	guidePills(counts, tabs)
	renderToolbar()

	-- What the list holds, right of the pills.
	local subtitle
	if newTabMode then
		subtitle = L["Pick a guide to open in a new tab."]
	elseif view == "browse" then
		if query ~= "" then
			subtitle = n == 1 and string.format(L["1 result for \226\128\156%s\226\128\157"], query)
				or string.format(L["%d results for \226\128\156%s\226\128\157"], n, query)
		else
			local parts = { n == 1 and L["1 guide"] or string.format(L["%d guides"], n), filter == "All" and L["All factions"] or ns.FactionName(filter) }
			local open = tabs and #tabs or 0
			if open > 0 then parts[#parts + 1] = string.format(L["%d open"], open) end
			subtitle = table.concat(parts, DOT)
		end
	elseif view == "home" then
		subtitle = L["Pick up where you left off, or start something new."]
	elseif view == "current" then
		subtitle = L["The guides open in your tabs."]
	else
		subtitle = L["The tabs you closed and the last guides you loaded."]
	end
	W.ShellTitle(win, L["Guides"], subtitle)

	local child = gv.List.Child
	local y, empty, moreY, counted = layoutList(view, entries, tabs, active, byId, openIndex)
	-- The last search's Codex matches go away first; a browse with a query
	-- draws them again below.
	if UI.HideLookupRows then UI.HideLookupRows(child) end
	local turnOn
	if view == "browse" then
		-- Items, NPCs and quests that match, under the guides (UI/Lookup.lua).
		if query ~= "" and UI.LookupRows then
			y = UI.LookupRows(child, y, query, LIST_W, LIST_X)
			local codex = UI.LookupTotal and UI.LookupTotal() or 0
			if codex > 0 and not newTabMode then
				W.ShellTitle(win, L["Guides"], string.format(L["%s  \194\183  %d in the Codex for \226\128\156%s\226\128\157"],
					n == 1 and L["1 guide"] or string.format(L["%d guides"], n), codex, query))
			end
		end
		if n == 0 and not (query ~= "" and UI.LookupCount and UI.LookupCount() > 0) then
			if #(ns.Guides and ns.Guides.List and ns.Guides.List() or {}) == 0 then
				local Pk = UI.Packs
				if Pk and Pk.OwnGuidesOff() then
					empty = L["No guides: Alfa Guides is installed but unticked in the game's AddOns list."]
					turnOn = true
				elseif Pk and Pk.OursSwitchedOff() then
					empty = L["No guides shown: Alfa's own guides are switched off. Turn them on under Options, Community guides (/alfa packs)."]
				elseif Pk and Pk.AnySwitchedOff() then
					empty = L["No guides shown: the community addons are switched off. Turn one on under Options, Community guides (/alfa packs)."]
				else
					empty = L["No guides installed. Enable Alfa Guides or a community addon in the AddOns list on the character screen, then reload."]
				end
			elseif query ~= "" then
				empty = string.format(L["No guides match \226\128\156%s\226\128\157."], query)
			elseif category == PACK .. MIS_RUTAS then
				empty = T("Aún no tienes rutas. Ármalas en la ventana de Alfa: Aventura > Rutas; cada una aparece aquí como guía.")
			elseif category == "Favorites" then
				empty = L["No favourites yet. Select a guide and click its star."]
			elseif filterOpts() then
				empty = T("Ninguna guía cumple estos filtros. Quita alguno para ver más.")
			elseif category ~= "All" then
				empty = string.format(L["No %s guides for this faction."], bucketLabel(category))
			else
				empty = L["No guides for this faction."]
			end
		end
	end
	-- Home's "Show all (N)" / "Show fewer" under the open tabs' cards.
	local more = gv.More
	if moreY then
		local order = tabs and #tabs or 0
		W.SetButtonText(more, allCards and L["Show fewer"] or string.format(L["Show all (%d)"], order))
		more:ClearAllPoints()
		more:SetPoint("TOPLEFT", child, "TOPLEFT", LIST_X - 8, -moreY)
		more:Show()
	else
		more:Hide()
	end
	if empty then
		-- Where guides can show up, say how to load one once they do.
		if #(ns.Guides and ns.Guides.List and ns.Guides.List() or {}) > 0 and category ~= PACK .. MIS_RUTAS then empty = empty .. "\n\n" .. loadHint() end
		gv.Empty:SetText(empty)
		gv.Empty:ClearAllPoints()
		gv.Empty:SetPoint("TOPLEFT", child, "TOPLEFT", LIST_X, -(y + 12))
		gv.Empty:Show()
		y = y + 12 + gv.Empty:GetStringHeight()
	else
		gv.Empty:Hide()
	end
	-- Alfa Guides unticked in the AddOns list: one click turns it on.
	if turnOn then
		W.SetButtonText(gv.TurnOn, L["Turn on Alfa Guides and reload"])
		gv.TurnOn:ClearAllPoints()
		gv.TurnOn:SetPoint("TOPLEFT", child, "TOPLEFT", LIST_X, -(y + 12))
		gv.TurnOn:Show()
		y = y + 12 + gv.TurnOn:GetHeight()
	else
		gv.TurnOn:Hide()
	end
	gv.Watermark:SetShown(empty ~= nil and #layout == 0)
	child:SetWidth(LIST_X + LIST_W + 8)
	W.SetScrollContent(gv.List, y + 16)
	fitSubtitle()
	paintVisible()
	renderDetails(byId, tabs)
	P.shown = { view = view, guides = counted.guides, folders = counted.folders, cards = counted.cards, filters = P.Filters() }
end

---------------------------------------------------------------------------
-- Render
---------------------------------------------------------------------------

function P.Render()
	if not (win and win:IsShown()) then return end
	local active = activeSection()
	if not active then section = nil end
	renderSections()
	searchFor(active)
	if active then
		gv:Hide()
		sectionPills(active)
		renderSection(active)
		return
	end
	for _, s in ipairs(sections) do if s.psFrame then s.psFrame:Hide() end end
	W.ShellTabs(win, nil)
	gv:Show()
	renderGuides()
end

-- Searching: keep the selection among the results, so Enter loads what
-- the list shows.
local function selectFirstResult()
	local sel = P.Selected()
	for _, id in ipairs(visibleIds) do if id == sel then return end end
	if visibleIds[1] then P.Select(visibleIds[1]) end
end

function P.SetView(v)
	view = v or "home"
	section = nil
	if view ~= "browse" and query ~= "" then
		query = ""
		if win then win.Search:SetText("") end
	end
	if win and win:IsShown() then
		W.ScrollTo(gv.List, 0)
		P.Render()
	end
end

function P.View() return view end

function P.SetCategory(c)
	category = c or "All"
	P.SetView("browse")
end

function P.Category() return category end
function P.IsNewTabMode() return newTabMode end

-- Arrow keys in the search box walk the shown guides.
local function step(delta)
	if #visibleIds == 0 then return end
	local sel, at = P.Selected(), nil
	for i, id in ipairs(visibleIds) do if id == sel then at = i end end
	at = at and min(#visibleIds, max(1, at + delta)) or 1
	P.Select(visibleIds[at])
	reveal()
end
P.Step = step

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------

local function onSearch(text)
	text = text or ""
	if questContext and text ~= questContext.query then questContext = nil end
	if text == query then return end
	-- A section with its own search takes the box while it is shown; in any
	-- other section typing goes back to the guides.
	local s = activeSection()
	if s and s.search then
		query = text
		s.search(text)
		return
	end
	if s and text ~= "" then section = nil end
	-- A new search looks through every guide; a category picked while
	-- searching narrows it.
	if query == "" and text ~= "" then category = "All" end
	query = text
	if not (win and win:IsShown()) then return end
	if query ~= "" then view = "browse" end
	W.ScrollTo(gv.List, 0)
	P.Render()
	if query ~= "" then selectFirstResult() end
end

local function build()
	win = W.Shell("AlfaPicker", {
		top = true, width = HUB_W, height = HUB_H, title = "", scalePath = "ui.menuScale",
		searchPlaceholder = HUB_SEARCH, onSearch = onSearch, searchWidth = 260,
	})
	-- No rail nor sidebar: a section has the window's whole width.
	win.psSidebar, win.psRail = 0, 0
	P.frame = win
	P.search = win.Search
	-- The hub draws its own columns; no footer.
	win.Content:Hide()
	W.ShellFooter(win, nil, nil)

	win.Search:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
		local s = activeSection()
		if s and s.enter then s.enter() elseif not s then P.LoadSelected() end
	end)
	win.Search:SetScript("OnArrowPressed", function(_, key)
		local d = key == "UP" and -1 or (key == "DOWN" and 1 or nil)
		if not d then return end
		local s = activeSection()
		if s and s.step then s.step(d) elseif not s then step(d) end
	end)

	-- Guides: the filter bar and the list on the left, the ficha on the right.
	gv = CreateFrame("Frame", nil, win.Main)
	gv:SetPoint("TOPLEFT", win.PillRow, "BOTTOMLEFT", 0, 0)
	gv:SetPoint("BOTTOMRIGHT", win.Main, "BOTTOMRIGHT", 0, 0)
	P.view = gv
	buildToolbar()
	local sf = W.Scroll(gv)
	sf:SetPoint("TOPLEFT", gv, "TOPLEFT", PAD - LIST_X, -TOOL_H)
	sf:SetPoint("BOTTOMLEFT", gv, "BOTTOMLEFT", PAD - LIST_X, 4)
	sf:SetWidth(LIST_X + LIST_W + 10)
	-- Cards are drawn for what is in view: scrolling draws the rest.
	sf:HookScript("OnMouseWheel", function() paintVisible() end)
	sf:HookScript("OnVerticalScroll", function() paintVisible() end)
	sf:HookScript("OnSizeChanged", function() paintVisible() end)
	gv.List = sf
	P.scroll = sf
	gv.Watermark = gv:CreateTexture(nil, "BACKGROUND", nil, -4)
	gv.Watermark:SetTexture(Theme.Media("watermark"))
	gv.Watermark:SetSize(260, 260)
	gv.Watermark:SetPoint("CENTER", sf, "CENTER", 0, 0)
	W.Painter(gv.Watermark, function(t) t:SetVertexColor(Theme.Wash("watermark")) end)
	gv.Watermark:Hide()
	gv.Empty = W.Text(sf.Child, "note", "textMuted")
	gv.Empty:SetWordWrap(true)
	gv.Empty:SetJustifyV("TOP")
	gv.Empty:SetWidth(LIST_W - 40)
	gv.Empty:Hide()
	gv.TurnOn = W.Button(sf.Child, "", function()
		if UI.Packs then UI.Packs.TurnOnOwnGuides() end
	end, { primary = true })
	gv.TurnOn:Hide()
	gv.More = W.Button(sf.Child, "", function()
		allCards = not allCards
		P.Render()
	end, { ghost = true, height = 24 })
	gv.More.psTight = true
	gv.More:Hide()
	win.factionButtons = { gv.Tool.Faction }

	buildDetails()
	win:HookScript("OnShow", function() P.Render() end)
	win:HookScript("OnHide", function() Kit.HideGrid() end)
	-- A gamepad moves through the hub (UI/Gamepad.lua): LB / RB step the
	-- sections, X loads the guide on a focused card, Y closes an open tab's
	-- card.
	if ns.Gamepad and ns.Gamepad.Register then
		ns.Gamepad.Register(win, {
			initial = function(rows)
				-- The selected guide, else the first card, else a folder header.
				local first, header
				for i, w in ipairs(rows) do
					if ns.Gamepad.Within(w, gv) and w.psKey == nil then
						if w.psGuide and w.psGuide.id == P.Selected() then return i end
						if w.psFolder then header = header or i elseif w.psGuide then first = first or i end
					end
				end
				return first or header
			end,
			prevTab = function() P.StepSection(-1) end,
			nextTab = function() P.StepSection(1) end,
			tabsLabel = L["Sections"],
			x = function(w)
				if w and w.psGuide and w.psGuide.id then
					P.Select(w.psGuide.id)
					P.LoadSelected()
				end
			end,
			xLabel = function(w) return w and w.psGuide and T("Usar esta guía") or nil end,
			reset = function(w)
				if not (w and w.psCard) then return false end
				closeCard(w)
				return true
			end,
			resetLabel = function(w) return w and w.psCard and L["Close tab"] or nil end,
		})
	end
end

-- El centro del motor, sin pasar por los reemplazos (Core/Reemplazos.lua):
-- lo usan sus secciones (Buscador, Mazmorras, Talentos, Raros, Personajes,
-- Importar) cuando no tienen ventana de Alfa propia, aunque el selector de
-- guias si la tenga. opts: { newTab = true } when loading should open a new tab.
local function abrirCentro(opts)
	if not win then build() end
	newTabMode = type(opts) == "table" and opts.newTab and true or false
	-- Remember the last selection; without one, start on the open guide or
	-- the suggestion.
	local byId = headersById()
	local sel = P.Selected()
	if not (sel and byId[sel]) then
		sel = nil
		local tabs, active = tabsInfo()
		if tabs and active and tabs[active] then sel = tabs[active].guideId end
		local G = ns.Guides
		if not sel and G and G.Suggest then sel = G.Suggest() end
		uiState().pickerSelected = sel and byId[sel] and sel or nil
	end
	-- The folder holding the open guide starts expanded (#1358).
	if not win:IsShown() then
		local tabs, active = tabsInfo()
		local open = tabs and active and tabs[active] and tabs[active].guideId
		if open then P.SetCollapsed(P.FolderOf(open), false) end
	end
	local settings = UI.Options and UI.Options.frame
	if win:IsShown() then
		P.Render()
	else
		if settings and settings:IsShown() then P.TakePlace(win, settings) end
		win:Show()
	end
	if settings then settings:Hide() end
end

-- El centro del motor en la seccion `seccion` (nil: la que tenia).
function UI.AbrirCentro(seccion, opts)
	abrirCentro(opts)
	if seccion then P.ShowSection(seccion) end
end

-- El selector de guias. Con su ventana reemplazada (SHOW_PICKER) abre la de
-- Alfa con { pestanaNueva, opciones }; el centro del motor, si estaba
-- abierto, se cierra.
function UI.ShowPicker(opts)
	local R = ns.Reemplazos
	local nueva = type(opts) == "table" and opts.newTab and true or false
	if R and R.Llamar("SHOW_PICKER", { pestanaNueva = nueva, opciones = opts }) then
		if win and win:IsShown() then win:Hide() end
		return
	end
	abrirCentro(opts)
end

-- A new font measures the pills, the cards and the ficha's label column
-- anew: the hub on screen renders again.
W.OnFontChanged(function()
	if win and win:IsShown() then P.Render() end
end)

function P.SetQuery(text)
	if not win then build() end
	win.Search:SetText(text or "")
	onSearch(text or "")
end

-- A quest menu searches installed guides, including those without a Codex.
function P.ShowQuest(id)
	id = readable(id)
	if type(id) ~= "number" or id <= 0 or id >= math.huge or id % 1 ~= 0 then return false end
	if ns.Reemplazos and ns.Reemplazos.Llamar("SHOW_PICKER", { mision = id }) then
		if win and win:IsShown() then win:Hide() end
		return true
	end
	abrirCentro()
	P.ShowSection("Guides")
	-- Every guide that has the quest: no filter of the list hides one.
	place, lband, fits = nil, nil, false
	P.SetCategory("All")
	-- The filter is account-wide: only lift one that hides this character's
	-- faction, and back to "auto" so an alt of the other faction is not left
	-- filtered to this one.
	local filter = factionFilter()
	if filter ~= "All" and filter ~= UI.PlayerFaction() then ns.Set("ui.pickerFaction", "auto") end
	local name = UI.QuestTitle(id) or (ns.Names and ns.Names.Quest(id))
	questContext = { id = id, query = name or tostring(id), steps = {} }
	P.SetQuery(questContext.query)
	P.Render()
	if #visibleIds == 0 then P.Select(nil) else selectFirstResult() end
	win.Search:SetFocus()
	return true
end

ns.On("GUIDE_CHANGED", function(id)
	remember(id)
	P.Render()
end)
ns.On("SETTING_CHANGED", function(path)
	if path == "ui.pickerFaction" or path == "ui.pickerCollapsed" or path == "" or path == "ui" then P.Render() end
end)
-- The filter is account-wide: a character of the other faction logging in
-- after "Horde" or "Alliance" was picked would open on the wrong side's
-- guides. Back to "auto" (this character's faction) at login; "All" stays.
ns.OnLogin(function()
	local f = ns.Get("ui.pickerFaction")
	local mine = UI.PlayerFaction()
	if mine and (f == "Alliance" or f == "Horde") and f ~= mine then ns.Set("ui.pickerFaction", "auto") end
end)
local function guidesChanged()
	factCache = {}
	if questContext then questContext.steps = {} end
	P.Render()
end
ns.On("GUIDES_REGISTERED", guidesChanged)
ns.On("PACKS_CHANGED", guidesChanged)
ns.On("TABS_CHANGED", function() P.Render() end)
-- A level up moves "For your level" and the recommendation.
if ns.RegisterEvent then
	ns.RegisterEvent("PLAYER_LEVEL_UP", function()
		if ns.After then ns.After(0.5, function() P.Render() end) else P.Render() end
	end)
end
