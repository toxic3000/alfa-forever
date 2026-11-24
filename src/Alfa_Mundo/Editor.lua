-- Alfa - Mundo: la ficha de un marcador, para ponerlo o cambiarlo (Toxic /
-- La Jauría). GPL-3.0.
--
-- Hecha con el Kit, junto al punto donde hiciste clic (o junto a su pin o su
-- fila en la lista): el nombre, el ícono, el color y, abajo, lo que puedes
-- hacer con él. Uno nuevo: "Guardar" y "Guardar y seguir". Uno tuyo:
-- "Borrar", "Compartir con el grupo", "Guardar" y "Seguir". Enter guarda;
-- Esc la cierra sin cambiar nada. Vive sobre los dos mapas (estrato
-- FULLSCREEN_DIALOG) y no es un marco protegido.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = N.Textos(M.EN)
local Mk = M.Marcadores

local ipairs, max, floor, format = ipairs, math.max, math.floor, string.format
local ESP = K.ESP

local E = {}
M.Editor = E

local NOMBRE = "AlfaMundoMarcador"
local ANCHO = 368
local PAD = ESP.base
local TAM_ICONO, GAP_ICONO = 34, 6
local TAM_COLOR, GAP_COLOR = 24, 8

local F
local estado = {} -- { m = marcador | nil, nuevo = { mapa, x, y } | nil, icono, color }

---------------------------------------------------------------------------
-- Pintar lo elegido
---------------------------------------------------------------------------
local function pintar()
	if not F then return end
	local token = estado.color or "acento"
	K.SetIcono(F.Icono, Mk.Textura(estado.icono), token)
	for _, b in ipairs(F.iconos) do
		local on = b.alfaClave == estado.icono
		b.alfaColor = on and token or nil
		b:SetMarcado(on)
		if on then
			F.SelIcono:ClearAllPoints()
			F.SelIcono:SetPoint("TOPLEFT", b, "TOPLEFT", -2, 2)
			F.SelIcono:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -2)
			F.SelIcono.caja:Estilo({ fondo = false, borde = token, alfaBorde = 1 })
			F.SelIcono:Show()
		end
	end
	for _, b in ipairs(F.colores) do
		if b.alfaClave == token then
			F.SelColor:ClearAllPoints()
			F.SelColor:SetPoint("TOPLEFT", b, "TOPLEFT", -3, 3)
			F.SelColor:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 3, -3)
			F.SelColor:Show()
		end
	end
end

---------------------------------------------------------------------------
-- Acciones
---------------------------------------------------------------------------
function E.Cerrar() if F then F:Hide() end end

-- -> el marcador guardado (nuevo o cambiado)
local function guardar()
	local nombre = F.Nombre:Texto()
	if estado.m then
		return Mk.Cambiar(estado.m.id, { nombre = nombre, icono = estado.icono, color = estado.color })
	end
	local n = estado.nuevo
	if not n then return nil end
	local m = Mk.Crear({ mapa = n.mapa, x = n.x, y = n.y, nombre = nombre, icono = estado.icono, color = estado.color })
	if m then
		E.ultimo = { icono = m.icono, color = m.color }
		N.Imprimir(format(L["Marcador puesto: %s."], m.nombre))
	end
	return m
end

function E.Guardar()
	local m = guardar()
	E.Cerrar()
	return m
end

local function guardarYSeguir()
	local m = guardar()
	E.Cerrar()
	if m then Mk.Seguir(m.id) end
end

local function compartir()
	local m = guardar()
	if m then Mk.Compartir(m.id) end
	E.Cerrar()
end

local function borrar()
	local m = estado.m
	E.Cerrar()
	if m then Mk.Borrar(m.id) end
end

---------------------------------------------------------------------------
-- Armar
---------------------------------------------------------------------------
local function campoDeNombre(padre)
	local b = K.Buscador(padre, { ayuda = L["Nombre del marcador"], retraso = 0, alEnter = function() E.Guardar() end })
	-- Un campo de texto, no una búsqueda: sin lupa.
	b.Lupa:Hide()
	b.Campo:ClearAllPoints()
	b.Campo:SetPoint("LEFT", b, "LEFT", ESP.m, 0)
	b.Campo:SetPoint("RIGHT", b, "RIGHT", -30, 0)
	b.Campo:SetMaxLetters(40)
	b.Ayuda:ClearAllPoints()
	b.Ayuda:SetPoint("LEFT", b.Campo, "LEFT", 1, 0)
	b.Ayuda:SetPoint("RIGHT", b.Campo, "RIGHT", 0, 0)
	b.Campo:SetScript("OnEscapePressed", function(self) self:ClearFocus() E.Cerrar() end)
	return b
end

local function marcoSeleccion(padre, corte)
	local s = CreateFrame("Frame", nil, padre)
	s.caja = K.Caja(s, { fondo = false, borde = "acento", corte = corte })
	s:EnableMouse(false)
	s:Hide()
	return s
end

