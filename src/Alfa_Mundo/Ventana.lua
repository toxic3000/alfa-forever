-- Alfa - Mundo: la ventana del mapa continuo (toxic3000 / La Jauría). GPL-3.0.
--
-- Una ventana del Kit (K.Ventana), aparte del mapa de Blizzard: no toca
-- WorldMapFrame ni reemplaza ninguna de sus funciones, así que no puede
-- contaminarlo. En la vista:
--   rueda          acercar y alejar donde está el cursor (suave)
--   arrastrar      mover, con inercia al soltar
--   doble clic     acercar
--   clic derecho   (o Mayús+clic) poner ahí un marcador
--   Ctrl+clic      la flecha y la ruta te llevan ahí, sin marcador
-- Arriba: buscar cerca (si Rutas lo ofrece), tus marcadores, las capas, el
-- modo limpio, el mapa del juego y el engrane (estilo del mapa y opciones).
-- Abajo a la derecha: +, – y centrar en mí. En el pie, la zona bajo el
-- cursor con su rango de niveles y las coordenadas tuyas y del cursor. La
-- ventana se mueve por su cabecera y cambia de tamaño por su esquina;
-- recuerda los dos. El marco sigue el estilo de Alfa (K.SetEstilo): en
-- Clásico WoW el mapa se mete dentro del borde del cuadro de diálogo.
--
-- El zoom nunca agranda un texel de la mejor capa que hay donde se acerca
-- (el terreno o el arte de la zona, Lz.Densidad) a más de NITIDEZ píxeles
-- de la pantalla: así no se ve pixelado.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = N.Textos(M.EN)
local Geo, Lz, Mc, Capas, Panel = M.Geo, M.Lienzo, M.Marcas, M.Capas, M.Panel
local Mk, PM, Tr = M.Marcadores, M.PanelMarcadores, M.Trayecto

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
local NITIDEZ = 2         -- píxeles de la pantalla por texel, como mucho, al acercar

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

-- Píxeles de la pantalla por unidad de la vista.
local function pixeles()
	local s = vista and vista:GetEffectiveScale() or 1
	if type(s) ~= "number" or s <= 0 then s = 1 end
	local alto
	if GetPhysicalScreenSize then
		local ok, _, h = pcall(GetPhysicalScreenSize)
		if ok and type(h) == "number" and h > 0 then alto = h end
	end
	return alto and s * alto / 768 or s
end

-- El zoom más alto en el punto (u, v) del mundo sin que se vea pixelado.
local function tope(u, v)
	local d = Lz.Densidad(u, v)
	if not (type(d) == "number" and d > 0) then return Z_MAX end
	local Wm, Hm = Lz.Tamano()
	local vw, vh = tamVista()
	local base = min(vw / Wm, vh / Hm)
	if not (base > 0) then return Z_MAX end
	return max(Z_MIN * 2, min(Z_MAX, NITIDEZ * d / pixeles() / base))
end

-- Un zoom pedido en (u, v): si pasa del tope, no acerca más que eso (pero
-- nunca obliga a alejarse de lo que ya ves).
local function limitar(nuevo, u, v)
	local t = tope(u, v)
	if nuevo > t then nuevo = max(t, min(nuevo, meta.z or z)) end
	return nuevo
end

---------------------------------------------------------------------------
-- Dibujar
---------------------------------------------------------------------------

