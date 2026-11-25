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
local next, format, tostring = next, string.format, tostring

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

-- La letra de los números de las casillas (la del rol «number» del tema).
local function caraNumeros()
	if T and T.FontSpec then
		local ok, p = pcall(T.FontSpec, "number")
		if ok and type(p) == "string" then return p end
	end
	return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

---------------------------------------------------------------------------
-- 1.4.0 (bug 1): los números de las casillas, gigantes y encimados.
-- Forever no vuelve a acomodar un texto tras una letra nueva o un cambio de
-- pantalla (RestartGx, escala, «Dos pantallas») hasta que su texto cambia
-- (lo mismo que motor/Alfa/Theme/Theme.lua arregla para sus textos con
-- textAgain y RetextLater). Los números de las casillas (montón, nivel de
-- objeto, recarga) y los de la barra son de letra propia, fuera del tema, y
-- su texto casi nunca cambia: se quedaban dibujados con la medida de antes,
-- el doble de grandes y fuera de su caja. Además B.Medir solo ponía la letra
-- cuando cambiaba el tamaño de la casilla, así que un estilo nuevo
-- (Restablecer) tampoco llegaba. Ahora:
--   * B.Medir pone la letra otra vez si cambia la casilla, la letra o la
--     «generación» de la pantalla (B.gen), y vuelve a escribir el texto;
--   * B.Refrescar() sube B.gen y rehace todos (ahora y un instante después),
--     con cada cambio de pantalla, de escala, de aspecto o de ajustes;
--   * cada número se mide: su letra es fija respecto a la casilla y se achica
--     hasta caber; el montón y el nivel nunca se enciman.
---------------------------------------------------------------------------
B.gen = 0
B.LETRA = 0.30   -- montón y nivel: 30 % de la casilla
B.LETRA_RECARGA = 0.32
B.LETRA_MIN = 7

local function esSecreto(v) return issecretvalue ~= nil and issecretvalue(v) and true or false end

-- Escribe el mismo texto otra vez para que el juego lo acomode con su letra de ahora.
local function otraVez(fs)
	if not (fs and fs.GetText) then return end
	local t = fs:GetText()
	if esSecreto(t) or t == nil or t == "" then return end
	fs:SetText(t .. " ")
	fs:SetText(t)
end
B.OtraVez = otraVez

-- Pone la letra; `forzar` la cambia de verdad (otro tamaño y luego el suyo:
-- con los mismos datos el juego puede dejar la de antes) y reescribe el texto.
local function fuente(fs, tam, forzar)
	local ruta = caraNumeros()
	if forzar then pcall(fs.SetFont, fs, ruta, tam + 1, "OUTLINE") end
	local ok, puesta = pcall(fs.SetFont, fs, ruta, tam, "OUTLINE")
	if not ok or puesta == false or not fs:GetFont() then
		fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", tam, "OUTLINE")
	end
	otraVez(fs)
end

-- Lo que mide un texto sin el ancho que se le haya puesto.
local function anchoDe(fs)
	local w
	if fs.GetUnboundedStringWidth then w = fs:GetUnboundedStringWidth() end
	w = tonumber(w)
	if not w or w <= 0 then w = tonumber(fs:GetStringWidth()) or 0 end
	return w
end
B.AnchoDe = anchoDe

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
	p.nivel = capa:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	p.nivel:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 3, 3)
	p.nivel:SetJustifyH("LEFT")
	p.cuenta = capa:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
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

-- El montón (abajo a la derecha) y el nivel (abajo a la izquierda) caben en
-- la casilla y no se tocan: con los dos, cada uno en su mitad. La letra es la
-- de la casilla (B.LETRA) y baja hasta caber.
local function encajar(p)
	local tam = p.tam or 0
	if tam <= 0 then return end
	local hayN = (p.nivel:GetText() or "") ~= ""
	local hayC = (p.cuenta:GetText() or "") ~= ""
	local tope = (hayN and hayC) and floor((tam - 6) / 2) or (tam - 5)
	for _, fs in ipairs({ p.nivel, p.cuenta }) do
		if (fs:GetText() or "") ~= "" then
			fs:SetWidth(0)
			local letra = p.letra or B.LETRA_MIN
			local _, actual = fs:GetFont()
			actual = tonumber(actual) or letra
			-- Una casilla que antes achicó su letra la recupera si ya cabe.
			if actual ~= letra and anchoDe(fs) * letra / max(1, actual) <= tope then
				fuente(fs, letra)
				actual = letra
			end
			local n = 0
			while anchoDe(fs) > tope and actual > B.LETRA_MIN and n < 8 do
				actual, n = actual - 1, n + 1
				fuente(fs, actual)
			end
		end
	end
