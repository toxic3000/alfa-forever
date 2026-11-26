-- Alfa - Rutas: la biblioteca de guías (toxic3000 / La Jauría). GPL-3.0.
--
-- Reemplaza el selector de guías del motor (SHOW_PICKER, docs/KIT.md). Una
-- ventana del Kit: arriba, en grande, la guía que Alfa recomienda para tu
-- nivel y tu zona (Guides.Suggest); debajo, las demás en tarjetas, con un
-- buscador y las categorías en segmentos (Para ti, Subir de nivel,
-- Profesiones, Clase, Reputación, Coleccionables, Mis rutas, Todas). Solo
-- salen las guías que son para tu personaje (facción, raza y clase).
-- Un clic en una tarjeta la abre: en la pestaña de ahora o en una nueva
-- (pedido.pestanaNueva, el + del rastreador).

local ADDON, M = ...
local A, L, N = M.A, M.L, M.N
local K = M.K
local B = {}
M.Biblioteca = B

local type, ipairs, pairs, tostring, tonumber = type, ipairs, pairs, tostring, tonumber
local floor, max, min, format, lower = math.floor, math.max, math.min, string.format, string.lower

local PAGINA = 24 -- tarjetas por tanda ("Ver más")

local v -- la ventana
local ui = {}
local est = { cat = "parati", buscar = "", nueva = false, cuantas = PAGINA }

local function G() return A.Guides end
local function E() return A.Engine end
local function U() return A.UI end

local CATS = {
	{ valor = "parati", texto = L["Para ti"] },
	-- 1.3.7: las que abriste hace poco y tus favoritas (95).
	{ valor = "recientes", texto = L["Recientes"] },
	{ valor = "favoritas", texto = L["Favoritas"] },
	{ valor = "Leveling", texto = L["Subir de nivel"] },
	{ valor = "Professions", texto = L["Profesiones"] },
	{ valor = "Class", texto = L["Clase"] },
	{ valor = "Reputation", texto = L["Reputación"] },
	{ valor = "Collectibles", texto = L["Coleccionables"] },
	{ valor = "mias", texto = L["Mis rutas"] },
	{ valor = "todas", texto = L["Todas"] },
}

local ICONO = { Leveling = "ic-nivel", Professions = "ic-oficios", Class = "ic-talentos", Reputation = "ic-manada",
	Collectibles = "ic-bolsas", Exploration = "ic-mapa", Miscellaneous = "ic-guia" }
local TONO = { Leveling = "exito", Professions = "aviso", Class = "clase", Reputation = "acento", Collectibles = "raro", Exploration = "acento" }

local function jugador()
	local C = M.Motor("Compat")
	return C and C.GetPlayerInfo and C.GetPlayerInfo() or {}
end

local function categoria(g)
	if g.pack == M.PACK then return "mias" end
	local c = g.category
	if type(c) ~= "string" or c == "" then return "Leveling" end
	return c
end

local function etiqueta(g)
	local u = U()
	return u and u.GuideLabel and u.GuideLabel(g) or g.title or g.id
end

local function nombreCat(c)
	for _, x in ipairs(CATS) do if x.valor == c then return x.texto end end
	local EL = A.L
	return (type(EL) == "table" and EL[c]) or c
end

-- ¿Está abierta en una pestaña? -> índice
local function pestana(id)
	local e = E()
	local tabs = e and e.GetTabs and e.GetTabs() or {}
	for i, t in ipairs(tabs) do if t.guideId == id then return i end end
	return nil
end

---------------------------------------------------------------------------
-- 1.3.7: recientes y favoritas, por personaje (M.Personaje().biblioteca)
---------------------------------------------------------------------------

local RECIENTES = 8

local function mias()
	local d = M.Personaje()
	if type(d.biblioteca) ~= "table" then d.biblioteca = {} end
	local b = d.biblioteca
	if type(b.recientes) ~= "table" then b.recientes = {} end
	if type(b.fav) ~= "table" then b.fav = {} end
	return b
end

function B.Reciente(id)
	if type(id) ~= "string" then return end
	local r = mias().recientes
	for i = #r, 1, -1 do if r[i] == id then table.remove(r, i) end end
	table.insert(r, 1, id)
	while #r > RECIENTES do table.remove(r) end
end

