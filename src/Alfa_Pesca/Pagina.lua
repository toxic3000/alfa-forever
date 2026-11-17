-- Alfa - Pesca: su página en la ventana de Alfa (toxic3000 / La Jauría). GPL-3.0.
--
-- La página de referencia del Kit de Alfa (docs/KIT.md): la plantilla
-- Tablero con, de arriba abajo,
--   1. el estado y qué hacer ahora (tarjeta "estado": listo, pescando, sin
--      caña, sin tecla, en pausa...), con tu habilidad de pesca y, si hace
--      falta, la acción que lo arregla (encender, elegir tu tecla);
--   2. los números de la sesión (capturas, tiempo con la caña en el agua,
--      habilidad subida) en tarjetas compactas;
--   3. lo pescado en la sesión, en una rejilla de objetos;
--   4. los ajustes, en tres grupos de filas.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID

local floor, max, min, format = math.floor, math.max, math.min, string.format

local DOT = "  \194\183  "
local VISIBLES = 8 -- objetos del registro antes de "Ver todo"

local function pct(v) return floor((tonumber(v) or 0) * 100 + 0.5) .. " %" end
local function segundos(v) return format(L["%.2f s"], tonumber(v) or 0) end

local function teclaTexto()
	local t = M.Teclas()
	return t[1] and M.TextoTecla(t[1]) or nil
end

---------------------------------------------------------------------------
-- 1. El estado y la acción
---------------------------------------------------------------------------

