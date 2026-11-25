-- The waypoint arrow: turns smoothly toward the target, with distance, label
-- and ETA underneath, and while a timed quest's timer runs its countdown
-- between the distance and the label (syncTimer). It shifts from its far colour to its near colour as
-- you close in and becomes a pulsing ring on arrival. On another continent
-- it shows the target's zone instead; where the client gives no player
-- position (the Deeprun Tram) it says so over the label, or keeps showing the
-- route's ride, until a position returns.
--
-- Colour comes from Theme through Nav.RGB / Nav.Wash (repainted in OnTheme):
-- the arrow in "arrow" far away and "arrowNear" up close and on arrival (the
-- accent and success unless the player picked their own, nav.arrowColor /
-- nav.arrowNearColor), text in those colours in their legible *Text forms;
-- the distance in text, the label in text, the ETA line 12px in text at 80%,
-- outlines and shadows in shade, the hover wash that says "movable" in the
-- ink "mover" wash. No colour literals.
--
-- Styles (nav.arrowStyle; "skin", the default, takes the skin's: the wolf
-- in Alfa's three looks, Alfa, Clasico WoW and Cristal; the Halo dart in Halo,
-- the Hearth dart in Hearth and the other game looks):
--   "lobo" Alfa: la cabeza de un lobo vista desde arriba, el hocico por punta
--          y las orejas hacia atras como las aletas de una flecha
--          (Media/Nav/lobo-flecha*, tools/flecha_lobo.py), girada con
--          SetRotation, en el color de la flecha sobre un contorno oscuro que
--          la separa del terreno; al llegar, la huella del lobo dentro del aro.
--   "3d"   a pre-rendered arrow lying on the ground in front of you: one
--          sprite-sheet frame per heading (tools/media/nav/arrow3d.js), the
--          body tinted with SetVertexColor and an untinted specular sheet
--          added on top; the heading picks the frame
--   "flat" a faceted dart rotated with SetRotation
--   "halo", "hearth"  the skins' darts (DIRECTION_B_HALO.md §3,
--          DIRECTION_A_BLIZZARD.md §5; tools/media/skins.js): a 54-unit dart
--          with a dark 2-unit edge, rotated; Halo's in the accent, Hearth's
--          gold gradient baked in; both turn to the arrival colour within
--          40 m. Arrival: a 48-unit ring (stroke 3), then a check (stroke 5).
--
-- Work happens only while shown: OnUpdate samples the world at 20 Hz and
-- turns the heading every frame, allocating nothing. The damping works on
-- the target's bearing on the map, capped at MAX_TURN, and the player's
-- facing is taken off every frame: a new aim point swings the arrow round
-- smoothly, while turning the camera moves it at once. Hidden states (no
-- target, taxi, instance) are re-checked by Nav's once-a-second ticker. It
-- goes with the guide window only with nav.hideArrowWithGuide on, and never
-- on the way back to your corpse (Nav.HiddenWithGuide). Hiding Polestar
-- takes it unless "Keep the arrow when hidden" is on (ns.ArrowHidden): it
-- stays on UIParent, outside Polestar's layer, so it can be kept.

local ADDON, ns = ...
local Nav = ns.Nav
local L = ns.L

local exp, sin, abs, floor, min, max, pi = math.exp, math.sin, math.abs, math.floor, math.min, math.max, math.pi
local wrap = Nav.WrapAngle
local MEDIA = Nav.MEDIA

local SAMPLE_INTERVAL = 0.05 -- seconds between world samples
local DAMPING = 12           -- rotation stiffness (1/s); higher = snappier
local MAX_TURN = 3.5         -- radians a second the bearing may swing (about 200°)
local CLOSE_RANGE = 250      -- yards over which the colour shifts toward success
local DIAL = 64

-- Sprite sheet layout; must match tools/media/nav/arrow3d.js LAYOUT.
local FRAMES, COLS, CELL, SHEET = 100, 10, 102, 1024
local TWO_PI = 2 * pi
local STEP = TWO_PI / FRAMES
local SPRITE = DIAL * 1.5

ns.RegisterDefaults("nav", { arrowStyle = "skin", arrowMinimo = false,
	flechaPorPersonaje = true, viajeCompacto = true }) -- 1.4.0 (33, 69)

-- The style a skin's arrow takes ("skin" in nav.arrowStyle).
local SKIN_ARROW = { alfa = "lobo", halo = "halo", hearth = "hearth", forever = "hearth", blizzard = "hearth", classic = "lobo" }
local DART = 54          -- the skins' dart, in the 64-unit dial
local DART_NEAR = 43.7   -- 40 m, in yards: the skins' darts turn to the arrival colour
local SKIN_RING = 48     -- the skins' arrival ring
-- The darts' dark edge: Halo #17130E (near #0B1A0C), Hearth #2A1A00.
local EDGE = { halo = { 0.09, 0.075, 0.055 }, haloNear = { 0.043, 0.102, 0.047 }, hearth = { 0.165, 0.102, 0 } }

-- Sheet frame for a heading (radians, counter-clockwise, 0 = straight ahead):
-- frame i shows the arrow turned i * 360 / FRAMES degrees.
function Nav.ArrowFrame(angle)
	return floor((angle % TWO_PI) / STEP + 0.5) % FRAMES
end

-- Texture coordinates of a frame: left, right, top, bottom.
function Nav.ArrowFrameCoords(index)
	local col = index % COLS
	local row = (index - col) / COLS
	return col * CELL / SHEET, (col + 1) * CELL / SHEET, row * CELL / SHEET, (row + 1) * CELL / SHEET
end

local WIDTH, TEXT_H = 200, 66 -- the frame: the dial, and the distance and label under it

local frame = CreateFrame("Frame", "AlfaNavArrow", UIParent)
frame:SetSize(WIDTH, DIAL + TEXT_H)
frame:SetFrameStrata("MEDIUM")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true) -- always movable: drag the arrow anywhere (Shift-drag with ui.lockHud on)
frame:RegisterForDrag("LeftButton")
frame:Hide()

local dial = CreateFrame("Frame", nil, frame)
dial:SetSize(DIAL, DIAL)
dial:SetPoint("TOP", frame, "TOP", 0, 0)

-- Shown behind the part that takes the mouse while hovering it, so it reads
-- as movable.
local mover = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
mover:SetColorTexture(Nav.Wash("mover"))
mover:Hide()

-- Only the dial takes the mouse: the text under it would otherwise catch
-- drags meant for the world, more so at a large scale. Without the dial
-- (another continent, no position) the text is all there is, so it does.
local function grabArea(onDial)
	local side = onDial and (WIDTH - DIAL) / 2 or 0
	frame:SetHitRectInsets(side, side, onDial and 0 or DIAL, onDial and TEXT_H or 0)
	mover:ClearAllPoints()
	if onDial then
		mover:SetAllPoints(dial)
	else
		mover:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -DIAL)
		mover:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	end
end
grabArea(true)

local glow = dial:CreateTexture(nil, "BACKGROUND")
glow:SetTexture(MEDIA .. "arrow-glow")
glow:SetSize(DIAL * 1.25, DIAL * 1.25)
glow:SetPoint("CENTER")
glow:SetBlendMode("ADD")

local body = dial:CreateTexture(nil, "ARTWORK")
body:SetTexture(MEDIA .. "arrow")
body:SetAllPoints()

local facet = dial:CreateTexture(nil, "ARTWORK", nil, 1)
facet:SetTexture(MEDIA .. "arrow-facet")
facet:SetAllPoints()

local sheet = dial:CreateTexture(nil, "ARTWORK")
sheet:SetTexture(MEDIA .. "arrow3d")
sheet:SetSize(SPRITE, SPRITE)
sheet:SetPoint("CENTER")

local sheetSpec = dial:CreateTexture(nil, "ARTWORK", nil, 2)
sheetSpec:SetTexture(MEDIA .. "arrow3d-spec")
sheetSpec:SetSize(SPRITE, SPRITE)
sheetSpec:SetPoint("CENTER")
sheetSpec:SetBlendMode("ADD")

local halo = dial:CreateTexture(nil, "BACKGROUND")
halo:SetTexture(MEDIA .. "glow")
halo:SetSize(DIAL * 1.4, DIAL * 1.4)
halo:SetPoint("CENTER")
halo:SetBlendMode("ADD")

local ring = dial:CreateTexture(nil, "ARTWORK")
ring:SetTexture(MEDIA .. "arrived")
ring:SetSize(DIAL, DIAL)
ring:SetPoint("CENTER")

-- La flecha de Alfa (estilo "lobo"): el contorno oscuro debajo y el lobo
-- encima, del mismo tamano; al llegar, la huella dentro del aro.
local LOBO = DIAL * 0.95
local wolfEdge = dial:CreateTexture(nil, "ARTWORK", nil, 0)
wolfEdge:SetTexture(MEDIA .. "lobo-flecha-borde")
wolfEdge:SetSize(LOBO, LOBO)
wolfEdge:SetPoint("CENTER")
local wolf = dial:CreateTexture(nil, "ARTWORK", nil, 1)
wolf:SetTexture(MEDIA .. "lobo-flecha")
wolf:SetAllPoints(wolfEdge)
local wolfPaw = dial:CreateTexture(nil, "ARTWORK", nil, 2)
wolfPaw:SetTexture(MEDIA .. "lobo-llegada")
wolfPaw:SetSize(DIAL * 0.5, DIAL * 0.5)
wolfPaw:SetPoint("CENTER")
for _, t in ipairs({ wolfEdge, wolf, wolfPaw }) do t:Hide() end

-- The skins' darts and arrival (Media/UI: dart, dart-edge, dart-gold,
-- skin-ring, skin-check, circle).
local UI_DIR = "Interface\\AddOns\\" .. ADDON .. "\\Media\\UI\\"
local dart = dial:CreateTexture(nil, "ARTWORK")
dart:SetTexture(UI_DIR .. "dart")
dart:SetSize(DART, DART)
dart:SetPoint("CENTER")
local dartEdge = dial:CreateTexture(nil, "ARTWORK", nil, 1)
dartEdge:SetTexture(UI_DIR .. "dart-edge")
dartEdge:SetAllPoints(dart)
local skinDisc = dial:CreateTexture(nil, "BACKGROUND")
skinDisc:SetTexture(UI_DIR .. "circle")
skinDisc:SetSize(SKIN_RING - 2, SKIN_RING - 2)
skinDisc:SetPoint("CENTER")
local skinRing = dial:CreateTexture(nil, "ARTWORK")
skinRing:SetTexture(UI_DIR .. "skin-ring")
skinRing:SetSize(SKIN_RING * 60 / 48, SKIN_RING * 60 / 48) -- the ring is 48 of the texture's 60 units
skinRing:SetPoint("CENTER")
local skinCheck = dial:CreateTexture(nil, "ARTWORK", nil, 1)
skinCheck:SetTexture(UI_DIR .. "skin-check")
skinCheck:SetAllPoints(skinRing)
for _, t in ipairs({ dart, dartEdge, skinDisc, skinRing, skinCheck }) do t:Hide() end

-- A travel instruction (hearth, teleport, fly, take a boat or a lift) has no
-- direction to point at: the dial shows what to do instead, the leg's glyph in the accent.
local UI_MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\UI\\"
local LEG_ICON = { hearth = "icon-hearth", teleport = "icon-use", fly = "icon-fly", boat = "icon-boat", zeppelin = "icon-boat",
	tram = "icon-boat", portal = "icon-gate", lift = "icon-lift" }
local legIcon = dial:CreateTexture(nil, "ARTWORK")
legIcon:SetSize(DIAL * 0.6, DIAL * 0.6)
legIcon:SetPoint("CENTER")
legIcon:Hide()

-- The catch-up's hourglass (Arrow.SetBusy; Media/UI hourglass and
-- hourglass-sand, tools/media/ui.js): while the guide window goes over the
-- steps, it stands in the dial's place and turns over and over, the glass
-- in text and its sand in the arrow's colour, with the text under the dial
-- hidden.
local HOURGLASS_HOLD, HOURGLASS_TURN = 0.45, 0.4 -- seconds upright, then turning over
local glass = CreateFrame("Frame", nil, frame)
glass:SetSize(DIAL, DIAL)
glass:SetPoint("CENTER", dial, "CENTER")
glass:Hide()
local glassBody = glass:CreateTexture(nil, "ARTWORK", nil, 1)
glassBody:SetTexture(UI_MEDIA .. "hourglass")
glassBody:SetSize(DIAL * 0.8, DIAL * 0.8)
glassBody:SetPoint("CENTER")
local glassSand = glass:CreateTexture(nil, "ARTWORK")
glassSand:SetTexture(UI_MEDIA .. "hourglass-sand")
glassSand:SetAllPoints(glassBody)
local glassTime = 0
glass:SetScript("OnUpdate", ns.Safe(function(_, elapsed)
	glassTime = glassTime + elapsed
	local c = glassTime % (HOURGLASS_HOLD + HOURGLASS_TURN)
	local a = 0
	if c > HOURGLASS_HOLD then
		local p = (c - HOURGLASS_HOLD) / HOURGLASS_TURN
		p = p < 0.5 and 4 * p * p * p or 1 - (2 - 2 * p) ^ 3 / 2
		a = pi * p
	end
	glassBody:SetRotation(a)
	glassSand:SetRotation(a)
end))

local distText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
distText:SetPoint("TOP", dial, "BOTTOM", 0, -12) -- clear of the dart's tip and the 3D arrow's shadow
distText:SetJustifyH("CENTER")

-- A timed quest's countdown (Quests/Timed.lua), between the distance and the
-- label while a timer runs (syncTimer); the label sits under the distance
-- otherwise.
local timerText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
timerText:SetPoint("TOP", distText, "BOTTOM", 0, -4)
timerText:SetJustifyH("CENTER")
timerText:Hide()

