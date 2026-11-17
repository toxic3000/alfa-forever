-- Alfa - Pesca: la guía de pesca (toxic3000 / La Jauría). GPL-3.0.
--
-- La pestaña Guía, de arriba abajo:
--   * Tu siguiente paso: aprender Pesca, conseguir una caña, aprender el
--     siguiente rango (instructor, el pescador de Bahía del Botín o la misión
--     de Nat Pagle) o en qué aguas seguir subiendo, con su botón.
--   * De 1 a 300: los cuatro tramos con sus zonas (orientativo) y el cebo que
--     conviene; el tuyo marcado.
--   * Cerca de ti: los bancos de peces de tu zona (Codex: dónde salen y lo
--     que dan, el más cercano con "Llévame") y lo que tú sacas aquí.
--   * Instructores y vendedores: Buscar cerca (Alfa_Rutas) y Guíame; y sus
--     marcadores en el mapa (capas "pesca.instructores" y "pesca.vendedores"
--     de Alfa_Mundo, con los datos del Codex).
--   * Equipo y cebos: lo que suma Pesca en Forever y cómo se consigue.
--   * Misiones de pesca (Codex) y el concurso de Tuercespina con su próxima
--     fecha en tu hora.
-- El Codex se carga al abrir esta pestaña o al encender una capa, nunca al entrar.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local V = M.V
local Eq = M.Eq
local ID = M.ID

local floor, max, min, format, type, pairs, ipairs, tonumber, tostring = math.floor, math.max, math.min, string.format, type, pairs, ipairs, tonumber, tostring
local ESP = K.ESP
local DOT = " \194\183 "

local function faccion()
	local f = UnitFactionGroup and UnitFactionGroup("player")
	if f == "Horde" then return "H" end
	if f == "Alliance" then return "A" end
	return nil
end

local function paraMi(fac)
	if not fac or fac == "" or fac == "AH" then return true end
	local mia = faccion()
	return not mia or fac:find(mia, 1, true) ~= nil
end

local function hecha(q)
	local C = C_QuestLog
	if C and C.IsQuestFlaggedCompleted then
		local ok, si = pcall(C.IsQuestFlaggedCompleted, q)
		if ok then return si == true end
	end
	return false
end

