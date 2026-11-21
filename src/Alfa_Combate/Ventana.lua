-- Alfa - Combate: la ventana del medidor de daño (toxic3000 / La Jauría). GPL-3.0.
--
-- 1.3.7 (pedido de Toxic: «una gráfica de barras con los de tu grupo, por
-- default y que no sea tan invasivo»). Una gráfica pequeña de 220 px con
-- barras de 16 px del color de cada clase:
--   * De fábrica en «automático» (combate.medidorModo = "auto"): sale sola en
--     grupo, en banda o dentro de una mazmorra; yendo solo por el mundo, no.
--     "siempre" la deja a la vista y "apagado" no la saca nunca sola.
--   * Arriba, una línea: «DPS · 1:23». Lo demás (qué se mide, qué pelea,
--     anunciar, empezar de cero, ajustes) va en su clic derecho.
--   * En grupo, 5 filas (tu grupo entero); en banda, combate.filasBanda. Tu
--     fila siempre se ve: si no estás en el top, sale al final, aparte.
--   * De fábrica abajo a la derecha, arriba de tus barras (sin taparlas, con
--     M.SinTapar de Resumen.lua). Se arrastra fuera de combate y también con
--     «Mover marcos» o «Acomodar la pantalla» (es un marco de M.Marco).
--   * Se atenúa 10 s después de la pelea; al pasar el ratón vuelve.
--   * En combate no atrapa clics: ni ella, ni su X, ni sus filas.
--   * Su X la esconde hasta tu próximo grupo (AlfaNucleoCharDB.combate.
--     medidorCerrado guarda si estabas en grupo al cerrarla). Para apagarla
--     del todo, Ajustes. /alfa dps la abre o la cierra a mano.
--   * Sin C_DamageMeter en el cliente nunca sale sola (la página explica
--     por qué). Con el registro del juego apagado, Lya lo dice una vez.
--   * Solo se repinta si algo cambió (fuera de combate, por una firma de lo
--     que se ve); en combate los números llegan secretos y se pintan tal cual.
-- También da las filas del top a la página (M.CrearFila, M.PintarFila).

local ADDON, M = ...
local N, A, K, L = M.N, M.A, M.K, M.L
local D = M.Medidor
local V = {}
M.Ventana = V

local type, ipairs, pairs, pcall, floor, max, min, format, tonumber, tostring = type, ipairs, pairs, pcall, math.floor, math.max, math.min, string.format, tonumber, tostring
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

-- compacta (1.3.7): la de la gráfica, con letra chica y sin la otra cifra.
function M.CrearFila(padre, alto, compacta)
	local f = CreateFrame("Frame", nil, padre)
	f:SetHeight(alto or 22)
	f:EnableMouse(true)
	f.alfaCompacta = compacta and true or nil
	f.Pista = K.Plano(f, "hundido", "BACKGROUND", 0)
	f.Pista:SetAllPoints(f)
	f.Barra = CreateFrame("StatusBar", nil, f)
	f.Barra:SetAllPoints(f)
	f.Barra:SetStatusBarTexture(BLANCO)
	f.Barra:SetMinMaxValues(0, 1)
	f.Barra:SetValue(0)
	f.Yo = K.Plano(f.Barra, "acento", "OVERLAY", 2)
	f.Yo:SetWidth(compacta and 2 or 3)
	f.Yo:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	f.Yo:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
	local letra = compacta and "pequeno" or "cuerpo"
	f.Pos = K.Texto(f.Barra, compacta and "pequeno" or "numero", "textoSuave")
	f.Pos:SetJustifyH("RIGHT")
	f.Pos:SetWidth(compacta and 14 or 20)
	f.Pos:SetPoint("LEFT", f, "LEFT", compacta and 2 or 4, 0)
	f.Valor = K.Texto(f.Barra, compacta and "pequeno" or "numero", "texto")
	f.Valor:SetJustifyH("RIGHT")
	f.Valor:SetPoint("RIGHT", f, "RIGHT", compacta and -ESP.xs or -ESP.s, 0)
	f.Otro = K.Texto(f.Barra, "pequeno", "textoTenue")
	f.Otro:SetJustifyH("RIGHT")
	f.Otro:SetPoint("RIGHT", f.Valor, "LEFT", compacta and 0 or -ESP.s, 0)
	f.Nombre = K.Texto(f.Barra, letra, "texto")
	f.Nombre:SetPoint("LEFT", f.Pos, "RIGHT", compacta and ESP.xs or ESP.s, 0)
	f.Nombre:SetPoint("RIGHT", f.Otro, "LEFT", -ESP.xs, 0)
	if compacta then f.Otro:Hide() end
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
	-- Un secreto va tal cual a SetValue (sin `or`, que lo compararía).
	local valor = x.valor
	if not M.Secreto(valor) and type(valor) ~= "number" then valor = 0 end
	pcall(f.Barra.SetValue, f.Barra, valor)
	local t = r.tipo
	local principal, otro = x.valor, x.porSeg
	if t.porSeg then principal, otro = x.porSeg, x.valor end
	f.Valor:SetText(D.Numero(principal))
	if f.alfaCompacta then f.Otro:SetText("") else f.Otro:SetText(D.Numero(otro)) end
	f.Yo:SetShown(x.yo and true or false)
	K.ColorTexto(f.Pos, x.aparte and "acento" or "textoSuave")
