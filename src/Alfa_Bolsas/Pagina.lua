-- Alfa - Bolsas: la página "Bolsas" en la ventana de Alfa. GPL-3.0.
--
-- Hecha con el Kit (docs/KIT.md), plantilla Tablero:
--   1. cómo están tus bolsas y qué hacer ahora (abrirlas; si se llenan, qué
--      vender con su acción de un clic; si otro addon las tiene, por qué);
--   2. tu banco: verlo, y cuánto cuesta más espacio (comprar con un
--      banquero o que la flecha te lleve a uno); qué vender y conservar;
--   3. tus personajes, con sus bolsas, su banco y olvidarlos;
--   4. los ajustes, en grupos de filas.

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local D, V, R, S, Bc = M.Datos, M.Ventana, M.Reemplazo, M.Sugerencias, M.Banco
local K = N.Kit
local ESP = K.ESP

local type, pairs, ipairs, tonumber, format, floor, max = type, pairs, ipairs, tonumber, string.format, math.floor, math.max

local P = {}
M.Pagina = P

local DOT = "  \194\183  "

---------------------------------------------------------------------------
-- 1. Cómo están tus bolsas
---------------------------------------------------------------------------

local function progreso(est)
	if not (est.total and est.total > 0) then return nil end
	local usadas = est.total - est.libres
	return { actual = usadas, total = est.total, texto = format(L["%d de %d casillas ocupadas"], usadas, est.total) }
end

local function estado()
	local est = S.Estado()
	local d = { icono = "ic-bolsas", progreso = progreso(est) }
	local abrir = { texto = L["Abrir mis bolsas"], icono = "ic-bolsas", alClic = function() V.MostrarBolsas(true) end }
	if R.Conflicto() then
		d.titulo, d.tono = L["Otro addon de bolsas está activo"], "aviso"
		d.texto = L["Para no chocar con él, Alfa no reemplaza tus bolsas mientras esté activo. Igual puedes abrir la ventana de Alfa desde aquí."]
		d.estado = { texto = L["En pausa"], tono = "aviso" }
		d.accion = abrir
		return d
	end
	if R.Mando() then
		d.titulo, d.tono = L["Con mando, se quedan las bolsas del juego"], "neutro"
		d.texto = L["Con la interfaz para mando, Alfa deja las bolsas del juego. Igual puedes abrir la ventana de Alfa desde aquí."]
		d.estado = { texto = L["En pausa"], tono = "neutro" }
		d.accion = abrir
		return d
	end
	if not M.Get("reemplazar") then
		d.titulo, d.tono = L["Usas las bolsas del juego"], "neutro"
		d.texto = L["Con las de Alfa ves todo en una ventana: tres vistas, búsqueda, la barra de tus bolsas y qué vender cuando se llenan."]
		d.estado = { texto = L["Apagadas"], tono = "neutro" }
		d.accion = { texto = L["Usar las bolsas de Alfa"], icono = "ic-seguir", alClic = function() M.Set("reemplazar", true) end }
		d.secundaria = { texto = L["Probar la ventana"], alClic = function() V.MostrarBolsas(true) end }
		return d
	end
	if est.lleno then
		d.titulo, d.tono = L["Tus bolsas se están llenando"], "aviso"
		local texto = S.TextoAviso(est)
		if #est.conservar > 0 then
			texto = texto .. " " .. format(L["Conserva %s: vale más de otra forma."], S.Nombres(est.conservar, 2))
		end
		d.texto = texto
		d.estado = { texto = est.libres == 1 and L["Queda 1"] or format(L["Quedan %d"], est.libres), tono = "aviso" }
		local chatarra = S.ComercianteAbierto() and #S.ChatarraAhora() or 0
		if chatarra > 0 then
			d.accion = { texto = format(L["Vender la chatarra (%d)"], chatarra), icono = "ic-oro", alClic = S.VenderChatarra }
		elseif est.sinMarcar > 0 then
			d.accion = { texto = format(L["Marcar como chatarra (%d)"], est.sinMarcar), icono = "ic-exito", alClic = S.MarcarChatarra }
			d.secundaria = { texto = L["Llévame al comerciante"], alClic = S.LlevarComerciante }
		elseif #est.vender > 0 then
			d.accion = { texto = L["Llévame al comerciante"], icono = "ic-flecha", alClic = S.LlevarComerciante }
			d.secundaria = { texto = L["Abrir mis bolsas"], alClic = abrir.alClic }
		else
			d.accion = { texto = L["Llévame al banco"], icono = "ic-flecha", alClic = S.LlevarBanco }
			d.secundaria = { texto = L["Abrir mis bolsas"], alClic = abrir.alClic }
		end
		return d
	end
	d.tono = "exito"
	d.titulo = est.total > 0 and format(L["Tienes %d casillas libres"], est.libres) or L["Tus bolsas"]
	d.texto = L["Se abren con la B. Elige la vista (todo junto, por categorías o por bolsa), busca por nombre o nivel y arrastra tus bolsas en su barra para cambiarlas."]
	d.estado = { texto = L["Listas"], tono = "exito" }
	d.accion = abrir
	d.secundaria = { texto = L["Ver mi banco"], alClic = function() V.MostrarBanco(nil) end }
	return d
