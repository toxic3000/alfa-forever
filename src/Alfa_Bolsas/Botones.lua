-- Alfa - Bolsas: los botones de objeto y sus marcas. GPL-3.0.
--
-- Dos clases de botón, con el mismo aspecto:
--   * En vivo (tus bolsas y tu banco abierto): ContainerFrameItemButtonTemplate
--     de Blizzard (Blizzard_UIPanels_Game Mainline/ContainerFrame.xml, el que
--     carga Forever), hijo de un marco "porta" con SetID(bolsa) y con
--     SetID(casilla) propio. Su OnClick es el de Blizzard y lee la bolsa con
--     self:GetParent():GetID() (ContainerFrameItemButtonMixin:GetBagID), así que
--     el clic derecho usa o equipa el objeto también en combate, sin
--     contaminación: Alfa nunca escribe en la tabla del botón (ni bagID, ni
--     Initialize, ni SetItemButton*), solo pinta regiones propias y oculta
--     las de Blizzard. Lo que Alfa sabe de cada botón vive en `partes`, fuera
--     del botón.
--   * De foto (el banco cerrado, otros personajes): un Button simple con el
--     cuadro del objeto (SetHyperlink) y sus clics con modificador.
--
--   B.Vivo(porta) -> botón ;  B.Foto(padre) -> botón
--   B.Medir(b, tam)          tamaño de la casilla y de sus marcas
--   B.Pintar(b, ent)         el objeto (ent = entrada de Ventana.lua) o vacío (nil)
--   B.Buscar(b, estado)      nil: sin búsqueda; true: coincide; false: atenuado
--   B.Enfriar(b, bolsa, casilla), B.Bloqueo(b, bloqueado)
--
-- Objetos de misión (los que el juego marca con GetContainerItemQuestInfo y
-- los de la clase Misión, 12): con bolsas.brilloMision, un borde del color de
-- misiones que late y una insignia «!» (llena si el objeto empieza una
-- misión); sin él, el marco dorado fijo del juego (bolsas.marcaMision). Las
-- piezas del brillo se crean solo en los botones que lo necesitan.

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local T = A.Theme

local type, pairs, ipairs, tonumber, floor, max = type, pairs, ipairs, tonumber, math.floor, math.max

local B = {}
M.Botones = B

local BLANCO = "Interface\\Buttons\\WHITE8x8"
local function media(nombre)
	if T and T.Media then
		local ok, p = pcall(T.Media, nombre)
		if ok and type(p) == "string" then return p end
	end
	return BLANCO
end

local partes = setmetatable({}, { __mode = "k" }) -- botón -> { regiones de Alfa, estado }
B.Partes = partes

-- Regiones propias de Blizzard que Alfa no usa: se ocultan una vez.
local AJENAS = { "icon", "Count", "Stock", "IconBorder", "IconOverlay", "IconOverlay2", "searchOverlay",
	"ItemContextOverlay", "IconQuestTexture", "JunkIcon", "UpgradeIcon", "NewItemTexture", "BattlepayItemTexture",
	"flash", "ExtendedSlot", "EmptyBagIcon", "BagIndicator" }

local QUEST_BORDE = "Interface\\ContainerFrame\\UI-Icon-QuestBorder"
local QUEST_BANG = "Interface\\ContainerFrame\\UI-Icon-QuestBang"

---------------------------------------------------------------------------
-- Piezas
---------------------------------------------------------------------------

-- Cuatro texturas de 1 a n píxeles por dentro del borde de `padre`.
local function marco(padre, capa, sub)
	local t = {}
	for i = 1, 4 do
		local x = padre:CreateTexture(nil, capa, nil, sub)
		x:SetTexture(BLANCO)
		t[i] = x
	end
	return t
end

