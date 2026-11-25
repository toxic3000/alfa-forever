-- Alfa - Bienvenida: «Editar escritorio» (1.3.8). toxic3000 / La Jauría. GPL-3.0.
--
-- Con el editor abierto, la rejilla de 24 x 16 se ve sobre el escritorio y
-- cada panel trae un marco del acento: se arrastra para moverlo y su esquina
-- de abajo a la derecha le cambia el tamaño; al soltar, se pega a la rejilla
-- (el imán). Una sombra enseña dónde va a quedar (en amarillo si se encima con
-- otro). Arriba, en lugar de la barra: «Agregar un panel» (el catálogo, con
-- su miniatura y una línea de cada uno), «Deshacer», «Como venía», «Guardar
-- como…» y «Listo». Fuera del editor los paneles no se mueven; una pelea o
-- Esc lo cierran (en combate no se acomoda nada).
--
--   M.EscritorioEditor.Abrir(conCatalogo) / Cerrar() / Alternar() / Activo()
--   .Arrastrar(id, dx, dy) / .CambiarTamano(id, dw, dh)   (en píxeles; el banco)
--   .Deshacer() / .PuedeDeshacer() / .Catalogo(on) / .GuardarComo(nombre)

local _, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ESP = K.ESP
local Es = M.Escritorio

local type, pairs, ipairs, tonumber, pcall = type, pairs, ipairs, tonumber, pcall
local floor, max, min, abs = math.floor, math.max, math.min, math.abs
local format, tinsert, tremove = string.format, table.insert, table.remove

local Ed = {}
M.EscritorioEditor = Ed

local activo = false
local pila = {}        -- deshacer: copias de los paneles de antes de cada cambio
local MAX_PILA = 30
local rejilla, barra, catalogo, sombra
local asas = {}        -- id -> el marco de edición de cada panel
local arrastre         -- { id, modo = "mover" | "tamano", x0, y0, celda }

local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end
local function desk() return Es.Marco() end
function Ed.Activo() return activo end

---------------------------------------------------------------------------
-- Deshacer
---------------------------------------------------------------------------
function Ed.AntesDeCambiar()
	if not activo then return end
	tinsert(pila, Es.Copiar(Es.Paneles()))
	while #pila > MAX_PILA do tremove(pila, 1) end
end
function Ed.PuedeDeshacer() return #pila > 0 end
function Ed.Deshacer()
	local antes = tremove(pila)
	if not antes then return false end
	Es.PonerPaneles(antes)
	Ed.PintarBarra()
	return true
end

---------------------------------------------------------------------------
-- La celda de un panel y sus choques
---------------------------------------------------------------------------
local function celdaDe(id)
	for _, x in ipairs(Es.Paneles()) do if x.id == id then return x end end
	return nil
end
Ed.CeldaDe = celdaDe

local function choca(c, sin)
	for _, x in ipairs(Es.Paneles()) do
		if x.id ~= sin and c.x < x.x + x.w and x.x < c.x + c.w and c.y < x.y + x.h and x.y < c.y + c.h then return x end
	end
	return nil
end
Ed.Choca = choca

local function minimo(id)
	local def = Es.TIPOS[id]
	local m = def and def.min
	return (m and m[1]) or 3, (m and m[2]) or 3
end

-- La celda que queda tras mover (dx, dy) o cambiar el tamaño (dw, dh) en
-- píxeles: pegada a la rejilla y dentro del escritorio.
local function celdaNueva(c, modo, dx, dy)
	local cw, ch = Es.Celda()
	if cw <= 0 or ch <= 0 then return c end
	local n = { id = c.id, x = c.x, y = c.y, w = c.w, h = c.h }
	if modo == "mover" then
		n.x = max(0, min(Es.COLUMNAS - c.w, floor(c.x + dx / cw + 0.5)))
		n.y = max(0, min(Es.FILAS - c.h, floor(c.y + dy / ch + 0.5)))
	else
		local mw, mh = minimo(c.id)
		n.w = max(mw, min(Es.COLUMNAS - c.x, floor(c.w + dx / cw + 0.5)))
		n.h = max(mh, min(Es.FILAS - c.y, floor(c.h + dy / ch + 0.5)))
	end
	return n
