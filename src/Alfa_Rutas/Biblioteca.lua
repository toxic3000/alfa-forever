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

-- Abre una guía: la pestaña donde ya está, una nueva o la de ahora.
function B.Seguir(id, nueva)
	local e = E()
	if not (e and id) then return end
	local i = pestana(id)
	if i then
		if e.SelectTab then e.SelectTab(i) end
	elseif nueva and e.OpenTab then
		if not e.OpenTab(id, true) then
			M.Aviso(L["Tienes 6 guías abiertas"], L["Cierra una pestaña para abrir otra."], { icono = "ic-aviso", tono = "aviso" })
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

local function coincide(g, q)
	if q == "" then return true end
	if plegar(g.title):find(q, 1, true) then return true end
	if g.zoneName and plegar(g.zoneName):find(q, 1, true) then return true end
	for _, k in ipairs(g.keywords or {}) do if plegar(k):find(q, 1, true) then return true end end
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
	for _, g in ipairs(Gd.List and Gd.List() or {}) do
		local mia = g.pack == M.PACK
		local para = mia or not Gd.GuideMatches or Gd.GuideMatches(g, p)
		if para and coincide(g, q) then
			local c = categoria(g)
			local entra
			if est.cat == "todas" then
				entra = true
			elseif est.cat == "parati" then
				-- Para ti: tus rutas, las sugeridas y las de subir de nivel o de
				-- tu clase que van con tu nivel (no las de todo el juego).
				local lo, hi = g.minLevel or 1, g.maxLevel or g.minLevel or 60
				entra = mia or rango[g.id] ~= nil
					or ((c == "Leveling" or c == "Class") and nivel >= lo - 1 and nivel <= hi and (hi - lo) < 40)
			else
				entra = c == est.cat
			end
			if entra and not (primera and g.id == primera.id and q == "") then out[#out + 1] = g end
		end
	end
	table.sort(out, function(a, b)
		local ra, rb = rango[a.id] or 999, rango[b.id] or 999
		if ra ~= rb then return ra < rb end
		local la, lb = a.minLevel or 0, b.minLevel or 0
		if la ~= lb then return la < lb end
		return tostring(a.title) < tostring(b.title)
	end)
	return q == "" and primera or nil, out
end

local function tarjeta(g)
	local c = categoria(g)
	local u = U()
	local abierta = pestana(g.id) ~= nil
	local ins = {}
	local lv = u and u.LevelRange and u.LevelRange(g.minLevel, g.maxLevel)
	if lv then ins[#ins + 1] = { format(L["Nivel %s"], lv), "neutro" } end
	if abierta then ins[#ins + 1] = { L["Abierta"], "acento" } end
	local lugar = u and u.GuidePlace and u.GuidePlace(g)
	return {
		icono = c == "mias" and "ic-ruta" or (ICONO[c] or "ic-guia"), tono = c == "mias" and "acento" or (TONO[c] or "acento"),
		titulo = g.title or g.id, texto = lugar or nombreCat(c), insignias = ins,
		alClic = function() B.Seguir(g.id, est.nueva) end,
		ayuda = g.pitch,
	}
end

---------------------------------------------------------------------------
-- La ventana
---------------------------------------------------------------------------

local function construir()
	v = K.Ventana({ nombre = "AlfaBiblioteca", titulo = L["Guías"], subtitulo = L["La recomendada para ti y todas las demás"],
		icono = "ic-guia", ancho = 900, alto = 620, desplazar = true })
	local c = v.Cuerpo
	ui.pila = K.Pila(c, { espacio = K.ESP.l })
	ui.barra = CreateFrame("Frame", nil, ui.pila)
	ui.buscar = K.Buscador(ui.barra, { ayuda = L["Buscar guías por nombre o zona"], alCambiar = function(t)
		est.buscar = t or ""
		est.cuantas = PAGINA
		B.Pintar()
	end })
	ui.cats = K.Segmentos(ui.barra, { estilo = "pildoras", opciones = CATS, valor = est.cat, alCambiar = function(val)
		est.cat = val
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
	ui.reco = ui.pila:Agregar(K.Tarjeta(ui.pila, { variante = "accion" }))
	ui.seccion = ui.pila:Agregar(K.Seccion(ui.pila, L["Más guías"]))
	ui.rejilla = ui.pila:Agregar(K.Rejilla(ui.pila, { min = 250, gap = K.ESP.base }), { espacio = K.ESP.m })
	ui.vacio = ui.pila:Agregar(K.Vacio(ui.pila, { lobo = "vacio", titulo = L["No hay guías así"], texto = L["Prueba con otra palabra o elige Todas."] }))
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
		ui.reco:Set({
			icono = "ic-huella", sobre = L["Recomendada para ti"], titulo = reco.title or reco.id,
			texto = reco.pitch or L["La guía que mejor te queda por tu nivel y donde estás."], insignias = ins,
			accion = { texto = abierta and L["Continuar"] or L["Seguir esta guía"], icono = "ic-seguir", alClic = function() B.Seguir(reco.id, est.nueva) end },
			secundaria = not abierta and not est.nueva and { texto = L["En una pestaña nueva"], alClic = function() B.Seguir(reco.id, true) end } or nil,
		})
	end
	K.Mostrar(ui.reco, reco ~= nil)
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
	if pedido.mision then
		local titulo = M.TituloMision(pedido.mision)
		est.cat, est.buscar = "todas", ""
		ui.cats:SetValor("todas")
		M.Aviso(format(L["Guías con %s"], M.Citar(titulo)), L["Busca la zona de la misión entre las guías de subir de nivel."], { icono = "ic-guia" })
	end
	v:SetTitulo(est.nueva and L["Abrir otra guía"] or L["Guías"], L["La recomendada para ti y todas las demás"], "ic-guia")
	v:Abrir()
	B.Pintar()
end

function B.Visible() return v ~= nil and v:IsShown() end

N.Reemplazar("SHOW_PICKER", function(p) B.Abrir(p) end, B.Visible)
A.On("TABS_CHANGED", function() if B.Visible() then B.Pintar() end end)
A.On("GUIDES_REGISTERED", function() if B.Visible() then B.Pintar() end end)
