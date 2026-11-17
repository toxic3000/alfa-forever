-- Alfa - Inicio: la tarjeta de aviso (toxic3000 / La Jauría). GPL-3.0.
--
-- Una tarjeta chica hecha con el Kit (docs/KIT.md): la franja del color del
-- aviso, su ícono en una baldosa (o el de un hechizo, o el lobo), el título,
-- una línea, un texto corto y hasta dos botones (el principal primero). Se
-- va sola a los inicio.segAviso segundos (no con el ratón encima), con su X
-- o con su botón. Se arrastra para moverla (inicio.avisoPos). Una a la vez:
-- las demás esperan en una cola corta, y una urgente pasa primero. La usan
-- los recordatorios, el resumen de la sesión anterior y los avisos del
-- motor que Inicio reemplaza (AvisosMotor.lua).
--
--   M.Aviso.Mostrar(spec)
--     spec = { clave, tipo = "info" | "exito" | "aviso" | "peligro",
--              icono = "ic-...", textura = fileID (un hechizo u objeto), lobo = "aullando",
--              titulo, linea, texto, segundos, sonido = true,
--              botones = { { texto, fn }, ... },   -- el primero es el principal
--              alCerrar = fn }                     -- al irse, por lo que sea
--   M.Aviso.Ocultar(todo)    -- el de ahora (todo = true vacía también la cola)
--   M.Aviso.Quitar(clave)    -- quita ese aviso (en pantalla o en la cola) sin llamar a su alCerrar
--   M.Aviso.Visible() -> la clave del aviso en pantalla, o nil
--   M.Aviso.Probar()
-- Nada corre en OnUpdate: la entrada es una animación del cliente y la
-- salida, un temporizador.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = N.Textos(M.EN)

local floor, max, min, ipairs, type, tonumber = math.floor, math.max, math.min, ipairs, type, tonumber

local Aviso = {}
M.Aviso = Aviso

local ANCHO, ANCHO_MAX = 360, 440
local PAD, BALDOSA = 16, 36
local COLA_MAX = 5
local DEFAULT = { "TOP", 0, -300 }
local TONO = { info = "acento", exito = "exito", aviso = "aviso", peligro = "peligro" }

local f, actual
local turno = 0
local cola = {}

local function lugar()
	local p = N.Get("inicio", "avisoPos")
	if type(p) ~= "table" or type(p[1]) ~= "string" then p = DEFAULT end
	f:ClearAllPoints()
	f:SetPoint(p[1], UIParent, p[1], tonumber(p[2]) or 0, tonumber(p[3]) or 0)
end

-- El alCerrar de un aviso, una sola vez.
local function avisarCierre(spec)
	if type(spec) ~= "table" or spec.alfaCerrado then return end
	spec.alfaCerrado = true
	if type(spec.alCerrar) == "function" then K.Llamar(spec.alCerrar, spec) end
end

-- Un botón: primero su acción (un aviso del motor la lee mientras sigue
-- abierto), luego el aviso se va si nadie lo quitó ya.
local function clic(b)
	local spec, accion = actual, b.alfaAccion
	if not (spec and accion) then return end
	if type(accion.fn) == "function" then K.Llamar(accion.fn) end
	if actual == spec then Aviso.Ocultar() end
end

