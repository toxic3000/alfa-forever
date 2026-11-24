-- Alfa - Rutas: las guías de oficios de Alfa (toxic3000 / La Jauría). GPL-3.0.
-- 1.3.9, pedido de Toxic: «las guías de profesiones están algo genéricas, por
-- no decir que son de ayuda cero».
--
-- Una guía por oficio, por tramos (1–75, 75–150, 150–225, 225–300), armada
-- para tu personaje cuando la pides (nunca al entrar):
--   * recolección (OficiosJuntar.lua): en cada tramo, la mejor zona para tu
--     facción y tu nivel con su ruta de nodos (Recolección), qué nodos dan
--     puntos y en qué color, cuándo ir al instructor y la herramienta;
--   * fabricación (OficiosCrear.lua): las recetas de cada tramo en orden (de
--     las guías del motor: la más barata que sigue en naranja o amarillo),
--     cuántas hacer, los materiales del tramo con lo que ya tienes y lo de tus
--     otros personajes descontado, dónde comprar lo que se vende, dónde se
--     junta lo demás y dónde aprender cada receta.
-- Cada paso tiene su meta real (la habilidad, «hasta N») y se salta solo si
-- ya la pasaste (`when` de habilidad), así «Restablecer esta guía» sabe
-- dónde vas. Viven en su propio paquete del motor (alfa-oficios), con la
-- categoría Profesiones de la Biblioteca y del Asistente.
--
-- Al cargar solo se registra una ficha corta por oficio (sin pasos de verdad);
-- la guía se arma al abrirla (Of.Abrir, la Biblioteca, el Asistente,
-- Comercio > Oficios) o si el motor abre la ficha por su cuenta (una pestaña
-- guardada): GUIDE_CHANGED la arma en cuanto puede.
--
--   Of.Id(linea) -> "alfa-oficios/mineria" ; Of.LineaDe(id) -> linea | nil
--   Of.Habilidad(linea) -> rank, max | nil
--   Of.Armar(linea) -> def | nil, motivo        (sin registrarla)
--   Of.Preparar(id) -> true si la armó (para la Biblioteca)
--   Of.Abrir(linea) -> ok                       (la arma, la registra y la abre)
--   Of.Oculta(g) -> bool                        (la guía del motor que esta reemplaza)
--   AlfaRuta.GuiaOficio(linea), AlfaRuta.TieneGuiaOficio(linea)

local ADDON, M = ...
local A, L, N, K = M.A, M.L, M.N, M.K
local D = M.OficiosDatos
local Of = {}
M.OficiosGuia = Of

local type, ipairs, pairs, tonumber, tostring, pcall = type, ipairs, pairs, tonumber, tostring, pcall
local floor, ceil, max, min, format, concat = math.floor, math.ceil, math.max, math.min, string.format, table.concat

local PACK = "alfa-oficios"
Of.PACK = PACK

local function num(v)
	if v == nil or N.Secreto(v) then return nil end
	return tonumber(v)
end
Of.num = num

---------------------------------------------------------------------------
-- Ids y habilidad
---------------------------------------------------------------------------

local porId = {}
for linea, o in pairs(D.OFICIOS) do porId[PACK .. "/" .. o.clave] = linea end

function Of.Id(linea)
	local o = D.OFICIOS[linea]
	return o and (PACK .. "/" .. o.clave) or nil
end
function Of.LineaDe(id) return type(id) == "string" and porId[id] or nil end

function Of.Habilidad(linea)
	local C = M.Motor("Compat")
	if not (C and C.GetSkillRank) then return nil end
	local ok, r, mx = pcall(C.GetSkillRank, linea)
	if not ok then return nil end
	r, mx = num(r), num(mx)
	if not r or not mx or mx <= 0 then return nil end
	return r, mx
end

-- El nombre del oficio en el idioma del cliente.
local ES = { [186] = "Minería", [182] = "Herboristería", [393] = "Desuello", [164] = "Herrería", [171] = "Alquimia",
	[197] = "Sastrería", [165] = "Peletería", [202] = "Ingeniería", [333] = "Encantamiento", [185] = "Cocina", [129] = "Primeros auxilios" }