local function ponerMarco(t, padre, grosor, r, g, b, a)
	local arriba, abajo, izq, der = t[1], t[2], t[3], t[4]
	arriba:ClearAllPoints(); arriba:SetPoint("TOPLEFT", padre, "TOPLEFT", 0, 0); arriba:SetPoint("TOPRIGHT", padre, "TOPRIGHT", 0, 0); arriba:SetHeight(grosor)
	abajo:ClearAllPoints(); abajo:SetPoint("BOTTOMLEFT", padre, "BOTTOMLEFT", 0, 0); abajo:SetPoint("BOTTOMRIGHT", padre, "BOTTOMRIGHT", 0, 0); abajo:SetHeight(grosor)
	izq:ClearAllPoints(); izq:SetPoint("TOPLEFT", arriba, "BOTTOMLEFT", 0, 0); izq:SetPoint("BOTTOMLEFT", abajo, "TOPLEFT", 0, 0); izq:SetWidth(grosor)
	der:ClearAllPoints(); der:SetPoint("TOPRIGHT", arriba, "BOTTOMRIGHT", 0, 0); der:SetPoint("BOTTOMRIGHT", abajo, "TOPRIGHT", 0, 0); der:SetWidth(grosor)
	for i = 1, 4 do
		t[i]:SetVertexColor(r, g, b, a)
		t[i]:Show()
	end
end

local function mostrarMarco(t, si)
	for i = 1, 4 do t[i]:SetShown(si) end
end

local function pixel(region)
	if T and T.Pixel then
		local ok, v = pcall(T.Pixel, region)
		if ok and type(v) == "number" and v > 0 then return v end
	end
	return 1
end

local function fuente(fs, tam)
	local ruta = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
	if T and T.FontSpec then
		local ok, p = pcall(T.FontSpec, "number")
		if ok and type(p) == "string" then ruta = p end
	end
	if not pcall(fs.SetFont, fs, ruta, tam, "OUTLINE") or not fs:GetFont() then
		fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", tam, "OUTLINE")
	end
end

-- El aspecto de Alfa sobre cualquier botón: pozo, icono, marcas.
local function decorar(b)
	local p = { tam = 0 }
	p.fondo = b:CreateTexture(nil, "BACKGROUND", nil, -7)
	p.fondo:SetTexture(BLANCO)
	p.fondo:SetAllPoints(b)
	p.tinte = b:CreateTexture(nil, "BACKGROUND", nil, -6)
	p.tinte:SetTexture(BLANCO)
	p.tinte:SetAllPoints(b)
	p.tinte:Hide()
	p.icono = b:CreateTexture(nil, "ARTWORK", nil, 1)
	p.icono:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	p.icono:Hide()
	p.borde = marco(b, "BORDER", 6)

	-- Las marcas van en un marco propio por encima del enfriamiento.
	local capa = CreateFrame("Frame", nil, b)
	capa:SetAllPoints(b)
	p.capa = capa
	p.calidad = marco(capa, "OVERLAY", 1)
	mostrarMarco(p.calidad, false)
	p.mision = capa:CreateTexture(nil, "OVERLAY", nil, 2)
	p.mision:SetAllPoints(p.icono)
	p.mision:Hide()
	p.nuevo = capa:CreateTexture(nil, "OVERLAY", nil, 3)
	p.nuevo:SetTexture(media("glow"))
	p.nuevo:SetBlendMode("ADD")
	p.nuevo:SetPoint("TOPLEFT", b, "TOPLEFT", -6, 6)
	p.nuevo:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 6, -6)
	p.nuevo:Hide()
	local ag = p.nuevo:CreateAnimationGroup()
	ag:SetLooping("BOUNCE")
	local a1 = ag:CreateAnimation("Alpha")
	a1:SetFromAlpha(0.25)
	a1:SetToAlpha(0.95)
	a1:SetDuration(0.9)
	if a1.SetSmoothing then a1:SetSmoothing("IN_OUT") end
	p.anim = ag
	p.mejora = capa:CreateTexture(nil, "OVERLAY", nil, 5)
	p.mejora:SetTexture(media("qol-upgrade"))
	p.mejora:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
	p.mejora:Hide()
	p.chatarra = capa:CreateTexture(nil, "OVERLAY", nil, 5)
	p.chatarra:SetTexture(media("qol-coin"))
	p.chatarra:SetPoint("TOPRIGHT", b, "TOPRIGHT", -2, -2)
	p.chatarra:Hide()
	p.nivel = capa:CreateFontString(nil, "OVERLAY")
	p.nivel:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 3, 3)
	p.nivel:SetJustifyH("LEFT")
	p.cuenta = capa:CreateFontString(nil, "OVERLAY")
	p.cuenta:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 3)
	p.cuenta:SetJustifyH("RIGHT")
	p.busca = marco(capa, "OVERLAY", 7)
	mostrarMarco(p.busca, false)
	partes[b] = p
	return p