end

---------------------------------------------------------------------------
-- 2. El banco y qué vender
---------------------------------------------------------------------------

local function tarjetaBanco()
	local r = D.Actual()
	local d = { icono = "ic-bolsas", titulo = L["Tu banco"] }
	if D.BancoAbierto() then
		d.texto = L["Estás con un banquero: desde su ventana depositas lo que quieras con un clic."]
		d.insignias = { { L["En vivo"], "exito" } }
		d.accion = { texto = L["Ver mi banco"], alClic = function() V.MostrarBanco(nil) end }
	elseif r and r.bancoVisto then
		local objetos, ocupadas = D.Resumen(r.banco)
		d.texto = format(L["%d objetos en %d casillas. Lo ves desde cualquier lugar con la última foto."], objetos, ocupadas)
		d.insignias = { { format(L["Foto: %s"], M.Hace(r.bancoVisto)), "neutro", "ic-reloj" } }
		d.accion = { texto = L["Ver mi banco"], alClic = function() V.MostrarBanco(nil) end }
	else
		d.texto = L["Visita a un banquero una vez y Alfa guardará una foto para verlo desde cualquier lugar."]
		d.accion = { texto = L["Llévame al banco"], icono = "ic-flecha", alClic = S.LlevarBanco }
	end
	return d
end

