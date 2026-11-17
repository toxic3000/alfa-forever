-- Alfa - Combate: la ventana del medidor de daño (Toxic / La Jauría). GPL-3.0.
--
-- Una ventana del Kit, compacta y movible, con el top de tu grupo o banda:
-- la pelea actual, la anterior o todo, en DPS, daño, CPS o curación, con
-- barras del color de cada clase y tu fila marcada. Abajo, "Anunciar" (solo
-- con tu clic, fuera de combate) y "Empezar de cero".
--   * No se cierra con Esc (es para tenerla a la vista al pelear): con su X,
--     con /alfa dps o desde la página. Recuerda su lugar y crece hacia abajo.
--   * Los valores secretos van directo a la barra y al texto, sin aritmética.
-- También da las filas del top a la página (M.CrearFila, M.PintarFila).

local ADDON, M = ...
local N, A, K, L = M.N, M.A, M.K, M.L
local D = M.Medidor
local V = {}
M.Ventana = V

local type, ipairs, pairs, pcall, floor, max, min, format, tonumber = type, ipairs, pairs, pcall, math.floor, math.max, math.min, string.format, tonumber
local ESP = K.ESP

---------------------------------------------------------------------------
-- Una fila del top (la usa también la página)
---------------------------------------------------------------------------
local BLANCO = "Interface\\Buttons\\WHITE8X8"

