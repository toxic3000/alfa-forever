-- Alfa - Builds: el árbol de talentos real del juego (toxic3000 / La Jauría). GPL-3.0.
--
-- Forever usa un árbol de C_Traits por clase (tres ramas, filas que piden
-- puntos en la rama y flechas). Aquí se lee el árbol vivo, se resuelven los
-- talentos de un build (por spellID, luego por el nombre en inglés de la foto
-- del motor y luego por el nombre en el idioma del cliente), se calcula el
-- avance y se aplica el plan comprando rangos y confirmando la configuración.
--
--   T.Leer() -> vivo | nil, razon     ("sinapi" | "sinconfig" | "sinarbol")
--   T.Resolver(build, vivo) -> res    { nodo = spell -> nodeID, faltan, recorte }
--   T.Estado(build, vivo, res) -> st  { hechos, total, siguiente, fuera, libres, gastados }
--   T.PlanCompra(build, vivo, res) -> plan { compras, pendientes, saltados }
--   T.Aplicar(plan, alTerminar) -> ok, razon
--   T.Disposicion(vivo) -> { specs, nodos, flechas } para dibujar
--   T.Actual() -> vivo (en caché, se renueva con los eventos de talentos)
--
-- Todas las llamadas al cliente pasan por pcall y por Compat.Readable: un
-- valor secreto se lee como desconocido. Nada de esto corre en combate.

local ADDON, M = ...
local A, L = M.A, M.L
local T = {}
M.Arbol = T

local type, pairs, ipairs, pcall, tonumber = type, pairs, ipairs, pcall, tonumber

local function R(v)
	if A.Compat and A.Compat.Readable then return A.Compat.Readable(v) end
	return v
end

