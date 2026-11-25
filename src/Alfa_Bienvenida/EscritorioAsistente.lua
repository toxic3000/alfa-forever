-- Alfa - Bienvenida: el asistente de «Dos pantallas» (1.3.8).
-- toxic3000 / La Jauría. GPL-3.0.
--
-- 1.4.0: dos pasos (antes tres) con el dibujo de tus monitores arriba, que
-- cambia al momento:
--   1. Tus monitores: lo que Alfa ve de tu ventana, la proporción del
--      principal (16:9, 21:9, 16:10 o a la medida con una barra) y de qué
--      lado está el otro. Si la ventana todavía es de un monitor, cómo
--      estirarla (antes era un paso entero de instrucciones).
--   2. Pruébalo: «Ver cómo queda» pone el escritorio de verdad donde va, sin
--      mover nada (Es.VistaPrevia); «Probar 15 segundos» lo pone ya y, si no
--      dices «Sí», vuelve solo a como estaba (Es.Probar). Mientras ves o
--      pruebas, el asistente se esconde y regresa si vuelves atrás.
--   M.EscritorioAsistente.Abrir() / Cerrar() / Paso(n) / Estado() (el banco)

local _, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ESP = K.ESP
local Es = M.Escritorio

local type, ipairs, tonumber, pairs = type, ipairs, tonumber, pairs
local floor, max, min, abs = math.floor, math.max, math.min, math.abs
local format = string.format

local As = {}
M.EscritorioAsistente = As

local ANCHO, ALTO = 760, 640
local PASOS = { "Tus monitores", "Pruébalo" }
local v       -- la ventana
local ui = {}
local est = { paso = 1 }

local function opt(k) return N.Get(Es.ID, k) end

function As.Estado() return est end

---------------------------------------------------------------------------
-- El dibujo de tus monitores
---------------------------------------------------------------------------
local function rect(padre, capa, sub)
	local t = padre:CreateTexture(nil, capa or "ARTWORK", nil, sub or 0)
	t:SetTexture(K.Ruta("white"))
	return t
end

local function armarDibujo(padre)
	local d = CreateFrame("Frame", nil, padre)
	d:SetHeight(230)
	d.Marco = CreateFrame("Frame", nil, d)
	d.Marco.caja = K.Caja(d.Marco, { fondo = "hundido", borde = "lineaFuerte", corte = K.CORTE.panel })
	-- El juego: el cielo, el suelo y las piezas de la interfaz.
	d.Juego = CreateFrame("Frame", nil, d.Marco)
	d.Cielo = rect(d.Juego, "BACKGROUND", 1)
	d.Cielo:SetAllPoints(d.Juego)
	d.Suelo = rect(d.Juego, "BACKGROUND", 2)
	d.Suelo:SetPoint("BOTTOMLEFT", d.Juego, "BOTTOMLEFT", 0, 0)
	d.Suelo:SetPoint("BOTTOMRIGHT", d.Juego, "BOTTOMRIGHT", 0, 0)
	d.Barra1 = rect(d.Juego, "ARTWORK", 1)
	d.Barra2 = rect(d.Juego, "ARTWORK", 1)
	d.Mini = d.Juego:CreateTexture(nil, "ARTWORK", nil, 2)
	d.Mini:SetTexture("Interface\\AddOns\\Alfa\\Media\\Nav\\ring")
	d.Chat = rect(d.Juego, "ARTWORK", 1)
	d.Retrato = rect(d.Juego, "ARTWORK", 1)
	d.EtJuego = K.Texto(d.Juego, "encabezado", "texto")
	d.EtJuegoSub = K.Texto(d.Juego, "pequeno", "textoSuave")
	-- Alfa: su fondo, su barra y sus paneles (los de tu distribución).
	d.Alfa = CreateFrame("Frame", nil, d.Marco)
	d.AlfaFondo = rect(d.Alfa, "BACKGROUND", 1)
	d.AlfaFondo:SetAllPoints(d.Alfa)
	d.AlfaBarra = rect(d.Alfa, "BACKGROUND", 2)
	d.AlfaBarra:SetPoint("TOPLEFT", d.Alfa, "TOPLEFT", 0, 0)
	d.AlfaBarra:SetPoint("TOPRIGHT", d.Alfa, "TOPRIGHT", 0, 0)
	d.AlfaBarra:SetHeight(8)
	d.Lobo = d.Alfa:CreateTexture(nil, "ARTWORK", nil, 3)
	d.Lobo:SetTexture(K.Lobo("normal"))
	-- Su nombre va en una placa encima de los paneles.
	d.Placa = CreateFrame("Frame", nil, d.Alfa)
	d.Placa:SetFrameLevel(d.Alfa:GetFrameLevel() + 10)
	d.Placa.caja = K.Caja(d.Placa, { fondo = "fondo", borde = "acento", corte = K.CORTE.chico })
	d.EtAlfa = K.Texto(d.Placa, "encabezado", "texto")
	d.EtAlfaSub = K.Texto(d.Placa, "pequeno", "textoSuave")
	d.paneles = {}
	-- La raya entre los dos monitores.
	d.Corte = rect(d.Marco, "OVERLAY", 2)
	d.Medida = K.Texto(d, "pequeno", "textoTenue")
	d.Medida:SetPoint("BOTTOM", d, "BOTTOM", 0, 0)
	return d
