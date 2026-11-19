-- Alfa - Bienvenida: la ventana de configuración (toxic3000 / La Jauría).
-- GPL-3.0.
--
-- Una ventana del Kit (K.Ventana) con dos vistas:
--   asistente  K.Asistente, una decisión por pantalla:
--                1. el idioma de Alfa (cada uno escrito en el suyo; el de
--                   tu juego ya elegido). Cambiarlo puede pedir recargar: el
--                   asistente guarda dónde iba y sigue en el paso 2;
--                2. el estilo, que se ve al instante (y en Cristal, el
--                   acento), y el aullido;
--                3-7. lo que Alfa hace sola, en pantallas de interruptores
--                   (Pasos.lua): misiones, tu guía, comerciantes y viajes,
--                   otros jugadores y tu personaje (con lo recomendado para
--                   tu clase y tu rol ya elegido);
--                8. compartir tu ubicación con La Jauría: siempre una
--                   elección explícita, "No, por ahora" mientras no digas que
--                   sí (sin La Jauría, el paso no sale);
--                9. el resumen: cada respuesta con "Cambiar" y
--                   un solo botón, "Listo".
--              Cada respuesta se guarda al elegirla. "Ir al resumen" deja el
--              resto como está.
--   portada    K.Tablero: lo nuevo de la versión (Novedades.lua) y tu
--              configuración, o "Configurar" si aún falta.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID
local ESP = K.ESP

local format = string.format
local DOT = "  \194\183  "
local ANCHO, ALTO = 820, 680

local v -- la ventana
local ui = { grupos = {} }

local function datos() return N.Datos(ID) end

local function manada()
	local m = AlfaManada
	return type(m) == "table" and type(m.Compartir) == "function" and type(m.Comparte) == "function" and m or nil
end

---------------------------------------------------------------------------
-- Medir: la vista de ahora con el ancho del cuerpo (el asistente con su
-- alto, para que el pie quede abajo).
---------------------------------------------------------------------------
-- La ventana ocupa toda la pantalla; el contenido va en una columna centrada
-- de COLUMNA a lo más, para que se lea cómodo en pantallas anchas.
local COLUMNA = 960

local function acomodar()
	if not (v and v:IsShown()) then return end
	local total = v:AnchoCuerpo()
	local ancho = math.min(total, COLUMNA)
	local margen = v.margen + math.floor((total - ancho) / 2)
	local h = 0
	if ui.vista == "asistente" and ui.asistente then
		ui.asistente.alfaMargen = margen
		h = ui.asistente:Acomodar(ancho, v:AltoCuerpo() - 2)
	elseif ui.portada then
		ui.portada.alfaMargen = margen
		h = ui.portada:Acomodar(ancho)
	end
	v:SetAltoContenido(h)
end
M.Acomodar = acomodar

-- Mide ahora y otra vez en un momento: el juego termina de acomodar los
-- textos largos (los que bajan de renglón) un cuadro después.
local function acomodarYa()
	acomodar()
	K.Despues(0.05, acomodar)
	K.Despues(0.3, acomodar)
end

-- Un cambio de estilo cambia la letra y las medidas: se mide de nuevo.
K.AlRepintar(function() acomodar() end)

---------------------------------------------------------------------------
-- Piezas de los pasos
---------------------------------------------------------------------------

-- Una nota (texto tenue) como bloque de una pila; vacía no ocupa lugar.
local function nota(pila, texto, color)
	local b = CreateFrame("Frame", nil, pila)
	b.Texto = K.Texto(b, "nota", color or "textoTenue")
	b.Texto:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	function b:Set(t)
		K.Escribir(self.Texto, t or "")
		K.Mostrar(self, (t or "") ~= "")
	end
	function b:Acomodar(ancho)
		local h = K.Parrafo(self.Texto, ancho)
		self:SetHeight(h)
		return h
	end
	pila:Agregar(b)
	b:Set(texto)
	return b
end

