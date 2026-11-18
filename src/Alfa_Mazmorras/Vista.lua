-- Alfa - Mazmorras: la página en la ventana de Alfa, hecha con el Kit
-- (toxic3000 / La Jauría). GPL-3.0.
--
-- Desde la 1.0 es la única vista de las mazmorras: el diario del motor
-- (SHOW_DUNGEON) y su tarjeta de mazmorra abierta (DUNGEON_TOAST) se
-- reemplazan por esta página y por avisos del Kit (Reemplazos.lua).
--
--   Inicio      «Para tu nivel ahora» en grande: una mazmorra recomendada y su
--               botón «Prepárame» (recoge sus misiones que ya puedes tomar y te
--               lleva a la entrada). Debajo, todas por rango en tarjetas con el
--               arte de su zona, y tu progreso en corto si ya tienes.
--   Mazmorra    cabecera (arte, rango, zona, jefes vencidos) y pestañas:
--               Resumen   qué hacer ahora, sus datos, requisitos y atajos
--               Jefes     cada jefe con su estado, consejos, botín y misiones
--               Botín     por jefe, con lo que te sirve, lo que tienes y las mejoras
--               Misiones  cada una con lo que le falta (Plan.lua)
--               Consejos  antes de entrar (solo si la mazmorra los tiene)
--   Progreso    lo que llevas: mazmorras, jefes y botín (por personaje).
-- Una pestaña sin contenido no se muestra; una sección vacía tampoco, o dice
-- qué hacer para llenarla. Los ajustes viven en Ajustes > Descubrir >
-- Mazmorras (Ajustes.lua).

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = N.Textos(M.EN)
local D, P, Pz = M.D, M.P, M.Pz
local ID = D.ID

local type, pairs, ipairs, tostring, tonumber = type, pairs, ipairs, tostring, tonumber
local floor, max, min, abs = math.floor, math.max, math.min, math.abs
local format, concat, sort = string.format, table.concat, table.sort
local ESP = K.ESP
local DOT = Pz.DOT
local GUION = "\226\128\147"

local llamar = D.Llamar

local V = {}
M.V = V

local estado = {
	vista = "inicio",     -- inicio | mazmorra | progreso
	clave = nil,          -- la mazmorra abierta
	pestana = "resumen",  -- resumen | jefes | botin | misiones | consejos
	rango = nil,          -- el rango elegido en Inicio
	spoiler = {},         -- key:jefe -> sus consejos a la vista sin descubrirlo
	extra = {},           -- key:jefe -> su botín poco probable a la vista
	hechas = false,       -- Misiones: las hechas a la vista
}
V.estado = estado

local vista, ui -- la vista de la página y sus piezas

local function Dg() return A.Dungeons end

---------------------------------------------------------------------------
-- Ayudas
---------------------------------------------------------------------------

local function rango(lo, hi)
	if type(lo) ~= "number" then return nil end
	if type(hi) ~= "number" or hi == lo then return tostring(lo) end
	return lo .. GUION .. hi
end

local function niveles(lo, hi)
	if type(lo) ~= "number" then return nil end
	if type(hi) ~= "number" or hi == lo then return format(L["Nivel %d"], lo) end
	return format(L["Niveles %s"], rango(lo, hi))
end

