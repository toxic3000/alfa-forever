-- Alfa - Combate: su página en la ventana de Alfa (toxic3000 / La Jauría). GPL-3.0.
--
-- Un Tablero del Kit (docs/KIT.md), en Personaje:
--   1. Estado: cómo está tu ayuda de rotación y qué hacer (encenderla,
--      moverla, fijarla), con su fuente (la de Blizzard o la prioridad de Alfa).
--   2. Herramientas: el medidor de daño, los avisos de reacción y el botón
--      resaltado en tu barra, cada una con su acción.
--   3. El top de daño de tu grupo o banda, con anunciar en el chat.
--   4. Tu prioridad: en qué orden y en qué situación (solo si hay una).
--   5. Los ajustes, en cuatro grupos (rotación, avisos y explicaciones,
--      marca de misión, medidor).
-- Lo que no tiene nada útil no se muestra, o dice qué hacer para llenarlo.

local ADDON, M = ...
local N, A, K, L = M.N, M.A, M.K, M.L
local R, D, P, Rc = M.Rotacion, M.Medidor, M.Prioridad, M.Reacciones
local ID = M.ID

local floor, max, min, format, ipairs, tonumber, type = math.floor, math.max, math.min, string.format, ipairs, tonumber, type
local ESP = K.ESP
local FILA, GAP = 26, 2

local LANZADORES = { MAGE = true, PRIEST = true, WARLOCK = true }
local situacion -- más abajo

local function nombreClase()
	local n = M.Legible(M.Llamar(UnitClass, "player"))
	return type(n) == "string" and n or L["tu clase"]
end

---------------------------------------------------------------------------
-- 1. Estado
---------------------------------------------------------------------------
local function estado()
	local d = { icono = M.ICONO }
	local fuente = R.Fuente()
	local despues = max(0, min(3, floor(tonumber(M.Opt("despues")) or 0)))
	if M.Desbloqueado() then
		d.titulo, d.tono = L["Mueve tus marcos"], "acento"
		d.texto = L["Arrastra cada marco de combate adonde te acomode. Cuando termines, fíjalos para que no estorben."]
		d.estado = { texto = L["Moviendo"], tono = "acento" }
		d.accion = { texto = L["Listo, fijarlos"], icono = "ic-exito", alClic = function() M.Desbloquear(false) end }
	elseif not M.Opt("rotacion") then
		d.titulo, d.tono = L["La ayuda de rotación está apagada"], "neutro"
		d.texto = L["Enciéndela para ver en combate qué habilidad conviene ahora y cuáles siguen, en un ícono pequeño que puedes mover."]
		d.estado = { texto = L["Apagada"], tono = "neutro" }
		d.accion = { texto = L["Encenderla"], icono = "ic-seguir", alClic = function() M.SetOpt("rotacion", true) end }
	elseif not fuente then
		local _, porque = R.Disponible()
		d.titulo, d.tono = L["Todavía no hay ayuda de rotación para ti"], "aviso"
		d.texto = (porque and (porque .. " ") or "") .. L["Alfa tampoco tiene todavía una prioridad para tu clase con lo que sabes. Los avisos de reacción y el medidor sí funcionan."]
		d.estado = { texto = L["No disponible"], tono = "aviso" }
	else
		d.titulo, d.tono = L["Tu ayuda de rotación está lista"], "exito"
		if fuente == "blizzard" then
			d.texto = format(despues > 0 and L["En combate, el ícono muestra la habilidad que sugiere la ayuda de Blizzard y las %d que siguen. Tú decides qué presionar: Alfa nunca aprieta nada por ti."]
				or L["En combate, el ícono muestra la habilidad que sugiere la ayuda de Blizzard. Tú decides qué presionar: Alfa nunca aprieta nada por ti."], despues)
		else
			local rama = P.Rama()
			local quien = rama and rama.nombre and format("%s (%s)", nombreClase(), rama.nombre) or nombreClase()
			d.texto = format(L["Alfa sugiere con su prioridad para %s, leyendo solo tu personaje: tu recurso, tus recargas, los efectos que el juego activa y la vida del enemigo cuando se puede leer. Con varios enemigos cambia a las de área. Tú decides qué presionar."], quien)
		end
		d.estado = { texto = L["Lista"], tono = "exito" }
		d.accion = { texto = L["Mover el ícono"], icono = "ic-seguir", alClic = function() M.Desbloquear(true) end }
		d.secundaria = { texto = L["Probar un aviso"], alClic = function() Rc.Probar() end }
	end
	return d
