-- Alfa - Bolsas (toxic3000 / La Jauría). GPL-3.0.
--
-- Tus bolsas y tu banco en una sola ventana de Alfa, con tres vistas (todo
-- junto, por categorías o por bolsa), la barra de las bolsas equipadas,
-- ordenar, buscar, marcas sobre cada objeto, el inventario de todos tus
-- personajes (también en el cuadro de cada objeto), depositar rápido y
-- comprar espacio en el banco, y qué vender o conservar cuando las bolsas se
-- empiezan a llenar. Todo con código propio.
--
-- Archivos (en el orden del .toc):
--   Bolsas.lua       registro del módulo, ajustes y utilidades comunes (este)
--   Datos.lua        el registro por personaje y los conteos del cuadro de objeto
--   Objetos.lua      datos de cada objeto, categorías y búsqueda
--   Botones.lua      los botones de objeto (seguros en vivo, de foto) y sus marcas
--   Lotes.lua        mover objetos por lotes tras un clic (depositar, vender)
--   Banco.lua        depositar rápido y comprar espacio en el banco
--   Sugerencias.lua  qué vender o conservar cuando las bolsas se llenan
--   Barra.lua        la barra de las bolsas equipadas (ver, cambiar, resaltar)
--   Ventana.lua      las ventanas de bolsas y de banco
--   Reemplazo.lua    abrir la ventana de Alfa en lugar de las bolsas de Blizzard
--   Pagina.lua       la página "Bolsas" en la ventana de Alfa

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)

M.N, M.A, M.L = N, A, L
M.ID = "bolsas"

local type, tonumber, pairs, pcall = type, tonumber, pairs, pcall

---------------------------------------------------------------------------
-- Ajustes (AlfaDB.settings.bolsas)
---------------------------------------------------------------------------

M.AJUSTES = {
	vista = "categorias",     -- "una" (todo junto) | "categorias" | "bolsa"
	tamIcono = 36,            -- lado de cada casilla, en puntos
	columnas = 10,            -- casillas por fila
	reemplazar = true,        -- abrir la ventana de Alfa en lugar de las bolsas de Blizzard
	banco = true,             -- y en lugar del banco de Blizzard
	llavero = true,           -- mostrar el llavero junto a las bolsas
	ordenar = true,           -- el botón Ordenar
	ordenarInverso = false,   -- ordenar de derecha a izquierda
	marcaNivel = true,        -- nivel de objeto
	marcaCalidad = true,      -- borde del color de la calidad
	marcaChatarra = true,     -- moneda sobre la chatarra
	marcaNuevos = true,       -- brillo en los objetos nuevos
	marcaMejora = true,       -- flecha de mejora
	marcaMision = true,       -- marca de objeto de misión (el marco dorado fijo)
	brilloMision = true,      -- los objetos de misión brillan (borde que late e insignia «!»)
	cuadroConteo = true,      -- "Tienes 12 (...)" en el cuadro de cada objeto
	barra = true,             -- la barra de las bolsas equipadas en la ventana
	avisoLleno = true,        -- avisar (y sugerir qué vender) cuando se llenan
	avisoLibres = 4,          -- ... al quedar estas casillas libres o menos
	avisoCasiLleno = true,    -- 1.2.8: aviso con 2 casillas libres o menos (Sugerencias.lua)
	ponteEsto = true,         -- 1.2.9: «Ponte esto» con el equipo nuevo que es mejor (Mejora.lua)
	queGuardar = true,        -- 1.2.9: qué guardar en el banco o para otro personaje (Guardar.lua)
	conjuntos = true,         -- 1.3.0: conjuntos de equipo con nombre (Conjuntos.lua)
	comparar = true,          -- 1.3.0: +/- contra lo que llevas, en el cuadro del equipo (Comparar.lua)
	buscarTodos = true,       -- 1.3.0: buscar en todos tus personajes, en la página (Todos.lua)
	acomodar = true,          -- 1.3.0: el botón «Acomodar» (Acomodar.lua)
	barraConjuntos = false,   -- 1.4.0: apagado (tapaba las pestañas de Forever; migración 5). 1.3.7: un botón por conjunto junto a tu personaje (Cambio.lua)
	nivelPersonaje = true,    -- 1.3.7: nivel de objeto y durabilidad en tu personaje y la inspección (Ranuras.lua)
	atajos = true,            -- 1.3.7: «3 nuevos» y «1 mejora» en la búsqueda, a un clic (Atajos.lua)
	separar = true,           -- 1.3.8: el botón «Separar»: subasta o vendedor (Separar.lua)
	candado = true,           -- 1.3.8: el candado de objetos: no se borra ni se vende por error (Candado.lua)
	candadoAuto = true,       -- 1.3.8: candado solo en lo épico, de misión, la piedra de hogar y tus conjuntos
	candadoCuenta = false,    -- 1.3.8: los candados nuevos valen para toda la cuenta
	separarEpicos = false,    -- 1.3.9: «Separar» marca también lo épico con candado que vale para la subasta
	sobra = true,             -- 1.3.9: el botón «Lo que me sobra»: vender o mandar a otro personaje (Sobra.lua)
	ordenarModo = "juego",    -- 1.3.9: "juego" (el del juego) | "tipo" | "calidad" | "nombre" (Ordenar.lua)
	ordenarCandado = false,   -- 1.3.9: Ordenar deja en su lugar lo que tiene candado (con el orden de Alfa)
	porAbrir = true,          -- 1.4.0 (diario): «Abrir» lo que se abre y «Aprender» las recetas nuevas (Abrir.lua)
	paraMisiones = true,      -- 1.4.0 (diario): lo que piden tus misiones y está en tu banco (ParaMisiones.lua)
	deposito = "banco",       -- lo último que elegiste en "Depositar"
}