function B.EsFavorita(id) return id ~= nil and mias().fav[id] == true end
function B.Favorita(id, si)
	if type(id) ~= "string" then return end
	if si == nil then si = not B.EsFavorita(id) end
	mias().fav[id] = si and true or nil
	if B.Visible and B.Visible() then B.Pintar() end
end

-- Abre una guía: la pestaña donde ya está, una nueva o la de ahora.
function B.Seguir(id, nueva)
	local e = E()
	if not (e and id) then return end
	-- 1.3.9 (oficios): una guía de oficio de Alfa se arma antes de abrirla.
	if M.OficiosGuia and M.OficiosGuia.Preparar then M.OficiosGuia.Preparar(id) end
	B.Reciente(id)
	local i = pestana(id)
	if i then
		if e.SelectTab then e.SelectTab(i) end
	elseif nueva and e.OpenTab then
		if not e.OpenTab(id, true) then
			M.EnCurso.AvisoLleno() -- 1.3.7: con «Ver lo que sigues»
			return
		end
	elseif e.SetGuide then
		e.SetGuide(id)
	end
	if v then v:Cerrar() end
	M.Empezar()
end

---------------------------------------------------------------------------
-- Qué se muestra
---------------------------------------------------------------------------

local function plegar(s) return M.Plegar(s or "") end