-- Elegir una de varias tarjetas: la elegida con borde de acento y su insignia.
--   o = { opciones = { { valor, icono, titulo, texto, sobre, tal = true (sin traducir) } },
--         leer = fn() -> valor, guardar = fn(valor), min, variante }
local function eleccion(pila, o)
	local r = pila:Agregar(K.Rejilla(pila, { min = o.min or 280, gap = o.gap or ESP.base, variante = o.variante }))
	local function t(x) if x == nil or x == "" then return nil end return o.tal and x or L[x] end
	function r:Refrescar()
		local actual = o.leer()
		local lista = {}
		for i, x in ipairs(o.opciones) do
			local el = actual == x.valor
			lista[i] = {
				icono = x.icono, tono = el and "acento" or "neutro", titulo = t(x.titulo), texto = x.texto and L[x.texto] or nil,
				elegida = el, sobre = x.sobre and L[x.sobre] or nil,
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
-- 1. El idioma
---------------------------------------------------------------------------
local function cambiaIdioma() return ui.idioma ~= nil and ui.idioma ~= M.IdiomaActual() end

local function pintarIdioma()
	if ui.opIdioma then ui.opIdioma:Refrescar() end
	if ui.notaIdioma then
		ui.notaIdioma:Set(cambiaIdioma() and L["Al seguir, Alfa se recarga para cambiar el idioma y esta configuración sigue donde la dejaste."] or "")
	end
	if ui.asistente then ui.asistente:Refrescar() end
	acomodar()
end

-- Al pulsar Siguiente en el paso del idioma. -> true si ya se encargó (recarga).
local function seguirIdioma()
	if not cambiaIdioma() then return false end
	local loc = ui.idioma
	N.Set(ID, "idioma", loc)
	local recargar = false
	if type(N.PonerIdioma) == "function" then
		local ok, r = pcall(N.PonerIdioma, loc)
		recargar = ok and r and true or false
	end
	if not recargar then return false end
	-- Guardar dónde va (las respuestas ya están guardadas) y recargar.
	local a = ui.asistente
	local sig = a and a.pasos[a:Paso() + 1]
	datos().paso = sig and sig.id or nil
	M.recargando = true
	N.Imprimir(L["Alfa se recarga para cambiar el idioma. La configuración sigue donde la dejaste."])
	if ReloadUI then ReloadUI() end
	return true
end

local function pasoIdioma()
	local opciones = {}
	local delJuego = M.IdiomaDelJuego()
	for i, x in ipairs(M.IDIOMAS) do
		opciones[i] = { valor = x[1], titulo = x[2], sobre = x[1] == delJuego and "El de tu juego" or nil }
	end
	return {
		id = "idioma", corto = "Idioma",
		titulo = L["¿En qué idioma quieres Alfa?"],
		texto = L["Alfa se muestra en el idioma que elijas, aunque tu juego esté en otro."],
		construir = function(pila)
			ui.opIdioma = eleccion(pila, { opciones = opciones, tal = true, min = 220, gap = ESP.m,
				leer = function() return ui.idioma end,
				guardar = function(x) ui.idioma = x pintarIdioma() end })
			ui.notaIdioma = nota(pila, "", "aviso")
		end,
		alMostrar = function()
			ui.idioma = ui.idioma or M.IdiomaActual()
			pintarIdioma()
		end,
		antesDeSeguir = seguirIdioma,
		resumen = function() return M.NombreIdioma(M.IdiomaActual()) end,
	}
end

---------------------------------------------------------------------------
-- 1b. Qué es Alfa: después del idioma, para leerlo ya en el elegido
---------------------------------------------------------------------------
local QUE_ES = {
	"Alfa es un addon que toxic3000 creó para sus amigos y quiso compartir con todos.",
	"No busca apagar tu cerebro ni jugar por ti: busca que entiendas y disfrutes un juego de hace años, a tu ritmo.",
	"Si tienes poco tiempo, si no tienes con quién jugar o quién te ayude, puedes apoyarte en Alfa y en Lya en tu travesía.",
	"Por eso empezamos con esta configuración: para que cada quien arme su experiencia a su gusto. Todo se puede cambiar después.",
}

local function parrafo(pila, texto, rol, color)
	local b = CreateFrame("Frame", nil, pila)
	b.Texto = K.Texto(b, rol or "texto", color or "textoSuave")
	b.Texto:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	K.Escribir(b.Texto, texto)
	function b:Acomodar(ancho)
		local h = K.Parrafo(self.Texto, ancho)
		self:SetHeight(h)
		return h
	end
	pila:Agregar(b, { espacio = ESP.m })
	return b
end

local function pasoQueEs()
	return {
		id = "quees", corto = "Qué es Alfa",
		titulo = L["¿Qué es Alfa?"],
		texto = L["Antes de empezar, unas palabras de la manada."],
		construir = function(pila)
			for i, t in ipairs(QUE_ES) do
				parrafo(pila, L[t], i == 1 and "cuerpo" or "texto", i == 1 and "texto" or "textoSuave")
			end
		end,
	}
end

---------------------------------------------------------------------------
-- 2. El estilo y el aullido
---------------------------------------------------------------------------
local function refrescarEstilo()
	local cristal = K.Cristal()
	if ui.secAcento then K.Mostrar(ui.secAcento, cristal) end
	if ui.selAcento then
		K.Mostrar(ui.selAcento, cristal)
		ui.selAcento:Leer()
	end
	if ui.selEstilo then ui.selEstilo:Leer() end
	if ui.grupoSonido then ui.grupoSonido:Refrescar() end
	acomodar()
end

local function pasoEstilo()
	return {
		id = "estilo", corto = "Estilo",
		titulo = L["¿Cómo quieres que se vea Alfa?"],
		texto = L["Elige uno y lo ves al instante en esta ventana y en todas las de Alfa, también la flecha."],
		construir = function(pila)
			ui.selEstilo = pila:Agregar(K.SelectorEstilo(pila, { min = 220, alCambiar = refrescarEstilo }))
			ui.secAcento = pila:Agregar(K.Seccion(pila, L["Tu color de acento"]), { espacio = ESP.l })
			ui.selAcento = pila:Agregar(K.SelectorAcento(pila, { alCambiar = function() acomodar() end }), { espacio = ESP.s })
			local g = K.GrupoAjustes(pila, { titulo = L["Sonido"] })
			g:Fila({ titulo = L["Aullido al abrir Alfa"],
				texto = L["Un aullido de lobo, del propio juego, la primera vez que abres Alfa en cada sesión."],
				control = function(fila)
					return K.Interruptor(fila, { clave = ID .. ".aullido", alCambiar = function(x) if x then M.Aullar(true) end end })
				end })
			ui.grupoSonido = pila:Agregar(g, { espacio = ESP.l })
		end,
		alMostrar = refrescarEstilo,
		resumen = function()
			return (K.NombreEstilo(K.Estilo()) or "") .. DOT .. (N.Get(ID, "aullido") and L["Con aullido"] or L["Sin aullido"])
		end,
	}
end

---------------------------------------------------------------------------
-- 3-7. Lo que Alfa hace sola (Pasos.lua)
---------------------------------------------------------------------------
local function accesos(f)
	if f.get then return f.get, f.set end
	local c = f.clave
	if f.opciones then return function() return A.Get(c) end, function(x) A.Set(c, x) end end
	return function() return A.Get(c) and true or false end, function(x) A.Set(c, x and true or false) end
end

local function existeFila(f)
	if f.existe then
		local ok, si = pcall(f.existe)
		return ok and si and true or false
	end
	return f.clave ~= nil and A.Get(f.clave) ~= nil
end

-- Las filas que salen de una pantalla: { { titulo, filas } } sin grupos vacíos.
local function filtrar(p)
	local grupos = {}
	for _, g in ipairs(p.grupos) do
		local filas = {}
		for _, f in ipairs(g.filas) do
			if existeFila(f) then
				f.leer, f.escribir = accesos(f)
				filas[#filas + 1] = f
			end
		end
		if #filas > 0 then grupos[#grupos + 1] = { titulo = g.titulo, filas = filas } end
	end
	return grupos
end

local function opcionesTraducidas(f)
	local out = {}
	for i, o in ipairs(f.opciones) do out[i] = { valor = o.valor, texto = L[o.texto] } end
	return out
end

local function textoOpcion(f, valor)
	for _, o in ipairs(f.opciones or {}) do if o.valor == valor then return L[o.texto] end end
	return tostring(valor or "")
end

-- Lo que dice el resumen de una pantalla: lo que Alfa hará sola (las filas
-- destacadas tienen su propia fila en el resumen y aquí no se repiten).
local function resumenPantalla(grupos)
	local si, total = {}, 0
	for _, g in ipairs(grupos) do
		for _, f in ipairs(g.filas) do
			if not f.destacar then
				total = total + 1
				local ok, x = pcall(f.leer)
				if f.opciones then
					si[#si + 1] = L[f.titulo] .. ": " .. textoOpcion(f, ok and x or nil)
				elseif ok and x then
					si[#si + 1] = L[f.titulo]
				end
			end
		end
	end
	if #si == 0 then return L["Nada: todo esto lo haces tú."] end
	return format(L["%d de %d: %s."], #si, total, table.concat(si, ", "))
end

-- Una fila destacada en el resumen: "Sí" o "No" y su explicación corta.
local function resumenFila(f)
	local ok, x = pcall(f.leer)
	return (ok and x) and L["Sí"] or L["No"]
end

local function pasoAjustes(p, grupos)
	local bloques = {}
	local destacadas = {}
	for _, g in ipairs(grupos) do
		for _, f in ipairs(g.filas) do if f.destacar then destacadas[#destacadas + 1] = f end end
	end
	return {
		destacadas = destacadas,
		id = p.id, corto = p.corto,
		titulo = L[p.titulo], texto = L[p.texto],
		construir = function(pila)
			for i, g in ipairs(grupos) do
				local ga = K.GrupoAjustes(pila, { titulo = L[g.titulo] })
				local porId = {}
				for _, f in ipairs(g.filas) do porId[f.id] = f end
				for _, f in ipairs(g.filas) do
					local madre = f.hija and porId[f.hija]
					ga:Fila({
						titulo = L[f.titulo], texto = L[f.texto], hija = madre ~= nil,
						activa = madre and function() local ok, x = pcall(madre.leer) return ok and x and true or false end or nil,
						control = function(fila)
							if f.opciones then
								return K.Desplegable(fila, { opciones = opcionesTraducidas(f), ancho = 170, get = f.leer, set = f.escribir })
							end
							return K.Interruptor(fila, { get = f.leer, set = f.escribir, alCambiar = function()
								for _, b in ipairs(bloques) do b:Refrescar() end
							end })
						end,
					})
				end
				bloques[#bloques + 1] = pila:Agregar(ga, { espacio = i > 1 and ESP.l or nil })
			end
		end,
		alMostrar = function() for _, b in ipairs(bloques) do b:Refrescar() end end,
		resumen = function() return resumenPantalla(grupos) end,
	}
end

-- Lo recomendado para tu clase y tu rol, solo la primera vez que alguien
-- configura Alfa (quien ya la configuró conserva lo suyo).
local function recomendar()
	local d = datos()
	if d.recomendado or (tonumber(d.respondio) or 0) > 0 then return end
	d.recomendado = true
	local rol = M.Rol()
	for _, p in ipairs(M.PantallasDeAjustes()) do
		for _, g in ipairs(p.grupos) do
			for _, f in ipairs(g.filas) do
				if f.recomendar and existeFila(f) then
					local ok, x = pcall(f.recomendar, rol)
					if ok and x ~= nil then
						local _, escribir = accesos(f)
						pcall(escribir, x)
					end
				end
			end
		end
	end
end

---------------------------------------------------------------------------
-- 1.2.4: un asistente para elegir con la vista, no con listas.
--   * Lya se presenta y habla en cada paso (su globo arriba);
--   * «¿Cuánto te ayudo?»: tres tarjetas grandes (M.PERFILES) que escriben
--     de un clic todo lo de misiones, guía, comerciantes y otros jugadores;
--     las listas de siempre quedan detrás de «Afinar cosa por cosa»;
--   * «Tus extras»: un mosaico (M.EXTRAS) que se prende con un clic.
---------------------------------------------------------------------------

-- El globo de Lya sobre un paso: su cara y lo que dice.
local function lyaDice(pila, texto, lobo)
	local b = CreateFrame("Frame", nil, pila)
	b.caja = K.Caja(b, { fondo = "panel", borde = "acento", corte = K.CORTE.panel, alfaBorde = 0.5 })
	b.Lobo = b:CreateTexture(nil, "ARTWORK")
	b.Lobo:SetSize(40, 40)
	b.Lobo:SetTexture(K.Lobo(lobo or "normal"))
	K.Pintar(b.Lobo, function(t) t:SetVertexColor(K.Color("acento")) end)
	b.Nombre = K.Texto(b, "mayus", "acento")
	K.Escribir(b.Nombre, K.Mayus("Lya"))
	b.Texto = K.Texto(b, "texto", "texto")
	K.Escribir(b.Texto, texto)
	function b:Acomodar(ancho)
		local pad = ESP.m
		local x = pad + 40 + ESP.m
		self.Lobo:ClearAllPoints()
		self.Lobo:SetPoint("TOPLEFT", self, "TOPLEFT", pad, -pad)
		self.Nombre:ClearAllPoints()
		self.Nombre:SetPoint("TOPLEFT", self, "TOPLEFT", x, -pad)
		local y = pad + K.AltoTexto(self.Nombre) + 3
		self.Texto:ClearAllPoints()
		self.Texto:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
		y = y + K.Parrafo(self.Texto, ancho - x - pad) + pad
		local h = math.max(y, pad * 2 + 40)
		self:SetHeight(h)
		return h
	end
	pila:Agregar(b)
	return b
end

local function lyaHay() return rawget(_G, "AlfaLya") ~= nil and A.Get("lya.mostrar") ~= nil end

-- Todas las filas que existen, por id (con su leer y escribir).
local function filasPorId(soloPantallas)
	local t = {}
	for _, p in ipairs(M.PantallasDeAjustes()) do
		if not soloPantallas or soloPantallas[p.id] then
			for _, g in ipairs(filtrar(p)) do
				for _, f in ipairs(g.filas) do t[f.id] = f end
			end
		end
	end
	return t
end

local function perfilDe(valor)
	for _, x in ipairs(M.PERFILES) do if x.valor == valor then return x end end
end

local function aplicarPerfil(valor)
	local per = perfilDe(valor)
	if not per then return end
	local filas = filasPorId(M.PANTALLAS_PERFIL)
	for id, x in pairs(per.filas) do
		local f = filas[id]
		if f and x ~= nil then pcall(f.escribir, x) end
	end
	datos().perfil = valor
end
M.AplicarPerfil = aplicarPerfil

local function pasoPerfil()
	local pantallas = {}
	for _, p in ipairs(M.PantallasDeAjustes()) do
		if M.PANTALLAS_PERFIL[p.id] then
			local grupos = filtrar(p)
			if #grupos > 0 then pantallas[#pantallas + 1] = { p = p, grupos = grupos } end
		end
	end
	local bloques = {}
	return {
		id = "perfil", corto = "Cuánto te ayuda Alfa",
		titulo = L["¿Cuánto quieres que Alfa haga por ti?"],
		texto = L["Elige una y listo: Alfa ajusta tus misiones, tu guía, los comerciantes y los viajes. Mantén presionado Mayús en el juego para decidir tú en el momento."],
		construir = function(pila)
			lyaDice(pila, L["Unos prefieren que yo haga lo aburrido y otros quieren hacerlo todo. Tú dime, y si cambias de idea, lo cambias cuando quieras."], "atento")
			local opciones = {}
			for i, x in ipairs(M.PERFILES) do
				opciones[i] = { valor = x.valor, icono = x.icono, titulo = x.titulo, texto = x.texto, sobre = x.sobre }
			end
			ui.opPerfil = eleccion(pila, { opciones = opciones, min = 250, variante = "accion",
				leer = function() return datos().perfil end,
				guardar = function(x)
					aplicarPerfil(x)
					for _, b in ipairs(bloques) do b:Refrescar() end
				end })
			-- Las listas, solo para quien las pide.
			local fila = CreateFrame("Frame", nil, pila)
			fila:SetHeight(K.ALTO.boton)
			local afinar = K.Boton(fila, L["Afinar cosa por cosa"], nil, { tipo = "fantasma", icono = "ic-filtro" })
			afinar:SetPoint("LEFT", fila, "LEFT", 0, 0)
			pila:Agregar(fila, { espacio = ESP.l })
			local detalle = K.Pila(pila, { espacio = ESP.l })
			pila:Agregar(detalle, { espacio = ESP.m })
			for _, x in ipairs(pantallas) do
				detalle:Agregar(K.Seccion(detalle, L[x.p.corto]))
				for _, g in ipairs(x.grupos) do
					local ga = K.GrupoAjustes(detalle, { titulo = L[g.titulo] })
					local porIdG = {}
					for _, f in ipairs(g.filas) do porIdG[f.id] = f end
					for _, f in ipairs(g.filas) do
						local madre = f.hija and porIdG[f.hija]
						ga:Fila({
							titulo = L[f.titulo], texto = L[f.texto], hija = madre ~= nil,
							activa = madre and function() local ok, v2 = pcall(madre.leer) return ok and v2 and true or false end or nil,
							control = function(filaC)
								local function cambio()
									datos().perfil = "propio"
									if ui.opPerfil then ui.opPerfil:Refrescar() end
									for _, b in ipairs(bloques) do b:Refrescar() end
								end
								if f.opciones then
									return K.Desplegable(filaC, { opciones = opcionesTraducidas(f), ancho = 170, get = f.leer,
										set = function(x2) f.escribir(x2) cambio() end })
								end
								return K.Interruptor(filaC, { get = f.leer, set = f.escribir, alCambiar = cambio })
							end,
						})
					end
					bloques[#bloques + 1] = detalle:Agregar(ga, { espacio = ESP.s })
				end
			end
			K.Mostrar(detalle, false)
			afinar.alClic = function()
				local ver = detalle.alfaOculto and true or false
				K.Mostrar(detalle, ver)
				afinar:SetTexto(ver and L["Ocultar los detalles"] or L["Afinar cosa por cosa"])
				for _, b in ipairs(bloques) do b:Refrescar() end
				acomodarYa()
			end
		end,
		alMostrar = function()
			if ui.opPerfil then ui.opPerfil:Refrescar() end
			for _, b in ipairs(bloques) do b:Refrescar() end
		end,
		resumen = function()
			local per = perfilDe(datos().perfil)
			return per and L[per.titulo] or L["A tu medida"]
		end,
	}
end

local function pasoExtras()
	local filas = filasPorId()
	local lista = {}
	for _, x in ipairs(M.EXTRAS) do
		local f = filas[x[1]]
		if f and not f.opciones then lista[#lista + 1] = { f = f, icono = x[2] } end
	end
	if #lista == 0 then return nil end
	return {
		id = "extras", corto = "Tus extras",
		titulo = L["Elige tus extras"],
		texto = L["Toca una tarjeta para prenderla o apagarla. Las encendidas llevan el borde de color."],
		construir = function(pila)
			lyaDice(pila, L["Ya te dejé prendido lo que le va a tu clase. Agrega o quita lo que quieras: nada de esto juega por ti."], "normal")
			local r = pila:Agregar(K.Rejilla(pila, { min = 220, gap = ESP.m }))
			function r:Refrescar()
				local datosR = {}
				for i, x in ipairs(lista) do
					local ok, on = pcall(x.f.leer)
					on = ok and on and true or false
					datosR[i] = { icono = x.icono, tono = on and "acento" or "neutro", titulo = L[x.f.titulo], texto = L[x.f.texto],
						elegida = on, insignias = { on and { L["Encendido"], "acento", "ic-exito" } or { L["Apagado"], "neutro" } },
						alClic = function()
							pcall(x.f.escribir, not on)
							r:Refrescar()
							acomodar()
						end }
				end
				self:Llenar(datosR)
			end
			ui.rejExtras = r
			r:Refrescar()
		end,
		alMostrar = function() if ui.rejExtras then ui.rejExtras:Refrescar() end end,
		resumen = function()
			local si = {}
			for _, x in ipairs(lista) do
				local ok, on = pcall(x.f.leer)
				if ok and on then si[#si + 1] = L[x.f.titulo] end
			end
			if #si == 0 then return L["Ninguno"] end
			return table.concat(si, ", ")
		end,
	}
end

-- Lya se presenta (en vez de «Qué es Alfa», con el mismo mensaje en su voz).
local LYA_HOLA = {
	"¡Hola! Soy Lya, la loba de confianza del Alfa. Voy a acompañarte en esta configuración y después en tu camino.",
	"Alfa lo creó toxic3000 para sus amigos y quiso compartirlo con todos. No juega por ti: te ayuda a entender y disfrutar el juego a tu ritmo.",
	"Cuando no sepas algo de Alfa, dame clic derecho y elige «¿En qué te ayudo?»: te explico cada cosa y te llevo a ella. También te cuento historias del lugar donde estás.",
}

local function pasoLya()
	return {
		id = "lya", corto = "Lya",
		titulo = L["Te presento a Lya"],
		texto = L["Tu compañera en Alfa. Lleva el nombre de una gran perrita, en su memoria."],
		construir = function(pila)
			for i, t in ipairs(LYA_HOLA) do
				lyaDice(pila, L[t], i == 1 and "aullando" or (i == 2 and "normal" or "atento"))
			end
			ui.opLya = eleccion(pila, { min = 260,
				opciones = {
					{ valor = true, icono = "ic-lobo", titulo = "¡Sí, acompáñame!", sobre = "Recomendado",
						texto = "Lya se queda en tu pantalla: consejos cortos, historias y atajos a todo Alfa." },
					{ valor = false, icono = "ic-cerrar", titulo = "Solo cuando te llame",
						texto = "Lya descansa. La llamas con /alfa lya o /alfa ayuda cuando quieras." },
				},
				leer = function() return A.Get("lya.mostrar") ~= false end,
				guardar = function(x) A.Set("lya.mostrar", x and true or false) end,
			})
		end,
		alMostrar = function() if ui.opLya then ui.opLya:Refrescar() end end,
		resumen = function() return A.Get("lya.mostrar") ~= false and L["Te acompaña"] or L["Descansa hasta que la llames"] end,
	}
end

---------------------------------------------------------------------------
-- 8. La Jauría: siempre un sí explícito
---------------------------------------------------------------------------
local function pasoJauria()
	return {
		id = "jauria", corto = "La Jauría",
		titulo = L["¿Quieres que la manada te vea en el mapa del juego?"],
		texto = L["Es opcional. Si dices que sí, los lobos de La Jauría que usan Alfa ven a tu personaje en el mapa de WoW, como ves a tu grupo, y pueden llegar a donde estás con la flecha; y tú a ellos. Alfa solo comparte dónde anda tu personaje dentro del juego: la zona, el punto en el mapa, su nivel y su clase. Nada de tu ubicación real, tu computadora ni tu cuenta."],
		construir = function(pila)
			lyaDice(pila, L["Así la manada se encuentra para cazar juntos. Es tu decisión, y la cambias cuando quieras."], "atento")
			ui.opJauria = eleccion(pila, {
				opciones = {
					{ valor = false, icono = "ic-cerrar", titulo = "No, por ahora",
						texto = "Tu personaje no aparece en el mapa de nadie de La Jauría. Lo cambias cuando quieras en la página de La Jauría." },
					{ valor = true, icono = "ic-manada", titulo = "Sí, que la manada me vea",
						texto = "Tu personaje aparece en el mapa de quienes también se dejan ver. Solo su lugar en el juego y nunca dentro de mazmorras; va por un canal oculto que alguien con otro addon podría leer." },
				},
				leer = function() local m = manada() return m and m.Comparte() and true or false end,
				guardar = function(x) local m = manada() if m then m.Compartir(x and true or false) end end,
			})
			nota(pila, L["Lo apagas o lo enciendes cuando quieras en Manada > La Jauría."])
		end,
		alMostrar = function() if ui.opJauria then ui.opJauria:Refrescar() end end,
		resumen = function()
			local m = manada()
			return (m and m.Comparte()) and L["La manada te ve en el mapa"] or L["La manada no te ve en el mapa"]
		end,
	}
end

---------------------------------------------------------------------------
-- 9. El resumen
---------------------------------------------------------------------------
local function terminar(despues)
	local d = datos()
	d.respondio = M.VERSION
	d.paso = nil
	d.cuando = time and time() or nil
	M.MarcarVisto()
	-- Quien recién configura Alfa ya tiene todo lo nuevo: las notas de esta versión no le salen.
	if M.MarcarNotasVistas then M.MarcarNotasVistas() end
	if v then v:Cerrar() end
	-- Con Hoy (Alfa_Inicio) cargado, el aviso lleva a su página: lo primero que ver.
	local hoy = N.ModuloPorId and N.ModuloPorId("inicio") and { texto = L["Abrir Hoy"], alClic = function() N.Abrir("inicio") end } or nil
	K.Aviso({
		lobo = "aullando", tono = "acento", duracion = hoy and 12 or 8,
		titulo = L["¡Listo! Alfa ya es tuyo"],
		texto = L["Ábrelo con /alfa o con el lobo del minimapa. Para cambiar algo de esto: /alfa bienvenida."],
		accion = hoy,
	})
	M.Aullar()
	A.Fire("ALFA_CONFIGURADO")
	if despues then K.Llamar(despues) end
end

local function pasoResumen()
	local filas = {}
	return {
		id = "resumen", corto = "Resumen",
		titulo = L["Así queda tu Alfa"],
		texto = L["Revisa lo que elegiste. Cada cosa se cambia aquí con «Cambiar» o después en Ajustes."],
		construir = function(pila, a)
			local g = K.GrupoAjustes(pila, {})
			local function agregar(titulo, resumen, i)
				filas[#filas + 1] = { resumen = resumen, fila = g:Fila({ titulo = titulo, texto = "",
					control = function(fila) return K.Boton(fila, L["Cambiar"], function() a:Ir(i) end, { tipo = "secundario", tam = "chico" }) end }) }
			end
			for i, paso in ipairs(a.pasos) do
				if paso.resumen then agregar(L[paso.corto], paso.resumen, i) end
				-- Lo destacado (la ayuda de rotación, resaltar lo de misión), aparte.
				for _, f in ipairs(paso.destacadas or {}) do
					agregar(L[f.titulo], function() return resumenFila(f) end, i)
				end
			end
			ui.resumen = pila:Agregar(g)
		end,
		alMostrar = function()
			for _, x in ipairs(filas) do
				local ok, t = pcall(x.resumen)
				x.fila.alfaDatos.texto = ok and t or ""
			end
			if ui.resumen then ui.resumen:Refrescar() end
		end,
	}
end

local function pasos()
	-- 1.2.4: siete pasos en vez de diez, sin listas a la vista (pasoAjustes
	-- queda para quien quiera volver a las pantallas de interruptores).
	local lista = { pasoIdioma(), lyaHay() and pasoLya() or pasoQueEs(), pasoEstilo(), pasoPerfil() }
	local extras = pasoExtras()
	if extras then lista[#lista + 1] = extras end
	if manada() then lista[#lista + 1] = pasoJauria() end
	lista[#lista + 1] = pasoResumen()
	return lista
end

local function indicePaso(id)
	for i, p in ipairs(ui.asistente.pasos) do if p.id == id then return i end end
	return nil
end

---------------------------------------------------------------------------
-- La portada
---------------------------------------------------------------------------
local function accionPortada()
	local n = ui.asistente and #ui.asistente.pasos or 9
	if M.Pendiente() then
		return {
			lobo = "aullando", tono = "acento", sobre = L["Bienvenida"], titulo = format(L["Alfa %s ya está aquí"], M.VERSION_ALFA),
			texto = L["Antes de salir de caza, configura Alfa a tu medida: el idioma, cómo se ve, qué hace sola por ti y si quieres que la manada te vea en el mapa del juego."],
			progreso = { actual = 0, total = n, huellas = true, texto = format(L["%d pasos, unos 2 minutos"], n) },
			accion = { texto = L["Configurar"], icono = "ic-seguir", alClic = function() M.AbrirVentana("asistente") end },
		}
	end
	return {
		lobo = "normal", tono = "exito", sobre = L["Todo listo"],
		titulo = format(L["Tu estilo: %s"], K.NombreEstilo(K.Estilo()) or ""),
		texto = L["Tu Alfa ya está configurada. Revisa o cambia cualquier respuesta cuando quieras."],
		progreso = { actual = n, total = n, huellas = true, texto = L["Configuración terminada"] },
		accion = { texto = L["Ver mi configuración"], icono = "ic-ajustes", alClic = function() M.AbrirVentana("asistente") end },
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

-- El pie del asistente: "Ir al resumen" a la izquierda de Siguiente, sin
-- "Atrás" en el resumen (solo "Listo"), y "Recargar y seguir" cuando el
-- idioma pide recargar.
local function ajustarPie(a)
	local refrescar = a.Refrescar
	a.Saltar = K.Boton(a, L["Ir al resumen"], function() a:Ir(#a.pasos) end, { tipo = "fantasma" })
	a.Saltar:SetPoint("RIGHT", a.BotonSiguiente, "LEFT", -ESP.s, 0)
	function a:Refrescar()
		refrescar(self)
		local i, n = self:Paso(), #self.pasos
		self.BotonAtras:SetShown(i > 1 and i < n)
		self.Saltar:SetShown(i > 1 and i < n)
		local paso = self.pasos[i]
		if paso and paso.id == "idioma" and cambiaIdioma() then
			self.BotonSiguiente:SetTexto(L["Recargar y seguir"])
		end
	end
	local siguiente = a.Siguiente
	function a:Siguiente()
		local paso = self.pasos[self:Paso()]
		if paso and paso.antesDeSeguir and paso.antesDeSeguir() then return end
		siguiente(self)
	end
	a:Refrescar()
end

local function tituloAsistente()
	local n = #ui.asistente.pasos
	if M.Pendiente() then
		v:SetTitulo(L["Configura tu Alfa"], format(L["%d pasos, unos 2 minutos"], n), "ic-lobo")
	else
		v:SetTitulo(L["Tu configuración de Alfa"], L["Cambia lo que quieras: se guarda al momento."], "ic-ajustes")
	end
end

local function armar()
	v = K.Ventana({
		nombre = "AlfaBienvenidaVentana", titulo = L["Configura tu Alfa"], icono = "ic-lobo",
		ancho = ANCHO, alto = ALTO, desplazar = true,
		alCerrar = function() M.AlCerrar() end,
		fija = true, -- la configuración obligatoria no se cierra al empezar algo
	})
	v.alAcomodar = acomodar

	ui.portada = K.Tablero(v.Cuerpo, { margen = v.margen, accion = "accion", tituloOpciones = L["Lo nuevo en Alfa 1.0"], min = 230 })
	-- Debajo de la tarjeta, las notas de cada versión (la más nueva primero) y
	-- al final lo que trajo la 1.0. Solo las versiones hasta la tuya.
	local tuya = M.VersionAlfa and M.VersionAlfa()
	local primera = true
	for _, n in ipairs(M.NOTAS or {}) do
		if not tuya or M.CompararVersion(n.version, tuya) <= 0 then
			ui.portada:AgregarBloque(K.Seccion(ui.portada.Extra, "Alfa " .. n.version .. DOT .. L[n.titulo]), { espacio = not primera and ESP.xl or nil })
			local b = M.BloquePuntos(ui.portada.Extra)
			b:Set(n)
			ui.portada:AgregarBloque(b, { espacio = ESP.m })
			primera = false
		end
	end
	ui.portada:AgregarBloque(K.Seccion(ui.portada.Extra, L["Lo nuevo en Alfa 1.0"]), { espacio = ESP.xl })
	ui.rejilla10 = ui.portada:AgregarBloque(K.Rejilla(ui.portada.Extra, { min = 230 }), { espacio = ESP.m })
	ui.asistente = K.Asistente(v.Cuerpo, { margen = v.margen, textoTerminar = L["Listo"], alTerminar = function() terminar() end, pasos = pasos() })
	-- Una huella por paso (el Kit pone 10 como tope y aquí hay más pasos).
	if ui.asistente.Huellas then ui.asistente.Huellas.alfaMax = math.max(10, #ui.asistente.pasos) end
	ajustarPie(ui.asistente)
	ui.asistente.alCambiar = function(i)
		if v.Desplazable then v.Desplazable:IrArriba() end
		local p = ui.asistente.pasos[i]
		if M.Pendiente() and p then datos().paso = p.id end
		-- El alto del paso nuevo (sin esto la barra se quedaba con el del anterior).
		acomodarYa()
	end
	ui.asistente:Hide()
	v.alfaPortada, v.alfaAsistente = ui.portada, ui.asistente

	-- Pantalla completa: un velo oscuro detrás tapa el juego y la ventana
	-- llena la pantalla; no se arrastra.
	local velo = CreateFrame("Frame", nil, K.Raiz())
	velo:SetAllPoints(UIParent)
	velo:SetFrameStrata(v:GetFrameStrata())
	velo:SetFrameLevel(math.max(0, v:GetFrameLevel() - 1))
	velo:EnableMouse(true)
	velo.Fondo = velo:CreateTexture(nil, "BACKGROUND")
	velo.Fondo:SetAllPoints(velo)
	velo.Fondo:SetColorTexture(0.02, 0.03, 0.03, 0.82)
	velo:Hide()
	v.alfaVelo = velo
	v:HookScript("OnShow", function() if ui.vista == "asistente" then velo:Show() v:Raise() end end)
	v:HookScript("OnHide", function() velo:Hide() end)
	if v.Cabecera then
		v.Cabecera:SetScript("OnDragStart", nil)
		v.Cabecera:SetScript("OnDragStop", nil)
	end
	local f = CreateFrame("Frame")
	f:RegisterEvent("UI_SCALE_CHANGED")
	f:RegisterEvent("DISPLAY_SIZE_CHANGED")
	f:SetScript("OnEvent", function() if v:IsShown() and ui.vista == "asistente" then M.PantallaCompleta() end end)

	-- En combate la pantalla completa (su velo toma el ratón) no atrapa a nadie:
	-- se esconde al empezar, sin contar como cerrada (M.AlCerrar no hace nada
	-- con M.porCombate), y vuelve donde ibas al terminar la pelea, como las notas.
	local ev = CreateFrame("Frame")
	ev:RegisterEvent("PLAYER_REGEN_DISABLED")
	ev:RegisterEvent("PLAYER_REGEN_ENABLED")
	ev:SetScript("OnEvent", function(_, evento)
		if evento == "PLAYER_REGEN_DISABLED" then
			if v:IsShown() and ui.vista == "asistente" then
				ui.reabrir = true
				M.porCombate = true
				v:Cerrar()
				M.porCombate = nil
			end
		elseif ui.reabrir then
			K.Despues(1, function()
				if not ui.reabrir or (InCombatLockdown and InCombatLockdown()) then return end
				ui.reabrir = nil
				if not v:IsShown() then M.Abrir("pedido", "asistente") end
			end)
		end
	end)
end

-- El asistente esperaba el fin de un combate para volver.
function M.EsperaCombate() return ui.reabrir and true or false end

-- La ventana a toda la pantalla (con un margen corto), centrada.
local MARGEN_PANTALLA = 24
function M.PantallaCompleta()
	if not v then return end
	local w = K.num(UIParent:GetWidth(), ANCHO + 2 * MARGEN_PANTALLA)
	local h = K.num(UIParent:GetHeight(), ALTO + 2 * MARGEN_PANTALLA)
	v:ClearAllPoints()
	v:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	v:SetTamano(math.max(ANCHO, w - 2 * MARGEN_PANTALLA), math.max(ALTO, h - 2 * MARGEN_PANTALLA))
	if v.alfaVelo then v.alfaVelo:Show() end
	acomodarYa()
end

-- La portada (lo nuevo de la versión) es una ventana normal, sin velo.
local function ventanaNormal()
	if v.alfaVelo then v.alfaVelo:Hide() end
	v:ClearAllPoints()
	v:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	v:SetTamano(ANCHO, ALTO)
	acomodarYa()
end

function M.Visible() return v ~= nil and v:IsShown() end

-- Abre la ventana en el asistente (pendiente: donde lo dejaste; terminado:
-- el resumen) o en la portada.
function M.AbrirVentana(vista)
	if not v then armar() end
	ui.vista = vista == "portada" and "portada" or "asistente"
	if ui.vista == "asistente" then
		recomendar()
		ui.portada:Hide()
		ui.asistente:Show()
		local i = 1
		if not M.Pendiente() then
			i = indicePaso("resumen") or 1
		elseif datos().paso then
			i = indicePaso(datos().paso) or 1
		end
		ui.asistente:Ir(i)
		tituloAsistente()
	else
		ui.asistente:Hide()
		ui.portada:Show()
		ui.portada:SetAccion(accionPortada())
		-- Sus huellas, una por paso como en el asistente.
		local h = ui.portada.Accion and ui.portada.Accion.Huellas
		local n = #ui.asistente.pasos
		if h and h.alfaMax < n then
			h.alfaMax = n
			ui.portada:SetAccion(accionPortada())
		end
		ui.portada:SetOpciones({}, false)
		ui.rejilla10:Llenar(novedades())
		v:SetTitulo(format(L["Bienvenida a Alfa %s"], M.VERSION_ALFA), L["Lo nuevo de esta versión"], "ic-lobo")
	end
	v:Abrir()
	if v.Desplazable then v.Desplazable:IrArriba() end
	if ui.vista == "asistente" then M.PantallaCompleta() else ventanaNormal() end
end