local function construir()
	F = CreateFrame("Frame", NOMBRE, K.Raiz())
	F:SetFrameStrata("FULLSCREEN_DIALOG")
	F:SetToplevel(true)
	F:SetClampedToScreen(true)
	F:EnableMouse(true)
	F:SetWidth(ANCHO)
	F:Hide()
	F.caja = K.Caja(F, { fondo = "fondo", borde = "lineaFuerte", corte = K.CORTE.ventana })
	F.Marca = K.Marca(F, K.CORTE.ventana, "acento", 44)

	-- Cabecera: el ícono elegido en su baldosa, qué es y dónde está.
	F.Baldosa = CreateFrame("Frame", nil, F)
	F.Baldosa:SetSize(40, 40)
	F.Baldosa:SetPoint("TOPLEFT", F, "TOPLEFT", PAD, -PAD)
	F.Baldosa.caja = K.Caja(F.Baldosa, { fondo = "elevado", borde = "linea", corte = K.CORTE.control })
	F.Icono = K.Icono(F.Baldosa, "ic-huella", 22, "acento")
	F.Icono:SetPoint("CENTER")
	F.Titulo = K.Texto(F, "subtitulo", "texto")
	F.Titulo:SetPoint("TOPLEFT", F.Baldosa, "TOPRIGHT", ESP.m, -2)
	F.Lugar = K.Texto(F, "pequeno", "textoTenue")
	F.Lugar:SetPoint("TOPLEFT", F.Titulo, "BOTTOMLEFT", 0, -4)
	F.Cerrar = K.BotonIcono(F, "ic-cerrar", E.Cerrar, { tam = 24, icono = 11, ayuda = L["Cerrar"] })
	F.Cerrar:SetPoint("TOPRIGHT", F, "TOPRIGHT", -ESP.m, -ESP.m)
	F.Titulo:SetPoint("RIGHT", F.Cerrar, "LEFT", -ESP.s, 0)
	F.Lugar:SetPoint("RIGHT", F.Cerrar, "LEFT", -ESP.s, 0)
	F.Titulo:SetWordWrap(false)
	F.Lugar:SetWordWrap(false)

	F.Nombre = campoDeNombre(F)

	F.TIcono = K.Texto(F, "mayus", "textoTenue")
	K.Escribir(F.TIcono, L["Ícono"]:upper())
	F.iconos = {}
	for _, ic in ipairs(Mk.ICONOS) do
		local b = K.BotonIcono(F, ic.tex, function()
			estado.icono = ic.clave
			pintar()
		end, { tam = TAM_ICONO, icono = 20, tipo = "secundario", ayuda = ic.nombre })
		b.alfaClave = ic.clave
		F.iconos[#F.iconos + 1] = b
	end
	F.SelIcono = marcoSeleccion(F, K.CORTE.control)

	F.TColor = K.Texto(F, "mayus", "textoTenue")
	K.Escribir(F.TColor, L["Color"]:upper())
	F.colores = {}
	for _, c in ipairs(Mk.COLORES) do
		local b = CreateFrame("Button", nil, F)
		b:SetSize(TAM_COLOR, TAM_COLOR)
		b:RegisterForClicks("LeftButtonUp")
		b.caja = K.Caja(b, { fondo = c.clave, borde = false, corte = K.CORTE.chico })
		b.alfaClave = c.clave
		b:SetScript("OnClick", function()
			estado.color = c.clave
			pintar()
		end)
		K.ConInfo(b, c.nombre, nil)
		F.colores[#F.colores + 1] = b
	end
	F.SelColor = marcoSeleccion(F, K.CORTE.chico)

	F.Linea = K.Linea(F, "linea")

	-- Abajo: a la izquierda lo que cambia al marcador, a la derecha guardar.
	F.Borrar = K.Boton(F, L["Borrar"], borrar, { tipo = "peligro", tam = "chico" })
	F.Compartir = K.BotonIcono(F, "ic-manada", compartir, { tam = 28, icono = 16, tipo = "secundario" })
	K.ConInfo(F.Compartir, function()
		local puede, por = Mk.PuedeCompartir()
		if puede then return L["Compartir con el grupo"], L["Quien use Alfa en tu grupo lo recibe y puede seguirlo."] end
		return L["Compartir con el grupo"], Mk.PorQueNo(por)
	end)
	F.Guardar = K.Boton(F, L["Guardar"], function() E.Guardar() end, { tipo = "secundario" })
	F.Seguir = K.Boton(F, L["Seguir"], guardarYSeguir, { tipo = "primario", icono = "ic-seguir" })

	F:SetScript("OnHide", function()
		K.OcultarInfo()
		F.Nombre.Campo:ClearFocus()
		estado = {}
	end)
	if A.CloseOnEscape then A.CloseOnEscape(NOMBRE) end
end

-- Coloca las piezas y mide el alto.
local function acomodar()
	local w = ANCHO - PAD * 2
	local y = PAD + 40 + ESP.base
	F.Nombre:ClearAllPoints()
	F.Nombre:SetPoint("TOPLEFT", F, "TOPLEFT", PAD, -y)
	F.Nombre:SetWidth(w)
	y = y + K.ALTO.control + ESP.base

	F.TIcono:ClearAllPoints()
	F.TIcono:SetPoint("TOPLEFT", F, "TOPLEFT", PAD, -y)
	y = y + 14 + ESP.s
	local porFila = max(1, floor((w + GAP_ICONO) / (TAM_ICONO + GAP_ICONO)))
	for i, b in ipairs(F.iconos) do
		local col, fila = (i - 1) % porFila, floor((i - 1) / porFila)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", F, "TOPLEFT", PAD + col * (TAM_ICONO + GAP_ICONO), -(y + fila * (TAM_ICONO + GAP_ICONO)))
	end
	local filas = floor((#F.iconos - 1) / porFila) + 1
	y = y + filas * (TAM_ICONO + GAP_ICONO) - GAP_ICONO + ESP.base

	F.TColor:ClearAllPoints()
	F.TColor:SetPoint("TOPLEFT", F, "TOPLEFT", PAD, -y)
	y = y + 14 + ESP.s + 3
	for i, b in ipairs(F.colores) do
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", F, "TOPLEFT", PAD + 3 + (i - 1) * (TAM_COLOR + GAP_COLOR), -y)
	end
	y = y + TAM_COLOR + 3 + ESP.l

	F.Linea:ClearAllPoints()
	F.Linea:SetPoint("TOPLEFT", F, "TOPLEFT", 0, -y)
	F.Linea:SetPoint("TOPRIGHT", F, "TOPRIGHT", 0, -y)
	y = y + ESP.m
	local suyo = estado.m ~= nil
	F.Borrar:SetShown(suyo)
	F.Seguir:SetTexto(suyo and L["Seguir"] or L["Guardar y seguir"])
	F.Seguir:ClearAllPoints()
	F.Seguir:SetPoint("TOPRIGHT", F, "TOPRIGHT", -PAD, -y)
	F.Guardar:ClearAllPoints()
	F.Guardar:SetPoint("RIGHT", F.Seguir, "LEFT", -ESP.s, 0)
	F.Compartir:ClearAllPoints()
	F.Compartir:SetPoint("LEFT", F, "TOPLEFT", PAD, -(y + K.ALTO.boton / 2))
	F.Borrar:ClearAllPoints()
	F.Borrar:SetPoint("LEFT", F.Compartir, "RIGHT", ESP.s, 0)
	local puede = Mk.PuedeCompartir()
	F.Compartir:SetAlpha(puede and 1 or 0.45)
	y = y + K.ALTO.boton + PAD
	F:SetHeight(y)
end

-- opts = { marcador = m } (uno tuyo) | { nuevo = { mapa, x, y, nombre } },
--        ancla = marco (se abre a su lado; sin ancla, junto al cursor)
function E.Abrir(opts)
	opts = opts or {}
	if not F then construir() end
	local m = opts.marcador
	local n = opts.nuevo
	if not (m or (n and n.mapa and n.x and n.y)) then return end
	if n then
		local mapa, x, y = Mk.EnZona(n.mapa, n.x, n.y)
		n = { mapa = mapa, x = x, y = y, nombre = n.nombre }
	end
	local ultimo = E.ultimo or {}
	estado = {
		m = m, nuevo = not m and n or nil,
		icono = m and m.icono or ultimo.icono or "huella",
		color = m and m.color or ultimo.color or "acento",
	}
	local lugar = m or estado.nuevo
	K.Escribir(F.Titulo, m and m.nombre or L["Nuevo marcador"])
	local donde = Mk.Donde(lugar)
	if m and m.de then donde = donde .. "  \194\183  " .. format(L["de %s"], m.de) end
	K.Escribir(F.Lugar, donde)
	F.Nombre:SetTexto(m and m.nombre or (n and n.nombre) or "", true)
	F.Nombre:SetAyuda(Mk.NombreLugar(lugar))
	acomodar()
	pintar()
	F:ClearAllPoints()
	local ancla = opts.ancla
	local der, arriba = ancla and ancla.GetRight and ancla:GetRight(), ancla and ancla.GetTop and ancla:GetTop()
	local sa, sf = ancla and ancla.GetEffectiveScale and ancla:GetEffectiveScale(), F:GetEffectiveScale()
	if type(der) == "number" and type(arriba) == "number" and type(sa) == "number" and type(sf) == "number" and sf > 0 then
		-- Una vez, donde está el ancla ahora, contra UIParent: el ancla puede
		-- ser un pin que se recicla al mover el mapa (y la ficha saltaría con él).
		F:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", der * sa / sf + ESP.s, arriba * sa / sf)
	else
		local x, y = K.CursorEnUI() -- (1.3.8 revisión: con el escritorio movido, igual)
		F:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x + 14, y - 10)
	end
	F:Show()
	F:Raise()
	-- Uno nuevo: a escribir el nombre de una vez.
	if not m then F.Nombre:Foco() end
end

function E.Visible() return F and F:IsShown() or false end

-- El marcador que se edita ya no existe (lo borraste en otra parte).
Mk.AlCambiar(function()
	if F and F:IsShown() and estado.m and not Mk.PorId(estado.m.id) then E.Cerrar() end
end)
