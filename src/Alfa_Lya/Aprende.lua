-- Alfa - Lya aprende (1.2.8). toxic3000 / La Jauría. GPL-3.0.
--
--   Si cierras con la X tres veces el mismo tipo de consejo sin hacer nada,
--   Lya pregunta una vez «¿Ya no quieres que te diga esto?»: «Ya no» lo calla
--   (Cerebro.lua no lo vuelve a decir solo; si se lo pides, sí), «Sí, sígueme
--   diciendo» vuelve a contar desde cero. Los callados salen en su página
--   («Consejos que callaste») con su botón para devolverlos. lya.aprende
--   apaga la pregunta; lo que ya callaste sigue callado hasta que lo devuelvas.
--
--   El tipo de un consejo: c.clase, o la categoría de su id ("reparar3" ->
--   "reparar"); los saludos, los antojos y los consejos de mazmorra van juntos.
--   Nunca se cuentan lo importante (morir, subir de nivel, tus logros), lo que
--   pediste tú ni los avisos de Alfa.
--
--   Ap.Clase(c) -> tipo | nil     Ap.Callada(c) -> bool
--   Ap.AlCerrar(c)  Ap.AlActuar(c)  Ap.Callar(tipo, muestra)  Ap.Devolver(tipo)
--   Ap.DevolverTodos()  Ap.Lista() -> { { clave, nombre, fecha }, ... }

local ADDON, M = ...
local N = AlfaNucleo
local K = N.Kit
local L = M.L
local ID = M.ID

local type, pairs, tonumber, format, sort = type, pairs, tonumber, string.format, table.sort

local Ap = {}
M.Aprende = Ap

local VECES = 3

-- Las categorías que van juntas.
local GRUPO = {
	saludoManana = "saludo", saludoTarde = "saludo", saludoNoche = "saludo", bienvenida = "saludo",
	llegada = "saludo", volver = "saludo",
	hambre = "antojo", salchichas = "antojo", pideSalchicha = "antojo",
	mazmorraSin = "mazmorra",
}
-- Lo que nunca se calla así: lo importante y las respuestas a lo que haces.
local NUNCA = {
	presentacion = true, nuevo = true, hito = true, nivel = true, muerte = true, misionesHoy = true,
	racha = true, consuelo = true, gracias = true, graciasTotal = true, adios = true, adiosSin = true,
	antesDeIrte = true,
}
-- Su nombre en la lista de su página.
local NOMBRES = {
	reparar = "Ir a reparar",
	bolsas = "Bolsas llenas",
	entrenar = "Habilidades por entrenar",
	entregar = "Misiones por entregar",
	sabias = "Lo que sabe de Alfa",
	consejo = "Consejos del juego",
	animo = "Palabras de ánimo",
	carino = "Sus cariñitos",
	antojo = "Sus antojos y salchichas",
	zona = "Comentarios de la zona",
	ambiente = "Comentarios del momento",
	descanso = "Avisos de descanso",
	charla = "La plática: lore y datos",
	dato = "Datos curiosos",
	historia = "Historias de las misiones",
	mazmorra = "Consejos al entrar a una mazmorra",
	saludo = "Saludos al entrar",
	oficios = "Tus oficios",
}

local function datos()
	local d = N.DatosPersonaje(ID)
	d.callados = type(d.callados) == "table" and d.callados or {}
	d.cerrados = type(d.cerrados) == "table" and d.cerrados or {}
	d.preguntados = type(d.preguntados) == "table" and d.preguntados or {}
	return d
end

local function hoy() return date and date("%Y-%m-%d") or "?" end

function Ap.Clase(c)
	if type(c) ~= "table" or c.aprende == false then return nil end
	local k = c.clase
	if type(k) ~= "string" then
		local id = c.id
		if type(id) ~= "string" then return nil end
		if id:find(":", 1, true) then
			-- Los de otros módulos (AlfaLya.Decir, id "otro:mio1"): cada uno el suyo.
			if id:match("^(%a+):") ~= "otro" then return nil end
			k = id:gsub("%d+$", "")
		else
			k = id:match("^(%a+)")
		end
	end
	if not k or k == "" then return nil end
	k = GRUPO[k] or k
	if NUNCA[k] then return nil end
	return k
