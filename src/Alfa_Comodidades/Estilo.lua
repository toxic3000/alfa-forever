-- Alfa - Comodidades: el estilo de Alfa fuera de sus ventanas (toxic3000 / La Jauría). GPL-3.0.
--
-- Lo que comparten el chat (Chat.lua), el minimapa (MinimapaEstilo.lua) y
-- las barras de acción (Barras.lua) para vestirse con los tres estilos de
-- Alfa (docs/KIT.md, "Estilos"): Alfa, Clásico WoW y Cristal.
--
--   M.EstiloDe(clave)            el estilo elegido en ese ajuste ("igual" sigue al de Alfa)
--   M.OpcionesEstilo()           las opciones del desplegable: Igual que Alfa, Alfa, Clásico WoW, Cristal
--   M.ColorDe(estilo, token)     un color del Kit en ese estilo, aunque no sea el de ahora
--   M.CaraDe(estilo, peso)       la letra de ese estilo (nil: la que el juego ya tiene)
--   M.Piel(marco, opts)          relleno, borde de 1 px y marca de acento con la forma de Alfa;
--                                en Clásico WoW, el marco de los cuadros de información
--   M.Toques()                   lo que se cambia de una pieza de Blizzard (transparencia,
--                                letra, mostrar), recordado para devolverlo tal cual
--   M.AlCambiarAspecto(fn)       fn al cambiar el estilo, el esquema o el acento de Alfa
--
-- Con el estilo "igual" (o el mismo que el de Alfa) los colores salen de los
-- tokens del tema (siguen el esquema y el acento del jugador). Con otro
-- estilo, de los valores fijos de ese estilo. Nada de aquí toca marcos
-- protegidos: solo texturas propias, transparencias y letras.

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local K = N.Kit
local ID = M.ID

local type, pairs, ipairs, pcall, unpack = type, pairs, ipairs, pcall, unpack

---------------------------------------------------------------------------
-- El estilo de cada parte
---------------------------------------------------------------------------
local ESTILOS = { alfa = true, clasico = true, cristal = true }

function M.EstiloDe(clave)
	local v = N.Get(ID, clave)
	if ESTILOS[v] then return v end
	return K.Estilo()
end

