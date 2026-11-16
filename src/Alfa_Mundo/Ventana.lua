-- Alfa - Mundo: la ventana del mapa continuo (Toxic / La Jauría). GPL-3.0.
--
-- Una ventana propia de Alfa, aparte del mapa de Blizzard: no toca
-- WorldMapFrame ni reemplaza ninguna de sus funciones, así que no puede
-- contaminarlo. Rueda del ratón: acercar y alejar donde está el cursor.
-- Arrastrar: mover. Doble clic: acercar. Clic derecho: alejar. Mayús+clic:
-- poner ahí el destino de la flecha. Abajo, la zona bajo el cursor con su
-- rango de niveles y las coordenadas tuyas y del cursor.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)
local W, T = A.Widgets, A.Theme
local Geo, Lz, Mc, Capas, Panel = M.Geo, M.Lienzo, M.Marcas, M.Capas, M.Panel

local type, pairs, ipairs, pcall, tonumber, min, max, floor, abs = type, pairs, ipairs, pcall, tonumber, math.min, math.max, math.floor, math.abs
local format = string.format

local V = {}
M.Ventana = V

local NOMBRE = "AlfaMundoMapa"
local CAB, PIE, BORDE = 48, 28, 1
local Z_MIN, Z_MAX = 0.9, 90
local PASO = 1.4          -- zoom por golpe de rueda
local SUAVE = 14          -- qué tan rápido llega el zoom a su meta
local LATIDO = 0.1        -- segundos entre repintados de lo que se mueve solo
local DOBLE = 0.32        -- segundos para un doble clic

local F, vista
local cu, cv, z = 0.5, 0.5, 1          -- la vista: centro y zoom
local meta = { z = 1 }                 -- a dónde va: zoom (y ancla) o centro
local arrastre                          -- { x, y, cu, cv, movido }
local sucio = true
local reloj, relojTitulo = 0, 0
local ultimoClic = { t = 0, x = 0, y = 0 }
local sinArte = false
local porEncuadrar -- { mapa } mientras la ventana recién abierta no tiene tamaño

---------------------------------------------------------------------------
-- Medidas
---------------------------------------------------------------------------

local function tamVista()
	local w, h = vista:GetWidth() or 0, vista:GetHeight() or 0
	if type(w) ~= "number" or w < 1 then w = 1 end
	if type(h) ~= "number" or h < 1 then h = 1 end
	return w, h
end

local function escala(zoom)
	local Wm, Hm = Lz.Tamano()
	local vw, vh = tamVista()
	return min(vw / Wm, vh / Hm) * zoom
end

-- El cursor sobre la vista (unidades de la vista) | nil si está fuera.
local function cursor()
	if not (vista and GetCursorPosition) then return nil end
	local x, y = GetCursorPosition()
	local s = vista:GetEffectiveScale()
	local l, t = vista:GetLeft(), vista:GetTop()
	if not (type(x) == "number" and type(s) == "number" and s > 0 and type(l) == "number" and type(t) == "number") then return nil end
	x, y = x / s - l, t - y / s
	local vw, vh = tamVista()
	if x < 0 or y < 0 or x > vw or y > vh then return nil end
	return x, y
end

-- Un punto de la vista en el mundo (0..1).
local function aMundo(x, y)
	local Wm, Hm = Lz.Tamano()
	local vw, vh = tamVista()
	local k = escala(z)
	return cu + (x - vw / 2) / (k * Wm), cv + (y - vh / 2) / (k * Hm)
end

local function encajar()
	cu, cv = Geo.Encajar(cu, cv)
	if z < Z_MIN then z = Z_MIN elseif z > Z_MAX then z = Z_MAX end
end

---------------------------------------------------------------------------
-- Dibujar
---------------------------------------------------------------------------

local function colocar()
	sucio = false
	if sinArte then return end
	encajar()
	local vw, vh = tamVista()
	local k = escala(z)
	Lz.Colocar(cu, cv, k, vw, vh, z)
	Mc.Colocar(cu, cv, k, vw, vh, z)
	if Lz.Pendiente() then sucio = true end
end

function V.Repintar() sucio = true end

-- Lleva la vista a un zoom manteniendo fijo el punto (x, y) de la vista.
local function zoomEn(nuevo, x, y)
	nuevo = max(Z_MIN, min(Z_MAX, nuevo))
	if not (x and y) then
		local vw, vh = tamVista()
		x, y = vw / 2, vh / 2
	end
	local u, v = aMundo(x, y)
	meta.z, meta.x, meta.y, meta.u, meta.v = nuevo, x, y, u, v
	meta.cu, meta.cv = nil, nil
