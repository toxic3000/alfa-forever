-- Alfa - Lya: «Pregúntale a Lya», la guía de todo Alfa (1.2.4).
-- toxic3000 / La Jauría. GPL-3.0.
--
-- Una ventana del Kit donde Lya te explica Alfa con sus palabras y te lleva
-- a cada cosa con un clic:
--   * su globo arriba: lo que te responde, con «Llévame» cuando hay a dónde;
--   * «Ahora mismo»: lo que te serviría ya (bolsas llenas, equipo roto,
--     misiones por entregar...), solo si aplica;
--   * «Preguntas»: dudas comunes con su respuesta corta;
--   * «Todo lo que hay en Alfa»: una tarjeta por página, sacada de las
--     páginas registradas (N.modulos). Lo que Alfa agregue en el futuro sale
--     aquí solo, sin tocar este archivo.
-- Un buscador filtra las tres listas.
--
-- Otros módulos (y los que vengan) le enseñan a Lya con:
--   AlfaLya.Ensenar({ id, pregunta, respuesta, icono, modulo = "id" | abrir = fn, palabras = "..." })
--   AlfaLya.Guia()   abre la ventana
-- Y cuando llega una página nueva de Alfa (una versión nueva), Lya la
-- presenta una vez: «Hay algo nuevo en Alfa: …», con «Conocerlo».

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID
local ESP = K.ESP

local Gi = {}
M.Guia = Gi

local type, ipairs, pairs, format, lower = type, ipairs, pairs, string.format, string.lower
local floor = math.floor

---------------------------------------------------------------------------
-- Lo que Lya sabe responder
---------------------------------------------------------------------------

local PREGUNTAS = {}
local porId = {}

