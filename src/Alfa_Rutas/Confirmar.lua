-- Alfa - «Confirma en el juego» (toxic3000 / La Jauría). GPL-3.0. 1.4.0 (7)
--
-- Lo que el banco de pruebas no puede ver: unas 30 cosas de la 1.3.9 y la
-- 1.4.0 que solo se confirman en el juego de verdad (barcos, mazmorras, el
-- instalador, otros idiomas...). /alfa confirmar abre una ventana que las
-- recorre una por una: qué hacer, en pasos cortos, y cómo se ve cuando
-- funciona. Tres botones: «Funciona», «No funciona» y «Saltar» (y «Abrirlo»
-- cuando Alfa te puede llevar ahí). «Ver la lista» las enseña todas con su
-- marca, para saltar a cualquiera.
--
-- Lo que eliges se guarda en la cuenta (AlfaNucleoDB.confirmar) y va solo en
-- tu reporte al desarrollador (/alfa reportar: Alfa_Bienvenida/Reporte.lua lo
-- agrega con AlfaConfirmar.Resumen()), sin nada privado: solo qué cosas
-- funcionan y cuáles no.
--   AlfaNucleoDB.confirmar = { r = { [id] = { e = "si" | "no" | "salto", t, v } }, i = n }
--
-- AlfaConfirmar (global):
--   AlfaConfirmar.Abrir(id)          la ventana (en esa cosa, o donde ibas)
--   AlfaConfirmar.Lista() -> { { id, area, titulo, texto, estado }, ... }
--   AlfaConfirmar.Marcar(id, e) -> ok     e = "si" | "no" | "salto" | nil (borrar)
--   AlfaConfirmar.Cuenta() -> si, no, salto, total
--   AlfaConfirmar.Resumen() -> «Confirmado en el juego: …» | nil (nada respondido)
-- Comando: /alfa confirmar

local ADDON, M = ...
local A, L, N, K = M.A, M.L, M.N, M.K
local ESP = K.ESP
local Cf = {}
M.Confirmar = Cf

local type, ipairs, pairs, pcall, tostring, rawget = type, ipairs, pairs, pcall, tostring, rawget
local format, concat, max, min = string.format, table.concat, math.max, math.min

local ANCHO, ALTO = 620, 480

local function global(nombre, fn, ...)
	local G = rawget(_G, nombre)
	if type(G) == "table" and type(G[fn]) == "function" then return pcall(G[fn], ...) end
	return false
end
local function pagina(id) return function() N.Abrir(id) end end

