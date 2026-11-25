-- Alfa - Bienvenida: la ventana de Alfa, más cómoda (1.3.7). toxic3000 / La
-- Jauría. GPL-3.0.
--
-- Lo que hace más fácil moverse por la ventana principal de Alfa
-- (motor/Alfa/UI/Options.lua), sin tocar cómo se arma cada página:
--   * atajos de teclado: Ctrl+1…9 cambia de sección, Ctrl+← / Ctrl+→ la
--     página de antes o la siguiente, Ctrl+F el buscador y Alt+← vuelve a la
--     página de antes. Cada botón de sección dice su atajo al pasar el ratón.
--     Solo con la ventana abierta y fuera de combate; cualquier otra tecla
--     sigue al juego (bienvenida.atajosVentana).
--   * «‹» volver: la página donde estabas antes (hasta 12 pasos), junto al
--     título; el historial empieza cada vez que abres la ventana.
--   * más alta: la esquina de abajo a la derecha la estira hacia abajo (el
--     ancho no cambia); doble clic la devuelve a su alto. Alfa recuerda el
--     alto y el lugar donde la dejaste (bienvenida.recordarVentana).
--   * el buscador: al entrar a la caja vacía, tus últimas búsquedas y unas
--     ideas para empezar; sin resultados, las páginas de Alfa a un clic.
--
--   M.Ventana.Secciones() -> { "hoy", "aventura", ..., "ajustes" }
--   M.Ventana.IrSeccion(n) ; .Paso(delta) ; .Atras() ; .Buscar()
--   M.Ventana.Historial() ; .Recientes() ; .Recordar(texto) ; .Restablecer()
--   M.Ventana.Tecla(tecla) (lo que hace una tecla: para el banco)

local _, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ESP = K.ESP

local type, ipairs, pairs, pcall, tonumber, tostring, rawget = type, ipairs, pairs, pcall, tonumber, tostring, rawget
local format, floor, max, min = string.format, math.floor, math.max, math.min
local tinsert, tremove = table.insert, table.remove

local Vt = {}
M.Ventana = Vt

local HISTORIAL_MAX = 12
local RECIENTES_MAX = 5
local ALTO_MIN = 600
-- Ideas para empezar a buscar (cada una encuentra algo en Alfa).
local IDEAS = { "Talentos", "Bolsas", "Flecha", "Atajos", "Letra", "Pesca" }

local function Op() return A.UI and A.UI.Options end
local function ventana() local O = Op() return O and O.frame end
local function datos() return N.Datos("bienvenida") end
local function prendido(clave)
	local v = A.Get and A.Get("bienvenida." .. clave)
	return v ~= false
end
local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end

---------------------------------------------------------------------------
-- Secciones y páginas, en el orden de la barra
---------------------------------------------------------------------------
function Vt.Secciones()
	local O = Op()
	local out = {}
	if not (O and O.PagesOf) then return out end
	for _, s in ipairs(O.SECCIONES or {}) do
		if #O.PagesOf(s.key) > 0 then out[#out + 1] = s.key end
	end
	if O.AJUSTES and #O.PagesOf(O.AJUSTES.key) > 0 then out[#out + 1] = O.AJUSTES.key end
	return out
end

function Vt.IrSeccion(n)
	local O, win = Op(), ventana()
	if not (win and win:IsShown()) then return false end
	local k = Vt.Secciones()[n]
	if not k then return false end
	O.SelectSection(k)
	return true
end