end
Ed.CeldaNueva = celdaNueva

local function aplicar(id, n)
	local c = celdaDe(id)
	if not c or (c.x == n.x and c.y == n.y and c.w == n.w and c.h == n.h) then return false end
	Ed.AntesDeCambiar()
	c.x, c.y, c.w, c.h = n.x, n.y, n.w, n.h
	Es.Guardar()
	Es.Acomodar()
	Ed.PintarBarra()
	return true
end

-- dx a la derecha, dy hacia abajo (píxeles del escritorio).
function Ed.Arrastrar(id, dx, dy)
	local c = celdaDe(id)
	if not c then return false end
	return aplicar(id, celdaNueva(c, "mover", dx or 0, dy or 0))
end
function Ed.CambiarTamano(id, dw, dh)
	local c = celdaDe(id)
	if not c then return false end
	return aplicar(id, celdaNueva(c, "tamano", dw or 0, dh or 0))
end

---------------------------------------------------------------------------
-- Arrastrar con el ratón
---------------------------------------------------------------------------
local function cursor()
	local x, y = GetCursorPosition()
	-- 1.4.0: las celdas están en las unidades del área (pantallas.tamano la agranda).
	local d = desk()
	local s = d and (d.Area or d):GetEffectiveScale() or 1
	return (tonumber(x) or 0) / s, (tonumber(y) or 0) / s
end

local function ponerSombra(n, choque)
	local d = desk()
	if not (d and sombra) then return end
	local cw, ch = Es.Celda()
	local g = Es.GAP
	sombra:ClearAllPoints()
	sombra:SetPoint("TOPLEFT", d.Area, "TOPLEFT", n.x * cw + g / 2, -(n.y * ch + g / 2))
	sombra:SetSize(max(10, n.w * cw - g), max(10, n.h * ch - g))
	local tono = choque and "aviso" or (K.Clasico() and "oro" or "acento")
	local r, gg, b = K.Color(tono)
	sombra.Fondo:SetColorTexture(r, gg, b, 0.12)
	for _, t in ipairs(sombra.Bordes) do t:SetColorTexture(r, gg, b, 0.9) end
	K.Escribir(sombra.Medida, format("%d × %d", n.w, n.h))
	sombra:Show()
end

local function enMovimiento(self)
	if not arrastre then self:SetScript("OnUpdate", nil) return end
	local x, y = cursor()
	local dx, dy = x - arrastre.x0, arrastre.y0 - y
	local p = Es.Marcos[arrastre.id]
	local c = arrastre.celda
	local cw, ch = Es.Celda()
	local g = Es.GAP
	if p and cw > 0 then
		-- El panel sigue al ratón suave; la sombra enseña la celda (el imán).
		if arrastre.modo == "mover" then
			p:ClearAllPoints()
			p:SetPoint("TOPLEFT", desk().Area, "TOPLEFT", c.x * cw + g / 2 + dx, -(c.y * ch + g / 2 + dy))
		else
			p:SetSize(max(60, c.w * cw - g + dx), max(60, c.h * ch - g + dy))
		end
	end
	local n = celdaNueva(c, arrastre.modo, dx, dy)
	arrastre.n = n
	ponerSombra(n, choca(n, arrastre.id))
end

local function empezar(id, modo)
	if enCombate() then return end
	local c = celdaDe(id)
	if not c then return end
	local x, y = cursor()
	arrastre = { id = id, modo = modo, x0 = x, y0 = y, celda = { id = c.id, x = c.x, y = c.y, w = c.w, h = c.h } }
	local a = asas[id]
	-- El que mueves va encima de los demás mientras lo arrastras.
	local base = desk().Area:GetFrameLevel()
	local p = Es.Marcos[id]
	if p then p:SetFrameLevel(base + 34) end
	if a then
		a:SetFrameLevel(base + 38)
		a:SetScript("OnUpdate", enMovimiento)
	end
end

