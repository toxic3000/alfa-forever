-- Alfa - La Jauría: el marcador por bando (1.3.9, pedido de Toxic). GPL-3.0.
-- toxic3000 / La Jauría.
--
-- Cuántos lobos de La Jauría hay de la Horda y cuántos de la Alianza, en dos
-- columnas con el emblema y el color de cada bando (Kit/Bando.lua: dibujos
-- propios), en la página de La Jauría y como panel del Escritorio
-- (AlfaEscritorio.RegistrarPanel, si existe).
--
-- Qué se puede contar: el juego no deja que la Horda y la Alianza se hablen
-- por addon (y la 1.3.8 separó las facciones a propósito), así que en vivo
-- solo se cuenta a los de TU bando: tú y los lobos con Alfa que se oyen por
-- la Red de la manada (el canal de tu facción o tu hermandad, Gente.lua).
-- El de la otra facción:
--   * si alguna vez llega un número (lo deja el instalador o una versión
--     futura en AlfaNucleoDB.jauria.bandos[letra] = { n, fecha, fuente }),
--     se enseña como «último conocido» con su fecha;
--   * si no, «Se ve desde su lado».
-- Tu número también se guarda ahí (el más alto del día y su fecha), así el
-- instalador lo puede llevar al Discord algún día.
--   Mc.Contar() -> { H = { n, vivo, fecha, max }, A = {...}, mia = "H" | "A" | nil }
--   Mc.Nuevo(padre) -> bloque con :Acomodar(ancho) -> alto y :Llenar()

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L, U = M.L, M.U

local floor, max, min, format, date, time = math.floor, math.max, math.min, string.format, date, time
local ESP = K.ESP

local Mc = {}
M.Marcador = Mc

-- El hueco de datos (cuenta, no personaje): AlfaNucleoDB.jauria.bandos.
local function bandos()
	local db = rawget(_G, "AlfaNucleoDB")
	if type(db) ~= "table" then return nil end
	if type(db.jauria) ~= "table" then db.jauria = {} end
	if type(db.jauria.bandos) ~= "table" then db.jauria.bandos = {} end
	return db.jauria.bandos
end
Mc.Datos = bandos

local function hoy() return date and date("%Y-%m-%d") or "" end
local function ahora() return time and time() or 0 end

-- Los de tu bando en vivo: tú y los Alfa que se oyen (Gente.lua).
local function vivos()
	local G = M.Gente
	local n = G and G.Lobos and G.Lobos() or 0
	return n + 1
end

function Mc.Contar()
	local mia = N.FaccionLetra and N.FaccionLetra() or nil
	if K.bandoPrueba then mia = K.bandoPrueba end
	local db = bandos()
	local out = { mia = mia }
	for _, l in ipairs({ "H", "A" }) do
		local guardado = db and type(db[l]) == "table" and db[l] or nil
		if l == mia then
			local n = vivos()
			if db then
				local g = guardado or {}
				if g.dia ~= hoy() then g.dia, g.max = hoy(), 0 end
				g.max = max(tonumber(g.max) or 0, n)
				g.n, g.fecha, g.fuente = n, ahora(), "vivo"
				db[l] = g
			end
			out[l] = { n = n, vivo = true, max = db and db[l] and db[l].max or n }
		elseif guardado and tonumber(guardado.n) then
			out[l] = { n = floor(tonumber(guardado.n)), fecha = tonumber(guardado.fecha), fuente = guardado.fuente }
		else
			out[l] = {}
		end
	end
	return out
end

-- «hace 3 días», «hoy»
local function cuando(fecha)
	if not fecha then return nil end
	local s = ahora() - fecha
	if s < 86400 then return L["hoy"] end
	local d = floor(s / 86400)
	return N.Plural and N.Plural(d, L["hace %d día"], L["hace %d días"]) or format(L["hace %d días"], d)
end

---------------------------------------------------------------------------
-- El bloque: dos columnas
---------------------------------------------------------------------------
local ALTO_COL = 150