end

local function pintarDibujo(d, ancho)
	local g = Es.Geometria({ lado = est.lado, proporcion = est.proporcion, medida = est.medida })
	local W, H = Es.Pantalla()
	local ratio = W / max(1, H)
	-- 1.4.0 (85): con la interfaz grande (768 de alto) la ventana medía 824 y
	-- se salía por arriba: en pantallas bajas el dibujo se achica.
	local pant = K.num(UIParent:GetHeight(), 1080)
	local maxW, maxH = ancho - ESP.base * 2, pant < 900 and max(120, 196 - (900 - pant)) or 196
	local w, h = maxW, maxW / ratio
	if h > maxH then h, w = maxH, maxH * ratio end
	w, h = floor(w), floor(h)
	d:SetSize(ancho, maxH + 24)
	d.Marco:ClearAllPoints()
	d.Marco:SetPoint("TOP", d, "TOP", 0, 0)
	d.Marco:SetSize(w + 4, h + 4)
	local function en(f, r)
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", d.Marco, "TOPLEFT", 2 + floor(r[1] * w), -(2 + floor(r[2] * h)))
		f:SetSize(max(4, floor(r[3] * w)), max(4, floor(r[4] * h)))
	end
	en(d.Juego, g.principal)
	en(d.Alfa, g.escritorio)
	local jw, jh = max(4, floor(g.principal[3] * w)), max(4, floor(g.principal[4] * h))
	local cr, cg, cb = K.Color("acento")
	d.Cielo:SetGradient("VERTICAL", CreateColor(0.07, 0.10, 0.12, 1), CreateColor(0.16, 0.22, 0.28, 1))
	d.Suelo:SetHeight(floor(jh * 0.34))
	d.Suelo:SetVertexColor(0.08, 0.11, 0.08, 1)
	d.Barra1:ClearAllPoints()
	d.Barra1:SetPoint("BOTTOM", d.Juego, "BOTTOM", 0, 4)
	d.Barra1:SetSize(floor(jw * 0.42), max(3, floor(jh * 0.05)))
	d.Barra1:SetVertexColor(0.55, 0.48, 0.3, 0.9)
	d.Barra2:ClearAllPoints()
	d.Barra2:SetPoint("BOTTOM", d.Barra1, "TOP", 0, 2)
	d.Barra2:SetSize(floor(jw * 0.42), max(3, floor(jh * 0.05)))
	d.Barra2:SetVertexColor(0.45, 0.4, 0.26, 0.9)
	local mm = max(10, floor(jh * 0.2))
	d.Mini:ClearAllPoints()
	d.Mini:SetPoint("TOPRIGHT", d.Juego, "TOPRIGHT", -4, -4)
	d.Mini:SetSize(mm, mm)
	d.Mini:SetVertexColor(0.7, 0.66, 0.5, 1)
	d.Chat:ClearAllPoints()
	d.Chat:SetPoint("BOTTOMLEFT", d.Juego, "BOTTOMLEFT", 4, 4)
	d.Chat:SetSize(floor(jw * 0.24), floor(jh * 0.22))
	d.Chat:SetVertexColor(0, 0, 0, 0.45)
	d.Retrato:ClearAllPoints()
	d.Retrato:SetPoint("TOPLEFT", d.Juego, "TOPLEFT", 4, -4)
	d.Retrato:SetSize(floor(jw * 0.16), max(4, floor(jh * 0.1)))
	d.Retrato:SetVertexColor(0.3, 0.16, 0.12, 0.9)
	d.EtJuego:ClearAllPoints()
	d.EtJuego:SetPoint("CENTER", d.Juego, "CENTER", 0, 8)
	K.Escribir(d.EtJuego, L["El juego"])
	d.EtJuegoSub:ClearAllPoints()
	d.EtJuegoSub:SetPoint("TOP", d.EtJuego, "BOTTOM", 0, -2)
	local pw, ph = floor(W * g.principal[3] + 0.5), floor(H * g.principal[4] + 0.5)
	local fw, fh = Es.Fisica()
	local k = (fw and W > 0) and fw / W or 1
	K.Escribir(d.EtJuegoSub, format("%d × %d", floor(pw * k + 0.5), floor(ph * k + 0.5)))
	-- Alfa
	local aw, ah = max(4, floor(g.escritorio[3] * w)), max(4, floor(g.escritorio[4] * h))
	d.AlfaFondo:SetVertexColor(K.Color("fondo"))
	d.AlfaBarra:SetVertexColor(K.Color("panel"))
	local cw, ch = (aw - 4) / Es.COLUMNAS, (ah - 12) / Es.FILAS
	local lista = Es.PanelesDe(Es.Actual() or opt("distribucion") or "aventura")
	for i, x in ipairs(lista) do
		local p = d.paneles[i]
		if not p then
			p = CreateFrame("Frame", nil, d.Alfa)
			p.Fondo = rect(p, "BACKGROUND", 3)
			p.Fondo:SetAllPoints(p)
			p.Raya = rect(p, "ARTWORK", 4)
			p.Raya:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
			p.Raya:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0)
			p.Raya:SetHeight(2)
			p.Icono = p:CreateTexture(nil, "ARTWORK", nil, 5)
			p.Icono:SetPoint("CENTER", p, "CENTER", 0, 0)
			d.paneles[i] = p
		end
		p:ClearAllPoints()
		p:SetPoint("TOPLEFT", d.Alfa, "TOPLEFT", 2 + floor(x.x * cw) + 1, -(10 + floor(x.y * ch) + 1))
		p:SetSize(max(3, floor(x.w * cw) - 2), max(3, floor(x.h * ch) - 2))
		p.Fondo:SetVertexColor(K.Color("panel"))
		p.Raya:SetVertexColor(cr, cg, cb, 0.8)
		local def = Es.TIPOS[x.id]
		local tam = min(14, floor(min(x.w * cw, x.h * ch) * 0.45))
		p.Icono:SetTexture(K.Ruta(def and def.icono or "ic-lobo"))
		p.Icono:SetSize(tam, tam)
		p.Icono:SetVertexColor(cr, cg, cb, 0.9)
		p.Icono:SetShown(tam >= 6)
		p:Show()
	end
	for i = #lista + 1, #d.paneles do d.paneles[i]:Hide() end
	d.Lobo:ClearAllPoints()
	d.Lobo:SetPoint("TOPLEFT", d.Alfa, "TOPLEFT", 2, -1)
	d.Lobo:SetSize(7, 7)
	d.Lobo:SetVertexColor(cr, cg, cb, 1)
	K.Escribir(d.EtAlfa, L["Alfa"])
	-- 1.4.0: lo de Alfa es lo que sobra del juego (antes 1919 + 1921 por redondeo).
	local tw0, th0 = floor(W * k + 0.5), floor(H * k + 0.5)
	local jw0, jh0 = floor(pw * k + 0.5), floor(ph * k + 0.5)
	local hz0 = g.lado == "derecha" or g.lado == "izquierda"
	K.Escribir(d.EtAlfaSub, format("%d × %d", hz0 and (tw0 - jw0) or tw0, hz0 and th0 or (th0 - jh0)))
	local pw2 = max(K.AnchoTexto(d.EtAlfa), K.AnchoTexto(d.EtAlfaSub)) + ESP.base
	d.Placa:ClearAllPoints()
	d.Placa:SetPoint("CENTER", d.Alfa, "CENTER", 0, 0)
	d.Placa:SetSize(pw2, 40)
	d.EtAlfa:ClearAllPoints()
	d.EtAlfa:SetPoint("TOP", d.Placa, "TOP", 0, -5)
	d.EtAlfaSub:ClearAllPoints()
	d.EtAlfaSub:SetPoint("TOP", d.EtAlfa, "BOTTOM", 0, -1)
	-- La raya entre los dos.
	d.Corte:ClearAllPoints()
	local hz = g.lado == "derecha" or g.lado == "izquierda"
	if hz then
		local x = g.lado == "derecha" and g.principal[3] or g.escritorio[3]
		d.Corte:SetPoint("TOPLEFT", d.Marco, "TOPLEFT", 2 + floor(x * w) - 1, -2)
		d.Corte:SetSize(2, h)
	else
		local y = g.lado == "abajo" and g.principal[4] or g.escritorio[4]
		d.Corte:SetPoint("TOPLEFT", d.Marco, "TOPLEFT", 2, -(2 + floor(y * h) - 1))
		d.Corte:SetSize(w, 2)
	end
	d.Corte:SetVertexColor(cr, cg, cb, 1)
	local tw, th = Es.Fisica()
	tw, th = tw or floor(W + 0.5), th or floor(H + 0.5)
	K.Escribir(d.Medida, format(L["Tu ventana: %d × %d (%s)"], tw, th, Es.NombreRatio(ratio)))
	return g