M.VISTAS = { una = true, categorias = true, bolsa = true }

-- Para la búsqueda de ajustes de la ventana de Alfa (la página es propia,
-- Pagina.lua): los mismos ajustes que la página, con su texto.
local function clave(k) return M.ID .. "." .. k end
local function apagado(k) return function() return not M.Get(k) end end
local function entero(v) return tostring(math.floor(v + 0.5)) end

-- "Objetos de misión": un solo selector para brilloMision y marcaMision
-- (brilloMision manda, Botones.lua), igual que en la página.
local function misionActual()
	if M.Get("brilloMision") then return "brillo" end
	return M.Get("marcaMision") and "marco" or "nada"
end

local CONTROLES = {
	{ kind = "dropdown", key = clave("vista"), label = L["Vista"],
		help = L["Todo junto muestra cada casilla en su lugar; por categorías agrupa equipo, consumibles, misiones y materiales; por bolsa pone cada bolsa en su bloque."],
		choices = { { value = "una", label = L["Todo junto"] }, { value = "categorias", label = L["Categorías"] }, { value = "bolsa", label = L["Por bolsa"] } },
		get = function() return M.Vista() end, set = function(v) M.Set("vista", v) end,
		search = "bag view, categories, all in one, by bag" },
	{ kind = "slider", key = clave("tamIcono"), label = L["Tamaño de las casillas"], help = L["Qué tan grande se ve cada casilla."],
		min = 28, max = 48, step = 1, format = function(v) return math.floor(v + 0.5) .. " px" end, search = "icon size, slot size" },
	{ kind = "slider", key = clave("columnas"), label = L["Columnas"], help = L["Cuántas casillas caben en cada fila."],
		min = 6, max = 20, step = 1, format = entero, search = "columns, width" },
	{ kind = "toggle", key = clave("barra"), label = L["Barra de tus bolsas"],
		help = L["Arriba de la ventana, cada bolsa equipada con su espacio: pasa el ratón para resaltar lo que lleva y arrastra otra bolsa para cambiarla."],
		search = "bag bar, equipped bags" },
	{ kind = "toggle", key = clave("llavero"), label = L["Mostrar el llavero"], help = L["Tus llaves junto a tus bolsas."], search = "keyring, keys" },
	{ kind = "toggle", key = clave("reemplazar"), label = L["Usar las bolsas de Alfa"],
		help = L["La B, Mayús+B, la tecla de cada bolsa y los comerciantes abren la ventana de Alfa. Apágalo para volver a las del juego."],
		search = "replace bags, blizzard bags, one bag" },
	{ kind = "toggle", key = clave("banco"), label = L["Usar el banco de Alfa"], child = true, disabled = apagado("reemplazar"),
		help = L["Al hablar con un banquero se abre el banco de Alfa, con depositar rápido. La primera visita de cada personaje muestra el del juego: así recibe su primera pestaña."],
		search = "bank, replace bank" },
	{ kind = "toggle", key = clave("ordenar"), label = L["Botón Ordenar"], help = L["Junta los montones y acomoda tus objetos con un clic."], search = "sort, sort button" },
	-- 1.3.9: tu orden y el candado (Ordenar.lua).
	{ kind = "dropdown", key = clave("ordenarModo"), label = L["Cómo ordenar"], child = true, disabled = apagado("ordenar"),
		help = L["Como el juego, o el orden de Alfa: por tipo (equipo, consumibles, materiales… y la chatarra al final), por calidad o por nombre."],
		choices = { { value = "juego", label = L["Como el juego"] }, { value = "tipo", label = L["Por tipo"] },
			{ value = "calidad", label = L["Por calidad"] }, { value = "nombre", label = L["Por nombre"] } },
		search = "sort order, sort by type, sort by quality, sort by name" },
	{ kind = "toggle", key = clave("ordenarCandado"), label = L["No mover lo que tiene candado"], child = true, disabled = apagado("ordenar"),
		help = L["Al ordenar, lo que tiene candado se queda en su casilla y lo demás se acomoda alrededor."],
		search = "sort, locked items, keep in place" },
	{ kind = "toggle", key = clave("ordenarInverso"), label = L["Ordenar de derecha a izquierda"], child = true, disabled = apagado("ordenar"),
		help = L["Los objetos se juntan al final de tus bolsas en lugar de al principio."], search = "reverse sort" },
	{ kind = "toggle", key = clave("avisoLleno"), label = L["Sugerir qué vender"],
		help = L["Un aviso y una franja en tus bolsas con qué vender, qué conservar y a qué comerciante ir, con un clic para marcar la chatarra."],
		search = "bags full, sell, junk" },
	{ kind = "slider", key = clave("avisoLibres"), label = L["Avisar cuando queden"], min = 1, max = 10, step = 1, format = entero,
		child = true, disabled = apagado("avisoLleno"), help = L["Cuántas casillas libres quedan cuando Alfa te avisa."], search = "free slots" },
	{ kind = "toggle", key = clave("avisoCasiLleno"), label = L["Avisar cuando estén casi llenas"],
		help = L["Con 2 casillas libres o menos, un aviso con lo primero que puedes soltar y un botón para vender o ver tus bolsas."],
		search = "bags almost full, free slots, sell junk" },
	{ kind = "toggle", key = clave("ponteEsto"), label = L["«Ponte esto» con el equipo mejor"],
		help = L["Cuando te llega equipo mejor que lo que llevas puesto, un aviso con un botón para ponértelo (solo con tu clic y fuera de combate)."],
		search = "upgrade, equip, wear it, better gear" },
	{ kind = "toggle", key = clave("queGuardar"), label = L["Sugerir qué guardar"],
		help = L["En esta página, lo que te sirve más en el banco o con otro personaje: materiales de sus recetas, lo que piden sus misiones y equipo que tu clase no usa."],
		search = "bank, store, alts, boe, what to keep" },
	{ kind = "toggle", key = clave("conjuntos"), label = L["Conjuntos de equipo"],
		help = L["Guarda lo que llevas puesto con un nombre (curar, daño, pesca…) y póntelo con un clic, fuera de combate."],
		search = "gear sets, equipment sets, outfits, swap gear" },
	{ kind = "toggle", key = clave("barraConjuntos"), label = L["Botones de tus conjuntos"], child = true, disabled = apagado("conjuntos"),
		help = L["Junto a la ventana de tu personaje, un botón por conjunto. En combate te cambia las armas al momento y lo demás al terminar. Clic derecho: ponértelo al salir de cada combate."],
		search = "gear set buttons, quick swap, weapon swap, combat" },
	{ kind = "toggle", key = clave("nivelPersonaje"), label = L["Nivel y durabilidad en tu personaje"],
		help = L["En la ventana de tu personaje y al inspeccionar a alguien: el nivel de objeto de cada pieza y, si se está gastando, cuánto le queda."],
		search = "item level, ilvl, durability, character sheet, paper doll, inspect" },
	{ kind = "toggle", key = clave("comparar"), label = L["Comparar con lo que llevas"],
		help = L["En el cuadro de cada pieza de equipo: lo que ganas y lo que pierdes contra lo que llevas puesto, con números."],
		search = "compare gear, stats, tooltip, upgrade" },
	{ kind = "toggle", key = clave("buscarTodos"), label = L["Buscar en todos tus personajes"],
		help = L["En esta página, un buscador por las bolsas, bancos y equipo de todos tus personajes, con filtros de tipo, calidad y personaje."],
		search = "search alts, find item, all characters" },
	{ kind = "toggle", key = clave("acomodar"), label = L["Botón «Acomodar»"],
		help = L["En tus bolsas: con un comerciante vende tu chatarra; con un banquero guarda tus materiales. Con tu clic."],
		search = "tidy, clean bags, sell junk, deposit materials" },
	-- 1.3.8: el candado de objetos (Candado.lua).
	{ kind = "toggle", key = clave("candado"), label = L["Candado de objetos"],
		help = L["Alt+clic derecho sobre un objeto de tus bolsas le pone o le quita el candado. Con candado no se borra, no se vende y nada de Alfa lo toca."],
		search = "item lock, lock, protect, delete, sell, padlock" },
	{ kind = "toggle", key = clave("candadoAuto"), label = L["Candado automático"], child = true, disabled = apagado("candado"),
		help = L["Sin que hagas nada: lo épico y legendario, lo de misiones, tu piedra de hogar, lo de tus conjuntos de equipo, tus herramientas de oficio (caña, pico, martillo, cuchillo) y lo que te lleva de viaje."],
		search = "auto lock, epic, quest items, hearthstone, gear sets, tools, fishing pole, mining pick, mount" },
	-- 1.3.9
	{ kind = "toggle", key = clave("separarEpicos"), label = L["«Separar»: lo épico con candado a la subasta"],
		help = L["Con «Separar», lo épico que tiene candado también sale con el martillo si vale más en la subasta. El candado sigue: no se vende ni se borra."],
		search = "separate, epic, auction, locked" },
	{ kind = "toggle", key = clave("sobra"), label = L["Botón «Lo que me sobra»"],
		help = L["En tus bolsas: lo que te sobra para venderlo de un clic con un comerciante o mandárselo a otro de tus personajes desde el buzón. Nunca toca lo que tiene candado."],
		search = "leftovers, surplus, sell, send to alt, mail" },
	-- 1.4.0 (diario)
	{ kind = "toggle", key = clave("porAbrir"), label = L["Avisar lo que se abre, las recetas y las bolsas nuevas"],
		help = L["Al conseguir una almeja o una caja que se abre, una receta que ya puedes aprender o una bolsa nueva, un aviso con «Abrir», «Aprender» o «Ponérmela» a un clic."],
		search = "open, clam, container, lockbox, recipe, learn, abrir, almeja, receta, aprender" },
	{ kind = "toggle", key = clave("paraMisiones"), label = L["Lo que piden tus misiones y está en tu banco"],
		help = L["Si una misión pide algo que guardaste en el banco, Alfa te lo dice; con el banco abierto, «Sacarlo» lo pasa a tus bolsas."],
		search = "quest items in bank, withdraw, banco, misión, sacar" },
	{ kind = "toggle", key = clave("candadoCuenta"), label = L["Candados para toda la cuenta"], child = true, disabled = apagado("candado"),
		help = L["Los candados que pongas valen también para tus otros personajes. Apagado, cada personaje tiene los suyos."],
		search = "account wide lock, all characters" },
	{ kind = "toggle", key = clave("marcaNivel"), label = L["Nivel de objeto"], help = L["El número abajo a la izquierda de cada pieza de equipo."], search = "item level, ilvl" },
	{ kind = "toggle", key = clave("marcaCalidad"), label = L["Borde de calidad"], help = L["Un borde del color de la calidad: verde, azul, morado…"], search = "quality border, rarity" },
	{ kind = "toggle", key = clave("marcaChatarra"), label = L["Chatarra"], help = L["Una moneda sobre lo gris y lo que marcaste como chatarra."], search = "junk, grey items" },
	{ kind = "toggle", key = clave("marcaNuevos"), label = L["Objetos nuevos"], help = L["Brillan los objetos que acabas de conseguir, hasta que cierras las bolsas."], search = "new items, glow" },
	{ kind = "toggle", key = clave("marcaMejora"), label = L["Flecha de mejora"],
		help = L["Una flecha verde en el equipo que es mejor que lo que llevas puesto, según tu clase y nivel."], search = "upgrade arrow" },
	{ kind = "toggle", key = clave("atajos"), label = L["Atajos a lo nuevo y a tus mejoras"],
		help = L["En la búsqueda de tus bolsas, «3 nuevos» y «1 mejora»: un clic resalta solo eso."], search = "new items, upgrades, filter, shortcut" },
	{ kind = "dropdown", key = clave("brilloMision"), label = L["Objetos de misión"],
		help = L["Brillo: un borde dorado que late y una insignia «!» (llena si el objeto empieza una misión). Marco fijo: el marco dorado del juego. Nada: sin marca."],
		choices = { { value = "brillo", label = L["Brillo"] }, { value = "marco", label = L["Marco fijo"] }, { value = "nada", label = L["Nada"] } },
		get = misionActual,
		set = function(v)
			if v == nil then -- nil: los dos vuelven a como vienen
				M.Set("brilloMision", nil)
				M.Set("marcaMision", nil)
			elseif v == "brillo" then
				M.Set("brilloMision", true)
			else
				M.Set("brilloMision", false)
				M.Set("marcaMision", v == "marco")
			end
		end,
		search = "quest items, quest glow, quest border" },
	{ kind = "toggle", key = clave("cuadroConteo"), label = L["Cuántos tienes, en el cuadro de cada objeto"],
		help = L["Al pasar el ratón por un objeto: «Tienes 12 (Lobato: 7 en bolsas, Alt: 5 en banco)», con todos tus personajes."],
		search = "tooltip count, alts, item count" },
}

