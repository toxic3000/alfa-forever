-- El diario de mazmorras del motor, una seccion del centro (la ventana del
-- selector de guias). Basado en la seccion Dungeons de Polestar (GPL-3.0, The
-- Polestar authors); reescrito por toxic3000 / La Jauria con la interfaz propia
-- de Alfa (docs/INTERFAZ.md).
--
-- Un diario de misiones por mazmorra y banda, como el Diario de mazmorras
-- del juego acomoda sus paginas (cada mision con donde empieza y termina, su
-- objetivo, su cadena y sus recompensas; los jefes con las misiones que van
-- con ellos; la entrada). Sin tablas de botin. Los datos: Alfa.Dungeons
-- (Dungeons/Dungeons.lua) sobre el Codex, cargado al primer vistazo; una
-- pagina decodificada a la vez.
--
-- Inicio: pildoras con los tramos (Para tu nivel, Todas, 10-20 ... 50-60,
--   Bandas) y sus cuentas; la barra de filtros con la faccion; las mazmorras
--   en tarjetas de esquinas cortadas de dos en dos, en orden de nivel: el
--   arte de su zona centrado en la entrada, el nombre, su rango ("35–47 ·
--   mejor en 43"), donde, las misiones para la faccion elegida, y sus
--   etiquetas (Tu nivel, Dificil a tu nivel, Forever). En Todas, los tramos
--   encabezan sus tarjetas. Solo las tarjetas a la vista pintan su arte.
--
-- Una mazmorra: las pildoras son sus pestanas (Todas las mazmorras para
--   volver, Misiones, Llaves o Requisitos cuando tiene, Jefes y Entrada).
--   Arriba, su ficha: el arte de la zona con la entrada marcada, el nombre,
--   lo que valen sus misiones en niveles (Dungeons.QuestXP; al pasar el
--   raton, su panel), los datos, la faccion, y las acciones: "Entregar las
--   misiones" (mientras alguna esta en el registro; primaria cuando una esta
--   lista: una guia de Dungeons.HandIn), "Recoger las misiones" (primaria
--   mientras hay que recoger y nada que entregar: Dungeons.PickUp), cada una
--   en una pestana nueva, "Guiame a la entrada" (primaria si no) con "Nada
--   que recoger" diciendo por que, y "Ver en el mapa".
--   Misiones: un panel por mision: el nombre en el color de su dificultad
--   (aclarado a 4.5:1), el estado de este personaje (hecha, en el registro,
--   lista, nivel bajo, no es para tu clase o raza), nivel y requisito, para
--   quien es ("Solo brujo" en el color de la clase, razas tambien), faccion,
--   si se comparte, si se recoge dentro; una columna de etiquetas con el
--   objetivo, donde empieza y termina (cada uno con su chincheta que pone la
--   flecha; la linea Empieza entera es un enlace al que la da, o al primer
--   requisito pendiente), la cadena antes de ella (una linea por mision, la
--   siguiente sobre el acento; al pasar el raton, sus datos) y las
--   recompensas (iconos en el borde de su calidad, "Elige una", XP, dinero,
--   reputacion; tras una cadena pendiente, lo que vale con ella,
--   Dungeons.ChainXP, con el panel de niveles).
--   Requisitos: por requisito o llave (Dungeons.Attunements) su nombre, el
--   estado de este personaje, los datos, la nota, el objeto y si lo tienes,
--   "Guiame" (Dungeons.Attune, en una pestana nueva) y una fila por paso.
--   Jefes: en orden, nombre, nivel y las misiones de cada uno.
--   Entrada: la entrada sobre el arte de su zona, con los que dan misiones.
-- Filas, paneles, iconos y tarjetas se reusan entre paginas.
--
-- Se registra con UI.RegisterSection; se abre con SHOW_DUNGEON(key)
-- (Dungeons.Open). Dungeons.GuideTo pone la flecha en la entrada.

local ADDON, ns = ...
local UI, Theme, W = ns.UI, ns.Theme, ns.Widgets
local L = ns.L
local T = ns.T
local floor, ceil, max, min, type, ipairs, pairs, tostring, format, pcall = math.floor, math.ceil, math.max, math.min, type, ipairs, pairs, tostring, string.format, pcall
local lower, find, concat = string.lower, string.find, table.concat
local ZoneArt = UI.ZoneArt
local Kit = UI.HubKit

local SH = W.SHELL
local PAD = SH.pad -- every text edge inside a panel
local GUT = PAD / 2 -- state glyphs in the gutter
local EDGE = Kit.PAD -- the panels' and cards' left edge in the section
local CARD_GAP = Kit.COL_GAP
local CARD_H = 100
local THUMB_W, THUMB_H = 150, CARD_H - 16
local HERO_H = 118
local HERO_ART_W = 210
local LABEL_W = 88 -- a quest's label column
local VALUE_X = PAD + LABEL_W
local TILE_W, TILE_H, TILE_GAP = 200, 32, 8
local CHAIN_H = 26
local TIE_H = 24
local MAP_H = 296
local DOT = "  \194\183  "

local DS = {}
UI.DungeonsSection = DS

local BANDS = {
	{ key = "10", lo = 10, hi = 20 },
	{ key = "20", lo = 20, hi = 30 },
	{ key = "30", lo = 30, hi = 40 },
	{ key = "40", lo = 40, hi = 50 },
	{ key = "50", lo = 50, hi = 60 },
}
local SIDE = { Alliance = "A", Horde = "H" }

local band -- the pills' band; nil until the first render picks one
local page -- the dungeon shown, nil on Home
local tab = "quests"
local filter = ""
local root, hub, home, pg, segs
local cards, heads, blocks, bossRows, ties, givers = {}, {}, {}, {}, {}, {}
local atts, attSteps = {}, {} -- the Attunement tab: one panel per attunement, one row per step
local listCache
local shown = {} -- what the last render put up, for tests and the preview

local function D() return ns.Dungeons end

-- A faction's name in the client's language (Names.Faction), else the data's.
local function factionName(id, name)
	local N = ns.Names
	return (N and N.Faction and N.Faction(id)) or name
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local secret = ns.Compat.IsSecret

-- The section's width: the hub's (no rail nor sidebar).
local function mainWidth()
	local w = hub and (hub:GetWidth() - (hub.psRail or 0) - (hub.psSidebar or SH.sidebar) - 2) or 0
	if w <= 0 then w = Kit.HUB_W - 2 end
	return w
end

local function questWidth() return mainWidth() - EDGE * 2 end

local function viewHeight(sf)
	local h = sf and sf:GetHeight() or 0
	if h <= 0 then h = Kit.HUB_H - 220 end
	return h
end

local function uiState()
	local s = ns.CharState()
	if type(s.ui) ~= "table" then s.ui = {} end
	return s.ui
end

local function factionKey()
	local f = uiState().dungeonsFaction
	if f ~= "Alliance" and f ~= "Horde" and f ~= "All" then f = UI.PlayerFaction() or "All" end
	return f
end

local function playerLevel()
	local C = ns.Compat
	local info = C and C.GetPlayerInfo and C.GetPlayerInfo()
	return info and info.level or 1
end

local function thousands(n)
	local s = tostring(floor(n or 0))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then out = out:sub(2) end
	return out
end

local function money(copper)
	local LK = UI.Lookup
	if LK and LK.Money then return LK.Money(copper) end
	return nil
end

-- r, g, b moved toward the text colour until it reads at 4.5:1 on the
-- lightest ground (Theme.Legible).
local lift = Theme.Legible