local function infoFila(self)
	local x, r = self.alfaDato, self.alfaLectura
	if not (x and r) then return nil end
	if M.Secreto(x.nombre) or M.Secreto(x.valor) or M.Secreto(x.porSeg) then
		return L["En combate"], L["El juego oculta los números exactos mientras peleas: la barra y la cifra se ven, el detalle al salir de combate."]
	end
	local t = r.tipo
	local lineas = {}
	if t.porSeg then
		lineas[#lineas + 1] = format("%s: %s", t.texto, D.Numero(x.porSeg))
		lineas[#lineas + 1] = format("%s: %s", t.curacion and L["Curación"] or L["Daño"], D.Numero(x.valor))
	else
		lineas[#lineas + 1] = format("%s: %s", t.texto, D.Numero(x.valor))
		lineas[#lineas + 1] = format("%s: %s", t.curacion and L["CPS"] or L["DPS"], D.Numero(x.porSeg))
	end
	local total = r.total
	if not M.Secreto(total) and type(total) == "number" and total > 0 and type(x.valor) == "number" then
		lineas[#lineas + 1] = format(L["%d %% del total"], floor(x.valor * 100 / total + 0.5))
	end
	return tostring(x.nombre or "?"), lineas
end

function M.CrearFila(padre, alto)
	local f = CreateFrame("Frame", nil, padre)
	f:SetHeight(alto or 22)
	f:EnableMouse(true)
	f.Pista = K.Plano(f, "hundido", "BACKGROUND", 0)
	f.Pista:SetAllPoints(f)
	f.Barra = CreateFrame("StatusBar", nil, f)
	f.Barra:SetAllPoints(f)
	f.Barra:SetStatusBarTexture(BLANCO)
	f.Barra:SetMinMaxValues(0, 1)
	f.Barra:SetValue(0)
	f.Yo = K.Plano(f.Barra, "acento", "OVERLAY", 2)
	f.Yo:SetWidth(3)
	f.Yo:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	f.Yo:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
	f.Pos = K.Texto(f.Barra, "numero", "textoSuave")
	f.Pos:SetJustifyH("RIGHT")
	f.Pos:SetWidth(20)
	f.Pos:SetPoint("LEFT", f, "LEFT", 4, 0)
	f.Valor = K.Texto(f.Barra, "numero", "texto")
	f.Valor:SetJustifyH("RIGHT")
	f.Valor:SetPoint("RIGHT", f, "RIGHT", -ESP.s, 0)
	f.Otro = K.Texto(f.Barra, "pequeno", "textoTenue")
	f.Otro:SetJustifyH("RIGHT")
	f.Otro:SetPoint("RIGHT", f.Valor, "LEFT", -ESP.s, 0)
	f.Nombre = K.Texto(f.Barra, "cuerpo", "texto")
	f.Nombre:SetPoint("LEFT", f.Pos, "RIGHT", ESP.s, 0)
	f.Nombre:SetPoint("RIGHT", f.Otro, "LEFT", -ESP.s, 0)
	K.ConInfo(f, infoFila)
	return f
end

-- x: una fila de D.Leer; r: la lectura completa.
function M.PintarFila(f, x, r)
	f.alfaDato, f.alfaLectura = x, r
	f.Pos:SetText(tostring(x.pos))
	if M.Secreto(x.nombre) then
		f.Nombre:SetText(x.nombre)
	else
		local n = type(x.nombre) == "string" and x.nombre or "?"
		K.Escribir(f.Nombre, (n:gsub("%-.*$", "")))
	end
	local cr, cg, cb = D.Color(x.clase)
	f.Barra:SetStatusBarColor(cr, cg, cb, 0.55)
	local tope = r.max
	if not M.Secreto(tope) and (type(tope) ~= "number" or tope <= 0) then tope = 1 end
	pcall(f.Barra.SetMinMaxValues, f.Barra, 0, tope)
	pcall(f.Barra.SetValue, f.Barra, x.valor or 0)
	local t = r.tipo
	local principal, otro = x.valor, x.porSeg
	if t.porSeg then principal, otro = x.porSeg, x.valor end
	f.Valor:SetText(D.Numero(principal))
	f.Otro:SetText(D.Numero(otro))
	f.Yo:SetShown(x.yo and true or false)
	K.ColorTexto(f.Pos, x.aparte and "acento" or "textoSuave")
end

---------------------------------------------------------------------------
-- La ventana
---------------------------------------------------------------------------
local ANCHO, FILA, GAP = 360, 22, 2
local CABECERA = K.ALTO.cabecera
local v

local function lugar()
	local d = N.Datos(M.ID)
	d.ventana = type(d.ventana) == "table" and d.ventana or nil
	return d
end

local function colocar()
	local p = lugar().ventana
	v:ClearAllPoints()
	if p and type(p[1]) == "number" and type(p[2]) == "number" then
		v:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p[1], p[2])
	else
		v:SetPoint("TOPRIGHT", UIParent, "RIGHT", -48, 220)
	end
end

local function guardar()
	local x, y = v:GetLeft(), v:GetTop()
	if type(x) ~= "number" or type(y) ~= "number" then return end
	lugar().ventana = { floor(x + 0.5), floor(y + 0.5) }
	colocar() -- arriba a la izquierda: al cambiar de alto, crece hacia abajo
end

local function opcionesSesion()
	local o = {}
	for _, s in ipairs(D.SESIONES) do o[#o + 1] = { valor = s.clave, texto = s.texto } end
	return o
end

local function opcionesTipo()
	local o = {}
	for _, t in ipairs(D.TIPOS) do o[#o + 1] = { valor = t.clave, texto = t.texto } end
	return o
end

local function crear()
	if v then return v end
	v = K.Ventana({ titulo = L["Medidor de daño"], icono = "ic-manada", ancho = ANCHO, alto = 200, capa = "MEDIUM" })
	local c = v.Cabecera
	c:HookScript("OnDragStop", guardar)
	if c.Cerrar then c.Cerrar.alClic = function() M.SetOpt("medidor", false) end end
	v.Ajustes = K.BotonIcono(c, "ic-ajustes", function() N.Abrir(M.ID) end, { tam = 28, icono = 14, ayuda = L["Ajustes del medidor"] })
	if c.Cerrar then v.Ajustes:SetPoint("RIGHT", c.Cerrar, "LEFT", -ESP.xs, 0) else v.Ajustes:SetPoint("RIGHT", c, "RIGHT", -ESP.m, 0) end
	function v:Abrir()
		if not self:IsShown() then colocar() end
		self:Show()
	end
	local cuerpo = v.Cuerpo
	v.Sesion = K.Segmentos(cuerpo, { estilo = "segmentos", opciones = opcionesSesion(), valor = M.Opt("sesion"),
		alCambiar = function(val) M.SetOpt("sesion", val) end })
	v.Tipo = K.Desplegable(cuerpo, { opciones = opcionesTipo(), clave = M.ID .. ".tipo", ancho = 104 })
	v.filas = {}
	-- Sin datos: el lobo, qué pasa y, si hace falta, el botón que lo arregla.
	local e = CreateFrame("Frame", nil, cuerpo)
	e.Lobo = e:CreateTexture(nil, "ARTWORK")
	e.Lobo:SetSize(40, 40)
	e.Lobo:SetPoint("TOPLEFT", e, "TOPLEFT", 0, 0)
	e.Titulo = K.Texto(e, "cuerpo", "texto")
	e.Texto = K.Texto(e, "nota", "textoSuave")
	e.Boton = K.Boton(e, "", nil, { tipo = "acento", tam = "chico" })
	v.Vacio = e
	-- Abajo: empezar de cero y anunciar.
	v.Cero = K.Boton(cuerpo, L["Empezar de cero"], function() D.PedirReiniciar() end, { tipo = "fantasma", tam = "chico", icono = "ic-cerrar" })
	v.Anunciar = K.Boton(cuerpo, L["Anunciar"], function() D.Anunciar(M.Opt("sesion"), M.Opt("tipo")) end, { tipo = "acento", tam = "chico", icono = "ic-manada" })
	K.ConInfo(v.Anunciar, function()
		local puede, porque = D.PuedeAnunciar(M.Opt("sesion"), M.Opt("tipo"))
		if puede then return L["Anunciar en el chat"], (L["Escribe el top %d en el chat de tu grupo o banda."]):format(tonumber(M.Opt("anunciar")) or 5) end
		return L["Ahora no se puede anunciar"], porque
	end)
	return v
end

local function vacio(e, w, titulo, texto, boton)
	e.Lobo:SetTexture(K.Lobo(boton and "atento" or "dormido"))
	e.Lobo:SetVertexColor(K.Color(boton and "acento" or "textoTenue"))
	local x = 40 + ESP.m
	local tw = w - x
	K.Escribir(e.Titulo, titulo)
	e.Titulo:ClearAllPoints()
	e.Titulo:SetPoint("TOPLEFT", e, "TOPLEFT", x, -2)
	e.Titulo:SetWidth(tw)
	e.Titulo:SetWordWrap(true)
	local y = 2 + K.AltoTexto(e.Titulo)
	K.Escribir(e.Texto, texto or "")
	e.Texto:ClearAllPoints()
	e.Texto:SetPoint("TOPLEFT", e, "TOPLEFT", x, -(y + 3))
	y = y + 3 + K.Parrafo(e.Texto, tw, 4)
	if boton then
		e.Boton:SetTexto(boton.texto)
		e.Boton.alClic = boton.alClic
		e.Boton:ClearAllPoints()
		e.Boton:SetPoint("TOPLEFT", e, "TOPLEFT", x, -(y + ESP.s))
		e.Boton:Show()
		y = y + ESP.s + K.ALTO.botonChico
	else
		e.Boton:Hide()
	end
	y = max(y, 40)
	e:SetSize(w, y)
	return y
end

-- El estado sin filas: -> titulo, texto, boton (o nil)
function M.EstadoMedidor(r)
	if not r.ok then
		return L["El medidor no está disponible"], r.motivo
	end
	if D.Encendido() == false then
		return L["El registro de daño del juego está apagado"],
			L["Alfa lee el medidor oficial del juego. Enciéndelo y aquí verás el daño de tu grupo; su ventana puedes ocultarla en el Modo de edición."],
			{ texto = L["Encender el registro"], alClic = function() D.Encender() end }
	end
	if r.sinAnterior then
		return L["Todavía no hay una pelea anterior"], L["Después de tu segunda pelea, aquí ves la de antes."]
	end
	return L["Todavía no hay peleas"], L["Cuando tú o tu grupo peleen, aquí sale quién hace más daño."]
end

-- El subtítulo: "Grupo · pelea actual · 1:23".
function M.SubtituloMedidor(r)
	local _, ctx = D.Contexto()
	local partes = { ctx }
	for _, s in ipairs(D.SESIONES) do if s.clave == r.sesion then partes[#partes + 1] = s.texto end end
	local dur = D.Tiempo(r.dur)
	if dur then partes[#partes + 1] = dur end
	return table.concat(partes, "  \194\183  ")
end

function V.Pintar()
	if not (v and v:IsShown()) then return end
	local filas = max(3, min(10, floor(tonumber(M.Opt("filas")) or 10)))
	local r = D.Leer(M.Opt("sesion"), M.Opt("tipo"), filas)
	v:SetTitulo(L["Medidor de daño"], M.SubtituloMedidor(r))
	v.Sesion:SetValor(M.Opt("sesion"))
	v.Tipo:SetValor(M.Opt("tipo"))
	local cuerpo = v.Cuerpo
	local m = ESP.m
	local w = ANCHO - 2 * m
	local y = m
	v.Sesion:Acomodar(w - 104 - ESP.s)
	v.Sesion:ClearAllPoints()
	v.Sesion:SetPoint("TOPLEFT", cuerpo, "TOPLEFT", m, -y)
	v.Tipo:ClearAllPoints()
	v.Tipo:SetPoint("TOPRIGHT", cuerpo, "TOPRIGHT", -m, -y)
	y = y + K.ALTO.control + ESP.s
	local n = #r.filas
	for i = 1, n do
		local f = v.filas[i] or M.CrearFila(cuerpo, FILA)
		v.filas[i] = f
		M.PintarFila(f, r.filas[i], r)
		f:ClearAllPoints()
		-- Tu fila fuera del top va separada.
		if r.filas[i].aparte then y = y + ESP.xs end
		f:SetPoint("TOPLEFT", cuerpo, "TOPLEFT", m, -y)
		f:SetWidth(w)
		f:Show()
		y = y + FILA + GAP
	end
	for i = n + 1, #v.filas do v.filas[i]:Hide() end
	if n == 0 then
		local titulo, texto, boton = M.EstadoMedidor(r)
		v.Vacio:ClearAllPoints()
		v.Vacio:SetPoint("TOPLEFT", cuerpo, "TOPLEFT", m, -(y + ESP.xs))
		y = y + ESP.xs + vacio(v.Vacio, w, titulo, texto, boton) + ESP.s
		v.Vacio:Show()
	else
		v.Vacio:Hide()
	end
	y = y + ESP.xs
	local puede = D.PuedeAnunciar(M.Opt("sesion"), M.Opt("tipo"))
	v.Anunciar:SetActivo(puede)
	v.Anunciar:SetShown(r.ok and n > 0)
	v.Cero:SetShown(r.ok and n > 0)
	v.Cero:ClearAllPoints()
	v.Cero:SetPoint("TOPLEFT", cuerpo, "TOPLEFT", m - 4, -y)
	v.Anunciar:ClearAllPoints()
	v.Anunciar:SetPoint("TOPRIGHT", cuerpo, "TOPRIGHT", -m, -y)
	if r.ok and n > 0 then y = y + K.ALTO.botonChico end
	y = y + m
	v:SetSize(ANCHO, CABECERA + y)
end

function V.Ver()
	local quiere = M.Opt("medidor") and true or false
	if quiere and M.Opt("medidorGrupo") and D.Contexto() == "solo" then quiere = false end
	if not quiere then
		if v then v:Hide() end
		return
	end
	crear()
	v:Abrir()
	v:SetAlpha(max(0.3, min(1, tonumber(M.Opt("opacidad")) or 1)))
	V.Pintar()
end

function V.Abierta() return v ~= nil and v:IsShown() end
function V.Marco() return v end

function V.Alternar() M.SetOpt("medidor", not M.Opt("medidor")) end
