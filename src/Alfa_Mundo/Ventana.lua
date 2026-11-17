-- Alfa - Mundo: la ventana del mapa continuo (Toxic / La Jauría). GPL-3.0.
--
-- Una ventana del Kit (K.Ventana), aparte del mapa de Blizzard: no toca
-- WorldMapFrame ni reemplaza ninguna de sus funciones, así que no puede
-- contaminarlo. En la vista:
--   rueda          acercar y alejar donde está el cursor (suave)
--   arrastrar      mover, con inercia al soltar
--   doble clic     acercar
--   clic derecho   (o Mayús+clic) poner ahí un marcador
--   Ctrl+clic      la flecha y la ruta te llevan ahí, sin marcador
-- Arriba: tus marcadores, las capas, el modo limpio, el mapa del juego y
-- los ajustes. Abajo a la derecha: +, – y centrar en mí. En el pie, la zona
-- bajo el cursor con su rango de niveles y las coordenadas tuyas y del
-- cursor. La ventana se mueve por su cabecera y cambia de tamaño por su
-- esquina; recuerda los dos.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = N.Textos(M.EN)
local Geo, Lz, Mc, Capas, Panel = M.Geo, M.Lienzo, M.Marcas, M.Capas, M.Panel
local Mk, PM = M.Marcadores, M.PanelMarcadores

local type, pairs, ipairs, pcall, tonumber, min, max, floor, abs, exp, sqrt = type, pairs, ipairs, pcall, tonumber, math.min, math.max, math.floor, math.abs, math.exp, math.sqrt
local format = string.format
local ESP = K.ESP

local V = {}
M.Ventana = V

local NOMBRE = "AlfaMundoMapa"
local PIE, BORDE = 32, 1
local Z_MIN, Z_MAX = 0.9, 90
local PASO = 1.4          -- zoom por golpe de rueda
local SUAVE = 14          -- qué tan rápido llega el zoom a su meta
local LATIDO = 0.1        -- segundos entre repintados de lo que se mueve solo
local DOBLE = 0.32        -- segundos para un doble clic
local FRENO = 5.5         -- qué tan rápido se detiene la inercia
local INERCIA_MIN = 40    -- unidades de la vista por segundo para que siga sola
local ANCHO_MIN, ALTO_MIN = 600, 420

local F, vista
local cu, cv, z = 0.5, 0.5, 1          -- la vista: centro y zoom
local meta = { z = 1 }                 -- a dónde va: zoom (y ancla) o centro
local arrastre                          -- { x, y, cu, cv, movido }
local inercia                           -- { vu, vv } al soltar un arrastre rápido
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
	inercia = nil
	meta.z, meta.x, meta.y, meta.u, meta.v = nuevo, x, y, u, v
	meta.cu, meta.cv = nil, nil
end

-- Desliza la vista hasta (u, v) con el zoom dado.
local function irA(u, v, zoom)
	inercia = nil
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
	if inercia then
		cu, cv = cu + inercia.vu * dt, cv + inercia.vv * dt
		local freno = exp(-FRENO * dt)
		inercia.vu, inercia.vv = inercia.vu * freno, inercia.vv * freno
		local Wm, Hm = Lz.Tamano()
		local k = escala(z)
		if sqrt((inercia.vu * k * Wm) ^ 2 + (inercia.vv * k * Hm) ^ 2) < 8 then inercia = nil end
		cambio = true
	end
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
-- El pie: la zona bajo el cursor y las coordenadas
---------------------------------------------------------------------------

local textoCoords = Mk.TextoCoords
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
			K.Escribir(F.Zona, Geo.Nombre(zona) or "")
			local lo, hi = Geo.Niveles(zona)
			local texto, col = Geo.TextoNiveles(lo, hi)
			if texto and A.Get("maps.zoneLevels") then
				K.Escribir(F.Niveles, format(L["Niveles %s"], texto))
				local T = A.Theme
				local r, g, b = 1, 1, 1
				if T and T.Color then r, g, b = T.Color(col or "quest") end
				F.Niveles:SetTextColor(r or 1, g or 1, b or 1)
			else
				K.Escribir(F.Niveles, "")
			end
		else
			K.Escribir(F.Zona, "")
			K.Escribir(F.Niveles, "")
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
			if texto and niveles then texto = texto .. "  \194\183  " .. niveles end
		end
	end
	if not texto and z >= 1.5 then
		local cont = Geo.Cadena(cu, cv)
		texto = cont and Geo.Nombre(cont)
	end
	texto = texto or Geo.Nombre(Geo.MUNDO) or L["Azeroth"]
	if Capas.Limpio() then texto = texto .. "  \194\183  " .. L["Modo limpio"] end
	K.Escribir(F.Cabecera.Subtitulo, texto)