-- -> datos de la tarjeta de estado
local function estado(ui)
	local tecla = teclaTexto()
	local clic = M.Opt("dobleClic")
	local d = { icono = "ic-pesca" }
	if M.E.otro then
		d.titulo, d.tono = L["Otro addon de pesca está activo"], "aviso"
		d.texto = L["Para que no choquen, Alfa no toma tu tecla ni cambia tus ajustes. Desactiva uno de los dos en la lista de addons (pantalla de personajes) y recarga. Si dejas Alfa, tomará sola la tecla que usabas en el otro addon."]
		d.estado = { texto = L["En pausa"], tono = "aviso" }
	elseif not M.Opt("activo") then
		d.titulo, d.tono = L["La pesca de Alfa está apagada"], "neutro"
		d.texto = L["Tu tecla y tus ajustes del juego quedan como siempre. Enciéndela para pescar con una sola tecla."]
		d.estado = { texto = L["Apagada"], tono = "neutro" }
		d.accion = { texto = L["Encender la pesca"], icono = "ic-seguir", alClic = function() N.Set(ID, "activo", true) end }
	elseif M.SabePesca() == false then
		d.titulo, d.tono = L["Todavía no sabes pescar"], "aviso"
		d.texto = L["Aprende Pesca con un instructor de pesca (hay en las capitales) y compra una caña. Luego vuelve aquí."]
		d.estado = { texto = L["Aprende Pesca"], tono = "aviso" }
	elseif M.Pescando() then
		d.titulo, d.tono = L["Pescando…"], "acento"
		d.texto = tecla and format(L["El corcho está en el agua. Cuando se hunda, pulsa %s para recoger."], tecla)
			or L["El corcho está en el agua. Cuando se hunda, haz clic derecho sobre él para recoger."]
		d.estado = { texto = L["Pescando"], tono = "acento" }
	elseif not M.TieneCana() then
		d.titulo, d.tono = L["Equipa tu caña de pescar"], "aviso"
		d.texto = L["Para pescar necesitas una caña en las manos. Cuando la tengas puesta, ya puedes lanzar."]
		d.estado = { texto = L["Sin caña"], tono = "aviso" }
	elseif not tecla and not clic then
		d.titulo, d.tono = L["Elige tu tecla para pescar"], "aviso"
		d.texto = L["Con ella lanzas la caña y, cuando pica, recoges el pez. Pulsa el botón y luego la tecla que quieras."]
		d.estado = { texto = L["Sin tecla"], tono = "aviso" }
		d.accion = { texto = L["Elegir mi tecla"], icono = "ic-seguir", alClic = function() if ui.atajo then ui.atajo:Capturar() end end }
	else
		d.titulo, d.tono = L["Listo para pescar"], "exito"
		if tecla then
			d.texto = format(L["Pulsa %s para lanzar. Cuando el corcho se hunda, pulsa %s otra vez para recoger."], tecla, tecla)
			if clic then d.texto = d.texto .. " " .. L["También puedes lanzar con doble clic derecho."] end
		else
			d.texto = L["Haz doble clic derecho en el mundo para lanzar. Cuando pique, haz clic derecho sobre el corcho para recoger."]
		end
		d.estado = { texto = L["Listo"], tono = "exito" }
	end
	-- Tu habilidad de pesca, como avance.
	local rango, maximo, bono = M.Habilidad()
	if rango then
		local partes = { maximo > 0 and format(L["Pesca %d / %d"], rango, maximo) or format(L["Pesca %d"], rango) }
		if bono > 0 then partes[#partes + 1] = format(L["+%d por cebo o equipo"], bono) end
		if maximo >= 300 and rango >= maximo then
			partes[#partes + 1] = L["al máximo"]
		elseif maximo > 0 and rango >= maximo then
			partes[#partes + 1] = L["aprende el siguiente rango"]
		end
		d.progreso = { actual = rango, total = max(1, maximo), texto = table.concat(partes, DOT) }
	end
	return d
end

---------------------------------------------------------------------------
-- 2. Los números de la sesión
---------------------------------------------------------------------------
local function numeros()
	local s = M.Sesion()
	local seg = s.segundos + (M.E.canal and max(0, GetTime() - M.E.canal) or 0)
	local rango = M.Habilidad()
	local inicial = tonumber(s.rangoInicial)
	local subio = (rango and inicial and rango > inicial) and (rango - inicial) or 0
	return {
		{ variante = "compacta", icono = "ic-pesca", titulo = L["Capturas"], valor = tostring(s.capturas),
			texto = s.inicio and format(L["desde las %s"], date("%H:%M", s.inicio)) or nil },
		{ variante = "compacta", icono = "ic-reloj", titulo = L["Con la caña en el agua"], valor = seg >= 1 and N.Duracion(seg) or "0 s" },
		{ variante = "compacta", icono = "ic-nivel", titulo = L["Habilidad en esta sesión"], valor = subio > 0 and ("+" .. subio) or "0",
			tono = subio > 0 and "exito" or nil },
	}
end

---------------------------------------------------------------------------
-- 3. Lo pescado: una rejilla de objetos (ícono con su calidad, nombre, cuántos)
---------------------------------------------------------------------------
local function celdaObjeto(padre)
	local c = CreateFrame("Frame", nil, padre)
	c.caja = K.Caja(c, { fondo = "panel", borde = "linea", corte = K.CORTE.control })
	c.Icono = K.IconoObjeto(c, 30)
	c.Icono:SetPoint("LEFT", c, "LEFT", K.ESP.m, 0)
	c.Cantidad = K.Texto(c, "numero", "textoSuave")
	c.Cantidad:SetJustifyH("RIGHT")
	c.Cantidad:SetPoint("RIGHT", c, "RIGHT", -K.ESP.base, 0)
	c.Nombre = K.Texto(c, "cuerpo", "objeto")
	c.Nombre:SetPoint("LEFT", c.Icono, "RIGHT", K.ESP.m, 0)
	c.Nombre:SetPoint("RIGHT", c.Cantidad, "LEFT", -K.ESP.s, 0)
	function c:Set(o)
		self.Icono:SetObjeto({ id = type(o.id) == "number" and o.id or nil, icono = o.icono, calidad = o.calidad })
		K.Escribir(self.Nombre, o.nombre or "?")
		local r, g, b = K.ColorDeCalidad(o.calidad)
		if r and A.Theme and A.Theme.Legible then
			self.Nombre:SetTextColor(A.Theme.Legible(r, g, b))
		else
			K.ColorTexto(self.Nombre, "objeto")
		end
		self.Cantidad:SetText(format("\195\151%d", o.cantidad or 0))
	end
	function c:Acomodar(ancho, altoMin)
		local h = max(K.ALTO.compacta, altoMin or 0)
		self:SetSize(ancho, h)
		return h
	end
	return c
end

local function registro(ui, padre)
	local b = K.Pila(padre, { espacio = K.ESP.m })
	b.Seccion = b:Agregar(K.Seccion(b, L["Lo pescado en esta sesión"]))
	b.Rejilla = b:Agregar(K.Rejilla(b, { min = 260, gap = K.ESP.s }), { espacio = K.ESP.s })
	b.Vacio = b:Agregar(K.Vacio(b, {
		lobo = "dormido", titulo = L["Todavía no has pescado nada"],
		texto = L["Lo que saques aparece aquí, con cuántos llevas de cada uno."],
	}), { espacio = K.ESP.base })
	b.celdas = {}
	b.Pie = CreateFrame("Frame", nil, b)
	b.Pie.Mas = K.Boton(b.Pie, "", function() ui.verTodo = not ui.verTodo M.Avisar() end, { tipo = "fantasma", tam = "chico" })
	b.Pie.Mas:SetPoint("LEFT", b.Pie, "LEFT", 0, 0)
	b.Pie.Borrar = K.Boton(b.Pie, L["Empezar de nuevo"], function()
		K.Dialogo({
			titulo = L["¿Empezar un registro nuevo?"], texto = L["Se borra lo pescado en esta sesión. Tu habilidad de pesca no cambia."],
			aceptar = L["Borrar registro"], peligro = true, alAceptar = function() M.NuevaSesion() end,
		})
	end, { tipo = "fantasma", tam = "chico", icono = "ic-cerrar" })
	b.Pie.Borrar:SetPoint("RIGHT", b.Pie, "RIGHT", 0, 0)
	b.Pie:SetHeight(K.ALTO.botonChico)
	b:Agregar(b.Pie, { espacio = K.ESP.m })
	function b:Llenar()
		local s = M.Sesion()
		local lista = M.Objetos()
		local n = ui.verTodo and #lista or min(#lista, VISIBLES)
		self.Seccion:Set(L["Lo pescado en esta sesión"], { cuenta = s.total > 0 and s.total or nil })
		local elems = {}
		for i = 1, n do
			local c = self.celdas[i] or celdaObjeto(self.Rejilla)
			self.celdas[i] = c
			c:Set(lista[i])
			c:Show()
			elems[i] = c
		end
		for i = n + 1, #self.celdas do self.celdas[i]:Hide() end
		self.Rejilla:SetElementos(elems)
		K.Mostrar(self.Rejilla, n > 0)
		K.Mostrar(self.Vacio, #lista == 0)
		local mas = #lista > VISIBLES
		self.Pie.Mas:SetShown(mas)
		if mas then self.Pie.Mas:SetTexto(ui.verTodo and L["Ver menos"] or format(L["Ver todo (%d)"], #lista)) end
		self.Pie.Borrar:SetShown(s.capturas > 0 or s.total > 0)
		K.Mostrar(self.Pie, mas or self.Pie.Borrar:IsShown())
	end
	return b
end

---------------------------------------------------------------------------
-- 4. Los ajustes: cada fila crea su control dentro de sí (K.FilaAjuste)
---------------------------------------------------------------------------
local function activa() return M.Opt("activo") and true or false end
local function hijaDe(padre) return function() return M.Opt("activo") and M.Opt(padre) and true or false end end

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

local function grupos(ui, padre)
	local encendido = K.GrupoAjustes(padre, { titulo = L["Encendido y tecla"] })
	encendido:Fila({ titulo = L["Usar la pesca de Alfa"], control = interruptor("activo"),
		texto = L["Apágalo si no quieres que Alfa toque tu tecla ni tus ajustes al pescar."] })
	encendido:Fila({ titulo = L["Tecla para pescar"], activa = activa,
		control = function(fila)
			ui.atajo = K.Atajo(fila, { accion = M.ACCION, titulo = L["Tecla para pescar"] })
			return ui.atajo
		end,
		texto = L["Con ella lanzas la caña y, cuando pica, recoges el pez. También está en el menú de atajos del juego, en Alfa."] })

	local mientras = K.GrupoAjustes(padre, { titulo = L["Mientras pescas"] })
	mientras:Fila({ titulo = L["Recoger todo lo que pesques"], control = interruptor("autobotin"), activa = activa,
		texto = L["Toma el botín de la pesca enseguida, aunque tengas apagado el botín automático del juego."] })
	mientras:Fila({ titulo = L["Subir el sonido al pescar"], control = interruptor("sonido"), activa = activa,
		texto = L["Apaga la música y el ambiente y sube los efectos para que oigas cuando pica, aunque el juego esté en segundo plano. Al terminar, todo vuelve a como estaba."] })
	mientras:Fila({ titulo = L["Volumen mientras pescas"], control = deslizador("volumen", 0, 1, 0.05, pct), hija = true, activa = hijaDe("sonido"),
		texto = L["Qué tan fuerte se oye el juego mientras el corcho está en el agua."] })
	mientras:Fila({ titulo = L["Ocultar nombres al pescar"], control = interruptor("ocultarNombres"), activa = activa,
		texto = L["Esconde las placas y los nombres de los PNJ mientras pescas (los enemigos hostiles conservan su nombre), para ver y tocar mejor el corcho."] })
	mientras:Fila({ titulo = L["Ícono sobre el corcho"], control = interruptor("iconoCorcho"), activa = activa,
		texto = L["Muestra un ícono encima del corcho: así sabes que tu tecla lo va a recoger."] })

	local doble = K.GrupoAjustes(padre, { titulo = L["Doble clic derecho"] })
	doble:Fila({ titulo = L["Doble clic derecho para lanzar"], control = interruptor("dobleClic"), activa = activa,
		texto = L["Haz doble clic derecho en el mundo para lanzar la caña, sin usar la tecla. Nunca en combate ni en vuelo."] })
	doble:Fila({ titulo = L["Rapidez del doble clic"], control = deslizador("velocidad", 0.1, 0.8, 0.05, segundos), hija = true, activa = hijaDe("dobleClic"),
		texto = L["Tiempo máximo entre los dos clics. Súbelo si tus dobles clics no lanzan."] })
	doble:Fila({ titulo = L["También en montura"], control = interruptor("montado"), hija = true, activa = hijaDe("dobleClic"),
		texto = L["Permite lanzar con doble clic aunque vayas montado."] })
	doble:Fila({ titulo = L["Doble clic mientras pescas vuelve a lanzar"], control = interruptor("relanzar"), hija = true, activa = hijaDe("dobleClic"),
		texto = L["Encendido: el doble clic mientras pescas lanza de nuevo y, con Mayús, Ctrl o Alt, recoge. Apagado: al revés."] })
	return { encendido, mientras, doble }
end

---------------------------------------------------------------------------
-- La página
---------------------------------------------------------------------------
local function construir(view)
	local ui = {}
	local t = K.Tablero(view, { margen = N.MargenPagina(), accion = "estado", tituloOpciones = L["Esta sesión"], min = 240 })
	-- Cada bloque nace dentro de t.Extra, la pila de abajo del tablero.
	ui.registro = t:AgregarBloque(registro(ui, t.Extra))
	ui.ajustes = grupos(ui, t.Extra)
	for i, g in ipairs(ui.ajustes) do t:AgregarBloque(g, { espacio = i == 1 and K.ESP.xl or K.ESP.l }) end
	K.EnPagina(view, t, function()
		t:SetAccion(estado(ui))
		t:SetOpciones(numeros(), L["Esta sesión"])
		ui.registro:Llenar()
		for _, g in ipairs(ui.ajustes) do g:Refrescar() end
	end)
	ui.tablero = t
	M.vista = view
end

-- Algo cambió (pescaste, cambió tu tecla, tu caña, un ajuste...): la página
-- se rehace si está a la vista.
M.alCambiar = function()
	local view = M.vista
	if view then N.RehacerPagina(view) end
end

N.Modulo({
	id = ID, nombre = L["Pesca"], icono = "ic-pesca", orden = 55,
	subtitulo = L["Lanza con una tecla y recoge con la misma, con autobotín, sonido amplificado y doble clic."],
	comando = "pesca",
	ajustes = M.AJUSTES,
	construir = construir,
})

-- /alfa pesca con sus opciones (on, off, reiniciar); sin nada abre la página.
A.RegisterCommand("pesca", M.Comando, L["abre Pesca (también: on, off, reiniciar)"])