-- 1.3.7: las misiones de una guía y quién las da y las recibe, en un texto
-- para buscar (94). Sale de la ficha de la guía (qref, sin armar sus pasos)
-- y de la base de misiones (sin cargarla: si no está, no hay). Se arma una
-- vez por guía, la primera vez que se busca con 3 letras o más.
local textoMisiones = {}
local function misionesDe(g)
	local t = textoMisiones[g.id]
	if t ~= nil then return t or nil end
	local Q = M.Motor("QuestDB")
	local ref = rawget(g, "qref")
	local ids = type(ref) == "table" and type(ref.q) == "table" and ref.q or nil
	if not (ids and Q and Q.IsLoaded and Q.IsLoaded() and Q.GetQuestTitle) then return nil end
	local partes, vistos = {}, {}
	local function poner(s)
		if type(s) == "string" and s ~= "" and not vistos[s] then
			vistos[s] = true
			partes[#partes + 1] = plegar(s)
		end
	end
	for _, q in ipairs(ids) do
		local ok, titulo = pcall(Q.GetQuestTitle, q)
		if ok then poner(titulo) end
		local r = Q.QuestRecord and Q.QuestRecord(q)
		if type(r) == "table" and Q.F and Q.EntityName then
			for _, campo in ipairs({ Q.F.START, Q.F.FINISH }) do
				local v = r[campo]
				local lista = type(v) == "table" and v or { v }
				for _, ent in ipairs(lista) do
					if type(ent) == "number" and ent ~= 0 then
						local okN, n = pcall(Q.EntityName, ent)
						if okN then poner(n) end
					end
				end
			end
		end
	end
	t = table.concat(partes, "\n")
	textoMisiones[g.id] = t
	return t
end

local function coincide(g, q)
	if q == "" then return true end
	if plegar(g.title):find(q, 1, true) then return true end
	if g.zoneName and plegar(g.zoneName):find(q, 1, true) then return true end
	for _, k in ipairs(g.keywords or {}) do if plegar(k):find(q, 1, true) then return true end end
	-- 1.3.7: por el nombre de una misión o de un PNJ (94).
	if #q >= 3 and not (InCombatLockdown and InCombatLockdown()) then
		local t = misionesDe(g)
		if t and t:find(q, 1, true) then return true end
	end
	return false
end

-- -> recomendada (header | nil), lista
local function datos()
	local Gd = G()
	if not Gd then return nil, {} end
	local p = jugador()
	local nivel = p.level or 1
	local sugeridas = Gd.Suggestions and Gd.Suggestions() or {}
	local primera = sugeridas[1] and Gd.Get(sugeridas[1])
	local rango = {}
	for i, id in ipairs(sugeridas) do rango[id] = i end
	local q = plegar(est.buscar)
	local out = {}
	-- 1.3.7: «Guías con esta misión»: solo las que la tocan (75).
	local conMision
	if est.mision then
		conMision = {}
		for _, k in ipairs({ "q", "p" }) do
			local ids = Gd.QuestGuides and Gd.QuestGuides(k, est.mision)
			for _, id in ipairs(ids or {}) do conMision[id] = true end
		end
	end
	local b = mias()
	local reciente = {}
	for i, id in ipairs(b.recientes) do reciente[id] = i end
	for _, g in ipairs(Gd.List and Gd.List() or {}) do
		local mia = g.pack == M.PACK
		local para = mia or not Gd.GuideMatches or Gd.GuideMatches(g, p)
		-- 1.3.9 (oficios): la guía de Alfa de cada oficio reemplaza la del motor.
		if para and M.OficiosGuia and M.OficiosGuia.Oculta(g) then para = false end
		if para and (not conMision or conMision[g.id]) and coincide(g, q) then
			local c = categoria(g)
			local entra
			if conMision or est.cat == "todas" then
				entra = true
			elseif est.cat == "recientes" then
				entra = reciente[g.id] ~= nil
			elseif est.cat == "favoritas" then
				entra = b.fav[g.id] == true
			elseif est.cat == "parati" then
				-- Para ti: tus rutas, las sugeridas y las de subir de nivel o de
				-- tu clase que van con tu nivel (no las de todo el juego).
				local lo, hi = g.minLevel or 1, g.maxLevel or g.minLevel or 60
				entra = mia or rango[g.id] ~= nil
					or ((c == "Leveling" or c == "Class") and nivel >= lo - 1 and nivel <= hi and (hi - lo) < 40)
			else
				entra = c == est.cat
			end
			local sinReco = conMision or est.cat == "recientes" or est.cat == "favoritas"
			if entra and (sinReco or not (primera and g.id == primera.id and q == "")) then out[#out + 1] = g end
		end
	end
	table.sort(out, function(a, b)
		if est.cat == "recientes" and not conMision then return (reciente[a.id] or 99) < (reciente[b.id] or 99) end
		local ra, rb = rango[a.id] or 999, rango[b.id] or 999
		if ra ~= rb then return ra < rb end
		local la, lb = a.minLevel or 0, b.minLevel or 0
		if la ~= lb then return la < lb end
		return tostring(a.title) < tostring(b.title)
	end)
	local sinReco = conMision or est.cat == "recientes" or est.cat == "favoritas"
	return (q == "" and not sinReco) and primera or nil, out
end

-- 1.3.7: cómo vas con una guía (92): «Terminada», «Paso 12 de 80»,
-- «Empezada» o nada (nueva). -> texto, tono | nil
local function estadoDe(g)
	local e = E()
	if not (e and e.GetGuideState) then return nil end
	local ok, st, hechos, todos = pcall(e.GetGuideState, g.id)
	if not ok then return nil end
	if st == "done" then return L["Terminada"], "exito" end
	if st == "started" then
		if tonumber(todos) and todos > 0 then return format(L["Paso %d de %d"], math.min((hechos or 0) + 1, todos), todos), "acento" end
		return L["Empezada"], "acento"
	end
	return nil
end
B.EstadoDe = estadoDe

-- 1.3.7: «≈ 2 h a tu ritmo» (96): sus pasos por lo que tardas en cada uno.
local function tiempoDe(g)
	local H = M.Hora
	local n = tonumber(rawget(g, "stepCount")) or (type(rawget(g, "steps")) == "table" and #g.steps) or nil
	local m = H and H.EstimadoPasos and n and H.EstimadoPasos(n)
	if not m then return nil end
	if m >= 60 then m = floor(m / 5 + 0.5) * 5 end
	return format(L["≈ %s a tu ritmo"], N.Duracion(m * 60, true))
end
B.TiempoDe = tiempoDe

local function tarjeta(g)
	local c = categoria(g)
	local u = U()
	local abierta = pestana(g.id) ~= nil
	local ins = {}
	local lv = u and u.LevelRange and u.LevelRange(g.minLevel, g.maxLevel)
	if lv then ins[#ins + 1] = { format(L["Nivel %s"], lv), "neutro" } end
	local st, tono = estadoDe(g)
	if st then ins[#ins + 1] = { st, tono } elseif abierta then ins[#ins + 1] = { L["Abierta"], "acento" } end
	if B.EsFavorita(g.id) then ins[#ins + 1] = { L["Favorita"], "oro" } end
	local lugar = u and u.GuidePlace and u.GuidePlace(g)
	return {
		icono = c == "mias" and "ic-ruta" or (ICONO[c] or "ic-guia"), tono = c == "mias" and "acento" or (TONO[c] or "acento"),
		titulo = g.title or g.id, texto = lugar or nombreCat(c), insignias = ins,
		-- 1.3.7: el clic enseña su detalle antes de cargarla (93).
		alClic = function() B.Detalle(g.id) end,
		ayuda = g.pitch,
	}
end

---------------------------------------------------------------------------
-- 1.3.7: el detalle de una guía antes de cargarla (93): de qué trata, sus
-- zonas, cuántos pasos, cómo vas, cuánto te toma y qué sigue. No arma sus
-- pasos ni carga nada: todo sale de su ficha.
---------------------------------------------------------------------------

local det -- { v, tarjeta, texto, id }

function B.LineasDetalle(g)
	local u = U()
	local lineas = {}
	if g.pitch and g.pitch ~= "" then lineas[#lineas + 1] = g.pitch end
	if u and type(u.GuideMeta) == "function" then
		local ok, meta = pcall(u.GuideMeta, g)
		if ok and type(meta) == "string" and meta ~= "" then lineas[#lineas + 1] = meta end
	end
	local zonas, vistas = {}, {}
	for _, z in ipairs({ g.zoneName, unpack(type(rawget(g, "zones")) == "table" and g.zones or {}) }) do
		if type(z) == "string" and z ~= "" and not vistas[z] then vistas[z] = true zonas[#zonas + 1] = z end
	end
	if #zonas > 0 then lineas[#lineas + 1] = format(L["Zonas: %s"], table.concat(zonas, ", ")) end
	local n = tonumber(rawget(g, "stepCount")) or (type(rawget(g, "steps")) == "table" and #g.steps) or nil
	if n and n > 0 then lineas[#lineas + 1] = M.Plural(n, L["%d paso"], L["%d pasos"]) end
	local ref = rawget(g, "qref")
	local nq = type(ref) == "table" and type(ref.q) == "table" and #ref.q or 0
	if nq > 0 then lineas[#lineas + 1] = M.Plural(nq, L["Toca %d misión"], L["Toca %d misiones"]) end
	local st = estadoDe(g)
	if st then lineas[#lineas + 1] = format(L["Cómo vas: %s"], st) end
	local t = tiempoDe(g)
	if t then lineas[#lineas + 1] = t end
	local sig = type(rawget(g, "next")) == "string" and M.NombreGuia and M.NombreGuia(g.next) or nil
	if sig then lineas[#lineas + 1] = format(L["Después sigue: %s"], sig) end
	return lineas
end

function B.Detalle(id)
	local Gd = G()
	local g = Gd and Gd.Get and Gd.Get(id)
	if not g then return end
	if not det then
		det = {}
		det.v = K.Ventana({ nombre = "AlfaBibliotecaDetalle", titulo = L["Detalle de la guía"], icono = "ic-guia", ancho = 460, alto = 400 })
		det.tarjeta = K.Tarjeta(det.v.Cuerpo, { variante = "accion" })
		det.texto = K.Texto(det.v.Cuerpo, "cuerpo", "textoSuave")
		det.texto:SetWordWrap(true)
		det.texto:SetJustifyH("LEFT")
		function det.Acomodar()
			local m, ancho = det.v.margen, det.v:AnchoCuerpo()
			det.tarjeta:ClearAllPoints()
			det.tarjeta:SetPoint("TOPLEFT", det.v.Cuerpo, "TOPLEFT", m, -K.ESP.base)
			det.tarjeta:SetWidth(ancho)
			det.tarjeta:Acomodar(ancho)
			det.texto:ClearAllPoints()
			det.texto:SetPoint("TOPLEFT", det.tarjeta, "BOTTOMLEFT", 0, -K.ESP.m)
			K.Parrafo(det.texto, ancho, 12)
		end
		det.v.alAcomodar = function() det.Acomodar() end
	end
	det.id = id
	local abierta = pestana(id) ~= nil
	local u = U()
	local lv = u and u.LevelRange and u.LevelRange(g.minLevel, g.maxLevel)
	local fav = B.EsFavorita(id)
	det.tarjeta:Set({ icono = "ic-guia", sobre = lv and format(L["Nivel %s"], lv) or nombreCat(categoria(g)), titulo = g.title or g.id,
		accion = { texto = abierta and L["Continuar"] or L["Seguir esta guía"], icono = "ic-seguir", alClic = function()
			det.v:Cerrar()
			B.Seguir(id, est.nueva)
		end },
		secundaria = { texto = fav and L["Quitar de favoritas"] or L["Agregar a favoritas"], alClic = function()
			B.Favorita(id)
			B.Detalle(id)
		end } })
	K.Escribir(det.texto, table.concat(B.LineasDetalle(g), "\n"))
	det.v:SetTitulo(L["Detalle de la guía"], nil, "ic-guia")
	if not det.v:IsShown() then det.v:Abrir() end
	det.Acomodar()
	return det
end
function B.DatosBanco() return datos() end -- (para el banco)
function B.DetalleVisible() return det ~= nil and det.v:IsShown() and det.id or nil end

---------------------------------------------------------------------------
-- La ventana
---------------------------------------------------------------------------

local function construir()
	v = K.Ventana({ nombre = "AlfaBiblioteca", titulo = L["Guías"], subtitulo = L["La recomendada para ti y todas las demás"],
		icono = "ic-guia", ancho = 900, alto = 620, desplazar = true })
	local c = v.Cuerpo
	ui.pila = K.Pila(c, { espacio = K.ESP.l })
	ui.barra = CreateFrame("Frame", nil, ui.pila)
	ui.buscar = K.Buscador(ui.barra, { ayuda = L["Buscar guías por nombre, zona, misión o PNJ"], alCambiar = function(t)
		est.buscar = t or ""
		est.cuantas = PAGINA
		B.Pintar()
	end })
	ui.cats = K.Segmentos(ui.barra, { estilo = "pildoras", opciones = CATS, valor = est.cat, alCambiar = function(val)
		est.cat = val
		est.mision = nil
		est.cuantas = PAGINA
		B.Pintar()
	end })
	function ui.barra:Acomodar(ancho)
		ui.buscar:ClearAllPoints()
		ui.buscar:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
		ui.buscar:SetWidth(ancho)
		local sh = ui.cats:Acomodar(ancho)
		ui.cats:ClearAllPoints()
		ui.cats:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -(K.ALTO.control + K.ESP.m))
		local h = K.ALTO.control + K.ESP.m + sh
		self:SetHeight(h)
		return h
	end
	ui.pila:Agregar(ui.barra)
	-- 1.3.7: el filtro «Guías con esta misión», con su «Ver todas» (75).
	ui.filtro = ui.pila:Agregar(K.Boton(ui.pila, "", function()
		est.mision = nil
		B.Pintar()
	end, { tipo = "secundario", tam = "chico", icono = "ic-cerrar" }))
	ui.filtro.alfaAnchoPropio = true
	ui.reco = ui.pila:Agregar(K.Tarjeta(ui.pila, { variante = "accion" }))
	ui.seccion = ui.pila:Agregar(K.Seccion(ui.pila, L["Más guías"]))
	ui.rejilla = ui.pila:Agregar(K.Rejilla(ui.pila, { min = 250, gap = K.ESP.base }), { espacio = K.ESP.m })
	ui.vacio = ui.pila:Agregar(K.Vacio(ui.pila, { lobo = "vacio", titulo = L["No hay guías así"], texto = L["Prueba con otra palabra o elige Todas."],
		-- 1.4.1: el texto pide «Todas»: aquí está el botón.
		accion = { texto = L["Ver todas"], icono = "ic-guia", alClic = function()
			est.cat, est.buscar, est.cuantas, est.mision = "todas", "", PAGINA, nil
			ui.cats:SetValor("todas")
			if ui.buscar.SetTexto then pcall(ui.buscar.SetTexto, ui.buscar, "") end
			B.Pintar()
		end } }))
	ui.mas = ui.pila:Agregar(K.Boton(ui.pila, L["Ver más"], function() est.cuantas = est.cuantas + PAGINA B.Pintar() end, { tipo = "secundario" }))
	ui.mas.alfaAnchoPropio = true
	v.alAcomodar = function() B.Pintar() end
	v:SetPie({ K.Boton(v, L["Cerrar"], function() v:Cerrar() end, { tipo = "fantasma" }) },
		{ K.Boton(v, L["¿Qué quieres hacer?"], function() v:Cerrar() if M.Asistente then M.Asistente.Abrir() end end, { tipo = "secundario", icono = "ic-lobo" }) })
end

function B.Pintar()
	if not (v and v:IsShown()) then return end
	local reco, lista = datos()
	if reco then
		local u = U()
		local abierta = pestana(reco.id) ~= nil
		local lugar = u and u.GuidePlace and u.GuidePlace(reco)
		local lv = u and u.LevelRange and u.LevelRange(reco.minLevel, reco.maxLevel)
		local ins = {}
		if lv then ins[#ins + 1] = { format(L["Nivel %s"], lv), "acento" } end
		if lugar then ins[#ins + 1] = { lugar, "neutro" } end
		local st, tono = estadoDe(reco)
		if st then ins[#ins + 1] = { st, tono } end
		local t = tiempoDe(reco)
		if t then ins[#ins + 1] = { t, "neutro", "ic-reloj" } end
		ui.reco:Set({
			icono = "ic-huella", sobre = L["Recomendada para ti"], titulo = reco.title or reco.id,
			texto = reco.pitch or L["La guía que mejor te queda por tu nivel y donde estás."], insignias = ins,
			accion = { texto = abierta and L["Continuar"] or L["Seguir esta guía"], icono = "ic-seguir", alClic = function() B.Seguir(reco.id, est.nueva) end },
			secundaria = { texto = L["Ver detalle"], alClic = function() B.Detalle(reco.id) end },
		})
	end
	K.Mostrar(ui.reco, reco ~= nil)
	-- 1.3.7: «Guías con esta misión» se quita con un clic (75).
	if ui.filtro then
		K.Mostrar(ui.filtro, est.mision ~= nil)
		if est.mision then ui.filtro:SetTexto(format(L["Con %s · Ver todas"], M.Citar(M.TituloMision(est.mision)))) end
	end
	local datosRej = {}
	for i = 1, min(#lista, est.cuantas) do datosRej[i] = tarjeta(lista[i]) end
	ui.rejilla:Llenar(datosRej)
	ui.seccion:Set(reco and L["Más guías"] or nombreCat(est.cat), { cuenta = #lista })
	K.Mostrar(ui.seccion, #lista > 0)
	K.Mostrar(ui.rejilla, #datosRej > 0)
	K.Mostrar(ui.vacio, #lista == 0 and not reco)
	K.Mostrar(ui.mas, #lista > est.cuantas)
	local ancho = v:AnchoCuerpo()
	ui.pila:ClearAllPoints()
	ui.pila:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", v.margen, -K.ESP.base)
	local h = ui.pila:Acomodar(ancho)
	v:SetAltoContenido(h + 2 * K.ESP.base)
end

-- pedido: { pestanaNueva, alternar, mision }
function B.Abrir(pedido)
	pedido = pedido or {}
	if not v then construir() end
	if pedido.alternar and v:IsShown() then v:Cerrar() return end
	est.nueva = pedido.pestanaNueva and true or false
	if pedido.categoria then
		est.cat, est.cuantas = pedido.categoria, PAGINA
		ui.cats:SetValor(pedido.categoria)
	end
	-- 1.3.7: solo las guías que tocan esa misión, de verdad (75; antes solo
	-- abría «Todas» con un aviso).
	est.mision = tonumber(pedido.mision) or nil
	if est.mision then
		est.cat, est.buscar, est.cuantas = "todas", "", PAGINA
		ui.cats:SetValor("todas")
		if ui.buscar.SetTexto then pcall(ui.buscar.SetTexto, ui.buscar, "") end
	end
	v:SetTitulo(est.nueva and L["Abrir otra guía"] or L["Guías"], L["La recomendada para ti y todas las demás"], "ic-guia")
	v:Abrir()
	B.Pintar()
end

function B.Visible() return v ~= nil and v:IsShown() end

N.Reemplazar("SHOW_PICKER", function(p) B.Abrir(p) end, B.Visible)
A.On("TABS_CHANGED", function() if B.Visible() then B.Pintar() end end)
A.On("GUIDES_REGISTERED", function() if B.Visible() then B.Pintar() end end)
