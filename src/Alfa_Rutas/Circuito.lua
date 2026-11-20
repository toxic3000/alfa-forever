-- Alfa - Rutas: el circuito de la zona (toxic3000 / La Jauría). GPL-3.0.
-- 1.3.0
--
-- Todas las misiones de la zona donde estás, en el mejor orden: las que
-- llevas (lo que falta y su entrega) y las que puedes tomar aquí (tomarla,
-- hacerla y entregarla). Cada misión va en orden (tomar antes de hacer,
-- hacer antes de entregar, y una que pide otra después de esa); el orden de
-- todo junto sale del vecino más cercano y se mejora con 2-opt (dar vuelta
-- un tramo si el camino queda más corto sin romper ese orden), midiendo en
-- yardas del mundo (Compat.MapToWorld). Se instala como guía del motor
-- («Circuito de <zona>», Guias.IdEspecial("circuito")): el rastreador la
-- muestra y la flecha la lleva, paso por paso. Ajuste rutas.circuito.
--
--   Circuito.Ordenar(paradas, desde, ceder?) -> orden   (paradas de Plan.PasosDe)
--   Circuito.Costo(orden, paradas, desde) -> yardas
--   Circuito.Armar(alTerminar(def | nil, motivo, n))
--   Circuito.Ahora()                arma, instala y abre la guía

local ADDON, M = ...
local A, L = M.A, M.L
local I = M.Indice
local Ci = {}
M.Circuito = Ci

A.RegisterDefaults(M.ID, { circuito = true })

local type, ipairs, pairs, tonumber = type, ipairs, pairs, tonumber
local sqrt, floor, format = math.sqrt, math.floor, string.format

local OTRO = 1e6       -- yardas: otro continente o sin medida
local MAX_TOMAR = 12   -- misiones nuevas que entran como mucho
local MAX_PASADAS = 6  -- vueltas de 2-opt

local function CP() return M.Motor("Compat") end
local function CX() return M.Motor("Codex") end
local function enCombate() return InCombatLockdown and InCombatLockdown() or false end
local function encendido() return A.Get(M.ID .. ".circuito") ~= false end

local function mundo(p)
	local Cp = CP()
	if not (p and p.map and p.x and p.y and Cp and Cp.MapToWorld) then return nil end
	local ok, c, wx, wy = pcall(Cp.MapToWorld, p.map, p.x, p.y, p.f)
	if ok and c and type(wx) == "number" and type(wy) == "number" then return { c = c, wx = wx, wy = wy } end
	return nil
end

local function yardas(a, b)
	if not (a and b) or a.c ~= b.c then return OTRO end
	local dx, dy = a.wx - b.wx, a.wy - b.wy
	return sqrt(dx * dx + dy * dy)
end

---------------------------------------------------------------------------
-- El orden: vecino más cercano y 2-opt con las reglas de cada misión
---------------------------------------------------------------------------

function Ci.Costo(orden, paradas, desde)
	local aqui, total = desde, 0
	for _, i in ipairs(orden) do
		local s = paradas[i]
		if aqui then total = total + yardas(aqui, s.wIn) end
		aqui = s.wOut
	end
	return total
end

local function valido(orden, paradas)
	local pos = {}
	for k, i in ipairs(orden) do pos[i] = k end
	for k, i in ipairs(orden) do
		for _, d in ipairs(paradas[i].deps or {}) do
			if pos[d] and pos[d] > k then return false end
		end
	end
	return true
end
Ci.Valido = valido

