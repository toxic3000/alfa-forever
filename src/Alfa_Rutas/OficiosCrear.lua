-- Alfa - Rutas: las guías de oficios de fabricación (Herrería, Alquimia,
-- Sastrería, Peletería, Ingeniería, Encantamiento, Cocina y Primeros
-- auxilios). toxic3000 / La Jauría. GPL-3.0. 1.3.9.
--
-- Las recetas salen de la guía del motor de cada oficio (la más barata que
-- sigue en naranja o amarillo, en su orden, con sus colores y reactivos); se
-- reacomodan en los cuatro tramos y cada tramo empieza con:
--   * el instructor del rango (cuando ya puedes aprenderlo);
--   * «Tus materiales para 75–150»: cuántos de cada uno, lo que ya tienes
--     aquí, lo que tienen tus otros personajes (mándalo por correo), cuántos
--     te faltan, de dónde salen y lo que cuestan en la subasta; las metas de
--     comprar (con su vendedor) y de juntar (con su zona) piden solo lo que
--     falta, y el motor las baja mientras subes.
-- Después, una receta por paso: «Haz X hasta 35», cuántas veces desde tu
-- habilidad, sus colores, lo que lleva cada una y dónde se aprende.

local ADDON, M = ...
local A, L, N = M.A, M.L, M.N
local D = M.OficiosDatos
local C = {}
M.OficiosCrear = C

local ipairs, pairs, type, floor, ceil, max, min, format, concat = ipairs, pairs, type, math.floor, math.ceil, math.max, math.min, string.format, table.concat

local function Of() return M.OficiosGuia end

local QUEST = { accept = true, turnin = true, complete = true }

-- Las veces que se hace una receta «hasta N» desde la habilidad k (la misma
-- cuenta que el motor: un punto seguro antes del amarillo; después, la
-- probabilidad baja hasta el gris).
function C.Veces(goal, desde, k)
	local y, gris = goal.yellow, goal.grey
	local u = goal.untilSkill
	if not u then return 0 end
	local inicio = max(desde, k)
	if not (y and gris and gris > y) then return max(0, u - inicio) end
	local n = 0
	for x = inicio, u - 1 do
		local p = x < y and 1 or (gris - x) / (gris - y)
		if p > 0 then n = n + 1 / p end
	end
	return n
end

---------------------------------------------------------------------------
-- Recorrer la guía del motor: piezas en orden, cada una con su habilidad
---------------------------------------------------------------------------