end

-- Colores del tema en el pozo y su borde.
local function pintarPozo(b, p)
	local r, g, bb = M.Color("shade", 0, 0, 0.02)
	p.fondo:SetVertexColor(r, g, bb, 0.42)
	local br, bg, bbb, ba = 1, 1, 1, 0.09
	if T and T.Wash then
		local ok, x, y, z, w = pcall(T.Wash, "border")
		if ok and type(x) == "number" then br, bg, bbb, ba = x, y, z, w end
	end
	ponerMarco(p.borde, b, pixel(b), br, bg, bbb, ba)
end

function B.Medir(b, tam)
	local p = partes[b]
	if not p or p.tam == tam then return end
	p.tam = tam
	b:SetSize(tam, tam)
	local px = pixel(b)
	p.icono:ClearAllPoints()
	p.icono:SetPoint("TOPLEFT", b, "TOPLEFT", 2 * px, -2 * px)
	p.icono:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2 * px, 2 * px)
	local flecha = max(10, floor(tam * 0.42 + 0.5))
	p.mejora:SetSize(flecha, flecha)
	local moneda = max(9, floor(tam * 0.34 + 0.5))
	p.chatarra:SetSize(moneda, moneda)
	local letra = max(9, floor(tam * 0.30 + 0.5))
	fuente(p.nivel, letra)
	fuente(p.cuenta, letra)
	p.grosor = max(1, floor(tam / 20 + 0.5)) * px
	pintarPozo(b, p)
	p.firma = nil
end

---------------------------------------------------------------------------
-- Botones en vivo (seguros) y de foto
---------------------------------------------------------------------------

local function ocultarAjenas(b)
	for _, k in ipairs(AJENAS) do
		local r = b[k]
		if type(r) == "table" and r.Hide then r:Hide() end
	end
	local nt = b.GetNormalTexture and b:GetNormalTexture()
	if nt then nt:SetAlpha(0) end
end

function B.Vivo(porta)
	local ok, b = pcall(CreateFrame, "ItemButton", nil, porta, "ContainerFrameItemButtonTemplate")
	if not ok or not b then return nil end
	b:SetFrameLevel(porta:GetFrameLevel() + 1)
	local cd = b.Cooldown
	if type(cd) == "table" and cd.SetFrameLevel then cd:SetFrameLevel(b:GetFrameLevel() + 1) end
	ocultarAjenas(b)
	local p = decorar(b)
	p.vivo = true
	p.capa:SetFrameLevel(b:GetFrameLevel() + 3)
	if type(cd) == "table" and cd.ClearAllPoints then
		cd:ClearAllPoints()
		cd:SetAllPoints(p.icono)
	end
	return b
end