-- About as wide as the distance line's longest text ("Hearth to The
-- Crossroads: saves 3 min"), so a quest name of that length stays on one
-- line; longer ones wrap to a second (#1581).
local LABEL_WIDTH = 300
local labelText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
labelText:SetPoint("TOP", distText, "BOTTOM", 0, -5)
labelText:SetWidth(LABEL_WIDTH)
labelText:SetJustifyH("CENTER")
labelText:SetWordWrap(true)
labelText:SetMaxLines(2)

local etaText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
etaText:SetPoint("TOP", labelText, "BOTTOM", 0, -4)
etaText:SetJustifyH("CENTER")

---------------------------------------------------------------------------
-- Alfa 1.4.0 (2, bug que Toxic vio en el juego): «Consigue Mena de estaño de
-- Filón de estaño» se salía de su renglón y el juego la cortaba a medias. La
-- meta cabe siempre en META_LINEAS renglones de LABEL_WIDTH: si no cabe, se
-- acorta por palabras con un «…» limpio (nunca a media letra ni a media
-- clave de color). Con un aviso debajo («Pueblo enemigo»), la meta va en un
-- renglón y el aviso en el otro. Entera sale en el cuadro al pasar el ratón.
--   Arrow.AcortarMeta(texto) -> lo que cabe     Arrow.Meta() -> mostrada, entera
---------------------------------------------------------------------------
local Meta = { entera = "", mostrada = "" } -- lo que dice la meta entera y lo que se ve
local ponerMeta, acortarMeta, acortarCon
do
local META_LINEAS = 2
local META_HOLGURA = 0.9 -- lo que de verdad se llena de un renglón al envolver por palabras
local PUNTOS = "\226\128\166" -- «…»
local medidor = frame:CreateFontString(nil, "BACKGROUND", "GameFontNormalSmall")
medidor:Hide()

local function anchoTexto(t, fuente)
	local f, s, fl = (fuente or labelText):GetFont()
	if f then pcall(medidor.SetFont, medidor, f, s, fl or "") end
	medidor:SetText(t)
	local w = medidor.GetUnboundedStringWidth and medidor:GetUnboundedStringWidth() or medidor:GetStringWidth()
	return tonumber(w) or 0
end

-- Cierra una clave de color que quedó abierta al cortar.
local function cerrarColor(t)
	local abiertas = 0
	for c in t:gmatch("|([cr])") do
		if c == "c" then abiertas = abiertas + 1 elseif abiertas > 0 then abiertas = abiertas - 1 end
	end
	return abiertas > 0 and (t .. "|r") or t
end

-- Lo más largo de `t` que mide como mucho `tope`, con «…» al final.
local function cortarA(t, tope, fuente)
	if anchoTexto(t, fuente) <= tope then return t end
	local palabras = {}
	for p in t:gmatch("%S+") do palabras[#palabras + 1] = p end
	local hecho = ""
	for i, p in ipairs(palabras) do
		local prueba = i == 1 and p or (hecho .. " " .. p)
		if anchoTexto(cerrarColor(prueba) .. PUNTOS, fuente) > tope then break end
		hecho = prueba
	end
	if hecho == "" then
		-- Una sola palabra larguísima: por letras (UTF-8 entero, sin partir una letra).
		local letras = {}
		for ch in (palabras[1] or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do letras[#letras + 1] = ch end
		for i = 1, #letras do
			local prueba = table.concat(letras, "", 1, i)
			if anchoTexto(prueba .. PUNTOS, fuente) > tope then break end
			hecho = prueba
		end
	end
	-- Sin coma ni dos puntos colgando antes del «…».
	hecho = hecho:gsub("[%s,;:%-]+$", "")
	return cerrarColor(hecho) .. PUNTOS
end

-- 1.4.0 (76): un renglón de cualquier texto de la flecha, con la letra de `fs`.
function acortarCon(fs, t, ancho)
	if type(t) ~= "string" or t == "" or (issecretvalue and issecretvalue(t)) then return t end
	return cortarA(t, ancho, fs)
end

function acortarMeta(texto)
	texto = type(texto) == "string" and texto or ""
	if texto == "" or (issecretvalue and issecretvalue(texto)) then return texto end
	local renglon = LABEL_WIDTH * META_HOLGURA
	local partes = {}
	for p in (texto .. "\n"):gmatch("(.-)\n") do partes[#partes + 1] = p end
	-- ¿Cuántos renglones pide cada parte?
	local total = 0
	for _, p in ipairs(partes) do total = total + math.max(1, math.ceil(anchoTexto(p) / renglon)) end
	if total <= META_LINEAS then return texto end
	if #partes == 1 then return cortarA(texto, renglon * META_LINEAS) end
	-- La meta en un renglón, lo demás (el aviso) en el que queda.
	local meta = cortarA(partes[1], renglon)
	local resto = table.concat(partes, " ", 2)
	return meta .. "\n" .. cortarA(resto, renglon * (META_LINEAS - 1))
end

-- Todo lo que va en el renglón de la meta pasa por aquí.
function ponerMeta(texto)
	texto = texto or ""
	if issecretvalue and issecretvalue(texto) then
		Meta.entera, Meta.mostrada = "", ""
		labelText:SetText(texto)
		return
	end
	if texto == Meta.entera and labelText:GetText() == Meta.mostrada then return end
	Meta.entera = texto
	Meta.mostrada = acortarMeta(texto)
	labelText:SetText(Meta.mostrada)
end
end

-- Up or down to the target's floor (Nav.FloorHint), left of the distance.
local floorIcon = frame:CreateTexture(nil, "OVERLAY")
floorIcon:SetSize(12, 12)
floorIcon:SetPoint("RIGHT", distText, "LEFT", -3, 0)
floorIcon:Hide()
local UI_MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\UI\\"

local Arrow = {
	AcortarMeta = acortarMeta, AcortarA = acortarCon, Meta = function() return Meta.mostrada, Meta.entera end,
	frame = frame, dial = dial, mover = mover, body = body, facet = facet, glow = glow, sheet = sheet, sheetSpec = sheetSpec,
	ring = ring, halo = halo, legIcon = legIcon, distText = distText, timerText = timerText, labelText = labelText, etaText = etaText, floorIcon = floorIcon,
	dart = dart, dartEdge = dartEdge, skinRing = skinRing, skinCheck = skinCheck, skinDisc = skinDisc,
	wolf = wolf, wolfEdge = wolfEdge, wolfPaw = wolfPaw,
	glass = glass, glassBody = glassBody, glassSand = glassSand,
}
Nav.arrow = Arrow

---------------------------------------------------------------------------
-- State (all scalars: nothing is allocated per frame)
---------------------------------------------------------------------------

local mode            -- "travel" | "arrived" | "search" | "far" | "instruction" | "nopos" | nil
local accum = 0       -- time since the last world sample
local curAngle = 0    -- displayed rotation (bearing less facing)
local goalAngle = 0   -- bearing (or, without a facing, rotation) the damping moves toward
local curBearing = 0  -- the damped bearing
local hasAngle = false
local byBearing = false -- goalAngle and curBearing are map bearings (the facing is known)

local function facing()
	local C = ns.Compat
	return C and C.GetPlayerFacing and C.GetPlayerFacing() or nil
end
local lastYards, lastEta
local floorShown -- the floor glyph's hint ("up" | "down") or nil
local lastDist, closeSpeed = nil, 0
local pulse = 0
local showEta = true
local minimo = false -- Alfa 1.3.9: nav.arrowMinimo, solo la flecha y la distancia
local routeSeen = -1  -- Travel.version the label shows; -1 = the target's own label
local loneSeen = -1   -- Travel.version a lone walk's warning was last asked for
local WARN_SECONDS = 8 -- a walk's "Hostile town" warning stays under its step this long
local warning, warnUntil -- the warning being said (Travel.TakeWarning) and until when (GetTime)
local style = "3d"    -- nav.arrowStyle
local shownFrame = -1 -- sheet frame on screen (-1 = none yet)

-- A target's own warning (Nav.SetTarget's `warning`: a dungeon whose way in
-- lies in the other faction's land) stays under the label while it is the
-- target; the walk's hostile-town warning (`warning`) comes after it.
local function withTargetWarning(text)
	local t = Nav.GetTarget()
	local tw = t and t.warning
	if not tw then return text end
	return text ~= "" and (text .. "\n" .. tw) or tw
end

-- The route's label line: the current leg's instruction, and under it the
-- walk's "Hostile town" warning while it is being said.
local function routeLabel(T)
	local text = withTargetWarning(T.CurrentLabel() or "")
	if not warning then return text end
	return text ~= "" and (text .. "\n" .. warning) or warning
end

local tintR, tintG, tintB = Nav.RGB("arrow")

-- The ETA / secondary line: text at 80%, a step behind the distance.
local function etaColor()
	local r, g, b = Nav.RGB("text")
	etaText:SetTextColor(r, g, b, 0.8)
end

local function skinStyle() return style == "halo" or style == "hearth" end

local function setRotation(a)
	if style == "lobo" then
		wolf:SetRotation(a)
		wolfEdge:SetRotation(a)
	elseif skinStyle() then
		dart:SetRotation(a)
		dartEdge:SetRotation(a)
	elseif style == "3d" then
		local f = Nav.ArrowFrame(a)
		if f ~= shownFrame then
			shownFrame = f
			local l, r, t, b = Nav.ArrowFrameCoords(f)
			sheet:SetTexCoord(l, r, t, b)
			sheetSpec:SetTexCoord(l, r, t, b)
		end
	else
		body:SetRotation(a)
		facet:SetRotation(a)
		glow:SetRotation(a)
	end
end

-- Which arrow textures are up while travelling, for the current style.
local function showArrow(on)
	local flat = on and style == "flat"
	local solid = on and style == "3d"
	local own = on and skinStyle()
	local lobo = on and style == "lobo"
	wolf:SetShown(lobo)
	wolfEdge:SetShown(lobo)
	body:SetShown(flat)
	facet:SetShown(flat)
	glow:SetShown(flat)
	sheet:SetShown(solid)
	sheetSpec:SetShown(solid)
	dart:SetShown(own)
	dartEdge:SetShown(own)
end

-- The skins' arrival: the ring, the disc under it (Halo's veil), and the
-- check once the arrival has shown (Arrow's OnUpdate: SKIN_CHECK_AFTER).
local SKIN_CHECK_AFTER = 0.6
local function showSkinArrival(on)
	local own = on and skinStyle()
	skinRing:SetShown(own)
	skinDisc:SetShown(own and style == "halo")
	skinCheck:SetShown(false)
	return own
end

---------------------------------------------------------------------------
-- Alfa 1.2.9/1.2.10: la llegada con la cara de La Jauría. Al llegar (o al
-- buscar en un área) el aro y la huella de antes se van: en su lugar sale una
-- placa de Alfa entera. A la izquierda un medallón con el lobo (atento y
-- olfateando cuando hay que buscar; aullando cuando llegaste) con su halo que
-- respira; a la derecha, en mayúsculas y en el color de llegada, «Busca por
-- aquí» o «Llegaste», lo que hay que hacer en palabras llanas (el texto de la
-- meta; el de nivel, «Sube al nivel 30: te falta 20%»), el avance como un
-- rastro de huellas («4 de 6») o una barra con su porcentaje (experiencia), y
-- en un área con varios lugares el botón «Siguiente lugar» (fuera de combate;
-- en combate no toma el ratón: el clic en la flecha sigue sirviendo). Entra
-- subiendo. La letra, el panel y los colores son los del Kit de Alfa
-- (AlfaNucleo.Kit, se lee al llegar: el núcleo carga después del motor). Sin
-- el Kit, la llegada de antes.
--
-- 1.3.1: la placa sin nada que contar no se queda. Con avance que seguir
-- (las huellas o la barra: «1 de 10», la experiencia) se queda mientras dure,
-- como antes. Sin él («Completa “Campamento básico: Peletería”», un
-- «Llegaste» suelto) entra, se queda QUEDA (1.3.9: con «Siguiente lugar» se
-- queda, y la flecha sigue tomando el clic mientras haya otro lugar)
-- segundos y se desvanece sola; solo vuelve, un rato más corto
-- (QUEDA_CAMBIO), cuando cambia lo que dice de verdad: otro paso, otro
-- destino o el estado (su firma), y si aparece un avance vuelve y se queda.
-- Un repintado igual no la trae de vuelta. Al irte (la flecha vuelve a
-- apuntar) se olvida: al llegar a otro lugar sale entera, como siempre. Ya
-- ida, la flecha tampoco toma el ratón (no queda un área invisible que atrape
-- clics). Se ancla una vez (solo se mueve mientras entra) y con
-- ui.reduceMotion ni sube, ni respira, ni olfatea: solo aparece y se va con
-- un fundido corto.
---------------------------------------------------------------------------
local llegada        -- la placa (se arma la primera vez)
local llegadaVista = false -- en modo llegada (la placa a la vista o ya ida)
local piedraVista = false  -- 1.3.3: la placa dice «usa tu piedra de hogar» (pintarPiedra)
local PLACA_ANCHO = 264   -- la placa entera
local PLACA_PAD = 10      -- su margen
local MEDALLA = 46        -- el círculo del lobo, a la izquierda
local COLUMNA = PLACA_ANCHO - PLACA_PAD * 3 - MEDALLA -- lo que queda para el texto
local HUELLAS_MAX = 8
-- 1.4.0 (79): la placa crece con lo que dice: más ancha (hasta Arrow.PL.MAX) y,
-- si aún no cabe, más líneas. Nunca «te ahorras 2 min…».
-- (todo en Arrow.PL, sin locales nuevos: el archivo ya roza el tope de 200 de Lua)
Arrow.PL = { MAX = 360, LINEAS = 3, TOPE = 6 } -- ancho tope; líneas antes de ensanchar; líneas tope

-- 1.4.0 (78/79): las placas (llegada, piedra de hogar, viaje) tienen su
-- propia ancla, AlfaNavPlacas. De fábrica va arriba del disco (la placa
-- ocupa el lugar de la flecha, como siempre); si la mueves («Acomodar la
-- pantalla» o Mayús+arrastre), nav.placasPos la deja aparte de la flecha.
-- «Volver a su lugar» la junta otra vez con ella.
Arrow.PL.ancla = CreateFrame("Frame", "AlfaNavPlacas", UIParent)
Arrow.PL.ancla:SetSize(PLACA_ANCHO, 72)
Arrow.PL.ancla:SetFrameStrata("MEDIUM")
Arrow.PL.ancla:SetClampedToScreen(true)
Arrow.PL.ancla:EnableMouse(false)
function Arrow.PL.aparte()
	local p = ns.Get("nav.placasPos")
	return type(p) == "table" and type(p.point) == "string"
end
function Arrow.PL.poner()
	Arrow.PL.ancla:ClearAllPoints()
	local p = ns.Get("nav.placasPos")
	if type(p) == "table" and type(p.point) == "string" then
		Arrow.PL.ancla:SetPoint(p.point, UIParent, p.relPoint or p.point, tonumber(p.x) or 0, tonumber(p.y) or 0)
	else
		Arrow.PL.ancla:SetPoint("TOP", dial, "TOP", 0, 0)
	end
	-- La que está a la vista, a su lugar nuevo (solo se ancla al entrar).
	for _, nombre in ipairs({ "AlfaNavLlegada", "AlfaNavViaje" }) do
		local f = rawget(_G, nombre)
		if type(f) == "table" and f.IsShown and f:IsShown() then
			f:ClearAllPoints()
			Arrow.PL.anclar(f, nombre == "AlfaNavViaje" and f.alfaAbajo or false, 0)
		end
	end
end
-- La placa a la vista se ancla a ella; con la flecha, la tarjeta del camino
-- (abajo) va debajo del disco.
function Arrow.PL.anclar(f, abajo, dy)
	dy = dy or 0
	if Arrow.PL.aparte() then
		f:SetPoint("TOP", Arrow.PL.ancla, "TOP", 0, dy)
	elseif abajo then
		f:SetPoint("TOP", dial, "BOTTOM", 0, -6 + dy)
	else
		f:SetPoint("TOP", dial, "TOP", 0, dy)
	end
end
Arrow.PL.poner()
-- La placa a la vista (llegada, piedra o viaje), o nil.
function Arrow.PL.vista()
	for _, nombre in ipairs({ "AlfaNavLlegada", "AlfaNavViaje" }) do
		local f = rawget(_G, nombre)
		if type(f) == "table" and f.IsVisible and f:IsVisible() and not f.alfaOculta and not f.alfaCerrada then return f end
	end
	return nil
end
Arrow.PlacaVista = Arrow.PL.vista
-- Las deja aparte justo donde están ahora (al empezar a moverlas solas).
function Arrow.SepararPlacas()
	if Arrow.PL.aparte() then return true end
	local src = Arrow.PL.vista() or Arrow.PL.ancla
	local l, t = src:GetLeft(), src:GetTop()
	if type(l) ~= "number" or type(t) ~= "number" then return false end
	local us = UIParent:GetEffectiveScale()
	local k = (src:GetEffectiveScale() or 1) / ((us and us > 0) and us or 1)
	local ul, ub = UIParent:GetLeft() or 0, UIParent:GetBottom() or 0
	-- (en la escala de la flecha, la misma del ancla)
	ns.Set("nav.placasPos", { point = "TOPLEFT", relPoint = "BOTTOMLEFT", x = math.floor(l - ul / k + 0.5), y = math.floor(t - ub / k + 0.5) })
	return true
end
-- El ancla mide lo que la placa (para el recuadro de «Acomodar la pantalla»).
function Arrow.PL.medir(f)
	local w, h = f:GetWidth(), f:GetHeight()
	if type(w) == "number" and type(h) == "number" and w > 0 and h > 0 then Arrow.PL.ancla:SetSize(w, h) end
end
Arrow.placas, Arrow.PonerPlacas, Arrow.PlacasAparte = Arrow.PL.ancla, Arrow.PL.poner, Arrow.PL.aparte
-- 1.4.0: qué tramo es (el mismo viaje aunque Travel rehaga el plan).
function Arrow.PL.claveTramo(leg)
	if type(leg) ~= "table" then return nil end
	local de, a = type(leg.from) == "table" and leg.from or {}, type(leg.to) == "table" and leg.to or {}
	return table.concat({ tostring(leg.kind), tostring(de.name or de.c), tostring(a.name or a.c),
		tostring(leg.transport and leg.transport.id or "") }, "|")
end

local ENTRA_PLACA = 0.3   -- segundos que tarda en entrar subiendo
local QUEDA = 6           -- segundos a la vista al llegar
local QUEDA_CAMBIO = 3.5  -- segundos a la vista cuando vuelve por un cambio
local SALE = 0.6          -- segundos del fundido al irse
local QUIETA_ENTRA, QUIETA_SALE = 0.15, 0.2 -- con ui.reduceMotion: fundidos cortos
local LOBO_TAM = MEDALLA * 0.62
Arrow.PLACA = { QUEDA = QUEDA, QUEDA_CAMBIO = QUEDA_CAMBIO, SALE = SALE, ENTRA = ENTRA_PLACA } -- (para el banco)
-- Alfa 1.3.7c: el estimado sin moverte (yardas por segundo corriendo y en
-- una montura de nivel 40, y desde cuántas yardas se dice).
Arrow.PASO_A_PIE, Arrow.PASO_MONTADO, Arrow.ESTIMA_DESDE = 7, 11.2, 40

local function kit()
	local N = rawget(_G, "AlfaNucleo")
	local K = type(N) == "table" and N.Kit or nil
	return type(K) == "table" and type(K.Cara) == "function" and type(K.Tamano) == "function" and K or nil
end

-- 1.3.1: PLAYER_REGEN_DISABLED llega antes del bloqueo de combate (ahí
-- InCombatLockdown todavía es false): sin esta bandera, «Siguiente lugar»
-- seguía tomando el ratón al empezar la pelea. Entre REGEN_DISABLED y
-- REGEN_ENABLED cuenta como combate.
local pelea = false
local function enCombate() return pelea or (InCombatLockdown and InCombatLockdown()) or false end

-- 1.3.9: el clic en la flecha lleva a «otro lugar». Primero el del motor (un
-- área con varios lugares, Nav.NextSpot); si no, quien guía la flecha con una
-- ruta propia (Recolección, buscar un material...) se apunta en
-- Nav.OtroLugar = { disponible = fn() -> bool, ir = fn() -> bool }.
local function hayOtroLugar()
	local t = Nav.GetTarget and Nav.GetTarget()
	if t and t.spots then return true end
	local o = Nav.OtroLugar
	if type(o) == "table" and type(o.disponible) == "function" then
		local ok, si = pcall(o.disponible)
		return ok and si and true or false
	end
	return false
end

local function irOtroLugar()
	if Nav.NextSpot and Nav.NextSpot() then return true end
	local o = Nav.OtroLugar
	if type(o) == "table" and type(o.ir) == "function" then
		local ok, si = pcall(o.ir)
		return ok and si and true or false
	end
	return false
end
Arrow.OtroLugar, Arrow.HayOtroLugar = irOtroLugar, hayOtroLugar

-- La letra de Alfa para un rol del Kit, con la sombra del tema (la placa ya
-- da el fondo: sin contorno grueso).
local function letra(K, fs, rol)
	local spec = K.TIPO and K.TIPO[rol] or { "medium", 12 }
	local ok = pcall(fs.SetFont, fs, K.Cara(spec[1]), K.Tamano(rol), "")
	if not ok then fs:SetFont(STANDARD_TEXT_FONT, K.Tamano(rol), "") end
	local r, g, b = Nav.RGB("shade")
	fs:SetShadowColor(r, g, b, 0.9)
	fs:SetShadowOffset(1, -1)
	fs.alfaRol = rol
end

-- 1.3.1: se fue sola. Oculta (su OnUpdate ya no corre) y la flecha sin
-- ratón mientras siga la llegada: nada invisible atrapa clics.
local function desvanecida(self)
	self.alfaOculta = true
	self:Hide()
	-- 1.3.9: si hay otro lugar a dónde ir, la flecha sigue tomando el clic,
	-- pero nunca en combate: ahí no se ve nada y no debe atrapar el ratón.
	frame:EnableMouse(hayOtroLugar() and not enCombate())
end

-- La placa anima sola mientras se ve: entra subiendo, el halo respira y el
-- lobo olfatea (busca) o levanta el hocico (llegaste); al cumplir su rato se
-- desvanece. Nada se crea aquí, y solo se ancla mientras entra (1.3.1).
local function animarPlaca(self, dt)
	if self.alfaOculta then return end
	dt = tonumber(dt) or 0
	local quieta = self.alfaQuieta
	local t = (self.alfaT or 0) + dt
	self.alfaT = t
	local entra = quieta and QUIETA_ENTRA or ENTRA_PLACA
	local e = t < entra and t / entra or 1
	e = e * e * (3 - 2 * e)
	-- Su rato a la vista y después el fundido.
	local queda = (self.alfaQueda or QUEDA) - dt
	self.alfaQueda = queda
	local sale = 1
	if queda < 0 then
		sale = 1 + queda / (quieta and QUIETA_SALE or SALE)
		if sale <= 0 then desvanecida(self) return end
	end
	self:SetAlpha(e * sale * (self.alfaVisible or 1))
	if not self.alfaAnclada then
		self:ClearAllPoints()
		if quieta or e >= 1 then
			Arrow.PL.anclar(self, false, 0)
			self.alfaAnclada = true
		else
			Arrow.PL.anclar(self, false, -(1 - e) * 10)
		end
	end
	if quieta then return end
	self.Halo:SetAlpha(0.3 + 0.2 * (0.5 + 0.5 * sin(t * 2.4)))
	if self.Lobo.SetRotation then
		if self.alfaBusca then
			self.Lobo:SetRotation(0.12 * sin(t * 3.1))
		else
			self.Lobo:SetRotation(0)
		end
	end
	local s = 1 + 0.04 * (0.5 + 0.5 * sin(t * (self.alfaBusca and 3.1 or 1.8)))
	self.Lobo:SetSize(LOBO_TAM * s, LOBO_TAM * s)
end

local function armarLlegada(K)
	if llegada then return llegada end
	local f = CreateFrame("Frame", "AlfaNavLlegada", frame)
	f:SetSize(PLACA_ANCHO, 72)
	Arrow.PL.anclar(f, false, 0)
	f:EnableMouse(false)
	f:Hide()
	-- La placa: el panel de Alfa con su corte, la franja de color a la
	-- izquierda y la marca arriba, como una tarjeta de acción del Kit.
	f.caja = K.Caja(f, { corte = K.CORTE.tarjeta, rol = "panel", alfaFondo = 0.9 })
	f.Franja = f:CreateTexture(nil, "ARTWORK", nil, 1)
	f.Franja:SetColorTexture(1, 1, 1, 1)
	f.Franja:SetWidth(3)
	f.Franja:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -K.CORTE.tarjeta - 4)
	f.Franja:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, K.CORTE.tarjeta + 4)
	-- El medallón: un círculo oscuro con su aro, el halo y el lobo.
	f.Medalla = CreateFrame("Frame", nil, f)
	f.Medalla:SetSize(MEDALLA, MEDALLA)
	f.Medalla:SetPoint("TOPLEFT", f, "TOPLEFT", PLACA_PAD + 2, -PLACA_PAD)
	f.Halo = f.Medalla:CreateTexture(nil, "BACKGROUND", nil, 1)
	f.Halo:SetTexture(MEDIA .. "glow")
	f.Halo:SetBlendMode("ADD")
	f.Halo:SetSize(MEDALLA * 1.7, MEDALLA * 1.7)
	f.Halo:SetPoint("CENTER")
	f.Fondo = f.Medalla:CreateTexture(nil, "BACKGROUND", nil, 2)
	f.Fondo:SetTexture(UI_DIR .. "circle")
	f.Fondo:SetAllPoints()
	f.Aro = f.Medalla:CreateTexture(nil, "ARTWORK")
	f.Aro:SetTexture(MEDIA .. "ring")
	f.Aro:SetAllPoints()
	f.Lobo = f.Medalla:CreateTexture(nil, "ARTWORK", nil, 2)
	f.Lobo:SetPoint("CENTER", f.Medalla, "CENTER", 0, 0)
	f.Lobo:SetSize(MEDALLA * 0.62, MEDALLA * 0.62)
	-- La columna de texto.
	local x = PLACA_PAD * 2 + 2 + MEDALLA
	f.Sobre = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	f.Sobre:SetPoint("TOPLEFT", f, "TOPLEFT", x, -PLACA_PAD - 1)
	f.Sobre:SetWidth(COLUMNA)
	f.Sobre:SetJustifyH("LEFT")
	f.Accion = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	f.Accion:SetWidth(COLUMNA)
	f.Accion:SetJustifyH("LEFT")
	f.Accion:SetWordWrap(true)
	f.Accion:SetMaxLines(3)
	f.Avance = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	f.Avance:SetJustifyH("RIGHT")
	-- 1.3.3: las líneas chicas de «usa tu piedra» (después, la piedra, cuánto falta).
	f.Nota = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	f.Nota:SetWidth(COLUMNA)
	f.Nota:SetJustifyH("LEFT")
	f.Nota:SetWordWrap(true)
	f.Nota:Hide()
	-- El avance: un rastro de huellas (hasta 8 lugares) o, para la
	-- experiencia y lo largo, una barra con su porcentaje.
	if K.Huellas then f.Huellas = K.Huellas(f, { tam = 13, max = HUELLAS_MAX, gap = 3 }) f.Huellas:Hide() end
	f.Pista = f:CreateTexture(nil, "ARTWORK")
	f.Pista:SetHeight(5)
	f.Relleno = f:CreateTexture(nil, "ARTWORK", nil, 1)
	f.Relleno:SetPoint("TOPLEFT", f.Pista, "TOPLEFT", 0, 0)
	f.Relleno:SetPoint("BOTTOMLEFT", f.Pista, "BOTTOMLEFT", 0, 0)
	if K.Boton then
		f.Siguiente = K.Boton(f, ns.T("Siguiente lugar"), function()
			if not enCombate() then irOtroLugar() end
		end, { tam = "chico", icono = "ic-huella" })
		f.Siguiente:Hide()
	end
	f:SetScript("OnUpdate", animarPlaca)
	llegada = f
	Arrow.llegada = f
	return f
end

-- Lo que dice la meta a la que llegaste: { accion, cur, max, avance, xp } o nil.
local function metaDeLlegada(target)
	local E = ns.Engine
	if not (target and E and E.GetStepView and target.stepIndex and target.goalIndex) then return nil end
	local ok, v = pcall(E.GetStepView, target.stepIndex)
	local gv = ok and type(v) == "table" and type(v.goals) == "table" and v.goals[target.goalIndex] or nil
	if type(gv) ~= "table" then return nil end
	local d = {}
	if gv.t == "level" then
		local p = ns.Levels and ns.Levels.Player and ns.Levels.Player() or {}
		local xpMax = tonumber(p.xpMax) or 0
		local falta = tonumber(gv.xpLeft)
		local goal = E.GetGuide and E.GetGuide()
		local step = goal and goal.steps and goal.steps[target.stepIndex]
		local g = step and step.goals and step.goals[target.goalIndex]
		local lvl = g and tonumber(g.level)
		if lvl and falta and xpMax > 0 then
			if falta <= xpMax then
				d.accion = ns.T("Sube al nivel %d: te falta %d%%"):format(lvl, math.max(1, math.ceil(falta / xpMax * 100)))
				d.cur, d.max, d.xp = xpMax - falta, xpMax, true
			else
				d.accion = ns.T("Sube al nivel %d: te faltan %s de experiencia"):format(lvl, BreakUpLargeNumbers and BreakUpLargeNumbers(falta) or tostring(falta))
			end
		elseif lvl then
			d.accion = ns.T("Sube al nivel %d"):format(lvl)
		end
		return d
	end
	local pr = gv.progress
	if type(pr) == "table" and tonumber(pr.cur) and tonumber(pr.max) and pr.max > 1 then
		d.cur, d.max = pr.cur, pr.max
		d.avance = ns.T("%d de %d"):format(pr.cur, pr.max)
	end
	return d
end

local function altoTexto(K, fs, base)
	return K.num and K.num(fs:GetStringHeight(), base) or base
end

-- 1.4.0 (79): el ancho de una sola línea de un texto (sin cortar).
function Arrow.PL.anchoSuelto(fs)
	local fn = fs.GetUnboundedStringWidth or fs.GetStringWidth
	local ok, w = pcall(fn, fs)
	w = ok and tonumber(w) or 0
	if issecretvalue and issecretvalue(w) then return 0 end
	return w
end

-- La placa a la medida de su acción: hasta Arrow.PL.LINEAS líneas en el
-- ancho de siempre; si no caben, más ancha (hasta Arrow.PL.MAX); y si ni así,
-- las líneas que hagan falta (hasta Arrow.PL.TOPE). -> la columna del texto
function Arrow.PL.ajustarAncho(f, largo)
	local extra = PLACA_ANCHO - COLUMNA
	local col = COLUMNA
	if largo > COLUMNA * Arrow.PL.LINEAS then
		col = math.min(Arrow.PL.MAX - extra, math.ceil(largo / Arrow.PL.LINEAS * 1.1))
	end
	f:SetWidth(col + extra)
	for _, fs in ipairs({ f.Sobre, f.Accion, f.Nota }) do if fs then fs:SetWidth(col) end end
	f.Accion:SetMaxLines(Arrow.PL.TOPE)
	f.alfaColumna = col
	return col
end
Arrow.PLACA.MAX, Arrow.PLACA.LINEAS = Arrow.PL.MAX, Arrow.PL.TOPE -- (para el banco)

-- Esconde lo de la llegada de antes (el aro, la huella, el halo, la palomita
-- de las otras apariencias): la placa ocupa su lugar.
local function sinLlegadaVieja()
	ring:Hide()
	halo:Hide()
	wolfPaw:Hide()
	skinRing:Hide()
	skinDisc:Hide()
	skinCheck:Hide()
end

-- 1.3.1: lo que dice la placa, en una línea: si cambia, la placa vuelve.
local function firmaDe(m, accion, texto, d, t, otro)
	t = type(t) == "table" and t or {}
	return table.concat({ m, accion, texto or "", tostring(d.cur or ""), tostring(d.max or ""),
		tostring(t.map or ""), tostring(t.x or ""), tostring(t.y or ""), tostring(t.stepIndex or ""),
		tostring(t.goalIndex or ""), otro and "1" or "0" }, "|")
end

local function pintarLlegada(m)
	local K = kit()
	if not K then return false end
	local f = armarLlegada(K)
	local target = Nav.GetTarget()
	local d = metaDeLlegada(target) or {}
	local accion = d.accion or (target and target.label) or ""
	if issecretvalue and issecretvalue(accion) then accion = "" end
	local hay = d.max and d.max > 0
	local frac = hay and math.max(0, math.min(1, (d.cur or 0) / d.max)) or 0
	local texto = d.avance or (d.xp and ("%d%%"):format(math.floor(frac * 100)) or nil)
	-- 1.3.9: «otro lugar» del motor (un área con varios lugares) o de quien
	-- guía la flecha con su ruta (Nav.OtroLugar: Recolección...).
	local otro = hayOtroLugar()
	local firma = firmaDe(m, accion, texto, d, target, otro)
	local cambio = firma ~= f.alfaFirma
	if not cambio and f.alfaOculta then
		-- Ya se fue y nada cambió: sigue ida, y lo de la llegada de antes también.
		-- Sin la placa, la flecha no se ve: en combate no toma el ratón (1.3.9).
		frame:EnableMouse(otro and not enCombate())
		sinLlegadaVieja()
		distText:Hide()
		labelText:Hide()
		etaText:Hide()
		llegadaVista = true
		return true
	end
	f.alfaModo = m
	f.alfaBusca = m == "search"
	if f.Nota then f.Nota:Hide() end
	local nr, ng, nb = Nav.RGB("arrowNear")
	local tr, tg, tb = Nav.RGB("arrowNearText")
	-- Los colores: la llegada del jugador (verde de fábrica) en la franja, el
	-- lobo, su aro y su halo; el fondo del medallón, el panel hundido.
	f.Franja:SetVertexColor(nr, ng, nb, 1)
	f.Aro:SetVertexColor(nr, ng, nb, 0.9)
	f.Halo:SetVertexColor(nr, ng, nb, 1)
	f.Lobo:SetVertexColor(nr, ng, nb, 1)
	f.Fondo:SetVertexColor(K.ConAlfa("hundido", 0.95))
	f.Lobo:SetTexture(K.Lobo(f.alfaBusca and "atento" or "aullando"))
	letra(K, f.Sobre, "mayus")
	f.Sobre:SetTextColor(tr, tg, tb, 1)
	f.Sobre:SetText(K.Mayus(m == "search" and ns.T("Busca por aquí") or ns.T("Llegaste")))
	letra(K, f.Accion, "cuerpo")
	f.Accion:SetTextColor(K.Color("texto"))
	f.Accion:SetText(accion)
	local columna = Arrow.PL.ajustarAncho(f, Arrow.PL.anchoSuelto(f.Accion))
	local x = PLACA_PAD * 2 + 2 + MEDALLA
	local y = PLACA_PAD + 1 + altoTexto(K, f.Sobre, 10)
	f.Accion:ClearAllPoints()
	f.Accion:SetPoint("TOPLEFT", f, "TOPLEFT", x, -(y + 3))
	f.Accion:SetShown(accion ~= "")
	if accion ~= "" then y = y + 3 + altoTexto(K, f.Accion, 14) end
	-- El avance: huellas para «4 de 6», barra con su porcentaje para la
	-- experiencia o para muchos lugares.
	f.Avance:ClearAllPoints()
	f.Pista:ClearAllPoints()
	local conHuellas = hay and f.Huellas and not d.xp and d.max <= HUELLAS_MAX
	letra(K, f.Avance, "pequeno")
	f.Avance:SetTextColor(K.Color("textoSuave"))
	f.Avance:SetText(texto or "")
	f.Avance:SetShown(texto ~= nil)
	local anchoAvance = texto and math.ceil(f.Avance:GetStringWidth() or 0) + 6 or 0
	if conHuellas then
		f.Huellas:Set(d.cur or 0, d.max)
		f.Huellas:ClearAllPoints()
		f.Huellas:SetPoint("TOPLEFT", f, "TOPLEFT", x, -(y + 6))
		f.Huellas:Show()
		f.Pista:Hide()
		f.Relleno:Hide()
		local alto = K.num and K.num(f.Huellas:GetHeight(), 18) or 18
		f.Avance:SetPoint("RIGHT", f, "TOPRIGHT", -PLACA_PAD - 2, -(y + 6 + alto / 2))
		y = y + 6 + alto
	elseif hay then
		if f.Huellas then f.Huellas:Hide() end
		local ancho = columna - anchoAvance
		f.Pista:SetPoint("TOPLEFT", f, "TOPLEFT", x, -(y + 8))
		f.Pista:SetWidth(ancho)
		f.Pista:SetColorTexture(K.ConAlfa("hundido", 0.95))
		f.Relleno:SetColorTexture(nr, ng, nb, 1)
		f.Relleno:SetWidth(math.max(1, ancho * frac))
		f.Relleno:SetShown(frac > 0)
		f.Pista:Show()
		f.Avance:SetPoint("RIGHT", f, "TOPRIGHT", -PLACA_PAD - 2, -(y + 10))
		y = y + 13
	else
		if f.Huellas then f.Huellas:Hide() end
		f.Pista:Hide()
		f.Relleno:Hide()
		f.Avance:Hide()
	end
	-- «Siguiente lugar»: un área con varios lugares (el clic en la flecha
	-- también lo hace). En combate se ve pero no toma el ratón.
	local b = f.Siguiente
	if b then
		if otro then
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", f, "TOPLEFT", x, -(y + 8))
			local peleando = enCombate()
			b:EnableMouse(not peleando)
			b:SetAlpha(peleando and 0.5 or 1)
			b:Show()
			y = y + 8 + (K.ALTO and K.ALTO.botonChico or 24)
		else
			b:Hide()
		end
	end
	y = math.max(y, PLACA_PAD + MEDALLA) + PLACA_PAD
	f:SetHeight(y)
	-- 1.3.1: su rato a la vista. Con algo que contar (huellas o barra) se
	-- queda mientras dure. Sin avance que seguir: al llegar, QUEDA; si vuelve
	-- por un cambio, QUEDA_CAMBIO. Si ya se había ido, entra otra vez. Un
	-- repintado igual no le cambia el rato.
	f.alfaQuieta = ns.Get("ui.reduceMotion") and true or false
	f.alfaCuenta = hay and true or false
	if cambio then
		-- 1.3.9: con «Siguiente lugar» (otro) también se queda: su botón sigue a la mano.
		local queda = (hay or otro) and math.huge or (f.alfaFirma == nil and QUEDA or QUEDA_CAMBIO)
		f.alfaFirma = firma
		if f.alfaOculta or not f:IsShown() then
			f.alfaT, f.alfaAnclada = 0, false
			f.alfaQueda = queda
		elseif hay or otro or f.alfaQueda == math.huge or (f.alfaQueda or 0) < queda then
			-- (de contar a no contar: ahora sí corre su rato)
			f.alfaQueda = queda
		end
		f.alfaOculta = false
	end
	if f.alfaQuieta then
		-- Sin movimiento: el halo y el lobo quietos (animarPlaca no los toca).
		f.Halo:SetAlpha(0.4)
		if f.Lobo.SetRotation then f.Lobo:SetRotation(0) end
		f.Lobo:SetSize(LOBO_TAM, LOBO_TAM)
	end
	-- 1.4.0 (78): con las placas aparte, el lugar vacío de la flecha no toma el ratón.
	frame:EnableMouse(not Arrow.PL.aparte())
	f:Show()
	Arrow.PL.medir(f)
	sinLlegadaVieja()
	-- La placa es más ancha que la flecha: que no se salga de la pantalla.
	local sobra = Arrow.PL.aparte() and 0 or math.max(0, ((f:GetWidth() or PLACA_ANCHO) - WIDTH) / 2)
	if frame.SetClampRectInsets then frame:SetClampRectInsets(-sobra, sobra, 0, 0) end
	distText:Hide()
	labelText:Hide()
	etaText:Hide()
	timerText:ClearAllPoints()
	timerText:SetPoint("TOP", f, "BOTTOM", 0, -4)
	llegadaVista = true
	return true
end

local function quitarLlegada()
	if llegada then
		llegada:Hide()
		-- 1.3.1: te fuiste: la próxima llegada sale entera.
		llegada.alfaFirma, llegada.alfaOculta = nil, false
		if llegada.Nota then llegada.Nota:Hide() end
	end
	piedraVista = false
	frame:EnableMouse(true)
	if frame.SetClampRectInsets then frame:SetClampRectInsets(0, 0, 0, 0) end
	if not llegadaVista then return end
	llegadaVista = false
	distText:Show()
	labelText:Show()
	timerText:ClearAllPoints()
	timerText:SetPoint("TOP", distText, "BOTTOM", 0, -4)
end

---------------------------------------------------------------------------
-- 1.3.3: «Usa tu piedra de hogar». Cuando la ruta del motor va por un tramo
-- `hearth` (Nav/Travel.lua), en lugar de «Piedra de hogar a X: ahorra 9 min»
-- y «2:16 en total», la placa de la llegada lo dice claro: a dónde vuelves,
-- cuántas misiones entregas ahí (AlfaRuta.EntregasPiedra, Hogar.lua), cuánto
-- te ahorras (leg.saved y leg.place, parches de Nav/Travel.lua), lo que sigue
-- después, si tu piedra está lista y en cuánto llegas. El botón seguro es el
-- del motor (AlfaHearthButton: Buttons.WantsHearth también dice sí con este
-- tramo, parche de QoL/Buttons.lua). Se queda mientras dure el tramo: se va
-- al usar la piedra (la ruta pasa al tramo siguiente).
---------------------------------------------------------------------------
local PIEDRA = 6948

local function estadoPiedra()
	local C = C_Item
	if C and type(C.GetItemCount) == "function" then
		local ok, cuenta = pcall(C.GetItemCount, PIEDRA)
		if ok and type(cuenta) == "number" and cuenta < 1 then return ns.T("No traes tu piedra de hogar.") end
	end
	local fn = (C_Container and C_Container.GetItemCooldown) or (C and C.GetItemCooldown)
	if type(fn) == "function" then
		local ok, inicio, dura = pcall(fn, PIEDRA)
		if ok and not (issecretvalue and (issecretvalue(inicio) or issecretvalue(dura))) then
			inicio, dura = tonumber(inicio) or 0, tonumber(dura) or 0
			local falta = inicio > 0 and dura > 1.5 and (inicio + dura - GetTime()) or 0
			if falta > 0 then return ns.T("Tu piedra está lista en %d min."):format(math.max(1, math.ceil(falta / 60))) end
		end
	end
	return ns.T("Tu piedra está lista.")
end

local function textoPiedra(leg)
	local lugar = leg.place
	if type(lugar) ~= "string" or lugar == "" or (issecretvalue and issecretvalue(lugar)) then lugar = nil end
	local min = tonumber(leg.saved) and math.floor(leg.saved / 60) or nil
	if min and min < 1 then min = nil end
	local R = rawget(_G, "AlfaRuta")
	local n = 0
	if type(R) == "table" and type(R.EntregasPiedra) == "function" then
		local ok, k = pcall(R.EntregasPiedra)
		n = ok and tonumber(k) or 0
	end
	if not lugar then return ns.T("Usa tu piedra de hogar: te lleva a tu posada.") end
	if n > 0 and min then
		if n == 1 then return ns.T("Vuelves a %s: entregas 1 misión y te ahorras %d min caminando."):format(lugar, min) end
		return ns.T("Vuelves a %s: entregas %d misiones y te ahorras %d min caminando."):format(lugar, n, min)
	end
	if min then return ns.T("Vuelves a %s y te ahorras %d min caminando."):format(lugar, min) end
	return ns.T("Vuelves a %s."):format(lugar)
end

local function pintarPiedra(leg)
	local K = kit()
	if not (K and leg) then return false end
	local f = armarLlegada(K)
	local target = Nav.GetTarget()
	local accion = textoPiedra(leg)
	local lineas = {}
	local meta = target and target.label
	if type(meta) == "string" and meta ~= "" and not (issecretvalue and issecretvalue(meta)) then
		lineas[#lineas + 1] = ns.T("Después: %s"):format(meta)
	end
	lineas[#lineas + 1] = estadoPiedra()
	local T = Nav.travel
	local okR, secs = false, nil
	if T and T.Remaining then okR, secs = pcall(T.Remaining, nil) end
	if okR and tonumber(secs) then lineas[#lineas + 1] = ns.T("Llegas en unos %d min"):format(math.max(1, math.ceil(secs / 60))) end
	local nota = table.concat(lineas, "\n")
	local firma = "piedra|" .. accion .. "|" .. nota
	local cambio = firma ~= f.alfaFirma
	f.alfaModo, f.alfaBusca = "piedra", false
	local nr, ng, nb = Nav.RGB("arrowNear")
	local tr, tg, tb = Nav.RGB("arrowNearText")
	f.Franja:SetVertexColor(nr, ng, nb, 1)
	f.Aro:SetVertexColor(nr, ng, nb, 0.9)
	f.Halo:SetVertexColor(nr, ng, nb, 1)
	f.Lobo:SetVertexColor(nr, ng, nb, 1)
	f.Fondo:SetVertexColor(K.ConAlfa("hundido", 0.95))
	f.Lobo:SetTexture(K.Lobo("atento"))
	letra(K, f.Sobre, "mayus")
	f.Sobre:SetTextColor(tr, tg, tb, 1)
	f.Sobre:SetText(K.Mayus(ns.T("Usa tu piedra de hogar")))
	letra(K, f.Accion, "cuerpo")
	f.Accion:SetTextColor(K.Color("texto"))
	f.Accion:SetText(accion)
	Arrow.PL.ajustarAncho(f, Arrow.PL.anchoSuelto(f.Accion))
	local x = PLACA_PAD * 2 + 2 + MEDALLA
	local y = PLACA_PAD + 1 + altoTexto(K, f.Sobre, 10)
	f.Accion:ClearAllPoints()
	f.Accion:SetPoint("TOPLEFT", f, "TOPLEFT", x, -(y + 3))
	f.Accion:Show()
	y = y + 3 + altoTexto(K, f.Accion, 14)
	letra(K, f.Nota, "pequeno")
	f.Nota:SetTextColor(K.Color("textoSuave"))
	f.Nota:SetText(nota)
	f.Nota:ClearAllPoints()
	f.Nota:SetPoint("TOPLEFT", f, "TOPLEFT", x, -(y + 4))
	f.Nota:Show()
	y = y + 4 + altoTexto(K, f.Nota, 12)
	f.Avance:Hide()
	if f.Huellas then f.Huellas:Hide() end
	f.Pista:Hide()
	f.Relleno:Hide()
	if f.Siguiente then f.Siguiente:Hide() end
	y = math.max(y, PLACA_PAD + MEDALLA) + PLACA_PAD
	f:SetHeight(y)
	f.alfaQuieta = ns.Get("ui.reduceMotion") and true or false
	f.alfaCuenta = true
	if cambio then
		f.alfaFirma = firma
		if f.alfaOculta or not f:IsShown() then f.alfaT, f.alfaAnclada = 0, false end
		f.alfaQueda = math.huge -- se queda mientras dure el tramo
		f.alfaOculta = false
	end
	if f.alfaQuieta then
		f.Halo:SetAlpha(0.4)
		if f.Lobo.SetRotation then f.Lobo:SetRotation(0) end
		f.Lobo:SetSize(LOBO_TAM, LOBO_TAM)
	end
	-- 1.4.0 (78): con las placas aparte, el lugar vacío de la flecha no toma el ratón.
	frame:EnableMouse(not Arrow.PL.aparte())
	f:Show()
	Arrow.PL.medir(f)
	sinLlegadaVieja()
	legIcon:Hide()
	local sobra = Arrow.PL.aparte() and 0 or math.max(0, ((f:GetWidth() or PLACA_ANCHO) - WIDTH) / 2)
	if frame.SetClampRectInsets then frame:SetClampRectInsets(-sobra, sobra, 0, 0) end
	distText:Hide()
	labelText:Hide()
	etaText:Hide()
	timerText:ClearAllPoints()
	timerText:SetPoint("TOP", f, "BOTTOM", 0, -4)
	llegadaVista, piedraVista = true, true
	return true
end
Arrow.PintarPiedra = pintarPiedra

---------------------------------------------------------------------------
-- Alfa 1.3.8: el mensaje de un viaje, a la manera de Alfa (pedido de Toxic).
-- Antes, sobre el muelle: «Toma el barco a Isla Theramore / Barco: espera
-- promedio 2:55 / Ve a 23.8, 77.3 / 18 min 55 s en total» (el texto del
-- motor heredado). Ahora, tres líneas claras y sin coordenadas sueltas:
--   «Toma el barco a Isla Theramore · sale en ~3 min»   (sin horario medido)
--   «Toma el barco a Isla Theramore · sale en 1:20»     (cuenta real, al segundo)
--   «¡Ya está en el muelle! Sale en 0:40»               (atracado)
--   debajo, el siguiente: «Si lo pierdes, el siguiente sale en 14 min», o
--   «Hora aproximada: aún nadie lo ha medido»; y al final «Llegas en 19 min».
-- Lo mismo para el zepelín, el tranvía, un portal y un vuelo. Los horarios
-- son los del motor (Nav/Transit.lua: lo mismo que ven el aviso de barcos,
-- Nav/Alerts.lua, y los muelles del mapa, Alfa_Rutas/Barcos.lua).
--   Arrow.TextoViaje(leg) -> linea, debajo, llegas | nil
--   Arrow.Viaje() -> { linea, debajo, llegas, kind } | nil   (lo que se ve)
---------------------------------------------------------------------------
local VIAJE = {
	boat = { toma = "Toma el barco a %s", abordo = "En el barco a %s", aqui = "¡El barco ya está en el muelle! Sale en %s" },
	zeppelin = { toma = "Toma el zepelín a %s", abordo = "En el zepelín a %s", aqui = "¡El zepelín ya está en la torre! Sale en %s" },
	tram = { toma = "Toma el tranvía a %s", abordo = "En el tranvía a %s", aqui = "¡El tranvía ya está en el andén! Sale en %s" },
	portal = { toma = "Cruza el portal a %s" },
	fly = { toma = "Vuela a %s", debajo = "Habla con el maestro de vuelo" },
}
Arrow.VIAJE = VIAJE
local VIAJE_ALTO = 16 -- la tercera línea («Llegas en…») cabe dentro del marco
local viajeVisto, viajeCuando -- { linea, debajo, llegas, kind } mientras se ve; GetTime() de la última vez

local function mmss(secs)
	secs = math.max(0, math.ceil(secs or 0))
	return ("%d:%02d"):format(floor(secs / 60), secs % 60)
end
-- «1:20» en el último par de minutos (se cuenta al segundo), «~3 min» antes.
local function cuantoFalta(secs, medido)
	if medido and secs <= 120 then return mmss(secs) end
	local m = math.max(1, floor(secs / 60 + 0.5))
	return (medido and "%d min" or "~%d min"):format(m)
end

local function duracionRedonda(secs)
	local Nu = rawget(_G, "AlfaNucleo")
	if type(Nu) == "table" and type(Nu.Duracion) == "function" then return Nu.Duracion(secs, secs >= 120) end
	return mmss(secs)
end

local function destino(leg)
	local T = Nav.travel
	local p = leg.to
	local n = p and ((T and T.PlaceName and T.PlaceName(p)) or p.name)
	if type(n) ~= "string" or n == "" then return nil end
	return n:match("^([^,]+)") or n
end

function Arrow.TextoViaje(leg, secsTotal)
	local v = type(leg) == "table" and VIAJE[leg.kind]
	if not v then return nil end
	local lugar = destino(leg)
	if not lugar then return nil end
	local linea, debajo = ns.T(v.toma):format(lugar), v.debajo and ns.T(v.debajo) or nil
	local X = ns.Transit
	local id = type(leg.transport) == "table" and leg.transport.id or leg.transport
	if v.abordo and X and id and X.NextDeparture then
		local now = X.Now and X.Now() or 0
		local riding = X.Riding and X.Riding(now)
		if type(riding) == "table" and riding.kind == leg.kind then
			linea = ns.T(v.abordo):format(lugar)
		else
			local llega, sale = X.NextArrival(leg.kind, id, now, leg.side)
			local espera, _, medido = X.NextDeparture(leg.kind, id, now, leg.side)
			if llega and llega <= 0 and sale then
				linea = ns.T(v.aqui):format(mmss(sale))
			elseif llega and medido then
				linea = linea .. "  \194\183  " .. ns.T("sale en %s"):format(cuantoFalta(espera or llega, true))
			elseif espera then
				linea = linea .. "  \194\183  " .. ns.T("sale en %s"):format(cuantoFalta(espera, false))
			end
			-- El siguiente (el horario real, cuando alguien de la manada lo midió).
			if medido and espera then
				local sig = X.NextDeparture(leg.kind, id, now + espera + 5, leg.side)
				if sig then debajo = ns.T("Si lo pierdes, el siguiente sale en %s"):format(duracionRedonda(espera + 5 + sig)) end
			elseif espera then
				debajo = ns.T("Hora aproximada: aún nadie lo ha medido")
			end
		end
	end
	local llegas = secsTotal and ns.T("Llegas en %s"):format(duracionRedonda(secsTotal)) or nil
	return linea, debajo, llegas
end

---------------------------------------------------------------------------
-- Alfa 1.3.9: la tarjeta del viaje (pedido de Toxic: «no me gusta en lo
-- absoluto, es igual al de Polestar»). En lugar de tres líneas sueltas sobre
-- el mundo, una tarjeta de Alfa en el lugar de la flecha, como la placa de
-- llegada: el panel del Kit con su corte y su franja (del color de tu bando
-- con la temática de la 1.3.9, Kit/Bando.lua), un medallón con el transporte
-- dibujado a la manera de Alfa (tools/bandos.py: viaje-barco, -zepelin,
-- -tranvia, -portal, -grifo), el título claro («Barco a Trinquete») y la
-- salida como protagonista: una cuenta grande («2:48») con su barra que se
-- llena; sin horario medido, «~3 min», «Sale cada ~6 min», una barra que
-- espera (un brillo que va y viene) y «Mide el horario: espéralo aquí una
-- vez». Abajo, la ruta en tres puntos (Tú, el muelle, el destino) con el de
-- ahora resaltado y cuánto falta para llegar.
-- Estados (tarjeta.estado):
--   "camino"    caminando al muelle (la flecha apunta; la tarjeta va debajo
--               y dice la distancia: «Ve al muelle · 120 m»)
--   "muelle"    esperando en el muelle (la cuenta de la salida)
--   "abordo"    a bordo («A bordo», llegas en 0:40 con su barra de viaje)
--   "llegando"  los últimos segundos («¡Tierra a la vista!»)
-- Nada del texto del motor se ve a la vez (sinTextoViejo).
--   Arrow.Tarjeta() -> { estado, kind, titulo, sobre, cuenta, nota, ruta, barra, espera } | nil
---------------------------------------------------------------------------
local NUCLEO_MEDIA = "Interface\\AddOns\\Alfa_Nucleo\\Media\\"
local TARJETA = {
	boat = { icono = "viaje-barco", titulo = "Barco a %s", ir = "Ve al muelle", espera = "Esperando en el muelle",
		aqui = "¡El barco ya está aquí!", lugar = "el muelle", corto = "Al muelle", llegando = "¡Tierra a la vista!" },
	zeppelin = { icono = "viaje-zepelin", titulo = "Zepelín a %s", ir = "Ve a la torre", espera = "Esperando en la torre",
		aqui = "¡El zepelín ya está aquí!", lugar = "la torre", corto = "A la torre", llegando = "¡Tierra a la vista!" },
	tram = { icono = "viaje-tranvia", titulo = "Tranvía a %s", ir = "Ve al andén", espera = "Esperando en el andén",
		aqui = "¡El tranvía ya está aquí!", lugar = "el andén", corto = "Al andén", llegando = "¡Llegando al andén!" },
	portal = { icono = "viaje-portal", titulo = "Portal a %s", ir = "Ve al portal", espera = "Cruza el portal",
		lugar = "el portal", corto = "Al portal" },
	fly = { icono = "viaje-grifo", titulo = "Vuelo a %s", ir = "Ve con el maestro de vuelo", espera = "Habla con el maestro de vuelo",
		lugar = "el maestro de vuelo", corto = "Maestro de vuelo" },
}
Arrow.TARJETA = TARJETA
local TJ_ANCHO, TJ_PAD, TJ_MEDALLA = 300, 10, 46
local TJ_COLUMNA = TJ_ANCHO - TJ_PAD * 3 - TJ_MEDALLA
local LLEGANDO = 20 -- segundos antes de llegar: «¡Tierra a la vista!»
local tarjeta       -- el marco (se arma la primera vez)
local tarjetaVista  -- { ... } lo que dice mientras se ve

local function colorTarjeta(K)
	local B = K.Bando and K.Bando()
	if B then return B.color[1], B.color[2], B.color[3], B.metal end
	local r, g, b = Nav.RGB("arrow")
	return r, g, b, nil
end

-- La barra que espera (sin horario): un brillo que va y viene; la tarjeta
-- entra subiendo y el medallón respira. Nada se crea aquí.
local function animarTarjeta(self, dt)
	dt = tonumber(dt) or 0
	local t = (self.alfaT or 0) + dt
	self.alfaT = t
	local quieta = self.alfaQuieta
	local entra = quieta and QUIETA_ENTRA or ENTRA_PLACA
	local e = t < entra and t / entra or 1
	e = e * e * (3 - 2 * e)
	self:SetAlpha(e)
	if not self.alfaAnclada then
		self:ClearAllPoints()
		local abajo = self.alfaAbajo
		local y = (quieta or e >= 1) and 0 or -(1 - e) * 10
		Arrow.PL.anclar(self, abajo, y)
		if quieta or e >= 1 then self.alfaAnclada = true end
	end
	if quieta then return end
	-- 1.4.0 (69): el aro y el halo quietos (Toxic: «el aro parpadea»).
	self.Halo:SetAlpha(0.35)
	if self.alfaEspera and self.Brillo:IsShown() then
		local ancho = self.alfaPista or TJ_COLUMNA
		local p = (t * 0.45) % 1
		p = p < 0.5 and p * 2 or 2 - p * 2 -- va y viene
		p = p * p * (3 - 2 * p)
		self.Brillo:ClearAllPoints()
		self.Brillo:SetPoint("LEFT", self.Pista, "LEFT", p * (ancho - 40), 0)
	end
end

local function armarTarjeta(K)
	if tarjeta then return tarjeta end
	local f = CreateFrame("Frame", "AlfaNavViaje", frame)
	f:SetSize(TJ_ANCHO, 110)
	Arrow.PL.anclar(f, false, 0)
	f:EnableMouse(false)
	f:Hide()
	f.caja = K.Caja(f, { corte = K.CORTE.tarjeta, rol = "panel", alfaFondo = 0.92 })
	f.Franja = f:CreateTexture(nil, "ARTWORK", nil, 1)
	f.Franja:SetColorTexture(1, 1, 1, 1)
	f.Franja:SetWidth(3)
	f.Franja:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -K.CORTE.tarjeta - 4)
	f.Franja:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, K.CORTE.tarjeta + 4)
	-- El adorno del bando arriba (madera y hierro, o piedra y plata).
	f.Adorno = f:CreateTexture(nil, "ARTWORK", nil, 2)
	f.Adorno:SetHeight(4)
	f.Adorno:SetPoint("TOPLEFT", f, "TOPLEFT", K.CORTE.tarjeta + 2, 0)
	f.Adorno:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, 0)
	f.Adorno:Hide()
	-- El medallón con el transporte.
	f.Medalla = CreateFrame("Frame", nil, f)
	f.Medalla:SetSize(TJ_MEDALLA, TJ_MEDALLA)
	f.Medalla:SetPoint("TOPLEFT", f, "TOPLEFT", TJ_PAD + 2, -TJ_PAD)
	f.Halo = f.Medalla:CreateTexture(nil, "BACKGROUND", nil, 1)
	f.Halo:SetTexture(MEDIA .. "glow")
	f.Halo:SetBlendMode("ADD")
	f.Halo:SetSize(TJ_MEDALLA * 1.7, TJ_MEDALLA * 1.7)
	f.Halo:SetPoint("CENTER")
	f.Fondo = f.Medalla:CreateTexture(nil, "BACKGROUND", nil, 2)
	f.Fondo:SetTexture(UI_DIR .. "circle")
	f.Fondo:SetAllPoints()
	f.Aro = f.Medalla:CreateTexture(nil, "ARTWORK")
	f.Aro:SetTexture(MEDIA .. "ring")
	f.Aro:SetAllPoints()
	f.Icono = f.Medalla:CreateTexture(nil, "ARTWORK", nil, 2)
	f.Icono:SetSize(TJ_MEDALLA * 0.62, TJ_MEDALLA * 0.62)
	f.Icono:SetPoint("CENTER")
	-- La columna: el estado, el título y, a la derecha, la cuenta grande.
	f.Sobre = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	f.Sobre:SetJustifyH("LEFT")
	f.Titulo = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	f.Titulo:SetJustifyH("LEFT")
	f.Titulo:SetWordWrap(true)
	f.Titulo:SetMaxLines(2)
	f.Cuenta = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	f.Cuenta:SetJustifyH("RIGHT")
	f.CuentaSobre = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	f.CuentaSobre:SetJustifyH("RIGHT")
	-- La barra: se llena con la cuenta; sin horario, un brillo que espera.
	f.Pista = f:CreateTexture(nil, "ARTWORK")
	f.Pista:SetHeight(4)
	f.Relleno = f:CreateTexture(nil, "ARTWORK", nil, 1)
	f.Relleno:SetPoint("TOPLEFT", f.Pista, "TOPLEFT", 0, 0)
	f.Relleno:SetPoint("BOTTOMLEFT", f.Pista, "BOTTOMLEFT", 0, 0)
	f.Brillo = f:CreateTexture(nil, "ARTWORK", nil, 2)
	f.Brillo:SetSize(40, 4)
	f.Brillo:SetColorTexture(1, 1, 1, 1)
	f.Brillo:Hide()
	f.Nota = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	f.Nota:SetJustifyH("LEFT")
	f.Nota:SetWordWrap(true)
	f.Nota:SetMaxLines(3)
	-- La ruta: tres puntos en una línea y sus nombres debajo.
	f.RutaLinea = f:CreateTexture(nil, "ARTWORK")
	f.RutaLinea:SetHeight(2)
	f.RutaHecha = f:CreateTexture(nil, "ARTWORK", nil, 1)
	f.RutaHecha:SetHeight(2)
	f.Puntos = {}
	for i = 1, 3 do
		local p = f:CreateTexture(nil, "ARTWORK", nil, 3)
		p:SetTexture(UI_DIR .. "circle")
		p:SetSize(8, 8)
		f.Puntos[i] = p
	end
	f.Ruta = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	f.Ruta:SetJustifyH("LEFT")
	f.Ruta:SetWordWrap(true)
	f.Ruta:SetMaxLines(2)
	f:SetScript("OnUpdate", animarTarjeta)
	tarjeta = f
	Arrow.tarjeta = f
	return f
end

-- El texto viejo (el del motor: la línea dorada, la de abajo y «Llegas en»)
-- y el disco no se ven con la tarjeta; el disco solo mientras caminas.
local function sinTextoViejo(conDisco)
	distText:Hide()
	labelText:Hide()
	etaText:Hide()
	legIcon:Hide()
	halo:Hide()
	floorIcon:SetShown(conDisco and floorShown ~= nil or false)
	if not conDisco then
		-- Sin disco a la vista (en el muelle o a bordo): el texto de antes en
		-- blanco, por si alguien lo lee (y nada atrapa el ratón).
		distText:SetText("")
		ponerMeta("")
	end
end

local function quitarTarjeta()
	if tarjeta and tarjeta:IsShown() then
		-- 1.4.0: si vuelve enseguida al mismo viaje, sale sin volver a entrar
		-- (Toxic: «no deja de parpadear» esperando el barco).
		tarjeta.alfaQuitada = GetTime()
		tarjeta:Hide()
		if Arrow.PL.aparte() then frame:EnableMouse(true) end -- 1.4.0 (78)
		distText:Show()
		labelText:Show()
		if frame.SetClampRectInsets then frame:SetClampRectInsets(0, 0, 0, 0) end
	end
	tarjetaVista = nil
end
Arrow.QuitarTarjeta = quitarTarjeta

-- Lo que dice la tarjeta para un tramo de viaje y un estado.
-- -> { estado, kind, titulo, sobre, cuenta, cuentaSobre, nota, ruta, paso, frac, espera, urge }
function Arrow.DatosTarjeta(leg, estado, secsTotal, yardas)
	local v = type(leg) == "table" and TARJETA[leg.kind]
	if not v then return nil end
	local lugar = destino(leg)
	if not lugar then return nil end
	local d = { estado = estado, kind = leg.kind, titulo = ns.T(v.titulo):format(lugar) }
	local X = ns.Transit
	local id = type(leg.transport) == "table" and leg.transport.id or leg.transport
	local now = X and X.Now and X.Now() or 0
	-- A bordo: el motor sabe cuándo llega.
	if (estado == "muelle" or estado == "abordo") and X and X.Riding then
		local riding = X.Riding(now)
		if type(riding) == "table" and riding.kind == leg.kind then
			estado = (tonumber(riding.arriveIn) or 99) <= LLEGANDO and "llegando" or "abordo"
			d.estado = estado
			d.llegaEn = tonumber(riding.arriveIn)
		end
	end
	if estado == "camino" then
		d.sobre = ns.T(v.ir)
		if yardas then d.distancia = ns.FormatDistance(floor(yardas + 0.5)) end
		d.paso = 1
	elseif estado == "abordo" or estado == "llegando" then
		d.sobre = estado == "llegando" and ns.T(v.llegando or "¡Tierra a la vista!") or ns.T("A bordo")
		d.paso = 3
		local ride
		if X and X.NextDeparture and id then
			local _, r2 = X.NextDeparture(leg.kind, id, now, leg.side)
			ride = r2
		end
		local falta = d.llegaEn
		if falta then
			d.cuenta, d.cuentaSobre = mmss(falta), ns.T("llegas en")
			local total = tonumber(ride) or tonumber(leg.seconds) or 0
			if total > 0 then d.frac = math.max(0, math.min(1, 1 - falta / total)) end
			d.urge = falta <= 10
		end
	else
		d.sobre = ns.T(v.espera)
		d.paso = 2
	end
	-- La salida (barco, zepelín, tranvía): la cuenta real o la espera de siempre.
	if (estado == "camino" or estado == "muelle") and X and id and X.NextDeparture and v.aqui then
		local llega, sale = X.NextArrival(leg.kind, id, now, leg.side)
		local espera, _, medido = X.NextDeparture(leg.kind, id, now, leg.side)
		if llega and llega <= 0 and sale then
			if estado == "muelle" then d.sobre = ns.T(v.aqui) end
			d.cuenta, d.cuentaSobre = mmss(sale), ns.T("zarpa en")
			d.frac = 1
			d.urge = sale <= 10
		elseif medido and (espera or llega) then
			local s = espera or llega
			d.cuenta, d.cuentaSobre = mmss(s), ns.T("sale en")
			d.urge = s <= 10
			local sig = espera and X.NextDeparture(leg.kind, id, now + espera + 5, leg.side)
			if sig then d.nota = ns.T("Si lo pierdes, el siguiente sale en %s"):format(duracionRedonda(espera + 5 + sig)) end
			d.medido = true
			d.restante = s
			-- 1.4.0 (37): el horario lo midió un lobo de tu hermandad (Alfa_Mundo/Horarios.lua).
			local de = type(Nav.HorarioDeLaManada) == "function" and Nav.HorarioDeLaManada(id) or nil
			if type(de) == "string" and de ~= "" then
				d.deLaManada = de
				d.nota = (d.nota and (d.nota .. "\n") or "") .. ns.T("Horario medido por %s, de La Jauría"):format(de)
			end
		elseif espera then
			d.cuenta, d.cuentaSobre = ("~%d min"):format(math.max(1, floor(espera / 60 + 0.5))), ns.T("sale en")
			d.espera = true -- sin horario: la barra espera
			local cada = math.max(1, floor(espera * 2 / 60 + 0.5))
			d.nota = ns.T("Sale cada ~%d min"):format(cada) .. "\n" .. ns.T("Mide el horario: espéralo aquí una vez")
		end
	elseif leg.kind == "fly" and estado ~= "abordo" then
		local s = tonumber(leg.seconds)
		if s and s > 0 then d.cuenta, d.cuentaSobre = duracionRedonda(s), ns.T("de vuelo") end
		if estado == "camino" then d.nota = ns.T("Habla con el maestro de vuelo") end
	elseif leg.kind == "portal" and estado == "camino" then
		d.nota = ns.T("Lo cruzas y llegas al momento")
	end
	-- La ruta: Tú, el muelle (o la torre...) y el destino.
	local T = Nav.travel
	local muelle = leg.from and T and T.PlaceName and T.PlaceName(leg.from)
	if type(muelle) ~= "string" or muelle == "" or (issecretvalue and issecretvalue(muelle)) then muelle = ns.T(v.lugar) end
	muelle = muelle:match("^([^,]+)") or muelle
	d.puntos = { ns.T("Tú"), muelle, lugar }
	-- A bordo la cuenta ya dice cuándo llegas: «llegas en» solo si después hay más camino.
	if secsTotal and not (d.llegaEn and secsTotal < d.llegaEn + 60) then d.llegas = ns.T("llegas en %s"):format(duracionRedonda(secsTotal)) end
	return d
end

---------------------------------------------------------------------------
-- Alfa 1.4.0 (69): la tarjeta compacta (nav.viajeCompacto, de fábrica). Toxic:
-- «ocupa mucho, no se entiende el ícono, no se cierra y se queda al llegar».
-- Dos renglones junto al dibujo del transporte (grifo o murciélago según tu
-- bando, barco, zepelín, tranvía, portal):
--   «Vuelo a Forjaz                  1:31»
--   «Ve con el maestro de vuelo · 1066 yd»
-- Lo demás (la nota, la ruta, cuándo llegas) en el cuadro al pasar el ratón.
-- Se cierra con su X o con clic derecho (hasta el siguiente destino); a bordo
-- se queda TJ_A_BORDO segundos y se va sola, y al llegar ya no vuelve. Fuera
-- de combate toma el ratón; en combate no (no atrapa clics).
--   Arrow.Tarjeta().compacta / .cerrada ; Arrow.CerrarTarjeta()
---------------------------------------------------------------------------
local TJ_COMPACTA = 272
local TJ_A_BORDO = 6
local pintarCompacta
Arrow.cerradas = {} -- tramo (kind|título) -> true: lo cerraste
do
local MEDALLA_C = 30

local function claveDe(d) return tostring(d.kind) .. "|" .. tostring(d.titulo) end

local function iconoDe(d)
	if d.kind == "fly" then
		local f = UnitFactionGroup and UnitFactionGroup("player")
		if not (issecretvalue and issecretvalue(f)) and f == "Horde" then return "viaje-murcielago" end
	end
	return TARJETA[d.kind].icono
end
Arrow.IconoViaje = iconoDe

local function detalle(f)
	local d = tarjetaVista
	if not d or enCombate() then return end
	GameTooltip:SetOwner(f, "ANCHOR_BOTTOM")
	GameTooltip:SetText(d.titulo, Nav.RGB("text"))
	local r, g, b = Nav.RGB("textDim")
	if d.sobre then GameTooltip:AddLine(d.sobre .. (d.distancia and ("  \194\183  " .. d.distancia) or ""), r, g, b, true) end
	if d.cuenta then
		local cr, cg, cb = Nav.RGB("arrowText")
		GameTooltip:AddLine((d.cuentaSobre and (d.cuentaSobre .. " ") or "") .. d.cuenta, cr, cg, cb)
	end
	if d.nota then GameTooltip:AddLine(d.nota, r, g, b, true) end
	if d.puntos then GameTooltip:AddLine(table.concat(d.puntos, "  \226\128\186  "), r, g, b, true) end
	if d.llegas then GameTooltip:AddLine(d.llegas:sub(1, 1):upper() .. d.llegas:sub(2), r, g, b) end
	GameTooltip:AddLine(" ")
	local mr, mg, mb = Nav.RGB("textMuted")
	GameTooltip:AddLine(ns.T("Clic derecho o la X: cerrarla"), mr, mg, mb)
	GameTooltip:Show()
end

local function cerrar(f)
	local d = tarjetaVista
	if d then Arrow.cerradas[claveDe(d)] = true end
	if GameTooltip:GetOwner() == f then GameTooltip:Hide() end
	f:Hide()
	f.alfaCerrada = true
end
Arrow.CerrarTarjeta = function() if tarjeta then cerrar(tarjeta) end end

local function armarCompacta(K, f)
	if f.Cerrar then return end
	f.Cerrar = K.BotonIcono(f, "ic-cerrar", function() cerrar(f) end, { tam = 18, icono = 9, ayuda = ns.T("Cerrar") })
	f.Cerrar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
	f:SetScript("OnEnter", detalle)
	f:SetScript("OnLeave", function(self) if GameTooltip:GetOwner() == self then GameTooltip:Hide() end end)
	f:SetScript("OnMouseUp", function(self, boton) if boton == "RightButton" and not enCombate() then cerrar(self) end end)
end

-- -> true si se encargó (pintada, cerrada o ida sola); false: la flecha de siempre.
function pintarCompacta(K, f, d, abajo)
	local clave = claveDe(d)
	-- A bordo: unos segundos y se va; al llegar ya no vuelve.
	if d.estado == "abordo" or d.estado == "llegando" then
		f.alfaBordo = f.alfaBordo or {}
		local t = GetTime and GetTime() or 0
		f.alfaBordo[clave] = f.alfaBordo[clave] or t
		if t - f.alfaBordo[clave] > TJ_A_BORDO or (d.llegaEn and d.llegaEn <= 1) then Arrow.cerradas[clave] = true end
	end
	if Arrow.cerradas[clave] then
		if f:IsShown() then
			f:Hide()
			if GameTooltip:GetOwner() == f then GameTooltip:Hide() end
		end
		f.alfaCerrada = true
		tarjetaVista = d
		-- Caminando al muelle, la flecha de siempre; en el muelle o a bordo, nada.
		if abajo then return false end
		sinTextoViejo(false)
		return true
	end
	f.alfaCerrada = false
	armarCompacta(K, f)
	local r, g, b, metal = colorTarjeta(K)
	local nuevo = not f:IsShown() or f.alfaAbajo ~= abajo or f.alfaModo ~= "compacta"
	if nuevo then
		f.alfaT, f.alfaAnclada = 0, false
		-- 1.4.0: el mismo viaje que se acaba de quitar vuelve sin entrar otra vez.
		if f.alfaViaje == tostring(d.kind) .. "|" .. tostring(d.titulo) and GetTime() - (f.alfaQuitada or -99) < 2 then f.alfaT = 99 end
		f.alfaViaje = tostring(d.kind) .. "|" .. tostring(d.titulo)
		f:ClearAllPoints()
		Arrow.PL.anclar(f, abajo, 0)
	end
	f.alfaModo, f.alfaFirma = "compacta", nil
	f.alfaAbajo = abajo
	f.alfaQuieta = ns.Get("ui.reduceMotion") and true or false
	f.alfaEspera, f.alfaUrge = false, false
	-- Lo que no va en la compacta.
	for _, x in ipairs({ f.Pista, f.Relleno, f.Brillo, f.Nota, f.RutaLinea, f.RutaHecha, f.Ruta, f.CuentaSobre, f.Adorno }) do x:Hide() end
	for _, p in ipairs(f.Puntos) do p:Hide() end
	f.Medalla:SetSize(MEDALLA_C, MEDALLA_C)
	f.Medalla:ClearAllPoints()
	f.Medalla:SetPoint("LEFT", f, "LEFT", TJ_PAD + 2, 0)
	f.Halo:SetSize(MEDALLA_C * 1.6, MEDALLA_C * 1.6)
	f.Halo:SetAlpha(0.35)
	f.Icono:SetSize(MEDALLA_C * 0.72, MEDALLA_C * 0.72)
	f.Icono:SetTexture(NUCLEO_MEDIA .. iconoDe(d))
	f.Icono:SetVertexColor(r, g, b, 1)
	f.Aro:SetVertexColor(r, g, b, 0.9)
	f.Halo:SetVertexColor(r, g, b, 1)
	f.Fondo:SetVertexColor(K.ConAlfa("hundido", 0.95))
	f.Franja:SetVertexColor(r, g, b, 1)
	f.Cuenta:SetAlpha(1)
	local x = TJ_PAD * 2 + 2 + MEDALLA_C
	local derecha = 4 + 18 + 6 -- la X
	-- Renglón 1: el título entero (el destino es lo que importa).
	local ancho = TJ_COMPACTA - x - derecha
	letra(K, f.Titulo, "cuerpo")
	f.Titulo:SetTextColor(K.Color("texto"))
	f.Titulo:SetWidth(ancho)
	f.Titulo:SetWordWrap(false)
	f.Titulo:SetMaxLines(1)
	f.Titulo:SetText(Arrow.AcortarA and Arrow.AcortarA(f.Titulo, d.titulo, ancho) or d.titulo)
	f.Titulo:ClearAllPoints()
	f.Titulo:SetPoint("TOPLEFT", f, "TOPLEFT", x, -TJ_PAD)
	local y = TJ_PAD + altoTexto(K, f.Titulo, 14)
	-- Renglón 2: la cuenta (en el color del viaje) y qué hacer, o de quién es el horario.
	local anchoCuenta = 0
	-- Caminando al muelle, lo que importa es a cuánto está (la cuenta, en el cuadro).
	local cuenta = d.estado ~= "camino" and d.cuenta or nil
	if cuenta then
		letra(K, f.Cuenta, "cuerpo")
		f.Cuenta:SetJustifyH("LEFT")
		f.Cuenta:SetWidth(0)
		if metal then f.Cuenta:SetTextColor(metal[1], metal[2], metal[3], 1) else f.Cuenta:SetTextColor(Nav.RGB("arrowText")) end
		f.Cuenta:SetText(cuenta)
		f.Cuenta:ClearAllPoints()
		f.Cuenta:SetPoint("TOPLEFT", f, "TOPLEFT", x, -(y + 3))
		anchoCuenta = math.ceil(tonumber(f.Cuenta:GetStringWidth()) or 0) + 8
		f.Cuenta:Show()
	else
		f.Cuenta:Hide()
	end
	local dos = d.sobre or ""
	-- Corto y completo: «Maestro de vuelo · 1066 yd», no «Habla con el…».
	local v = TARJETA[d.kind]
	if v and v.corto and (dos == ns.T(v.ir) or (d.kind == "fly" and dos == ns.T(v.espera))) then dos = ns.T(v.corto) end
	if d.distancia and d.estado == "camino" then dos = d.distancia .. "  \194\183  " .. dos
	elseif d.distancia then dos = dos .. "  \194\183  " .. d.distancia end
	if d.deLaManada and d.estado ~= "camino" then dos = ns.T("Horario medido por %s, de La Jauría"):format(d.deLaManada) end
	local anchoDos = TJ_COMPACTA - x - TJ_PAD - anchoCuenta
	letra(K, f.Sobre, "pequeno")
	f.Sobre:SetTextColor(K.Color("textoSuave"))
	f.Sobre:SetWidth(anchoDos)
	f.Sobre:SetWordWrap(false)
	f.Sobre:SetText(Arrow.AcortarA and Arrow.AcortarA(f.Sobre, dos, anchoDos) or dos)
	f.Sobre:ClearAllPoints()
	if cuenta then
		f.Sobre:SetPoint("LEFT", f.Cuenta, "RIGHT", 8, 0)
	else
		f.Sobre:SetPoint("TOPLEFT", f, "TOPLEFT", x, -(y + 3))
	end
	f.Sobre:SetShown(dos ~= "")
	if dos ~= "" or cuenta then
		y = y + 3 + math.max(cuenta and altoTexto(K, f.Cuenta, 14) or 0, dos ~= "" and altoTexto(K, f.Sobre, 12) or 0)
	end
	y = math.max(y, MEDALLA_C) + TJ_PAD
	f:SetSize(TJ_COMPACTA, y)
	local libre = not enCombate()
	f:EnableMouse(libre)
	f.Cerrar:SetShown(libre)
	f:Show()
	Arrow.PL.medir(f) -- 1.4.0 (78)
	sinTextoViejo(abajo)
	local sobra = math.max(0, (TJ_COMPACTA - WIDTH) / 2)
	if frame.SetClampRectInsets then frame:SetClampRectInsets(-sobra, sobra, 0, abajo and -(y + 6 - TEXT_H) or 0) end
	tarjetaVista = d
	return true
end
end

-- Pinta la tarjeta. -> true si se pudo (sin el Kit, false: el texto de antes).
local function pintarTarjeta(d, abajo)
	local K = kit()
	if not (K and d) then return false end
	local f = armarTarjeta(K)
	if ns.Get("nav.viajeCompacto") ~= false then return pintarCompacta(K, f, d, abajo) end
	-- (la grande: lo que la compacta escondió vuelve)
	if f.alfaModo ~= "grande" then
		f.alfaModo, f.alfaFirma, f.alfaCerrada = "grande", nil, false
		f.Medalla:SetSize(TJ_MEDALLA, TJ_MEDALLA)
		f.Medalla:ClearAllPoints()
		f.Medalla:SetPoint("TOPLEFT", f, "TOPLEFT", TJ_PAD + 2, -TJ_PAD)
		f.Halo:SetSize(TJ_MEDALLA * 1.7, TJ_MEDALLA * 1.7)
		f.Icono:SetSize(TJ_MEDALLA * 0.62, TJ_MEDALLA * 0.62)
		f.Titulo:SetWordWrap(true)
		f.Titulo:SetMaxLines(2)
		f.Sobre:SetWordWrap(true)
		f.Sobre:Show()
		for _, x in ipairs({ f.RutaLinea, f.Ruta }) do x:Show() end
		for _, p in ipairs(f.Puntos) do p:Show() end
		if f.Cerrar then f.Cerrar:Hide() end
		f.Cuenta:SetJustifyH("RIGHT")
		f:EnableMouse(false)
	end
	local r, g, b, metal = colorTarjeta(K)
	local B = K.Bando and K.Bando()
	local firma = table.concat({ d.estado, d.kind, d.titulo, d.sobre or "", d.distancia or "", d.cuenta or "", d.nota or "",
		tostring(d.frac or ""), d.llegas or "", tostring(abajo) }, "|")
	local nuevo = not f:IsShown() or f.alfaAbajo ~= abajo
	if nuevo then
		f.alfaT, f.alfaAnclada = 0, false
		-- 1.4.0: el mismo viaje que se acaba de quitar vuelve sin entrar otra vez.
		if f.alfaViaje == tostring(d.kind) .. "|" .. tostring(d.titulo) and GetTime() - (f.alfaQuitada or -99) < 2 then f.alfaT = 99 end
		f.alfaViaje = tostring(d.kind) .. "|" .. tostring(d.titulo)
		f:ClearAllPoints()
		Arrow.PL.anclar(f, abajo, 0)
	end
	f.alfaAbajo = abajo
	f.alfaQuieta = ns.Get("ui.reduceMotion") and true or false
	f.alfaEspera = d.espera and true or false
	f.alfaUrge = d.urge and true or false
	if not d.urge then f.Cuenta:SetAlpha(1) end
	if firma == f.alfaFirma and not nuevo then
		f:Show()
		sinTextoViejo(abajo)
		return true
	end
	f.alfaFirma = firma
	f.Franja:SetVertexColor(r, g, b, 1)
	f.Aro:SetVertexColor(r, g, b, 0.9)
	f.Halo:SetVertexColor(r, g, b, 1)
	f.Icono:SetTexture(NUCLEO_MEDIA .. Arrow.IconoViaje(d))
	f.Icono:SetVertexColor(r, g, b, 1)
	f.Fondo:SetVertexColor(K.ConAlfa("hundido", 0.95))
	if B and B.adorno then
		f.Adorno:SetTexture(B.adorno)
		f.Adorno:SetVertexColor(1, 1, 1, 1)
		f.Adorno:Show()
	else
		f.Adorno:Hide()
	end
	local x = TJ_PAD * 2 + 2 + TJ_MEDALLA
	local y = TJ_PAD
	-- La cuenta grande a la derecha.
	local anchoCuenta = 0
	if d.cuenta then
		letra(K, f.CuentaSobre, "mayus")
		f.CuentaSobre:SetTextColor(K.Color("textoSuave"))
		f.CuentaSobre:SetText(K.Mayus(d.cuentaSobre or ""))
		letra(K, f.Cuenta, "cifra")
		if metal then f.Cuenta:SetTextColor(metal[1], metal[2], metal[3], 1) else f.Cuenta:SetTextColor(Nav.RGB("arrowText")) end
		f.Cuenta:SetText(d.cuenta)
		f.CuentaSobre:ClearAllPoints()
		f.CuentaSobre:SetPoint("TOPRIGHT", f, "TOPRIGHT", -TJ_PAD - 2, -y - 1)
		f.Cuenta:ClearAllPoints()
		f.Cuenta:SetPoint("TOPRIGHT", f.CuentaSobre, "BOTTOMRIGHT", 0, -2)
		anchoCuenta = math.ceil(math.max(f.Cuenta:GetStringWidth() or 0, f.CuentaSobre:GetStringWidth() or 0)) + 10
		f.Cuenta:Show()
		f.CuentaSobre:Show()
	else
		f.Cuenta:Hide()
		f.CuentaSobre:Hide()
	end
	local ancho = TJ_COLUMNA - anchoCuenta
	letra(K, f.Sobre, "mayus")
	f.Sobre:SetTextColor(r, g, b, 1)
	f.Sobre:SetWidth(ancho)
	f.Sobre:SetText(K.Mayus(d.sobre or "") .. (d.distancia and ("  \194\183  " .. d.distancia) or ""))
	f.Sobre:ClearAllPoints()
	f.Sobre:SetPoint("TOPLEFT", f, "TOPLEFT", x, -y - 1)
	y = y + 1 + altoTexto(K, f.Sobre, 10)
	letra(K, f.Titulo, "subtitulo")
	f.Titulo:SetTextColor(K.Color("texto"))
	f.Titulo:SetWidth(ancho)
	f.Titulo:SetText(d.titulo)
	f.Titulo:ClearAllPoints()
	f.Titulo:SetPoint("TOPLEFT", f, "TOPLEFT", x, -(y + 3))
	y = y + 3 + altoTexto(K, f.Titulo, 16)
	if d.cuenta then
		local altoC = TJ_PAD + 1 + altoTexto(K, f.CuentaSobre, 10) + 2 + altoTexto(K, f.Cuenta, 24)
		y = math.max(y, altoC)
	end
	-- La barra.
	local conBarra = d.frac ~= nil or d.espera or d.medido
	f.Pista:ClearAllPoints()
	if conBarra then
		f.Pista:SetPoint("TOPLEFT", f, "TOPLEFT", x, -(y + 7))
		f.Pista:SetWidth(TJ_COLUMNA)
		f.alfaPista = TJ_COLUMNA
		f.Pista:SetColorTexture(K.ConAlfa("hundido", 0.95))
		f.Pista:Show()
		local frac = d.frac
		if d.medido and d.restante then
			-- La primera cuenta que vio es la barra entera: se llena al acercarse la salida.
			if not f.alfaRef or f.alfaRefTramo ~= d.titulo or d.restante > f.alfaRef then
				f.alfaRef, f.alfaRefTramo = math.max(d.restante, 1), d.titulo
			end
			frac = 1 - d.restante / f.alfaRef
		end
		f.Relleno:SetColorTexture(r, g, b, 1)
		f.Relleno:SetWidth(math.max(1, TJ_COLUMNA * (frac or 0)))
		f.Relleno:SetShown((frac or 0) > 0)
		f.Brillo:SetVertexColor(r, g, b, 0.85)
		f.Brillo:SetShown(d.espera and true or false)
		if d.espera then
			f.Brillo:ClearAllPoints()
			f.Brillo:SetPoint("LEFT", f.Pista, "LEFT", 0, 0)
		end
		y = y + 7 + 4
	else
		f.Pista:Hide()
		f.Relleno:Hide()
		f.Brillo:Hide()
	end
	-- La nota.
	if d.nota then
		letra(K, f.Nota, "pequeno")
		f.Nota:SetTextColor(K.Color("textoSuave"))
		f.Nota:SetWidth(TJ_COLUMNA)
		f.Nota:SetText(d.nota)
		f.Nota:ClearAllPoints()
		f.Nota:SetPoint("TOPLEFT", f, "TOPLEFT", x, -(y + 6))
		f.Nota:Show()
		y = y + 6 + altoTexto(K, f.Nota, 12)
	else
		f.Nota:Hide()
	end
	-- La ruta: los tres puntos y sus nombres, el de ahora en el color del viaje.
	y = y + 10
	local x0, x1 = x + 4, x + TJ_COLUMNA - 4
	f.RutaLinea:ClearAllPoints()
	f.RutaLinea:SetPoint("LEFT", f, "TOPLEFT", x0, -(y + 4))
	f.RutaLinea:SetWidth(x1 - x0)
	f.RutaLinea:SetColorTexture(K.ConAlfa("lineaFuerte", 1))
	local paso = d.paso or 1
	local hecho = (paso - 1) / 2
	f.RutaHecha:ClearAllPoints()
	f.RutaHecha:SetPoint("LEFT", f, "TOPLEFT", x0, -(y + 4))
	f.RutaHecha:SetWidth(math.max(1, (x1 - x0) * hecho))
	f.RutaHecha:SetColorTexture(r, g, b, 1)
	f.RutaHecha:SetShown(hecho > 0)
	for i, p in ipairs(f.Puntos) do
		local px = x0 + (x1 - x0) * (i - 1) / 2
		local actual = i == paso
		local tam = actual and 10 or 7
		p:SetSize(tam, tam)
		p:ClearAllPoints()
		p:SetPoint("CENTER", f, "TOPLEFT", px, -(y + 4))
		if i <= paso then p:SetVertexColor(r, g, b, 1) else p:SetVertexColor(K.Color("textoTenue")) end
	end
	y = y + 10
	local partes = {}
	local cr, cg, cb = r, g, b
	if metal then cr, cg, cb = metal[1], metal[2], metal[3] end
	local hex = ("|cff%02x%02x%02x"):format(floor(cr * 255 + 0.5), floor(cg * 255 + 0.5), floor(cb * 255 + 0.5))
	for i, n in ipairs(d.puntos or {}) do
		partes[i] = i == paso and (hex .. n .. "|r") or n
	end
	local ruta = table.concat(partes, "  \226\128\186  ")
	letra(K, f.Ruta, "pequeno")
	f.Ruta:SetTextColor(K.Color("textoSuave"))
	f.Ruta:SetWidth(TJ_COLUMNA)
	if d.llegas then
		-- En la misma línea si cabe; si no, en la suya (nunca partida a la mitad).
		f.Ruta:SetText(ruta)
		local libre = TJ_COLUMNA - (tonumber(f.Ruta:GetStringWidth()) or 0)
		f.Ruta:SetText(d.llegas)
		local pide = (tonumber(f.Ruta:GetStringWidth()) or 0) + 16
		if libre >= pide then
			ruta = ruta .. "  \194\183  " .. d.llegas
		else
			ruta = ruta .. "\n" .. d.llegas:sub(1, 1):upper() .. d.llegas:sub(2)
		end
	end
	f.Ruta:SetText(ruta)
	f.Ruta:ClearAllPoints()
	f.Ruta:SetPoint("TOPLEFT", f, "TOPLEFT", x, -(y + 2))
	y = y + 2 + altoTexto(K, f.Ruta, 12)
	y = math.max(y, TJ_PAD + TJ_MEDALLA) + TJ_PAD
	f:SetHeight(y)
	f:SetWidth(TJ_ANCHO)
	if f.alfaQuieta then f.Halo:SetAlpha(0.4) end
	f:Show()
	Arrow.PL.medir(f) -- 1.4.0 (78)
	sinTextoViejo(abajo)
	local sobra = math.max(0, (TJ_ANCHO - WIDTH) / 2)
	if frame.SetClampRectInsets then frame:SetClampRectInsets(-sobra, sobra, 0, abajo and -(y + 6 - TEXT_H) or 0) end
	tarjetaVista = d
	return true
end

function Arrow.Tarjeta()
	if tarjeta and tarjeta.alfaCerrada and tarjetaVista then return { cerrada = true, estado = tarjetaVista.estado, kind = tarjetaVista.kind } end
	if not (tarjeta and tarjeta:IsShown() and tarjetaVista) then return nil end
	local d = tarjetaVista
	return { estado = d.estado, kind = d.kind, titulo = d.titulo, sobre = tarjeta.Sobre:GetText(), cuenta = d.cuenta,
		nota = d.nota, ruta = tarjeta.Ruta:GetText(), barra = tarjeta.Pista:IsShown() or nil, espera = d.espera or nil,
		abajo = tarjeta.alfaAbajo or nil, paso = d.paso, compacta = tarjeta.alfaModo == "compacta" or nil,
		icono = tarjeta.Icono:GetTexture(), cerrar = tarjeta.Cerrar ~= nil and tarjeta.Cerrar:IsShown() or nil,
		viejo = distText:IsShown() or labelText:IsShown() or etaText:IsShown() or legIcon:IsShown() or nil }
end

-- Caminando a un muelle (el tramo que sigue es un viaje): la tarjeta va
-- debajo de la flecha. -> true si la pintó.
local function pintarCamino(T, dist)
	local siguiente = T and T.NextLeg and T.NextLeg()
	if not (type(siguiente) == "table" and TARJETA[siguiente.kind]) then return false end
	local t = GetTime()
	if tarjetaVista and tarjetaVista.estado == "camino" and viajeCuando and t - viajeCuando < 0.25 then
		sinTextoViejo(true)
		return true
	end
	viajeCuando = t
	local okR, secs = false, nil
	if showEta and T.Remaining then okR, secs = pcall(T.Remaining, dist) end
	local d = Arrow.DatosTarjeta(siguiente, "camino", okR and tonumber(secs) or nil, dist)
	return pintarTarjeta(d, true)
end

-- Pinta el viaje en la flecha (solo lo que cambió). -> true si era un viaje.
local function pintarViaje(leg, secsTotal)
	-- Cuatro veces por segundo basta (la flecha mira el mundo 20 veces).
	local t = GetTime()
	if viajeVisto and viajeCuando and t - viajeCuando < 0.25 and viajeVisto.leg == leg then
		if tarjetaVista then sinTextoViejo(false) end
		return true
	end
	viajeCuando = t
	local linea, debajo, llegas = Arrow.TextoViaje(leg, secsTotal)
	-- 1.3.9: la tarjeta de Alfa; el texto de antes solo sin el Kit.
	if linea and pintarTarjeta(Arrow.DatosTarjeta(leg, "muelle", secsTotal), false) then
		viajeVisto = { linea = linea, debajo = debajo, llegas = llegas, kind = leg.kind, leg = leg }
		if floor(frame:GetWidth() + 0.5) ~= WIDTH or floor(frame:GetHeight() + 0.5) ~= DIAL + TEXT_H then
			frame:SetSize(WIDTH, DIAL + TEXT_H)
		end
		dial:Show()
		showArrow(false)
		-- Solo el área de la tarjeta (arriba) toma el ratón para moverla.
		frame:SetHitRectInsets((WIDTH - DIAL) / 2, (WIDTH - DIAL) / 2, 0, TEXT_H)
		-- 1.4.0 (78): con la tarjeta aparte, el lugar vacío de la flecha no toma el ratón.
		if Arrow.PL.aparte() then frame:EnableMouse(false) end
		return true
	end
	if not linea then
		-- Alfa 1.3.8 (revisión): el tramo dejó de ser viaje sin cambiar de modo:
		-- la flecha vuelve a su tamaño de siempre.
		if viajeVisto and (floor(frame:GetWidth() + 0.5) ~= WIDTH or floor(frame:GetHeight() + 0.5) ~= DIAL + TEXT_H) then
			frame:SetSize(WIDTH, DIAL + TEXT_H)
			grabArea(true) -- (en «instruction» el disco está a la vista)
		end
		if viajeVisto or tarjetaVista then
			quitarTarjeta()
			grabArea(true)
		end
		viajeVisto = nil
		return false
	end
	local v = viajeVisto
	if not (v and v.linea == linea) then distText:SetText(linea) end
	if not (v and v.debajo == debajo) then ponerMeta(debajo or "") end
	if llegas then
		if not (v and v.llegas == llegas) then etaText:SetText(llegas) end
		etaText:Show()
	else
		etaText:Hide()
	end
	viajeVisto = { linea = linea, debajo = debajo, llegas = llegas, kind = leg.kind, leg = leg }
	-- El marco crece con lo que dice (nada de textos que se salgan de su caja);
	-- solo el disco sigue tomando el ratón.
	local w = WIDTH
	for _, fs in ipairs({ distText, labelText, etaText }) do
		local sw = fs:IsShown() and fs.GetStringWidth and fs:GetStringWidth() or 0
		if type(sw) == "number" and sw + 12 > w then w = sw + 12 end
	end
	w = math.ceil(w)
	local h = DIAL + TEXT_H + VIAJE_ALTO
	if w ~= floor(frame:GetWidth() + 0.5) or h ~= floor(frame:GetHeight() + 0.5) then
		frame:SetSize(w, h)
		local side = (w - DIAL) / 2
		frame:SetHitRectInsets(side, side, 0, h - DIAL)
	end
	return true
end
function Arrow.Viaje() return mode == "instruction" and viajeVisto or nil end

-- Para el banco y para quien quiera saber qué dice la llegada.
function Arrow.Llegada()
	if not (llegadaVista and llegada and llegada:IsShown()) then return nil end
	local b = llegada.Siguiente
	return {
		sobre = llegada.Sobre:GetText(), accion = llegada.Accion:IsShown() and llegada.Accion:GetText() or nil,
		avance = llegada.Avance:IsShown() and llegada.Avance:GetText() or nil,
		barra = llegada.Pista:IsShown() or (llegada.Huellas ~= nil and llegada.Huellas:IsShown()) or nil,
		huellas = llegada.Huellas ~= nil and llegada.Huellas:IsShown() or nil,
		lobo = llegada.Lobo:GetTexture(), aroViejo = ring:IsShown() or wolfPaw:IsShown() or skinRing:IsShown() or nil,
		siguiente = b ~= nil and b:IsShown() or nil, clicable = b ~= nil and b:IsShown() and b:IsMouseEnabled() or nil,
		seVa = llegada.alfaQueda ~= math.huge or nil,
		nota = llegada.Nota ~= nil and llegada.Nota:IsShown() and llegada.Nota:GetText() or nil, -- 1.3.3
		piedra = piedraVista or nil, -- 1.3.1: se desvanece sola (sin avance que contar)
	}
end

-- 1.3.7: el marco de la placa mientras se ve (para que el anuncio de zona,
-- Kit/Anuncio.lua, salga en orden: espera o va debajo de ella, nunca encima).
function Arrow.PlacaMarco()
	if llegadaVista and llegada and llegada:IsShown() and not llegada.alfaOculta then return llegada end
	return nil
end

local function setMode(m)
	if m == mode then return end
	mode = m
	viajeVisto, viajeCuando = nil, nil -- Alfa 1.3.8: el viaje se vuelve a pintar entero
	quitarTarjeta() -- Alfa 1.3.9: la tarjeta del viaje vuelve a pintarse si sigue
	if floor(frame:GetWidth() + 0.5) ~= WIDTH or floor(frame:GetHeight() + 0.5) ~= DIAL + TEXT_H then frame:SetSize(WIDTH, DIAL + TEXT_H) end
	if not (m == "arrived" or m == "search" or m == "instruction") then quitarLlegada() end
	local travel, done, act = m == "travel", m == "arrived" or m == "search", m == "instruction"
	dial:SetShown(travel or done or act)
	grabArea(travel or done or act)
	showArrow(travel)
	local skinDone = showSkinArrival(done)
	ring:SetShown(done and not skinDone)
	wolfPaw:SetShown(done and style == "lobo")
	halo:SetShown((done and not skinDone) or act)
	legIcon:SetShown(act)
	lastYards, lastEta = nil, nil
	lastDist, closeSpeed = nil, 0
	etaText:Hide()
	if done then
		pulse = 0
		local r, g, b = Nav.RGB("arrowNear")
		ring:SetVertexColor(r, g, b, 1)
		halo:SetVertexColor(r, g, b, 0.5)
		skinRing:SetVertexColor(r, g, b, 1)
		skinCheck:SetVertexColor(r, g, b, 1)
		wolfPaw:SetVertexColor(r, g, b, 1)
		skinDisc:SetVertexColor(0.031, 0.024, 0.016, 0.45)
		wolfPaw:SetSize(DIAL * 0.5, DIAL * 0.5)
		wolfPaw:SetAlpha(1)
		-- Alfa 1.3.7c: quien quiera festejar la llegada (Lya da un brinco).
		if m == "arrived" and ns.Fire then ns.Fire("ALFA_LLEGADA", Nav.GetTarget()) end
		-- Alfa 1.2.9: la llegada de La Jauría (pintarLlegada); sin el Kit, la de antes.
		if not pintarLlegada(m) then
			distText:SetTextColor(Nav.RGB("arrowNearText"))
			-- An area objective is never done by standing somewhere: look around,
			-- then move on (a click on the arrow, or the next spot comes up by itself).
			distText:SetText(m == "search" and L["Search here"] or L["Arrived"])
			if m == "search" then
				etaColor()
				etaText:SetText(L["Click the arrow for the next spot"])
				etaText:Show()
			end
		end
	elseif m == "far" then
		local r, g, b = Nav.RGB("place")
		distText:SetTextColor(r, g, b, 1)
		distText:SetText(Nav.GetTargetZoneName() or L["Unknown zone"])
		etaColor()
		etaText:SetText(L["On another continent"])
		etaText:Show()
	elseif m == "nopos" then
		-- Nothing to point at or measure; the label (target or route leg) stays.
		distText:SetTextColor(Nav.RGB("textDim"))
		distText:SetText(L["No position here"])
	elseif act then
		-- Act here: "Fly to Lakeshire", "Take the zeppelin to Undercity", "Hearth to Goldshire".
		local T = Nav.travel
		local leg = T and T.CurrentLeg and T.CurrentLeg()
		-- Alfa 1.3.3: el tramo de la piedra, en la placa de La Jauría.
		if leg and leg.kind == "hearth" and pintarPiedra(leg) then return end
		quitarLlegada()
		legIcon:SetTexture(UI_MEDIA .. (leg and LEG_ICON[leg.kind] or "icon-goto"))
		local r, g, b = Nav.RGB("arrow")
		legIcon:SetVertexColor(r, g, b, 1)
		halo:SetVertexColor(r, g, b, 0.45)
		distText:SetTextColor(Nav.RGB("arrowText"))
		distText:SetText(T and T.CurrentLabel() or "")
		local target = Nav.GetTarget()
		ponerMeta(target and target.label or "")
		etaColor()
	else
		distText:SetTextColor(Nav.RGB("text"))
		etaColor()
		local T = Nav.travel
		if T and T.Active() then ponerMeta(routeLabel(T)) end
	end
end

local nearShown -- the skins' darts: whether the arrival colour is on

local function tint(r, g, b)
	tintR, tintG, tintB = r, g, b
	body:SetVertexColor(r, g, b, 1)
	glow:SetVertexColor(r, g, b, 0.45)
	sheet:SetVertexColor(r, g, b, 1)
	wolf:SetVertexColor(r, g, b, 1)
	-- El contorno del lobo: la sombra del tema, casi opaca, para que se lea
	-- sobre la nieve o el pasto en los tres estilos.
	local sr, sg, sb = Nav.RGB("shade")
	wolfEdge:SetVertexColor(sr, sg, sb, 0.82)
	if skinStyle() then
		-- Hearth's far dart is its baked gold, unless the player picked
		-- their own arrow colour; up close (and Halo's always) it is tinted.
		local own = type(ns.Get("nav.arrowColor")) == "table"
		local gold = style == "hearth" and not nearShown and not own
		dart:SetTexture(UI_DIR .. (gold and "dart-gold" or "dart"))
		if gold then dart:SetVertexColor(1, 1, 1, 1) else dart:SetVertexColor(r, g, b, 1) end
		local e = EDGE[style == "halo" and (nearShown and "haloNear" or "halo") or "hearth"]
		dartEdge:SetVertexColor(e[1], e[2], e[3], 1)
	end
end

-- The far colour away, the near colour up close; smoothstep over CLOSE_RANGE.
local function applyColor(dist, radius)
	if skinStyle() then
		-- The skins' darts: the far colour, then the arrival colour within 40 m.
		nearShown = dist <= DART_NEAR
		tint(Nav.RGB(nearShown and "arrowNear" or "arrow"))
		return
	end
	local t = 1 - (dist - radius) / CLOSE_RANGE
	if t < 0 then t = 0 elseif t > 1 then t = 1 end
	t = t * t * (3 - 2 * t)
	local ar, ag, ab = Nav.RGB("arrow")
	local sr, sg, sb = Nav.RGB("arrowNear")
	tint(ar + (sr - ar) * t, ag + (sg - ag) * t, ab + (sb - ab) * t)
end

-- nav.arrowStyle changed: swap textures in place, keeping heading and colour.
local function applyStyle(new)
	if new == style then return end
	style = new
	shownFrame = -1
	showArrow(mode == "travel")
	setRotation(curAngle)
	tint(tintR, tintG, tintB)
end

-- Shortest Path Forever's own arrow guides while the target is handed to it (Nav/Handoff.lua),
-- TomTom's while it is used and can point at the target (Nav.TomTomArrowGuides). Hiding
-- Polestar takes it unless the arrow is kept (ns.ArrowHidden).
local function shouldShow()
	return ns.Get("nav.arrow") and not ns.ArrowHidden() and not Nav.HiddenWithGuide() and Nav.GetTarget() ~= nil
		and not Nav.TomTomArrowGuides() and not Nav.HandedOff()
end

-- Alfa 1.3.7: los tiempos como en todo Alfa (N.Duracion: «1 h 13 min»,
-- «4 min 10 s»), no «73:05» (agente Rutas, ítems 101-102).
local function duracion(secs)
	local Nu = rawget(_G, "AlfaNucleo")
	-- 1.3.9 (74): igual que el rastreador, Hoy y el Escritorio: al segundo en
	-- los últimos dos minutos, redondo antes («12 min», no «12 min 07 s»).
	if type(Nu) == "table" and type(Nu.Duracion) == "function" then return Nu.Duracion(secs, secs >= 120) end
	return ("%d:%02d"):format(floor(secs / 60), secs % 60)
end

local function showSeconds(secs)
	secs = floor(secs + 0.5)
	if secs ~= lastEta then
		lastEta = secs
		etaText:SetText(ns.T("%s en total"):format(duracion(secs)))
	end
	etaText:Show()
end

-- The label line follows the route: the current leg's instruction while a
-- route is active, the target's label otherwise. A walk entering the other
-- faction's towns says so once, as it starts (Travel.TakeWarning), for
-- WARN_SECONDS: under the step, or under the target's label when the walk
-- is the whole route.
local function syncLabel(T, routed)
	local leg = not routed and T ~= nil and T.CurrentLeg and T.CurrentLeg()
	local lone = leg and leg.kind == "walk" or false
	if warning and (not (routed or lone) or GetTime() >= warnUntil) then
		warning = nil
		routeSeen = -2
	end
	if routed then
		if T.version ~= routeSeen then
			routeSeen = T.version
			local w = T.TakeWarning and T.TakeWarning()
			if w then warning, warnUntil = w, GetTime() + WARN_SECONDS end
			-- 1.4.0: en el muelle (o con el maestro de vuelo) Travel sube su
			-- versión cada segundo por la cuenta de la salida. Antes eso volvía a
			-- armar el modo (setMode quitaba la tarjeta y la volvía a meter con su
			-- entrada): la tarjeta parpadeaba sin parar. El mismo tramo se
			-- repinta en su lugar; solo otro tramo (o la piedra) arma el modo.
			local leg = mode == "instruction" and T.CurrentLeg and T.CurrentLeg()
			if leg and leg.kind ~= "hearth" and Arrow.PL.tramo == Arrow.PL.claveTramo(leg) then
				viajeVisto, viajeCuando = nil, nil
				distText:SetText(T.CurrentLabel and T.CurrentLabel() or "")
				local target = Nav.GetTarget()
				ponerMeta(target and target.label or "")
			else
				ponerMeta(routeLabel(T))
				if mode == "instruction" then mode = nil end
			end
		end
		return
	end
	if lone and T.version ~= loneSeen then
		loneSeen = T.version
		local w = T.TakeWarning and T.TakeWarning()
		if w then warning, warnUntil, routeSeen = w, GetTime() + WARN_SECONDS, -2 end
	end
	if routeSeen ~= -1 then
		routeSeen = -1
		local target = Nav.GetTarget()
		local text = withTargetWarning(target and target.label or "")
		if warning then text = text ~= "" and (text .. "\n" .. warning) or warning end
		ponerMeta(text)
	end
end

-- One world sample; returns false when the arrow has hidden itself.
local function sample(elapsed)
	if not shouldShow() then
		frame:Hide()
		return false
	end
	local state, dist, angle, _, _, measured = Nav.Sample()
	if Nav.IsHiddenState(state) then
		frame:Hide()
		return false
	end
	local hint = state == "travel" and Nav.FloorHint and Nav.FloorHint() or nil
	if hint ~= floorShown then
		floorShown = hint
		if hint then
			floorIcon:SetTexture(UI_MEDIA .. (hint == "up" and "chevron-up" or "chevron-down"))
			floorIcon:SetVertexColor(Nav.RGB("text"))
		end
		floorIcon:SetShown(hint ~= nil)
	end
	local T = Nav.travel
	local routed = T ~= nil and T.Active() or false
	syncLabel(T, routed)
	if state == "far" or state == "arrived" or state == "search" or state == "nopos" then
		setMode(state)
		return true
	end
	if state == "instruction" then
		-- Alfa 1.3.3: otro tramo con el mismo modo (la piedra y luego un vuelo):
		-- se vuelve a mirar, para que la placa de la piedra no se quede.
		local leg = T and T.CurrentLeg and T.CurrentLeg()
		local esPiedra = leg ~= nil and leg.kind == "hearth"
		if mode == "instruction" and esPiedra ~= piedraVista then mode = nil end
		setMode("instruction")
		Arrow.PL.tramo = Arrow.PL.claveTramo(leg) -- 1.4.0: el tramo que pinta el modo (syncLabel)
		if piedraVista then etaText:Hide() return true end
		local secs = showEta and T.Remaining(nil)
		-- Alfa 1.3.8: un viaje (barco, zepelín, tranvía, portal, vuelo), a la manera de Alfa.
		if pintarViaje(leg, secs or nil) then return true end
		if secs then showSeconds(secs) else etaText:Hide() end
		return true
	end

	setMode("travel")
	if angle then
		local f = facing()
		local bearing = f and wrap(angle + f) or angle
		if not hasAngle or byBearing ~= (f ~= nil) then
			byBearing = f ~= nil
			curBearing, hasAngle = bearing, true
			curAngle = angle
			setRotation(curAngle)
		end
		goalAngle = bearing
	end

	local yards = floor(dist + 0.5)
	if yards ~= lastYards then
		lastYards = yards
		distText:SetText(ns.FormatDistance(yards))
	end
	local target = Nav.GetTarget()
	applyColor(dist, target and target.r or Nav.DEFAULT_RADIUS)

	-- Alfa 1.3.9: caminando a un muelle, la tarjeta del viaje debajo de la
	-- flecha (con la flecha mínima, no: solo la flecha y la distancia).
	if routed and not minimo and pintarCamino(T, dist) then return true end
	if tarjetaVista then quitarTarjeta() end

	if showEta then
		if routed then
			-- Whole-route time: legs ahead plus this walk (`measured`: dist is along a path).
			local secs = T.Remaining(dist, measured)
			if secs then showSeconds(secs) else etaText:Hide() end
			return true
		end
		-- Only timed samples move the reference point: an out-of-band Refresh
		-- (sample(0)) would otherwise shorten the next interval's distance
		-- without shortening its time, underestimating the closing speed.
		if elapsed > 0 then
			if lastDist then
				local v = (lastDist - dist) / elapsed
				closeSpeed = closeSpeed + (v - closeSpeed) * min(1, elapsed * 2)
			end
			lastDist = dist
		end
		if closeSpeed > 1.5 then
			local secs = floor(dist / closeSpeed + 0.5)
			if secs ~= lastEta then
				lastEta = secs
				etaText:SetText(duracion(secs)) -- Alfa 1.3.7
			end
			etaText:Show()
		elseif dist >= Arrow.ESTIMA_DESDE then
			-- Alfa 1.3.7c: parado (o yendo a otro lado), un estimado en línea
			-- recta a tu paso: a pie o montado. Así se sabe si queda lejos
			-- antes de echar a correr.
			local m = IsMounted and IsMounted() -- (sin probarlo antes de saber si es secreto)
			local montado = not (issecretvalue and issecretvalue(m)) and m == true
			local secs = floor(dist / (montado and Arrow.PASO_MONTADO or Arrow.PASO_A_PIE) + 0.5)
			local clave = (montado and 1e7 or 0) + secs
			if clave ~= lastEta then
				lastEta = clave
				etaText:SetText(ns.T(montado and "≈ %s montado" or "≈ %s a pie"):format(duracion(secs)))
			end
			etaText:Show()
		else
			lastEta = nil
			etaText:Hide()
		end
	end
	return true
end

-- Alfa 1.3.9 (72): la flecha mínima. Solo la flecha (o lo que hay que hacer:
-- la tarjeta del viaje, la placa de llegada) y la distancia: ni la meta, ni
-- el tiempo, ni la cuenta de una misión con tiempo, ni la tarjeta del camino
-- al muelle.
local muestraCompleta = sample
sample = function(elapsed)
	local sigue = muestraCompleta(elapsed)
	if sigue and minimo and (mode == "travel" or mode == "far" or mode == "nopos") then
		labelText:Hide()
		etaText:Hide()
		timerText:Hide()
	end
	return sigue
end
function Arrow.Minimo() return minimo end

---------------------------------------------------------------------------
-- Alfa 1.4.0 (2): la flecha nunca queda detrás de una ventana de Alfa. En la
-- captura de Toxic la ventana de Bolsas tapaba media meta. Cuatro veces por
-- segundo (solo mientras la flecha se ve) se mira si lo que dice la flecha
-- se encima con una ventana de Alfa a la vista; si sí, la flecha sube a la
-- capa de arriba de esa ventana y su texto lleva una placa oscura debajo
-- para leerse sobre la ventana. Al quitarse la ventana, vuelve a su capa.
-- Solo el disco toma el ratón (como siempre): el texto encima no atrapa
-- clics de la ventana. Las ventanas de diálogo (capa DIALOG y arriba) mandan:
-- la flecha nunca las tapa.
--   Nav.VentanasDeAlfa[#+1] = marco   otra ventana que la flecha no debe quedar debajo
--   Arrow.Encima() -> nombre de la ventana | nil, capa de la flecha
---------------------------------------------------------------------------
local revisarEn, evitarVentanas = 0, nil
do
local CAPA_NUM = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4 }
local CAPA_DE = { "LOW", "MEDIUM", "HIGH", "DIALOG" } -- [n] = la de arriba de la capa n
local CAPA_PROPIA = "MEDIUM"
local VENTANAS_ALFA = { "AlfaBolsasVentana", "AlfaBolsasBanco", "AlfaGuideFrame", "AlfaWelcome", "AlfaWhatsNew",
	"AlfaRastreador", "AlfaEscritorioMarco", "AlfaMazmorrasResumen", "AlfaCombateMedidor" }
Nav.VentanasDeAlfa = Nav.VentanasDeAlfa or {}
local encima, encimaNombre -- la ventana que la flecha tiene debajo ahora
-- 1.4.0 (revisión): subida encima de una ventana de Alfa, la flecha no toma
-- el ratón: el disco quedaría sobre casillas y botones de esa ventana, y un
-- clic en una bolsa movería la flecha. Al bajar vuelve lo que pidió el resto
-- de la flecha (quiereRaton: el último EnableMouse de este archivo).
local ponerRaton = frame.EnableMouse
local quiereRaton = frame:IsMouseEnabled() and true or false
frame.EnableMouse = function(self, on)
	quiereRaton = on and true or false
	return ponerRaton(self, quiereRaton and encima == nil)
end
local respaldo = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
respaldo:Hide()

-- Un rectángulo en píxeles de pantalla: izq, abajo, der, arriba.
local function caja(r, e)
	if not (r and r.IsVisible and r:IsVisible()) then return nil end
	local ok, l, b, w, h = pcall(r.GetRect, r)
	l, b, w, h = tonumber(l), tonumber(b), tonumber(w), tonumber(h)
	if not (ok and l and b and w and h) or w <= 0 or h <= 0 then return nil end
	return l * e, b * e, (l + w) * e, (b + h) * e
end

local function unir(a, l, b, r, t)
	if not l then return a end
	if not a then return { l, b, r, t } end
	if l < a[1] then a[1] = l end
	if b < a[2] then a[2] = b end
	if r > a[3] then a[3] = r end
	if t > a[4] then a[4] = t end
	return a
end

-- Lo que la flecha enseña (el disco, sus textos, la placa o la tarjeta).
local function cajaFlecha()
	local e = tonumber(frame:GetEffectiveScale()) or 1
	local a
	if dial:IsShown() then a = unir(a, caja(dial, e)) end
	for _, fs in ipairs({ distText, timerText, labelText, etaText }) do
		if fs:IsShown() and (fs:GetText() or "") ~= "" then a = unir(a, caja(fs, e)) end
	end
	if llegada and llegada:IsShown() then a = unir(a, caja(llegada, e)) end
	if tarjeta and tarjeta:IsShown() then a = unir(a, caja(tarjeta, e)) end
	return a
end

local function candidatas(fn)
	for _, n in ipairs(VENTANAS_ALFA) do
		local v = rawget(_G, n)
		if type(v) == "table" then fn(v, n) end
	end
	local Nu = rawget(_G, "AlfaNucleo")
	local K = type(Nu) == "table" and rawget(Nu, "Kit")
	local lista = type(K) == "table" and rawget(K, "VENTANAS")
	if type(lista) == "table" then
		for _, v in ipairs(lista) do fn(v, v.alfaNombre or (v.GetName and v:GetName())) end
	end
	for _, v in ipairs(Nav.VentanasDeAlfa) do fn(v, v.GetName and v:GetName()) end
end

local function pintarRespaldo(on)
	-- La placa y la tarjeta ya traen su panel.
	on = on and not (llegada and llegada:IsShown()) and not (tarjeta and tarjeta:IsShown())
	if not on then respaldo:Hide() return end
	local w, arriba, abajo = 0, nil, nil
	for _, fs in ipairs({ distText, timerText, labelText, etaText }) do
		if fs:IsShown() and (fs:GetText() or "") ~= "" then
			local sw = tonumber(fs:GetStringWidth()) or 0
			if sw > w then w = sw end
			arriba = arriba or fs
			abajo = fs
		end
	end
	if not arriba then respaldo:Hide() return end
	local r, g, b = Nav.RGB("shade")
	respaldo:SetColorTexture(r, g, b, 0.78)
	respaldo:ClearAllPoints()
	respaldo:SetPoint("TOP", arriba, "TOP", 0, 5)
	respaldo:SetPoint("BOTTOM", abajo, "BOTTOM", 0, -5)
	respaldo:SetWidth(math.ceil(w) + 20)
	respaldo:Show()
end

-- Lo que dice la flecha es más ancho (LABEL_WIDTH) y más alto (dos renglones,
-- la cuenta de una misión con tiempo) que su marco: el marco se sujeta a la
-- pantalla contando todo su texto, para que nada quede fuera arriba, abajo ni
-- a los lados. (La placa y la tarjeta ponen lo suyo.)
local function sujetarTexto()
	if not frame.SetClampRectInsets then return end
	if (llegada and llegada:IsShown()) or (tarjeta and tarjeta:IsShown()) then return end
	local lado = math.max(0, (LABEL_WIDTH - WIDTH) / 2)
	local abajo = 0
	local fb = tonumber(frame:GetBottom())
	if fb then
		for _, fs in ipairs({ distText, timerText, labelText, etaText }) do
			if fs:IsShown() and (fs:GetText() or "") ~= "" then
				local b = tonumber(fs:GetBottom())
				if b and fb - b > abajo then abajo = fb - b end
			end
		end
	end
	frame:SetClampRectInsets(-lado, lado, 0, -math.ceil(abajo))
end
Arrow.SujetarTexto = sujetarTexto

function evitarVentanas()
	sujetarTexto()
	local mia = cajaFlecha()
	local capa, cual, nombre = 0, nil, nil
	if mia then
		candidatas(function(v, n)
			if v == frame or not (v.IsVisible and v:IsVisible()) then return end
			local cv = CAPA_NUM[v.GetFrameStrata and v:GetFrameStrata() or ""]
			if not cv then return end -- DIALOG y arriba: esa ventana manda
			local l, b, r, t = caja(v, tonumber(v:GetEffectiveScale()) or 1)
			if not l or l >= mia[3] or r <= mia[1] or b >= mia[4] or t <= mia[2] then return end
			if cv > capa then capa, cual, nombre = cv, v, n end
		end)
	end
	local quiero = cual and CAPA_DE[capa] or CAPA_PROPIA
	if (CAPA_NUM[quiero] or 5) < (CAPA_NUM[CAPA_PROPIA] or 3) then quiero = CAPA_PROPIA end
	if frame:GetFrameStrata() ~= quiero then frame:SetFrameStrata(quiero) end
	local antes = encima
	encima, encimaNombre = cual, cual and (nombre or "?") or nil
	if (antes == nil) ~= (cual == nil) then ponerRaton(frame, quiereRaton and cual == nil) end
	pintarRespaldo(cual ~= nil)
end
Arrow.EvitarVentanas = evitarVentanas
function Arrow.Encima() return encimaNombre, frame:GetFrameStrata(), respaldo:IsShown() or nil end
function Arrow.TomaRaton() return frame:IsMouseEnabled() and true or false, quiereRaton end
end
local REVISAR = 0.25

frame:SetScript("OnUpdate", ns.Safe(function(_, elapsed)
	accum = accum + elapsed
	if accum >= SAMPLE_INTERVAL then
		local step = accum
		accum = 0
		if not sample(step) then return end
	end
	revisarEn = revisarEn - elapsed
	if revisarEn <= 0 then
		revisarEn = REVISAR
		evitarVentanas()
	end
	if mode == "travel" and hasAngle then
		local diff = wrap(goalAngle - curBearing)
		if abs(diff) > 1e-4 then
			local step = diff * (1 - exp(-elapsed * DAMPING))
			local cap = MAX_TURN * elapsed
			if step > cap then step = cap elseif step < -cap then step = -cap end
			curBearing = wrap(curBearing + step)
		end
		local f = byBearing and facing()
		local shown = f and wrap(curBearing - f) or curBearing
		if abs(wrap(shown - curAngle)) > 1e-4 then
			curAngle = shown
			setRotation(curAngle)
		end
	elseif (mode == "arrived" or mode == "search") and skinStyle() then
		pulse = pulse + elapsed
		if pulse >= SKIN_CHECK_AFTER and not llegadaVista and not skinCheck:IsShown() then skinCheck:Show() end
	elseif (mode == "arrived" or mode == "search") and not llegadaVista then
		-- (1.3.1: con la placa de Alfa el aro viejo está oculto: no se anima)
		pulse = pulse + elapsed
		local s = 1 + 0.06 * sin(pulse * 4)
		ring:SetSize(DIAL * s, DIAL * s)
		halo:SetAlpha(0.35 + 0.25 * (0.5 + 0.5 * sin(pulse * 4)))
		-- La huella del lobo late suave, más lento que el aro (1.2.9).
		if style == "lobo" then
			local h = 0.5 + 0.5 * sin(pulse * 2.4)
			local ps = DIAL * 0.5 * (1 + 0.05 * h)
			wolfPaw:SetSize(ps, ps)
			wolfPaw:SetAlpha(0.8 + 0.2 * h)
		end
	end
end))

frame:SetScript("OnShow", function()
	accum, hasAngle = 0, false
	revisarEn = 0 -- (1.4.0) lo primero: ¿hay una ventana de Alfa debajo?
end)

---------------------------------------------------------------------------
-- Moving, settings
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Alfa 1.4.0 (33): la flecha de cada personaje. Con nav.flechaPorPersonaje
-- (de fábrica, sí) el lugar, el tamaño y si la escondiste se guardan en este
-- personaje (AlfaCharDB.flecha) y se ponen al entrar: tu cazador la tiene
-- arriba y grande, tu sacerdote abajo y escondida. Un personaje que nunca la
-- tocó usa la de la cuenta, como antes. «Restablecer» la flecha también la
-- olvida en el personaje.
---------------------------------------------------------------------------
do
local PROPIOS = { ["nav.arrowPos"] = "pos", ["nav.arrowScale"] = "escala", ["nav.arrow"] = "ver", ["nav.placasPos"] = "placas" }
local poniendo = false
local function flechaPropia(crear)
	if not ns.Get("nav.flechaPorPersonaje") then return nil end
	local s = ns.CharState and ns.CharState()
	if type(s) ~= "table" then return nil end
	if type(s.flecha) ~= "table" then
		if not crear then return nil end
		s.flecha = {}
	end
	return s.flecha
end
local function copia(v)
	if type(v) ~= "table" then return v end
	local o = {}
	for k, x in pairs(v) do o[k] = x end
	return o
end
function Arrow.Propia() return flechaPropia(false) end

-- Al entrar: lo de este personaje manda.
function Arrow.PonerPropia()
	local f = flechaPropia(false)
	if not f then return false end
	poniendo = true
	for ruta, campo in pairs(PROPIOS) do
		local v = f[campo]
		if v ~= nil then
			if v == "nada" then v = nil end
			local ahora = ns.Get(ruta)
			local igual = ahora == v
			if type(v) == "table" and type(ahora) == "table" then
				igual = v.point == ahora.point and v.relPoint == ahora.relPoint and v.x == ahora.x and v.y == ahora.y
			end
			if not igual then pcall(ns.Set, ruta, copia(v)) end
		end
	end
	poniendo = false
	return true
end

ns.On("SETTING_CHANGED", function(path, value)
	if poniendo then return end
	local campo = PROPIOS[path]
	if campo then
		local f = flechaPropia(true)
		-- (sin lugar guardado: «nada», para no volver al de la cuenta)
		if f then f[campo] = value == nil and "nada" or copia(value) end
	elseif path == "nav" or path == "" then
		local f = flechaPropia(false)
		if f then for _, c in pairs(PROPIOS) do f[c] = nil end end
	end
end)
if ns.OnLogin then ns.OnLogin(function() Arrow.PonerPropia() end) end
end

local function applyPosition()
	frame:ClearAllPoints()
	local pos = ns.Get("nav.arrowPos")
	if type(pos) == "table" and type(pos.point) == "string" then
		frame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, tonumber(pos.x) or 0, tonumber(pos.y) or 0)
	else
		frame:SetPoint("TOP", UIParent, "TOP", 0, -140)
	end
end

function Nav.ResetArrowPosition()
	ns.Set("nav.arrowPos", nil)
end

local moving = false
frame:SetScript("OnDragStart", function(self)
	if ns.DragLocked() then return end
	moving = true
	self:StartMoving()
end)

frame:SetScript("OnDragStop", function(self)
	if not moving then return end
	moving = false
	self:StopMovingOrSizing()
	local point, _, relPoint, x, y = self:GetPoint(1)
	if point then ns.Set("nav.arrowPos", { point = point, relPoint = relPoint, x = x, y = y }) end
end)

frame:SetScript("OnEnter", function(self)
	mover:SetShown(not ns.DragLocked())
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
	GameTooltip:SetText(L["Alfa arrow"])
	GameTooltip:AddLine(ns.Get("ui.lockHud") and L["Shift-drag to move."] or L["Drag to move."], Nav.RGB("text"))
	if hayOtroLugar() then GameTooltip:AddLine(L["Click for the next spot."], Nav.RGB("text")) end
	-- 1.4.0 (2): la meta entera, si en la flecha va acortada.
	if Meta.entera ~= "" and Meta.entera ~= Meta.mostrada and labelText:IsShown() then
		GameTooltip:AddLine(" ")
		local r, g, b = Nav.RGB("text")
		GameTooltip:AddLine(Meta.entera, r, g, b, true)
	end
	GameTooltip:Show()
end)

frame:SetScript("OnLeave", function()
	mover:Hide()
	GameTooltip:Hide()
end)

-- A click (not a drag) on an area objective's arrow moves on to its next spot.
local dragged = false
frame:SetScript("OnMouseDown", function() dragged = false end)
frame:HookScript("OnDragStart", function() dragged = true end)
frame:SetScript("OnMouseUp", function(_, button)
	if button == "LeftButton" and not dragged then irOtroLugar() end
end)

local function clamp(v, lo, hi, default)
	v = tonumber(v) or default
	return min(hi, max(lo, v))
end

function Arrow:OnSettings()
	frame:SetScale(clamp(ns.Get("nav.arrowScale"), 0.5, 2, 1))
	frame:SetAlpha(clamp(ns.Get("nav.arrowAlpha"), 0.1, 1, 1))
	lastYards = nil -- nav.distanceUnit: redraw the distance on the next sample
	showEta = ns.Get("nav.arrowEta") and true or false
	if not showEta and mode == "travel" then etaText:Hide() end
	-- Alfa 1.3.9: la flecha mínima (solo la flecha y la distancia).
	local antes = minimo
	minimo = ns.Get("nav.arrowMinimo") and true or false
	if antes ~= minimo then
		routeSeen, mode = -2, nil
		if not minimo then labelText:Show() end
	end
	applyStyle(Arrow.StyleFor(ns.Get("nav.arrowStyle")))
	applyPosition()
	-- 1.4.0 (78): el ancla de las placas, en la escala de la flecha.
	Arrow.PL.ancla:SetScale(frame:GetScale() or 1)
	Arrow.PL.poner()
	self:Refresh()
end

-- The style a setting stands for: "skin" takes the skin's.
function Arrow.StyleFor(v)
	if v == "skin" or v == nil then
		local Theme = ns.Theme
		return SKIN_ARROW[Theme and Theme.SkinKey and Theme.SkinKey() or "alfa"] or "3d"
	end
	if v == "flat" or v == "halo" or v == "hearth" or v == "lobo" then return v end
	return "3d"
end

-- The countdown line (timerText): while a timed quest's timer runs, the
-- countdown of the arrow's target's quest, else of the timer that ends
-- first (a "Fly to" or a walk on the way to a delivery's hand-in has no
-- quest of its own), as Timed.Countdown words and colours it. Set on
-- QUEST_TIMER (each second a timer runs, once when the last one stops) and
-- on a new target; no work of its own per frame.
local timerShown -- the countdown on screen, or nil
local function syncTimer()
	local T = ns.Timed
	local text
	if T then
		local target = Nav.GetTarget()
		local q = target and target.quest
		text = q and T.Countdown(q)
		if not text then
			q = T.Soonest()
			text = q and T.Countdown(q)
		end
	end
	if text == timerShown then return end
	local was = timerShown ~= nil
	timerShown = text
	if text then timerText:SetText(text) end
	if was ~= (text ~= nil) then
		timerText:SetShown(text ~= nil and not (minimo and mode == "travel"))
		labelText:ClearAllPoints()
		labelText:SetPoint("TOP", text and timerText or distText, "BOTTOM", 0, -5)
	end
end
Arrow.SyncTimer = syncTimer
ns.On("QUEST_TIMER", syncTimer)

function Arrow:OnTheme()
	applyStyle(Arrow.StyleFor(ns.Get("nav.arrowStyle")))
	if skinStyle() then
		-- The handoff's arrow text: distance Display 20, name 12, line 11.
		Nav.SetHudFont(distText, "number", 20)
		Nav.SetHudFont(labelText, "body", 12)
		Nav.SetHudFont(etaText, "small", 11)
		labelText:SetTextColor(Nav.RGB("npc"))
	else
		Nav.SetHudFont(distText, "number", 16)
		Nav.SetHudFont(labelText, "body", 12)
		Nav.SetHudFont(etaText, "small", 12)
		labelText:SetTextColor(Nav.RGB("text"))
	end
	etaColor()
	Nav.SetHudFont(timerText, "small", skinStyle() and 11 or 12)
	-- 1.4.0 (2): otra letra, otro ancho: la meta se vuelve a acomodar.
	do local e = Meta.entera Meta.entera = false ponerMeta(e) end
	-- Its colours are the theme's: set it afresh.
	timerShown = nil
	timerText:Hide()
	labelText:ClearAllPoints()
	labelText:SetPoint("TOP", distText, "BOTTOM", 0, -5)
	syncTimer()
	mover:SetColorTexture(Nav.Wash("mover"))
	local m = mode
	mode = nil
	if m then setMode(m) end
	-- La flecha cambia de estilo con el estilo de Alfa ("skin"): el lobo
	-- vuelve a mostrarse si iba en camino.
	if mode == "travel" then showArrow(true) end
end

function Arrow:OnTarget(target)
	ponerMeta(target and target.label or "")
	mode, hasAngle, routeSeen, loneSeen, warning = nil, false, -1, -1, nil
	-- 1.4.0 (69): otro destino, las tarjetas cerradas vuelven a salir.
	for k in pairs(Arrow.cerradas) do Arrow.cerradas[k] = nil end
	if tarjeta then tarjeta.alfaBordo = nil end
	-- 1.3.1: sin destino, la llegada se olvida (el siguiente sale entero).
	if not target and llegada then llegada.alfaFirma = nil end
	syncTimer()
	self:Refresh()
end

-- Show/hide from outside OnUpdate (target change, events, ticker).
function Arrow:Refresh()
	if frame:IsShown() then
		sample(0)
	elseif shouldShow() then
		local state = Nav.Sample()
		if not Nav.IsHiddenState(state) then
			frame:Show()
			sample(0)
		end
	end
end

-- The catch-up (the guide window's CATCH_UP): the hourglass in the dial's
-- place, or the arrow back.
function Arrow.SetBusy(on)
	on = on and true or false
	if on == glass:IsShown() then return end
	if on then
		glassTime = 0
		glassBody:SetVertexColor(Nav.RGB("text"))
		glassSand:SetVertexColor(Nav.RGB("arrow"))
	end
	glass:SetShown(on)
	local a = on and 0 or 1
	dial:SetAlpha(a)
	distText:SetAlpha(a)
	labelText:SetAlpha(a)
	if llegada then llegada.alfaVisible = a llegada:SetAlpha(a) end
	etaText:SetAlpha(a)
	timerText:SetAlpha(a)
end

function Arrow.IsBusy()
	return glass:IsShown()
end

ns.On("CATCH_UP", function(on) Arrow.SetBusy(on) end)

-- La llegada al día (1.2.9): el avance cambia mientras estás ahí («4 de 6»
-- -> «5 de 6») y el botón «Siguiente lugar» toma el ratón solo fuera de combate.
-- 1.3.1: si la placa ya se fue, solo vuelve cuando lo que dice cambió.
local function llegadaAlDia()
	if llegadaVista and (mode == "arrived" or mode == "search") and frame:IsShown() then pintarLlegada(mode) end
	-- 1.3.3: la placa de la piedra, al día (la recarga, lo que falta, otra ruta).
	if piedraVista and mode == "instruction" and frame:IsShown() then
		local T = Nav.travel
		local leg = T and T.CurrentLeg and T.CurrentLeg()
		if leg and leg.kind == "hearth" then pintarPiedra(leg) end
	end
end
Arrow.LlegadaAlDia = llegadaAlDia
ns.On("STEP_UPDATED", llegadaAlDia)
ns.On("ROUTE_CHANGED", function() llegadaAlDia() end) -- 1.3.3: la placa de la piedra
-- 1.3.1: la bandera de la pelea (ver `pelea`, arriba de la placa).
ns.RegisterEvent("PLAYER_REGEN_DISABLED", function() pelea = true llegadaAlDia() end)
ns.RegisterEvent("PLAYER_REGEN_ENABLED", function() pelea = false llegadaAlDia() end)
ns.RegisterEvent("PLAYER_XP_UPDATE", llegadaAlDia)
Arrow.EnPelea = enCombate -- (para el banco)

function Arrow.GetMode()
	return frame:IsShown() and mode or nil
end

function Arrow.GetAngle()
	return curAngle
end

function Arrow.GetStyle()
	return style
end

-- Sheet frame on screen in the 3D style (nil in the flat style).
function Arrow.GetFrame()
	if style ~= "3d" or shownFrame < 0 then return nil end
	return shownFrame
end

---------------------------------------------------------------------------
-- Alfa 1.4.0 (2, pista de Bolsas): Forever no vuelve a medir un texto hasta
-- que su texto cambia. Tras reiniciar los gráficos, cambiar la resolución, la
-- escala o el tamaño de UIParent (Dos pantallas) la meta, la distancia y la
-- tarjeta se quedaban con la medida vieja (encimadas o cortadas). En esos
-- casos (y 0,1 s después) cada texto de la flecha recibe otra vez su letra
-- (otro tamaño y luego el suyo) y su texto, y la meta se vuelve a acomodar.
---------------------------------------------------------------------------
do
local function remedir(fs)
	if not (fs and fs.GetFont and fs.GetText) then return end
	local f, s, fl = fs:GetFont()
	if f and s then
		pcall(fs.SetFont, fs, f, s + 1, fl or "")
		pcall(fs.SetFont, fs, f, s, fl or "")
	end
	local t = fs:GetText()
	if t ~= nil and not (issecretvalue and issecretvalue(t)) then
		fs:SetText("")
		fs:SetText(t)
	end
end

local function textosDe(marco, lista)
	if not marco then return end
	for _, r in ipairs({ marco:GetRegions() }) do
		if r.GetObjectType and r:GetObjectType() == "FontString" then lista[#lista + 1] = r end
	end
	for _, h in ipairs({ marco:GetChildren() }) do textosDe(h, lista) end
end

function Arrow.Remedir()
	local lista = {}
	textosDe(frame, lista)
	for _, fs in ipairs(lista) do remedir(fs) end
	-- La meta se acomoda con la medida nueva; la tarjeta se vuelve a pintar entera.
	local e = Meta.entera
	Meta.entera = false
	ponerMeta(e or "")
	if tarjeta then tarjeta.alfaFirma = nil end
	viajeCuando = nil
	revisarEn = 0
	if frame:IsShown() then pcall(sample, 0) end
end

local function remedirLuego()
	Arrow.Remedir()
	if ns.After then ns.After(0.1, function() Arrow.Remedir() end) end
end
for _, ev in ipairs({ "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED", "GX_RESTARTED" }) do
	ns.RegisterEvent(ev, remedirLuego)
end
if UIParent and UIParent.HookScript then UIParent:HookScript("OnSizeChanged", remedirLuego) end
-- Dos pantallas (Alfa_Bienvenida/Escritorio*.lua) avisa al mover el mundo y al volver.
ns.On("ALFA_ESCRITORIO", function() remedirLuego() end)
end

Nav.RegisterModule(Arrow)