end

local function pintarBotones()
	if not F then return end
	F.BLimpio:SetMarcado(Capas.Limpio())
	F.BCapas:SetMarcado(Panel.Visible())
	F.BMarcas:SetMarcado(PM.Visible())
	local n = Mk.Cuantos()
	F.Cuenta:SetText(n > 0 and tostring(n) or "")
end

---------------------------------------------------------------------------
-- Ratón
---------------------------------------------------------------------------

-- El punto de la vista en el mapa de su zona (o del continente): mapa, x, y, nombre
local function lugarEn(x, y)
	local u, v = aMundo(x, y)
	local cont, zona = Geo.Cadena(u, v)
	local mapa = zona or cont
	if not mapa then return nil end
	local px, py = Geo.AMapa(mapa, u, v)
	if not px then return nil end
	return mapa, px, py, Geo.Nombre(mapa)
end

local function nuevoMarcador(x, y)
	local mapa, px, py = lugarEn(x, y)
	if not mapa then
		N.Imprimir(L["Ahí no hay ninguna zona: pon el marcador sobre tierra."])
		return
	end
	M.Editor.Abrir({ nuevo = { mapa = mapa, x = px, y = py } })
end

local function llevarme(x, y)
	local mapa, px, py, nombre = lugarEn(x, y)
	if not mapa then
		N.Imprimir(L["Ahí no se puede poner la flecha."])
		return
	end
	if Mk.SeguirPunto(mapa, px, py, format(L["%s (%s)"], nombre or L["Destino"], textoCoords(px, py))) then Mc.Latido() end
end

local function rueda(_, delta)
	if sinArte or type(delta) ~= "number" then return end
	local x, y = cursor()
	zoomEn(meta.z * PASO ^ delta, x, y)
end
V.Rueda = rueda

local function alPresionar(_, boton)
	if sinArte then return end
	local x, y = cursor()
	if not x then return end
	if boton == "LeftButton" then
		arrastre = { x = x, y = y, cu = cu, cv = cv, movido = false, vu = 0, vv = 0 }
		inercia = nil
		meta.cu, meta.cv, meta.u = nil, nil, nil
		meta.z = z
	elseif boton == "RightButton" then
		arrastre = { derecho = true, x = x, y = y }
	end
end

local function alSoltar(_, boton)
	if sinArte then return end
	local x, y = cursor()
	local a = arrastre
	arrastre = nil
	if boton == "RightButton" then
		if x and a and a.derecho and abs(x - a.x) + abs(y - a.y) < 6 then nuevoMarcador(x, y) end
		return
	end
	if boton ~= "LeftButton" or not a or a.derecho then return end
	if a.movido then
		-- Un arrastre rápido sigue solo un poco y se frena.
		local Wm, Hm = Lz.Tamano()
		local k = escala(z)
		local rapidez = sqrt((a.vu * k * Wm) ^ 2 + (a.vv * k * Hm) ^ 2)
		if rapidez > INERCIA_MIN and not (A.Get("ui.reduceMotion")) then inercia = { vu = a.vu, vv = a.vv } end
		return
	end
	if not x then return end
	if IsShiftKeyDown and IsShiftKeyDown() then
		nuevoMarcador(x, y)
		return
	end
	if IsControlKeyDown and IsControlKeyDown() then
		llevarme(x, y)
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

local function arrastrar(dt)
	local a = arrastre
	if not a or a.derecho then return false end
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
	local nu, nv = a.cu - dx / (k * Wm), a.cv - dy / (k * Hm)
	-- La rapidez del arrastre (suavizada), para la inercia al soltar.
	if dt > 0 then
		local f = min(1, dt * 18)
		a.vu = a.vu + ((nu - cu) / dt - a.vu) * f
		a.vv = a.vv + ((nv - cv) / dt - a.vv) * f
	end
	cu, cv = nu, nv
	return true
end

local encuadrar -- (abajo, con V.Abrir)

local function alActualizar(_, dt)
	dt = type(dt) == "number" and dt or 0
	if porEncuadrar and encuadrar then encuadrar() end
	if arrastrar(dt) then sucio = true end
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

