-- Alfa - Pesca: tamaños, récords, tu nivel de pescador y el pez de la semana
-- (toxic3000 / La Jauría). GPL-3.0.
--
-- 1.3.8, a la manera de Alfa (la idea de un diario de pescador con tamaños,
-- récords, un nivel y un pez de la semana, hecha con lo nuestro):
--   * Tamaño de cada captura: el juego no da peso ni largo, así que Alfa le
--     da uno creíble a cada pieza: cada especie tiene su largo de siempre y
--     su forma, tu habilidad sube un poco la media y, muy de vez en cuando,
--     sale un ejemplar. Es estable y sin trampas: sale de tu personaje y del
--     número de tu captura (recargar o volver a lanzar no lo cambia).
--     Se muestra en centímetros y kilos (en inglés, pulgadas y libras), con
--     la coma o el punto de cada idioma.
--   * Récords personales por pez y por zona, con «¡Nuevo récord!».
--   * Tu nivel de pescador de Alfa: experiencia por captura (más por lo raro,
--     lo nuevo, los récords y los bancos), su barra y sus títulos. Quien ya
--     pescaba con Alfa empieza con lo que dice su diario.
--   * El pez de la semana: el mismo para todos los de tu facción (sale de la
--     fecha del servidor), con dónde pescarlo; sacar 5 da experiencia extra.
--   * La temporada (un mes del servidor): lo que ganas en ella va a la tabla
--     de La Jauría (Jauria.lua), si quieres compartirla.
-- Datos por personaje (AlfaNucleoCharDB.pesca): records, recordsZona, pescador.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID

local floor, max, min, format, type, pairs, ipairs, tonumber, tostring = math.floor, math.max, math.min, string.format, type, pairs, ipairs, tonumber, tostring

local Pz = {}
M.Pez = Pz

local function datos() return N.DatosPersonaje(ID) end
local function num(v) return tonumber(v) or 0 end

---------------------------------------------------------------------------
-- Las especies: el largo de siempre (cm) y su forma (gramos = forma × cm³).
-- Los trofeos dicen su peso en el nombre ("10 Pound..."): ese manda.
---------------------------------------------------------------------------
local FORMA = { pez = 0.012, anguila = 0.0028, plano = 0.018, langosta = 0.024 }
Pz.ESPECIE = {
	[6291] = { 12 }, [6303] = { 30 }, [6289] = { 34 }, [6317] = { 26 }, [6361] = { 58 }, [6308] = { 46 },
	[21071] = { 30 }, [6358] = { 38 }, [6359] = { 44 }, [6362] = { 55 }, [8365] = { 45 }, [21153] = { 40 },
	[4603] = { 60 }, [13754] = { 50 }, [13758] = { 36 }, [13756] = { 42 }, [13755] = { 34, "langosta" },
	[13759] = { 46 }, [13760] = { 60 }, [13889] = { 66 }, [13893] = { 76 }, [13888] = { 38, "langosta" },
	[13890] = { 50, "plano" }, [13422] = { 82, "anguila" }, [13757] = { 92, "anguila" }, [6522] = { 30 },
	[19807] = { 30 }, [8959] = { 72, "plano" }, [6299] = { 20 }, [6458] = { 26 }, [13546] = { 30 }, [19996] = { 36 },
	-- Concurso y misiones de pesca
	[19803] = { 48 }, [19805] = { 44 }, [19806] = { 52 }, [19808] = { 56 },
	[16967] = { 64 }, [16968] = { 70 }, [16969] = { 76 }, [16970] = { 62 },
	-- Sorpresas (peces hinchados)
	[6643] = { 40 }, [6644] = { 40 }, [6645] = { 40 }, [6646] = { 44 }, [6647] = { 46 }, [8366] = { 44 },
	[13881] = { 52 }, [13891] = { 56 }, [21162] = { 40 }, [21163] = { 44 }, [21164] = { 46 }, [21243] = { 52 },
}
local SIN_TAMANO = { botin = true }

