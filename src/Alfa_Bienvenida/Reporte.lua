-- Alfa - Bienvenida: "Reportar un error, una mejora o un comentario"
-- (toxic3000 / La Jauría). GPL-3.0.
--
-- Un addon no puede enviar nada fuera del juego, así que esta ventana del Kit
-- arma el reporte y tú lo pegas en el buzón privado del Discord de La Jauría
-- (📮-buzon-alfa: los miembros escriben, pero no leen lo de los demás; solo
-- lo lee el desarrollador). Nunca lleva datos personales de nadie: ni el
-- nombre de tu personaje ni tu reino, y del desarrollador nada.
--
--   1. Eliges qué es: Error, Mejora o Comentario.
--   2. Lo escribes (hasta 1000 letras).
--   3. Alfa compone el reporte listo para pegar: el tipo, tu texto, la
--      versión de Alfa, la del cliente, el idioma, tu clase y nivel, la zona
--      con coordenadas y, si es un error, los últimos errores de Lua que el
--      motor de Alfa atrapó en esta sesión (Alfa.Errors) y las acciones que
--      el juego le bloqueó (Alfa.Blocked). Cabe en un mensaje de Discord.
--   4. El reporte y la invitación al Discord van en cuadros para copiar
--      (se eligen solos al hacer clic; Ctrl+C).
--
-- Contrato (global AlfaReporte):
--   AlfaReporte.Abrir(tipo)   "error" | "mejora" | "comentario" (por omisión, error)
-- Comando: /alfa reportar [error | mejora | comentario]

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ESP = K.ESP

local format, max, min, floor = string.format, math.max, math.min, math.floor

local idiomaJuego = GetLocale -- sin llamar: el build cambia las llamadas por el idioma de Alfa
local ANCHO, ALTO = 680, 660
local MAX_TEXTO = 1000   -- letras de tu texto
local MAX_REPORTE = 1950 -- un mensaje de Discord admite 2000
local MAX_ERRORES = 5
local MAX_LINEA = 180
-- El canal se llama "📮-buzon-alfa" en Discord, pero las letras del juego no
-- tienen emojis (saldría un cuadro): en el juego se escribe sin él, y en
-- Discord basta con buscar "buzon".
local CANAL = "#buzon-alfa"
local INVITACION = "https://discord.gg/hUNjA6BJwh"

local TIPOS = {
	{ valor = "error", texto = "Error", ayuda = "Qué hacías, qué esperabas y qué pasó. Si puedes, cómo hacer que vuelva a pasar." },
	{ valor = "mejora", texto = "Mejora [reporte]", ayuda = "Qué te gustaría que Alfa hiciera, o hiciera mejor, y para qué te serviría." },
	{ valor = "comentario", texto = "Comentario", ayuda = "Lo que quieras contarle al desarrollador de Alfa." },
}

local v
local ui = { tipo = "error" }

local function legible(x)
	if issecretvalue and issecretvalue(x) then return nil end
	return x
end

local function tipoDe(valor)
	for _, t in ipairs(TIPOS) do if t.valor == valor then return t end end
	return TIPOS[1]
end

-- Un texto cortado a n bytes, nunca a media letra.
local function cortar(s, n)
	s = tostring(s or "")
	if #s <= n then return s end
	return (s:sub(1, n - 3):gsub("[\192-\255][\128-\191]*$", "")) .. "..."
end

-- Sin códigos de color ni de textura del juego.
local function plano(s)
	s = tostring(s or ""):gsub("||", "\1")
	s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
	return (s:gsub("\1", "|"))
end

---------------------------------------------------------------------------
-- Los datos del reporte
---------------------------------------------------------------------------
local function version()
	local ver = tostring(A.version or N.version or "dev")
	if A.stage then ver = ver .. " " .. tostring(A.stage) end
	return ver
end

local function cliente()
	if not GetBuildInfo then return "?", "?" end
	local ok, ver, build = pcall(GetBuildInfo)
	if not ok then return "?", "?" end
	return tostring(ver or "?"), tostring(build or "?")
end

local function personaje()
	local _, clase = M.Clase()
	local nivel = UnitLevel and legible(UnitLevel("player")) or nil
	return clase or "?", type(nivel) == "number" and nivel or 0