N.Modulo({
	id = M.ID, nombre = L["Bolsas"], icono = "ic-bolsas", orden = 40,
	subtitulo = L["Tus bolsas y tu banco en una sola ventana, y lo que lleva cada uno de tus personajes."],
	comando = "bolsas",
	ajustes = M.AJUSTES,
	controles = CONTROLES,
	construir = function(view) if M.ConstruirPagina then M.ConstruirPagina(view) end end,
})

function M.Get(clave)
	local v = N.Get(M.ID, clave)
	if v == nil then v = M.AJUSTES[clave] end
	return v
end

function M.Set(clave, valor) N.Set(M.ID, clave, valor) end

-- La vista de la ventana: "una", "categorias" o "bolsa".
function M.Vista()
	local v = M.Get("vista")
	return M.VISTAS[v] and v or "categorias"
end

function M.EnCombate() return InCombatLockdown and InCombatLockdown() and true or false end

-- Un número del ajuste, dentro de [lo, hi].
function M.Numero(clave, lo, hi)
	local v = tonumber(M.Get(clave)) or tonumber(M.AJUSTES[clave]) or lo
	if v < lo then v = lo elseif v > hi then v = hi end
	return math.floor(v + 0.5)
end

---------------------------------------------------------------------------
-- Valores del juego: los secretos (Forever) se leen como desconocidos.
---------------------------------------------------------------------------