local function construir()
	f = CreateFrame("Frame", "AlfaInicioAviso", K.Raiz())
	f:SetSize(ANCHO, 80)
	f:SetFrameStrata("HIGH")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f.caja = K.Caja(f, { fondo = "panel", borde = "lineaFuerte", corte = K.CORTE.panel })
	f.Marca = K.Marca(f, K.CORTE.panel, "acento")
	f.Franja = K.Plano(f, "acento", "ARTWORK", 1)
	f.Franja:SetWidth(3)
	f.Franja:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -K.CORTE.panel - 2)
	f.Franja:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, K.CORTE.panel + 2)

	f.Baldosa = CreateFrame("Frame", nil, f)
	f.Baldosa:SetSize(BALDOSA, BALDOSA)
	f.Baldosa:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 2, -PAD)
	f.Baldosa.caja = K.Caja(f.Baldosa, { fondo = "acento", alfaFondo = 0.14, borde = "acento", alfaBorde = 0.4, corte = K.CORTE.control })
	f.Icono = K.Icono(f.Baldosa, "ic-info", 20, "acento")
	f.Icono:SetPoint("CENTER")

	f.Titulo = K.Texto(f, "encabezado", "texto")
	f.Linea = K.Texto(f, "pequeno", "textoTenue")
	f.Texto = K.Texto(f, "nota", "textoSuave")

	f.Cerrar = K.BotonIcono(f, "ic-cerrar", function() Aviso.Ocultar() end, { tam = 22, icono = 10, ayuda = L["Cerrar"] })
	f.Cerrar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)

	f.B1 = K.Boton(f, "", clic, { tipo = "acento", tam = "chico" })
	f.B2 = K.Boton(f, "", clic, { tipo = "fantasma", tam = "chico" })

	local ag = f:CreateAnimationGroup()
	local alfa = ag:CreateAnimation("Alpha")
	alfa:SetFromAlpha(0)
	alfa:SetToAlpha(1)
	alfa:SetDuration(0.2)
	alfa:SetSmoothing("OUT")
	f.Entrada = ag

	f:SetScript("OnDragStart", function(self) if not (A.DragLocked and A.DragLocked()) then self:StartMoving() end end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, _, x, y = self:GetPoint(1)
		if point then N.Set("inicio", "avisoPos", { point, floor((x or 0) + 0.5), floor((y or 0) + 0.5) }) end
	end)
	f:Hide()
	Aviso.frame = f
end

local function ponerBoton(b, accion)
	b.alfaAccion = accion
	if not accion then
		b:Hide()
		return 0
	end
	b:SetTexto(accion.texto or "")
	b:Show()
	return b:AnchoNatural()
end

local function vencer(mio)
	if mio ~= turno or not (f and f:IsShown()) then return end
	if f:IsMouseOver() then
		K.Despues(2, function() vencer(mio) end)
		return
	end
	Aviso.Ocultar()
end

local function pintar(spec)
	actual = spec
	turno = turno + 1
	local mio = turno
	local tono = TONO[spec.tipo] or "acento"
	local relleno = K.Tono(tono)
	K.ColorPlano(f.Franja, relleno)
	K.ColorPlano(f.Marca, relleno)
	f.Baldosa.caja:Estilo({ fondo = relleno, borde = relleno })
	-- El ícono: el de un hechizo tal cual, el lobo o un ícono de Alfa teñido.
	if spec.textura then
		f.Icono:SetTexture(spec.textura)
		f.Icono.alfaColor = nil
		f.Icono:SetVertexColor(1, 1, 1, 1)
		f.Icono:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		f.Icono:SetSize(BALDOSA - 6, BALDOSA - 6)
	else
		f.Icono:SetTexCoord(0, 1, 0, 1)
		if spec.lobo then
			f.Icono:SetTexture(K.Lobo(spec.lobo))
			f.Icono.alfaColor = relleno
			f.Icono:SetVertexColor(K.Color(relleno))
			f.Icono:SetSize(30, 30)
		else
			K.SetIcono(f.Icono, spec.icono or "ic-info", relleno)
			f.Icono:SetSize(20, 20)
		end
	end

	local botones = type(spec.botones) == "table" and spec.botones or {}
	local w1 = ponerBoton(f.B1, botones[1])
	local w2 = ponerBoton(f.B2, botones[2])
	K.Escribir(f.Titulo, spec.titulo or "")
	K.Escribir(f.Linea, spec.linea or "")
	K.Escribir(f.Texto, spec.texto or "")

	local x = PAD + 2 + BALDOSA + 12
	-- Lo justo para el título y los botones, sin pasar de ANCHO_MAX.
	local ancho = max(ANCHO, min(ANCHO_MAX, x + K.AnchoTexto(f.Titulo) + 34), x + w1 + (w2 > 0 and w2 + 8 or 0) + PAD)
	ancho = min(ANCHO_MAX, ancho)
	f:SetWidth(ancho)
	local tw = ancho - x - 30
	local y = PAD - 2
	f.Titulo:ClearAllPoints()
	f.Titulo:SetPoint("TOPLEFT", f, "TOPLEFT", x, -y)
	y = y + K.Parrafo(f.Titulo, tw, 2)
	local conLinea = (spec.linea or "") ~= ""
	f.Linea:SetShown(conLinea)
	if conLinea then
		y = y + 2
		f.Linea:ClearAllPoints()
		f.Linea:SetPoint("TOPLEFT", f, "TOPLEFT", x, -y)
		y = y + K.Parrafo(f.Linea, tw, 2)
	end
	local conTexto = (spec.texto or "") ~= ""
	f.Texto:SetShown(conTexto)
	if conTexto then
		y = y + 6
		f.Texto:ClearAllPoints()
		f.Texto:SetPoint("TOPLEFT", f, "TOPLEFT", x, -y)
		y = y + K.Parrafo(f.Texto, ancho - x - PAD, 5)
	end
	if w1 > 0 then
		y = y + 10
		f.B1:ClearAllPoints()
		f.B1:SetPoint("TOPLEFT", f, "TOPLEFT", x, -y)
		if w2 > 0 then
			f.B2:ClearAllPoints()
			f.B2:SetPoint("LEFT", f.B1, "RIGHT", 8, 0)
		end
		y = y + K.ALTO.botonChico
	end
	f:SetHeight(max(y, PAD + BALDOSA) + PAD)

	local wasShown = f:IsShown()
	lugar()
	f:Show()
	if not wasShown then
		f.Entrada:Stop()
		f.Entrada:Play()
	end
	if spec.sonido and N.Get("inicio", "sonido") and SOUNDKIT and SOUNDKIT.RAID_WARNING then
		pcall(A.PlaySound, SOUNDKIT.RAID_WARNING, "Master")
	end
	local secs = tonumber(spec.segundos) or tonumber(N.Get("inicio", "segAviso")) or 10
	if w1 > 0 then secs = secs + 4 end
	K.Despues(secs, function() vencer(mio) end)
