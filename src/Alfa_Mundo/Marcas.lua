-- Alfa - Mundo: lo que se dibuja encima del mapa continuo (Toxic / La
-- Jauría). GPL-3.0.
--
-- Sobre el arte, en un marco sin escala (los íconos guardan su tamaño con
-- el zoom):
--   * nombres y niveles de cada zona (zonas.nombres, zonas.niveles);
--   * las capas de íconos del motor tal como las publica Polestar.Pins
--     (misiones, raros, mazmorras, vuelos, servicios, la guía...): las
--     mismas que en el mapa del juego, con su cuadro y su clic, encendidas
--     o apagadas por sus propios ajustes (Capas.lua);
--   * tus marcadores (Marcadores.lua), que llegan como una capa más;
--   * tu grupo (esencial.grupo) y tú.
-- Clic derecho en un pin que no es tuyo: seguirlo o guardarlo como marcador.
-- Cada capa del motor entra a partir de un zoom (ZOOM) para no llenar el
-- mundo entero de íconos.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)
local Geo, Lz = M.Geo, M.Lienzo

local type, pairs, ipairs, pcall, tonumber, min, max, floor = type, pairs, ipairs, pcall, tonumber, math.min, math.max, math.floor
local format = string.format

local Mc = {}
M.Marcas = Mc

local MAPA = "Interface\\AddOns\\Alfa\\Media\\Map\\"
local NAV = "Interface\\AddOns\\Alfa\\Media\\Nav\\"
local MEDALLAS = { alfa = MAPA .. "medallion-alfa", halo = MAPA .. "medallion-halo", hearth = MAPA .. "medallion-hearth" }
local FLECHA = "Interface\\Minimap\\MinimapArrow"

-- Las capas de Polestar.Pins que se ven en el mapa de Alfa, de abajo
-- arriba, con el zoom desde el que entran. Los puntos de vuelo (maps.taxi,
-- Maps/TravelPins.lua: los de tu facción y los neutrales, verdes si ya los
-- conoces y ámbar con "?" si no) entran con el continente entero.
local CAPAS_MOTOR = {
	{ "maps.services", 7 }, { "quests.available", 4 }, { "quests.objectives", 3.5 }, { "quests.turnin", 3.5 },
	{ "mundo.salidas", 6 }, { "mundo.portales", 3 },
	{ "rares.treasure", 4 }, { "rares.rare", 3.5 }, { "maps.inns", 3.5 }, { "maps.docks", 2.2 }, { "maps.taxi", 1.5 },
	{ "maps.dungeons", 1.6 }, { "nav.upcoming", 1.6 }, { "nav.goals", 2.5 }, { "nav.spots", 3 }, { "nav.route", 1.4 },
	{ "qol.death", 0 }, { "nav.target", 0 },
}
local MAX_PINES = 320
local NOMBRES_PIN = 9 -- desde qué zoom se escribe el nombre de una salida o un portal (`etiqueta`)
local TAM = { lejos = 13, cerca = 17 } -- tamaño de un pin según el zoom (unidades de la vista)
local ETIQUETAS = { 1.55, 2.1, 22, 34 } -- entran entre [1] y [2], se van entre [3] y [4]

local encima, vista
local vistaAhora -- { cu, cv, k, vw, vh, z }
local W, H = 1002, 668

local function rampa(v, a, b)
	if v <= a then return 0 end
	if v >= b then return 1 end
	local t = (v - a) / (b - a)
	return t * t * (3 - 2 * t)
end

local function color(nombre, alfa)
	local T = A.Theme
	if T and type(T.Color) == "function" then
		local ok, r, g, b = pcall(T.Color, nombre)
		if ok and type(r) == "number" then return r, g, b, alfa or 1 end
	end
	return 1, 1, 1, alfa or 1
end

-- Del mundo (0..1) a la vista (unidades desde su esquina arriba a la izquierda).
local function aVista(u, v)
	local o = vistaAhora
	return (u - o.cu) * W * o.k + o.vw / 2, (v - o.cv) * H * o.k + o.vh / 2
