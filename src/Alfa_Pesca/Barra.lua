-- Alfa - Pesca: la barra de pesca (toxic3000 / La Jauría). GPL-3.0.
--
-- Mientras el modo pesca está abierto:
--   * La barra (Kit): tu habilidad ("Experto 126/225") con su avance, lo que
--     hace tu tecla ahora ("Buen lanzamiento · Pulsa Espacio al salpicar"),
--     el tiempo que le queda al lanzamiento y botones: equipo, cebo, cocina,
--     juguetes, metas, diario, ajustes y cerrar. Horizontal o vertical, se
--     mueve arrastrándola, cambia de tamaño y se pliega sola cuando no tienes
--     el ratón encima.
--   * Sus menús se abren hacia donde hay espacio en la pantalla.
--   * Vista mínima al lanzar: la barra se cambia por una línea fina con el
--     tiempo, tu habilidad y lo último que sacaste.
--   * El aviso de lo que sacaste: los íconos con su cantidad y, si toca, la
--     maestría nueva.
-- Nada corre en OnUpdate salvo el tiempo del lanzamiento, mientras dura.
--
-- Lo que necesita un clic protegido (usar un cebo, un juguete, encender una
-- fogata, cocinar) pasa por un solo botón seguro que se pone encima del
-- botón del Kit al pasar el ratón, fuera de combate (M.Cubrir); al empezar un
-- combate se quita. Así ningún marco del Kit queda protegido.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID
local E = M.E
local Eq = M.Eq

local floor, max, min, format, type, pairs, ipairs, tonumber, tostring = math.floor, math.max, math.min, string.format, type, pairs, ipairs, tonumber, tostring
local ESP = K.ESP

local MEDIA = "Interface\\AddOns\\Alfa_Pesca\\Media\\"
M.ICONO = {
	cebo = MEDIA .. "pesca-cebo", fogata = MEDIA .. "pesca-fogata", meta = MEDIA .. "pesca-meta", diario = MEDIA .. "pesca-diario",
}

local function opt(k) return N.Get(ID, k) end
local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end

local function reloj(seg)
	seg = max(0, floor((seg or 0) + 0.5))
	return format("%d:%02d", floor(seg / 60), seg % 60)
end
M.Reloj = reloj

---------------------------------------------------------------------------
-- El botón seguro que cubre al botón del Kit bajo el ratón
---------------------------------------------------------------------------
local seguro = CreateFrame("Button", "AlfaPescaSeguro", UIParent, "SecureActionButtonTemplate")
seguro:SetFrameStrata("FULLSCREEN_DIALOG")
seguro:RegisterForClicks("AnyUp")
seguro:Hide()

local ATRIBUTOS = { "type", "type1", "type2", "macrotext", "macrotext1", "item", "spell" }

local function soltarSeguro()
	if enCombate() then return end
	local d = seguro.dueno
	seguro.dueno = nil
	seguro:Hide()
	seguro:ClearAllPoints()
	if d then
		d.alfaSobre = nil
		local f = d:GetScript("OnLeave")
		if f then pcall(f, d) end
		K.OcultarInfo(d)
	end
end

-- El botón del Kit de abajo pierde el ratón al cubrirse: se le devuelve su
-- realce y su cuadro de información.
local function mostrarInfoDe(d)
	local i = d.alfaInfo
	if not i then return end
	local t, x = i[1], i[2]
	if type(t) == "function" then t, x = t(d) end
	if (t and t ~= "") or (x and x ~= "") then K.MostrarInfo(d, t, x) end
end

seguro:SetScript("OnEnter", function(self)
	local d = self.dueno
	if not d then return end
	local f = d:GetScript("OnEnter")
	if f then pcall(f, d) end
	mostrarInfoDe(d)
end)
seguro:SetScript("OnLeave", soltarSeguro)
seguro:SetScript("PostClick", function(self, boton)
	local d = self.dueno
	if d and d.alfaTrasClic then K.Llamar(d.alfaTrasClic, d, boton) end
end)

-- dueno: un botón del Kit; atrib = { type = "macro", macrotext = "..." } | { type = "item", item = "item:123" } ...
function M.Cubrir(dueno, atrib)
	if enCombate() or not dueno or not atrib then return end
	for _, k in ipairs(ATRIBUTOS) do seguro:SetAttribute(k, atrib[k]) end
	seguro.dueno = dueno
	seguro:ClearAllPoints()
	seguro:SetAllPoints(dueno)
	seguro:Show()
	mostrarInfoDe(dueno)
end

-- Un botón del Kit que hace algo protegido: atrib() -> atributos | nil (nil: su clic normal).
function M.ConSeguro(b, atrib)
	b.alfaSeguro = atrib
	b:HookScript("OnEnter", function(self)
		if enCombate() or (seguro.dueno == self and seguro:IsShown()) then return end
		local a = type(self.alfaSeguro) == "function" and self.alfaSeguro(self) or self.alfaSeguro
		if a then M.Cubrir(self, a) end
	end)
	-- Si el botón se va (se cierra su menú o su ventana), el seguro se va con él.
	b:HookScript("OnHide", function(self) if seguro.dueno == self then soltarSeguro() end end)
	return b