local function secreto(v)
	return type(v) ~= "nil" and issecretvalue ~= nil and issecretvalue(v) and true or false
end

function M.Leer(v)
	if secreto(v) then return nil end
	return v
end

function M.Num(v)
	if secreto(v) then return nil end
	return tonumber(v)
end

function M.Texto(v)
	if secreto(v) or type(v) ~= "string" then return nil end
	return v
end

-- Una llamada al cliente protegida con pcall: -> sus resultados, o nada.
local function resultados(ok, ...)
	if ok then return ... end
	return nil
end

function M.Llamar(fn, ...)
	if type(fn) ~= "function" then return nil end
	return resultados(pcall(fn, ...))
end

-- C_Container leído al usarlo (1.3.0): si el juego lo crea tarde o lo
-- cambia, Datos.lua y Ventana.lua no se quedan con una tabla vieja o vacía.
M.CC = setmetatable({}, { __index = function(_, k)
	local t = rawget(_G, "C_Container")
	return type(t) == "table" and t[k] or nil
end })

function M.ItemID(link)
	if type(link) == "number" then return link end
	if type(link) ~= "string" then return nil end
	return tonumber(link:match("item:(%d+)"))
end

-- Error de una función nuestra al manejador del juego, sin cortar el resto.
function M.Seguro(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		if A.NoteError then pcall(A.NoteError, err) end
		if geterrorhandler then pcall(geterrorhandler(), err) end
	end
	return ok
end

---------------------------------------------------------------------------
-- Avisos internos del módulo (sin pasar por el motor)
---------------------------------------------------------------------------

local oyentes = {}

function M.Escuchar(que, fn)
	oyentes[que] = oyentes[que] or {}
	local lista = oyentes[que]
	lista[#lista + 1] = fn
end

function M.Avisar(que, ...)
	local lista = oyentes[que]
	if not lista then return end
	for i = 1, #lista do M.Seguro(lista[i], ...) end
end

-- fn en el siguiente cuadro (o ya, si no hay temporizador).
function M.Luego(seg, fn)
	if C_Timer and C_Timer.After then
		C_Timer.After(seg or 0, function() M.Seguro(fn) end)
	else
		M.Seguro(fn)
	end
end

---------------------------------------------------------------------------
-- Comandos: /alfa bolsas abre la página; con "abrir" o "banco", las ventanas.
---------------------------------------------------------------------------

A.RegisterCommand("bolsas", function(resto)
	local arg = type(resto) == "string" and resto:lower():match("^%s*(%S*)") or ""
	if arg == "abrir" or arg == "open" then
		if M.Ventana then M.Ventana.AlternarBolsas() end
	elseif arg == "banco" or arg == "bank" then
		if M.Ventana then M.Ventana.MostrarBanco() end
	elseif arg == "conjunto" or arg == "set" or arg == "guardar" or arg == "save" then
		-- 1.3.0: /alfa bolsas conjunto <nombre> (ponértelo) o guardar <nombre>.
		local nombre = resto:match("^%s*%S+%s+(.-)%s*$")
		local Cj = M.Conjuntos
		if not Cj then return end
		if not nombre or nombre == "" then
			local lista = {}
			for _, c in ipairs(Cj.Lista()) do lista[#lista + 1] = c.n end
			N.Imprimir(#lista > 0 and (L["Tus conjuntos:"] .. " " .. table.concat(lista, ", ")) or L["Aún no guardas ningún conjunto."])
		elseif arg == "guardar" or arg == "save" then
			Cj.Guardar(nombre)
		else
			Cj.Poner(nombre)
		end
	else
		N.Abrir(M.ID)
	end
end, L["La página de Bolsas; «abrir», «banco», «conjunto <nombre>» y «guardar <nombre>»"])

-- Un texto de color: "|cffrrggbb...|r".
function M.Pintado(texto, r, g, b)
	return ("|cff%02x%02x%02x%s|r"):format(math.floor((r or 1) * 255 + 0.5), math.floor((g or 1) * 255 + 0.5),
		math.floor((b or 1) * 255 + 0.5), tostring(texto or ""))
end

-- Color del tema por nombre, con respaldo.
function M.Color(nombre, r, g, b)
	local T = A.Theme
	if T and T.Color then
		local ok, cr, cg, cb, ca = pcall(T.Color, nombre)
		if ok and type(cr) == "number" then return cr, cg, cb, ca or 1 end
	end
	return r or 1, g or 1, b or 1, 1
end

function M.Acento()
	local T = A.Theme
	if T and T.Accent then
		local ok, r, g, b = pcall(T.Accent)
		if ok and type(r) == "number" then return r, g, b end
	end
	return 0.55, 0.88, 0.31
end

-- Color de una clase ("WARRIOR").
function M.ColorClase(clase)
	local T = A.Theme
	if T and T.ClassColor and type(clase) == "string" then
		local ok, r, g, b = pcall(T.ClassColor, clase)
		if ok and type(r) == "number" then return r, g, b end
	end
	return M.Color("text")
end

-- "hoy", "ayer", "hace 3 días".
function M.Hace(t)
	t = tonumber(t)
	if not t or t <= 0 then return L["nunca"] end
	local ahora = time and time() or t
	local dias = math.floor((ahora - t) / 86400)
	if dias <= 0 then return L["hoy"] end
	if dias == 1 then return L["ayer"] end
	return (L["hace %d días"]):format(dias)
end
