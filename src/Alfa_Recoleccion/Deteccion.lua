-- Alfa - Recolección: saber qué recolectaste y dónde (toxic3000 / La Jauría, GPL-3.0).
--
-- Método adaptado de código MIT (ver CREDITOS.md):
--   UNIT_SPELLCAST_SENT     el hechizo de minar, herborizar, abrir o forzar,
--                           con el nombre de lo que tocas: se anota dónde estás
--   UNIT_SPELLCAST_SUCCEEDED terminó: el nodo cuenta una vez más
--   LOOT_OPENED             el botín de ese nodo va al historial
-- Además, el botín dice qué objeto del juego lo dio (GetLootSourceInfo: su
-- GUID trae el ID del objeto). Así se reconoce un nodo aunque su nombre no
-- esté en el catálogo (y se aprende ese nombre para la próxima), y también
-- los bancos de peces, que se pescan sin un hechizo propio.
-- Nada de esto corre en instancias.

local _, M = ...
local N = AlfaNucleo
local A = N.A
local R = M.R

local pcall, type, tonumber, pairs, ipairs, max = pcall, type, tonumber, pairs, ipairs, math.max
local secreto = R.Secreto

-- Hechizos de recolección (todos sus rangos de Classic); otro ID con el mismo
-- nombre en tu idioma también cuenta.
local HECHIZOS = {
	[2575] = "mineria", [2576] = "mineria", [3564] = "mineria", [10248] = "mineria",
	[2366] = "hierbas", [2368] = "hierbas", [3570] = "hierbas", [11993] = "hierbas",
	[3365] = "tesoros", [1804] = "tesoros",
}
local BASE_HECHIZO = { [2575] = "mineria", [2366] = "hierbas", [3365] = "tesoros", [1804] = "tesoros" }

local nombresHechizo = {}
local function nombreHechizo(id)
	local n = nombresHechizo[id]
	if n ~= nil then return n or nil end
	local S = C_Spell
	local ok, nombre = false, nil
	if S and S.GetSpellName then ok, nombre = pcall(S.GetSpellName, id) end
	if ok and type(nombre) == "string" and not secreto(nombre) and nombre ~= "" then
		nombresHechizo[id] = nombre
		return nombre
	end
	return nil
end

local function tipoDeHechizo(spellID)
	if secreto(spellID) or type(spellID) ~= "number" then return nil end
	local t = HECHIZOS[spellID]
	if t ~= nil then return t or nil end
	local nombre = nombreHechizo(spellID)
	if not nombre then return nil end
	for id, tipo in pairs(BASE_HECHIZO) do
		if nombreHechizo(id) == nombre then
			HECHIZOS[spellID] = tipo
			return tipo
		end
	end
	HECHIZOS[spellID] = false
	return nil
end