end

---------------------------------------------------------------------------
-- La barra
---------------------------------------------------------------------------
local B = {}
M.Barra = B

local barra, canal, menu, toast

local BOTONES = {
	{ id = "equipo", icono = "ic-personaje", ayuda = L["Equipo de pesca"] },
	{ id = "cebo", icono = M.ICONO.cebo, ayuda = L["Cebos"] },
	{ id = "cocina", icono = M.ICONO.fogata, ayuda = L["Cocina junto al agua"] },
	{ id = "juguetes", icono = "ic-bolsas", ayuda = L["Juguetes y consumibles de pesca"] },
	{ id = "metas", icono = M.ICONO.meta, ayuda = L["Metas de pesca"] },
	{ id = "diario", icono = M.ICONO.diario, ayuda = L["Diario de pesca"] },
	{ id = "ajustes", icono = "ic-ajustes", ayuda = L["Ajustes de pesca"] },
	{ id = "cerrar", icono = "ic-cerrar", ayuda = L["Cerrar el modo pesca"] },
}
local TAM_BOTON, GAP = 24, 2

local function datosBarra()
	local d = N.Datos(ID)
	if type(d.barra) ~= "table" then d.barra = {} end
	return d.barra
end

local function guardarLugar(f, clave)
	local p, _, rp, x, y = f:GetPoint(1)
	if not p then return end
	datosBarra()[clave] = { p, rp, floor(K.num(x, 0) + 0.5), floor(K.num(y, 0) + 0.5) }
end

local function ponerEnSuLugar(f, clave, defecto)
	f:ClearAllPoints()
	local l = datosBarra()[clave]
	if type(l) == "table" and type(l[3]) == "number" then
		f:SetPoint(l[1], UIParent, l[2], l[3], l[4])
	else
		f:SetPoint(defecto[1], UIParent, defecto[2], defecto[3], defecto[4])
	end
end

local function arrastrable(f, clave)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetClampedToScreen(true)
	f:SetScript("OnDragStart", function(self) if not (A.DragLocked and A.DragLocked()) then self:StartMoving() end end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		guardarLugar(self, clave)
		if menu and menu:IsShown() then B.CerrarMenu() end
	end)
end

local function abrirVentana(pestana)
	if M.V then M.V.Abrir(pestana) end
end

local function alClicBoton(id, b)
	if id == "cerrar" then M.CerrarModo() return end
	if id == "ajustes" then N.Abrir(ID) return end
	if id == "diario" then abrirVentana("diario") return end
	if id == "metas" then if M.Metas then M.Metas.Alternar(true) end return end
	B.AlternarMenu(id, b)
end