end

---------------------------------------------------------------------------
-- La ventana
---------------------------------------------------------------------------
local function pasoTexto(i) return L[PASOS[i]] end

local function armar()
	v = K.Ventana({ nombre = "AlfaEscritorioAsistente", titulo = L["Dos pantallas"],
		subtitulo = L["Alfa en tu segundo monitor"], icono = "ic-ventana", ancho = ANCHO, alto = ALTO })
	local c = v.Cuerpo
	ui.Pasos = K.Segmentos(c, { estilo = "segmentos", alCambiar = function(val) As.Paso(val) end })
	ui.Dibujo = armarDibujo(c)
	-- Paso 1
	ui.Titulo = K.Texto(c, "titulo", "texto")
	ui.Titulo:SetJustifyH("LEFT")
	ui.Texto = K.Texto(c, "texto", "textoSuave")
	ui.Texto:SetJustifyH("LEFT")
	ui.Lineas = {}
	for i = 1, 4 do
		local n = CreateFrame("Frame", nil, c)
		n:SetSize(22, 22)
		n.caja = K.Caja(n, { fondo = "elevado", borde = "linea", corte = K.CORTE.chico })
		n.Num = K.Texto(n, "numero", "acento")
		n.Num:SetPoint("CENTER", n, "CENTER", 0, 0)
		n.Num:SetText(tostring(i))
		n.Texto = K.Texto(c, "nota", "texto")
		n.Texto:SetJustifyH("LEFT")
		ui.Lineas[i] = n
	end
	-- Paso 2
	ui.SecProp = K.Texto(c, "encabezado", "texto")
	ui.Prop = K.Segmentos(c, { estilo = "pildoras", alCambiar = function(val) est.proporcion = val As.Pintar() end })
	ui.Medida = K.Deslizador(c, { min = 40, max = 90, paso = 1, ancho = 300, formato = function(x) return format("%d %%", x) end,
		get = function() return est.medida end, set = function(x) est.medida = x As.Pintar() end })
	ui.MedidaTexto = K.Texto(c, "nota", "textoSuave")
	ui.SecLado = K.Texto(c, "encabezado", "texto")
	ui.Lado = K.Segmentos(c, { estilo = "pildoras", alCambiar = function(val) est.lado = val As.Pintar() end })
	ui.Resumen = K.Texto(c, "nota", "textoSuave")
	ui.Resumen:SetJustifyH("LEFT")
	-- Paso 3
	ui.Probar = K.Boton(c, L["Probar 15 segundos"], function() As.Probar() end, { tipo = "primario", tam = "grande", icono = "ic-ventana" })
	ui.Ver = K.Boton(c, L["Ver cómo queda"], function() As.VistaPrevia() end, { tipo = "secundario", tam = "grande", icono = "ic-mapa",
		ayuda = L["Pongo tu escritorio donde va a quedar, sin mover nada del juego, para que lo veas antes."] })
	ui.Volver = K.Boton(c, L["Volver a una pantalla"], function() Es.Apagar() As.Pintar() end, { tipo = "secundario" })
	ui.filas = {}
	local function fila(clave, titulo, texto)
		local f = CreateFrame("Frame", nil, c)
		f.Titulo = K.Texto(f, "cuerpo", "texto")
		f.Titulo:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
		f.Titulo:SetJustifyH("LEFT")
		f.Texto = K.Texto(f, "nota", "textoSuave")
		f.Texto:SetJustifyH("LEFT")
		f.Interruptor = K.Interruptor(f, { clave = Es.ID .. "." .. clave })
		f.Interruptor:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
		f.titulo, f.texto = titulo, texto
		ui.filas[#ui.filas + 1] = f
		return f
	end
	fila("moverMundo", L["Poner el mundo en el monitor principal"],
		L["El mundo se dibuja solo en tu monitor principal y no detrás de Alfa."])
	fila("moverInterfaz", L["Poner la interfaz del juego en el principal"],
		L["Tus barras, tu retrato, el minimapa, el chat y las misiones se quedan contigo."])
	fila("auto", L["Cambiar el escritorio solo"],
		L["En una mazmorra, pescando o en la subasta, Alfa pone los paneles que te sirven ahí."])
	-- El pie
	ui.Atras = K.Boton(v, L["Atrás"], function() As.Paso(est.paso - 1) end, { tipo = "secundario" })
	ui.Siguiente = K.Boton(v, L["Siguiente"], function() As.Paso(est.paso + 1) end, { tipo = "primario" })
	v:SetPie({ ui.Atras, ui.Siguiente })
	-- Mientras pruebas, la ventana se esconde; vuelve si regresas a como estaba.
	A.On("ALFA_ESCRITORIO", function(que)
		if que == "rechazado" and est.probando then
			est.probando = nil
			v:Abrir()
			As.Pintar()
		elseif que == "guardado" and est.probando then
			est.probando = nil
		end
	end)
end

local function colocar(f, x, y, w)
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", x, -y)
	if w then f:SetWidth(w) end
	f:Show()
end

local function textoDeteccion()
	local r = Es.Ratio()
	local s = Es.Sugerencia()
	local nombre = Es.NombreRatio(r)
	if s.motivo == "ancha" then
		return format(L["Tu ventana es de %s: parece que juegas sobre %d monitores. ¡Perfecto para esto!"], nombre, s.monitores)
	elseif s.motivo == "alta" then
		return format(L["Tu ventana es de %s, más alta que ancha: parece que tienes un monitor arriba del otro."], nombre)
	end
	return format(L["Tu ventana es de %s, de un solo monitor. Puedes estirarla sobre dos o probar el escritorio a un lado de esta pantalla."], nombre)
end

local INSTRUCCIONES = {
	"Pon el juego en modo ventana: Esc > Sistema > Gráficos > Modo de pantalla > «En ventana».",
	"Haz la ventana del ancho de tus dos monitores: arrástrala desde su orilla, o escribe en el chat /console gxWindowedResolution 3840x1080 (tu ancho total) y luego /console gxRestart.",
	"Vuelve aquí: Alfa ve la ventana nueva y te propone cómo repartirla.",
	"¿Usas Offhand? Déjalo estirar la ventana: Alfa no mueve nada y solo pone su escritorio en el otro monitor.",
}
-- 1.4.0: con la ventana ya ancha no hacen falta (solo la de Offhand, abajo).

function As.Pintar()
	if not (v and v:IsShown()) then return end
	local c = v.Cuerpo
	local ancho = v:AnchoCuerpo()
	local x = v.margen
	local ops = {}
	for i = 1, #PASOS do ops[i] = { valor = i, texto = format("%d. %s", i, pasoTexto(i)) } end
	ui.Pasos:SetOpciones(ops)
	ui.Pasos:SetValor(est.paso)
	local _, usado = ui.Pasos:Acomodar(ancho)
	colocar(ui.Pasos, x + floor((ancho - (usado or ancho)) / 2), ESP.base)
	local y = ESP.base + K.ALTO.control + ESP.base
	ui.Dibujo:ClearAllPoints()
	ui.Dibujo:SetPoint("TOPLEFT", c, "TOPLEFT", x, -y)
	local g = pintarDibujo(ui.Dibujo, ancho)
	ui.Dibujo:Show()
	y = y + K.num(ui.Dibujo:GetHeight(), 220) + ESP.base
	-- Todo lo de los pasos, escondido; cada uno saca lo suyo.
	for _, f in ipairs({ ui.Titulo, ui.Texto, ui.SecProp, ui.Prop, ui.Medida, ui.MedidaTexto, ui.SecLado, ui.Lado, ui.Resumen, ui.Probar, ui.Ver, ui.Volver }) do f:Hide() end
	for _, n in ipairs(ui.Lineas) do n:Hide() n.Texto:Hide() end
	for _, f in ipairs(ui.filas) do f:Hide() end
	if est.paso == 1 then
		-- Lo que Alfa ve de tu ventana.
		colocar(ui.Texto, x, y)
		K.Escribir(ui.Texto, textoDeteccion())
		y = y + K.Parrafo(ui.Texto, ancho, 3) + ESP.m
		-- Con la ventana de un solo monitor: cómo estirarla (o el escritorio a un lado).
		if not Es.EsAncha() then
			local n = 0
			for i, nn in ipairs(ui.Lineas) do
				if i <= 3 then
					n = n + 1
					colocar(nn, x, y)
					nn.Texto:ClearAllPoints()
					nn.Texto:SetPoint("TOPLEFT", c, "TOPLEFT", x + 22 + ESP.m, -(y + 3))
					K.Escribir(nn.Texto, L[INSTRUCCIONES[i]])
					nn.Texto:Show()
					y = y + max(22, K.Parrafo(nn.Texto, ancho - 22 - ESP.m, 3) + 3) + ESP.s
				end
			end
			y = y + ESP.s
		end
		colocar(ui.SecProp, x, y, ancho)
		K.Escribir(ui.SecProp, L["Tu monitor principal (donde juegas)"])
		y = y + 20
		local pops = {}
		for i, p in ipairs(Es.PROPORCIONES) do pops[i] = { valor = p.valor, texto = L[p.texto], ayuda = L[p.ayuda] } end
		ui.Prop:SetOpciones(pops)
		ui.Prop:SetValor(est.proporcion)
		local hp = ui.Prop:Acomodar(ancho)
		colocar(ui.Prop, x, y)
		y = y + hp + ESP.m
		if est.proporcion == "medida" or g.una then
			colocar(ui.Medida, x, y)
			ui.Medida:Acomodar(320)
			ui.Medida:Leer()
			ui.MedidaTexto:ClearAllPoints()
			ui.MedidaTexto:SetPoint("LEFT", ui.Medida, "RIGHT", ESP.base, 0)
			K.Escribir(ui.MedidaTexto, g.una and L["Tu ventana no es más ancha que ese monitor: el juego usa esta parte."] or L["Cuánto de la ventana es para el juego."])
			K.Parrafo(ui.MedidaTexto, ancho - 320 - ESP.base, 2)
			ui.MedidaTexto:Show()
			y = y + K.ALTO.control + ESP.m
		end
		colocar(ui.SecLado, x, y, ancho)
		K.Escribir(ui.SecLado, L["¿Dónde está el otro monitor?"])
		y = y + 20
		local lops = {}
		for i, l in ipairs(Es.LADOS) do lops[i] = { valor = l.valor, texto = L[l.texto], icono = l.icono } end
		ui.Lado:SetOpciones(lops)
		ui.Lado:SetValor(est.lado)
		local hl = ui.Lado:Acomodar(ancho)
		colocar(ui.Lado, x, y)
		y = y + hl + ESP.m
		colocar(ui.Resumen, x, y)
		local W, H = Es.Pantalla()
		local fw = Es.Fisica()
		local k = (fw and W > 0) and fw / W or 1
		local jw, jh = floor(W * g.principal[3] * k + 0.5), floor(H * g.principal[4] * k + 0.5)
		local tw0, th0 = floor(W * k + 0.5), floor(H * k + 0.5)
		local hz0 = g.lado == "derecha" or g.lado == "izquierda"
		local aw, ah = hz0 and (tw0 - jw) or tw0, hz0 and th0 or (th0 - jh)
		K.Escribir(ui.Resumen, format(L["El juego: %d × %d. Alfa: %d × %d."], jw, jh, aw, ah))
		y = y + K.Parrafo(ui.Resumen, ancho, 2)
	else
		colocar(ui.Titulo, x, y, ancho)
		K.Escribir(ui.Titulo, L["Pruébalo"])
		y = y + K.AltoTexto(ui.Titulo) + ESP.s
		colocar(ui.Texto, x, y)
		local otro = Es.OtroLoHace()
		local t = L["Primero míralo sin mover nada con «Ver cómo queda». Luego «Probar»: si algo se ve raro, no toques nada y en 15 segundos vuelvo a como estaba."]
		if otro then t = t .. " " .. format(L["Veo %s: él acomoda la interfaz y yo solo pongo mi escritorio en el otro monitor."], otro) end
		K.Escribir(ui.Texto, t)
		y = y + K.Parrafo(ui.Texto, ancho, 4) + ESP.base
		colocar(ui.Ver, x, y)
		ui.Probar:ClearAllPoints()
		ui.Probar:SetPoint("LEFT", ui.Ver, "RIGHT", ESP.s, 0)
		ui.Probar:Show()
		ui.Ver:SetActivo(not Es.Aplicado())
		if Es.Aplicado() then
			ui.Volver:ClearAllPoints()
			ui.Volver:SetPoint("LEFT", ui.Probar, "RIGHT", ESP.s, 0)
			ui.Volver:Show()
		end
		y = y + K.ALTO.botonGrande + ESP.l
		for _, f in ipairs(ui.filas) do
			colocar(f, x, y, ancho)
			K.Escribir(f.Titulo, f.titulo)
			f.Titulo:SetWidth(ancho - 60)
			f.Texto:ClearAllPoints()
			f.Texto:SetPoint("TOPLEFT", f.Titulo, "BOTTOMLEFT", 0, -3)
			K.Escribir(f.Texto, f.texto)
			local th = K.Parrafo(f.Texto, ancho - 60, 2)
			f:SetHeight(18 + th)
			f.Interruptor:Leer()
			f.Interruptor:SetActivo(not (otro and f ~= ui.filas[3]))
			y = y + 18 + th + ESP.m
		end
	end
	-- La ventana mide lo que su paso (sin hueco abajo).
	local alto = K.ALTO.cabecera + y + ESP.l + K.ALTO.pie
	if est.paso == 1 then alto = alto + 20 end
	if abs(K.num(v:GetHeight(), 0) - alto) > 1 then v:SetTamano(ANCHO, alto) end
	ui.Atras:SetActivo(est.paso > 1)
	ui.Siguiente:SetShown(est.paso < #PASOS)
	ui.Siguiente:SetTexto(L["Siguiente"])
end

function As.Paso(n)
	est.paso = max(1, min(#PASOS, tonumber(n) or 1))
	As.Pintar()
end

function As.Probar()
	est.probando = true
	if v then v:Cerrar() end
	if not Es.Probar({ lado = est.lado, proporcion = est.proporcion, medida = est.medida }) then
		est.probando = nil
		if v then v:Abrir() As.Pintar() end
		return false
	end
	return true
end

-- 1.4.0: «Ver cómo queda»: el escritorio de verdad donde va, sin mover
-- nada. Al cerrarla vuelve el asistente; con «Probar» sigue la prueba.
function As.VistaPrevia()
	est.probando = true
	if v then v:Cerrar() end
	local ok = Es.VistaPrevia({ lado = est.lado, proporcion = est.proporcion, medida = est.medida }, function(probo)
		if probo then return end
		est.probando = nil
		if v then v:Abrir() As.Pintar() end
	end)
	if not ok then
		est.probando = nil
		if v then v:Abrir() As.Pintar() end
		return false
	end
	return true
end

function As.Abrir(paso)
	if not v then armar() end
	-- Lo guardado; sin nada guardado, lo que Alfa sugiere para tu ventana.
	local s = Es.Sugerencia()
	local guardado = N.Get(Es.ID, "activo") == true or N.Datos(Es.ID).elegido
	est.lado = guardado and opt("lado") or s.lado
	est.proporcion = guardado and opt("proporcion") or s.proporcion
	est.medida = tonumber(opt("medida")) or 70
	est.paso = tonumber(paso) or 1
	v:Abrir()
	As.Pintar()
	return true
end

function As.Cerrar() if v then v:Cerrar() end end
function As.Visible() return v ~= nil and v:IsShown() end
function As.Ventana() return v end