---------------------------------------------------------------------------
-- Nombres: "Filón de cobre" -> grupo, por tipo de hechizo.
---------------------------------------------------------------------------
local function normalizar(s)
	s = s:gsub("|A.-|a", ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[%w_]+:", ""):gsub("|r", "")
	-- Mayúsculas con acento (UTF-8 de Latin-1) a minúsculas; el apóstrofo curvo al recto.
	s = s:gsub("\195[\128-\150\152-\158]", function(c) return "\195" .. string.char(c:byte(2) + 32) end)
	s = s:gsub("\226\128\153", "'")
	s = s:lower():gsub("^%s+", ""):gsub("%s+$", "")
	return s
end
R.Normalizar = normalizar

local porNombre -- tipo -> { [nombre normalizado] = grupo }

local function armarNombres()
	porNombre = {}
	for _, tipo in ipairs(M.TIPOS) do porNombre[tipo] = {} end
	for g, gr in ipairs(M.GRUPOS) do
		local t = porNombre[gr.tipo]
		local function poner(nombre)
			if type(nombre) == "string" and nombre ~= "" then
				local k = normalizar(nombre)
				if t[k] == nil then t[k] = g end
			end
		end
		poner(gr.es)
		poner(gr.en)
		for _, a in ipairs(gr.alias or {}) do poner(a) end
	end
	-- Los nombres que se aprendieron del botín.
	local aprendidos = R.Datos().nombres
	if type(aprendidos) == "table" then
		for tipo, lista in pairs(aprendidos) do
			local t = porNombre[tipo]
			if t and type(lista) == "table" then
				for k, clave in pairs(lista) do
					local g = M.porClave[clave]
					if g and t[k] == nil then t[k] = g end
				end
			end
		end
	end
end

function R.GrupoPorNombre(tipo, nombre, mapID)
	if not porNombre then armarNombres() end
	if type(nombre) ~= "string" or secreto(nombre) then return nil end
	local t = porNombre[tipo]
	local g = t and t[normalizar(nombre)]
	if g and M.GRUPOS[g].mapa and mapID and M.GRUPOS[g].mapa ~= mapID then return nil end
	return g
end

local function aprender(tipo, nombre, g)
	if not (tipo and type(nombre) == "string" and g) or secreto(nombre) then return end
	local D = R.Datos()
	if type(D.nombres) ~= "table" then D.nombres = {} end
	if type(D.nombres[tipo]) ~= "table" then D.nombres[tipo] = {} end
	local k = normalizar(nombre)
	if k == "" then return end
	D.nombres[tipo][k] = M.GRUPOS[g].clave
	if porNombre and porNombre[tipo] then porNombre[tipo][k] = g end
end

---------------------------------------------------------------------------
-- El botín abierto
---------------------------------------------------------------------------
local function numBotin()
	if not GetNumLootItems then return 0 end
	local ok, n = pcall(GetNumLootItems)
	if not ok or secreto(n) or type(n) ~= "number" then return 0 end
	return n
end

-- El ID del objeto del juego que dio el botín, si es un objeto (no un PNJ).
local function objetoDelBotin()
	if not GetLootSourceInfo then return nil end
	for slot = 1, numBotin() do
		local ok, guid = pcall(GetLootSourceInfo, slot)
		if ok and not secreto(guid) and type(guid) == "string" then
			local id = guid:match("^GameObject%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
			if id then return tonumber(id) end
		end
	end
	return nil
end

local function leerBotin()
	local objetos = {}
	if not (GetLootSlotLink and GetLootSlotInfo) then return objetos end
	for slot = 1, numBotin() do
		local ok, link = pcall(GetLootSlotLink, slot)
		if ok and not secreto(link) and type(link) == "string" then
			local id = tonumber(link:match("item:(%d+)"))
			if id then
				local ok2, _, _, cantidad = pcall(GetLootSlotInfo, slot)
				cantidad = ok2 and not secreto(cantidad) and tonumber(cantidad) or 1
				objetos[id] = (objetos[id] or 0) + max(1, cantidad)
			end
		end
	end
	return objetos
end

---------------------------------------------------------------------------
-- El seguimiento de un lanzamiento
---------------------------------------------------------------------------
local seg = {}            -- tipo, cast, hechizo, mapa, x, y, nombre, g, termino, contado
local ultimo = 0          -- GetTime() del último nodo anotado

local function limpiar() for k in pairs(seg) do seg[k] = nil end end

local function anotar(g, mapID, x, y, objectID)
	R.Registrar(g, mapID, x, y, objectID)
	R.Anotar(g, mapID)
	ultimo = GetTime()
	if M.Ruta and M.Ruta.Recolectado then M.Ruta.Recolectado(mapID, x, y) end
end

local function alEnviar(_, unidad, objetivo, castGUID, spellID)
	if secreto(unidad) or unidad ~= "player" then return end
	limpiar()
	if secreto(objetivo) or secreto(castGUID) or secreto(spellID) then return end
	local tipo = tipoDeHechizo(spellID)
	if not tipo or type(castGUID) ~= "string" or R.EnInstancia() then return end
	local mapID, x, y = R.PosicionJugador()
	if not mapID then return end
	seg.tipo, seg.cast, seg.hechizo, seg.mapa, seg.x, seg.y = tipo, castGUID, spellID, mapID, x, y
	if type(objetivo) == "string" and objetivo ~= "" then
		seg.nombre = objetivo
		seg.g = R.GrupoPorNombre(tipo, objetivo, mapID)
	end
end

local function alTerminar(_, unidad, castGUID, spellID)
	if secreto(unidad) or unidad ~= "player" then return end
	if secreto(castGUID) or secreto(spellID) then return end
	if not seg.cast or castGUID ~= seg.cast or spellID ~= seg.hechizo then return end
	seg.termino = GetTime()
	if seg.g then
		anotar(seg.g, seg.mapa, seg.x, seg.y)
		seg.contado = true
	end
end

local function alFallar(_, unidad, castGUID)
	if secreto(unidad) or unidad ~= "player" or secreto(castGUID) then return end
	if seg.cast and castGUID == seg.cast and not seg.termino then limpiar() end
end

local function alAbrirBotin()
	if R.EnInstancia() then return limpiar() end
	local ahora = GetTime()
	local objeto = objetoDelBotin()
	local gObjeto = objeto and M.porObjeto[objeto]
	if seg.termino and ahora - seg.termino < 3 then
		if not seg.contado and gObjeto and M.GRUPOS[gObjeto].tipo == seg.tipo then
			-- El nombre no estaba en el catálogo: el botín dice qué era.
			anotar(gObjeto, seg.mapa, seg.x, seg.y, objeto)
			seg.contado = true
			aprender(seg.tipo, seg.nombre, gObjeto)
		elseif seg.contado and gObjeto and gObjeto ~= seg.g and M.GRUPOS[gObjeto].tipo == seg.tipo then
			aprender(seg.tipo, seg.nombre, gObjeto)
		end
		if seg.contado then R.AnotarBotin(leerBotin()) end
	elseif gObjeto and ahora - ultimo > 3 then
		-- Botín de un nodo sin hechizo seguido (un banco de peces, un cofre flotante).
		local mapID, x, y = R.PosicionJugador()
		if mapID then
			anotar(gObjeto, mapID, x, y, objeto)
			R.AnotarBotin(leerBotin())
		end
	end
	limpiar()
end

A.RegisterEvent("UNIT_SPELLCAST_SENT", alEnviar)
A.RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", alTerminar)
A.RegisterEvent("UNIT_SPELLCAST_FAILED", alFallar)
A.RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", alFallar)
A.RegisterEvent("LOOT_OPENED", alAbrirBotin)
