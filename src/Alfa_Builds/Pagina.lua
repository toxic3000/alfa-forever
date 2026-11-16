-- Alfa - Builds: la página Talentos, hecha con el Kit (Toxic / La Jauría). GPL-3.0.
--
-- Una página que guía (docs/KIT.md, plantilla Tablero):
--   1. Arriba, en grande, qué talento poner ahora y por qué, con Aplicar
--      (fuera de combate, con la vista previa de lo que cambia). Si no hay
--      punto libre, cuál sigue y en qué nivel llega; si tus puntos van por
--      otro lado, qué hacer; si el build está completo, el siguiente paso.
--   2. Tu camino: qué quieres hacer y cómo te gusta jugar, en dos clics, y
--      el build que resulta con su avance en huellas.
--   3. Tu árbol: las tres ramas con tus puntos y el plan encima (Lienzo.lua).
--   4. El plan por nivel: lo que falta, en orden, con su porqué (lo hecho se
--      pliega).
--   5. Consejos del build, si los trae.
--   6. Más para tu personaje: equipo y estadísticas, compartir, combate.
--   7. Los avisos, al final.
-- Equipo y Compartir son vistas de la misma página, con "Volver a Talentos".
-- Las ayudas de combate son de su propia página (área de combate): aquí solo
-- su tarjeta, y solo si esa página existe.
--
--   P.Construir(view) ; P.Rehacer() ; P.Ir(vista) ; P.Visible()

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local K = N.Kit
local T = M.Arbol
local P = {}
M.Pagina = P

local floor, max, min, format = math.floor, math.max, math.min, string.format
local ESP = K.ESP

local view            -- la vista de la ventana principal
local vista = "talentos"
local vistas = {}     -- clave -> { t = plantilla, llenar = fn }
local ui = {}         -- estado de la página (plegados, mensajes)

local function nivel() return A.Compat.Readable(UnitLevel("player")) or 1 end
local function nivelDe(i) return 9 + i end

local PLAN_VISIBLE = 6 -- talentos que siguen, a la vista antes de "Ver todo el plan"

local NOMBRE_ARMAS = { ["2h"] = L["Arma de dos manos"], dual = L["Dos armas"], escudo = L["Arma y escudo"] }

---------------------------------------------------------------------------
-- Ayudas
---------------------------------------------------------------------------

-- El ícono del juego (hechizo, profesión) en una tarjeta del Kit, que tiñe
-- los suyos; sin textura, la tarjeta vuelve a su ícono de Alfa.
local function iconoJuego(t, tex)
	local ic = t and t.Icono
	if not ic then return end
	if not ic.alfaTamKit then ic.alfaTamKit = K.num(ic:GetWidth(), 22) end
	if tex then
		ic:SetTexture(tex)
		ic.alfaColor = nil
		ic:SetVertexColor(1, 1, 1, 1)
		ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		local tam = K.num(t.Baldosa:GetWidth(), 40) - 4
		ic:SetSize(tam, tam)
	else
		ic:SetTexCoord(0, 1, 0, 1)
		ic:SetSize(ic.alfaTamKit, ic.alfaTamKit)
	end
end

-- El cuadro del juego de un hechizo, con líneas de Alfa debajo.
local function infoHechizo(dueno, spell, lineas)
	if not (spell and GameTooltip) then return end
	GameTooltip:SetOwner(dueno, "ANCHOR_RIGHT")
	pcall(GameTooltip.SetSpellByID, GameTooltip, spell)
	if lineas and #lineas > 0 then
		GameTooltip:AddLine(" ")
		for _, l in ipairs(lineas) do
			local r, g, b = K.Color(l[2] or "textoSuave")
			GameTooltip:AddLine(l[1], r, g, b, true)
		end
	end
	GameTooltip:Show()
end

local function sinInfo(dueno)
	if GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() == dueno then GameTooltip:Hide() end
end

local function enlazarHechizo(spell)
	if not (spell and IsModifiedClick and IsModifiedClick("CHATLINK")) then return end
	local link = A.Compat.SpellLink and A.Compat.SpellLink(spell)
	local insertar = (ChatFrameUtil and ChatFrameUtil.InsertLink) or ChatEdit_InsertLink
	if link and insertar then insertar(link) end
end

-- La ventana de talentos del juego, como su tecla. Nunca en combate ni con
-- la interfaz de mando, que maneja sus propias ventanas.
local function abrirVentanaJuego()
	if InCombatLockdown() or (A.GamepadUI and A.GamepadUI()) then return end
	local U = PlayerSpellsUtil
	if U and U.ToggleClassTalentOrSpecFrame then pcall(U.ToggleClassTalentOrSpecFrame)
	elseif U and U.OpenToClassTalentsTab then pcall(U.OpenToClassTalentsTab) end
end

-- Una sección y su contenido, con el ritmo del Kit (12 entre ambos).
local function grupo(padre, titulo, opts)
	local g = K.Pila(padre, { espacio = ESP.m })
	g.Seccion = g:Agregar(K.Seccion(g, titulo, opts))
	return g
end

-- Un párrafo como bloque de una pila.
local function parrafo(padre, rol, color, lineas)
	local f = CreateFrame("Frame", nil, padre)
	f.Texto = K.Texto(f, rol or "nota", color or "textoSuave")
	f.Texto:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	function f:Set(s) K.Escribir(self.Texto, s or "") K.Mostrar(self, (s or "") ~= "") end
	function f:Acomodar(ancho)
		local h = K.Parrafo(self.Texto, ancho, lineas)
		self:SetSize(ancho, h)
		return h
	end
	return f
end

-- Mueve la ventana principal hasta un bloque de la página.
local function irABloque(b)
	local O = A.UI and A.UI.Options
	local win = O and O.frame
	local W = A.Widgets
	if not (b and view and win and win.Scroll and W and W.ScrollTo) then return end
	local arriba, top = K.num(view:GetTop(), 0), K.num(b:GetTop(), 0)
	if arriba > 0 and top > 0 then W.ScrollTo(win.Scroll, max(0, arriba - top - ESP.base)) end
end

local function alInicio()
	local O = A.UI and A.UI.Options
	local win = O and O.frame
	local W = A.Widgets
	if win and win.Scroll and W and W.ScrollTo then W.ScrollTo(win.Scroll, 0) end
end

---------------------------------------------------------------------------
-- 1. Qué poner ahora (la tarjeta grande)
---------------------------------------------------------------------------

local function puntosFuera(st)
	local n = 0
	for _, f in ipairs(st and st.fuera or {}) do n = n + (f.rangos or 0) end
	return n
end

local function nombreRama(b)
	return b and M.NombreSpec(b) or nil
end

