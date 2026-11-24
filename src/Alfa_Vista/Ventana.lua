-- Alfa - Paisaje y gráficos: la ventana (toxic3000 / La Jauría). GPL-3.0.
--
-- Una ventana del Kit (sigue los tres estilos de Alfa solo) que se abre con
-- /alfa paisaje, /alfa graficos y desde su página. Pestañas: Calidad,
-- Entorno, Cámara, Interfaz, Filtros y Avanzado, y un buscador que busca en
-- todas a la vez. Cada fila de una variable del juego trae:
--   * su control (deslizador, interruptor o lista) con el valor que el juego
--     de verdad aplica (se vuelve a leer después de escribir);
--   * un campo para escribir el valor exacto (en los deslizadores);
--   * «Por defecto» (el valor de fábrica del juego);
--   * una marca a la izquierda si cambió (verde: Alfa la mantiene al entrar;
--     gris: la cambió otra cosa; amarilla: espera a que termine el combate);
--   * una estrella si también está en el menú de opciones del juego;
--   * atenuada si depende de otra que está apagada.
-- Nada se crea hasta que se abre por primera vez.

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local K = N.Kit
local ID = M.ID
local ESP = K.ESP

local type, ipairs, pairs, format, floor, max, min, tonumber, concat =
	type, ipairs, pairs, string.format, math.floor, math.max, math.min, tonumber, table.concat

local V = {}
M.Ventana = V
V.filtro, V.pestana = "", "calidad"

local ANCHO, ALTO = 920, 660
local ANCHO_DESL, ANCHO_CAMPO, ANCHO_BUSCAR = 180, 64, 240
local ESTRELLA = "Interface\\AddOns\\Alfa_Vista\\Media\\estrella"

local v -- la ventana

---------------------------------------------------------------------------
-- Ayudas
---------------------------------------------------------------------------
local ACENTOS = { ["á"] = "a", ["é"] = "e", ["í"] = "i", ["ó"] = "o", ["ú"] = "u", ["ü"] = "u", ["ñ"] = "n",
	["Á"] = "a", ["É"] = "e", ["Í"] = "i", ["Ó"] = "o", ["Ú"] = "u", ["Ü"] = "u", ["Ñ"] = "n" }
local function plano(s)
	s = tostring(s or ""):lower()
	return (s:gsub("\195[\128-\191]", function(c) return ACENTOS[c] or c end))
end

local function estrella()
	local r, g, b = K.Color("oro")
	return format("|T%s:12:12:0:0:32:32:0:32:0:32:%d:%d:%d|t", ESTRELLA, floor(r * 255), floor(g * 255), floor(b * 255))
end

-- El valor como se muestra (la nitidez va al revés que en el juego).
local function valorMostrado(def)
	local n = tonumber(M.ValorDe(def.cvar))
	if not n then return nil end
	if def.invertir then n = def.invertir - n end
	return n
end

local function pedirMostrado(def, n)
	if def.min then n = max(def.min, n) end
	if def.max then n = min(def.max, n) end
	if def.invertir then n = def.invertir - n end
	return M.Pedir(def.cvar, n)
end

-- Un valor del juego, dicho para leer: el nombre de la opción en una lista.
local function textoDe(def, valor)
	if valor == nil then return "?" end
	if def.tipo == "lista" then
		for _, o in ipairs(def.opciones) do
			if M.Igual(o[1], valor) then return o[2] end
		end
	elseif def.tipo == "interruptor" then
		local n = tonumber(valor)
		return (n and n ~= 0) and L["encendido"] or L["apagado"]
	elseif def.invertir and tonumber(valor) then
		return M.Texto(def.invertir - tonumber(valor))
	end
	return M.Texto(valor)
end
V.TextoDe = textoDe

local function padreEncendido(cvar)
	if not M.Existe(cvar) then return true end
	local n = tonumber(M.ValorDe(cvar))
	return n ~= nil and n ~= 0
end

local function coincide(def, filtro)
	if filtro == "" then return true end
	def.alfaBuscar = def.alfaBuscar or plano(concat({ def.titulo or "", def.texto or "", def.cvar or "", def.buscar or "" }, " "))
	for palabra in filtro:gmatch("%S+") do
		if not def.alfaBuscar:find(palabra, 1, true) then return false end
	end
	return true
end

