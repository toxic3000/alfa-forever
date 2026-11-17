-- Alfa - Bienvenida: la ventana de Alfa 1.0 (toxic3000 / La Jauría). GPL-3.0.
--
-- Una ventana del Kit (K.Ventana) con dos vistas:
--   portada    K.Tablero: arriba la acción grande ("Empezar", o "Todo listo"
--              con tus respuestas si ya pasaste por el asistente) y abajo lo
--              nuevo de la 1.0 (Novedades.lua).
--   asistente  K.Asistente, en este orden:
--                1. el estilo (y, en Cristal, el color de acento);
--                2. las misiones automáticas: solo las de tu ruta o todas
--                   (el ajuste ruta.soloRuta de Ruta y misiones);
--                3. compartir tu ubicación con La Jauría, con la pregunta de
--                   AlfaManada.PreguntarCompartir() (sin La Jauría, el paso
--                   no sale);
--                4. el aullido.
-- Cada respuesta se guarda al elegirla; "Listo" cierra con un aviso.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID
local ESP = K.ESP

local format = string.format
local DOT = "  \194\183  "
local ANCHO, ALTO = 820, 660

local v -- la ventana
local ui = {}

local function datos() return N.Datos(ID) end
local function respondio() return (tonumber(datos().respondio) or 0) >= M.VERSION end

local function manada()
	local m = AlfaManada
	return type(m) == "table" and type(m.PreguntarCompartir) == "function" and m or nil
end

---------------------------------------------------------------------------
-- Medir: la vista de ahora con el ancho del cuerpo (el asistente con su
-- alto, para que el pie quede abajo).
---------------------------------------------------------------------------
local function acomodar()
	if not (v and v:IsShown()) then return end
	local ancho = v:AnchoCuerpo()
	local h = 0
	if ui.vista == "asistente" and ui.asistente then
		h = ui.asistente:Acomodar(ancho, v:AltoCuerpo() - 2)
	elseif ui.portada then
		h = ui.portada:Acomodar(ancho)
	end
	v:SetAltoContenido(h)
end
M.Acomodar = acomodar

-- Un cambio de estilo cambia la letra y las medidas: se mide de nuevo.
K.AlRepintar(function() acomodar() end)

---------------------------------------------------------------------------
-- Piezas de los pasos
---------------------------------------------------------------------------

-- Una línea de texto como bloque de una pila.
local function nota(pila, texto)
	local b = CreateFrame("Frame", nil, pila)
	b.Texto = K.Texto(b, "nota", "textoTenue")
	b.Texto:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	K.Escribir(b.Texto, texto)
	function b:Acomodar(ancho)
		local h = K.Parrafo(self.Texto, ancho)
		self:SetHeight(h)
		return h
	end
	return pila:Agregar(b)
end

-- Elegir una de varias tarjetas: la elegida con borde de acento y su insignia.
--   o = { opciones = { { valor, icono, titulo, texto, recomendado } }, leer = fn() -> valor, guardar = fn(valor) }
local function eleccion(pila, o)
	local r = pila:Agregar(K.Rejilla(pila, { min = 280, gap = ESP.base }))
	function r:Refrescar()
		local actual = o.leer()
		local lista = {}
		for i, x in ipairs(o.opciones) do
			local el = actual == x.valor
			lista[i] = {
				icono = x.icono, tono = el and "acento" or "neutro", titulo = L[x.titulo], texto = L[x.texto], elegida = el,
				sobre = x.recomendado and L["Recomendado"] or nil,
				insignias = el and { { L["Elegido"], "acento", "ic-exito" } } or nil,
				alClic = function()
					o.guardar(x.valor)
					r:Refrescar()
					acomodar()
				end,
			}
		end
		self:Llenar(lista)
	end
	r:Refrescar()
	return r
end

---------------------------------------------------------------------------
-- Los pasos
---------------------------------------------------------------------------
local function refrescarEstilo()
	local cristal = K.Cristal()
	if ui.secAcento then K.Mostrar(ui.secAcento, cristal) end
	if ui.selAcento then
		K.Mostrar(ui.selAcento, cristal)
		ui.selAcento:Leer()
	end
	if ui.selEstilo then ui.selEstilo:Leer() end
	acomodar()
end

local function pasoEstilo()
	return {
		titulo = L["¿Cómo quieres que se vea Alfa?"],
		texto = L["Elige uno y lo ves al instante en todas las ventanas de Alfa, también la flecha."],
		construir = function(pila)
			ui.selEstilo = pila:Agregar(K.SelectorEstilo(pila, { min = 220, alCambiar = refrescarEstilo }))
			ui.secAcento = pila:Agregar(K.Seccion(pila, L["Tu color de acento"]), { espacio = ESP.l })
			ui.selAcento = pila:Agregar(K.SelectorAcento(pila, { alCambiar = function() acomodar() end }), { espacio = ESP.s })
			nota(pila, L["Lo cambias cuando quieras en Ajustes > Estilo y sonido."])
		end,
		alMostrar = refrescarEstilo,
	}
end

