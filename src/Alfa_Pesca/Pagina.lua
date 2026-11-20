-- Alfa - Pesca: su página en la ventana de Alfa (toxic3000 / La Jauría). GPL-3.0.
--
-- La plantilla Tablero del Kit (docs/KIT.md), de arriba abajo:
--   1. el estado y qué hacer ahora (tarjeta "estado"): abrir o cerrar el modo
--      pesca, aprender Pesca, encender, en pausa..., con tu habilidad;
--   2. los accesos: diario, estadísticas, guía, cocina, metas y logros;
--   3. los ajustes, en grupos: tecla y modo, equipo y cebos, la barra,
--      sonido y avisos, mientras pescas, doble clic derecho y tus datos.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID
local E = M.E
local Eq = M.Eq

local floor, max, min, format = math.floor, math.max, math.min, string.format
local ESP = K.ESP
local DOT = "  \194\183  "

local function pct(v) return floor((tonumber(v) or 0) * 100 + 0.5) .. " %" end
local function segundos(v) return format(L["%.2f s"], tonumber(v) or 0) end

---------------------------------------------------------------------------
-- La tecla del modo pesca: clic y pulsa (teclado, botones del ratón 3 a 5,
-- rueda, con Mayús, Ctrl o Alt); clic derecho la quita.
---------------------------------------------------------------------------
local captura
local IGNORAR = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, SHIFT = true, CTRL = true, ALT = true,
	LMETA = true, RMETA = true, META = true, UNKNOWN = true }
local RATON = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }

local function prefijo()
	local p = ""
	if IsAltKeyDown and IsAltKeyDown() then p = p .. "ALT-" end
	if IsControlKeyDown and IsControlKeyDown() then p = p .. "CTRL-" end
	if IsShiftKeyDown and IsShiftKeyDown() then p = p .. "SHIFT-" end
	return p
end

local function terminarCaptura(tecla)
	if not captura then return end
	local c = captura.control
	captura:Hide()
	captura.control = nil
	if c then c.alfaEsperando = nil end
	if tecla and c then N.Set(ID, c.alfaClave, tecla) end
	if c then c:Leer() end
end