local function fotoEntrar(self)
	local p = partes[self]
	local link = p and p.ent and p.ent.rec and p.ent.rec.l
	if type(link) ~= "string" or not GameTooltip then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	local hl = link:match("|H(.-)|h") or link
	if not pcall(GameTooltip.SetHyperlink, GameTooltip, hl) then
		GameTooltip:SetText(link)
	end
	local c = p.ent.rec.c
	if type(c) == "number" and c > 1 then
		local r, g, bb = M.Color("textDim")
		GameTooltip:AddLine((L["Cantidad: %d"]):format(c), r, g, bb)
	end
	GameTooltip:Show()
end

local function fotoSalir(self)
	if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end

local function fotoClic(self)
	local p = partes[self]
	local link = p and p.ent and p.ent.rec and p.ent.rec.l
	if type(link) == "string" and IsModifiedClick and IsModifiedClick() and HandleModifiedItemClick then
		HandleModifiedItemClick(link)
	end
end

function B.Foto(padre)
	local b = CreateFrame("Button", nil, padre)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetFrameLevel(padre:GetFrameLevel() + 1)
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetTexture(BLANCO)
	hl:SetAllPoints(b)
	hl:SetVertexColor(1, 1, 1, 0.12)
	local p = decorar(b)
	p.capa:SetFrameLevel(b:GetFrameLevel() + 2)
	b:SetScript("OnEnter", fotoEntrar)
	b:SetScript("OnLeave", fotoSalir)
	b:SetScript("OnClick", fotoClic)
	return b
end

---------------------------------------------------------------------------
-- El brillo de misión (se crea la primera vez que un botón lo necesita)
---------------------------------------------------------------------------

local function piezasMision(b, p)
	if p.brillo then return p.brillo, p.insignia end
	local g = CreateFrame("Frame", nil, p.capa)
	g:SetAllPoints(b)
	g:SetFrameLevel(p.capa:GetFrameLevel() + 1)
	g.borde = marco(g, "OVERLAY", 3)
	g.halo = g:CreateTexture(nil, "OVERLAY", nil, 2)
	g.halo:SetTexture(media("glow"))
	g.halo:SetBlendMode("ADD")
	g.halo:SetPoint("TOPLEFT", b, "TOPLEFT", -5, 5)
	g.halo:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 5, -5)
	local ag = g:CreateAnimationGroup()
	ag:SetLooping("BOUNCE")
	local a = ag:CreateAnimation("Alpha")
	a:SetFromAlpha(1)
	a:SetToAlpha(0.35)
	a:SetDuration(0.8)
	if a.SetSmoothing then a:SetSmoothing("IN_OUT") end
	g.late = ag
	g:Hide()
	-- La insignia «!» no late: queda fija arriba a la izquierda.
	local ins = CreateFrame("Frame", nil, p.capa)
	ins:SetFrameLevel(p.capa:GetFrameLevel() + 2)
	ins:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
	ins.fondo = ins:CreateTexture(nil, "OVERLAY", nil, 4)
	ins.fondo:SetTexture(BLANCO)
	ins.fondo:SetAllPoints(ins)
	ins.borde = marco(ins, "OVERLAY", 5)
	ins.texto = ins:CreateFontString(nil, "OVERLAY")
	ins.texto:SetPoint("CENTER", ins, "CENTER", 1, 0)
	ins:Hide()
	p.brillo, p.insignia = g, ins
	return g, ins
end

local function sinBrillo(p)
	if not p.brillo then return end
	if p.brillo.late:IsPlaying() then p.brillo.late:Stop() end
	p.brillo:Hide()
	p.insignia:Hide()
end