end

---------------------------------------------------------------------------
-- 2. Herramientas
---------------------------------------------------------------------------
local function herramientas()
	local out = {}
	-- Medidor
	local disponible, motivo = D.Disponible()
	local abierta = M.Opt("medidor") and true or false
	local m = { icono = "ic-manada", titulo = L["Medidor de daño"], lineas = 5 }
	if not disponible then
		m.texto = motivo
		m.insignias = { { L["No disponible"], "aviso" } }
	elseif D.Encendido() == false and D.Leer("todo", "dano", 1).vacia then
		m.texto = L["El registro de daño del juego está apagado: enciéndelo para ver el top de tu grupo."]
		m.insignias = { { L["Apagado"], "neutro" } }
		m.accion = { texto = L["Encender el registro"], alClic = function() D.Encender() end }
	else
		m.texto = L["El top de DPS de tu grupo o banda en una ventana pequeña, con la pelea actual y la anterior."]
		m.insignias = { abierta and { L["En pantalla"], "exito" } or { L["Cerrada"], "neutro" } }
		m.accion = { texto = abierta and L["Cerrar la ventana"] or L["Abrir la ventana"], alClic = function() M.Ventana.Alternar() end }
	end
	out[#out + 1] = m
	-- Avisos
	local lista = Rc.Lista()
	local a = { icono = "ic-alerta", titulo = L["Avisos de reacción"], lineas = 5 }
	if #lista == 0 then
		a.texto = L["Tu clase no tiene habilidades de reacción. Si quieres, Alfa te avisa cuando el juego hace brillar una de tus habilidades (en Avisos, abajo)."]
	else
		local si, no = {}, {}
		for _, x in ipairs(lista) do
			local n = M.NombreHechizo(x.id) or (x.def.texto:gsub("\194\161", ""):gsub("!", ""))
			if x.conocida then si[#si + 1] = n else no[#no + 1] = n end
		end
		if #si > 0 then
			a.texto = format(L["Te avisa al momento de %s."], M.Juntar(si))
			if #no > 0 then a.texto = a.texto .. " " .. format(L["Cuando aprendas %s, también."], M.Juntar(no)) end
		else
			a.texto = format(L["Cuando aprendas %s, te avisa al momento de usarlas."], M.Juntar(no))
		end
		a.insignias = { { format(L["%d de %d"], #si, #lista), #si > 0 and "exito" or "neutro" } }
	end
	if not M.Opt("avisos") then a.insignias = { { L["Apagados"], "neutro" } } end
	a.accion = { texto = L["Probar un aviso"], alClic = function() Rc.Probar() end }
	out[#out + 1] = a
	-- Resaltado
	local on = R.ResaltadoActivo()
	out[#out + 1] = {
		icono = "ic-rejilla", titulo = L["Botón resaltado en tu barra"], lineas = 5,
		texto = R.ResaltadoOficial() and L["Usa el resaltado del propio juego sobre el botón de la habilidad sugerida."]
			or L["Un borde verde que late sobre el botón de tu barra con la habilidad sugerida, para encontrarlo rápido."],
		insignias = { on and { L["Encendido"], "exito" } or { L["Apagado"], "neutro" } },
		accion = { texto = on and L["No resaltarlo"] or L["Resaltarlo"], alClic = function() R.SetResaltado(not on) end },
	}
	return out
end

---------------------------------------------------------------------------
-- 3. El top de daño
---------------------------------------------------------------------------
local function opciones(lista)
	local o = {}
	for _, x in ipairs(lista) do o[#o + 1] = { valor = x.clave, texto = x.texto } end
	return o
end

local function bloqueMedidor(padre)
	local b = K.Pila(padre, { espacio = ESP.m })
	b.Seccion = b:Agregar(K.Seccion(b, L["Top de daño"]))
	-- Los controles: la pelea, el tipo y anunciar.
	local barra = CreateFrame("Frame", nil, b)
	barra.Sesion = K.Segmentos(barra, { estilo = "segmentos", opciones = opciones(D.SESIONES), valor = M.Opt("sesion"),
		alCambiar = function(v) M.SetOpt("sesion", v) end })
	barra.Tipo = K.Desplegable(barra, { opciones = opciones(D.TIPOS), clave = ID .. ".tipo", ancho = 120 })
	barra.Anunciar = K.Boton(barra, L["Anunciar en el grupo"], function() D.Anunciar(M.Opt("sesion"), M.Opt("tipo")) M.Avisar() end,
		{ tipo = "secundario", icono = "ic-manada" })
	K.ConInfo(barra.Anunciar, function()
		local puede, porque = D.PuedeAnunciar(M.Opt("sesion"), M.Opt("tipo"))
		if puede then return L["Anunciar en el chat"], (L["Escribe el top %d en el chat de tu grupo o banda."]):format(tonumber(M.Opt("anunciar")) or 5) end
		return L["Ahora no se puede anunciar"], porque
	end)
	barra.Cero = K.Boton(barra, L["Empezar de cero"], function() D.PedirReiniciar() end, { tipo = "fantasma", icono = "ic-cerrar" })
	function barra:Acomodar(ancho)
		local _, sw = self.Sesion:Acomodar(ancho)
		self.Sesion:ClearAllPoints()
		self.Sesion:SetPoint("LEFT", self, "LEFT", 0, 0)
		self.Tipo:ClearAllPoints()
		self.Tipo:SetPoint("LEFT", self, "LEFT", sw + ESP.s, 0)
		self.Anunciar:ClearAllPoints()
		self.Anunciar:SetPoint("RIGHT", self, "RIGHT", 0, 0)
		self.Cero:ClearAllPoints()
		self.Cero:SetPoint("RIGHT", self.Anunciar, "LEFT", -ESP.s, 0)
		self:SetHeight(K.ALTO.control)
		return K.ALTO.control
	end
	b.Barra = b:Agregar(barra)
	-- Las filas.
	local lista = CreateFrame("Frame", nil, b)
	lista.filas = {}
	function lista:Acomodar(ancho)
		local y = 0
		for _, f in ipairs(self.filas) do
			if f:IsShown() then
				if f.alfaAparte then y = y + ESP.xs end
				f:ClearAllPoints()
				f:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
				f:SetWidth(ancho)
				y = y + FILA + GAP
			end
		end
		y = max(0, y - GAP)
		self:SetHeight(max(1, y))
		return y
	end
	b.Lista = b:Agregar(lista, { espacio = ESP.s })
	b.Nota = b:Agregar(K.Texto(b, "pequeno", "textoTenue"), { espacio = ESP.s })
	b.Nota.Acomodar = function(self, ancho) return K.Parrafo(self, ancho, 2) end
	b.Vacio = b:Agregar(K.Vacio(b, { lobo = "dormido" }), { espacio = ESP.base })
	b.alfaForma = ""

	-- -> true si cambió la forma (cuántas filas, vacío o no): la página se vuelve a medir.
	function b:Llenar()
		local filas = max(3, min(10, floor(tonumber(M.Opt("filas")) or 10)))
		local r = D.Leer(M.Opt("sesion"), M.Opt("tipo"), filas)
		self.Seccion:Set(format(L["Top %d de %s"], filas, D.Tipo(M.Opt("tipo")).texto), { cuenta = M.SubtituloMedidor(r) })
		barra.Sesion:SetValor(M.Opt("sesion"))
		barra.Tipo:SetValor(M.Opt("tipo"))
		local n = #r.filas
		for i = 1, n do
			local f = lista.filas[i] or M.CrearFila(lista, FILA)
			lista.filas[i] = f
			f.alfaAparte = r.filas[i].aparte
			M.PintarFila(f, r.filas[i], r)
			f:Show()
		end
		for i = n + 1, #lista.filas do lista.filas[i]:Hide() end
		K.Mostrar(lista, n > 0)
		local puede = D.PuedeAnunciar(M.Opt("sesion"), M.Opt("tipo"))
		barra.Anunciar:SetActivo(puede)
		barra.Anunciar:SetShown(r.ok and n > 0)
		barra.Cero:SetShown(r.ok and n > 0)
		K.Mostrar(barra, r.ok)
		local nota = ""
		if n > 0 and r.secreto then
			nota = L["En combate el juego oculta los números exactos: las barras y las cifras se ven igual, el detalle y el anuncio, al salir."]
		elseif n > 0 then
			nota = L["Los datos son del medidor oficial del juego: tú, tu grupo o banda y sus mascotas."]
		end
		self.Nota:SetText(nota)
		K.Mostrar(self.Nota, nota ~= "")
		if n == 0 then
			local titulo, texto, boton = M.EstadoMedidor(r)
			self.Vacio:Set({ lobo = boton and "atento" or "dormido", titulo = titulo, texto = texto, accion = boton })
		end
		K.Mostrar(self.Vacio, n == 0)
		local aparte = n > 0 and r.filas[n].aparte and "a" or ""
		local forma = n .. aparte .. (r.ok and "s" or "n") .. (nota ~= "" and "t" or "") .. (r.secreto and "x" or "")
		local cambio = forma ~= self.alfaForma
		self.alfaForma = forma
		return cambio
	end
	return b
end

---------------------------------------------------------------------------
-- 4. Tu prioridad
---------------------------------------------------------------------------
local function celda(padre)
	local c = CreateFrame("Frame", nil, padre)
	c.caja = K.Caja(c, { fondo = "panel", borde = "linea", corte = K.CORTE.control })
	c.Num = K.Texto(c, "numero", "textoTenue")
	c.Num:SetJustifyH("RIGHT")
	c.Num:SetWidth(18)
	c.Num:SetPoint("TOPLEFT", c, "TOPLEFT", ESP.s, -ESP.m - 6)
	c.Icono = c:CreateTexture(nil, "ARTWORK")
	c.Icono:SetSize(28, 28)
	c.Icono:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	c.Icono:SetPoint("TOPLEFT", c, "TOPLEFT", ESP.s + 18 + ESP.s, -ESP.m)
	c.Nombre = K.Texto(c, "cuerpo", "texto")
	c.Porque = K.Texto(c, "nota", "textoSuave")
	c.Insignia = K.Insignia(c, "", "neutro")
	function c:Set(x)
		self.alfaDato = x
		self.Num:SetText(tostring(x.orden))
		self.Icono:SetTexture(M.IconoHechizo(x.id) or K.Lobo("normal"))
		K.Escribir(self.Nombre, x.nombre or "?")
		K.Escribir(self.Porque, x.porque or "")
		if x.situacion then self.Insignia:Set(x.situacion[1], x.situacion[2]) else self.Insignia:Set("", "neutro") end
	end
	function c:Acomodar(ancho, altoMin)
		local x = ESP.s + 18 + ESP.s + 28 + ESP.m
		local iw = self.Insignia:IsShown() and (K.num(self.Insignia:GetWidth(), 0) + ESP.s) or 0
		local tw = max(60, ancho - x - ESP.m - iw)
		self.Nombre:ClearAllPoints()
		self.Nombre:SetPoint("TOPLEFT", self, "TOPLEFT", x, -ESP.m)
		self.Nombre:SetWidth(tw)
		self.Insignia:ClearAllPoints()
		self.Insignia:SetPoint("TOPRIGHT", self, "TOPRIGHT", -ESP.m, -ESP.m + 2)
		local y = ESP.m + K.AltoTexto(self.Nombre)
		if (self.Porque:GetText() or "") ~= "" then
			self.Porque:ClearAllPoints()
			self.Porque:SetPoint("TOPLEFT", self, "TOPLEFT", x, -(y + 2))
			y = y + 2 + K.Parrafo(self.Porque, ancho - x - ESP.m, 2)
		end
		local alto = max(altoMin or 0, y + ESP.m, 28 + 2 * ESP.m)
		self:SetSize(ancho, alto)
		return alto
	end
	return c
end

-- La insignia de situación de una entrada.
situacion = function(x)
	local d = x.def
	if d.aoe or d.minEnemigos then return { L["Área"], "aviso" } end
	if d.corta then return { L["Cortar"], "peligro" } end
	if d.remate or d.bajoVida then return { L["Remate"], "peligro" } end
	if d.vidaPropia or d.vidaMascota then return { L["Vida baja"], "exito" } end
	if x.con then return { L["Efecto activo"], "acento" } end
	if d.enGrupo then return { L["En grupo"], "clase" } end
	if d.fueraCombate then return { L["Antes de pelear"], "neutro" } end
	if d.solo then return { L["Un enemigo"], "neutro" } end
	return nil
end

local function bloquePrioridad(padre)
	local b = K.Pila(padre, { espacio = ESP.m })
	b.Seccion = b:Agregar(K.Seccion(b, L["Tu prioridad"]))
	b.Nota = b:Agregar(K.Texto(b, "nota", "textoSuave"), { espacio = ESP.s })
	b.Nota.Acomodar = function(self, ancho) return K.Parrafo(self, ancho, 3) end
	b.Rejilla = b:Agregar(K.Rejilla(b, { min = 300, gap = ESP.s }), { espacio = ESP.m })
	b.celdas = {}
	-- -> si hay algo que mostrar
	function b:Llenar()
		local fuente = R.Fuente()
		local datos = {}
		if fuente == "alfa" then
			local rama = P.Rama()
			for i, x in ipairs(P.Lista()) do
				local d = x.def
				datos[#datos + 1] = { orden = i, id = x.id, nombre = x.nombre, porque = d.porque, situacion = situacion(x) }
			end
			self.Seccion:Set(rama and rama.nombre and format(L["Tu prioridad: %s"], rama.nombre) or L["Tu prioridad"], { cuenta = #datos })
			local _, origen = P.Rama()
			local de = origen == "ajuste" and L["Elegida por ti en los ajustes."]
				or origen == "talentos" and L["Elegida por tus talentos."] or L["La de tu clase mientras subes: cambia sola cuando pongas talentos."]
			self.Nota:SetText(de .. " " .. L["De arriba abajo: la primera que el juego te deja usar es la que sale en el ícono. Lo que el juego hace brillar pasa al frente; las de área salen con varios enemigos peleando. Solo aparecen las que ya aprendiste."])
		elseif fuente == "blizzard" then
			for i, id in ipairs(R.Hechizos()) do
				datos[#datos + 1] = { orden = i, id = id, nombre = M.NombreHechizo(id) }
			end
			self.Seccion:Set(L["Habilidades que vigila la ayuda de Blizzard"], { cuenta = #datos })
			self.Nota:SetText(L["El juego elige entre estas según la situación; el ícono te muestra cuál conviene ahora."])
		end
		local elems = {}
		for i, d in ipairs(datos) do
			local c = self.celdas[i] or celda(self.Rejilla)
			self.celdas[i] = c
			c:Set(d)
			c:Show()
			elems[i] = c
		end
		for i = #datos + 1, #self.celdas do self.celdas[i]:Hide() end
		self.Rejilla:SetElementos(elems)
		return #datos > 0
	end
	return b
end

---------------------------------------------------------------------------
-- 5. Ajustes
---------------------------------------------------------------------------
local function interruptor(clave)
	return function(fila) return K.Interruptor(fila, { clave = ID .. "." .. clave }) end
end

local function deslizador(clave, a, b, paso, formato)
	return function(fila)
		local d = K.Deslizador(fila, { min = a, max = b, paso = paso, clave = ID .. "." .. clave, formato = formato })
		d.alfaAnchoFila = 220
		return d
	end
end

local function segmentos(clave, valores)
	return function(fila)
		local o = {}
		for _, v in ipairs(valores) do o[#o + 1] = { valor = v, texto = tostring(v) } end
		local s = K.Segmentos(fila, { estilo = "segmentos", opciones = o, valor = M.Opt(clave), alCambiar = function(v) M.SetOpt(clave, v) end })
		s.Leer = function(self) self:SetValor(M.Opt(clave)) end
		return s
	end
end

local function pct(v) return floor((tonumber(v) or 0) * 100 + 0.5) .. " %" end
local function px(v) return floor(tonumber(v) or 0) .. " px" end
local function entero(v) return tostring(floor(tonumber(v) or 0)) end

local function si(clave) return function() return M.Opt(clave) and true or false end end
local function ambas(a, b) return function() return M.Opt(a) and M.Opt(b) and true or false end end

local function grupos(padre)
	local g1 = K.GrupoAjustes(padre, { titulo = L["Ícono de rotación"] })
	g1:Fila({ titulo = L["Mostrar la ayuda de rotación"], control = interruptor("rotacion"),
		texto = L["Un ícono con la habilidad que conviene ahora. Solo muestra: nunca aprieta nada por ti."] })
	g1:Fila({ titulo = L["Cuántas habilidades después"], control = segmentos("despues", { 0, 1, 2, 3 }), hija = true, activa = si("rotacion"),
		texto = L["Las que vienen después, más pequeñas a la derecha."] })
	g1:Fila({ titulo = L["También fuera de combate"], control = interruptor("fuera"), hija = true, activa = si("rotacion"),
		texto = L["Con un enemigo elegido, antes de empezar la pelea, y transparente para que no estorbe."] })
	g1:Fila({ titulo = L["Opacidad fuera de combate"], control = deslizador("alfaFuera", 0.15, 1, 0.05, pct), hija = true, activa = ambas("rotacion", "fuera"),
		texto = L["Qué tanto se ve el ícono mientras no peleas."] })
	g1:Fila({ titulo = L["Tamaño del ícono"], control = deslizador("tam", 32, 64, 4, px), hija = true, activa = si("rotacion") })
	g1:Fila({ titulo = L["Mostrar la tecla"], control = interruptor("tecla"), hija = true, activa = si("rotacion"),
		texto = L["La tecla del botón de tu barra con esa habilidad, sobre el ícono."] })
	g1:Fila({ titulo = L["Nombre de la habilidad"], control = interruptor("nombre"), hija = true, activa = si("rotacion"),
		texto = L["Debajo del ícono: útil mientras aprendes."] })
	g1:Fila({ titulo = L["Explicar por qué, unas pocas veces"], control = interruptor("porque"), hija = true, activa = si("rotacion"),
		texto = L["Una línea corta debajo del ícono, como «Golpe mortal: recarga lista». Cada una sale hasta 4 veces y luego se calla; su × la calla antes."] })
	g1:Fila({ titulo = L["Barrido de recarga"], control = interruptor("barrido"), hija = true, activa = si("rotacion"),
		texto = L["Un barrido oscuro y suave sobre los íconos mientras su recarga corre."] })
	local rama = g1:Fila({ titulo = L["Tu especialización"], hija = true, activa = si("rotacion"),
		texto = L["Con qué prioridad sugiere Alfa. Automática: la de tus talentos o, mientras subes, la de tu clase."],
		control = function(fila)
			local o = { { valor = "auto", texto = L["Automática"] } }
			for _, r in ipairs(P.Ramas()) do o[#o + 1] = { valor = r.clave, texto = r.nombre or r.clave } end
			local d = K.Desplegable(fila, { opciones = o, clave = ID .. ".rama", ancho = 160 })
			return d
		end })
	g1:Fila({ titulo = L["Resaltar el botón en tu barra"], hija = true, activa = si("rotacion"),
		texto = L["Marca el botón de tu barra que tiene la habilidad sugerida."],
		control = function(fila)
			-- Con el resaltado oficial, el ajuste es el del juego (lo lee y lo cambia R).
			local s = K.Interruptor(fila, { clave = ID .. ".resaltar", alCambiar = function(v) if R.ResaltadoOficial() then R.SetResaltado(v) end end })
			s.Leer = function(self) self:SetValor(R.ResaltadoActivo()) end
			return s
		end })
	local fuente = g1:Fila({ titulo = L["Usar siempre la prioridad de Alfa"], hija = true, activa = si("rotacion"), control = interruptor("prioridadAlfa"),
		texto = L["Aunque el juego ofrezca la ayuda de Blizzard, sugiere con la prioridad de Alfa para tu clase."] })
	g1:Fila({ titulo = L["Lugar de los marcos"], texto = L["Tus marcos de combate vuelven a su lugar de siempre."],
		control = function(fila) return K.Boton(fila, L["Restablecer"], function() M.ReiniciarPosiciones() end, { tipo = "secundario", tam = "chico" }) end })

	local g2 = K.GrupoAjustes(padre, { titulo = L["Avisos, golpe y estadísticas"] })
	g2:Fila({ titulo = L["Avisos de reacción"], control = interruptor("avisos"),
		texto = L["Un aviso corto cuando se activa una habilidad que depende de lo que pasó, como Abrumar después de que el enemigo esquive."] })
	g2:Fila({ titulo = L["Con sonido"], control = interruptor("avisosSonido"), hija = true, activa = si("avisos") })
	g2:Fila({ titulo = L["Explicar por qué"], control = interruptor("avisosPorque"), hija = true, activa = si("avisos"),
		texto = L["Una línea debajo del aviso con lo que pasó."] })
	g2:Fila({ titulo = L["También cuando el juego hace brillar otra habilidad"], control = interruptor("avisosOtros"), hija = true, activa = si("avisos"),
		texto = L["Cualquier habilidad tuya que el juego resalte por un efecto."] })
	local function textoExplicaciones()
		local n = M.TextosCallados()
		local t = format(L["Cada aviso y cada porqué sale con texto hasta %d veces y luego solo queda el ícono."], M.LIMITE_TEXTO)
		if n > 0 then t = t .. " " .. (n == 1 and L["Ya hay 1 callada."] or format(L["Ya hay %d calladas."], n)) end
		return t
	end
	local expl = g2:Fila({ titulo = L["Explicaciones"], texto = textoExplicaciones(),
		control = function(fila) return K.Boton(fila, L["Volver a mostrarlas"], function() M.ReiniciarTextos() end, { tipo = "secundario", tam = "chico" }) end })
	local golpe = g2:Fila({ titulo = L["Barra de golpe"], control = interruptor("golpe"),
		texto = L["Cuánto falta para tu siguiente golpe automático, con cada mano. Ayuda a meter Embate o Golpe heroico sin perder golpes."] })
	local golpeN = g2:Fila({ titulo = L["Segundos junto a la barra"], control = interruptor("golpeNumero"), hija = true, activa = si("golpe"),
		texto = L["El número que cuenta hacia atrás. Apagado, solo la barra."] })
	g2:Fila({ titulo = L["Panel de estadísticas"], control = interruptor("panel"),
		texto = L["Un cuadro pequeño y movible con tu vida y las estadísticas que más pesan para tu clase. En combate el juego oculta algunos números: se queda el último que se pudo leer."] })

	local g4 = K.GrupoAjustes(padre, { titulo = L["Misiones"] })
	g4:Fila({ titulo = L["Marcar a quien te falta para una misión"], control = interruptor("marcaMision"),
		texto = L["Un ícono de misión en la placa de nombre de los enemigos y personajes que todavía necesitas para una misión de tu registro. En mazmorras el juego oculta esos datos y no se marcan."] })
	g4:Fila({ titulo = L["Con un brillo suave"], control = interruptor("marcaMisionBrillo"), hija = true, activa = si("marcaMision"),
		texto = L["Además del ícono, un brillo dorado que late alrededor de su barra."] })

	local g3 = K.GrupoAjustes(padre, { titulo = L["Medidor de daño"] })
	g3:Fila({ titulo = L["Mostrar la ventana del medidor"], control = interruptor("medidor"),
		texto = L["También con /alfa dps. No se cierra con Esc, para que la tengas a la vista al pelear."] })
	g3:Fila({ titulo = L["Solo cuando estás en grupo"], control = interruptor("medidorGrupo"), hija = true, activa = si("medidor"),
		texto = L["Si juegas sin grupo, la ventana se esconde."] })
	g3:Fila({ titulo = L["Opacidad de la ventana"], control = deslizador("opacidad", 0.3, 1, 0.05, pct), hija = true, activa = si("medidor") })
	g3:Fila({ titulo = L["Cuántos en el top"], control = deslizador("filas", 3, 10, 1, entero),
		texto = L["En la ventana y aquí. Si no estás entre ellos, tu fila sale al final."] })
	g3:Fila({ titulo = L["Cuántos se anuncian"], control = segmentos("anunciar", { 3, 5, 10 }),
		texto = L["Las líneas que escribe Anunciar en el chat de tu grupo o banda."] })

	-- Lo que no aplica a ti no se muestra.
	local function filtrar()
		K.Mostrar(fuente, R.Disponible() and true or false)
		K.Mostrar(golpe, not LANZADORES[M.Clase() or ""])
		K.Mostrar(golpeN, not LANZADORES[M.Clase() or ""])
		K.Mostrar(rama, R.Fuente() == "alfa" and #P.Ramas() > 0)
		if type(expl.alfaDatos) == "table" then expl.alfaDatos.texto = textoExplicaciones() end
	end
	return { g1, g2, g4, g3 }, filtrar
end

---------------------------------------------------------------------------
-- La página
---------------------------------------------------------------------------
local function construir(view)
	local ui = {}
	local t = K.Tablero(view, { margen = N.MargenPagina(), accion = "estado", tituloOpciones = L["Tus herramientas de combate"], min = 256 })
	ui.medidor = t:AgregarBloque(bloqueMedidor(t.Extra))
	ui.prioridad = t:AgregarBloque(bloquePrioridad(t.Extra), { espacio = ESP.xl })
	ui.ajustes, ui.filtrar = grupos(t.Extra)
	for i, g in ipairs(ui.ajustes) do t:AgregarBloque(g, { espacio = i == 1 and ESP.xl or ESP.l }) end
	K.EnPagina(view, t, function()
		t:SetAccion(estado())
		t:SetOpciones(herramientas(), L["Tus herramientas de combate"])
		ui.medidor:Llenar()
		K.Mostrar(ui.prioridad, ui.prioridad:Llenar() and M.Opt("rotacion") and true or false)
		ui.filtrar()
		for _, g in ipairs(ui.ajustes) do g:Refrescar() end
	end)
	M.vista, M.ui = view, ui
end

-- Algo cambió (un ajuste, tus hechizos, el combate): la página se rehace si está a la vista.
M.alCambiar = function()
	local view = M.vista
	if view then N.RehacerPagina(view) end
end

-- Llegaron datos del medidor: solo se repintan sus filas (y se mide de
-- nuevo si cambió cuántas son).
M.alMedidor = function()
	local view, ui = M.vista, M.ui
	if not (view and ui and view.IsVisible and view:IsVisible()) then return end
	if ui.medidor:Llenar() then N.RehacerPagina(view) end
end

N.Modulo({
	id = ID, nombre = L["Combate"], icono = M.ICONO, orden = 15, seccion = "personaje",
	subtitulo = L["Qué habilidad presionar ahora y cuáles siguen, avisos de reacción y el top de daño de tu grupo."],
	ajustes = M.AJUSTES,
	construir = construir,
})