end
Mc.AVista = aVista

local function dentro(x, y, m)
	local o = vistaAhora
	m = m or 0
	return x >= -m and y >= -m and x <= o.vw + m and y <= o.vh + m
end

---------------------------------------------------------------------------
-- Pines: un grupo de botones reusados
---------------------------------------------------------------------------

local libres, usados = {}, {} -- usados: capa -> { índice -> pin }
local enUso = 0

local function medalla()
	local Pins = A.Pins
	local pack = Pins and type(Pins.IconPack) == "function" and Pins.IconPack() or "alfa"
	if pack == "bare" then return nil end
	return MEDALLAS[pack] or MEDALLAS.alfa
end

local function alEntrar(self)
	local p = self.amPin
	if not (p and p.tooltip and GameTooltip) then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	if type(p.tooltip) == "function" then
		local ok, err = pcall(p.tooltip, GameTooltip)
		if not ok and geterrorhandler then geterrorhandler()(err) end
	else
		GameTooltip:SetText(tostring(p.tooltip))
	end
	GameTooltip:Show()
end

local function alSalir(self)
	if GameTooltip and GameTooltip:GetOwner() == self then GameTooltip:Hide() end
end

-- La rueda sobre un pin acerca el mapa igual que sobre el arte.
local function ruedaAlMapa(_, delta)
	local V = M.Ventana
	if V and V.Rueda then V.Rueda(nil, delta) end
end

-- Clic derecho en cualquier pin que no sea uno de tus marcadores: el menú
-- para seguirlo (flecha y ruta) o guardarlo como marcador (Marcadores.lua).
-- Los pines del motor no usan el botón derecho (en el mapa del juego lo
-- dejan pasar al mapa). Un pin sin clic propio (vuelos, barcos, posadas,
-- servicios) abre ese mismo menú también con el clic izquierdo.
local function alClic(self, boton)
	local p = self.amPin
	if not p then return end
	if not p.amMarcador and (boton == "RightButton" or type(p.onClick) ~= "function") then
		local Mk = M.Marcadores
		if Mk and Mk.MenuPin then Mk.MenuPin(self, p) end
		return
	end
	if type(p.onClick) == "function" then
		local ok, err = pcall(p.onClick, boton, self)
		if not ok and geterrorhandler then geterrorhandler()(err) end
	end
end

local function nuevoPin()
	local f = CreateFrame("Button", nil, encima)
	f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	f.brillo = f:CreateTexture(nil, "BACKGROUND")
	f.brillo:SetTexture(MAPA .. "glow")
	f.brillo:SetPoint("CENTER")
	f.fondo = f:CreateTexture(nil, "BORDER")
	f.fondo:SetPoint("CENTER")
	f.icono = f:CreateTexture(nil, "ARTWORK")
	f.icono:SetPoint("CENTER")
	f.aro = f:CreateTexture(nil, "OVERLAY")
	f.aro:SetTexture(NAV .. "ring")
	f.aro:SetPoint("CENTER")
	f.aro:Hide()
	f.texto = f:CreateFontString(nil, "OVERLAY")
	f.texto:SetPoint("CENTER", 0, 0)
	-- La insignia del motor (`badge`): el "?" de un vuelo que aún no conoces.
	f.insignia = f:CreateFontString(nil, "OVERLAY")
	f.insignia:SetPoint("CENTER", f, "TOPRIGHT", -1, -1)
	f.insignia:Hide()
	-- La flechita de una salida de zona (`rumbo`, radianes: 0 = arriba).
	f.rumbo = f:CreateTexture(nil, "OVERLAY")
	f.rumbo:SetTexture(FLECHA)
	f.rumbo:Hide()
	-- El nombre de una salida o un portal (`etiqueta`), bajo el pin.
	f.nombre = f:CreateFontString(nil, "OVERLAY")
	f.nombre:SetPoint("TOP", f, "BOTTOM", 0, -1)
	f.nombre:Hide()
	f:SetScript("OnEnter", alEntrar)
	f:SetScript("OnLeave", alSalir)
	f:SetScript("OnClick", alClic)
	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", ruedaAlMapa)
	return f