-- Las misiones: ruta.soloRuta (lo define Ruta y misiones). Sin respuesta
-- guardada se marca la recomendada, y se guarda al seguir.
local function soloRuta()
	local x = A.Get("ruta.soloRuta")
	if x == nil then return true end
	return x and true or false
end

local function pasoMisiones()
	return {
		titulo = L["¿Qué misiones toma Alfa por ti?"],
		texto = L["Cuando Alfa acepta y entrega misiones solo, puede limitarse a las que sirven a tu ruta."],
		construir = function(pila)
			ui.opMisiones = eleccion(pila, {
				opciones = {
					{ valor = true, icono = "ic-ruta", recomendado = true, titulo = "Solo las de mi ruta",
						texto = "Acepta y entrega solo las misiones que te sirven para la ruta que sigues. Tu registro queda limpio." },
					{ valor = false, icono = "ic-misiones", titulo = "Todas las que encuentre",
						texto = "Acepta y entrega cualquier misión que se cruce en tu camino, sea o no de tu ruta." },
				},
				leer = soloRuta,
				guardar = function(x) A.Set("ruta.soloRuta", x) end,
			})
		end,
		alMostrar = function() if ui.opMisiones then ui.opMisiones:Refrescar() end end,
		alSalir = function() if A.Get("ruta.soloRuta") == nil then A.Set("ruta.soloRuta", true) end end,
	}
end

-- La Jauría: la pregunta es de La Jauría (AlfaManada.PreguntarCompartir); aquí
-- se explica, se pregunta al llegar al paso y se muestra lo que respondiste.
local function pintarJauria()
	local t = ui.tarjetaJauria
	local m = manada()
	if not (t and m) then return end
	local sabe = type(m.Comparte) == "function"
	local comparte = sabe and m.Comparte() and true or false
	local responder = { texto = L["Responder"], icono = "ic-manada", alClic = function() M.PreguntarJauria() end }
	if not sabe then
		t:Set({ icono = "ic-manada", tono = "acento", titulo = L["Tu ubicación y La Jauría"],
			texto = L["Solo la ven tu grupo y quienes usan Alfa y aceptaron compartir."], accion = responder })
	elseif comparte then
		responder.texto = L["Cambiar mi respuesta"]
		t:Set({ icono = "ic-manada", tono = "exito", titulo = L["Compartes tu ubicación"],
			texto = L["Tu manada te ve en el mapa y te puede seguir con la flecha. Lo apagas cuando quieras en la página de La Jauría."],
			estado = { texto = L["Compartes"], tono = "exito" }, accion = responder })
	else
		responder.texto = L["Cambiar mi respuesta"]
		t:Set({ icono = "ic-manada", tono = "neutro", titulo = L["No compartes tu ubicación"],
			texto = L["Nadie de La Jauría ve dónde estás. Si cambias de idea, lo enciendes en la página de La Jauría."],
			estado = { texto = L["No compartes"], tono = "neutro" }, accion = responder })
	end
end

function M.PreguntarJauria()
	local m = manada()
	if not m then return end
	ui.preguntoJauria = true
	K.Llamar(m.PreguntarCompartir, function()
		pintarJauria()
		acomodar()
	end)
end

local function pasoJauria()
	return {
		titulo = L["¿Compartes tu ubicación con La Jauría?"],
		texto = L["Así tu manada te encuentra en el mapa y te sigue con la flecha. Solo la ven tu grupo y quienes usan Alfa y aceptaron compartir."],
		construir = function(pila)
			ui.tarjetaJauria = pila:Agregar(K.Tarjeta(pila, { variante = "estado" }))
		end,
		alMostrar = function()
			pintarJauria()
			if not ui.preguntoJauria then M.PreguntarJauria() end
		end,
	}
end

local function pasoAullido()
	return {
		titulo = L["¿Quieres el aullido?"],
		texto = L["Un aullido de lobo, del propio juego, la primera vez que abres Alfa en cada sesión."],
		construir = function(pila)
			ui.opAullido = eleccion(pila, {
				opciones = {
					{ valor = true, icono = "ic-lobo", recomendado = true, titulo = "Sí, que aúlle",
						texto = "La manada te saluda al abrir Alfa por primera vez en la sesión." },
					{ valor = false, icono = "ic-cerrar", titulo = "No, en silencio",
						texto = "Alfa abre sin sonido. Lo enciendes cuando quieras en Ajustes > Estilo y sonido." },
				},
				leer = function() return N.Get(ID, "aullido") and true or false end,
				guardar = function(x)
					N.Set(ID, "aullido", x)
					if x then M.Aullar(true) end
				end,
			})
			local b = K.Boton(pila, L["Escuchar el aullido"], function() M.Aullar(true) end, { tipo = "secundario", icono = "ic-lobo" })
			b.alfaAnchoPropio = true
			pila:Agregar(b, { espacio = ESP.l })
		end,
		alMostrar = function() if ui.opAullido then ui.opAullido:Refrescar() end end,
	}
end