local function columna(padre, letra)
	local t = K.TemaBando(letra)
	local c = CreateFrame("Frame", nil, padre)
	c.alfaLetra = letra
	c.Fondo = c:CreateTexture(nil, "BACKGROUND")
	c.Fondo:SetAllPoints(c)
	c.Fondo:SetColorTexture(t.oscuro[1], t.oscuro[2], t.oscuro[3], 0.92)
	c.Borde = {}
	for i = 1, 4 do
		local b = c:CreateTexture(nil, "BORDER")
		b:SetColorTexture(t.color[1], t.color[2], t.color[3], 0.55)
		c.Borde[i] = b
	end
	c.Borde[1]:SetPoint("TOPLEFT") c.Borde[1]:SetPoint("TOPRIGHT") c.Borde[1]:SetHeight(1)
	c.Borde[2]:SetPoint("BOTTOMLEFT") c.Borde[2]:SetPoint("BOTTOMRIGHT") c.Borde[2]:SetHeight(1)
	c.Borde[3]:SetPoint("TOPLEFT") c.Borde[3]:SetPoint("BOTTOMLEFT") c.Borde[3]:SetWidth(1)
	c.Borde[4]:SetPoint("TOPRIGHT") c.Borde[4]:SetPoint("BOTTOMRIGHT") c.Borde[4]:SetWidth(1)
	c.Tira = K.TiraBando(c, 5, "ARTWORK")
	c.Tira:SetPoint("TOPLEFT", c, "TOPLEFT", 1, -1)
	c.Tira:SetPoint("TOPRIGHT", c, "TOPRIGHT", -1, -1)
	c.Halo = c:CreateTexture(nil, "ARTWORK", nil, 0)
	c.Halo:SetTexture("Interface\\AddOns\\Alfa_Bienvenida\\Media\\intro-halo")
	c.Halo:SetBlendMode("ADD")
	c.Halo:SetSize(96, 96)
	c.Halo:SetVertexColor(t.color[1], t.color[2], t.color[3], 0.5)
	c.Emblema = c:CreateTexture(nil, "ARTWORK", nil, 1)
	c.Emblema:SetTexture(t.emblema)
	c.Emblema:SetSize(56, 56)
	c.Emblema:SetPoint("TOP", c, "TOP", 0, -14)
	c.Halo:SetPoint("CENTER", c.Emblema, "CENTER")
	c.Nombre = K.Texto(c, "mayus", { t.metal[1], t.metal[2], t.metal[3], 1 })
	c.Nombre:SetJustifyH("CENTER")
	c.Cifra = K.Texto(c, "cifra", "texto")
	c.Cifra:SetJustifyH("CENTER")
	c.Nota = K.Texto(c, "pequeno", "textoSuave")
	c.Nota:SetJustifyH("CENTER")
	c.Tuyo = K.Texto(c, "insignia", { t.color[1], t.color[2], t.color[3], 1 })
	c.Tuyo:SetJustifyH("CENTER")
	return c
end

local function pintarColumna(c, d, mia, ancho)
	local t = K.TemaBando(c.alfaLetra)
	c.Tira:Pintar(t)
	K.Escribir(c.Nombre, K.Mayus(L[t.titulo]))
	local nota
	if d.vivo then
		K.Escribir(c.Cifra, tostring(d.n))
		c.Cifra:SetAlpha(1)
		nota = d.n == 1 and L["Tú, por ahora: invita a la manada"]
			or format(N.Plural and N.Plural(d.n, L["%d lobo con Alfa en línea"], L["%d lobos con Alfa en línea"]) or L["%d lobos con Alfa en línea"], d.n)
		if d.max and d.max > d.n then nota = nota .. "\n" .. format(L["Hoy llegaron a %d"], d.max) end
	elseif d.n then
		K.Escribir(c.Cifra, tostring(d.n))
		c.Cifra:SetAlpha(0.75)
		nota = format(L["Último conocido: %s"], cuando(d.fecha) or "")
	else
		K.Escribir(c.Cifra, "?")
		c.Cifra:SetAlpha(0.5)
		nota = L["Se ve desde su lado"]
	end
	K.Escribir(c.Nota, nota)
	K.Escribir(c.Tuyo, c.alfaLetra == mia and K.Mayus(L["Tu bando"]) or "")
	c.Tuyo:SetShown(c.alfaLetra == mia)
	-- Acomodo de arriba abajo.
	local y = 14 + 56 + 6
	c.Nombre:ClearAllPoints()
	c.Nombre:SetPoint("TOP", c, "TOP", 0, -y)
	c.Nombre:SetWidth(ancho - 12)
	y = y + K.AltoTexto(c.Nombre) + 2
	c.Cifra:ClearAllPoints()
	c.Cifra:SetPoint("TOP", c, "TOP", 0, -y)
	c.Cifra:SetWidth(ancho - 12)
	y = y + K.AltoTexto(c.Cifra) + 2
	c.Nota:ClearAllPoints()
	c.Nota:SetPoint("TOP", c, "TOP", 0, -y)
	y = y + K.Parrafo(c.Nota, ancho - 16, 3) + 8
	if c.Tuyo:IsShown() then
		c.Tuyo:ClearAllPoints()
		c.Tuyo:SetPoint("TOPRIGHT", c, "TOPRIGHT", -8, -10)
	end
	return y