end

local function tomar(capa, i)
	local deCapa = usados[capa]
	if not deCapa then
		deCapa = {}
		usados[capa] = deCapa
	end
	local f = deCapa[i]
	if f then
		f.amVisto = true
		return f, false
	end
	f = table.remove(libres) or nuevoPin()
	f.amVisto = true
	deCapa[i] = f
	enUso = enUso + 1
	return f, true
end

local function soltarSinVer()
	for _, deCapa in pairs(usados) do
		for i, f in pairs(deCapa) do
			if not f.amVisto then
				deCapa[i] = nil
				enUso = enUso - 1
				f.amPin = nil
				f:Hide()
				if GameTooltip and GameTooltip:GetOwner() == f then GameTooltip:Hide() end
				libres[#libres + 1] = f
			end
			f.amVisto = false
		end
	end
end

local function rgba(c)
	if type(c) == "table" then return c[1] or c.r or 1, c[2] or c.g or 1, c[3] or c.b or 1, c[4] or c.a or 1 end
	local T = A.Theme
	if T and type(T.Accent) == "function" then
		local ok, r, g, b = pcall(T.Accent)
		if ok and type(r) == "number" then return r, g, b, 1 end
	end
	return 0.9, 0.73, 0.4, 1
end

-- El aspecto de un pin del motor (como Pins.lua: medalla y glifo, o ícono).
local function vestir(f, p, tam)
	local r, g, b, a = rgba(p.color)
	if p.state == "dim" then a = a * 0.6 end
	if p.state == "focus" then tam = tam * 1.3 end
	f.amTam = tam
	local icono = type(p.icon) == "string" and p.icon or nil
	local marca = icono and icono:match("^map:(.+)$")
	f.brillo:SetShown(p.glow and true or false)
	if marca then
		local m = p.medal ~= false and medalla() or nil
		local medal = 2 * floor(tam * 1.4 / 2 + 0.5)
		f:SetSize(medal, medal)
		f.fondo:SetTexture(m)
		f.fondo:SetSize(medal, medal)
		f.fondo:SetVertexColor(1, 1, 1, a)
		f.fondo:SetShown(m ~= nil)
		f.icono:SetTexture(MAPA .. "icon-" .. marca)
		f.icono:SetSize(tam * 27 / 24, tam * 27 / 24)
		f.icono:SetVertexColor(r, g, b, a)
		f.brillo:SetSize(medal * 2.3, medal * 2.3)
	else
		f:SetSize(tam, tam)
		if icono then
			local ruta = icono:find("[\\/]") and icono or (NAV .. icono)
			f.icono:SetTexture(ruta)
			f.icono:SetSize(tam, tam)
			f.icono:SetVertexColor(r, g, b, a)
			f.fondo:SetTexture(NAV .. "pin-fill")
			f.fondo:SetSize(tam * 1.2, tam * 1.2)
			f.fondo:SetVertexColor(color("scrim", 0.55 * a))
			f.fondo:SetShown(p.backdrop and true or false)
		else
			f.fondo:SetTexture(NAV .. "pin-fill")
			f.fondo:SetSize(tam, tam)
			f.fondo:SetVertexColor(r, g, b, a)
			f.fondo:Show()
			f.icono:SetTexture(NAV .. "pin")
			f.icono:SetSize(tam, tam)
			f.icono:SetVertexColor(1, 1, 1, a)
		end
		f.brillo:SetSize(tam * 1.8, tam * 1.8)
	end
	f.brillo:SetVertexColor(r, g, b, 0.5)
	-- El aro fino de color (los marcadores): `ring = { r, g, b, a }`.
	if type(p.ring) == "table" then
		local ar, ag, ab, aa = rgba(p.ring)
		f.aro:SetSize(tam * 1.3, tam * 1.3)
		f.aro:SetVertexColor(ar, ag, ab, aa)
		f.aro:Show()
	else
		f.aro:Hide()
	end
	if p.text then
		local T = A.Theme
		local alto = max(8, tam * 0.6)
		if T and type(T.SetFace) == "function" and type(T.FontSpec) == "function" then
			T.SetFace(f.texto, (T.FontSpec("number")), alto, "OUTLINE")
		else
			f.texto:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", alto, "OUTLINE")
		end
		f.texto:SetText(p.text)
		f.texto:SetTextColor(1, 1, 1, a)
		f.texto:Show()
	else
		f.texto:Hide()
	end
	if type(p.rumbo) == "number" then
		local d = tam * 0.95
		f.rumbo:SetSize(tam * 0.95, tam * 0.95)
		f.rumbo:ClearAllPoints()
		f.rumbo:SetPoint("CENTER", f, "CENTER", -math.sin(p.rumbo) * d, math.cos(p.rumbo) * d)
		if f.rumbo.SetRotation then f.rumbo:SetRotation(p.rumbo) end
		f.rumbo:SetVertexColor(r, g, b, a)
		f.rumbo:Show()
	else
		f.rumbo:Hide()
	end
	if type(p.etiqueta) == "string" then
		local T = A.Theme
		local alto = max(9, floor(tam * 0.7 + 0.5))
		if T and type(T.SetFace) == "function" and type(T.FontSpec) == "function" then
			T.SetFace(f.nombre, (T.FontSpec("label")), alto, "OUTLINE")
		else
			f.nombre:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", alto, "OUTLINE")
		end
		f.nombre:SetText(p.etiqueta)
		f.nombre:SetTextColor(color("text", a))
	else
		f.nombre:SetText("")
	end
	if p.badge ~= nil then
		local T = A.Theme
		local alto = max(8, floor(tam * 0.62 + 0.5))
		if T and type(T.SetFace) == "function" and type(T.FontSpec) == "function" then
			T.SetFace(f.insignia, (T.FontSpec("number")), alto, "OUTLINE")
		else
			f.insignia:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", alto, "OUTLINE")
		end
		f.insignia:SetText(tostring(p.badge))
		f.insignia:SetTextColor(r, g, b, a)
		f.insignia:Show()
	else
		f.insignia:Hide()
	end
	f:SetFrameLevel(encima:GetFrameLevel() + (tonumber(p.priority) and min(40, floor(p.priority / 3)) or 1) + 2)
end

local function poner(f, x, y)
	f:ClearAllPoints()
	f:SetPoint("CENTER", encima, "TOPLEFT", x, -y)
	f:Show()
end

---------------------------------------------------------------------------
-- Capas del motor: sus pines pasados a unidades de mundo, una vez por
-- versión de la capa (Pins.GetLayer devuelve una tabla nueva en cada SetLayer)
---------------------------------------------------------------------------

local cache = {} -- capa -> { pines, u = {}, v = {} }
local dibujadas = {} -- capa -> la tabla de pines (o false) que se dibujó por última vez
local zAhora = 1

local function puntos(nombre)
	local Pins = A.Pins
	if not (Pins and type(Pins.GetLayer) == "function" and type(Pins.IsLayerVisible) == "function") then return nil end
	if not Pins.IsLayerVisible(nombre) then return nil end
	local pines = Pins.GetLayer(nombre)
	if type(pines) ~= "table" then return nil end
	local c = cache[nombre]
	if c and c.pines == pines then return c end
	c = { pines = pines, u = {}, v = {} }
	for i = 1, #pines do
		local p = pines[i]
		if type(p) == "table" and not p.areaOnly then
			local u, v = Geo.DePin(p)
			c.u[i], c.v[i] = u or false, v or false
		else
			c.u[i], c.v[i] = false, false
		end
	end
	cache[nombre] = c
	return c
end

-- Una capa de Pins en la vista; n: los pines puestos hasta ahora. -> n
local function dibujarCapa(nombre, desde, z, tam, n)
	local c = puntos(nombre)
	dibujadas[nombre] = c and c.pines or false
	if z < desde or n > MAX_PINES then return n end
	if not c then return n end
	local pines = c.pines
	for i = 1, #pines do
		local u = c.u[i]
		if u then
			local x, y = aVista(u, c.v[i])
			if dentro(x, y, 12) then
				n = n + 1
				if n > MAX_PINES then return n end
				local p = pines[i]
				local f, nuevo = tomar(nombre, i)
				if nuevo or f.amPin ~= p or f.amZ ~= tam then
					f.amPin, f.amZ = p, tam
					vestir(f, p, (tonumber(p.size) or 16) / 16 * tam)
				end
				local conNombre = p.etiqueta ~= nil and zAhora >= NOMBRES_PIN
				if f.nombre:IsShown() ~= conNombre then f.nombre:SetShown(conNombre) end
				poner(f, x, y)
			end
		end
	end
	return n
end

local function dibujarMotor(z, tam)
	local n = 0
	for _, def in ipairs(CAPAS_MOTOR) do n = dibujarCapa(def[1], def[2], z, tam, n) end
	-- Las capas de otros módulos que publican sus pines en Alfa.Pins con el
	-- mismo id (o el de `pines`) también salen aquí, desde su `zoom`.
	local Capas = M.Capas
	for _, e in ipairs(Capas.Modulos()) do
		if Capas.Activa(e) then n = dibujarCapa(e.pines or e.id, e.zoom or 2, z, tam, n) end
	end
end

---------------------------------------------------------------------------
-- Nombres y niveles de zona
---------------------------------------------------------------------------

local etiquetas = {}

local function etiqueta(i)
	local e = etiquetas[i]
	if e then return e end
	local Wd = A.Widgets
	local T = A.Theme
	e = CreateFrame("Frame", nil, encima)
	e:SetSize(160, 32)
	e:SetFrameLevel(encima:GetFrameLevel() + 1)
	e.Nombre = Wd.Text(e, "label", "text")
	e.Nombre:SetPoint("BOTTOM", e, "CENTER", 0, 1)
	e.Nombre:SetJustifyH("CENTER")
	e.Niveles = Wd.Text(e, "number", "quest")
	e.Niveles:SetPoint("TOP", e, "CENTER", 0, -1)
	e.Niveles:SetJustifyH("CENTER")
	if T and type(T.SetOutline) == "function" then
		T.SetOutline(e.Nombre, true)
		T.SetOutline(e.Niveles, true)
	end
	etiquetas[i] = e
	return e
end

local function dibujarEtiquetas(z)
	local nombres = A.Get("mundo.nombres") ~= false
	local niveles = A.Get("maps.zoneLevels") and true or false
	local n = 0
	local a = rampa(z, ETIQUETAS[1], ETIQUETAS[2]) * (1 - rampa(z, ETIQUETAS[3], ETIQUETAS[4]))
	if (nombres or niveles) and a > 0.01 then
		local o = vistaAhora
		for _, zona in ipairs(Lz.Zonas()) do
			local ancho = zona.w * o.k
			if ancho >= 70 then
				local x, y = aVista((zona.l + zona.w / 2) / W, (zona.t + zona.h / 2) / H)
				if dentro(x, y, -10) then
					n = n + 1
					local e = etiqueta(n)
					if not e.amId or e.amId ~= zona.id or e.amNombres ~= nombres or e.amNiveles ~= niveles then
						e.amId, e.amNombres, e.amNiveles = zona.id, nombres, niveles
						e.Nombre:SetText(nombres and (Geo.Nombre(zona.id) or "") or "")
						local lo, hi = Geo.Niveles(zona.id)
						local texto, col = Geo.TextoNiveles(lo, hi)
						if niveles and texto then
							e.Niveles:SetText(texto)
							A.Widgets.Color(e.Niveles, col or "quest")
						else
							e.Niveles:SetText("")
						end
					end
					e:SetAlpha(a)
					e:ClearAllPoints()
					e:SetPoint("CENTER", encima, "TOPLEFT", x, -y)
					e:Show()
				end
			end
		end
	end
	for i = n + 1, #etiquetas do etiquetas[i]:Hide() end
end

-- Al cambiar de nivel, de tema o de íconos: todo se vuelve a vestir.
function Mc.OlvidarEtiquetas()
	for _, e in ipairs(etiquetas) do e.amId = nil end
end

function Mc.Reestilar()
	Mc.OlvidarEtiquetas()
	for _, deCapa in pairs(usados) do
		for _, f in pairs(deCapa) do f.amPin = nil end
	end
	if M.Ventana and M.Ventana.Repintar then M.Ventana.Repintar() end
end

---------------------------------------------------------------------------
-- Tú y tu grupo
---------------------------------------------------------------------------

local yo, grupo = nil, {}

local function clase(unidad)
	if not UnitClass then return nil end
	local ok, _, archivo = pcall(UnitClass, unidad)
	local C = A.Compat
	if not ok or (C and C.IsSecret and C.IsSecret(archivo)) or type(archivo) ~= "string" then return nil end
	return archivo
end

local function punto(i)
	local f = grupo[i]
	if f then return f end
	f = CreateFrame("Button", nil, encima)
	f:SetSize(14, 14)
	f:SetFrameLevel(encima:GetFrameLevel() + 60)
	f.t = f:CreateTexture(nil, "ARTWORK")
	f.t:SetAllPoints()
	-- El punto de grupo del juego (atlas de Forever);
	-- si falta, el disco de los pines del motor.
	if not (f.t.SetAtlas and f.t:SetAtlas("WhiteCircle-RaidBlips")) then f.t:SetTexture(NAV .. "pin-fill") end
	f:SetScript("OnEnter", function(self)
		if not (GameTooltip and self.amNombre) then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(self.amNombre, 1, 1, 1)
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", alSalir)
	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", ruedaAlMapa)
	grupo[i] = f
	return f
end

local function unidades()
	local out = {}
	if IsInRaid and IsInRaid() then
		for i = 1, 40 do out[#out + 1] = "raid" .. i end
	elseif IsInGroup and IsInGroup() then
		for i = 1, 4 do out[#out + 1] = "party" .. i end
	end
	return out
end

local function dibujarGrupo()
	local n = 0
	local on = A.Get("mundo.grupo") ~= false
	if on then
		-- Sin UnitIsUnit ni UnitExists: en una banda tu propio punto queda bajo
		-- tu flecha, y el juego no da posición de quien no está (ni valores
		-- secretos que probar).
		for _, unidad in ipairs(unidades()) do
			do
				local u, v = Geo.Unidad(unidad)
				if u then
					local x, y = aVista(u, v)
					if dentro(x, y, 8) then
						n = n + 1
						local f = punto(n)
						local cl = clase(unidad)
						local T = A.Theme
						local r, g, b
						if cl and T and type(T.ClassColor) == "function" then r, g, b = T.ClassColor(cl) end
						f.t:SetVertexColor(r or 0.55, g or 0.8, b or 1, 1)
						local C = A.Compat
						local nombre = C and type(C.UnitFullName) == "function" and C.UnitFullName(unidad)
						f.amNombre = type(nombre) == "string" and nombre or nil
						f:ClearAllPoints()
						f:SetPoint("CENTER", encima, "TOPLEFT", x, -y)
						f:Show()
					end
				end
			end
		end
	end
	for i = n + 1, #grupo do grupo[i]:Hide() end
end

local function dibujarYo()
	if not yo then
		yo = CreateFrame("Frame", nil, encima)
		yo:SetSize(30, 30)
		yo:SetFrameLevel(encima:GetFrameLevel() + 70)
		yo.halo = yo:CreateTexture(nil, "BACKGROUND")
		yo.halo:SetTexture(MAPA .. "glow")
		yo.halo:SetSize(46, 46)
		yo.halo:SetPoint("CENTER")
		yo.flecha = yo:CreateTexture(nil, "OVERLAY")
		yo.flecha:SetTexture(FLECHA)
		yo.flecha:SetSize(30, 30)
		yo.flecha:SetPoint("CENTER")
	end
	local u, v = Geo.Jugador()
	if not u then
		yo:Hide()
		return
	end
	local x, y = aVista(u, v)
	local r, g, b = color("accent")
	yo.halo:SetVertexColor(r, g, b, 0.45)
	local f = Geo.Orientacion()
	if f and yo.flecha.SetRotation then yo.flecha:SetRotation(f) end
	yo:ClearAllPoints()
	yo:SetPoint("CENTER", encima, "TOPLEFT", x, -y)
	yo:Show()
end

---------------------------------------------------------------------------
-- Entrada
---------------------------------------------------------------------------

function Mc.Crear(padre)
	if encima then return encima end
	vista = padre
	encima = CreateFrame("Frame", nil, padre)
	encima:SetAllPoints(padre)
	encima:SetFrameLevel(padre:GetFrameLevel() + 30)
	return encima
end

-- Tras cada cambio de la vista (mover, zoom, tamaño).
function Mc.Colocar(cu, cv, k, vw, vh, z)
	if not encima then return end
	W, H = Lz.Tamano()
	local o = vistaAhora or {}
	vistaAhora = o
	o.cu, o.cv, o.k, o.vw, o.vh, o.z = cu, cv, k, vw, vh, z
	zAhora = z
	local tam = TAM.lejos + (TAM.cerca - TAM.lejos) * rampa(z, 2, 16)
	tam = floor(tam * 2 + 0.5) / 2
	dibujarEtiquetas(z)
	dibujarMotor(z, tam)
	soltarSinVer()
	dibujarGrupo()
	dibujarYo()
end

-- Alguna capa de Pins cambió (o se mostró u ocultó) desde que se dibujó.
local function capasCambiaron()
	local Pins = A.Pins
	if not (Pins and type(Pins.GetLayer) == "function" and type(Pins.IsLayerVisible) == "function") then return false end
	local function cambio(nombre)
		local p = Pins.IsLayerVisible(nombre) and Pins.GetLayer(nombre)
		if type(p) ~= "table" then p = false end
		return p ~= dibujadas[nombre]
	end
	for _, def in ipairs(CAPAS_MOTOR) do
		if cambio(def[1]) then return true end
	end
	local Capas = M.Capas
	for _, e in ipairs(Capas.Modulos()) do
		if cambio(e.pines or e.id) then return true end
	end
	return false
end

-- Lo que se mueve solo, unas veces por segundo: tú y tu grupo siempre; los
-- pines solo si alguna capa cambió (la guía, un vuelo descubierto...). Con el
-- mapa quieto no se recorre ningún pin.
function Mc.Latido()
	if not (encima and vistaAhora) then return end
	local o = vistaAhora
	if capasCambiaron() then
		Mc.Colocar(o.cu, o.cv, o.k, o.vw, o.vh, o.z)
		return
	end
	dibujarGrupo()
	dibujarYo()
end

-- Al abrir el mapa: si alguna capa necesita el Codex (mazmorras, servicios,
-- raros), se carga una vez; el motor rehace sus capas al terminar.
function Mc.PrepararDatos()
	local X = A.Codex
	if not (X and type(X.IsLoaded) == "function" and type(X.Load) == "function") then return end
	if X.IsLoaded() then return end
	if A.Get("maps.dungeonPins") or A.Get("maps.servicePins") or A.Get("rares.worldRares") or A.Get("rares.worldTreasures") then
		pcall(X.Load)
	end
end

function Mc.CuantosPines() return enUso end