-- Un número de 0 a 2^31 a partir de un texto (siempre el mismo).
local function hash(s)
	local h = 7
	for i = 1, #s do h = (h * 31 + s:byte(i)) % 2147483647 end
	return h
end

-- Números al azar que siempre salen iguales para la misma semilla (Park-Miller).
local function azar(semilla)
	local x = max(1, semilla % 2147483647)
	return function()
		x = (x * 48271) % 2147483647
		return x / 2147483647
	end
end

-- El peso de un trofeo, de su nombre: "10 Pound Mud Snapper" -> 10 libras.
local function librasDelNombre(nombre)
	if type(nombre) ~= "string" then return nil end
	local n = tonumber(nombre:match("(%d+)"))
	if n and n >= 3 and n <= 80 then return n end
	return nil
end

-- -> largo de siempre (cm), forma (g/cm³) o nil si no tiene tamaño (cofres, restos).
function Pz.Especie(id, clase, nombre)
	clase = clase or (id and M.CLASE[id]) or "otro"
	if SIN_TAMANO[clase] then return nil end
	local e = id and Pz.ESPECIE[id]
	if clase == "trofeo" then
		local lb = librasDelNombre(nombre or (id and M.Eq.Nombre(id)))
		local base = e and e[1] or 70
		local g = lb and lb * 453.6 or (FORMA.pez * base ^ 3)
		return base, g / (base ^ 3)
	end
	if e then return e[1], FORMA[e[2] or "pez"] end
	if clase == "otro" then
		-- Lo que no está en el catálogo: solo si parece pescado (comida o material).
		local clas
		if id and C_Item and C_Item.GetItemInfoInstant then
			local ok, _, _, _, _, _, c = pcall(C_Item.GetItemInfoInstant, id)
			if ok then clas = c end
		end
		if clas ~= 0 and clas ~= 7 then return nil end
	end
	return 20 + hash("especie:" .. tostring(id or nombre)) % 31, FORMA.pez
end

-- El tamaño de una pieza. -> { mm, g, ejemplar } | nil
--   semilla: texto único de esa pieza; hab: tu habilidad de pesca.
function Pz.Tamano(id, clase, semilla, hab, nombre)
	local base, forma = Pz.Especie(id, clase, nombre)
	if not base then return nil end
	local r = azar(hash(tostring(semilla)))
	-- Casi normal (suma de cuatro): la mayoría cerca de lo de siempre.
	local z = ((r() + r() + r() + r()) - 2) / 0.5774
	z = max(-2.5, min(2.5, z))
	local largo = base * (1 + 0.11 * z)
	-- Tu habilidad sube la media hasta un 6 %.
	largo = largo * (1 + 0.06 * max(0, min(1, (num(hab) - 1) / 300)))
	local ejemplar = r() < 0.03
	if ejemplar then largo = largo * (1.18 + 0.15 * r()) end
	local gordo = 1 + 0.07 * ((r() + r()) - 1)
	local g = forma * largo ^ 3 * gordo
	return { mm = max(20, floor(largo * 10 + 0.5)), g = max(5, floor(g + 0.5)), ejemplar = ejemplar or nil }
end

---------------------------------------------------------------------------
-- Cómo se escribe: centímetros y kilos (pulgadas y libras en inglés)
---------------------------------------------------------------------------
local COMA = { esMX = true, esES = true, deDE = true, frFR = true, ptBR = true, ruRU = true, itIT = true }
local function locale() return GetLocale and GetLocale() or "esMX" end
function Pz.Imperial() return locale() == "enUS" end

local function decimal(v, dec)
	local s = format("%." .. (dec or 1) .. "f", v)
	if COMA[locale()] then s = s:gsub("%.", ",") end
	return s
end
Pz.Decimal = decimal

function Pz.Largo(mm)
	mm = num(mm)
	if Pz.Imperial() then return format(L["%s in"], decimal(mm / 25.4, 1)) end
	return format(L["%s cm"], tostring(floor(mm / 10 + 0.5)))
end

