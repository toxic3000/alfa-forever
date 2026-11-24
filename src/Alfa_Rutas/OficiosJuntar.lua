-- Alfa - Rutas: las guías de oficios de recolección (Minería, Herboristería,
-- Desuello). toxic3000 / La Jauría. GPL-3.0. 1.3.9.
--
-- Minería y Herboristería, con los nodos de Recolección (GatherLite): cada
-- tramo se parte donde aparece un recurso nuevo y donde se aprende un rango;
-- en cada parte, los nodos que te dan puntos (naranja o amarillo, si no hay,
-- verdes), la mejor zona para tu facción y tu nivel (AlfaRecoleccion.Zonas:
-- puntos y densidad) y una vuelta por sus lugares con más nodos. Las partes
-- seguidas con la misma zona se juntan en un solo paso.
-- Desuello (y las otras dos si Recolección no está): las zonas de bestias de
-- la guía del motor que son para ti, con su vuelta.
-- Los instructores de cada rango y la herramienta salen de la guía del motor.

local ADDON, M = ...
local A, L, N = M.A, M.L, M.N
local D = M.OficiosDatos
local J = {}
M.OficiosJuntar = J

local ipairs, pairs, type, floor, max, min, format, concat = ipairs, pairs, type, math.floor, math.max, math.min, string.format, table.concat
local sqrt = math.sqrt

local PUNTOS_RUTA = 12  -- lugares de la vuelta
local CELDA = 0.07      -- tamaño de un lugar (del mapa, 0-1)

local function Of() return M.OficiosGuia end

-- Los colores de un nodo: mínimo, amarillo, verde, gris.
local function colores(gr)
	local n = gr.niveles or {}
	local a = n[1] or 1
	return a, n[2] or a + 25, n[3] or a + 50, n[4] or a + 100
end

-- Cuánto vale un nodo con habilidad h: naranja 1, amarillo 0,8, verde 0,3, gris 0.
local function valor(gr, h)
	local a, y, g, gris = colores(gr)
	if h < a then return 0 end
	if h < y then return 1 end
	if h < g then return 0.8 end
	if h < gris then return 0.3 end
	return 0
end
J.Valor = valor

local function datosRecoleccion()
	local AR = rawget(_G, "AlfaRecoleccion")
	if type(AR) ~= "table" or type(AR.Datos) ~= "function" or type(AR.Zonas) ~= "function" then return nil end
	local ok, d = pcall(AR.Datos)
	if not ok or type(d) ~= "table" or type(d.grupos) ~= "table" or type(d.base) ~= "table" then return nil end
	d.api = AR
	return d
end

-- Los nodos clásicos (con sus cuatro colores) de un tipo.
local function grupos(d, tipo)
	local out = {}
	for _, gr in ipairs(d.grupos) do
		if gr.tipo == tipo and type(gr.niveles) == "table" and #gr.niveles == 4 and gr.niveles[1] < 300 then out[#out + 1] = gr end
	end
	return out
end