-- El arte y lo de encima, cada uno por su cuenta: si uno falla, el otro igual
-- se mueve con la vista (el error se avisa una vez por sesión).
local avisoColocar = false
local function aparte(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok and not avisoColocar and geterrorhandler then
		avisoColocar = true
		geterrorhandler()(err)
	end
end

local function colocar()
	sucio = false
	if sinArte then return end
	encajar()
	local vw, vh = tamVista()
	local k = escala(z)
	aparte(Lz.Colocar, cu, cv, k, vw, vh, z)
	aparte(Mc.Colocar, cu, cv, k, vw, vh, z)
	aparte(Tr.Colocar, cu, cv, k, vw, vh, z)
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
	nuevo = limitar(nuevo, u, v)
	inercia = nil
	meta.z, meta.x, meta.y, meta.u, meta.v = nuevo, x, y, u, v
	meta.cu, meta.cv = nil, nil
end

-- Desliza la vista hasta (u, v) con el zoom dado.
local function irA(u, v, zoom)
	inercia = nil
	meta.cu, meta.cv = Geo.Encajar(u, v)
	meta.z = limitar(max(Z_MIN, min(Z_MAX, zoom or z)), meta.cu, meta.cv)
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
	zz = min(zz, 26, tope(u, v))
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
		-- Mientras se arrastra, el arrastre deja bajo el cursor el punto que
		-- agarraste (arrastrar, después de esto): el ancla del zoom no pelea con él.
		if meta.u and not (arrastre and arrastre.movido) then
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

-- Buscar cerca: la API de Alfa_Rutas (Cerca.lua), si está cargada.
local function hayCerca()
	local C = AlfaCerca
	return type(C) == "table" and type(C.Menu) == "function"
end

-- El título llega hasta el botón de más a la izquierda que se ve.
local function acomodarTitulo()
	local c = F.Cabecera
	local izq = F.BCerca:IsShown() and F.BCerca or F.BMarcas
	c.Subtitulo:SetPoint("RIGHT", izq, "LEFT", -ESP.base, 0)
	c.Titulo:SetPoint("RIGHT", izq, "LEFT", -ESP.base, 0)
end

-- 1.3.6: el reloj de 0,5 s la llama aunque nada cambie: si el estado de los
-- botones es el mismo que el último pintado, no se toca nada. forzar: al abrir.
local ultimoBotones
local function pintarBotones(forzar)
	if not F then return end
	local cerca = hayCerca()
	local limpio, capas, marcas, n = Capas.Limpio() and true or false, Panel.Visible() and true or false, PM.Visible() and true or false, tonumber(Mk.Cuantos()) or 0
	local estado = format("%s%s%s%s%d", tostring(cerca), tostring(limpio), tostring(capas), tostring(marcas), n)
	if not forzar and estado == ultimoBotones then return end
	ultimoBotones = estado
	if F.BCerca:IsShown() ~= cerca then
		F.BCerca:SetShown(cerca)
		acomodarTitulo()
	end
	F.BLimpio:SetMarcado(limpio)
	F.BCapas:SetMarcado(capas)
	F.BMarcas:SetMarcado(marcas)
	-- 1.3.6: con K.Escribir, como todo texto de Alfa.
	K.Escribir(F.Cuenta, n > 0 and tostring(n) or "")
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
		-- gu, gv: el punto del mundo que agarraste; se queda bajo el cursor
		-- aunque el zoom cambie durante el arrastre (la rueda).
		local gu, gv = aMundo(x, y)
		arrastre = { x = x, y = y, cu = cu, cv = cv, gu = gu, gv = gv, movido = false, vu = 0, vv = 0 }
		inercia = nil
		meta.cu, meta.cv, meta.u = nil, nil, nil
		meta.z = z
	elseif boton == "RightButton" then
		arrastre = { derecho = true, x = x, y = y }
	end
end

-- Un zoom que sigue animándose al terminar un arrastre: su ancla pasa al
-- punto bajo el cursor de ahora (si no, la vista saltaría al ancla vieja).
local function reanclarZoom()
	if not meta.u then return end
	if inercia then meta.u = nil return end -- la inercia mueve; el zoom, desde el centro
	local x, y = cursor()
	if not x then
		local vw, vh = tamVista()
		x, y = vw / 2, vh / 2
	end
	meta.x, meta.y = x, y
	meta.u, meta.v = aMundo(x, y)
end

local finArrastre = -1 -- cuándo terminó el último arrastre con movimiento

-- Fin de un arrastre que movió el mapa.
local function terminarArrastre(a)
	-- Un arrastre rápido sigue solo un poco y se frena.
	local Wm, Hm = Lz.Tamano()
	local k = escala(z)
	local rapidez = sqrt((a.vu * k * Wm) ^ 2 + (a.vv * k * Hm) ^ 2)
	if rapidez > INERCIA_MIN and not (A.Get("ui.reduceMotion")) then inercia = { vu = a.vu, vv = a.vv } end
	reanclarZoom()
	finArrastre = GetTime and GetTime() or 0
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
		terminarArrastre(a)
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

-- Los pines y los puntos del grupo (Marcas.lua) se quedan el botón al
-- presionarlos: reenvían el izquierdo aquí para que arrastrar empezando sobre
-- uno también mueva el mapa.
function V.Presionar(boton)
	if boton == "LeftButton" then alPresionar(nil, boton) end
end

-- Al soltar sobre un pin: solo actúa si el arrastre movió el mapa (-> true).
function V.SoltarArrastre(boton)
	local a = arrastre
	if sinArte or boton ~= "LeftButton" or not a or a.derecho then return false end
	arrastre = nil
	if not a.movido then return false end
	terminarArrastre(a)
	return true
end

-- Si el clic de un pin viene de soltar un arrastre (no debe dispararse).
function V.RecienArrastrado()
	if arrastre and arrastre.movido then return true end
	local ahora = GetTime and GetTime() or 0
	return ahora - finArrastre < 0.1
end

local function arrastrar(dt)
	local a = arrastre
	if not a or a.derecho then return false end
	if not (IsMouseButtonDown and IsMouseButtonDown("LeftButton")) then
		arrastre = nil
		if a.movido then reanclarZoom() end
		return false
	end
	local x, y = cursor()
	if not x then return false end
	local dx, dy = x - a.x, y - a.y
	if not a.movido and abs(dx) + abs(dy) < 3 then return false end
	a.movido = true
	local Wm, Hm = Lz.Tamano()
	local vw, vh = tamVista()
	local k = escala(z)
	-- El punto agarrado bajo el cursor, con el zoom de ahora (sin zoom de por
	-- medio es lo mismo que mover el centro lo que se movió el cursor).
	local nu, nv = a.gu - (x - vw / 2) / (k * Wm), a.gv - (y - vh / 2) / (k * Hm)
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
	-- El zoom primero: el arrastre se acomoda al zoom de este mismo cuadro.
	if animar(dt) then sucio = true end
	if arrastrar(dt) then sucio = true end
	if sucio then colocar() end
	reloj = reloj + dt
	if reloj >= LATIDO then
		reloj = 0
		if not sucio then
			Mc.Latido()
			aparte(Tr.Latido)
		end
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

-- El engrane: el estilo del mapa (terreno o clásico) y las opciones de Mundo.
local function menuAjustes(boton)
	local opciones = {}
	for _, o in ipairs(M.OpcionesEstilo()) do opciones[#opciones + 1] = o end
	opciones[#opciones + 1] = { separador = true }
	opciones[#opciones + 1] = { valor = "opciones", texto = L["Más opciones en la página Mundo"], icono = "ic-ajustes" }
	local actual = A.Get("mundo.estiloMapa") == "clasico" and "clasico" or "terreno"
	K.Menu(boton, opciones, actual, function(v)
		if v == "opciones" then
			N.Abrir("mundo")
		elseif v == "terreno" or v == "clasico" then
			A.Set("mundo.estiloMapa", v)
		end
	end, 280)
	-- Junto al borde derecho de la ventana: el menú se abre hacia la izquierda.
	local m = _G.AlfaKitMenu
	if m and m:IsShown() then
		m:ClearAllPoints()
		m:SetPoint("TOPRIGHT", boton, "BOTTOMRIGHT", 0, -4)
	end
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
	F = K.Ventana({ nombre = NOMBRE, titulo = L["Mapa de Alfa"], subtitulo = " ", icono = "ic-mundo",
		ancho = w, alto = h,
		alAbrir = function(self)
			mostrado.zona, mostrado.coords = -1, nil
			pintarBotones(true)
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
	F.BAjustes = botonCab("ic-ajustes", L["Ajustes del mapa"], function(self) menuAjustes(self) end,
		L["El estilo del mapa (terreno como el minimapa, o el arte clásico) y la página Mundo, con todas las opciones del mapa."]) -- 1.3.6: Mundo es la página del mapa de Alfa
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
	F.BCapas = botonCab("ic-comunidad", L["Capas de Alfa"], function(self)
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
	-- Buscar cerca (Alfa_Rutas): solo se ve si su API está; se mira otra vez al hacer clic.
	F.BCerca = botonCab("ic-cerca", L["Buscar cerca: vuelo, posada, banco…"], function(self)
		if hayCerca() then K.Llamar(AlfaCerca.Menu, self) end
	end)
	F.BCerca:SetPoint("RIGHT", F.BMarcas, "LEFT", -ESP.xs, 0)
	F.BCerca:SetShown(hayCerca())
	acomodarTitulo()
	c.Subtitulo:SetWordWrap(false)

	-- La vista del mapa
	vista = CreateFrame("Frame", nil, F.Cuerpo)
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
	-- Tu camino (1.2.1): la ruta, el vuelo y el destino, entre el arte y los pines.
	Tr.Crear(vista)
	Tr.alVerCamino = function() V.VerCamino() end
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
	-- Encima del lienzo y de los pines (Marcas: hasta ~100 sobre su capa).
	zoom:SetFrameLevel(vista:GetFrameLevel() + (Lz.NIVELES or 30) + 130)
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
	asa:SetFrameLevel(F:GetFrameLevel() + 40)
	asa.t = K.Icono(asa, "resize", 16, "textoTenue", "OVERLAY")
	asa.t:SetAllPoints()
	asa:SetScript("OnEnter", function(self) K.SetIcono(self.t, "resize", "texto") end)
	asa:SetScript("OnLeave", function(self) K.SetIcono(self.t, "resize", "textoTenue") end)
	asa:SetScript("OnMouseDown", function() if F.StartSizing then F:StartSizing("BOTTOMRIGHT") end end)
	asa:SetScript("OnMouseUp", function()
		F:StopMovingOrSizing()
		guardarTamano()
		sucio = true
	end)
	K.ConInfo(asa, L["Cambiar el tamaño"], nil)

	-- El marco sigue el estilo de Alfa: en Clásico WoW el borde del cuadro de
	-- diálogo es ancho, y el mapa, el pie y el asa se meten dentro de él.
	K.Pintar({ vista, pie, asa }, function(x)
		local izq, der, abajo, esquina = BORDE, BORDE, BORDE, 6
		local mj = K.Clasico() and K.MARCOS and K.MARCOS.dialogo
		if mj then izq, der, abajo, esquina = mj.izq, mj.der, mj.abajo, mj.der + 2 end
		x[1]:ClearAllPoints()
		x[1]:SetPoint("TOPLEFT", F.Cuerpo, "TOPLEFT", izq, 0)
		x[1]:SetPoint("BOTTOMRIGHT", F.Cuerpo, "BOTTOMRIGHT", -der, PIE + abajo - BORDE)
		x[2]:ClearAllPoints()
		x[2]:SetPoint("BOTTOMLEFT", F.Cuerpo, "BOTTOMLEFT", izq, abajo)
		x[2]:SetPoint("BOTTOMRIGHT", F.Cuerpo, "BOTTOMRIGHT", -der, abajo)
		x[3]:ClearAllPoints()
		x[3]:SetPoint("BOTTOMRIGHT", F, "BOTTOMRIGHT", -esquina, esquina)
		sucio = true
	end)

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
	if M.Entradas then M.Entradas.Preparar() end
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
		local zz = p.z or min(26, p.mapa and zoomPara(p.mapa) or 12)
		cu, cv, z = p.u, p.v, max(Z_MIN, min(Z_MAX, zz, tope(p.u, p.v)))
		meta.z, meta.cu, meta.cv, meta.u = z, nil, nil, nil
		sucio = true
		return
	end
	local zz, u, v = nil, nil, nil
	if type(p.mapa) == "number" then zz, u, v = zoomPara(p.mapa) end
	if zz then
		cu, cv, z = u, v, max(Z_MIN, min(Z_MAX, zz, tope(u, v)))
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
	if not V.Visible() then
		-- El zoom se mide al encuadrar: antes de abrirla por primera vez la
		-- vista no existe (ni tiene tamaño).
		V.Abrir()
		porEncuadrar = { u = u, v = v, mapa = m.mapa }
		return
	end
	irA(u, v, max(z, min(26, zoomPara(m.mapa) or 12)))
end

-- La ficha del camino (Trayecto.lua): la vista se desliza hasta que se ve
-- todo, de ti al destino (1.2.1).
function V.VerCamino()
	if not (F and F:IsShown()) or sinArte then return end
	local u0, v0, u1, v1 = Tr.Encuadre()
	if not u0 then return end
	local Wm, Hm = Lz.Tamano()
	local vw, vh = tamVista()
	local base = min(vw / Wm, vh / Hm)
	if not (base > 0) then return end
	local w, h = max(u1 - u0, 1e-4), max(v1 - v0, 1e-4)
	local zz = min(vw / (w * Wm), vh / (h * Hm)) / base * 0.8
	irA((u0 + u1) / 2, (v0 + v1) / 2, max(Z_MIN, min(zz, 26)))
end

-- Al mapa del juego en la zona que ves (desde un addon no se abre en combate:
-- su abridor del cliente, Compat.OpenWorldMap, no contamina el mapa).
function V.AlMapaDelJuego()
	local C = A.Compat
	if not (C and type(C.CanOpenWorldMap) == "function" and C.CanOpenWorldMap() and type(C.OpenWorldMap) == "function") then
		N.Imprimir(L["Con la interfaz de mando el mapa del juego se abre con su tecla."])
		return
	end
	local zona
	if V.Visible() then
		-- Desde el mapa de Alfa: la zona que miras.
		local _, enVista = Geo.Cadena(cu, cv)
		zona = enVista or (z >= 1.5 and Geo.Cadena(cu, cv)) or nil
	elseif type(C.GetPlayerMapPosition) == "function" then
		-- 1.3.2: desde la página (el mapa de Alfa cerrado): donde estás, no la
		-- última vista del mapa de Alfa.
		local ok, mapa = pcall(C.GetPlayerMapPosition)
		zona = ok and type(mapa) == "number" and mapa or nil
	end
	if C.OpenWorldMap(zona) then
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

-- Terreno o clásico (mundo.estiloMapa).
function V.Estilo()
	if F and not sinArte then
		Lz.Estilo()
		sucio = true
	end
end

-- Para el contrato público (AlfaMundo.Abrir / Alternar / Cerrar).
local API = AlfaMundo
API.Abrir = V.Abrir
API.Alternar = V.Alternar
API.Cerrar = V.Cerrar

-- Las zonas (y ciudades) que el mapa continuo muestra ahora con su arte, o
-- nil si está cerrado: así un módulo publica sus pines solo de lo que se ve
-- (Recolección). 1.1.8.
API.ZonasALaVista = function()
	if not (F and F:IsShown()) then return nil end
	local ids = {}
	for _, lista in ipairs({ Lz.Zonas() or {}, Lz.Ciudades() or {} }) do
		for _, z in ipairs(lista) do
			if z.visible then ids[#ids + 1] = z.id end
		end
	end
	return ids
end