-- El tamaño se guarda en mundo.ventana ({ ancho, alto }); el lugar lo
-- guarda la ventana del Kit. (El formato viejo era { punto, x, y, ancho, alto }.)
local function tamanoGuardado()
	local g = A.Get("mundo.ventana")
	if type(g) ~= "table" then return nil end
	if type(g[1]) == "string" then return tonumber(g[4]), tonumber(g[5]) end
	return tonumber(g.ancho), tonumber(g.alto)
end

local function guardarTamano()
	A.Set("mundo.ventana", { ancho = floor(F:GetWidth() + 0.5), alto = floor(F:GetHeight() + 0.5) })
	-- Cambiar el tamaño mueve el ancla de la ventana: su lugar se guarda como
	-- lo guarda la ventana del Kit al arrastrarla (AlfaNucleoDB.kit.ventanas).
	local p, _, rp, x, y = F:GetPoint(1)
	if p then
		local d = N.Datos("kit")
		d.ventanas = type(d.ventanas) == "table" and d.ventanas or {}
		d.ventanas[NOMBRE] = { p, rp, floor((tonumber(x) or 0) + 0.5), floor((tonumber(y) or 0) + 0.5) }
	end
end

local function tamanoInicial()
	local uw, uh = UIParent:GetWidth() or 1280, UIParent:GetHeight() or 800
	local w, h = tamanoGuardado()
	if not w then
		w = min(1120, floor(uw * 0.72))
		h = min(floor(uh * 0.82), floor(w * 0.68))
	end
	return max(ANCHO_MIN, min(w, uw)), max(ALTO_MIN, min(h or ALTO_MIN, uh))
end

local function botonCab(icono, ayuda, fn, texto)
	local b = K.BotonIcono(F.Cabecera, icono, fn, { tam = 30, icono = 16, ayuda = ayuda, ayudaTexto = texto })
	return b
end

local function botonZoom(padre, texto, fn, ayuda)
	local b = K.Boton(padre, texto, fn, { tipo = "secundario", ancho = 32 })
	b:SetAncho(32)
	b:SetHeight(32)
	K.ConInfo(b, ayuda, nil)
	return b
end