local function hexOf(r, g, b)
	return format("ff%02x%02x%02x", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
end

-- The client's difficulty colour for a quest level, as the quest log draws
-- it (GetQuestDifficultyColor; its QuestDifficultyColors by level gap
-- otherwise), lifted.
local function difficulty(level, plevel)
	local r, g, b
	if type(level) == "number" then
		if GetQuestDifficultyColor then
			local ok, c = pcall(GetQuestDifficultyColor, level)
			if ok and type(c) == "table" and type(c.r) == "number" and not secret(c.r) then r, g, b = c.r, c.g, c.b end
		end
		local t = not r and QuestDifficultyColors
		if type(t) == "table" then
			local d = level - plevel
			local key
			if d >= 5 then key = "impossible"
			elseif d >= 3 then key = "verydifficult"
			elseif d >= -4 then key = "difficult"
			else
				local C = ns.Compat
				key = (C and C.IsQuestTrivial and C.IsQuestTrivial(level, plevel)) and "trivial" or "standard"
			end
			local c = t[key]
			if type(c) == "table" and type(c.r) == "number" then r, g, b = c.r, c.g, c.b end
		end
	end
	if not r then r, g, b = Theme.Color("quest") end
	return lift(r, g, b)
end

local function paintRGB(fs, r, g, b)
	W.Uncolor(fs)
	fs:SetTextColor(r, g, b, 1)
end

-- The client's colour for an item quality (unlifted, for borders), or nil.
local function qualityRaw(q)
	if type(q) ~= "number" then return nil end
	local C = C_Item
	if C and C.GetItemQualityColor then
		local ok, r, g, b = pcall(C.GetItemQualityColor, q)
		if ok and type(r) == "number" and not secret(r) then return r, g, b end
	end
	local t = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
	if type(t) == "table" and type(t.r) == "number" then return t.r, t.g, t.b end
	return nil
end

local function itemIcon(id)
	local C = C_Item
	if type(id) ~= "number" or not (C and C.GetItemIconByID) then return nil end
	local ok, icon = pcall(C.GetItemIconByID, id)
	if ok and icon and not secret(icon) then return icon end
	return nil
end

-- A reward tile's border and name in the item's colour: what the game's
-- tooltip draws, else the client's quality, else the page's (built from the
-- client's tables, which can disagree with the game: Axe of Orgrimmar, #837).
-- A tile whose item is not loaded yet asks for it and is painted again when
-- it arrives (GET_ITEM_INFO_RECEIVED below).
local tilesWaiting = {}
local function paintTile(t, id, quality)
	t.psQuality = quality
	local C = ns.Compat
	local qr, qg, qb = C.ItemTipColor(id)
	if not qr then
		if type(id) == "number" and not C.RequestItem(id) then
			local waiting = tilesWaiting[id] or {}
			tilesWaiting[id] = waiting
			waiting[t] = true
		end
		qr, qg, qb = qualityRaw(C.GetItemQuality(id) or quality)
	end
	if qr then
		Theme.Border(t.Well, qr, qg, qb, 0.9)
		paintRGB(t.Name, lift(qr, qg, qb))
	else
		local ir, ig, ib = Theme.Wash("border")
		Theme.Border(t.Well, ir, ig, ib, 0.6)
		W.Color(t.Name, "item")
	end
end

ns.RegisterEvent("GET_ITEM_INFO_RECEIVED", function(_, id)
	local waiting = tilesWaiting[id]
	if not waiting then return end
	tilesWaiting[id] = nil
	for t in pairs(waiting) do
		if t.psID == id and t:IsShown() then paintTile(t, id, t.psQuality) end
	end
end)

local mapName = ns.Compat.MapName

local function bandOf(level)
	if type(level) ~= "number" then return nil end
	for i = #BANDS, 1, -1 do
		if level >= BANDS[i].lo then return BANDS[i].key end
	end
	return BANDS[1].key
end

local function bandLabel(key)
	for _, b in ipairs(BANDS) do
		if b.key == key then return UI.LevelRange(b.lo, b.hi) end
	end
	return key
end

-- For your level: from the dungeon's recommended start to its top (Fitz,
-- 2026-11-08: the Ruins of Lordaeron, 15-22, is not for a level
-- 13; an overlap with a wide window let it in from 13).
local function forYou(d, plevel)
	if d.kind == "raid" or not d.minLevel then return false end
	return plevel >= d.minLevel and plevel <= (d.maxLevel or d.minLevel)
end

-- The level the dungeon suits best (Dungeons.BestAt), nil without one.
local function bestAt(d)
	return D().BestAt and D().BestAt(d.key) or nil
end

-- In range but 4+ levels under where it suits best: "Tough at your level"
-- (Uldaman, 35-47, best at 43, at 35).
local TOUGH = 4
local function tough(d, plevel)
	local b = bestAt(d)
	return b ~= nil and plevel <= b - TOUGH
end

-- "best at 43" after a range wider than one level, nil otherwise.
local function bestAtFact(d)
	local b = bestAt(d)
	if not b or not d.minLevel or (d.maxLevel or d.minLevel) <= d.minLevel then return nil end
	return format(T("mejor en %d"), b)
end

-- The range as the cards say it: "35–47 · best at 43".
local function rangeText(d)
	local lv = UI.LevelRange(d.minLevel, d.maxLevel)
	local best = bestAtFact(d)
	if lv and best then return lv .. DOT .. best end
	return lv or best
end

-- Quests on a page for the filter ("All": both factions).
local function questCount(d, f)
	local q = d.quests or {}
	if f == "All" then return max(q.A or 0, q.H or 0), q.A or 0, q.H or 0 end
	return q[SIDE[f]] or 0
end

-- For your level under the filter: a dungeon whose quests are all the other
-- faction's is theirs, not yours; so is one whose way in lies inside their
-- capital (Dungeons.EnemyCapital: The Hall of Thanes is not a Horde dungeon).
local function forYouAs(d, plevel, f)
	if not forYou(d, plevel) then return false end
	if f == "All" then return true end
	if D().EnemyCapital and D().EnemyCapital(d.key, SIDE[f]) then return false end
	local q = d.quests or {}
	return (q[SIDE[f]] or 0) > 0 or ((q.A or 0) == 0 and (q.H or 0) == 0)
end

local function list()
	if not listCache then listCache = D().List() end
	return listCache
end

-- The cards a band shows, in level order; For your level, the ones that fit
-- first, by closeness to where each suits best, the tough ones after.
local function entries(key, plevel, f)
	local out = {}
	local q = filter ~= "" and lower(filter) or nil
	for _, d in ipairs(list()) do
		local ok
		if q then
			ok = find(lower(d.name), q, 1, true) ~= nil
		elseif key == "level" then
			ok = forYouAs(d, plevel, f)
		elseif key == "raid" then
			ok = d.kind == "raid"
		elseif key == "all" then
			ok = d.kind ~= "raid"
		else
			ok = d.kind ~= "raid" and bandOf(d.minLevel) == key
		end
		if ok then out[#out + 1] = d end
	end
	if key == "level" and not q then
		local rank = {}
		for i, d in ipairs(out) do
			local b = bestAt(d) or plevel
			rank[d] = { tough(d, plevel) and 1 or 0, b > plevel and b - plevel or plevel - b, i }
		end
		table.sort(out, function(a, b)
			local ra, rb = rank[a], rank[b]
			if ra[1] ~= rb[1] then return ra[1] < rb[1] end
			if ra[2] ~= rb[2] then return ra[2] < rb[2] end
			return ra[3] < rb[3]
		end)
	end
	return out
end

-- Quest state for this character: "done", "ready", "log", "class" / "race"
-- (not for this character's class or race: Dungeons.QuestFor, the rule the
-- pick-up guide leaves it out by), "low", "open".
local function questState(q, plevel)
	local C = ns.Compat
	if C and q.id then
		if C.IsQuestCompleted and C.IsQuestCompleted(q.id) then return "done" end
		if C.IsOnQuest and C.IsOnQuest(q.id) then
			if C.IsQuestReadyForTurnIn and C.IsQuestReadyForTurnIn(q.id) then return "ready" end
			return "log"
		end
	end
	local _, why = D().QuestFor(q)
	if why then return why end
	if q.minLevel and plevel < q.minLevel then return "low" end
	return "open"
end

local STATE_GLYPH = {
	done = { "check", "success" }, ready = { "icon-turnin", "success" }, log = { "icon-turnin", "quest" },
	class = { "lock", "textMuted" }, race = { "lock", "textMuted" },
	low = { "lock", "warning" }, open = { "icon-accept", "quest" },
}

local function stateChip(state, q)
	if state == "done" then return L["Done"], "success" end
	if state == "ready" then return L["Ready to turn in"], "success" end
	if state == "log" then return L["In your log"], "neutral" end
	if state == "class" then return L["Not for your class"], "neutral" end
	if state == "race" then return L["Not for your race"], "neutral" end
	if state == "low" then return format(L["From level %d"], q.minLevel), "warning" end
	return nil
end

-- Who a quest is for (Dungeons.QuestFor), "Warlock only" with each class in
-- its colour, "Dwarf and Gnome only"; nil when anyone of its side may take it.
local function whoText(q)
	local who = D().QuestFor(q)
	if not who then return nil end
	local function names(lst, name, colour)
		if not lst then return nil end
		local out = {}
		for i, f in ipairs(lst) do
			local text = name(f)
			local r, g, b
			if colour then r, g, b = Theme.ClassColor(f) end
			out[i] = r and format("|cff%02x%02x%02x%s|r", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5), text) or text
		end
		if #out == 2 then return format(L["%s and %s"], out[1], out[2]) end
		return concat(out, ", ")
	end
	local r, c = names(who.races, UI.RaceName), names(who.classes, UI.ClassName, true)
	return format(L["%s only"], (r and c) and (r .. " " .. c) or r or c)
end

local POINT_COLOR = { npc = "npc", object = "object", item = "item" }

-- "Nalpak  ·  The Barrens", coloured; "inside the dungeon" when it is.
local function pointText(p)
	if type(p) ~= "table" then return "|c" .. Theme.Hex("textMuted") .. L["Not known"] .. "|r" end
	local N = ns.Names
	local own = type(p.id) == "number" and ((p.kind == "npc" and N.Npc(p.id)) or (p.kind == "object" and N.Object(p.id)) or (p.kind == "item" and N.Item(p.id))) or nil
	local name = own or p.name or L["Not known"]
	local text = "|c" .. Theme.Hex(POINT_COLOR[p.kind] or "npc") .. name .. "|r"
	local place
	if p.inside then
		place = "|c" .. Theme.Hex("dungeon") .. L["inside the dungeon"] .. "|r"
	else
		local z = mapName(p.map)
		if z then place = "|c" .. Theme.Hex("textDim") .. z .. "|r" end
	end
	if place then text = text .. "|c" .. Theme.Hex("textMuted") .. DOT .. "|r" .. place end
	return text
end

local function canGuide(p)
	return type(p) == "table" and p.map and p.x and p.y and ns.Nav and true or false
end

-- Where a page quest starts for this character: its giver of the
-- character's side nearest `from` when several NPCs give it
-- (Dungeons.Giver), else the page's own start.
local function startOf(q, from)
	local s = q.start
	local Dg = D()
	if not s or s.inside or s.kind == "item" or q.startItem or not Dg.Giver then return s end
	return Dg.Giver(q, from) or s
end

-- Where a page quest is turned in for this character: the page's own place,
-- or the Codex ender of the character's side when the page's is the other
-- side's (Dungeons.Ender).
local function endOf(q, from)
	local f = q.finish
	local Dg = D()
	if not f or f.inside or not Dg.Ender then return f end
	return Dg.Ender(q, from) or f
end

local function guideTo(self)
	local p = self.psPoint
	local Dg = D()
	if p and Dg and Dg.GuideToPoint then Dg.GuideToPoint(p, self.psLabel) end
end

-- The Starts line as one link over its pin and text: the arrow to the giver,
-- or to the first prerequisite still to do.
local function linkEnter(self)
	local p = self.psPin
	if p:IsEnabled() then W.Color(p.Icon, "text") end
	W.SimpleTip(self)
end

local function linkLeave(self)
	local p = self.psPin
	W.Color(p.Icon, "textDim", p:IsEnabled() and 1 or 0.35)
	W.HideTip(self)
end

---------------------------------------------------------------------------
-- Pools
---------------------------------------------------------------------------

-- A quest block's own chips, chain rows and tiles, kept on the block.
local function chip(b, i)
	local c = b.Chips[i]
	if not c then
		c = W.Chip(b)
		b.Chips[i] = c
	end
	return c
end

local function pin(parent, tip)
	local b = W.IconButton(parent, "icon-goto", 22, tip or L["Set the arrow here"], guideTo, 12)
	return b
end

local function card(i)
	local c = cards[i]
	if c then return c end
	c = Kit.Card(home.Body)
	c:SetHeight(CARD_H)
	-- The zone's painting at its left, its corners cut like the card's.
	c.Art = ZoneArt.Create(c, THUMB_W, THUMB_H, "panel")
	c.Art:SetPoint("TOPLEFT", c, "TOPLEFT", 8, -8)
	c.Art.psZoom = 1.6
	Kit.CutPicture(c.Art, "panel", Theme.CUT.control)
	c.psPicture = c.Art
	local tx = 8 + THUMB_W + 14
	c.Name = W.Text(c, "title", "text")
	c.Name:SetPoint("TOPLEFT", c, "TOPLEFT", tx, -12)
	c.Range = W.Text(c, "label", "accent")
	c.Range:SetPoint("TOPLEFT", c, "TOPLEFT", tx, -35)
	c.Stats = W.Text(c, "small", "textDim")
	c.Stats:SetSpacing(2) -- factLines may break it onto a second line
	c.Stats:SetWordWrap(true)
	c.Stats:SetJustifyV("TOP")
	c.Stats:SetPoint("TOPLEFT", c, "TOPLEFT", tx, -56)
	c.Forever = W.Chip(c)
	c.Yours = W.Chip(c)
	c:SetScript("OnClick", function(self) DS.Open(self.psKey) end)
	c:SetScript("OnEnter", W.SimpleTip)
	c:SetScript("OnLeave", W.HideTip)
	cards[i] = c
	return c
end

local function head(i)
	local h = heads[i]
	if h then return h end
	h = Kit.Folder(home.Body)
	heads[i] = h
	return h
end

-- A quest's XP, money and reputation rewards, as chip texts.
local function rewardExtras(rw)
	local extras = {}
	if rw.xp and rw.xp > 0 then extras[#extras + 1] = format(L["%s XP"], thousands(rw.xp)) end
	local m = rw.money and money(rw.money)
	if m then extras[#extras + 1] = m end
	for _, r in ipairs(rw.rep or {}) do
		if r.value and r.value ~= 0 then
			extras[#extras + 1] = format(r.value > 0 and "+%d %s" or "%d %s", r.value, factionName(r.faction, r.name) or L["Reputation"])
		end
	end
	return extras
end

-- A chain quest's details on hover: levels, this character's state, the
-- objective, where it starts and ends, its rewards, and its XP at the
-- character's level when the client gives less.
local function chainEnter(self)
	local q = self.psQuest
	if not q then return end
	local lines = {}
	local meta = {}
	if q.level then meta[#meta + 1] = format(L["Level %d"], q.level) end
	if q.minLevel then meta[#meta + 1] = format(L["Requires level %d"], q.minLevel) end
	local who = whoText(q)
	if who then meta[#meta + 1] = who end
	if #meta > 0 then lines[#lines + 1] = concat(meta, DOT) end
	local stateText, kind = stateChip(questState(q, self.psLevel or 1), q)
	if stateText then
		local r, g, b = Theme.Color(kind == "success" and "success" or "textDim")
		lines[#lines + 1] = { stateText, r, g, b }
	end
	local obj = D().ObjectiveText(q)
	if obj then lines[#lines + 1] = obj end
	lines[#lines + 1] = { left = L["Starts"], right = pointText(startOf(q, ns.PlayerPoint())) }
	if q.finish then lines[#lines + 1] = { left = L["Ends"], right = pointText(endOf(q, ns.PlayerPoint())) } end
	local rw = q.rewards or {}
	local extras = rewardExtras(rw)
	if #extras > 0 then lines[#lines + 1] = { left = L["Rewards"], right = concat(extras, DOT) } end
	for _, it in ipairs(rw.items or {}) do
		local name = (type(it.id) == "number" and ns.Names.Item(it.id)) or it.name
		if name then
			lines[#lines + 1] = { left = it.choice and L["Choose one"] or L["You get"], right = "|c" .. Theme.Hex("item") .. name .. "|r" }
		end
	end
	local Lv = ns.Levels
	if Lv and type(rw.xp) == "number" and rw.xp > 0 and q.level then
		local part = Lv.Share(self.psLevel or 1, q.level)
		if part < 1 then
			local r, g, b = Theme.Color("warning")
			lines[#lines + 1] = { format(L["%s XP at your level"], thousands(floor(rw.xp * part + 0.5))), r, g, b }
		end
	end
	W.Tooltip(self, "ANCHOR_TOP", q.title or (L["Quest"] .. " " .. tostring(q.id)), lines)
end

local function chainRow(b, i)
	local r = b.Chains[i]
	if r then return r end
	r = CreateFrame("Frame", nil, b)
	r:SetHeight(CHAIN_H)
	r.Highlight = W.Fill(r, "chipAccent", "BACKGROUND")
	r.Highlight:Hide()
	r:EnableMouse(true)
	r:SetScript("OnEnter", chainEnter)
	r:SetScript("OnLeave", W.HideTip)
	-- Completed steps keep their check; unfinished ones show their chain number.
	r.Glyph = W.Tex(r, "ARTWORK", "circle", "textMuted")
	r.Glyph:SetPoint("CENTER", r, "LEFT", 10, 0)
	r.Number = W.Text(r, "caption", "textMuted")
	r.Number:SetPoint("CENTER", r, "LEFT", 10, 0)
	r.Title = W.Text(r, "label", "text")
	r.Title:SetPoint("LEFT", r, "LEFT", 24, 0)
	r.Sub = W.Text(r, "small", "textMuted")
	r.Sub:SetPoint("LEFT", r.Title, "RIGHT", 10, 0)
	r.Pin = pin(r)
	r.Pin:SetPoint("LEFT", r.Sub, "RIGHT", 2, 0)
	b.Chains[i] = r
	return r
end

local function tileEnter(self)
	W.ItemTip(self, self.psID)
end

local function tileLeave(self)
	W.HideTooltip(self)
end

-- Shift-click links it in chat, Ctrl-click tries it on, Alt-click guides
-- (W.ItemClick: the client's own modified-click handling).
local function tileClick(self)
	W.ItemClick(self.psID)
end

local function tile(b, i)
	local t = b.Tiles[i]
	if t then return t end
	t = CreateFrame("Button", nil, b)
	t:SetSize(TILE_W, TILE_H)
	W.Hover(t)
	t.Well = CreateFrame("Frame", nil, t)
	t.Well:SetSize(TILE_H, TILE_H)
	t.Well:SetPoint("LEFT", t, "LEFT", 0, 0)
	t.Well.Ground = W.Fill(t.Well, "scrim", "BACKGROUND", 0)
	t.Icon = t.Well:CreateTexture(nil, "ARTWORK")
	t.Icon:SetPoint("TOPLEFT", t.Well, "TOPLEFT", 1, -1)
	t.Icon:SetPoint("BOTTOMRIGHT", t.Well, "BOTTOMRIGHT", -1, 1)
	t.Name = W.Text(t, "label", "item")
	t.Name:SetPoint("LEFT", t.Well, "RIGHT", 10, 0)
	t.Name:SetWidth(TILE_W - TILE_H - 14)
	t:SetScript("OnEnter", tileEnter)
	t:SetScript("OnLeave", tileLeave)
	t:SetScript("OnClick", tileClick)
	b.Tiles[i] = t
	return t
end

local function label(parent, text)
	local fs = W.Text(parent, "small", "textDim")
	fs:SetText(text or "")
	fs:SetJustifyH("LEFT")
	return fs
end

local function block(i)
	local b = blocks[i]
	if b then return b end
	b = CreateFrame("Frame", nil, pg.Body)
	Theme.Skin(b, "panel")
	b.Chains, b.Tiles, b.Chips = {}, {}, {}
	-- What the quest and the chain before it are worth (UI/LevelTip.lua).
	b.ChainXP = UI.LevelTip.Chip(b, hub)
	b.Glyph = W.Tex(b, "ARTWORK", "icon-accept", "quest")
	b.Glyph:SetSize(14, 14)
	b.Glyph:SetPoint("CENTER", b, "TOPLEFT", GUT, -28)
	b.Title = W.Text(b, "title", "text")
	b.Title:SetPoint("LEFT", b, "TOPLEFT", PAD, -28)
	b.Faction = W.Chip(b)
	b.State = W.Chip(b)
	b.Meta = W.Text(b, "small", "textMuted")
	b.Meta:SetPoint("TOPLEFT", b, "TOPLEFT", PAD, -44)
	b.HeadRule = W.Divider(b)
	b.HeadRule:SetPoint("TOPLEFT", b, "TOPLEFT", PAD, -62)
	b.HeadRule:SetPoint("TOPRIGHT", b, "TOPRIGHT", -PAD, -62)
	b.ObjLabel = label(b, L["Objective"])
	b.Obj = W.Text(b, "note", "text")
	b.Obj:SetWordWrap(true)
	b.Obj:SetJustifyV("TOP")
	b.StartLabel = label(b, L["Starts"])
	b.StartPin = pin(b)
	b.Start = W.Text(b, "label", "text")
	b.Start:SetWordWrap(true)
	b.Start:SetJustifyV("TOP")
	b.StartLink = CreateFrame("Button", nil, b)
	b.StartLink:SetHeight(22)
	b.StartLink:SetFrameLevel(b.StartPin:GetFrameLevel() + 1)
	W.Hover(b.StartLink)
	b.StartLink.psPin = b.StartPin
	b.StartLink:SetScript("OnClick", guideTo)
	b.StartLink:SetScript("OnEnter", linkEnter)
	b.StartLink:SetScript("OnLeave", linkLeave)
	b.EndLabel = label(b, L["Ends"])
	b.EndPin = pin(b)
	b.End = W.Text(b, "label", "text")
	b.ChainLabel = label(b, L["Chain"])
	b.ChooseLabel = label(b, L["Choose one"])
	b.GetLabel = label(b, L["You get"])
	b.MoreLabel = label(b, L["Rewards"])
	blocks[i] = b
	return b
end

-- A boss: its panel with the kill order in an accent facet, the name, its
-- facts; the quests tied to it are rows over the panel (tie).
local function bossRow(i)
	local r = bossRows[i]
	if r then return r end
	r = CreateFrame("Frame", nil, pg.Body)
	Theme.Skin(r, "panel")
	r.Tag = W.Tag(r, 26, 22, Theme.CUT.small)
	r.Tag:SetPoint("CENTER", r, "TOPLEFT", GUT + 6, -24)
	W.Painter(r.Tag, function(t)
		local ar, ag, ab = Theme.Accent()
		t:SetColor(ar, ag, ab, 0.16)
	end)
	r.Num = W.Text(r.Tag, "number", "accent")
	r.Num:SetJustifyH("CENTER")
	r.Num:SetPoint("CENTER", r.Tag, "CENTER", 0, 0)
	r.Name = W.Text(r, "title", "text")
	r.Name:SetPoint("LEFT", r, "TOPLEFT", PAD + 14, -24)
	r.Level = W.Text(r, "small", "textMuted")
	r.Level:SetPoint("LEFT", r.Name, "RIGHT", 10, 0)
	bossRows[i] = r
	return r
end

local function tie(i)
	local t = ties[i]
	if t then return t end
	t = CreateFrame("Button", nil, pg.Body)
	t:SetHeight(TIE_H)
	W.Hover(t)
	t.Glyph = W.Tex(t, "ARTWORK", "icon-kill", "textDim")
	t.Glyph:SetSize(12, 12)
	t.Glyph:SetPoint("LEFT", t, "LEFT", 4, 0)
	t.Text = W.Text(t, "label", "textDim")
	t.Text:SetPoint("LEFT", t, "LEFT", 24, 0)
	t:SetScript("OnClick", function(self) DS.ShowQuest(self.psQuest) end)
	t:SetScript("OnEnter", W.SimpleTip)
	t:SetScript("OnLeave", W.HideTip)
	t.psTip = L["Show the quest"]
	ties[i] = t
	return t
end

-- An attunement's panel on its tab: state glyph, name, state chip, facts,
-- our note, the item with whether it is owned, and "Guide me through it";
-- its steps are rows over the panel (attStep).
local function attHead(i)
	local h = atts[i]
	if h then return h end
	h = CreateFrame("Frame", nil, pg.Body)
	Theme.Skin(h, "panel")
	h.Tiles = {}
	h.Glyph = W.Tex(h, "ARTWORK", "icon-dungeon", "dungeon")
	h.Glyph:SetSize(14, 14)
	h.Glyph:SetPoint("CENTER", h, "TOPLEFT", GUT, -30)
	h.Title = W.Text(h, "title", "quest")
	h.Title:SetPoint("LEFT", h, "TOPLEFT", PAD, -30)
	h.State = W.Chip(h)
	h.State:SetPoint("LEFT", h.Title, "RIGHT", 10, 0)
	h.Meta = W.Text(h, "small", "textMuted")
	h.Meta:SetPoint("TOPLEFT", h, "TOPLEFT", PAD, -46)
	h.Note = W.Text(h, "note", "textDim")
	h.Note:SetWordWrap(true)
	h.Note:SetJustifyV("TOP")
	h.Note:SetJustifyH("LEFT")
	h.Note:SetPoint("TOPLEFT", h, "TOPLEFT", PAD, -66)
	h.Owned = W.Text(h, "small", "textMuted")
	h.Guide = W.Button(h, L["Guide me through it"], function(self) DS.Attune(self.psAtt) end, { height = 28, icon = "icon-goto" })
	h.Guide:SetPoint("RIGHT", h, "TOPRIGHT", -16, -30)
	atts[i] = h
	return h
end

-- One step of an attunement: its state glyph in the gutter, what to do and
-- where; a click sets the arrow there.
local function attStep(i)
	local r = attSteps[i]
	if r then return r end
	r = CreateFrame("Button", nil, pg.Body)
	r:SetHeight(TIE_H)
	W.Hover(r)
	r.Glyph = W.Tex(r, "ARTWORK", "circle", "textMuted")
	r.Glyph:SetSize(12, 12)
	r.Glyph:SetPoint("CENTER", r, "LEFT", GUT, 0)
	r.Text = W.Text(r, "label", "text")
	r.Text:SetPoint("LEFT", r, "LEFT", PAD, 0)
	r.Sub = W.Text(r, "small", "textMuted")
	r.Sub:SetPoint("LEFT", r.Text, "RIGHT", 10, 0)
	r:SetScript("OnClick", guideTo)
	r:SetScript("OnEnter", W.SimpleTip)
	r:SetScript("OnLeave", W.HideTip)
	attSteps[i] = r
	return r
end

-- A place marker on a painting: a dark well under a ring and dot.
local function marker(parent, glyph, color, size)
	local m = CreateFrame("Frame", nil, parent)
	m:SetSize(size, size)
	m.Well = m:CreateTexture(nil, "ARTWORK")
	m.Well:SetTexture(Theme.Media("circle"))
	m.Well:SetAllPoints(m)
	W.Painter(m.Well, function(t)
		local r, g, b = Theme.Color("scrim")
		t:SetVertexColor(r, g, b, 0.78)
	end)
	m.Glyph = W.Tex(m, "OVERLAY", glyph, color)
	m.Glyph:SetSize(size - 6, size - 6)
	m.Glyph:SetPoint("CENTER", m, "CENTER", 0, 0)
	return m
end

local function entranceMarker(parent)
	local m = marker(parent, "qol-ring", "dungeon", 24)
	m.Dot = W.Tex(m, "OVERLAY", "circle", "dungeon")
	m.Dot:SetSize(7, 7)
	m.Dot:SetPoint("CENTER", m, "CENTER", 0, 0)
	return m
end

local function placeOn(m, art, x, y)
	local cw, ch = art.Canvas:GetWidth(), art.Canvas:GetHeight()
	m:ClearAllPoints()
	m:SetPoint("CENTER", art.Canvas, "TOPLEFT", (x or 50) / 100 * cw, -(y or 50) / 100 * ch)
end

local function giverEnter(self)
	W.Tooltip(self, "ANCHOR_TOP", self.psName, self.psLines)
end

local function giver(i)
	local g = givers[i]
	if g then return g end
	g = marker(pg.MapArt, "icon-accept", "quest", 20)
	g:SetFrameLevel(pg.MapArt.Over:GetFrameLevel() + 2)
	g:EnableMouse(true)
	g:SetScript("OnEnter", giverEnter)
	g:SetScript("OnLeave", W.HideTip)
	givers[i] = g
	return g
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------

local function factionMenu(anchor)
	local cur = uiState().dungeonsFaction
	if cur ~= "Alliance" and cur ~= "Horde" and cur ~= "All" then cur = nil end
	local mine = UI.PlayerFaction()
	local order = { "Alliance", "Horde", "All" }
	if mine == "Horde" then order = { "Horde", "Alliance", "All" } end
	local items = {}
	for _, f in ipairs(order) do
		local key = f
		items[#items + 1] = { text = f == "All" and L["All factions"] or ns.FactionName(f), checked = (cur or mine or "All") == f,
			onClick = function() DS.SetFaction(key) end }
	end
	W.ShowMenu(anchor, items, { point = anchor.psMenuPoint or "TOPLEFT", relPoint = anchor.psMenuRel or "BOTTOMLEFT", x = 0, y = -4 })
end

-- The faction pills (the home's filter bar, the page's ficha) say the filter.
local function paintFaction(b)
	local f = factionKey()
	return Kit.SetFilterPill(b, f == "All" and L["All factions"] or ns.FactionName(f), { menu = true, active = f ~= UI.PlayerFaction() })
end

local function segPaint()
	for _, b in ipairs(segs) do paintFaction(b) end
end

function DS.Build(parent, shell)
	if root then return root end
	hub = shell
	root = CreateFrame("Frame", nil, parent)
	root:SetAllPoints(parent)
	local MW = mainWidth()

	-- Home: the filter bar, then the cards.
	home = CreateFrame("Frame", nil, root)
	home:SetAllPoints(root)
	home.Tool = CreateFrame("Frame", nil, home)
	home.Tool:SetPoint("TOPLEFT", home, "TOPLEFT", 0, 0)
	home.Tool:SetPoint("TOPRIGHT", home, "TOPRIGHT", 0, 0)
	home.Tool:SetHeight(Kit.TOOL_H)
	home.Faction = Kit.FilterPill(home.Tool, function(b) factionMenu(b) end)
	home.Faction.psTip = L["Faction filter"]
	home.Faction:SetPoint("LEFT", home.Tool, "LEFT", EDGE, 0)
	home.Hint = W.Text(home.Tool, "small", "textMuted")
	home.Hint:SetPoint("LEFT", home.Faction, "RIGHT", 14, 0)
	home.Hint:SetText(T("Escribe arriba el nombre de una mazmorra para buscarla."))
	-- The wolf's engraving, behind an empty state only.
	home.Watermark = home:CreateTexture(nil, "BACKGROUND", nil, -4)
	home.Watermark:SetTexture(Theme.Media("watermark"))
	home.Watermark:SetSize(300, 300)
	home.Watermark:SetPoint("CENTER", home, "CENTER", 0, 0)
	W.Painter(home.Watermark, function(t) t:SetVertexColor(Theme.Wash("watermark")) end)
	home.Watermark:Hide()
	home.Scroll = W.Scroll(home)
	home.Scroll:SetPoint("TOPLEFT", home, "TOPLEFT", 0, -Kit.TOOL_H)
	home.Scroll:SetPoint("BOTTOMRIGHT", home, "BOTTOMRIGHT", -4, 4)
	home.Body = home.Scroll.Child
	home.Body:SetWidth(MW)
	home.Scroll:HookScript("OnVerticalScroll", function() DS.PaintVisible() end)
	home.Scroll:HookScript("OnMouseWheel", function() DS.PaintVisible() end)
	home.EmptyTitle = W.Text(home.Body, "display", "text")
	home.EmptyTitle:SetPoint("TOPLEFT", home.Body, "TOPLEFT", EDGE, -28)
	home.EmptyNote = W.Text(home.Body, "note", "textDim")
	home.EmptyNote:SetWordWrap(true)
	home.EmptyNote:SetJustifyV("TOP")
	home.EmptyNote:SetWidth(min(560, MW - EDGE * 2))
	home.EmptyNote:SetPoint("TOPLEFT", home.EmptyTitle, "BOTTOMLEFT", 0, -10)

	-- A dungeon: its ficha on top, the tab's content under it.
	pg = CreateFrame("Frame", nil, root)
	pg:SetAllPoints(root)
	local hero = Kit.Card(pg, "Frame")
	hero:SetPoint("TOPLEFT", pg, "TOPLEFT", EDGE, -12)
	hero:SetPoint("TOPRIGHT", pg, "TOPRIGHT", -EDGE, -12)
	hero:SetHeight(HERO_H)
	pg.Hero = hero
	local art = ZoneArt.Create(hero, HERO_ART_W, HERO_H - 16, "panel")
	art.psZoom = 1.5
	art:SetPoint("TOPLEFT", hero, "TOPLEFT", 8, -8)
	Kit.CutPicture(art, "panel", Theme.CUT.control)
	hero.psPicture = art
	pg.Art = art
	art.Entrance = entranceMarker(art)
	art.Entrance:SetFrameLevel(art.Over:GetFrameLevel() + 1)
	local tx = 8 + HERO_ART_W + 18
	pg.Title = W.Text(hero, "display", "text")
	pg.Title:SetPoint("TOPLEFT", hero, "TOPLEFT", tx, -16)
	pg.Forever = W.Chip(hero)
	pg.Forever:SetPoint("LEFT", pg.Title, "RIGHT", 12, 0)
	-- The levels the quests here are worth (pageHeader places it after the
	-- Forever chip); hovering opens its panel on the hub (UI/LevelTip.lua).
	pg.XP = UI.LevelTip.Chip(hero, hub)
	pg.Range = W.Text(hero, "label", "accent")
	pg.Range:SetPoint("TOPLEFT", hero, "TOPLEFT", tx, -44)
	pg.Sub = W.Text(hero, "note", "textDim")
	pg.Sub:SetSpacing(2)
	pg.Sub:SetWordWrap(true)
	pg.Sub:SetJustifyV("TOP")
	pg.Sub:SetPoint("TOPLEFT", hero, "TOPLEFT", tx, -64)
	pg.Faction = Kit.FilterPill(hero, function(b) factionMenu(b) end)
	pg.Faction.psTip = L["Faction filter"]
	pg.Faction.psMenuPoint, pg.Faction.psMenuRel = "TOPRIGHT", "BOTTOMRIGHT"
	pg.Faction:SetPoint("TOPRIGHT", hero, "TOPRIGHT", -12, -12)
	-- The actions, right to left from the ficha's corner (pageHeader places
	-- them): the primary one is "Hand in the quests" while quests here are
	-- finished, else "Pick up the quests" while there are quests to pick up,
	-- else "Guide me to the entrance".
	pg.HandIn = W.Button(hero, L["Hand in the quests"], function() DS.HandIn() end, { primary = true, height = 28, icon = "icon-turnin" })
	pg.HandInQuiet = W.Button(hero, L["Hand in the quests"], function() DS.HandIn() end, { height = 28, icon = "icon-turnin" })
	pg.Pickup = W.Button(hero, L["Pick up the quests"], function() DS.PickUp() end, { primary = true, height = 28, icon = "icon-accept" })
	pg.PickupQuiet = W.Button(hero, L["Pick up the quests"], function() DS.PickUp() end, { height = 28, icon = "icon-accept" })
	pg.PickupNone = W.Button(hero, L["Nothing to pick up"], function() DS.PickUp() end, { height = 28 })
	pg.Go = W.Button(hero, L["Guide me to the entrance"], function() DS.GuideThere() end, { primary = true, height = 28, icon = "icon-goto" })
	pg.Go.psTip = L["Set the arrow to the entrance."]
	pg.GoQuiet = W.Button(hero, L["Guide me to the entrance"], function() DS.GuideThere() end, { height = 28, icon = "icon-goto" })
	pg.GoQuiet.psTip = pg.Go.psTip
	pg.MapBtn = W.Button(hero, L["Show on map"], function() DS.ShowOnMap() end, { height = 28 })

	pg.Scroll = W.Scroll(pg)
	pg.Scroll:SetPoint("TOPLEFT", pg, "TOPLEFT", 0, -(12 + HERO_H + 8))
	pg.Scroll:SetPoint("BOTTOMRIGHT", pg, "BOTTOMRIGHT", -4, 4)
	pg.Body = pg.Scroll.Child
	pg.Body:SetWidth(MW)
	pg.Scroll:HookScript("OnVerticalScroll", function() DS.PaintQuests() end)
	pg.Scroll:HookScript("OnMouseWheel", function() DS.PaintQuests() end)
	-- Measures objectives before any block is drawn.
	pg.Measure = W.Text(pg, "note", "text")
	pg.Measure:SetWordWrap(true)
	pg.Measure:Hide()
	pg.MeasureStart = W.Text(pg, "label", "text") -- a quest's start line
	pg.MeasureStart:SetWordWrap(true)
	pg.MeasureStart:Hide()

	-- The Entrance tab: the zone's painting in a panel, the note under it.
	pg.MapPanel = Kit.Card(pg.Body, "Frame")
	pg.MapPanel:SetPoint("TOPLEFT", pg.Body, "TOPLEFT", EDGE, -8)
	pg.MapPanel:SetSize(MW - EDGE * 2, MAP_H + 16)
	pg.MapArt = ZoneArt.Create(pg.MapPanel, MW - EDGE * 2 - 16, MAP_H, "panel")
	pg.MapArt.psZoom = 1
	pg.MapArt:SetPoint("TOPLEFT", pg.MapPanel, "TOPLEFT", 8, -8)
	Kit.CutPicture(pg.MapArt, "panel", Theme.CUT.control)
	pg.MapPanel.psPicture = pg.MapArt
	pg.MapArt.Entrance = entranceMarker(pg.MapArt)
	pg.MapArt.Entrance:SetFrameLevel(pg.MapArt.Over:GetFrameLevel() + 3)
	pg.MapNote = W.Text(pg.Body, "note", "textDim")
	pg.MapNote:SetWordWrap(true)
	pg.MapNote:SetJustifyV("TOP")
	pg.MapNote:SetWidth(MW - EDGE * 2 - 16)
	pg.MapNote:SetPoint("TOPLEFT", pg.MapPanel, "BOTTOMLEFT", 8, -14)
	pg.EmptyTitle = W.Text(pg.Body, "display", "text")
	pg.EmptyNote = W.Text(pg.Body, "note", "textDim")
	pg.EmptyNote:SetWordWrap(true)
	pg.EmptyNote:SetJustifyV("TOP")
	pg.EmptyNote:SetWidth(min(560, MW - EDGE * 2))
	pg.EmptyNote:SetPoint("TOPLEFT", pg.EmptyTitle, "BOTTOMLEFT", 0, -10)

	-- The faction filter: on the home's bar and in the page's ficha.
	segs = { home.Faction, pg.Faction }

	-- The hub hides the section's parent when leaving Dungeons. Hiding the
	-- whole hub leaves that parent's shown state intact, so its page can resume.
	root:SetScript("OnHide", function(self)
		if self:IsShown() and parent:IsShown() then return end
		UI.LevelTip.Hide()
	end)
	return root
end

---------------------------------------------------------------------------
-- Home
---------------------------------------------------------------------------

local function hidePool(pool, from)
	for i = from or 1, #pool do pool[i]:Hide() end
end

-- Paint the cards' art in view (and one line past it); the rest wait.
function DS.PaintVisible()
	if not (home and home:IsShown()) then return end
	local top = home.Scroll:GetVerticalScroll() or 0
	local view = viewHeight(home.Scroll)
	for i = 1, (home.psCount or 0) do
		local c = cards[i]
		local key = c.psKey
		if c.psPainted ~= key and c.psY < top + view + CARD_H and c.psY + CARD_H > top - CARD_H then
			local d = c.psEntry
			local e = d.entrance
			c.psArt = ZoneArt.Paint(c.Art, e and e.map or d.zone, e and e.x, e and e.y, i)
			c.psPainted = key
			shown.painted = (shown.painted or 0) + 1
		end
	end
end

local function navItems(plevel, f)
	local items = {}
	local counts, level, all, raids = {}, 0, 0, 0
	for _, d in ipairs(list()) do
		if d.kind == "raid" then
			raids = raids + 1
		else
			all = all + 1
			local k = bandOf(d.minLevel)
			if k then counts[k] = (counts[k] or 0) + 1 end
			if forYouAs(d, plevel, f) then level = level + 1 end
		end
	end
	items[1] = { key = "level", label = L["For your level"], count = level }
	items[2] = { key = "all", label = T("Todas"), count = all }
	for _, b in ipairs(BANDS) do
		items[#items + 1] = { key = b.key, label = bandLabel(b.key), count = counts[b.key] or 0 }
	end
	if raids > 0 then items[#items + 1] = { key = "raid", label = L["Raids"], count = raids } end
	return items, level
end

local function defaultBand(plevel)
	if band then return band end
	local _, level = navItems(plevel, factionKey())
	return level > 0 and "level" or "all"
end

-- A dungeon's facts ("The Barrens · 4 quests", on its card and in its ficha),
-- broken onto more lines between two facts where one line is too narrow.
local function factLines(fs, facts, width)
	local lines, line = {}, nil
	for _, fact in ipairs(facts) do
		local candidate = line and (line .. DOT .. fact) or fact
		if line and W.TextWidth(fs, candidate) > width then
			lines[#lines + 1] = line
			line = fact
		else
			line = candidate
		end
	end
	lines[#lines + 1] = line or ""
	return concat(lines, "\n")
end

-- The enemy-territory warning (Dungeons.EnemyEntrance) for the filter's side,
-- this character's under All, in the warning colour; nil when it needs none.
local function enemyWarning(d, f)
	local side = SIDE[f] or SIDE[UI.PlayerFaction() or ""]
	local text = D().EnemyEntrance and D().EnemyEntrance(d.key, side)
	return text and ("|c" .. Theme.Hex("warning") .. text .. "|r") or nil
end

local function paintCard(c, d, f, plevel, key, cw)
	c.psKey, c.psEntry = d.key, d
	c:SetWidth(cw)
	c.psTip = d.name
	c.psTipLines = { T("Clic: abre su página con sus misiones, jefes y entrada.") }
	local tx = 8 + THUMB_W + 14
	-- The chips at the right of the range line: Your level (or Tough at
	-- your level, calmly, everywhere), Forever.
	local right = 12
	local isTough = forYou(d, plevel) and tough(d, plevel)
	if isTough or (key ~= "level" and forYou(d, plevel)) then
		local w = W.SetChip(c.Yours, isTough and L["Tough at your level"] or L["Your level"], not isTough and "accent" or "warning")
		c.Yours:ClearAllPoints()
		c.Yours:SetPoint("TOPRIGHT", c, "TOPRIGHT", -right, -32)
		right = right + w + 6
	else
		c.Yours:Hide()
	end
	if d.forever then
		local w = W.SetChip(c.Forever, L["Forever"])
		c.Forever:ClearAllPoints()
		c.Forever:SetPoint("TOPRIGHT", c, "TOPRIGHT", -right, -32)
		right = right + w + 6
	else
		c.Forever:Hide()
	end
	c.Name:SetWidth(0)
	c.Name:SetText(d.name)
	c.Name:SetWidth(max(60, min(cw - tx - 12, ceil(c.Name:GetStringWidth()) + 1)))
	c.Range:SetText(rangeText(d) or "")
	c.Range:SetWidth(max(40, cw - tx - right - 6))
	local facts = {}
	if d.zoneName then facts[#facts + 1] = d.zoneName end
	local n, a, h = questCount(d, f)
	if f == "All" and a ~= h and a > 0 and h > 0 then
		facts[#facts + 1] = format(L["%d Alliance, %d Horde quests"], a, h)
	elseif f == "All" and a ~= h then
		local k = max(a, h)
		if k == 1 then
			facts[#facts + 1] = a > 0 and L["1 Alliance quest"] or L["1 Horde quest"]
		else
			facts[#facts + 1] = format(a > 0 and L["%d Alliance quests"] or L["%d Horde quests"], k)
		end
	elseif n == 0 then
		facts[#facts + 1] = f == "All" and L["No quests known"] or format(L["No %s quests"], ns.FactionName(f))
	else
		facts[#facts + 1] = n == 1 and L["1 quest"] or format(L["%d quests"], n)
	end
	if (d.bosses or 0) > 0 then facts[#facts + 1] = d.bosses == 1 and L["1 boss"] or format(L["%d bosses"], d.bosses) end
	local statsW = max(60, cw - tx - 12)
	c.Stats:SetWidth(statsW)
	local text = factLines(c.Stats, facts, statsW)
	local warn = enemyWarning(d, f)
	if warn then text = text .. "\n" .. warn end
	c.Stats:SetText(text)
	W.Color(c.Stats, n > 0 and "textDim" or "textMuted")
end

local function renderHome(plevel)
	home:Show()
	pg:Hide()
	local f = factionKey()
	local key = defaultBand(plevel)
	local rows = entries(key, plevel, f)
	-- What the grid holds, right of the pills.
	local title, sub
	if filter ~= "" then
		title = L["Search"]
		sub = #rows == 1 and format(L["1 result for \226\128\156%s\226\128\157"], filter) or format(L["%d results for \226\128\156%s\226\128\157"], #rows, filter)
	elseif key == "level" then
		title = L["For your level"]
		sub = format(#rows == 1 and L["Level %d  \194\183  1 dungeon to run now"] or L["Level %d  \194\183  %d dungeons to run now"], plevel, #rows)
	elseif key == "raid" then
		title = L["Raids"]
		sub = #rows == 1 and L["1 raid"] or format(L["%d raids"], #rows)
	elseif key == "all" then
		title = T("Mazmorras")
		sub = format(L["%d dungeons  \194\183  every quest, where it starts and what it gives"], #rows)
	else
		title = format(L["Levels %s"], bandLabel(key))
		sub = #rows == 1 and L["1 dungeon"] or format(L["%d dungeons"], #rows)
	end
	W.ShellTitle(hub, title, sub)
	home.Watermark:SetShown(#rows == 0)

	local MW = mainWidth()
	local cw = floor((MW - EDGE * 2 - CARD_GAP) / 2)
	local y = 6
	local nh, col, lastBand = 0, 0, nil
	for i, d in ipairs(rows) do
		-- Under All, the level bands head their cards.
		if key == "all" and filter == "" then
			local b = bandOf(d.minLevel) or "other"
			if b ~= lastBand then
				if col == 1 then y = y + CARD_H + CARD_GAP end
				col = 0
				nh = nh + 1
				local h = head(nh)
				h:ClearAllPoints()
				h:SetPoint("TOPLEFT", home.Body, "TOPLEFT", EDGE, -y)
				h:SetWidth(MW - EDGE * 2)
				Kit.SetFolder(h, b == "other" and L["Level not known"] or format(L["Levels %s"], bandLabel(b)), nil, false)
				h:Show()
				y = y + Kit.FOLDER_H + 8
				lastBand = b
			end
		end
		local c = card(i)
		paintCard(c, d, f, plevel, filter ~= "" and "search" or key, cw)
		c.psY = y
		c:ClearAllPoints()
		c:SetPoint("TOPLEFT", home.Body, "TOPLEFT", EDGE + col * (cw + CARD_GAP), -y)
		c:Show()
		if col == 1 then
			y = y + CARD_H + CARD_GAP
			col = 0
		else
			col = 1
		end
	end
	if col == 1 then y = y + CARD_H + CARD_GAP end
	home.psCount = #rows
	hidePool(cards, #rows + 1)
	hidePool(heads, nh + 1)
	local empty = #rows == 0
	home.EmptyTitle:SetShown(empty)
	home.EmptyNote:SetShown(empty)
	if empty then
		home.EmptyTitle:SetText(filter ~= "" and L["No dungeon by that name"] or L["Nothing here yet"])
		home.EmptyNote:SetText(filter ~= "" and L["Try part of the name, such as \226\128\156caverns\226\128\157."] or L["No dungeon in this band is known yet."])
		y = 120
	end
	home.Body:SetWidth(MW)
	W.SetScrollContent(home.Scroll, y + 8)
	shown.view, shown.band, shown.cards, shown.heads, shown.painted = "home", key, #rows, nh, 0
	DS.PaintVisible()
end

---------------------------------------------------------------------------
-- A dungeon page
---------------------------------------------------------------------------

local function pageHeader(d)
	local art = pg.Art
	local e = d.entrance
	local painted = ZoneArt.Paint(art, e and e.map or d.zone, e and e.x, e and e.y, 1)
	if painted and e and e.map then
		placeOn(art.Entrance, art, e.x, e.y)
		art.Entrance:Show()
	else
		art.Entrance:Hide()
	end
	local facts = {}
	local z = d.zoneName or (e and mapName(e.map))
	if z then facts[#facts + 1] = z end
	if d.players then facts[#facts + 1] = format(L["%d players"], d.players) end
	if (d.bosses or 0) > 0 then facts[#facts + 1] = d.bosses == 1 and L["1 boss"] or format(L["%d bosses"], d.bosses) end
	local warn = enemyWarning(d, factionKey())
	pg.Title:SetWidth(0)
	pg.Title:SetText(d.name)
	pg.Range:SetText(rangeText(d) and (L["Levels"] .. " " .. rangeText(d)) or "")
	local MW = mainWidth()
	local heroW = MW - EDGE * 2
	local tx = 8 + HERO_ART_W + 18
	local fw = paintFaction(pg.Faction)
	if d.forever then
		W.SetChip(pg.Forever, L["Forever"])
	else
		pg.Forever:Hide()
	end
	-- The levels chip: what the quests still to do are worth, after the
	-- Forever chip; none at 60 or with no XP to count.
	local xs = D().QuestXP and D().QuestXP(d.key)
	local xw = UI.LevelTip.Set(pg.XP, xs, { head = L["If you finish the quests here"], need = L["You are level %d. Level %d is recommended for the quests here; from there:"] })
	if xw then
		pg.XP:ClearAllPoints()
		if d.forever then
			pg.XP:SetPoint("LEFT", pg.Forever, "RIGHT", 6, 0)
		else
			pg.XP:SetPoint("LEFT", pg.Title, "RIGHT", 12, 0)
		end
	end
	local chipsW = (d.forever and (pg.Forever:GetWidth() + 12) or 0) + (xw and (xw + (d.forever and 6 or 12)) or 0)
	pg.Title:SetWidth(max(80, min(ceil(pg.Title:GetStringWidth()) + 1, heroW - tx - fw - 24 - chipsW)))
	-- The actions, right to left: the primary first.
	local go = e ~= nil and ns.Nav ~= nil
	local Dg, LKm = D(), ns.Lookup
	local plan = LKm and LKm.Guide and Dg.PickupPlan and Dg.PickupPlan(d.key) or nil
	local hplan = LKm and LKm.Guide and Dg.HandinPlan and Dg.HandinPlan(d.key) or nil
	local take = plan and #plan.take or 0
	local hand = hplan and #hplan.hand or 0
	local logged = hplan and hand + #hplan.unfinished + #hplan.inside + #hplan.unplaced or 0
	local lead = hand > 0 and "handin" or take > 0 and "pickup" or "go"
	local side = SIDE[UI.PlayerFaction() or ""]
	local none = plan ~= nil and take == 0 and #Dg.Quests(d.key, side) > 0 and lead == "go"
	-- The quests that wait for a level say so on the button and in its tip
	-- (Dungeons.PickupLabel, WaitingLines: "3 now · 2 at level 16").
	local waiting = plan and Dg.WaitingLines and Dg.WaitingLines(plan) or {}
	local pickLabel = plan and Dg.PickupLabel and Dg.PickupLabel(plan) or L["Pick up the quests"]
	local function withWaiting(lines)
		if #waiting > 0 then
			lines[#lines + 1] = L["Waiting:"]
			for _, w in ipairs(waiting) do lines[#lines + 1] = w end
		end
		return lines
	end
	if take > 0 then
		local lines = { format(take == 1 and L["A guide to the 1 quest here you can take, with what comes before it, ending at the entrance."]
			or L["A guide to the %d quests here you can take, with what comes before them, ending at the entrance."], take) }
		local carried = #plan.carried
		if carried > 0 then lines[#lines + 1] = carried == 1 and L["1 more is in your log already."] or format(L["%d more are in your log already."], carried) end
		withWaiting(lines)
		lines[#lines + 1] = L["It opens in a new tab."]
		for _, b in ipairs({ pg.Pickup, pg.PickupQuiet }) do
			W.SetButtonText(b, pickLabel)
			b.psTip, b.psTipLines = pickLabel, lines
		end
	elseif none then
		local text = #waiting > 0 and pickLabel or L["Nothing to pick up"]
		W.SetButtonText(pg.PickupNone, text)
		pg.PickupNone.psTip, pg.PickupNone.psTipLines = text, withWaiting({ DS.NothingText(plan) })
	end
	if logged > 0 then
		local lines
		if hand > 0 then
			lines = { format(hand == 1 and L["A guide to where the 1 finished quest here is turned in, and the follow-ups it opens there."]
				or L["A guide to where the %d finished quests here are turned in, and the follow-ups they open there."], hand) }
			if logged > hand then lines[#lines + 1] = Dg.HandinText(hplan) end
			lines[#lines + 1] = L["It opens in a new tab."]
		else
			lines = { Dg.HandinText(hplan) }
		end
		for _, b in ipairs({ pg.HandIn, pg.HandInQuiet }) do b.psTip, b.psTipLines = L["Hand in the quests"], lines end
	end
	pg.HandIn:SetShown(lead == "handin")
	pg.HandInQuiet:SetShown(lead ~= "handin" and logged > 0)
	pg.Pickup:SetShown(lead == "pickup")
	pg.PickupQuiet:SetShown(lead == "handin" and take > 0)
	pg.PickupNone:SetShown(none)
	pg.Go:SetShown(go and lead == "go")
	pg.GoQuiet:SetShown(go and lead ~= "go")
	pg.MapBtn:SetShown(e ~= nil and ns.Compat.CanOpenWorldMap())
	-- In priority order; three at most, so the facts keep their room (the
	-- Entrance tab shows the entrance too).
	local order = lead == "handin" and { pg.HandIn, pg.PickupQuiet, pg.GoQuiet, pg.MapBtn }
		or lead == "pickup" and { pg.Pickup, pg.HandInQuiet, pg.GoQuiet, pg.MapBtn }
		or { pg.Go, pg.HandInQuiet, pg.PickupNone, pg.MapBtn }
	local prev, used, n = nil, 0, 0
	for _, b in ipairs(order) do
		if b:IsShown() and n == 3 then b:Hide() end
		if b:IsShown() then
			n = n + 1
			b:ClearAllPoints()
			if prev then
				b:SetPoint("RIGHT", prev, "LEFT", -8, 0)
				used = used + 8
			else
				b:SetPoint("BOTTOMRIGHT", pg.Hero, "BOTTOMRIGHT", -12, 12)
			end
			used = used + b:GetWidth()
			prev = b
		end
	end
	-- The facts, on as many lines as they need, left of the actions' column
	-- when it comes up beside them.
	local subW = heroW - tx - 16
	if used > 0 and used > heroW - tx - 300 then subW = heroW - tx - used - 28 end
	pg.Sub:SetWidth(max(120, subW))
	local text = factLines(pg.Sub, facts, max(120, subW))
	if warn then text = text .. "\n" .. warn end
	pg.Sub:SetText(text)
	return facts
end

-- Why a page has nothing to pick up, in one sentence.
function DS.NothingText(plan)
	local text = L["Nothing to pick up before the run: the quests here for you are done, already in your log, or start inside the dungeon or later in their chain."]
	local later = plan and plan.later or 0
	if later > 0 then
		text = text .. " " .. (later == 1 and L["1 more opens at a later level."] or format(L["%d more open at a later level."], later))
	end
	return text
end

local function emptyPage(title, text, y)
	pg.EmptyTitle:ClearAllPoints()
	pg.EmptyTitle:SetPoint("TOPLEFT", pg.Body, "TOPLEFT", EDGE + 8, -y)
	pg.EmptyTitle:SetText(title)
	pg.EmptyTitle:Show()
	pg.EmptyNote:SetText(text)
	pg.EmptyNote:Show()
	return y + 24 + 10 + pg.EmptyNote:GetStringHeight() + 24
end

-- Where each part of a quest block goes, from the data alone (the objective
-- measured on one shared string), so every block is placed before any is
-- drawn and only the ones in view are.
local function tilesPer()
	return max(1, floor((questWidth() - VALUE_X - PAD + TILE_GAP) / (TILE_W + TILE_GAP)))
end

local function tilesHeight(n)
	if n == 0 then return 0 end
	local per = tilesPer()
	return floor((n + per - 1) / per) * (TILE_H + 6) - 6
end

-- What drops the item that starts page quest q (Dungeons.StartDrops), inside
-- the dungeon or outside it (the Damp Note's Blackfathom Tide Priestesses,
-- in the tunnels before the portal, #1380), the likeliest first.
-- -> list | nil, insideOnly (every one of them inside)
local function dropsOf(q, key)
	local Dg = D()
	if not (key and Dg.StartDrops and (q.startItem or (q.start and q.start.kind == "item"))) then return nil, false end
	local d = Dg.StartDrops(key, q)
	if not d or #d.inside + #d.outside == 0 then return nil, false end
	local lst = {}
	for _, s in ipairs(d.inside) do lst[#lst + 1] = s end
	for _, s in ipairs(d.outside) do lst[#lst + 1] = s end
	table.sort(lst, function(a, b) return (a.chance or 0) > (b.chance or 0) end)
	return lst, #d.outside == 0
end

-- Where a quest starts, and the line that says so: the giver or object, or
-- the item that starts it with what drops it: the boss, else the two
-- likeliest mobs or objects (dropsOf). -> point, text
local function startLine(q, key)
	local s = startOf(q, ns.PlayerPoint())
	if q.startItem and not (s and s.kind == "item") then s = { kind = "item", id = q.startItem.id, name = q.startItem.name, map = s and s.map, x = s and s.x, y = s and s.y, f = s and s.f, inside = s and s.inside } end
	local text = pointText(s)
	if s and s.kind == "item" and key then
		local from
		for _, boss in ipairs(D().Bosses(key)) do
			for _, t in ipairs(boss.quests or {}) do
				if t.id == q.id and t.how == "starts" then from = boss.name end
			end
		end
		if not from then
			local lst = dropsOf(q, key)
			local a, b = lst and lst[1] and lst[1].name, lst and lst[2] and lst[2].name
			from = a and b and format(L["%s, %s"], a, b) or a
		end
		if from then
			text = "|c" .. Theme.Hex("item") .. ((type(s.id) == "number" and ns.Names.Item(s.id)) or s.name or "") .. "|r|c" .. Theme.Hex("textMuted") .. DOT .. "|r|c" .. Theme.Hex("textDim") .. format(L["drops from %s"], from) .. "|r"
		end
	end
	return s, text
end

local function plan(q, key)
	local VW = questWidth() - VALUE_X - PAD
	local p = {}
	local y = 74
	p.objective = D().ObjectiveText(q)
	if p.objective then
		p.objective = "\226\128\162  " .. p.objective:gsub("\n", "\n\226\128\162  ")
		p.obj = y
		local m = pg.Measure
		m:SetWidth(min(VW, 620))
		m:SetText(p.objective)
		y = y + max(16, m:GetStringHeight()) + 12
	end
	p.starts = y
	-- The start line wraps where it is too long for its half (paintQuest).
	local m = pg.MeasureStart
	m:SetWidth(floor((VW - 16) / 2) - 24)
	local _, startText = startLine(q, key)
	m:SetText(startText)
	y = y + max(22, 5 + m:GetStringHeight() + 5) + 12
	local nChain = #(q.chain or {})
	if nChain > 0 then
		p.chain = y
		y = y + nChain * CHAIN_H + 10
	end
	local rw = q.rewards or {}
	local nChoice, nGet = 0, 0
	for _, it in ipairs(rw.items or {}) do if it.choice then nChoice = nChoice + 1 else nGet = nGet + 1 end end
	if nChoice > 0 then
		p.choose = y
		y = y + tilesHeight(nChoice) + 10
	end
	if nGet > 0 then
		p.get = y
		y = y + tilesHeight(nGet) + 10
	end
	p.extras = rewardExtras(rw)
	-- The chain's worth, while one of its quests is still to do.
	local C, open = ns.Compat, false
	for _, cid in ipairs(q.chain or {}) do
		if not (C and C.IsQuestCompleted and C.IsQuestCompleted(cid)) then open = true end
	end
	local cs = open and D().ChainXP and D().ChainXP(key, q.id) or nil
	p.chainXP = cs and not cs.maxed and cs.xp > 0 and cs or nil
	if #p.extras > 0 or p.chainXP then
		p.more = y
		y = y + W.CHIP_H + 4
	end
	p.h = y + 14
	return p
end

-- Item tiles across the value column at y in the block; -> how many.
local function placeTiles(b, n0, items, choice, y)
	local per = tilesPer()
	local n = 0
	for _, it in ipairs(items) do
		if (it.choice and true or false) == choice then
			local t = tile(b, n0 + n + 1)
			local col, line = n % per, floor(n / per)
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", b, "TOPLEFT", VALUE_X + col * (TILE_W + TILE_GAP), -(y + line * (TILE_H + 6)))
			t.psID = it.id
			local icon = itemIcon(it.id)
			if icon then
				t.Icon:SetTexture(icon)
				t.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
				W.Uncolor(t.Icon)
				t.Icon:SetVertexColor(1, 1, 1, 1)
			else
				t.Icon:SetTexture(Theme.Media("icon-collect"))
				t.Icon:SetTexCoord(0, 1, 0, 1)
				W.Color(t.Icon, "textMuted")
			end
			paintTile(t, it.id, it.quality)
			local name = it.name or (L["Item"] .. " " .. tostring(it.id))
			if (it.count or 1) > 1 then name = format(L["%d x %s"], it.count, name) end
			t.Name:SetText(name)
			t:Show()
			n = n + 1
		end
	end
	return n
end

local function labelAt(fs, y)
	if not y then
		fs:Hide()
		return
	end
	fs:ClearAllPoints()
	fs:SetPoint("TOPLEFT", fs:GetParent(), "TOPLEFT", PAD, -y)
	fs:Show()
end

-- One quest block at top in the body, laid out by its plan p.
local function paintQuest(b, q, p, top, plevel, key)
	local MW = questWidth()
	local VW = MW - VALUE_X - PAD
	b:ClearAllPoints()
	b:SetPoint("TOPLEFT", pg.Body, "TOPLEFT", EDGE, -top)
	b:SetWidth(MW)
	b:SetHeight(p.h)
	b.psQuest = q.id
	local state = questState(q, plevel)
	local g = STATE_GLYPH[state]
	b.Glyph:SetTexture(Theme.Media(g[1]))
	W.Color(b.Glyph, g[2])
	-- A pooled block measures its new title from scratch.
	b.Title:SetWidth(0)
	b.Title:SetText(q.title or (L["Quest"] .. " " .. tostring(q.id)))
	-- Done, or not for this character's class or race: the muted text colour
	-- (held legible), its chip says why; else the quest's difficulty colour,
	-- as on the Attunement tab and in the quest log.
	if state == "done" or state == "class" or state == "race" then W.Color(b.Title, "textMuted") else paintRGB(b.Title, difficulty(q.level, plevel)) end
	-- Right of the title line: the state, then the faction mark.
	local right = PAD
	local text, kind = stateChip(state, q)
	if text then
		local w = W.SetChip(b.State, text, kind)
		b.State:ClearAllPoints()
		b.State:SetPoint("RIGHT", b, "TOPRIGHT", -right, -28)
		right = right + w + 6
	else
		b.State:Hide()
	end
	if q.faction then
		local w = W.SetChip(b.Faction, ns.FactionName(q.faction == "A" and "A" or "H"))
		b.Faction:ClearAllPoints()
		b.Faction:SetPoint("RIGHT", b, "TOPRIGHT", -right, -28)
		right = right + w + 6
	else
		b.Faction:Hide()
	end
	b.Title:SetWidth(max(80, min(floor(b.Title:GetStringWidth() + 1), MW - PAD - right - 12)))
	-- Level, requirement and flags.
	local meta = {}
	if q.level then meta[#meta + 1] = format(L["Level %d"], q.level) end
	if q.minLevel then meta[#meta + 1] = format(L["Requires level %d"], q.minLevel) end
	-- Who it is for: "Warlock only" in the class colour (#1730), races too.
	local who = whoText(q)
	if who then meta[#meta + 1] = who end
	-- An item that starts it: where it drops decides (dropsOf), else the page.
	local drops, insideOnly = dropsOf(q, key)
	if (drops and insideOnly) or (not drops and q.inside) then meta[#meta + 1] = L["Picked up inside the dungeon"] end
	if q.shareable == true then meta[#meta + 1] = L["Shareable"] elseif q.shareable == false then meta[#meta + 1] = L["Not shareable"] end
	b.Meta:SetText(concat(meta, DOT))
	b.Meta:SetWidth(MW - PAD * 2)
	-- Objective.
	labelAt(b.ObjLabel, p.obj and p.obj + 1)
	if p.obj then
		b.Obj:ClearAllPoints()
		b.Obj:SetPoint("TOPLEFT", b, "TOPLEFT", VALUE_X, -p.obj)
		b.Obj:SetWidth(min(VW, 620))
		b.Obj:SetText(p.objective)
		b.Obj:Show()
	else
		b.Obj:Hide()
	end
	-- Starts and ends, side by side.
	local y = p.starts
	local half = floor((VW - 16) / 2)
	local s, startText = startLine(q, key)
	labelAt(b.StartLabel, y + 4)
	b.StartPin:ClearAllPoints()
	b.StartPin:SetPoint("TOPLEFT", b, "TOPLEFT", VALUE_X - 4, -y)
	-- The arrow goes to the first prerequisite still to do, else the giver.
	local Dg = D()
	local target, tlabel, first, turnIn
	if key and Dg.GiverTarget then target, tlabel, first, turnIn = Dg.GiverTarget(key, q.id) end
	-- Its own giver, or where the item that starts it drops outside (#1380).
	if not target then target, tlabel = s, s and s.name end
	local go = canGuide(target)
	b.StartPin.psPoint, b.StartPin.psLabel = target, tlabel
	W.SetIconState(b.StartPin, false, go)
	local link = b.StartLink
	link.psPoint, link.psLabel = target, tlabel
	link:SetEnabled(go)
	if not go then
		link.psTip, link.psTipLines = L["Not known"], { L["Where this quest starts is not known yet."] }
	elseif first then
		link.psTip = format(L["Set the arrow to %s"], tlabel or L["the quest giver"])
		link.psTipLines = { format(turnIn and L["First turn in %s, which comes before this quest."] or L["First pick up %s, which comes before this quest."], ns.Quoted(first)) }
	else
		link.psTip = format(L["Set the arrow to %s"], tlabel or L["the quest giver"])
		link.psTipLines = { L["Where this quest starts."] }
	end
	b.StartPin.psTip, b.StartPin.psTipLines = link.psTip, link.psTipLines
	b.Start:ClearAllPoints()
	-- Its first line level with the pin's middle; a long one ("… drops from
	-- <boss>") wraps under it, and plan made the room.
	b.Start:SetPoint("TOPLEFT", b.StartPin, "TOPRIGHT", 4, -5)
	b.Start:SetWidth(half - 24)
	b.Start:SetText(startText)
	link:ClearAllPoints()
	link:SetPoint("LEFT", b.StartPin, "LEFT", 0, 0)
	link:SetWidth(26 + min(half - 24, floor(b.Start:GetStringWidth() + 1)))
	link:Show()
	local fin = endOf(q, ns.PlayerPoint())
	b.EndLabel:ClearAllPoints()
	b.EndLabel:SetPoint("TOPLEFT", b, "TOPLEFT", VALUE_X + half + 16, -(y + 4))
	b.EndPin:ClearAllPoints()
	b.EndPin:SetPoint("TOPLEFT", b, "TOPLEFT", VALUE_X + half + 16 + 40, -y)
	b.EndPin.psPoint, b.EndPin.psLabel = fin, fin and fin.name
	W.SetIconState(b.EndPin, false, canGuide(fin))
	b.End:ClearAllPoints()
	b.End:SetPoint("LEFT", b.EndPin, "RIGHT", 4, 0)
	b.End:SetWidth(half - 40 - 24)
	b.End:SetText(pointText(fin))
	-- The chain before it, oldest first, each with its own pin.
	local nChain = 0
	local nextStep = false
	labelAt(b.ChainLabel, p.chain and p.chain + 6)
	if p.chain then
		y = p.chain
		for _, id in ipairs(q.chain) do
			local cq = D().Quest(key, id) or { id = id }
			nChain = nChain + 1
			local r = chainRow(b, nChain)
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", b, "TOPLEFT", VALUE_X - 4, -y)
			r:SetWidth(VW + 4)
			local cs = questState(cq, plevel)
			local marked = cs ~= "done" and not nextStep
			if marked then nextStep = true end
			if marked then r.Highlight:Show() else r.Highlight:Hide() end
			if cs == "done" then
				r.Glyph:SetTexture(Theme.Media("check"))
				r.Glyph:SetSize(12, 12)
				W.Color(r.Glyph, "success")
				r.Glyph:Show()
				r.Number:Hide()
			else
				r.Glyph:Hide()
				r.Number:SetText(tostring(nChain))
				r.Number:Show()
			end
			r.Title:SetText(cq.title or (L["Quest"] .. " " .. tostring(id)))
			-- The next step is marked by its ground; titles keep the difficulty colour.
			if cs == "done" then W.Color(r.Title, "textMuted") else paintRGB(r.Title, difficulty(cq.level, plevel)) end
			local sub = {}
			if cq.level then sub[#sub + 1] = format(L["Level %d"], cq.level) end
			local cw = whoText(cq)
			if cw then sub[#sub + 1] = cw end
			local st = startOf(cq, ns.PlayerPoint())
			if st and st.name then
				local z = st.inside and L["inside the dungeon"] or mapName(st.map)
				sub[#sub + 1] = z and format(L["%s, %s"], st.name, z) or st.name
			end
			r.Sub:SetText(concat(sub, DOT))
			local room = VW + 4 - 24 - 30
			local tw = min(floor(r.Title:GetStringWidth() + 1), floor(room * 0.55))
			r.Title:SetWidth(tw)
			r.Sub:SetWidth(max(40, min(floor(r.Sub:GetStringWidth() + 1), room - tw - 10)))
			r.Pin.psPoint, r.Pin.psLabel = st, st and st.name
			r.psQuest, r.psLevel = cq, plevel
			W.SetIconState(r.Pin, false, canGuide(st))
			r:Show()
			y = y + CHAIN_H
		end
	end
	hidePool(b.Chains, nChain + 1)
	-- Rewards: the choice, the items you get, then XP, money and reputation.
	local items = (q.rewards or {}).items or {}
	local nTiles = 0
	labelAt(b.ChooseLabel, p.choose and p.choose + 10)
	if p.choose then nTiles = nTiles + placeTiles(b, nTiles, items, true, p.choose) end
	labelAt(b.GetLabel, p.get and p.get + 10)
	if p.get then nTiles = nTiles + placeTiles(b, nTiles, items, false, p.get) end
	hidePool(b.Tiles, nTiles + 1)
	labelAt(b.MoreLabel, p.more and p.more + 4 or nil)
	local x = VALUE_X
	for i, e in ipairs(p.extras) do
		local c = chip(b, i)
		local w = W.SetChip(c, e, "neutral")
		c:ClearAllPoints()
		c:SetPoint("TOPLEFT", b, "TOPLEFT", x, -p.more)
		x = x + w + 6
	end
	hidePool(b.Chips, #p.extras + 1)
	local cs = p.chainXP
	local cw = UI.LevelTip.Set(b.ChainXP, cs, cs and {
		head = L["If you finish this quest and the chain before it"],
		need = L["You are level %d. Level %d is recommended for the first quest in this chain; from there:"],
		chip = format(L["%s XP with its chain"], thousands(cs.xp)),
	} or nil)
	if cw then
		b.ChainXP:ClearAllPoints()
		b.ChainXP:SetPoint("TOPLEFT", b, "TOPLEFT", x, -p.more)
	end
	b:Show()
end

-- The current quests pass: the list, each block's plan and top, which
-- blocks are drawn.
local qpass = { quests = {}, plans = {}, tops = {}, painted = {}, key = nil, plevel = 1 }

-- Draw the blocks in view (and a screen past it); the rest wait.
function DS.PaintQuests()
	if not (pg and pg:IsShown() and tab == "quests" and qpass.key) then return end
	local top = pg.Scroll:GetVerticalScroll() or 0
	local view = viewHeight(pg.Scroll)
	local n = 0
	for i, q in ipairs(qpass.quests) do
		local y, p = qpass.tops[i], qpass.plans[i]
		if not qpass.painted[i] and y < top + view * 2 and y + p.h > top - view / 2 then
			paintQuest(block(i), q, p, y, qpass.plevel, qpass.key)
			qpass.painted[i] = true
		end
		if qpass.painted[i] then n = n + 1 end
	end
	shown.blocks = n
end

local function renderQuests(key, f, plevel)
	local side = SIDE[f]
	local qs = D().Quests(key, side)
	hidePool(blocks)
	qpass.quests, qpass.key, qpass.plevel = qs, key, plevel
	local plans, tops = {}, {}
	local y = 4
	for i, q in ipairs(qs) do
		local p = plan(q, key)
		plans[i], tops[i] = p, y
		y = y + p.h + CARD_GAP
	end
	qpass.plans, qpass.tops, qpass.painted = plans, tops, {}
	if #qs == 0 then
		local other = 0
		if side then other = #D().Quests(key, side == "A" and "H" or "A") end
		local text = L["No quests are known for this dungeon yet."]
		if other > 0 then
			local them = ns.FactionName(side == "A" and "H" or "A")
			text = other == 1 and format(L["1 quest here is for the %s. Switch the filter to All to see it."], them)
				or format(L["%d quests here are for the %s. Switch the filter to All to see them."], other, them)
		end
		y = emptyPage(L["No quests for you here"], text, 20)
	end
	shown.quests = #qs
	return y + 16
end

local TIE = {
	kill = { "icon-kill", L["Kill it for %s"] },
	item = { "icon-collect", L["Drops %s for %s"] },
	starts = { "icon-accept", L["Drops %s, which starts %s"] },
	involved = { "icon-note", L["Part of %s"] },
}

local BOSS_ROLE = { rare = L["Rare"], event = L["Event"], optional = L["Optional"] }

-- The facts beside a boss's name: level, Chest (an object boss, under its
-- own key: "Chest" is also the gear slot), its role.
local function bossFacts(boss)
	local t = {}
	if boss.level then t[#t + 1] = format(L["Level %d"], boss.level) end
	if boss.object then t[#t + 1] = ns.LC("boss", "Chest") end
	if BOSS_ROLE[boss.role] then t[#t + 1] = BOSS_ROLE[boss.role] end
	return concat(t, DOT)
end

local function renderBosses(key, f, plevel)
	local side = SIDE[f]
	local MW = questWidth()
	local y, nt = 4, 0
	local bosses = D().Bosses(key)
	for i, boss in ipairs(bosses) do
		local r = bossRow(i)
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", pg.Body, "TOPLEFT", EDGE, -y)
		r:SetWidth(MW)
		r.Num:SetText(tostring(boss.order or i))
		r.Name:SetText(boss.name or L["Boss"])
		r.Level:SetText(bossFacts(boss))
		local h = 48
		local n = 0
		for _, t in ipairs(boss.quests or {}) do
			local q = D().Quest(key, t.id)
			if q and (not side or not q.faction or q.faction == side) then
				nt = nt + 1
				n = n + 1
				local row = tie(nt)
				local spec = TIE[t.how] or TIE.involved
				row.Glyph:SetTexture(Theme.Media(spec[1]))
				local qh = "|c" .. hexOf(difficulty(q.level, plevel)) .. (ns.Quoted(q.title) or "") .. "|r"
				local ih = "|c" .. Theme.Hex("item") .. (t.itemName or L["an item"]) .. "|r"
				if t.how == "item" or t.how == "starts" then
					row.Text:SetText(format(spec[2], ih, qh))
				else
					row.Text:SetText(format(spec[2], qh))
				end
				row.psQuest = q.id
				row:SetFrameLevel(r:GetFrameLevel() + 2)
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", pg.Body, "TOPLEFT", EDGE + PAD + 10, -(y + h - 6))
				row:SetWidth(MW - PAD * 2 - 10)
				row.Text:SetWidth(MW - PAD * 2 - 34)
				row:Show()
				h = h + TIE_H
			end
		end
		if n > 0 then h = h + 10 end
		r:SetHeight(h)
		r:Show()
		y = y + h + 8
	end
	hidePool(bossRows, #bosses + 1)
	hidePool(ties, nt + 1)
	if #bosses == 0 then
		y = emptyPage(L["No bosses known yet"], L["The sources Alfa reads list no bosses for this dungeon."], 20)
	end
	shown.bosses, shown.ties = #bosses, nt
	return y + 16
end

local function renderMap(key, d, f)
	local art = pg.MapArt
	local e = d.entrance
	local side = SIDE[f]
	local painted = e and ZoneArt.Paint(art, e.map, e.x, e.y, 1)
	pg.MapPanel:Show()
	pg.MapNote:Show()
	local n = 0
	if painted then
		placeOn(art.Entrance, art, e.x, e.y)
		art.Entrance:Show()
		-- The quest givers on the entrance's zone, one marker per giver.
		local byGiver, order = {}, {}
		for _, q in ipairs(D().Quests(key, side)) do
			local s = startOf(q, e)
			if s and s.map == e.map and s.x and s.y and not s.inside then
				local id = (s.kind or "") .. tostring(s.id or s.name)
				local gq = byGiver[id]
				if not gq then
					gq = { point = s, lines = {} }
					byGiver[id] = gq
					order[#order + 1] = gq
				end
				gq.lines[#gq.lines + 1] = q.title
			end
		end
		for _, gq in ipairs(order) do
			n = n + 1
			local g = giver(n)
			placeOn(g, art, gq.point.x, gq.point.y)
			g.psName, g.psLines = gq.point.name, gq.lines
			g:Show()
		end
	else
		art.Entrance:Hide()
		if not e then ZoneArt.Paint(art, nil, nil, nil, 1) end
	end
	hidePool(givers, n + 1)
	if e then
		local z = mapName(e.map) or d.zoneName or ""
		local text = format(L["The entrance, on %s (%.1f, %.1f)."], z, e.x or 0, e.y or 0)
		if n > 0 then text = text .. " " .. (n == 1 and L["The quest giver nearby is marked; hover for their quests."] or format(L["The %d quest givers nearby are marked; hover for their quests."], n)) end
		local warn = enemyWarning(d, f)
		if warn then text = warn .. "\n" .. text end
		pg.MapNote:SetText(text)
	else
		pg.MapNote:SetText(L["The entrance of this dungeon is not known yet."])
	end
	shown.map, shown.givers = e and "entrance" or "none", n
	return 8 + MAP_H + 16 + 14 + pg.MapNote:GetStringHeight() + 24
end

---------------------------------------------------------------------------
-- Attunement: what lets a character in or opens the doors, with this
-- character's progress (Dungeons/Attune.lua) and "Guide me through it"
---------------------------------------------------------------------------

local ATT_GLYPH = {
	done = { "check", "success" }, ready = { "icon-turnin", "success" }, log = { "icon-turnin", "quest" },
	open = { "icon-accept", "quest" }, locked = { "circle", "textMuted" }, level = { "lock", "textMuted" },
	rep = { "lock", "textMuted" }, na = { "circle", "textMuted" }, skip = { "circle", "textMuted" },
}
-- An open step that is no quest wears its own verb's glyph.
local ITEM_GLYPH = { drop = "icon-kill", object = "icon-interact", rep = "icon-rep", gift = "icon-talk" }
local ATT_KIND = { attunement = L["Attunement"], key = L["Key"], item = L["Item"] }

local function colored(token, text)
	return "|c" .. Theme.Hex(token) .. (text or L["Not known"]) .. "|r"
end

-- The client's word for a standing; Neutral when the step names none.
local function standingName(n)
	return ns.StandingName(n) or ns.StandingName(4)
end

-- A step -> its line and the point its click sets the arrow to.
local function stepLine(s, plevel)
	if s.kind == "quest" then
		return "|c" .. hexOf(difficulty(s.level, plevel)) .. (s.title or "") .. "|r", s.start
	elseif s.kind == "drop" then
		return format(L["%s from %s"], colored("item", s.item.name), colored("npc", s.npc and s.npc.name)), s.npc
	elseif s.kind == "object" then
		return format(L["%s from %s"], colored("item", s.item.name), colored("object", s.object and s.object.name)), s.object
	elseif s.kind == "rep" then
		return format(L["Reach %s with %s"], standingName(s.standing), colored("faction", factionName(s.faction, s.name))), nil
	elseif s.kind == "gift" then
		return format(L["%s gives you %s"], colored("npc", s.npc and s.npc.name), colored("item", s.item.name)), s.npc
	end
	return "", nil
end

-- The words after a step: its state, who a quest is for (whoText), then
-- where (a quest's giver, a drop's chance and instance).
local function stepSub(s, state)
	local t = {}
	if state == "done" then t[#t + 1] = L["Done"]
	elseif state == "ready" then t[#t + 1] = L["Ready to turn in"]
	elseif state == "log" then t[#t + 1] = L["In your log"]
	elseif state == "locked" then t[#t + 1] = L["After the steps before it"]
	elseif state == "level" then t[#t + 1] = format(L["From level %d"], s.minLevel or 0)
	elseif state == "rep" and s.rep then t[#t + 1] = format(L["Needs %s with %s"], standingName(s.rep.standing), factionName(s.rep.faction, s.rep.name) or L["Not known"])
	elseif state == "skip" then t[#t + 1] = L["Not needed"]
	end
	if s.kind == "quest" then
		local who = whoText(s)
		if who then t[#t + 1] = who end
	end
	if s.kind == "quest" and s.start then
		t[#t + 1] = pointText(s.start)
	elseif (s.kind == "drop" or s.kind == "object") and s.chance then
		t[#t + 1] = format(L["%d%% chance"], floor(s.chance + 0.5))
	end
	if s.kind == "drop" and s.instance then
		local inst = D().Get(s.instance)
		if inst then t[#t + 1] = format(L["inside %s"], inst.name) end
	end
	return concat(t, DOT)
end

local function located(p)
	return type(p) == "table" and p.map ~= nil and p.x ~= nil and p.y ~= nil
end

local function renderAttune(key, f, plevel)
	local side = SIDE[f]
	local MW = questWidth()
	local Dg = D()
	local mineCode = SIDE[UI.PlayerFaction() or ""]
	local list_ = Dg.Attunements(key, side)
	local y, nr = 4, 0
	shown.attune = {}
	for i, a in ipairs(list_) do
		local st = Dg.AttunementState(a)
		local h = attHead(i)
		h:ClearAllPoints()
		h:SetPoint("TOPLEFT", pg.Body, "TOPLEFT", EDGE, -y)
		h:SetWidth(MW)
		W.Color(h.Title, a.kind == "attunement" and "quest" or "item")
		h.Title:SetText(a.name or "")
		-- This character's state: the other side's attunement has none.
		local mine = not a.faction or a.faction == mineCode
		local total, did = 0, 0
		for _, e in ipairs(st.steps) do
			if e.state ~= "na" and e.state ~= "skip" then
				total = total + 1
				if e.state == "done" then did = did + 1 end
			end
		end
		local glyph, chipText = { "icon-dungeon", "dungeon" }, nil
		if not mine then
			h.State:Hide()
		elseif st.done then
			chipText = L["Done"]
			W.SetChip(h.State, chipText, "success")
			glyph = { "check", "success" }
		elseif st.goalDone and a.item then
			chipText = L["Not in your bags"]
			W.SetChip(h.State, chipText, "warning")
		elseif did > 0 then
			chipText = format(L["%d of %d done"], did, total)
			W.SetChip(h.State, chipText)
		else
			h.State:Hide()
		end
		h.Glyph:SetTexture(Theme.Media(glyph[1]))
		W.Color(h.Glyph, glyph[2])
		local facts = { ATT_KIND[a.kind] or ATT_KIND.attunement }
		facts[#facts + 1] = a.need == "one" and L["One in the group is enough"] or L["Everyone entering needs it"]
		if a.level then facts[#facts + 1] = format(L["From level %d"], a.level) end
		if a.faction == "A" then facts[#facts + 1] = L["Alliance only"] elseif a.faction == "H" then facts[#facts + 1] = L["Horde only"] end
		h.Meta:SetText(concat(facts, DOT))
		local hy = 66
		if a.note then
			h.Note:SetWidth(MW - PAD * 2)
			h.Note:SetText(L[a.note]) -- the attunement table's notes are data keys (tools/lib/i18n/keys.js)
			h.Note:Show()
			hy = hy + floor(h.Note:GetStringHeight() + 0.5)
		else
			h.Note:Hide()
		end
		-- The item it gives (a key, the amulet), and whether it is owned.
		local t = h.Tiles[1]
		if a.item then
			t = tile(h, 1)
			hy = hy + 10
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", h, "TOPLEFT", PAD, -hy)
			t.psID = a.item.id
			local icon = itemIcon(a.item.id)
			if icon then
				t.Icon:SetTexture(icon)
				t.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
				W.Uncolor(t.Icon)
				t.Icon:SetVertexColor(1, 1, 1, 1)
			else
				t.Icon:SetTexture(Theme.Media("icon-collect"))
				t.Icon:SetTexCoord(0, 1, 0, 1)
				W.Color(t.Icon, "textMuted")
			end
			paintTile(t, a.item.id, a.item.quality)
			t.Name:SetText(a.item.name or (L["Item"] .. " " .. tostring(a.item.id)))
			t:Show()
			h.Owned:ClearAllPoints()
			h.Owned:SetPoint("LEFT", t, "RIGHT", 12, 0)
			if mine then
				h.Owned:SetText(st.owned and L["You have it"] or L["Not in your bags or bank"])
				W.Color(h.Owned, st.owned and "success" or "textMuted")
				h.Owned:Show()
			else
				h.Owned:Hide()
			end
			hy = hy + TILE_H
		else
			if t then t:Hide() end
			h.Owned:Hide()
		end
		-- "Guide me through it": while something is left for this character.
		local can = mine and not st.done and st.left > 0 and Dg.Attune ~= nil and ns.Lookup ~= nil
		h.Guide:SetShown(can)
		h.Guide.psAtt = a.id
		h.Guide.psTip = L["Guide me through it"]
		h.Guide.psTipLines = { st.left == 1 and L["A guide through the 1 step left, from where you stand."]
			or format(L["A guide through the %d steps left, from where you stand."], st.left), L["It opens in a new tab."] }
		hy = hy + 12
		-- The steps, this side's only, over the panel.
		local states = {}
		for _, e in ipairs(st.steps) do
			local s = e.step
			if not side or not s.faction or s.faction == side then
				nr = nr + 1
				local r = attStep(nr)
				r:SetFrameLevel(h:GetFrameLevel() + 2)
				r:ClearAllPoints()
				r:SetPoint("TOPLEFT", pg.Body, "TOPLEFT", EDGE, -(y + hy))
				r:SetWidth(MW - 12)
				local state = mine and e.state or "na"
				local g = ATT_GLYPH[state] or ATT_GLYPH.na
				local gname = (state == "open" and ITEM_GLYPH[s.kind]) or g[1]
				r.Glyph:SetTexture(Theme.Media(gname))
				r.Glyph:SetSize(gname == "circle" and 6 or 12, gname == "circle" and 6 or 12)
				W.Color(r.Glyph, (state == "open" and ITEM_GLYPH[s.kind]) and "textDim" or g[2])
				local text, point = stepLine(s, plevel)
				r.Text:SetText(text)
				r.Sub:SetText(stepSub(s, mine and e.state or nil))
				r.psPoint = located(point) and point or nil
				r.psLabel = point and point.name or nil
				r.psTip = r.psPoint and L["Set the arrow here"] or nil
				r:Show()
				states[#states + 1] = state
				hy = hy + TIE_H
			end
		end
		hy = hy + 14
		h:SetHeight(hy)
		h:Show()
		shown.attune[i] = { id = a.id, done = st.done, chip = chipText, guide = can, owned = st.owned, states = states }
		y = y + hy + 8
	end
	hidePool(atts, #list_ + 1)
	hidePool(attSteps, nr + 1)
	if #list_ == 0 then
		y = emptyPage(L["Nothing to unlock"], L["Nothing the sources Alfa reads names opens this dungeon's way in or its doors."], 20)
	end
	return y + 16
end

local TABS = { { key = "quests" }, { key = "attune" }, { key = "bosses" }, { key = "map" } }

-- A page's tabs, as the hub's pills: back to every dungeon, then its own.
local function pageTabs(key)
	local f = factionKey()
	local side = SIDE[f]
	local nq = #D().Quests(key, side)
	local nb = #D().Bosses(key)
	local att = D().Attunements(key, side)
	local items = { { key = "home", label = T("Todas las mazmorras"), icon = "chevron-left" } }
	items[#items + 1] = { key = "quests", label = L["Quests"], count = nq > 0 and nq or nil }
	if #att > 0 then
		-- "Keys" when every one is a key, else "Attunement".
		local keys = true
		for _, a in ipairs(att) do keys = keys and a.kind == "key" end
		items[#items + 1] = { key = "attune", label = keys and L["Keys"] or L["Attunement"], count = #att > 1 and #att or nil }
	end
	items[#items + 1] = { key = "bosses", label = L["Bosses"], count = nb > 0 and nb or nil }
	items[#items + 1] = { key = "map", label = T("Entrada") }
	return items, #att
end

local function renderPage(key, plevel)
	local d = D().Get(key)
	if not d then
		page = nil
		return false
	end
	home:Hide()
	pg:Show()
	pageHeader(d)
	local f = factionKey()
	local _, natt = pageTabs(key)
	if tab == "attune" and natt == 0 then tab = "quests" end
	-- The name and what the ficha says sit in the ficha: nothing beside the pills.
	W.ShellTitle(hub, d.name, "")
	-- Hide what the other tabs put up.
	pg.EmptyTitle:Hide()
	pg.EmptyNote:Hide()
	if tab ~= "quests" then
		hidePool(blocks)
		qpass.key = nil
	end
	if tab ~= "bosses" then hidePool(bossRows); hidePool(ties) end
	if tab ~= "attune" then hidePool(atts); hidePool(attSteps) end
	if tab ~= "map" then
		pg.MapPanel:Hide()
		pg.MapNote:Hide()
		hidePool(givers)
	end
	local h
	if tab == "bosses" then
		h = renderBosses(key, f, plevel)
	elseif tab == "attune" then
		h = renderAttune(key, f, plevel)
	elseif tab == "map" then
		h = renderMap(key, d, f)
	else
		h = renderQuests(key, f, plevel)
	end
	pg.Body:SetWidth(mainWidth())
	W.SetScrollContent(pg.Scroll, h)
	if tab == "quests" then DS.PaintQuests() end
	shown.view, shown.page, shown.tab = "page", key, tab
	return true
end

---------------------------------------------------------------------------
-- Render
---------------------------------------------------------------------------

local REASON = {
	nodata = L["The Alfa_Codex addon is older than this Alfa: reinstall Alfa, then /reload."],
	missing = L["The Alfa_Codex addon is not installed. Get Alfa from CurseForge or the GitHub Releases page (the Alfa zip under Assets, not \"Source code\"), install it and restart the game."],
	disabled = L["The Alfa_Codex addon is turned off: enable it in the AddOns list, then /reload."],
}

local function renderEmpty(reason)
	home:Show()
	pg:Hide()
	hidePool(cards)
	hidePool(heads)
	home.psCount = 0
	home.Tool:Hide()
	W.ShellTitle(hub, T("Mazmorras"), L["Every dungeon quest, where it starts and what it gives"])
	home.Watermark:Show()
	local text
	if reason == "off" then
		text = L["The Dungeons section is turned off. Turn it on under Options > Discovery > Dungeons."]
	else
		local LK = UI.Lookup
		text = REASON[reason] or (LK and LK.ReasonText and LK.ReasonText(reason)) or tostring(reason)
	end
	home.EmptyTitle:SetText(reason == "off" and L["Dungeons are off"] or L["Dungeons need the Codex"])
	home.EmptyNote:SetText(text)
	home.EmptyTitle:Show()
	home.EmptyNote:Show()
	W.SetScrollContent(home.Scroll, 160)
	shown.view, shown.empty = "empty", reason
end

function DS.Render()
	if not root then return end
	for k in pairs(shown) do shown[k] = nil end
	local Dg = D()
	local loaded, reason
	if Dg then loaded, reason = Dg.Load() else loaded, reason = false, "missing" end
	if not loaded then
		renderEmpty(reason)
		return
	end
	home.Tool:Show()
	segPaint()
	local plevel = playerLevel()
	if page and renderPage(page, plevel) then return end
	home.EmptyTitle:Hide()
	home.EmptyNote:Hide()
	renderHome(plevel)
end

-- Re-render the whole hub while Dungeons is its section, so the pills mark
-- the band or the tab; else just this section.
local function refresh()
	local P = UI.Picker
	if P and P.Section and P.Section() == "Dungeons" and P.Render and hub and hub:IsShown() then
		P.Render()
	elseif root and root:IsVisible() then
		DS.Render()
	end
end

-- The pills: the bands on Home, the tabs on a page.
function DS.Nav()
	local Dg = D()
	if not (Dg and Dg.IsEnabled() and Dg.Load()) then return {}, nil end
	if page and Dg.Get(page) then
		local items, natt = pageTabs(page)
		return items, (tab == "attune" and natt == 0) and "quests" or tab
	end
	local plevel = playerLevel()
	local items = navItems(plevel, factionKey())
	return items, (filter == "" and defaultBand(plevel)) or nil
end

function DS.SetBand(key)
	band = key
	page = nil
	if home then W.ScrollTo(home.Scroll, 0) end
	refresh()
end

function DS.SetTab(key)
	for _, t in ipairs(TABS) do
		if t.key == key then
			tab = key
			if pg then W.ScrollTo(pg.Scroll, 0) end
			refresh()
			return
		end
	end
end

-- A pill: a page's tab (or back to every dungeon) while a page is open, else a band.
function DS.OnNav(key)
	if page then
		if key == "home" then DS.Home() else DS.SetTab(key) end
		return
	end
	DS.SetBand(key)
end

function DS.SetFaction(f)
	uiState().dungeonsFaction = f
	refresh()
end

function DS.Open(key)
	page = key
	tab = "quests"
	if pg then W.ScrollTo(pg.Scroll, 0) end
	refresh()
end

function DS.Home()
	page = nil
	refresh()
end

-- The Quests tab, scrolled to one quest.
function DS.ShowQuest(id)
	tab = "quests"
	refresh()
	for i, q in ipairs(qpass.quests) do
		if q.id == id then
			W.ScrollTo(pg.Scroll, max(0, qpass.tops[i] - 8))
			DS.PaintQuests()
			return
		end
	end
end

function DS.GuideThere()
	local Dg = D()
	if page and Dg then Dg.GuideTo(page) end
end

-- Open a dungeon's planned guide (open: Dungeons.PickUp or HandIn) in a new
-- tab; the hub steps aside, as Lookup's guides do. Nothing to plan says why
-- in chat (nothing(): the sentence).
local function openPlanned(open, key, nothing)
	local gid, reason = open(key)
	if gid then
		ns.Set("ui.shown", true)
		-- Alfa: se cierran las demas ventanas de Alfa y queda el seguimiento (Alfa_Nucleo)
		if AlfaNucleo and AlfaNucleo.EmpezarRuta then AlfaNucleo.EmpezarRuta() end
		if hub then hub:Hide() end
		return gid
	end
	local text
	if reason == "nothing" then
		text = nothing()
	elseif reason == "tabs" then
		-- Alfa 1.3.7: el aviso trae «Ver lo que sigues» (Alfa_Rutas/EnCurso.lua).
		local R = rawget(_G, "AlfaRuta")
		if type(R) == "table" and type(R.AvisoLleno) == "function" then
			R.AvisoLleno()
			refresh()
			return nil, reason
		end
		text = L["Six tabs is the limit. Close one to open another."]
	else
		text = format(L["No guide could be made for this (%s)."], tostring(reason))
	end
	ns.Print(text)
	refresh()
	return nil, reason
end

-- The page's pick-up guide; nothing to pick up says so instead.
function DS.PickUp()
	local Dg = D()
	if not (page and Dg and Dg.PickUp) then return nil end
	local key = page
	return openPlanned(Dg.PickUp, key, function() return DS.NothingText(Dg.PickupPlan(key)) end)
end

-- A dungeon's hand-in guide (the page's, or `key`'s from the finished
-- pick-up guide); nothing finished says what is still open instead.
function DS.HandIn(key)
	local Dg = D()
	key = key or page
	if not (key and Dg and Dg.HandIn) then return nil end
	return openPlanned(Dg.HandIn, key, function() return Dg.HandinText(Dg.HandinPlan(key)) end)
end

-- An attunement's guide (Dungeons.Attune), from the page's Attunement tab;
-- nothing left says so instead.
function DS.Attune(id)
	local Dg = D()
	if not (page and id and Dg and Dg.Attune) then return nil end
	return openPlanned(function(key)
		local gid, reason = Dg.Attune(key, id)
		if reason == "done" then reason = "nothing" end
		return gid, reason
	end, page, function() return L["Nothing is left to do for it."] end)
end

-- In combat the map stays shut (Compat.OpenWorldMap: opening it then is
-- blocked); the chat says so instead of the button doing nothing (review P3-13).
function DS.ShowOnMap()
	local Dg = D()
	if not (page and Dg) then return end
	if ns.Compat.InCombat() then
		ns.Print(L["The map can't open in combat: press Show on map again when it ends."])
		return
	end
	Dg.ShowOnMap(page)
end

function DS.Search(text)
	filter = text or ""
	page = nil
	if home then W.ScrollTo(home.Scroll, 0) end
	refresh()
end

-- Enter opens the first card.
function DS.Enter()
	if page or not home then return end
	local c = cards[1]
	if c and c:IsShown() and c.psKey then DS.Open(c.psKey) end
end

-- SHOW_DUNGEON(key): the hub at the page (nil: Home).
-- Con el diario reemplazado (SHOW_DUNGEON, Core/Reemplazos.lua) se abre la
-- ventana de Alfa con { mazmorra = key }.
function DS.Show(key)
	if ns.Reemplazos and ns.Reemplazos.Llamar("SHOW_DUNGEON", { mazmorra = key }) then return end
	page = key
	tab = "quests"
	filter = ""
	local win = AlfaPicker
	if win and win.Search then win.Search:SetText("") end
	if UI.AbrirCentro then UI.AbrirCentro("Dungeons") end
	if pg then W.ScrollTo(pg.Scroll, 0) end
	if home then W.ScrollTo(home.Scroll, 0) end
end

function DS.Page() return page end
function DS.Tab() return tab end
function DS.Shown() return shown end
DS.cards, DS.blocks, DS.bossRows, DS.ties, DS.givers = cards, blocks, bossRows, ties, givers
DS.atts, DS.attSteps = atts, attSteps
function DS.Frames() return root, home, pg, segs end

ns.On("SHOW_DUNGEON", function(key) DS.Show(key) end)
-- The dungeon list carries names: a late names pack sorts and names it anew.
local function listChanged()
	listCache = nil
	if root and root:IsVisible() then DS.Render() end
end
ns.On("CODEX_LOADED", listChanged)
ns.On("NAMES_LOADED", listChanged)
Theme.OnChanged(function() if root and root:IsVisible() then DS.Render() end end)
local function questsChanged()
	if root and root:IsVisible() and page then DS.Render() end
end
for _, ev in ipairs({ "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN", "PLAYER_LEVEL_UP" }) do
	ns.RegisterEvent(ev, questsChanged)
end
-- A key picked up or a standing reached changes the Attunement tab only.
local function ownedChanged()
	if tab == "attune" and root and root:IsVisible() and page then DS.Render() end
end
for _, ev in ipairs({ "BAG_UPDATE_DELAYED", "UPDATE_FACTION" }) do
	ns.RegisterEvent(ev, ownedChanged)
end

if UI.RegisterSection then
	UI.RegisterSection({
		key = "Dungeons", label = "Mazmorras", icon = "icon-dungeon", order = 30,
		build = DS.Build,
		render = DS.Render,
		nav = DS.Nav,
		onNav = DS.OnNav,
		search = DS.Search,
		enter = DS.Enter,
		searchPlaceholder = L["Search dungeons"],
	})
end
