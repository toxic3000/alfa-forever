-- Alfa - Rutas: el bloque "Tu plan de misiones" de la página Ruta (Toxic / La
-- Jauría). GPL-3.0.
--
-- Tus misiones abiertas y las que agregaste a mano, cada una con un
-- interruptor (entra o no al plan), si está lista para entregar o qué le
-- falta, en qué zona y qué tan lejos, y si pide grupo o es de mazmorra. Un
-- filtro elige cuáles entran (todas, solo las listas, solo las de esta
-- zona); lo que tocas a mano manda sobre el filtro. "Armar mi plan" hace la
-- guía (Cerrar.lua). Las que no valen la pena se marcan para abandonar, con
-- confirmación.

local ADDON, M = ...
local A, L, N = M.A, M.L, M.N
local K = M.K
local Cr, T = M.Cerrar, M.Tareas

local ipairs, format, max, min = ipairs, string.format, math.max, math.min

local FILA = 50
local FILTROS = {
	{ valor = "todas", texto = L["Todas"] },
	{ valor = "listas", texto = L["Listas para entregar"] },
	{ valor = "zona", texto = L["En esta zona"] },
}

local function filaMision(padre)
	local f = CreateFrame("Frame", nil, padre)
	f.caja = K.Caja(f, { fondo = "panel", borde = "linea", corte = K.CORTE.control })
	f.Entra = K.Interruptor(f, { alCambiar = function() if f.alfaId then Cr.Alternar(f.alfaId) end end })
	f.Entra:SetPoint("LEFT", f, "LEFT", K.ESP.m, 0)
	K.ConInfo(f.Entra, L["En tu plan"], L["Encendida: entra al plan aunque el filtro la deje fuera. Apagada: queda fuera."])
	f.Abandonar = K.BotonIcono(f, "ic-cerrar", function()
		if not f.alfaId then return end
		local marcada = M.Personaje().marcas[f.alfaId] == "abandonar"
		if f.alfaExtra and not f.alfaEnLog then
			Cr.Quitar(f.alfaId)
		else
			Cr.MarcarAbandonar(f.alfaId, not marcada)
		end
	end, { tam = 24, icono = 11, tipo = "fantasma" })
	f.Abandonar:SetPoint("RIGHT", f, "RIGHT", -K.ESP.s, 0)
	f.Estado = K.Insignia(f, "", "neutro")
	f.Titulo = K.Texto(f, "cuerpo", "texto")
	f.Sub = K.Texto(f, "pequeno", "textoTenue")
	function f:Set(it)
		self.alfaId, self.alfaExtra, self.alfaEnLog = it.id, it.extra, it.enLog
		local entra = Cr.Entra(it)
		self.Entra:SetValor(entra)
		local marca = M.Personaje().marcas[it.id]
		local w
		if marca == "abandonar" then
			w = self.Estado:Set(L["Para abandonar"], "peligro")
		elseif it.enLog and it.listo then
			w = self.Estado:Set(L["Lista"], "exito", "ic-exito")
		elseif it.enLog then
			w = self.Estado:Set(L["Por terminar"], "neutro")
		elseif it.bloqueo then
			w = self.Estado:Set(L["Bloqueada"], it.imposible and "peligro" or "aviso")
		else
			w = self.Estado:Set(L["Agregada"], "acento", "ic-mas")
		end
		self.alfaAnchoEstado = w
		K.Escribir(self.Titulo, (it.nivel and ("[" .. it.nivel .. "] ") or "") .. (it.titulo or ""))
		K.ColorTexto(self.Titulo, entra and "texto" or "textoTenue")
		local partes = {}
		if it.bloqueoTexto then partes[#partes + 1] = it.bloqueoTexto end
		local zona = it.zona and M.Zona(it.zona)
		if zona then partes[#partes + 1] = zona end
		if it.viaje and it.viaje < M.Indice.LEJOS then partes[#partes + 1] = format(L["≈ %s"], M.Minutos(it.viaje)) end
		if it.lejos then partes[#partes + 1] = K.Tenir("aviso", L["lejos"]) end
		if it.otraZona then partes[#partes + 1] = K.Tenir("aviso", L["otra zona"]) end
		for _, r in ipairs(it.razones or {}) do partes[#partes + 1] = r end
		K.Escribir(self.Sub, table.concat(partes, "  \194\183  "))
		local quitar = it.extra and not it.enLog
		self.Abandonar:SetIcono(quitar and "ic-cerrar" or "ic-alerta")
		self.Abandonar:SetMarcado(marca == "abandonar")
		K.ConInfo(self.Abandonar, quitar and L["Quitar del plan"] or L["Marcar para abandonar"],
			quitar and L["La sacas de tu plan."] or L["Se abandona con «Abandonar marcadas», que pide confirmación."])
	end
	function f:Acomodar(ancho)
		self:SetSize(ancho, FILA)
		local x = K.ESP.m + 36 + K.ESP.m
		self.Estado:ClearAllPoints()
		self.Estado:SetPoint("RIGHT", self.Abandonar, "LEFT", -K.ESP.s, 0)
		local tw = ancho - x - (self.alfaAnchoEstado or 60) - 24 - 3 * K.ESP.s
		self.Titulo:ClearAllPoints()
		self.Titulo:SetPoint("TOPLEFT", self, "TOPLEFT", x, -9)
		self.Titulo:SetWidth(max(60, tw))
		self.Sub:ClearAllPoints()
		self.Sub:SetPoint("TOPLEFT", self.Titulo, "BOTTOMLEFT", 0, -3)
		self.Sub:SetWidth(max(60, tw))
		return FILA
	end
	return f
end

-- El bloque. ui.alCambiar: la página se rehace.
function M.BloqueMisiones(padre, alCambiar)
	local b = K.Pila(padre, { espacio = K.ESP.m })
	b.Seccion = b:Agregar(K.Seccion(b, L["Cerrar mis misiones"]))
	-- Arriba: el filtro y la acción.
	local barra = CreateFrame("Frame", nil, b)
	b.Filtro = K.Segmentos(barra, { estilo = "segmentos", opciones = FILTROS, valor = Cr.Filtro(), alCambiar = function(f)
		Cr.SetFiltro(f)
		if alCambiar then alCambiar() end
	end })
	b.Armar = K.Boton(barra, L["Armar mi plan"], function() Cr.Ahora() end, { tipo = "primario", icono = "ic-seguir" })
	function barra:Acomodar(ancho)
		local sh, sw = b.Filtro:Acomodar(ancho - b.Armar:AnchoNatural() - K.ESP.base)
		b.Filtro:ClearAllPoints()
		b.Filtro:SetPoint("LEFT", self, "LEFT", 0, 0)
		b.Armar:ClearAllPoints()
		b.Armar:SetPoint("RIGHT", self, "RIGHT", 0, 0)
		local h = max(sh, K.ALTO.boton)
		self:SetHeight(h)
		return h
	end
	b.Barra = b:Agregar(barra)
	b.Resumen = b:Agregar(K.Texto(b, "nota", "textoSuave"), { espacio = K.ESP.s })
	function b.Resumen:Acomodar(ancho) return K.Parrafo(self, ancho, 2) end
	b.Lista = b:Agregar(K.Pila(b, { espacio = K.ESP.xs }), { espacio = K.ESP.s })
	b.filas = {}
	b.Vacio = b:Agregar(K.Vacio(b, { lobo = "dormido", titulo = L["Tu registro está vacío"],
		texto = L["Toma unas misiones cerca y Alfa las cierra contigo por el camino más corto."],
		accion = { texto = L["Recoger misiones cerca"], icono = "ic-misiones", alClic = function() M.Recoger.Ahora() end } }))
	b.Cargando = b:Agregar(K.Texto(b, "nota", "textoTenue"))
	function b.Cargando:Acomodar(ancho) self:SetWidth(ancho) return 20 end
	-- Abajo: abandonar y marcar las que no valen la pena.
	local pie = CreateFrame("Frame", nil, b)
	b.Sugeridas = K.Boton(pie, L["Marcar las que no valen la pena"], function()
		local n = 0
		for _, it in ipairs(Cr.Lista() or {}) do
			if it.sugerencia == "abandonar" and not M.Personaje().marcas[it.id] then
				Cr.MarcarAbandonar(it.id, true)
				n = n + 1
			end
		end
		M.Aviso(n > 0 and format(L["Marqué %d misiones"], n) or L["No hay misiones que convenga dejar"],
			n > 0 and L["Revisa la lista antes de abandonar."] or nil, { icono = "ic-info" })
	end, { tipo = "fantasma", tam = "chico" })
	b.Abandonar = K.Boton(pie, "", function() Cr.AbandonarMarcadas() end, { tipo = "peligro", tam = "chico", icono = "ic-cerrar" })
	function pie:Acomodar(ancho)
		b.Sugeridas:ClearAllPoints()
		b.Sugeridas:SetPoint("LEFT", self, "LEFT", 0, 0)
		b.Abandonar:ClearAllPoints()
		b.Abandonar:SetPoint("RIGHT", self, "RIGHT", 0, 0)
		self:SetHeight(K.ALTO.botonChico)
		return K.ALTO.botonChico
	end
	b.Pie = b:Agregar(pie, { espacio = K.ESP.m })

	function b:Llenar()
		local lista = Cr.Lista()
		if not lista then
			if not T.Corriendo("cerrar:revisar") then
				Cr.Revisar(function() if alCambiar then alCambiar() end end)
			end
			K.Escribir(self.Cargando, L["Revisando tu registro..."])
			K.Mostrar(self.Cargando, true)
			K.Mostrar(self.Barra, false)
			K.Mostrar(self.Resumen, false)
			K.Mostrar(self.Lista, false)
			K.Mostrar(self.Vacio, false)
			K.Mostrar(self.Pie, false)
			self.Seccion:Set(L["Cerrar mis misiones"])
			return
		end
		K.Mostrar(self.Cargando, false)
		local c = Cr.Cuentas(lista)
		local hay = #lista > 0
		self.Seccion:Set(L["Cerrar mis misiones"], { cuenta = hay and #lista or nil })
		K.Mostrar(self.Barra, hay)
		K.Mostrar(self.Resumen, hay)
		K.Mostrar(self.Lista, hay)
		K.Mostrar(self.Vacio, not hay)
		self.Filtro:SetValor(Cr.Filtro())
		local partes = { format(L["%d en tu plan"], c.entran) }
		if c.listas > 0 then partes[#partes + 1] = format(L["%d listas para entregar"], c.listas) end
		if c.faltan > 0 then partes[#partes + 1] = format(L["%d por terminar"], c.faltan) end
		if c.otraZona > 0 then partes[#partes + 1] = format(L["%d en otra zona"], c.otraZona) end
		K.Escribir(self.Resumen, table.concat(partes, "  \194\183  ") .. ". " .. L["Toca el interruptor para poner o quitar una; lo que tocas manda sobre el filtro."])
		self.Armar:SetActivo(c.entran > 0)
		self.Lista:Vaciar()
		for i, it in ipairs(lista) do
			local f = self.filas[i] or filaMision(self.Lista)
			self.filas[i] = f
			f:Set(it)
			f:Show()
			self.Lista:Agregar(f)
		end
		for i = #lista + 1, #self.filas do self.filas[i]:Hide() end
		local sugeridas = 0
		for _, it in ipairs(lista) do if it.sugerencia == "abandonar" and not M.Personaje().marcas[it.id] then sugeridas = sugeridas + 1 end end
		self.Sugeridas:SetShown(sugeridas > 0)
		self.Abandonar:SetShown(c.abandonar > 0)
		if c.abandonar > 0 then self.Abandonar:SetTexto(format(L["Abandonar marcadas (%d)"], c.abandonar)) end
		K.Mostrar(self.Pie, hay and (sugeridas > 0 or c.abandonar > 0))
	end
	return b
end
