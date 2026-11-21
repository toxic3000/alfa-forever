-- Alfa - Builds: compartir builds con una cadena de texto (toxic3000 / La Jauría). GPL-3.0.
--
-- Cadena:  ALFA1;CLASE;rama;objetivo;estilo;Título;spell-rango,spell-rango,...
-- Los talentos van en orden, como las entradas de Builds/<Clase>.lua (cada
-- par sube ese talento hasta ese rango). Una cadena importada se guarda en
-- el personaje y aparece entre los builds para elegir.
--
--   S.Exportar(build) -> texto
--   S.ExportarActual() -> texto | nil, razon   (tus talentos de ahora)
--   S.Importar(texto) -> build | nil, error
--   S.Borrar(id) ; S.Lista() -> { build... }
--   M.Importado(id) -> build | nil

-- 1.3.6: en lo que lees dice «plan de talentos» en vez de «build» (la cadena ALFA1; sigue igual).
local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local S = {}
M.Compartir = S

local PREFIJO = "ALFA1"
local MAX_TEXTO, MAX_TALENTOS, MAX_IMPORTADOS = 2000, 80, 12

local function guardados()
	local d = N.DatosPersonaje(M.ID)
	d.importados = type(d.importados) == "table" and d.importados or {}
	return d.importados
end

-- 1.3.7: hasta `n` letras sin partir una letra de varios bytes (á, ñ, cirílico,
-- chino...): cortar por bytes dejaba la última letra rota en el título.
function M.Cortar(s, n)
	if type(s) ~= "string" or #s <= n then return s end
	local out, k = {}, 0
	for c in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		k = k + 1
		if k > n then break end
		out[k] = c
	end
	return table.concat(out)
end