-- -> datos de la tarjeta, textura del juego para su ícono (o nil)
local function ahora(e)
	local b, st, vivo = e.build, e.st, e.vivo
	if not b then
		if not M.DatosClase() then
			return { lobo = "dormido", tono = "neutro", sobre = L["Tus talentos"],
				titulo = L["Alfa todavía no tiene builds para tu clase"],
				texto = L["Si alguien de la manada te pasa uno, impórtalo y Alfa te guía con él punto por punto."],
				accion = { texto = L["Importar un build"], icono = "ic-mas", alClic = function() P.Ir("compartir") end } }
		end
		return { icono = "ic-reloj", tono = "neutro", titulo = L["Alfa está leyendo tu clase"], texto = L["En unos segundos aparece tu build."] }
	end
	if e.foto or not st then
		return { icono = "ic-reloj", tono = "neutro", sobre = L["Tus talentos"], titulo = L["El juego todavía no carga tu árbol"],
			texto = L["Abre la ventana de talentos del juego una vez o espera unos segundos: en cuanto Alfa la lea, te dice qué poner. Mientras, abajo ves tu build."],
			accion = { texto = L["Abrir la ventana de talentos"], icono = "ic-talentos", alClic = abrirVentanaJuego } }
	end
	local s = M.Siguiente(e)
	if not s then
		return { lobo = "aullando", tono = "exito", sobre = L["Build completo"], titulo = format(L["Tienes todo %s"], b.titulo or ""),
			texto = format(L["Tus %d puntos están donde tu build los pide. Lo que sigue es el equipo: piezas con las estadísticas que le sirven a tu build."], b.total or 0),
			accion = { texto = L["Ver mi equipo"], icono = "ic-bolsas", alClic = function() P.Ir("equipo") end } }
	end
	local fuera = puntosFuera(st)
	local libres = vivo.libres or 0
	local insignias = { { format(L["Rango %d de %d"], s.rango, s.max), "acento" } }
	local rama = nombreRama(b)
	if rama then insignias[#insignias + 1] = { rama, "clase" } end
	local verArbol = { texto = L["Verlo en el árbol"], alClic = function() irABloque(ui.arbol) end }
	-- Tus puntos van por otro camino y no te quedan libres (un punto suelto
	-- fuera del plan no cambia el consejo: se avisa con una insignia).
	local desviado = fuera > 0 and (fuera >= 3 or fuera > st.hechos)
	if libres == 0 and desviado then
		local d = { icono = "ic-aviso", tono = "aviso", sobre = L["Tus talentos"], titulo = L["Tus puntos van por otro camino"],
			texto = format(L["Tienes %d puntos fuera de %s. Alfa nunca quita talentos: para seguir este build, reinicia tus talentos con tu entrenador de clase y Alfa te los vuelve a poner con un clic. O elige el build de la rama que ya llevas."], fuera, b.titulo or ""),
			insignias = { { format(L["%d puntos fuera del plan"], fuera), "aviso" } } }
		local mia = M.SpecActual()
		if mia and mia ~= b.spec then
			local e2 = M.Eleccion()
			local otro = M.Elegir(e2.objetivo, e2.estilo, mia)
			if otro and otro.spec == mia then
				d.accion = { texto = format(L["Seguir un build de %s"], M.NombreSpec(otro)), icono = "ic-seguir",
					alClic = function() M.ElegirBuild(e2.objetivo, e2.estilo, mia) P.Rehacer() end }
			end
		end
		d.secundaria = { texto = L["Abrir la ventana de talentos"], alClic = abrirVentanaJuego }
		return d
	end
	-- Hay punto libre y se puede tomar.
	if s.ahora then
		insignias[#insignias + 1] = { libres == 1 and L["1 punto libre"] or format(L["%d puntos libres"], libres), "acento" }
		if fuera > 0 then insignias[#insignias + 1] = { format(L["%d puntos fuera del plan"], fuera), "aviso" } end
		if InCombatLockdown() then insignias[#insignias + 1] = { L["En combate: espera a terminar"], "aviso" } end
		return {
			icono = "ic-talentos", tono = "acento", sobre = L["Pon ahora"], titulo = s.nombre, texto = s.porque, lineas = 4,
			insignias = insignias,
			accion = { texto = s.compras > 1 and format(L["Aplicar %d puntos"], s.compras) or L["Aplicar"], icono = "ic-exito", alClic = function() M.PedirAplicar() end },
			secundaria = verArbol,
		}, s.icono
	end
	-- Hay punto libre, pero lo que sigue no está en tu árbol.
	if libres > 0 then
		return { icono = "ic-aviso", tono = "aviso", sobre = L["Tus talentos"], titulo = L["Lo que sigue en tu build no está en tu árbol"],
			texto = format(L["Tienes %d puntos libres, pero los talentos que siguen en %s no existen en tu árbol (puede que cambiaran con un parche). Ponlos a mano en la ventana del juego o prueba otro estilo."], libres, b.titulo or ""),
			insignias = { { libres == 1 and L["1 punto libre"] or format(L["%d puntos libres"], libres), "acento" } },
			accion = { texto = L["Abrir la ventana de talentos"], icono = "ic-talentos", alClic = abrirVentanaJuego } }
	end
	-- Sin punto libre: cuál sigue y cuándo llega.
	insignias[#insignias + 1] = { format(L["Llega en el nivel %d"], s.nivel), "neutro" }
	if fuera > 0 then insignias[#insignias + 1] = { format(L["%d puntos fuera del plan"], fuera), "aviso" } end
	return {
		icono = "ic-talentos", tono = "acento",
		sobre = (st.hechos == 0 and nivel() < 10) and L["Tu primer talento"] or L["Tu siguiente talento"],
		titulo = s.nombre, texto = s.porque, lineas = 4, insignias = insignias, secundaria = verArbol,
	}, s.icono
end

---------------------------------------------------------------------------
-- 2. Tu camino: objetivo, estilo y rama en dos clics, y el build que resulta
---------------------------------------------------------------------------

local function bloqueCamino(padre)
	local c = K.Pila(padre, { espacio = ESP.m })
	c.Seccion = c:Agregar(K.Seccion(c, L["Tu camino"]))
	c.Panel = c:Agregar(CreateFrame("Frame", nil, c))
	c.Panel.caja = K.Caja(c.Panel, { fondo = "panel", borde = "linea", corte = K.CORTE.panel })
	c.filas = {}
	local function fila(titulo, alCambiar)
		local f = {}
		f.Titulo = K.Texto(c.Panel, "etiqueta", "textoSuave")
		K.Escribir(f.Titulo, titulo)
		f.Seg = K.Segmentos(c.Panel, { estilo = "segmentos", opciones = {}, alCambiar = alCambiar })
		c.filas[#c.filas + 1] = f
		return f
	end
	c.Objetivo = fila(L["Quiero"], function(v)
		local e = M.Eleccion()
		M.ElegirBuild(v, e.estilo, nil)
		P.Rehacer()
	end)
	c.Estilo = fila(L["Cómo juego"], function(v)
		local e = M.Eleccion()
		local b = M.BuildElegido()
		M.ElegirBuild(e.objetivo, v, b and b.spec)
		P.Rehacer()
	end)
	c.Rama = fila(L["Rama"], function(v)
		local e = M.Eleccion()
		M.ElegirBuild(e.objetivo, e.estilo, v)
		P.Rehacer()
	end)
	c.Build = c:Agregar(K.Tarjeta(c, { variante = "normal" }))

	function c:Llenar(e)
		local el = M.Eleccion()
		local b = e.build
		local ops = {}
		for _, o in ipairs(M.OBJETIVOS) do
			local hay = M.Hay(o.clave)
			ops[#ops + 1] = { valor = o.clave, texto = o.nombre,
				ayuda = hay and o.desc or (o.desc .. " " .. L["Tu clase todavía no tiene uno propio: Alfa usa el más parecido."]) }
		end
		self.Objetivo.Seg:SetOpciones(ops)
		self.Objetivo.Seg:SetValor(el.objetivo)
		ops = {}
		for _, s in ipairs(M.ESTILOS) do
			local hay = M.Hay(el.objetivo, s.clave)
			ops[#ops + 1] = { valor = s.clave, texto = s.nombre,
				ayuda = hay and s.desc or (s.desc .. " " .. L["Para lo que elegiste no hay uno con este estilo: Alfa usa el más cercano."]) }
		end
		self.Estilo.Seg:SetOpciones(ops)
		self.Estilo.Seg:SetValor(el.estilo)
		-- Ramas posibles para el objetivo (solo si hay más de una).
		local ramas, vistas_ = {}, {}
		local dc = M.DatosClase()
		for _, x in ipairs(M.Builds()) do
			if x.objetivo == el.objetivo and not vistas_[x.spec] then
				vistas_[x.spec] = true
				local sp = dc and dc.especialidades and dc.especialidades[x.spec]
				ramas[#ramas + 1] = { valor = x.spec, texto = sp and sp.nombre or x.spec, ayuda = sp and sp.desc or nil, orden = sp and sp.indice or 9 }
			end
		end
		table.sort(ramas, function(a, z) return a.orden < z.orden end)
		self.Rama.Seg:SetOpciones(ramas)
		self.Rama.Seg:SetValor(b and b.spec)
		self.Rama.oculta = #ramas < 2
		-- El build que resulta.
		K.Mostrar(self.Build, b ~= nil)
		if not b then return end
		local insignias = {}
		local rama = M.NombreSpec(b)
		if rama then insignias[#insignias + 1] = { rama, "clase" } end
		if b.armas and NOMBRE_ARMAS[b.armas] then insignias[#insignias + 1] = { NOMBRE_ARMAS[b.armas], "neutro" } end
		local rec = M.Recomendado(b.objetivo)
		if rec and rec.id == b.id then insignias[#insignias + 1] = { L["Recomendado por Alfa"], "acento" } end
		if b.importado then insignias[#insignias + 1] = { L["Importado"], "mazmorra" } end
		local exacto = M.EleccionExacta()
		local ayuda
		if not exacto then
			insignias[#insignias + 1] = { L["Lo más parecido"], "aviso" }
			local o, s = M.Objetivo(el.objetivo), M.Estilo(el.estilo)
			ayuda = format(L["No hay un build exacto para %s y %s: este es el que más se parece."], o and o.nombre or "", s and s.nombre or "")
		end
		local st = e.st
		local hechos, total = st and not e.foto and st.hechos or 0, b.total or 0
		self.Build:Set({
			icono = "ic-talentos", sobre = L["Tu build"], titulo = b.titulo or b.id, texto = b.resumen, lineas = 3,
			insignias = insignias, ayuda = ayuda,
			progreso = (total > 0 and not e.foto) and { actual = hechos, total = total, huellas = true,
				texto = format(L["%d de %d puntos"], hechos, total) } or nil,
		})
		local sp = dc and dc.especialidades and dc.especialidades[b.spec]
		iconoJuego(self.Build, sp and A.Compat.SpellIcon(sp.icono) or nil)
	end

	-- Las filas de elección: el nombre en una columna y los segmentos al lado.
	local acomodarPila = c.Acomodar
	function c:Acomodar(ancho)
		local pad = ESP.base
		local col = 0
		for _, f in ipairs(self.filas) do col = max(col, K.Ajustar(f.Titulo, 160)) end
		col = col + ESP.l
		local y = pad
		local visibles = 0
		for _, f in ipairs(self.filas) do
			local ver = not f.oculta
			f.Titulo:SetShown(ver)
			f.Seg:SetShown(ver)
			if ver then
				if visibles > 0 then y = y + ESP.s end
				visibles = visibles + 1
				local h = f.Seg:Acomodar(ancho - 2 * pad - col)
				f.Seg:ClearAllPoints()
				f.Seg:SetPoint("TOPLEFT", self.Panel, "TOPLEFT", pad + col, -y)
				f.Titulo:ClearAllPoints()
				f.Titulo:SetPoint("LEFT", self.Panel, "TOPLEFT", pad, -(y + floor(h / 2)))
				y = y + h
			end
		end
		self.Panel:SetHeight(y + pad)
		return acomodarPila(self, ancho)
	end
	return c
end

---------------------------------------------------------------------------
-- 4. El plan por nivel
---------------------------------------------------------------------------

local ESTADO = {
	hecho = { L["Hecho"], "exito" }, siguiente = { L["Toca ahora"], "acento" },
	pendiente = { L["Más adelante"], "neutro" }, falta = { L["No está en tu árbol"], "aviso" },
}

-- Las entradas del build (un talento subido hasta un rango) con su avance.
local function entradas(e)
	local b, st, res, vivo = e.build, e.st, e.res, e.vivo
	local out = {}
	for _, p in ipairs(b.picks) do
		local x = out[p.entrada]
		if not x then
			x = { entrada = p.entrada, spell = p.spell, desde = p.i, hasta = p.i, rank = p.rank, primerRango = p.rank, estados = {}, pick = p }
			out[p.entrada] = x
		end
		x.hasta, x.rank = p.i, p.rank
		x.estados[(st and st.estadoPick[p.i]) or "pendiente"] = true
	end
	local lista = {}
	for i = 1, #(b.talentos or {}) do if out[i] then lista[#lista + 1] = out[i] end end
	for _, x in ipairs(lista) do
		x.estado = (x.estados.falta and "falta") or (x.estados.siguiente and "siguiente") or (x.estados.pendiente and "pendiente") or "hecho"
		local id = res and res.nodo[x.spell]
		local n = id and vivo and vivo.nodos[id]
		x.max = n and n.max or x.rank
		x.nombre = (n and n.nombre) or T.Nombre(x.spell) or (b.talentos[x.entrada] and b.talentos[x.entrada][3]) or tostring(x.spell)
		x.icono = (n and n.icono) or T.Icono(x.spell)
		x.porque = M.PorQue(b, x.pick)
	end
	return lista
end

local function textoNiveles(x)
	local a, z = nivelDe(x.desde), nivelDe(x.hasta)
	if a == z then return format(L["Nv %d"], a) end
	return format(L["Nv %d-%d"], a, z)
end

local function textoRango(x)
	if x.primerRango and x.primerRango ~= x.rank then return format("%d-%d/%d", x.primerRango, x.rank, x.max or x.rank) end
	return format("%d/%d", x.rank, x.max or x.rank)
end

local function filaPlan(padre)
	local f = CreateFrame("Button", nil, padre)
	f:RegisterForClicks("LeftButtonUp")
	f.velo = K.Velo(f, 0, 0.03)
	f.Nivel = K.Texto(f, "numero", "textoTenue")
	f.Icono = f:CreateTexture(nil, "ARTWORK")
	f.Icono:SetSize(28, 28)
	f.Icono:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.Marco = K.Borde(f.Icono, 0, "OVERLAY", f)
	K.Pintar(f, function(x) x.Marco:Color(x.alfaBorde or "lineaFuerte") end)
	f.Nombre = K.Texto(f, "cuerpo", "texto")
	f.Rango = K.Texto(f, "pequeno", "textoTenue")
	f.Por = K.Texto(f, "nota", "textoSuave")
	f.Estado = K.Insignia(f, "", "neutro")
	f:SetScript("OnEnter", function(self)
		self.velo:Show()
		infoHechizo(self, self.spell, self.lineas)
	end)
	f:SetScript("OnLeave", function(self) self.velo:Hide() sinInfo(self) end)
	f:SetScript("OnClick", function(self) enlazarHechizo(self.spell) end)
	function f:Set(x, foto)
		self.spell = x.spell
		K.Escribir(self.Nivel, textoNiveles(x))
		self.Icono:SetTexture(x.icono or "Interface\\Icons\\INV_Misc_QuestionMark")
		self.Icono:SetDesaturated(x.estado == "falta")
		K.Escribir(self.Nombre, x.nombre)
		K.Escribir(self.Rango, textoRango(x))
		K.Escribir(self.Por, x.porque or "")
		local est = ESTADO[x.estado] or ESTADO.pendiente
		self.Estado:Set(est[1], est[2])
		self.Estado:SetShown(not foto)
		self.alfaBorde = (not foto and x.estado == "siguiente") and "acento" or (x.estado == "hecho" and not foto) and "exito" or "lineaFuerte"
		self.Marco:Color(self.alfaBorde)
		self:SetAlpha((x.estado == "hecho" and not foto) and 0.7 or 1)
		self.lineas = { { format(L["Puntos %d a %d de tu build (niveles %d a %d)."], x.desde, x.hasta, nivelDe(x.desde), nivelDe(x.hasta)), "acento" } }
	end
	function f:Acomodar(ancho)
		local pad = ESP.base
		local colNivel = 64
		local tx = pad + colNivel + 28 + ESP.m
		self.Nivel:ClearAllPoints()
		self.Nivel:SetPoint("TOPLEFT", self, "TOPLEFT", pad, -(ESP.m + 6))
		self.Icono:ClearAllPoints()
		self.Icono:SetPoint("TOPLEFT", self, "TOPLEFT", pad + colNivel, -ESP.m)
		local iw = self.Estado:IsShown() and (K.num(self.Estado:GetWidth(), 0) + ESP.base) or 0
		self.Estado:ClearAllPoints()
		self.Estado:SetPoint("TOPRIGHT", self, "TOPRIGHT", -pad, -(ESP.m + 2))
		local rw = K.Ajustar(self.Rango, 80)
		local nw = K.Ajustar(self.Nombre, max(60, ancho - tx - pad - iw - rw - ESP.s))
		self.Nombre:ClearAllPoints()
		self.Nombre:SetPoint("TOPLEFT", self, "TOPLEFT", tx, -ESP.m)
		self.Rango:ClearAllPoints()
		self.Rango:SetPoint("LEFT", self.Nombre, "RIGHT", ESP.s, 0)
		local y = ESP.m + K.AltoTexto(self.Nombre)
		if (self.Por:GetText() or "") ~= "" then
			y = y + 3
			self.Por:ClearAllPoints()
			self.Por:SetPoint("TOPLEFT", self, "TOPLEFT", tx, -y)
			y = y + K.Parrafo(self.Por, max(80, ancho - tx - pad - iw), 2)
			self.Por:Show()
		else
			self.Por:Hide()
		end
		local h = max(28 + 2 * ESP.m, y + ESP.m)
		self:SetSize(ancho, h)
		return h
	end
	return f
end

local function bloquePlan(padre)
	local b = CreateFrame("Frame", nil, padre)
	b.caja = K.Caja(b, { fondo = "panel", borde = "linea", corte = K.CORTE.panel })
	b.filas, b.lineas = {}, {}
	function b:Llenar(lista, foto) self.datos, self.foto = lista or {}, foto end
	function b:Acomodar(ancho)
		local y = 0
		for i, x in ipairs(self.datos or {}) do
			local f = self.filas[i] or filaPlan(self)
			self.filas[i] = f
			f:Set(x, self.foto)
			if i > 1 then
				local ln = self.lineas[i - 1] or K.Linea(self, "linea")
				self.lineas[i - 1] = ln
				ln:ClearAllPoints()
				ln:SetPoint("TOPLEFT", self, "TOPLEFT", ESP.base, -y)
				ln:SetPoint("TOPRIGHT", self, "TOPRIGHT", -ESP.base, -y)
				ln:Show()
			end
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
			f:Show()
			y = y + f:Acomodar(ancho)
		end
		local n = #(self.datos or {})
		for i = n + 1, #self.filas do self.filas[i]:Hide() end
		for i = max(1, n), #self.lineas do self.lineas[i]:Hide() end
		self:SetSize(ancho, max(1, y))
		return y
	end
	return b
end

---------------------------------------------------------------------------
-- 5. Consejos del build
---------------------------------------------------------------------------

local function bloqueConsejos(padre)
	local b = CreateFrame("Frame", nil, padre)
	b.caja = K.Caja(b, { fondo = "panel", borde = "linea", corte = K.CORTE.panel })
	b.textos = {}
	function b:Llenar(lista) self.datos = lista or {} end
	function b:Acomodar(ancho)
		local y = ESP.base
		for i, s in ipairs(self.datos or {}) do
			local t = self.textos[i]
			if not t then
				t = { Huella = K.Icono(self, "ic-huella", 14, "acento"), Texto = K.Texto(self, "texto", "texto") }
				self.textos[i] = t
			end
			if i > 1 then y = y + ESP.s end
			t.Huella:ClearAllPoints()
			t.Huella:SetPoint("TOPLEFT", self, "TOPLEFT", ESP.base, -(y + 1))
			K.Escribir(t.Texto, s)
			t.Texto:ClearAllPoints()
			t.Texto:SetPoint("TOPLEFT", self, "TOPLEFT", ESP.base + 14 + ESP.m, -y)
			y = y + K.Parrafo(t.Texto, ancho - 2 * ESP.base - 14 - ESP.m)
			t.Huella:Show()
			t.Texto:Show()
		end
		for i = #(self.datos or {}) + 1, #self.textos do self.textos[i].Huella:Hide() self.textos[i].Texto:Hide() end
		y = y + ESP.base
		self:SetSize(ancho, y)
		return y
	end
	return b
end

---------------------------------------------------------------------------
-- La vista Talentos
---------------------------------------------------------------------------

-- Las ayudas de combate son del área de combate (su página "combate").
local function hayCombate() return N.ModuloPorId and N.ModuloPorId("combate") ~= nil end
local function abrirCombate()
	if AlfaCombate and AlfaCombate.Abrir then AlfaCombate.Abrir() else N.Abrir("combate") end
end

local function interruptor(clave)
	return function(fila) return K.Interruptor(fila, { clave = clave }) end
end

local function construirTalentos()
	local t = K.Tablero(view, { margen = N.MargenPagina(), accion = "accion" })
	-- 2. Tu camino
	ui.camino = t:AgregarBloque(bloqueCamino(t.Extra))
	-- 3. Tu árbol
	local g = grupo(t.Extra, L["Tu árbol"])
	ui.arbol = g
	ui.lienzo = g:Agregar(M.Lienzo.Nuevo(g))
	t:AgregarBloque(g)
	-- 4. El plan por nivel
	g = grupo(t.Extra, L["Plan por nivel"])
	ui.gPlan = g
	ui.plan = g:Agregar(bloquePlan(g))
	ui.planNota = g:Agregar(parrafo(g, "nota", "textoTenue"))
	t:AgregarBloque(g)
	-- 5. Consejos
	g = grupo(t.Extra, L["Consejos para jugarlo"])
	ui.gConsejos = g
	ui.consejos = g:Agregar(bloqueConsejos(g))
	t:AgregarBloque(g)
	-- 6. Más para tu personaje
	g = grupo(t.Extra, L["Más para tu personaje"])
	ui.mas = g:Agregar(K.Rejilla(g, { min = 240, gap = ESP.base }))
	t:AgregarBloque(g)
	-- 7. Avisos
	local av = K.GrupoAjustes(t.Extra, { titulo = L["Avisos"] })
	av:Fila({ titulo = L["Avisarme del talento que toca"], control = interruptor("builds.aviso"),
		texto = L["Al subir de nivel (y al entrar, si te quedan puntos), un aviso dice qué talento poner, con el botón para aplicarlo."] })
	av:Fila({ titulo = L["Comparar equipo con mi build"], control = interruptor("builds.escalaAuto"),
		texto = L["Al elegir un build, las flechas de mejora de tus bolsas valoran lo que ese build necesita."] })
	if A.Get("qol.levelUpSpells") ~= nil then
		av:Fila({ titulo = L["Avisar los hechizos nuevos para entrenar"], control = interruptor("qol.levelUpSpells"),
			texto = L["Al subir de nivel, un aviso dice qué aprender, cuánto cuesta y con qué entrenador, con el botón Llévame."] })
	end
	if A.Get("qol.oldRanks") ~= nil then
		av:Fila({ titulo = L["Avisar rangos viejos en tus barras"], control = interruptor("qol.oldRanks"),
			texto = L["Cuando aprendes un rango nuevo, un aviso ofrece cambiarlo en tus barras."] })
	end
	ui.avisos = t:AgregarBloque(av, { espacio = ESP.xl })

	local function llenar()
		local e = M.Estado()
		ui.estado = e
		local d, tex = ahora(e)
		t:SetAccion(d)
		iconoJuego(t.Accion, tex)
		local b = e.build
		local hay = b ~= nil
		-- 2.
		K.Mostrar(ui.camino, hay)
		if hay then ui.camino:Llenar(e) end
		-- 3.
		K.Mostrar(ui.arbol, hay or e.vivo ~= nil)
		ui.lienzo:Set(e)
		ui.arbol.Seccion:Set(L["Tu árbol"], {
			cuenta = (e.st and not e.foto) and format("%d/%d", e.st.hechos, e.st.total) or nil,
			enlace = { texto = L["Abrir la ventana del juego"], alClic = abrirVentanaJuego },
		})
		-- 4. Lo que sigue, los primeros PLAN_VISIBLE; lo hecho y lo de
		-- después se ven con "Ver todo el plan".
		if hay then
			local lista = entradas(e)
			local hechos, resto = 0, {}
			for _, x in ipairs(lista) do
				if x.estado == "hecho" and not e.foto then hechos = hechos + 1 else resto[#resto + 1] = x end
			end
			local mostrar = lista
			if not ui.planCompleto and #resto > 0 then
				mostrar = {}
				for i = 1, min(PLAN_VISIBLE, #resto) do mostrar[i] = resto[i] end
			end
			local ocultos = #lista - #mostrar
			local alternar = function() ui.planCompleto = not ui.planCompleto P.Rehacer() end
			local enlace
			if ui.planCompleto and #resto > 0 and #lista > PLAN_VISIBLE then
				enlace = { texto = L["Ver menos"], alClic = alternar }
			elseif ocultos > 0 then
				enlace = { texto = format(L["Ver todo el plan (%d)"], #lista), alClic = alternar }
			end
			ui.plan:Llenar(mostrar, e.foto)
			ui.gPlan.Seccion:Set(L["Plan por nivel"], { cuenta = format(L["%d talentos"], #lista), enlace = enlace })
			local partes = {}
			if ocultos > 0 and hechos > 0 then
				partes[#partes + 1] = hechos == 1 and L["Ya tienes 1 talento de este plan."] or format(L["Ya tienes %d talentos de este plan."], hechos)
			end
			if ocultos > 0 and #resto > #mostrar then
				partes[#partes + 1] = format(L["Después de estos siguen %d más."], #resto - #mostrar)
			end
			if e.res and #e.res.faltan > 0 then
				partes[#partes + 1] = format(L["No están en tu árbol y se saltan: %s."], table.concat(e.res.faltan, ", "))
			end
			ui.planNota:Set(table.concat(partes, " "))
		end
		K.Mostrar(ui.gPlan, hay)
		-- 5.
		local consejos = b and b.consejos or {}
		K.Mostrar(ui.gConsejos, #consejos > 0)
		ui.consejos:Llenar(consejos)
		-- 6.
		local n = #M.Compartir.Lista()
		local mas = {
			{ icono = "ic-bolsas", titulo = L["Equipo y estadísticas"], texto = L["Qué estadísticas buscar y lo mejor que puedes usar en tu nivel."],
				alClic = function() P.Ir("equipo") end, secundaria = { texto = L["Abrir"], alClic = function() P.Ir("equipo") end } },
			{ icono = "ic-manada", titulo = L["Compartir con la manada"], texto = L["Pasa tu build a un amigo o usa el que te pasen."],
				insignias = n > 0 and { { n == 1 and L["1 importado"] or format(L["%d importados"], n), "neutro" } } or nil,
				alClic = function() P.Ir("compartir") end, secundaria = { texto = L["Abrir"], alClic = function() P.Ir("compartir") end } },
		}
		if hayCombate() then
			mas[#mas + 1] = { icono = "ic-alerta", titulo = L["Ayudas de combate"], texto = L["Qué presionar y en qué orden, avisos de reacción, la barra de golpe y el medidor de daño."],
				alClic = abrirCombate, secundaria = { texto = L["Abrir"], alClic = abrirCombate } }
		end
		ui.mas:Llenar(mas)
		av:Refrescar()
	end
	return t, llenar
end

---------------------------------------------------------------------------
-- La vista Equipo y estadísticas
---------------------------------------------------------------------------

local function encabezado(t)
	local volver = K.Boton(t.Encabezado, L["Volver a Talentos"], function() P.Ir("talentos") end, { tipo = "secundario" })
	t.Encabezado:Acciones({ volver })
end

-- Qué estadísticas buscar: número, nombre, barra y por qué.
local function bloqueStats(padre)
	local b = CreateFrame("Frame", nil, padre)
	b.caja = K.Caja(b, { fondo = "panel", borde = "linea", corte = K.CORTE.panel })
	b.filas = {}
	function b:Llenar(lista) self.datos = lista or {} end
	function b:Acomodar(ancho)
		local pad = ESP.base
		local y = pad
		local colNombre = 170
		local bw = max(80, floor(ancho * 0.22))
		local px = pad + 28 + colNombre + bw + ESP.l
		local angosto = ancho - px < 220
		for i, s in ipairs(self.datos or {}) do
			local f = self.filas[i]
			if not f then
				f = { Num = K.Texto(self, "numero", "acento"), Nombre = K.Texto(self, "cuerpo", "texto"),
					Barra = K.Progreso(self, { alto = 6 }), Por = K.Texto(self, "nota", "textoSuave") }
				self.filas[i] = f
			end
			local info = M.STATS[s.clave] or { nombre = s.clave, porque = "" }
			if i > 1 then y = y + ESP.m end
			K.Escribir(f.Num, tostring(i))
			f.Num:ClearAllPoints()
			f.Num:SetPoint("TOPLEFT", self, "TOPLEFT", pad, -y)
			K.Escribir(f.Nombre, info.nombre)
			K.Ajustar(f.Nombre, colNombre - ESP.s)
			f.Nombre:ClearAllPoints()
			f.Nombre:SetPoint("TOPLEFT", self, "TOPLEFT", pad + 28, -y)
			f.Barra:ClearAllPoints()
			f.Barra:SetPoint("TOPLEFT", self, "TOPLEFT", pad + 28 + colNombre, -(y + 5))
			f.Barra:Acomodar(bw)
			f.Barra:Set(s.relativo or 0.5)
			K.Escribir(f.Por, info.porque)
			f.Por:ClearAllPoints()
			local h
			if angosto then
				f.Por:SetPoint("TOPLEFT", self, "TOPLEFT", pad + 28, -(y + 20))
				h = 20 + K.Parrafo(f.Por, ancho - 2 * pad - 28)
			else
				f.Por:SetPoint("TOPLEFT", self, "TOPLEFT", px, -y)
				h = max(18, K.Parrafo(f.Por, ancho - px - pad))
			end
			for _, x in pairs(f) do x:Show() end
			y = y + h
		end
		for i = #(self.datos or {}) + 1, #self.filas do for _, x in pairs(self.filas[i]) do x:Hide() end end
		y = y + pad
		self:SetSize(ancho, y)
		return y
	end
	return b
end

-- Una fila de objeto: ícono con su calidad, nombre, de dónde sale, mejora y "Cómo conseguirlo".
local function filaObjeto(padre)
	local f = CreateFrame("Frame", nil, padre)
	f.Icono = K.IconoObjeto(f, 36)
	f.Nombre = K.Texto(f, "cuerpo", "objeto")
	f.Origen = K.Texto(f, "pequeno", "textoTenue")
	f.Mejora = K.Insignia(f, "", "neutro")
	f.Nivel = K.Insignia(f, "", "neutro")
	f.Guia = K.Boton(f, L["Cómo conseguirlo"], function(self) local p = self:GetParent() if p.id then M.Equipo.Guiar(p.id) end end,
		{ tipo = "fantasma", tam = "chico", icono = "ic-seguir", ayuda = L["Abre la guía de Alfa que te lleva a conseguir este objeto."] })
	function f:Set(it, nv)
		self.id = it.id
		self.Icono:SetObjeto({ id = it.id, calidad = it.calidad })
		K.Escribir(self.Nombre, M.Equipo.Nombre(it.id))
		local r, g, b = K.ColorDeCalidad(it.calidad)
		if r and A.Theme and A.Theme.Legible then self.Nombre:SetTextColor(A.Theme.Legible(r, g, b)) else K.ColorTexto(self.Nombre, "objeto") end
		K.Escribir(self.Origen, M.Equipo.Origen(it.id) or "")
		if it.vacio then
			self.Mejora:Set(L["Ranura vacía"], "exito")
		elseif it.mejora and it.mejora > 0.5 then
			self.Mejora:Set(format(L["%d %% mejor"], floor(it.mejora + 0.5)), "exito")
		elseif it.mejora and it.mejora >= -0.5 then
			self.Mejora:Set(L["Igual que lo tuyo"], "neutro")
		else
			self.Mejora:Set(L["Ya tienes algo mejor"], "neutro")
		end
		local req = max(1, it.req or 1)
		self.Nivel:Set(format(L["Nv %d"], req), req > nv and "aviso" or "neutro")
	end
	function f:Acomodar(ancho)
		local pad = ESP.base
		self.Icono:ClearAllPoints()
		self.Icono:SetPoint("LEFT", self, "LEFT", pad, 0)
		self.Guia:ClearAllPoints()
		self.Guia:SetPoint("RIGHT", self, "RIGHT", -pad, 0)
		local gw = K.num(self.Guia:GetWidth(), 120)
		self.Mejora:ClearAllPoints()
		self.Mejora:SetPoint("RIGHT", self.Guia, "LEFT", -ESP.m, 0)
		self.Nivel:ClearAllPoints()
		self.Nivel:SetPoint("RIGHT", self.Mejora, "LEFT", -ESP.s, 0)
		local derecha = gw + K.num(self.Mejora:GetWidth(), 0) + K.num(self.Nivel:GetWidth(), 0) + ESP.m + ESP.s + ESP.base
		local tx = pad + 36 + ESP.m
		local tw = max(80, ancho - tx - pad - derecha)
		self.Nombre:ClearAllPoints()
		self.Nombre:SetPoint("TOPLEFT", self, "TOPLEFT", tx, -ESP.m)
		K.Ajustar(self.Nombre, tw)
		self.Origen:ClearAllPoints()
		self.Origen:SetPoint("TOPLEFT", self.Nombre, "BOTTOMLEFT", 0, -3)
		K.Ajustar(self.Origen, tw)
		local h = 36 + 2 * ESP.s
		self:SetSize(ancho, h)
		return h
	end
	return f
end

-- Lo mejor para tu nivel, por ranura.
local function bloqueEquipo(padre)
	local b = CreateFrame("Frame", nil, padre)
	b.caja = K.Caja(b, { fondo = "panel", borde = "linea", corte = K.CORTE.panel })
	b.filas, b.titulos, b.lineas = {}, {}, {}
	function b:Llenar(res) self.res = res end
	function b:Acomodar(ancho)
		local y, nf, nl = ESP.s, 0, 0
		local nv = nivel()
		for gi, g in ipairs(self.res and self.res.grupos or {}) do
			local h = self.titulos[gi] or K.Texto(self, "mayus", "textoTenue")
			self.titulos[gi] = h
			if gi > 1 then
				nl = nl + 1
				local ln = self.lineas[nl] or K.Linea(self, "linea")
				self.lineas[nl] = ln
				ln:ClearAllPoints()
				ln:SetPoint("TOPLEFT", self, "TOPLEFT", ESP.base, -(y + ESP.s))
				ln:SetPoint("TOPRIGHT", self, "TOPRIGHT", -ESP.base, -(y + ESP.s))
				ln:Show()
				y = y + ESP.base
			end
			K.Escribir(h, tostring(g.nombre or ""):upper())
			h:ClearAllPoints()
			h:SetPoint("TOPLEFT", self, "TOPLEFT", ESP.base, -(y + ESP.s))
			h:Show()
			y = y + ESP.s + 14
			for _, it in ipairs(g.items) do
				nf = nf + 1
				local f = self.filas[nf] or filaObjeto(self)
				self.filas[nf] = f
				f:Set(it, nv)
				f:ClearAllPoints()
				f:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
				f:Show()
				y = y + f:Acomodar(ancho)
			end
		end
		for i = #(self.res and self.res.grupos or {}) + 1, #self.titulos do self.titulos[i]:Hide() end
		for i = nf + 1, #self.filas do self.filas[i]:Hide() end
		for i = nl + 1, #self.lineas do self.lineas[i]:Hide() end
		y = y + ESP.s
		self:SetSize(ancho, y)
		return y
	end
	return b
end

local function buscarEquipo()
	local b = M.BuildElegido()
	if not b then return end
	local ok, razon = M.Equipo.Buscar(b, function() ui.msgEquipo = nil P.Rehacer() end, function(frac)
		ui.fracEquipo = frac
		if ui.buscar and ui.buscar.Barra and ui.buscar:IsVisible() then ui.buscar.Barra:Set(frac) end
	end)
	ui.msgEquipo = not ok and (M.Equipo.RAZONES[razon] or tostring(razon)) or nil
	ui.fracEquipo = 0
	P.Rehacer()
end

local function construirEquipo()
	local t = K.Tablero(view, { margen = N.MargenPagina(), accion = "estado",
		encabezado = { icono = "ic-bolsas", sobre = L["Talentos"], titulo = L["Equipo y estadísticas"],
			subtitulo = L["Lo que tu build necesita de tu equipo y dónde conseguirlo."] } })
	encabezado(t)
	local g = grupo(t.Extra, L["Qué estadísticas buscar"])
	ui.stats = g:Agregar(bloqueStats(g))
	ui.statsNota = g:Agregar(parrafo(g, "nota", "textoTenue"))
	ui.statsNota:Set(L["El orden importa más que los números: busca piezas con las primeras de la lista."])
	t:AgregarBloque(g)
	g = grupo(t.Extra, L["Lo mejor para tu nivel"])
	ui.gEquipo = g
	ui.buscar = g:Agregar(K.Tarjeta(g, { variante = "normal" }))
	ui.equipo = g:Agregar(bloqueEquipo(g))
	t:AgregarBloque(g)
	g = grupo(t.Extra, L["Profesiones que te sirven"])
	ui.prof = g:Agregar(K.Rejilla(g, { min = 190, gap = ESP.base }))
	ui.profNota = g:Agregar(parrafo(g, "nota", "textoTenue"))
	ui.profNota:Set(L["Solo puedes tener dos principales a la vez; las secundarias son libres. Se aprenden con su entrenador en las ciudades."])
	t:AgregarBloque(g)

	local function llenar()
		local b = M.BuildElegido()
		if not b then
			t:SetAccion({ lobo = "dormido", tono = "neutro", titulo = L["Primero elige tu build"],
				texto = L["Con tu build, Alfa sabe qué estadísticas te sirven y qué equipo buscar."],
				accion = { texto = L["Volver a Talentos"], alClic = function() P.Ir("talentos") end } })
			K.Mostrar(t.Extra, false)
			return
		end
		K.Mostrar(t.Extra, true)
		-- Los pesos de las flechas de mejora.
		local activa = M.Pesos.Activa() == b.id
		if activa then
			t:SetAccion({ icono = "ic-exito", tono = "exito", titulo = L["Tus flechas de mejora usan tu build"],
				texto = format(L["Al comparar objetos, Alfa valora más lo que pide %s: lo de arriba en la lista de estadísticas."], b.titulo or ""),
				estado = { texto = L["Activo"], tono = "exito" },
				secundaria = { texto = L["Volver a automático"], alClic = function() M.Pesos.Desactivar() P.Rehacer() end } })
		else
			local G = A.Gear
			local _, nombre = G and G.GetSpec and G.GetSpec()
			t:SetAccion({ icono = "ic-aviso", tono = "aviso", titulo = L["Tus flechas de mejora no usan tu build"],
				texto = format(L["Ahora usan: %s. Activa los pesos de %s para que Alfa compare el equipo como lo pide tu build."], tostring(nombre or L["automático"]), b.titulo or ""),
				estado = { texto = L["Sin activar"], tono = "aviso" },
				accion = { texto = L["Usar los pesos de mi build"], icono = "ic-exito", alClic = function()
					local ok, msg = M.Pesos.Activar(b)
					if not ok and msg then N.Imprimir(msg) end
					P.Rehacer()
				end } })
		end
		ui.stats:Llenar(M.Pesos.Orden(b))
		-- Equipo: buscando, sin buscar o con resultados.
		local ocupado, frac = M.Equipo.Ocupado()
		local res = M.Equipo.Resultado(b)
		if res and res.viejo then M.Equipo.Mejoras(res, M.Pesos.Pesos(b)) end
		local hayRes = res and #res.grupos > 0
		K.Mostrar(ui.buscar, ocupado or not hayRes)
		K.Mostrar(ui.equipo, hayRes and not ocupado)
		if ocupado then
			ui.buscar:Set({ icono = "ic-buscar", titulo = L["Buscando lo mejor para tu nivel…"],
				texto = L["Alfa revisa su base de objetos sin trabar el juego. Tarda unos segundos la primera vez."],
				progreso = { actual = frac or 0, total = 1 } })
		elseif not hayRes then
			ui.buscar:Set({ icono = "ic-buscar", titulo = L["Busca lo mejor que puedes usar"],
				texto = ui.msgEquipo or (res and L["No se encontró nada mejor cerca de tu nivel. Vuelve a buscar al subir unos niveles."])
					or L["Alfa revisa su base de objetos, se queda con lo que tu clase puede usar cerca de tu nivel y lo compara con lo que llevas, con los pesos de tu build."],
				accion = { texto = L["Buscar equipo para mi nivel"], icono = "ic-buscar", alClic = buscarEquipo } })
		else
			ui.equipo:Llenar(res)
		end
		ui.gEquipo.Seccion:Set(L["Lo mejor para tu nivel"], {
			enlace = (hayRes and not ocupado) and { texto = L["Buscar otra vez"], alClic = buscarEquipo } or nil })
		-- Profesiones.
		local prof = M.Profesiones(b)
		local datos = {}
		for i, clave in ipairs({ prof[1], prof[2] }) do
			local def = M.PROFESIONES[clave] or { nombre = clave }
			datos[#datos + 1] = { icono = "ic-oficios", sobre = L["Principal"], titulo = def.nombre, texto = i == 1 and prof[3] or nil, tex = def.icono }
		end
		for _, s in ipairs(M.PROF_SECUNDARIAS) do
			local def = M.PROFESIONES[s[1]] or { nombre = s[1] }
			datos[#datos + 1] = { icono = "ic-oficios", sobre = L["Secundaria"], tono = "neutro", titulo = def.nombre, texto = s[2], tex = def.icono }
		end
		ui.prof:Llenar(datos)
		for i, d in ipairs(datos) do iconoJuego(ui.prof.pool[i], d.tex) end
	end
	return t, llenar
end

---------------------------------------------------------------------------
-- La vista Compartir
---------------------------------------------------------------------------

-- Un campo de texto de varias líneas con la forma del Kit.
local function campo(padre, opts)
	opts = opts or {}
	local f = CreateFrame("Frame", nil, padre)
	f.caja = K.Caja(f, { fondo = "hundido", borde = "lineaFuerte", corte = K.CORTE.control })
	local e = CreateFrame("EditBox", nil, f)
	e:SetMultiLine(true)
	e:SetAutoFocus(false)
	e:SetMaxLetters(2000)
	e:SetPoint("TOPLEFT", f, "TOPLEFT", ESP.m, -ESP.s)
	e:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -ESP.m, ESP.s)
	e.alfaRol = "etiqueta"
	K.Pintar(e, function(x) K.Fuente(x, "etiqueta") x:SetTextColor(K.Color("texto")) end)
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	e:SetScript("OnEditFocusGained", function() f.caja:Estilo({ borde = "acento" }) end)
	e:SetScript("OnEditFocusLost", function() f.caja:Estilo({ borde = "lineaFuerte" }) end)
	if opts.soloLectura then
		-- Se puede seleccionar y copiar, pero no cambiar.
		e:SetScript("OnTextChanged", function(self, delJugador)
			if delJugador and f.alfaTexto and self:GetText() ~= f.alfaTexto then
				self:SetText(f.alfaTexto)
				self:HighlightText()
			end
		end)
	end
	f:EnableMouse(true)
	f:SetScript("OnMouseDown", function() e:SetFocus() end)
	f.Edit = e
	function f:Set(s) self.alfaTexto = s or "" e:SetText(self.alfaTexto) end
	function f:Copiar() e:SetFocus() e:HighlightText() end
	function f:Acomodar(ancho)
		local h = opts.alto or 76
		self:SetSize(ancho, h)
		return h
	end
	return f
end

local function filaImportado(padre)
	local f = CreateFrame("Frame", nil, padre)
	f.Nombre = K.Texto(f, "cuerpo", "texto")
	f.Rama = K.Texto(f, "pequeno", "textoTenue")
	f.Borrar = K.Boton(f, L["Borrar"], function(self)
		local id = self:GetParent().id
		K.Dialogo({ titulo = L["¿Borrar este build?"], peligro = true, aceptar = L["Borrar"],
			texto = L["Se quita de tu lista. Si lo necesitas otra vez, vuelve a importar su cadena."],
			alAceptar = function() M.Compartir.Borrar(id) P.Rehacer() end })
	end, { tipo = "fantasma", tam = "chico", icono = "ic-cerrar" })
	f.Usar = K.Boton(f, L["Seguir este build"], function(self)
		M.UsarBuild(self:GetParent().id)
		P.Ir("talentos")
	end, { tipo = "secundario", tam = "chico", icono = "ic-seguir" })
	function f:Set(b, actual)
		self.id = b.id
		K.Escribir(self.Nombre, b.titulo or "?")
		K.Escribir(self.Rama, M.NombreSpec(b) or "")
		self.Usar:SetActivo(not actual)
		self.Usar:SetTexto(actual and L["Lo estás siguiendo"] or L["Seguir este build"])
	end
	function f:Acomodar(ancho)
		local pad = ESP.base
		self.Borrar:ClearAllPoints()
		self.Borrar:SetPoint("RIGHT", self, "RIGHT", -pad, 0)
		self.Usar:ClearAllPoints()
		self.Usar:SetPoint("RIGHT", self.Borrar, "LEFT", -ESP.s, 0)
		local bw = K.num(self.Usar:GetWidth(), 100) + K.num(self.Borrar:GetWidth(), 80) + ESP.s + ESP.base
		self.Nombre:ClearAllPoints()
		self.Nombre:SetPoint("LEFT", self, "LEFT", pad, 0)
		local nw = K.Ajustar(self.Nombre, max(80, ancho - 2 * pad - bw - 120))
		self.Rama:ClearAllPoints()
		self.Rama:SetPoint("LEFT", self.Nombre, "RIGHT", ESP.s, 0)
		K.Ajustar(self.Rama, max(40, ancho - 2 * pad - bw - nw - ESP.s))
		self:SetSize(ancho, K.ALTO.fila + ESP.s)
		return K.ALTO.fila + ESP.s
	end
	return f
end

local function bloqueImportados(padre)
	local b = CreateFrame("Frame", nil, padre)
	b.caja = K.Caja(b, { fondo = "panel", borde = "linea", corte = K.CORTE.panel })
	b.filas, b.lineas = {}, {}
	function b:Llenar(lista, actual) self.datos, self.actual = lista or {}, actual end
	function b:Acomodar(ancho)
		local y = 0
		for i, ib in ipairs(self.datos) do
			local f = self.filas[i] or filaImportado(self)
			self.filas[i] = f
			f:Set(ib, ib.id == self.actual)
			if i > 1 then
				local ln = self.lineas[i - 1] or K.Linea(self, "linea")
				self.lineas[i - 1] = ln
				ln:ClearAllPoints()
				ln:SetPoint("TOPLEFT", self, "TOPLEFT", ESP.base, -y)
				ln:SetPoint("TOPRIGHT", self, "TOPRIGHT", -ESP.base, -y)
				ln:Show()
			end
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
			f:Show()
			y = y + f:Acomodar(ancho)
		end
		for i = #self.datos + 1, #self.filas do self.filas[i]:Hide() end
		for i = max(1, #self.datos), #self.lineas do self.lineas[i]:Hide() end
		self:SetSize(ancho, max(1, y))
		return y
	end
	return b
end

local function construirCompartir()
	local t = K.Tablero(view, { margen = N.MargenPagina(), accion = "accion",
		encabezado = { icono = "ic-manada", sobre = L["Talentos"], titulo = L["Compartir con la manada"],
			subtitulo = L["Una cadena de texto lleva un build completo: la copias, la pasas y la pegan."] } })
	encabezado(t)
	ui.copia = t:AgregarBloque(campo(t.Extra, { soloLectura = true, alto = 76 }), { espacio = ESP.base })
	ui.msgCopia = t:AgregarBloque(parrafo(t.Extra, "nota", "aviso"), { espacio = ESP.s })
	local g = grupo(t.Extra, L["Importar un build"])
	ui.impTexto = g:Agregar(parrafo(g, "nota", "textoSuave"))
	ui.impTexto:Set(L["Pega aquí una cadena que empiece con ALFA1; (Ctrl + V) y pulsa Importar. Alfa revisa cada talento contra tu árbol."])
	ui.entrada = g:Agregar(campo(g, { alto = 76 }))
	local pie = CreateFrame("Frame", nil, g)
	pie.Boton = K.Boton(pie, L["Importar"], function()
		local b, err = M.Compartir.Importar(ui.entrada.Edit:GetText())
		if b then
			ui.msgImp, ui.tonoImp = format(L["Importado: %s. Ya puedes seguirlo."], b.titulo or ""), "exito"
			ui.entrada:Set("")
		else
			ui.msgImp, ui.tonoImp = M.Compartir.ERRORES[err] or tostring(err), "aviso"
		end
		P.Rehacer()
	end, { tipo = "primario", icono = "ic-mas" })
	pie.Boton:SetPoint("TOPLEFT", pie, "TOPLEFT", 0, 0)
	pie.Msg = K.Texto(pie, "nota", "exito")
	pie.Msg:SetPoint("LEFT", pie.Boton, "RIGHT", ESP.base, 0)
	function pie:Acomodar(ancho)
		K.Escribir(self.Msg, ui.msgImp or "")
		K.ColorTexto(self.Msg, ui.tonoImp or "exito")
		K.Ajustar(self.Msg, max(80, ancho - K.num(self.Boton:GetWidth(), 100) - ESP.base))
		self:SetSize(ancho, K.ALTO.boton)
		return K.ALTO.boton
	end
	g:Agregar(pie)
	t:AgregarBloque(g)
	g = grupo(t.Extra, L["Tus builds importados"])
	ui.gImportados = g
	ui.importados = g:Agregar(bloqueImportados(g))
	t:AgregarBloque(g)

	local function llenar()
		local b = M.BuildElegido()
		local texto, quien = ui.exportando, nil
		if not texto then texto = b and M.Compartir.Exportar(b) or "" quien = b end
		local nombre = ui.exportando and L["tus talentos de ahora"] or (b and b.titulo) or ""
		t:SetAccion({ icono = "ic-manada", sobre = L["Compartir"],
			titulo = b and format(L["Comparte %s"], nombre) or L["Comparte tus talentos"],
			texto = L["Copia la cadena de abajo y pásala por el chat o por Discord: con Alfa la pegan en Importar y tienen tu mismo build."],
			accion = { texto = L["Seleccionar para copiar"], icono = "ic-exito", alClic = function() ui.copia:Copiar() end },
			secundaria = ui.exportando and { texto = format(L["Mejor %s"], b and b.titulo or L["mi build"]), alClic = function() ui.exportando = nil P.Rehacer() end }
				or { texto = L["Usar mis talentos de ahora"], alClic = function()
					local s, razon = M.Compartir.ExportarActual()
					ui.exportando = s
					ui.msgExp = not s and (razon == "vacio" and L["Todavía no tienes talentos para compartir."] or L["El juego todavía no carga tu árbol."]) or nil
					P.Rehacer()
				end } })
		ui.copia:Set(texto)
		ui.msgCopia:Set(ui.msgExp)
		local lista = M.Compartir.Lista()
		-- Sin importados, la sección no se muestra: la de arriba ya dice cómo.
		K.Mostrar(ui.gImportados, #lista > 0)
		ui.gImportados.Seccion:Set(L["Tus builds importados"], { cuenta = #lista })
		ui.importados:Llenar(lista, b and b.id)
	end
	return t, llenar
end

---------------------------------------------------------------------------
-- La página
---------------------------------------------------------------------------

local CONSTRUIR = { talentos = construirTalentos, equipo = construirEquipo, compartir = construirCompartir }

local function vistaDe(clave)
	local v = vistas[clave]
	if v then return v end
	local t, llenar = CONSTRUIR[clave]()
	v = { t = t, llenar = llenar }
	vistas[clave] = v
	return v
end

function P.Construir(v)
	view = v
	-- Al volver a la página se empieza por Talentos.
	view:HookScript("OnHide", function() vista = "talentos" end)
	view.Refresh = function()
		local actual = CONSTRUIR[vista] and vista or "talentos"
		local x = vistaDe(actual)
		for k, otra in pairs(vistas) do otra.t:SetShown(k == actual) end
		K.Llamar(x.llenar)
		return x.t:Acomodar(N.AnchoPagina())
	end
end

function P.Visible() return view ~= nil and view:IsVisible() and true or false end

-- Rehace la página si está a la vista (una vez por cuadro aunque lo pidan varios).
local pedido = false
function P.Rehacer()
	if pedido then return end
	pedido = true
	A.After(0, function()
		pedido = false
		if view then N.RehacerPagina(view) end
	end)
end

function P.Ir(clave)
	clave = CONSTRUIR[clave] and clave or "talentos"
	local cambia = clave ~= vista
	vista = clave
	if clave ~= "compartir" then ui.exportando, ui.msgExp = nil, nil end
	if view and view:IsVisible() then
		N.RehacerPagina(view)
		if cambia then alInicio() end
	end
end