end

local function lugar()
	local zona, x, y
	local CM = C_Map
	if CM and CM.GetBestMapForUnit then
		local ok, mapa = pcall(CM.GetBestMapForUnit, "player")
		mapa = ok and legible(mapa) or nil
		if type(mapa) == "number" then
			local ok2, info = pcall(CM.GetMapInfo, mapa)
			if ok2 and type(info) == "table" and type(legible(info.name)) == "string" then zona = info.name end
			local ok3, pos = pcall(CM.GetPlayerMapPosition, mapa, "player")
			if ok3 and pos and pos.GetXY then
				local px, py = pos:GetXY()
				px, py = legible(px), legible(py)
				if type(px) == "number" and type(py) == "number" and (px > 0 or py > 0) then x, y = px * 100, py * 100 end
			end
			zona = (zona or "?") .. format(" [%d]", mapa)
		end
	end
	if not zona and GetZoneText then zona = legible(GetZoneText()) end
	local sub = GetSubZoneText and legible(GetSubZoneText()) or nil
	if type(sub) == "string" and sub ~= "" then zona = (zona or "?") .. " - " .. sub end
	if x then return format("%s (%.1f, %.1f)", zona or "?", x, y) end
	return zona or "?"
end

-- Los errores que el motor atrapó en esta sesión y lo que el juego le
-- bloqueó, los más nuevos al final.
local function errores()
	local lista = {}
	local ok, e = pcall(function() return A.Errors and A.Errors() end)
	for _, x in ipairs(ok and type(e) == "table" and e or {}) do
		local msg = tostring(x.msg or ""):gsub("^Interface[/\\]AddOns[/\\]", "")
		lista[#lista + 1] = { seq = x.seq or 0, texto = format("%dx %s", x.count or 1, msg) }
	end
	local ok2, b = pcall(function() return A.Blocked and A.Blocked() end)
	for _, x in ipairs(ok2 and type(b) == "table" and b or {}) do
		lista[#lista + 1] = { seq = x.seq or 0, texto = format(L["%dx bloqueado: %s en %s (%s)"], x.count or 1, plano(x.fn), tostring(x.addon or "?"), tostring(x.where or x.at or "?")) }
	end
	table.sort(lista, function(a, c) return a.seq < c.seq end)
	local out = {}
	for i = max(1, #lista - MAX_ERRORES + 1), #lista do out[#out + 1] = cortar(lista[i].texto, MAX_LINEA) end
	return out
end

-- El reporte, listo para pegar en Discord.
local function componer()
	local t = tipoDe(ui.tipo)
	local texto = (ui.texto or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if texto == "" then texto = L["(todavía sin texto: escríbelo arriba)"] end
	local cv, build = cliente()
	local clase, nivel = personaje()
	local datos = {
		format(L["Alfa %s · cliente %s (%s) · %s · Alfa en %s"], version(), cv, build, tostring(idiomaJuego and idiomaJuego() or "?"), M.IdiomaActual()),
		format(L["%s, nivel %d"], clase, nivel),
		format(L["Lugar: %s"], lugar()),
	}
	local errs = {}
	if t.valor == "error" then errs = errores() end
	local function armar(nErr)
		local d = {}
		for i, l in ipairs(datos) do d[i] = l end
		if t.valor == "error" then
			if nErr == 0 then
				d[#d + 1] = L["Errores de Lua de Alfa en esta sesión: ninguno"]
			else
				d[#d + 1] = L["Errores de Lua de Alfa en esta sesión:"]
				for i = #errs - nErr + 1, #errs do d[#d + 1] = "  " .. errs[i] end
			end
		end
		return format("**[Alfa] %s**\n%s\n```\n%s\n```", L[t.texto], texto, table.concat(d, "\n"))
	end
	-- Si no cabe en un mensaje, se dejan fuera los errores más viejos.
	local n = #errs
	local s = armar(n)
	while #s > MAX_REPORTE and n > 0 do
		n = n - 1
		s = armar(n)
	end
	-- Si aún no cabe (un texto largo en ruso, coreano o chino ocupa más bytes
	-- que letras), se recorta solo lo que escribiste: los datos y el cierre del
	-- bloque se quedan completos.
	if #s > MAX_REPORTE then
		texto = cortar(texto, math.max(20, #texto - (#s - MAX_REPORTE)))
		s = armar(n)
	end
	return cortar(s, MAX_REPORTE)
end

M.ComponerReporte = componer

---------------------------------------------------------------------------
-- Piezas: un cuadro de texto (para escribir o para copiar)
---------------------------------------------------------------------------

-- o = { alto, lineas = true (varias líneas), soloCopiar = true, alCambiar = fn(texto), max }
local function cuadro(padre, o)
	local c = CreateFrame("Frame", nil, padre)
	c:SetHeight(o.alto or K.ALTO.control)
	c:EnableMouse(true)
	c.caja = K.Caja(c, { fondo = "hundido", borde = "lineaFuerte", corte = K.CORTE.control })
	local e = CreateFrame("EditBox", nil, c)
	c.Campo = e
	e:SetAutoFocus(false)
	if o.max then e:SetMaxLetters(o.max) end
	K.Pintar(e, function(x)
		K.FuenteSegura(x, K.Cara("medium"), K.Tamano("cuerpo"), "")
		x:SetTextColor(K.Color("texto"))
	end)
	if o.lineas then
		e:SetMultiLine(true)
		local sf = CreateFrame("ScrollFrame", nil, c)
		c.Desliza = sf
		sf:SetPoint("TOPLEFT", c, "TOPLEFT", ESP.m, -ESP.s)
		sf:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -ESP.m, ESP.s)
		sf:SetScrollChild(e)
		sf:EnableMouseWheel(true)
		sf:SetScript("OnMouseWheel", function(self, delta)
			local rango = self.GetVerticalScrollRange and self:GetVerticalScrollRange() or 0
			self:SetVerticalScroll(max(0, min(rango, self:GetVerticalScroll() - delta * 20)))
		end)
		-- El cursor siempre a la vista al escribir.
		e:SetScript("OnCursorChanged", function(_, _, y, _, h)
			local arriba, alto = sf:GetVerticalScroll(), K.num(sf:GetHeight(), 0)
			y = -(y or 0)
			if y < arriba then
				sf:SetVerticalScroll(y)
			elseif y + (h or 0) > arriba + alto then
				sf:SetVerticalScroll(y + (h or 0) - alto)
			end
		end)
	else
		e:SetPoint("LEFT", c, "LEFT", ESP.m, 0)
		e:SetPoint("RIGHT", c, "RIGHT", -ESP.m, 0)
		e:SetHeight(K.ALTO.control - 4)
	end
	c:SetScript("OnMouseDown", function() e:SetFocus() end)
	e:SetScript("OnEditFocusGained", function(self)
		if o.soloCopiar then self:HighlightText() end
		c.caja:Estilo({ borde = "acento", alfaBorde = 0.8 })
	end)
	e:SetScript("OnEditFocusLost", function(self)
		self:HighlightText(0, 0)
		c.caja:Estilo({ borde = "lineaFuerte", alfaBorde = 1 })
	end)
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	if not o.lineas then e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end) end
	e:SetScript("OnTextChanged", function(self, usuario)
		if o.soloCopiar then
			if usuario and self:GetText() ~= (c.texto or "") then
				self:SetText(c.texto or "")
				self:HighlightText()
			end
			return
		end
		if c.Ayuda then c.Ayuda:SetShown((self:GetText() or "") == "") end
		if usuario and o.alCambiar then K.Llamar(o.alCambiar, self:GetText() or "") end
	end)
	if o.soloCopiar then e:SetScript("OnMouseUp", function(self) self:HighlightText() end) end
	-- La ayuda del cuadro vacío, para escribir.
	if not o.soloCopiar then
		c.Ayuda = K.Texto(c, "texto", "textoTenue")
		c.Ayuda:SetPoint("TOPLEFT", c, "TOPLEFT", ESP.m + 2, o.lineas and -ESP.s - 2 or -9)
		c.Ayuda:SetPoint("RIGHT", c, "RIGHT", -ESP.m, 0)
		c.Ayuda:SetJustifyH("LEFT")
		c.Ayuda:SetWordWrap(true)
	end
	function c:SetAyuda(t) if self.Ayuda then K.Escribir(self.Ayuda, t or "") end end
	function c:Set(t)
		self.texto = t or ""
		e:SetText(self.texto)
		e:SetCursorPosition(0)
		if self.Desliza then self.Desliza:SetVerticalScroll(0) end
		if self.Ayuda then self.Ayuda:SetShown(self.texto == "") end
	end
	function c:Copiar()
		e:SetFocus()
		e:HighlightText()
	end
	function c:Acomodar(ancho)
		self:SetWidth(ancho)
		if o.lineas then e:SetWidth(max(60, ancho - 2 * ESP.m)) end
		return K.num(self:GetHeight(), K.ALTO.control)
	end
	return c
end

-- Un cuadro para copiar con su botón: a la derecha, o debajo con su nota
-- (o.abajo, para el de varias líneas).
local function filaCopiar(padre, o)
	local f = CreateFrame("Frame", nil, padre)
	f.Cuadro = cuadro(f, { alto = o.alto, lineas = o.lineas, soloCopiar = true })
	f.Boton = K.Boton(f, L[o.boton or "Elegir para copiar"], function() f.Cuadro:Copiar() end, { tipo = o.abajo and "primario" or "secundario", icono = o.abajo and "ic-exito" or nil })
	if o.nota then
		f.Nota = K.Texto(f, "nota", "textoTenue")
		K.Escribir(f.Nota, L[o.nota])
	end
	function f:Set(t) self.Cuadro:Set(t) end
	function f:Acomodar(ancho)
		local bw = self.Boton:AnchoNatural()
		self.Cuadro:ClearAllPoints()
		self.Cuadro:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
		self.Boton:ClearAllPoints()
		local h
		if o.abajo then
			h = self.Cuadro:Acomodar(ancho) + ESP.m
			self.Boton:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -h)
			if self.Nota then
				self.Nota:ClearAllPoints()
				self.Nota:SetPoint("LEFT", self.Boton, "RIGHT", ESP.m, 0)
				K.Ajustar(self.Nota, max(60, ancho - bw - ESP.m))
			end
			h = h + K.num(self.Boton:GetHeight(), K.ALTO.boton)
		else
			h = self.Cuadro:Acomodar(max(120, ancho - bw - ESP.s))
			self.Boton:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0)
		end
		self:SetSize(ancho, h)
		return h
	end
	return f
end

-- Un bloque que no se estira: los segmentos miden su propio ancho.
local function suelto(padre, crear)
	local b = CreateFrame("Frame", nil, padre)
	local hijo = crear(b)
	b.Hijo = hijo
	hijo:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	function b:Acomodar(ancho)
		local h = hijo:Acomodar(ancho)
		self:SetSize(ancho, h)
		return h
	end
	return b
end

-- Una línea de texto como bloque de una pila.
local function parrafo(pila, rol, color)
	local b = CreateFrame("Frame", nil, pila)
	b.Texto = K.Texto(b, rol or "nota", color or "textoSuave")
	b.Texto:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	function b:Set(t) K.Escribir(self.Texto, t or "") end
	function b:Acomodar(ancho)
		local h = K.Parrafo(self.Texto, ancho)
		self:SetHeight(h)
		return h
	end
	return pila:Agregar(b)
end

---------------------------------------------------------------------------
-- La ventana
---------------------------------------------------------------------------
local function rehacer()
	if not ui.reporte then return end
	ui.reporte:Set(componer())
	-- Letras, no bytes (como cuenta la caja): "ñ" o "я" son una sola.
	local t = ui.texto or ""
	local n = strlenutf8 and strlenutf8(t) or #(t:gsub("[\128-\191]", ""))
	ui.cuenta:Set(format(L["%d de %d letras"], n, MAX_TEXTO))
end

local function acomodar()
	if not (v and v:IsShown() and ui.pila) then return end
	local ancho = v:AnchoCuerpo()
	ui.pila:ClearAllPoints()
	ui.pila:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", v.margen, -ESP.base)
	local h = ui.pila:Acomodar(ancho)
	v:SetAltoContenido(h + 2 * ESP.base)
end

local function elegirTipo(valor)
	ui.tipo = tipoDe(valor).valor
	if ui.segmentos then ui.segmentos:SetValor(ui.tipo) end
	if ui.entrada then ui.entrada:SetAyuda(L[tipoDe(ui.tipo).ayuda]) end
	rehacer()
end

local function armar()
	v = K.Ventana({
		nombre = "AlfaReporteVentana", titulo = L["Reportar a Alfa"],
		subtitulo = L["Un error, una mejora o un comentario, directo al desarrollador"], icono = "ic-info",
		ancho = ANCHO, alto = ALTO, desplazar = true,
		fija = true, -- un reporte a medio escribir no se cierra al empezar algo
	})
	v.alAcomodar = acomodar
	local p = K.Pila(v.Cuerpo, { espacio = ESP.m })
	ui.pila = p

	p:Agregar(K.Seccion(p, L["¿Qué nos quieres contar?"]))
	local opciones = {}
	for i, t in ipairs(TIPOS) do opciones[i] = { valor = t.valor, texto = L[t.texto] } end
	ui.segmentos = p:Agregar(suelto(p, function(b)
		return K.Segmentos(b, { estilo = "segmentos", opciones = opciones, valor = ui.tipo, alCambiar = function(x) elegirTipo(x) end })
	end)).Hijo
	ui.entrada = p:Agregar(cuadro(p, { alto = 120, lineas = true, max = MAX_TEXTO,
		alCambiar = function(t) ui.texto = t rehacer() end }), { espacio = ESP.base })
	ui.cuenta = parrafo(p, "pequeno", "textoTenue")

	p:Agregar(K.Seccion(p, L["Tu reporte, listo para pegar"]), { espacio = ESP.l })
	parrafo(p, "nota", "textoSuave"):Set(L["Alfa le agregó lo que ayuda a arreglarlo: versiones, idioma, tu clase y nivel y dónde estás. No lleva tu nombre ni tu reino."])
	ui.reporte = p:Agregar(filaCopiar(p, { alto = 150, lineas = true, abajo = true, boton = "Elegir todo", nota = "Luego cópialo con Ctrl+C." }))

	p:Agregar(K.Seccion(p, L["Dónde mandarlo"]), { espacio = ESP.l })
	parrafo(p, "texto", "texto"):Set(format(L["Pégalo en %s del Discord de La Jauría."], CANAL))
	ui.invitacion = p:Agregar(filaCopiar(p, {}))
	parrafo(p, "nota", "textoSuave"):Set(L["Lo revisa el desarrollador de Alfa. En ese canal nadie más ve tu mensaje. Si aún no estás en el Discord, entra con la invitación de arriba."])

	v:SetPie({ K.Boton(v, L["Cerrar"], function() v:Cerrar() end, { tipo = "secundario" }) })
end

function M.AbrirReporte(tipo)
	if not v then armar() end
	local url = type(A.DiscordURL) == "string" and A.DiscordURL ~= "" and A.DiscordURL or INVITACION
	ui.invitacion:Set(url)
	if ui.entrada and ui.entrada.Campo:GetText() ~= (ui.texto or "") then ui.entrada:Set(ui.texto or "") end
	elegirTipo(tipo or ui.tipo)
	v:Abrir()
	if v.Desplazable then v.Desplazable:IrArriba() end
	acomodar()
	ui.entrada.Campo:SetFocus()
end

-- /alfa reportar [error | mejora | comentario]
local PALABRAS = { error = "error", bug = "error", fallo = "error", mejora = "mejora", idea = "mejora",
	sugerencia = "mejora", comentario = "comentario", comment = "comentario" }

A.RegisterCommand("reportar", function(resto)
	local palabra = type(resto) == "string" and resto:lower():match("^%s*(%S*)") or ""
	M.AbrirReporte(PALABRAS[palabra])
end, L["reporta un error, una mejora o un comentario al desarrollador de Alfa (también: mejora, comentario)"])

AlfaReporte = type(AlfaReporte) == "table" and AlfaReporte or {}
function AlfaReporte.Abrir(tipo) return M.AbrirReporte(tipo) end