local function pintarBrillo(b, p, inicia)
	local g, ins = piezasMision(b, p)
	local r, gg, bb = M.Color("quest", 0.95, 0.82, 0.42)
	ponerMarco(g.borde, b, max(p.grosor or 1, 2 * pixel(b)), r, gg, bb, 1)
	g.halo:SetVertexColor(r, gg, bb, 0.5)
	g:Show()
	if not g.late:IsPlaying() then g.late:Play() end
	local t = max(11, floor((p.tam or 36) * 0.36 + 0.5))
	if ins.alfaTam ~= t then
		ins.alfaTam = t
		ins:SetSize(t, t)
		fuente(ins.texto, max(9, t - 2))
	end
	ins.texto:SetText("!")
	-- Empieza una misión: la insignia llena; si no, oscura con el «!» de color.
	if inicia then
		ins.fondo:SetVertexColor(r, gg, bb, 1)
		ins.texto:SetTextColor(0.08, 0.06, 0.02, 1)
	else
		local sr, sg, sb = M.Color("shade", 0, 0, 0.02)
		ins.fondo:SetVertexColor(sr, sg, sb, 0.9)
		ins.texto:SetTextColor(r, gg, bb, 1)
	end
	ponerMarco(ins.borde, ins, pixel(ins), r, gg, bb, 1)
	ins:Show()
end

---------------------------------------------------------------------------
-- Pintar
---------------------------------------------------------------------------

local function calidadColor(q)
	local r, g, b
	local f = C_Item and C_Item.GetItemQualityColor
	if f and type(q) == "number" then
		local ok, x, y, z = pcall(f, q)
		if ok and type(x) == "number" then r, g, b = x, y, z end
	end
	if not r then
		local c = type(ITEM_QUALITY_COLORS) == "table" and ITEM_QUALITY_COLORS[q]
		if type(c) == "table" and type(c.r) == "number" then r, g, b = c.r, c.g, c.b end
	end
	return r or 1, g or 1, b or 1
end
B.CalidadColor = calidadColor

local function abreviar(n)
	if n >= 10000 then return floor(n / 1000) .. "k" end
	if n >= 1000 then return ("%.1fk"):format(n / 1000) end
	return tostring(n)
end

-- ent: { rec = { i, c, l, q, icono, bloq, nuevo, mision, bang }, e = info,
--        nivel, cat, mejora, libre = cuántas casillas libres representa }
function B.Pintar(b, ent)
	local p = partes[b]
	if not p then return end
	p.ent = ent
	local rec = ent and ent.rec
	if not rec then
		p.icono:Hide()
		p.tinte:Hide()
		mostrarMarco(p.calidad, false)
		p.mision:Hide()
		sinBrillo(p)
		p.mejora:Hide()
		p.chatarra:Hide()
		p.nivel:SetText("")
		if p.anim:IsPlaying() then p.anim:Stop() end
		p.nuevo:Hide()
		local libre = ent and ent.libre
		if type(libre) == "number" and libre > 0 then
			p.cuenta:SetText(abreviar(libre))
			p.cuenta:SetTextColor(M.Color("textMuted"))
		else
			p.cuenta:SetText("")
		end
		if ent and ent.reagentes then
			local r, g, bb = M.Color("skill", 0.6, 0.88, 0.46)
			p.tinte:SetVertexColor(r, g, bb, 0.07)
			p.tinte:Show()
		end
		return
	end
	local e = ent.e or {}
	p.icono:SetTexture(rec.icono or e.icono or 134400)
	p.icono:SetDesaturated(rec.bloq and true or false)
	p.icono:SetVertexColor(1, 1, 1, 1)
	p.icono:Show()

	local c = tonumber(rec.c) or 1
	if c > 1 then
		p.cuenta:SetText(abreviar(c))
		p.cuenta:SetTextColor(1, 1, 1, 1)
	else
		p.cuenta:SetText("")
	end

	local q = rec.q
	local qr, qg, qb = calidadColor(q)
	if M.Get("marcaCalidad") and type(q) == "number" and q >= 2 then
		ponerMarco(p.calidad, b, p.grosor or 1, qr, qg, qb, 0.95)
		p.tinte:SetVertexColor(qr, qg, qb, 0.14)
		p.tinte:Show()
	else
		mostrarMarco(p.calidad, false)
		p.tinte:Hide()
	end

	if M.Get("marcaNivel") and ent.nivel and M.Objetos.EsEquipo(e) then
		p.nivel:SetText(ent.nivel)
		if type(q) == "number" and q >= 1 then
			local r, g, bb = qr, qg, qb
			if T and T.Legible then
				local ok, x, y, z = pcall(T.Legible, qr, qg, qb)
				if ok and type(x) == "number" then r, g, bb = x, y, z end
			end
			p.nivel:SetTextColor(r, g, bb, 1)
		else
			p.nivel:SetTextColor(0.85, 0.85, 0.85, 1)
		end
	else
		p.nivel:SetText("")
	end

	if M.Get("marcaChatarra") and (q == 0 or rec.basura) and not rec.sinValor then
		p.chatarra:SetVertexColor(1, 0.82, 0.25, 1)
		p.chatarra:Show()
	else
		p.chatarra:Hide()
	end

	if M.Get("marcaMejora") and ent.mejora then
		p.mejora:SetVertexColor(M.Color("success", 0.42, 0.85, 0.6))
		p.mejora:Show()
	else
		p.mejora:Hide()
	end

	local esMision = rec.mision or e.clase == 12
	if M.Get("brilloMision") and esMision then
		p.mision:Hide()
		pintarBrillo(b, p, rec.bang)
	elseif M.Get("marcaMision") and esMision then
		sinBrillo(p)
		p.mision:SetTexture(rec.bang and (TEXTURE_ITEM_QUEST_BANG or QUEST_BANG) or (TEXTURE_ITEM_QUEST_BORDER or QUEST_BORDE))
		p.mision:Show()
	else
		sinBrillo(p)
		p.mision:Hide()
	end

	if M.Get("marcaNuevos") and rec.nuevo then
		local r, g, bb = M.Acento()
		p.nuevo:SetVertexColor(r, g, bb, 1)
		p.nuevo:Show()
		if not p.anim:IsPlaying() then p.anim:Play() end
	else
		if p.anim:IsPlaying() then p.anim:Stop() end
		p.nuevo:Hide()
	end