-- Las cosas por confirmar: { id, area, titulo, texto, abrir }. Los textos
-- son claves de L (se traducen al pintar).
local LISTA = {
	-- Misiones
	{ id = "cerrar.hoy", area = "Misiones", titulo = "«Cerrar mis misiones» desde Hoy",
		texto = "1. Con varias misiones en tu registro, abre Hoy y toca «Cerrar mis misiones».\nFunciona si: al momento sale su avance, luego el resumen, y «Empezar» pone la flecha en la primera parada.",
		abrir = function() global("AlfaRuta", "CerrarTodo", "confirmar") end },
	{ id = "cerrar.mapa", area = "Misiones", titulo = "Tu ruta en los mapas",
		texto = "1. Empieza «Cerrar mis misiones».\n2. Abre el mapa del juego (M) y el mapa de Alfa.\nFunciona si: ves las paradas numeradas, unidas con puntitos." },
	{ id = "cerrar.sigue", area = "Misiones", titulo = "«¡Lista! Sigue: …»",
		texto = "1. Con la ruta de «Cerrar mis misiones» en marcha, entrega una misión.\nFunciona si: sale «¡Lista! Sigue: …», la flecha pasa a la siguiente parada y, al cerrar la última, Lya festeja." },
	{ id = "cerrar.combate", area = "Misiones", titulo = "Pedirla en combate",
		texto = "1. En plena pelea, pide «Cerrar mis misiones».\nFunciona si: dice que espera a que salgas de combate y sigue sola al terminar, sin errores." },
	{ id = "cerrar.ciudad", area = "Misiones", titulo = "La vuelta a la ciudad",
		texto = "1. En el resumen de «Cerrar mis misiones», prende «Al final, a la ciudad: entrenar y vender».\n2. Cierra tu ruta.\nFunciona si: la flecha te lleva a tu entrenador (si tienes algo que aprender) y luego a quien repara." },
	{ id = "guia.restablecer", area = "Misiones", titulo = "Restablecer una guía",
		texto = "1. En el menú (+) del rastreador elige «Restablecer esta guía».\nFunciona si: te deja en el paso que te toca por tu nivel, tus misiones o tu oficio, y «Deshacer» lo regresa." },
	{ id = "guia.nivel", area = "Misiones", titulo = "«Saltar a mi nivel»",
		texto = "1. Sigue una guía que vaya atrás de tu nivel (por ejemplo, una zona que ya pasaste).\nFunciona si: el rastreador te ofrece «Saltar a mi nivel» y te deja en la parte que te toca." },
	{ id = "guia.recompensa", area = "Misiones", titulo = "Qué recompensa elegir",
		texto = "1. Llega a un paso de entregar una misión que te deja elegir recompensa.\nFunciona si: el rastreador dice «Elige: …» con una pieza que te sirve, la misma que marca la ventana de la misión." },
	{ id = "guia.minimapa", area = "Misiones", titulo = "Quien recibe la misión, en el minimapa",
		texto = "1. Camina hacia el PNJ de una entrega de tu guía.\nFunciona si: al acercarte, el minimapa lo marca con el signo de entrega y su nombre al pasar el ratón." },
	{ id = "diario.lleno", area = "Misiones", titulo = "Registro casi lleno",
		texto = "1. Toma misiones hasta tener 18 de 20 en tu registro.\nFunciona si: sale un aviso con «Ver cuáles» que sugiere grises o lejanas para soltar (nunca una lista para entregar)." },
	-- Oficios y recolección
	{ id = "oficio.guia", area = "Oficios", titulo = "Guía de profesión por tramos",
		texto = "1. Abre la Biblioteca de guías > Profesiones y elige Minería o Herrería.\nFunciona si: ves la mejor zona, qué receta hacer y cuántas, y tus materiales con lo de tus otros personajes descontado.",
		abrir = function() global("AlfaRuta", "Biblioteca") end },
	{ id = "oficio.comprar", area = "Oficios", titulo = "«Comprar lo que falta»",
		texto = "1. En una guía de profesión que fabrica, llega al paso de tus materiales.\n2. Toca «Comprar lo que falta».\nFunciona si: tu lista de Comercio tiene lo que te falta, y en la subasta te dice qué buscar." },
	{ id = "recoleccion.llevame", area = "Oficios", titulo = "«Llévame» a un mineral o una hierba",
		texto = "1. Escribe /alfa recoleccion llevame plata.\nFunciona si: te manda a la zona más probable para tu nivel y tu bando, y te dice por qué." },
	{ id = "recoleccion.ruta", area = "Oficios", titulo = "La ruta por todos los puntos",
		texto = "1. Sigue una ruta de recolección y llega a un punto vacío.\nFunciona si: dice «Aquí no hay ahora; voy al siguiente» y la flecha pasa sola al que sigue." },
	{ id = "flecha.clic", area = "Oficios", titulo = "Clic en la flecha",
		texto = "1. Con la flecha a la vista, dale un clic.\nFunciona si: te lleva al siguiente lugar (otro punto de la meta o de tu ruta de recolección)." },
	-- Viaje
	{ id = "viaje.barco", area = "Viaje", titulo = "La tarjeta del barco",
		texto = "1. Ve a un muelle o a una torre de zepelín y espera el transporte.\nFunciona si: sale la tarjeta de Alfa con la cuenta de la salida, la ruta y su momento (muelle, a bordo, llegando)." },
	{ id = "viaje.zona", area = "Viaje", titulo = "El anuncio de zona",
		texto = "1. Entra a una zona nueva.\nFunciona si: el anuncio dice el rango de niveles correcto y no tapa los textos del juego." },
	{ id = "viaje.secreto", area = "Viaje", titulo = "La flecha en combate y en mazmorras",
		texto = "1. Sigue la flecha dentro de una mazmorra y durante una pelea.\nFunciona si: no sale ningún error de Alfa y la flecha sigue diciendo la distancia." },
	-- La Jauría
	{ id = "jauria.lobos", area = "La Jauría", titulo = "Lobos con Alfa",
		texto = "1. Escribe /alfa lobos.\nFunciona si: ves quién de tu hermandad usa Alfa, con su versión y quién debe actualizar." },
	{ id = "jauria.marcador", area = "La Jauría", titulo = "El marcador por bando",
		texto = "1. Abre la página La Jauría.\nFunciona si: el marcador de Horda y Alianza tiene números y no sale vacío.",
		abrir = pagina("manada") },
	{ id = "jauria.tema", area = "La Jauría", titulo = "La temática por bando",
		texto = "1. Prende la temática por bando en Ajustes > Estilo y sonido.\nFunciona si: Alfa se viste de tu bando y todos los textos se leen bien." },
	-- Reportar
	{ id = "reporte.enviar", area = "Reportar", titulo = "Reportar y «Enviar»",
		texto = "1. Escribe /alfa reportar, escribe algo y toca «Enviar».\n2. Abre el instalador de Alfa (Instalar-Alfa.exe).\nFunciona si: el instalador dice que mandó tu reporte.",
		abrir = function() global("AlfaReporte", "Abrir", "comentario") end },
	{ id = "reporte.navegador", area = "Reportar", titulo = "«Enviar ya por el navegador»",
		texto = "1. En la ventana de reportes toca «Enviar ya por el navegador».\n2. Copia el enlace y pégalo en tu navegador.\nFunciona si: el formulario abre con todo ya escrito." },
	-- Mazmorras
	{ id = "mazmorra.mapa", area = "Mazmorras", titulo = "El mapa por dentro de la mazmorra",
		texto = "1. Entra a una mazmorra y abre su página en Alfa.\nFunciona si: ves el plano por dentro, con sus pisos y tu avance por jefes.",
		abrir = pagina("mazmorras") },
	{ id = "mazmorra.antes", area = "Mazmorras", titulo = "«Antes de entrar»",
		texto = "1. Párate en la entrada de una mazmorra con tu grupo.\nFunciona si: la lista «Antes de entrar» se marca sola (grupo, reparar, comida)." },
	{ id = "mazmorra.fuera", area = "Mazmorras", titulo = "Al salir de la mazmorra",
		texto = "1. Sal de la mazmorra y camina por una zona normal.\nFunciona si: Alfa ya no dice que sigues en una mazmorra (ni el rastreador ni Hoy)." },
	{ id = "mazmorra.jefes", area = "Mazmorras", titulo = "Los avisos de jefes del juego",
		texto = "1. Pelea con un jefe de mazmorra.\nFunciona si: salen los avisos de jefes del juego. Forever podría no traerlos: si no salen, elige «No funciona»." },
	-- Hoy y avisos
	{ id = "hoy.primero", area = "Hoy y avisos", titulo = "Hoy: lo primero que conviene",
		texto = "1. Abre Hoy en un pueblo y luego en el campo.\nFunciona si: arriba sale lo que más conviene hacer ahí y cambia según dónde estás.",
		abrir = pagina("inicio") },
	{ id = "avisos.repetidos", area = "Hoy y avisos", titulo = "Avisos que no se repiten",
		texto = "1. Haz algo que dé el mismo aviso varias veces (por ejemplo, entregar misiones seguidas).\nFunciona si: los avisos iguales se callan solos y los distintos sí salen." },
	{ id = "avisos.idiomas", area = "Hoy y avisos", titulo = "Avisos en coreano o chino",
		texto = "1. Pon Alfa en coreano o en chino y espera unos avisos.\nFunciona si: ningún aviso sale cortado ni se sale de su caja." },
	-- Bolsas, pesca, curación y combate
	{ id = "bolsas.recarga", area = "Bolsas y más", titulo = "La recarga en su casilla",
		texto = "1. Usa tu piedra de hogar y abre las bolsas.\nFunciona si: el tiempo de recarga cabe en la casilla, sin cortarse ni encimarse.",
		abrir = pagina("bolsas") },
	{ id = "bolsas.candado", area = "Bolsas y más", titulo = "El candado automático",
		texto = "1. Abre las bolsas con un pico de minero o una montura.\nFunciona si: llevan su candado y «Vender grises» no las toca." },
	{ id = "pesca.records", area = "Bolsas y más", titulo = "Tus récords de pesca",
		texto = "1. Pesca unos peces y abre la página Pesca.\nFunciona si: tus récords dicen la fecha y el lugar.",
		abrir = pagina("pesca") },
	{ id = "curacion.mapa", area = "Bolsas y más", titulo = "El mapa de clics de Curación",
		texto = "1. Abre la página Curación y elige tu especialización.\nFunciona si: el dibujo del ratón dice qué hace cada clic.",
		abrir = pagina("curacion") },
	{ id = "combate.peleas", area = "Bolsas y más", titulo = "Tus últimas peleas",
		texto = "1. Pelea un par de veces y abre la página Combate.\nFunciona si: ves tus últimas peleas con su resumen.",
		abrir = pagina("combate") },
}
Cf.LISTA = LISTA
local POR_ID = {}
for i, x in ipairs(LISTA) do POR_ID[x.id] = i end

