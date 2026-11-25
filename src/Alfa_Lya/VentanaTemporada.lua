-- Alfa - Lya: la ventana de tu temporada con la manada (1.4.0, 11).
-- toxic3000 / La Jauría. GPL-3.0.
--
--   Arriba, la portada: Lya aullando, tus días de caza en grande y desde
--   cuándo cazan juntos. Debajo, tarjetas: tu aventura (niveles, misiones,
--   mazmorras, guías), el mundo (peces, raros, oro), tus récords y los
--   momentos con Lya (las últimas páginas de tu historia). Al abrirse entra
--   suave (se aclara y el lobo sube un poco). Abajo, «Copiar para Discord»:
--   un cuadro con el texto ya seleccionado (Ctrl+C), sin tu nombre ni tu reino
--   (Temporada.lua, N.SinPrivado). Se puede abrir y cerrar en combate (no es
--   un marco protegido) y se cierra con Esc.
--
--   Vt.Abrir()  Vt.Pintar()  Vt.Ventana()  Vt.Copiar()

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L

local type, tonumber, ipairs, format, floor, max, min = type, tonumber, ipairs, string.format, math.floor, math.max, math.min
local ESP = K.ESP

local Vt = {}
M.VentanaTemporada = Vt

local ANCHO, ALTO = 760, 640
local LOBO = 92
local v

local function numero(n)
	n = floor(tonumber(n) or 0)
	if N.Numero then
		local ok, s = pcall(N.Numero, n)
		if ok and type(s) == "string" then return s end
	end
	return tostring(n)
end

-- "2026-10-12" -> "12/10/2026"
local function fechaBonita(f)
	local y, m, d = tostring(f or ""):match("^(%d+)%-(%d+)%-(%d+)$")
	if not y then return f or "" end
	return format("%s/%s/%s", d, m, y)
end