function Pz.Peso(g)
	g = num(g)
	if Pz.Imperial() then
		local lb = g / 453.6
		if lb < 1 then return format(L["%s oz"], tostring(max(1, floor(g / 28.35 + 0.5)))) end
		return format(L["%s lb"], decimal(lb, 1))
	end
	if g < 1000 then return format(L["%s g"], tostring(floor(g + 0.5))) end
	return format(L["%s kg"], decimal(g / 1000, g >= 100000 and 0 or 1))
end

-- t = { mm, g } -> "32 cm · 0,4 kg"
function Pz.Texto(t)
	if type(t) ~= "table" or not t.g then return nil end
	if not t.mm then return Pz.Peso(t.g) end
	return Pz.Largo(t.mm) .. " \194\183 " .. Pz.Peso(t.g)
end

---------------------------------------------------------------------------
-- Récords
---------------------------------------------------------------------------
local function tabla(d, k)
	if type(d[k]) ~= "table" then d[k] = {} end
	return d[k]
end
function Pz.Records() return tabla(datos(), "records") end
function Pz.RecordsZona() return tabla(datos(), "recordsZona") end

-- El récord de un pez (clave del diario) -> { mm, g, t, z } | nil
function Pz.Record(clave) local r = Pz.Records()[clave] return type(r) == "table" and r or nil end