-- Todas las páginas de la barra, una tras otra (sección por sección).
local function paginas()
	local O = Op()
	local out = {}
	for _, k in ipairs(Vt.Secciones()) do
		for _, p in ipairs(O.PagesOf(k)) do out[#out + 1] = p end
	end
	return out
end

-- La página siguiente (delta 1) o la de antes (-1); al final, vuelve a empezar.
function Vt.Paso(delta)
	local O, win = Op(), ventana()
	if not (win and win:IsShown() and O.page) then return false end
	local lista = paginas()
	if #lista < 2 then return false end
	local at = 1
	for i, p in ipairs(lista) do if p.key == O.page.key then at = i end end
	local to = lista[(at - 1 + (delta or 1)) % #lista + 1]
	O.Select(to.key)
	return true
end

function Vt.Buscar()
	local win = ventana()
	if not (win and win:IsShown() and win.Search and win.Search.SetFocus) then return false end
	win.Search:SetFocus()
	return true
end

---------------------------------------------------------------------------
-- Volver: el historial de páginas de esta vez que abriste la ventana
---------------------------------------------------------------------------
local historial, volviendo, recienAbierta = {}, false, false
local pintarVolver -- (abajo)

function Vt.Historial() return historial end

function Vt.Atras()
	local O, win = Op(), ventana()
	if not (win and win:IsShown()) then return false end
	local key = tremove(historial)
	while key and O.page and key == O.page.key do key = tremove(historial) end
	if not key then
		if pintarVolver then pintarVolver() end
		return false
	end
	volviendo = true
	local ok = pcall(O.Select, key)
	volviendo = false
	if pintarVolver then pintarVolver() end
	return ok
end

local function nombrePagina(key)
	local O = Op()
	for _, p in ipairs(O.Pages and O.Pages() or {}) do
		if p.key == key then return O.PageLabel and O.PageLabel(p) or p.name end
	end
	return key
end

---------------------------------------------------------------------------
-- Búsquedas recientes (por cuenta)
---------------------------------------------------------------------------
function Vt.Recientes()
	local d = datos()
	if type(d.busquedas) ~= "table" then d.busquedas = {} end
	return d.busquedas
end

function Vt.Recordar(texto)
	if type(texto) ~= "string" then return false end
	texto = texto:gsub("^%s+", ""):gsub("%s+$", "")
	if #texto < 2 or #texto > 40 then return false end
	local l = Vt.Recientes()
	local baja = texto:lower()
	for i = #l, 1, -1 do
		if type(l[i]) ~= "string" or l[i]:lower() == baja then tremove(l, i) end
	end
	tinsert(l, 1, texto)
	while #l > RECIENTES_MAX do tremove(l) end
	return true
end

function Vt.OlvidarRecientes() datos().busquedas = {} end

-- ¿Lo buscado encontró algo? (lo último que pintó el buscador)
local function encontro()
	local O = Op()
	local r = O and O.results
	if type(r) ~= "table" then return false end
	if (r.count or 0) > 0 then return true end
	return O.SearchPages and #O.SearchPages() > 0 or false
end

---------------------------------------------------------------------------
-- Las pistas de los atajos en los botones de sección
---------------------------------------------------------------------------
local function pistasSecciones()
	local O, win = Op(), ventana()
	if not (win and win.sectionButtons) then return end
	local lista = Vt.Secciones()
	local idx = {}
	for i, k in ipairs(lista) do idx[k] = i end
	local con = prendido("atajosVentana")
	for _, b in ipairs(win.sectionButtons) do
		local i = b:IsShown() and idx[b.psKey]
		if i and i <= 9 and con and Vt.Libre("CTRL-" .. i) then
			if not b.psTip and b.Label then b.psTip = b.Label:GetText() end
			b.psTipLines = b.psTipLines or {}
			b.psTipLines[1] = format(L["Atajo: Ctrl+%d"], i)
			for j = #b.psTipLines, 2, -1 do b.psTipLines[j] = nil end
		else
			b.psTipLines = nil
		end
	end
end

---------------------------------------------------------------------------
-- El botón «‹» (volver)
---------------------------------------------------------------------------
local volver
local CORRE = 20 -- lo que se recorren el título y las pastillas cuando sale «‹»

local function buscando()
	local win = ventana()
	local t = win and win.Search and win.Search.GetText and win.Search:GetText()
	return type(t) == "string" and t ~= ""
end

pintarVolver = function()
	local win = ventana()
	if not (win and volver and win.PillRow and win.Nav) then return end
	local O = Op()
	local ultimo = historial[#historial]
	local hay = ultimo ~= nil and not buscando() and not (O.page and ultimo == O.page.key and #historial == 1)
	if hay then
		local texto = format(L["Volver a %s"], nombrePagina(ultimo))
		K.ConInfo(volver, texto, prendido("atajosVentana") and Vt.Libre("ALT-LEFT") and L["Atajo: Alt+←"] or nil)
	end
	if volver.alfaHay == hay then return end
	volver.alfaHay = hay
	volver:SetShown(hay)
	-- El título y las pastillas se corren (W.ShellPills / W.TopTitle leen psPillLeft);
	-- la fila y la página no se mueven.
	win.psPillLeft = hay and CORRE or nil
	if O.RefreshNav then pcall(O.RefreshNav) end
end

local function armarVolver(win)
	volver = K.BotonIcono(win.Main or win, "chevron-left", function() Vt.Atras() end, { tam = 24, icono = 14, tipo = "secundario" })
	local alto = (A.Widgets and A.Widgets.TOP and A.Widgets.TOP.pills) or 46
	if rawget(win, "PageHead") then
		-- 1.4.0 (82): con la barra lateral, junto al ícono de la cabecera de la página.
		local pad = (A.Widgets and A.Widgets.SHELL and A.Widgets.SHELL.pad) or 32
		volver:SetPoint("TOPLEFT", win.PageHead, "TOPLEFT", pad - 8, -24)
		volver:SetFrameLevel(win.PageHead:GetFrameLevel() + 5)
	else
		volver:SetPoint("TOPLEFT", win.Nav, "BOTTOMLEFT", 8, -floor((alto - 24) / 2))
		volver:SetFrameLevel(win.PillRow:GetFrameLevel() + 5)
	end
	volver:Hide()
	volver.alfaHay = false
	Vt.BotonVolver = volver
end

---------------------------------------------------------------------------
-- Alto y lugar de la ventana
---------------------------------------------------------------------------
local altoFabrica

local function topeAlto(win)
	local escala = (win.GetScale and win:GetScale()) or 1
	if type(escala) ~= "number" or escala <= 0 then escala = 1 end
	local pantalla = UIParent and UIParent.GetHeight and UIParent:GetHeight() or 768
	if type(pantalla) ~= "number" then pantalla = 768 end
	return max(altoFabrica or 700, floor(pantalla / escala - 20))
end

-- Vuelve a pintar la página a la vista con el alto nuevo (lo que se ve y el
-- desplazamiento), en la misma pestaña.
local function repintar()
	local O, win = Op(), ventana()
	if not (win and win:IsShown() and O.page) then return end
	if buscando() then
		if O.SetQuery then pcall(O.SetQuery, win.Search:GetText()) end
		return
	end
	local tab
	for nombre, v in pairs(O.page.views or {}) do if v == O.view then tab = nombre end end
	volviendo = true
	pcall(O.Select, O.page.key, tab)
	volviendo = false
end

local function guardarLugar()
	local win = ventana()
	if not (win and prendido("recordarVentana")) then return end
	local x, y = win:GetLeft(), win:GetTop()
	if type(x) ~= "number" or type(y) ~= "number" then return end
	local d = datos()
	d.ventana = type(d.ventana) == "table" and d.ventana or {}
	d.ventana.x, d.ventana.y = floor(x + 0.5), floor(y + 0.5)
end

local function guardarAlto()
	local win = ventana()
	if not (win and prendido("recordarVentana")) then return end
	local d = datos()
	d.ventana = type(d.ventana) == "table" and d.ventana or {}
	local h = floor(win:GetHeight() + 0.5)
	if altoFabrica and math.abs(h - altoFabrica) < 2 then d.ventana.h = nil else d.ventana.h = h end
end

function Vt.SetAlto(h, guardar)
	local win = ventana()
	if not win then return false end
	h = floor(min(max(ALTO_MIN, tonumber(h) or altoFabrica or 700), topeAlto(win)) + 0.5)
	win:SetHeight(h)
	if guardar then guardarAlto() end
	repintar()
	return true
end

-- La ventana en su alto y su lugar de siempre (y se olvida lo guardado).
function Vt.Restablecer()
	local win = ventana()
	datos().ventana = nil
	if not win then return end
	win:SetHeight(altoFabrica or 700)
	win:ClearAllPoints()
	win:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
	repintar()
end

local function restaurar(win)
	local d = prendido("recordarVentana") and datos().ventana
	if type(d) ~= "table" then return end
	if tonumber(d.h) then win:SetHeight(floor(min(max(ALTO_MIN, d.h), topeAlto(win)))) end
	if tonumber(d.x) and tonumber(d.y) then
		win:ClearAllPoints()
		win:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", d.x, d.y)
	end
end

local function armarAsa(win)
	-- El alto con que se arma (W.TOP.height): medirla aquí podía dar otro.
	altoFabrica = (A.Widgets and A.Widgets.TOP and A.Widgets.TOP.height) or win:GetHeight() or 700
	if win.SetResizable then win:SetResizable(true) end
	local ancho = win:GetWidth()
	local function limites()
		if win.SetResizeBounds then win:SetResizeBounds(ancho, ALTO_MIN, ancho, topeAlto(win))
		elseif win.SetMinResize then win:SetMinResize(ancho, ALTO_MIN) if win.SetMaxResize then win:SetMaxResize(ancho, topeAlto(win)) end end
	end
	limites()
	local asa = CreateFrame("Button", nil, win)
	asa:SetSize(16, 16)
	asa:SetFrameLevel(win:GetFrameLevel() + 40)
	asa:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -3, 3)
	asa.t = K.Icono(asa, "resize", 16, "textoTenue", "OVERLAY")
	asa.t:SetAllPoints()
	asa:SetScript("OnEnter", function(self) K.SetIcono(self.t, "resize", "texto") end)
	asa:SetScript("OnLeave", function(self) K.SetIcono(self.t, "resize", "textoTenue") end)
	asa:SetScript("OnMouseDown", function(_, boton)
		-- (StartSizing es protegida: en combate no se estira.)
		if boton ~= "LeftButton" or enCombate() then return end
		limites()
		if win.StartSizing then win:StartSizing("BOTTOM") end
		asa.alfaEstirando = true
	end)
	asa:SetScript("OnMouseUp", function()
		if not asa.alfaEstirando then return end
		asa.alfaEstirando = nil
		win:StopMovingOrSizing()
		-- El juego, al soltar, ancla la ventana por su esquina: se guarda dónde quedó.
		Vt.SetAlto(win:GetHeight(), true)
		guardarLugar()
	end)
	asa:SetScript("OnDoubleClick", function()
		Vt.SetAlto(altoFabrica, true)
	end)
	K.ConInfo(asa, L["Hacer más alta la ventana"], L["Arrastra hacia abajo para ver más de cada página. Doble clic: su alto de siempre."])
	-- Mientras se estira, la página se acomoda una vez al pararse.
	win:HookScript("OnSizeChanged", function()
		if not (asa.alfaEstirando and win:IsShown()) then return end
		if N.Una then N.Una("bienvenida.ventanaAlto", 0.15, repintar) end
	end)
	Vt.Asa = asa
end

---------------------------------------------------------------------------
-- Atajos de teclado
---------------------------------------------------------------------------
-- ¿La combinación está libre? Ctrl+1…9 son de fábrica en Classic (la barra
-- de la mascota) y cualquiera puede tener su propia tecla: si el juego ya le
-- asignó una acción, Alfa no se la come. combo: "CTRL-1", "ALT-LEFT"...
function Vt.Libre(combo)
	local fn = rawget(_G, "GetBindingAction")
	if type(fn) ~= "function" then return true end
	local ok, accion = pcall(fn, combo, true)
	if not ok or N.Secreto(accion) then return true end
	return not (type(accion) == "string" and accion ~= "")
end

-- -> true si la tecla es de Alfa (y ya hizo lo suyo).
function Vt.Tecla(tecla)
	if enCombate() or not prendido("atajosVentana") then return false end
	local win = ventana()
	if not (win and win:IsShown()) then return false end
	local ctrl = IsControlKeyDown and IsControlKeyDown() and true or false
	local alt = IsAltKeyDown and IsAltKeyDown() and true or false
	if type(tecla) ~= "string" then return false end
	if ctrl and not alt then
		local n = tonumber(tecla)
		if n and n >= 1 and n <= 9 then return Vt.Libre("CTRL-" .. tecla) and Vt.IrSeccion(n) end
		if tecla == "RIGHT" then return Vt.Libre("CTRL-RIGHT") and Vt.Paso(1) end
		if tecla == "LEFT" then return Vt.Libre("CTRL-LEFT") and Vt.Paso(-1) end
		if tecla == "F" then return Vt.Libre("CTRL-F") and Vt.Buscar() end
	elseif alt and not ctrl and tecla == "LEFT" then
		return Vt.Libre("ALT-LEFT") and Vt.Atras()
	end
	return false
end

local function armarTeclas(win)
	local f = CreateFrame("Frame", nil, win)
	f:SetAllPoints(win)
	f:EnableMouse(false)
	if f.EnableKeyboard then f:EnableKeyboard(true) end
	if f.SetPropagateKeyboardInput then f:SetPropagateKeyboardInput(true) end
	f:SetScript("OnKeyDown", function(self, tecla)
		-- En combate el juego no deja decidir: la tecla sigue su camino.
		if enCombate() then return end
		local ok, suya = pcall(Vt.Tecla, tecla)
		if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(not (ok and suya)) end
	end)
	f:SetScript("OnKeyUp", function(self)
		if not enCombate() and self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
	end)
	-- Al empezar una pelea, ninguna tecla se queda atrapada.
	f:RegisterEvent("PLAYER_REGEN_DISABLED")
	f:SetScript("OnEvent", function(self)
		if self.SetPropagateKeyboardInput then pcall(self.SetPropagateKeyboardInput, self, true) end
	end)
	Vt.Teclas = f
end

---------------------------------------------------------------------------
-- El buscador: tus búsquedas recientes y unas ideas
---------------------------------------------------------------------------
local panel
local PANEL_ANCHO = 300

local function buscarTexto(texto)
	local O, win = Op(), ventana()
	if not (win and win.Search) then return end
	win.Search:SetText(texto)
	if O.SetQuery then O.SetQuery(texto) end
	Vt.Recordar(texto)
	if panel then panel:Hide() end
end

local function filaReciente(p, i)
	local f = p.filas[i]
	if f then return f end
	f = CreateFrame("Button", nil, p)
	f:SetHeight(26)
	f:RegisterForClicks("LeftButtonUp")
	f.velo = K.Velo(f, K.CORTE.chico, 0.07)
	f.Icono = K.Icono(f, "ic-reloj", 14, "textoTenue")
	f.Icono:SetPoint("LEFT", f, "LEFT", 8, 0)
	f.Texto = K.Texto(f, "cuerpo", "texto")
	f.Texto:SetPoint("LEFT", f.Icono, "RIGHT", 8, 0)
	f.Texto:SetPoint("RIGHT", f, "RIGHT", -8, 0)
	f.Texto:SetJustifyH("LEFT")
	f.Texto:SetWordWrap(false)
	f:SetScript("OnEnter", function(self) self.velo:Show() end)
	f:SetScript("OnLeave", function(self) self.velo:Hide() end)
	f:SetScript("OnClick", function(self) buscarTexto(self.alfaTexto) end)
	p.filas[i] = f
	return f
end

local function armarPanel(win)
	local p = CreateFrame("Frame", "AlfaBuscadorSugerencias", win)
	p:SetFrameStrata(win:GetFrameStrata())
	p:SetFrameLevel(win:GetFrameLevel() + 60)
	p:SetWidth(PANEL_ANCHO)
	p:SetPoint("TOPRIGHT", win.Search, "BOTTOMRIGHT", 0, -6)
	p:EnableMouse(true)
	p.caja = K.Caja(p, { fondo = "elevado", borde = "lineaFuerte", corte = K.CORTE.panel })
	p.TituloRec = K.Texto(p, "mayus", "textoTenue")
	K.Escribir(p.TituloRec, K.Mayus(L["Lo que buscaste"]))
	p.Borrar = K.Boton(p, L["Borrar"], function()
		Vt.OlvidarRecientes()
		Vt.PintarPanel()
	end, { tipo = "fantasma", tam = "chico" })
	p.TituloIdeas = K.Texto(p, "mayus", "textoTenue")
	K.Escribir(p.TituloIdeas, K.Mayus(L["Prueba con"]))
	p.Pista = K.Texto(p, "nota", "textoSuave")
	p.filas, p.ideas = {}, {}
	p:Hide()
	panel = p
	Vt.Panel = p
end

function Vt.PintarPanel()
	local p = panel
	if not p then return end
	local pad = ESP.m
	local ancho = PANEL_ANCHO - pad * 2
	local y = pad
	local rec = Vt.Recientes()
	local hay = #rec > 0
	K.Mostrar(p.TituloRec, hay)
	K.Mostrar(p.Borrar, hay)
	if hay then
		p.TituloRec:ClearAllPoints()
		p.TituloRec:SetPoint("TOPLEFT", p, "TOPLEFT", pad, -(y + 6))
		p.Borrar:ClearAllPoints()
		p.Borrar:SetPoint("TOPRIGHT", p, "TOPRIGHT", -pad + 4, -y)
		y = y + 26
		for i, t in ipairs(rec) do
			local f = filaReciente(p, i)
			f.alfaTexto = t
			K.Escribir(f.Texto, t)
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", p, "TOPLEFT", pad - 4, -y)
			f:SetWidth(ancho + 8)
			f:Show()
			y = y + 26
		end
		y = y + ESP.s
	end
	for i = (hay and #rec or 0) + 1, #p.filas do p.filas[i]:Hide() end
	p.TituloIdeas:ClearAllPoints()
	p.TituloIdeas:SetPoint("TOPLEFT", p, "TOPLEFT", pad, -y)
	y = y + K.AltoTexto(p.TituloIdeas) + ESP.s
	-- Las ideas como pastillas, las que quepan en cada renglón.
	local x, alto = 0, K.ALTO.botonChico
	for i, idea in ipairs(IDEAS) do
		local b = p.ideas[i]
		if not b then
			b = K.Boton(p, "", function(self) buscarTexto(self.alfaTexto) end, { tipo = "secundario", tam = "chico" })
			p.ideas[i] = b
		end
		local texto = L[idea]
		b.alfaTexto = texto
		b:SetTexto(texto)
		local w = b:GetWidth()
		if x > 0 and x + w > ancho then x, y = 0, y + alto + ESP.xs end
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", p, "TOPLEFT", pad + x, -y)
		b:Show()
		x = x + w + ESP.xs
	end
	y = y + alto + ESP.m
	K.Escribir(p.Pista, prendido("atajosVentana") and Vt.Libre("CTRL-F") and L["Busca en todos los ajustes y páginas de Alfa. Atajo: Ctrl+F."]
		or L["Busca en todos los ajustes y páginas de Alfa."])
	p.Pista:ClearAllPoints()
	p.Pista:SetPoint("TOPLEFT", p, "TOPLEFT", pad, -y)
	y = y + K.Parrafo(p.Pista, ancho) + pad
	p:SetHeight(y)
end

function Vt.MostrarPanel()
	local win = ventana()
	if not (panel and win and win:IsShown()) or buscando() then
		if panel then panel:Hide() end
		return false
	end
	if N.Quitar then N.Quitar("bienvenida.panelBuscar") end
	Vt.PintarPanel()
	panel:Show()
	return true
end

local function esconderPanelLuego()
	if not panel then return end
	-- Un poco después: el clic en una búsqueda llega antes de esconderse.
	if N.Una then
		N.Una("bienvenida.panelBuscar", 0.25, function() if panel then panel:Hide() end end)
	else
		panel:Hide()
	end
end

local function conectarBuscador(win)
	local s = win.Search
	if not (s and s.HookScript) then return end
	s:HookScript("OnEditFocusGained", function(self)
		if (self:GetText() or "") == "" then Vt.MostrarPanel() end
	end)
	s:HookScript("OnEditFocusLost", function(self)
		local t = self:GetText() or ""
		if t ~= "" and encontro() then Vt.Recordar(t) end
		esconderPanelLuego()
	end)
	s:HookScript("OnTextChanged", function(self)
		local t = self:GetText() or ""
		if t ~= "" then
			if panel then panel:Hide() end
		elseif self.HasFocus and self:HasFocus() then
			Vt.MostrarPanel()
		end
		if pintarVolver then pintarVolver() end
	end)
	s:HookScript("OnEnterPressed", function(self)
		local t = self:GetText() or ""
		if t ~= "" and encontro() then Vt.Recordar(t) end
	end)
	win:HookScript("OnHide", function() if panel then panel:Hide() end end)
end

---------------------------------------------------------------------------
-- Sin resultados: las páginas de Alfa a un clic (Options.lua llama a
-- O.SinResultados(vista, y, texto) y usa la y que devuelve; sin y, se esconde).
---------------------------------------------------------------------------
local sinRes

local function SinResultados(vista, y, _texto)
	if not y then
		if sinRes then sinRes:Hide() end
		return nil
	end
	local O, win = Op(), ventana()
	if not (O and win) then return y end
	if not sinRes or sinRes:GetParent() ~= vista then
		sinRes = CreateFrame("Frame", nil, vista)
		sinRes.Titulo = K.Texto(sinRes, "encabezado", "texto")
		sinRes.Nota = K.Texto(sinRes, "nota", "textoSuave")
		sinRes.botones = {}
		Vt.SinRes = sinRes
	end
	local pad = (A.Widgets and A.Widgets.SHELL and A.Widgets.SHELL.pad) or 32
	local ancho = (win.BodyWidth or 874)
	sinRes:ClearAllPoints()
	sinRes:SetPoint("TOPLEFT", vista, "TOPLEFT", pad, -(y + ESP.s))
	sinRes:SetWidth(ancho)
	K.Escribir(sinRes.Titulo, L["O ve directo a una página"])
	sinRes.Titulo:ClearAllPoints()
	sinRes.Titulo:SetPoint("TOPLEFT", sinRes, "TOPLEFT", 0, 0)
	local h = K.AltoTexto(sinRes.Titulo) + ESP.s
	local x, alto, n = 0, K.ALTO.boton, 0
	for _, k in ipairs(Vt.Secciones()) do
		for _, p in ipairs(O.PagesOf(k)) do
			n = n + 1
			local b = sinRes.botones[n]
			if not b then
				b = K.Boton(sinRes, "", function(self) if self.alfaPagina then O.Select(self.alfaPagina) end end,
					{ tipo = "secundario", conIcono = true })
				sinRes.botones[n] = b
			end
			b.alfaPagina = p.key
			b:SetTexto(O.PageLabel and O.PageLabel(p) or p.name)
			b:SetIcono(p.icon)
			local w = b:GetWidth()
			if x > 0 and x + w > ancho then x, h = 0, h + alto + ESP.s end
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", sinRes, "TOPLEFT", x, -h)
			b:Show()
			x = x + w + ESP.s
		end
	end
	for i = n + 1, #sinRes.botones do sinRes.botones[i]:Hide() end
	h = h + alto + ESP.m
	K.Escribir(sinRes.Nota, L["Consejo: prueba con una palabra más corta o como la dirías en el juego («bolsas», «flecha», «talentos»)."])
	sinRes.Nota:ClearAllPoints()
	sinRes.Nota:SetPoint("TOPLEFT", sinRes, "TOPLEFT", 0, -h)
	h = h + K.Parrafo(sinRes.Nota, ancho)
	sinRes:SetHeight(h)
	sinRes:Show()
	return y + ESP.s + h + ESP.base
end

---------------------------------------------------------------------------
-- Conectar todo cuando la ventana existe
---------------------------------------------------------------------------
local armada = false

local function despues()
	pistasSecciones()
	if pintarVolver then pintarVolver() end
end

local function armar(win)
	if armada or not win then return end
	armada = true
	pcall(armarVolver, win)
	pcall(armarAsa, win)
	-- EnableKeyboard es protegida: si la ventana se abre en combate, al terminar.
	if enCombate() and N.FueraDeCombate then
		N.FueraDeCombate("bienvenida.teclasVentana", function() pcall(armarTeclas, win) end)
	else
		pcall(armarTeclas, win)
	end
	pcall(armarPanel, win)
	pcall(conectarBuscador, win)
	pcall(restaurar, win)
	-- Su lugar al soltarla (la cabecera y la barra de secciones la arrastran).
	for _, parte in ipairs({ win.Header, win.Nav }) do
		if parte and parte.HookScript then parte:HookScript("OnDragStop", guardarLugar) end
	end
	-- Cada vez que se abre: el historial empieza de nuevo.
	win:HookScript("OnShow", function()
		for i = #historial, 1, -1 do historial[i] = nil end
		recienAbierta = true
		if pintarVolver then pintarVolver() end
	end)
	for i = #historial, 1, -1 do historial[i] = nil end
	recienAbierta = true
end

local function conectar()
	local O = Op()
	if not (O and O.Select) or O.alfaVentana then return end
	O.alfaVentana = true
	O.SinResultados = SinResultados
	local seleccionar = O.Select
	O.Select = function(key, tab, ...)
		local win = O.frame
		if win and not armada then armar(win) end
		local antes = O.page and O.page.key
		-- Lo que buscabas, si eliges un resultado, queda en tus búsquedas.
		local enCaja = win and win.Search and win.Search.GetText and win.Search:GetText()
		if type(enCaja) == "string" and enCaja ~= "" and encontro() then Vt.Recordar(enCaja) end
		local r1, r2 = seleccionar(key, tab, ...)
		local ahora = O.page and O.page.key
		if recienAbierta then
			recienAbierta = false
		elseif not volviendo and antes and ahora and antes ~= ahora then
			if historial[#historial] ~= antes then historial[#historial + 1] = antes end
			while #historial > HISTORIAL_MAX do tremove(historial, 1) end
		end
		if panel then panel:Hide() end
		despues()
		return r1, r2
	end
	local refrescar = O.RefreshNav
	if refrescar then
		O.RefreshNav = function(...)
			local r = refrescar(...)
			pistasSecciones()
			return r
		end
	end
end

conectar()
if A.OnLogin then A.OnLogin(conectar) end
