-- Alfa - Rutas: «Cerrar mis misiones», de punta a punta (toxic3000 / La
-- Jauría). GPL-3.0. 1.3.9
--
-- Un solo botón para todo (Hoy, la página Ruta, el rastreador, el menú de
-- Alfa y el Escritorio: AlfaRuta.CerrarTodo / AlfaRuta.Liberar()):
--   1. abre al momento una ventanita con su avance («Preparando tu ruta…»,
--      «Midiendo caminos… 40 %»); si falta la base de misiones la carga sola
--      (en combate espera a que salgas y sigue sola) y, si no se puede, dice
--      por qué con «Reintentar»;
--   2. arma el plan con TODAS tus misiones (desde Hoy y los demás; la página
--      Ruta usa el atajo que ves en ella): lo que no se puede ahora (élite,
--      mazmorra, muy arriba de tu nivel, sin datos) va en «Para después»
--      con su porqué y no rompe la ruta;
--   3. antes de salir, un resumen: «12 misiones · 4 zonas · unos 55 min ·
--      +8,400 XP», con «Empezar», «Ver paradas» y «Quitar algunas» (casillas,
--      todas marcadas de fábrica; «Solo listas» / «Solo de esta zona» son
--      atajos a la vista, no trampas guardadas);
--   4. «Empezar» abre la ruta con la flecha en la primera parada, y la ruta
--      sale en el mapa de Alfa y en el del juego: paradas numeradas con el
--      camino en puntitos (capa rutas.cerrarRuta, ajuste rutas.cerrarMapa);
--   5. al entregar cada una, «¡Lista! Sigue: X» (rutas.cerrarSigue) y, al
--      cerrar la última, el festejo de Lya con la cuenta: tiempo, XP y
--      misiones cerradas.
-- Con rutas.cerrarResumen apagado, «Cerrar mis misiones» sale directo.
--
--   CerrarTodo.Abrir(opts)   opts = { origen, filtro, solo = { [qid] = true }, titulo, alListo }
--   CerrarTodo.Empezar()     instala y abre el plan del resumen
--   CerrarTodo.Estado() -> { fase, info, avance } (para el banco)
--   CerrarTodo.Cuenta() -> la cuenta del plan en marcha | nil
--   CerrarTodo.PintarMapa()  las paradas en los mapas
--   CerrarTodo.Ventana() -> la ventana | nil

local ADDON, M = ...
local A, L, N, K = M.A, M.L, M.N, M.K
local Cr, I = M.Cerrar, M.Indice
local Ct = {}
M.CerrarTodo = Ct

A.RegisterDefaults(M.ID, { cerrarResumen = true, cerrarSigue = true, cerrarMapa = true })

local type, ipairs, pairs, tonumber, tostring, pcall = type, ipairs, pairs, tonumber, tostring, pcall
local format, concat, floor, max, min = string.format, table.concat, math.floor, math.max, math.min

local DOT = "  \194\183  "
local FILA = 44
local ANCHO, ALTO = 460, 560
local CAPA = "rutas.cerrarRuta"

local function on(clave) return A.Get(M.ID .. "." .. clave) ~= false end
local function pj() return M.Personaje() end
local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end
local function E() return M.Motor("Engine") end
local function CP() return M.Motor("Compat") end

-- El estado del armado (uno a la vez).
local st = { fase = nil, avance = 0, opts = {}, gen = 0 }
function Ct.Estado() return st end

---------------------------------------------------------------------------
-- Textos del resumen
---------------------------------------------------------------------------