end

-- El estado sin filas: -> titulo, texto, boton (o nil)
function M.EstadoMedidor(r)
	if not r.ok then
		return L["El medidor no está disponible"], r.motivo
	end
	if D.Encendido() == false then
		return L["El registro de daño del juego está apagado"],
			L["Alfa lee el medidor oficial del juego. Enciéndelo y aquí verás el daño de tu grupo; su ventana puedes ocultarla en el Modo de edición."],
			D.AccionEncender()
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

---------------------------------------------------------------------------
-- La gráfica
---------------------------------------------------------------------------
V.ANCHO, V.FILA = 220, 16
local ANCHO, FILA, GAP, CAB, BORDE = V.ANCHO, V.FILA, 1, 20, 4
local ATENUA, TENUE = 10, 0.4
local PUNTO = { "BOTTOMRIGHT", "BOTTOMRIGHT", -16, 150 }
-- Abajo a la derecha, arriba de las barras; si tapa alguna, más a la izquierda o más arriba.
local LUGARES = { PUNTO, { "BOTTOMRIGHT", "BOTTOMRIGHT", -16, 200 }, { "BOTTOMRIGHT", "BOTTOMRIGHT", -100, 150 },
	{ "BOTTOMRIGHT", "BOTTOMRIGHT", -140, 150 }, { "BOTTOMRIGHT", "BOTTOMRIGHT", -190, 150 },
	{ "BOTTOMRIGHT", "BOTTOMRIGHT", -100, 220 }, { "BOTTOMRIGHT", "BOTTOMRIGHT", -240, 150 },
	{ "BOTTOMRIGHT", "BOTTOMRIGHT", -290, 180 } }

local v
local aMano = false   -- la abriste tú (/alfa dps, el menú): sale aunque vayas solo
local dichoX = false  -- «vuelve en tu próximo grupo», una vez por sesión

local function datos() return N.DatosPersonaje(M.ID) end

local function peleando()
	if M.enPelea then return true end
	return InCombatLockdown and InCombatLockdown() and true or false
end

local function base() return max(0.3, min(1, tonumber(M.Opt("opacidad")) or 1)) end

-- Lo que reciben el ratón: fuera de combate sí (se arrastra y tiene menú),
-- en combate nada.
local function raton(on)
	if not v then return end
	on = on and true or false
	v:EnableMouse(on)
	v.Cerrar:EnableMouse(on)
	for _, f in ipairs(v.filas) do f:EnableMouse(on) end
	if v.Vacio.Boton then v.Vacio.Boton:EnableMouse(on) end
end

local function brillar()
	if not v then return end
	N.Quitar("combate.medidorAtenuar")
	v.alfaTenue = nil
	v:SetAlpha(base())
end

local function atenuar()
	if not (v and v:IsShown()) or peleando() then return end
	if v.IsMouseOver and v:IsMouseOver() then
		N.Una("combate.medidorAtenuar", ATENUA, atenuar)
		return
	end
	v.alfaTenue = true
	v:SetAlpha(max(0.2, base() * TENUE))
end

local function pedirAtenuar()
	if peleando() then brillar() return end
	if v and v.alfaTenue then return end
	N.Una("combate.medidorAtenuar", ATENUA, atenuar)
end

local function colocar()
	if not v then return end
	M.SinTapar(v, "Medidor", LUGARES)
end

local function crearVacio(padre)
	local e = CreateFrame("Frame", nil, padre)
	e.Titulo = K.Texto(e, "pequeno", "texto")
	e.Texto = K.Texto(e, "pequeno", "textoSuave")
	e.Boton = K.Boton(e, "", nil, { tipo = "acento", tam = "chico" })
	return e
end