end

-- Desliza la vista hasta (u, v) con el zoom dado.
local function irA(u, v, zoom)
	meta.cu, meta.cv = Geo.Encajar(u, v)
	meta.z = max(Z_MIN, min(Z_MAX, zoom or z))
	meta.u = nil
end

-- El zoom que hace caber un mapa en la vista.
local function zoomPara(mapa, holgura)
	local l, t, w, h = Lz.RectZona(mapa)
	if not l then return nil end
	local Wm, Hm = Lz.Tamano()
	local vw, vh = tamVista()
	local base = min(vw / Wm, vh / Hm)
	local zz = min(vw / (max(w, 1e-4) * Wm), vh / (max(h, 1e-4) * Hm)) / base
	return zz * (holgura or 0.85), l + w / 2, t + h / 2
end

-- suave: deslizarse hasta ahí; al abrir, el zoom de tu zona (si no, nunca
-- se aleja de lo que ya ves).
local function centrarEnMi(suave, alAbrir)
	local u, v, mapa = Geo.Jugador()
	if not u then return false end
	local Ccompat = A.Compat
	local zona = Ccompat and type(Ccompat.GetUnitZone) == "function" and Ccompat.GetUnitZone("player") or mapa
	local zz = zoomPara(zona) or zoomPara(mapa) or 12
	zz = min(zz, 26)
	if not alAbrir then zz = max(z, zz) end
	if suave then
		irA(u, v, zz)
	else
		cu, cv, z = u, v, zz
		meta.z, meta.cu, meta.cv, meta.u = z, nil, nil, nil
		sucio = true
	end
	return true
end

local function animar(dt)
	local f = min(1, dt * SUAVE)
	local cambio = false
	if meta.cu then
		local du, dv = meta.cu - cu, meta.cv - cv
		cu, cv = cu + du * f, cv + dv * f
		if abs(du) < 1e-6 and abs(dv) < 1e-6 then cu, cv, meta.cu, meta.cv = meta.cu, meta.cv, nil, nil end
		cambio = true
	end
	if abs(meta.z - z) > 1e-4 then
		z = z * (meta.z / z) ^ f
		if abs(meta.z - z) / meta.z < 0.002 then z = meta.z end
		if meta.u then
			-- El punto bajo el cursor no se mueve mientras se acerca.
			local Wm, Hm = Lz.Tamano()
			local vw, vh = tamVista()
			local k = escala(z)
			cu = meta.u - (meta.x - vw / 2) / (k * Wm)
			cv = meta.v - (meta.y - vh / 2) / (k * Hm)
		end
		cambio = true
	end
	return cambio
end

---------------------------------------------------------------------------
-- La barra de abajo: la zona bajo el cursor y las coordenadas
---------------------------------------------------------------------------

local function textoCoords(x, y)
	local Maps = A.Maps
	if Maps and type(Maps.FormatCoords) == "function" then return Maps.FormatCoords(x, y) end
	return format("%.1f, %.1f", x or 0, y or 0)
end

local mostrado = {}