---------------------------------------------------------------------------
-- El campo del valor exacto
---------------------------------------------------------------------------
local function pintarCampo(b)
	b.caja:Estilo({ fondo = "hundido", borde = b.alfaFoco and "acento" or "lineaFuerte", alfaBorde = b.alfaFoco and 0.8 or 1 })
	K.FuenteSegura(b.Campo, K.Cara("semibold"), K.Tamano("numero"), "")
	b.Campo:SetTextColor(K.Color("texto"))
end

local function campo(padre, alEnter)
	local b = CreateFrame("Frame", nil, padre)
	b:SetSize(ANCHO_CAMPO, K.ALTO.control - 4)
	b.caja = K.Caja(b, { corte = K.CORTE.control })
	local e = CreateFrame("EditBox", nil, b)
	b.Campo = e
	e:SetAutoFocus(false)
	e:SetPoint("TOPLEFT", b, "TOPLEFT", 8, 0)
	e:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -8, 0)
	e:SetJustifyH("RIGHT")
	e:SetMaxLetters(10)
	e:SetScript("OnEnterPressed", function(self)
		local t = (self:GetText() or ""):gsub(",", ".")
		local n = tonumber(t)
		self:ClearFocus()
		if n then K.Llamar(alEnter, n) else b:Revertir() end
	end)
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	e:SetScript("OnEditFocusGained", function(self)
		b.alfaFoco = true
		pintarCampo(b)
		if self.HighlightText then self:HighlightText() end
	end)
	e:SetScript("OnEditFocusLost", function()
		b.alfaFoco = nil
		pintarCampo(b)
		b:Revertir()
	end)
	function b:Set(t)
		self.alfaTexto = t or ""
		if not self.alfaFoco then e:SetText(self.alfaTexto) end
	end
	function b:Revertir() e:SetText(self.alfaTexto or "") end
	function b:SetActivo(on)
		e:EnableMouse(on ~= false)
		if on == false then e:ClearFocus() end
		self:SetAlpha(on == false and 0.45 or 1)
	end
	K.ConInfo(b, L["Valor exacto"], L["Escribe el número que quieras y presiona Enter."])
	K.Pintar(b, pintarCampo)
	return b
end

---------------------------------------------------------------------------
-- El control de una fila: deslizador + campo, interruptor o lista, y
-- «Por defecto». Todos miden lo mismo: las columnas quedan alineadas.
---------------------------------------------------------------------------
local function arrastrar(c, valor)
	c.Campo:Set(M.Texto(valor))
	if c.alfaEspera then c.alfaEspera:Cancel() end
	-- Se aplica al soltar (un momento después del último movimiento): mover
	-- la distancia de visión cuadro por cuadro haría saltar el juego.
	c.alfaEspera = K.Despues(0.25, function()
		c.alfaEspera = nil
		pedirMostrado(c.def, valor)
	end)
end