local function pintarVacio(e, w, titulo, texto, boton)
	local y = 0
	K.Escribir(e.Titulo, titulo)
	e.Titulo:ClearAllPoints()
	e.Titulo:SetPoint("TOPLEFT", e, "TOPLEFT", 0, 0)
	y = K.Parrafo(e.Titulo, w, 2)
	K.Escribir(e.Texto, texto or "")
	e.Texto:ClearAllPoints()
	e.Texto:SetPoint("TOPLEFT", e, "TOPLEFT", 0, -(y + 2))
	y = y + 2 + K.Parrafo(e.Texto, w, 4)
	if boton then
		e.Boton:SetTexto(boton.texto)
		e.Boton.alClic = boton.alClic
		K.SeguroDe(e.Boton, boton)
		e.Boton:ClearAllPoints()
		e.Boton:SetPoint("TOPLEFT", e, "TOPLEFT", 0, -(y + ESP.xs))
		e.Boton:Show()
		y = y + ESP.xs + K.ALTO.botonChico
	else
		e.Boton:Hide()
	end
	e:SetSize(w, y)
	return y
end

local function crear()
	if v then return v end
	v = M.Marco("Medidor", L["Medidor de daño"], ANCHO, CAB + 40, PUNTO)
	v.Fondo = CreateFrame("Frame", nil, v)
	v.Fondo:SetAllPoints(v)
	v.Fondo:SetFrameLevel(v:GetFrameLevel())
	v.Fondo.caja = K.Caja(v.Fondo, { fondo = "fondo", alfaFondo = 0.82, borde = "linea", corte = K.CORTE.chico })
	v.Titulo = K.Texto(v.Fondo, "pequeno", "textoSuave")
	v.Titulo:SetPoint("TOPLEFT", v, "TOPLEFT", BORDE + 2, -4)
	v.Titulo:SetPoint("RIGHT", v, "RIGHT", -22, 0)
	v.Cerrar = K.BotonIcono(v.Fondo, "ic-cerrar", function() V.Cerrar() end,
		{ tam = 16, icono = 9, ayuda = L["Esconder hasta tu próximo grupo"], ayudaTexto = L["Para apagarlo del todo, en Ajustes de Combate."] })
	v.Cerrar:SetPoint("TOPRIGHT", v, "TOPRIGHT", -2, -2)
	v.filas = {}
	v.Vacio = crearVacio(v.Fondo)
	-- Se arrastra directo (fuera de combate) y recuerda dónde la dejas (el
	-- OnDragStop de M.Marco). Clic derecho: el menú.
	v:SetScript("OnDragStart", function(self) if not peleando() then self:StartMoving() end end)
	v:SetScript("OnMouseUp", function(self, boton)
		if boton == "RightButton" and not peleando() then V.Menu(self) end
	end)
	v:SetScript("OnEnter", function(self)
		if peleando() then return end
		brillar()
		if M.Desbloqueado() then return end
		K.MostrarInfo(self, L["Medidor de daño"], L["Arrástralo para moverlo. Clic derecho: qué se mide, anunciar y más."])
	end)
	v:SetScript("OnLeave", function(self)
		K.OcultarInfo(self)
		pedirAtenuar()
	end)
	v:SetScript("OnHide", function() N.Quitar("combate.medidorAtenuar") end)
	v:Hide()
	return v
end

-- Cuántas filas: en grupo (o solo) 5, tu grupo entero; en banda, las que elijas.
function V.Filas()
	if D.Contexto() == "banda" then return max(5, min(20, floor(tonumber(M.Opt("filasBanda")) or 8))) end
	return 5
end

local function firma(r, filas)
	if r.secreto then return nil end
	local p = { tostring(r.ok), tostring(r.vacia), tostring(r.sinAnterior), tostring(r.motivo), r.tipo.clave, tostring(r.sesion),
		tostring(r.dur and floor(r.dur) or ""), tostring(r.max), filas, tostring(D.Encendido()) }
	for _, x in ipairs(r.filas) do
		p[#p + 1] = format("%s|%s|%s|%s|%s|%s|%s", tostring(x.pos), tostring(x.nombre), tostring(x.clase), tostring(x.valor),
			tostring(x.porSeg), x.yo and "y" or "", x.aparte and "a" or "")
	end
	return table.concat(p, ";")
end

V.pintadas = 0 -- para el banco: cuántas veces se repintó de verdad