local function crearBarra()
	local f = CreateFrame("Frame", "AlfaPescaBarra", K.Raiz())
	f:SetFrameStrata("MEDIUM")
	f:SetSize(460, 76)
	f.caja = K.Caja(f, { fondo = "fondo", borde = "linea", corte = K.CORTE.panel, rol = "panel" })
	f.Marca = K.Marca(f, K.CORTE.panel)
	arrastrable(f, "lugar")
	-- La baldosa con el ícono de pesca (también se arrastra).
	f.Baldosa = CreateFrame("Frame", nil, f)
	f.Baldosa.caja = K.Caja(f.Baldosa, { fondo = "acento", alfaFondo = 0.14, borde = "acento", alfaBorde = 0.45, corte = K.CORTE.control })
	f.Icono = K.Icono(f.Baldosa, "ic-pesca", 20, "acento")
	f.Icono:SetPoint("CENTER")
	f.Habilidad = K.Texto(f, "cuerpo", "texto")
	f.Bono = K.Insignia(f, "", "acento")
	f.Estado = K.Texto(f, "nota", "textoSuave")
	f.Tiempo = K.Texto(f, "numero", "acento")
	f.Tiempo:SetJustifyH("RIGHT")
	f.Avance = K.Progreso(f, { alto = 3 })
	f.botones = {}
	for _, d in ipairs(BOTONES) do
		local b = K.BotonIcono(f, d.icono, function(self) alClicBoton(d.id, self) end, { tam = TAM_BOTON, icono = 14, ayuda = d.ayuda })
		b.alfaId = d.id
		f.botones[#f.botones + 1] = b
		b:HookScript("OnEnter", function() B.Desplegar() end)
	end
	f:SetScript("OnEnter", function() B.Desplegar() end)
	f:SetScript("OnLeave", function() B.PlegarLuego() end)
	f:SetScript("OnUpdate", nil)
	f:Hide()
	M.VISIBLES[#M.VISIBLES + 1] = f
	return f
end

-- Plegada: sin botones ni insignia (solo la línea de lo que pasa). Se pliega
-- sola un momento después de quitar el ratón, si lo pides.
local plegada, turnoPlegar = false, 0

function B.Desplegar()
	turnoPlegar = turnoPlegar + 1
	if plegada then
		plegada = false
		B.Acomodar()
	end
end

function B.PlegarLuego()
	if not opt("barraPlegar") then return end
	turnoPlegar = turnoPlegar + 1
	local mio = turnoPlegar
	A.After(2, function()
		if mio ~= turnoPlegar or not barra or not barra:IsShown() then return end
		if barra:IsMouseOver() or (menu and menu:IsShown()) then return end
		plegada = true
		B.Acomodar()
	end)
end

function B.Acomodar()
	local f = barra
	if not f then return end
	local vertical = opt("barraVertical") and true or false
	local pad = ESP.m
	local conBotones = not plegada
	for _, b in ipairs(f.botones) do b:SetShown(conBotones) end
	f.Bono:SetShown(conBotones and (f.alfaBono or 0) > 0)
	f.Baldosa:ClearAllPoints()
	f.Habilidad:ClearAllPoints()
	f.Estado:ClearAllPoints()
	f.Tiempo:ClearAllPoints()
	f.Avance:ClearAllPoints()
	f.Bono:ClearAllPoints()
	if not vertical then
		local ancho = 460
		local tile = conBotones and 34 or 26
		f.Baldosa:SetSize(tile, tile)
		f.Baldosa:SetPoint("TOPLEFT", f, "TOPLEFT", pad, -pad)
		local x = pad + tile + ESP.m
		f.Habilidad:SetPoint("TOPLEFT", f, "TOPLEFT", x, -(pad + (conBotones and 4 or 0)))
		K.Ajustar(f.Habilidad, 200)
		f.Bono:SetPoint("LEFT", f.Habilidad, "RIGHT", ESP.s, 0)
		local bx = ancho - pad
		for i = #f.botones, 1, -1 do
			local b = f.botones[i]
			b:ClearAllPoints()
			b:SetPoint("TOPRIGHT", f, "TOPLEFT", bx, -pad)
			bx = bx - TAM_BOTON - GAP
		end
		local yEstado = conBotones and (pad + TAM_BOTON + 2) or (pad + 15)
		f.Tiempo:SetPoint("TOPRIGHT", f, "TOPRIGHT", -pad, -yEstado)
		K.Ajustar(f.Tiempo, 60)
		f.Estado:SetPoint("TOPLEFT", f, "TOPLEFT", x, -yEstado)
		f.Estado:SetWidth(max(60, ancho - x - pad - K.AnchoTexto(f.Tiempo) - ESP.s))
		f.Estado:SetWordWrap(false)
		local alto = yEstado + 16 + ESP.s + 3 + pad
		if not conBotones then alto = pad + 15 + 16 + ESP.s + 3 + ESP.s end
		f.Avance:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", pad, conBotones and pad or ESP.s)
		f.Avance:Acomodar(ancho - 2 * pad)
		f:SetSize(ancho, alto)
	else
		local ancho = 204
		local tile = 30
		f.Baldosa:SetSize(tile, tile)
		f.Baldosa:SetPoint("TOPLEFT", f, "TOPLEFT", pad, -pad)
		local x = pad + tile + ESP.s
		f.Habilidad:SetPoint("TOPLEFT", f, "TOPLEFT", x, -(pad + 2))
		K.Ajustar(f.Habilidad, ancho - x - pad)
		f.Bono:SetPoint("TOPLEFT", f.Habilidad, "BOTTOMLEFT", 0, -3)
		local cabeza = f.Bono:IsShown() and max(tile, 2 + 15 + 3 + K.ALTO.insignia) or tile
		local y = pad + cabeza + ESP.s
		f.Avance:SetPoint("TOPLEFT", f, "TOPLEFT", pad, -y)
		f.Avance:Acomodar(ancho - 2 * pad)
		y = y + 3 + ESP.s
		f.Estado:SetPoint("TOPLEFT", f, "TOPLEFT", pad, -y)
		y = y + K.Parrafo(f.Estado, ancho - 2 * pad, 3)
		f.Tiempo:SetPoint("TOPLEFT", f, "TOPLEFT", pad, -(y + 4))
		K.Ajustar(f.Tiempo, 80)
		y = y + ((f.Tiempo:GetText() or "") ~= "" and 20 or 4)
		if conBotones then
			y = y + ESP.s
			local porFila = 4
			local gap = floor((ancho - 2 * pad - porFila * TAM_BOTON) / (porFila - 1))
			for i, b in ipairs(f.botones) do
				local fila, col = floor((i - 1) / porFila), (i - 1) % porFila
				b:ClearAllPoints()
				b:SetPoint("TOPLEFT", f, "TOPLEFT", pad + col * (TAM_BOTON + gap), -(y + fila * (TAM_BOTON + 6)))
			end
			y = y + 2 * TAM_BOTON + 6
		end
		f:SetSize(ancho, y + pad)
	end
	f:SetScale(max(0.6, min(1.6, tonumber(opt("barraEscala")) or 1)))
end

-- Los números y textos de la barra.
function B.Refrescar()
	local f = barra
	if not f or not f:IsShown() then return end
	local texto, r, mx, bono = M.TextoHabilidad()
	K.Escribir(f.Habilidad, texto)
	f.Avance:Set(r, mx)
	local total = (bono or 0)
	f.alfaBono = total
	if total > 0 then f.Bono:Set(format(L["+%d"], total), "acento") end
	local est = M.Estado()
	K.Escribir(f.Estado, est.texto or "")
	K.ColorTexto(f.Estado, est.tono == "aviso" and "aviso" or (est.tono == "exito" and "exito" or "textoSuave"))
	local resta = M.Restante()
	f.Tiempo:SetText(resta and reloj(resta) or "")
	local relleno = K.Tono(E.modo and "acento" or "neutro")
	f.Baldosa.caja:Estilo({ fondo = relleno, alfaFondo = 0.14, borde = relleno, alfaBorde = 0.45 })
	for _, b in ipairs(f.botones) do
		if b.SetMarcado then b:SetMarcado(menu and menu:IsShown() and menu.id == b.alfaId) end
	end
	B.Acomodar()
end

-- El tiempo del lanzamiento: solo mientras dura.
local acum = 0
local function alActualizar(self, dt)
	acum = acum + (dt or 0)
	if acum < 0.1 then return end
	acum = 0
	local resta = M.Restante()
	if not resta then
		self:SetScript("OnUpdate", nil)
		return
	end
	if barra and barra:IsShown() then barra.Tiempo:SetText(reloj(resta)) end
	if canal and canal:IsShown() then
		canal.Tiempo:SetText(reloj(resta))
		canal.Avance:Set(resta / 30)
	end
end

local function contar(f)
	acum = 1
	f:SetScript("OnUpdate", alActualizar)
end

---------------------------------------------------------------------------
-- La vista mínima al lanzar
---------------------------------------------------------------------------
local function crearCanal()
	local f = CreateFrame("Frame", "AlfaPescaCanal", K.Raiz())
	f:SetFrameStrata("MEDIUM")
	f:SetSize(280, 44)
	f.caja = K.Caja(f, { fondo = "fondo", borde = "linea", corte = K.CORTE.control, rol = "panel" })
	f.Icono = K.Icono(f, "ic-pesca", 14, "acento")
	f.Icono:SetPoint("TOPLEFT", f, "TOPLEFT", ESP.s, -ESP.s)
	f.Habilidad = K.Texto(f, "pequeno", "textoSuave")
	f.Habilidad:SetPoint("LEFT", f.Icono, "RIGHT", 6, 0)
	f.Tiempo = K.Texto(f, "numero", "acento")
	f.Tiempo:SetPoint("TOPRIGHT", f, "TOPRIGHT", -ESP.s, -ESP.s + 1)
	f.Avance = K.Progreso(f, { alto = 4 })
	f.Avance:SetPoint("TOPLEFT", f, "TOPLEFT", ESP.s, -26)
	f.Recap = K.Texto(f, "pequeno", "textoTenue")
	f.Recap:SetPoint("TOPLEFT", f.Avance, "BOTTOMLEFT", 0, -3)
	f.Recap:SetPoint("RIGHT", f, "RIGHT", -ESP.s, 0)
	f.Recap:SetWordWrap(false)
	arrastrable(f, "lugarCanal")
	f:Hide()
	M.VISIBLES[#M.VISIBLES + 1] = f
	return f
end

local function recap()
	local o = E.ultimo and E.ultimo[1]
	if not o then return L["Todavía nada en esta sesión"] end
	local s = M.Sesion()
	return format(L["Última: %s ×%d · %d en la sesión"], o.nombre or "?", o.cantidad or 1, s.total or 0)
end

function B.MostrarCanal()
	if not (E.modo and opt("vistaMinima") and E.canal) then return end
	canal = canal or crearCanal()
	local r, mx = M.Habilidad()
	K.Escribir(canal.Habilidad, r and format(L["Pesca %d/%d"], r, mx or 0) or L["Pesca"])
	K.Escribir(canal.Recap, recap())
	canal.Avance:Acomodar(280 - 2 * ESP.s)
	local resta = M.Restante() or 0
	canal.Tiempo:SetText(reloj(resta))
	canal.Avance:Set(resta / 30)
	if barra and barra:IsShown() and not datosBarra().lugarCanal then
		canal:ClearAllPoints()
		canal:SetPoint("CENTER", barra, "CENTER", 0, 0)
	else
		ponerEnSuLugar(canal, "lugarCanal", { "BOTTOM", "BOTTOM", 0, 240 })
	end
	canal:SetScale(max(0.6, min(1.6, tonumber(opt("barraEscala")) or 1)))
	canal:Show()
	if barra then barra:Hide() end
	if menu then B.CerrarMenu() end
	contar(canal)
end

function B.OcultarCanal()
	if canal then canal:Hide() canal:SetScript("OnUpdate", nil) end
end

---------------------------------------------------------------------------
-- Mostrar u ocultar la barra según el modo
---------------------------------------------------------------------------
function B.Actualizar()
	if E.modo and E.canal and opt("vistaMinima") then
		B.MostrarCanal()
		return
	end
	B.OcultarCanal()
	local quiere = E.modo and opt("barra")
	if quiere then
		barra = barra or crearBarra()
		if not barra:IsShown() then
			ponerEnSuLugar(barra, "lugar", { "BOTTOM", "BOTTOM", 0, 220 })
			plegada = false
			barra:Show()
			B.PlegarLuego()
		end
		B.Refrescar()
		if E.canal then contar(barra) end
	elseif barra then
		barra:Hide()
		if menu then B.CerrarMenu() end
	end
end

function B.Barra() return barra end

---------------------------------------------------------------------------
-- Los menús de la barra
---------------------------------------------------------------------------
local FILA = 36
local ANCHO_MENU = 268

local function crearMenu()
	local f = CreateFrame("Frame", "AlfaPescaMenu", K.Raiz())
	f:SetFrameStrata("HIGH")
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f.caja = K.Caja(f, { fondo = "panel", borde = "lineaFuerte", corte = K.CORTE.control, rol = "panel" })
	f.Titulo = K.Texto(f, "encabezado", "texto")
	f.Titulo:SetPoint("TOPLEFT", f, "TOPLEFT", ESP.m, -ESP.m)
	f.Nota = K.Texto(f, "nota", "textoTenue")
	f.filas = {}
	f.pie = {}
	f:Hide()
	f:SetScript("OnHide", function()
		if seguro.dueno and not enCombate() then soltarSeguro() end
		if barra then B.Refrescar() end
	end)
	M.VISIBLES[#M.VISIBLES + 1] = f
	return f
end

local function filaMenu(i)
	local fl = menu.filas[i]
	if fl then return fl end
	fl = CreateFrame("Button", nil, menu)
	fl:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	fl:SetHeight(FILA)
	fl.Fondo = fl:CreateTexture(nil, "BACKGROUND")
	fl.Fondo:SetAllPoints(fl)
	fl.Fondo:SetColorTexture(1, 1, 1, 0.05)
	fl.Fondo:Hide()
	fl.Icono = fl:CreateTexture(nil, "ARTWORK")
	fl.Icono:SetSize(26, 26)
	fl.Icono:SetPoint("LEFT", fl, "LEFT", 6, 0)
	fl.Nombre = K.Texto(fl, "etiqueta", "texto")
	fl.Nombre:SetPoint("TOPLEFT", fl.Icono, "TOPRIGHT", 8, 1)
	fl.Nombre:SetPoint("RIGHT", fl, "RIGHT", -8, 0)
	fl.Valor = K.Texto(fl, "pequeno", "textoSuave")
	fl.Valor:SetPoint("TOPLEFT", fl.Nombre, "BOTTOMLEFT", 0, -2)
	fl.Valor:SetPoint("RIGHT", fl, "RIGHT", -8, 0)
	fl:SetScript("OnEnter", function(self) self.alfaSobre = true self.Fondo:Show() end)
	fl:SetScript("OnLeave", function(self) self.alfaSobre = nil self.Fondo:Hide() end)
	fl:SetScript("OnClick", function(self, boton)
		local d = self.alfaDato
		if d and d.alClic and not d.apagada then K.Llamar(d.alClic, d, boton) end
	end)
	fl.alfaTrasClic = function(self, boton)
		local d = self.alfaDato
		if d and d.trasClic then K.Llamar(d.trasClic, d, boton) end
	end
	M.ConSeguro(fl, function(self)
		local d = self.alfaDato
		return d and not d.apagada and d.seguro or nil
	end)
	menu.filas[i] = fl
	return fl
end

local function pintarFila(fl, d)
	fl.alfaDato = d
	if type(d.icono) == "string" and not d.icono:find("\\", 1, true) and d.icono:sub(1, 3) == "ic-" then
		K.SetIcono(fl.Icono, d.icono, d.apagada and "textoTenue" or "acento")
		fl.Icono:SetTexCoord(0, 1, 0, 1)
	elseif type(d.icono) == "string" and d.icono:find("Alfa_Pesca", 1, true) then
		K.SetIcono(fl.Icono, d.icono, d.apagada and "textoTenue" or "acento")
		fl.Icono:SetTexCoord(0, 1, 0, 1)
	else
		fl.Icono:SetTexture(d.icono or "Interface\\Icons\\INV_Misc_QuestionMark")
		fl.Icono.alfaColor = nil
		fl.Icono:SetVertexColor(1, 1, 1, 1)
		fl.Icono:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	end
	fl.Icono:SetDesaturated(d.apagada and true or false)
	K.Escribir(fl.Nombre, d.nombre or "?")
	K.ColorTexto(fl.Nombre, d.apagada and "textoTenue" or (d.marcada and "acento" or "texto"))
	K.Escribir(fl.Valor, d.valor or "")
	if d.ayuda or d.motivo then K.ConInfo(fl, d.nombre, d.motivo or d.ayuda) else fl.alfaInfo = { nil, nil } end
end

local function botonPie(i)
	local b = menu.pie[i]
	if b then return b end
	b = K.Boton(menu, "", nil, { tipo = "secundario", tam = "chico" })
	menu.pie[i] = b
	return b
end

-- Hacia dónde abre: abajo o arriba según el espacio, alineado al borde que conviene.
local function colocarMenu(dueno)
	menu:ClearAllPoints()
	local x, y = dueno:GetCenter()
	local s = dueno:GetEffectiveScale() / max(0.01, UIParent:GetEffectiveScale())
	x, y = K.num(x, 0) * s, K.num(y, 0) * s
	local w, h = K.num(UIParent:GetWidth(), 1920), K.num(UIParent:GetHeight(), 1080)
	local arriba = y < h / 2
	local derecha = x > w / 2
	if opt("barraVertical") then
		if derecha then
			menu:SetPoint(arriba and "BOTTOMRIGHT" or "TOPRIGHT", dueno, arriba and "BOTTOMLEFT" or "TOPLEFT", -6, 0)
		else
			menu:SetPoint(arriba and "BOTTOMLEFT" or "TOPLEFT", dueno, arriba and "BOTTOMRIGHT" or "TOPRIGHT", 6, 0)
		end
	else
		local v1, v2 = arriba and "BOTTOM" or "TOP", arriba and "TOP" or "BOTTOM"
		local h1 = derecha and "RIGHT" or "LEFT"
		menu:SetPoint(v1 .. h1, dueno, v2 .. h1, 0, arriba and 6 or -6)
	end
	menu:SetScale(barra and barra:GetScale() or 1)
end

-- contenido = { titulo, nota, filas = { ... }, pie = { { texto, alClic, activo } } }
function B.MostrarMenu(id, dueno, contenido)
	menu = menu or crearMenu()
	menu.id = id
	K.Escribir(menu.Titulo, contenido.titulo or "")
	local y = ESP.m + 18 + ESP.s
	if contenido.nota and contenido.nota ~= "" then
		K.Escribir(menu.Nota, contenido.nota)
		menu.Nota:ClearAllPoints()
		menu.Nota:SetPoint("TOPLEFT", menu, "TOPLEFT", ESP.m, -y)
		y = y + K.Parrafo(menu.Nota, ANCHO_MENU - 2 * ESP.m, 3) + ESP.s
		menu.Nota:Show()
	else
		menu.Nota:Hide()
	end
	local filas = contenido.filas or {}
	for i, d in ipairs(filas) do
		local fl = filaMenu(i)
		pintarFila(fl, d)
		fl:ClearAllPoints()
		fl:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -y)
		fl:SetWidth(ANCHO_MENU - 8)
		fl:Show()
		y = y + FILA
	end
	for i = #filas + 1, #menu.filas do menu.filas[i]:Hide() end
	local pie = contenido.pie or {}
	if #pie > 0 then
		y = y + ESP.s
		local x = ESP.m
		for i, p in ipairs(pie) do
			local b = botonPie(i)
			b:SetTexto(p.texto)
			b.alClic = function() K.Llamar(p.alClic) B.CerrarMenu() end
			b:SetActivo(p.activo ~= false)
			b:ClearAllPoints()
			if x + b:AnchoNatural() > ANCHO_MENU - ESP.m and x > ESP.m then
				x = ESP.m
				y = y + K.ALTO.botonChico + ESP.s
			end
			b:SetPoint("TOPLEFT", menu, "TOPLEFT", x, -y)
			b:Show()
			x = x + b:AnchoNatural() + ESP.s
		end
		y = y + K.ALTO.botonChico
	end
	for i = #pie + 1, #menu.pie do menu.pie[i]:Hide() end
	menu:SetSize(ANCHO_MENU, y + ESP.m)
	colocarMenu(dueno)
	menu:Show()
	if barra then B.Refrescar() end
end

function B.CerrarMenu()
	if menu and menu:IsShown() then menu:Hide() end
end

function B.AlternarMenu(id, dueno)
	if menu and menu:IsShown() and menu.id == id then B.CerrarMenu() return end
	local fn = B.MENUS[id]
	if not fn then return end
	local ok, contenido = pcall(fn)
	if not ok then
		if geterrorhandler then geterrorhandler()(contenido) end
		return
	end
	if contenido then B.MostrarMenu(id, dueno, contenido) end
end

local function minutos(seg)
	if seg <= 0 then return nil end
	if seg >= 60 then return format(L["%d min"], floor(seg / 60 + 0.5)) end
	return format(L["%d s"], floor(seg + 0.5))
end

B.MENUS = {
	equipo = function()
		local filas = {}
		for _, e in ipairs(Eq.Lista()) do
			filas[#filas + 1] = { icono = e.icono, nombre = e.nombre, marcada = e.puesto,
				valor = (e.bono > 0 and format(L["+%d"], e.bono) or "") .. (e.puesto and (" " .. L["puesto"]) or "") }
		end
		local cambios = #Eq.MejorEquipo()
		local nota
		if #filas == 0 then
			nota = L["No llevas nada de pesca. Compra una caña con un vendedor de suministros de pesca: la guía te dice dónde."]
		elseif cambios > 0 then
			nota = format(L["Tienes %d piezas mejores para pescar en tus bolsas."], cambios)
		end
		return {
			titulo = L["Equipo de pesca"], nota = nota, filas = filas,
			pie = {
				{ texto = L["Ponerme lo de pesca"], activo = cambios > 0 and not enCombate(), alClic = function() Eq.PonerPesca() end },
				{ texto = L["Volver a mi equipo"], activo = Eq.HayNormal() and not enCombate(), alClic = function() Eq.Restaurar() end },
			},
		}
	end,
	cebo = function()
		local filas = {}
		local pref = tonumber(opt("ceboPreferido")) or 0
		local cana = Eq.CanaPuesta()
		local activo = Eq.CeboActivo()
		for _, c in ipairs(Eq.Cebos()) do
			local apagada = not c.puede or not cana or c.cuenta <= 0
			filas[#filas + 1] = {
				id = c.id, icono = c.icono, nombre = c.nombre, marcada = c.id == pref,
				valor = format(L["+%d · ×%d"], c.bono, c.cuenta) .. (c.id == pref and (" · " .. L["preferido"]) or ""),
				apagada = apagada, motivo = (not cana and L["Ponte la caña primero."]) or c.motivo,
				ayuda = L["Clic: ponerlo en tu caña. Clic derecho: usarlo siempre que tu tecla ponga cebo."],
				seguro = c.nombre and { type1 = "macro", macrotext1 = "/use " .. c.nombre .. "\n/use 16", type2 = nil } or nil,
				trasClic = function(d, boton)
					if boton == "RightButton" then
						N.Set(ID, "ceboPreferido", d.id == pref and 0 or d.id)
						B.CerrarMenu()
					end
				end,
			}
		end
		local nota
		if activo then nota = format(L["Tu caña tiene cebo: %s más."], minutos(activo) or L["un momento"]) end
		if #filas == 0 then nota = L["No tienes cebos. Los venden los vendedores de suministros de pesca; la guía dice cuáles sirven a tu habilidad."] end
		return {
			titulo = L["Cebos"], nota = nota, filas = filas,
			pie = { { texto = L["Usar siempre el mejor"], activo = pref ~= 0, alClic = function() N.Set(ID, "ceboPreferido", 0) end } },
		}
	end,
	cocina = function()
		local filas = {}
		local fogata = M.Cocina and M.Cocina.NombreFogata()
		filas[#filas + 1] = {
			icono = M.ICONO.fogata, nombre = L["Encender una fogata"], valor = "",
			apagada = not (M.Cocina and M.Cocina.SabeFogata()), motivo = L["Aprende Cocina para encender fogatas."],
			seguro = fogata and { type = "spell", spell = fogata } or nil,
		}
		local recetas = M.Cocina and M.Cocina.Listas(5) or {}
		for _, r in ipairs(recetas) do
			filas[#filas + 1] = { icono = r.icono, nombre = r.nombre, valor = format(L["alcanza para %d"], r.alcanza),
				alClic = function() M.Cocina.Encolar(r, r.alcanza) abrirVentana("cocina") B.CerrarMenu() end,
				ayuda = L["Clic: a la cola de cocina."] }
		end
		return {
			titulo = L["Cocina junto al agua"],
			nota = #recetas == 0 and L["Cuando tengas pescado que sepas cocinar, aparece aquí."] or nil,
			filas = filas,
			pie = { { texto = L["Abrir la cocina"], alClic = function() abrirVentana("cocina") end } },
		}
	end,
	juguetes = function()
		local filas = {}
		for _, j in ipairs(Eq.Juguetes()) do
			local espera = minutos(j.espera)
			filas[#filas + 1] = { icono = j.icono, nombre = j.nombre, valor = espera or format(L["×%d"], j.cuenta),
				apagada = j.cuenta <= 0, seguro = { type = "item", item = "item:" .. j.id } }
		end
		return {
			titulo = L["Juguetes y consumibles de pesca"],
			nota = #filas == 0 and L["No llevas juguetes ni consumibles de pesca. Lo que tenga que ver con pescar aparece aquí solo."] or nil,
			filas = filas,
		}
	end,
}

---------------------------------------------------------------------------
-- El aviso de lo que sacaste
---------------------------------------------------------------------------
local MAX_ICONOS = 4

local function crearToast()
	local f = CreateFrame("Frame", "AlfaPescaCaptura", K.Raiz())
	f:SetFrameStrata("MEDIUM")
	f:SetSize(300, 64)
	f.caja = K.Caja(f, { fondo = "panel", borde = "lineaFuerte", corte = K.CORTE.control, rol = "panel" })
	f.Franja = K.Plano(f, "acento", "ARTWORK", 1)
	f.Franja:SetWidth(3)
	f.Franja:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -8)
	f.Franja:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 8)
	K.SoloCasa(f.Franja)
	f.iconos = {}
	for i = 1, MAX_ICONOS do
		local ic = K.IconoObjeto(f, 30)
		ic:SetPoint("TOPLEFT", f, "TOPLEFT", ESP.m + (i - 1) * 34, -ESP.m + 2)
		f.iconos[i] = ic
	end
	f.Titulo = K.Texto(f, "cuerpo", "texto")
	f.Texto = K.Texto(f, "pequeno", "acento")
	local ag = f:CreateAnimationGroup()
	local a = ag:CreateAnimation("Alpha")
	a:SetFromAlpha(1)
	a:SetToAlpha(0)
	a:SetDuration(0.6)
	a:SetStartDelay(3.6)
	ag:SetScript("OnFinished", function() f:Hide() end)
	f.salida = ag
	f:Hide()
	M.VISIBLES[#M.VISIBLES + 1] = f
	return f
end

-- tomados: lo que sacaste; nuevo: lo que dijo el registro (primera vez, maestría).
function M.MostrarCaptura(tomados, nuevo)
	if not opt("resumen") then return end
	toast = toast or crearToast()
	local n = min(#tomados, MAX_ICONOS)
	for i = 1, MAX_ICONOS do
		local o = tomados[i]
		local ic = toast.iconos[i]
		if o and i <= n then
			ic:SetObjeto({ id = o.id, icono = o.icono, calidad = o.calidad, cantidad = o.cantidad })
			ic:Show()
		else
			ic:Hide()
		end
	end
	local x = ESP.m + n * 34 + ESP.s
	local o = tomados[1]
	K.Escribir(toast.Titulo, format(L["%s ×%d"], o.nombre or "?", o.cantidad or 1))
	toast.Titulo:ClearAllPoints()
	toast.Titulo:SetPoint("TOPLEFT", toast, "TOPLEFT", x, -ESP.m - 1)
	local extra
	for _, x2 in ipairs(nuevo or {}) do
		if x2.nivel then
			local _, nombre = M.Maestria(x2.total)
			extra = format(L["Maestría nueva: %s (%d)"], nombre or "", x2.total or 0)
		elseif x2.primera and not extra then
			extra = L["¡Primera vez! Nuevo en tu diario"]
		end
	end
	if not extra and #tomados > 1 then
		local otros = {}
		for i = 2, #tomados do otros[#otros + 1] = format(L["%s ×%d"], tomados[i].nombre or "?", tomados[i].cantidad or 1) end
		extra = table.concat(otros, " \194\183 ")
	end
	if not extra then
		local e = M.Diario()[o.id or o.nombre or "?"]
		local _, _, sig = M.Maestria(e and e.n or 0)
		if e and sig then extra = format(L["%d de %d para la siguiente maestría"], e.n, sig) end
	end
	K.Escribir(toast.Texto, extra or "")
	toast.Texto:ClearAllPoints()
	toast.Texto:SetPoint("TOPLEFT", toast.Titulo, "BOTTOMLEFT", 0, -4)
	local ancho = max(240, x + max(K.Ajustar(toast.Titulo, 260), K.Ajustar(toast.Texto, 260)) + ESP.m)
	toast:SetSize(ancho, 54)
	toast:ClearAllPoints()
	local ancla = (barra and barra:IsShown() and barra) or (canal and canal:IsShown() and canal)
	if ancla then
		local _, y = ancla:GetCenter()
		local h = K.num(UIParent:GetHeight(), 1080)
		if K.num(y, 0) < h * 0.6 then
			toast:SetPoint("BOTTOM", ancla, "TOP", 0, ESP.s)
		else
			toast:SetPoint("TOP", ancla, "BOTTOM", 0, -ESP.s)
		end
		toast:SetScale(ancla:GetScale())
	else
		toast:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 300)
	end
	toast.salida:Stop()
	toast:SetAlpha(1)
	toast:Show()
	toast.salida:Play()
end

---------------------------------------------------------------------------
-- Avisos de logros y metas (uno por vez, con el aviso del Kit)
---------------------------------------------------------------------------
function M.AnunciarLogros(nuevos)
	if #nuevos == 0 then return end
	local titulo, texto
	if #nuevos == 1 then
		titulo = format(L["Logro de pesca: %s"], nuevos[1].nombre)
		texto = nuevos[1].texto
	else
		titulo = format(L["%d logros de pesca nuevos"], #nuevos)
		local nombres = {}
		for _, lg in ipairs(nuevos) do nombres[#nombres + 1] = lg.nombre end
		texto = table.concat(nombres, " · ")
	end
	K.Aviso({ lobo = "aullando", titulo = titulo, texto = texto, tono = "acento", duracion = 6,
		accion = { texto = L["Ver logros"], alClic = function() abrirVentana("logros") end } })
	if opt("alertas") and PlaySound then pcall(PlaySound, M.SONIDO_LOGRO, "Master") end
end

function M.AnunciarMetas(cumplidas)
	if #cumplidas == 0 then return end
	local texto = M.TextoMeta and M.TextoMeta(cumplidas[1]) or ""
	if #cumplidas > 1 then texto = format(L["%s y %d más"], texto, #cumplidas - 1) end
	K.Aviso({ icono = M.ICONO.meta, titulo = L["Meta cumplida"], texto = texto, tono = "exito", duracion = 5 })
	M.Alerta("meta", M.SONIDO_LOGRO)
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------
M.Escuchar(function(m)
	if m.modo or m.canal or m.todo or m.ajustes then B.Actualizar() end
	if barra and barra:IsShown() then B.Refrescar() end
	if canal and canal:IsShown() then K.Escribir(canal.Recap, recap()) end
	if m.modo and not E.modo then
		B.CerrarMenu()
		if toast then toast:Hide() end
	end
end)

-- Antes de que empiece el combate (todavía se puede): fuera el botón seguro y los menús.
A.RegisterEvent("PLAYER_REGEN_DISABLED", function()
	seguro:Hide()
	seguro:ClearAllPoints()
	seguro.dueno = nil
	B.CerrarMenu()
end)
