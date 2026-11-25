-- Alfa - Bienvenida: la página "Estilo y sonido" en Ajustes (toxic3000 / La
-- Jauría). GPL-3.0.
--
-- Un Tablero del Kit:
--   1. tu estilo de ahora, con "Mi configuración" (el asistente, en su resumen);
--   2. los estilos para cambiar en un clic (y, salvo en Alfa y Clásico WoW,
--      el acento);
--   3. el sonido: el aullido al abrir Alfa y un botón para escucharlo;
--   4. (1.3.0) para leer mejor (letra grande, colores para daltonismo,
--      «¿Qué es esto?»), la pantalla limpia y tus atajos (Teclas.lua);
--   5. la configuración, lo nuevo de la versión y "Reportar".

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID
local ESP = K.ESP

local format = string.format

local function estado()
	local e = K.DatosEstilo()
	return {
		icono = e and e.icono or "ic-apariencia", tono = "acento", sobre = L["Tu estilo"],
		titulo = K.NombreEstilo(K.Estilo()) or "",
		texto = e and L[e.texto] or nil,
		accion = { texto = L["Mi configuración"], icono = "ic-ajustes", alClic = function() M.Abrir("pedido", "asistente") end },
		-- La letra, su tamaño, los bordes y la flecha siguen en Ajustes > Apariencia (del motor).
		-- 1.3.6: el botón dice qué hay detrás y que es para quien quiere afinar.
		secundaria = { texto = L["Colores, letra y ventanas (avanzado)"], alClic = function() N.Abrir("appearance") end },
	}
end

local function bloqueEstilos(ui, padre)
	local b = K.Pila(padre, { espacio = ESP.m })
	b.Seccion = b:Agregar(K.Seccion(b, L["Elige tu estilo"]))
	b.Selector = b:Agregar(K.SelectorEstilo(b, { min = 220, alCambiar = function() M.alCambiar() end }))
	b.SecAcento = b:Agregar(K.Seccion(b, L["Tu color de acento"]), { espacio = ESP.l })
	b.Acento = b:Agregar(K.SelectorAcento(b, {}), { espacio = ESP.s })
	function b:Refrescar()
		-- El acento se elige en Cristal y en los estilos de la casa con el suyo (1.3.0).
		local conAcento = K.EligeAcento()
		K.Mostrar(self.SecAcento, conAcento)
		K.Mostrar(self.Acento, conAcento)
		self.Selector:Leer()
		self.Acento:Leer()
	end
	return b
end