end
B.Encajar = encajar

function B.Medir(b, tam)
	local p = partes[b]
	if not p then return end
	local cara = caraNumeros()
	if p.tam == tam and p.gen == B.gen and p.cara == cara then return end
	-- Otra generación de pantalla o de letra: forzar (Forever guarda la de antes).
	local forzar = (p.tam or 0) > 0
	p.tam, p.gen, p.cara = tam, B.gen, cara
	b:SetSize(tam, tam)
	local px = pixel(b)
	p.icono:ClearAllPoints()
	p.icono:SetPoint("TOPLEFT", b, "TOPLEFT", 2 * px, -2 * px)
	p.icono:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2 * px, 2 * px)
	local flecha = max(10, floor(tam * 0.42 + 0.5))
	p.mejora:SetSize(flecha, flecha)
	local moneda = max(9, floor(tam * 0.34 + 0.5))
	p.chatarra:SetSize(moneda, moneda)
	local letra = max(B.LETRA_MIN + 1, floor(tam * B.LETRA + 0.5))
	p.letra = letra
	fuente(p.nivel, letra, forzar)
	fuente(p.cuenta, letra, forzar)
	encajar(p)
	-- La insignia «!» y la recarga se miden otra vez al pintarse.
	if p.insignia then p.insignia.alfaTam = nil end
	p.recargaTam = nil
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
	ins.texto = ins:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
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
		encajar(p)
		if ent and ent.reagentes then
			local r, g, bb = M.Color("skill", 0.6, 0.88, 0.46)
			p.tinte:SetVertexColor(r, g, bb, 0.07)
			p.tinte:Show()
		end
		if M.Separar then M.Separar.Pintar(b, p, ent) end
		if M.Candado then M.Candado.Pintar(b, p, ent) end
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
	encajar(p)

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
	-- 1.3.8: «Separar»: subasta o comerciante (Separar.lua).
	if M.Separar then M.Separar.Pintar(b, p, ent) end
	-- 1.3.8: el candado (Candado.lua): la marca y, con un comerciante, que no se venda.
	if M.Candado then M.Candado.Pintar(b, p, ent) end
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

---------------------------------------------------------------------------
-- 1.3.9 (bug 14): el número de la recarga dentro de la casilla. El del juego
-- («55m» en la piedra de hogar) es de su letra y su tamaño, y en las casillas
-- de Alfa se salía. Ahora es un texto propio, con la letra de Alfa, que se
-- achica hasta caber (nunca más ancho que la casilla menos 4 px), y el del
-- juego se esconde. Con valores secretos (no se pueden leer) queda el del
-- juego. Un solo reloj (N.Cada «bolsas.recargas», 1 s) mientras alguna
-- recarga legible corre.
---------------------------------------------------------------------------
local recargas = {} -- botón -> p (con p.finRecarga)
local RELOJ_RECARGAS = "bolsas.recargas"
local ceil = math.ceil

-- 3300 -> "55m", 7200 -> "2h", 42.2 -> "43"
function B.TextoRecarga(falta)
	if falta >= 3600 then return format(L["%dh [recarga]"], ceil(falta / 3600)) end
	if falta >= 60 then return format(L["%dm [recarga]"], ceil(falta / 60)) end
	return tostring(max(1, ceil(falta)))
end