local function opcionesDe(def, actual)
	local lista, esta = {}, false
	for i, o in ipairs(def.opciones) do
		lista[i] = { valor = o[1], texto = o[2] }
		if M.Igual(o[1], actual) then esta = true end
	end
	if actual ~= nil and not esta then
		lista[#lista + 1] = { valor = M.Texto(actual), texto = format(L["Otro (%s)"], M.Texto(actual)) }
	end
	return lista
end

local function valorDeLista(def)
	local actual = M.ValorDe(def.cvar)
	for _, o in ipairs(def.opciones) do
		if M.Igual(o[1], actual) then return o[1] end
	end
	return actual and M.Texto(actual)
end

function V.Control(fila, def)
	local c = CreateFrame("Frame", nil, fila)
	c.def = def
	c.Def = K.Boton(c, L["Por defecto"], function() M.Restablecer(def.cvar) end, { tipo = "fantasma", tam = "chico" })
	c.Def:SetPoint("RIGHT", c, "RIGHT", 0, 0)
	K.ConInfo(c.Def, function()
		return L["Por defecto"], format(L["Vuelve al valor de fábrica del juego: %s."], textoDe(def, M.Defecto(def.cvar)))
	end)
	local anchoDef = K.num(c.Def:GetWidth(), 84)
	local derecha = -(anchoDef + ESP.s)
	if def.tipo == "deslizador" then
		c.Campo = campo(c, function(n) pedirMostrado(def, n) end)
		c.Campo:SetPoint("RIGHT", c, "RIGHT", derecha, 0)
		c.Desl = K.Deslizador(c, { min = def.min, max = def.max, paso = def.paso, ancho = ANCHO_DESL,
			get = function() return valorMostrado(def) or def.min end,
			set = function(n) arrastrar(c, n) end })
		c.Desl.Cifra:Hide()
		c.Desl.Barra:SetPoint("RIGHT", c.Desl, "RIGHT", 0, 0)
		c.Desl:SetPoint("RIGHT", c.Campo, "LEFT", -ESP.m, 0)
	elseif def.tipo == "interruptor" then
		c.Inter = K.Interruptor(c, {
			get = function() local n = tonumber(M.ValorDe(def.cvar)) return n ~= nil and n ~= 0 end,
			set = function(on) M.Pedir(def.cvar, on and 1 or 0) end })
		c.Inter:SetPoint("RIGHT", c, "RIGHT", derecha, 0)
	else
		c.Lista = K.Desplegable(c, { opciones = opcionesDe(def, M.ValorDe(def.cvar)), ancho = ANCHO_DESL,
			get = function() return valorDeLista(def) end,
			set = function(valor) M.Pedir(def.cvar, valor) end })
		c.Lista:SetPoint("RIGHT", c, "RIGHT", derecha, 0)
	end
	c:SetSize(ANCHO_DESL + ESP.m + ANCHO_CAMPO + ESP.s + anchoDef, K.ALTO.control)

	function c:Leer()
		if self.Desl then
			if not self.alfaEspera then
				self.Desl:Leer()
				local n = valorMostrado(def)
				self.Campo:Set(n and M.Texto(n) or "")
			end
		elseif self.Inter then
			self.Inter:Leer()
		else
			self.Lista:SetOpciones(opcionesDe(def, M.ValorDe(def.cvar)))
			self.Lista:Leer()
		end
		local distinta = M.Cambiada(def.cvar) or M.Pendiente(def.cvar)
		self.Def:SetActivo(self.alfaActivo ~= false and distinta and true or false)
	end
	function c:SetActivo(on)
		self.alfaActivo = on
		local x = self.Desl or self.Inter or self.Lista
		x:SetActivo(on)
		if self.Campo then self.Campo:SetActivo(on) end
	end
	return c
end

---------------------------------------------------------------------------
-- Filas
---------------------------------------------------------------------------
local function textoFila(def)
	local partes = { def.texto }
	if def.reinicio then partes[#partes + 1] = L["Se ve después de reiniciar los gráficos."] end
	if M.Pendiente(def.cvar) then partes[#partes + 1] = K.Tenir("aviso", L["Se aplica al salir de combate."]) end
	local lim = M.limites[def.cvar]
	if lim then
		partes[#partes + 1] = K.Tenir("aviso", format(L["Pediste %s; el juego lo dejó en %s."], textoDe(def, lim[1]), textoDe(def, lim[2])))
	end
	if def.cvar == "cameraDistanceMaxZoomFactor" and M.CamaraDeComodidades() then
		partes[#partes + 1] = K.Tenir("aviso", L["«Alejar más la cámara» de Comodidades está encendido y manda sobre este valor al entrar."])
	end
	return concat(partes, " ")
end

local function infoFila(fila)
	local def = fila.def
	if not def or not def.cvar then return nil end
	local lineas = {
		format(L["Variable del juego: %s"], def.cvar),
		format(L["Ahora: %s · De fábrica: %s"], textoDe(def, M.ValorDe(def.cvar)), textoDe(def, M.Defecto(def.cvar))),
	}
	if M.Pendiente(def.cvar) then lineas[#lineas + 1] = L["Espera a que termine el combate."]
	elseif M.Elegida(def.cvar) then lineas[#lineas + 1] = L["Alfa la vuelve a poner al entrar."]
	elseif M.Cambiada(def.cvar) then lineas[#lineas + 1] = L["La cambiaste fuera de Alfa (menú del juego o consola)."] end
	if def.menu then lineas[#lineas + 1] = L["También está en el menú de opciones del juego."] end
	if M.Info(def.cvar) and M.Info(def.cvar).segura then lineas[#lineas + 1] = L["El juego solo deja cambiarla fuera de combate."] end
	return def.titulo, lineas
end

local function pintarFila(fila)
	local def = fila.def
	local d = fila.alfaDatos
	d.titulo = def.menu and (def.titulo .. "  " .. estrella()) or def.titulo
	d.texto = textoFila(def)
	local color
	if M.Pendiente(def.cvar) then color = "aviso"
	elseif M.Elegida(def.cvar) then color = "acento"
	elseif M.Cambiada(def.cvar) then color = "textoTenue" end
	fila.Marca:SetShown(color ~= nil)
	if color then K.ColorPlano(fila.Marca, color) end
	fila:Refrescar()
end

local function filaCVar(ga, def)
	local fila = ga:Fila({ titulo = def.titulo, texto = def.texto, hija = def.padre ~= nil,
		activa = def.padre and function() return padreEncendido(def.padre) end or nil,
		control = function(f) return V.Control(f, def) end })
	fila.def = def
	fila.Marca = K.Plano(fila, "acento", "ARTWORK", 2)
	fila.Marca:SetSize(3, 16)
	fila.Marca:SetPoint("TOPLEFT", fila, "TOPLEFT", 5, -ESP.m)
	fila.Marca:Hide()
	fila:EnableMouse(true)
	K.ConInfo(fila, infoFila)
	return fila
end

---------------------------------------------------------------------------
-- Bloques propios: preajustes, nota de los filtros y tintes
---------------------------------------------------------------------------
local function aplicarPreset(id)
	local ok, como = M.AplicarPreset(id)
	if ok and como == "espera" then
		K.Aviso({ titulo = M.PRESET[id].nombre, texto = L["Estás en combate: se aplica en cuanto termine."], icono = "ic-reloj", tono = "aviso" })
	end
end
V.AplicarPreset = aplicarPreset

-- Un solo botón verde: el de la firma de Alfa; el que ya está puesto, tenue.
function V.TiposDePresets(rejilla, actual)
	for i, p in ipairs(M.PRESETS) do
		local t = rejilla.pool[i]
		if t and t.Accion then
			t.Accion:SetTipo(actual == p and "acento" or (p.id == "manada" and "primario" or "secundario"))
		end
	end
end

local function bloquePresets(padre)
	local b = CreateFrame("Frame", nil, padre)
	b.Seccion = K.Seccion(b, L["Preajustes"])
	b.Nota = K.Texto(b, "nota", "textoSuave")
	b.Rejilla = K.Rejilla(b, { min = 250, gap = ESP.m })
	function b:Refrescar()
		local actual = M.UltimoPreset()
		local lista = {}
		for _, p in ipairs(M.PRESETS) do
			local puesto = actual == p
			lista[#lista + 1] = {
				icono = p.icono, tono = p.id == "manada" and "acento" or "neutro",
				sobre = p.id == "manada" and L["Firma de Alfa"] or nil,
				titulo = p.nombre, texto = p.texto, elegida = puesto,
				accion = { texto = puesto and L["Puesto"] or L["Aplicar"], alClic = function() aplicarPreset(p.id) end },
			}
		end
		self.Rejilla:Llenar(lista)
		V.TiposDePresets(self.Rejilla, actual)
		self.Seccion:Set(L["Preajustes"], M.PuedeDeshacer() and { enlace = { texto = L["Deshacer"], alClic = function() M.Deshacer() end } } or nil)
	end
	function b:Acomodar(ancho)
		self.Seccion:ClearAllPoints()
		self.Seccion:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
		self.Seccion:SetWidth(ancho)
		local y = self.Seccion:Acomodar(ancho) + ESP.xs
		K.Escribir(self.Nota, L["Solo tocan gráficos: nunca la cámara, el ratón ni la interfaz. «Deshacer» devuelve lo que tenías antes del último que aplicaste."])
		self.Nota:ClearAllPoints()
		self.Nota:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
		y = y + K.Parrafo(self.Nota, ancho) + ESP.m
		self.Rejilla:ClearAllPoints()
		self.Rejilla:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
		y = y + self.Rejilla:Acomodar(ancho)
		self:SetSize(ancho, y)
		return y
	end
	b.buscar = plano(L["Preajustes"] .. " preset bajo medio alto ultra manada " .. L["Paisaje de la manada"])
	return b
end

local function bloqueNota(padre, texto)
	local b = CreateFrame("Frame", nil, padre)
	b.Texto = K.Texto(b, "nota", "textoSuave")
	function b:Acomodar(ancho)
		K.Escribir(self.Texto, texto)
		self.Texto:ClearAllPoints()
		self.Texto:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
		local h = K.Parrafo(self.Texto, ancho)
		self:SetSize(ancho, h)
		return h
	end
	return b
end

local function pintarTinte(x)
	local on = N.Get(ID, "tinte") == x.tinte.id
	x.caja:Estilo({ fondo = on and "elevado" or "panel", borde = on and "acento" or (x.alfaSobre and "textoTenue" or "linea") })
	K.ColorTexto(x.Nombre, on and "texto" or "textoSuave")
end

local function bloqueTintes(padre)
	local b = CreateFrame("Frame", nil, padre)
	b.Seccion = K.Seccion(b, L["Tinte de color"])
	b.botones = {}
	local palabras = { L["Tinte de color"], "tint color filter" }
	for i, t in ipairs(M.TINTES) do
		local x = CreateFrame("Button", nil, b)
		x.tinte = t
		x:RegisterForClicks("LeftButtonUp")
		x.caja = K.Caja(x, { corte = K.CORTE.control, rol = "panel" })
		x.Mini = x:CreateTexture(nil, "ARTWORK")
		x.Mini:SetTexture(t.miniatura)
		x.Nombre = K.Texto(x, "etiqueta", "textoSuave")
		x.Nombre:SetJustifyH("CENTER")
		K.Escribir(x.Nombre, t.nombre)
		x:SetScript("OnClick", function(self) N.Set(ID, "tinte", self.tinte.id) end)
		x:SetScript("OnEnter", function(self) self.alfaSobre = true pintarTinte(self) end)
		x:SetScript("OnLeave", function(self) self.alfaSobre = nil pintarTinte(self) end)
		K.Pintar(x, pintarTinte)
		b.botones[i] = x
		palabras[#palabras + 1] = t.nombre
		palabras[#palabras + 1] = t.id
	end
	b.buscar = plano(concat(palabras, " "))
	function b:Refrescar() for _, x in ipairs(self.botones) do pintarTinte(x) end end
	function b:Acomodar(ancho)
		self.Seccion:ClearAllPoints()
		self.Seccion:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
		self.Seccion:SetWidth(ancho)
		local y = self.Seccion:Acomodar(ancho) + ESP.s
		local gap = ESP.m
		local cols = max(1, floor((ancho + gap) / (112 + gap)))
		local w = floor((ancho - gap * (cols - 1)) / cols)
		local mini = floor((w - 12) / 2)
		local h = 6 + mini + 6 + 16 + 6
		for i, x in ipairs(self.botones) do
			local c, f = (i - 1) % cols, floor((i - 1) / cols)
			x:ClearAllPoints()
			x:SetPoint("TOPLEFT", self, "TOPLEFT", c * (w + gap), -(y + f * (h + gap)))
			x:SetSize(w, h)
			x.Mini:ClearAllPoints()
			x.Mini:SetPoint("TOP", x, "TOP", 0, -6)
			x.Mini:SetSize(w - 12, mini)
			x.Nombre:ClearAllPoints()
			x.Nombre:SetPoint("BOTTOM", x, "BOTTOM", 0, 8)
			x.Nombre:SetWidth(w - 8)
		end
		local filas = math.ceil(#self.botones / cols)
		y = y + filas * h + (filas - 1) * gap
		self:SetSize(ancho, y)
		return y
	end
	return b
end

---------------------------------------------------------------------------
-- Grupos que no son variables del juego (filtros y herramientas)
---------------------------------------------------------------------------
local function interruptor(clave)
	return function(fila) return K.Interruptor(fila, { clave = ID .. "." .. clave }) end
end

local function deslizador(clave, a, b, paso)
	return function(fila)
		local d = K.Deslizador(fila, { min = a, max = b, paso = paso, clave = ID .. "." .. clave,
			formato = function(x) return floor(x * 100 + 0.5) .. " %" end })
		d.alfaAnchoFila = 240
		return d
	end
end

local function encendido(clave) return function() return N.Get(ID, clave) == true end end

local EXTRA = {
	{ pestana = "filtros", titulo = L["Viñeta"], filas = {
		{ titulo = L["Oscurecer las orillas"], texto = L["Las esquinas de la pantalla se oscurecen poco a poco, como en una foto."],
			control = interruptor("vineta"), buscar = "vignette" },
		{ titulo = L["Fuerza"], hija = true, activa = encendido("vineta"), control = deslizador("vinetaFuerza", 0.1, 1, 0.05), buscar = "vignette strength" },
	} },
	{ pestana = "filtros", titulo = L["Grano de película"], filas = {
		{ titulo = L["Grano"], texto = L["Un grano fino, como de cine. Casi no cuesta: se mueve unas 14 veces por segundo y solo mientras se ve."],
			control = interruptor("grano"), buscar = "film grain noise" },
		{ titulo = L["Fuerza"], hija = true, activa = encendido("grano"), control = deslizador("granoFuerza", 0.1, 1, 0.05), buscar = "grain strength" },
		{ titulo = L["En movimiento"], hija = true, activa = encendido("grano"), control = interruptor("granoMover"),
			texto = L["Apagado, el grano se queda quieto."], buscar = "animated grain" },
	} },
	{ pestana = "filtros", titulo = L["Barras de cine"], filas = {
		{ titulo = L["Barras arriba y abajo"], texto = L["Pantalla de película para capturas y paseos. Solo cambia cómo se ve: no da más FPS."],
			control = interruptor("barras"), buscar = "letterbox cinematic bars" },
		{ titulo = L["Alto de las barras"], hija = true, activa = encendido("barras"), control = deslizador("barrasAlto", 0.04, 0.16, 0.01), buscar = "letterbox height" },
	} },
	"tintes",
	{ pestana = "filtros", filas = {
		{ titulo = L["Fuerza del tinte"], activa = function() return (N.Get(ID, "tinte") or "ninguno") ~= "ninguno" end,
			control = deslizador("tinteFuerza", 0.1, 1, 0.05), buscar = "tint strength" },
		{ titulo = L["Quitar todos los filtros"], texto = L["Apaga la viñeta, el grano, las barras y el tinte de un clic."],
			control = function(fila) return K.Boton(fila, L["Quitar filtros"], function() M.Filtros.Quitar() end, { tipo = "secundario", tam = "chico" }) end,
			activa = function() return M.Filtros.Activos() and true or false end, buscar = "remove filters clear" },
	} },
	{ pestana = "avanzado", titulo = L["Herramientas"], filas = {
		{ titulo = L["Volver a poner mis valores al entrar"], control = interruptor("reaplicar"),
			texto = L["Cuando el juego termina de cargar, Alfa revisa lo que elegiste aquí y lo vuelve a poner si algo lo cambió. Si después los cambias en el menú del juego, Alfa se queda con lo nuevo."],
			buscar = "reapply login keep settings" },
		{ titulo = L["Reiniciar los gráficos"], texto = L["Algunos ajustes, como el HDR, se ven hasta reiniciar los gráficos. Te pide confirmación."],
			control = function(fila) return K.Boton(fila, L["Reiniciar gráficos"], function() M.PedirReinicio() end, { tipo = "secundario", tam = "chico" }) end,
			buscar = "restart graphics gx" },
		{ titulo = L["Todo como estaba antes de Alfa"], texto = L["Devuelve cada ajuste que Alfa tocó al valor que tenía antes y deja de mantenerlos."],
			activa = function() return M.HayOriginales() end,
			control = function(fila) return K.Boton(fila, L["Volver a lo de antes"], function()
				K.Dialogo({ titulo = L["¿Volver a lo de antes?"], texto = L["Cada ajuste que Alfa cambió vuelve al valor que tenía antes. Los filtros no cambian."],
					aceptar = L["Volver a lo de antes"], peligro = true, alAceptar = function() M.VolverOriginal() end })
			end, { tipo = "peligro", tam = "chico" }) end,
			buscar = "restore original reset all" },
	} },
}

---------------------------------------------------------------------------
-- La ventana
---------------------------------------------------------------------------
local NOMBRE_PESTANA = {}
for _, p in ipairs(M.PESTANAS) do NOMBRE_PESTANA[p.id] = p.nombre end

local function estadoTexto()
	local partes = {}
	local n = M.Elegidas()
	if M.EnCombate() then
		partes[#partes + 1] = K.Tenir("aviso", L["Estás en combate: lo que cambies se aplica en cuanto termine."])
	elseif M.Pendientes() > 0 then
		partes[#partes + 1] = K.Tenir("aviso", N.Plural(M.Pendientes(), L["%d cambio espera al combate."], L["%d cambios esperan al combate."]))
	elseif n == 0 then
		partes[#partes + 1] = L["Alfa solo leyó tus valores: nada cambia hasta que toques un control."]
	elseif N.Get(ID, "reaplicar") == false then
		partes[#partes + 1] = N.Plural(n, L["Cambiaste %d ajuste aquí. Volver a ponerlo al entrar está apagado (Avanzado)."], L["Cambiaste %d ajustes aquí. Volver a ponerlos al entrar está apagado (Avanzado)."])
	else
		partes[#partes + 1] = N.Plural(n, L["Alfa mantiene %d ajuste tuyo y lo vuelve a poner al entrar."], L["Alfa mantiene %d ajustes tuyos y los vuelve a poner al entrar."])
	end
	partes[#partes + 1] = format(L["La %s también está en el menú del juego."], estrella())
	local _, faltan = M.Conteo()
	if #faltan > 0 then partes[#partes + 1] = format(L["Este cliente no tiene %d de estos ajustes: no se muestran."], #faltan) end
	return concat(partes, " ")
end

local function actualizarPie()
	local reinicio = M.NecesitaReinicio()
	if V.pieReinicio ~= reinicio then
		V.pieReinicio = reinicio
		V.BotonReinicio:SetShown(reinicio)
		local izq = { V.BotonDeshacer }
		if reinicio then izq[#izq + 1] = V.BotonReinicio end
		v:SetPie({ V.BotonCerrar }, izq)
	end
	V.BotonDeshacer:SetActivo(M.PuedeDeshacer())
end

function V.Acomodar()
	if not v then return end
	local w = v:AnchoCuerpo()
	local m = v.margen
	local cuerpo = v.Cuerpo
	V.Tabs:Acomodar(w - ANCHO_BUSCAR - ESP.base)
	V.Tabs:ClearAllPoints()
	V.Tabs:SetPoint("TOPLEFT", cuerpo, "TOPLEFT", m, -ESP.base)
	V.Buscar:ClearAllPoints()
	V.Buscar:SetWidth(ANCHO_BUSCAR)
	V.Buscar:SetPoint("TOPRIGHT", cuerpo, "TOPRIGHT", -m, -ESP.base)
	local y = ESP.base + K.ALTO.control + ESP.m
	K.Escribir(V.Estado, estadoTexto())
	V.Estado:ClearAllPoints()
	V.Estado:SetPoint("TOPLEFT", cuerpo, "TOPLEFT", m, -y)
	y = y + K.Parrafo(V.Estado, w, 2) + ESP.m
	local d = V.Desp
	d:ClearAllPoints()
	d:SetPoint("TOPLEFT", cuerpo, "TOPLEFT", m, -y)
	d:Acomodar(w + 12, max(100, v:AltoCuerpo() - y - ESP.xs))
	V.Pila:ClearAllPoints()
	V.Pila:SetPoint("TOPLEFT", d.Contenido, "TOPLEFT", 0, 0)
	local h = V.Pila:Acomodar(w)
	d:SetAltoContenido(h + ESP.l)
end

function V.Rehacer()
	if not (v and v:IsShown()) then return end
	local filtro = V.filtro
	local buscando = filtro ~= ""
	local total = 0
	for _, b in ipairs(V.bloques) do
		local mostrar
		if b.filas then
			local visibles = 0
			for _, fila in ipairs(b.filas) do
				local def = fila.def
				local hay = not def.cvar or M.Existe(def.cvar)
				if hay and buscando then hay = coincide(def, filtro) end
				K.Mostrar(fila, hay)
				if hay then
					visibles = visibles + 1
					if def.cvar then pintarFila(fila) else fila:Refrescar() end
				end
			end
			if b.info then K.Mostrar(b.info, visibles > 0 and not buscando) end
			mostrar = visibles > 0 and (buscando or b.pestana == V.pestana)
			if b.ga.Seccion and b.titulo then
				b.ga.Seccion:Set(buscando and (NOMBRE_PESTANA[b.pestana] .. " · " .. b.titulo) or b.titulo)
			end
		elseif b.b.buscar then
			if buscando then
				local ok = true
				for palabra in filtro:gmatch("%S+") do if not b.b.buscar:find(palabra, 1, true) then ok = false end end
				mostrar = ok
			else
				mostrar = b.pestana == V.pestana
			end
		else
			mostrar = not buscando and b.pestana == V.pestana
		end
		if mostrar and b.b.Refrescar then b.b:Refrescar() end
		K.Mostrar(b.b, mostrar)
		if mostrar then total = total + 1 end
	end
	K.Mostrar(V.Vacio, buscando and total == 0)
	V.Tabs:SetValor(not buscando and V.pestana or nil)
	actualizarPie()
	V.Acomodar()
end

local function agregarGrupo(def)
	local ga = K.GrupoAjustes(V.Pila, { titulo = def.titulo })
	local b = { b = ga, ga = ga, pestana = def.pestana, titulo = def.titulo, filas = {} }
	if def.info then
		b.info = ga:Fila({ titulo = def.info.titulo, texto = def.info.texto })
		b.info.def = def.info
	end
	for _, f in ipairs(def.filas) do
		local fila
		if f.cvar then
			fila = filaCVar(ga, f)
		else
			fila = ga:Fila({ titulo = f.titulo, texto = f.texto, hija = f.hija, activa = f.activa, control = f.control })
			fila.def = f
		end
		b.filas[#b.filas + 1] = fila
	end
	V.Pila:Agregar(ga, { espacio = ESP.l })
	V.bloques[#V.bloques + 1] = b
end

local function crear()
	if v then return v end
	v = K.Ventana({ nombre = "AlfaVistaVentana", titulo = L["Paisaje y gráficos"],
		subtitulo = L["Lo que el menú del juego no enseña, a tu gusto"], icono = "ic-paisaje",
		ancho = ANCHO, alto = ALTO, alCerrar = function() K.CerrarMenu() end })
	V.v = v
	local cuerpo = v.Cuerpo
	local opciones = {}
	for _, p in ipairs(M.PESTANAS) do opciones[#opciones + 1] = { valor = p.id, texto = p.nombre } end
	-- Una pestaña guardada que ya no existe (de otra versión) vuelve a Calidad.
	local guardada = N.Datos(ID).pestana
	V.pestana = NOMBRE_PESTANA[guardada] and guardada or "calidad"
	V.Tabs = K.Segmentos(cuerpo, { estilo = "segmentos", opciones = opciones, valor = V.pestana,
		alCambiar = function(id)
			V.pestana = id
			N.Datos(ID).pestana = id
			if V.filtro ~= "" then V.Buscar:SetTexto("", true) V.filtro = "" end
			V.Desp:IrArriba()
			V.Rehacer()
		end })
	V.Buscar = K.Buscador(cuerpo, { ayuda = L["Buscar: pasto, niebla, sombras..."], alCambiar = function(texto)
		V.filtro = plano(texto)
		V.Desp:IrArriba()
		V.Rehacer()
	end })
	V.Estado = K.Texto(cuerpo, "nota", "textoSuave")
	V.Desp = K.Desplazable(cuerpo)
	V.Pila = K.Pila(V.Desp.Contenido, { espacio = ESP.l })
	V.bloques = {}

	local presets = bloquePresets(V.Pila)
	V.Pila:Agregar(presets)
	V.bloques[#V.bloques + 1] = { b = presets, pestana = "calidad" }
	for _, g in ipairs(M.GRUPOS) do agregarGrupo(g) end
	local nota = bloqueNota(V.Pila, L["Estos filtros los dibuja Alfa, no el juego: quedan detrás de toda la interfaz (nunca la tapan) y también se ven con la interfaz oculta (Alt+Z), para tus capturas."])
	V.Pila:Agregar(nota)
	V.bloques[#V.bloques + 1] = { b = nota, pestana = "filtros" }
	for _, g in ipairs(EXTRA) do
		if g == "tintes" then
			local t = bloqueTintes(V.Pila)
			V.Pila:Agregar(t)
			V.bloques[#V.bloques + 1] = { b = t, pestana = "filtros" }
		else
			agregarGrupo(g)
		end
	end
	V.Vacio = K.Vacio(V.Pila, { lobo = "vacio", titulo = L["Nada coincide"], texto = L["Prueba con otra palabra, como «pasto», «niebla» o «sombras»."] })
	V.Pila:Agregar(V.Vacio)

	V.BotonCerrar = K.Boton(v, L["Cerrar"], function() v:Cerrar() end, { tipo = "secundario" })
	V.BotonDeshacer = K.Boton(v, L["Deshacer preajuste"], function() M.Deshacer() end, { tipo = "fantasma" })
	K.ConInfo(V.BotonDeshacer, L["Deshacer preajuste"], L["Devuelve los valores que tenías antes del último preajuste."])
	V.BotonReinicio = K.Boton(v, L["Reiniciar gráficos"], function() M.PedirReinicio() end, { tipo = "acento" })
	V.pieReinicio = nil
	actualizarPie()

	v.alAcomodar = function() V.Acomodar() end
	v:HookScript("OnShow", function()
		M.Sincronizar()
		V.Rehacer()
	end)
	return v
end

function V.Abrir(pestana)
	crear()
	if pestana and NOMBRE_PESTANA[pestana] then
		V.pestana = pestana
		if V.filtro ~= "" then V.Buscar:SetTexto("", true) V.filtro = "" end
	end
	v:Abrir()
	V.Rehacer()
end

function V.Cerrar() if v then v:Cerrar() end end
function V.Visible() return v and v:IsShown() or false end

M.AlCambiar(function() if v and v:IsShown() then V.Rehacer() end end)
A.On("SETTING_CHANGED", function(path)
	if not (v and v:IsShown()) or type(path) ~= "string" then return end
	if path == "" or path == ID or path:sub(1, #ID + 1) == ID .. "." or path == "comodidades.camara" then V.Rehacer() end
end)