function Gi.Ensenar(p)
	if type(p) ~= "table" or type(p.id) ~= "string" or type(p.pregunta) ~= "string" or type(p.respuesta) ~= "string" then return false end
	if porId[p.id] then
		for i, x in ipairs(PREGUNTAS) do if x.id == p.id then PREGUNTAS[i] = p end end
	else
		PREGUNTAS[#PREGUNTAS + 1] = p
	end
	porId[p.id] = p
	return true
end

local function hay(id) return N.ModuloPorId and N.ModuloPorId(id) ~= nil end

-- Las de fábrica. Los textos son claves (se traducen al mostrarlos).
local BASE = {
	{ id = "empezar", icono = "ic-hoy", modulo = "inicio", pregunta = "¿Por dónde empiezo?",
		respuesta = "Abre Hoy: ahí te digo lo más útil para este momento en grande, y tu camino a un par de clics." },
	{ id = "guia", icono = "ic-ruta", modulo = "rutas", pregunta = "¿Cómo sigo una guía para subir de nivel?",
		respuesta = "En Ruta eliges a dónde ir y yo te armo el camino. La flecha te lleva paso a paso y el rastrador te dice qué toca." },
	{ id = "cerrar", icono = "ic-misiones", modulo = "rutas", pregunta = "Tengo muchas misiones a medias, ¿qué hago?",
		respuesta = "Pide «Cerrar mis misiones» en Ruta: te llevo a terminar las que llevas y luego a entregarlas, en el mejor orden." },
	{ id = "buscar", icono = "ic-enciclopedia", modulo = "enciclopedia", pregunta = "¿Dónde consigo un objeto o encuentro a alguien?",
		respuesta = "Búscalo en la Enciclopedia: objetos, PNJ, misiones, zonas y raros, con dónde están y el botón «Guíame»." },
	{ id = "talentos", icono = "ic-talentos", modulo = "builds", pregunta = "¿Qué talentos pongo?",
		respuesta = "En Talentos te digo qué punto poner y por qué, según tu clase y cómo juegas." },
	{ id = "rotacion", icono = "ic-nivel", modulo = "combate", pregunta = "¿Qué habilidad uso en combate?",
		respuesta = "Prende la ayuda de rotación en Combate: te sugiero qué usar ahora y qué sigue. Solo sugiero; los botones los presionas tú." },
	{ id = "mazmorras", icono = "ic-mazmorra", modulo = "mazmorras", pregunta = "¿Qué mazmorra me toca?",
		respuesta = "En Mazmorras ves cuáles van con tu nivel, sus jefes, su botín, sus misiones y cómo llegar a la entrada." },
	{ id = "bolsas", icono = "ic-bolsas", modulo = "bolsas", pregunta = "Mis bolsas son un desorden",
		respuesta = "Las bolsas de Alfa acomodan todo por categorías, marcan lo nuevo y lo de misión, y depositan rápido en el banco." },
	{ id = "dinero", icono = "ic-comercio", modulo = "comercio", pregunta = "¿Cuánto vale lo que tengo?",
		respuesta = "En Comercio ves precios de la subasta y qué te conviene vender. Yo vendo lo gris por ti con el comerciante." },
	{ id = "recolectar", icono = "ic-recoleccion", modulo = "recoleccion", pregunta = "¿Dónde hay minas o hierbas?",
		respuesta = "Recolección te marca en el mapa y el minimapa las de tus profesiones, y recuerda dónde las encontraste." },
	{ id = "manada", icono = "ic-manada", modulo = "manada", pregunta = "¿Cómo encuentro a la manada?",
		respuesta = "En La Jauría ves a tu grupo y a los lobos que se dejan ver en el mapa. Puedes seguirlos con la flecha o invitarlos." },
	{ id = "guaridas", icono = "ic-huella", modulo = "manada", pregunta = "¿Cómo me cambio de capa (guarida)?",
		respuesta = "En La Jauría > Guaridas te digo en cuál estás y en cuáles anda la manada. Con «Pedir entrar» te pasas a la de un lobo con la puerta abierta." },
	{ id = "invitar", icono = "ic-manada", modulo = "manada", pregunta = "¿Cómo invito a alguien al clan?",
		respuesta = "Clic derecho en su retrato o en su nombre del chat y elige «Invitar al clan». A tu hermandad le llega con un clic." },
	{ id = "estilo", icono = "ic-apariencia", modulo = "bienvenida", pregunta = "¿Puedo cambiar cómo se ve Alfa?",
		respuesta = "Sí: Alfa, Clásico WoW o Cristal, con tu color. También puede vestir el chat, el minimapa y las barras." },
	{ id = "auto", icono = "ic-ajustes", pregunta = "¿Qué hace Alfa sola por mí?",
		respuesta = "Lo que elegiste al configurarlo: aceptar y entregar misiones, vender lo gris, reparar, tomar vuelos... Lo cambias cuando quieras.",
		abrir = function() local B = rawget(_G, "AlfaBienvenida") if B and B.Abrir then B.Abrir("asistente") end end,
		existe = function() return rawget(_G, "AlfaBienvenida") ~= nil end },
	{ id = "historias", icono = "ic-misiones", pregunta = "Me salté la historia de una misión",
		respuesta = "¡Yo te la guardé! En Historias está todo lo que cuentan tus misiones, para leerlo cuando quieras.",
		abrir = function() if M.Historias then M.Historias.Abrir() end end, existe = function() return M.Historias ~= nil end },
	{ id = "lya", icono = "ic-lobo", modulo = "lya", pregunta = "¿Quién eres, Lya?",
		respuesta = "Soy Lya, la loba de confianza del Alfa. Te acompaño, te cuento el lore de cada lugar y te ayudo con todo lo de Alfa. Y me encantan las salchichas." },
	{ id = "comandos", icono = "ic-info", pregunta = "¿Cómo abro Alfa?",
		respuesta = "Con /alfa, con el lobo del minimapa o dándome clic derecho. Para hablar conmigo de todo esto: /alfa ayuda." },
	-- 1.2.5: más de cada página.
	{ id = "pesca", icono = "ic-pesca", modulo = "pesca", pregunta = "¿Cómo pesco más fácil?",
		respuesta = "En Pesca tienes una sola tecla para equiparte, lanzar y recoger, un diario de lo que sacas y una guía de 1 a 300." },
	{ id = "pescaDonde", icono = "ic-pesca", modulo = "pesca", pregunta = "¿Dónde subo mi pesca?",
		respuesta = "La guía de Pesca te dice a qué agua ir según tu nivel de pesca, y la flecha te lleva." },
	{ id = "mazmorraEntrada", icono = "ic-mazmorra", modulo = "mazmorras", pregunta = "¿Cómo llego a la entrada de una mazmorra?",
		respuesta = "Abre su ficha en Mazmorras y toca «Guíame»: la flecha te lleva hasta la puerta, aunque esté escondida en una cueva." },
	{ id = "mazmorraBotin", icono = "ic-mazmorra", modulo = "mazmorras", pregunta = "¿Qué me puede caer en una mazmorra?",
		respuesta = "En la ficha de cada mazmorra está el botín de cada jefe y lo que mejora tu equipo." },
	{ id = "vender", icono = "ic-comercio", modulo = "comercio", pregunta = "¿Qué me conviene vender en la subasta?",
		respuesta = "Comercio te dice qué vale más en la subasta que con el comerciante, y cuánto pedir." },
	{ id = "recolectarRuta", icono = "ic-recoleccion", modulo = "recoleccion", pregunta = "¿Cómo junto minerales o hierbas más rápido?",
		respuesta = "En Recolección eliges qué buscar y te marco en el mapa los puntos de tus profesiones, con los que ya encontraste." },
	{ id = "curar", icono = "ic-curacion", modulo = "curacion", pregunta = "¿Cómo curo a mi grupo más fácil?",
		respuesta = "Prende los marcos de Curación: pasas el ratón sobre un compañero y con un clic lo curas." },
	{ id = "medidor", icono = "ic-nivel", modulo = "combate", pregunta = "¿Cuánto daño hago?",
		respuesta = "En Combate tienes el medidor de daño del grupo y la ayuda de rotación para tu clase." },
	{ id = "mapa", icono = "ic-mapa", modulo = "mundo", pregunta = "¿Cómo marco un lugar en el mapa?",
		respuesta = "En Mundo pones tus marcadores, los compartes con tu grupo y la flecha te lleva a ellos." },
	{ id = "paisaje", icono = "ic-mundo", modulo = "vista", pregunta = "¿Cómo hago que el juego se vea mejor?",
		respuesta = "En Paisaje y gráficos hay un paisaje más bonito con un clic, y cada ajuste gráfico explicado." },
	{ id = "dia", icono = "ic-huella", pregunta = "¿Cómo me fue hoy?",
		respuesta = "Te llevo la cuenta de tu día de caza: misiones, niveles, oro, raros y el tiempo. Escribe /alfa lya dia y te lo cuento.",
		existe = function() return M.Dia ~= nil end, abrir = function() if M.Dia then M.Dia.Contar() end end },
	{ id = "anunciar", icono = "ic-misiones", pregunta = "¿Mi grupo ve cuando completo una misión?",
		respuesta = "Sí: sale «[Misión] está lista para entregar» y «¡Misión completada!» en el chat del grupo. Solo, te sale a ti." },
	{ id = "rarosManada", icono = "ic-raros", modulo = "manada", pregunta = "¿Cómo me entero de raros de la manada?",
		respuesta = "Cuando un lobo de la manada encuentra un raro, te aviso en qué guarida está y te dejo pedir entrar con un clic." },
	-- 1.2.6
	{ id = "llamar", icono = "ic-manada", modulo = "manada", pregunta = "¿Cómo pido ayuda a la manada?",
		respuesta = "En La Jauría > Guaridas toca «Llamar a la manada» (o escribe /alfa manada llamar): los lobos de tu zona reciben tu lugar y te aviso quién viene." },
	{ id = "dijiste", icono = "ic-lobo", pregunta = "¿Qué me dijiste hace rato?",
		respuesta = "Arriba en esta ventana está lo último que te dije, con sus botones. Para ver los 20 más recientes: /alfa lya historial." },
	{ id = "semana", icono = "ic-nivel", pregunta = "¿Cómo me fue esta semana?",
		respuesta = "Te llevo la cuenta de tu semana de caza y tu mejor día. Escribe /alfa lya semana y te lo cuento.",
		existe = function() return M.Dia ~= nil end, abrir = function() if M.Dia then M.Dia.ContarSemana() end end },
	{ id = "tecla", icono = "ic-mando", pregunta = "¿Puedo llamarte con una tecla?",
		respuesta = "Sí: en las asignaciones de teclas del juego, en la sección Alfa, ponle una tecla a «Pregúntale a Lya» y otra a «Lo que te ofrece Lya», que hace lo de su botón." },
	-- 1.2.9
	{ id = "muerte", icono = "ic-huella", modulo = "lya", pregunta = "Me morí, ¿corro por mi cuerpo o voy con el ángel?",
		respuesta = "Cuando sales como espíritu te digo a cuánto está tu cuerpo, lo que cuesta el ángel a tu nivel y qué conviene. La flecha te lleva." },
	{ id = "claseHechizos", icono = "ic-talentos", modulo = "lya", pregunta = "Aprendí un hechizo nuevo, ¿para qué sirve?",
		respuesta = "Cada vez que aprendes uno de los principales de tu clase te digo en corto para qué sirve y cuándo usarlo." },
	{ id = "foco", icono = "ic-mazmorra", modulo = "lya", pregunta = "¿Te puedes hacer a un lado en las peleas?",
		respuesta = "Sí: con el modo foco, en mazmorras y en combate me hago chiquita y me callo. Al terminar vuelvo. Está en mis ajustes." },
	{ id = "momento", icono = "ic-reloj", modulo = "lya", pregunta = "¿Hay alguna fiesta hoy en Azeroth?",
		respuesta = "Si hay fiesta te lo digo al entrar. Y según la hora y la zona te cuento lo que pasa por ahí." },
}
for _, p in ipairs(BASE) do p.base = true Gi.Ensenar(p) end

local function vigente(p)
	if p.existe then
		local ok, si = pcall(p.existe)
		return ok and si and true or false
	end
	if p.modulo then return hay(p.modulo) end
	return true
end

local function texto(p, campo)
	local t = p[campo]
	if p.base then return L[t] end
	return t
end

-- Abrir lo de una pregunta o una página.
local function llevar(p)
	if p.abrir then return K.Llamar(p.abrir) end
	if p.modulo then N.Abrir(p.modulo) end
end

---------------------------------------------------------------------------
-- Ahora mismo: lo que te serviría ya
---------------------------------------------------------------------------
local function ahora()
	local Ce = M.Cerebro
	local lista = {}
	-- Tu día de caza (Dia.lua, 1.2.5), siempre primero.
	if M.Dia then
		local r = M.Dia.Resumen()
		lista[#lista + 1] = { icono = "ic-huella", titulo = L["Tu día de caza"],
			texto = r and format(L["Hoy llevas %s"], r) or L["Hoy todavía no cazamos nada. ¿Salimos?"], existe = true }
		-- 1.2.6: tu semana y tu mejor día.
		local rs = M.Dia.Resumen(M.Dia.Semana())
		if rs then
			local rec = M.Dia.Record()
			lista[#lista + 1] = { icono = "ic-nivel", titulo = L["Tu semana de caza"],
				texto = format(L["Esta semana llevas %s"], rs) .. ((rec and (tonumber(rec.misiones) or 0) > 0) and (" " .. format(L["Tu mejor día: %d misiones."], rec.misiones)) or ""),
				existe = true }
		end
	end
	local d = Ce.PeorDurabilidad and Ce.PeorDurabilidad()
	if d and d <= 40 then
		lista[#lista + 1] = { icono = "ic-alerta", titulo = L["Tu equipo está por romperse"],
			texto = format(L["Lo más gastado va al %d %%. Te llevo con quien repare."], math.floor(d + 0.5)),
			fn = function() local C = rawget(_G, "AlfaCerca") if C and C.Ir then C.Ir("repair") end end,
			existe = rawget(_G, "AlfaCerca") ~= nil }
	end
	local libres = Ce.BolsasLibres and Ce.BolsasLibres()
	if libres and libres <= 4 then
		lista[#lista + 1] = { icono = "ic-bolsas", titulo = L["Casi no te queda espacio"],
			texto = format(L["Te quedan %d espacios en las bolsas. Vende lo gris o guarda en el banco."], libres),
			fn = function() if Ce.AbrirBolsas then Ce.AbrirBolsas() end end, existe = true }
	end
	local R = rawget(_G, "AlfaRuta")
	if type(R) == "table" and type(R.Listas) == "function" then
		local ok, n = pcall(R.Listas)
		if ok and type(n) == "number" and n >= 2 then
			lista[#lista + 1] = { icono = "ic-misiones", titulo = format(L["%d misiones listas para entregar"], n),
				texto = L["Te llevo a entregarlas todas en el mejor orden."], fn = function() if Ce.EntregarTodas then Ce.EntregarTodas() end end, existe = true }
		end
	end
	local B = rawget(_G, "AlfaBienvenida")
	if B and B.Notas then
		lista[#lista + 1] = { icono = "ic-lobo", titulo = L["Lo nuevo de esta versión"],
			texto = L["Lo que trajo la última versión de Alfa, contado corto."], fn = function() B.Notas() end, existe = true }
	end
	local out = {}
	for _, x in ipairs(lista) do if x.existe then out[#out + 1] = x end end
	return out
end

---------------------------------------------------------------------------
-- La ventana
---------------------------------------------------------------------------
local v
local ui = {}

-- (1.3.2) Para buscar: sin mayúsculas ni acentos, también en cirílico
-- («misión» = «mision», «Карта» = «карта», «Ёж» = «еж»). string.lower solo
-- cambia las letras de ASCII.
local PLIEGUE = {}
do
	local function de(cp)
		if cp < 0x80 then return string.char(cp) end
		return string.char(0xC0 + floor(cp / 64), 0x80 + cp % 64)
	end
	local LATIN = {
		[0xC0] = "a", [0xC1] = "a", [0xC2] = "a", [0xC3] = "a", [0xC4] = "a", [0xC5] = "a", [0xC6] = "ae", [0xC7] = "c",
		[0xC8] = "e", [0xC9] = "e", [0xCA] = "e", [0xCB] = "e", [0xCC] = "i", [0xCD] = "i", [0xCE] = "i", [0xCF] = "i",
		[0xD0] = "d", [0xD1] = "n", [0xD2] = "o", [0xD3] = "o", [0xD4] = "o", [0xD5] = "o", [0xD6] = "o", [0xD8] = "o",
		[0xD9] = "u", [0xDA] = "u", [0xDB] = "u", [0xDC] = "u", [0xDD] = "y", [0xDF] = "ss",
	}
	for cp, base in pairs(LATIN) do
		PLIEGUE[de(cp)] = base
		if cp ~= 0xDF then PLIEGUE[de(cp + 0x20)] = base end -- la minúscula
	end
	PLIEGUE[de(0xFF)] = "y"
	-- Cirílico: А-Я -> а-я, Ё/ё -> е.
	for cp = 0x410, 0x42F do PLIEGUE[de(cp)] = de(cp + 0x20) end
	PLIEGUE[de(0x401)], PLIEGUE[de(0x451)] = de(0x435), de(0x435)
end

-- Los textos de las preguntas no cambian: se pliegan una vez (con tope, por
-- si acaso). Lo que escribes no se guarda.
local plegados, nPlegados = {}, 0
local function plegar(s, guardar)
	if type(s) ~= "string" then return "" end
	local ya = plegados[s]
	if ya then return ya end
	local r = s:gsub("[A-Z]", lower):gsub("[\192-\223][\128-\191]", PLIEGUE)
	if guardar then
		if nPlegados >= 2000 then plegados, nPlegados = {}, 0 end
		plegados[s], nPlegados = r, nPlegados + 1
	end
	return r
end
Gi.Plegar = plegar

-- Cada palabra de lo que buscas debe estar en alguno de los textos.
local function coincide(filtro, ...)
	if filtro == "" then return true end
	local partes = {}
	for i = 1, select("#", ...) do
		local s = select(i, ...)
		if type(s) == "string" then partes[#partes + 1] = plegar(s, true) end
	end
	local todo = table.concat(partes, " ")
	for palabra in filtro:gmatch("%S+") do
		if not todo:find(palabra, 1, true) then return false end
	end
	return true
end
Gi.Coincide = coincide -- (para el banco)

-- El globo de Lya: lo que dice y a dónde lleva.
local function globo(padre)
	local b = CreateFrame("Frame", nil, padre)
	b.caja = K.Caja(b, { fondo = "panel", borde = "acento", corte = K.CORTE.panel, alfaBorde = 0.6 })
	b.Lobo = b:CreateTexture(nil, "ARTWORK")
	b.Lobo:SetSize(64, 64)
	b.Lobo:SetTexture(K.Lobo("atento"))
	K.Pintar(b.Lobo, function(t) t:SetVertexColor(K.Color("acento")) end)
	b.Nombre = K.Texto(b, "mayus", "acento")
	b.Texto = K.Texto(b, "cuerpo", "texto")
	b.Ir = K.Boton(b, L["Llévame"], function() if b.alfaP then llevar(b.alfaP) end end, { tipo = "primario", icono = "ic-seguir" })
	function b:Decir(t, p)
		self.alfaP = p
		K.Escribir(self.Nombre, K.Mayus and K.Mayus("Lya") or "LYA")
		K.Escribir(self.Texto, t)
		K.Mostrar(self.Ir, p ~= nil and (p.abrir ~= nil or p.modulo ~= nil or p.fn ~= nil))
		if p and p.fn then self.Ir.alClic = function() K.Llamar(p.fn) end
		else self.Ir.alClic = function() if self.alfaP then llevar(self.alfaP) end end end
		if v and v.alAcomodar then v.alAcomodar() end
	end
	function b:Acomodar(ancho)
		self:SetWidth(ancho)
		local pad = ESP.l
		local x = pad + 64 + ESP.base
		local w = ancho - x - pad
		self.Lobo:ClearAllPoints()
		self.Lobo:SetPoint("TOPLEFT", self, "TOPLEFT", pad, -pad)
		local y = pad
		self.Nombre:ClearAllPoints()
		self.Nombre:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
		y = y + K.AltoTexto(self.Nombre) + 4
		self.Texto:ClearAllPoints()
		self.Texto:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
		y = y + K.Parrafo(self.Texto, w) + ESP.m
		if self.Ir:IsShown() and not self.Ir.alfaOculto then
			self.Ir:ClearAllPoints()
			self.Ir:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
			y = y + K.num(self.Ir:GetHeight(), K.ALTO.boton) + ESP.m
		end
		local alto = math.max(y - ESP.m + pad, pad * 2 + 64)
		self:SetHeight(alto)
		return alto
	end
	return b
end

local function decir(t, p)
	if ui.globo then ui.globo:Decir(t, p) end
	-- Si está en pantalla, da un saltito al responder.
	local UI = M.UI
	if UI and UI.Saltar and UI.Visible and UI.Visible() then pcall(UI.Saltar) end
end

local function llenar()
	local filtro = plegar(ui.buscador and ui.buscador:Texto() or "")
	-- Lo último que dijo (sin buscar; con «historial», los 20; si no, 3).
	local dijo = {}
	local Ce = M.Cerebro
	if filtro == "" and Ce and Ce.historial then
		for i, h in ipairs(Ce.historial) do
			if i > (ui.todoDijo and 20 or 3) then break end
			local a = h.acciones and h.acciones[1]
			dijo[#dijo + 1] = { icono = "ic-lobo", titulo = h.texto, texto = h.hora, ayuda = h.texto, -- (1.3.2) completo al pasar el ratón
				alClic = function() decir(h.texto, a and not a.seguro and { fn = a.fn } or nil) end }
		end
	end
	K.Mostrar(ui.secDijo, #dijo > 0)
	K.Mostrar(ui.rejDijo, #dijo > 0)
	ui.rejDijo:Llenar(dijo)
	-- Ahora mismo
	local ya = {}
	if filtro == "" then
		for _, x in ipairs(ahora()) do
			ya[#ya + 1] = { icono = x.icono, titulo = x.titulo, texto = x.texto, tono = "aviso", ayuda = x.texto, -- (1.3.2) completo al pasar el ratón
				alClic = function() decir(x.texto, x) end }
		end
	end
	ui.secAhora:SetShown(#ya > 0)
	K.Mostrar(ui.secAhora, #ya > 0)
	K.Mostrar(ui.rejAhora, #ya > 0)
	ui.rejAhora:Llenar(ya)
	-- Preguntas
	local qs = {}
	-- Desde el «?» de una página (1.2.5): primero lo de esa página.
	local tema = filtro == "" and ui.tema or nil
	local delTema = 0
	if tema then for _, p in ipairs(PREGUNTAS) do if p.modulo == tema and vigente(p) then delTema = delTema + 1 end end end
	if delTema == 0 then tema = nil end
	for _, p in ipairs(PREGUNTAS) do
		if vigente(p) and (not tema or p.modulo == tema) then
			local q, r = texto(p, "pregunta"), texto(p, "respuesta")
			if coincide(filtro, q, r, p.palabras) then
				qs[#qs + 1] = { icono = p.icono or "ic-info", titulo = q, alClic = function() decir(r, p) end }
			end
		end
	end
	K.Mostrar(ui.secPreg, #qs > 0)
	K.Mostrar(ui.rejPreg, #qs > 0)
	ui.rejPreg:Llenar(qs)
	-- Todo lo que hay en Alfa: las páginas registradas (también las futuras).
	local mods = {}
	local lista = {}
	for _, m in ipairs(N.modulos or {}) do lista[#lista + 1] = m end
	table.sort(lista, function(a, b) return (a.orden or 99) < (b.orden or 99) end)
	for _, m in ipairs(lista) do
		local nombre, sub = m.nombre or m.id, m.subtitulo or ""
		if coincide(filtro, nombre, sub, m.id) then
			mods[#mods + 1] = { icono = m.icono or "ic-lobo", titulo = nombre, texto = sub,
				alClic = function()
					decir(sub ~= "" and format(L["%s: %s"], nombre, sub) or nombre, { modulo = m.id })
				end }
		end
	end
	K.Mostrar(ui.secMods, #mods > 0)
	K.Mostrar(ui.rejMods, #mods > 0)
	ui.rejMods:Llenar(mods)
	K.Mostrar(ui.vacio, #qs == 0 and #mods == 0)
	if v and v.alAcomodar then v.alAcomodar() end
end

local function acomodar()
	if not (v and v:IsShown() and ui.pila) then return end
	local ancho = v:AnchoCuerpo() - 2 * v.margen
	local h = ui.pila:Acomodar(ancho)
	ui.pila:ClearAllPoints()
	ui.pila:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", v.margen, -v.margen)
	v:SetAltoContenido(h + 2 * v.margen)
end

local function armar()
	v = K.Ventana({ nombre = "AlfaLyaGuia", titulo = L["Pregúntale a Lya"], icono = "ic-lobo", ancho = 760, alto = 640, desplazar = true })
	v:SetTitulo(L["Pregúntale a Lya"], L["Todo lo de Alfa, explicado por Lya y a un clic"], "ic-lobo")
	v.alAcomodar = acomodar
	local p = K.Pila(v.Cuerpo, { espacio = ESP.base })
	ui.pila = p
	ui.globo = p:Agregar(globo(p))
	ui.buscador = p:Agregar(K.Buscador(p, { ayuda = L["¿Qué buscas? Escribe una palabra"], alCambiar = function() ui.tema = nil llenar() end }), { espacio = ESP.l })
	-- 1.2.6: lo último que dijo Lya, con sus botones.
	ui.secDijo = p:Agregar(K.Seccion(p, L["Lo último que te dije"]), { espacio = ESP.l })
	ui.rejDijo = p:Agregar(K.Rejilla(p, { min = 300, variante = "compacta" }), { espacio = ESP.s })
	ui.secAhora = p:Agregar(K.Seccion(p, L["Ahora mismo te ayudaría con"]), { espacio = ESP.l })
	ui.rejAhora = p:Agregar(K.Rejilla(p, { min = 220, variante = "compacta" }), { espacio = ESP.s })
	ui.secPreg = p:Agregar(K.Seccion(p, L["Preguntas"]), { espacio = ESP.l })
	ui.rejPreg = p:Agregar(K.Rejilla(p, { min = 300, variante = "compacta" }), { espacio = ESP.s })
	ui.secMods = p:Agregar(K.Seccion(p, L["Todo lo que hay en Alfa"]), { espacio = ESP.l })
	ui.rejMods = p:Agregar(K.Rejilla(p, { min = 220 }), { espacio = ESP.s })
	local vacio = CreateFrame("Frame", nil, p)
	vacio.Texto = K.Texto(vacio, "nota", "textoTenue")
	vacio.Texto:SetPoint("TOPLEFT")
	K.Escribir(vacio.Texto, L["No sé de eso todavía. Prueba con otra palabra, o pregúntale a la manada en el Discord."])
	function vacio:Acomodar(ancho) local h = K.Parrafo(self.Texto, ancho) self:SetHeight(h) return h end
	ui.vacio = p:Agregar(vacio, { espacio = ESP.l })
end

local SALUDOS = {
	"¡Hola! Pregúntame lo que quieras de Alfa: te lo explico corto y te llevo.",
	"¿En qué te ayudo? Toca una pregunta o una página y te cuento.",
	"Aquí estoy. Si no sabes por dónde empezar, toca «¿Por dónde empiezo?».",
}

-- pregunta: el id de una pregunta para responderla; tema: el id de una
-- página (el «?» de su cabecera) para empezar por lo de esa página.
function Gi.Abrir(pregunta, tema, historial)
	ui.todoDijo = historial and true or false
	if not N.Permitido or N.Permitido() then
		if not v then armar() end
		v:Abrir()
		if ui.buscador and ui.buscador.SetTexto then ui.buscador:SetTexto("", true) end
		ui.tema = tema
		llenar()
		local p = pregunta and porId[pregunta]
		local m = tema and N.ModuloPorId and N.ModuloPorId(tema)
		if p and vigente(p) then decir(texto(p, "respuesta"), p)
		elseif m then
			decir(format(L["Estás en %s. %s Abajo tienes lo que más me preguntan de aquí."], m.nombre or tema, m.subtitulo or ""), nil)
		else decir(L[SALUDOS[math.random(#SALUDOS)]], nil) end
		K.Despues(0.05, acomodar)
		return true
	end
	return false
end

function Gi.Visible() return v ~= nil and v:IsShown() end

---------------------------------------------------------------------------
-- Lo nuevo de Alfa: Lya presenta cada página nueva una vez
---------------------------------------------------------------------------
local function presentarNuevas()
	local d = N.Datos(ID)
	local primera = type(d.conocidos) ~= "table"
	d.conocidos = type(d.conocidos) == "table" and d.conocidos or {}
	local nueva
	for _, m in ipairs(N.modulos or {}) do
		if not d.conocidos[m.id] then
			d.conocidos[m.id] = true
			if not primera and not nueva then nueva = m end
		end
	end
	if not nueva then return end
	local Ce = M.Cerebro
	Ce.Decir({ id = "nuevo:" .. nueva.id, importante = true, salto = true,
		texto = format(L["¡Hay algo nuevo en Alfa: %s! ¿Te lo enseño?"], nueva.nombre or nueva.id),
		acciones = { { texto = L["Conocerlo"], fn = function() N.Abrir(nueva.id) end },
			{ texto = L["Pregúntale a Lya"], fn = function() Gi.Abrir() end } } })
end

A.OnLogin(function() A.After(25, function() pcall(presentarNuevas) end) end)

---------------------------------------------------------------------------
-- Entradas: /alfa ayuda, /alfa lya ayuda (Cerebro.lua), el menú de Lya
-- (Lya.lua) y AlfaLya.Guia()
---------------------------------------------------------------------------
A.RegisterCommand("ayuda", function() Gi.Abrir() end, L["Pregúntale a Lya: todo lo de Alfa explicado y a un clic"])
-- La tecla (Bindings.xml, 1.2.5), en la sección Alfa de las teclas del juego.
BINDING_NAME_ALFA_LYA_GUIA = L["Pregúntale a Lya"]
BINDING_NAME_ALFA_LYA_BOTON = L["Lo que te ofrece Lya (su botón)"]

local API = AlfaLya
if type(API) == "table" then
	API.Guia = function(pregunta, tema) return Gi.Abrir(pregunta, tema) end
	API.Ensenar = function(p)
		if type(p) ~= "table" then return false end
		local c = {}
		for k, x in pairs(p) do c[k] = x end
		c.base = nil
		return Gi.Ensenar(c)
	end
end