local function recorrer(ctx)
	local Ofi = Of()
	local piezas, pos = {}, 1
	local aprender = {} -- spell -> meta learn (aún sin receta que la use)
	for _, s in ipairs(ctx.pasosMotor) do
		local rango, crafts, quests, niveles = nil, {}, {}, {}
		for _, g in ipairs(s.goals or {}) do
			if g.t == "train" and type(g.rank) == "number" then rango = g.rank
			elseif g.t == "learn" and g.spell then aprender[g.spell] = aprender[g.spell] or g
			elseif g.t == "craft" then crafts[#crafts + 1] = g
			elseif QUEST[g.t] then quests[#quests + 1] = g
			elseif g.t == "level" then niveles[#niveles + 1] = g end
		end
		if rango then
			local extra = {}
			for _, g in ipairs(s.goals or {}) do
				-- Los libros del rango (Cocina, Primeros auxilios) van con él.
				if g.t == "buy" then extra[#extra + 1] = g end
			end
			piezas[#piezas + 1] = { tipo = "rango", rango = rango, pos = pos, extra = extra }
		end
		if #quests > 0 then
			piezas[#piezas + 1] = { tipo = "mision", pos = pos, paso = s }
		end
		if #crafts > 0 then
			local ant = piezas[#piezas]
			local p = { tipo = "craft", pos = pos, crafts = crafts, learns = {}, trasMision = ant ~= nil and ant.tipo == "mision" }
			for _, g in ipairs(crafts) do
				local l = g.spell and aprender[g.spell]
				if l then p.learns[#p.learns + 1] = l aprender[g.spell] = nil end
			end
			for _, g in ipairs(crafts) do
				if g.untilSkill then p.desde = p.desde or pos pos = max(pos, g.untilSkill) p.hasta = pos end
			end
			p.desde = p.desde or pos
			piezas[#piezas + 1] = p
		end
	end
	-- Una receta que cruza el fin de un tramo (de 50 a 100) se parte en dos:
	-- hasta 75 en su tramo y de 75 a 100 en el siguiente (cada tramo pide sus
	-- materiales y se salta solo con su habilidad).
	local partidas = {}
	for _, p in ipairs(piezas) do
		while p.tipo == "craft" and p.hasta and Ofi.Tramo(p.desde) ~= Ofi.Tramo(p.hasta - 1) do
			local fin = D.TRAMOS[Ofi.Tramo(p.desde)][2]
			local a = { tipo = "craft", pos = p.pos, desde = p.desde, hasta = fin, learns = p.learns, trasMision = p.trasMision, crafts = {} }
			local b = { tipo = "craft", pos = fin, desde = fin, hasta = p.hasta, learns = {}, crafts = {} }
			for _, g in ipairs(p.crafts) do
				if g.untilSkill then
					local c = {}
					for k, v in pairs(g) do c[k] = v end
					c.untilSkill = fin
					a.crafts[#a.crafts + 1] = c
					b.crafts[#b.crafts + 1] = g
				else
					a.crafts[#a.crafts + 1] = g
				end
			end
			partidas[#partidas + 1] = a
			p = b
		end
		partidas[#partidas + 1] = p
	end
	piezas = partidas
	for _, p in ipairs(piezas) do
		-- Un rango que se aprende al llegar al tope del anterior (75, 150...) ya es del tramo siguiente.
		p.tramo = Ofi.Tramo(p.pos)
	end
	return piezas
end

---------------------------------------------------------------------------
-- Los materiales de un tramo
---------------------------------------------------------------------------

-- item -> cantidad que usan las recetas del tramo n desde la habilidad k
-- (lista: las recetas del tramo; de fábrica, las de la guía armada).
local function demanda(ctx, n, k, soloHasta, lista)
	lista = lista or ctx.crafts[n] or {}
	local t = D.TRAMOS[n]
	local d, orden = {}, {}
	local function sumar(id, q)
		if not d[id] then orden[#orden + 1] = id end
		d[id] = (d[id] or 0) + q
	end
	local start = t[1]
	local contadas = {}
	for _, g in ipairs(lista) do
		if g.untilSkill then
			local v = C.Veces(g, start, k)
			for _, r in ipairs(g.reagents or {}) do sumar(r.item, v * (r.count or 1)) end
			start = max(start, g.untilSkill)
		elseif g.count and g.item then
			contadas[#contadas + 1] = g
		end
	end
	if not soloHasta then
		local ahora, todo = demanda(ctx, n, k, true, lista), demanda(ctx, n, t[1], true, lista)
		for _, g in ipairs(contadas) do
			local parte = 1
			if (todo[g.item] or 0) > 0 then parte = min(1, (ahora[g.item] or 0) / todo[g.item]) end
			for _, r in ipairs(g.reagents or {}) do sumar(r.item, g.count * (r.count or 1) * parte) end
		end
	end
	return d, orden
end
C.Demanda = demanda

---------------------------------------------------------------------------
-- 1.3.9 (pedido de Toxic): llegar a la meta más rápido y más barato
---------------------------------------------------------------------------
-- La guía del motor elige recetas caras (el hacha de 40 barras de torio) y
-- las hace hasta casi gris. Aquí, con las recetas de TODA la guía del motor
-- de tu oficio (sus colores, sus reactivos y dónde se aprenden: tu
-- instructor o el vendedor de tu facción), cada punto se sube con la que
-- cuesta menos por punto mientras te da puntos. Los puntos esperados, con la
-- misma cuenta del motor (C.Veces): naranja 1; amarillo de 1 a 0,5 (unos
-- 0,75); verde de 0,5 a 0 (unos 0,25). Una receta se deja en cuanto otra
-- sale más barata por punto (una en verde casi siempre pierde).
-- El costo de cada una: el precio de subasta si todo lo tiene (Comercio);
-- si no, cuántos materiales base lleva (barra ≈ mineral; lo del proveedor
-- casi nada; lo raro, D.PESO). Lo intermedio (piedras, rollos) cuenta por
-- lo que lleva. Si en un tramo no sale más barato, queda la guía clásica.

local function prob(g, x)
	local y, gris = g.yellow, g.grey
	if not (y and gris and gris > y) then return 1 end
	if x < y then return 1 end
	if x >= gris then return 0 end
	return (gris - x) / (gris - y)
end
C.Prob = prob

local function copia(g)
	local c = {}
	for k, v in pairs(g) do c[k] = v end
	return c
end

-- Las recetas que dan puntos (con sus colores), lo intermedio (lo que otra
-- receta de la guía fabrica) y dónde se aprende cada una.
local function candidatas(piezas)
	local cands, orden, inter, learns = {}, {}, {}, {}
	local mision, nivelMision
	for _, p in ipairs(piezas) do
		if p.tipo == "mision" then
			mision, nivelMision = p, nil
			for _, g in ipairs(p.paso.goals or {}) do
				if g.t == "level" and tonumber(g.level) then nivelMision = max(nivelMision or 0, tonumber(g.level)) end
			end
		elseif p.tipo == "craft" then
			for _, l in ipairs(p.learns or {}) do
				if l.spell and not learns[l.spell] then learns[l.spell] = l end
			end
			for _, g in ipairs(p.crafts) do
				if g.item and type(g.reagents) == "table" and #g.reagents > 0 and not inter[g.item] then inter[g.item] = g end
				if g.untilSkill and g.yellow and g.grey and g.spell and type(g.reagents) == "table" then
					local c = cands[g.spell]
					if not c then
						-- Se puede desde donde la guía la aprende; la que trae una misión
						-- con nivel (las botas imperiales: nivel 50), solo con ese nivel.
						c = { spell = g.spell, goal = g, desde = p.desde, mision = p.trasMision and mision or nil,
							nivel = p.trasMision and nivelMision or nil, i = #orden + 1 }
						cands[g.spell] = c
						orden[#orden + 1] = c
						if c.mision then
							c.mision.daRecetas = c.mision.daRecetas or {}
							c.mision.daRecetas[g.spell] = true
						end
					elseif p.desde < c.desde then
						c.desde = p.desde
					end
				end
			end
		end
	end
	return cands, orden, inter, learns
end

-- Lo que cuesta un material: «precio» (subasta) o «peso» (materiales base).
local function costoMaterial(ctx, op, id, hondo)
	local memo = op.memo
	if memo[id] then return memo[id] end
	local Ofi = Of()
	local g = op.inter[id]
	local v
	if g and hondo < 3 then
		v = 0
		for _, r in ipairs(g.reagents) do v = v + (r.count or 1) * costoMaterial(ctx, op, r.item, hondo + 1) end
	elseif op.modo == "precio" then
		v = Ofi.Precio(id) or 0
	elseif ctx.compras[id] then
		v = D.PESO_VENDEDOR
	else
		v = D.PESO[id] or 1
	end
	memo[id] = v
	return v
end

local function costoReceta(ctx, op, g)
	local v = 0
	for _, r in ipairs(g.reagents or {}) do v = v + (r.count or 1) * costoMaterial(ctx, op, r.item, 0) end
	return max(v, 0.01)
end

-- ¿Todo tiene precio de subasta? (lo de los proveedores no hace falta)
local function conPrecios(ctx, op)
	local Ofi = Of()
	local visto = {}
	local function base(id, hondo)
		if visto[id] ~= nil then return visto[id] end
		local g = op.inter[id]
		local ok
		if g and hondo < 3 then
			ok = true
			for _, r in ipairs(g.reagents) do if not base(r.item, hondo + 1) then ok = false end end
		else
			ok = ctx.compras[id] ~= nil or Ofi.Precio(id) ~= nil
		end
		visto[id] = ok
		return ok
	end
	for _, c in ipairs(op.orden) do
		for _, r in ipairs(c.goal.reagents or {}) do if not base(r.item, 0) then return false end end
	end
	return #op.orden > 0
end

-- El plan de un tramo: { { c, desde, hasta } }, costo | nil (sin receta para algún punto)
local function planTramo(ctx, op, n)
	local t = D.TRAMOS[n]
	local segs, total = {}, 0
	local actual
	for x = t[1], t[2] - 1 do
		local mejor, mejorV
		for _, c in ipairs(op.orden) do
			if c.desde <= x and (not c.nivel or (ctx.nivel or 1) >= c.nivel) then
				local p = prob(c.goal, x)
				if p > 0 then
					local v = c.costo / p
					if not mejor or v < mejorV - 1e-9 then mejor, mejorV = c, v
					elseif op.modo == "precio" and v <= mejorV * 1.03 and (c.vale or 0) > (mejor.vale or 0) then
						-- Casi lo mismo: la que da algo que se vende mejor.
						mejor, mejorV = c, v
					end
				end
			end
		end
		if not mejor then return nil end
		-- No se cambia por casi nada (2 %): menos pasos.
		if actual and mejor ~= actual then
			local pa = prob(actual.goal, x)
			if pa > 0 and (actual.desde <= x) and actual.costo / pa <= mejorV * 1.02 then mejor, mejorV = actual, actual.costo / pa end
		end
		total = total + mejorV
		local s = segs[#segs]
		if s and s.c == mejor then s.hasta = x + 1
		else segs[#segs + 1] = { c = mejor, desde = x, hasta = x + 1 } end
		actual = mejor
	end
	return segs, total
end

-- Lo que costaba el tramo con las recetas de la guía clásica.
local function costoClasico(ctx, op, n, lista)
	local t = D.TRAMOS[n]
	local start, total, hay = t[1], 0, false
	for _, g in ipairs(lista or {}) do
		if g.untilSkill then
			hay = true
			total = total + C.Veces(g, start, t[1]) * costoReceta(ctx, op, g)
			start = max(start, g.untilSkill)
		end
	end
	return hay and total or nil
end

-- Las piezas de un tramo con su plan: una por receta, con lo intermedio
-- primero y lo que se aprende la primera vez que se usa.
local function piezasDe(op, n, segs, usado)
	local out = {}
	for _, s in ipairs(segs) do
		local g = copia(s.c.goal)
		g.untilSkill = s.hasta
		local veces = C.Veces(g, s.desde, s.desde)
		local crafts, learns = {}, {}
		for _, r in ipairs(g.reagents or {}) do
			local ig = op.inter[r.item]
			if ig and ig.spell ~= g.spell then
				local x = copia(ig)
				x.untilSkill, x.yellow, x.grey = nil, nil, nil
				x.count = max(1, ceil(veces * (r.count or 1) - 0.001))
				crafts[#crafts + 1] = x
				if ig.spell and not usado[ig.spell] and op.learns[ig.spell] then learns[#learns + 1] = op.learns[ig.spell] end
				if ig.spell then usado[ig.spell] = true end
			end
		end
		crafts[#crafts + 1] = g
		if not usado[g.spell] and op.learns[g.spell] then learns[#learns + 1] = op.learns[g.spell] end
		usado[g.spell] = true
		out[#out + 1] = { tipo = "craft", pos = s.desde, desde = s.desde, hasta = s.hasta, tramo = n, crafts = crafts, learns = learns,
			trasMision = s.c.mision ~= nil, optimizada = true }
	end
	return out
end

-- -> piezas (las de la guía clásica en los tramos donde no sale más barato)
function C.Optimizar(ctx, piezas)
	local cands, orden, inter, learns = candidatas(piezas)
	local op = { orden = orden, inter = inter, learns = learns, memo = {} }
	op.modo = conPrecios(ctx, op) and "precio" or "peso"
	local Ofi = Of()
	for _, c in ipairs(orden) do
		c.costo = costoReceta(ctx, op, c.goal)
		c.vale = op.modo == "precio" and c.goal.item and Ofi.Precio(c.goal.item) or nil
	end
	ctx.optimizado, ctx.costoModo = {}, op.modo
	if #orden == 0 then return piezas end
	-- Las recetas de la guía clásica de cada tramo (para comparar), como la
	-- seguirías tú: la que pide un nivel que no tienes (las botas imperiales
	-- antes del 50) no se hace y la de antes sigue hasta donde iba aquella
	-- (lo que la propia guía dice: «sigue con el hacha hasta 300»).
	local clasicas = {}
	for _, p in ipairs(piezas) do
		if p.tipo == "craft" then
			local l = clasicas[p.tramo] or {}
			clasicas[p.tramo] = l
			for _, g in ipairs(p.crafts) do
				local c = g.untilSkill and g.spell and cands[g.spell]
				if c and c.nivel and (ctx.nivel or 1) < c.nivel then
					local ant
					for i = #l, 1, -1 do if l[i].untilSkill then ant = i break end end
					if ant then
						l[ant] = copia(l[ant])
						l[ant].untilSkill = max(l[ant].untilSkill, g.untilSkill)
					end
				else
					l[#l + 1] = g
				end
			end
		end
	end
	ctx.craftsGuia = clasicas
	ctx.costos = {}
	local planes = {}
	local usadas = {}
	for n = 1, #D.TRAMOS do
		local antes = costoClasico(ctx, op, n, clasicas[n])
		local segs, total = planTramo(ctx, op, n)
		ctx.costos[n] = { antes = antes, ahora = total, modo = op.modo }
		if antes and segs and total < antes * 0.98 then
			planes[n] = segs
			ctx.optimizado[n] = { antes = antes, ahora = total }
			for _, s in ipairs(segs) do usadas[s.c.spell] = true end
		else
			for _, g in ipairs(clasicas[n] or {}) do if g.spell then usadas[g.spell] = true end end
		end
	end
	if not next(planes) then return piezas end
	local out, usado = {}, {}
	for n = 1, #D.TRAMOS do
		local lista = {}
		for i, p in ipairs(piezas) do
			if p.tramo == n then
				if not planes[n] then
					lista[#lista + 1] = p
					for _, l in ipairs(p.learns or {}) do if l.spell then usado[l.spell] = true end end
				elseif p.tipo ~= "craft" then
					-- Una misión que solo daba una receta que ya no se usa (las botas sin
					-- nivel 50) se va con ella.
					local sirve = not p.daRecetas
					for sp in pairs(p.daRecetas or {}) do if usadas[sp] then sirve = true end end
					if sirve then p.orden = i lista[#lista + 1] = p end
				end
			end
		end
		if planes[n] then
			for j, p in ipairs(piezasDe(op, n, planes[n], usado)) do p.orden = 100000 + j lista[#lista + 1] = p end
			local RANGO = { rango = 0, mision = 1, craft = 2 }
			table.sort(lista, function(a, b)
				if a.pos ~= b.pos then return a.pos < b.pos end
				if RANGO[a.tipo] ~= RANGO[b.tipo] then return RANGO[a.tipo] < RANGO[b.tipo] end
				return (a.orden or 0) < (b.orden or 0)
			end)
		end
		for _, p in ipairs(lista) do out[#out + 1] = p end
	end
	return out
end

-- De dónde sale un material, en palabras cortas.
local function origen(ctx, id, hechos)
	local Ofi = Of()
	if ctx.compras[id] then return L["lo venden: la flecha te lleva"] end
	if hechos[id] then return L["lo fabricas tú"] end
	local al = D.ALEACION[id]
	if al then return format(L["se funde de %s y %s (Minería)"], Ofi.Tok(ctx, "item", al[1]), Ofi.Tok(ctx, "item", al[2])) end
	local mineral = D.FUNDIR[id]
	if mineral then return format(L["se funde de %s (Minería)"], Ofi.Tok(ctx, "item", mineral)) end
	local tela = D.TELA[id]
	if tela then return format(L["sale de humanoides de nivel %d a %d"], tela[1], tela[2]) end
	if D.ES_CUERO[id] then return L["se desuella (Desuello)"] end
	local AR = rawget(_G, "AlfaRecoleccion")
	if type(AR) == "table" and type(AR.GruposDe) == "function" then
		local ok, g = pcall(AR.GruposDe, id)
		if ok and type(g) == "table" and #g > 0 then
			local Dt = type(AR.Datos) == "function" and AR.Datos()
			local gr = Dt and Dt.grupos
			for _, x in ipairs(gr or {}) do
				if x.clave == g[1] then return x.tipo == "hierbas" and L["se recoge (Herboristería)"] or L["se mina (Minería)"] end
			end
		end
	end
	if ctx.recoger[id] then return L["se junta: la flecha te lleva"] end
	return L["en la subasta o de botín"]
end

local function materiales(ctx, n, hechosAntes)
	local Ofi = Of()
	local t = D.TRAMOS[n]
	local k = (ctx.rank >= t[1] and ctx.rank < t[2]) and ctx.rank or t[1]
	local ahora, orden = demanda(ctx, n, k)
	local todo = demanda(ctx, n, t[1])
	local propios = {}
	for _, g in ipairs(ctx.crafts[n] or {}) do if g.item then propios[g.item] = true end end
	local lineas, metas = {}, {}
	local faltaAlgo = false
	for _, id in ipairs(orden) do
		if not propios[id] then
			local necesita = ceil((ahora[id] or 0) - 0.001)
			local lleno = ceil((todo[id] or 0) - 0.001)
			if lleno > 0 then
				local aqui = Ofi.Aqui(id)
				local otros, quien = Ofi.Otros(id)
				local faltan = max(0, necesita - aqui - otros)
				local tok = Ofi.Tok(ctx, "item", id)
				local partes = {}
				if faltan > 0 then
					partes[1] = format(L["%s: te faltan %d de %d"], tok, faltan, necesita)
					faltaAlgo = true
				else
					partes[1] = format(L["%s: %d, ¡ya los tienes!"], tok, necesita)
				end
				if aqui > 0 then partes[#partes + 1] = format(L["tienes %d"], aqui) end
				for i = 1, min(2, #quien) do
					partes[#partes + 1] = format(L["%s tiene %d (mándalo por correo)"], quien[i].nombre or "?", quien[i].n)
				end
				if faltan > 0 then
					partes[#partes + 1] = origen(ctx, id, hechosAntes)
					local p = Ofi.Precio(id)
					if p then partes[#partes + 1] = format(L["≈ %s c/u en la subasta"], N.DineroTexto(p, true)) end
				end
				lineas[#lineas + 1] = "• " .. concat(partes, " · ")
				-- La meta pide el tramo entero menos lo de tus otros personajes: el
				-- motor le quita lo que ya usaste mientras subes.
				local cuenta = max(0, lleno - otros)
				if cuenta > 0 and faltan > 0 then
					local base = ctx.compras[id] or (ctx.recoger[id] and ctx.recoger[id][1])
					if base then
						metas[#metas + 1] = Ofi.Copiar(ctx, base, { count = cuenta, optional = nil })
					else
						metas[#metas + 1] = { t = "collect", item = id, itemName = ctx.names["item:" .. id] or tostring(id), count = cuenta }
					end
				end
			end
		end
	end
	if #lineas == 0 then return nil end
	local nota
	if faltaAlgo then
		nota = L["Junta esto antes de empezar el tramo (lo de tus otros personajes ya está descontado):"] .. "\n" .. concat(lineas, "\n")
	else
		nota = L["Ya tienes todo lo de este tramo entre tus personajes:"] .. "\n" .. concat(lineas, "\n")
	end
	local ahorro = C.Ahorro(ctx, n)
	if ahorro then nota = ahorro .. "\n" .. nota end
	if #metas == 0 then metas[1] = { t = "note", text = L["Nada que comprar ni juntar: sigue al siguiente paso."] } end
	return Ofi.Paso(ctx, n, format(L["Tus materiales para %d–%d"], t[1], t[2]), nota, metas, t[2])
end

-- 1.3.9: «Unos 1,374 Thorium Bar en total (antes la guía clásica pedía
-- 1,943).»: el material que más pedía la guía clásica en el tramo, solo si
-- bajó. -> texto, id, ahora, antes | nil
function C.Ahorro(ctx, n)
	if not (ctx.optimizado and ctx.optimizado[n] and ctx.craftsGuia and ctx.craftsGuia[n]) then return nil end
	local t = D.TRAMOS[n]
	local antes = demanda(ctx, n, t[1], false, ctx.craftsGuia[n])
	local ahora = demanda(ctx, n, t[1])
	local propios = {}
	for _, l in ipairs({ ctx.craftsGuia[n], ctx.crafts[n] or {} }) do
		for _, g in ipairs(l) do if g.item then propios[g.item] = true end end
	end
	local id, mas
	for x, q in pairs(antes) do
		if not propios[x] and not ctx.compras[x] and (not mas or q > mas or (q == mas and x < id)) then id, mas = x, q end
	end
	if not id then return nil end
	local a, b = ceil((ahora[id] or 0) - 0.001), ceil(mas - 0.001)
	if a >= b * 0.95 then return nil end
	return format(L["Unos %s %s en total (antes la guía clásica pedía %s)."], N.Numero(a), Of().Tok(ctx, "item", id), N.Numero(b)), id, a, b
end

---------------------------------------------------------------------------
-- Los pasos
---------------------------------------------------------------------------

local function textoReactivos(ctx, g)
	local Ofi = Of()
	local p = {}
	for _, r in ipairs(g.reagents or {}) do p[#p + 1] = format("%d %s", r.count or 1, Ofi.Tok(ctx, "item", r.item)) end
	return concat(p, ", ")
end

local function pasoReceta(ctx, pz)
	local Ofi = Of()
	local metas, lineas = {}, {}
	for _, l in ipairs(pz.learns) do
		if l.item and ctx.compras[l.item] then
			metas[#metas + 1] = Ofi.Copiar(ctx, ctx.compras[l.item], { count = 1 })
			lineas[#lineas + 1] = format(L["La receta viene en %s: cómprala (la flecha te lleva) y úsala."], Ofi.Tok(ctx, "item", l.item))
		elseif l.item and pz.trasMision then
			lineas[#lineas + 1] = format(L["La receta viene en %s: te la da la misión de antes."], Ofi.Tok(ctx, "item", l.item))
		elseif l.item then
			lineas[#lineas + 1] = format(L["La receta viene en %s: búscala en la subasta o de botín."], Ofi.Tok(ctx, "item", l.item))
		else
			lineas[#lineas + 1] = format(L["Apréndela con tu instructor: %s."], Ofi.Tok(ctx, "spell", l.spell, l.spellName))
		end
		metas[#metas + 1] = Ofi.Copiar(ctx, l)
	end
	local titulo, hasta
	for _, g in ipairs(pz.crafts) do
		metas[#metas + 1] = Ofi.Copiar(ctx, g)
		local nombre = Ofi.Tok(ctx, "spell", g.spell, g.spellName)
		if g.untilSkill then
			hasta = g.untilSkill
			titulo = format(L["Haz %s hasta %d"], nombre, g.untilSkill)
			local k = max(pz.desde, ctx.rank)
			local veces = ceil(C.Veces(g, pz.desde, k) - 0.001)
			local y, gris = g.yellow, g.grey
			if y and gris then
				local verde = floor((y + gris) / 2)
				lineas[#lineas + 1] = format(L["Naranja hasta %d, amarillo hasta %d, verde hasta %d."], y, verde, gris)
			end
			if ctx.rank < g.untilSkill then
				lineas[#lineas + 1] = N.Plural(veces, L["Desde tu habilidad: más o menos %d vez."], L["Desde tu habilidad: más o menos %d veces."])
			end
			lineas[#lineas + 1] = format(L["Cada una lleva %s."], textoReactivos(ctx, g))
		elseif g.count then
			titulo = titulo or format(L["Haz %d %s"], g.count, Ofi.Tok(ctx, "item", g.item or 0, g.itemName))
			lineas[#lineas + 1] = format(L["Primero %d %s (%s cada una): las usa la receta que sigue y también dan puntos."], g.count, Ofi.Tok(ctx, "item", g.item or 0, g.itemName), textoReactivos(ctx, g))
		end
	end
	if ctx.of.yunque then lineas[#lineas + 1] = format(L["Junto a un yunque, con %s en tus bolsas."], Ofi.Tok(ctx, "item", ctx.of.herramienta)) end
	return Ofi.Paso(ctx, pz.tramo, titulo or L["Haz la receta"], concat(lineas, " "), metas, hasta)
end

local function pasoMision(ctx, pz)
	local Ofi = Of()
	local metas = {}
	for _, g in ipairs(pz.paso.goals or {}) do
		if g.t ~= "note" then metas[#metas + 1] = Ofi.Copiar(ctx, g) end
	end
	return Ofi.Paso(ctx, pz.tramo, pz.paso.title or L["Misión de tu oficio"],
		L["Una misión de tu oficio: la necesitas para seguir subiendo. Tómala y entrégala; la flecha te lleva."], metas)
end

local function recetasPorTramo(piezas)
	local t = {}
	for _, p in ipairs(piezas) do
		if p.tipo == "craft" then
			local l = t[p.tramo] or {}
			t[p.tramo] = l
			for _, g in ipairs(p.crafts) do l[#l + 1] = g end
		end
	end
	return t
end

function C.Armar(ctx)
	local Ofi = Of()
	local piezas = recorrer(ctx)
	-- 1.3.9: las más baratas (Optimizar guarda las de la guía clásica en
	-- ctx.craftsGuia, para decir cuánto bajó).
	ctx.craftsGuia = recetasPorTramo(piezas)
	piezas = C.Optimizar(ctx, piezas)
	ctx.crafts = recetasPorTramo(piezas)
	local hechos = {}
	local hayRango1 = false
	for n = 1, #D.TRAMOS do
		local puestos = false
		local ultimo, ultimoHasta
		for _, p in ipairs(piezas) do
			if p.tramo == n then
				if p.tipo ~= "rango" and not puestos then materiales(ctx, n, hechos) puestos = true end
				if p.tipo == "rango" then
					local extra = {}
					if p.rango == 1 then
						hayRango1 = true
						local h = ctx.of.herramienta and ctx.compras[ctx.of.herramienta]
						if h then extra[#extra + 1] = Ofi.Copiar(ctx, h, { count = 1 }) end
					end
					for _, g in ipairs(p.extra or {}) do extra[#extra + 1] = Ofi.Copiar(ctx, g) end
					Ofi.PasoRango(ctx, p.rango, extra, n)
				elseif p.tipo == "craft" then
					ultimo = pasoReceta(ctx, p)
					ultimoHasta = p.hasta
				else
					pasoMision(ctx, p)
				end
			end
		end
		if not puestos then materiales(ctx, n, hechos) end
		-- El tramo termina con su meta de habilidad.
		local fin = D.TRAMOS[n][2]
		if ultimo and (ultimoHasta or 0) ~= fin then ultimo.goals[#ultimo.goals + 1] = Ofi.MetaHabilidad(ctx, fin) end
		for _, g in ipairs(ctx.crafts[n] or {}) do if g.item then hechos[g.item] = true end end
	end
	if not hayRango1 and #ctx.steps > 0 then
		-- Sin instructor en la guía del motor: el paso de aprender va primero igual.
		local s = Ofi.PasoRango(ctx, 1, nil, 1)
		table.remove(ctx.steps)
		table.insert(ctx.steps, 1, s)
	end
	return #ctx.steps > 0
end