local function soltar()
	local a = arrastre
	arrastre = nil
	if sombra then sombra:Hide() end
	if not a then return end
	local asa = asas[a.id]
	local base = desk() and desk().Area:GetFrameLevel() or 0
	if asa then
		asa:SetScript("OnUpdate", nil)
		asa:SetFrameLevel(base + 30)
	end
	local p = Es.Marcos[a.id]
	if p then p:SetFrameLevel(base + 2) end
	if a.n then aplicar(a.id, a.n) end
	Es.Acomodar()
end
Ed.Soltar = soltar

---------------------------------------------------------------------------
-- Lo que se ve
---------------------------------------------------------------------------
local function bordes(f, grueso)
	f.Bordes = {}
	for i, lado in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
		{ "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
		local t = f:CreateTexture(nil, "BORDER")
		t:SetPoint(lado[1], f, lado[1], 0, 0)
		t:SetPoint(lado[2], f, lado[2], 0, 0)
		if lado[3] then t:SetHeight(grueso) else t:SetWidth(grueso) end
		f.Bordes[i] = t
	end
end

local function pintarAsa(a)
	local r, g, b = K.Color(K.Clasico() and "oro" or "acento")
	a.Fondo:SetColorTexture(r, g, b, a.sobre and 0.12 or 0.03) -- 1.4.0: menos tinte verde encima de tus paneles
	for _, t in ipairs(a.Bordes) do t:SetColorTexture(r, g, b, a.sobre and 1 or 0.7) end
	a.Grip:SetVertexColor(r, g, b, 1)
end

local function crearAsa(id)
	local def = Es.TIPOS[id]
	local a = CreateFrame("Button", nil, desk().Area)
	a:SetFrameLevel(desk().Area:GetFrameLevel() + 30)
	a:RegisterForClicks("RightButtonUp")
	a.Fondo = a:CreateTexture(nil, "BACKGROUND")
	a.Fondo:SetAllPoints(a)
	bordes(a, 2)
	-- La etiqueta en el centro: el nombre y su medida.
	a.Etiqueta = CreateFrame("Frame", nil, a)
	a.Etiqueta.caja = K.Caja(a.Etiqueta, { fondo = "fondo", borde = "acento", corte = K.CORTE.chico })
	a.Etiqueta:SetPoint("CENTER", a, "CENTER", 0, 0)
	a.Icono = K.Icono(a.Etiqueta, def and def.icono or "ic-lobo", 16, "acento")
	a.Icono:SetPoint("LEFT", a.Etiqueta, "LEFT", ESP.s, 0)
	a.Nombre = K.Texto(a.Etiqueta, "encabezado", "texto")
	a.Nombre:SetPoint("LEFT", a.Icono, "RIGHT", ESP.s, 0)
	a.Medida = K.Texto(a.Etiqueta, "pequeno", "textoTenue")
	a.Medida:SetPoint("LEFT", a.Nombre, "RIGHT", ESP.s, 0)
	a.Quitar = K.BotonIcono(a, "ic-cerrar", function() Es.QuitarPanel(id) end, { tam = 24, icono = 10, ayuda = L["Quitar del escritorio"] })
	a.Quitar:SetPoint("TOPRIGHT", a, "TOPRIGHT", -ESP.s, -5)
	a.Grip = a:CreateTexture(nil, "OVERLAY")
	a.Grip:SetTexture(K.Ruta("resize"))
	a.Grip:SetSize(16, 16)
	a.Grip:SetPoint("BOTTOMRIGHT", a, "BOTTOMRIGHT", -3, 3)
	a.Esquina = CreateFrame("Button", nil, a)
	a.Esquina:SetSize(26, 26)
	a.Esquina:SetPoint("BOTTOMRIGHT", a, "BOTTOMRIGHT", 0, 0)
	a.Esquina:SetScript("OnMouseDown", function(_, b) if b == "LeftButton" then empezar(id, "tamano") end end)
	a.Esquina:SetScript("OnMouseUp", function(_, b) if b == "LeftButton" then soltar() end end)
	a.Esquina:SetScript("OnEnter", function() K.MostrarInfo(a.Esquina, L["Cambiar el tamaño"], L["Arrastra la esquina: se pega a la rejilla al soltar."]) end)
	a.Esquina:SetScript("OnLeave", function() K.OcultarInfo(a.Esquina) end)
	a:SetScript("OnMouseDown", function(_, b) if b == "LeftButton" then empezar(id, "mover") end end)
	a:SetScript("OnMouseUp", function(_, b) if b == "LeftButton" then soltar() end end)
	a:SetScript("OnClick", function(_, b) if b == "RightButton" then Es.QuitarPanel(id) end end)
	a:SetScript("OnEnter", function(self)
		self.sobre = true
		pintarAsa(self)
		K.MostrarInfo(self, def and L[def.titulo] or id, L["Arrástralo para moverlo. Clic derecho: lo quitas."])
	end)
	a:SetScript("OnLeave", function(self)
		self.sobre = nil
		pintarAsa(self)
		K.OcultarInfo(self)
	end)
	a:SetScript("OnHide", function() if arrastre and arrastre.id == id then soltar() end end)
	K.Pintar(a, pintarAsa)
	return a
end

local function crearRejilla()
	local d = desk()
	rejilla = CreateFrame("Frame", nil, d.Area)
	rejilla:SetAllPoints(d.Area)
	rejilla:SetFrameLevel(d.Area:GetFrameLevel() + 1)
	rejilla.lineas = {}
	for i = 1, Es.COLUMNAS - 1 do
		local t = rejilla:CreateTexture(nil, "BACKGROUND")
		t:SetWidth(1)
		rejilla.lineas[#rejilla.lineas + 1] = { t, "v", i }
	end
	for j = 1, Es.FILAS - 1 do
		local t = rejilla:CreateTexture(nil, "BACKGROUND")
		t:SetHeight(1)
		rejilla.lineas[#rejilla.lineas + 1] = { t, "h", j }
	end
	K.Pintar(rejilla, function(x)
		local r, g, b = K.Color(K.Clasico() and "oro" or "acento")
		for _, l in ipairs(x.lineas) do l[1]:SetColorTexture(r, g, b, 0.10) end
	end)
	sombra = CreateFrame("Frame", nil, d.Area)
	sombra:SetFrameLevel(d.Area:GetFrameLevel() + 40)
	sombra.Fondo = sombra:CreateTexture(nil, "BACKGROUND")
	sombra.Fondo:SetAllPoints(sombra)
	bordes(sombra, 2)
	sombra.Medida = K.Texto(sombra, "numero", "texto")
	sombra.Medida:SetPoint("BOTTOMLEFT", sombra, "BOTTOMLEFT", ESP.s, ESP.s)
	sombra:Hide()
end

local function acomodarRejilla()
	if not rejilla then return end
	local cw, ch = Es.Celda()
	for _, l in ipairs(rejilla.lineas) do
		local t = l[1]
		t:ClearAllPoints()
		if l[2] == "v" then
			t:SetPoint("TOPLEFT", rejilla, "TOPLEFT", floor(l[3] * cw), 0)
			t:SetPoint("BOTTOMLEFT", rejilla, "BOTTOMLEFT", floor(l[3] * cw), 0)
		else
			t:SetPoint("TOPLEFT", rejilla, "TOPLEFT", 0, -floor(l[3] * ch))
			t:SetPoint("TOPRIGHT", rejilla, "TOPRIGHT", 0, -floor(l[3] * ch))
		end
	end
end

-- Cada panel con su marco de edición (o sin él, fuera del editor).
function Ed.Repintar()
	if not activo then
		for _, a in pairs(asas) do a:Hide() end
		return
	end
	acomodarRejilla()
	local hay = {}
	for _, x in ipairs(Es.Paneles()) do
		local p = Es.Marcos[x.id]
		if p and p:IsShown() then
			local a = asas[x.id] or crearAsa(x.id)
			asas[x.id] = a
			hay[x.id] = true
			a:ClearAllPoints()
			a:SetAllPoints(p)
			-- Mientras editas, el × y el menú de la cabecera son los del marco de edición.
			p.Cab.Menu:Hide()
			p.Cab.Cerrar:Hide()
			local def = Es.TIPOS[x.id]
			K.Escribir(a.Nombre, def and L[def.titulo] or x.id)
			K.Escribir(a.Medida, format("%d × %d", x.w, x.h))
			a.Etiqueta:SetSize(ESP.s + 16 + ESP.s + K.AnchoTexto(a.Nombre) + ESP.s + K.AnchoTexto(a.Medida) + ESP.m, 30)
			a:Show()
		end
	end
	for id, a in pairs(asas) do if not hay[id] then a:Hide() end end
	if catalogo and catalogo:IsShown() then Ed.PintarCatalogo() end
end

---------------------------------------------------------------------------
-- La barra del editor (encima de la del escritorio)
---------------------------------------------------------------------------
local function crearBarra()
	local d = desk()
	barra = CreateFrame("Frame", nil, d.Barra)
	barra:SetAllPoints(d.Barra)
	barra:SetFrameLevel(d.Barra:GetFrameLevel() + 20)
	barra:EnableMouse(true)
	barra.Fondo = K.Plano(barra, "elevado", "BACKGROUND", 1)
	barra.Fondo:SetAllPoints(barra)
	barra.Raya = K.Plano(barra, "acento", "ARTWORK", 1)
	barra.Raya:SetPoint("BOTTOMLEFT", barra, "BOTTOMLEFT", 0, 0)
	barra.Raya:SetPoint("BOTTOMRIGHT", barra, "BOTTOMRIGHT", 0, 0)
	barra.Raya:SetHeight(2)
	barra.Icono = K.Icono(barra, "ic-ajustes", 20, "acento")
	barra.Icono:SetPoint("LEFT", barra, "LEFT", ESP.base, 0)
	barra.Titulo = K.Texto(barra, "subtitulo", "texto")
	barra.Titulo:SetPoint("TOPLEFT", barra.Icono, "TOPRIGHT", ESP.m, 4)
	K.Escribir(barra.Titulo, L["Editando tu escritorio"])
	barra.Sub = K.Texto(barra, "pequeno", "textoTenue")
	barra.Sub:SetPoint("TOPLEFT", barra.Titulo, "BOTTOMLEFT", 0, -2)
	K.Escribir(barra.Sub, L["Arrastra los paneles y su esquina; se pegan a la rejilla."])
	barra.Listo = K.Boton(barra, L["Listo"], function() Ed.Cerrar() end, { tipo = "primario", icono = "ic-exito" })
	barra.Listo:SetPoint("RIGHT", barra, "RIGHT", -ESP.m, 0)
	barra.Guardar = K.Boton(barra, L["Guardar como…"], function() Ed.PedirNombre() end, { tipo = "secundario" })
	barra.Guardar:SetPoint("RIGHT", barra.Listo, "LEFT", -ESP.s, 0)
	barra.Restablecer = K.Boton(barra, L["Como venía"], function()
		Ed.AntesDeCambiar()
		if not Es.Restablecer() then tremove(pila) end
		Ed.PintarBarra()
	end, { tipo = "secundario", ayuda = L["Esta distribución con los paneles de fábrica."] })
	barra.Restablecer:SetPoint("RIGHT", barra.Guardar, "LEFT", -ESP.s, 0)
	barra.Deshacer = K.Boton(barra, L["Deshacer"], function() Ed.Deshacer() end, { tipo = "secundario", icono = "reset" })
	barra.Deshacer:SetPoint("RIGHT", barra.Restablecer, "LEFT", -ESP.s, 0)
	barra.Agregar = K.Boton(barra, L["Agregar un panel"], function() Ed.Catalogo(not (catalogo and catalogo:IsShown())) end,
		{ tipo = "secundario", icono = "ic-mas" })
	barra.Agregar:SetPoint("RIGHT", barra.Deshacer, "LEFT", -ESP.s, 0)
	-- «Guardar como…»: el nombre, en la misma barra.
	barra.Nombre = K.Buscador(barra, { ayuda = L["Nombre de tu escritorio"], alEnter = function(t) Ed.GuardarComo(t) end })
	barra.Nombre:SetWidth(240)
	barra.Nombre:SetPoint("RIGHT", barra.Listo, "LEFT", -ESP.s - 92, 0)
	K.SetIcono(barra.Nombre.Lupa, "ic-lobo", "textoTenue")
	barra.Nombre:Hide()
	barra.Ok = K.Boton(barra, L["Guardar"], function() Ed.GuardarComo(barra.Nombre:Texto()) end, { tipo = "primario", ancho = 84 })
	barra.Ok:SetPoint("LEFT", barra.Nombre, "RIGHT", ESP.s, 0)
	barra.Ok:Hide()
	barra:Hide()
end

function Ed.PintarBarra()
	if not barra then return end
	-- En un escritorio angosto, los botones primero (el título se va).
	local angosta = K.num(barra:GetWidth(), 0) < 1100
	barra.Titulo:SetShown(not angosta)
	barra.Sub:SetShown(not angosta)
	barra.Deshacer:SetActivo(#pila > 0)
	local actual = Es.Actual()
	local deAlfa = false
	for _, d in ipairs(Es.DISTRIBUCIONES) do if d.id == actual then deAlfa = true end end
	barra.Restablecer:SetShown(deAlfa)
	barra.Restablecer:SetActivo(deAlfa and Es.Cambiada(actual))
	local pidiendo = barra.Nombre:IsShown()
	for _, b in ipairs({ barra.Agregar, barra.Deshacer, barra.Guardar }) do b:SetShown(not pidiendo) end
	if pidiendo then barra.Restablecer:Hide() end
	barra.Ok:SetShown(pidiendo)
end

function Ed.PedirNombre()
	if not barra then return end
	barra.Nombre:Show()
	barra.Nombre:SetTexto("", true)
	barra.Nombre:Foco()
	Ed.PintarBarra()
end

function Ed.GuardarComo(nombre)
	local id = Es.GuardarComo(nombre)
	if barra then
		barra.Nombre:Hide()
		barra.Nombre.Campo:ClearFocus()
	end
	Ed.PintarBarra()
	Es.PintarBarra()
	return id
end

---------------------------------------------------------------------------
-- El catálogo: cada panel con su miniatura y una línea
---------------------------------------------------------------------------
-- La miniatura dibuja la forma del panel: líneas, cifras, barras, un mapa,
-- una flecha o un globo de texto.
local function miniatura(m, forma)
	m.piezas = m.piezas or {}
	for _, t in ipairs(m.piezas) do t:Hide() end
	local i = 0
	local function pieza(x, y, w, h, color, a)
		i = i + 1
		local t = m.piezas[i] or m:CreateTexture(nil, "ARTWORK")
		m.piezas[i] = t
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", m, "TOPLEFT", x, -y)
		t:SetSize(w, h)
		local r, g, b = K.Color(color)
		t:SetColorTexture(r, g, b, a or 1)
		t:Show()
		return t
	end
	pieza(0, 0, 72, 8, "elevado")
	pieza(4, 3, 10, 2, "acento")
	if forma == "barras" then
		for k, f in ipairs({ 1, 0.8, 0.62, 0.45 }) do pieza(4, 12 + (k - 1) * 9, 64 * f, 6, "acento", 0.55 - k * 0.08) end
	elseif forma == "cifras" then
		for k = 0, 3 do
			local x, y = 4 + (k % 2) * 33, 12 + floor(k / 2) * 18
			pieza(x, y, 30, 15, "hundido")
			pieza(x + 3, y + 7, 16, 4, "texto", 0.8)
		end
	elseif forma == "mapa" then
		pieza(4, 12, 64, 34, "hundido")
		pieza(14, 20, 18, 12, "linea")
		pieza(38, 26, 22, 14, "linea")
		pieza(32, 24, 5, 5, "acento")
	elseif forma == "flecha" then
		pieza(8, 14, 26, 26, "hundido")
		pieza(17, 18, 8, 18, "acento")
		pieza(40, 18, 26, 6, "texto", 0.8)
		pieza(40, 28, 20, 4, "textoTenue")
	elseif forma == "texto" then
		pieza(4, 12, 10, 10, "acento", 0.8)
		pieza(18, 12, 50, 22, "elevado")
		pieza(22, 16, 40, 3, "texto", 0.7)
		pieza(22, 22, 32, 3, "texto", 0.7)
	else
		for k = 0, 3 do
			pieza(4, 13 + k * 9, 5, 5, "acento", 0.8)
			pieza(13, 14 + k * 9, 52 - (k % 2) * 14, 3, "texto", 0.7)
		end
	end
end
Ed.Miniatura = miniatura

local function crearCatalogo()
	local d = desk()
	catalogo = CreateFrame("Frame", "AlfaEscritorioCatalogo", d.Area)
	catalogo:SetFrameLevel(d.Area:GetFrameLevel() + 60)
	catalogo:SetPoint("TOPRIGHT", d.Area, "TOPRIGHT", -ESP.s, -ESP.s)
	catalogo:SetPoint("BOTTOMRIGHT", d.Area, "BOTTOMRIGHT", -ESP.s, ESP.s)
	catalogo:SetWidth(360)
	catalogo:EnableMouse(true)
	catalogo.caja = K.Caja(catalogo, { fondo = "fondo", borde = "lineaFuerte", corte = K.CORTE.panel })
	catalogo.Marca = K.Marca(catalogo, K.CORTE.panel, "acento")
	catalogo.Icono = K.Icono(catalogo, "ic-mas", 18, "acento")
	catalogo.Icono:SetPoint("TOPLEFT", catalogo, "TOPLEFT", ESP.base, -ESP.base)
	catalogo.Titulo = K.Texto(catalogo, "subtitulo", "texto")
	catalogo.Titulo:SetPoint("LEFT", catalogo.Icono, "RIGHT", ESP.s, 0)
	K.Escribir(catalogo.Titulo, L["Agregar un panel"])
	catalogo.Cerrar = K.BotonIcono(catalogo, "ic-cerrar", function() Ed.Catalogo(false) end, { tam = 26, icono = 11, ayuda = L["Cerrar"] })
	catalogo.Cerrar:SetPoint("TOPRIGHT", catalogo, "TOPRIGHT", -ESP.s, -ESP.s)
	catalogo.Lista = K.Desplazable(catalogo)
	catalogo.Lista:SetPoint("TOPLEFT", catalogo, "TOPLEFT", ESP.base, -52)
	catalogo.Lista:SetPoint("BOTTOMRIGHT", catalogo, "BOTTOMRIGHT", -ESP.s, ESP.base)
	catalogo.items = {}
	catalogo:Hide()
end

local function itemCatalogo(i)
	local it = catalogo.items[i]
	if it then return it end
	local c = catalogo.Lista.Contenido
	it = CreateFrame("Frame", nil, c)
	it.caja = K.Caja(it, { fondo = "panel", borde = "linea", corte = K.CORTE.tarjeta })
	it.Mini = CreateFrame("Frame", nil, it)
	it.Mini:SetSize(72, 48)
	it.Mini:SetPoint("TOPLEFT", it, "TOPLEFT", ESP.s, -ESP.s)
	it.Mini.caja = K.Caja(it.Mini, { fondo = "fondo", borde = "linea", corte = K.CORTE.chico })
	it.Icono = K.Icono(it, "ic-lobo", 14, "acento")
	it.Icono:SetPoint("TOPLEFT", it.Mini, "TOPRIGHT", ESP.m, -1)
	it.Titulo = K.Texto(it, "cuerpo", "texto")
	it.Titulo:SetPoint("LEFT", it.Icono, "RIGHT", 6, 0)
	it.Texto = K.Texto(it, "nota", "textoSuave")
	it.Texto:SetJustifyH("LEFT")
	it.Boton = K.Boton(it, L["Agregar"], nil, { tipo = "secundario", tam = "chico", icono = "ic-mas" })
	it.Ya = K.Insignia(it, L["Ya está"], "exito")
	catalogo.items[i] = it
	return it
end

function Ed.PintarCatalogo()
	if not catalogo then return end
	local lista = catalogo.Lista
	local ancho = max(200, K.num(catalogo:GetWidth(), 360) - ESP.base - ESP.s - 12)
	lista.Contenido:SetWidth(ancho)
	local y = 0
	for i, id in ipairs(Es.ORDEN) do
		local def = Es.TIPOS[id]
		local it = itemCatalogo(i)
		miniatura(it.Mini, def.forma)
		K.SetIcono(it.Icono, def.icono or "ic-lobo", "acento")
		K.Escribir(it.Titulo, L[def.titulo])
		local tx = ESP.s + 72 + ESP.m
		local tw = ancho - tx - ESP.s
		K.Escribir(it.Texto, L[def.texto or ""])
		it.Texto:ClearAllPoints()
		it.Texto:SetPoint("TOPLEFT", it, "TOPLEFT", tx, -(ESP.s + 20))
		local th = K.Parrafo(it.Texto, tw, 3)
		local ya = Es.TienePanel(id)
		it.Boton:SetShown(not ya)
		it.Ya:SetShown(ya)
		it.Boton.alClic = function()
			Ed.AntesDeCambiar()
			if not Es.AgregarPanel(id) then tremove(pila) end
			Ed.PintarBarra()
		end
		local yb = ESP.s + 20 + th + ESP.s
		it.Boton:ClearAllPoints()
		it.Boton:SetPoint("TOPLEFT", it, "TOPLEFT", tx, -yb)
		it.Ya:ClearAllPoints()
		it.Ya:SetPoint("TOPLEFT", it, "TOPLEFT", tx, -(yb + 2))
		local h = max(48 + ESP.s * 2, yb + K.ALTO.botonChico + ESP.s)
		it:ClearAllPoints()
		it:SetPoint("TOPLEFT", lista.Contenido, "TOPLEFT", 0, -y)
		it:SetSize(ancho, h)
		it:Show()
		y = y + h + ESP.s
	end
	for i = #Es.ORDEN + 1, #catalogo.items do catalogo.items[i]:Hide() end
	lista:SetAltoContenido(y)
end

function Ed.Catalogo(on)
	if not activo then return end
	if not catalogo then crearCatalogo() end
	catalogo:SetShown(on and true or false)
	if on then Ed.PintarCatalogo() end
end
function Ed.CatalogoVisible() return catalogo ~= nil and catalogo:IsShown() end

---------------------------------------------------------------------------
-- Entrar y salir
---------------------------------------------------------------------------
function Ed.Abrir(conCatalogo)
	local d = desk()
	if not (d and d:IsShown()) then
		N.Imprimir(L["Primero acomoda tus pantallas: /alfa pantallas."])
		return false
	end
	if enCombate() then
		N.Imprimir(L["El escritorio se edita fuera de combate."])
		return false
	end
	if not rejilla then crearRejilla() end
	if not barra then crearBarra() end
	activo = true
	wipe(pila)
	Es.SoltarMapa()
	rejilla:Show()
	barra:Show()
	barra.Nombre:Hide()
	Es.Acomodar()
	Ed.PintarBarra()
	-- Los paneles se pintan otra vez (el mapa espera afuera mientras editas).
	for _, p in pairs(Es.Marcos) do if p:IsShown() then Es.PintarPanel(p, true) end end
	if conCatalogo then Ed.Catalogo(true) end
	d:EnableKeyboard(true)
	d:SetScript("OnKeyDown", function(self, tecla)
		local esc = tecla == "ESCAPE"
		if self.SetPropagateKeyboardInput and not enCombate() then self:SetPropagateKeyboardInput(not esc) end
		if esc then Ed.Cerrar() end
	end)
	return true
end

function Ed.Cerrar()
	if not activo then return end
	soltar()
	activo = false
	if rejilla then rejilla:Hide() end
	if barra then barra:Hide() end
	if catalogo then catalogo:Hide() end
	if sombra then sombra:Hide() end
	for _, a in pairs(asas) do a:Hide() end
	for _, p in pairs(Es.Marcos) do p.Cab.Menu:Show() p.Cab.Cerrar:Show() end
	local d = desk()
	if d then
		d:SetScript("OnKeyDown", nil)
		if not enCombate() then d:EnableKeyboard(false) end
	end
	Es.Guardar()
	Es.Acomodar()
	for _, p in pairs(Es.Marcos) do if p:IsShown() then Es.PintarPanel(p, true) end end
end

function Ed.Alternar() if activo then Ed.Cerrar() else Ed.Abrir() end end