---------------------------------------------------------------------------
-- Las tarjetas
---------------------------------------------------------------------------
local function aventura(x)
	local out = {}
	local nivel = x.nivel and (x.nivelInicio and x.nivelInicio < x.nivel and format(L["del %d al %d"], x.nivelInicio, x.nivel) or format(L["nivel %d"], x.nivel)) or nil
	out[#out + 1] = { icono = "ic-nivel", tono = "acento", sobre = L["Niveles"], titulo = numero(x.niveles), texto = nivel }
	out[#out + 1] = { icono = "ic-misiones", tono = "acento", sobre = L["Misiones"], titulo = numero(x.misiones), texto = L["entregadas"] }
	out[#out + 1] = { icono = "ic-mazmorra", tono = "acento", sobre = L["Mazmorras"], titulo = numero(x.mazmorras), texto = L["terminadas"] }
	out[#out + 1] = { icono = "ic-guia", tono = "acento", sobre = L["Guías"], titulo = numero(x.guias), texto = L["de principio a fin"] }
	return out
end

local function mundo(x)
	local out = {}
	local p = x.pesca
	out[#out + 1] = { icono = "ic-pesca", tono = "acento", sobre = L["Peces"], titulo = numero(p and p.capturas or 0),
		texto = p and p.distintos > 0 and N.Plural(p.distintos, L["%d distinto"], L["%d distintos"]) or L["¿Vamos al lago?"] }
	out[#out + 1] = { icono = "ic-raros", tono = "acento", sobre = L["Raros vistos"], titulo = numero(x.raros) }
	out[#out + 1] = { icono = "ic-oro", tono = "acento", sobre = L["Oro ganado"], titulo = N.Dinero and N.Dinero(x.oro, true) or numero(x.oro / 10000),
		texto = x.oroAhora and format(L["Llevas %s"], N.Dinero and N.Dinero(x.oroAhora, true) or numero(x.oroAhora / 10000)) or nil }
	out[#out + 1] = { icono = "ic-reloj", tono = "acento", sobre = L["Tiempo"], -- 1.4.0 (83): «Tiempo de caza» cortado con letra grande
		titulo = N.Duracion and N.Duracion(x.minutos * 60, true) or numero(x.minutos),
		texto = x.jugado and format(L["%s jugados en total"], N.Duracion and N.Duracion(x.jugado, true) or numero(x.jugado)) or nil }
	return out
end

local function records(x)
	local out = {}
	if x.mejorDia > 0 then
		out[#out + 1] = { icono = "ic-exito", tono = "acento", sobre = L["Tu mejor día"], titulo = N.Plural(x.mejorDia, L["%d misión"], L["%d misiones"]),
			texto = x.mejorDiaFecha and fechaBonita(x.mejorDiaFecha) or nil }
	end
	if x.pesca and x.pesca.racha > 0 then
		out[#out + 1] = { icono = "ic-pesca", tono = "acento", sobre = L["Tu mejor racha de pesca"], titulo = numero(x.pesca.racha) }
	end
	out[#out + 1] = { icono = "ic-huella", tono = "acento", sobre = L["Salchichas para Lya"], titulo = numero(x.salchichas),
		texto = x.salchichas > 0 and L["Te las tiene bien contadas."] or L["Todavía me debes la primera."] }
	if x.muertes > 0 then
		out[#out + 1] = { icono = "ic-curacion", tono = "acento", sobre = L["Veces que te levantaste"], titulo = numero(x.muertes),
			texto = L["Caer no cuenta; levantarse, sí."] }
	end
	return out
end

local function momentos(x)
	local out = {}
	for i, e in ipairs(x.momentos or {}) do
		out[i] = { icono = e.icono, tono = "acento", sobre = fechaBonita(e.fecha), titulo = e.titulo, texto = e.linea }
	end
	if #out == 0 then
		out[1] = { icono = "ic-huella", tono = "neutro", titulo = L["Tu historia empieza pronto"],
			texto = L["Lya apunta aquí tus pasos grandes: tu primera mazmorra, tus niveles, tu primera montura y más."] }
	end
	return out
end

---------------------------------------------------------------------------
-- La ventana
---------------------------------------------------------------------------
local function cuadroCopiar(padre)
	local c = CreateFrame("Frame", nil, padre)
	c:EnableMouse(true)
	c.caja = K.Caja(c, { fondo = "hundido", borde = "acento", corte = K.CORTE.control })
	c.Pista = K.Texto(padre, "pequeno", "textoTenue")
	K.Escribir(c.Pista, L["Ya está seleccionado: Ctrl+C para copiar y pégalo en Discord. No lleva tu nombre ni tu reino."])
	local e = CreateFrame("EditBox", nil, c)
	c.Campo = e
	e:SetAutoFocus(false)
	e:SetMultiLine(true)
	K.Pintar(e, function(x)
		K.FuenteSegura(x, K.Cara("medium"), K.Tamano("nota"), "")
		x:SetTextColor(K.Color("texto"))
	end)
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	e:SetScript("OnTextChanged", function(self, usuario)
		if usuario and self:GetText() ~= (c.texto or "") then
			self:SetText(c.texto or "")
			self:HighlightText()
		end
	end)
	e:SetScript("OnMouseUp", function(self) self:HighlightText() end)
	e:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
	c:SetScript("OnMouseDown", function() e:SetFocus() end)
	c:SetScript("OnShow", function() c.Pista:Show() end)
	c:SetScript("OnHide", function() c.Pista:Hide() end)
	function c:Set(t)
		self.texto = t or ""
		e:SetText(self.texto)
		e:SetCursorPosition(0)
	end
	function c:Acomodar(ancho)
		self:SetWidth(ancho)
		local lineas = 1
		for _ in tostring(self.texto or ""):gmatch("\n") do lineas = lineas + 1 end
		local alto = lineas * (K.Tamano("nota") + 4) + 2 * ESP.m
		e:ClearAllPoints()
		e:SetPoint("TOPLEFT", self, "TOPLEFT", ESP.m, -ESP.m)
		e:SetWidth(max(60, ancho - 2 * ESP.m))
		e:SetHeight(alto - 2 * ESP.m)
		self.Pista:ClearAllPoints()
		self.Pista:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -ESP.s)
		local hp = K.Parrafo(self.Pista, ancho, 3)
		self:SetHeight(alto)
		return alto + ESP.s + hp
	end
	return c
end

local function armar()
	if v then return v end
	v = K.Ventana({ nombre = "AlfaLyaTemporada", titulo = L["Tu temporada con la manada"], icono = "ic-lobo",
		ancho = ANCHO, alto = ALTO, desplazar = true })
	v:SetTitulo(L["Tu temporada con la manada"], L["Tu aventura desde que usas Alfa"], "ic-lobo")
	local c = v.Cuerpo
	-- La portada
	local h = CreateFrame("Frame", nil, c)
	v.Portada = h
	h.caja = K.Caja(h, { fondo = "panel", borde = "acento", corte = K.CORTE.panel, alfaBorde = 0.6 })
	h.Brillo = h:CreateTexture(nil, "BACKGROUND", nil, 1)
	h.Brillo:SetPoint("TOPLEFT", h, "TOPLEFT", 1, -1)
	h.Brillo:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", -1, 1)
	h.Brillo:SetColorTexture(1, 1, 1, 1)
	K.Pintar(h.Brillo, function(t)
		local r, g, b = K.Color("acento")
		t:SetVertexColor(r, g, b, 0.08)
	end)
	h.Lobo = h:CreateTexture(nil, "ARTWORK")
	h.Lobo:SetSize(LOBO, LOBO)
	h.Lobo:SetTexture(K.Lobo("aullando"))
	K.Pintar(h.Lobo, function(t) t:SetVertexColor(K.Color("acento")) end)
	h.Sobre = K.Texto(h, "mayus", "acento")
	h.Titulo = K.Texto(h, "portada", "texto")
	h.Texto = K.Texto(h, "texto", "textoSuave")
	h.Texto:SetWordWrap(true)
	-- La entrada suave: se aclara y el lobo sube un poco.
	if v.CreateAnimationGroup then
		local g = v.Cuerpo:CreateAnimationGroup()
		local a = g:CreateAnimation("Alpha")
		if a.SetFromAlpha then a:SetFromAlpha(0) a:SetToAlpha(1) end
		if a.SetDuration then a:SetDuration(0.35) end
		v.Entrada = g
		local gl = h.Lobo.CreateAnimationGroup and h.Lobo:CreateAnimationGroup()
		if gl then
			local t = gl:CreateAnimation("Translation")
			if t.SetOffset then t:SetOffset(0, 8) end
			if t.SetDuration then t:SetDuration(0.5) end
			if t.SetSmoothing then t:SetSmoothing("OUT") end
			v.EntradaLobo = gl
		end
	end
	-- Las secciones
	v.secciones = {}
	for _, s in ipairs({ { "aventura", L["Tu aventura"] }, { "mundo", L["El mundo"] }, { "records", L["Tus récords"] }, { "momentos", L["Momentos con Lya"] } }) do
		local x = { Seccion = K.Seccion(c, s[2]), Rejilla = K.Rejilla(c, { min = s[1] == "momentos" and 300 or 150, gap = ESP.s, variante = "normal" }) }
		v.secciones[s[1]] = x
		v.secciones[#v.secciones + 1] = x
	end
	v.Copia = cuadroCopiar(c)
	v.Copia:Hide()
	v.Copiar = K.Boton(v, L["Copiar para Discord"], function() Vt.Copiar() end, { tipo = "primario", icono = "ic-comunidad" })
	v.Cerrar2 = K.Boton(v, L["Cerrar"], function() v:Cerrar() end, { tipo = "secundario" })
	v:SetPie({ v.Cerrar2, v.Copiar })
	v.alAcomodar = function() Vt.Pintar() end
	return v
end

function Vt.Pintar()
	if not (v and v:IsShown()) then return end
	local Te = M.Temporada
	local x = Te.Datos()
	local m = v.margen or 24
	local ancho = v:AnchoCuerpo()
	local y = ESP.m
	-- La portada
	local h = v.Portada
	h:ClearAllPoints()
	h:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", m, -y)
	h:SetWidth(ancho)
	K.Escribir(h.Sobre, K.Mayus(L["La manada te cuenta"]))
	-- El número grande: los días desde que empezamos; los días de caza (los que
	-- jugaste) van abajo, dichos en palabras simples.
	local juntos = max(1, x.conAlfa)
	K.Escribir(h.Titulo, juntos == 1 and L["¡Hoy empezamos juntos!"] or format(L["¡%s días juntos!"], numero(juntos)))
	local quien = {}
	if x.raza then quien[#quien + 1] = x.raza end
	if x.clase then quien[#quien + 1] = x.clase end
	if x.nivel then quien[#quien + 1] = format(L["nivel %d"], x.nivel) end
	local linea = format(L["Desde el %s. Salimos a cazar %s."], fechaBonita(x.desde), N.Plural(max(1, x.dias), L["%d día"], L["%d días"]))
	if #quien > 0 then linea = table.concat(quien, " · ") .. "\n" .. linea end
	K.Escribir(h.Texto, linea)
	local pad = ESP.l
	local xt = pad + LOBO + ESP.l
	local wt = ancho - xt - pad
	h.Lobo:ClearAllPoints()
	h.Lobo:SetPoint("LEFT", h, "LEFT", pad, 0)
	h.Sobre:ClearAllPoints()
	h.Sobre:SetPoint("TOPLEFT", h, "TOPLEFT", xt, -pad)
	h.Titulo:ClearAllPoints()
	h.Titulo:SetPoint("TOPLEFT", h.Sobre, "BOTTOMLEFT", 0, -ESP.xs)
	local altoTitulo = K.Parrafo(h.Titulo, wt, 2)
	h.Texto:ClearAllPoints()
	h.Texto:SetPoint("TOPLEFT", h.Titulo, "BOTTOMLEFT", 0, -ESP.s)
	local altoTexto = K.Parrafo(h.Texto, wt, 4)
	local altoH = max(LOBO + 2 * pad, pad + K.Tamano("mayus") + 4 + ESP.xs + altoTitulo + ESP.s + altoTexto + pad)
	h:SetHeight(altoH)
	y = y + altoH + ESP.l
	-- Las tarjetas
	local datos = { aventura = aventura(x), mundo = mundo(x), records = records(x), momentos = momentos(x) }
	for _, k in ipairs({ "aventura", "mundo", "records", "momentos" }) do
		local s = v.secciones[k]
		s.Seccion:ClearAllPoints()
		s.Seccion:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", m, -y)
		s.Seccion:SetWidth(ancho)
		y = y + (s.Seccion.Acomodar and s.Seccion:Acomodar(ancho) or 24) + ESP.s
		s.Rejilla:Llenar(datos[k])
		s.Rejilla:ClearAllPoints()
		s.Rejilla:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", m, -y)
		s.Rejilla:SetWidth(ancho)
		local hr = s.Rejilla:Acomodar(ancho)
		s.Rejilla:SetHeight(max(1, hr))
		y = y + hr + ESP.l
	end
	if v.Copia:IsShown() then
		v.Copia:ClearAllPoints()
		v.Copia:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", m, -y)
		y = y + v.Copia:Acomodar(ancho) + ESP.l
	end
	v:SetAltoContenido(y)
end

-- «Copiar para Discord»: el cuadro con el texto, ya seleccionado.
function Vt.Copiar()
	armar()
	v.Copia:Set(M.Temporada.TextoCompartir())
	v.Copia:Show()
	Vt.Pintar()
	if v.Desplazable and v.Desplazable.SetVerticalScroll then
		local alto = K.num(v.Desplazable.Contenido:GetHeight(), 0) - K.num(v.Desplazable:GetHeight(), 0)
		if alto > 0 then
			v.Desplazable:SetVerticalScroll(alto)
			if v.Desplazable.Barra then v.Desplazable.Barra:SetValue(alto) end
		end
	end
	v.Copia.Campo:SetFocus()
	v.Copia.Campo:HighlightText()
	return v.Copia.texto
end

function Vt.Abrir()
	armar()
	v.Copia:Hide()
	if not v:IsShown() then v:Abrir() end
	if v.Desplazable and v.Desplazable.IrArriba then v.Desplazable:IrArriba() end
	Vt.Pintar()
	if v.Entrada and v.Entrada.Play then pcall(v.Entrada.Play, v.Entrada) end
	if v.EntradaLobo and v.EntradaLobo.Play then pcall(v.EntradaLobo.Play, v.EntradaLobo) end
	return true
end

function Vt.Ventana() return v end