-- «12 misiones · 4 zonas · unos 55 min · +8,400 XP»
function Ct.TextoResumen(info)
	if type(info) ~= "table" then return "" end
	local partes = { M.Plural(info.misiones or 0, L["%d misión"], L["%d misiones"]) }
	local z = #(info.zonas or {})
	if z > 0 then partes[#partes + 1] = M.Plural(z, L["%d zona"], L["%d zonas"]) end
	if (info.segundos or 0) > 0 then partes[#partes + 1] = format(L["unos %s"], M.Minutos(info.segundos)) end
	if (info.xp or 0) > 0 then partes[#partes + 1] = format(L["+%s XP"], M.Miles(info.xp)) end
	return concat(partes, DOT)
end

local VERBOS = { accept = "ic-misiones", turnin = "ic-exito", kill = "ic-raros", collect = "ic-bolsas", loot = "ic-bolsas",
	interact = "ic-seguir", use = "ic-seguir", talk = "ic-personajes", complete = "ic-huella" }

-- Una parada del plan, para la lista: { n, titulo, sub, icono, map, x, y, f }
local function paradaDe(paso, n)
	local map, x, y, f, turn, hacer, tomar
	-- 1.3.9 (revisión): el lugar de una parada de entrega es su PNJ, no el de
	-- «Completa la misión» que va antes (decía «Montañas de Alterac» de un
	-- PNJ de Laderas de Trabalomas).
	for _, g in ipairs(paso.goals or {}) do
		if (g.t == "turnin" or g.t == "accept") and g.map and g.x and g.y then map, x, y, f = g.map, g.x, g.y, g.f break end
	end
	for _, g in ipairs(paso.goals or {}) do
		if not map and g.map and g.x and g.y then map, x, y, f = g.map, g.x, g.y, g.f end
		if g.t == "turnin" then turn = (turn or 0) + 1
		elseif g.t == "accept" then tomar = (tomar or 0) + 1
		elseif VERBOS[g.t] and g.t ~= "complete" then hacer = (hacer or 0) + 1 end
	end
	local partes = {}
	if turn then partes[#partes + 1] = M.Plural(turn, L["Entregar %d"], L["Entregar %d"]) end
	if hacer then partes[#partes + 1] = M.Plural(hacer, L["%d cosa por hacer"], L["%d cosas por hacer"]) end
	if tomar then partes[#partes + 1] = M.Plural(tomar, L["Tomar %d"], L["Tomar %d"]) end
	local zona = map and M.Zona(map)
	if zona then partes[#partes + 1] = zona end
	return { n = n, titulo = paso.title or "", sub = concat(partes, DOT),
		icono = turn and "ic-exito" or (tomar and "ic-misiones") or "ic-huella", map = map, x = x, y = y, f = f }
end

---------------------------------------------------------------------------
-- La ventana
---------------------------------------------------------------------------
local v

local function fila(padre)
	local f = CreateFrame("Frame", nil, padre)
	f.caja = K.Caja(f, { fondo = "panel", borde = "linea", corte = K.CORTE.control })
	f.Num = K.Texto(f, "numero", "acento")
	f.Num:SetJustifyH("CENTER")
	f.Icono = K.Icono(f, "ic-huella", 14, "acento")
	f.Titulo = K.Texto(f, "cuerpo", "texto")
	f.Titulo:SetWordWrap(true)
	f.Sub = K.Texto(f, "pequeno", "textoTenue")
	f.Sub:SetWordWrap(true)
	f.Entra = K.Interruptor(f, { alCambiar = function(on2)
		if f.alfaId then Ct.Alternar(f.alfaId, on2) end
	end })
	f.Boton = K.Boton(f, L["Meterla"], function()
		if f.alfaId then Ct.Meter(f.alfaId) end
	end, { tipo = "secundario", tam = "chico" })
	-- d = { n, titulo, sub, icono, casilla = bool | nil, boton = bool }
	function f:Set(d, ancho)
		self.alfaId = d.id
		local x = K.ESP.s
		self.Num:SetShown(d.n ~= nil)
		self.Icono:SetShown(d.n == nil and d.casilla == nil)
		self.Entra:SetShown(d.casilla ~= nil)
		self.Boton:SetShown(d.boton == true)
		if d.n then
			K.Escribir(self.Num, tostring(d.n))
			self.Num:ClearAllPoints()
			self.Num:SetPoint("TOPLEFT", self, "TOPLEFT", x, -K.ESP.s)
			self.Num:SetWidth(22)
			x = x + 22 + K.ESP.s
		elseif d.casilla ~= nil then
			self.Entra:SetValor(d.casilla and true or false)
			self.Entra:ClearAllPoints()
			self.Entra:SetPoint("TOPLEFT", self, "TOPLEFT", x, -K.ESP.s)
			x = x + 36 + K.ESP.s
		else
			K.SetIcono(self.Icono, d.icono or "ic-reloj", d.tono or "aviso")
			self.Icono:ClearAllPoints()
			self.Icono:SetPoint("TOPLEFT", self, "TOPLEFT", x + 4, -K.ESP.s - 1)
			x = x + 22 + K.ESP.s
		end
		local derecha = K.ESP.s
		if d.boton then
			self.Boton:ClearAllPoints()
			self.Boton:SetPoint("RIGHT", self, "RIGHT", -K.ESP.s, 0)
			derecha = derecha + self.Boton:AnchoNatural() + K.ESP.s
		end
		local tw = max(80, ancho - x - derecha)
		K.Escribir(self.Titulo, d.titulo or "")
		K.ColorTexto(self.Titulo, d.apagada and "textoTenue" or "texto")
		self.Titulo:ClearAllPoints()
		self.Titulo:SetPoint("TOPLEFT", self, "TOPLEFT", x, -K.ESP.s)
		local h1 = K.Parrafo(self.Titulo, tw, 2)
		local h = K.ESP.s + h1
		if d.sub and d.sub ~= "" then
			K.Escribir(self.Sub, d.sub)
			self.Sub:ClearAllPoints()
			self.Sub:SetPoint("TOPLEFT", self.Titulo, "BOTTOMLEFT", 0, -3)
			h = h + 3 + K.Parrafo(self.Sub, tw, 3)
			self.Sub:Show()
		else
			self.Sub:Hide()
		end
		h = max(FILA, h + K.ESP.s)
		self:SetSize(ancho, h)
		return h
	end
	return f
end

local FILTROS = {
	{ valor = "todas", texto = L["Todas mis misiones"], icono = "ic-misiones" },
	{ valor = "listas", texto = L["Solo listas"], icono = "ic-exito" },
	{ valor = "zona", texto = L["Solo de esta zona"], icono = "ic-mapa" },
}

local function armarVentana()
	v = K.Ventana({ nombre = "AlfaRutasCerrarTodo", titulo = L["Cerrar mis misiones"], icono = "ic-misiones",
		ancho = ANCHO, alto = ALTO, desplazar = true,
		alCerrar = function() if st.fase ~= "resumen" then st.cancelado = true end end })
	local c = v.Cuerpo
	v.Lobo = c:CreateTexture(nil, "ARTWORK")
	v.Lobo:SetSize(56, 56)
	K.Pintar(v.Lobo, function(t) t:SetVertexColor(K.Color("acento")) end)
	v.Grande = K.Texto(c, "titulo", "texto")
	v.Grande:SetWordWrap(true)
	v.Linea = K.Texto(c, "nota", "textoSuave")
	v.Linea:SetWordWrap(true)
	v.Barra = K.Progreso(c, { alto = 6, tono = "acento" })
	v.Filtros = K.Segmentos(c, { estilo = "pildoras", opciones = FILTROS, valor = "todas", alCambiar = function(f)
		Cr.SetFiltro(f)
		Ct.Rehacer()
	end })
	v.Sec1 = K.Texto(c, "mayus", "textoTenue")
	v.Sec2 = K.Texto(c, "mayus", "textoTenue")
	v.Accion = K.Boton(c, "", function() if v.alfaAccion then v.alfaAccion() end end, { tipo = "secundario", tam = "chico" })
	v.filas = {}
	v.Empezar = K.Boton(v, L["Empezar"], function() Ct.Empezar() end, { tipo = "primario", icono = "ic-seguir" })
	v.Vista = K.Boton(v, L["Quitar algunas"], function()
		st.vista = st.vista == "elegir" and "paradas" or "elegir"
		Ct.Pintar()
	end, { tipo = "secundario" })
	v.Cerrar2 = K.Boton(v, L["Ahora no"], function() v:Cerrar() end, { tipo = "fantasma" })
	v:SetPie({ v.Vista, v.Empezar }, { v.Cerrar2 })
	v.alAcomodar = function() if v:IsShown() then Ct.Pintar() end end
end
function Ct.Ventana() return v end

local function texto(fs, t, x, y, ancho, lineas)
	if not t or t == "" then fs:Hide() return y end
	K.Escribir(fs, t)
	fs:ClearAllPoints()
	fs:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", x, -y)
	fs:Show()
	return y + K.Parrafo(fs, ancho, lineas or 3)
end

-- Las filas (paradas, casillas o «Para después») desde la fila k.
local function filas(lista, k, x, y, ancho)
	for _, d in ipairs(lista) do
		local f = v.filas[k] or fila(v.Cuerpo)
		v.filas[k] = f
		local h = f:Set(d, ancho)
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", x, -y)
		f:Show()
		y = y + h + K.ESP.xs
		k = k + 1
	end
	return y, k
end

local MAX_PARADAS_LISTA = 40

local pintando = false
function Ct.Pintar()
	if not v or pintando then return end
	pintando = true
	local ok, e = pcall(Ct.PintarYa)
	pintando = false
	if not ok and geterrorhandler then geterrorhandler()(e) end
end

function Ct.PintarYa()
	local m = v.margen or K.ESP.l
	local ancho = v:AnchoCuerpo() - 8
	local x, y = m, K.ESP.m
	local fase = st.fase
	local k = 1
	for _, w in ipairs({ v.Sec1, v.Sec2, v.Accion, v.Filtros, v.Barra }) do w:Hide() end
	-- Arriba: el lobo y lo grande.
	local conLobo = fase ~= "resumen"
	if conLobo then
		v.Lobo:SetTexture(K.Lobo(st.lobo or "atento"))
		v.Lobo:ClearAllPoints()
		v.Lobo:SetPoint("TOP", v.Cuerpo, "TOP", 0, -y)
		v.Lobo:Show()
		y = y + 56 + K.ESP.s
		v.Grande:SetJustifyH("CENTER")
		v.Linea:SetJustifyH("CENTER")
	else
		v.Lobo:Hide()
		v.Grande:SetJustifyH("LEFT")
		v.Linea:SetJustifyH("LEFT")
	end
	y = texto(v.Grande, st.grande, x, y, ancho, 3) + K.ESP.xs
	y = texto(v.Linea, st.linea, x, y, ancho, 4) + K.ESP.m
	if fase == "preparando" or st.midiendo then
		v.Barra:ClearAllPoints()
		v.Barra:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", x, -y)
		if v.Barra.Acomodar then v.Barra:Acomodar(ancho) else v.Barra:SetWidth(ancho) end
		v.Barra:Set(max(0.02, min(1, st.avance or 0)))
		v.Barra:Show()
		y = y + 6 + K.ESP.m
	end
	if st.accion then
		v.Accion:SetTexto(st.accion.texto)
		v.alfaAccion = st.accion.alClic
		v.Accion:ClearAllPoints()
		if conLobo then v.Accion:SetPoint("TOP", v.Cuerpo, "TOP", 0, -y) else v.Accion:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", x, -y) end
		v.Accion:Show()
		y = y + K.ALTO.botonChico + K.ESP.m
	end
	-- Los atajos (no en un plan de unas cuantas).
	if (fase == "resumen" or fase == "vacio") and not st.opts.solo then
		v.Filtros:SetValor(Cr.Filtro())
		v.Filtros:ClearAllPoints()
		v.Filtros:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", x, -y)
		local h = v.Filtros:Acomodar(ancho)
		v.Filtros:Show()
		y = y + h + K.ESP.m
	end
	if fase == "resumen" or fase == "vacio" then
		local lista = {}
		if st.vista == "elegir" then
			y = texto(v.Sec1, K.Mayus(L["Elige cuáles entran"]), x, y, ancho, 1) + K.ESP.s
			for _, it in ipairs(Cr.Lista() or st.lista or {}) do
				if it.enLog and not it.despues then
					local partes = {}
					if it.listo then partes[#partes + 1] = L["Lista"] end
					local zona = it.zona and M.Zona(it.zona)
					if zona then partes[#partes + 1] = zona end
					local entra = Cr.Entra(it, st.opts.solo and { solo = st.opts.solo } or nil)
					lista[#lista + 1] = { id = it.id, titulo = it.titulo, sub = concat(partes, DOT), casilla = entra, apagada = not entra }
				end
			end
		else
			local par = st.paradas or {}
			if #par > 0 then
				y = texto(v.Sec1, K.Mayus(M.Plural(#par, L["%d parada, en este orden"], L["%d paradas, en este orden"])), x, y, ancho, 1) + K.ESP.s
				for i = 1, min(#par, MAX_PARADAS_LISTA) do lista[#lista + 1] = par[i] end
				if #par > MAX_PARADAS_LISTA then
					lista[#lista + 1] = { titulo = format(L["y %d más"], #par - MAX_PARADAS_LISTA), icono = "ic-mas", tono = "textoTenue" }
				end
			end
		end
		y, k = filas(lista, k, x, y, ancho)
		local despues = st.info and st.info.despues or {}
		if #despues > 0 then
			y = y + K.ESP.m
			y = texto(v.Sec2, K.Mayus(format(L["Para después (%d)"], #despues)), x, y, ancho, 1) + K.ESP.s
			local l2 = {}
			for _, d in ipairs(despues) do
				l2[#l2 + 1] = { id = d.id, titulo = d.titulo, sub = d.por, icono = "ic-reloj", tono = "aviso", boton = true }
			end
			y, k = filas(l2, k, x, y, ancho)
		end
	end
	for i = k, #v.filas do v.filas[i]:Hide() end
	v:SetAltoContenido(y + K.ESP.m)
	-- El pie.
	local listo = fase == "resumen" and st.def ~= nil and not st.midiendo
	v.Empezar:SetActivo(listo)
	v.Empezar:SetShown(fase == "resumen")
	v.Vista:SetShown(fase == "resumen")
	local tv = st.vista == "elegir" and L["Ver paradas"] or L["Quitar algunas"]
	if v.alfaVista ~= tv or v.alfaFasePie ~= fase then
		v.alfaVista, v.alfaFasePie = tv, fase
		v.Vista:SetTexto(tv)
		v:SetPie({ v.Vista, v.Empezar }, { v.Cerrar2 })
	end
end

local function mostrar()
	if not v then armarVentana() end
	if not v:IsShown() then v:Abrir() end
	v:Raise()
	Ct.Pintar()
end

local function poner(campos)
	for k2, x in pairs(campos) do st[k2] = x end
	if v and v:IsShown() then Ct.Pintar() end
end

---------------------------------------------------------------------------
-- Armar
---------------------------------------------------------------------------

local function filtroDe()
	if st.opts.solo then return { solo = st.opts.solo } end
	return Cr.Filtro()
end

local function porQueVacio(info)
	local lista = Cr.Lista() or {}
	local enLog = 0
	for _, it in ipairs(lista) do if it.enLog then enLog = enLog + 1 end end
	if enLog == 0 then
		return L["Tu registro está vacío"], L["Toma unas misiones cerca y Alfa las cierra contigo por el camino más corto."],
			{ texto = L["Recoger misiones cerca"], alClic = function() if v then v:Cerrar() end M.Recoger.Ahora() end }, "dormido"
	end
	local f = Cr.Filtro()
	if not st.opts.solo and f ~= "todas" then
		return L["Con ese atajo no queda ninguna"],
			f == "listas" and L["No tienes misiones listas para entregar. Con «Todas mis misiones» entran también las que faltan por terminar."]
				or L["No tienes misiones en esta zona. Con «Todas mis misiones» entran las de las demás zonas."],
			{ texto = L["Con todas"], alClic = function() Cr.SetFiltro("todas") Ct.Rehacer() end }, "atento"
	end
	if info and #(info.despues or {}) > 0 then
		return L["Todas son para después"], L["Las que tienes no se pueden hacer ahora: abajo dice por qué. Mete la que quieras y Alfa la suma a la ruta."], nil, "atento"
	end
	return L["Nada que cerrar"], L["Ninguna de tus misiones entra a la ruta. Revisa «Quitar algunas»: quizá las apagaste."], nil, "atento"
end

local function alArmar(gen, def, motivo, notas, sello, info)
	if gen ~= st.gen or st.cancelado then return end
	if not def then
		st.lista = Cr.Lista() or st.lista
		if motivo == "nada" or motivo == "vacio" then
			local g, l, ac, lobo = porQueVacio(info)
			poner({ fase = "vacio", midiendo = false, def = nil, info = info or {}, grande = g, linea = l, accion = ac, lobo = lobo, paradas = {} })
		elseif motivo == "combat" then
			Ct.Esperar()
		else
			poner({ fase = "error", midiendo = false, def = nil, grande = L["No pude armar tu ruta"], linea = I.TextoMotivo(motivo), lobo = "atento",
				accion = { texto = L["Reintentar"], alClic = function() Ct.Rehacer() end } })
		end
		if st.opts.alListo then K.Llamar(st.opts.alListo, false) end
		return
	end
	st.lista = Cr.Lista()
	local paradas = {}
	for i, paso in ipairs(def.steps or {}) do paradas[#paradas + 1] = paradaDe(paso, i) end
	local primera = paradas[1]
	local linea = primera and format(L["Primera parada: %s."], primera.titulo) or nil
	if info and info.listas and info.listas > 0 and info.misiones and info.listas < info.misiones then
		linea = (linea and (linea .. " ") or "") .. M.Plural(info.listas, L["%d ya está lista para entregar."], L["%d ya están listas para entregar."])
	end
	poner({ fase = "resumen", midiendo = false, def = def, notas = notas, sello = sello, info = info or {}, paradas = paradas,
		grande = Ct.TextoResumen(info), linea = linea, accion = nil, avance = 1 })
	if not on("cerrarResumen") and not st.yaEmpezo then Ct.Empezar() end
end

-- Arma con lo de ahora (el filtro, lo que tocaste) y deja el resumen.
local function armar()
	st.gen = st.gen + 1
	local gen = st.gen
	st.cancelado = false
	if enCombate() then return Ct.Esperar() end
	if st.fase ~= "resumen" and st.fase ~= "vacio" then
		poner({ fase = "preparando", grande = L["Preparando tu ruta…"], linea = L["Reviso tu registro y cargo la base de misiones."], lobo = "atento", accion = nil, avance = 0.04 })
	else
		poner({ midiendo = true, avance = 0.04, linea = L["Midiendo caminos…"] })
	end
	-- Un cuadro después: que la ventana se vea antes de cargar la base (pesa).
	A.After(0.05, function()
		if gen ~= st.gen or st.cancelado then return end
		if enCombate() then return Ct.Esperar() end
		local ok, motivo = I.CodexListo()
		if not ok then
			if motivo == "combat" then return Ct.Esperar() end
			return alArmar(gen, nil, motivo)
		end
		if st.fase == "preparando" then poner({ linea = L["Revisando tu registro…"], avance = 0.08 }) end
		Cr.Armar({ filtro = filtroDe(), alAvanzar = function(f)
			if gen ~= st.gen then return end
			local pct = floor(min(1, max(0, f or 0)) * 100 + 0.5)
			st.avance = 0.1 + 0.85 * min(1, f or 0)
			if st.fase == "preparando" then st.grande = L["Preparando tu ruta…"] end
			st.linea = format(L["Midiendo caminos… %d %%"], pct)
			if v and v:IsShown() then Ct.Pintar() end
		end }, function(def, motivo, notas, sello, info) alArmar(gen, def, motivo, notas, sello, info) end)
	end)
end

-- En combate: la ventana lo dice y sigue sola al salir.
function Ct.Esperar()
	poner({ fase = "espera", midiendo = false, grande = L["En cuanto salgas de combate"],
		linea = L["Armo tu ruta solo al terminar la pelea: no tienes que volver a darle clic."], lobo = "atento", accion = nil })
	N.FueraDeCombate("rutas.cerrarTodo", function()
		if v and v:IsShown() and st.fase == "espera" then st.fase = "preparando" armar() end
	end)
end

function Ct.Rehacer()
	if not (v and v:IsShown()) then return end
	armar()
end

-- Una casilla: dentro o fuera; se vuelve a medir medio segundo después del último clic.
function Ct.Alternar(qid, dentro)
	qid = tonumber(qid)
	if not qid then return end
	if st.opts.solo then
		st.opts.solo[qid] = dentro and true or nil
	else
		local it
		for _, x in ipairs(Cr.Lista() or {}) do if x.id == qid then it = x end end
		local ya = it and Cr.Entra(it)
		if dentro and not ya then
			-- La apagaste aquí: solo se quita esa marca (el atajo vuelve a mandar);
			-- si ni así entra, se mete a mano.
			local marcas = pj().marcas
			if marcas[qid] == "fuera" or marcas[qid] == "quitada" then marcas[qid] = nil end
			if not (it and Cr.Entra(it)) then Cr.Agregar(qid) end
		elseif not dentro and ya then
			Cr.Quitar(qid)
		end
	end
	st.def = nil
	poner({ midiendo = true, linea = L["Midiendo caminos…"] })
	N.Una("rutas.cerrarTodo.rehacer", 0.5, function() Ct.Rehacer() end)
end

-- «Meterla»: una de «Para después» entra a la ruta (tú decides).
function Ct.Meter(qid)
	qid = tonumber(qid)
	if not qid then return end
	if st.opts.solo then st.opts.solo[qid] = true end
	pj().incluir[qid] = true
	pj().marcas[qid] = nil
	M.Avisar("CERRAR")
	Ct.Rehacer()
end

-- El botón de todos lados.
function Ct.Abrir(opts)
	opts = type(opts) == "table" and opts or {}
	-- Sin nada que preguntar: directo, como antes (rutas.cerrarResumen apagado).
	st.opts = opts
	st.vista = "paradas"
	st.def, st.info, st.paradas, st.accion, st.midiendo = nil, nil, nil, nil, false
	st.yaEmpezo = false
	st.fase = "preparando"
	if opts.filtro then
		Cr.SetFiltro(opts.filtro)
	elseif opts.origen ~= "pagina" and not opts.solo then
		-- 1.3.9 (1): desde Hoy, el menú, el rastreador o el Escritorio,
		-- siempre todas: el atajo de la última vez («solo listas») no se
		-- queda escondido, y lo que apagaste en otro plan vuelve a entrar
		-- (lo marcado para abandonar y lo que quitaste desde el rastreador,
		-- «quitada», se respetan: 1.3.9, revisión 7).
		Cr.SetFiltro("todas")
		local marcas = pj().marcas
		for qid, m in pairs(marcas) do if m == "fuera" then marcas[qid] = nil end end
	end
	if v then v:SetTitulo(opts.titulo or L["Cerrar mis misiones"], nil, "ic-misiones") end
	st.grande, st.linea, st.lobo, st.avance = L["Preparando tu ruta…"], L["Reviso tu registro y cargo la base de misiones."], "atento", 0.02
	mostrar()
	if v then v:SetTitulo(opts.titulo or L["Cerrar mis misiones"], nil, "ic-misiones") end
	armar()
	return true
end

---------------------------------------------------------------------------
-- Empezar y la cuenta del camino
---------------------------------------------------------------------------

local function cuenta() local c = pj().cerrarCuenta return type(c) == "table" and c or nil end
function Ct.Cuenta() return cuenta() end

local function xpDeAhora()
	local xp = UnitXP and tonumber(UnitXP("player")) or 0
	return xp
end

function Ct.Empezar()
	if not st.def then return false end
	st.yaEmpezo = true
	local ok = Cr.Instalar(st.def, st.notas, st.sello)
	if ok then
		local dentro = {}
		for qid in pairs(st.sello and st.sello.dentro or {}) do dentro[qid] = true end
		pj().cerrarCuenta = { inicio = time and time() or 0, xp = 0, n = 0, total = st.info and st.info.misiones or 0,
			dentro = dentro, hechas = {}, nivel = UnitLevel and UnitLevel("player") or nil, xp0 = xpDeAhora() }
		if v then v:Cerrar() end
		Ct.PintarMapa()
		if Cr.Lista then M.Avisar("CERRAR") end
	end
	if st.opts.alListo then K.Llamar(st.opts.alListo, ok) end
	return ok
end

-- ¿Queda en tu registro alguna de las del plan?
local function quedan(c)
	local Cp = CP()
	local n = 0
	for qid in pairs(c.dentro or {}) do
		if not c.hechas[qid] and Cp and Cp.IsOnQuest and Cp.IsOnQuest(qid) then n = n + 1 end
	end
	return n
end

local function festejar(c)
	pj().cerrarCuenta = nil
	local seg = max(60, (time and time() or 0) - (c.inicio or 0))
	local partes = { M.Plural(c.n, L["%d misión cerrada"], L["%d misiones cerradas"]) }
	if c.xp > 0 then partes[#partes + 1] = format(L["+%s XP"], M.Miles(c.xp)) end
	partes[#partes + 1] = format(L["en %s"], M.Minutos(seg))
	local linea = concat(partes, DOT)
	if K.Anuncio then
		pcall(K.Anuncio, { estilo = "llegada", lobo = "aullando", sobre = L["Cerrar mis misiones"], titulo = L["¡Cerraste tu ruta!"],
			texto = linea, segundos = 7, prioridad = 2, clave = "rutas.cerrarFin" })
	end
	local Lya = rawget(_G, "AlfaLya")
	if type(Lya) == "table" and type(Lya.Decir) == "function" then
		pcall(Lya.Decir, format(L["¡Auuu! Registro limpio: %s. Eso merece una salchicha."], linea), { id = "rutas.cerrarFin", aullar = true })
	else
		M.Aviso(L["¡Cerraste tu ruta!"], linea, { lobo = "aullando", importante = "siempre" })
	end
	Ct.PintarMapa()
end
Ct.Festejar = festejar

-- Después de cada entrega: «¡Lista! Sigue: X», o el festejo si fue la última.
local function trasEntrega(qid)
	local c = cuenta()
	if not c then return end
	if quedan(c) == 0 then return festejar(c) end
	if not on("cerrarSigue") then return end
	if not (M.Guias.Activa and M.Guias.Activa() == "liberar") then return end
	local e = E()
	local vivo = e and e.GetLiveStep and e.GetLiveStep()
	local vista = vivo and e.GetStepView and e.GetStepView(vivo)
	local titulo = vista and vista.title
	if type(titulo) ~= "string" or titulo == "" then return end
	local falta = quedan(c)
	M.Aviso(format(L["¡Lista! Sigue: %s"], titulo), M.Plural(falta, L["Te falta %d misión de tu ruta."], L["Te faltan %d misiones de tu ruta."]),
		{ icono = "ic-exito", clave = "rutas.cerrarSigue", duracion = 6 })
end

A.RegisterEvent("QUEST_TURNED_IN", function(_, qid, xp)
	local c = cuenta()
	qid = tonumber(qid)
	if not (c and qid and c.dentro[qid]) or c.hechas[qid] then return end
	c.hechas[qid] = true
	c.n = c.n + 1
	c.xp = c.xp + (tonumber(xp) or 0)
	-- Un momento: que el motor pase al paso que sigue.
	A.After(1.5, function() trasEntrega(qid) end)
end)

-- Abandonar la última también termina la cuenta (sin festejo si no cerraste ninguna).
A.RegisterEvent("QUEST_REMOVED", function(_, qid)
	local c = cuenta()
	qid = tonumber(qid)
	if not (c and qid and c.dentro[qid]) then return end
	A.After(1.5, function()
		local c2 = cuenta()
		if not c2 or quedan(c2) > 0 then return end
		if c2.n > 0 then festejar(c2) else pj().cerrarCuenta = nil Ct.PintarMapa() end
	end)
end)

---------------------------------------------------------------------------
-- 9 y 33: la ruta en el mapa de Alfa y en el del juego
---------------------------------------------------------------------------
-- Una capa de Alfa.Pins con las paradas que faltan del plan, numeradas, y el
-- camino entre ellas en puntitos (mismo continente). El mapa de Alfa la
-- dibuja por AlfaMundo.RegistrarCapa; el del juego, por la capa misma.

local MAX_PUNTOS = 160
local PASO_PUNTO = 45 -- yardas entre puntitos (más si el tramo es largo)
local ESTADO_FUERA = { na = true, done = true, skipped = true }

local function rgb(token)
	local r, g, b = K.Color(token)
	return { r or 1, g or 1, b or 1, 1 }
end

function Ct.Pines()
	local out = {}
	local e = E()
	if not (e and e.GetGuide and M.Guias.Activa and M.Guias.Activa() == "liberar") then return out end
	local vivo = e.GetLiveStep and e.GetLiveStep()
	if not vivo then return out end
	local Cp = CP()
	local acento, tenue = rgb("acento"), rgb("textoSuave")
	local antes, puntos = nil, 0
	local n = 0
	for s = vivo, e.GetStepCount() do
		local vista = e.GetStepView(s)
		if vista and not ESTADO_FUERA[vista.status or ""] then
			local g
			-- La entrega o la toma manda (no su «Completa la misión», que va en el lugar de los objetivos).
			for _, x in ipairs(vista.goals or {}) do
				if (x.t == "turnin" or x.t == "accept") and x.map and x.x and x.y and x.status ~= "done" then g = x break end
			end
			if not g then
				for _, x in ipairs(vista.goals or {}) do
					if x.map and x.x and x.y and (x.status == "active" or x.status == "pending" or x.status == nil) then g = x break end
				end
			end
			if g then
				n = n + 1
				local titulo = (type(vista.title) == "string" and vista.title ~= "") and vista.title or format(L["Parada %d"], n)
				local icono = "map:target"
				for _, x in ipairs(vista.goals or {}) do
					if x.t == "turnin" then icono = "map:quest-turnin" break end
					if x.t == "accept" then icono = "map:quest-available" end
				end
				out[#out + 1] = { map = g.map, x = g.x, y = g.y, f = g.f, icon = icono, size = n == 1 and 18 or 15,
					color = n == 1 and acento or tenue, badge = tostring(n), priority = n == 1 and 3 or 2, state = n == 1 and "focus" or nil,
					tooltip = function(tip)
						tip:SetText(format(L["%d. %s"], n, titulo), K.Color("texto"))
						local z = M.Zona(g.map)
						if z then tip:AddLine(z, K.Color("textoSuave")) end
						tip:AddLine(L["Parada de «Cerrar mis misiones»"], K.Color("acento"))
					end }
				-- El camino desde la parada de antes, en puntitos.
				if antes and puntos < MAX_PUNTOS then
					local c1, x1, y1, c2, x2, y2
					if Cp and Cp.MapToWorld then
						c1, x1, y1 = Cp.MapToWorld(antes.map, antes.x, antes.y, antes.f)
						c2, x2, y2 = Cp.MapToWorld(g.map, g.x, g.y, g.f)
					end
					if not (c1 and c2) and antes.map == g.map then
						-- Sin coordenadas del mundo, en el mismo mapa: por su porcentaje.
						local d = ((g.x - antes.x) ^ 2 + (g.y - antes.y) ^ 2) ^ 0.5 * 35
						local cuantos = min(24, floor(d / PASO_PUNTO))
						for k = 1, cuantos - 1 do
							if puntos >= MAX_PUNTOS then break end
							local t = k / cuantos
							out[#out + 1] = { map = g.map, x = antes.x + (g.x - antes.x) * t, y = antes.y + (g.y - antes.y) * t, f = g.f,
								icon = "map:pin-small", medal = false, size = 5, color = { acento[1], acento[2], acento[3], 0.7 }, priority = 1 }
							puntos = puntos + 1
						end
					elseif c1 and c1 == c2 and x1 and x2 then
						local d = ((x2 - x1) ^ 2 + (y2 - y1) ^ 2) ^ 0.5
						local cuantos = min(24, floor(d / PASO_PUNTO))
						for k = 1, cuantos - 1 do
							if puntos >= MAX_PUNTOS then break end
							local t = k / cuantos
							out[#out + 1] = { c = c1, wx = x1 + (x2 - x1) * t, wy = y1 + (y2 - y1) * t, icon = "map:pin-small", medal = false,
								size = 5, color = { acento[1], acento[2], acento[3], 0.7 }, priority = 1 }
							puntos = puntos + 1
						end
					end
				end
				antes = g
			end
		end
	end
	return out
end

local firma
function Ct.PintarMapa(forzar)
	if forzar then firma = nil end
	local P = A.Pins
	if not (P and P.SetLayer and P.ClearLayer) then return end
	local pines = on("cerrarMapa") and Ct.Pines() or {}
	if #pines == 0 then
		if firma ~= "" then P.ClearLayer(CAPA) firma = "" end
		return
	end
	local partes = {}
	for _, p in ipairs(pines) do if p.badge then partes[#partes + 1] = p.badge .. ":" .. p.map .. ":" .. p.x .. ":" .. p.y end end
	local f = concat(partes, "|")
	if f == firma then return end
	firma = f
	pcall(P.SetLayer, CAPA, pines, { world = true, minimap = false, edge = false })
end

local pronto = false
local function repintarPronto()
	if pronto then return end
	pronto = true
	A.After(0.5, function()
		pronto = false
		Ct.PintarMapa()
	end)
end
for _, msg in ipairs({ "STEP_CHANGED", "GUIDE_CHANGED", "TABS_CHANGED" }) do A.On(msg, repintarPronto) end

A.OnLogin(function()
	local Mu = rawget(_G, "AlfaMundo")
	if type(Mu) == "table" and type(Mu.RegistrarCapa) == "function" then
		pcall(Mu.RegistrarCapa, { id = CAPA, grupo = L["Viajes"], nombre = L["Tu ruta de «Cerrar mis misiones»"],
			ayuda = L["Las paradas que faltan, numeradas, con el camino en puntitos."], color = "acento", activa = on("cerrarMapa"),
			esencial = true, zoom = 1, -- la ruta cruza zonas: se ve desde el continente
			alCambiar = function(activa) A.Set(M.ID .. ".cerrarMapa", activa and true or false) firma = nil Ct.PintarMapa() end })
	end
	A.After(3, repintarPronto)
end)

A.On("SETTING_CHANGED", function(path)
	if path == M.ID .. ".cerrarMapa" then firma = nil Ct.PintarMapa() end
end)