function Of.Nombre(linea)
	local C = M.Motor("Compat")
	local n = C and C.GetSkillLineName and C.GetSkillLineName(linea)
	if type(n) == "string" and n ~= "" and not N.Secreto(n) then return n end
	local AL = A.L
	local o = D.OFICIOS[linea]
	local en = o and o.en
	local t = en and type(AL) == "table" and rawget(AL, en)
	if type(t) == "string" then return t end
	return L[ES[linea] or "?"]
end

local function jugador()
	local C = M.Motor("Compat")
	return C and C.GetPlayerInfo and C.GetPlayerInfo() or {}
end
Of.Jugador = jugador

local function codigoFaccion(p)
	return (p.faction == "Alliance" and "A") or (p.faction == "Horde" and "H") or nil
end
Of.CodigoFaccion = codigoFaccion

---------------------------------------------------------------------------
-- Lo que tienes: aquí (bolsas y banco) y en tus otros personajes (Bolsas)
---------------------------------------------------------------------------

function Of.Aqui(id)
	local B = rawget(_G, "AlfaBolsas")
	if type(B) == "table" and type(B.Cuantos) == "function" then
		local ok, n = pcall(B.Cuantos, id)
		if ok and type(n) == "number" then return n end
	end
	local CI = rawget(_G, "C_Item")
	local f = (type(CI) == "table" and CI.GetItemCount) or rawget(_G, "GetItemCount")
	if type(f) == "function" then
		local ok, n = pcall(f, id, true)
		if ok then return num(n) or 0 end
	end
	return 0
end

