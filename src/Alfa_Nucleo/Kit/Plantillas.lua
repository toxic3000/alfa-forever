-- Alfa - Kit: plantillas de página (Toxic / La Jauría). GPL-3.0.
--
-- Tres acomodos fijos para que toda página se vea ordenada, alineada y sin
-- espacio perdido. Todas miden y se acomodan al ancho que se les da: el de la
-- ventana principal (AlfaNucleo.AnchoPagina(), con AlfaNucleo.MargenPagina()
-- a los lados) o el de una ventana propia (v:AnchoCuerpo(), con v.margen).
--
--   K.Tablero(padre, opts)      la acción recomendada en grande y debajo una rejilla
--   K.ListaFicha(padre, opts)   filtros arriba, la lista a la izquierda y la ficha a la derecha
--   K.Asistente(padre, opts)    pasos con huellas, el paso de ahora y Atrás / Siguiente
--   K.EnPagina(view, plantilla) la conecta con una página de la ventana principal

local _, N = ...
local K = N.Kit
local A = N.A
local L = K.L

local floor, max, min, type, ipairs = math.floor, math.max, math.min, type, ipairs
local ESP = K.ESP

---------------------------------------------------------------------------
-- Tablero
--   opts = { margen = 32, arriba = 16, abajo = 24, encabezado = { icono, titulo, subtitulo },
--            accion = "accion" | "estado" (la variante de la tarjeta de arriba),
--            tituloOpciones = "Otras opciones", min = 256 (ancho de tarjeta), variante = "normal" }
--   t:SetAccion(datos | nil)          la tarjeta grande (K.Tarjeta "accion" o "estado")
--   t:SetOpciones(lista, titulo)      las alternativas, en rejilla
--   t:AgregarBloque(bloque, opts)     más secciones debajo (ajustes, listas...)
--   t:Acomodar(ancho) -> alto total (con sus márgenes de arriba y abajo)
---------------------------------------------------------------------------
function K.Tablero(padre, opts)
	opts = opts or {}
	local t = K.Pila(padre, { espacio = ESP.l })
	t.alfaPadre = padre
	t.alfaMargen, t.alfaArriba, t.alfaAbajo = opts.margen or 0, opts.arriba or ESP.base, opts.abajo or ESP.l
	if opts.encabezado then t.Encabezado = t:Agregar(K.Encabezado(t, opts.encabezado)) end
	t.Accion = t:Agregar(K.Tarjeta(t, { variante = opts.accion or "accion" }))
	t.Opciones = t:Agregar(K.Seccion(t, opts.tituloOpciones or L["Otras opciones"]))
	t.Rejilla = t:Agregar(K.Rejilla(t, { min = opts.min, variante = opts.variante }), { espacio = ESP.m })
	t.Extra = t:Agregar(K.Pila(t, { espacio = ESP.l }))
	K.Mostrar(t.Accion, false)
	K.Mostrar(t.Opciones, false)
	K.Mostrar(t.Rejilla, false)

	function t:SetAccion(d)
		if d then self.Accion:Set(d) end
		K.Mostrar(self.Accion, d ~= nil)
	end
	function t:SetOpciones(lista, titulo, o)
		lista = lista or {}
		self.Rejilla:Llenar(lista)
		if titulo then self.Opciones:Set(titulo, o) end
		K.Mostrar(self.Opciones, #lista > 0 and titulo ~= false)
		K.Mostrar(self.Rejilla, #lista > 0)
	end
	function t:AgregarBloque(b, o) return self.Extra:Agregar(b, o) end
	local acomodarPila = t.Acomodar
	function t:Acomodar(ancho)
		self:ClearAllPoints()
		self:SetPoint("TOPLEFT", self.alfaPadre, "TOPLEFT", self.alfaMargen, -self.alfaArriba)
		local h = acomodarPila(self, ancho)
		return self.alfaArriba + h + self.alfaAbajo
	end
	return t
end

---------------------------------------------------------------------------
-- Lista con filtros y ficha
--   opts = { margen, arriba = 16, abajo = 16, anchoFicha = 340,
--            buscador = { ayuda, alCambiar }, segmentos = { opciones, valor, alCambiar },
--            alto = 36 (de fila), crear = fn(fila), pintar = fn(fila, dato, i, elegida),
--            ficha = fn(pila, dato, plantilla)  (llena la ficha: crea sus bloques la
--                    primera vez en la pila y los actualiza después),
--            vacio = { lobo, titulo, texto }       (sin resultados),
--            vacioFicha = { lobo, titulo, texto }  (nada elegido),
--            elegirPrimero = true, cuenta = fn(n) -> "12 resultados" }
--   t:SetDatos(lista, conservar) ; t:Elegir(i) ; t:Elegido() -> dato
--   t:RehacerFicha() ; t:Acomodar(ancho, alto) -> alto
---------------------------------------------------------------------------
function K.ListaFicha(padre, opts)
	opts = opts or {}
	local t = CreateFrame("Frame", nil, padre)
	t.alfaPadre = padre
	t.alfaMargen, t.alfaArriba, t.alfaAbajo = opts.margen or 0, opts.arriba or ESP.base, opts.abajo or ESP.base
	t.alfaAnchoFicha = opts.anchoFicha or K.ANCHO.ficha
	t.alfaOpts = opts
	t.Barra = CreateFrame("Frame", nil, t)
	if opts.buscador then t.Buscador = K.Buscador(t.Barra, opts.buscador) end
	if opts.segmentos then t.Segmentos = K.Segmentos(t.Barra, opts.segmentos) end
	t.Cuenta = K.Texto(t, "pequeno", "textoTenue")

	t.MarcoLista = CreateFrame("Frame", nil, t)
	t.MarcoLista.caja = K.Caja(t.MarcoLista, { fondo = "panel", borde = "linea", corte = K.CORTE.panel })
	t.Lista = K.Lista(t.MarcoLista, {
		alto = opts.alto, crear = opts.crear, pintar = opts.pintar, alClic = opts.alClic,
		vacio = opts.vacio or { lobo = "vacio", titulo = L["Nada por aquí"], texto = L["Prueba con otra búsqueda o quita un filtro."] },
	})
	t.Lista.alElegir = function(dato) t:MostrarFicha(dato) end

	t.Ficha = CreateFrame("Frame", nil, t)
	t.Ficha.caja = K.Caja(t.Ficha, { fondo = "panel", borde = "linea", corte = K.CORTE.panel })
	t.FichaDesp = K.Desplazable(t.Ficha)
	t.FichaDesp:SetPoint("TOPLEFT", t.Ficha, "TOPLEFT", ESP.base, -ESP.base)
	t.FichaPila = K.Pila(t.FichaDesp.Contenido, { espacio = ESP.base })
	t.FichaPila:SetPoint("TOPLEFT", t.FichaDesp.Contenido, "TOPLEFT", 0, 0)
	t.FichaVacia = K.Vacio(t.Ficha, opts.vacioFicha or { lobo = "atento", titulo = L["Elige algo de la lista"], texto = L["Aquí ves todo lo que hay que saber, con qué hacer después."] })

	function t:SetDatos(lista, conservar)
		lista = lista or {}
		self.Lista:SetDatos(lista, conservar)
		local n = #lista
		K.Escribir(self.Cuenta, opts.cuenta and opts.cuenta(n) or (n == 1 and L["1 resultado"] or (L["%d resultados"]):format(n)))
		if not conservar then
			if opts.elegirPrimero ~= false and n > 0 then self.Lista:Elegir(1) else self:MostrarFicha(nil) end
		end
	end
	function t:Elegir(i) self.Lista:Elegir(i) end
	function t:Elegido() local _, d = self.Lista:Elegida() return d end
	function t:MostrarFicha(dato)
		self.alfaFicha = dato
		local hay = dato ~= nil
		self.FichaDesp:SetShown(hay)
		self.FichaVacia:SetShown(not hay)
		if hay and opts.ficha then K.Llamar(opts.ficha, self.FichaPila, dato, self) end
		self:RehacerFicha()
		self.FichaDesp:IrArriba()
	end
	function t:RehacerFicha()
		local w = K.num(self.Ficha:GetWidth(), self.alfaAnchoFicha)
		local h = K.num(self.Ficha:GetHeight(), 200)
		self.FichaDesp:Acomodar(w - ESP.base - 4, h - 2 * ESP.base)
		if self.FichaDesp:IsShown() then
			local alto = self.FichaPila:Acomodar(self.FichaDesp:AnchoUtil() - ESP.base + 4)
			self.FichaDesp:SetAltoContenido(alto)
		else
			local vh = self.FichaVacia:Acomodar(w - 2 * ESP.l)
			self.FichaVacia:ClearAllPoints()
			self.FichaVacia:SetPoint("TOP", self.Ficha, "TOP", 0, -max(ESP.l, floor((h - vh) / 2.4)))
		end
	end
	function t:Acomodar(ancho, alto)
		alto = alto or K.num(self:GetHeight(), 400)
		self:ClearAllPoints()
		self:SetPoint("TOPLEFT", self.alfaPadre, "TOPLEFT", self.alfaMargen, -self.alfaArriba)
		local disponible = alto - self.alfaArriba - self.alfaAbajo
		self:SetSize(ancho, disponible)
		-- La barra de filtros: el buscador ocupa lo que dejan los segmentos.
		local by, bh = 0, K.ALTO.control
		local segW = 0
		if self.Segmentos then
			local sh, sw = self.Segmentos:Acomodar(ancho)
			segW = sw
			if ancho - sw < 260 then
				-- Angosto: los segmentos bajan a su propia fila.
				self.Segmentos:ClearAllPoints()
				self.Segmentos:SetPoint("TOPLEFT", self.Barra, "TOPLEFT", 0, -(K.ALTO.control + ESP.s))
				bh = K.ALTO.control + ESP.s + sh
				segW = 0
			else
				self.Segmentos:ClearAllPoints()
				self.Segmentos:SetPoint("TOPRIGHT", self.Barra, "TOPRIGHT", 0, -floor((K.ALTO.control - sh) / 2))
			end
		end
		if self.Buscador then
			self.Buscador:ClearAllPoints()
			self.Buscador:SetPoint("TOPLEFT", self.Barra, "TOPLEFT", 0, 0)
			self.Buscador:SetWidth(max(160, ancho - (segW > 0 and segW + ESP.base or 0)))
		end
		self.Barra:ClearAllPoints()
		self.Barra:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -by)
		self.Barra:SetSize(ancho, bh)
		local hayBarra = self.Buscador or self.Segmentos
		local y = hayBarra and (bh + ESP.base) or 0
		-- La cuenta, sobre la lista.
		self.Cuenta:ClearAllPoints()
		self.Cuenta:SetPoint("TOPLEFT", self, "TOPLEFT", 2, -y)
		y = y + 18 + ESP.xs
		local resto = max(120, disponible - y)
		local angosto = ancho < 680
		local fw = angosto and ancho or min(self.alfaAnchoFicha, floor(ancho * 0.45))
		local lw = angosto and ancho or (ancho - fw - ESP.base)
		local lh = angosto and floor(resto * 0.45) or resto
		self.MarcoLista:ClearAllPoints()
		self.MarcoLista:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
		self.MarcoLista:SetSize(lw, lh)
		self.Lista:ClearAllPoints()
		self.Lista:SetPoint("TOPLEFT", self.MarcoLista, "TOPLEFT", 4, -4)
		self.Lista:Acomodar(lw - 8, lh - 8)
		self.Ficha:ClearAllPoints()
		if angosto then
			self.Ficha:SetPoint("TOPLEFT", self.MarcoLista, "BOTTOMLEFT", 0, -ESP.base)
			self.Ficha:SetSize(fw, resto - lh - ESP.base)
		else
			self.Ficha:SetPoint("TOPLEFT", self.MarcoLista, "TOPRIGHT", ESP.base, 0)
			self.Ficha:SetSize(fw, resto)
		end
		self:RehacerFicha()
		return alto
	end
	return t
end

---------------------------------------------------------------------------
-- Asistente por pasos
--   opts = { margen, arriba = 16, abajo = 16,
--            pasos = { { titulo, texto, construir = fn(pila, asistente), alMostrar = fn(pila),
--                        listo = fn() -> bool (puede seguir), alSalir = fn() } },
--            alTerminar = fn(), textoTerminar = "Listo" }
--   a:Ir(i) a:Siguiente() a:Atras() a:Paso() -> i ; a:Acomodar(ancho, alto) -> alto
--   Con `alto`, el pie queda abajo; sin él, el asistente mide lo que ocupa.
---------------------------------------------------------------------------
function K.Asistente(padre, opts)
	opts = opts or {}
	local a = CreateFrame("Frame", nil, padre)
	a.alfaPadre = padre
	a.alfaMargen, a.alfaArriba, a.alfaAbajo = opts.margen or 0, opts.arriba or ESP.base, opts.abajo or ESP.base
	a.pasos = opts.pasos or {}
	a.pilas = {}
	a.alfaPaso = 1
	a.Huellas = K.Huellas(a, { tam = 18, max = 10, gap = 6 })
	a.Numero = K.Texto(a, "mayus", "acento")
	a.Titulo = K.Texto(a, "titulo", "texto")
	a.Texto = K.Texto(a, "texto", "textoSuave")
	a.Linea = K.Linea(a, "linea")
	a.BotonAtras = K.Boton(a, L["Atrás"], function() a:Atras() end, { tipo = "secundario" })
	a.BotonSiguiente = K.Boton(a, L["Siguiente"], function() a:Siguiente() end, { tipo = "primario", conIcono = true })

	local function pila(i)
		local p = a.pilas[i]
		if p then return p end
		p = K.Pila(a, { espacio = ESP.base })
		local paso = a.pasos[i]
		if paso and paso.construir then K.Llamar(paso.construir, p, a) end
		a.pilas[i] = p
		return p
	end

	function a:Paso() return self.alfaPaso end
	function a:Refrescar()
		local n = #self.pasos
		local i = self.alfaPaso
		local paso = self.pasos[i] or {}
		self.Huellas:Set(i - 1, n)
		K.Escribir(self.Numero, (L["Paso %d de %d"]):format(i, n):upper())
		K.Escribir(self.Titulo, paso.titulo or "")
		K.Escribir(self.Texto, paso.texto or "")
		self.BotonAtras:SetShown(i > 1)
		self.BotonSiguiente:SetTexto(i >= n and (opts.textoTerminar or L["Listo"]) or L["Siguiente"])
		self.BotonSiguiente:SetIcono(i >= n and "ic-exito" or "ic-seguir")
		self.BotonSiguiente:SetActivo(not paso.listo or paso.listo() and true or false)
	end
	function a:Ir(i)
		i = max(1, min(#self.pasos, i))
		local antes = self.pasos[self.alfaPaso]
		if antes and antes.alSalir and i ~= self.alfaPaso then K.Llamar(antes.alSalir) end
		self.alfaPaso = i
		for k, p in pairs(self.pilas) do p:SetShown(k == i) end
		local p = pila(i)
		p:Show()
		local paso = self.pasos[i]
		if paso and paso.alMostrar then K.Llamar(paso.alMostrar, p, self) end
		self:Refrescar()
		if self.alfaAncho then self:Acomodar(self.alfaAncho, self.alfaAlto) end
		if self.alCambiar then K.Llamar(self.alCambiar, i) end
	end
	function a:Siguiente()
		local paso = self.pasos[self.alfaPaso]
		if paso and paso.listo and not paso.listo() then return end
		if self.alfaPaso >= #self.pasos then
			if opts.alTerminar then K.Llamar(opts.alTerminar, self) end
			return
		end
		self:Ir(self.alfaPaso + 1)
	end
	function a:Atras() self:Ir(self.alfaPaso - 1) end
	function a:Acomodar(ancho, alto)
		self.alfaAncho, self.alfaAlto = ancho, alto
		self:ClearAllPoints()
		self:SetPoint("TOPLEFT", self.alfaPadre, "TOPLEFT", self.alfaMargen, -self.alfaArriba)
		local y = 0
		local hw = self.Huellas:Acomodar()
		self.Huellas:ClearAllPoints()
		self.Huellas:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
		self.Numero:ClearAllPoints()
		self.Numero:SetPoint("LEFT", self.Huellas, "RIGHT", ESP.m, 0)
		y = y + 26 + ESP.base
		self.Titulo:ClearAllPoints()
		self.Titulo:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
		self.Titulo:SetWidth(ancho)
		y = y + K.AltoTexto(self.Titulo)
		if (self.Texto:GetText() or "") ~= "" then
			y = y + 6
			self.Texto:ClearAllPoints()
			self.Texto:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
			y = y + K.Parrafo(self.Texto, min(ancho, 640))
		end
		y = y + ESP.l
		local p = pila(self.alfaPaso)
		p:ClearAllPoints()
		p:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
		y = y + p:Acomodar(ancho)
		-- El pie: abajo del todo si hay alto; si no, tras el contenido.
		local pie = K.ALTO.boton
		local yPie = y + ESP.l
		if alto then yPie = max(yPie, alto - self.alfaArriba - self.alfaAbajo - pie) end
		self.Linea:ClearAllPoints()
		self.Linea:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -(yPie - ESP.base))
		self.Linea:SetPoint("TOPRIGHT", self, "TOPLEFT", ancho, -(yPie - ESP.base))
		self.BotonAtras:ClearAllPoints()
		self.BotonAtras:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -yPie)
		self.BotonSiguiente:ClearAllPoints()
		self.BotonSiguiente:SetPoint("TOPRIGHT", self, "TOPLEFT", ancho, -yPie)
		local total = yPie + pie
		self:SetSize(ancho, total)
		return self.alfaArriba + total + self.alfaAbajo
	end
	a:Ir(1)
	return a
end

---------------------------------------------------------------------------
-- Una plantilla dentro de una página de la ventana principal: su
-- view.Refresh mide la plantilla con el ancho de la página. `antes` (opcional)
-- pone los datos antes de medir. Con ListaFicha o Asistente, el alto es el
-- visible de la página (sin desplazar la página entera).
---------------------------------------------------------------------------
function K.EnPagina(view, plantilla, antes)
	plantilla.alfaVista = view
	view.Refresh = function()
		if antes then K.Llamar(antes) end
		local ancho = N.AnchoPagina()
		if plantilla.MostrarFicha or plantilla.BotonSiguiente then
			return plantilla:Acomodar(ancho, N.AltoPagina())
		end
		return plantilla:Acomodar(ancho)
	end
	return plantilla
end

-- Vuelve a medir una página de la ventana principal que está a la vista
-- (tras un cambio de datos).
function K.Rehacer(plantillaOVista)
	local view = plantillaOVista and (plantillaOVista.alfaVista or plantillaOVista)
	if not (view and view.Refresh and view.IsVisible and view:IsVisible()) then return end
	N.RehacerPagina(view)
end