end

function Ap.Callada(c)
	local k = Ap.Clase(c)
	return k ~= nil and datos().callados[k] ~= nil
end

function Ap.Nombre(k, muestra)
	if NOMBRES[k] then return L[NOMBRES[k]] end
	if type(muestra) == "string" and muestra ~= "" then
		-- Un pedacito de lo que decía (cortado en un espacio, sin partir letras).
		if #muestra <= 48 then return muestra end
		local corte = muestra:sub(1, 48):match("^(.*)%s") or muestra:sub(1, 40)
		return corte .. "…"
	end
	return k
end

local function decir(texto, acciones)
	local Ce = M.Cerebro
	if not Ce then return false end
	return Ce.Decir({ texto = texto, pedido = true, aprende = false, cara = acciones and "atenta" or nil,
		segundos = acciones and 12 or 7, lineas = 4, acciones = acciones }) == true
end

function Ap.Preguntar(k, muestra)
	local d = datos()
	if d.preguntados[k] or d.callados[k] then return false end
	local ok = decir(format(L["%s: ya lo cerraste tres veces. ¿Ya no quieres que te diga esto?"], Ap.Nombre(k, muestra)), {
		{ texto = L["Ya no"], fn = function() Ap.Callar(k, muestra) end },
		{ texto = L["Sí, sígueme diciendo"], fn = function() Ap.Seguir(k) end },
	})
	if ok then d.preguntados[k] = hoy() end
	return ok
end

function Ap.AlCerrar(c)
	if type(c) ~= "table" or c.pedido or c.importante then return end
	local k = Ap.Clase(c)
	if not k then return end
	local d = datos()
	local n = (tonumber(d.cerrados[k]) or 0) + 1
	d.cerrados[k] = n
	if n >= VECES and not d.preguntados[k] and not d.callados[k] and N.Get(ID, "aprende") ~= false then
		local muestra = c.texto
		K.Despues(0.6, function() Ap.Preguntar(k, muestra) end)
	end
end

function Ap.AlActuar(c)
	local k = Ap.Clase(c)
	if k then datos().cerrados[k] = nil end
end

function Ap.Callar(k, muestra)
	local d = datos()
	d.callados[k] = { fecha = hoy(), muestra = type(muestra) == "string" and muestra or nil }
	d.cerrados[k] = nil
	decir(L["Listo, ya no te lo digo. Si me extrañas, está en mi página: «Consejos que callaste»."])
	M.Avisar()
end

function Ap.Seguir(k)
	datos().cerrados[k] = nil
	decir(L["¡Va! Te lo sigo diciendo, con gusto."])
end

function Ap.Devolver(k)
	local d = datos()
	d.callados[k], d.cerrados[k], d.preguntados[k] = nil, nil, nil
	M.Avisar()
end

function Ap.DevolverTodos()
	local d = datos()
	d.callados, d.cerrados, d.preguntados = {}, {}, {}
	N.Imprimir(L["Lya vuelve a decirte todos los consejos que callaste."])
	M.Avisar()
end

function Ap.Lista()
	local t = {}
	for k, v in pairs(datos().callados) do
		local muestra = type(v) == "table" and v.muestra or nil
		t[#t + 1] = { clave = k, nombre = Ap.Nombre(k, muestra), fecha = type(v) == "table" and v.fecha or nil }
	end
	sort(t, function(a, b) return tostring(a.nombre) < tostring(b.nombre) end)
	return t
end

-- Los ganchos del globo (Lya.lua).
M.AlCerrarGlobo = Ap.AlCerrar
M.AlActuarGlobo = Ap.AlActuar