end

function Mc.Nuevo(padre, opts)
	opts = opts or {}
	local b = CreateFrame("Frame", nil, padre)
	b.Sobre = K.Texto(b, "mayus", "textoTenue")
	b.Titulo = K.Texto(b, "subtitulo", "texto")
	b.Texto = K.Texto(b, "nota", "textoSuave")
	b.H = columna(b, "H")
	b.A = columna(b, "A")
	b.Medio = K.Texto(b, "encabezado", "textoTenue")
	b.Medio:SetJustifyH("CENTER")
	b.sinCabeza = opts.sinCabeza
	function b:Llenar()
		self.datos = Mc.Contar()
	end
	function b:Acomodar(ancho)
		local d = self.datos or Mc.Contar()
		self.datos = d
		local y = 0
		if not self.sinCabeza then
			K.Escribir(self.Sobre, K.Mayus(L["La Jauría por bando"]))
			self.Sobre:ClearAllPoints()
			self.Sobre:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
			y = y + K.AltoTexto(self.Sobre) + 2
			K.Escribir(self.Titulo, L["Cuántos lobos hay de cada lado"])
			self.Titulo:ClearAllPoints()
			self.Titulo:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
			y = y + K.Parrafo(self.Titulo, ancho, 2) + 2
			K.Escribir(self.Texto, L["Tu bando se cuenta en vivo con la Red de la manada. El otro lado no se oye desde aquí: el juego no deja que la Horda y la Alianza se hablen por addon."])
			self.Texto:ClearAllPoints()
			self.Texto:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
			y = y + K.Parrafo(self.Texto, ancho, 4) + ESP.m
		end
		self.Sobre:SetShown(not self.sinCabeza)
		self.Titulo:SetShown(not self.sinCabeza)
		self.Texto:SetShown(not self.sinCabeza)
		local gap = 28
		local w = floor((ancho - gap) / 2)
		local h1 = pintarColumna(self.H, d.H or {}, d.mia, w)
		local h2 = pintarColumna(self.A, d.A or {}, d.mia, w)
		local h = max(ALTO_COL, h1, h2)
		self.H:ClearAllPoints()
		self.H:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
		self.H:SetSize(w, h)
		self.A:ClearAllPoints()
		self.A:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -y)
		self.A:SetSize(w, h)
		K.Escribir(self.Medio, "&")
		self.Medio:ClearAllPoints()
		self.Medio:SetPoint("CENTER", self, "TOPLEFT", ancho / 2, -(y + h / 2))
		y = y + h
		self:SetSize(ancho, y)
		return y
	end
	return b
end

---------------------------------------------------------------------------
-- El panel del Escritorio (si la API está)
---------------------------------------------------------------------------
local function registrarPanel()
	local E = rawget(_G, "AlfaEscritorio")
	if not (type(E) == "table" and type(E.RegistrarPanel) == "function") or Mc.panel then return end
	Mc.panel = true
	E.RegistrarPanel({ id = "jauria", titulo = "La Jauría por bando", icono = "ic-manada",
		texto = "Cuántos lobos hay de la Horda y de la Alianza.", tam = { 6, 6 }, min = { 5, 5 }, ritmo = 10,
		abrir = function() if M.Pagina then M.Pagina.Abrir() end end,
		crear = function(p, c) p.marcador = Mc.Nuevo(c, { sinCabeza = true }) end,
		pintar = function(p, c, w)
			p.marcador:Llenar()
			p.marcador:ClearAllPoints()
			p.marcador:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
			p.marcador:Acomodar(w)
		end })
end
Mc.RegistrarPanel = registrarPanel
if A and A.OnLogin then A.OnLogin(function() pcall(registrarPanel) end) end