local function pasos()
	local lista = { pasoEstilo(), pasoMisiones() }
	if manada() then lista[#lista + 1] = pasoJauria() end
	lista[#lista + 1] = pasoAullido()
	return lista
end

---------------------------------------------------------------------------
-- La portada
---------------------------------------------------------------------------
local function resumen()
	local partes = {}
	partes[#partes + 1] = soloRuta() and L["Misiones: solo las de tu ruta"] or L["Misiones: todas"]
	local m = manada()
	if m and type(m.Comparte) == "function" then
		partes[#partes + 1] = m.Comparte() and L["La Jauría te ve"] or L["No compartes tu ubicación"]
	end
	partes[#partes + 1] = N.Get(ID, "aullido") and L["Con aullido"] or L["Sin aullido"]
	return table.concat(partes, DOT)
end

local function accionPortada()
	local n = ui.asistente and #ui.asistente.pasos or 4
	if not respondio() then
		return {
			lobo = "aullando", tono = "acento", sobre = L["Bienvenida"], titulo = L["Alfa 1.0 ya está aquí"],
			texto = manada()
				and L["Antes de salir de caza, unas preguntas rápidas: cómo quieres que se vea Alfa, qué misiones toma por ti, si compartes tu ubicación con La Jauría y si quieres el aullido."]
				or L["Antes de salir de caza, unas preguntas rápidas: cómo quieres que se vea Alfa, qué misiones toma por ti y si quieres el aullido."],
			progreso = { actual = 0, total = n, huellas = true, texto = format(L["%d pasos, un minuto"], n) },
			accion = { texto = L["Empezar"], icono = "ic-seguir", alClic = function() M.AbrirVentana("asistente") end },
			secundaria = { texto = L["Ahora no"], alClic = function() if v then v:Cerrar() end end },
		}
	end
	return {
		lobo = "normal", tono = "exito", sobre = L["Todo listo"],
		titulo = format(L["Tu estilo: %s"], K.NombreEstilo(K.Estilo()) or ""),
		texto = resumen(),
		progreso = { actual = n, total = n, huellas = true, texto = L["Respondiste todo"] },
		accion = { texto = L["Repasar mis respuestas"], icono = "ic-ajustes", alClic = function() M.AbrirVentana("asistente") end },
		secundaria = { texto = L["Cerrar"], alClic = function() if v then v:Cerrar() end end },
	}
end

local function novedades()
	local lista = {}
	for i, x in ipairs(M.NOVEDADES) do
		lista[i] = { icono = x[1], titulo = L[x[2]], texto = L[x[3]] }
	end
	return lista
end

---------------------------------------------------------------------------
-- La ventana
---------------------------------------------------------------------------
local function terminar()
	datos().respondio = M.VERSION
	M.MarcarVisto()
	if A.Get("ruta.soloRuta") == nil then A.Set("ruta.soloRuta", true) end
	if v then v:Cerrar() end
	K.Aviso({
		lobo = "aullando", tono = "acento", duracion = 8,
		titulo = L["¡Listo! Alfa ya es tuyo"],
		texto = L["Ábrelo con /alfa o con el lobo del minimapa. Tu estilo y el aullido se cambian en Ajustes > Estilo y sonido."],
	})
	M.Aullar()
end

local function armar()
	v = K.Ventana({
		nombre = "AlfaBienvenidaVentana", titulo = format(L["Bienvenida a Alfa %s"], M.VERSION_ALFA),
		subtitulo = L["Lo nuevo y tu Alfa a tu medida"], icono = "ic-lobo",
		ancho = ANCHO, alto = ALTO, desplazar = true,
		alCerrar = function() M.AlCerrar() end,
	})
	v.alAcomodar = acomodar

	ui.portada = K.Tablero(v.Cuerpo, { margen = v.margen, accion = "accion", tituloOpciones = L["Lo nuevo en Alfa 1.0"], min = 230 })
	ui.asistente = K.Asistente(v.Cuerpo, { margen = v.margen, textoTerminar = L["Listo"], alTerminar = terminar, pasos = pasos() })
	ui.asistente.alCambiar = function() if v.Desplazable then v.Desplazable:IrArriba() end end
	ui.asistente:Hide()
	v.alfaPortada, v.alfaAsistente = ui.portada, ui.asistente
end

function M.Visible() return v ~= nil and v:IsShown() end

-- Abre la ventana en la portada o en el asistente (desde su primer paso).
function M.AbrirVentana(vista)
	if not v then armar() end
	ui.vista = vista == "asistente" and "asistente" or "portada"
	if ui.vista == "asistente" then
		ui.portada:Hide()
		ui.asistente:Show()
		ui.asistente:Ir(1)
		v:SetTitulo(L["Tu Alfa, a tu medida"], format(L["%d preguntas rápidas"], #ui.asistente.pasos), "ic-lobo")
	else
		ui.asistente:Hide()
		ui.portada:Show()
		ui.portada:SetAccion(accionPortada())
		ui.portada:SetOpciones(novedades(), L["Lo nuevo en Alfa 1.0"])
		v:SetTitulo(format(L["Bienvenida a Alfa %s"], M.VERSION_ALFA), L["Lo nuevo y tu Alfa a tu medida"], "ic-lobo")
	end
	v:Abrir()
	if v.Desplazable then v.Desplazable:IrArriba() end
	acomodar()
end