local function limpio(s, largo)
	s = tostring(s or ""):gsub("[;|%c]", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
	if largo then s = M.Cortar(s, largo) end
	return s
end

function S.Exportar(b)
	local partes = {}
	for _, t in ipairs(b.talentos or {}) do partes[#partes + 1] = t[1] .. "-" .. t[2] end
	return table.concat({ PREFIJO, b.clase or "", b.spec or "", b.objetivo or "", b.estilo or "",
		limpio(b.titulo, 40), table.concat(partes, ",") }, ";")
end

-- Tus talentos de ahora, en un orden que el árbol acepta: por rama y por fila.
function S.ExportarActual()
	local vivo, razon = M.Arbol.Actual()
	if not vivo then return nil, razon end
	local d = M.Arbol.Disposicion(vivo)
	local lista = {}
	for _, n in ipairs(d.nodos) do
		local v = vivo.nodos[n.id]
		if v and v.activo > 0 and v.spell then lista[#lista + 1] = { n = n, r = v.activo, spell = v.spell } end
	end
	if #lista == 0 then return nil, "vacio" end
	table.sort(lista, function(a, b)
		if a.n.fila ~= b.n.fila then return a.n.fila < b.n.fila end
		if (a.n.spec or 0) ~= (b.n.spec or 0) then return (a.n.spec or 0) < (b.n.spec or 0) end
		return a.n.col < b.n.col
	end)
	-- La rama con más puntos da nombre al build.
	local por, mejor = {}, nil
	for _, e in ipairs(lista) do por[e.n.spec or 0] = (por[e.n.spec or 0] or 0) + e.r end
	for s, c in pairs(por) do if not mejor or c > por[mejor] then mejor = s end end
	local spec = "?"
	local dc = M.DatosClase()
	for clave, sp in pairs(dc and dc.especialidades or {}) do
		if sp.indice == mejor then spec = clave end
	end
	local partes = {}
	for _, e in ipairs(lista) do partes[#partes + 1] = e.spell .. "-" .. e.r end
	local nombre = UnitName("player")
	nombre = A.Compat.Readable(nombre) or "?"
	return table.concat({ PREFIJO, M.ClaseJugador() or "", spec, "solo", "equilibrado",
		limpio(string.format(L["Talentos de %s"], nombre), 40), table.concat(partes, ",") }, ";")
end

S.ERRORES = {
	vacio = L["Pega primero una cadena de talentos de Alfa."],
	largo = L["Ese texto es demasiado largo para un plan de talentos."],
	formato = L["Eso no es una cadena de talentos de Alfa. Empieza con ALFA1;"],
	clase = L["Ese plan de talentos es para otra clase."],
	talentos = L["La cadena no trae talentos válidos."],
	lleno = L["Ya tienes demasiados planes importados. Borra alguno primero."],
}

-- Convierte lo guardado en un build que el resto del módulo entiende.
local function construir(id, g)
	local base
	for _, b in ipairs(M.Builds()) do
		if b.spec == g.spec and (b.objetivo == g.objetivo or not base) then base = b end
	end
	base = base or M.Builds()[1]
	local b = {
		id = id, clase = g.clase, spec = g.spec, objetivo = g.objetivo, estilo = g.estilo,
		titulo = g.titulo, importado = true, data = M.DatosClase(),
		resumen = L["Plan de talentos importado de una cadena. Alfa lo resuelve en tu árbol y te avisa si algún talento no existe."],
		talentos = g.talentos, armas = base and base.armas, stats = base and base.stats,
		consejos = {}, pesos = base and base.pesos,
	}
	return M.RegistrarSuelto(b)
end

function M.Importado(id)
	local g = guardados()[id]
	if type(g) ~= "table" then return nil end
	return construir(id, g)
end

function S.Lista()
	local out = {}
	for id, g in pairs(guardados()) do
		if type(g) == "table" then out[#out + 1] = M.Importado(id) end
	end
	table.sort(out, function(a, b) return (a.titulo or "") < (b.titulo or "") end)
	return out
end

function S.Importar(texto)
	if type(texto) ~= "string" then return nil, "vacio" end
	texto = texto:gsub("^%s+", ""):gsub("%s+$", "")
	if texto == "" then return nil, "vacio" end
	if #texto > MAX_TEXTO then return nil, "largo" end
	local campos = {}
	for c in (texto .. ";"):gmatch("([^;]*);") do campos[#campos + 1] = c end
	if campos[1] ~= PREFIJO or #campos < 7 then return nil, "formato" end
	local clase = campos[2]
	if clase ~= M.ClaseJugador() then return nil, "clase" end
	local talentos = {}
	for spell, rango in campos[7]:gmatch("(%d+)%-(%d+)") do
		spell, rango = tonumber(spell), tonumber(rango)
		if spell and rango and rango >= 1 and rango <= 5 then talentos[#talentos + 1] = { spell, rango } end
		if #talentos > MAX_TALENTOS then return nil, "largo" end
	end
	if #talentos == 0 then return nil, "talentos" end
	local g = guardados()
	-- 1.3.7: el mismo plan (misma rama y mismos talentos) importado otra vez no
	-- se duplica: se devuelve el que ya tienes.
	local firma = {}
	for _, t in ipairs(talentos) do firma[#firma + 1] = t[1] .. "-" .. t[2] end
	firma = table.concat(firma, ",")
	for id, viejo in pairs(g) do
		if type(viejo) == "table" and viejo.clase == clase and type(viejo.talentos) == "table" then
			local otra = {}
			for _, t in ipairs(viejo.talentos) do otra[#otra + 1] = tostring(t[1]) .. "-" .. tostring(t[2]) end
			if table.concat(otra, ",") == firma then return M.Importado(id), "repetido" end
		end
	end
	local n = 0
	for _ in pairs(g) do n = n + 1 end
	if n >= MAX_IMPORTADOS then return nil, "lleno" end
	local dc = M.DatosClase()
	local spec = campos[3]
	if not (dc and dc.especialidades and dc.especialidades[spec]) then
		for k in pairs(dc and dc.especialidades or {}) do spec = k break end
	end
	local objetivo = M.Objetivo(campos[4]) and campos[4] or "solo"
	local estilo = M.Estilo(campos[5]) and campos[5] or "equilibrado"
	local titulo = limpio(campos[6], 40)
	if titulo == "" then titulo = L["Plan importado"] end
	local id = "imp-" .. tostring(time and time() or 0) .. "-" .. tostring(math.random(1000, 9999))
	g[id] = { clase = clase, spec = spec, objetivo = objetivo, estilo = estilo, titulo = titulo, talentos = talentos, fecha = time and time() or 0 }
	return M.Importado(id)
end

function S.Borrar(id)
	guardados()[id] = nil
	M.OlvidarSuelto(id)
end
