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
local Co, Am, Rs, Rg = M.Corte, M.Amenaza, M.Resumen, M.Recargas
local Cu = M.Cuenta
local ID = M.ID

local floor, max, min, format, ipairs, tonumber, type = math.floor, math.max, math.min, string.format, ipairs, tonumber, type
local ESP = K.ESP
local FILA, GAP = 26, 2

local LANZADORES = { MAGE = true, PRIEST = true, WARLOCK = true }
local situacion -- más abajo

-- 1.3.2: lo que se prueba o se mueve sale en pantalla, debajo de la ventana
-- de Alfa: se cierra la ventana y una línea en tu chat dice cómo volver.
-- 1.3.6: en vez de la línea con el comando, un aviso con «Volver a Combate».
local function aLaVista(fn, aviso)
	return function()
		if fn() == false then return end
		N.CerrarVentana()
		K.Aviso({ titulo = L["Combate"], texto = aviso, icono = M.ICONO, duracion = 10,
			accion = { texto = L["Volver a Combate"], alClic = function() N.Abrir(ID) end } })
	end
end
local function moverMarcos()
	M.Desbloquear(true)
	if not M.Desbloqueado() then return false end -- en combate no se mueven (ya lo dijo)
end

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
		d.accion = { texto = L["Fijar marcos"], icono = "ic-exito", alClic = function() M.Desbloquear(false) end }
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
		d.accion = { texto = L["Mover marcos"], icono = "ic-seguir",
			alClic = aLaVista(moverMarcos, L["Arrastra tus marcos de combate adonde te acomoden. Para fijarlos, vuelve a Combate."]) }
	end
	return d
end