local function unir(lista, sep)
	local t = {}
	for _, s in ipairs(lista) do if type(s) == "string" and s ~= "" then t[#t + 1] = s end end
	return concat(t, sep or DOT)
end

local function cuantas(n, una, varias) return n == 1 and una or format(varias, n) end

local function decimal(v)
	local s = format("%.1f", v)
	if N.espanol then s = s:gsub("%.", ",") end
	return s
end

local function fecha(t)
	if type(t) ~= "number" or t <= 0 or not date then return nil end
	return date("%d/%m/%Y", t)
end

-- El color de una misión según tu nivel, como lo pinta el juego.
local function tonoNivel(nivelMision, nivel)
	if type(nivelMision) ~= "number" then return "neutro" end
	local d = nivelMision - nivel
	if d >= 5 then return "peligro" end
	if d >= 3 then return "aviso" end
	if d >= -2 then return "oro" end
	if d >= -8 then return "exito" end
	return "neutro"
end

local function enemiga(key)
	local x = Dg()
	return x and x.EnemyEntrance and llamar(x.EnemyEntrance, key) or nil
end

local function capitalEnemiga(key, lado)
	local x = Dg()
	return lado and x and x.EnemyCapital and llamar(x.EnemyCapital, key, lado) and true or false
end

local function mejorNivel(key)
	local x = Dg()
	local b = x and x.BestAt and llamar(x.BestAt, key)
	return type(b) == "number" and b or nil
end

-- Para tu nivel: dentro de su rango (desde un nivel antes) y con la entrada
-- fuera de la capital del otro bando.
local function paraTuNivel(d, nivel, lado)
	local lo, hi = d.minLevel or 1, d.maxLevel or d.minLevel or 60
	if nivel < lo - 1 or nivel > hi then return false end
	return not capitalEnemiga(d.key, lado)
end

local function sirve(e)
	if not N.Get(ID, "meSirve") then return true end
	return D.MeSirve(e.id) ~= false
end

local function abrirAjustes() if M.Ajustes then M.Ajustes.Abrir() end end

---------------------------------------------------------------------------
-- La recomendada
---------------------------------------------------------------------------

local function puntaje(d, nivel)
	local lo, hi = d.minLevel or 1, d.maxLevel or d.minLevel or 60
	local best = mejorNivel(d.key) or floor((lo + hi) / 2)
	local s = -abs(best - nivel) * 10
	if D.Hecha(d.key) then s = s - 30 end
	local v = D.Cuenta(d.key)
	if v > 0 and not D.Hecha(d.key) then s = s + 8 end
	local lado = D.Lado()
	if lado and d.quests and (d.quests[lado] or 0) > 0 then s = s + 4 end
	return s
end

-- -> d, modo ("dentro" | "nivel" | "pronto") | nil
local function recomendada(lista, nivel, lado)
	local aqui = D.MazmorraActual()
	if aqui then
		for _, d in ipairs(lista) do if d.key == aqui then return d, "dentro" end end
	end
	for _, tipo in ipairs({ "dungeon", "raid" }) do
		local cand = {}
		for _, d in ipairs(lista) do
			if d.kind == tipo and paraTuNivel(d, nivel, lado) then cand[#cand + 1] = { d = d, p = puntaje(d, nivel) } end
		end
		if #cand > 0 then
			-- Las tres mejores por nivel ganan por lo que ya puedes recoger
			-- en ellas: «Prepárame» sirve más ahí.
			sort(cand, function(a, b) return a.p > b.p end)
			for i = 1, min(3, #cand) do
				local e = P.Estado(cand[i].d.key)
				cand[i].p = cand[i].p + min(#e.recoger, 6) * 6 + (e.listas > 0 and 10 or 0)
			end
			local mejor = cand[1]
			for i = 2, min(3, #cand) do if cand[i].p > mejor.p then mejor = cand[i] end end
			return mejor.d, "nivel"
		end
	end
	local sig
	for _, d in ipairs(lista) do
		if d.kind == "dungeon" and (d.minLevel or 0) > nivel and not capitalEnemiga(d.key, lado)
			and (not sig or d.minLevel < sig.minLevel) then sig = d end
	end
	if sig then return sig, "pronto" end
	return nil
end
V.Recomendada = function()
	if not D.Listo() then return nil end
	return recomendada(D.Lista(), D.Nivel(), D.Lado())
end

---------------------------------------------------------------------------
-- Tarjetas de mazmorra
---------------------------------------------------------------------------

local function datosTarjeta(d, nivel, lado, meta)
	local ins = {}
	local h = D.Hecha(d.key)
	local v, total = D.Cuenta(d.key)
	if paraTuNivel(d, nivel, lado) then ins[#ins + 1] = { L["Tu nivel"], "acento" } end
	if h then
		ins[#ins + 1] = { (h.veces or 0) > 1 and format(L["Hecha %d veces"], h.veces) or L["Hecha"], "exito" }
	elseif v > 0 and total > 0 then
		ins[#ins + 1] = { format(L["%d de %d jefes"], v, total), "acento" }
	end
	if d.kind == "raid" then ins[#ins + 1] = { L["Banda"], "mazmorra" } end
	if d.forever then ins[#ins + 1] = { L["De Forever"], "mazmorra" } end
	if enemiga(d.key) then ins[#ins + 1] = { L["Entrada enemiga"], "aviso" } end
	local q = lado and d.quests and d.quests[lado] or 0
	return {
		key = d.key, nombre = d.name or d.key, insignias = ins, avance = not h and { v, total } or nil,
		meta = meta or unir({ niveles(d.minLevel, d.maxLevel), d.zoneName }),
		ayuda = q > 0 and cuantas(q, L["1 misión para tu bando."], L["%d misiones para tu bando."]) or nil,
		alClic = function() V.AbrirMazmorra(d.key) end,
	}
end

-- Llena una rejilla con tarjetas de mazmorra (su reserva: rej.tarjetas).
local function llenarTarjetas(rej, datos)
	rej.tarjetas = rej.tarjetas or {}
	local elems = {}
	for i, d in ipairs(datos) do
		local c = rej.tarjetas[i] or Pz.TarjetaMazmorra(rej)
		rej.tarjetas[i] = c
		c:Set(d)
		c:Show()
		elems[i] = c
	end
	for i = #datos + 1, #rej.tarjetas do rej.tarjetas[i]:Hide() end
	rej:SetElementos(elems)
	K.Mostrar(rej, #datos > 0)
end

---------------------------------------------------------------------------
-- Inicio
---------------------------------------------------------------------------

local RANGOS = {
	{ valor = "10", lo = 0, hi = 19, texto = "10" .. GUION .. "20" },
	{ valor = "20", lo = 20, hi = 29, texto = "20" .. GUION .. "30" },
	{ valor = "30", lo = 30, hi = 39, texto = "30" .. GUION .. "40" },
	{ valor = "40", lo = 40, hi = 49, texto = "40" .. GUION .. "50" },
	{ valor = "50", lo = 50, hi = 99, texto = "50" .. GUION .. "60" },
}

-- El rango de una mazmorra: el de la mitad de sus niveles (Castillo de
-- Colmillo Oscuro, 18-26, va con las de 20 a 30, donde uno la busca).
local function rangoDe(d)
	if d.kind == "raid" then return "bandas" end
	local lo = d.minLevel or 1
	local m = floor((lo + (d.maxLevel or lo)) / 2)
	for _, r in ipairs(RANGOS) do if m >= r.lo and m <= r.hi then return r.valor end end
	return "50"
end

local function rangoDeNivel(nivel)
	for _, r in ipairs(RANGOS) do if nivel >= r.lo and nivel <= r.hi then return r.valor end end
	return "50"
end

local function accionInicio(d, modo, nivel)
	local abrir = function() V.AbrirMazmorra(d.key) end
	local t = { icono = "ic-mazmorra", tono = "acento", titulo = d.name or d.key, alClic = abrir, lineas = 4 }
	local best = mejorNivel(d.key)
	local meta = unir({ d.zoneName, niveles(d.minLevel, d.maxLevel), best and format(L["mejor a nivel %d"], best) or nil })
	local ins = {}
	local h = D.Hecha(d.key)
	local v, total = D.Cuenta(d.key)
	if modo == "dentro" then
		t.sobre = Pz.Mayus(L["Estás aquí"])
		t.texto = meta .. "\n" .. L["Mira a sus jefes y sus consejos antes de cada pelea."]
		t.accion = { texto = L["Ver sus jefes"], icono = "ic-seguir", alClic = function() V.AbrirMazmorra(d.key, "jefes") end }
	elseif modo == "pronto" then
		t.sobre = Pz.Mayus(L["Tu siguiente mazmorra"])
		t.texto = meta .. "\n" .. format(L["Se abre a nivel %d: te faltan %d niveles. Mientras, sigue tu ruta."], d.minLevel or 0, max(1, (d.minLevel or 0) - nivel))
		t.accion = { texto = L["Ver la mazmorra"], icono = "ic-seguir", alClic = abrir }
	else
		local e = P.Estado(d.key)
		t.sobre = Pz.Mayus(L["Para tu nivel ahora"])
		if e.listas > 0 then
			t.texto = meta .. "\n" .. cuantas(e.listas, L["Terminaste 1 de sus misiones: entrégala y recoge las que siguen."],
				L["Terminaste %d de sus misiones: entrégalas y recoge las que siguen."])
			t.accion = { texto = L["Entregar misiones"], icono = "ic-seguir", alClic = function() P.Entregar(d.key) end }
		else
			t.texto = meta .. "\n" .. P.Frase(e)
			t.accion = { texto = #e.recoger > 0 and L["Prepárame"] or L["Llévame a la entrada"], icono = "ic-seguir",
				alClic = function() P.Preparar(d.key) end }
		end
		t.secundaria = { texto = L["Ver la mazmorra"], alClic = abrir }
		if #e.recoger > 0 then ins[#ins + 1] = { cuantas(#e.recoger, L["1 misión para recoger"], L["%d misiones para recoger"]), "acento" } end
		if #e.esperan > 0 then ins[#ins + 1] = { cuantas(#e.esperan, L["1 para después"], L["%d para después"]), "aviso" } end
	end
	if h then
		ins[#ins + 1] = { L["Ya la completaste"], "exito" }
	elseif v > 0 and total > 0 then
		ins[#ins + 1] = { format(L["%d de %d jefes"], v, total), "acento" }
	end
	if enemiga(d.key) then ins[#ins + 1] = { L["Entrada enemiga"], "aviso" } end
	t.insignias = ins
	return t
end

-- Tus números, solo los que ya tienen algo.
local function numeros(hechas, jefes, objetos, veces)
	local t = {}
	local function poner(n, icono, titulo)
		if (n or 0) > 0 then t[#t + 1] = { variante = "compacta", icono = icono, titulo = titulo, valor = tostring(n) } end
	end
	poner(hechas, "ic-mazmorra", L["Mazmorras hechas"])
	poner(jefes, "ic-huella", L["Jefes vencidos"])
	poner(objetos, "ic-bolsas", L["Objetos obtenidos"])
	poner(veces, "ic-exito", L["Veces completadas"])
	return t
end

local function construirInicio(padre)
	local t = K.Pila(padre, { espacio = ESP.l })
	t.Accion = t:Agregar(K.Tarjeta(t, { variante = "accion" }))
	t.Seccion = t:Agregar(K.Seccion(t, L["Todas las mazmorras"]))
	t.Rangos = t:Agregar(K.Segmentos(t, { estilo = "pildoras", alCambiar = function(v)
		estado.rango = v
		V.Refrescar()
	end }), { espacio = ESP.m })
	t.Rangos.alfaAnchoPropio = true
	t.Rejilla = t:Agregar(K.Rejilla(t, { min = 300, gap = ESP.m }), { espacio = ESP.base })
	t.SecProgreso = t:Agregar(K.Seccion(t, L["Tu progreso"], { enlace = { texto = L["Ver todo"], alClic = function() V.Ir("progreso") end } }))
	t.Progreso = t:Agregar(K.Rejilla(t, { min = 200, gap = ESP.m, variante = "compacta" }), { espacio = ESP.m })
	t.Pie = t:Agregar(Pz.Botones(t))
	t.Pie:Set({ K.Boton(t.Pie, L["Ajustes de mazmorras"], abrirAjustes, { tipo = "fantasma", tam = "chico", icono = "ic-ajustes" }) })
	return t
end

local function llenarInicio(t)
	local lista = D.Lista()
	local nivel, lado = D.Nivel(), D.Lado()
	D.RevisarTodo()
	local d, modo = recomendada(lista, nivel, lado)
	if d then
		local datos = accionInicio(d, modo, nivel)
		t.Accion:Set(datos)
		Pz.ArteEnTarjeta(t.Accion, d.key)
	end
	K.Mostrar(t.Accion, d ~= nil)
	-- Los rangos con mazmorras, y sus tarjetas.
	local cuenta = {}
	for _, x in ipairs(lista) do
		local r = rangoDe(x)
		cuenta[r] = (cuenta[r] or 0) + 1
	end
	local opciones = {}
	for _, r in ipairs(RANGOS) do
		if cuenta[r.valor] then opciones[#opciones + 1] = { valor = r.valor, texto = r.texto, cuenta = cuenta[r.valor] } end
	end
	if cuenta.bandas then opciones[#opciones + 1] = { valor = "bandas", texto = L["Bandas"], cuenta = cuenta.bandas } end
	if not estado.rango or not cuenta[estado.rango] then
		estado.rango = (d and rangoDe(d)) or rangoDeNivel(nivel)
		if not cuenta[estado.rango] then estado.rango = opciones[1] and opciones[1].valor end
	end
	t.Rangos:SetOpciones(opciones)
	t.Rangos:SetValor(estado.rango)
	local datos = {}
	for _, x in ipairs(lista) do
		if rangoDe(x) == estado.rango then datos[#datos + 1] = datosTarjeta(x, nivel, lado) end
	end
	llenarTarjetas(t.Rejilla, datos)
	K.Mostrar(t.Seccion, #opciones > 0)
	K.Mostrar(t.Rangos, #opciones > 1)
	-- Tu progreso, en corto (solo si ya hay).
	local hechas, jefes, objetos = D.Resumen()
	local hay = hechas + jefes + objetos > 0
	K.Mostrar(t.SecProgreso, hay)
	K.Mostrar(t.Progreso, hay)
	if hay then
		t.Progreso:Llenar(numeros(hechas, jefes, objetos))
	end
end

---------------------------------------------------------------------------
-- Una mazmorra: la acción de ahora y el resumen
---------------------------------------------------------------------------

local function siguienteJefe(key)
	for i, j in ipairs(D.Jefes(key)) do
		if not j.rol and not D.Vencido(key, j.id) then return j, i end
	end
	return nil
end

local function accionMazmorra(key, d, e, nivel)
	local t = { icono = "ic-mazmorra", tono = "acento" }
	local h = D.Hecha(key)
	if D.MazmorraActual() == key then
		local j, i = siguienteJefe(key)
		t.titulo = L["Estás dentro"]
		if j then
			local nombre = D.Descubierto(key, j) and j.nombre or format(L["el jefe %d"], i)
			t.texto = format(L["Sigue: %s. Lee sus consejos antes de la pelea."], nombre or "?")
		else
			t.texto = L["Ya vencieron a todos sus jefes. Si tienes misiones listas, entrégalas al salir."]
		end
		t.estado = { texto = L["Dentro"], tono = "mazmorra" }
		t.accion = { texto = L["Ver los jefes"], icono = "ic-seguir", alClic = function() V.Pestana("jefes") end }
	elseif e.listas > 0 then
		t.tono = "exito"
		t.titulo = cuantas(e.listas, L["Tienes 1 misión lista para entregar"], L["Tienes %d misiones listas para entregar"])
		t.texto = L["Te llevo a quien recibe cada una y recoges las que siguen."]
		t.estado = { texto = L["Para entregar"], tono = "exito" }
		t.accion = { texto = L["Entregar misiones"], icono = "ic-seguir", alClic = function() P.Entregar(key) end }
		t.secundaria = { texto = L["Ver las misiones"], alClic = function() V.Pestana("misiones") end }
	elseif nivel < (d.minLevel or 1) - 1 then
		t.tono = "aviso"
		t.titulo = L["Todavía es pronto"]
		local partes = { format(L["Es para niveles %s y vas en el %d: te faltan %d niveles."], rango(d.minLevel, d.maxLevel) or "?", nivel, (d.minLevel or 1) - nivel) }
		local w = P.FrasesEspera(e)
		if w then partes[#partes + 1] = w end
		t.texto = concat(partes, " ")
		t.estado = { texto = format(L["Desde nivel %d"], d.minLevel or 1), tono = "aviso" }
		t.secundaria = { texto = L["Llévame a la entrada"], alClic = function() P.Entrada(key) end }
	else
		local n = #e.recoger
		if n > 0 then
			t.titulo = L["Prepárate para entrar"]
			t.estado = { texto = cuantas(n, L["1 para recoger"], L["%d para recoger"]), tono = "acento" }
		elseif h then
			t.titulo = L["Ya la completaste"]
			t.estado = { texto = L["Hecha"], tono = "exito" }
		else
			t.titulo = L["Lista para entrar"]
		end
		t.texto = P.Frase(e)
		if h and n == 0 then t.texto = t.texto .. " " .. L["Repítela por su botín o para ayudar a tu manada."] end
		t.accion = { texto = n > 0 and L["Prepárame"] or L["Llévame a la entrada"], icono = "ic-seguir", alClic = function() P.Preparar(key) end }
		if n > 0 then t.secundaria = { texto = L["Solo la entrada"], alClic = function() P.Entrada(key) end } end
	end
	local en = enemiga(key)
	if en then t.texto = (t.texto or "") .. "\n" .. K.Tenir("aviso", en) end
	t.lineas = 5
	return t
end

local NOMBRE_REQ = { attunement = L["Requisito"], key = L["Llave"], item = L["Objeto"] }

local function construirResumen(padre)
	local r = K.Pila(padre, { espacio = ESP.l })
	r.Estado = r:Agregar(K.Tarjeta(r, { variante = "estado" }))
	r.Datos = r:Agregar(K.Rejilla(r, { min = 260, gap = ESP.m, variante = "compacta" }))
	r.SecReq = r:Agregar(K.Seccion(r, L["Requisitos y llaves"]))
	r.Req = r:Agregar(K.Rejilla(r, { min = 300, gap = ESP.m }), { espacio = ESP.m })
	r.Botones = r:Agregar(Pz.Botones(r))
	local B = r.Botones
	r.Mapa = K.Boton(B, L["Ver en el mapa"], function() local x = Dg() if x and x.ShowOnMap then llamar(x.ShowOnMap, estado.clave) end end,
		{ tipo = "fantasma", tam = "chico", icono = "ic-mapa" })
	r.Antes = K.Boton(B, L["Ya la hice antes"], function()
		local k = estado.clave
		K.Dialogo({ titulo = L["¿Ya hiciste esta mazmorra?"], lobo = "atento",
			texto = format(L["Se descubren todos los jefes de %s, como si la hubieras terminado. Si te equivocas, puedes olvidar tu progreso aquí."], D.Nombre(k)),
			aceptar = L["Sí, ya la hice"], alAceptar = function() D.MarcarAntes(k) end })
	end, { tipo = "fantasma", tam = "chico", icono = "ic-exito" })
	r.Olvidar = K.Boton(B, L["Olvidar mi progreso aquí"], function()
		local k = estado.clave
		K.Dialogo({ titulo = L["¿Olvidar tu progreso?"], peligro = true,
			texto = format(L["Se borran los jefes vencidos, las veces completada y el botín anotado de %s para este personaje."], D.Nombre(k)),
			aceptar = L["Olvidar"], alAceptar = function() D.Olvidar(k) end })
	end, { tipo = "fantasma", tam = "chico", icono = "ic-cerrar" })
	B:Set({ r.Mapa, r.Antes, r.Olvidar })
	return r
end

local function llenarResumen(r, key, d, e, nivel, lado)
	r.Estado:Set(accionMazmorra(key, d, e, nivel))
	local x = Dg()
	local v, total = D.Cuenta(key)
	local h = D.Hecha(key)
	-- Sus datos: solo los que dicen algo y no están ya en la cabecera (rango,
	-- mejor nivel, jefes vencidos).
	local datos = {}
	local tuyas = 0
	for _, f in ipairs(e.lista) do if f.grupo ~= "otras" and f.grupo ~= "hechas" then tuyas = tuyas + 1 end end
	if tuyas > 0 then
		datos[#datos + 1] = { variante = "compacta", icono = "ic-misiones", titulo = L["Misiones para ti"], valor = tostring(tuyas),
			texto = #e.recoger > 0 and cuantas(#e.recoger, L["1 para recoger ahora"], L["%d para recoger ahora"]) or nil }
	end
	local xs = x and x.QuestXP and llamar(x.QuestXP, key)
	if type(xs) == "table" and not xs.maxed and (xs.levels or 0) >= 0.1 then
		datos[#datos + 1] = { variante = "compacta", icono = "ic-nivel", titulo = L["Sus misiones dan"], valor = format(L["+%s niveles"], decimal(xs.levels)) }
	end
	if h and (h.veces or 0) > 0 then
		datos[#datos + 1] = { variante = "compacta", icono = "ic-exito", titulo = L["Veces completada"], valor = tostring(h.veces) }
	end
	r.Datos:Llenar(datos)
	K.Mostrar(r.Datos, #datos > 0)
	-- Requisitos y llaves (sobre todo de las bandas).
	local reqs = {}
	for _, a in ipairs(x and x.Attunements and llamar(x.Attunements, key, lado) or {}) do
		local st = x.AttunementState and llamar(x.AttunementState, a)
		local listo = type(st) == "table" and st.done
		local falta = type(st) == "table" and st.left or nil
		reqs[#reqs + 1] = {
			icono = a.kind == "key" and "ic-exito" or "ic-ruta", tono = listo and "exito" or "aviso",
			sobre = Pz.Mayus(listo and L["Ya lo tienes"] or (falta and falta > 0 and cuantas(falta, L["Te falta 1 paso"], L["Te faltan %d pasos"]) or L["Pendiente"])),
			titulo = a.name or "?", texto = a.note,
			insignias = { { NOMBRE_REQ[a.kind] or L["Requisito"], "neutro" } },
			secundaria = not listo and { texto = L["Guíame"], alClic = function()
				-- (sin "x.Attune and ...": el and se queda solo con el primer valor y perdía el porqué)
				local gid, porque
				if x.Attune then gid, porque = llamar(x.Attune, key, a.id) end
				if gid then if N.EmpezarRuta then N.EmpezarRuta() else A.Set("ui.shown", true) end
				elseif K.Aviso then K.Aviso({ titulo = L["No pude armar esa guía"], texto = porque == "tabs" and L["Tienes seis guías abiertas: cierra una y vuelve a intentarlo."] or nil, icono = "ic-alerta", tono = "aviso" }) end
			end } or nil,
		}
	end
	r.Req:Llenar(reqs)
	K.Mostrar(r.SecReq, #reqs > 0)
	K.Mostrar(r.Req, #reqs > 0)
	-- Atajos pequeños.
	r.Antes:SetShown(D.Historia() and not h and total > 0)
	r.Olvidar:SetShown(h ~= nil or v > 0)
	r.Mapa:SetShown(d.entrance ~= nil)
	K.Mostrar(r.Botones, r.Botones:Hay())
end

---------------------------------------------------------------------------
-- Jefes
---------------------------------------------------------------------------

local ROL_JEFE = { rare = { L["Raro"], "raro" }, event = { L["Evento"], "neutro" }, optional = { L["Opcional"], "neutro" } }

-- Los títulos de las misiones de un jefe que son tuyas.
local function misionesDeJefe(key, j, tuyas)
	local t = {}
	for _, q in ipairs(type(j.misiones) == "table" and j.misiones or {}) do
		local f = type(q) == "table" and tuyas[q.id]
		if f and f.grupo ~= "otras" then
			t[#t + 1] = P.Citar(f.q.title) .. (f.grupo == "hechas" and (" " .. K.Tenir("exito", "\226\156\147")) or "")
		end
	end
	if #t == 0 then return nil end
	return format(#t == 1 and L["Misión: %s"] or L["Misiones: %s"], concat(t, ", "))
end

local function construirJefes(padre)
	local j = K.Pila(padre, { espacio = ESP.m })
	j.Nota = j:Agregar(Pz.Nota(j, "nota", "textoSuave"))
	j.Lista = j:Agregar(K.Pila(j, { espacio = ESP.m }))
	j.jefes = {}
	return j
end

local function llenarJefes(j, key, e)
	local jefes = D.Jefes(key)
	local tuyas = {}
	for _, f in ipairs(e.lista) do tuyas[f.q.id] = f end
	local ocultos = 0
	for i, jf in ipairs(jefes) do
		local b = j.jefes[i]
		if not b then
			b = j.Lista:Agregar(Pz.BloqueJefe(j.Lista))
			j.jefes[i] = b
		end
		local desc = D.Descubierto(key, jf)
		local venc = D.Vencido(key, jf.id) ~= nil
		local llave = key .. ":" .. jf.id
		local ins = {}
		if jf.final and desc then ins[#ins + 1] = { L["Jefe final"], "mazmorra" } end
		local rol = ROL_JEFE[jf.rol or ""]
		if rol then ins[#ins + 1] = rol end
		if venc then ins[#ins + 1] = { L["Vencido"], "exito" } end
		local datos = {
			n = i, oculto = not desc, vencido = venc, insignias = ins,
			nombre = desc and (jf.nombre or "?") or format(L["Jefe %d por descubrir"], i),
			nivel = desc and type(jf.nivel) == "number" and jf.nivel or nil,
		}
		local ver = desc or estado.spoiler[llave]
		if not desc then
			ocultos = ocultos + 1
			datos.nota = jf.rol and L["Los jefes opcionales y raros se descubren al terminar la mazmorra."]
				or L["Vence a este jefe para descubrir su nombre y su botín."]
			if jf.consejos and not ver then
				datos.verConsejos = function()
					estado.spoiler[llave] = true
					V.Refrescar()
				end
			end
		end
		if ver and jf.consejos then datos.consejos = jf.consejos end
		if desc then
			local principal = D.BotinDe(key, jf)
			local iconos = {}
			for _, it in ipairs(principal) do
				if sirve(it) then iconos[#iconos + 1] = { id = it.id, calidad = it.calidad } end
			end
			if #iconos > 0 then
				datos.botin = iconos
				datos.alMas = function() V.Pestana("botin") end
			elseif not jf.npc and not jf.objeto then
				datos.nota = L["Es un grupo: cada uno suelta su propio botín."]
			end
			datos.misiones = misionesDeJefe(key, jf, tuyas)
		end
		b:Set(datos)
		K.Mostrar(b, true)
	end
	for i = #jefes + 1, #j.jefes do K.Mostrar(j.jefes[i], false) end
	if ocultos > 0 then
		j.Nota:Set(cuantas(ocultos, L["Modo historia: 1 jefe por descubrir. Vence a cada uno para ver su nombre y su botín (puedes apagarlo en Ajustes)."],
			L["Modo historia: %d jefes por descubrir. Vence a cada uno para ver su nombre y su botín (puedes apagarlo en Ajustes)."]))
	end
	K.Mostrar(j.Nota, ocultos > 0)
end

---------------------------------------------------------------------------
-- Botín
---------------------------------------------------------------------------

-- Lo que muestra una celda de un objeto del botín.
local function datosCelda(e, key, nombreJefe)
	local o = D.Objeto(e)
	-- Sin huecos: unir() va con ipairs, y un objeto sin ranura (receta, de
	-- misión) dejaba { nil, tipo } y perdía el tipo, el nivel y el jefe.
	local sub = {}
	if o.ranura then sub[#sub + 1] = o.ranura end
	if o.tipo then sub[#sub + 1] = o.tipo end
	if type(o.req) == "number" and o.req > 1 then sub[#sub + 1] = format(L["Niv. %d"], o.req) end
	if nombreJefe then sub[#sub + 1] = nombreJefe end
	local c = { id = e.id, nombre = o.nombre, calidad = o.calidad, icono = o.icono, sub = unir(sub), chance = e.chance }
	if D.Obtenido(e, key) then
		c.marca = "tienes"
	else
		local mejora, _, nivel = D.Mejora(e.id)
		if mejora then
			c.marca = "mejora"
		elseif nivel then
			c.marca, c.marcaTexto = "luego", format(L["Desde nivel %d"], nivel)
		end
	end
	return c
end

local function llenarCeldas(rej, lista)
	rej.celdas = rej.celdas or {}
	local elems = {}
	for i, c in ipairs(lista) do
		local x = rej.celdas[i] or Pz.Celda(rej)
		rej.celdas[i] = x
		x:Set(c)
		x:Show()
		elems[i] = x
	end
	for i = #lista + 1, #rej.celdas do rej.celdas[i]:Hide() end
	rej:SetElementos(elems)
	K.Mostrar(rej, #lista > 0)
end

local function construirBotin(padre)
	local b = K.Pila(padre, { espacio = ESP.l })
	b.Filtro = b:Agregar(K.Segmentos(b, { estilo = "pildoras", alCambiar = function(v) N.Set(ID, "meSirve", v == "mio") end }))
	b.Filtro.alfaAnchoPropio = true
	b.Lista = b:Agregar(K.Pila(b, { espacio = ESP.l }))
	b.grupos = {}
	b.Nota = b:Agregar(Pz.Nota(b, "nota", "textoTenue"))
	b.Vacio = b:Agregar(K.Vacio(b, { lobo = "vacio" }))
	return b
end

local function grupoBotin(b, i)
	local g = b.grupos[i]
	if g then return g end
	g = b.Lista:Agregar(K.Pila(b.Lista, { espacio = ESP.s }))
	g.Seccion = g:Agregar(K.Seccion(g, ""))
	g.Rejilla = g:Agregar(K.Rejilla(g, { min = 280, gap = ESP.s }))
	b.grupos[i] = g
	return g
end

local function llenarBotin(b, key)
	local jefes = D.Jefes(key)
	local todos, mios, ocultos = 0, 0, 0
	local grupos = {}
	local meSirve = N.Get(ID, "meSirve") and true or false
	for _, jf in ipairs(jefes) do
		local principal, extra = D.BotinDe(key, jf)
		if D.Descubierto(key, jf) then
			local vis, ext = {}, {}
			for _, it in ipairs(principal) do
				todos = todos + 1
				local ok = D.MeSirve(it.id) ~= false
				if ok then mios = mios + 1 end
				if not meSirve or ok then vis[#vis + 1] = it end
			end
			for _, it in ipairs(extra) do if sirve(it) then ext[#ext + 1] = it end end
			if #vis + #ext > 0 then grupos[#grupos + 1] = { j = jf, vis = vis, ext = ext } end
		else
			ocultos = ocultos + #principal
		end
	end
	b.Filtro:SetOpciones({
		{ valor = "todo", texto = L["Todo"], cuenta = todos },
		{ valor = "mio", texto = L["Lo que me sirve"], cuenta = mios,
			ayuda = L["Solo lo que tu clase puede usar y le conviene a tu especialización."] },
	})
	b.Filtro:SetValor(meSirve and "mio" or "todo")
	K.Mostrar(b.Filtro, todos > 0)
	for i, g in ipairs(grupos) do
		local x = grupoBotin(b, i)
		local llave = key .. ":" .. g.j.id
		local abierto = estado.extra[llave]
		local enlace
		if #g.ext > 0 then
			enlace = { texto = abierto and L["Ocultar lo poco probable"] or format(L["Poco probable (%d)"], #g.ext), alClic = function()
				estado.extra[llave] = not estado.extra[llave] or nil
				V.Refrescar()
			end }
		end
		x.Seccion:Set(g.j.nombre or "?", { cuenta = #g.vis, enlace = enlace })
		local celdas = {}
		for _, it in ipairs(g.vis) do celdas[#celdas + 1] = datosCelda(it, key) end
		if abierto then for _, it in ipairs(g.ext) do celdas[#celdas + 1] = datosCelda(it, key) end end
		llenarCeldas(x.Rejilla, celdas)
		K.Mostrar(x, true)
	end
	for i = #grupos + 1, #b.grupos do K.Mostrar(b.grupos[i], false) end
	K.Mostrar(b.Lista, #grupos > 0)
	if ocultos > 0 and #grupos > 0 then
		b.Nota:Set(cuantas(ocultos, L["1 objeto más es de un jefe que aún no descubres."], L["%d objetos más son de jefes que aún no descubres."]))
	end
	K.Mostrar(b.Nota, ocultos > 0 and #grupos > 0)
	if #grupos == 0 then
		if meSirve and todos > 0 then
			b.Vacio:Set({ lobo = "vacio", titulo = L["Nada de esto le sirve a tu clase"], texto = L["Cambia a «Todo» para ver su botín completo."],
				accion = { texto = L["Ver todo"], alClic = function() N.Set(ID, "meSirve", false) end } })
		elseif ocultos > 0 then
			b.Vacio:Set({ lobo = "dormido", titulo = L["Su botín está por descubrir"], texto = L["Vence a sus jefes para ver lo que sueltan, o apaga el modo historia en Ajustes."] })
		else
			b.Vacio:Set({ lobo = "vacio", titulo = L["No se conoce su botín"], texto = L["Los datos de Alfa no traen botín propio de sus jefes."] })
		end
	end
	K.Mostrar(b.Vacio, #grupos == 0)
	return todos + ocultos
end

-- Cuánto botín tiene (para saber si su pestaña se muestra).
local function hayBotin(key)
	for _, jf in ipairs(D.Jefes(key)) do
		local principal, extra = D.BotinDe(key, jf)
		if #principal + #extra > 0 then return true end
	end
	return false
end

---------------------------------------------------------------------------
-- Misiones
---------------------------------------------------------------------------

local GRUPOS = {
	{ clave = "recoger", titulo = L["Para recoger ahora"] },
	{ clave = "registro", titulo = L["En tu registro"] },
	{ clave = "despues", titulo = L["Todavía no"] },
	{ clave = "otras", titulo = L["No son para ti"] },
	{ clave = "hechas", titulo = L["Hechas"], compacta = true },
}

local function construirMisiones(padre)
	local m = K.Pila(padre, { espacio = ESP.l })
	m.Nota = m:Agregar(Pz.Nota(m, "nota", "textoSuave"))
	m.grupos = {}
	for _, g in ipairs(GRUPOS) do
		local x = m:Agregar(K.Pila(m, { espacio = ESP.m }))
		x.Seccion = x:Agregar(K.Seccion(x, g.titulo))
		x.Rejilla = x:Agregar(K.Rejilla(x, { min = g.compacta and 260 or 300, gap = ESP.m, variante = g.compacta and "compacta" or "normal" }))
		m.grupos[g.clave] = x
	end
	return m
end

local function llenarMisiones(m, key, e, nivel)
	local por = {}
	for _, g in ipairs(GRUPOS) do por[g.clave] = {} end
	-- En cada grupo: lo de ahora primero (f.orden), luego por nivel.
	local filas = {}
	for i, f in ipairs(e.lista) do filas[i] = { f = f, i = i } end
	sort(filas, function(x, y)
		local ox, oy = x.f.orden or 9, y.f.orden or 9
		if ox ~= oy then return ox < oy end
		local nx, ny = x.f.q.level or 0, y.f.q.level or 0
		if nx ~= ny then return nx < ny end
		return x.i < y.i
	end)
	for _, fila in ipairs(filas) do
		local f = fila.f
		local q = f.q
		local lista = por[f.grupo] or por.despues
		if f.grupo == "hechas" then
			lista[#lista + 1] = { icono = "ic-exito", tono = "exito", titulo = q.title or "?", valor = q.level and tostring(q.level) or nil }
		else
			lista[#lista + 1] = {
				icono = "ic-misiones", tono = f.tono, sobre = Pz.Mayus(f.estado), titulo = q.title or "?", texto = f.texto, lineas = 3,
				insignias = q.level and { { format(L["Nivel %d"], q.level), tonoNivel(q.level, nivel) } } or nil,
				secundaria = f.llevame and { texto = L["Llévame"], alClic = function() P.Llevame(f.llevame, f.etiqueta) end } or nil,
			}
		end
	end
	for _, g in ipairs(GRUPOS) do
		local x = m.grupos[g.clave]
		local lista = por[g.clave]
		local enlace
		if g.clave == "recoger" and #lista > 0 then
			enlace = { texto = L["Prepárame"], alClic = function() P.Preparar(key) end }
		elseif g.clave == "registro" and e.listas > 0 then
			enlace = { texto = L["Entregar"], alClic = function() P.Entregar(key) end }
		elseif g.clave == "hechas" and #lista > 0 then
			enlace = { texto = estado.hechas and L["Ocultar"] or L["Ver"], alClic = function() estado.hechas = not estado.hechas V.Refrescar() end }
		end
		x.Seccion:Set(g.titulo, { cuenta = #lista, enlace = enlace })
		local ver = g.clave ~= "hechas" or estado.hechas
		x.Rejilla:Llenar(ver and lista or {})
		K.Mostrar(x.Rejilla, ver and #lista > 0)
		K.Mostrar(x, #lista > 0)
	end
	local partes = {}
	if #e.recoger > 0 then
		partes[1] = L["«Prepárame» recoge solo las que ya puedes tomar y te lleva a la entrada."]
	end
	if #e.esperan > 0 then partes[#partes + 1] = L["A las demás les dice qué les falta: tu nivel o una misión antes."] end
	m.Nota:Set(concat(partes, " "))
	K.Mostrar(m.Nota, #partes > 0)
end

---------------------------------------------------------------------------
-- Consejos
---------------------------------------------------------------------------

local function construirConsejos(padre)
	local c = K.Pila(padre, { espacio = ESP.l })
	c.Seccion = c:Agregar(K.Seccion(c, L["Antes de entrar"]))
	c.Lista = c:Agregar(Pz.Consejos(c), { espacio = ESP.m })
	c.Avisos = c:Agregar(K.Tarjeta(c, { variante = "normal" }))
	return c
end

local function llenarConsejos(c, key)
	local general = D.Consejos(key) or {}
	c.Lista:Set(general)
	c.Seccion:Set(L["Antes de entrar"], { cuenta = #general })
	local Av = M.Avisos
	local linea = Av and Av.LineaActiva()
	local ins = {}
	if linea == true then ins[1] = { L["Línea de tiempo prendida"], "exito" }
	elseif linea == false then ins[1] = { L["Línea de tiempo apagada"], "neutro" } end
	c.Avisos:Set({
		icono = "ic-aviso", tono = "acento", titulo = L["En la pelea, el juego te avisa"],
		texto = L["La línea de tiempo de Blizzard dice qué ataque viene y cuándo, y los mensajes grandes, lo peligroso. Alfa no inventa avisos: los prendes y ajustas en Ajustes."],
		insignias = ins, secundaria = { texto = L["Ajustar los avisos"], alClic = abrirAjustes },
	})
end

---------------------------------------------------------------------------
-- La página de una mazmorra
---------------------------------------------------------------------------

local PESTANAS = {
	{ valor = "resumen", texto = L["Resumen"] },
	{ valor = "jefes", texto = L["Jefes"] },
	{ valor = "botin", texto = L["Botín"] },
	{ valor = "misiones", texto = L["Misiones"] },
	{ valor = "consejos", texto = L["Consejos"] },
}

local function construirMazmorra(padre)
	local p = K.Pila(padre, { espacio = ESP.l })
	p.Cabecera = p:Agregar(Pz.Cabecera(p, function() V.Ir("inicio") end))
	p.Pestanas = p:Agregar(K.Segmentos(p, { estilo = "segmentos", alCambiar = function(v)
		estado.pestana = v
		V.Refrescar(true)
	end }))
	p.Pestanas.alfaAnchoPropio = true
	p.tabs = {
		resumen = p:Agregar(construirResumen(p)),
		jefes = p:Agregar(construirJefes(p)),
		botin = p:Agregar(construirBotin(p)),
		misiones = p:Agregar(construirMisiones(p)),
		consejos = p:Agregar(construirConsejos(p)),
	}
	return p
end

local function llenarMazmorra(p)
	local key = estado.clave
	local d = D.Info(key)
	local nivel, lado = D.Nivel(), D.Lado()
	D.RevisarMisiones(key)
	local e = P.Estado(key)
	local jefes = D.Jefes(key)
	local v, total = D.Cuenta(key)
	local h = D.Hecha(key)
	-- Cabecera
	local sobre = d.kind == "raid" and L["Banda"] or L["Mazmorra"]
	if d.forever then sobre = sobre .. " \194\183 " .. L["De Forever"] end
	local best = mejorNivel(key)
	local ins = {}
	if D.MazmorraActual() == key then ins[#ins + 1] = { L["Estás aquí"], "mazmorra" } end
	if h then
		ins[#ins + 1] = { (h.veces or 0) > 1 and format(L["Hecha %d veces"], h.veces) or ((h.veces or 0) == 0 and L["Ya la habías hecho"] or L["Hecha"]), "exito" }
	elseif D.Historia() and total > 0 then
		ins[#ins + 1] = { L["Modo historia"], "mazmorra" }
	end
	if paraTuNivel(d, nivel, lado) then ins[#ins + 1] = { L["Tu nivel"], "acento" } end
	if enemiga(key) then ins[#ins + 1] = { L["Entrada enemiga"], "aviso" } end
	p.Cabecera:Set({
		key = key, sobre = sobre, titulo = d.name or key, insignias = ins,
		meta = unir({ niveles(d.minLevel, d.maxLevel), best and format(L["mejor a nivel %d"], best) or nil, d.zoneName,
			type(d.players) == "number" and format(L["%d jugadores"], d.players) or nil }),
		avance = total > 0 and { v, total, format(L["%d de %d jefes vencidos"], v, total) } or nil,
	})
	-- Pestañas: solo las que tienen algo.
	local tiene = {
		resumen = true,
		jefes = #jefes > 0,
		botin = hayBotin(key),
		misiones = #e.lista > 0,
		consejos = D.Consejos(key) ~= nil,
	}
	local cuenta = { jefes = #jefes > 0 and #jefes or nil, misiones = #e.lista > 0 and #e.lista or nil }
	local opciones = {}
	for _, t in ipairs(PESTANAS) do
		if tiene[t.valor] then opciones[#opciones + 1] = { valor = t.valor, texto = t.texto, cuenta = cuenta[t.valor] } end
	end
	if not tiene[estado.pestana] then estado.pestana = "resumen" end
	p.Pestanas:SetOpciones(opciones)
	p.Pestanas:SetValor(estado.pestana)
	K.Mostrar(p.Pestanas, #opciones > 1)
	for clave, bloque in pairs(p.tabs) do K.Mostrar(bloque, clave == estado.pestana) end
	local t = estado.pestana
	if t == "jefes" then llenarJefes(p.tabs.jefes, key, e)
	elseif t == "botin" then llenarBotin(p.tabs.botin, key)
	elseif t == "misiones" then llenarMisiones(p.tabs.misiones, key, e, nivel)
	elseif t == "consejos" then llenarConsejos(p.tabs.consejos, key)
	else llenarResumen(p.tabs.resumen, key, d, e, nivel, lado) end
end

---------------------------------------------------------------------------
-- Tu progreso
---------------------------------------------------------------------------

local function construirProgreso(padre)
	local g = K.Pila(padre, { espacio = ESP.l })
	g.Volver = g:Agregar(Pz.Botones(g))
	g.Volver:Set({ Pz.Volver(g.Volver, L["Todas las mazmorras"], function() V.Ir("inicio") end) })
	g.Enc = g:Agregar(K.Encabezado(g, { icono = "ic-huella", titulo = L["Tu progreso"],
		subtitulo = L["Lo que este personaje lleva en las mazmorras: se guarda solo al vencer jefes y recoger botín."] }), { espacio = ESP.base })
	g.Numeros = g:Agregar(K.Rejilla(g, { min = 180, gap = ESP.m, variante = "compacta" }))
	g.SecMaz = g:Agregar(K.Seccion(g, L["Por mazmorra"]))
	g.Maz = g:Agregar(K.Rejilla(g, { min = 300, gap = ESP.m }), { espacio = ESP.m })
	g.SecBotin = g:Agregar(K.Seccion(g, L["Botín obtenido"]))
	g.Botin = g:Agregar(K.Rejilla(g, { min = 280, gap = ESP.s }), { espacio = ESP.m })
	g.Vacio = g:Agregar(K.Vacio(g, { lobo = "dormido", titulo = L["Todavía no hay progreso"],
		texto = L["Cuando venzas a tu primer jefe, tu progreso aparecerá aquí."],
		accion = { texto = L["Ver la de tu nivel"], alClic = function() V.Ir("inicio") end } }))
	return g
end

local function llenarProgreso(g)
	D.RevisarTodo()
	local hechas, jefes, objetos, veces = D.Resumen()
	local hay = hechas + jefes + objetos > 0
	g.Numeros:Llenar(numeros(hechas, jefes, objetos, veces))
	K.Mostrar(g.Numeros, hay)
	-- Por mazmorra, la más reciente primero.
	local p = D.Progreso()
	local filas, vistas = {}, {}
	local function reciente(key)
		local t = 0
		local h = p.hechas[key]
		if type(h) == "table" then t = max(t, h.t or 0, h.desde or 0) end
		local js = p.jefes[key]
		if type(js) == "table" then for _, r in pairs(js) do if type(r) == "table" then t = max(t, r.t or 0) end end end
		return t
	end
	for key in pairs(p.hechas) do vistas[key] = true end
	for key in pairs(p.jefes) do vistas[key] = true end
	for key in pairs(vistas) do filas[#filas + 1] = { key = key, t = reciente(key) } end
	sort(filas, function(a, b) if a.t ~= b.t then return a.t > b.t end return a.key < b.key end)
	local nivel, lado = D.Nivel(), D.Lado()
	local entradas = D.Entradas()
	local datos = {}
	for _, f in ipairs(filas) do
		local d = D.Info(f.key)
		if not d then
			local en = entradas[f.key]
			d = { key = f.key, name = (en and en.nombre) or f.key, minLevel = en and en.min, maxLevel = en and en.max, kind = en and en.tipo }
		end
		local v, total = D.Cuenta(f.key)
		local h = D.Hecha(f.key)
		-- Los jefes y "hecha" ya van en sus insignias.
		local partes = {}
		if h and (h.veces or 0) > 0 then partes[1] = cuantas(h.veces, L["completada 1 vez"], L["completada %d veces"]) end
		partes[#partes + 1] = fecha(f.t)
		datos[#datos + 1] = datosTarjeta(d, nivel, lado, unir(partes))
	end
	g.SecMaz:Set(L["Por mazmorra"], { cuenta = #datos })
	llenarTarjetas(g.Maz, datos)
	K.Mostrar(g.SecMaz, #datos > 0)
	-- Botín obtenido, lo último primero (los 24 más recientes).
	local botin = {}
	for id, b in pairs(p.botin) do
		if type(b) == "table" and type(id) == "number" then botin[#botin + 1] = { id = id, k = b.k, j = b.j, t = b.t or 0 } end
	end
	sort(botin, function(a, b) if a.t ~= b.t then return a.t > b.t end return a.id < b.id end)
	local celdas = {}
	for i, b in ipairs(botin) do
		if i > 24 then break end
		local nombreJefe
		for _, jf in ipairs(D.Jefes(b.k)) do if jf.id == b.j then nombreJefe = jf.nombre end end
		celdas[#celdas + 1] = datosCelda({ id = b.id, jefe = b.j }, b.k, nombreJefe or D.Nombre(b.k))
		celdas[#celdas].marca = nil
	end
	g.SecBotin:Set(L["Botín obtenido"], { cuenta = #botin })
	llenarCeldas(g.Botin, celdas)
	K.Mostrar(g.SecBotin, #celdas > 0)
	K.Mostrar(g.Vacio, not hay)
end

---------------------------------------------------------------------------
-- Sin datos todavía (el Codex se carga fuera de combate)
---------------------------------------------------------------------------

local function llenarSinDatos(v, razon)
	if razon == "combat" then
		v:Set({ lobo = "dormido", titulo = L["Se carga al salir de combate"],
			texto = L["Los datos de las mazmorras se cargan fuera de combate. Esta página se llena sola al terminar la pelea."] })
		N.FueraDeCombate(function() V.RefrescarPronto() end)
	elseif razon == "off" then
		v:Set({ lobo = "dormido", titulo = L["El diario de mazmorras está apagado"],
			texto = L["Préndelo para ver jefes, botín, misiones y consejos de cada mazmorra."],
			accion = { texto = L["Prenderlo"], icono = "ic-seguir", alClic = function() A.Set("dungeons.enabled", true) V.RefrescarPronto() end } })
	else
		v:Set({ lobo = "vacio", titulo = L["Faltan los datos de las mazmorras"],
			texto = L["No se encontró la carpeta Alfa_Codex. Reinstala Alfa completo."] })
	end
end

---------------------------------------------------------------------------
-- La vista
---------------------------------------------------------------------------

local function render()
	if not (vista and ui) then return 80 end
	local margen, ancho = N.MargenPagina(), N.AnchoPagina()
	local raiz
	local listo, razon = D.Listo()
	if not listo then
		raiz = ui.sinDatos
		llenarSinDatos(ui.sinDatos, razon)
	elseif estado.vista == "mazmorra" and D.Info(estado.clave) then
		raiz = ui.mazmorra
		llenarMazmorra(ui.mazmorra)
	elseif estado.vista == "progreso" then
		raiz = ui.progreso
		llenarProgreso(ui.progreso)
	else
		estado.vista = "inicio"
		raiz = ui.inicio
		llenarInicio(ui.inicio)
	end
	for _, r in ipairs({ ui.inicio, ui.mazmorra, ui.progreso, ui.sinDatos }) do r:SetShown(r == raiz) end
	raiz:ClearAllPoints()
	raiz:SetPoint("TOPLEFT", vista, "TOPLEFT", margen, -ESP.base)
	local h = raiz:Acomodar(ancho)
	raiz:SetWidth(ancho)
	return ESP.base + K.num(h, 0) + ESP.l
end

function V.Construir(view)
	vista = view
	ui = {
		inicio = construirInicio(view),
		mazmorra = construirMazmorra(view),
		progreso = construirProgreso(view),
		sinDatos = K.Vacio(view, { lobo = "dormido" }),
	}
	view.Refresh = function()
		local ok, h = pcall(render)
		if not ok then
			if geterrorhandler then geterrorhandler()(h) end
			return 80
		end
		return h
	end
end

function V.Visible() return vista ~= nil and vista:IsVisible() and true or false end

-- Repinta en su lugar (arriba: vuelve al principio de la página).
function V.Refrescar(arriba)
	if not V.Visible() then return end
	N.RehacerPagina(vista)
	if arriba then N.SubirPagina() end
end

local pronto
function V.RefrescarPronto(seg)
	if pronto then return end
	pronto = true
	local function ya()
		pronto = false
		V.Refrescar()
	end
	if A.After then A.After(seg or 0.1, ya) else ya() end
end

local function abrir()
	if V.Visible() then V.Refrescar(true) else N.Abrir(ID) end
end

function V.Ir(cual)
	estado.vista = cual
	abrir()
end

function V.Pestana(p)
	estado.pestana = p
	V.Refrescar(true)
end

-- Abre la página en una mazmorra (desde el chat, el minimapa, un aviso o la lista).
function V.AbrirMazmorra(key, pestana)
	if type(key) ~= "string" then return V.Ir("inicio") end
	if estado.clave ~= key then estado.pestana = "resumen" end
	estado.vista, estado.clave = "mazmorra", key
	if pestana then estado.pestana = pestana end
	abrir()
end

---------------------------------------------------------------------------
-- Los avisos de la mazmorra (Datos.lua los pide: M.Anunciar)
---------------------------------------------------------------------------

function M.Anunciar(tipo, key, a, b)
	local nombre = D.Nombre(key)
	if tipo == "entrada" then
		K.Aviso({ lobo = "atento", tono = "mazmorra", duracion = 8, titulo = format(L["Entraste a %s"], nombre),
			texto = (b or 0) > 0 and format(L["%d jefes, %d vencidos. Sus consejos te esperan en Alfa."], b, a or 0) or L["Sus consejos te esperan en Alfa."],
			accion = { texto = L["Ver sus jefes"], alClic = function() V.AbrirMazmorra(key, "jefes") end } })
	elseif tipo == "jefe" then
		K.Aviso({ icono = "ic-exito", tono = "exito", titulo = format(L["Descubriste a %s"], (type(a) == "table" and a.nombre) or "?"), texto = nombre,
			accion = { texto = L["Ver su botín"], alClic = function() V.AbrirMazmorra(key, "botin") end } })
	elseif tipo == "hecha" then
		P.Olvidar()
		local e = P.Estado(key)
		local veces = tonumber(a) or 1
		K.Aviso({ lobo = "aullando", tono = "acento", duracion = 10, titulo = format(L["¡Completaste %s!"], nombre),
			texto = veces > 1 and format(L["Ya van %d veces. La manada aúlla contigo."], veces) or L["La manada aúlla contigo."],
			accion = e.llevas > 0 and { texto = L["Entregar misiones"], alClic = function() P.Entregar(key) end }
				or { texto = L["Ver tu progreso"], alClic = function() V.Ir("progreso") end } })
	end
end

---------------------------------------------------------------------------
-- La página, el comando y lo que la repinta
---------------------------------------------------------------------------

N.Modulo({
	id = ID, nombre = L["Mazmorras"], icono = "ic-mazmorra", orden = 50, seccion = "aventura",
	subtitulo = L["La mazmorra para tu nivel, sus jefes, botín, misiones y consejos."],
	ajustes = { historia = true, avisoDescubrir = true, avisoEntrar = true, meSirve = false, capaEntradas = true },
	construir = function(view) V.Construir(view) end,
})

-- Minúsculas y sin acentos, para buscar como uno escribe ("sima ignea").
local ACENTOS = {
	["\195\161"] = "a", ["\195\169"] = "e", ["\195\173"] = "i", ["\195\179"] = "o", ["\195\186"] = "u",
	["\195\188"] = "u", ["\195\177"] = "n", ["\195\129"] = "a", ["\195\137"] = "e", ["\195\141"] = "i",
	["\195\147"] = "o", ["\195\154"] = "u", ["\195\156"] = "u", ["\195\145"] = "n",
}
local function plano(s)
	return (tostring(s or ""):gsub("\195[\128-\191]", ACENTOS):lower():gsub("[^%w]+", " "):gsub("^ +", ""):gsub(" +$", ""))
end

-- -> key | nil: igual, luego al principio, luego en cualquier parte del nombre.
local function buscarMazmorra(texto)
	local q = plano(texto)
	if q == "" then return nil end
	local inicio, dentro
	for _, d in ipairs(D.Lista()) do
		local n = plano(d.name)
		if n == q or d.key == q then return d.key end
		if not inicio and n:sub(1, #q) == q then inicio = d.key end
		if not dentro and n:find(q, 1, true) then dentro = d.key end
	end
	if inicio or dentro then return inicio or dentro end
	local x = Dg()
	local key = x and x.Find and llamar(x.Find, texto)
	return type(key) == "string" and key or nil
end
V.Buscar = buscarMazmorra

-- /alfa mazmorras [nombre | progreso | ajustes]
A.RegisterCommand("mazmorras", function(rest)
	rest = type(rest) == "string" and rest:gsub("^%s+", ""):gsub("%s+$", "") or ""
	local p = plano(rest)
	if p == "ajustes" then return abrirAjustes() end
	if p == "progreso" then return V.Ir("progreso") end
	if rest ~= "" then
		local key = D.Listo() and buscarMazmorra(rest)
		if type(key) == "string" then return V.AbrirMazmorra(key) end
		N.Imprimir(format(L["No encontré una mazmorra llamada «%s»."], rest))
	end
	V.Ir("inicio")
end, L["La mazmorra para tu nivel; con un nombre, esa mazmorra (también: progreso, ajustes)"])

D.AlCambiar(function() V.RefrescarPronto() end)

A.On("SETTING_CHANGED", function(path)
	if type(path) == "string" and (path == "" or path == ID or path:sub(1, #ID + 1) == ID .. "." or path == "dungeons.enabled") then
		V.RefrescarPronto()
	end
end)
A.On("GEAR_UPDATED", function() if estado.vista ~= "inicio" then V.RefrescarPronto(0.3) end end)
A.RegisterEvent("GET_ITEM_INFO_RECEIVED", function()
	if estado.vista ~= "inicio" and (estado.pestana == "botin" or estado.pestana == "jefes" or estado.vista == "progreso") then V.RefrescarPronto(0.5) end
end)
for _, ev in ipairs({ "PLAYER_LEVEL_UP", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED" }) do
	A.RegisterEvent(ev, function() V.RefrescarPronto(0.3) end)
end
A.RegisterEvent("QUEST_LOG_UPDATE", function() if estado.vista == "mazmorra" then V.RefrescarPronto(1) end end)
A.RegisterEvent("ZONE_CHANGED_NEW_AREA", function() V.RefrescarPronto(1) end)