-- ceder (1.3.2, opcional): el de la tarea (Tareas.lua). El 2-opt hace
-- muchas cuentas con el registro lleno: sin ceder, un tirón al armarlo.
function Ci.Ordenar(paradas, desde, ceder)
	ceder = ceder or function() end
	if #paradas == 0 then return {} end
	for _, s in ipairs(paradas) do
		s.wIn = s.wIn or mundo(s.inP)
		s.wOut = s.wOut or mundo(s.outP) or s.wIn
	end
	local w0 = desde and (desde.c and desde or mundo(desde)) or nil
	-- Vecino más cercano entre las que ya se pueden.
	local orden, hechas, aqui = {}, {}, w0
	for _ = 1, #paradas do
		local bi, bc
		ceder()
		for i, s in ipairs(paradas) do
			if not hechas[i] then
				local lista = true
				for _, d in ipairs(s.deps or {}) do if not hechas[d] then lista = false break end end
				if lista then
					local c = aqui and yardas(aqui, s.wIn) or 0
					if not bc or c < bc then bi, bc = i, c end
				end
			end
		end
		if not bi then break end
		hechas[bi] = true
		orden[#orden + 1] = bi
		aqui = paradas[bi].wOut
	end
	-- Lo que quedó fuera (dependencias raras): al final, tal cual.
	for i = 1, #paradas do if not hechas[i] then orden[#orden + 1] = i end end
	-- 2-opt: dar vuelta el tramo i..j si acorta y no rompe el orden.
	local mejor = Ci.Costo(orden, paradas, w0)
	local n = #orden
	for _ = 1, MAX_PASADAS do
		local cambio = false
		for i = 1, n - 1 do
			ceder()
			for j = i + 1, n do
				local prueba = {}
				for k = 1, i - 1 do prueba[k] = orden[k] end
				for k = i, j do prueba[k] = orden[j - (k - i)] end
				for k = j + 1, n do prueba[k] = orden[k] end
				if valido(prueba, paradas) then
					local c = Ci.Costo(prueba, paradas, w0)
					if c + 0.5 < mejor then orden, mejor, cambio = prueba, c, true end
				end
			end
		end
		if not cambio then break end
	end
	return orden
end

---------------------------------------------------------------------------
-- Las misiones de la zona
---------------------------------------------------------------------------

local function enMapa(p, map) return p and p.map == map end

local function partes(idx, desde, ceder)
	local Cp, C = CP(), CX()
	local map = desde.map
	local out, usadas = {}, {}
	-- Las que llevas: lo que falta o su entrega, aquí.
	for _, qid in ipairs(Cp.GetLogQuests and Cp.GetLogQuests() or {}) do
		local q = C.Quest(qid)
		local pm = q and I.PasosMision(q, desde)
		if pm and not pm.dentro then
			pm.q = q
			pm.listo = Cp.IsQuestReadyForTurnIn and Cp.IsQuestReadyForTurnIn(qid) or false
			local aqui = enMapa(pm.fin, map) or (not pm.listo and enMapa(pm.objetivo, map))
			if aqui then
				out[#out + 1] = pm
				usadas[qid] = true
			end
		end
		ceder()
	end
	-- Las que puedes tomar aquí: las más cerca primero.
	if idx then
		local p = I.Jugador()
		local nivel = p.level
		local techo = nivel + M.num(A.Get(M.ID .. ".margen"), 2)
		local evitar = A.Get(M.ID .. ".evitarGrupo") ~= false
		local nuevas = {}
		for k, e in ipairs(idx.lista) do
			if not usadas[e.id] and e.lvl <= techo and e.lvl >= nivel - 5 and I.Disponible(e, {}, nivel) and not I.EnRegistro(e.id) then
				local dador = I.Puntos(e, desde, p)
				if enMapa(dador, map) then nuevas[#nuevas + 1] = { e = e, d = yardas(mundo(desde), mundo(dador)) } end
			end
			if k % 25 == 0 then ceder() end
		end
		table.sort(nuevas, function(a, b) return a.d < b.d end)
		local n = 0
		for _, c in ipairs(nuevas) do
			if n >= MAX_TOMAR then break end
			local q = C.Quest(c.e.id)
			local pm = q and I.PasosMision(q, desde)
			if pm and not pm.dentro and not (evitar and pm.grupo) and pm.aceptar and enMapa(pm.fin, map) then
				pm.q = q
				out[#out + 1] = pm
				n = n + 1
			end
			ceder()
		end
	end
	return out
end
Ci.Partes = partes

function Ci.Armar(alTerminar)
	if not encendido() then return alTerminar(nil, "apagado") end
	if enCombate() then return alTerminar(nil, "combat") end
	local desde = A.PlayerPoint and A.PlayerPoint() or nil
	if not (desde and desde.map) then return alTerminar(nil, "lugar") end
	local ok, motivo = I.CodexListo()
	if not ok then return alTerminar(nil, motivo) end
	I.Pedir(function(idx)
		M.Tareas.Lanzar("circuito:armar", function(ceder)
			local lista = partes(idx, desde, ceder)
			if #lista == 0 then return { n = 0 } end
			local pasos = M.Plan.PasosDe(lista, desde, nil, function(paradas, d) return Ci.Ordenar(paradas, d, ceder) end)
			return { pasos = pasos, n = #lista }
		end, function(res)
			if not (res and res.pasos and #res.pasos > 0) then return alTerminar(nil, "vacio", 0) end
			local zona = M.Zona(desde.map) or L["tu zona"]
			M.Plan.Anotar(res.pasos[1], format(res.n == 1 and L["%d misión de %s en el mejor orden: tomarla, hacerla y entregarla."]
				or L["%d misiones de %s en el mejor orden: tomarlas, hacerlas y entregarlas."], res.n, zona))
			local def = M.Guias.Def(M.Guias.IdEspecial("circuito"), format(L["Circuito de %s"], zona), res.pasos, {
				zone = desde.map, pitch = L["Todas las misiones de la zona en el mejor orden."],
			})
			alTerminar(def, nil, res.n)
		end)
	end)
end

function Ci.Ahora()
	if enCombate() then
		M.Aviso(L["Circuito de la zona"], L["Se puede al salir de combate."], { icono = "ic-aviso", tono = "aviso" })
		return false
	end
	M.Aviso(L["Armando el circuito de la zona..."], L["Alfa junta tus misiones y las de aquí y busca el camino más corto."], { icono = "ic-ruta" })
	Ci.Armar(function(def, motivo, n)
		if not def then
			local texto = (motivo == "vacio") and L["No hay misiones para ti en esta zona."]
				or (motivo == "lugar" and L["No sé en qué zona estás."]) or I.TextoMotivo(motivo)
			M.Aviso(L["No armé el circuito"], texto, { icono = "ic-aviso", tono = "aviso" })
			return
		end
		M.Guias.Olvidar(def.id)
		if not M.Guias.Instalar(def) then
			M.Aviso(L["No armé el circuito"], L["El motor no aceptó la guía."], { icono = "ic-aviso", tono = "aviso" })
			return
		end
		local i, por = M.Guias.Abrir(def.id)
		if i then
			M.Aviso(def.title, format(n == 1 and L["%d misión: sigue la flecha."] or L["%d misiones: sigue la flecha."], n), { lobo = "aullando" })
		elseif por == "tabs" then
			M.Aviso(L["Tienes 6 guías abiertas"], L["Cierra una pestaña para abrir tu plan."], { icono = "ic-aviso", tono = "aviso" })
		end
		M.Avisar("SEGUIR", "circuito")
	end)
	return true
end