local function llamar(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if ok then return a, b, c end
	return nil
end

-- La foto del árbol que trae el motor (Alfa/Talents/Builds.lua): filas,
-- columnas, flechas y nombres en inglés. Solo la clase del jugador.
local function foto()
	local Tal = A.Talents
	return Tal and Tal.Data and Tal.Data() or nil
end
T.Foto = foto

function T.Nombre(spell)
	if not spell then return nil end
	local n = C_Spell and C_Spell.GetSpellName and R(llamar(C_Spell.GetSpellName, spell))
	if not n and GetSpellInfo then n = R(llamar(GetSpellInfo, spell)) end
	return type(n) == "string" and n ~= "" and n or nil
end

function T.Icono(spell)
	return spell and A.Compat and A.Compat.SpellIcon and A.Compat.SpellIcon(spell) or nil
end

---------------------------------------------------------------------------
-- Lectura del árbol vivo
---------------------------------------------------------------------------

function T.Config()
	if not C_ClassTalents then return nil end
	local id = R(llamar(C_ClassTalents.GetActiveConfigID))
	return type(id) == "number" and id or nil
end

local function arbolDe(config)
	local info = C_Traits and llamar(C_Traits.GetConfigInfo, config)
	local tree = type(info) == "table" and type(info.treeIDs) == "table" and R(info.treeIDs[1]) or nil
	if type(tree) ~= "number" then
		local f = foto()
		tree = f and f.tree
	end
	return tree
end

-- Spell, nombre e ícono de una entrada del árbol.
local function entrada(config, entryID)
	local e = entryID and llamar(C_Traits.GetEntryInfo, config, entryID)
	local defID = type(e) == "table" and R(e.definitionID)
	local d = defID and llamar(C_Traits.GetDefinitionInfo, defID)
	if type(d) ~= "table" then return nil end
	local spell = R(d.spellID)
	local nombre = R(d.overrideName)
	if type(nombre) ~= "string" or nombre == "" then nombre = T.Nombre(spell) end
	local icono = R(d.overrideIcon) or T.Icono(spell)
	return spell, nombre, icono
end

-- Ramas: los grupos que el marco de talentos usa de cabecera de columna.
local function ramas(config, tree)
	local lista = llamar(C_Traits.GetGroupDisplayInfoByTreeID, tree)
	local out = {}
	if type(lista) ~= "table" then return out end
	for i, g in ipairs(lista) do
		out[#out + 1] = { grupo = R(g.groupID), nombre = R(g.displayName), orden = R(g.orderIndex) or i, gastado = 0 }
	end
	table.sort(out, function(a, b) return (a.orden or 0) < (b.orden or 0) end)
	local ids = {}
	for i, g in ipairs(out) do ids[i] = g.grupo end
	local gc = #ids > 0 and llamar(C_Traits.GetGroupCurrencyInfo, config, ids)
	if type(gc) == "table" then
		for _, g in ipairs(gc) do
			local c = type(g) == "table" and type(g.currencyInfos) == "table" and g.currencyInfos[1]
			local gid = type(g) == "table" and R(g.traitNodeGroupID)
			for _, s in ipairs(out) do
				if s.grupo == gid and type(c) == "table" then s.gastado = R(c.spent) or 0 end
			end
		end
	end
	return out
end

-- Puntos sin gastar y puntos ya gastados (moneda del árbol).
local function puntos(config, tree)
	local list = llamar(C_Traits.GetTreeCurrencyInfo, config, tree, false)
	if type(list) ~= "table" or not list[1] then return nil, nil end
	local libres, gastados = 0, 0
	for _, c in ipairs(list) do
		if type(c) == "table" then
			libres = libres + (R(c.quantity) or 0)
			gastados = gastados + (R(c.spent) or 0)
		end
	end
	return libres, gastados
end

local cache, cacheRazon

function T.Leer()
	if not (C_Traits and C_ClassTalents and C_Traits.GetTreeNodes) then return nil, "sinapi" end
	local config = T.Config()
	if not config then return nil, "sinconfig" end
	local tree = arbolDe(config)
	if not tree then return nil, "sinarbol" end
	local ids = llamar(C_Traits.GetTreeNodes, tree)
	if type(ids) ~= "table" or #ids == 0 then return nil, "sinarbol" end
	local specs = ramas(config, tree)
	local grupoSpec = {}
	for i, s in ipairs(specs) do if s.grupo then grupoSpec[s.grupo] = i end end
	local vivo = { config = config, tree = tree, nodos = {}, porSpell = {}, porNombre = {}, specs = specs }
	for _, raw in ipairs(ids) do
		local id = R(raw)
		local info = id and llamar(C_Traits.GetNodeInfo, config, id)
		if type(info) == "table" and R(info.ID) and R(info.ID) ~= 0 and R(info.isVisible) ~= false then
			local entryID = (type(info.activeEntry) == "table" and R(info.activeEntry.entryID))
				or (type(info.entryIDs) == "table" and R(info.entryIDs[1])) or nil
			local spell, nombre, icono = entrada(config, entryID)
			local spec
			if type(info.groupIDs) == "table" then
				for _, g in ipairs(info.groupIDs) do
					local s = grupoSpec[R(g)]
					if s then spec = s end
				end
			end
			local flechas = {}
			if type(info.visibleEdges) == "table" then
				for _, e in ipairs(info.visibleEdges) do
					local to = type(e) == "table" and R(e.targetNode)
					if to then flechas[#flechas + 1] = to end
				end
			end
			local n = {
				id = id, entry = entryID, spell = spell, nombre = nombre, icono = icono,
				max = R(info.maxRanks) or 0, activo = R(info.activeRank) or 0,
				actual = R(info.currentRank) or R(info.activeRank) or 0,
				compra = R(info.canPurchaseRank) and true or false,
				disponible = R(info.isAvailable) ~= false, flechaOk = R(info.meetsEdgeRequirements) ~= false,
				x = R(info.posX), y = R(info.posY), spec = spec, flechas = flechas,
			}
			vivo.nodos[id] = n
			if spell then
				local k = spell .. "#" .. n.max
				vivo.porSpell[spell] = vivo.porSpell[spell] == nil and id or false
				vivo.porSpell[k] = id
			end
			if nombre then vivo.porNombre[nombre] = vivo.porNombre[nombre] == nil and id or false end
		end
	end
	vivo.libres, vivo.gastados = puntos(config, tree)
	if vivo.libres == nil then
		-- Sin moneda legible: un punto por nivel desde el 10, menos lo gastado.
		local g = 0
		for _, n in pairs(vivo.nodos) do g = g + n.activo end
		local nivel = R(UnitLevel("player")) or 1
		vivo.gastados = g
		vivo.libres = math.max(0, math.max(0, nivel - 9) - g)
		vivo.estimado = true
	end
	vivo.cambiosPendientes = R(llamar(C_Traits.ConfigHasStagedChanges, config)) and true or false
	return vivo
end

-- El árbol vivo en caché; T.Invalidar() lo descarta (eventos de talentos).
function T.Actual()
	if cache == nil then
		local v, razon = T.Leer()
		cache, cacheRazon = v or false, razon
	end
	return cache or nil, cacheRazon
end

function T.Invalidar() cache, cacheRazon = nil, nil end

---------------------------------------------------------------------------
-- Resolver un build a los nodos vivos
---------------------------------------------------------------------------

-- Nodo de la foto por spell o por nombre en inglés.
local function enFoto(spell, nombre)
	local f = foto()
	if not f then return nil end
	for id, n in pairs(f.nodes) do
		if n.spell == spell then return id, n end
	end
	if nombre then
		for id, n in pairs(f.nodes) do
			if n.name == nombre then return id, n end
		end
	end
end

-- -> res = { nodo = { [spell] = nodeID }, faltan = { nombre... }, recorte = { [spell] = max } }
function T.Resolver(build, vivo)
	local res = { nodo = {}, faltan = {}, recorte = {}, porNodo = {} }
	if not (build and vivo) then return res end
	local vistos, maxPedido, nombreDe = {}, {}, {}
	for _, p in ipairs(build.picks) do
		maxPedido[p.spell] = math.max(maxPedido[p.spell] or 0, p.rank)
		nombreDe[p.spell] = nombreDe[p.spell] or p.nombre
	end
	for _, p in ipairs(build.picks) do
		local spell = p.spell
		if not vistos[spell] then
			vistos[spell] = true
			local id = vivo.porSpell[spell .. "#" .. (maxPedido[spell] or 0)] or vivo.porSpell[spell]
			if not id then
				local fid = enFoto(spell, nombreDe[spell])
				if fid and vivo.nodos[fid] then id = fid end
			end
			if not id then
				local local_ = T.Nombre(spell)
				local hit = local_ and vivo.porNombre[local_]
				if hit then id = hit end
			end
			if id then
				res.nodo[spell] = id
				res.porNodo[id] = spell
				local n = vivo.nodos[id]
				if n and n.max > 0 and n.max < (maxPedido[spell] or 0) then res.recorte[spell] = n.max end
			else
				res.faltan[#res.faltan + 1] = T.Nombre(spell) or nombreDe[spell] or tostring(spell)
			end
		end
	end
	res.ok = #res.faltan == 0
	return res
end

---------------------------------------------------------------------------
-- Avance del plan
---------------------------------------------------------------------------

-- st = { hechos, total, siguiente (pick), estadoPick = { [i] = "hecho"|"siguiente"|"pendiente"|"falta" },
--        fuera = { { nodo, rangos } }, libres, gastados, planeado = { [nodeID] = rango } }
function T.Estado(build, vivo, res)
	local st = { hechos = 0, total = build and build.total or 0, estadoPick = {}, fuera = {}, planeado = {} }
	if not (build and vivo and res) then return st end
	st.libres, st.gastados = vivo.libres or 0, vivo.gastados or 0
	for _, p in ipairs(build.picks) do
		local id = res.nodo[p.spell]
		if id then
			local tope = res.recorte[p.spell]
			local r = tope and math.min(p.rank, tope) or p.rank
			st.planeado[id] = math.max(st.planeado[id] or 0, r)
		end
	end
	for _, p in ipairs(build.picks) do
		local id = res.nodo[p.spell]
		local n = id and vivo.nodos[id]
		local tope = res.recorte[p.spell]
		if not n or (tope and p.rank > tope) then
			st.estadoPick[p.i] = "falta"
		elseif n.activo >= p.rank then
			st.estadoPick[p.i] = "hecho"
			st.hechos = st.hechos + 1
		elseif not st.siguiente then
			st.siguiente = p
			st.estadoPick[p.i] = "siguiente"
		else
			st.estadoPick[p.i] = "pendiente"
		end
	end
	for id, n in pairs(vivo.nodos) do
		local extra = n.activo - (st.planeado[id] or 0)
		if extra > 0 then st.fuera[#st.fuera + 1] = { nodo = id, rangos = extra, nombre = n.nombre } end
	end
	table.sort(st.fuera, function(a, b) return (a.nombre or "") < (b.nombre or "") end)
	return st
end

-- Lo que compraría "Aplicar": en orden, mientras haya puntos libres.
-- plan = { compras = { { nodo, rank, pick } }, pendientes (picks que esperan
--          más nivel), saltados = { pick } (no están en tu árbol), config }
function T.PlanCompra(build, vivo, res)
	local plan = { compras = {}, pendientes = 0, saltados = {}, config = vivo and vivo.config }
	if not (build and vivo and res) then return plan end
	local sim = {}
	for id, n in pairs(vivo.nodos) do sim[id] = n.activo end
	local libres = vivo.libres or 0
	for _, p in ipairs(build.picks) do
		local id = res.nodo[p.spell]
		local n = id and vivo.nodos[id]
		local tope = res.recorte[p.spell]
		if not n or (tope and p.rank > tope) then
			plan.saltados[#plan.saltados + 1] = p
		elseif (sim[id] or 0) < p.rank then
			if libres > 0 then
				plan.compras[#plan.compras + 1] = { nodo = id, rank = p.rank, pick = p, nombre = n.nombre or p.nombre }
				sim[id] = p.rank
				libres = libres - 1
			else
				plan.pendientes = plan.pendientes + 1
			end
		end
	end
	plan.sobran = libres
	return plan
end

---------------------------------------------------------------------------
-- Aplicar: comprar rangos y confirmar
---------------------------------------------------------------------------

T.RAZONES = {
	combate = L["Estás en combate. Los talentos solo se cambian fuera de combate: termina la pelea y vuelve a intentarlo."],
	sinapi = L["Tu cliente no deja cambiar talentos desde un addon. Usa la ventana de talentos del juego (tecla N)."],
	sinconfig = L["El juego todavía no cargó tus talentos. Espera unos segundos o abre la ventana de talentos (tecla N) una vez."],
	nada = L["No hay nada que comprar: o ya tienes todo lo del plan hasta tu nivel, o no tienes puntos libres."],
	bloqueado = L["El juego no deja cambiar talentos ahora mismo"],
	confirmar = L["El juego rechazó confirmar los cambios. Se deshicieron para que tu árbol quede como estaba."],
	nivel = L["Te faltan niveles: cada nivel desde el 10 te da un punto."],
	fila = L["Esa fila todavía no se abre: faltan puntos en esa rama."],
	flecha = L["Ese talento necesita antes otro talento completo (la flecha del árbol)."],
	puntos = L["No quedan puntos libres."],
	otro = L["El juego no dejó comprar ese rango."],
	-- 1.2.0: con la ventana del juego abierta, comprar desde Alfa haría correr
	-- sus avisos marcados por Alfa (lo mismo que bloqueaba el libro de hechizos).
	ventana = L["Cierra la ventana de talentos y hechizos del juego y vuelve a aplicar"],
	pendientes = L["Tienes cambios sin guardar en la ventana de talentos del juego: guárdalos o deshazlos ahí primero"],
}

-- La ventana de talentos del juego a la vista (en Forever es la misma del libro de hechizos).
local function ventanaDelJuego()
	for _, nombre in ipairs({ "PlayerSpellsFrame", "ClassTalentFrame", "PlayerTalentFrame" }) do
		local f = rawget(_G, nombre)
		if type(f) == "table" and f.IsShown and f:IsShown() then return true end
	end
	return false
end

-- La configuración guardada que el marco de talentos tiene elegida (si la
-- hay y sigue existiendo), como hace el botón Aplicar del juego.
local function guardadaElegida()
	if not (PlayerUtil and PlayerUtil.GetCurrentSpecID and C_ClassTalents.GetLastSelectedSavedConfigID) then return nil end
	local spec = R(llamar(PlayerUtil.GetCurrentSpecID))
	if type(spec) ~= "number" then return nil end
	local saved = R(llamar(C_ClassTalents.GetLastSelectedSavedConfigID, spec))
	if type(saved) ~= "number" then return nil end
	local lista = llamar(C_ClassTalents.GetConfigIDsBySpecID, spec)
	if type(lista) == "table" then
		for _, id in ipairs(lista) do if R(id) == saved then return saved end end
	end
	return nil
end

local function razonDeNodo(config, id)
	local info = llamar(C_Traits.GetNodeInfo, config, id)
	if type(info) ~= "table" then return "otro" end
	if R(info.isAvailable) == false then return "fila" end
	if R(info.meetsEdgeRequirements) == false then return "flecha" end
	if R(info.canPurchaseRank) == false then return "puntos" end
	return "otro"
end

local pendiente -- { config, alTerminar, compradas }

-- Antes de comprar: ¿se puede editar ahora? -> ok, razon, texto del juego
function T.PuedeEditar(config)
	if InCombatLockdown() then return false, "combate" end
	if not (C_Traits and C_Traits.PurchaseRank and (C_ClassTalents.CommitConfig or C_Traits.CommitConfig)) then return false, "sinapi" end
	if not config then return false, "sinconfig" end
	if ventanaDelJuego() then return false, "ventana" end
	-- Lo que tú cambiaste en la ventana del juego y no guardaste no se borra (1.2.0).
	if C_Traits.ConfigHasStagedChanges and R(llamar(C_Traits.ConfigHasStagedChanges, config)) then return false, "pendientes" end
	if C_ClassTalents.CanEditTalents then
		local ok, puede, err = pcall(C_ClassTalents.CanEditTalents)
		if ok and R(puede) == false then return false, "bloqueado", R(err) end
	end
	if C_Traits.CanEditConfig then
		local ok, puede, err = pcall(C_Traits.CanEditConfig, config)
		if ok and R(puede) == false then return false, "bloqueado", R(err) end
	end
	return true
end

-- alTerminar(ok, resumen) llega cuando el juego confirma o rechaza.
-- resumen = { compradas = n, fallos = { { compra, razon } } }
function T.Aplicar(plan, alTerminar)
	local config = plan and plan.config
	local puede, razon, textoJuego = T.PuedeEditar(config)
	if not puede then return false, razon, textoJuego end
	if #plan.compras == 0 then return false, "nada" end
	local resumen = { compradas = 0, fallos = {} }
	local fallado = {}
	for _, c in ipairs(plan.compras) do
		if fallado[c.nodo] then
			resumen.fallos[#resumen.fallos + 1] = { compra = c, razon = fallado[c.nodo] }
		else
			local ok, bien = pcall(C_Traits.PurchaseRank, config, c.nodo)
			if ok and R(bien) then
				resumen.compradas = resumen.compradas + 1
			else
				local r = razonDeNodo(config, c.nodo)
				fallado[c.nodo] = r
				resumen.fallos[#resumen.fallos + 1] = { compra = c, razon = r }
			end
		end
	end
	if resumen.compradas == 0 then
		llamar(C_Traits.RollbackConfig, config)
		return false, (resumen.fallos[1] and resumen.fallos[1].razon) or "otro", nil, resumen
	end
	local ok, bien
	if C_ClassTalents.CommitConfig then
		ok, bien = pcall(C_ClassTalents.CommitConfig, guardadaElegida())
	end
	if not (ok and R(bien)) and C_Traits.CommitConfig then
		ok, bien = pcall(C_Traits.CommitConfig, config)
	end
	if not (ok and R(bien)) then
		llamar(C_Traits.RollbackConfig, config)
		return false, "confirmar", nil, resumen
	end
	pendiente = { config = config, alTerminar = alTerminar, resumen = resumen }
	-- Si el juego no avisa en 6 s, se da por hecho y se vuelve a leer.
	A.After(6, function()
		if pendiente and pendiente.config == config then
			local p = pendiente
			pendiente = nil
			T.Invalidar()
			if p.alTerminar then p.alTerminar(true, p.resumen) end
		end
	end)
	return true, nil, nil, resumen
end

function T.OnConfigActualizada(_, configID)
	T.Invalidar()
	local p = pendiente
	if p and (R(configID) == nil or R(configID) == p.config) then
		pendiente = nil
		if p.alTerminar then p.alTerminar(true, p.resumen) end
	end
end

function T.OnConfirmacionFallida(_, configID)
	T.Invalidar()
	local p = pendiente
	if p and (R(configID) == nil or R(configID) == p.config) then
		pendiente = nil
		if p.alTerminar then p.alTerminar(false, p.resumen) end
	end
end

---------------------------------------------------------------------------
-- Disposición para dibujar el árbol
---------------------------------------------------------------------------

-- El nombre de la rama i en tu idioma (Builds/<Clase>.lua): la foto del motor
-- los trae en inglés ("Arms", "Feral Combat").
local function nombreRama(i)
	local dc = M.DatosClase and M.DatosClase()
	for _, sp in pairs(dc and dc.especialidades or {}) do
		if sp.indice == i then return sp.nombre end
	end
	return nil
end
T.NombreRama = nombreRama

-- -> { specs = { { nombre, gastado } }, nodos = { { id, spec, fila, col, spell, nombre, icono, max, activo } },
--      flechas = { { de, a } }, filas, columnas }
-- Filas y columnas de la foto del motor; un nodo vivo que la foto no tiene
-- toma la fila de un nodo conocido a la misma altura (posY) y la columna de
-- uno a la misma posX, o la más cercana.
function T.Disposicion(vivo)
	local f = foto()
	local d = { specs = {}, nodos = {}, flechas = {}, filas = 7, columnas = 4 }
	local nombresSpec = f and f.specs or {}
	if vivo then
		for i, s in ipairs(vivo.specs) do d.specs[i] = { nombre = s.nombre or nombreRama(i) or nombresSpec[i], gastado = s.gastado or 0 } end
	end
	for i, nom in ipairs(nombresSpec) do
		if not d.specs[i] then d.specs[i] = { nombre = nombreRama(i) or nom, gastado = 0 } end
	end
	local filaY, colX = {}, {}
	local puestos = {}
	local function agregar(n)
		d.nodos[#d.nodos + 1] = n
		puestos[n.id] = n
		if n.fila > d.filas then d.filas = n.fila end
		if n.col > d.columnas then d.columnas = n.col end
	end
	if vivo then
		local sinFoto = {}
		for id, n in pairs(vivo.nodos) do
			local fn = f and f.nodes[id]
			if fn and n.spec == nil then n.spec = fn.spec end
			if fn then
				agregar({ id = id, spec = n.spec or fn.spec, fila = fn.row, col = fn.col, spell = n.spell or fn.spell,
					nombre = n.nombre or T.Nombre(n.spell or fn.spell) or fn.name, icono = n.icono, max = n.max, activo = n.activo })
				local s = n.spec or fn.spec
				if n.y then filaY[s .. ":" .. n.y] = fn.row end
				if n.x then colX[s .. ":" .. n.x] = fn.col end
			elseif n.spec and n.x and n.y then
				sinFoto[#sinFoto + 1] = n
			end
		end
		for _, n in ipairs(sinFoto) do
			local fila = filaY[n.spec .. ":" .. n.y]
			local col = colX[n.spec .. ":" .. n.x]
			if not (fila and col) then
				-- La más cercana por posición entre los nodos de su rama.
				local bestF, dF, bestC, dC
				for _, m in ipairs(d.nodos) do
					local v = vivo.nodos[m.id]
					if m.spec == n.spec and v and v.x and v.y then
						local dy, dx = math.abs(v.y - n.y), math.abs(v.x - n.x)
						if not dF or dy < dF then bestF, dF = m.fila, dy end
						if not dC or dx < dC then bestC, dC = m.col, dx end
					end
				end
				fila, col = fila or bestF or 1, col or bestC or 1
			end
			agregar({ id = n.id, spec = n.spec, fila = fila, col = col, spell = n.spell, nombre = n.nombre,
				icono = n.icono, max = n.max, activo = n.activo })
		end
		for id, n in pairs(vivo.nodos) do
			for _, to in ipairs(n.flechas or {}) do
				if puestos[id] and puestos[to] then d.flechas[#d.flechas + 1] = { de = id, a = to } end
			end
		end
	end
	if #d.nodos == 0 and f then
		for id, fn in pairs(f.nodes) do
			agregar({ id = id, spec = fn.spec, fila = fn.row, col = fn.col, spell = fn.spell, nombre = T.Nombre(fn.spell) or fn.name, max = fn.max, activo = 0 })
		end
	end
	if #d.flechas == 0 and f then
		for _, e in ipairs(f.edges or {}) do
			if puestos[e[1]] and puestos[e[2]] then d.flechas[#d.flechas + 1] = { de = e[1], a = e[2] } end
		end
	end
	return d
end

-- Un nodo de la foto o vivo por id (para resolver sin el árbol vivo).
function T.NodoFoto(id)
	local f = foto()
	return f and f.nodes[id]
end

-- Sin árbol vivo (pantalla de carga, cliente sin C_Traits): se resuelve
-- contra la foto del motor para poder dibujar el plan.
function T.VivoDeFoto()
	local f = foto()
	if not f then return nil end
	local vivo = { config = nil, tree = f.tree, nodos = {}, porSpell = {}, porNombre = {}, specs = {}, libres = 0, gastados = 0, foto = true }
	for i, nom in ipairs(f.specs or {}) do vivo.specs[i] = { nombre = nombreRama(i) or nom, gastado = 0 } end
	for id, fn in pairs(f.nodes) do
		vivo.nodos[id] = { id = id, spell = fn.spell, nombre = T.Nombre(fn.spell) or fn.name, max = fn.max, activo = 0, actual = 0, spec = fn.spec, flechas = {} }
		vivo.porSpell[fn.spell] = id
		vivo.porSpell[fn.spell .. "#" .. fn.max] = id
	end
	for _, e in ipairs(f.edges or {}) do
		local n = vivo.nodos[e[1]]
		if n then n.flechas[#n.flechas + 1] = e[2] end
	end
	return vivo
end