-- Pone el texto y lo achica hasta que cabe en la casilla.
local function escribirRecarga(p, texto)
	local fs = p.recarga
	local tam = max(16, p.tam or 36)
	local tope = tam - 4
	if p.recargaTexto == texto and p.recargaTam == tam then return end
	local otra = p.recargaTam ~= tam -- casilla o pantalla nueva (B.Medir la borra): forzar
	p.recargaTexto, p.recargaTam = texto, tam
	local letra = max(8, floor(tam * B.LETRA_RECARGA + 0.5))
	local cara = N.Kit and N.Kit.Cara and N.Kit.Cara("semibold") or (STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF")
	-- 1.4.0: se mide sin el ancho de antes (con él, el juego daba lo ya
	-- recortado y la letra nunca bajaba: «56m» salía cortado).
	fs:SetWidth(0)
	for i = 1, 8 do
		if otra and i == 1 then pcall(fs.SetFont, fs, cara, letra + 1, "OUTLINE") end
		if N.Kit and N.Kit.FuenteSegura then N.Kit.FuenteSegura(fs, cara, letra, "OUTLINE")
		else pcall(fs.SetFont, fs, cara, letra, "OUTLINE") end
		fs:SetText(texto)
		if otra and i == 1 then otraVez(fs) end
		if anchoDe(fs) <= tope or letra <= 8 then break end
		letra = letra - 1
	end
	p.recargaLetra = letra
	fs:SetWidth(tope)
	-- Con un montón abajo, la recarga sube un poco: nunca se enciman.
	local hayC = p.cuenta and (p.cuenta:GetText() or "") ~= ""
	fs:ClearAllPoints()
	fs:SetPoint("CENTER", p.capa, "CENTER", 0, hayC and floor(tam * 0.14 + 0.5) or 0)
end
B.EscribirRecarga = escribirRecarga

local function ticRecargas()
	local ahora = GetTime and GetTime() or 0
	for b, p in pairs(recargas) do
		local falta = (p.finRecarga or 0) - ahora
		if falta <= 0 or not p.recarga or not b:IsShown() then
			recargas[b] = nil
			p.finRecarga = nil
			if p.recarga then p.recarga:Hide() end
		elseif b:IsVisible() then
			escribirRecarga(p, B.TextoRecarga(falta))
			if falta <= 10 then p.recarga:SetTextColor(1, 0.82, 0.25, 1) else p.recarga:SetTextColor(1, 1, 1, 1) end
			p.recarga:Show()
		end
	end
	if next(recargas) == nil and N.Quitar then N.Quitar(RELOJ_RECARGAS) end
end
B.TicRecargas = ticRecargas
B.Recargas = recargas

local function numerosDelJuego(cd, mostrar)
	if type(cd.SetHideCountdownNumbers) == "function" then pcall(cd.SetHideCountdownNumbers, cd, not mostrar) end
end

local function sinRecarga(p)
	if not p then return end
	p.finRecarga = nil
	if p.recarga then p.recarga:Hide() end
end

-- El enfriamiento del objeto (pociones, piedra de hogar...), solo en vivo.
function B.Enfriar(b, bolsa, casilla)
	local cd = b.Cooldown
	-- (1.3.9: sin el marco del juego, el número propio igual se pone.)
	if type(cd) ~= "table" or not cd.SetCooldown then cd = nil end
	local p = partes[b]
	if not p then return end
	if not (p.ent and p.ent.rec) then
		if cd then if cd.Clear then cd:Clear() else cd:Hide() end end
		recargas[b] = nil
		sinRecarga(p)
		return
	end
	local inicio, dur, activo = M.Llamar(C_Container and C_Container.GetContainerItemCooldown, bolsa, casilla)
	inicio, dur = M.Num(inicio), M.Num(dur)
	activo = M.Leer(activo)
	local on = activo == true or (type(activo) == "number" and activo ~= 0)
	if on and inicio and dur and inicio > 0 and dur > 0 then
		if cd then
			cd:SetCooldown(inicio, dur)
			cd:Show()
		end
		-- 1.3.9: el número propio (las de más de 2 s; la global no lleva número).
		local falta = inicio + dur - (GetTime and GetTime() or 0)
		if dur > 2 and falta > 0 then
			if cd then numerosDelJuego(cd, false) end
			if not p.recarga then
				p.recarga = p.capa:CreateFontString(nil, "OVERLAY")
				p.recarga:SetPoint("CENTER", b, "CENTER", 0, 0)
				p.recarga:SetJustifyH("CENTER")
			end
			p.finRecarga = inicio + dur
			recargas[b] = p
			escribirRecarga(p, B.TextoRecarga(falta))
			p.recarga:SetTextColor(1, 1, 1, 1)
			p.recarga:Show()
			if N.Cada and not (N.HayTarea and N.HayTarea(RELOJ_RECARGAS)) then N.Cada(RELOJ_RECARGAS, 1, ticRecargas) end
		else
			recargas[b] = nil
			sinRecarga(p)
		end
	else
		recargas[b] = nil
		sinRecarga(p)
		if cd then
			if cd.Clear then cd:Clear() else cd:Hide() end
			-- Sin número legible (secreto): el del juego.
			if on then numerosDelJuego(cd, true) end
		end
	end
end

-- Un cambio de tema: el pozo y el borde de cada botón otra vez.
function B.Tema()
	for b, p in pairs(partes) do
		pintarPozo(b, p)
		p.firma = nil
	end
end

---------------------------------------------------------------------------
-- 1.4.0 (bug 1): todos los números de las casillas otra vez, con la medida
-- de ahora (ver arriba, «los números de las casillas, gigantes»).
--   B.Refrescar()      sube la generación y rehace letra y texto de todas
--   B.RefrescarLuego() lo mismo, un instante después (junta varios avisos)
--   B.OtraVezTodo()    solo reescribe los textos a la vista (al abrir)
---------------------------------------------------------------------------
function B.OtraVezTodo()
	for b, p in pairs(partes) do
		if b:IsVisible() then
			otraVez(p.nivel)
			otraVez(p.cuenta)
			if p.recarga and p.recarga:IsShown() then otraVez(p.recarga) end
			if p.insignia and p.insignia:IsShown() then otraVez(p.insignia.texto) end
		end
	end
	if M.Barra and M.Barra.OtraVez then M.Barra.OtraVez() end
end

function B.Refrescar()
	B.gen = B.gen + 1
	for b, p in pairs(partes) do
		if (p.tam or 0) > 0 then B.Medir(b, p.tam) end
		if p.recarga and p.finRecarga and p.recargaTexto then
			local t = p.recargaTexto
			p.recargaTexto = nil
			escribirRecarga(p, t)
		end
	end
	if M.Barra and M.Barra.Refrescar then M.Barra.Refrescar() end
	-- Y un instante después: un texto puesto en el mismo cuadro puede quedarse como estaba.
	if N.Una then N.Una("bolsas.letras", 0.1, B.OtraVezTodo) end
end

function B.RefrescarLuego()
	if N.Una then N.Una("bolsas.refrescar", 0.2, B.Refrescar) else B.Refrescar() end
end

-- Cambios de pantalla: resolución, escala, gráficos reiniciados (Dos pantallas).
for _, ev in ipairs({ "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED", "GX_RESTARTED" }) do
	A.RegisterEvent(ev, function() B.RefrescarLuego() end)
end
-- UIParent cambia de tamaño (Dos pantallas lo ancla a un monitor y lo devuelve).
if UIParent and UIParent.HookScript then
	UIParent:HookScript("OnSizeChanged", function() B.RefrescarLuego() end)
end
-- Restablecer (página o todo), un perfil, un respaldo, otro estilo o tamaño.
local function tocaLetras(ruta)
	if type(ruta) ~= "string" then return false end
	if ruta == "" then return true end
	for _, raiz in ipairs({ M.ID, "nucleo", "ui", "pantallas" }) do
		if ruta == raiz or ruta:sub(1, #raiz + 1) == raiz .. "." then return true end
	end
	return false
end
B.TocaLetras = tocaLetras
A.On("SETTING_CHANGED", function(ruta)
	if tocaLetras(ruta) then B.RefrescarLuego() end
end)
if N.Kit and N.Kit.AlRepintar then N.Kit.AlRepintar(function() B.RefrescarLuego() end) end