end

-- Resultado de la búsqueda sobre un botón ya pintado.
function B.Buscar(b, estado)
	local p = partes[b]
	if not p then return end
	if estado == nil then
		b:SetAlpha(1)
		mostrarMarco(p.busca, false)
	elseif estado then
		b:SetAlpha(1)
		local r, g, bb = M.Acento()
		ponerMarco(p.busca, b, max(p.grosor or 1, 2 * pixel(b)), r, g, bb, 1)
	else
		b:SetAlpha(0.22)
		mostrarMarco(p.busca, false)
	end
end

function B.Bloqueo(b, bloqueado)
	local p = partes[b]
	if p and p.icono then p.icono:SetDesaturated(bloqueado and true or false) end
end

-- El enfriamiento del objeto (pociones, piedra de hogar...), solo en vivo.
function B.Enfriar(b, bolsa, casilla)
	local cd = b.Cooldown
	if type(cd) ~= "table" or not cd.SetCooldown then return end
	local p = partes[b]
	if not (p and p.ent and p.ent.rec) then
		if cd.Clear then cd:Clear() else cd:Hide() end
		return
	end
	local inicio, dur, activo = M.Llamar(C_Container and C_Container.GetContainerItemCooldown, bolsa, casilla)
	inicio, dur = M.Num(inicio), M.Num(dur)
	activo = M.Leer(activo)
	local on = activo == true or (type(activo) == "number" and activo ~= 0)
	if on and inicio and dur and inicio > 0 and dur > 0 then
		cd:SetCooldown(inicio, dur)
		cd:Show()
	elseif cd.Clear then
		cd:Clear()
	else
		cd:Hide()
	end
end

-- Un cambio de tema: el pozo y el borde de cada botón otra vez.
function B.Tema()
	for b, p in pairs(partes) do
		pintarPozo(b, p)
		p.firma = nil
	end
end