-- -> total, { { nombre, n }, ... } de tus otros personajes de esta facción
function Of.Otros(id)
	local B = rawget(_G, "AlfaBolsas")
	if not (type(B) == "table" and type(B.QuienTiene) == "function") then return 0, {} end
	local ok, lista = pcall(B.QuienTiene, id)
	if not ok or type(lista) ~= "table" then return 0, {} end
	local total, quien = 0, {}
	for _, x in ipairs(lista) do
		local n = (tonumber(x.bolsas) or 0) + (tonumber(x.banco) or 0)
		if n > 0 and not x.otraFaccion then
			total = total + n
			quien[#quien + 1] = { nombre = x.nombre, n = n }
		end
	end
	table.sort(quien, function(a, b) return a.n > b.n end)
	return total, quien
end

function Of.Precio(id)
	local C = rawget(_G, "AlfaComercio")
	if type(C) == "table" and type(C.PrecioSubasta) == "function" then
		local ok, p = pcall(C.PrecioSubasta, id)
		if ok and type(p) == "number" and p > 0 then return p end
	end
	return nil
end

---------------------------------------------------------------------------
-- El contexto de una guía en armado: tokens y la guía del motor
---------------------------------------------------------------------------

local function nombreSuelto(kind, id)
	if kind == "item" then
		local CI = rawget(_G, "C_Item")
		local n = type(CI) == "table" and CI.GetItemNameByID and CI.GetItemNameByID(id)
		if type(n) ~= "string" then n = M.NombreObjeto and M.NombreObjeto(id) end
		if type(n) == "string" and n ~= "" and not N.Secreto(n) then return n end
	elseif kind == "zone" then
		local n = M.Zona and M.Zona(id)
		if type(n) == "string" and n ~= "" then return n end
	elseif kind == "skill" then
		local o = D.OFICIOS[id]
		return o and o.en
	elseif kind == "spell" then
		local CS = rawget(_G, "C_Spell")
		local n = type(CS) == "table" and CS.GetSpellName and CS.GetSpellName(id)
		if type(n) == "string" and n ~= "" and not N.Secreto(n) then return n end
	end
	return nil
end

-- "{kind:id}" y su nombre en inglés (el motor lo pone en el idioma del cliente).
function Of.Tok(ctx, kind, id, en)
	local k = kind .. ":" .. tostring(id)
	if not ctx.names[k] then
		ctx.names[k] = (type(en) == "string" and en ~= "" and en) or ctx.motorNames[k] or nombreSuelto(kind, id) or ("#" .. tostring(id))
	end
	return "{" .. k .. "}"
end

-- Lee la guía del motor de este oficio: sus pasos que son para ti, sus
-- instructores por rango, lo que se compra y lo que se junta (por objeto).
local function leerMotor(ctx)
	ctx.pasosMotor, ctx.trenes, ctx.compras, ctx.recoger = {}, {}, {}, {}
	local Gd = A.Guides
	local g = Gd and Gd.Get and Gd.Get(ctx.of.motor)
	if not g then return false end
	local ok, steps = pcall(function() return g.steps end)
	if not ok or type(steps) ~= "table" then return false end
	if type(g.names) == "table" then
		for k, v in pairs(g.names) do ctx.motorNames[k] = v end
	end
	local Gm = Gd.Matches
	for _, s in ipairs(steps) do
		if type(s) == "table" and (not Gm or Gm(s.only, ctx.p)) then
			ctx.pasosMotor[#ctx.pasosMotor + 1] = s
			for _, goal in ipairs(s.goals or {}) do
				if goal.t == "train" and type(goal.rank) == "number" and not ctx.trenes[goal.rank] then
					ctx.trenes[goal.rank] = goal
				elseif goal.t == "buy" and goal.item and not ctx.compras[goal.item] then
					ctx.compras[goal.item] = goal
				elseif goal.t == "collect" and goal.item and not goal.quest then
					local l = ctx.recoger[goal.item] or {}
					ctx.recoger[goal.item] = l
					l[#l + 1] = goal
				end
			end
		end
	end
	return true
end

-- Una copia de una meta del motor, con sus candidatos solo de tu facción.
function Of.Copiar(ctx, goal, extra)
	local c = M.Copia(goal)
	setmetatable(c, nil)
	if type(goal.spotsPacked) == "string" then c.spotsPacked = goal.spotsPacked c.spots = nil end
	if type(c.candidates) == "table" then
		local Gd = A.Guides
		local out = {}
		for _, x in ipairs(c.candidates) do
			if not (Gd and Gd.CandidateMatches) or Gd.CandidateMatches(x, ctx.p) then out[#out + 1] = x end
		end
		c.candidates = #out > 0 and out or c.candidates
	end
	for k, v in pairs(extra or {}) do c[k] = v end
	return c
end

function Of.Ctx(linea)
	local o = D.OFICIOS[linea]
	if not o then return nil end
	local p = jugador()
	local rank, mx = Of.Habilidad(linea)
	local ctx = { linea = linea, of = o, p = p, fac = codigoFaccion(p), nivel = p.level or 1, rank = rank or 0, max = mx or 0,
		conoce = rank ~= nil, names = {}, motorNames = {}, steps = {} }
	ctx.motorOk = leerMotor(ctx)
	ctx.skillTok = Of.Tok(ctx, "skill", linea, o.en)
	return ctx
end

-- El tramo (1-4) de una habilidad: 75 ya es del segundo.
function Of.Tramo(h)
	for i, t in ipairs(D.TRAMOS) do
		if h < t[2] then return i end
	end
	return #D.TRAMOS
end

-- Un paso; hasta: la habilidad con la que se salta solo.
function Of.Paso(ctx, tramo, titulo, nota, metas, hasta)
	local s = { title = titulo, note = nota, section = tramo, goals = metas }
	if hasta then s.when = { { k = "skill", name = ctx.of.en, skillLine = ctx.linea, n = hasta, neg = true } } end
	ctx.steps[#ctx.steps + 1] = s
	return s
end

function Of.MetaHabilidad(ctx, nivel)
	return { t = "skill", skill = ctx.of.en, skillLine = ctx.linea, level = nivel }
end

-- El paso del instructor para el rango r (1 Aprendiz ... 4 Artesano); tramo: su sección
-- (de fábrica, la de la habilidad con que se aprende).
function Of.PasoRango(ctx, r, extra, tramo)
	local rg = D.RANGOS[r]
	if not rg then return nil end
	local metas = {}
	if rg.nivel > 1 then metas[#metas + 1] = { t = "level", level = rg.nivel } end
	local tren = ctx.trenes[r]
	if tren then
		metas[#metas + 1] = Of.Copiar(ctx, tren)
	else
		metas[#metas + 1] = { t = "train", skill = ctx.of.en, skillLine = ctx.linea, rank = r }
	end
	for _, g in ipairs(extra or {}) do metas[#metas + 1] = g end
	local titulo, nota
	if r == 1 then
		titulo = format(L["Aprende %s"], ctx.skillTok)
		nota = L["Cualquier instructor de tu facción te lo enseña, a cualquier nivel; la flecha te lleva al más cercano."]
	else
		titulo = format(L["Rango %s: tu tope sube a %d"], L[rg.nombre], rg.tope)
		nota = format(L["Lo aprendes con habilidad %d y nivel %d. No todos los instructores lo enseñan: la flecha te lleva al más cercano de tu facción que sí."], rg.desde, rg.nivel)
	end
	return Of.Paso(ctx, tramo or Of.Tramo(rg.desde), titulo, nota, metas)
end

---------------------------------------------------------------------------
-- Armar
---------------------------------------------------------------------------

function Of.Def(ctx)
	local o = ctx.of
	local secciones = {}
	for i, t in ipairs(D.TRAMOS) do secciones[i] = { skill = o.en, skillLine = ctx.linea, from = t[1], to = t[2] } end
	local fac = ctx.p.faction
	return {
		id = Of.Id(ctx.linea), pack = PACK,
		title = ctx.skillTok .. " 1-300",
		category = "Professions", author = "Alfa", version = 1,
		faction = (fac == "Alliance" or fac == "Horde") and fac or nil,
		minLevel = o.tipo == "juntar" and 1 or 5, maxLevel = 60,
		pitch = o.tipo == "juntar" and L["Por tramos: la mejor zona para tu nivel con su ruta, qué da puntos y cuándo ir al instructor."]
			or L["Por tramos: qué receta hacer y cuántas, tus materiales con lo que ya tienes descontado y dónde comprar lo demás."],
		keywords = { L["profesión"], L["oficio"], o.en, Of.Nombre(ctx.linea), "alfa" },
		sections = secciones, names = ctx.names, steps = ctx.steps,
	}
end

function Of.Armar(linea)
	local ctx = Of.Ctx(linea)
	if not ctx then return nil, "oficio" end
	local armador = ctx.of.tipo == "juntar" and M.OficiosJuntar or M.OficiosCrear
	if not armador then return nil, "armador" end
	local ok, err = pcall(armador.Armar, ctx)
	if not ok then
		if A.Debug then A.Debug("Oficios: " .. tostring(err)) end
		return nil, "error", err
	end
	if #ctx.steps == 0 then return nil, "vacia" end
	return Of.Def(ctx), ctx
end

---------------------------------------------------------------------------
-- El paquete, las fichas y abrir
---------------------------------------------------------------------------

local registrado = false
local armadas = {} -- id -> true: ya tiene sus pasos de verdad (esta sesión)

local function paquete()
	if registrado then return true end
	if type(A.RegisterPack) ~= "function" then return false end
	local ok = A.RegisterPack({
		addon = ADDON, id = PACK, format = 9, title = L["Guías de oficios de Alfa"], author = "Alfa",
		version = tostring(N.version or "1"), license = "GPL-3.0-only",
		notes = L["Una guía por oficio, por tramos, armada para tu personaje al abrirla."],
	})
	registrado = ok and true or false
	return registrado
end

local function avisarMotor()
	if A.IsLoggedIn and A.IsLoggedIn() then
		A.Fire("GUIDES_REGISTERED")
		A.Fire("PACKS_CHANGED", PACK)
	end
end

-- La ficha de cada oficio: lo que la Biblioteca enseña antes de abrirla.
local function ficha(linea)
	local o = D.OFICIOS[linea]
	local names = { ["skill:" .. linea] = o.en }
	local tok = "{skill:" .. linea .. "}"
	return {
		id = Of.Id(linea), pack = PACK, title = tok .. " 1-300", category = "Professions",
		author = "Alfa", version = 1, minLevel = o.tipo == "juntar" and 1 or 5, maxLevel = 60,
		pitch = o.tipo == "juntar" and L["Por tramos: la mejor zona para tu nivel con su ruta, qué da puntos y cuándo ir al instructor."]
			or L["Por tramos: qué receta hacer y cuántas, tus materiales con lo que ya tienes descontado y dónde comprar lo demás."],
		keywords = { L["profesión"], L["oficio"], o.en, Of.Nombre(linea), "alfa" }, names = names,
		steps = { { title = format(L["Preparando tu guía de %s…"], tok),
			goals = { { t = "note", text = L["Alfa la arma con tu habilidad, tu nivel y lo que tienes. Si no cambia en un momento, ábrela otra vez desde la Biblioteca."] } } } },
	}
end

function Of.Fichas()
	if not paquete() then return false end
	for _, linea in ipairs(D.ORDEN) do
		local id = Of.Id(linea)
		if not armadas[id] then A.RegisterGuide(ficha(linea)) end
	end
	return true
end

-- Arma y registra la guía de un oficio. -> ok, motivo
function Of.Instalar(linea)
	if not paquete() then return false, "paquete" end
	local def, ctx = Of.Armar(linea)
	if not def then return false, ctx end
	local ok, err = A.RegisterGuide(def)
	if not ok then return false, err end
	armadas[def.id] = true
	Of.ultimo = { linea = linea, def = def }
	avisarMotor()
	return true
end

-- La Biblioteca (y quien abra una de nuestras fichas): la arma antes.
function Of.Preparar(id)
	local linea = Of.LineaDe(id)
	if not linea then return false end
	if InCombatLockdown and InCombatLockdown() then return false end
	return (Of.Instalar(linea))
end

function Of.Abrir(linea)
	linea = tonumber(linea)
	if not (linea and D.OFICIOS[linea]) then return false end
	if InCombatLockdown and InCombatLockdown() then
		M.Aviso(L["Guía de oficio"], L["Se puede al salir de combate."], { icono = "ic-aviso", tono = "aviso" })
		return false
	end
	local ok, motivo = Of.Instalar(linea)
	if not ok then
		M.Aviso(L["Guía de oficio"], L["No pude armar esta guía ahora. Prueba de nuevo en un momento; si sigue, /alfa diagnostico lo revisa."], { icono = "ic-aviso", tono = "aviso" })
		return false, motivo
	end
	local id = Of.Id(linea)
	if M.Biblioteca and M.Biblioteca.Reciente then M.Biblioteca.Reciente(id) end
	local i = M.Guias and M.Guias.Abrir and M.Guias.Abrir(id)
	return i ~= nil
end

function Of.Tiene(linea) return D.OFICIOS[tonumber(linea) or 0] ~= nil end

-- Las guías del motor que estas reemplazan (la Biblioteca no las repite).
local REEMPLAZA = {}
for _, o in pairs(D.OFICIOS) do REEMPLAZA[o.motor] = true end
function Of.Oculta(g)
	return type(g) == "table" and REEMPLAZA[g.id] == true and registrado
end

-- Tus oficios: { { linea, rank, max }, ... } (los principales primero, por habilidad).
function Of.Mios()
	local out = {}
	for _, linea in ipairs(D.ORDEN) do
		local r, mx = Of.Habilidad(linea)
		if r then out[#out + 1] = { linea = linea, rank = r, max = mx, secundario = D.OFICIOS[linea].secundario } end
	end
	table.sort(out, function(a, b)
		if (a.secundario and true or false) ~= (b.secundario and true or false) then return not a.secundario end
		return a.rank < b.rank
	end)
	return out
end

-- El primer paso que te falta (para el Asistente): título | nil. Arma la guía.
function Of.SiguientePaso(linea)
	local def = Of.Armar(linea)
	if not def then return nil end
	local r = Of.Habilidad(linea) or 0
	for _, s in ipairs(def.steps) do
		local hasta = s.when and s.when[1] and s.when[1].n
		if not hasta or r < hasta then return s.title, def end
	end
	return nil, def
end

---------------------------------------------------------------------------
-- Al cargar: las fichas; una ficha abierta por el motor se arma sola
---------------------------------------------------------------------------

Of.Fichas()

local function revisarAbierta(id)
	local E = M.Motor("Engine")
	id = id or (E and E.GetGuide and E.GetGuide() and E.GetGuide().id)
	if type(id) ~= "string" or not Of.LineaDe(id) or armadas[id] then return end
	local linea = Of.LineaDe(id)
	N.FueraDeCombate("rutas.oficioAbierto", function() Of.Instalar(linea) end)
end
A.On("GUIDE_CHANGED", function(id) revisarAbierta(id) end)
A.OnLogin(function()
	if N.Una then N.Una("rutas.oficioAbierto", 3, function() revisarAbierta() end) end
end)

AlfaRuta = type(rawget(_G, "AlfaRuta")) == "table" and rawget(_G, "AlfaRuta") or {}
AlfaRuta.GuiaOficio = function(linea) return Of.Abrir(linea) end
AlfaRuta.TieneGuiaOficio = function(linea) return Of.Tiene(linea) end