local function grupos(ui, padre)
	local sonido = K.GrupoAjustes(padre, { titulo = L["Sonido"] })
	sonido:Fila({ titulo = L["Aullido al abrir Alfa"],
		texto = L["Un aullido de lobo, del propio juego, la primera vez que abres Alfa en cada sesión."],
		control = function(fila) return K.Interruptor(fila, { clave = ID .. ".aullido" }) end })
	sonido:Fila({ titulo = L["El lobo te recibe al entrar"],
		texto = L["Cada vez que entras al juego, la intro del lobo y la luna te da la bienvenida. Un clic o Esc la saltan."],
		control = function(fila) return K.Interruptor(fila, { clave = ID .. ".introSiempre" }) end })
	sonido:Fila({ titulo = L["Anuncios animados"],
		texto = L["Zonas, barcos, raros y mazmorras con un anuncio grande y animado, como la intro, en vez de una tarjeta. Cada tipo se elige abajo, en Anuncios."],
		control = function(fila) return K.Interruptor(fila, { clave = ID .. ".anuncios" }) end })
	-- 1.3.5: para equipos modestos (Alfa_Nucleo/Reloj.lua, N.Ligero).
	sonido:Fila({ titulo = L["Modo ligero"],
		texto = L["Para computadoras modestas: lo que Alfa revisa en segundo plano va a la mitad de velocidad, Lya se anima más despacio y los anuncios salen como tarjeta, sin animación."],
		control = function(fila) return K.Interruptor(fila, { clave = "nucleo.ligero" }) end })
	sonido:Fila({ titulo = L["Escuchar el aullido"], texto = L["Suena ahora, aunque el aullido esté apagado."],
		control = function(fila) return K.Boton(fila, L["Escuchar"], function() M.Aullar(true) end, { tipo = "secundario", icono = "ic-lobo" }) end })
	-- 1.3.7: «Sonidos de Alfa» y No molestar (Alfa_Nucleo/Momentos.lua).
	if N.FilasMomentos then N.FilasMomentos(sonido) end
	-- 1.3.9 (67): el Centro de avisos (Momentos.lua): cada tipo con su interruptor y «Probar».
	local centro = N.GrupoCentroAvisos and N.GrupoCentroAvisos(padre) or nil

	-- 1.3.0: para leer mejor (Kit/Tokens.lua, Kit/Ayuda.lua).
	local leer = K.GrupoAjustes(padre, { titulo = L["Para leer mejor"] })
	leer:Fila({ titulo = L["Letra más grande"],
		texto = L["Todo el texto de Alfa un poco más grande, en cada ventana. Se suma al tamaño de Ajustes > Apariencia."],
		control = function(fila) return K.Interruptor(fila, { clave = "nucleo.letraGrande" }) end })
	-- 1.4.0 (66): alto contraste (Kit/Tokens.lua, un retoque del tema).
	leer:Fila({ titulo = L["Alto contraste"],
		texto = L["Texto blanco, fondos opacos y bordes marcados en todas las ventanas de Alfa, en cualquier estilo. Se suma a la letra grande y a los colores para daltonismo."],
		control = function(fila) return K.Interruptor(fila, { clave = "nucleo.altoContraste" }) end })
	leer:Fila({ titulo = L["Colores para daltonismo"],
		texto = L["Lo bueno en azul, los avisos en amarillo y el peligro en naranja, y los perjuicios con colores que se distinguen sin el rojo y el verde."],
		control = function(fila) return K.Interruptor(fila, { clave = "nucleo.daltonico" }) end })
	leer:Fila({ titulo = L["«¿Qué es esto?»"],
		texto = L["Deja esta tecla abajo y pasa el ratón por cualquier cosa de Alfa: te digo para qué sirve."],
		control = function(fila) return K.Desplegable(fila, { opciones = M.OPCIONES_AYUDA(), clave = "nucleo.ayudaTecla", ancho = 150 }) end })
	-- 1.3.8: la escala de las ventanas de Alfa (Kit/Estilos.lua).
	leer:Fila({ titulo = L["Tamaño de las ventanas de Alfa"],
		texto = L["Agranda o achica las ventanas de Alfa enteras, aparte de la escala del juego. La ventana principal de Alfa tiene la suya en Apariencia."],
		control = function(fila)
			local d = K.Deslizador(fila, { min = 0.8, max = 1.3, paso = 0.05, clave = "nucleo.escalaVentanas",
				formato = function(v) return ("%d %%"):format(math.floor((v or 1) * 100 + 0.5)) end })
			d.alfaAnchoFila = 220
			return d
		end })
	-- 1.3.8: el adorno de temporada (Kit/Estilos.lua).
	leer:Fila({ titulo = L["Adornos de temporada"],
		texto = L["En Noche de Brujas, Fiesta de Invierno, Amor en el aire y el Fuego del Solsticio, un detalle chiquito de la fiesta en cada ventana de Alfa."],
		control = function(fila) return K.Interruptor(fila, { clave = "nucleo.temporada" }) end })
	-- 1.3.9: la temática por bando (Kit/Bando.lua).
	if N.FilasBando then N.FilasBando(leer) end
	-- 1.3.9 (53, 55): la franja de la primera vez en cada página y el Modo aprendiz.
	leer:Fila({ titulo = L["Para qué sirve cada página"],
		texto = L["La primera vez que abres una página, una línea abajo te dice para qué sirve, con «Enséñame» para un recorrido de 3 pasos."],
		control = function(fila) return K.Interruptor(fila, { clave = ID .. ".primeraVez" }) end })
	leer:Fila({ titulo = L["Modo aprendiz"],
		texto = L["La primera vez que sale cada aviso, Lya te cuenta de dónde viene y dónde se apaga."],
		control = function(fila) return K.Interruptor(fila, { clave = ID .. ".aprendiz" }) end })
	-- 1.3.6: un interruptor que dice si el modo ayuda está prendido (Kit/Ayuda.lua).
	leer:Fila({ titulo = L["Modo ayuda"], hija = true,
		texto = L["Sin tener una tecla abajo: lo prendes o lo apagas con su atajo, o aquí."],
		control = function(fila) return K.Interruptor(fila, {
			get = function() return K.ModoAyuda and K.ModoAyuda() or false end,
			set = function(v) if K.AlternarAyuda then K.AlternarAyuda(v and true or false) end end }) end })

	-- 1.3.1: acomodar con el ratón lo de Alfa en tu pantalla (Acomodar.lua).
	local acomodar = K.GrupoAjustes(padre, { titulo = L["Acomodar la pantalla"] })
	acomodar:Fila({ titulo = L["Mueve lo de Alfa con el ratón"],
		texto = L["La flecha y sus placas, tu guía, los avisos, los anuncios, Lya, la pesca, Combate, Curación y más: los arrastras a donde quieras, con imán a la rejilla. También con /alfa acomodar."],
		control = function(fila) return K.Boton(fila, L["Acomodar [pantalla]"], function()
			if N.CerrarVentana then N.CerrarVentana() elseif A.UI and A.UI.Options and A.UI.Options.frame then A.UI.Options.frame:Hide() end
			if M.Acomodar then M.Acomodar.Abrir() end
		end, { tipo = "secundario", icono = "ic-ventana" }) end })
	-- 1.4.0 (78): moverlo directo, por personaje y las placas de la flecha (Kit/Movible.lua).
	acomodar:Fila({ titulo = L["Mayús + arrastrar"],
		texto = L["Fuera de combate, con Mayús apretada arrastras cualquier cosa de Alfa sin entrar a «Acomodar la pantalla»."],
		control = function(fila) return K.Interruptor(fila, { clave = "acomodar.conMayus" }) end })
	acomodar:Fila({ titulo = L["Cada personaje con su acomodo"],
		texto = L["Lo que acomodes se guarda solo para este personaje. La flecha ya recuerda su lugar en cada uno."],
		control = function(fila) return K.Interruptor(fila, { clave = "acomodar.porPersonaje" }) end })
	acomodar:Fila({ titulo = L["Las placas van con la flecha"],
		texto = L["«Llegaste», «Usa tu piedra de hogar» y los viajes salen donde está la flecha. Apágalo para ponerlas en otro lugar."],
		control = function(fila) return K.Interruptor(fila, {
			get = function() local p = A.Get("nav.placasPos") return not (type(p) == "table" and p.point) end,
			set = function(v)
				if v then A.Set("nav.placasPos", nil) return end
				local Nv = rawget(A, "Nav")
				local Ar = type(Nv) == "table" and rawget(Nv, "arrow")
				if type(Ar) == "table" and Ar.SepararPlacas then Ar.SepararPlacas() end
			end }) end })

	-- 1.3.0: la pantalla limpia (Alfa_Nucleo/Limpia.lua).
	local Pl = N.PantallaLimpia
	local limpia = K.GrupoAjustes(padre, { titulo = L["Pantalla limpia"] })
	limpia:Fila({ titulo = L["Tu tecla de pantalla limpia"],
		texto = L["Con una tecla escondes lo del juego que no necesitas y quedan Alfa, tu rastreador y Lya. Otra pulsación lo devuelve todo."],
		control = function(fila) return K.Atajo(fila, { accion = "ALFA_PANTALLA_LIMPIA", titulo = L["Pantalla limpia"], ancho = 150 }) end })
	limpia:Fila({ titulo = L["Probar la pantalla limpia"], texto = L["También con /alfa limpia."],
		control = function(fila) return K.Boton(fila, L["Probar"], function() if Pl then Pl.Alternar() end end, { tipo = "secundario", icono = "ic-lobo", tecla = "ALFA_PANTALLA_LIMPIA" }) end })
	-- 1.3.8: el modo Zen (Zen.lua).
	limpia:Fila({ titulo = L["Modo Zen"],
		texto = L["Una tecla esconde todo Alfa menos la flecha, para explorar o tomar capturas. Otra pulsación lo devuelve. También con /alfa zen."],
		control = function(fila) return K.Atajo(fila, { accion = "ALFA_ZEN", titulo = L["Modo Zen"], ancho = 150 }) end })
	limpia:Fila({ titulo = L["Probar el modo Zen"], hija = true, texto = L["Para volver: otra vez tu tecla, /alfa zen o el lobo del minimapa."],
		control = function(fila) return K.Boton(fila, L["Probar"], function()
			if N.CerrarVentana then N.CerrarVentana() end
			if M.Zen then M.Zen.Alternar(true) end
		end, { tipo = "secundario", icono = "ic-flecha", tecla = "ALFA_ZEN" }) end })
	for _, g in ipairs(Pl and Pl.GRUPOS or {}) do
		limpia:Fila({ titulo = K.L[g.nombre], hija = true,
			texto = (g.id == "Barras" or g.id == "Retratos") and L["Si estás en combate, espera a que termine."] or nil,
			control = function(fila) return K.Interruptor(fila, { clave = "nucleo.limpia" .. g.id }) end })
	end

	-- 1.3.7: la ventana de Alfa (Ventana.lua).
	local vent = K.GrupoAjustes(padre, { titulo = L["La ventana de Alfa"] })
	vent:Fila({ titulo = L["Atajos de teclado en la ventana"],
		texto = L["Con la ventana abierta: Ctrl y un número cambian de sección, Ctrl+← y Ctrl+→ de página, Ctrl+F busca y Alt+← vuelve a donde estabas."],
		control = function(fila) return K.Interruptor(fila, { clave = ID .. ".atajosVentana" }) end })
	vent:Fila({ titulo = L["Recordar su alto y su lugar"],
		texto = L["La esquina de abajo a la derecha la hace más alta. Alfa la abre donde la dejaste y del alto que la dejaste."],
		control = function(fila) return K.Interruptor(fila, { clave = ID .. ".recordarVentana" }) end })
	vent:Fila({ titulo = L["La ventana como venía"], hija = true,
		texto = L["Vuelve a su alto de siempre, en el centro de la pantalla."],
		control = function(fila) return K.Boton(fila, L["Devolverla"], function()
			if M.Ventana then M.Ventana.Restablecer() end
		end, { tipo = "secundario", icono = "ic-ventana" }) end })

	-- 1.3.0: tus atajos (Teclas.lua).
	local atajos = K.GrupoAjustes(padre, { titulo = L["Tus atajos"] })
	atajos:Fila({ titulo = L["Tus atajos de Alfa"],
		texto = L["Todas las teclas de Alfa en un lugar, para cambiarlas ahí mismo. También con /alfa teclas."],
		control = function(fila) return K.Boton(fila, L["Abrir"], function() M.Teclas.Abrir() end, { tipo = "secundario", icono = "ic-ajustes" }) end })

	-- 1.3.6: la ayuda va hasta arriba de la página (construir la pone antes de los estilos).
	local bienvenida = K.GrupoAjustes(padre, { titulo = L["Configuración y ayuda"] })
	-- 1.2.9: Alfa sencillo o completo (Alfa_Nucleo/Modo.lua).
	-- 1.3.6: dice «Mundo», como la página.
	bienvenida:Fila({ titulo = L["Cómo ves Alfa"], texto = L["Sencillo: solo Hoy, Ruta, Mundo, Bolsas, Talentos y Lya a la vista, y menos avisos. Completo: todo Alfa. Lo demás sigue funcionando."],
		control = function(fila) return K.Desplegable(fila, { opciones = M.OPCIONES_MODO(), clave = ID .. ".modo", ancho = 150 }) end })
	bienvenida:Fila({ titulo = L["Tu configuración de Alfa"],
		texto = L["El idioma, el estilo, lo que Alfa hace sola por ti y La Jauría, con «Cambiar» en cada cosa. También con /alfa bienvenida."],
		control = function(fila) return K.Boton(fila, L["Abrir"], function() M.Abrir("pedido", "asistente") end, { tipo = "secundario" }) end })
	bienvenida:Fila({ titulo = L["El recorrido por Alfa"],
		-- 1.3.6: el recorrido ya no tiene 5 pasos fijos (depende de lo que tengas a la vista).
		texto = L["Lya te enseña la ventana de Alfa paso a paso. También con /alfa recorrido."],
		control = function(fila) return K.Boton(fila, L["Ver"], function() if M.Recorrido then M.Recorrido.Empezar() end end, { tipo = "secundario", icono = "ic-lobo" }) end })
	bienvenida:Fila({ titulo = L["Reportar un error, una mejora o un comentario"],
		texto = L["Cuéntanos qué pasó y dale «Enviar»: le llega directo al desarrollador de Alfa. También con /alfa reportar."],
		control = function(fila) return K.Boton(fila, L["Reportar"], function() M.AbrirReporte() end, { tipo = "secundario" }) end })
	bienvenida:Fila({ titulo = L["Revisar Alfa"],
		texto = L["Busca addons que chocan con Alfa, partes apagadas y ajustes raros, con el arreglo a un clic. También con /alfa diagnostico."],
		control = function(fila) return K.Boton(fila, L["Revisar"], function() M.Diagnostico.Abrir() end, { tipo = "secundario", icono = "ic-buscar" }) end })
	bienvenida:Fila({ titulo = format(L["Lo nuevo en Alfa %s"], M.VERSION_ALFA),
		texto = L["La bienvenida con las novedades de esta versión."],
		control = function(fila) return K.Boton(fila, L["Ver"], function()
			if M.AbrirNotas and M.AbrirNotas() then return end
			M.Abrir("pedido", "portada")
		end, { tipo = "secundario" }) end })
	-- 1.2.7: tus perfiles y la copia de tus ajustes (Perfiles.lua).
	local Pf = M.Perfiles
	local perfiles = K.GrupoAjustes(padre, { titulo = L["Tus perfiles"] })
	local function elegir(boton, alElegir)
		local ops = {}
		for _, n in ipairs(Pf.Lista()) do ops[#ops + 1] = { valor = n, texto = n, icono = "ic-ajustes" } end
		if #ops == 0 then
			K.Aviso({ titulo = L["Aún no tienes perfiles"], texto = L["Guarda tu configuración como perfil primero."], icono = "ic-info" })
			return
		end
		K.Menu(boton, ops, nil, alElegir, 240)
	end
	perfiles:Fila({ titulo = L["Guardar mi configuración"],
		texto = L["Guarda cómo tienes Alfa ahora con el nombre de tu personaje, para volver a ella con un clic. Útil si juegas con varios personajes."],
		control = function(fila) return K.Boton(fila, L["Guardar"], function()
			local n = Pf.NombreSugerido()
			Pf.Guardar(n)
			K.Aviso({ titulo = L["Perfil guardado"], texto = format(L["Tu configuración quedó guardada como «%s»."], n), icono = "ic-exito" })
		end, { tipo = "secundario", icono = "ic-exito" }) end })
	perfiles:Fila({ titulo = L["Usar un perfil"],
		texto = L["Pone los ajustes de un perfil que guardaste. Algunas cosas se ven completas al recargar."],
		control = function(fila)
			local b
			b = K.Boton(fila, L["Elegir"], function()
				elegir(b, function(n)
					if Pf.Aplicar(n) then
						K.Aviso({ titulo = format(L["Usas el perfil «%s»"], n), texto = L["Algunas cosas se ven completas al recargar."], icono = "ic-exito",
							accion = { texto = L["Recargar ahora"], alClic = function() if ReloadUI then ReloadUI() end end } })
					end
				end)
			end, { tipo = "secundario" })
			return b
		end })
	perfiles:Fila({ titulo = L["Borrar un perfil"], texto = L["Quita un perfil que ya no usas. Tus ajustes de ahora no cambian."],
		control = function(fila)
			local b
			b = K.Boton(fila, L["Borrar"], function()
				elegir(b, function(n) Pf.Borrar(n) K.Aviso({ titulo = format(L["Borraste «%s»"], n), icono = "ic-cerrar" }) end)
			end, { tipo = "secundario" })
			return b
		end })
	perfiles:Fila({ titulo = L["Exportar mis ajustes"], texto = L["Tu configuración como texto: guárdalo de respaldo o pásaselo a la manada."],
		control = function(fila) return K.Boton(fila, L["Exportar"], function() Pf.MostrarExportar() end, { tipo = "secundario" }) end })
	perfiles:Fila({ titulo = L["Importar ajustes"], texto = L["Pega el texto de «Exportar» para traer esa configuración. Lo de ahora queda guardado como perfil por si acaso."],
		control = function(fila) return K.Boton(fila, L["Importar"], function() Pf.AbrirImportar() end, { tipo = "secundario" }) end })
	perfiles:Fila({ titulo = L["Memoria de Alfa"], texto = L["Cuánta memoria usa cada parte de Alfa ahora, y suelta la que ya no ocupa. También con /alfa rendimiento."],
		control = function(fila) return K.Boton(fila, L["Revisar"], function() Pf.Rendimiento() end, { tipo = "secundario" }) end })
	-- 1.2.9: los respaldos de cada semana (Respaldos.lua y Alfa_Nucleo/Respaldos.lua).
	local Rs = M.Respaldos
	local respaldos = K.GrupoAjustes(padre, { titulo = L["Respaldos"] })
	respaldos:Fila({ titulo = L["Respaldo de tus ajustes"],
		texto = L["Alfa guarda una copia de tus ajustes y perfiles cada semana y antes de cada actualización. Quedan las últimas 3."],
		control = function(fila) return K.Boton(fila, L["Respaldar ahora"], function() Rs.Ahora() end, { tipo = "secundario", icono = "ic-exito" }) end })
	local filasRespaldo = {}
	for i = 1, 3 do
		filasRespaldo[i] = respaldos:Fila({ titulo = "", texto = "",
			control = function(fila) return K.Boton(fila, L["Restaurar"], function() Rs.Restaurar(fila.alfaIndice) end, { tipo = "secundario", icono = "ic-reloj" }) end })
	end
	local refrescarRespaldos = respaldos.Refrescar
	function respaldos:Refrescar()
		local lista = Rs.Lista()
		for i, fila in ipairs(filasRespaldo) do
			-- El más nuevo arriba.
			local j = #lista - i + 1
			local r = lista[j]
			fila.alfaIndice = j
			fila.alfaDatos.titulo = r and (i == 1 and L["El más reciente"] or format(L["Respaldo %d"], i)) or ""
			fila.alfaDatos.texto = r and Rs.Texto(r) or ""
			K.Mostrar(fila, r ~= nil)
		end
		refrescarRespaldos(self)
	end

	-- 1.2.9: los errores de Alfa que se atraparon (Alfa_Nucleo/Errores.lua).
	local errores = K.GrupoAjustes(padre, { titulo = L["Errores atrapados"] })
	local filaErrores = errores:Fila({ titulo = L["Errores de Alfa"], texto = "",
		control = function(fila) return K.Boton(fila, L["Copiar"], function() Rs.CopiarErrores() end, { tipo = "secundario" }) end })
	errores:Fila({ titulo = L["Borrar la lista"], texto = L["Empieza de cero, por ejemplo después de mandar tu reporte."],
		control = function(fila) return K.Boton(fila, L["Borrar"], function() Rs.BorrarErrores() end, { tipo = "secundario", icono = "ic-cerrar" }) end })
	local refrescarErrores = errores.Refrescar
	function errores:Refrescar()
		filaErrores.alfaDatos.texto = Rs.ResumenErrores() .. " " .. L["«Reportar» ya los lleva."]
		refrescarErrores(self)
	end
	-- 1.3.6: «Configuración y ayuda» primero.
	-- 1.3.7 anuncios: un interruptor y «Probar» por tipo (Alfa_Nucleo/Zonas.lua), después del sonido.
	-- 1.3.8: «Lo más usado» hasta arriba (Usados.lua; sin nada usado, no sale).
	local lista = {}
	if M.Usados then lista[1] = M.Usados.Grupo(padre) end
	lista[#lista + 1] = bienvenida
	lista.ayuda = bienvenida
	lista[#lista + 1] = sonido
	if N.GrupoAnuncios then lista[#lista + 1] = N.GrupoAnuncios(padre) end
	if centro then lista[#lista + 1] = centro end
	for _, g in ipairs({ leer, limpia, atajos, perfiles, respaldos, errores }) do lista[#lista + 1] = g end
	return lista
end

local function construir(view)
	local ui = {}
	local t = K.Tablero(view, { margen = N.MargenPagina(), accion = "estado" })
	-- 1.3.6: «Configuración y ayuda» (el recorrido, reportar, revisar) hasta
	-- arriba; luego los estilos y lo demás.
	local estilos = bloqueEstilos(ui, t.Extra)
	ui.grupos = grupos(ui, t.Extra)
	for i, g in ipairs(ui.grupos) do
		t:AgregarBloque(g, { espacio = i == 1 and ESP.xl or ESP.l })
		if g == ui.grupos.ayuda then ui.estilos = t:AgregarBloque(estilos, { espacio = ESP.xl }) end
	end
	K.EnPagina(view, t, function()
		t:SetAccion(estado())
		ui.estilos:Refrescar()
		for _, g in ipairs(ui.grupos) do g:Refrescar() end
	end)
	M.vista = view
end

-- Algo cambió (el estilo, el acento): la página se rehace si está a la vista.
function M.alCambiar()
	local view = M.vista
	if view then N.RehacerPagina(view) end
end
K.AlRepintar(function() M.alCambiar() end)

-- «¿Qué es esto?»: la tecla que se deja abajo (nucleo.ayudaTecla).
function M.OPCIONES_AYUDA()
	return {
		{ valor = "ALT", texto = L["Alt"] }, { valor = "CTRL", texto = L["Ctrl"] }, { valor = "SHIFT", texto = L["Mayús"] },
		{ valor = "NO", texto = L["Solo su atajo"] },
	}
end

-- Para la búsqueda de ajustes de la ventana de Alfa (la página es propia):
-- el aullido y los botones de arriba. El estilo y el acento no van: son
-- ui.skin, ui.accent y ui.classAccent, que la búsqueda ya encuentra en
-- Ajustes > Apariencia (cada ajuste sale una sola vez).
local CONTROLES = {
	{ kind = "toggle", key = ID .. ".aullido", label = L["Aullido al abrir Alfa"],
		help = L["Un aullido de lobo, del propio juego, la primera vez que abres Alfa en cada sesión."], search = "howl, wolf sound, sound, opening sound" },
	{ kind = "toggle", key = ID .. ".introSiempre", label = L["El lobo te recibe al entrar"],
		help = L["Cada vez que entras al juego, la intro del lobo y la luna te da la bienvenida. Un clic o Esc la saltan."],
		search = "intro, wolf, moon, login animation, welcome animation" },
	-- 1.3.3: la entrada en silencio (Alfa_Nucleo/Entrada.lua).
	{ kind = "dropdown", key = ID .. ".alEntrar", label = L["Al entrar al juego"],
		help = L["Solo la animación: lo demás (tu sesión anterior, avisos, lo nuevo) te espera en Hoy y con Lya. Animación y avisos: como antes."],
		choices = function()
			return { { value = "silencio", label = L["Solo la animación"] }, { value = "avisos", label = L["Animación y avisos"] } }
		end, search = "login, startup, silent, quiet, notifications, popups, entrada, silencio, avisos al entrar" },
	{ kind = "button", label = L["Escuchar el aullido"], button = L["Escuchar"], icon = "info",
		help = L["Suena ahora, aunque el aullido esté apagado."], onClick = function() M.Aullar(true) end, search = "howl, play sound, test sound" },
	{ kind = "button", label = L["Tu configuración de Alfa"], button = L["Abrir"], icon = "info",
		help = L["El idioma, el estilo, lo que Alfa hace sola por ti y La Jauría, con «Cambiar» en cada cosa. También con /alfa bienvenida."],
		onClick = function() M.Abrir("pedido", "asistente") end, search = "setup, welcome, wizard, language, configuration, ayuda, help, tutorial" },
	-- 1.3.6: el recorrido también sale en el buscador.
	{ kind = "button", label = L["El recorrido por Alfa"], button = L["Ver"], icon = "info",
		help = L["Lya te enseña la ventana de Alfa paso a paso. También con /alfa recorrido."],
		onClick = function() if M.Recorrido then M.Recorrido.Empezar() end end,
		search = "recorrido, ayuda, tutorial, help, tour, guided tour, how to use, como usar, primeros pasos, empezar" },
	{ kind = "button", label = L["Reportar un error, una mejora o un comentario"], button = L["Reportar"], icon = "info",
		help = L["Cuéntanos qué pasó y dale «Enviar»: le llega directo al desarrollador de Alfa. También con /alfa reportar."],
		onClick = function() M.AbrirReporte() end, search = "bug report, feedback, suggestion, discord, reportar, ayuda, help" },
	-- 1.3.2: noReset: «Restablecer página» no lo toca (lo de fábrica, sencillo, es para quien empieza).
	{ kind = "dropdown", key = ID .. ".modo", label = L["Cómo ves Alfa"], noReset = true,
		help = L["Sencillo: solo Hoy, Ruta, Mundo, Bolsas, Talentos y Lya a la vista, y menos avisos. Completo: todo Alfa. Lo demás sigue funcionando."],
		choices = function()
			local out = {}
			for i, o in ipairs(M.OPCIONES_MODO()) do out[i] = { value = o.valor, label = o.texto } end
			return out
		end, search = "simple mode, full mode, basic, advanced, beginner, sidebar, sencillo, completo" },
	-- 1.3.0
	{ kind = "toggle", key = "nucleo.letraGrande", label = L["Letra más grande"],
		help = L["Todo el texto de Alfa un poco más grande, en cada ventana. Se suma al tamaño de Ajustes > Apariencia."],
		search = "bigger text, large font, accessibility, readability, letra grande, accesibilidad" },
	-- 1.4.0 (66)
	{ kind = "toggle", key = "nucleo.altoContraste", label = L["Alto contraste"],
		help = L["Texto blanco, fondos opacos y bordes marcados en todas las ventanas de Alfa, en cualquier estilo. Se suma a la letra grande y a los colores para daltonismo."],
		search = "high contrast, contrast, accessibility, readability, alto contraste, accesibilidad, leer mejor, vista" },
	-- 1.3.8
	-- 1.4.0 (62): tu escala de Alfa no se pierde al restablecer la página (noReset).
	{ kind = "slider", key = "nucleo.escalaVentanas", label = L["Tamaño de las ventanas de Alfa"], min = 0.8, max = 1.3, step = 0.05, noReset = true,
		format = function(v) return ("%d %%"):format(math.floor((v or 1) * 100 + 0.5)) end,
		help = L["Agranda o achica las ventanas de Alfa enteras, aparte de la escala del juego. La ventana principal de Alfa tiene la suya en Apariencia."],
		search = "window scale, size, bigger windows, smaller, zoom, escala, tamaño, ventanas grandes" },
	{ kind = "toggle", key = "nucleo.temporada", label = L["Adornos de temporada"],
		help = L["En Noche de Brujas, Fiesta de Invierno, Amor en el aire y el Fuego del Solsticio, un detalle chiquito de la fiesta en cada ventana de Alfa."],
		search = "holiday, seasonal, halloween, winter veil, christmas, love is in the air, midsummer, temporada, fiesta, navidad" },
	-- 1.3.9 (Kit/Bando.lua)
	{ kind = "toggle", key = "nucleo.bando", label = L["Temática de tu bando"],
		help = L["Alfa se viste de tu bando: colores, emblema y adornos en las ventanas, los anuncios, Hoy y el marcador."],
		search = "faction theme, horde, alliance, red, blue, emblem, bando, horda, alianza, facción" },
	{ kind = "button", label = L["Modo Zen"], button = L["Probar"], icon = "info",
		help = L["Una tecla esconde todo Alfa menos la flecha, para explorar o tomar capturas. Otra pulsación lo devuelve. También con /alfa zen."],
		onClick = function() if M.Zen then M.Zen.Alternar(true) end end,
		search = "zen, screenshot, hide alfa, only arrow, minimal, capturas, esconder, solo la flecha" },
	-- 1.3.5
	{ kind = "toggle", key = "nucleo.ligero", label = L["Modo ligero"],
		help = L["Para computadoras modestas: lo que Alfa revisa en segundo plano va a la mitad de velocidad, Lya se anima más despacio y los anuncios salen como tarjeta, sin animación."],
		search = "light mode, low end, performance, fps, lag, slow computer, modo ligero, rendimiento, lento" },
	-- 1.3.9 (53, 55)
	{ kind = "toggle", key = ID .. ".primeraVez", label = L["Para qué sirve cada página"],
		help = L["La primera vez que abres una página, una línea abajo te dice para qué sirve, con «Enséñame» para un recorrido de 3 pasos."],
		search = "first time, page intro, tutorial, onboarding, help, primera vez, recorrido, para qué sirve" },
	{ kind = "toggle", key = ID .. ".aprendiz", label = L["Modo aprendiz"],
		help = L["La primera vez que sale cada aviso, Lya te cuenta de dónde viene y dónde se apaga."],
		search = "apprentice, beginner, newbie, learn, explain notices, aprendiz, principiante, nuevo, explicar avisos" },
	{ kind = "toggle", key = "nucleo.daltonico", label = L["Colores para daltonismo"],
		help = L["Lo bueno en azul, los avisos en amarillo y el peligro en naranja, y los perjuicios con colores que se distinguen sin el rojo y el verde."],
		search = "colorblind, color blind, colour blind, deuteranopia, protanopia, accessibility, daltonismo, debuff colors" },
	{ kind = "dropdown", key = "nucleo.ayudaTecla", label = L["«¿Qué es esto?»"],
		help = L["Deja esta tecla abajo y pasa el ratón por cualquier cosa de Alfa: te digo para qué sirve."],
		choices = function()
			local out = {}
			for i, o in ipairs(M.OPCIONES_AYUDA()) do out[i] = { value = o.valor, label = o.texto } end
			return out
		end, search = "help, what is this, tooltip, hover help, context help, ayuda" },
	{ kind = "button", label = L["Pantalla limpia"], button = L["Probar"], icon = "info",
		help = L["Con una tecla escondes lo del juego que no necesitas y quedan Alfa, tu rastreador y Lya. Otra pulsación lo devuelve todo."],
		onClick = function() if N.PantallaLimpia then N.PantallaLimpia.Alternar() end end,
		search = "clean screen, hide ui, minimal ui, screenshot mode, immersion, pantalla limpia" },
	-- 1.3.7: la ventana de Alfa (Ventana.lua).
	{ kind = "toggle", key = ID .. ".atajosVentana", label = L["Atajos de teclado en la ventana"],
		help = L["Con la ventana abierta: Ctrl y un número cambian de sección, Ctrl+← y Ctrl+→ de página, Ctrl+F busca y Alt+← vuelve a donde estabas."],
		search = "keyboard shortcuts, hotkeys, ctrl, navigation, atajos, teclado, teclas, secciones, volver, back" },
	{ kind = "toggle", key = ID .. ".recordarVentana", label = L["Recordar su alto y su lugar"],
		help = L["La esquina de abajo a la derecha la hace más alta. Alfa la abre donde la dejaste y del alto que la dejaste."],
		search = "window size, resize, taller, position, remember, tamaño, alto, agrandar, ventana, lugar" },
	{ kind = "button", label = L["La ventana como venía"], button = L["Devolverla"], icon = "info",
		help = L["Vuelve a su alto de siempre, en el centro de la pantalla."],
		onClick = function() if M.Ventana then M.Ventana.Restablecer() end end,
		search = "reset window, window size, position, center, ventana, tamaño, centro" },
	{ kind = "button", label = L["Tus atajos de Alfa"], button = L["Abrir"], icon = "info",
		help = L["Todas las teclas de Alfa en un lugar, para cambiarlas ahí mismo. También con /alfa teclas."],
		onClick = function() M.Teclas.Abrir() end, search = "keybindings, key bindings, hotkeys, shortcuts, keys, teclas, atajos" },
	{ kind = "button", label = L["Revisar Alfa"], button = L["Revisar"], icon = "info",
		help = L["Busca addons que chocan con Alfa, partes apagadas y ajustes raros, con el arreglo a un clic. También con /alfa diagnostico."],
		onClick = function() M.Diagnostico.Abrir() end, search = "diagnostics, conflicts, addon conflict, troubleshoot, compatibility, revisar, ayuda, help, problemas" },
	{ kind = "button", label = L["Respaldar ahora"], button = L["Respaldar ahora"], icon = "info",
		help = L["Alfa guarda una copia de tus ajustes y perfiles cada semana y antes de cada actualización. Quedan las últimas 3."],
		onClick = function() M.Respaldos.Ahora() end, search = "backup, restore, settings backup, respaldo" },
	{ kind = "button", label = L["Errores atrapados"], button = L["Copiar"], icon = "info",
		help = L["Los errores de Alfa que se atraparon, para copiarlos en tu reporte."], onClick = function() M.Respaldos.CopiarErrores() end, search = "errors, lua errors, bugs, copy errors" },
	{ kind = "button", label = function()
			-- 1.3.3: con las novedades sin ver, un punto (no se abren solas al entrar).
			local t = format(L["Lo nuevo en Alfa %s"], M.VERSION_ALFA)
			if M.NotasPorVer and M.NotasPorVer() then t = t .. "  " .. K.Tenir("acento", "\226\151\143") end
			return t
		end, button = L["Ver"], icon = "info",
		help = L["La bienvenida con las novedades de esta versión."],
		onClick = function()
			if M.AbrirNotas and M.AbrirNotas() then return end
			M.Abrir("pedido", "portada")
		end, search = "whats new, changelog, patch notes, release notes, version" },
}

-- 1.3.7: los de los momentos (Alfa_Nucleo/Momentos.lua), para la búsqueda.
for _, c in ipairs(N.ControlesMomentos and N.ControlesMomentos() or {}) do CONTROLES[#CONTROLES + 1] = c end

N.Modulo({
	id = ID, nombre = L["Estilo y sonido"], icono = "ic-apariencia", orden = 90, seccion = "ajustes",
	-- 1.3.6: subtítulo corto (la ventana esconde los de más de 60 letras).
	subtitulo = L["Tu estilo, el sonido, la ayuda y tus atajos."],
	comando = "estilo",
	ajustes = { aullido = true, idioma = "", introSiempre = true,
		-- 1.3.3: "silencio" (al entrar, solo la animación) | "avisos" (como antes)
		alEntrar = "silencio",
		-- 1.2.7: los avisos de viaje y de raros como un anuncio animado (Kit/Anuncio.lua)
		anuncios = true,
		-- 1.2.9: "sencillo" (lo esencial a la vista) | "completo" (todo Alfa).
		-- Quien ya tenía Alfa queda en completo (migración 3, Pasos.lua).
		modo = "sencillo",
		-- 1.3.7: la ventana de Alfa (Ventana.lua): sus atajos y recordar su alto y lugar.
		atajosVentana = true, recordarVentana = true },
	controles = CONTROLES,
	construir = construir,
	-- 1.3.3: un punto en la página (y en Ajustes) con las novedades sin ver.
	dot = function() return M.NotasPorVer ~= nil and M.NotasPorVer() ~= nil end,
	-- 1.3.2: «Restablecer página» devuelve también el estilo y su color de
	-- acento (los que se eligen arriba, en las tarjetas) y dice exactamente qué
	-- vuelve; «Cómo ves Alfa» no cambia (noReset).
	restablecer = {
		texto = function(etiquetas)
			local lista = {}
			for i, e in ipairs(etiquetas or {}) do lista[i] = "«" .. e .. "»" end
			local unidas = #lista > 1 and (table.concat(lista, ", ", 1, #lista - 1) .. L[" y "] .. lista[#lista]) or (lista[1] or "")
			return format(L["Vuelven a como venían el estilo Alfa con su color, %s. «%s» y tus perfiles no cambian."], unidas, L["Cómo ves Alfa"])
		end,
		fn = function()
			-- El acento propio que recordaba cada estilo (Kit/Tokens.lua) se olvida
			-- primero: si no, al cambiar de estilo volvería el suyo.
			local d = N.Datos("kit")
			d.acentos = {}
			A.Set("ui.skin", nil)
			A.Set("ui.classAccent", nil)
			A.Set("ui.accent", nil)
			if K.Repintar then pcall(K.Repintar) end
		end,
	},
})

-- 1.3.0: Lya sabe contar lo de leer mejor, la pantalla limpia y los atajos.
A.OnLogin(function()
	local Lya = rawget(_G, "AlfaLya")
	if not (type(Lya) == "table" and type(Lya.Ensenar) == "function") then return end
	for _, p in ipairs({
		{ id = "bienvenida.leer", icono = "ic-info", pregunta = L["Me cuesta leer Alfa, ¿qué hago?"],
			respuesta = L["En Ajustes > Estilo y sonido prende «Letra más grande» y, si confundes el rojo con el verde, «Colores para daltonismo»."] },
		{ id = "bienvenida.quees", icono = "ic-info", pregunta = L["¿Para qué sirve cada botón?"],
			respuesta = L["Deja Alt abajo y pasa el ratón por cualquier cosa de Alfa: te digo para qué sirve. La tecla se cambia en Estilo y sonido."] },
		{ id = "bienvenida.limpia", icono = "ic-lobo", pregunta = L["¿Puedo ver el mundo sin tanta cosa en pantalla?"],
			respuesta = L["Sí: con /alfa limpia, o con tu tecla de pantalla limpia, escondo el chat, el minimapa y lo demás que elijas. Otra vez y vuelve todo."] },
		{ id = "bienvenida.teclas", icono = "ic-ajustes", pregunta = L["¿Cómo cambio las teclas de Alfa?"],
			respuesta = L["Escribe /alfa teclas: ahí están todas, y con un clic pulsas la que quieras."] },
	}) do
		p.modulo = M.ID
		pcall(Lya.Ensenar, p)
	end
end)