function M.OpcionesEstilo()
	local t = { { valor = "igual", texto = L["Igual que Alfa"] } }
	for _, e in ipairs(K.ESTILOS or {}) do
		t[#t + 1] = { valor = e.id, texto = K.NombreEstilo(e.id) or e.nombre }
	end
	return t
end

---------------------------------------------------------------------------
-- Colores
---------------------------------------------------------------------------
local DA = K.DISENO_A or {}

-- Clásico WoW fuera del estilo general: los colores de la piel "classic" del tema.
local CLASICO = {
	fondo = { 0, 0, 0, 0.8 }, panel = { 0.063, 0.063, 0.063, 0.85 }, elevado = { 0.1, 0.1, 0.1, 0.9 },
	hundido = { 0, 0, 0, 0.85 }, pie = { 0.063, 0.063, 0.063, 0.85 },
	linea = { 0.41, 0.41, 0.41, 1 }, lineaFuerte = { 0.6, 0.6, 0.6, 1 },
	texto = { 1, 1, 1, 1 }, textoSuave = { 0.8, 0.8, 0.8, 1 }, textoTenue = { 0.6, 0.6, 0.6, 1 },
	acento = { 1, 0.82, 0, 1 }, titulo = { 1, 0.82, 0, 1 },
}
-- Cristal fuera del estilo general: los fondos del diseño A, de cristal.
local CRISTAL_FONDOS = { fondo = 0.74, panel = 0.5, elevado = 0.62, hundido = 0.42, pie = 0.46 }
local CRISTAL_LINEAS = { linea = 0.16, lineaFuerte = 0.28 }

local function desde(c, a)
	c = c or DA.texto or { 0.9, 0.94, 0.9, 1 }
	return c[1], c[2], c[3], a or c[4] or 1
end

-- -> r, g, b, a de un token del Kit en ese estilo
function M.ColorDe(estilo, token)
	if estilo == K.Estilo() then return K.Color(token) end
	if estilo == "clasico" then return desde(CLASICO[token] or CLASICO.texto) end
	if token == "acento" then
		-- El acento del jugador, salvo que el de ahora sea el oro de Clásico WoW.
		if not K.Clasico() then return K.Color("acento") end
		return desde(DA.acento, 1)
	end
	if estilo == "cristal" then
		if CRISTAL_FONDOS[token] then return desde(DA[token], CRISTAL_FONDOS[token]) end
		if CRISTAL_LINEAS[token] then return desde(DA.texto, CRISTAL_LINEAS[token]) end
	end
	return desde(DA[token])
end

-- El mismo color como tabla { r, g, b, a }, con la opacidad multiplicada.
function M.TablaColor(estilo, token, opacidad)
	local r, g, b, a = M.ColorDe(estilo, token)
	return { r, g, b, (a or 1) * (opacidad or 1) }
end

---------------------------------------------------------------------------
-- Letra
---------------------------------------------------------------------------
local FUENTES = "Interface\\AddOns\\Alfa\\Media\\Fonts\\"
local INTER = { regular = "Inter-Regular.ttf", medium = "Inter-Medium.ttf", semibold = "Inter-SemiBold.ttf" }
local CJK = { zhCN = true, zhTW = true, koKR = true }

-- -> la ruta de la letra, o nil para dejar la del juego (Clásico WoW)
function M.CaraDe(estilo, peso)
	if estilo == "clasico" then return nil end
	if estilo == K.Estilo() and K.Cara then return K.Cara(peso) end
	local loc = GetLocale and GetLocale()
	if CJK[loc] then return nil end
	return FUENTES .. (INTER[peso] or INTER.medium)
end

---------------------------------------------------------------------------
-- La piel: la forma de Alfa (o el marco del juego en Clásico WoW)
--   p = M.Piel(marco, { corte = 8, marca = true, anchoMarca = 28 })
--   p:Pintar(estilo, { fondo = "fondo", borde = "linea", opacidad = 1, marca = true })
--   p:SetShown(bool)
-- Las texturas son del propio `marco` (un marco de Alfa, nunca uno de Blizzard).
---------------------------------------------------------------------------
local Piel = {}
Piel.__index = Piel

function M.Piel(marco, opts)
	opts = opts or {}
	local p = setmetatable({ marco = marco, corte = opts.corte or K.CORTE.panel, on = true }, Piel)
	p.forma = K.Forma(marco, p.corte, "BACKGROUND", -7)
	p.borde = K.Borde(marco, p.corte)
	if opts.marca then
		p.marca = marco:CreateTexture(nil, "ARTWORK", nil, 3)
		p.marca:SetColorTexture(1, 1, 1, 1)
		p.marca:SetSize(opts.anchoMarca or 28, 2)
		p.marca:SetPoint("TOPLEFT", marco, "TOPLEFT", p.corte + 6, 0)
	end
	return p
end

function Piel:Pintar(estilo, e)
	self.estilo, self.e = estilo, e
	if not self.on then return end
	if estilo == "clasico" and e.juego ~= false then
		self.forma:Hide()
		self.borde:Hide()
		if self.marca then self.marca:Hide() end
		self.juego = self.juego or K.MarcoJuego(self.marco, e.tipoJuego or "info")
		self.juego.on = true
		self.juego:Pintar({
			fondo = e.fondo and M.TablaColor(estilo, e.fondo, e.opacidad) or nil,
			borde = e.borde and { 0.8, 0.8, 0.8, 1 } or nil,
		})
		return
	end
	if self.juego then self.juego:Hide() end
	if e.fondo then
		self.forma:Show()
		self.forma:RGBA(unpack(M.TablaColor(estilo, e.fondo, e.opacidad)))
	else
		self.forma:Hide()
	end
	if e.borde then
		self.borde:Show()
		self.borde:Color(M.TablaColor(estilo, e.borde, e.alfaBorde))
	else
		self.borde:Hide()
	end
	if self.marca then
		local con = estilo ~= "clasico" and e.marca ~= false
		self.marca:SetShown(con)
		if con then self.marca:SetVertexColor(M.ColorDe(estilo, "acento")) end
	end
end

function Piel:SetShown(on)
	self.on = on and true or false
	if self.on then
		if self.e then self:Pintar(self.estilo, self.e) end
		return
	end
	self.forma:Hide()
	self.borde:Hide()
	if self.marca then self.marca:Hide() end
	if self.juego then self.juego:Hide() end
end
function Piel:Show() self:SetShown(true) end
function Piel:Hide() self:SetShown(false) end

---------------------------------------------------------------------------
-- Toques en piezas de Blizzard: cada cambio recuerda cómo estaba la pieza y
-- :Devolver() la deja igual. Solo transparencia, mostrar/ocultar regiones de
-- arte y la cara de la letra (el tamaño y el contorno se quedan como estén).
---------------------------------------------------------------------------
local Toques = {}
Toques.__index = Toques

function M.Toques()
	return setmetatable({ alfa = {}, ocultas = {}, letra = {} }, Toques)
end

-- Transparente (para lo que Blizzard muestra y oculta solo).
function Toques:Ocultar(reg)
	if type(reg) ~= "table" or not reg.SetAlpha then return end
	if self.alfa[reg] == nil then
		local ok, a = pcall(reg.GetAlpha, reg)
		self.alfa[reg] = (ok and type(a) == "number") and a or 1
	end
	reg:SetAlpha(0)
end

-- Oculta (para lo que Blizzard funde con su transparencia).
function Toques:Esconder(reg)
	if type(reg) ~= "table" or not reg.Hide then return end
	if self.ocultas[reg] == nil then
		self.ocultas[reg] = reg:IsShown() and true or false
	end
	reg:Hide()
end

-- La cara de la letra; cara = nil la devuelve a la de antes.
function Toques:Letra(fs, cara)
	if type(fs) ~= "table" or not (fs.GetFont and fs.SetFont) then return end
	local ok, actual, tam, banderas = pcall(fs.GetFont, fs)
	if not (ok and type(tam) == "number") then return end
	if not cara then
		local antes = self.letra[fs]
		if antes then pcall(fs.SetFont, fs, antes, tam, banderas or "") end
		self.letra[fs] = nil
		return
	end
	if self.letra[fs] == nil then self.letra[fs] = actual or false end
	if actual ~= cara then
		local bien = pcall(fs.SetFont, fs, cara, tam, banderas or "")
		if not bien and self.letra[fs] then pcall(fs.SetFont, fs, self.letra[fs], tam, banderas or "") end
	end
end

-- Devuelve una sola región (transparencia y mostrar).
function Toques:DevolverUna(reg)
	if type(reg) ~= "table" then return end
	local a = self.alfa[reg]
	if a ~= nil then pcall(reg.SetAlpha, reg, a) self.alfa[reg] = nil end
	local v = self.ocultas[reg]
	if v ~= nil then
		if v then pcall(reg.Show, reg) end
		self.ocultas[reg] = nil
	end
end

function Toques:Devolver()
	for reg, a in pairs(self.alfa) do pcall(reg.SetAlpha, reg, a) end
	for reg, v in pairs(self.ocultas) do if v then pcall(reg.Show, reg) end end
	for fs in pairs(self.letra) do self:Letra(fs, nil) end
	self.alfa, self.ocultas, self.letra = {}, {}, {}
end

---------------------------------------------------------------------------
-- Al cambiar el aspecto de Alfa (estilo, esquema, acento, letra): el Kit
-- llama a sus pintores (K.Pintar); este es uno más, para las tres partes.
---------------------------------------------------------------------------
local repintores = {}
function M.AlCambiarAspecto(fn) repintores[#repintores + 1] = fn end

M.anclaAspecto = {}
K.Pintar(M.anclaAspecto, function()
	if not (A.IsLoggedIn and A.IsLoggedIn()) then return end
	for i = 1, #repintores do M.Seguro(repintores[i]) end
end)