local function actualizarPie()
	local x, y = cursor()
	local zona, cx, cy
	if x then
		local u, v = aMundo(x, y)
		local _, zz = Geo.Cadena(u, v)
		zona = zz
		if zona then cx, cy = Geo.AMapa(zona, u, v) end
	end
	-- La zona y su rango
	if zona ~= mostrado.zona then
		mostrado.zona = zona
		if zona then
			local nombre = Geo.Nombre(zona) or ""
			local lo, hi = Geo.Niveles(zona)
			local texto, col = Geo.TextoNiveles(lo, hi)
			F.Zona:SetText(nombre)
			if texto and A.Get("maps.zoneLevels") then
				F.Niveles:SetText(format(L["Niveles %s"], texto))
				W.Color(F.Niveles, col or "quest")
			else
				F.Niveles:SetText("")
			end
		else
			F.Zona:SetText("")
			F.Niveles:SetText("")
		end
		F.Ayuda:SetShown(not zona)
	end
	-- Coordenadas
	local partes = {}
	if A.Get("maps.coords") ~= false then
		local _, _, mapa, px, py = Geo.Jugador()
		if mapa then partes[#partes + 1] = L["Tú"] .. "  " .. textoCoords(px, py) end
		if cx and cx >= 0 and cx <= 100 and cy >= 0 and cy <= 100 then partes[#partes + 1] = L["Cursor"] .. "  " .. textoCoords(cx, cy) end
	end
	local texto = table.concat(partes, "     ")
	if texto ~= mostrado.coords then
		mostrado.coords = texto
		F.Coords:SetText(texto)
	end
end

-- El subtítulo: lo que hay en el centro de la vista.
local function actualizarTitulo()
	local texto
	if z >= 3 then
		local _, zona = Geo.Cadena(cu, cv)
		if zona then
			texto = Geo.Nombre(zona)
			local lo, hi = Geo.Niveles(zona)
			local niveles = Geo.TextoNiveles(lo, hi)
			if texto and niveles then texto = texto .. "  ·  " .. niveles end
		end
	end
	if not texto and z >= 1.5 then
		local cont = Geo.Cadena(cu, cv)
		texto = cont and Geo.Nombre(cont)
	end
	texto = texto or Geo.Nombre(Geo.MUNDO) or L["Azeroth"]
	if Capas.Limpio() then texto = texto .. "  ·  " .. L["Modo limpio"] end
	F.Sub:SetText(texto)
end

local function pintarBotones()
	if not F then return end
	W.SetIconState(F.BLimpio, Capas.Limpio())
	W.SetIconState(F.BCapas, Panel.Visible())
end

---------------------------------------------------------------------------
-- Ratón
---------------------------------------------------------------------------

local function ponerDestino(x, y)
	local u, v = aMundo(x, y)
	local _, zona = Geo.Cadena(u, v)
	local Nav = A.Nav
	if not (zona and Nav and type(Nav.SetTarget) == "function") then
		N.Imprimir(L["Ahí no se puede poner un destino."])
		return
	end
	local px, py = Geo.AMapa(zona, u, v)
	local nombre = Geo.Nombre(zona) or L["Destino"]
	if Nav.SetTarget(zona, px, py, nombre) then
		N.Imprimir(format(L["La flecha te lleva a %s (%s)."], nombre, textoCoords(px, py)))
		Mc.Latido()
	end
end

local function rueda(_, delta)
	if sinArte or type(delta) ~= "number" then return end
	local x, y = cursor()
	zoomEn(meta.z * PASO ^ delta, x, y)
end
V.Rueda = rueda

local function alPresionar(_, boton)
	if boton ~= "LeftButton" or sinArte then return end
	local x, y = cursor()
	if not x then return end
	arrastre = { x = x, y = y, cu = cu, cv = cv, movido = false }
	meta.cu, meta.cv, meta.u = nil, nil, nil
	meta.z = z
end

local function alSoltar(_, boton)
	if sinArte then return end
	local x, y = cursor()
	if boton == "RightButton" then
		if x then zoomEn(meta.z / 2, x, y) end
		return
	end
	if boton ~= "LeftButton" then return end
	local a = arrastre
	arrastre = nil
	if not a or a.movido or not x then return end
	if IsShiftKeyDown and IsShiftKeyDown() then
		ponerDestino(x, y)
		return
	end
	local ahora = GetTime and GetTime() or 0
	if ahora - ultimoClic.t < DOBLE and abs(x - ultimoClic.x) < 8 and abs(y - ultimoClic.y) < 8 then
		zoomEn(meta.z * 2, x, y)
		ultimoClic.t = 0
	else
		ultimoClic.t, ultimoClic.x, ultimoClic.y = ahora, x, y
	end
end

local function arrastrar()
	local a = arrastre
	if not a then return false end
	if not (IsMouseButtonDown and IsMouseButtonDown("LeftButton")) then
		arrastre = nil
		return false
	end
	local x, y = cursor()
	if not x then return false end
	local dx, dy = x - a.x, y - a.y
	if not a.movido and abs(dx) + abs(dy) < 3 then return false end
	a.movido = true
	local Wm, Hm = Lz.Tamano()
	local k = escala(z)
	cu, cv = a.cu - dx / (k * Wm), a.cv - dy / (k * Hm)
	return true
end

local encuadrar -- (abajo, con V.Abrir)

local function alActualizar(_, dt)
	dt = type(dt) == "number" and dt or 0
	if porEncuadrar and encuadrar then encuadrar() end
	if arrastrar() then sucio = true end
	if animar(dt) then sucio = true end
	if sucio then colocar() end
	reloj = reloj + dt
	if reloj >= LATIDO then
		reloj = 0
		if not sucio then Mc.Latido() end
		actualizarPie()
	end
	relojTitulo = relojTitulo + dt
	if relojTitulo >= 0.5 then
		relojTitulo = 0
		actualizarTitulo()
		pintarBotones()
	end
end

---------------------------------------------------------------------------
-- Ventana
---------------------------------------------------------------------------

-- Como Maps.CompactFrame del motor: el centro respecto al de la pantalla.
local function guardarGeometria()
	local cx, cy = F:GetCenter()
	local ux, uy = UIParent:GetCenter()
	if not (cx and ux) then return end
	local s = F:GetEffectiveScale() / UIParent:GetEffectiveScale()
	A.Set("mundo.ventana", { "CENTER", floor(cx * s - ux + 0.5), floor(cy * s - uy + 0.5), floor(F:GetWidth() + 0.5), floor(F:GetHeight() + 0.5) })
end

local function colocarVentana()
	local g = A.Get("mundo.ventana")
	local uw, uh = UIParent:GetWidth() or 1280, UIParent:GetHeight() or 800
	local w = min(1120, floor(uw * 0.72))
	local h = min(floor(uh * 0.8), floor(w * 0.66))
	F:ClearAllPoints()
	if type(g) == "table" and type(g[1]) == "string" then
		F:SetSize(max(560, tonumber(g[4]) or w), max(380, tonumber(g[5]) or h))
		F:SetPoint(g[1], UIParent, g[1], tonumber(g[2]) or 0, tonumber(g[3]) or 0)
	else
		F:SetSize(w, h)
		F:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
	end
end

local function botonCab(icono, tip, fn)
	local b = W.IconButton(F.Cab, icono, 30, tip, fn, 16)
	return b
end

local function construir()
	F = CreateFrame("Frame", NOMBRE, A.UIParent)
	F:SetFrameStrata("HIGH")
	F:SetToplevel(true)
	F:SetClampedToScreen(true)
	F:EnableMouse(true)
	F:SetMovable(true)
	F:SetResizable(true)
	if F.SetResizeBounds then F:SetResizeBounds(560, 380) end
	F:Hide()
	T.Skin(F, "window")
	W.Rim(F, { width = 520 })

	-- Cabecera: título, lo que hay al centro, y los botones.
	local cab = CreateFrame("Frame", nil, F)
	cab:SetPoint("TOPLEFT", F, "TOPLEFT", 0, 0)
	cab:SetPoint("TOPRIGHT", F, "TOPRIGHT", 0, 0)
	cab:SetHeight(CAB)
	cab:EnableMouse(true)
	cab:RegisterForDrag("LeftButton")
	cab:SetScript("OnDragStart", function() F:StartMoving() end)
	cab:SetScript("OnDragStop", function()
		F:StopMovingOrSizing()
		guardarGeometria()
	end)
	F.Cab = cab
	F.Emblema = cab:CreateTexture(nil, "ARTWORK")
	F.Emblema:SetTexture(T.Media("icon-explore"))
	F.Emblema:SetSize(22, 22)
	F.Emblema:SetPoint("LEFT", cab, "LEFT", 16, 0)
	W.Color(F.Emblema, "accent")
	F.Titulo = W.Text(cab, "title", "text")
	F.Titulo:SetPoint("TOPLEFT", F.Emblema, "TOPRIGHT", 10, 4)
	F.Titulo:SetText(L["Mapa del mundo"])
	F.Sub = W.Text(cab, "small", "textDim")
	F.Sub:SetPoint("TOPLEFT", F.Titulo, "BOTTOMLEFT", 0, -2)

	F.BCerrar = botonCab("close", L["Cerrar"], function() F:Hide() end)
	F.BCerrar:SetPoint("RIGHT", cab, "RIGHT", -10, 0)
	F.BOpciones = botonCab("gear", L["Opciones de Mundo"], function() N.Abrir("mundo") end)
	F.BOpciones:SetPoint("RIGHT", F.BCerrar, "LEFT", -2, 0)
	F.BJuego = botonCab("window", L["Abrir el mapa del juego"], function()
		local C = A.Compat
		if C and type(C.CanOpenWorldMap) == "function" and C.CanOpenWorldMap() and type(C.OpenWorldMap) == "function" then
			local _, zona = Geo.Cadena(cu, cv)
			if not C.OpenWorldMap(zona) then N.Imprimir(L["El mapa del juego no se abre en combate."]) end
		end
	end)
	F.BJuego:SetPoint("RIGHT", F.BOpciones, "LEFT", -2, 0)
	F.BCentrar = botonCab("qol-target", L["Centrar en mí"], function()
		if not centrarEnMi(true) then N.Imprimir(L["Aquí el juego no da tu posición (por ejemplo, dentro de una mazmorra)."]) end
	end)
	F.BCentrar:SetPoint("RIGHT", F.BJuego, "LEFT", -10, 0)
	F.BLimpio = botonCab("compact", L["Modo limpio: solo tú, tu grupo y la guía"], function()
		Capas.AlternarLimpio()
	end)
	F.BLimpio:SetPoint("RIGHT", F.BCentrar, "LEFT", -2, 0)
	F.BCapas = botonCab("layers", L["Capas: elige qué se ve en el mapa"], function(self)
		Panel.Alternar(self, { punto = "TOPRIGHT", relativo = "BOTTOMRIGHT", x = 0, y = -4, sinMapa = true })
		pintarBotones()
	end)
	F.BCapas:SetPoint("RIGHT", F.BLimpio, "LEFT", -2, 0)
	F.Sub:SetPoint("RIGHT", F.BCapas, "LEFT", -12, 0)

	-- La vista del mapa
	vista = CreateFrame("Frame", nil, F)
	vista:SetPoint("TOPLEFT", F, "TOPLEFT", BORDE, -CAB)
	vista:SetPoint("BOTTOMRIGHT", F, "BOTTOMRIGHT", -BORDE, PIE)
	vista:EnableMouse(true)
	vista:EnableMouseWheel(true)
	local fondo = vista:CreateTexture(nil, "BACKGROUND", nil, -8)
	fondo:SetAllPoints(vista)
	fondo:SetTexture(T.Media("white"))
	W.Color(fondo, "shade")
	vista:SetScript("OnMouseWheel", A.Safe(rueda))
	vista:SetScript("OnMouseDown", A.Safe(alPresionar))
	vista:SetScript("OnMouseUp", A.Safe(alSoltar))
	vista:SetScript("OnSizeChanged", function() sucio = true end)
	F.Vista = vista
	local lienzo = Lz.Crear(vista)
	Mc.Crear(vista)
	if not lienzo then
		sinArte = true
		F.SinArte = W.Text(vista, "body", "textDim")
		F.SinArte:SetPoint("CENTER", vista, "CENTER", 0, 0)
		F.SinArte:SetText(L["Este cliente no da el arte del mapa: no se puede dibujar el mapa continuo."])
	end

	-- Zoom con botones, abajo a la derecha de la vista.
	local zoom = CreateFrame("Frame", nil, vista)
	zoom:SetSize(30, 64)
	zoom:SetPoint("BOTTOMRIGHT", vista, "BOTTOMRIGHT", -10, 10)
	zoom:SetFrameLevel(vista:GetFrameLevel() + 80)
	F.Mas = W.Button(zoom, "+", function() zoomEn(meta.z * 2) end, { width = 30, height = 30 })
	F.Mas:SetPoint("TOP", zoom, "TOP", 0, 0)
	F.Mas:SetWidth(30)
	F.Mas.psTip = L["Acercar"]
	F.Menos = W.Button(zoom, "–", function() zoomEn(meta.z / 2) end, { width = 30, height = 30 })
	F.Menos:SetPoint("BOTTOM", zoom, "BOTTOM", 0, 0)
	F.Menos:SetWidth(30)
	F.Menos.psTip = L["Alejar"]

	-- Pie: zona bajo el cursor, ayuda y coordenadas.
	local pie = CreateFrame("Frame", nil, F)
	pie:SetPoint("BOTTOMLEFT", F, "BOTTOMLEFT", BORDE, BORDE)
	pie:SetPoint("BOTTOMRIGHT", F, "BOTTOMRIGHT", -BORDE, BORDE)
	pie:SetHeight(PIE - BORDE)
	local regla = W.Divider(pie)
	regla:SetPoint("TOPLEFT", pie, "TOPLEFT", 0, 0)
	regla:SetPoint("TOPRIGHT", pie, "TOPRIGHT", 0, 0)
	F.Zona = W.Text(pie, "label", "text")
	F.Zona:SetPoint("LEFT", pie, "LEFT", 14, 0)
	F.Niveles = W.Text(pie, "number", "quest")
	F.Niveles:SetPoint("LEFT", F.Zona, "RIGHT", 10, 0)
	F.Ayuda = W.Text(pie, "small", "textMuted")
	F.Ayuda:SetPoint("LEFT", pie, "LEFT", 14, 0)
	F.Ayuda:SetText(L["Rueda: acercar · Arrastra: mover · Doble clic: acercar · Mayús+clic: destino de la flecha"])
	F.Coords = W.Text(pie, "number", "textDim")
	F.Coords:SetPoint("RIGHT", pie, "RIGHT", -34, 0)
	F.Coords:SetJustifyH("RIGHT")
	F.Ayuda:SetPoint("RIGHT", F.Coords, "LEFT", -12, 0)

	-- Asa para cambiar el tamaño.
	local asa = CreateFrame("Button", nil, F)
	asa:SetSize(18, 18)
	asa:SetPoint("BOTTOMRIGHT", F, "BOTTOMRIGHT", -4, 4)
	asa:SetFrameLevel(F:GetFrameLevel() + 40)
	asa.t = asa:CreateTexture(nil, "OVERLAY")
	asa.t:SetAllPoints()
	asa.t:SetTexture(T.Media("resize"))
	W.Color(asa.t, "textMuted")
	asa:SetScript("OnMouseDown", function() F:StartSizing("BOTTOMRIGHT") end)
	asa:SetScript("OnMouseUp", function()
		F:StopMovingOrSizing()
		guardarGeometria()
		sucio = true
	end)

	F:SetScript("OnUpdate", A.Safe(alActualizar))
	F:SetScript("OnShow", function(self)
		local An = A.Anim
		if An and An.To then An.To(self, "alpha", 0, 1, An.FAST, "out") end
		mostrado.zona, mostrado.coords = -1, nil
		pintarBotones()
		actualizarTitulo()
	end)
	F:SetScript("OnHide", function()
		arrastre = nil
		if Panel.Visible() then Panel.Ocultar() end
	end)
	if A.CloseOnEscape then A.CloseOnEscape(NOMBRE) end
	colocarVentana()
	Capas.AlCambiar(function()
		sucio = true
		pintarBotones()
		if F:IsShown() then actualizarTitulo() end
	end)
end

-- Por encima del mapa del juego si está abierto (su estrato, uno más).
local SIGUIENTE = { LOW = "MEDIUM", MEDIUM = "HIGH", HIGH = "DIALOG", DIALOG = "FULLSCREEN", FULLSCREEN = "FULLSCREEN_DIALOG" }
local function estrato()
	local mapa = WorldMapFrame
	if mapa and mapa.IsShown and mapa:IsShown() and mapa.GetFrameStrata then
		local s = SIGUIENTE[mapa:GetFrameStrata() or ""]
		if s then return s end
	end
	return "HIGH"
end

-- mapa: uiMapID para encuadrar (nil: tu zona, o el mundo si no hay posición).
function V.Abrir(mapa)
	if not F then construir() end
	F:SetFrameStrata(estrato())
	F:Show()
	F:Raise()
	if sinArte then return end
	Mc.PrepararDatos()
	-- El encuadre espera a que la vista tenga su tamaño (el primer cuadro).
	porEncuadrar = { mapa = mapa }
	sucio = true
end

function encuadrar()
	local p = porEncuadrar
	local vw = tamVista()
	if not p or vw < 20 then return end
	porEncuadrar = nil
	local zz, u, v = nil, nil, nil
	if type(p.mapa) == "number" then zz, u, v = zoomPara(p.mapa) end
	if zz then
		cu, cv, z = u, v, max(Z_MIN, min(Z_MAX, zz))
		meta.z, meta.cu, meta.cv, meta.u = z, nil, nil, nil
	elseif not centrarEnMi(false, true) then
		cu, cv, z = 0.5, 0.5, 1
		meta.z, meta.cu, meta.cv, meta.u = 1, nil, nil, nil
	end
	sucio = true
end

function V.Cerrar() if F then F:Hide() end end
function V.Visible() return F and F:IsShown() or false end
function V.Alternar(mapa)
	if V.Visible() then V.Cerrar() else V.Abrir(mapa) end
end

-- Lo que cambia el arte (exploración, zonas sin descubrir, detalle).
function V.RehacerArte()
	if F and not sinArte then
		Lz.Rehacer()
		sucio = true
	end
end

function V.Detalle()
	if F and not sinArte then
		Lz.Detalle()
		sucio = true
	end
end

-- Para el contrato público (AlfaMundo.Abrir / Alternar / Cerrar).
local API = AlfaMundo
API.Abrir = V.Abrir
API.Alternar = V.Alternar
API.Cerrar = V.Cerrar