-- La vuelta por los lugares con más nodos de esas claves en la zona.
local function vuelta(d, claves, mapa)
	local celdas, lista = {}, {}
	for _, gr in ipairs(d.grupos) do
		if claves[gr.clave] then
			for _, oid in ipairs(gr.ids) do
				local xy = d.base[oid] and d.base[oid][mapa]
				if type(xy) == "string" and d.puntosDe then xy = d.puntosDe(xy) end
				if type(xy) == "table" then
					for i = 1, #xy - 1, 2 do
						local x, y = xy[i], xy[i + 1]
						local k = floor(x / CELDA) * 1000 + floor(y / CELDA)
						local c = celdas[k]
						if not c then
							c = { x = 0, y = 0, n = 0, por = {} }
							celdas[k] = c
							lista[#lista + 1] = c
						end
						c.x, c.y, c.n = c.x + x, c.y + y, c.n + 1
						c.por[gr.clave] = (c.por[gr.clave] or 0) + 1
					end
				end
			end
		end
	end
	table.sort(lista, function(a, b) return a.n > b.n end)
	local elegidos = {}
	for i = 1, min(PUNTOS_RUTA, #lista) do
		local c = lista[i]
		c.x, c.y = c.x / c.n, c.y / c.n
		local mejor, mn = nil, 0
		for clave, n in pairs(c.por) do if n > mn or (n == mn and clave < mejor) then mejor, mn = clave, n end end
		c.clave = mejor
		elegidos[#elegidos + 1] = c
	end
	-- Vecino más cercano desde el lugar con más nodos: una vuelta corta.
	local orden, usado = {}, {}
	if #elegidos > 0 then
		orden[1], usado[1] = elegidos[1], true
		for _ = 2, #elegidos do
			local ult = orden[#orden]
			local j, dmin = nil, math.huge
			for k, c in ipairs(elegidos) do
				if not usado[k] then
					local dx, dy = c.x - ult.x, c.y - ult.y
					local dd = dx * dx + dy * dy
					if dd < dmin then j, dmin = k, dd end
				end
			end
			usado[j] = true
			orden[#orden + 1] = elegidos[j]
		end
	end
	local total = 0
	for _, c in ipairs(lista) do total = total + c.n end
	return orden, total
end
J.Vuelta = vuelta

local function nombreNodo(d, gr)
	local idx
	for i, g in ipairs(d.grupos) do if g == gr then idx = i break end end
	if idx and type(d.nombre) == "function" then
		local ok, n = pcall(d.nombre, idx)
		if ok and type(n) == "string" then return n end
	end
	return N.espanol and gr.es or gr.en
end

-- Los cortes de los tramos: inicio, rangos, recursos nuevos, fin.
local function cortes(lista)
	local c, visto = {}, {}
	local function poner(v)
		if v >= 1 and v <= 300 and not visto[v] then visto[v] = true c[#c + 1] = v end
	end
	poner(1)
	for _, t in ipairs(D.TRAMOS) do poner(t[2]) end
	for _, v in ipairs(D.CORTES_RANGO) do poner(v) end
	for _, gr in ipairs(lista) do poner(gr.niveles[1]) end
	table.sort(c)
	return c
end

-- Nodos esperados de a a b (un punto por nodo naranja, menos en amarillo y verde).
local function nodosEsperados(lista, a, b)
	local n = 0
	for h = a, b - 1 do
		local v = 0
		for _, gr in ipairs(lista) do v = max(v, valor(gr, h)) end
		n = n + (v > 0 and 1 / v or 1)
	end
	return floor(n * 1.15 + 0.5)
end

local function textoColores(d, gr)
	local _, y, g, gris = colores(gr)
	return format(L["%s (naranja hasta %d, amarillo hasta %d, verde hasta %d)"], nombreNodo(d, gr), y, g, gris)
end

---------------------------------------------------------------------------
-- Con Recolección: zonas y vueltas propias
---------------------------------------------------------------------------

local function conRecoleccion(ctx, d)
	local Ofi = Of()
	local o = ctx.of
	local lista = grupos(d, o.recurso)
	if #lista == 0 then return false end
	local c = cortes(lista)
	-- Las partes finas, cada una con su zona.
	local partes = {}
	for i = 1, #c - 1 do
		local a, b = c[i], c[i + 1]
		local mid = (a + b) / 2
		local buenos, verdes = {}, {}
		for _, gr in ipairs(lista) do
			if gr.niveles[1] <= a then
				local v = valor(gr, mid)
				if v >= 0.8 then buenos[#buenos + 1] = gr elseif v > 0 then verdes[#verdes + 1] = gr end
			end
		end
		local usar = #buenos > 0 and buenos or verdes
		if #usar > 0 then
			local claves = {}
			for _, gr in ipairs(usar) do claves[#claves + 1] = gr.clave end
			local ok, zonas = pcall(d.api.Zonas, { claves = claves, nivel = ctx.nivel, faccion = ctx.fac })
			local z = ok and type(zonas) == "table" and zonas[1] or nil
			if z then
				partes[#partes + 1] = { a = a, b = b, grupos = usar, claves = claves, zona = z, otra = zonas[2], tramo = Ofi.Tramo(a) }
			end
		end
	end
	if #partes == 0 then return false end
	-- Juntar las seguidas con la misma zona dentro del mismo tramo (sin pasar un rango).
	local rangoEn = {}
	for r, rg in ipairs(D.RANGOS) do if r > 1 then rangoEn[rg.desde] = r end end
	local juntas = {}
	for _, p in ipairs(partes) do
		local u = juntas[#juntas]
		if u and u.zona.mapa == p.zona.mapa and u.tramo == p.tramo and u.b == p.a and not rangoEn[p.a] then
			u.b = p.b
			local hay = {}
			for _, gr in ipairs(u.grupos) do hay[gr] = true end
			for _, gr in ipairs(p.grupos) do if not hay[gr] then u.grupos[#u.grupos + 1] = gr u.claves[#u.claves + 1] = gr.clave end end
		else
			juntas[#juntas + 1] = p
		end
	end
	-- Los pasos.
	local herramienta = o.herramienta and ctx.compras[o.herramienta]
	local extra = {}
	if herramienta then extra[1] = Ofi.Copiar(ctx, herramienta, { count = 1 }) end
	local r1 = Ofi.PasoRango(ctx, 1, extra)
	local notas = { r1.note }
	if o.herramienta then notas[#notas + 1] = format(L["Necesitas %s en tus bolsas: sin ella no puedes."], Ofi.Tok(ctx, "item", o.herramienta)) end
	if o.buscar then notas[#notas + 1] = format(L["Enciende %s (libro de hechizos, pestaña General) para ver los nodos en el minimapa."], Ofi.Tok(ctx, "spell", o.buscar)) end
	r1.note = concat(notas, " ")
	for _, p in ipairs(juntas) do
		local r = rangoEn[p.a]
		if r then Ofi.PasoRango(ctx, r) end
		local set = {}
		for _, k in ipairs(p.claves) do set[k] = true end
		local orden = vuelta(d, set, p.zona.mapa)
		local metas = {}
		local principal = p.grupos[1]
		for _, cel in ipairs(orden) do
			local gr
			for _, g in ipairs(p.grupos) do if g.clave == cel.clave then gr = g end end
			metas[#metas + 1] = { t = "goto", text = nombreNodo(d, gr or principal), map = p.zona.mapa,
				x = floor(cel.x * 1000 + 0.5) / 10, y = floor(cel.y * 1000 + 0.5) / 10, r = 30 }
		end
		metas[#metas + 1] = Ofi.MetaHabilidad(ctx, p.b)
		local nombres = {}
		for _, gr in ipairs(p.grupos) do nombres[#nombres + 1] = textoColores(d, gr) end
		local lineas = {
			format(L["Dan puntos aquí: %s."], concat(nombres, "; ")),
			format(L["Da la vuelta por los %d lugares y recoge todo lo que veas hasta %s %d: cuenta con unos %d nodos."], #orden, ctx.skillTok, p.b, nodosEsperados(p.grupos, p.a, p.b)),
		}
		local motivo = d.api.Motivo and d.api.Motivo(p.zona, { claves = p.claves })
		if type(motivo) == "string" then lineas[#lineas + 1] = motivo end
		if o.forja then lineas[#lineas + 1] = L["Cuando se llenen tus bolsas, funde en una forja: también sube Minería."] end
		if p.otra and p.otra.mapa ~= p.zona.mapa then lineas[#lineas + 1] = format(L["Otra buena opción: %s."], Ofi.Tok(ctx, "zone", p.otra.mapa)) end
		Ofi.Paso(ctx, p.tramo, format(L["%s hasta %d"], nombreNodo(d, principal), p.b), concat(lineas, "\n"), metas, p.b)
	end
	return true
end

---------------------------------------------------------------------------
-- Con la guía del motor (Desuello, o sin Recolección)
---------------------------------------------------------------------------

local function conMotor(ctx)
	local Ofi = Of()
	local o = ctx.of
	local herramienta = o.herramienta and ctx.compras[o.herramienta]
	local extra = {}
	if herramienta then extra[1] = Ofi.Copiar(ctx, herramienta, { count = 1 }) end
	local r1 = Ofi.PasoRango(ctx, 1, extra)
	if o.herramienta then r1.note = r1.note .. " " .. format(L["Necesitas %s en tus bolsas: sin ella no puedes."], Ofi.Tok(ctx, "item", o.herramienta)) end
	local rangoEn = {}
	for r, rg in ipairs(D.RANGOS) do if r > 1 then rangoEn[rg.desde] = r end end
	local hechos = {}
	local desde = 1
	local hay = false
	for _, s in ipairs(ctx.pasosMotor) do
		local hasta, mapa
		local metas = {}
		for _, g in ipairs(s.goals or {}) do
			if g.t == "skill" and type(g.level) == "number" then hasta = g.level end
			if g.t == "goto" then metas[#metas + 1] = Ofi.Copiar(ctx, g) mapa = mapa or g.map end
		end
		if hasta and mapa and hasta > desde then
			for v = desde, hasta - 1 do
				local r = rangoEn[v]
				if r and not hechos[r] then hechos[r] = true Ofi.PasoRango(ctx, r) end
			end
			metas[#metas + 1] = Ofi.MetaHabilidad(ctx, hasta)
			local zonaTok = Ofi.Tok(ctx, "zone", mapa)
			local lineas = {}
			if o.clave == "desuello" then
				local nv = D.NivelDesollar(desde)
				local bajo = max(1, nv - 5)
				local cueros = {}
				for _, it in ipairs(D.CUEROS[Ofi.Tramo(desde)] or {}) do cueros[#cueros + 1] = Ofi.Tok(ctx, "item", it) end
				lineas[1] = format(L["Con %d puedes desollar bestias hasta nivel %d: las de nivel %d a %d te dan más puntos."], desde, nv, bajo, nv)
				lineas[2] = L["Mata y desuella toda bestia con piel de tu camino: cada desuello en naranja o amarillo es un punto."]
				if #cueros > 0 then lineas[3] = format(L["Sale: %s."], concat(cueros, ", ")) end
				Ofi.Paso(ctx, Ofi.Tramo(hasta - 1), format(L["Bestias hasta %d"], hasta), concat(lineas, "\n"), metas, hasta)
			else
				lineas[1] = format(L["Da la vuelta por los puntos y recoge todo lo que veas hasta %s %d."], ctx.skillTok, hasta)
				if o.forja then lineas[2] = L["Cuando se llenen tus bolsas, funde en una forja: también sube Minería."] end
				Ofi.Paso(ctx, Ofi.Tramo(hasta - 1), format(L["%s hasta %d"], zonaTok, hasta), concat(lineas, "\n"), metas, hasta)
			end
			hay = true
			desde = hasta
		end
	end
	return hay
end

function J.Armar(ctx)
	local d = ctx.of.recurso and datosRecoleccion()
	if d and conRecoleccion(ctx, d) then return true end
	ctx.steps = {}
	return conMotor(ctx)
end