local function tarjetaEspacio()
	local c = Bc.Estado()
	local d = { icono = "ic-oro", titulo = L["Más espacio en el banco"] }
	if not c then
		d.texto = L["Visita a un banquero y Alfa te dirá cuánto cuesta la siguiente casilla de bolsa del banco."]
		-- Si la tarjeta del banco (al lado) ya lleva al banco, aquí no se repite el botón.
		local r = D.Actual()
		if D.BancoAbierto() or (r and r.bancoVisto) then
			d.accion = { texto = L["Llévame al banco"], icono = "ic-flecha", alClic = S.LlevarBanco }
		end
		return d
	end
	if c.completo then
		d.titulo = L["Tu banco está completo"]
		d.texto = format(L["Ya tienes las %d casillas de bolsa del banco. Para más espacio, pon bolsas más grandes en ellas."], c.maximo)
		d.insignias = { { format(L["%d de %d"], c.compradas, c.maximo), "exito" } }
		return d
	end
	local costo = c.costo and N.Dinero(c.costo, true) or "?"
	d.texto = format(L["Tienes %d de %d casillas de bolsa. La siguiente cuesta %s; después pon una bolsa en ella."], c.compradas, c.maximo, costo)
	d.insignias = { { format(L["%d de %d"], c.compradas, c.maximo), "neutro" } }
	if c.vivo then
		if c.alcanza == false then d.insignias[#d.insignias + 1] = { L["No te alcanza"], "aviso" } end
		d.accion = { texto = L["Comprar"], icono = "ic-oro", alClic = Bc.Comprar }
	else
		if c.fecha then d.insignias[#d.insignias + 1] = { format(L["Precio de %s"], M.Hace(c.fecha)), "neutro", "ic-reloj" } end
		d.accion = { texto = L["Llévame al banco"], icono = "ic-flecha", alClic = S.LlevarBanco }
	end
	return d
end

local function tarjetaVender()
	local est = S.Estado()
	local d = { icono = "ic-comercio", titulo = L["Qué vender y qué conservar"] }
	if #est.vender == 0 and #est.conservar == 0 then
		d.texto = L["Nada que vender por ahora: lo que llevas sirve o vale más guardado."]
	else
		local partes = {}
		if #est.vender > 0 then
			partes[#partes + 1] = format(L["Puedes vender %d cosas por unos %s."], #est.vender, N.Dinero(est.valorVenta, true))
		end
		if #est.conservar > 0 then
			partes[#partes + 1] = format(L["%d valen más en la subasta o transformadas."], #est.conservar)
		end
		d.texto = table.concat(partes, " ")
	end
	if S.Comercio() then
		d.accion = { texto = L["Ver en Comercio"], alClic = function() N.Abrir("comercio") end }
	end
	return d
end

-- 1.2.8: el oro de esta sesión (Sesion.lua).
local function tarjetaSesion()
	local s = M.Sesion.Datos()
	local d = { icono = "ic-oro", titulo = L["Esta sesión"] }
	if s.ganado <= 0 then
		d.texto = L["Aún no ganas oro en esta sesión. Alfa cuenta lo que ganas desde que entraste al juego."]
	elseif s.porHora > 0 then
		d.texto = format(L["Ganaste %s en %s: unos %s por hora."], N.Dinero(s.ganado, true), N.Duracion(s.segundos), N.Dinero(s.porHora, true))
	else
		d.texto = format(L["Ganaste %s. En un minuto te digo cuánto ganas por hora."], N.Dinero(s.ganado, true))
	end
	if s.gastado > 0 then
		local neto = s.oro >= 0 and ("+" .. N.Dinero(s.oro, true)) or N.Dinero(s.oro, true)
		d.texto = d.texto .. " " .. format(L["Con lo que gastaste: %s."], neto)
	end
	return d
end

local function opciones()
	return { tarjetaBanco(), tarjetaEspacio(), tarjetaVender(), tarjetaSesion() }
end

---------------------------------------------------------------------------
-- 1.2.9: qué guardar (Guardar.lua)
---------------------------------------------------------------------------

local MAX_GUARDAR = 12

local function iconoDe(id)
	local CI = C_Item
	if CI and CI.GetItemIconByID then
		local t = M.Llamar(CI.GetItemIconByID, id)
		if t then return t end
	end
	return nil
end

local function nombreDe(x)
	if x.link then return x.link end
	local CI = C_Item
	local n = CI and CI.GetItemNameByID and M.Texto(M.Llamar(CI.GetItemNameByID, x.id))
	return n or ("#" .. tostring(x.id))
end

local function bloqueGuardar(padre)
	local b = K.Pila(padre, { espacio = ESP.m })
	b.Seccion = b:Agregar(K.Seccion(b, L["Qué guardar"]))
	local nota = CreateFrame("Frame", nil, b)
	nota.Texto = K.Texto(nota, "nota", "textoSuave")
	nota.Texto:SetPoint("TOPLEFT")
	function nota:Acomodar(ancho) local h = K.Parrafo(self.Texto, ancho, 3) self:SetSize(ancho, h) return h end
	b.Nota = b:Agregar(nota)
	b.Rejilla = b:Agregar(K.Rejilla(b, { min = 300, gap = ESP.s, variante = "compacta" }), { espacio = ESP.s })
	function b:Llenar()
		local Gu = M.Guardar
		local lista = M.Get("queGuardar") ~= false and Gu.Sugerencias() or {}
		local abierto = D.BancoAbierto()
		local enlace
		if #lista > 0 then
			if abierto then
				enlace = { texto = format(L["Al banco (%d)"], #lista), alClic = function() Gu.AlBanco() P.Rehacer() end }
			else
				enlace = { texto = L["Llévame al banco"], alClic = S.LlevarBanco }
			end
		end
		self.Seccion:Set(L["Qué guardar"], { cuenta = #lista > 0 and #lista or nil, enlace = enlace })
		K.Escribir(self.Nota.Texto, abierto and L["Estás con un banquero: «Al banco» los deposita con un clic, o toca uno para guardar solo ese."]
			or L["Esto te sirve más en el banco o con otro de tus personajes (mándaselo por correo). Con un banquero, se guarda con un clic."])
		local tarjetas = {}
		for i = 1, math.min(#lista, MAX_GUARDAR) do
			local x = lista[i]
			local icono = iconoDe(x.id)
			tarjetas[i] = {
				icono = icono or "ic-bolsas", tenir = icono and false or nil,
				titulo = nombreDe(x), texto = x.motivo,
				valor = x.cantidad > 1 and format(L["×%d"], x.cantidad) or nil,
				alClic = abierto and function() Gu.AlBanco({ x }) P.Rehacer() end or nil,
				ayuda = abierto and L["Clic: guardar este en el banco."] or nil,
			}
		end
		self.Rejilla:Llenar(tarjetas)
		K.Mostrar(self, #lista > 0)
	end
	return b
end

---------------------------------------------------------------------------
-- 3. Tus personajes
---------------------------------------------------------------------------

local function textoPersonaje(p, actual)
	local r = p.r
	local partes = {}
	if tonumber(r.nivel) then partes[#partes + 1] = (L["Nivel %d"]):format(r.nivel) end
	if type(r.reino) == "string" then partes[#partes + 1] = r.reino end
	local dinero = (p.clave == actual and M.Num(GetMoney and GetMoney())) or tonumber(r.dinero) or 0
	partes[#partes + 1] = N.Dinero(dinero, true)
	if p.clave ~= actual then partes[#partes + 1] = (L["visto %s"]):format(M.Hace(r.visto)) end
	local objetos, ocupadas, total = D.Resumen(r.bolsas)
	local linea2 = (L["Bolsas: %d objetos en %d de %d casillas"]):format(objetos, ocupadas, total)
	if r.bancoVisto then
		local bo, bocc = D.Resumen(r.banco)
		linea2 = linea2 .. DOT .. (L["Banco: %d objetos en %d casillas (foto: %s)"]):format(bo, bocc, M.Hace(r.bancoVisto))
	else
		linea2 = linea2 .. DOT .. L["Banco: sin foto todavía"]
	end
	return table.concat(partes, DOT) .. "\n" .. linea2
end

local function controlPersonaje(fila)
	local c = CreateFrame("Frame", nil, fila)
	c.Bolsas = K.Boton(c, L["Bolsas"], function() V.Ver(V.Ventana("bolsas"), fila.clave) end, { tipo = "secundario", tam = "chico" })
	c.Banco = K.Boton(c, L["Banco"], function() V.MostrarBanco(fila.clave) end, { tipo = "secundario", tam = "chico" })
	c.Olvidar = K.Boton(c, L["Olvidar"], function()
		local k = fila.clave
		local r = D.Personaje(k)
		if not r then return end
		K.Dialogo({
			titulo = L["¿Olvidar a este personaje?"],
			texto = (L["Alfa borrará lo que guardó de %s: sus bolsas, su banco y su equipo. Si vuelves a jugar con él, se guarda de nuevo."]):format(tostring(r.nombre or k)),
			aceptar = L["Olvidar"], peligro = true,
			alAceptar = function()
				D.Olvidar(k)
				P.Rehacer()
			end,
		})
	end, { tipo = "peligro", tam = "chico" })
	function c:SetActivo(on) self:SetAlpha(on == false and 0.45 or 1) end
	function c:Poner(propio)
		self.Olvidar:SetShown(not propio)
		local x = 0
		for _, b in ipairs({ self.Olvidar, self.Banco, self.Bolsas }) do
			if b:IsShown() then
				b:ClearAllPoints()
				b:SetPoint("RIGHT", self, "RIGHT", -x, 0)
				x = x + b:AnchoNatural() + ESP.s
			end
		end
		self:SetSize(max(1, x - ESP.s), K.ALTO.botonChico)
	end
	c:Poner(false)
	return c
end

local function bloquePersonajes(padre)
	local b = CreateFrame("Frame", nil, padre)
	b.Seccion = K.Seccion(b, L["Tus personajes"])
	b.Panel = CreateFrame("Frame", nil, b)
	b.Panel.caja = K.Caja(b.Panel, { fondo = "panel", borde = "linea", corte = K.CORTE.panel })
	b.filas, b.lineas = {}, {}
	b.Cuenta = K.FilaAjuste(b.Panel, {
		titulo = L["Dinero de toda la cuenta"], texto = L["La suma de lo que guardó Alfa de cada personaje (el tuyo, al día)."],
		control = function(fila)
			local c = CreateFrame("Frame", nil, fila)
			c.Texto = K.Texto(c, "numero", "texto")
			c.Texto:SetPoint("RIGHT", c, "RIGHT", 0, 0)
			c:SetSize(120, K.ALTO.botonChico)
			function c:SetActivo() end
			fila.Valor = c
			return c
		end,
	})
	b.Vacio = K.Vacio(b, { lobo = "dormido", titulo = L["Aún no hay personajes guardados"], texto = L["Juega con cada personaje una vez y Alfa recordará sus bolsas y su banco."] })
	function b:Llenar()
		local lista = D.Lista()
		self.lista = lista
		self.Seccion:Set(L["Tus personajes"], { cuenta = #lista > 0 and #lista or nil })
		K.Escribir(self.Cuenta.Valor.Texto, N.Dinero(D.DineroCuenta(), true))
		self.Cuenta.Valor:SetWidth(K.AnchoTexto(self.Cuenta.Valor.Texto) + 2)
		local actual = D.Clave()
		for i, p in ipairs(lista) do
			local f = self.filas[i]
			if not f then
				f = K.FilaAjuste(self.Panel, { titulo = "", texto = "", control = controlPersonaje })
				self.filas[i] = f
			end
			f.clave = p.clave
			local cr, cg, cb = M.ColorClase(p.r.clase)
			local nombre = M.Pintado(p.r.nombre or p.clave, cr, cg, cb)
			if p.clave == actual then nombre = nombre .. "  " .. K.Tenir("textoTenue", L["(tú)"]) end
			f.alfaDatos.titulo, f.alfaDatos.texto = nombre, textoPersonaje(p, actual)
			f.Control:Poner(p.clave == actual)
			f:Refrescar()
			f:Show()
		end
		for i = #lista + 1, #self.filas do self.filas[i]:Hide() end
		self.Cuenta:SetShown(#lista > 1)
		K.Mostrar(self.Vacio, #lista == 0)
	end
	function b:Acomodar(ancho)
		self.Seccion:ClearAllPoints()
		self.Seccion:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
		self.Seccion:SetWidth(ancho)
		local y = self.Seccion:Acomodar(ancho) + ESP.s
		local filas = {}
		if self.Cuenta:IsShown() then filas[#filas + 1] = self.Cuenta end
		for i = 1, #(self.lista or {}) do filas[#filas + 1] = self.filas[i] end
		if #filas == 0 then
			self.Panel:Hide()
			local vh = self.Vacio:Acomodar(ancho)
			self.Vacio:ClearAllPoints()
			self.Vacio:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -(y + ESP.base))
			y = y + ESP.base + vh
			self:SetSize(ancho, y)
			return y
		end
		self.Panel:Show()
		local py = 0
		for i, f in ipairs(filas) do
			if i > 1 then
				local ln = self.lineas[i - 1] or K.Linea(self.Panel, "linea")
				self.lineas[i - 1] = ln
				ln:ClearAllPoints()
				ln:SetPoint("TOPLEFT", self.Panel, "TOPLEFT", ESP.base, -py)
				ln:SetPoint("TOPRIGHT", self.Panel, "TOPRIGHT", -ESP.base, -py)
				ln:Show()
			end
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", self.Panel, "TOPLEFT", 0, -py)
			py = py + f:Acomodar(ancho)
		end
		for i = #filas, #self.lineas do self.lineas[i]:Hide() end
		self.Panel:ClearAllPoints()
		self.Panel:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
		self.Panel:SetSize(ancho, max(1, py))
		y = y + py
		self:SetSize(ancho, y)
		return y
	end
	return b
end

---------------------------------------------------------------------------
-- 4. Los ajustes
---------------------------------------------------------------------------

local function ruta(clave) return M.ID .. "." .. clave end

local function interruptor(clave)
	return function(fila) return K.Interruptor(fila, { clave = ruta(clave) }) end
end

local function deslizador(clave, a, b, formato)
	return function(fila)
		local d = K.Deslizador(fila, { min = a, max = b, paso = 1, clave = ruta(clave), formato = formato })
		d.alfaAnchoFila = 220
		return d
	end
end

local function siempre(clave) return function() return M.Get(clave) and true or false end end

local function grupos(padre)
	local ventana = K.GrupoAjustes(padre, { titulo = L["La ventana"] })
	ventana:Fila({ titulo = L["Vista"], texto = L["Todo junto muestra cada casilla en su lugar; por categorías agrupa equipo, consumibles, misiones y materiales; por bolsa pone cada bolsa en su bloque."],
		control = function(fila)
			local seg = K.Segmentos(fila, { estilo = "segmentos", valor = M.Vista(), opciones = {
				{ valor = "una", texto = L["Todo junto"] },
				{ valor = "categorias", texto = L["Categorías"] },
				{ valor = "bolsa", texto = L["Por bolsa"] },
			}, alCambiar = function(v) M.Set("vista", v) end })
			function seg:Leer() self:SetValor(M.Vista()) end
			function seg:SetActivo(on) self:SetAlpha(on == false and 0.45 or 1) end
			return seg
		end })
	ventana:Fila({ titulo = L["Tamaño de las casillas"], texto = L["Qué tan grande se ve cada casilla."],
		control = deslizador("tamIcono", 28, 48, function(v) return floor(v + 0.5) .. " px" end) })
	ventana:Fila({ titulo = L["Columnas"], texto = L["Cuántas casillas caben en cada fila."],
		control = deslizador("columnas", 6, 20, function(v) return tostring(floor(v + 0.5)) end) })
	ventana:Fila({ titulo = L["Barra de tus bolsas"], control = interruptor("barra"),
		texto = L["Arriba de la ventana, cada bolsa equipada con su espacio: pasa el ratón para resaltar lo que lleva y arrastra otra bolsa para cambiarla."] })
	ventana:Fila({ titulo = L["Mostrar el llavero"], control = interruptor("llavero"), texto = L["Tus llaves junto a tus bolsas."] })

	local juego = K.GrupoAjustes(padre, { titulo = L["En lugar de las del juego"] })
	juego:Fila({ titulo = L["Usar las bolsas de Alfa"], control = interruptor("reemplazar"),
		texto = L["La B, Mayús+B, la tecla de cada bolsa y los comerciantes abren la ventana de Alfa. Apágalo para volver a las del juego."] })
	juego:Fila({ titulo = L["Usar el banco de Alfa"], control = interruptor("banco"), hija = true, activa = siempre("reemplazar"),
		texto = L["Al hablar con un banquero se abre el banco de Alfa, con depositar rápido. La primera visita de cada personaje muestra el del juego: así recibe su primera pestaña."] })

	local ordenar = K.GrupoAjustes(padre, { titulo = L["Ordenar"] })
	ordenar:Fila({ titulo = L["Botón Ordenar"], control = interruptor("ordenar"), texto = L["Junta los montones y acomoda tus objetos con un clic."] })
	ordenar:Fila({ titulo = L["Ordenar de derecha a izquierda"], control = interruptor("ordenarInverso"), hija = true, activa = siempre("ordenar"),
		texto = L["Los objetos se juntan al final de tus bolsas en lugar de al principio."] })

	local lleno = K.GrupoAjustes(padre, { titulo = L["Cuando se llenan"] })
	lleno:Fila({ titulo = L["Sugerir qué vender"], control = interruptor("avisoLleno"),
		texto = L["Un aviso y una franja en tus bolsas con qué vender, qué conservar y a qué comerciante ir, con un clic para marcar la chatarra."] })
	-- El valor va solo ("4"): el título ya dice qué cuenta y cabe en su caja.
	lleno:Fila({ titulo = L["Avisar cuando queden"], control = deslizador("avisoLibres", 1, 10, function(v)
		return tostring(floor(v + 0.5))
	end), hija = true, activa = siempre("avisoLleno"), texto = L["Cuántas casillas libres quedan cuando Alfa te avisa."] })
	lleno:Fila({ titulo = L["Avisar cuando estén casi llenas"], control = interruptor("avisoCasiLleno"),
		texto = L["Con 2 casillas libres o menos, un aviso con lo primero que puedes soltar y un botón para vender o ver tus bolsas."] })

	-- 1.2.9
	local equipo = K.GrupoAjustes(padre, { titulo = L["Equipo y banco"] })
	equipo:Fila({ titulo = L["«Ponte esto» con el equipo mejor"], control = interruptor("ponteEsto"),
		texto = L["Cuando te llega equipo mejor que lo que llevas puesto, un aviso con un botón para ponértelo (solo con tu clic y fuera de combate)."] })
	equipo:Fila({ titulo = L["Sugerir qué guardar"], control = interruptor("queGuardar"),
		texto = L["En esta página, lo que te sirve más en el banco o con otro personaje: materiales de sus recetas, lo que piden sus misiones y equipo que tu clase no usa."] })

	local marcas = K.GrupoAjustes(padre, { titulo = L["Marcas sobre cada objeto"] })
	marcas:Fila({ titulo = L["Nivel de objeto"], control = interruptor("marcaNivel"), texto = L["El número abajo a la izquierda de cada pieza de equipo."] })
	marcas:Fila({ titulo = L["Borde de calidad"], control = interruptor("marcaCalidad"), texto = L["Un borde del color de la calidad: verde, azul, morado..."] })
	marcas:Fila({ titulo = L["Chatarra"], control = interruptor("marcaChatarra"), texto = L["Una moneda sobre lo gris y lo que marcaste como chatarra."] })
	marcas:Fila({ titulo = L["Objetos nuevos"], control = interruptor("marcaNuevos"), texto = L["Brillan los objetos que acabas de conseguir, hasta que cierras las bolsas."] })
	marcas:Fila({ titulo = L["Flecha de mejora"], control = interruptor("marcaMejora"), texto = L["Una flecha verde en el equipo que es mejor que lo que llevas puesto, según tu clase y nivel."] })
	-- Un solo selector para los dos ajustes (brilloMision manda sobre marcaMision,
	-- Botones.lua); lee lo que ya tienes y solo cambia lo que eliges.
	marcas:Fila({ titulo = L["Objetos de misión"],
		texto = L["Brillo: un borde dorado que late y una insignia «!» (llena si el objeto empieza una misión). Marco fijo: el marco dorado del juego. Nada: sin marca."],
		control = function(fila)
			local function actual()
				if M.Get("brilloMision") then return "brillo" end
				return M.Get("marcaMision") and "marco" or "nada"
			end
			local seg = K.Segmentos(fila, { estilo = "segmentos", valor = actual(), opciones = {
				{ valor = "brillo", texto = L["Brillo"] },
				{ valor = "marco", texto = L["Marco fijo"] },
				{ valor = "nada", texto = L["Nada"] },
			}, alCambiar = function(v)
				if v == "brillo" then
					M.Set("brilloMision", true)
				else
					M.Set("brilloMision", false)
					M.Set("marcaMision", v == "marco")
				end
			end })
			function seg:Leer() self:SetValor(actual()) end
			function seg:SetActivo(on) self:SetAlpha(on == false and 0.45 or 1) end
			return seg
		end })
	marcas:Fila({ titulo = L["Cuántos tienes, en el cuadro de cada objeto"], control = interruptor("cuadroConteo"),
		texto = L["Al pasar el ratón por un objeto: «Tienes 12 (Lobato: 7 en bolsas, Alt: 5 en banco)», con todos tus personajes."] })
	return { ventana, juego, ordenar, lleno, equipo, marcas }
end

---------------------------------------------------------------------------
-- La página
---------------------------------------------------------------------------

function M.ConstruirPagina(view)
	local ui = {}
	local t = K.Tablero(view, { margen = N.MargenPagina(), accion = "estado", tituloOpciones = L["Tu banco y lo que llevas"], min = 240 })
	ui.guardar = t:AgregarBloque(bloqueGuardar(t.Extra))
	ui.personajes = t:AgregarBloque(bloquePersonajes(t.Extra))
	ui.ajustes = grupos(t.Extra)
	for i, g in ipairs(ui.ajustes) do t:AgregarBloque(g, { espacio = i == 1 and ESP.xl or ESP.l }) end
	K.EnPagina(view, t, function()
		t:SetAccion(estado())
		t:SetOpciones(opciones(), L["Tu banco y lo que llevas"])
		ui.guardar:Llenar()
		ui.personajes:Llenar()
		for _, g in ipairs(ui.ajustes) do g:Refrescar() end
	end)
	P.view = view
end

-- La página otra vez, si está a la vista (datos nuevos, un ajuste...).
local pendiente = false
function P.Rehacer()
	if pendiente then return end
	pendiente = true
	M.Luego(0.3, function()
		pendiente = false
		if P.view then N.RehacerPagina(P.view) end
	end)
end

M.Escuchar("DATOS", P.Rehacer)
M.Escuchar("COMPRA", P.Rehacer)
M.Escuchar("SUGERENCIAS", P.Rehacer)
M.Escuchar("SESION", P.Rehacer)
M.Escuchar("LOTE", function(nombre) if nombre == "depositar" and not M.Lotes.Activo("depositar") then P.Rehacer() end end)
A.RegisterEvent("BANKFRAME_OPENED", P.Rehacer)
A.RegisterEvent("BANKFRAME_CLOSED", P.Rehacer)
A.On("SETTING_CHANGED", function(r)
	if type(r) == "string" and (r == "" or r == M.ID or r:sub(1, #M.ID + 1) == M.ID .. ".") then P.Rehacer() end
end)