end

local function siguiente()
	if f and f:IsShown() then return end
	local spec = table.remove(cola, 1)
	if spec then pintar(spec) end
end

function Aviso.Mostrar(spec)
	if type(spec) ~= "table" then return end
	if A.Hidden and A.Hidden() then
		avisarCierre(spec)
		return
	end
	if not f then construir() end
	if f:IsShown() and actual and actual.clave ~= spec.clave then
		for i = #cola, 1, -1 do
			if cola[i].clave == spec.clave then table.remove(cola, i) end
		end
		if spec.tipo == "peligro" then table.insert(cola, 1, spec) else cola[#cola + 1] = spec end
		while #cola > COLA_MAX do avisarCierre(table.remove(cola)) end
		return
	end
	pintar(spec)
end

function Aviso.Ocultar(todo)
	local era = actual
	actual = nil
	turno = turno + 1
	if f and f:IsShown() then f:Hide() end
	if todo then
		local resto = cola
		cola = {}
		for _, s in ipairs(resto) do avisarCierre(s) end
	end
	avisarCierre(era)
	if #cola > 0 then A.After(0.4, siguiente) end
end

-- Quita el aviso `clave` (lo cerró quien lo pidió): sin llamar a su alCerrar.
function Aviso.Quitar(clave)
	for i = #cola, 1, -1 do
		if cola[i].clave == clave then table.remove(cola, i) end
	end
	if actual and actual.clave == clave then
		actual.alfaCerrado = true
		Aviso.Ocultar()
	end
end

function Aviso.Visible()
	return f and f:IsShown() and actual and actual.clave or nil
end

-- Un aviso de muestra (el botón de los ajustes).
function Aviso.Probar()
	Aviso.Mostrar({
		clave = "prueba", tipo = "info", lobo = "normal",
		titulo = L["Así se ven tus avisos"],
		linea = L["Arrástralo para moverlo"],
		texto = L["Alfa te avisa aquí de lo importante: equipo por reparar, bolsas llenas, habilidades nuevas, tu buff y tu descanso."],
	})
end

-- Ocultar Alfa quita el aviso y su cola: era noticia, no algo para después.
A.On("ALFA_HIDDEN", function(oculto)
	if oculto == true then Aviso.Ocultar(true) end
end)