local ESTADOS = { si = true, no = true, salto = true }

local function datos()
	local d = N.Datos("confirmar")
	if type(d.r) ~= "table" then d.r = {} end
	return d
end

local function version() return tostring(A.version or N.version or "dev") end

function Cf.Estado(id)
	local r = datos().r[id]
	return type(r) == "table" and ESTADOS[r.e] and r.e or nil
end

function Cf.Marcar(id, e)
	if not POR_ID[id] then return false end
	if e ~= nil and not ESTADOS[e] then return false end
	datos().r[id] = e and { e = e, t = time and time() or 0, v = version() } or nil
	return true
end

function Cf.Lista()
	local out = {}
	for i, x in ipairs(LISTA) do
		out[i] = { id = x.id, area = L[x.area], titulo = L[x.titulo], texto = L[x.texto], estado = Cf.Estado(x.id) }
	end
	return out
end

function Cf.Cuenta()
	local si, no, salto = 0, 0, 0
	for _, x in ipairs(LISTA) do
		local e = Cf.Estado(x.id)
		if e == "si" then si = si + 1 elseif e == "no" then no = no + 1 elseif e == "salto" then salto = salto + 1 end
	end
	return si, no, salto, #LISTA
end

-- Para el reporte: en español (todas las filas del formulario dicen lo
-- mismo), con los ids de lo que no funciona.
function Cf.Resumen()
	local si, no, salto, total = Cf.Cuenta()
	if si + no + salto == 0 then return nil end
	local malos = {}
	for _, x in ipairs(LISTA) do if Cf.Estado(x.id) == "no" then malos[#malos + 1] = x.id end end
	local s = format("Confirmado en el juego (%s): %d funcionan · %d no", version(), si, no)
	if #malos > 0 then s = s .. " (" .. concat(malos, ", ") .. ")" end
	if salto > 0 then s = s .. format(" · %d saltadas", salto) end
	local sin = total - si - no - salto
	if sin > 0 then s = s .. format(" · %d sin probar", sin) end
	return s
end

---------------------------------------------------------------------------
-- La ventana
---------------------------------------------------------------------------
local v
local ui = { vista = "uno", filas = {} }

local ICONO = { si = "ic-exito", no = "ic-cerrar", salto = "ic-flecha" }
local TONO = { si = "exito", no = "aviso", salto = "textoTenue" }
local NOMBRE = { si = "Funciona", no = "No funciona", salto = "Saltada" }

local function actual()
	local d = datos()
	local i = tonumber(d.i) or 1
	if i < 1 or i > #LISTA then i = 1 end
	d.i = i
	return i
end

-- La siguiente sin responder (después de i; si no hay, la primera sin responder).
local function siguienteLibre(i)
	for k = i + 1, #LISTA do if not Cf.Estado(LISTA[k].id) then return k end end
	for k = 1, i do if not Cf.Estado(LISTA[k].id) then return k end end
	return nil
end

local function texto(fs, t, x, y, ancho, lineas)
	if not t or t == "" then fs:Hide() return y end
	K.Escribir(fs, t)
	fs:ClearAllPoints()
	fs:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", x, -y)
	fs:Show()
	return y + K.Parrafo(fs, ancho, lineas or 8)
end

local function fila(i)
	local f = ui.filas[i]
	if f then return f end
	f = CreateFrame("Button", nil, v.Cuerpo)
	f:SetHeight(26)
	f.Icono = K.Icono(f, "ic-ruta", 12, "textoTenue")
	f.Icono:SetPoint("LEFT", f, "LEFT", 4, 0)
	f.Texto = K.Texto(f, "cuerpo", "texto")
	f.Texto:SetPoint("LEFT", f, "LEFT", 24, 0)
	f.Texto:SetPoint("RIGHT", f, "RIGHT", -4, 0)
	f.Texto:SetJustifyH("LEFT")
	f.Texto:SetWordWrap(false)
	f.velo = K.Velo(f, K.CORTE.control, 0.06)
	f.velo:Hide()
	f:SetScript("OnEnter", function(self) self.velo:Show() end)
	f:SetScript("OnLeave", function(self) self.velo:Hide() end)
	f:SetScript("OnClick", function(self)
		datos().i = self.alfaI
		ui.vista = "uno"
		Cf.Pintar()
	end)
	ui.filas[i] = f
	return f
end

local function pie()
	local uno = ui.vista == "uno"
	for _, b in ipairs({ v.Si, v.No, v.Saltar, v.Antes }) do b:SetShown(uno) end
	v.VerLista:SetTexto(uno and L["Ver la lista"] or L["Volver"])
	if uno then
		v:SetPie({ v.Saltar, v.No, v.Si }, { v.VerLista, v.Antes })
	else
		v:SetPie({}, { v.VerLista })
	end
end

local pintando = false
local pintarYa
function Cf.Pintar()
	if not (v and v:IsShown()) or pintando then return end
	pintando = true
	local ok, e = pcall(pintarYa)
	pintando = false
	if not ok and geterrorhandler then geterrorhandler()(e) end
end

pintarYa = function()
	local m = v.margen or ESP.l
	local ancho = v:AnchoCuerpo() - 8
	local x, y = m, ESP.m
	local si, no, salto, total = Cf.Cuenta()
	for _, w in ipairs({ v.Area, v.Titulo, v.Texto, v.Ya, v.BotonAbrir, v.Reportar }) do w:Hide() end
	for _, f in ipairs(ui.filas) do f:Hide() end
	-- Arriba: lo que llevas.
	y = texto(v.Linea, format(L["Llevas %d de %d  ·  %d funcionan  ·  %d no"], si + no + salto, total, si, no), x, y, ancho, 2) + ESP.s
	v.Barra:ClearAllPoints()
	v.Barra:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", x, -y)
	v.Barra:Acomodar(ancho)
	v.Barra:Set(si + no + salto, total)
	y = y + 6 + ESP.l
	if ui.vista == "uno" then
		local i = actual()
		local it = LISTA[i]
		y = texto(v.Area, K.Mayus(format(L["%d de %d  ·  %s"], i, total, L[it.area])), x, y, ancho, 1) + ESP.xs
		y = texto(v.Titulo, L[it.titulo], x, y, ancho, 3) + ESP.m
		y = texto(v.Texto, L[it.texto], x, y, ancho, 10) + ESP.m
		local e = Cf.Estado(it.id)
		if e then
			K.ColorTexto(v.Ya, TONO[e])
			y = texto(v.Ya, format(L["Ya dijiste: %s"], L[NOMBRE[e]]), x, y, ancho, 2) + ESP.m
		end
		if it.abrir then
			v.BotonAbrir:ClearAllPoints()
			v.BotonAbrir:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", x, -y)
			v.BotonAbrir:Show()
			v.alfaAbrir = it.abrir
		end
		if e == "no" and rawget(_G, "AlfaReporte") then
			v.Reportar:ClearAllPoints()
			if it.abrir then v.Reportar:SetPoint("LEFT", v.BotonAbrir, "RIGHT", ESP.s, 0) else v.Reportar:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", x, -y) end
			v.Reportar:Show()
		end
		if it.abrir or (e == "no" and rawget(_G, "AlfaReporte")) then y = y + K.ALTO.botonChico + ESP.m end
		v.Antes:SetActivo(i > 1)
	else
		local area
		local k = 0
		for i, it in ipairs(LISTA) do
			if it.area ~= area then
				area = it.area
				k = k + 1
				local f = fila(k)
				f.alfaI = nil
				f:EnableMouse(false)
				f.Icono:Hide()
				K.Escribir(f.Texto, K.Mayus(L[it.area]))
				K.Fuente(f.Texto, "mayus")
				K.ColorTexto(f.Texto, "textoTenue")
				f:ClearAllPoints()
				f:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", x - 4, -y)
				f:SetWidth(ancho + 8)
				f:Show()
				y = y + 24
			end
			k = k + 1
			local f = fila(k)
			f.alfaI = i
			f:EnableMouse(true)
			local e = Cf.Estado(it.id)
			f.Icono:SetShown(true)
			K.SetIcono(f.Icono, ICONO[e] or "ic-ruta")
			K.ColorTexto(f.Icono, TONO[e] or "textoTenue")
			K.Fuente(f.Texto, "cuerpo")
			K.Escribir(f.Texto, L[it.titulo])
			K.ColorTexto(f.Texto, e and "textoSuave" or "texto")
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", x - 4, -y)
			f:SetWidth(ancho + 8)
			f:Show()
			y = y + 26
		end
	end
	v:SetAltoContenido(y + ESP.m)
	pie()
end

local function responder(e)
	local i = actual()
	Cf.Marcar(LISTA[i].id, e)
	if N.Sonar then N.Sonar(e == "no" and "aviso" or "exito", 3) end
	-- «No funciona» se queda para ofrecer el reporte; lo demás pasa a la siguiente.
	if e ~= "no" then
		local sig = siguienteLibre(i)
		if sig then
			datos().i = sig
		else
			ui.vista = "lista"
			M.Aviso(L["¡Gracias por probar Alfa!"], L["Ya respondiste todo. Va en tu reporte (/alfa reportar)."], { icono = "ic-exito", lobo = "aullando" })
		end
	end
	Cf.Pintar()
end

local function armar()
	v = K.Ventana({ nombre = "AlfaConfirmarVentana", titulo = L["Confirma en el juego"], icono = "ic-exito",
		subtitulo = L["Lo que solo se confirma jugando: una por una"], ancho = ANCHO, alto = ALTO, desplazar = true })
	local c = v.Cuerpo
	v.Linea = K.Texto(c, "nota", "textoSuave")
	v.Linea:SetWordWrap(true)
	v.Barra = K.Progreso(c, { alto = 6, tono = "exito" })
	v.Area = K.Texto(c, "mayus", "acento")
	v.Titulo = K.Texto(c, "titulo", "texto")
	v.Titulo:SetWordWrap(true)
	v.Texto = K.Texto(c, "cuerpo", "textoSuave")
	v.Texto:SetWordWrap(true)
	v.Texto:SetJustifyH("LEFT")
	v.Ya = K.Texto(c, "nota", "exito")
	v.Ya:SetWordWrap(true)
	v.BotonAbrir = K.Boton(c, L["Abrirlo"], function() if v.alfaAbrir then K.Llamar(v.alfaAbrir) end end, { tipo = "secundario", tam = "chico", icono = "ic-flecha" })
	v.Reportar = K.Boton(c, L["Reportarlo"], function() global("AlfaReporte", "Abrir", "error") end, { tipo = "fantasma", tam = "chico" })
	v.Si = K.Boton(v, L["Funciona"], function() responder("si") end, { tipo = "primario", icono = "ic-exito" })
	v.No = K.Boton(v, L["No funciona"], function() responder("no") end, { tipo = "secundario", icono = "ic-cerrar" })
	v.Saltar = K.Boton(v, L["Saltar"], function() responder("salto") end, { tipo = "fantasma" })
	v.Antes = K.Boton(v, L["‹ Anterior"], function()
		local d = datos()
		d.i = max(1, actual() - 1)
		Cf.Pintar()
	end, { tipo = "fantasma" })
	v.VerLista = K.Boton(v, L["Ver la lista"], function()
		ui.vista = ui.vista == "uno" and "lista" or "uno"
		Cf.Pintar()
	end, { tipo = "fantasma" })
	v.alAcomodar = function() Cf.Pintar() end
end

function Cf.Abrir(id)
	if not v then armar() end
	if id and POR_ID[id] then datos().i = POR_ID[id] ui.vista = "uno" end
	if not v:IsShown() then v:Abrir() end
	if v.Desplazable and v.Desplazable.IrArriba then v.Desplazable:IrArriba() end
	Cf.Pintar()
	return v
end
function Cf.Ventana() return v, ui end

A.RegisterCommand("confirmar", function(resto)
	local id = type(resto) == "string" and resto:match("^%s*(%S+)") or nil
	Cf.Abrir(id)
end, L["prueba conmigo lo que solo se confirma en el juego, una cosa a la vez"])

AlfaConfirmar = type(AlfaConfirmar) == "table" and AlfaConfirmar or {}
AlfaConfirmar.Abrir = Cf.Abrir
AlfaConfirmar.Lista = Cf.Lista
AlfaConfirmar.Marcar = Cf.Marcar
AlfaConfirmar.Cuenta = Cf.Cuenta
AlfaConfirmar.Resumen = Cf.Resumen

-- Lya sabe de esto (Pregúntale a Lya).
A.RegisterEvent("PLAYER_LOGIN", function()
	local Lya = rawget(_G, "AlfaLya")
	if not (type(Lya) == "table" and type(Lya.Ensenar) == "function") then return end
	pcall(Lya.Ensenar, { id = "alfa.confirmar", icono = "ic-exito", modulo = M.ID,
		pregunta = L["¿Cómo ayudo a probar Alfa?"],
		respuesta = L["Escribe /alfa confirmar: te enseño una por una las cosas que solo se prueban jugando. Dime si funcionan y lo mando en tu reporte."] })
end)