local function construir()
	local w, h = tamanoInicial()
	F = K.Ventana({ nombre = NOMBRE, titulo = L["Mapa del mundo"], subtitulo = " ", icono = "ic-mundo",
		ancho = w, alto = h,
		alAbrir = function(self)
			mostrado.zona, mostrado.coords = -1, nil
			pintarBotones()
			actualizarTitulo()
		end,
		alCerrar = function()
			arrastre, inercia = nil, nil
			M.CerrarEmergentes()
			if M.Editor and M.Editor.Visible() then M.Editor.Cerrar() end
		end })
	F:SetResizable(true)
	if F.SetResizeBounds then F:SetResizeBounds(ANCHO_MIN, ALTO_MIN) elseif F.SetMinResize then F:SetMinResize(ANCHO_MIN, ALTO_MIN) end
	local c = F.Cabecera

	-- Los botones de la cabecera, de derecha a izquierda junto a la X.
	F.BAjustes = botonCab("ic-ajustes", L["Opciones de Mundo"], function() N.Abrir("mundo") end)
	F.BAjustes:SetPoint("RIGHT", c.Cerrar, "LEFT", -ESP.xs, 0)
	F.BJuego = botonCab("ic-mapa", L["Ir al mapa del juego"], function() V.AlMapaDelJuego() end,
		L["Abre el mapa del juego en esta misma zona. En combate el mapa del juego no se abre desde Alfa."])
	F.BJuego:SetPoint("RIGHT", F.BAjustes, "LEFT", -ESP.xs, 0)
	F.Sep = K.Linea(c, "linea", true)
	F.Sep:SetHeight(22)
	F.Sep:SetPoint("RIGHT", F.BJuego, "LEFT", -ESP.s, 0)
	F.BLimpio = botonCab("ic-descubrir", L["Modo limpio"], function() Capas.AlternarLimpio() end,
		L["Deja solo lo esencial: tú, tu grupo, tus marcadores y el siguiente paso de la guía."])
	F.BLimpio:SetPoint("RIGHT", F.Sep, "LEFT", -ESP.s, 0)
	F.BCapas = botonCab("ic-comunidad", L["Capas del mapa"], function(self)
		Panel.Alternar(self, { punto = "TOPRIGHT", relativo = "BOTTOMRIGHT", x = 0, y = -6, sinMapa = true })
		pintarBotones()
	end, L["Elige qué se ve en el mapa: guía, misiones, raros, viajes, zonas y lo que agregan otros módulos."])
	F.BCapas:SetPoint("RIGHT", F.BLimpio, "LEFT", -ESP.xs, 0)
	F.BMarcas = botonCab("ic-huella", L["Tus marcadores"], function(self)
		PM.Alternar(self)
		pintarBotones()
	end, L["Tu lista: síguelos con la flecha, compártelos con el grupo, cámbialos o bórralos."])
	F.BMarcas:SetPoint("RIGHT", F.BCapas, "LEFT", -ESP.xs, 0)
	F.Cuenta = K.Texto(F.BMarcas, "insignia", "acento")
	F.Cuenta:SetPoint("BOTTOMRIGHT", F.BMarcas, "BOTTOMRIGHT", 2, -1)
	c.Subtitulo:SetPoint("RIGHT", F.BMarcas, "LEFT", -ESP.base, 0)
	c.Titulo:SetPoint("RIGHT", F.BMarcas, "LEFT", -ESP.base, 0)
	c.Subtitulo:SetWordWrap(false)

	-- La vista del mapa
	vista = CreateFrame("Frame", nil, F.Cuerpo)
	vista:SetPoint("TOPLEFT", F.Cuerpo, "TOPLEFT", BORDE, 0)
	vista:SetPoint("BOTTOMRIGHT", F.Cuerpo, "BOTTOMRIGHT", -BORDE, PIE)
	vista:EnableMouse(true)
	vista:EnableMouseWheel(true)
	vista.Fondo = K.Plano(vista, "hundido", "BACKGROUND", -8)
	vista.Fondo:SetAllPoints(vista)
	vista:SetScript("OnMouseWheel", A.Safe(rueda))
	vista:SetScript("OnMouseDown", A.Safe(alPresionar))
	vista:SetScript("OnMouseUp", A.Safe(alSoltar))
	vista:SetScript("OnSizeChanged", function() sucio = true end)
	vista:SetScript("OnUpdate", A.Safe(alActualizar))
	F.Vista = vista
	local lienzo = Lz.Crear(vista)
	Mc.Crear(vista)
	if not lienzo then
		sinArte = true
		F.SinArte = K.Vacio(vista, { lobo = "vacio", titulo = L["Este cliente no da el arte del mapa"],
			texto = L["No se puede dibujar el mapa continuo. El mapa del juego sigue funcionando con todas las capas de Alfa."],
			accion = { texto = L["Ir al mapa del juego"], icono = "ic-mapa", alClic = function() V.AlMapaDelJuego() end } })
		F.SinArte:Acomodar(420)
		F.SinArte:SetPoint("CENTER", vista, "CENTER", 0, 0)
	end

	-- Zoom y centrar, abajo a la derecha de la vista.
	local zoom = CreateFrame("Frame", nil, vista)
	zoom:SetSize(32, 32 * 3 + ESP.xs * 2)
	zoom:SetPoint("BOTTOMRIGHT", vista, "BOTTOMRIGHT", -ESP.m, ESP.m)
	zoom:SetFrameLevel(vista:GetFrameLevel() + 80)
	F.Mas = botonZoom(zoom, "+", function() zoomEn(meta.z * 2) end, L["Acercar"])
	F.Mas:SetPoint("TOP", zoom, "TOP", 0, 0)
	F.Menos = botonZoom(zoom, "\226\128\147", function() zoomEn(meta.z / 2) end, L["Alejar"])
	F.Menos:SetPoint("TOP", F.Mas, "BOTTOM", 0, -ESP.xs)
	F.Centrar = K.BotonIcono(zoom, "ic-raros", function()
		if not centrarEnMi(true) then N.Imprimir(L["Aquí el juego no da tu posición (por ejemplo, dentro de una mazmorra)."]) end
	end, { tam = 32, icono = 16, tipo = "secundario", ayuda = L["Centrar en mí"] })
	F.Centrar:SetPoint("TOP", F.Menos, "BOTTOM", 0, -ESP.xs)

	-- Pie: zona bajo el cursor, ayuda y coordenadas.
	local pie = CreateFrame("Frame", nil, F.Cuerpo)
	pie:SetPoint("BOTTOMLEFT", F.Cuerpo, "BOTTOMLEFT", BORDE, BORDE)
	pie:SetPoint("BOTTOMRIGHT", F.Cuerpo, "BOTTOMRIGHT", -BORDE, BORDE)
	pie:SetHeight(PIE - BORDE)
	pie.Linea = K.Linea(pie, "linea")
	pie.Linea:SetPoint("TOPLEFT", pie, "TOPLEFT", 0, 0)
	pie.Linea:SetPoint("TOPRIGHT", pie, "TOPRIGHT", 0, 0)
	F.Zona = K.Texto(pie, "etiqueta", "texto")
	F.Zona:SetPoint("LEFT", pie, "LEFT", ESP.base, 0)
	F.Niveles = K.Texto(pie, "numero", "mision")
	F.Niveles:SetPoint("LEFT", F.Zona, "RIGHT", ESP.m, 0)
	F.Ayuda = K.Texto(pie, "pequeno", "textoTenue")
	F.Ayuda:SetPoint("LEFT", pie, "LEFT", ESP.base, 0)
	F.Ayuda:SetWordWrap(false)
	K.Escribir(F.Ayuda, L["Rueda: zoom  \194\183  Arrastra: mover  \194\183  Clic derecho: marcador  \194\183  Ctrl+clic: llévame"])
	F.Coords = K.Texto(pie, "numero", "textoSuave")
	F.Coords:SetPoint("RIGHT", pie, "RIGHT", -36, 0)
	F.Coords:SetJustifyH("RIGHT")
	F.Ayuda:SetPoint("RIGHT", F.Coords, "LEFT", -ESP.m, 0)

	-- Asa para cambiar el tamaño.
	local asa = CreateFrame("Button", nil, F)
	asa:SetSize(16, 16)
	asa:SetPoint("BOTTOMRIGHT", F, "BOTTOMRIGHT", -6, 6)
	asa:SetFrameLevel(F:GetFrameLevel() + 40)
	asa.t = K.Icono(asa, "resize", 16, "textoTenue", "OVERLAY")
	asa.t:SetAllPoints()
	asa:SetScript("OnEnter", function(self) K.SetIcono(self.t, "resize", "texto") end)
	asa:SetScript("OnLeave", function(self) K.SetIcono(self.t, "resize", "textoTenue") end)
	asa:SetScript("OnMouseDown", function() F:StartSizing("BOTTOMRIGHT") end)
	asa:SetScript("OnMouseUp", function()
		F:StopMovingOrSizing()
		guardarTamano()
		sucio = true
	end)
	K.ConInfo(asa, L["Cambiar el tamaño"], nil)

	Capas.AlCambiar(function()
		sucio = true
		pintarBotones()
		if F:IsShown() then actualizarTitulo() end
	end)
	Mk.AlCambiar(function()
		sucio = true
		pintarBotones()
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
	F:Abrir()
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
	if p.u then
		cu, cv, z = p.u, p.v, max(Z_MIN, min(Z_MAX, p.z or 14))
		meta.z, meta.cu, meta.cv, meta.u = z, nil, nil, nil
		sucio = true
		return
	end
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

function V.Cerrar() if F then F:Cerrar() end end
function V.Visible() return F and F:IsShown() or false end
function V.Alternar(mapa)
	if V.Visible() then V.Cerrar() else V.Abrir(mapa) end
end

-- La vista va hasta un marcador (abre el mapa si hace falta).
function V.IrAMarcador(m)
	local u, v = Geo.DeMapa(m.mapa, m.x, m.y)
	if not u then return end
	local zz = max(z, min(26, zoomPara(m.mapa) or 12))
	if not V.Visible() then
		V.Abrir()
		porEncuadrar = { u = u, v = v, z = zz }
		return
	end
	irA(u, v, zz)
end

-- Al mapa del juego en la zona que ves (desde un addon no se abre en combate:
-- su abridor del cliente, Compat.OpenWorldMap, no contamina el mapa).
function V.AlMapaDelJuego()
	local C = A.Compat
	if not (C and type(C.CanOpenWorldMap) == "function" and C.CanOpenWorldMap() and type(C.OpenWorldMap) == "function") then
		N.Imprimir(L["Con la interfaz de mando el mapa del juego se abre con su tecla."])
		return
	end
	local _, zona = Geo.Cadena(cu, cv)
	if C.OpenWorldMap(zona or (z >= 1.5 and Geo.Cadena(cu, cv)) or nil) then
		V.Cerrar()
	else
		N.Imprimir(L["En combate el mapa del juego no se abre desde Alfa: usa el de Alfa."])
	end
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