-- Los récords de ese pez por zona -> { { zona, mm, g, t } } (del más grande)
function Pz.RecordsDe(clave)
	local out = {}
	for zona, t in pairs(Pz.RecordsZona()) do
		local r = type(t) == "table" and t[clave]
		if type(r) == "table" then out[#out + 1] = { zona = zona, mm = r.mm, g = r.g, t = r.t } end
	end
	table.sort(out, function(a, b) return num(a.g) > num(b.g) end)
	return out
end

function Pz.CuantosRecords()
	local n = 0
	for _, r in pairs(Pz.Records()) do if type(r) == "table" then n = n + 1 end end
	return n
end

-- El más pesado de todos -> clave, récord
function Pz.MejorDeTodos()
	local mejor, clave
	for k, r in pairs(Pz.Records()) do
		if type(r) == "table" and (not mejor or num(r.g) > num(mejor.g)) then mejor, clave = r, k end
	end
	return clave, mejor
end

---------------------------------------------------------------------------
-- Nivel de pescador
---------------------------------------------------------------------------
Pz.MAX = 60
Pz.XP = {
	base = 10, primera = 40, record = 15, recordZona = 5, ejemplar = 20, banco = 4, semana = 10, premioSemana = 300,
	clase = { pez = 0, trofeo = 40, concurso = 60, mision = 15, sorpresa = 8, botin = 2, otro = 0 },
	calidad = { [2] = 5, [3] = 20, [4] = 50, [5] = 100 },
}
Pz.TITULOS = {
	{ 1, L["Cachorro de orilla"] }, { 5, L["Lobezno del muelle"] }, { 10, L["Pescador de la manada"] },
	{ 15, L["Ojo de garza"] }, { 20, L["Mano de sedal"] }, { 25, L["Lector de mareas"] }, { 30, L["Lobo de agua"] },
	{ 40, L["Señor del anzuelo"] }, { 50, L["Alfa de las aguas"] }, { 60, L["Leyenda de La Jauría"] },
}

-- Lo que pide un nivel para pasar al siguiente.
function Pz.Pide(nivel) return 60 + 30 * (max(1, nivel) - 1) end

-- -> nivel, xp dentro del nivel, lo que pide (nil al máximo), título
function Pz.Nivel(xp)
	xp = max(0, num(xp))
	local nivel = 1
	while nivel < Pz.MAX and xp >= Pz.Pide(nivel) do
		xp = xp - Pz.Pide(nivel)
		nivel = nivel + 1
	end
	return nivel, xp, nivel < Pz.MAX and Pz.Pide(nivel) or nil, Pz.Titulo(nivel)
end

function Pz.Titulo(nivel)
	local t = Pz.TITULOS[1][2]
	for _, x in ipairs(Pz.TITULOS) do if nivel >= x[1] then t = x[2] end end
	return t
end

Pz.MESES = { L["enero"], L["febrero"], L["marzo"], L["abril"], L["mayo"], L["junio"], L["julio"], L["agosto"],
	L["septiembre"], L["octubre"], L["noviembre"], L["diciembre"] }

-- La temporada: un mes del servidor ("202611").
function Pz.Temporada(t)
	t = t or (GetServerTime and GetServerTime()) or time()
	return date("!%Y%m", t)
end

function Pz.NombreTemporada(id)
	id = tostring(id or Pz.Temporada())
	local mes = tonumber(id:sub(5, 6))
	local nombre = mes and Pz.MESES[mes]
	return nombre and format(L["Temporada de %s"], nombre) or L["Esta temporada"]
end

-- Lo que llevas: { xp, semana = {...}, temporada = {...} }. Quien ya pescaba
-- con Alfa empieza con lo que dice su diario (una sola vez).
function Pz.Datos()
	local d = datos()
	local p = d.pescador
	if type(p) ~= "table" then
		local xp = 0
		for clave, e in pairs(M.Diario()) do
			if type(e) == "table" and num(e.n) > 0 then
				local c = Pz.XP.clase[(type(clave) == "number" and M.CLASE[clave]) or "otro"] or 0
				xp = xp + num(e.n) * (Pz.XP.base + c) + Pz.XP.primera
			end
		end
		p = { xp = xp, desde = time(), historial = xp > 0 or nil }
		d.pescador = p
	end
	p.xp = num(p.xp)
	local tid = Pz.Temporada()
	if type(p.temporada) ~= "table" or p.temporada.id ~= tid then
		p.temporada = { id = tid, xp = 0, records = 0, capturas = 0 }
	end
	return p
end

-- Suma experiencia; si subes de nivel, lo dice (una vez por tanda).
function Pz.Ganar(xp, sinAviso)
	xp = floor(num(xp))
	if xp <= 0 then return 0 end
	local p = Pz.Datos()
	local antes = Pz.Nivel(p.xp)
	p.xp = p.xp + xp
	p.temporada.xp = num(p.temporada.xp) + xp
	local despues, _, _, titulo = Pz.Nivel(p.xp)
	if despues > antes then
		Pz.subio = despues
		if not sinAviso then Pz.AvisarNivel(despues, antes) end
		if M.Jauria and M.Jauria.Cambio then M.Jauria.Cambio("nivel") end
	end
	M.Avisar("pescador")
	return xp
end

function Pz.AvisarNivel(nivel, antes)
	if not (N.Kit and N.Kit.Aviso) or not M.Opt("avisoNivel") then return end
	local titulo = Pz.Titulo(nivel)
	local nuevoTitulo = titulo ~= Pz.Titulo(antes or (nivel - 1))
	N.Kit.Aviso({ id = "pesca.nivel", lobo = "aullando", tono = "acento", duracion = 6, detalle = not nuevoTitulo or nil,
		titulo = format(L["Pescador de Alfa: nivel %d"], nivel),
		texto = nuevoTitulo and format(L["Tu título nuevo: %s."], titulo) or titulo,
		accion = { texto = L["Ver mi nivel"], alClic = function() if M.V then M.V.Abrir("pescador") end end } })
	if M.Opt("alertas") and PlaySound then pcall(PlaySound, M.SONIDO_LOGRO, "Master") end
end

---------------------------------------------------------------------------
-- El pez de la semana: el mismo para todos los de tu facción (la fecha del
-- servidor), con dónde pescarlo. A = Alianza, H = Horda (mapas del juego).
---------------------------------------------------------------------------
Pz.SEMANA = {
	{ id = 6289, A = { 1429, 1432, 1436 }, H = { 1420, 1421, 1413 } },           -- pargo de barro
	{ id = 6308, A = { 1436, 1433, 1437 }, H = { 1413, 1421, 1424 } },           -- bagre
	{ id = 6361, A = { 1436, 1439 }, H = { 1413, 1421 } },                       -- albacora
	{ id = 21071, A = { 1432, 1436 }, H = { 1421, 1413 } },                      -- salvia
	{ id = 6358, A = { 1437, 1436, 1417 }, H = { 1413, 1424, 1417 } },           -- boca negra
	{ id = 6359, A = { 1437, 1417 }, H = { 1424, 1442, 1417 } },                 -- aleta de fuego
	{ id = 6362, A = { 1440, 1434, 1443 }, H = { 1424, 1434, 1443 } },           -- bacalao
	{ id = 8365, A = { 1431, 1437, 1417 }, H = { 1424, 1435, 1417 } },           -- trucha
	{ id = 21153, A = { 1416, 1434 }, H = { 1416, 1434, 1421 } },                -- gran salvia
	{ id = 4603, A = { 1434, 1444, 1446 }, H = { 1434, 1444, 1446 } },           -- cola amarilla
	{ id = 13422, A = { 1434, 1444, 1447 }, H = { 1434, 1444, 1447 } },          -- anguila
	{ id = 13754, A = { 1444, 1446, 1447 }, H = { 1444, 1446, 1447 } },          -- pez de poder
	{ id = 13759, A = { 1425, 1423, 1448 }, H = { 1425, 1423, 1448 } },          -- pargo de aleta nocturna
	{ id = 13760, A = { 1451, 1448, 1452 }, H = { 1451, 1448, 1452 } },          -- salmón escama de sol
}
Pz.META_SEMANA = 5

local function faccion()
	local f = UnitFactionGroup and N.Leer((UnitFactionGroup("player")))
	if f == "Alliance" then return "A" end
	if f == "Horde" then return "H" end
	return nil
end
Pz.Faccion = faccion

-- La semana del servidor (empieza el lunes 00:00 UTC).
function Pz.NumeroSemana(t)
	t = t or (GetServerTime and GetServerTime()) or time()
	return floor((t - 345600) / 604800)
end

-- -> { id, mapas, semana, faccion, llevas, meta, premiado, quedan (segundos) }
function Pz.Semana(t)
	t = t or (GetServerTime and GetServerTime()) or time()
	local f = faccion() or "A"
	local lista = {}
	for _, x in ipairs(Pz.SEMANA) do if x[f] and #x[f] > 0 then lista[#lista + 1] = x end end
	if #lista == 0 then return nil end
	local s = Pz.NumeroSemana(t)
	local x = lista[hash("semana:" .. s .. ":" .. f) % #lista + 1]
	local p = Pz.Datos()
	if type(p.semana) ~= "table" or p.semana.k ~= s then p.semana = { k = s, n = 0 } end
	local fin = (s + 1) * 604800 + 345600
	return { id = x.id, mapas = x[f], semana = s, faccion = f, llevas = num(p.semana.n), meta = Pz.META_SEMANA,
		premiado = p.semana.premiado and true or false, quedan = max(0, fin - t) }
end

---------------------------------------------------------------------------
-- Cada captura (la llama Registro.lua por cada objeto que sacas)
--   o = { id, nombre, calidad }, clave del diario, n piezas, zona,
--   info = { banco, primera } -> { tam, record ("pez" | "zona"), xp }
---------------------------------------------------------------------------
local ANOTAR_MAX = 5 -- piezas que se miden de una misma captura

function Pz.Anotar(o, clave, n, zona, info)
	info = info or {}
	n = max(1, num(n))
	local v = M.Vida()
	local hab = M.Habilidad and M.Habilidad() or 0
	local yo = (UnitGUID and N.Leer((UnitGUID("player")))) or (UnitName and N.Leer((UnitName("player")))) or "?"
	local clase = (type(o.id) == "number" and M.CLASE[o.id]) or "otro"
	local mejor, total
	for i = 1, min(n, ANOTAR_MAX) do
		local t = Pz.Tamano(o.id, clase, yo .. ":" .. num(v.capturas) .. ":" .. tostring(clave) .. ":" .. i, hab, o.nombre)
		if t then
			total = (total or 0) + t.g
			if not mejor or t.g > mejor.g then mejor = t end
		end
	end
	if total and n > ANOTAR_MAX then total = floor(total / ANOTAR_MAX * n + 0.5) end
	local out = { tam = mejor, peso = total }
	-- Los récords.
	local p = Pz.Datos()
	if mejor then
		local ahora = time()
		local recs = Pz.Records()
		local r = recs[clave]
		if type(r) ~= "table" or mejor.g > num(r.g) then
			-- El primero de su especie es récord, pero «¡Nuevo récord!» es al ganarle a otro.
			if type(r) == "table" then out.record = "pez" end
			recs[clave] = { mm = mejor.mm, g = mejor.g, t = ahora, z = zona }
			p.temporada.records = num(p.temporada.records) + (out.record and 1 or 0)
		end
		local porZona = Pz.RecordsZona()
		local zt = type(porZona[zona]) == "table" and porZona[zona] or {}
		porZona[zona] = zt
		local rz = zt[clave]
		if type(rz) ~= "table" or mejor.g > num(rz.g) then
			if type(rz) == "table" and not out.record then out.record = "zona" end
			zt[clave] = { mm = mejor.mm, g = mejor.g, t = ahora }
		end
		if not p.temporada.mejor or mejor.g > num(p.temporada.mejor.g) then
			p.temporada.mejor = { id = type(o.id) == "number" and o.id or nil, g = mejor.g, mm = mejor.mm }
		end
	end
	p.temporada.capturas = num(p.temporada.capturas) + n
	-- La experiencia.
	local X = Pz.XP
	local xp = n * (X.base + (X.clase[clase] or 0)) + (X.calidad[num(o.calidad)] or 0)
	if info.primera then xp = xp + X.primera end
	if out.record == "pez" then xp = xp + X.record elseif out.record == "zona" then xp = xp + X.recordZona end
	if mejor and mejor.ejemplar then xp = xp + X.ejemplar end
	if info.banco then xp = xp + X.banco end
	-- El pez de la semana.
	local sem = Pz.Semana()
	if sem and o.id == sem.id then
		xp = xp + X.semana * n
		p.semana.n = num(p.semana.n) + n
		out.semana = true
		if not p.semana.premiado and p.semana.n >= sem.meta then
			p.semana.premiado = time()
			xp = xp + X.premioSemana
			out.premioSemana = true
		end
	end
	out.xp = xp
	return out
end

-- Lo de toda una ventana de botín (después de anotar cada objeto): la sesión,
-- la experiencia y los avisos.
function Pz.TrasCaptura(s, lista)
	local xp, peso = 0, 0
	local nuevoRecord, premio
	for _, x in ipairs(lista) do
		xp = xp + num(x.xp)
		peso = peso + num(x.peso)
		if x.record == "pez" then nuevoRecord = true end
		if x.premioSemana then premio = true end
		if x.tam and (type(s.mejor) ~= "table" or x.tam.g > num(s.mejor.g)) then
			s.mejor = { id = x.id, nombre = x.nombre, g = x.tam.g, mm = x.tam.mm }
		end
	end
	s.peso = num(s.peso) + peso
	s.xp = num(s.xp) + xp
	Pz.Ganar(xp)
	if premio and N.Kit and N.Kit.Aviso then
		local sem = Pz.Semana()
		local nombre = sem and M.V and M.V.NombreObjeto(sem.id) or ""
		N.Kit.Aviso({ id = "pesca.semana", icono = "ic-exito", tono = "exito", duracion = 6,
			titulo = L["¡Pez de la semana cumplido!"],
			texto = format(L["Sacaste %d de %s: +%d de experiencia de pescador."], Pz.META_SEMANA, nombre, Pz.XP.premioSemana),
			accion = { texto = L["Ver mi nivel"], alClic = function() if M.V then M.V.Abrir("pescador") end end } })
	end
	if nuevoRecord and M.Jauria and M.Jauria.Cambio then M.Jauria.Cambio("record") end
end

-- Para mostrar la experiencia: "Nivel 7 · 40/180"
function Pz.TextoNivel()
	local p = Pz.Datos()
	local nivel, en, pide, titulo = Pz.Nivel(p.xp)
	if not pide then return format(L["Nivel %d · %s"], nivel, titulo), nivel, 1, 1, titulo end
	return format(L["Nivel %d · %s"], nivel, titulo), nivel, en, pide, titulo
end

-- Borrar todo (Registro.lua: M.BorrarTodo) también borra esto.
function Pz.Borrar()
	local d = datos()
	d.records, d.recordsZona, d.pescador = nil, nil, nil
end

---------------------------------------------------------------------------
-- 1.3.9: la fecha de un récord ("12 de noviembre de 2026"; sin el año si es
-- de este año) y el aviso del pez de la semana al llegar a una de sus zonas.
---------------------------------------------------------------------------
function Pz.Fecha(t)
	t = tonumber(t)
	if not t then return nil end
	local d = date("*t", t)
	local hoy = date("*t", time())
	local molde = d.year == hoy.year and L["{dia} de {mes}"] or L["{dia} de {mes} de {año}"]
	local mes = Pz.MESES[d.month] or tostring(d.month)
	return (molde:gsub("{dia}", tostring(d.day)):gsub("{mes}", mes):gsub("{año}", tostring(d.year)))
end

-- El mapa y sus padres (una subzona o una ciudad cuentan como su zona).
local function zonasDe(mapa)
	local out, n = {}, 0
	local C = C_Map
	while mapa and n < 4 do
		out[#out + 1] = mapa
		n = n + 1
		if not (C and C.GetMapInfo) then break end
		local ok, info = pcall(C.GetMapInfo, mapa)
		local padre = ok and type(info) == "table" and tonumber(N.Leer(info.parentMapID)) or nil
		if not padre or padre == mapa or padre == 0 then break end
		mapa = padre
	end
	return out
end

-- -> true si avisó. Una vez por zona y por semana; nunca en combate; solo si pescas.
function Pz.AvisoSemanaZona(mapa)
	if not M.Opt("avisoSemana") then return false end
	if InCombatLockdown and InCombatLockdown() then return false end
	if (num(M.Habilidad and M.Habilidad() or 0)) <= 0 then return false end
	local s = Pz.Semana()
	if not s or s.premiado or s.llevas >= s.meta then return false end
	mapa = mapa or (M.MapaJugador and M.MapaJugador())
	if not mapa then return false end
	local suya
	local enLista = {}
	for _, m in ipairs(s.mapas or {}) do enLista[m] = true end
	for _, m in ipairs(zonasDe(mapa)) do if enLista[m] then suya = m break end end
	if not suya then return false end
	local p = Pz.Datos()
	p.semana.avisados = type(p.semana.avisados) == "table" and p.semana.avisados or {}
	if p.semana.avisados[suya] then return false end
	p.semana.avisados[suya] = true
	local nombre = M.V and M.V.NombreObjeto(s.id) or tostring(s.id)
	local zona = M.V and M.V.NombreMapa(suya) or ""
	local libre = N.AlLibre or function(_, f) f() end
	libre("pesca.semanaZona", function()
		if not (N.Kit and N.Kit.Aviso) then return end
		N.Kit.Aviso({ id = "pesca.semanaZona", icono = "ic-pesca", tono = "oro", duracion = 8, prioridad = 3,
			titulo = L["El pez de la semana anda por aquí"],
			texto = format(L["%s sale en %s. Llevas %d de %d esta semana."], nombre, zona, s.llevas, s.meta),
			accion = { texto = L["Ver el pez de la semana"], alClic = function() if M.V then M.V.Abrir("pescador") end end } })
	end, 3)
	return true
end

local function revisarZona() N.Una("pesca.semanaZona", 6, function() Pz.AvisoSemanaZona() end, { fueraDeCombate = true }) end
A.RegisterEvent("ZONE_CHANGED_NEW_AREA", revisarZona)
A.RegisterEvent("PLAYER_ENTERING_WORLD", revisarZona)