---------------------------------------------------------------------------
-- 2. Herramientas
---------------------------------------------------------------------------
local function herramientas()
	local out = {}
	-- Medidor
	-- 1.3.7: dice cuándo sale (127) y, sin el medidor del juego, por qué no sale (26).
	local disponible, motivo = D.Disponible()
	local abierta = M.Ventana.Abierta()
	local modo = M.ModoMedidor()
	local m = { icono = "ic-manada", titulo = L["Medidor de daño"], lineas = 5 }
	if not D.Existe() then
		m.texto = L["Alfa dibuja el daño de tu grupo con el medidor oficial del juego, y tu cliente no lo trae. Por eso la gráfica no sale sola."]
		m.insignias = { { L["No disponible"], "aviso" } }
	elseif not disponible then
		m.texto = motivo
		m.insignias = { { L["No disponible"], "aviso" } }
	elseif D.Encendido() == false and D.Leer("todo", "dano", 1).vacia then
		m.texto = L["El registro de daño del juego está apagado: enciéndelo para ver el top de tu grupo."]
		m.insignias = { { L["Apagado"], "neutro" } }
		m.accion = D.AccionEncender()
	else
		local cuando = (modo == "siempre" and L["Siempre a la vista."]) or (modo == "apagado" and L["Apagado: sale solo si lo abres tú (/alfa dps)."])
			or L["Sale solo en grupo, en banda y en mazmorras."]
		local otro = modo == "auto" and M.Ventana.OtroMedidor()
		if otro then cuando = format(L["Con %s no sale sola, para que no veas dos medidores."], otro) end
		m.texto = L["Una gráfica pequeña con el daño de tu grupo, abajo a la derecha. Clic derecho sobre ella: qué se mide, anunciar y más."] .. " " .. cuando
		local insignia = (modo == "siempre" and { L["Siempre"], "exito" }) or (modo == "apagado" and { L["Apagado"], "neutro" }) or { L["Sale en grupo"], "exito" }
		m.insignias = { insignia }
		m.accion = { texto = abierta and L["Esconderla"] or L["Verla ahora"], alClic = function() M.Ventana.Alternar() end }
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
	a.accion = { texto = L["Probar un aviso"], alClic = aLaVista(function() Rc.Probar() end, L["Así se ve en pantalla."]) }
	out[#out + 1] = a
	-- 1.3.0: tu última pelea (el resumen) y el aviso para cortar.
	local u = Rs.Ultima()
	local p = { icono = "ic-lista", titulo = L["Tu última pelea"], lineas = 5 }
	if u then
		local partes = {}
		if u.dano and u.dano > 0 then partes[#partes + 1] = format(L["%s de daño"], D.Numero(u.dano)) end
		if u.cura and u.cura > 0 then partes[#partes + 1] = format(L["%s de curación"], D.Numero(u.cura)) end
		local t = #partes > 0 and (M.Juntar(partes) .. ".") or ""
		local g = Rs.TextoGolpe(u.golpe)
		if g then t = (t ~= "" and (t .. " ") or "") .. g end
		p.texto = t ~= "" and t or L["El medidor del juego no tiene números de esta pelea."]
		local dur = D.Tiempo(u.dur)
		if dur then p.insignias = { { dur, "neutro" } } end
		p.accion = { texto = L["Ver de nuevo"], alClic = aLaVista(function() return Rs.VerDeNuevo() end, L["Así se ve en pantalla."]) }
	else
		p.texto = L["Al terminar una pelea, aquí queda su resumen: tu daño, tu curación y lo que más te pegó."]
	end
	-- 1.3.8: apagado (de fábrica) no sale solo, pero se guarda: «a pedido».
	if not M.Opt("resumen") then
		p.insignias = p.insignias or {}
		p.insignias[#p.insignias + 1] = { L["A pedido"], "neutro" }
	end
	out[#out + 1] = p
	-- 1.4.2: lo que te tumbó la última vez (Caida.lua).
	local Ca = M.Caida
	local uc = Ca and Ca.Ultima()
	local cd = { icono = "ic-alerta", titulo = L["Tu última caída"], lineas = 5 }
	if uc then
		local g = type(uc.golpes) == "table" and uc.golpes[1]
		local f = type(uc.final) == "table" and uc.final
		local partes = {}
		if f and f.nombre then partes[#partes + 1] = f.quien and format(L["El golpe final: %s, de %s."], f.nombre, f.quien) or format(L["El golpe final: %s."], f.nombre) end
		if g and g.nombre and not (f and f.nombre == g.nombre) then
			partes[#partes + 1] = format(L["Lo que más te pegó: %s (%s)."], g.nombre, D.Numero(g.valor))
		end
		local total, ev = tonumber(uc.total) or 0, tonumber(uc.evitable) or 0
		if total > 0 and ev > 0 then partes[#partes + 1] = format(L["Se podía evitar el %d %%."], floor(ev * 100 / total + 0.5)) end
		cd.texto = #partes > 0 and table.concat(partes, " ") or L["El medidor del juego no tiene números de esta pelea."]
		if uc.zona then cd.insignias = { { uc.zona, "neutro" } } end
		cd.accion = { texto = L["Ver de nuevo"], alClic = aLaVista(function() return Ca.Ver(true) end, L["Así se ve en pantalla."]) }
	else
		cd.texto = L["Si caes en una pelea, aquí queda lo que te tumbó: el golpe final, lo que más te pegó y cuánto se podía evitar."]
	end
	if Ca and not M.Opt("caida") then
		cd.insignias = cd.insignias or {}
		cd.insignias[#cd.insignias + 1] = { L["A pedido"], "neutro" }
	end
	if Ca then out[#out + 1] = cd end
	local corte = Co.Habilidad()
	local c = { icono = "ic-alerta", titulo = L["Aviso para cortar"], lineas = 5 }
	if corte then
		c.texto = format(L["Cuando tu objetivo lance algo que se puede cortar, te avisa con %s y su tecla."], M.NombreHechizo(corte) or "?")
	else
		c.texto = L["Cuando aprendas una habilidad para cortar hechizos, te avisa en cuanto tu objetivo empiece a lanzar."]
	end
	c.insignias = { M.Opt("corte") and { L["Encendido"], "exito" } or { L["Apagado"], "neutro" } }
	c.accion = { texto = L["Probar el aviso"], alClic = aLaVista(function() Co.Probar() end, L["Así se ve en pantalla."]) }
	out[#out + 1] = c
	-- 1.3.7: para jefes y mazmorras: «Sal de ahí», la cuenta y los temporizadores.
	local j = { icono = "ic-mazmorra", titulo = L["Jefes y mazmorras"], lineas = 5 }
	local partes = {}
	if M.Opt("salDeAhi") then partes[#partes + 1] = L["«¡Sal de ahí!» si pisas algo que daña"] end
	if M.Opt("cuenta") then partes[#partes + 1] = L["la cuenta para jalar en grande"] end
	if M.Opt("jefes") then partes[#partes + 1] = L["cuándo viene el próximo ataque del jefe"] end
	if #partes > 0 then
		j.texto = format(L["En instancias: %s."], M.Juntar(partes))
		j.insignias = { { L["Encendido"], "exito" } }
	else
		j.texto = L["Ayudas para mazmorras y bandas: «¡Sal de ahí!», la cuenta para jalar y los tiempos del jefe. Enciéndelas abajo, en Ajustes."]
		j.insignias = { { L["Apagado"], "neutro" } }
	end
	local lanzar = Cu.Accion()
	if lanzar then
		j.accion = lanzar
	else
		j.accion = { texto = L["Probar «¡Sal de ahí!»"], alClic = aLaVista(function() M.SalDeAhi.Probar() end, L["Así se ve en pantalla."]) }
	end
	out[#out + 1] = j
	-- El resaltado del botón no va aquí: es una fila de "Ícono de rotación".
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
		local puede, porque = D.PuedeAnunciar(M.Opt("sesion"), M.Opt("tipo"), r) -- 1.3.7: con la misma lectura
		barra.Anunciar:SetActivo(puede, porque) -- (1.4.0, 112: apagado, su globo dice por qué)
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
-- 4b. Tus recargas largas (1.3.0): cuáles salen en la barra
---------------------------------------------------------------------------
local function celdaRecarga(padre)
	local c = CreateFrame("Frame", nil, padre)
	c.caja = K.Caja(c, { fondo = "panel", borde = "linea", corte = K.CORTE.control })
	c.Icono = c:CreateTexture(nil, "ARTWORK")
	c.Icono:SetSize(24, 24)
	c.Icono:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	c.Icono:SetPoint("LEFT", c, "LEFT", ESP.m, 0)
	c.Nombre = K.Texto(c, "cuerpo", "texto")
	c.Dura = K.Texto(c, "nota", "textoSuave")
	c.Interruptor = K.Interruptor(c, {
		get = function() return c.alfaNombre and not Rg.Oculta(c.alfaNombre) or false end,
		set = function(v) if c.alfaNombre then Rg.Ocultar(c.alfaNombre, not v) end end,
	})
	function c:Set(x)
		self.alfaNombre = x.nombre
		self.Icono:SetTexture(M.IconoHechizo(x.id) or K.Lobo("normal"))
		K.Escribir(self.Nombre, x.nombre)
		K.Escribir(self.Dura, format(L["Vuelve en %s"], Rg.Tiempo(x.dur)))
		self.Interruptor:Leer()
	end
	function c:Acomodar(ancho)
		local x = ESP.m + 24 + ESP.m
		local tw = max(60, ancho - x - ESP.m - 36 - ESP.m)
		self.Interruptor:ClearAllPoints()
		self.Interruptor:SetPoint("RIGHT", self, "RIGHT", -ESP.m, 0)
		self.Nombre:ClearAllPoints()
		self.Nombre:SetPoint("TOPLEFT", self, "TOPLEFT", x, -ESP.s - 1)
		self.Nombre:SetWidth(tw)
		self.Dura:ClearAllPoints()
		self.Dura:SetPoint("TOPLEFT", self.Nombre, "BOTTOMLEFT", 0, -1)
		self.Dura:SetWidth(tw)
		local alto = max(24 + 2 * ESP.s, 2 * ESP.s + 2 + K.AltoTexto(self.Nombre) + 1 + K.AltoTexto(self.Dura))
		self:SetSize(ancho, alto)
		return alto
	end
	return c
end

local function bloqueRecargas(padre)
	local b = K.Pila(padre, { espacio = ESP.m })
	b.Seccion = b:Agregar(K.Seccion(b, L["Tus recargas largas"]))
	b.Nota = b:Agregar(K.Texto(b, "nota", "textoSuave"), { espacio = ESP.s })
	b.Nota.Acomodar = function(self, ancho) return K.Parrafo(self, ancho, 3) end
	b.Rejilla = b:Agregar(K.Rejilla(b, { min = 240, gap = ESP.s }), { espacio = ESP.m })
	b.celdas = {}
	function b:Llenar()
		local lista = Rg.Conocidas()
		self.Seccion:Set(L["Tus recargas largas"], { cuenta = #lista })
		self.Nota:SetText(L["Las que ya usaste y tardan en volver. Apaga las que no quieras ver en la barra."])
		local elems = {}
		for i, x in ipairs(lista) do
			local c = self.celdas[i] or celdaRecarga(self.Rejilla)
			self.celdas[i] = c
			c:Set(x)
			c:Show()
			elems[i] = c
		end
		for i = #lista + 1, #self.celdas do self.celdas[i]:Hide() end
		self.Rejilla:SetElementos(elems)
		return #lista > 0
	end
	return b
end

---------------------------------------------------------------------------
-- 4c. 1.3.9: tus últimas peleas, lado a lado (Resumen.lua)
---------------------------------------------------------------------------
local function hace(t)
	t = tonumber(t)
	if not (t and time) then return nil end
	local s = math.max(0, time() - t)
	if s < 90 then return L["hace un momento"] end
	if s < 3600 then return format(L["hace %d min"], floor(s / 60)) end
	if s < 86400 then return format(L["hace %d h"], floor(s / 3600)) end
	return N.Plural(floor(s / 86400), L["hace %d día"], L["hace %d días"])
end

local function bloquePeleas(padre)
	local b = K.Pila(padre, { espacio = ESP.m })
	b.Seccion = b:Agregar(K.Seccion(b, L["Tus últimas peleas"]))
	b.Nota = b:Agregar(K.Texto(b, "nota", "textoSuave"), { espacio = ESP.s })
	b.Nota.Acomodar = function(self, ancho) return K.Parrafo(self, ancho, 3) end
	b.Rejilla = b:Agregar(K.Rejilla(b, { min = 300, gap = ESP.s, variante = "compacta" }), { espacio = ESP.m })
	function b:Llenar()
		local lista = Rs.Peleas()
		local datos = {}
		local mejor
		for _, p in ipairs(lista) do local v = Rs.Ritmo(p) if v and (not mejor or v > mejor) then mejor = v end end
		for i, p in ipairs(lista) do
			local v, tipo = Rs.Ritmo(p)
			local partes = {}
			local dur = D.Tiempo(p.dur)
			if dur then partes[#partes + 1] = dur end
			if p.zona then partes[#partes + 1] = p.zona end
			local cuando = hace(p.cuando)
			if cuando then partes[#partes + 1] = cuando end
			local dif = Rs.Diferencia(i, lista)
			local valor = v and v > 0 and format(tipo == "cps" and L["%s cps"] or L["%s dps"], D.Numero(v)) or L["sin datos"]
			local d = { variante = "compacta", icono = tipo == "cps" and "ic-curacion" or M.ICONO,
				titulo = i == 1 and L["La última"] or format(L["Hace %d peleas"], i - 1),
				texto = table.concat(partes, "  \194\183  "), valor = valor,
				tono = (v and mejor and v >= mejor and #lista > 1) and "exito" or "neutro" }
			if dif then
				local pct = floor(dif * 100 + 0.5)
				d.texto = d.texto .. "  \194\183  " .. (pct >= 0 and format(L["+%d %% que la de antes"], pct) or format(L["%d %% que la de antes"], pct))
			end
			if v and mejor and v >= mejor and #lista > 1 then d.ayuda = L["Tu mejor de estas peleas."] end
			datos[#datos + 1] = d
		end
		self.Seccion:Set(L["Tus últimas peleas"], { cuenta = #lista > 0 and #lista or nil })
		self.Nota:SetText(#lista > 1 and L["Tu daño o tu curación por segundo en cada una, contra la de antes. Se guardan las últimas 5."]
			or L["Al terminar cada pelea queda aquí, para compararla con las siguientes. Se guardan las últimas 5."])
		self.Rejilla:Llenar(datos)
		K.Mostrar(self.Rejilla, #datos > 0)
		return #lista > 0
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
local function porciento(v) return floor(tonumber(v) or 0) .. " %" end
local function segundos(v) return floor(tonumber(v) or 0) .. " s" end

local function si(clave) return function() return M.Opt(clave) and true or false end end
local function ambas(a, b) return function() return M.Opt(a) and M.Opt(b) and true or false end end

local function grupos(padre)
	local g1 = K.GrupoAjustes(padre, { titulo = L["Ícono de rotación"] })
	g1:Fila({ titulo = L["Mostrar la ayuda de rotación"], control = interruptor("rotacion"),
		texto = L["Un ícono con la habilidad que conviene ahora. Solo muestra: nunca aprieta nada por ti."] })
	g1:Fila({ titulo = L["Cuántas habilidades después"], control = segmentos("despues", { 0, 1, 2, 3 }), hija = true, activa = si("rotacion"),
		texto = L["Las que vienen después, más pequeñas a la derecha."] })
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
			-- Con el resaltado oficial, el ajuste es el del juego: se lee aquí y se
			-- cambia en sus opciones (el clic dice dónde y el interruptor vuelve a
			-- mostrar lo que hay).
			local s = K.Interruptor(fila, { clave = ID .. ".resaltar", alCambiar = function(v, self)
				if R.ResaltadoOficial() then R.SetResaltado(v) if self then self:Leer() end end
			end })
			s.Leer = function(self) self:SetValor(R.ResaltadoActivo()) end
			return s
		end })
	-- Lo de todos los días queda a la vista; lo fino, plegado bajo "Más
	-- opciones del ícono" (el Kit no pliega grupos: una fila con su interruptor
	-- muestra u oculta esas filas; se recuerda solo en esta sesión).
	local mas = {}
	local function plegada(o) local f = g1:Fila(o) mas[#mas + 1] = f return f end
	local masFila = g1:Fila({ titulo = L["Más opciones del ícono"], hija = true, activa = si("rotacion"),
		texto = L["Fuera de combate, tamaño, tecla, nombre, explicaciones, barrido y de dónde sale la sugerencia."],
		control = function(fila)
			return K.Interruptor(fila, { get = function() return M.masIcono and true or false end,
				set = function(v) M.masIcono = v and true or false M.Avisar() end })
		end })
	plegada({ titulo = L["También fuera de combate"], control = interruptor("fuera"), hija = true, activa = si("rotacion"),
		texto = L["Con un enemigo elegido, antes de empezar la pelea, y transparente para que no estorbe."] })
	plegada({ titulo = L["Opacidad fuera de combate"], control = deslizador("alfaFuera", 0.15, 1, 0.05, pct), hija = true, activa = ambas("rotacion", "fuera"),
		texto = L["Qué tanto se ve el ícono mientras no peleas."] })
	plegada({ titulo = L["Tamaño del ícono"], control = deslizador("tam", 32, 96, 4, px), hija = true, activa = si("rotacion") })
	plegada({ titulo = L["Tamaño de las que siguen"], control = deslizador("tamDespues", 0.5, 1, 0.05, pct), hija = true, activa = si("rotacion"),
		texto = L["Qué tan grandes salen las que vienen después, comparadas con el ícono principal."] })
	plegada({ titulo = L["Mostrar la tecla"], control = interruptor("tecla"), hija = true, activa = si("rotacion"),
		texto = L["La tecla del botón de tu barra con esa habilidad, sobre el ícono."] })
	plegada({ titulo = L["Tecla grande"], control = interruptor("teclaGrande"), hija = true, activa = ambas("rotacion", "tecla"),
		texto = L["Abajo y al centro del ícono, con letra que crece con él. Apagada, chiquita en la esquina."] })
	plegada({ titulo = L["Nombre de la habilidad"], control = interruptor("nombre"), hija = true, activa = si("rotacion"),
		texto = L["Debajo del ícono: útil mientras aprendes."] })
	plegada({ titulo = L["Explicar por qué, unas pocas veces"], control = interruptor("porque"), hija = true, activa = si("rotacion"),
		texto = L["Una línea corta debajo del ícono, como «Golpe mortal: recarga lista». Cada una sale hasta 4 veces y luego se calla; su × la calla antes."] })
	plegada({ titulo = L["Barrido de recarga"], control = interruptor("barrido"), hija = true, activa = si("rotacion"),
		texto = L["Un barrido oscuro y suave sobre los íconos mientras su recarga corre."] })
	local fuente = plegada({ titulo = L["Usar siempre la prioridad de Alfa"], hija = true, activa = si("rotacion"), control = interruptor("prioridadAlfa"),
		texto = L["Sugiere con la prioridad de Alfa para tu clase. Apagado, usa la ayuda de Blizzard cuando el juego da una sugerencia que Alfa puede leer; en combate Forever la oculta, así que ahí sigue la de Alfa."] })
	g1:Fila({ titulo = L["Volver a su lugar"], texto = L["Tus marcos de combate vuelven a su lugar de siempre."],
		control = function(fila) return K.Boton(fila, L["Restablecer"], function()
			M.ReiniciarPosiciones()
			N.Imprimir(L["Tus marcos de combate volvieron a su lugar de siempre."])
		end, { tipo = "secundario", tam = "chico" }) end })

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
		control = function(fila) return K.Boton(fila, L["Volver a mostrarlas"], function()
			local n = M.TextosCallados()
			M.ReiniciarTextos()
			N.Imprimir(n > 0 and L["Las explicaciones vuelven a salir."] or L["No había explicaciones calladas: ya salen todas."])
		end, { tipo = "secundario", tam = "chico" }) end })
	local golpe = g2:Fila({ titulo = L["Barra de golpe"], control = interruptor("golpe"),
		texto = L["Cuánto falta para tu siguiente golpe automático, con cada mano. Ayuda a meter Embate o Golpe heroico sin perder golpes."] })
	local golpeN = g2:Fila({ titulo = L["Segundos junto a la barra"], control = interruptor("golpeNumero"), hija = true, activa = si("golpe"),
		texto = L["El número que cuenta hacia atrás. Apagado, solo la barra."] })
	g2:Fila({ titulo = L["Panel de estadísticas"], control = interruptor("panel"),
		texto = L["Un cuadro pequeño y movible con tu vida y las estadísticas que más pesan para tu clase. En combate el juego oculta algunos números: se queda el último que se pudo leer."] })

	-- 1.3.0: ayudas de pelea
	local g5 = K.GrupoAjustes(padre, { titulo = L["Cortar, amenaza y recargas"] })
	g5:Fila({ titulo = L["Aviso para cortar"], control = interruptor("corte"),
		texto = L["Cuando tu objetivo lanza algo que se puede cortar: tu habilidad para cortar, su tecla y si está lista."] })
	g5:Fila({ titulo = L["También tu foco"], control = interruptor("corteFoco"), hija = true, activa = si("corte") })
	g5:Fila({ titulo = L["Con sonido"], control = interruptor("corteSonido"), hija = true, activa = si("corte"),
		texto = L["En grupo o en una instancia."] })
	g5:Fila({ titulo = L["También yendo solo"], control = interruptor("corteSonidoSolo"), hija = true,
		activa = ambas("corte", "corteSonido"),
		texto = L["Que suene también cuando vas solo por el mundo."] })
	g5:Fila({ titulo = L["Más suave si el juego oculta el hechizo"], control = interruptor("corteSonidoOculto"), hija = true,
		activa = ambas("corte", "corteSonido"),
		texto = L["En mazmorras y bandas el juego a veces no dice qué lanza el enemigo: suena más suave, y a veces también con lo que no se puede cortar."] })
	g5:Fila({ titulo = L["Barra de amenaza"], control = interruptor("amenaza"),
		texto = L["En grupo o con tu mascota: tu amenaza sobre tu objetivo. Te avisa antes de quitárselo al tanque, o si eres tanque, antes de perderlo."] })
	g5:Fila({ titulo = L["Tu papel"], hija = true, activa = si("amenaza"),
		texto = L["Automático: el que marcaste en tu grupo, o tu actitud o forma."],
		control = function(fila)
			local o = {}
			for _, x in ipairs(Am.PAPELES) do o[#o + 1] = { valor = x.clave, texto = x.texto } end
			return K.Desplegable(fila, { opciones = o, clave = ID .. ".amenazaPapel", ancho = 150 })
		end })
	g5:Fila({ titulo = L["Avisar desde"], control = deslizador("amenazaAviso", 60, 95, 5, porciento), hija = true, activa = si("amenaza"),
		texto = L["Si no eres tanque: con cuánta amenaza se pone amarilla."] })
	g5:Fila({ titulo = L["Con sonido"], control = interruptor("amenazaSonido"), hija = true, activa = si("amenaza") })
	g5:Fila({ titulo = L["Resumen al terminar cada pelea"], control = interruptor("resumen"),
		texto = L["Una tarjeta al terminar: cuánto duró, tu daño y tu curación por segundo y lo que más te pegó. Apagado, tu última pelea se guarda igual y la ves aquí arriba o en el menú del medidor."] })
	g5:Fila({ titulo = L["Solo peleas de al menos"], control = deslizador("resumenMin", 0, 30, 5, segundos), hija = true, activa = si("resumen"),
		texto = L["En grupo o en una instancia."] })
	g5:Fila({ titulo = L["Yendo solo, peleas de al menos"], control = deslizador("resumenMinSolo", 0, 60, 5, segundos), hija = true, activa = si("resumen"),
		texto = L["Cuando vas solo por el mundo, así no sale tras cada enemigo."] })
	g5:Fila({ titulo = L["Al caer, lo que te tumbó"], control = interruptor("caida"),
		texto = L["Si mueres en una pelea, un aviso con el golpe final, lo que más te pegó y cuánto se podía evitar. Apagado, se guarda igual y lo ves aquí arriba."] })
	g5:Fila({ titulo = L["Recargas largas"], control = interruptor("recargas"),
		texto = L["Tus habilidades que tardan en volver, en una barra discreta con lo que les falta."] })
	g5:Fila({ titulo = L["Desde cuántos segundos"], control = segmentos("recargasMin", { 30, 60, 120 }), hija = true, activa = si("recargas") })

	local g4 = K.GrupoAjustes(padre, { titulo = L["Misiones"] })
	g4:Fila({ titulo = L["Marcar a quien te falta para una misión"], control = interruptor("marcaMision"),
		texto = L["Un ícono de misión en la placa de nombre de los enemigos y personajes que todavía necesitas para una misión de tu registro. En mazmorras el juego oculta esos datos y no se marcan."] })
	g4:Fila({ titulo = L["Con un brillo suave"], control = interruptor("marcaMisionBrillo"), hija = true, activa = si("marcaMision"),
		texto = L["Además del ícono, un brillo dorado que late alrededor de su barra."] })

	local g3 = K.GrupoAjustes(padre, { titulo = L["Medidor de daño"] })
	-- 1.3.7: cuándo sale la gráfica (automático de fábrica) y cuántas filas en banda.
	local function encendido() return M.ModoMedidor() ~= "apagado" end
	g3:Fila({ titulo = L["Cuándo sale la gráfica"], texto = L["Automático: sola en grupo, en banda y en mazmorras; yendo solo, no. También con /alfa dps."],
		control = function(fila)
			local s = K.Segmentos(fila, { estilo = "segmentos", opciones = M.OpcionesModo(), valor = M.ModoMedidor(),
				alCambiar = function(v) M.SetOpt("medidorModo", v) end })
			s.Leer = function(self) self:SetValor(M.ModoMedidor()) end
			return s
		end })
	g3:Fila({ titulo = L["Filas en banda"], control = deslizador("filasBanda", 5, 20, 1, entero), hija = true, activa = encendido,
		texto = L["En grupo salen las 5 de tu grupo. Tu fila siempre se ve."] })
	g3:Fila({ titulo = L["Opacidad de la ventana"], control = deslizador("opacidad", 0.3, 1, 0.05, pct), hija = true, activa = encendido,
		texto = L["10 segundos después de la pelea se atenúa más; al pasar el ratón vuelve."] })
	g3:Fila({ titulo = L["Cuántos en el top"], control = deslizador("filas", 3, 10, 1, entero),
		texto = L["En la ventana y aquí. Si no estás entre ellos, tu fila sale al final."] })
	g3:Fila({ titulo = L["Cuántos se anuncian"], control = segmentos("anunciar", { 3, 5, 10 }),
		texto = L["Anunciar escribe 3 líneas cortas en el chat de tu grupo o banda, solo cuando tú le das clic."] })

	-- 1.3.7: jefes y mazmorras, y tus efectos.
	local g6 = K.GrupoAjustes(padre, { titulo = L["Jefes y mazmorras"] })
	g6:Fila({ titulo = L["«¡Sal de ahí!»"], control = interruptor("salDeAhi"),
		texto = L["En instancias, si pisas fuego, veneno o algo que deja el jefe en el suelo: un aviso rojo breve. Si el juego oculta esos datos, se apaga solo."] })
	g6:Fila({ titulo = L["Con sonido"], control = interruptor("salDeAhiSonido"), hija = true, activa = si("salDeAhi") })
	g6:Fila({ titulo = L["La cuenta para jalar en grande"], control = interruptor("cuenta"),
		texto = L["Cuando alguien lanza la cuenta del juego, un anuncio con quién la lanzó y cuánto falta."] })
	g6:Fila({ titulo = L["Tiempos del jefe"], control = interruptor("jefes"),
		texto = L["Alfa aprende pelea a pelea cada cuánto lanza el jefe sus ataques y te dice «Próximo Aliento en ~15 s». La primera vez no dice nada."] })
	g6:Fila({ titulo = L["Tus efectos a la vista"], control = interruptor("efectos"),
		texto = L["Tus venenos, maldiciones, escudos y curas que duran, con lo que les queda, en una fila chica."] })
	g6:Fila({ titulo = L["Avisar cuando uno se acaba"], control = interruptor("efectosAviso"), hija = true, activa = si("efectos") })

	-- 1.3.9: «Más ajustes». De fábrica se ven el ícono, cortar, la amenaza, el
	-- resumen, las recargas y el medidor, sin sus detalles; lo demás (avisos y
	-- golpe, jefes, misiones) y las filas hijas de esos grupos, plegados.
	local g7 = K.GrupoAjustes(padre, {})
	g7:Fila({ titulo = L["Más ajustes"], texto = L["Avisos de reacción, la barra de golpe, jefes y mazmorras, misiones y el detalle de cada herramienta."],
		control = function(fila) return K.Interruptor(fila, { clave = ID .. ".paginaCompleta" }) end })
	local avanzados = { g2, g6, g4 }
	local conHijas = { g5, g3 }

	-- Lo que no aplica a ti no se muestra.
	local function filtrar()
		local completa = M.Opt("paginaCompleta") and true or false
		for _, g in ipairs(avanzados) do K.Mostrar(g, completa) end
		for _, g in ipairs(conHijas) do
			for _, f in ipairs(g.filas) do
				if type(f.alfaDatos) == "table" and f.alfaDatos.hija then K.Mostrar(f, completa) end
			end
		end
		local abiertas = M.masIcono and true or false
		for _, f in ipairs(mas) do K.Mostrar(f, abiertas) end
		K.Mostrar(masFila, true)
		K.Mostrar(fuente, abiertas and R.Disponible() and true or false)
		K.Mostrar(golpe, not LANZADORES[M.Clase() or ""])
		K.Mostrar(golpeN, not LANZADORES[M.Clase() or ""])
		K.Mostrar(rama, R.Fuente() == "alfa" and #P.Ramas() > 0)
		if type(expl.alfaDatos) == "table" then expl.alfaDatos.texto = textoExplicaciones() end
	end
	return { g1, g5, g3, g7, g2, g6, g4 }, filtrar
end

---------------------------------------------------------------------------
-- La página
---------------------------------------------------------------------------
local function construir(view)
	local ui = {}
	local t = K.Tablero(view, { margen = N.MargenPagina(), accion = "estado", tituloOpciones = L["Tus herramientas de combate"], min = 256 })
	ui.medidor = t:AgregarBloque(bloqueMedidor(t.Extra))
	ui.prioridad = t:AgregarBloque(bloquePrioridad(t.Extra), { espacio = ESP.xl })
	ui.recargas = t:AgregarBloque(bloqueRecargas(t.Extra), { espacio = ESP.xl })
	ui.peleas = t:AgregarBloque(bloquePeleas(t.Extra), { espacio = ESP.xl })
	ui.ajustes, ui.filtrar = grupos(t.Extra)
	for i, g in ipairs(ui.ajustes) do t:AgregarBloque(g, { espacio = i == 1 and ESP.xl or ESP.l }) end
	K.EnPagina(view, t, function()
		-- 1.3.3: la primera vez que abres Combate, cómo se lee tu ayuda de rotación.
		if R.Presentar then R.Presentar(true) end
		t:SetAccion(estado())
		t:SetOpciones(herramientas(), L["Tus herramientas de combate"])
		ui.medidor:Llenar()
		K.Mostrar(ui.prioridad, ui.prioridad:Llenar() and M.Opt("rotacion") and true or false)
		K.Mostrar(ui.recargas, ui.recargas:Llenar() and M.Opt("recargas") and true or false)
		ui.peleas:Llenar()
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

---------------------------------------------------------------------------
-- Para la búsqueda de ajustes de la ventana de Alfa (la página es propia):
-- los mismos ajustes de arriba, con su texto, atenuados y ocultos igual. Lo
-- que en la página va plegado bajo "Más opciones del ícono" aquí va suelto
-- (ese interruptor solo pliega filas: no va). Ni la sesión ni el tipo del
-- top de daño: son la vista del medidor, no ajustes.
---------------------------------------------------------------------------
local function clave(k) return ID .. "." .. k end
local function no(fn) return function() return not fn() end end
local function noLanzador() return not LANZADORES[M.Clase() or ""] end

local function toggle(k, label, help, padre, search)
	return { kind = "toggle", key = clave(k), label = label, help = help, search = search,
		child = padre and true or nil, disabled = padre and no(si(padre)) or nil }
end

local function numeros(valores)
	local t = {}
	for i, v in ipairs(valores) do t[i] = { value = v, label = tostring(v) } end
	return t
end

local CONTROLES = {
	toggle("rotacion", L["Mostrar la ayuda de rotación"], L["Un ícono con la habilidad que conviene ahora. Solo muestra: nunca aprieta nada por ti."], nil,
		"rotation helper, next ability, assisted combat, one button"),
	{ kind = "dropdown", key = clave("despues"), label = L["Cuántas habilidades después"], help = L["Las que vienen después, más pequeñas a la derecha."],
		choices = numeros({ 0, 1, 2, 3 }), child = true, disabled = no(si("rotacion")), search = "upcoming abilities, queue" },
	{ kind = "dropdown", key = clave("rama"), label = L["Tu especialización"],
		help = L["Con qué prioridad sugiere Alfa. Automática: la de tus talentos o, mientras subes, la de tu clase."],
		choices = function()
			local o = { { value = "auto", label = L["Automática"] } }
			for _, r in ipairs(P.Ramas()) do o[#o + 1] = { value = r.clave, label = r.nombre or r.clave } end
			return o
		end,
		needs = function() return R.Fuente() == "alfa" and #P.Ramas() > 0 end,
		child = true, disabled = no(si("rotacion")), search = "spec, specialization, talents, priority" },
	-- Con el resaltado oficial, el ajuste es el del juego (como en la página).
	{ kind = "toggle", key = clave("resaltar"), label = L["Resaltar el botón en tu barra"],
		help = L["Marca el botón de tu barra que tiene la habilidad sugerida."],
		get = function() return R.ResaltadoActivo() end,
		set = function(v)
			M.SetOpt("resaltar", v)
			if R.ResaltadoOficial() then R.SetResaltado(v) end
		end,
		child = true, disabled = no(si("rotacion")), search = "highlight button, action bar" },
	toggle("fuera", L["También fuera de combate"], L["Con un enemigo elegido, antes de empezar la pelea, y transparente para que no estorbe."], "rotacion", "out of combat"),
	{ kind = "slider", key = clave("alfaFuera"), label = L["Opacidad fuera de combate"], help = L["Qué tanto se ve el ícono mientras no peleas."],
		min = 0.15, max = 1, step = 0.05, format = pct, child = true, disabled = no(ambas("rotacion", "fuera")), search = "opacity, alpha, out of combat" },
	{ kind = "slider", key = clave("tam"), label = L["Tamaño del ícono"], min = 32, max = 96, step = 4, format = px,
		child = true, disabled = no(si("rotacion")), search = "icon size, scale, bigger" },
	{ kind = "slider", key = clave("tamDespues"), label = L["Tamaño de las que siguen"], min = 0.5, max = 1, step = 0.05, format = pct,
		help = L["Qué tan grandes salen las que vienen después, comparadas con el ícono principal."],
		child = true, disabled = no(si("rotacion")), search = "next icons size" },
	toggle("tecla", L["Mostrar la tecla"], L["La tecla del botón de tu barra con esa habilidad, sobre el ícono."], "rotacion", "keybind, hotkey"),
	toggle("teclaGrande", L["Tecla grande"], L["Abajo y al centro del ícono, con letra que crece con él. Apagada, chiquita en la esquina."], "rotacion", "big keybind, hotkey size"),
	toggle("nombre", L["Nombre de la habilidad"], L["Debajo del ícono: útil mientras aprendes."], "rotacion", "ability name, spell name"),
	toggle("porque", L["Explicar por qué, unas pocas veces"], L["Una línea corta debajo del ícono, como «Golpe mortal: recarga lista». Cada una sale hasta 4 veces y luego se calla; su × la calla antes."], "rotacion", "explain why, reason"),
	toggle("barrido", L["Barrido de recarga"], L["Un barrido oscuro y suave sobre los íconos mientras su recarga corre."], "rotacion", "cooldown swipe"),
	(function()
		local c = toggle("prioridadAlfa", L["Usar siempre la prioridad de Alfa"], L["Sugiere con la prioridad de Alfa para tu clase. Apagado, usa la ayuda de Blizzard cuando el juego da una sugerencia que Alfa puede leer; en combate Forever la oculta, así que ahí sigue la de Alfa."], "rotacion", "alfa priority, blizzard assisted combat")
		c.needs = function() return R.Disponible() and true or false end
		return c
	end)(),
	{ kind = "button", label = L["Volver a su lugar"], button = L["Restablecer"], icon = "window",
		help = L["Tus marcos de combate vuelven a su lugar de siempre."], onClick = function() M.ReiniciarPosiciones() end,
		search = "reset position, move frames" },
	toggle("avisos", L["Avisos de reacción"], L["Un aviso corto cuando se activa una habilidad que depende de lo que pasó, como Abrumar después de que el enemigo esquive."], nil,
		"reaction alerts, proc, overpower"),
	toggle("avisosSonido", L["Con sonido"], nil, "avisos", "alert sound"),
	toggle("avisosPorque", L["Explicar por qué"], L["Una línea debajo del aviso con lo que pasó."], "avisos", "explain why"),
	toggle("avisosOtros", L["También cuando el juego hace brillar otra habilidad"], L["Cualquier habilidad tuya que el juego resalte por un efecto."], "avisos", "spell glow, proc"),
	{ kind = "button", label = L["Explicaciones"], button = L["Volver a mostrarlas"], icon = "info",
		help = format(L["Cada aviso y cada porqué sale con texto hasta %d veces y luego solo queda el ícono."], M.LIMITE_TEXTO),
		onClick = function() M.ReiniciarTextos() end, search = "explanations, show again, tips" },
	(function()
		local c = toggle("golpe", L["Barra de golpe"], L["Cuánto falta para tu siguiente golpe automático, con cada mano. Ayuda a meter Embate o Golpe heroico sin perder golpes."], nil, "swing timer, auto attack")
		c.needs = noLanzador
		return c
	end)(),
	(function()
		local c = toggle("golpeNumero", L["Segundos junto a la barra"], L["El número que cuenta hacia atrás. Apagado, solo la barra."], "golpe", "swing timer seconds")
		c.needs = noLanzador
		return c
	end)(),
	toggle("panel", L["Panel de estadísticas"], L["Un cuadro pequeño y movible con tu vida y las estadísticas que más pesan para tu clase. En combate el juego oculta algunos números: se queda el último que se pudo leer."], nil,
		"stats panel, character stats"),
	toggle("corte", L["Aviso para cortar"], L["Cuando tu objetivo lanza algo que se puede cortar: tu habilidad para cortar, su tecla y si está lista."], nil,
		"interrupt, kick, counterspell, cast alert"),
	toggle("corteFoco", L["También tu foco"], nil, "corte", "focus interrupt"),
	toggle("corteSonido", L["Con sonido"], L["En grupo o en una instancia."], "corte", "interrupt sound"),
	toggle("corteSonidoSolo", L["También yendo solo"], L["Que suene también cuando vas solo por el mundo."], "corte", "interrupt sound solo"),
	toggle("corteSonidoOculto", L["Más suave si el juego oculta el hechizo"], L["En mazmorras y bandas el juego a veces no dice qué lanza el enemigo: suena más suave, y a veces también con lo que no se puede cortar."], "corte", "interrupt sound dungeon hidden"),
	toggle("amenaza", L["Barra de amenaza"], L["En grupo o con tu mascota: tu amenaza sobre tu objetivo. Te avisa antes de quitárselo al tanque, o si eres tanque, antes de perderlo."], nil,
		"threat, aggro, tank"),
	{ kind = "dropdown", key = clave("amenazaPapel"), label = L["Tu papel"], help = L["Automático: el que marcaste en tu grupo, o tu actitud o forma."],
		choices = (function() local o = {} for _, x in ipairs(Am.PAPELES) do o[#o + 1] = { value = x.clave, label = x.texto } end return o end)(),
		child = true, disabled = no(si("amenaza")), search = "role, tank, threat" },
	{ kind = "slider", key = clave("amenazaAviso"), label = L["Avisar desde"], help = L["Si no eres tanque: con cuánta amenaza se pone amarilla."],
		min = 60, max = 95, step = 5, format = porciento, child = true, disabled = no(si("amenaza")), search = "threat warning percent" },
	toggle("amenazaSonido", L["Con sonido"], nil, "amenaza", "threat sound"),
	toggle("resumen", L["Resumen al terminar cada pelea"], L["Una tarjeta al terminar: cuánto duró, tu daño y tu curación por segundo y lo que más te pegó. Apagado, tu última pelea se guarda igual y la ves aquí arriba o en el menú del medidor."], nil,
		"fight summary, combat recap, dps, hps, resumen de pelea, ventana de daño"),
	{ kind = "slider", key = clave("resumenMin"), label = L["Solo peleas de al menos"], min = 0, max = 30, step = 5,
		format = segundos, child = true, disabled = no(si("resumen")), search = "fight summary minimum" },
	{ kind = "slider", key = clave("resumenMinSolo"), label = L["Yendo solo, peleas de al menos"], min = 0, max = 60, step = 5,
		help = L["Cuando vas solo por el mundo, así no sale tras cada enemigo."],
		format = segundos, child = true, disabled = no(si("resumen")), search = "fight summary solo minimum" },
	toggle("caida", L["Al caer, lo que te tumbó"], L["Si mueres en una pelea, un aviso con el golpe final, lo que más te pegó y cuánto se podía evitar. Apagado, se guarda igual y lo ves aquí arriba."], nil,
		"death recap, what killed me, died, muerte, que me mato"),
	toggle("recargas", L["Recargas largas"], L["Tus habilidades que tardan en volver, en una barra discreta con lo que les falta."], nil,
		"cooldowns, long cooldown bar, timers"),
	{ kind = "dropdown", key = clave("recargasMin"), label = L["Desde cuántos segundos"], choices = numeros({ 30, 60, 120 }),
		child = true, disabled = no(si("recargas")), search = "cooldown minimum" },
	toggle("marcaMision", L["Marcar a quien te falta para una misión"], L["Un ícono de misión en la placa de nombre de los enemigos y personajes que todavía necesitas para una misión de tu registro. En mazmorras el juego oculta esos datos y no se marcan."], nil,
		"quest mobs, nameplate quest icon"),
	toggle("marcaMisionBrillo", L["Con un brillo suave"], L["Además del ícono, un brillo dorado que late alrededor de su barra."], "marcaMision", "quest glow"),
	{ kind = "dropdown", key = clave("medidorModo"), label = L["Cuándo sale la gráfica"],
		help = L["Automático: sola en grupo, en banda y en mazmorras; yendo solo, no. También con /alfa dps."],
		choices = function()
			local o = {}
			for _, x in ipairs(M.OpcionesModo()) do o[#o + 1] = { value = x.valor, label = x.texto } end
			return o
		end,
		get = function() return M.ModoMedidor() end,
		search = "damage meter, dps meter, recount, details, graph, bars" },
	{ kind = "slider", key = clave("filasBanda"), label = L["Filas en banda"], min = 5, max = 20, step = 1, format = entero,
		help = L["En grupo salen las 5 de tu grupo. Tu fila siempre se ve."],
		child = true, disabled = function() return M.ModoMedidor() == "apagado" end, search = "meter rows raid" },
	{ kind = "slider", key = clave("opacidad"), label = L["Opacidad de la ventana"], min = 0.3, max = 1, step = 0.05, format = pct,
		child = true, disabled = function() return M.ModoMedidor() == "apagado" end, search = "meter opacity, alpha" },
	{ kind = "slider", key = clave("filas"), label = L["Cuántos en el top"], min = 3, max = 10, step = 1, format = entero,
		help = L["En la ventana y aquí. Si no estás entre ellos, tu fila sale al final."], search = "meter rows, top" },
	{ kind = "dropdown", key = clave("anunciar"), label = L["Cuántos se anuncian"], choices = numeros({ 3, 5, 10 }),
		help = L["Anunciar escribe 3 líneas cortas en el chat de tu grupo o banda, solo cuando tú le das clic."], search = "announce, report to chat" },
	-- 1.3.7
	toggle("salDeAhi", L["«¡Sal de ahí!»"], L["En instancias, si pisas fuego, veneno o algo que deja el jefe en el suelo: un aviso rojo breve. Si el juego oculta esos datos, se apaga solo."], nil,
		"get out of fire, standing in bad, ground effect, avoid"),
	toggle("salDeAhiSonido", L["Con sonido"], nil, "salDeAhi", "get out sound"),
	toggle("cuenta", L["La cuenta para jalar en grande"], L["Cuando alguien lanza la cuenta del juego, un anuncio con quién la lanzó y cuánto falta."], nil,
		"pull timer, countdown"),
	toggle("jefes", L["Tiempos del jefe"], L["Alfa aprende pelea a pelea cada cuánto lanza el jefe sus ataques y te dice «Próximo Aliento en ~15 s». La primera vez no dice nada."], nil,
		"boss timers, dbm, bigwigs, next ability"),
	toggle("efectos", L["Tus efectos a la vista"], L["Tus venenos, maldiciones, escudos y curas que duran, con lo que les queda, en una fila chica."], nil,
		"dots, hots, buffs, debuffs, timers, auras"),
	toggle("efectosAviso", L["Avisar cuando uno se acaba"], nil, "efectos", "dot expired, aura fell off"),
}

N.Modulo({
	id = ID, nombre = L["Combate"], icono = M.ICONO, orden = 15, seccion = "personaje",
	-- 1.3.6: subtítulo corto (la ventana esconde los de más de 60 letras).
	subtitulo = L["Qué presionar, cuándo cortar y cómo te fue en cada pelea."],
	ajustes = M.AJUSTES,
	controles = CONTROLES,
	construir = construir,
})