local function armarCaptura()
	local f = CreateFrame("Frame", "AlfaPescaTeclaCaptura", UIParent)
	f:SetAllPoints(UIParent)
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:EnableMouse(true)
	f:EnableMouseWheel(true)
	if f.EnableKeyboard then f:EnableKeyboard(true) end
	if f.SetPropagateKeyboardInput then f:SetPropagateKeyboardInput(false) end
	f:SetScript("OnKeyDown", function(_, k)
		if IGNORAR[k] then return end
		if k == "ESCAPE" then terminarCaptura(nil) return end
		terminarCaptura(prefijo() .. k)
	end)
	f:SetScript("OnMouseDown", function(_, b)
		local k = RATON[b]
		if k then terminarCaptura(prefijo() .. k) else terminarCaptura(nil) end
	end)
	f:SetScript("OnMouseWheel", function(_, d) terminarCaptura(prefijo() .. (d > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")) end)
	-- Si empieza un combate, la captura se cancela sin guardar nada (si no, se
	-- comería la primera tecla de la pelea).
	f:RegisterEvent("PLAYER_REGEN_DISABLED")
	f:SetScript("OnEvent", function(self)
		if self:IsShown() then terminarCaptura(nil) end
	end)
	f:Hide()
	return f
end

local function controlTecla(fila, clave)
	local b = K.Boton(fila, "", nil, { tipo = "secundario", ancho = 170 })
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b.alfaClave = clave
	function b:Leer()
		local texto, color
		if self.alfaEsperando then
			texto, color = L["Pulsa una tecla…"], "acento"
		else
			local k = N.Get(ID, clave)
			texto = M.TextoTecla(k) or L["Sin tecla"]
			color = (type(k) == "string" and k ~= "") and "texto" or "textoTenue"
		end
		self:SetTexto(texto)
		K.ColorTexto(self.Texto, color)
		self:SetAncho(max(170, self:AnchoNatural()))
	end
	b.alClic = function(self, boton)
		if InCombatLockdown and InCombatLockdown() then return end
		if boton == "RightButton" then
			terminarCaptura(nil)
			N.Set(ID, clave, "")
			self:Leer()
			return
		end
		captura = captura or armarCaptura()
		if captura.control then terminarCaptura(nil) end
		captura.control = self
		self.alfaEsperando = true
		self:Leer()
		captura:Show()
		K.Despues(8, function() if captura.control == self then terminarCaptura(nil) end end)
	end
	K.ConInfo(b, L["Clic para asignar"], L["Haz clic y pulsa la tecla, un botón del ratón o la rueda (con Mayús, Ctrl o Alt si quieres). Esc cancela; clic derecho la quita."])
	function b:Capturar() self.alClic(self, "LeftButton") end
	function b:SetActivo(on)
		if on == false then self:Disable() else self:Enable() end
		self:SetAlpha(on == false and 0.45 or 1)
	end
	b:Leer()
	return b
end

---------------------------------------------------------------------------
-- 1. El estado y la acción
---------------------------------------------------------------------------
local function estado(ui)
	local d = { icono = "ic-pesca" }
	local abrir = function() M.AbrirModo() end
	if E.otro then
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
		d.texto = L["Aprende Pesca con un instructor de pesca y compra una caña: la guía te lleva."]
		d.estado = { texto = L["Aprende Pesca"], tono = "aviso" }
		d.accion = { texto = L["Abrir la guía"], icono = "ic-guia", alClic = function() if M.V then M.V.Abrir("guia") end end }
	elseif E.modo then
		local est = M.Estado()
		d.titulo, d.tono = L["Modo pesca abierto"], "acento"
		d.texto = est.texto
		d.estado = { texto = M.Pescando() and L["Pescando"] or L["Listo [estado]"], tono = "acento" }
		d.accion = { texto = L["Cerrar el modo pesca"], icono = "ic-cerrar", alClic = function() M.CerrarModo() end }
		d.secundaria = { texto = L["Abrir el diario"], alClic = function() if M.V then M.V.Abrir("diario") end end }
	else
		local k = M.TextoTecla(M.Opt("tecla"))
		d.titulo, d.tono = L["Listo para pescar"], "exito"
		d.texto = k and format(L["Abre el modo pesca (aquí, con /alfa pesca o al ponerte la caña) y pulsa %s: tu tecla te pone el equipo, el cebo, lanza y recoge cuando salpica."], k)
			or L["Abre el modo pesca y elige tu tecla: te pone el equipo, el cebo, lanza y recoge cuando salpica."]
		d.estado = { texto = L["Listo [estado]"], tono = "exito" }
		d.accion = { texto = L["Abrir el modo pesca"], icono = "ic-seguir", alClic = abrir }
		d.secundaria = { texto = L["Elegir mi tecla"], alClic = function() if ui.tecla then ui.tecla:Capturar() end end }
	end
	local texto, r, mx, bono = M.TextoHabilidad()
	if r and r > 0 then
		local partes = { texto }
		if bono > 0 then partes[#partes + 1] = format(L["+%d por cebo o equipo"], bono) end
		if mx >= 300 and r >= mx then partes[#partes + 1] = L["al máximo"] end
		d.progreso = { actual = r, total = max(1, mx), texto = table.concat(partes, DOT) }
	end
	return d
end

---------------------------------------------------------------------------
-- 2. Los accesos
---------------------------------------------------------------------------
local function abrir(id) return function() if M.V then M.V.Abrir(id) end end end

local function accesos()
	local s = M.Sesion()
	local v = M.Vida()
	local hechos = 0
	for _ in pairs(M.Logros()) do hechos = hechos + 1 end
	local metas = #M.MetasGuardadas()
	return {
		{ icono = M.ICONO.diario, titulo = L["Diario de pesca"], texto = format(L["%d especies de %d en el catálogo."], M.Especies(), #M.CATALOGO), alClic = abrir("diario") },
		{ icono = "ic-nivel", titulo = L["Estadísticas [pesca]"], texto = format(L["Esta sesión: %d capturas de %d lanzamientos. Desde siempre: %d."], s.capturas, s.lanzamientos, v.capturas), alClic = abrir("estadisticas") },
		{ icono = "ic-guia", titulo = L["Guía de pesca"], texto = L["De 1 a 300, dónde pescar cerca de ti, equipo, cebos, misiones y el concurso."], alClic = abrir("guia") },
		{ icono = M.ICONO.fogata, titulo = L["Cocina junto al agua"], texto = L["Tus recetas de pescado, la cola de cocina y la fogata."], alClic = abrir("cocina") },
		{ icono = M.ICONO.meta, titulo = L["Metas de pesca"], texto = metas > 0 and format(L["%d metas en marcha."], metas) or L["Ponte una meta: un pez, capturas, tiempo o valor."], alClic = function() M.Metas.Alternar(true) end },
		{ icono = "ic-raros", titulo = L["Logros de pesca"], texto = format(L["%d de %d logrados."], hechos, #M.LOGROS), alClic = abrir("logros") },
	}
end

---------------------------------------------------------------------------
-- 3. Los ajustes
---------------------------------------------------------------------------
local function activa() return M.Opt("activo") and true or false end
local function hijaDe(padre) return function() return M.Opt("activo") and M.Opt(padre) and true or false end end

local function interruptor(clave)
	return function(fila) return K.Interruptor(fila, { clave = ID .. "." .. clave }) end
end

local function deslizador(clave, a, b, paso, formato, alCambiar)
	return function(fila)
		local d = K.Deslizador(fila, { min = a, max = b, paso = paso, clave = ID .. "." .. clave, formato = formato, alCambiar = alCambiar })
		d.alfaAnchoFila = 220
		return d
	end
end

local function desplegable(clave, opciones, alCambiar)
	return function(fila)
		return K.Desplegable(fila, { clave = ID .. "." .. clave, opciones = type(opciones) == "function" and opciones() or opciones, ancho = 200, alCambiar = alCambiar })
	end
end

local function opcionesCebo()
	local op = { { valor = 0, texto = L["El mejor que tengas"] } }
	local ids = {}
	for id in pairs(M.CEBOS) do ids[#ids + 1] = id end
	table.sort(ids, function(a, b) return M.CEBOS[a].bono < M.CEBOS[b].bono end)
	for _, id in ipairs(ids) do
		op[#op + 1] = { valor = id, texto = format(L["%s (+%d)"], (M.V and M.V.NombreObjeto(id)) or tostring(id), M.CEBOS[id].bono) }
	end
	return op
end

local function opcionesSonido()
	local op = {}
	for _, s in ipairs(M.SONIDOS) do op[#op + 1] = { valor = s.id, texto = s.nombre } end
	return op
end

-- "Avanzado" (las ranuras que no se cambian) abierto: lo pediste en esta
-- sesión o ya tienes alguna excluida (así la ves).
function M.VerExcluir()
	if M.verExcluir ~= nil then return M.verExcluir end
	local t = N.Get(ID, "excluir")
	if type(t) == "table" then
		for _, v in pairs(t) do if v == true then return true end end
	end
	return false
end

local function grupos(ui, padre)
	local g = {}
	local tecla = K.GrupoAjustes(padre, { titulo = L["Tecla y modo pesca"] })
	tecla:Fila({ titulo = L["Usar la pesca de Alfa"], control = interruptor("activo"),
		texto = L["Apágalo si no quieres que Alfa toque tus teclas, tu equipo ni tus ajustes al pescar."] })
	tecla:Fila({ titulo = L["Tecla del modo pesca"], activa = activa,
		control = function(fila) ui.tecla = controlTecla(fila, "tecla") return ui.tecla end,
		texto = L["Con el modo pesca abierto, esta tecla lo hace todo: equipo, cebo, lanzar y recoger. Al cerrarlo vuelve a ser la de siempre."] })
	tecla:Fila({ titulo = L["Mayús+Espacio sigue saltando"], control = interruptor("saltoMayus"), hija = true, activa = activa,
		texto = L["Con la tecla en Espacio, Mayús+Espacio salta mientras el modo está abierto."] })
	tecla:Fila({ titulo = L["Al moverte, la tecla vuelve a la normal"], control = interruptor("saltarAlMoverse"), hija = true, activa = activa,
		texto = L["Mientras caminas o corres, tu tecla hace lo de siempre (con Espacio, saltar)."] })
	tecla:Fila({ titulo = L["Tecla para volver a lanzar"], activa = activa,
		control = function(fila) return controlTecla(fila, "teclaRelanzar") end,
		texto = L["Suelta el lanzamiento de ahora y lanza otra vez, sin poner equipo ni cebo."] })
	tecla:Fila({ titulo = L["Abrir el modo al ponerte una caña"], control = interruptor("abrirConCana"), activa = activa })
	tecla:Fila({ titulo = L["Cerrar el modo al montar"], control = interruptor("cerrarAlMontar"), activa = activa })
	tecla:Fila({ titulo = L["Tecla fija para pescar"], activa = activa,
		control = function(fila) return K.Atajo(fila, { accion = M.ACCION, titulo = L["Tecla fija para pescar"] }) end,
		texto = L["Funciona también fuera del modo pesca. Está en el menú de atajos del juego, en Alfa."] })
	tecla:Fila({ titulo = L["Tecla para abrir o cerrar el modo"], activa = activa,
		control = function(fila) return K.Atajo(fila, { accion = "ALFA_PESCA_MODO", titulo = L["Tecla para abrir o cerrar el modo"] }) end })
	g[#g + 1] = tecla

	local equipo = K.GrupoAjustes(padre, { titulo = L["Equipo y cebos"] })
	equipo:Fila({ titulo = L["Ponerme el equipo de pesca"], control = interruptor("prepararEquipo"), activa = activa,
		texto = L["Tu tecla primero te pone la mejor caña y lo que tengas con bonificación de pesca (sombrero, guantes, botas, abalorios)."] })
	equipo:Fila({ titulo = L["Poner el cebo"], control = interruptor("prepararCebo"), activa = activa,
		texto = L["Si tu caña no tiene cebo, tu tecla pone el mejor que tengas (o el que prefieras) antes de lanzar."] })
	equipo:Fila({ titulo = L["Cebo preferido"], control = desplegable("ceboPreferido", opcionesCebo), hija = true, activa = hijaDe("prepararCebo") })
	equipo:Fila({ titulo = L["Volver a mi equipo al cerrar el modo"], control = interruptor("restaurarEquipo"), activa = activa,
		texto = L["Alfa recuerda lo que llevabas antes de ponerte lo de pesca y te lo vuelve a poner."] })
	-- Las cinco "No cambiar: ..." quedan plegadas bajo "Avanzado" (el Kit no
	-- pliega grupos: su interruptor las muestra; abiertas si ya excluiste alguna).
	ui.excluir = {}
	equipo:Fila({ titulo = L["Avanzado"], hija = true, activa = hijaDe("prepararEquipo"),
		texto = L["Las ranuras que tu tecla nunca cambia: cabeza, manos, pies, abalorios y las demás."],
		control = function(fila)
			return K.Interruptor(fila, { get = function() return M.VerExcluir() end,
				set = function(v) M.verExcluir = v and true or false if M.alCambiar then M.alCambiar() end end })
		end })
	for _, gr in ipairs(M.Eq.GRUPOS) do
		local id = gr.id
		ui.excluir[#ui.excluir + 1] = equipo:Fila({ titulo = format(L["No cambiar: %s"], gr.nombre), hija = true, activa = hijaDe("prepararEquipo"),
			control = function(fila)
				return K.Interruptor(fila, {
					get = function() local t = N.Get(ID, "excluir") return type(t) == "table" and t[id] == true end,
					set = function(v) Eq.SetExcluido(id, v) end,
				})
			end })
	end
	g[#g + 1] = equipo

	local barra = K.GrupoAjustes(padre, { titulo = L["La barra de pesca"] })
	barra:Fila({ titulo = L["Mostrar la barra en el modo pesca"], control = interruptor("barra"), activa = activa })
	barra:Fila({ titulo = L["Barra vertical"], control = interruptor("barraVertical"), hija = true, activa = hijaDe("barra") })
	barra:Fila({ titulo = L["Tamaño de la barra"], control = deslizador("barraEscala", 0.7, 1.5, 0.05, pct), hija = true, activa = hijaDe("barra") })
	barra:Fila({ titulo = L["Plegarla sola"], control = interruptor("barraPlegar"), hija = true, activa = hijaDe("barra"),
		texto = L["Sin el ratón encima, la barra guarda sus botones y deja solo lo que pasa."] })
	barra:Fila({ titulo = L["Vista mínima al lanzar"], control = interruptor("vistaMinima"), activa = activa,
		texto = L["Mientras el corcho está en el agua, una línea fina con el tiempo, tu habilidad y lo último que sacaste."] })
	barra:Fila({ titulo = L["Aviso con lo que sacas"], control = interruptor("resumen"), activa = activa })
	barra:Fila({ titulo = L["Ventana de metas"], control = interruptor("metasVentana"), activa = activa,
		texto = L["Con el modo pesca abierto y alguna meta, la ventanita de metas se ve sola."] })
	barra:Fila({ titulo = L["Ocultar la interfaz al pescar"], control = interruptor("ocultarUI"), activa = activa,
		texto = L["Mientras pescas se ve solo el mundo y la barra de pesca. Nunca en combate: al empezar uno, todo vuelve."] })
	barra:Fila({ titulo = L["Dejar el minimapa"], control = interruptor("uiMinimapa"), hija = true, activa = hijaDe("ocultarUI") })
	barra:Fila({ titulo = L["Dejar el chat"], control = interruptor("uiChat"), hija = true, activa = hijaDe("ocultarUI") })
	g[#g + 1] = barra

	local sonido = K.GrupoAjustes(padre, { titulo = L["Sonido y avisos"] })
	sonido:Fila({ titulo = L["Subir el sonido al pescar"], control = interruptor("sonido"), activa = activa,
		texto = L["Sube los efectos y baja la música y el ambiente para que oigas el chapoteo. Al terminar, todo vuelve a como estaba."] })
	sonido:Fila({ titulo = L["Volumen de los efectos"], control = deslizador("volumen", 0, 1, 0.05, pct), hija = true, activa = hijaDe("sonido") })
	sonido:Fila({ titulo = L["Música mientras pescas"], control = deslizador("musica", 0, 1, 0.05, pct), hija = true, activa = hijaDe("sonido") })
	sonido:Fila({ titulo = L["Ambiente mientras pescas"], control = deslizador("ambiente", 0, 1, 0.05, pct), hija = true, activa = hijaDe("sonido") })
	sonido:Fila({ titulo = L["Sonido con el juego en segundo plano"], control = interruptor("sonidoFondo"), activa = activa,
		texto = L["Mientras pescas, el juego se sigue oyendo aunque estés en otra ventana."] })
	sonido:Fila({ titulo = L["Avisos con sonido"], control = interruptor("alertas"), activa = activa,
		texto = L["Sonidos suaves del juego: nada de voces ni sonidos repetidos."] })
	sonido:Fila({ titulo = L["Sonido de los avisos"], hija = true, activa = hijaDe("alertas"),
		control = desplegable("alertaSonido", opcionesSonido, function(v)
			local s = M.SONIDO_DE[v]
			if s and PlaySound then pcall(PlaySound, s.kit, "Master") end
		end) })
	sonido:Fila({ titulo = L["Al sacar algo"], control = interruptor("alertaCaptura"), hija = true, activa = hijaDe("alertas") })
	sonido:Fila({ titulo = L["Cuando se escapa"], control = interruptor("alertaEscape"), hija = true, activa = hijaDe("alertas") })
	sonido:Fila({ titulo = L["Si te quedas sin lanzar"], control = interruptor("alertaInactivo"), hija = true, activa = hijaDe("alertas"),
		texto = L["Con el modo pesca abierto, un aviso suave para volver a lanzar."] })
	sonido:Fila({ titulo = L["Después de"], control = deslizador("inactivoSeg", 10, 120, 5, function(v) return format(L["%d s"], v) end), hija = true, activa = hijaDe("alertaInactivo") })
	g[#g + 1] = sonido

	local mientras = K.GrupoAjustes(padre, { titulo = L["Mientras pescas"] })
	mientras:Fila({ titulo = L["Recoger todo lo que pesques"], control = interruptor("autobotin"), activa = activa,
		texto = L["Toma el botín de la pesca enseguida, aunque tengas apagado el botín automático del juego."] })
	mientras:Fila({ titulo = L["Ocultar nombres al pescar"], control = interruptor("ocultarNombres"), activa = activa,
		texto = L["Esconde las placas y los nombres de los PNJ mientras pescas (los enemigos hostiles conservan su nombre), para ver y tocar mejor el corcho."] })
	mientras:Fila({ titulo = L["Ícono sobre el corcho"], control = interruptor("iconoCorcho"), activa = activa,
		texto = L["Muestra un ícono encima del corcho: así sabes que tu tecla lo va a recoger."] })
	g[#g + 1] = mientras

	local doble = K.GrupoAjustes(padre, { titulo = L["Doble clic derecho"] })
	doble:Fila({ titulo = L["Doble clic derecho para lanzar"], control = interruptor("dobleClic"), activa = activa,
		texto = L["Haz doble clic derecho en el mundo para lanzar la caña, sin usar la tecla. Nunca en combate ni en vuelo."] })
	doble:Fila({ titulo = L["Rapidez del doble clic"], control = deslizador("velocidad", 0.1, 0.8, 0.05, segundos), hija = true, activa = hijaDe("dobleClic"),
		texto = L["Tiempo máximo entre los dos clics. Súbelo si tus dobles clics no lanzan."] })
	doble:Fila({ titulo = L["También en montura"], control = interruptor("montado"), hija = true, activa = hijaDe("dobleClic") })
	doble:Fila({ titulo = L["Doble clic mientras pescas vuelve a lanzar"], control = interruptor("relanzar"), hija = true, activa = hijaDe("dobleClic"),
		texto = L["Encendido: el doble clic mientras pescas lanza de nuevo y, con Mayús, Ctrl o Alt, recoge. Apagado: al revés."] })
	g[#g + 1] = doble

	local datos = K.GrupoAjustes(padre, { titulo = L["Tus datos"] })
	datos:Fila({ titulo = L["Empezar otra sesión"], texto = L["La de ahora pasa a tus sesiones anteriores."],
		control = function(fila) return K.Boton(fila, L["Empezar otra"], function()
			local s = M.Sesion and M.Sesion()
			local habia = type(s) == "table" and ((tonumber(s.lanzamientos) or 0) + (tonumber(s.capturas) or 0)) > 0
			M.NuevaSesion()
			-- 1.2.2: se dice qué pasó (con la sesión vacía no cambiaba nada a la vista).
			N.Imprimir(habia and L["Guardaste tu sesión de pesca y empezaste otra."] or L["Tu sesión de pesca ya estaba vacía: la nueva empieza con tu primer lanzamiento."])
		end, { tipo = "secundario", tam = "chico" }) end })
	datos:Fila({ titulo = L["Borrar todo el registro"], texto = L["Sesiones, diario, logros y metas de este personaje. No se puede deshacer."],
		control = function(fila)
			return K.Boton(fila, L["Borrar"], function()
				K.Dialogo({ titulo = L["¿Borrar todo tu registro de pesca?"], texto = L["Se borran tus sesiones, tu diario, tus logros y tus metas de este personaje. Tu habilidad de pesca no cambia."],
					aceptar = L["Borrar todo"], peligro = true, alAceptar = function() M.BorrarTodo() end })
			end, { tipo = "peligro", tam = "chico" })
		end })
	g[#g + 1] = datos
	return g
end

---------------------------------------------------------------------------
-- La página
---------------------------------------------------------------------------
local function construir(view)
	local ui = {}
	local t = K.Tablero(view, { margen = N.MargenPagina(), accion = "estado", tituloOpciones = L["Pesca"], min = 250 })
	ui.ajustes = grupos(ui, t.Extra)
	for i, g in ipairs(ui.ajustes) do t:AgregarBloque(g, { espacio = i == 1 and K.ESP.xl or K.ESP.l }) end
	K.EnPagina(view, t, function()
		t:SetAccion(estado(ui))
		t:SetOpciones(accesos(), L["Tu pesca"])
		local ver = M.VerExcluir()
		for _, f in ipairs(ui.excluir or {}) do K.Mostrar(f, ver) end
		for _, g in ipairs(ui.ajustes) do g:Refrescar() end
	end)
	ui.tablero = t
	M.vista = view
end

M.alCambiar = function()
	local view = M.vista
	if view then N.RehacerPagina(view) end
end

---------------------------------------------------------------------------
-- Para la búsqueda de ajustes de la ventana de Alfa (la página es propia):
-- los mismos ajustes de arriba, con su texto y atenuados igual. Las teclas
-- (se capturan con un clic), los atajos del juego, "Avanzado" (solo pliega
-- filas) y los botones de tus datos no van.
---------------------------------------------------------------------------
local function clave(k) return ID .. "." .. k end
local function apagado() return not activa() end
local function apagadoDe(padre) local f = hijaDe(padre) return function() return not f() end end

local function toggle(k, label, help, hija, search)
	return { kind = "toggle", key = clave(k), label = label, help = help, search = search,
		child = hija and true or nil, disabled = hija and apagadoDe(hija) or apagado }
end

local function slider(k, label, a, b, paso, formato, hija, help, search)
	return { kind = "slider", key = clave(k), label = label, help = help, search = search, min = a, max = b, step = paso, format = formato,
		child = true, disabled = apagadoDe(hija) }
end

local function opciones(fn)
	return function()
		local t = {}
		for i, o in ipairs(fn()) do t[i] = { value = o.valor, label = o.texto } end
		return t
	end
end

local CONTROLES = {
	{ kind = "toggle", key = clave("activo"), label = L["Usar la pesca de Alfa"],
		help = L["Apágalo si no quieres que Alfa toque tus teclas, tu equipo ni tus ajustes al pescar."], search = "fishing, enable fishing, pesca" },
	toggle("saltoMayus", L["Mayús+Espacio sigue saltando"], L["Con la tecla en Espacio, Mayús+Espacio salta mientras el modo está abierto."], nil, "shift space, jump"),
	toggle("saltarAlMoverse", L["Al moverte, la tecla vuelve a la normal"], L["Mientras caminas o corres, tu tecla hace lo de siempre (con Espacio, saltar)."], nil, "moving, jump, key"),
	toggle("abrirConCana", L["Abrir el modo al ponerte una caña"], nil, nil, "fishing pole, fishing mode"),
	toggle("cerrarAlMontar", L["Cerrar el modo al montar"], nil, nil, "mount, fishing mode"),
	toggle("prepararEquipo", L["Ponerme el equipo de pesca"], L["Tu tecla primero te pone la mejor caña y lo que tengas con bonificación de pesca (sombrero, guantes, botas, abalorios)."], nil, "fishing gear, pole, equip"),
	toggle("prepararCebo", L["Poner el cebo"], L["Si tu caña no tiene cebo, tu tecla pone el mejor que tengas (o el que prefieras) antes de lanzar."], nil, "lure, bait"),
	{ kind = "dropdown", key = clave("ceboPreferido"), label = L["Cebo preferido"], choices = opciones(opcionesCebo),
		child = true, disabled = apagadoDe("prepararCebo"), search = "lure, bait" },
	toggle("restaurarEquipo", L["Volver a mi equipo al cerrar el modo"], L["Alfa recuerda lo que llevabas antes de ponerte lo de pesca y te lo vuelve a poner."], nil, "swap back, gear"),
	-- 1.2.5: lo de la barra y la vista, también en el buscador de Ajustes.
	toggle("barra", L["Mostrar la barra en el modo pesca"], nil, nil, "barra, bar, fishing bar"),
	toggle("barraVertical", L["Barra vertical"], nil, nil, "barra, vertical, bar"),
	toggle("barraPlegar", L["Plegarla sola"], nil, nil, "barra, plegar, collapse, bar"),
	toggle("vistaMinima", L["Vista mínima al lanzar"], nil, nil, "vista, minimal, cast"),
	toggle("resumen", L["Aviso con lo que sacas"], nil, nil, "aviso, botín, loot, catch"),
	toggle("metasVentana", L["Ventana de metas"], nil, nil, "metas, goals, window"),
	toggle("ocultarUI", L["Ocultar la interfaz al pescar"], nil, nil, "interfaz, ocultar, hide ui"),
}
-- "No cambiar: ..." de cada grupo de ranuras (no es un ajuste suelto: va en la tabla excluir).
for _, gr in ipairs(Eq.GRUPOS) do
	local id = gr.id
	CONTROLES[#CONTROLES + 1] = { kind = "toggle", label = format(L["No cambiar: %s"], gr.nombre), child = true,
		disabled = apagadoDe("prepararEquipo"), search = "gear slot, exclude",
		get = function() local t = N.Get(ID, "excluir") return type(t) == "table" and t[id] == true end,
		set = function(v) Eq.SetExcluido(id, v) end }
end
for _, c in ipairs({
	toggle("barra", L["Mostrar la barra en el modo pesca"], nil, nil, "fishing bar"),
	toggle("barraVertical", L["Barra vertical"], nil, "barra", "vertical bar"),
	slider("barraEscala", L["Tamaño de la barra"], 0.7, 1.5, 0.05, pct, "barra", nil, "bar size, scale"),
	toggle("barraPlegar", L["Plegarla sola"], L["Sin el ratón encima, la barra guarda sus botones y deja solo lo que pasa."], "barra", "collapse bar"),
	toggle("vistaMinima", L["Vista mínima al lanzar"], L["Mientras el corcho está en el agua, una línea fina con el tiempo, tu habilidad y lo último que sacaste."], nil, "minimal view, bobber"),
	toggle("resumen", L["Aviso con lo que sacas"], nil, nil, "catch toast, loot"),
	toggle("metasVentana", L["Ventana de metas"], L["Con el modo pesca abierto y alguna meta, la ventanita de metas se ve sola."], nil, "goals window"),
	toggle("ocultarUI", L["Ocultar la interfaz al pescar"], L["Mientras pescas se ve solo el mundo y la barra de pesca. Nunca en combate: al empezar uno, todo vuelve."], nil, "hide ui, hide interface"),
	toggle("uiMinimapa", L["Dejar el minimapa"], nil, "ocultarUI", "minimap"),
	toggle("uiChat", L["Dejar el chat"], nil, "ocultarUI", "chat"),
	toggle("sonido", L["Subir el sonido al pescar"], L["Sube los efectos y baja la música y el ambiente para que oigas el chapoteo. Al terminar, todo vuelve a como estaba."], nil, "sound, volume, splash"),
	slider("volumen", L["Volumen de los efectos"], 0, 1, 0.05, pct, "sonido", nil, "sound effects volume"),
	slider("musica", L["Música mientras pescas"], 0, 1, 0.05, pct, "sonido", nil, "music volume"),
	slider("ambiente", L["Ambiente mientras pescas"], 0, 1, 0.05, pct, "sonido", nil, "ambience volume"),
	toggle("sonidoFondo", L["Sonido con el juego en segundo plano"], L["Mientras pescas, el juego se sigue oyendo aunque estés en otra ventana."], nil, "background sound"),
	toggle("alertas", L["Avisos con sonido"], L["Sonidos suaves del juego: nada de voces ni sonidos repetidos."], nil, "alerts, sound"),
	{ kind = "dropdown", key = clave("alertaSonido"), label = L["Sonido de los avisos"], choices = opciones(opcionesSonido),
		child = true, disabled = apagadoDe("alertas"), search = "alert sound",
		get = function() return N.Get(ID, "alertaSonido") end,
		set = function(v)
			N.Set(ID, "alertaSonido", v)
			local s = M.SONIDO_DE[v]
			if s and PlaySound then pcall(PlaySound, s.kit, "Master") end
		end },
	toggle("alertaCaptura", L["Al sacar algo"], nil, "alertas", "catch alert"),
	toggle("alertaEscape", L["Cuando se escapa"], nil, "alertas", "escaped, missed"),
	toggle("alertaInactivo", L["Si te quedas sin lanzar"], L["Con el modo pesca abierto, un aviso suave para volver a lanzar."], "alertas", "idle alert"),
	slider("inactivoSeg", L["Después de"], 10, 120, 5, function(v) return format(L["%d s"], v) end, "alertaInactivo", nil, "idle seconds"),
	toggle("autobotin", L["Recoger todo lo que pesques"], L["Toma el botín de la pesca enseguida, aunque tengas apagado el botín automático del juego."], nil, "auto loot"),
	toggle("ocultarNombres", L["Ocultar nombres al pescar"], L["Esconde las placas y los nombres de los PNJ mientras pescas (los enemigos hostiles conservan su nombre), para ver y tocar mejor el corcho."], nil, "hide names, nameplates"),
	toggle("iconoCorcho", L["Ícono sobre el corcho"], L["Muestra un ícono encima del corcho: así sabes que tu tecla lo va a recoger."], nil, "bobber icon"),
	toggle("dobleClic", L["Doble clic derecho para lanzar"], L["Haz doble clic derecho en el mundo para lanzar la caña, sin usar la tecla. Nunca en combate ni en vuelo."], nil, "double click, right click, cast"),
	slider("velocidad", L["Rapidez del doble clic"], 0.1, 0.8, 0.05, segundos, "dobleClic", L["Tiempo máximo entre los dos clics. Súbelo si tus dobles clics no lanzan."], "double click speed"),
	toggle("montado", L["También en montura"], nil, "dobleClic", "mounted"),
	toggle("relanzar", L["Doble clic mientras pescas vuelve a lanzar"], L["Encendido: el doble clic mientras pescas lanza de nuevo y, con Mayús, Ctrl o Alt, recoge. Apagado: al revés."], "dobleClic", "recast"),
}) do CONTROLES[#CONTROLES + 1] = c end

N.Modulo({
	id = ID, nombre = L["Pesca"], icono = "ic-pesca", orden = 55,
	-- 1.3.6: subtítulo corto (la ventana esconde los de más de 60 letras).
	subtitulo = L["Una tecla para pescar, con diario, guía y cocina."],
	comando = "pesca",
	ajustes = M.AJUSTES,
	controles = CONTROLES,
	construir = construir,
})

-- /alfa pesca abre o cierra el modo; con algo más, lo dice M.Comando.
A.RegisterCommand("pesca", M.Comando, L["abre o cierra el modo pesca (también: ajustes, diario, guia, cocina, metas, estadisticas, logros, on, off, reiniciar)"])