-- forzar: repinta aunque no haya cambiado nada (al abrirla, al cambiar un ajuste).
function V.Pintar(forzar)
	if not (v and v:IsShown()) then return end
	local filas = V.Filas()
	local r = D.Leer(M.Opt("sesion"), M.Opt("tipo"), filas)
	local fr = firma(r, filas)
	if not forzar and fr and fr == v.alfaFirma then return end
	v.alfaFirma = fr
	V.pintadas = V.pintadas + 1
	-- La cabecera: «DPS · 1:23» (y la pelea, si no es la de ahora).
	local partes = { r.tipo.texto }
	if r.sesion ~= "actual" then
		for _, s in ipairs(D.SESIONES) do if s.clave == r.sesion then partes[#partes + 1] = s.texto end end
	end
	local dur = D.Tiempo(r.dur)
	if dur then partes[#partes + 1] = dur end
	K.Escribir(v.Titulo, table.concat(partes, " \194\183 "))
	local w = ANCHO - 2 * BORDE
	local y = CAB
	local n = #r.filas
	local enCombate = peleando()
	for i = 1, n do
		local f = v.filas[i]
		if not f then
			f = M.CrearFila(v.Fondo, FILA, true)
			v.filas[i] = f
			-- Sobre una fila también se arrastra la gráfica y sale su menú.
			f:RegisterForDrag("LeftButton")
			f:SetScript("OnDragStart", function() local s = v:GetScript("OnDragStart") if s then s(v) end end)
			f:SetScript("OnDragStop", function() local s = v:GetScript("OnDragStop") if s then s(v) end end)
			f:SetScript("OnMouseUp", function(_, boton) if boton == "RightButton" and not peleando() then V.Menu(v) end end)
			f:HookScript("OnEnter", function() if not peleando() then brillar() end end)
			f:HookScript("OnLeave", function() pedirAtenuar() end)
		end
		M.PintarFila(f, r.filas[i], r)
		if r.filas[i].aparte then y = y + 2 end
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", v, "TOPLEFT", BORDE, -y)
		f:SetWidth(w)
		f:EnableMouse(not enCombate)
		f:Show()
		y = y + FILA + GAP
	end
	for i = n + 1, #v.filas do v.filas[i]:Hide() end
	if n == 0 then
		local titulo, texto, boton = M.EstadoMedidor(r)
		v.Vacio:ClearAllPoints()
		v.Vacio:SetPoint("TOPLEFT", v, "TOPLEFT", BORDE + 2, -y)
		y = y + pintarVacio(v.Vacio, w - 4, titulo, texto, boton) + 2
		v.Vacio.Boton:EnableMouse(not enCombate)
		v.Vacio:Show()
	else
		v.Vacio:Hide()
	end
	local alto = floor(y + BORDE + 0.5)
	if alto ~= v.alfaAlto then
		v.alfaAlto = alto
		v:SetSize(ANCHO, alto)
		colocar()
	end
end

---------------------------------------------------------------------------
-- Cuándo sale
---------------------------------------------------------------------------
local OTROS = { "Details", "Recount", "Skada" }
-- El nombre del otro medidor cargado, o nil.
function V.OtroMedidor()
	local cargado = (C_AddOns and C_AddOns.IsAddOnLoaded) or rawget(_G, "IsAddOnLoaded")
	if type(cargado) ~= "function" then return nil end
	for _, n in ipairs(OTROS) do
		if M.Legible(M.Llamar(cargado, n)) == true then return n end
	end
	return nil
end

-- -> sale, por qué (para la página y el banco): "mover", "mano", "apagado",
--    "sinMedidor", "cerrada", "siempre", "otroMedidor", "grupo", "solo"
function V.Quiere()
	if M.Desbloqueado() then return true, "mover" end
	local d = datos()
	local g = M.EnGrupo()
	-- La X vale hasta tu próximo grupo: cambiaste de «en grupo» a «solo» (o al revés).
	if d.medidorCerrado ~= nil and d.medidorCerrado ~= g then d.medidorCerrado = nil end
	if aMano then return true, "mano" end
	local modo = M.ModoMedidor()
	if modo == "apagado" then return false, "apagado" end
	if not D.Existe() then return false, "sinMedidor" end
	if d.medidorCerrado ~= nil then return false, "cerrada" end
	if modo == "siempre" then return true, "siempre" end
	-- Con otro medidor (Details, Recount, Skada) el automático no sale: verías dos.
	if V.OtroMedidor() then return false, "otroMedidor" end
	if g then return true, "grupo" end
	return false, "solo"
end

-- 27: el registro del juego apagado, una sola vez por cuenta (Lya lo dice si
-- está a la vista: K.Aviso pasa por ella).
local function avisarRegistro()
	if not D.Existe() or D.Encendido() ~= false then return end
	local d = N.Datos(M.ID)
	if d.avisoRegistro then return end
	d.avisoRegistro = true
	local libre = N.AlLibre or function(_, f) f() end
	libre("combate.avisoRegistro", function()
		K.Aviso({ titulo = L["El medidor del juego está apagado"], icono = "ic-manada", duracion = 14,
			texto = L["Alfa lee el medidor oficial del juego para mostrarte el daño de tu grupo."] .. " " .. D.ComoEncender() })
	end, 3)
end

function V.Ver()
	local quiere = V.Quiere()
	if not quiere then
		if v then v:Hide() end
		return
	end
	crear()
	if not v:IsShown() then
		v.alfaFirma, v.alfaAlto = nil, nil
		v:Show()
	end
	raton(not peleando())
	if peleando() then brillar() elseif not v.alfaTenue then v:SetAlpha(base()) pedirAtenuar() end
	V.Pintar(true)
	avisarRegistro()
end

-- Al empezar y al terminar la pelea (Combate.lua): el ratón y la luz.
function V.Pelea(empieza)
	if not (v and v:IsShown()) then return end
	raton(not empieza)
	if empieza then brillar() else pedirAtenuar() end
end

function V.Abierta() return v ~= nil and v:IsShown() end
function V.Marco() return v end
function V.Tenue() return v ~= nil and v.alfaTenue == true end

-- La X: hasta tu próximo grupo.
function V.Cerrar()
	aMano = false
	datos().medidorCerrado = M.EnGrupo()
	if v then v:Hide() end
	if not dichoX then
		dichoX = true
		N.Imprimir(L["El medidor vuelve en tu próximo grupo. Para apagarlo del todo, en Ajustes de Combate."])
	end
	M.Avisar()
end

-- /alfa dps y el menú de Alfa: a la vista o fuera.
function V.Alternar()
	if V.Abierta() then
		V.Cerrar()
	else
		aMano = true
		datos().medidorCerrado = nil
		V.Ver()
		M.Avisar()
	end
end

-- Salir de un grupo cuenta como «próximo grupo» para lo que abriste a mano.
function V.CambioDeGrupo()
	if aMano and not M.EnGrupo() and M.ModoMedidor() ~= "siempre" then aMano = false end
	V.Ver()
end

---------------------------------------------------------------------------
-- El clic derecho
---------------------------------------------------------------------------
function V.Opciones()
	local o = {}
	for _, t in ipairs(D.TIPOS) do o[#o + 1] = { valor = "tipo:" .. t.clave, texto = t.texto } end
	o[#o + 1] = { separador = true }
	local actual = M.Opt("sesion")
	for _, s in ipairs(D.SESIONES) do
		o[#o + 1] = { valor = "sesion:" .. s.clave, texto = format(L["Pelea: %s"], s.texto), icono = s.clave == actual and "ic-exito" or nil }
	end
	o[#o + 1] = { separador = true }
	local puede, porque = D.PuedeAnunciar(M.Opt("sesion"), M.Opt("tipo"))
	o[#o + 1] = { valor = "anunciar", texto = L["Anunciar en el chat"], icono = "ic-manada", apagada = not puede, motivo = porque }
	o[#o + 1] = { valor = "cero", texto = L["Empezar de cero"], icono = "ic-cerrar" }
	o[#o + 1] = { valor = "ajustes", texto = L["Ajustes del medidor"], icono = "ic-ajustes" }
	o[#o + 1] = { valor = "esconder", texto = L["Esconder hasta tu próximo grupo"] }
	return o
end

function V.Elegir(valor)
	if type(valor) ~= "string" then return end
	local tipo = valor:match("^tipo:(.+)$")
	local sesion = valor:match("^sesion:(.+)$")
	if tipo then M.SetOpt("tipo", tipo)
	elseif sesion then M.SetOpt("sesion", sesion)
	elseif valor == "anunciar" then D.Anunciar(M.Opt("sesion"), M.Opt("tipo"))
	elseif valor == "cero" then D.PedirReiniciar()
	elseif valor == "ajustes" then N.Abrir(M.ID)
	elseif valor == "esconder" then V.Cerrar() end
end

function V.Menu(dueno)
	if peleando() then return end
	K.Menu(dueno or v, V.Opciones(), "tipo:" .. tostring(M.Opt("tipo")), V.Elegir, 190)
end

A.OnLogin(function()
	M.Ensenar({ id = "combate.medidor", icono = "ic-manada",
		pregunta = L["¿Dónde veo el daño de mi grupo?"],
		respuesta = L["En grupo, en banda o en una mazmorra sale sola una gráfica pequeña abajo a la derecha con el daño de cada quien. Clic derecho sobre ella para cambiar lo que mide o anunciarlo; su X la esconde hasta tu próximo grupo. También con /alfa dps."] })
end)