---------------------------------------------------------------------------
-- Datos del Codex: instructores, vendedores, fuentes
---------------------------------------------------------------------------
local function instructores(C)
	local out = {}
	if not (C and C.WithRole) then return out end
	for _, id in ipairs(C.WithRole("trainer:" .. M.SKILL) or {}) do
		local ok, npc = pcall(C.Npc, id)
		if ok and npc and paraMi(npc.faction) then out[#out + 1] = npc end
	end
	return out
end

-- Los PNJ que venden cañas o cebos.
local function vendedores(C)
	local out, visto = {}, {}
	if not C then return out end
	for _, item in ipairs({ M.CANA_BASICA, 6530, 6532, 6533 }) do
		local ok, rec = pcall(C.Item, item)
		if ok and rec then
			for _, s in ipairs(rec.sources or {}) do
				if s.type == "vendor" and s.npc and not visto[s.npc] then
					visto[s.npc] = true
					local okN, npc = pcall(C.Npc, s.npc)
					if okN and npc and paraMi(npc.faction) then out[#out + 1] = npc end
				end
			end
		end
	end
	return out
end

local FUENTE = {
	vendor = L["lo venden"], drop = L["botín de criaturas"], object = L["sale en el mundo"], quest = L["recompensa de misión"],
	gift = L["te lo da un PNJ"], craft = L["se fabrica"], rep = L["con reputación"], container = L["sale de un contenedor"],
	pvp = L["JcJ"], world = L["botín del mundo"],
}

-- -> "Pide Pesca 100 · lo venden" (y el texto largo para el cuadro)
local function comoConseguir(C, id)
	if not C then return nil end
	local ok, rec = pcall(C.Item, id)
	if not ok or not rec then return nil end
	local partes, tipos = {}, {}
	if rec.reqSkill == M.SKILL and (rec.reqSkillRank or 0) > 1 then partes[#partes + 1] = format(L["pide Pesca %d"], rec.reqSkillRank) end
	for _, s in ipairs(rec.sources or {}) do
		local t = s.type == "craft" and s.profession and format(L["se fabrica (%s)"], s.profession) or FUENTE[s.type]
		if t and not tipos[t] then
			tipos[t] = true
			partes[#partes + 1] = t
		end
		if #partes >= 3 then break end
	end
	if rec.status == "retired" then partes[#partes + 1] = L["ya no se consigue"] end
	if #partes == 0 then partes[1] = L["no se sabe de dónde sale"] end
	return table.concat(partes, DOT)
end

local function bono(id)
	local c = M.CEBOS[id]
	if c then return c.bono end
	local e = Eq.InfoEnlace("item:" .. id)
	return e and e.bono or 0
end

---------------------------------------------------------------------------
-- Distancias (para el banco más cercano)
---------------------------------------------------------------------------
local function dondeEstoy()
	local C = A.Compat
	if not (C and C.GetPlayerWorldPosition) then return nil end
	local ok, c, x, y = pcall(C.GetPlayerWorldPosition)
	if ok and c and x then return c, x, y end
	return nil
end

local function distancia(s, c, x, y)
	local Cm = A.Compat
	if not (Cm and Cm.MapToWorld and c) then return nil end
	local ok, sc, sx, sy = pcall(Cm.MapToWorld, s.map, s.x, s.y, s.f)
	if not ok or sc ~= c or not sx then return nil end
	return math.sqrt((sx - x) ^ 2 + (sy - y) ^ 2)
end

---------------------------------------------------------------------------
-- Las capas del mapa (Alfa_Mundo)
---------------------------------------------------------------------------
local CAPAS = { instructores = "pesca.instructores", vendedores = "pesca.vendedores" }
local registradas = false
local pedidas = {} -- capa -> ya se llamó una vez (la primera llamada es la del registro)

local function mundo()
	local Mu = rawget(_G, "AlfaMundo")
	if type(Mu) == "table" and type(Mu.RegistrarCapa) == "function" then return Mu end
	return nil
end

local function capaActiva(id)
	local Mu = mundo()
	if registradas and Mu and type(Mu.CapaActiva) == "function" then
		local ok, si = pcall(Mu.CapaActiva, id)
		return ok and si == true
	end
	return N.Get(ID, "mapaGuia") and true or false
end

local function tooltipNPC(npc, que)
	return function(tip)
		tip:SetText(npc.name or "?", K.Color("texto"))
		if npc.subName then tip:AddLine(npc.subName, K.Color("textoSuave")) end
		tip:AddLine(que, K.Color("acento"))
		tip:AddLine(L["Clic: Guíame"], K.Color("textoTenue"))
	end
end

local function pinesDe(lista, icono, que)
	local pins = {}
	for _, npc in ipairs(lista) do
		for _, s in ipairs(npc.spawns or {}) do
			if s.map and s.x and s.y then
				local id = npc.id
				pins[#pins + 1] = { map = s.map, x = s.x, y = s.y, f = s.f, icon = icono, size = 15, minimapSize = 12, priority = 2,
					color = { K.Color("acento") }, tooltip = tooltipNPC(npc, que),
					onClick = function(boton) if boton == "LeftButton" then V.Guiar("npc", id) end end }
			end
		end
	end
	return pins
end

local function pintarCapas()
	local P = A.Pins
	if not (P and P.SetLayer and P.ClearLayer) then return end
	local C = V.CodexListo()
	for clave, capa in pairs(CAPAS) do
		if capaActiva(capa) and C then
			local lista = clave == "instructores" and instructores(C) or vendedores(C)
			local icono = clave == "instructores" and "map:trainer-profession" or "map:vendor"
			local que = clave == "instructores" and L["Instructor de pesca"] or L["Vende cañas y cebos"]
			pcall(P.SetLayer, capa, pinesDe(lista, icono, que), { world = true, minimap = true })
		else
			pcall(P.ClearLayer, capa)
		end
	end
end

-- Encender una capa (tu clic): carga el Codex si hace falta.
local function alCambiarCapa(capa)
	return function(activa)
		local primera = not pedidas[capa]
		pedidas[capa] = true
		if activa and not primera then V.Codex() end
		pintarCapas()
	end
end

local function registrar()
	if registradas then return end
	local Mu = mundo()
	if not Mu then return end
	local ok1 = pcall(Mu.RegistrarCapa, { id = CAPAS.instructores, grupo = L["Pesca"], nombre = L["Instructores de pesca"],
		icono = "Interface\\AddOns\\Alfa\\Media\\Map\\icon-trainer-profession", color = "accent",
		ayuda = L["Dónde aprender Pesca y sus rangos. Se llenan al abrir la guía de pesca."], activa = false,
		alCambiar = alCambiarCapa(CAPAS.instructores) })
	local ok2 = pcall(Mu.RegistrarCapa, { id = CAPAS.vendedores, grupo = L["Pesca"], nombre = L["Cañas y cebos"],
		icono = "Interface\\AddOns\\Alfa\\Media\\Map\\icon-vendor", color = "accent",
		ayuda = L["Quién vende cañas y cebos. Se llenan al abrir la guía de pesca."], activa = false,
		alCambiar = alCambiarCapa(CAPAS.vendedores) })
	registradas = ok1 or ok2
end

local function ponerCapas(on)
	local Mu = mundo()
	if on then V.Codex() end
	if registradas and Mu and type(Mu.ActivarCapa) == "function" then
		for _, capa in pairs(CAPAS) do pcall(Mu.ActivarCapa, capa, on) end
	else
		N.Set(ID, "mapaGuia", on and true or false)
	end
	pintarCapas()
end

A.OnLogin(function() registrar() end)
A.On("CODEX_LOADED", function() pintarCapas() end)

-- Los bancos de peces en el mapa: la capa de Recolección, si está.
local function verBancos()
	local Mu = mundo()
	if not Mu then return false end
	if type(Mu.ActivarCapa) == "function" then pcall(Mu.ActivarCapa, "recoleccion.pesca", true) end
	if type(Mu.Abrir) == "function" then pcall(Mu.Abrir, M.MapaJugador()) end
	return true
end

---------------------------------------------------------------------------
-- Las secciones
---------------------------------------------------------------------------
local function tieneCana()
	if Eq.CanaPuesta() then return true end
	return #Eq.Inventario().canas > 0
end

local function tramoDe(r)
	for i, t in ipairs(M.TRAMOS) do
		if r < t.hasta or i == #M.TRAMOS then return t, i end
	end
	return M.TRAMOS[1], 1
end

local function zonasDe(t)
	local nombres = {}
	for _, m in ipairs(t.mapas) do
		local n = V.NombreMapa(m)
		if n then nombres[#nombres + 1] = n end
	end
	return table.concat(nombres, ", ")
end

local function llevarInstructor()
	if V.Llevar("trainer", M.SKILL) then return end
	local C = V.Codex()
	local lista = instructores(C)
	if lista[1] then V.Guiar("npc", lista[1].id) end
end

local function siguientePaso()
	local r, mx = M.Habilidad()
	local d = { icono = "ic-pesca", tono = "acento", sobre = L["Tu siguiente paso"] }
	if not r then
		d.titulo = L["Aprende Pesca"]
		d.texto = L["Cualquier instructor de pesca te la enseña. Luego compra una caña y unas lombrices: con eso empiezas."]
		d.accion = { texto = L["Llévame al instructor"], icono = "ic-flecha", alClic = llevarInstructor }
		return d
	end
	if not tieneCana() then
		d.titulo, d.tono = L["Consigue una caña de pescar"], "aviso"
		d.texto = L["La básica la venden los instructores y los vendedores de suministros de pesca."]
		d.accion = { texto = L["Guíame a una caña"], icono = "ic-flecha", alClic = function() V.Guiar("item", M.CANA_BASICA) end }
		d.progreso = { actual = r, total = max(1, mx), texto = format(L["%d de %d"], r, mx) }
		return d
	end
	local _, rango = M.NombreRango(mx)
	if mx < 300 and rango and rango.siguiente and r >= rango.siguiente then
		local idx
		for i, x in ipairs(M.RANGOS) do if x == rango then idx = i end end
		local proximo = M.RANGOS[(idx or 1) + 1]
		d.titulo = format(L["Ya puedes aprender el rango %s"], proximo and proximo.nombre or "")
		if mx <= 75 then
			d.texto = L["Te lo enseña cualquier instructor de pesca. Hasta que lo aprendas, tu habilidad no pasa del tope."]
			d.accion = { texto = L["Llévame al instructor"], icono = "ic-flecha", alClic = llevarInstructor }
		elseif mx <= 150 then
			d.texto = L["El rango Experto viene en un libro que vende el pescador de Bahía del Botín, en Tuercespina."]
			d.accion = { texto = L["Guíame al pescador"], icono = "ic-flecha", alClic = function() V.Guiar("npc", M.HEMING) end }
		else
			d.texto = L["Nat Pagle, en el Marjal Revolcafango, te pide cuatro peces raros: con su misión aprendes el rango Artesano."]
			d.accion = { texto = L["Guíame a la misión"], icono = "ic-flecha", alClic = function() V.Guiar("quest", 6607) end }
		end
		d.progreso = { actual = r, total = max(1, mx), texto = format(L["%d de %d"], r, mx) }
		return d
	end
	if mx >= 300 and r >= mx then
		d.titulo, d.tono = L["Tu pesca está al máximo"], "exito"
		d.texto = L["Ahora toca la colección: completa tu diario, los logros y prueba el concurso de los domingos."]
		d.accion = { texto = L["Ver mi diario"], icono = "ic-seguir", alClic = function() V.Mostrar("diario") end }
		return d
	end
	local t = tramoDe(r)
	d.titulo = format(L["Sigue subiendo: %d de %d"], r, mx)
	d.texto = format(L["Para tu habilidad conviene pescar en: %s."], zonasDe(t))
	local c = Eq.MejorCebo()
	if c then d.texto = d.texto .. " " .. format(L["Usa %s: tu tecla lo pone."], Eq.Nombre(c.id, c.enlace) or "?") end
	d.progreso = { actual = r, total = max(1, mx), texto = format(L["%d de %d"], r, mx) }
	return d
end

local function tarjetasTramos()
	local r = M.Habilidad() or 0
	local _, actual = tramoDe(r)
	local out = {}
	for i, t in ipairs(M.TRAMOS) do
		local cebo = V.NombreObjeto(t.cebo)
		out[#out + 1] = {
			icono = "ic-nivel", tono = i < actual and "exito" or "acento", elegida = i == actual,
			sobre = format(L["%d a %d"], t.desde, t.hasta), titulo = zonasDe(t), texto = t.texto,
			insignias = { { format(L["Cebo: %s"], cebo), "neutro" } },
			estado = i < actual and { texto = L["Hecho"], tono = "exito" } or nil,
		}
	end
	return out
end

-- Los bancos de tu zona: { { banco, nombre, da = "…", dist } }
local function bancosAqui(C)
	local mapa = M.MapaJugador()
	local out = {}
	if not mapa then return out, mapa end
	local c, x, y = dondeEstoy()
	for banco, b in pairs(M.BANCOS) do
		local aqui = false
		for _, m in ipairs(b.mapas) do if m == mapa then aqui = true end end
		if aqui then
			local nombre
			local mejor
			if C then
				local ok, obj = pcall(C.Object, banco)
				if ok and obj then
					nombre = obj.name
					for _, s in ipairs(obj.spawns or {}) do
						if s.map == mapa then
							local dd = distancia(s, c, x, y)
							if dd and (not mejor or dd < mejor) then mejor = dd end
						end
					end
				end
			end
			local da = {}
			for _, id in ipairs(b.da) do da[#da + 1] = V.NombreObjeto(id) end
			out[#out + 1] = { banco = banco, nombre = nombre or L["Banco de peces"], da = table.concat(da, ", "), dist = mejor }
		end
	end
	table.sort(out, function(a, b)
		if a.dist and b.dist then return a.dist < b.dist end
		if a.dist or b.dist then return a.dist ~= nil end
		return tostring(a.nombre) < tostring(b.nombre)
	end)
	return out, mapa
end

local function tarjetasCerca(C)
	local out = {}
	local lista = bancosAqui(C)
	for i, b in ipairs(lista) do
		if i > 6 then break end
		out[#out + 1] = {
			variante = "compacta", icono = M.ICONO.cebo, titulo = b.nombre, texto = b.da,
			valor = b.dist and format(L["%d m"], floor(b.dist * 0.9144 + 0.5)) or nil,
			alClic = function() V.Guiar("object", b.banco) end,
			ayuda = L["Clic: Guíame al banco."],
		}
	end
	return out
end

-- Lo que tú sacas en esta zona (de tu diario).
local function textoMisCapturas()
	local zona = M.Lugar()
	local t = {}
	for id, e in pairs(M.Diario()) do
		local n = type(e) == "table" and type(e.zonas) == "table" and tonumber(e.zonas[zona]) or 0
		if n > 0 then t[#t + 1] = { id, n } end
	end
	table.sort(t, function(a, b) return a[2] > b[2] end)
	if #t == 0 then return format(L["Todavía no pescas en %s. Lo que saques aquí se anota por zona."], zona) end
	local partes = {}
	for i = 1, min(6, #t) do
		local id = t[i][1]
		partes[#partes + 1] = format(L["%s ×%d"], type(id) == "number" and V.NombreObjeto(id) or tostring(id), t[i][2])
	end
	return format(L["Lo que sacas en %s: %s."], zona, table.concat(partes, DOT))
end

local function tarjetasServicios(C)
	local out = {}
	local Ce = rawget(_G, "AlfaCerca")
	local cerca = type(Ce) == "table" and type(Ce.Texto) == "function" and Ce.Texto("trainer", M.SKILL) or nil
	out[#out + 1] = { icono = "ic-guia", titulo = L["Instructor de pesca"],
		texto = cerca or L["Te enseña Pesca y sus rangos. También vende la caña básica."],
		accion = { texto = L["Llévame"], icono = "ic-flecha", alClic = llevarInstructor } }
	out[#out + 1] = { icono = M.ICONO.cebo, titulo = L["Cañas y cebos"],
		texto = L["Los vendedores de suministros de pesca tienen cañas, lombrices y baratijas."],
		accion = { texto = L["Guíame"], icono = "ic-flecha", alClic = function() V.Guiar("item", 6530) end } }
	local activas = capaActiva(CAPAS.instructores) or capaActiva(CAPAS.vendedores)
	out[#out + 1] = { icono = "ic-mapa", titulo = L["En el mapa"],
		texto = activas and L["Los instructores y vendedores de pesca se ven en el mapa y el minimapa."] or L["Marca en el mapa a los instructores y vendedores de pesca de tu facción."],
		accion = { texto = activas and L["Quitar del mapa"] or L["Mostrar en el mapa"], icono = "ic-mapa", alClic = function() ponerCapas(not activas) V.Acomodar() end } }
	if C then
		local n = #instructores(C)
		out[1].insignias = { { format(L["%d en el mundo"], n), "neutro" } }
	end
	return out
end

local function tarjetasEquipo(C)
	local out = {}
	local ids = {}
	for _, id in ipairs(M.EQUIPO_GUIA) do ids[#ids + 1] = id end
	local cebos = {}
	for id in pairs(M.CEBOS) do cebos[#cebos + 1] = id end
	table.sort(cebos, function(a, b) return M.CEBOS[a].bono < M.CEBOS[b].bono end)
	for _, id in ipairs(cebos) do ids[#ids + 1] = id end
	for _, id in ipairs(ids) do
		local b = bono(id)
		local como = comoConseguir(C, id)
		local tienes = Eq.Cuenta(id) > 0
		out[#out + 1] = {
			variante = "compacta", icono = Eq.Icono(id) or "ic-pesca", tenir = false,
			titulo = V.NombreObjeto(id), texto = como or (M.CEBOS[id] and format(L["Cebo de %d minutos"], M.CEBOS[id].min) or ""),
			valor = tienes and L["lo tienes"] or (b > 0 and format(L["+%d"], b) or nil),
			alClic = function() V.Guiar("item", id) end, ayuda = L["Clic: Guíame a conseguirlo."],
		}
	end
	return out
end

local function tarjetasMisiones(C)
	local out = {}
	if not C then return out end
	for _, q in ipairs(M.MISIONES) do
		local ok, rec = pcall(C.Quest, q)
		if ok and rec and paraMi(rec.faction) then
			local h = hecha(q)
			out[#out + 1] = {
				variante = "compacta", icono = "ic-misiones", tono = h and "exito" or "acento",
				titulo = rec.title or format(L["Misión %d"], q),
				texto = rec.minLevel and format(L["Desde nivel %d"], rec.minLevel) or nil,
				valor = h and L["hecha"] or nil,
				alClic = not h and function() V.Guiar("quest", q) end or nil,
				ayuda = not h and L["Clic: Guíame a la misión."] or nil,
			}
		end
	end
	table.sort(out, function(a, b) return (a.valor and 1 or 0) < (b.valor and 1 or 0) end)
	return out
end

local function tarjetaConcurso()
	local enCurso, inicio, fin = M.Concurso()
	local d = { icono = "ic-raros", tono = enCurso and "exito" or "acento", sobre = L["Concurso de pesca de Tuercespina"] }
	local t = date("*t", inicio)
	local cuando = format(L["%s %d/%d de %s a %s (tu hora)"], M.DIAS[t.wday] or "", t.day, t.month, date("%H:%M", inicio), date("%H:%M", fin))
	if enCurso then
		d.titulo = format(L["¡Es ahora! Hasta las %s"], date("%H:%M", fin))
		d.estado = { texto = L["En curso"], tono = "exito" }
	else
		d.titulo = format(L["El próximo: %s"], cuando)
	end
	d.texto = L["Cada domingo en Tuercespina: el primero en llevar 40 pescados sabrosos de los bancos especiales gana. También salen peces raros que se cambian por premios."]
	d.accion = { texto = L["Guíame a Bahía del Botín"], icono = "ic-flecha", alClic = function() V.Guiar("npc", M.CONCURSO_PNJ[1]) end }
	return d
end

---------------------------------------------------------------------------
-- La pestaña
---------------------------------------------------------------------------
local function construir(padre)
	registrar()
	local C = V.Codex()
	local p = V.Pagina(padre)
	local pila = p.pila
	local ui = {}
	ui.paso = pila:Agregar(K.Tarjeta(pila, { variante = "accion" }))
	ui.secTramos = pila:Agregar(K.Seccion(pila, L["De 1 a 300"]))
	ui.tramos = pila:Agregar(K.Rejilla(pila, { min = 380, gap = ESP.m }), { espacio = ESP.m })
	ui.secCerca = pila:Agregar(K.Seccion(pila, L["Cerca de ti"]))
	ui.cerca = pila:Agregar(K.Rejilla(pila, { min = 300, gap = ESP.s }), { espacio = ESP.m })
	ui.misCapturas = pila:Agregar(V.Parrafo(pila, "nota", "textoSuave"), { espacio = ESP.s })
	ui.secServ = pila:Agregar(K.Seccion(pila, L["Instructores y vendedores"]))
	ui.serv = pila:Agregar(K.Rejilla(pila, { min = 260, gap = ESP.m }), { espacio = ESP.m })
	ui.secEquipo = pila:Agregar(K.Seccion(pila, L["Equipo y cebos"]))
	ui.equipo = pila:Agregar(K.Rejilla(pila, { min = 300, gap = ESP.s }), { espacio = ESP.m })
	ui.secMis = pila:Agregar(K.Seccion(pila, L["Misiones de pesca"]))
	ui.mis = pila:Agregar(K.Rejilla(pila, { min = 300, gap = ESP.s }), { espacio = ESP.m })
	ui.concurso = pila:Agregar(K.Tarjeta(pila, { variante = "estado" }))
	ui.sinCodex = pila:Agregar(V.Parrafo(pila, "nota", "aviso"))
	p.antes = function()
		C = C or V.CodexListo()
		ui.paso:Set(siguientePaso())
		ui.tramos:Llenar(tarjetasTramos())
		local zona = M.Lugar()
		local cerca = tarjetasCerca(C)
		ui.secCerca:Set(format(L["Cerca de ti: %s"], zona), { enlace = mundo() and { texto = L["Ver bancos en el mapa"], alClic = verBancos } or nil })
		ui.cerca:Llenar(cerca)
		K.Mostrar(ui.cerca, #cerca > 0)
		local mis = textoMisCapturas()
		if #cerca == 0 then mis = L["No hay bancos de peces conocidos en esta zona: aquí se pesca en aguas abiertas."] .. " " .. mis end
		ui.misCapturas:Set(mis)
		ui.serv:Llenar(tarjetasServicios(C))
		ui.equipo:Llenar(tarjetasEquipo(C))
		local misiones = tarjetasMisiones(C)
		ui.mis:Llenar(misiones)
		K.Mostrar(ui.secMis, #misiones > 0)
		K.Mostrar(ui.mis, #misiones > 0)
		ui.concurso:Set(tarjetaConcurso())
		ui.sinCodex:Set(not C and L["Los datos del mundo (Codex) no están disponibles: faltan los bancos, las misiones y de dónde sale cada cosa."] or nil)
	end
	return p
end

V.Registrar("guia", { nombre = L["Guía"], icono = "ic-guia", orden = 3, cambia = { habilidad = true, equipo = true }, construir = construir })
