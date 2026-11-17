-- Alfa - Enciclopedia: su página en la ventana de Alfa, los reemplazos del
-- motor y lo que usan los demás módulos (toxic3000 / La Jauría). GPL-3.0.
--
-- La página (Aventura > Enciclopedia) es un Tablero: arriba, en grande,
-- abrir la enciclopedia; debajo, un acceso por tipo (con cuántos hay cuando
-- los datos ya están cargados), lo último que consultaste y el atajo de
-- Alt+clic. Abrir la página no carga los datos: eso pasa al abrir la ventana.
--
-- Reemplaza el buscador del motor (SHOW_LOOKUP) y su sección de raros
-- (SHOW_RARES): Alt+clic en un objeto, /alfa lookup, /alfa rares, el aviso
-- de un raro y el buscador del selector de guías abren la enciclopedia.
--
--   AlfaEnciclopedia.Abrir(tipo, id)   tipo: "objeto" | "montura" | "mascota" | "pnj" | "mision" | "zona" | "raro"
--       o "guia" con id "montura" (Mi primera montura) o "legado" (Puntos del legado)
--       o el del motor ("item", "npc", "quest", "zone", "rare", "treasure", "object"...);
--       sin id abre ese tipo. AlfaEnciclopedia.Buscar(texto), .Cerrar(), .Visible()

local ADDON, M = ...
local N, A, K, L = M.N, M.A, M.K, M.L
local V, Cat = M.V, M.Cat
local ID = M.ID

local type, tostring, ipairs, format = type, tostring, ipairs, string.format

local vista

---------------------------------------------------------------------------
-- Lo que usan los demás
---------------------------------------------------------------------------
local API = type(AlfaEnciclopedia) == "table" and AlfaEnciclopedia or {}
AlfaEnciclopedia = API
API.version = 1

function API.Abrir(tipo, id)
	-- Un tipo sin id ("objeto" o "item", "pnj" o "npc"...): su lista entera.
	if type(tipo) == "string" and M.TIPO[tipo] and id == nil then return V.Abrir({ tipo = tipo, texto = "" }) end
	local kind = M.KindDe(tipo)
	if kind and id ~= nil then return V.Abrir({ kind = kind, id = id }) end
	if kind and M.TIPO_DE_KIND[kind] then return V.Abrir({ tipo = M.TIPO_DE_KIND[kind], texto = "" }) end
	return V.Abrir()
end
function API.Buscar(texto) return V.Abrir({ texto = texto }) end
function API.Cerrar() return V.Cerrar() end
function API.Visible() return V.Visible() end

---------------------------------------------------------------------------
-- Reemplazos: la enciclopedia en lugar del buscador y los raros del motor
---------------------------------------------------------------------------
local function abrirGuia(id)
	local LK = A.UI and A.UI.Lookup
	if LK and LK.OpenGuide then return LK.OpenGuide(id) end
end

N.Reemplazar("SHOW_LOOKUP", function(p)
	p = p or {}
	if p.alternar then return V.Alternar() end
	if p.tipo == "guide" and p.id then return abrirGuia(p.id) end
	V.Abrir({ texto = p.buscar, kind = p.tipo, id = p.id })
end, V.Visible)

N.Reemplazar("SHOW_RARES", function(p)
	p = p or {}
	if p.id ~= nil and (p.tipo == "rare" or p.tipo == "treasure") then
		return V.Abrir({ kind = p.tipo, id = p.id })
	end
	V.Abrir({ tipo = "raro" })
end, V.Visible)

---------------------------------------------------------------------------
-- La página
---------------------------------------------------------------------------
local function contar(tipo)
	local C = M.CodexListo()
	local meta = C and C.Meta and C.Meta()
	local c = type(meta) == "table" and type(meta.counts) == "table" and meta.counts
	if not c then return nil end
	local n = 0
	for _, k in ipairs(M.TIPO[tipo].kinds) do n = n + (tonumber(c[k]) or 0) end
	return n > 0 and n or nil
end

local function opciones()
	local out = {}
	for _, t in ipairs(M.TIPOS) do
		local n = contar(t.clave)
		local ins = n and { { M.Miles(n), "neutro" } } or nil
		-- Monturas y mascotas: cuántas tienes (cuando ya se armaron).
		if (t.clave == "montura" or t.clave == "mascota") and M.Col then
			local tienes, total, sabe = M.Col.Cuenta(t.clave)
			if sabe then ins = { { format(L["Tienes %d de %d"], tienes, total), "exito" } } end
		end
		out[#out + 1] = {
			icono = t.icono, titulo = t.texto, texto = t.descripcion, insignias = ins,
			alClic = function() V.Abrir({ tipo = t.clave }) end,
		}
	end
	-- Las guías.
	out[#out + 1] = { icono = "ic-huella", titulo = L["Mi primera montura"],
		texto = L["Qué necesitas a tu nivel: la equitación, el oro, a quién ir y tu montura de clase."],
		alClic = function() V.Abrir({ kind = "guia", id = "montura" }) end }
	local disp = M.Legado and M.Legado.Resumen()
	out[#out + 1] = { icono = "ic-nivel", titulo = L["Puntos del legado"],
		texto = L["Qué son, cómo se gana cada uno, en qué se gastan y cuántos tienes."],
		insignias = disp and disp > 0 and { { format(L["%d para gastar"], disp), "exito" } } or nil,
		alClic = function() V.Abrir({ kind = "guia", id = "legado" }) end }
	return out
end

local ICONO = { item = "ic-bolsas", mount = "ic-huella", pet = "ic-lobo", recipe = "ic-oficios", tabard = "ic-bolsas",
	npc = "ic-personajes", rare = "ic-raros", treasure = "ic-raros", object = "ic-recoleccion", quest = "ic-misiones", zone = "ic-mapa",
	mountspell = "ic-huella", guia = "ic-guia" }
local CLASE = { item = L["Objeto"], mount = L["Montura"], pet = L["Mascota"], recipe = L["Receta"], tabard = L["Tabardo"],
	npc = L["PNJ"], rare = L["Raro"], treasure = L["Tesoro"], object = L["Objeto del mundo"], quest = L["Misión"], zone = L["Zona"],
	mountspell = L["Montura"], guia = L["Guía"] }

-- Lo último que consultaste: tarjetas compactas (solo si hay).
local function recientes(padre)
	local b = K.Pila(padre, { espacio = K.ESP.m })
	b.Seccion = b:Agregar(K.Seccion(b, L["Lo último que consultaste"]))
	b.Rejilla = b:Agregar(K.Rejilla(b, { min = 240, gap = K.ESP.s, variante = "compacta" }), { espacio = K.ESP.s })
	function b:Llenar()
		local d = N.DatosPersonaje(ID)
		local lista = type(d.recientes) == "table" and d.recientes or {}
		local datos = {}
		for i = 1, math.min(8, #lista) do
			local r = lista[i]
			if type(r) == "table" and r.k and r.id ~= nil then
				local nombre = M.CodexListo() and M.Nombre(r.k, r.id) or nil
				datos[#datos + 1] = { variante = "compacta", icono = ICONO[r.k] or "ic-enciclopedia",
					titulo = nombre or r.nombre or tostring(r.id), texto = CLASE[r.k],
					alClic = function() V.Abrir({ kind = r.k, id = r.id }) end }
				if nombre then r.nombre = nombre end
			end
		end
		self.Rejilla:Llenar(datos)
		K.Mostrar(self, #datos > 0)
	end
	return b
end

local function atajos(padre)
	local g = K.GrupoAjustes(padre, { titulo = L["Atajos"] })
	g:Fila({ titulo = L["Alt+clic en un objeto abre su ficha"],
		texto = L["En tus bolsas, el botín, el chat o cualquier enlace: Alt+clic abre la guía para conseguirlo o, si no hay, su ficha en la enciclopedia."],
		control = function(fila) return K.Interruptor(fila, { clave = "lookup.altClick" }) end })
	g:Fila({ titulo = L["Comando"], texto = L["/alfa enciclopedia abre la ventana; /alfa enciclopedia <texto> busca de una vez."] })
	return g
end

local function construir(view)
	local ui = {}
	local t = K.Tablero(view, { margen = N.MargenPagina(), accion = "accion", tituloOpciones = L["Qué quieres buscar"], min = 240 })
	ui.recientes = t:AgregarBloque(recientes(t.Extra))
	ui.atajos = t:AgregarBloque(atajos(t.Extra), { espacio = K.ESP.xl })
	K.EnPagina(view, t, function()
		t:SetAccion({
			icono = "ic-enciclopedia", sobre = M.Mayus(L["La enciclopedia de La Jauría"]), titulo = L["Busca cualquier cosa del juego"],
			texto = L["Todos los objetos, monturas, mascotas, PNJ, misiones, zonas y raros, aunque no los tengas: quién lo suelta y con qué probabilidad, quién lo vende y dónde, qué misión lo da y cómo llegar."],
			accion = { texto = L["Abrir la enciclopedia"], icono = "ic-buscar", alClic = function() V.Abrir() end },
		})
		t:SetOpciones(opciones(), L["Qué quieres buscar"])
		ui.recientes:Llenar()
		ui.atajos:Refrescar()
	end)
	vista = view
end

M.alRecientes = function() if vista then N.RehacerPagina(vista) end end
A.On("CODEX_LOADED", function() if vista then N.RehacerPagina(vista) end end)

N.Modulo({
	id = ID, nombre = L["Enciclopedia"], icono = "ic-enciclopedia", orden = 25, seccion = "aventura",
	subtitulo = L["Todo el juego, aunque no lo tengas: objetos, monturas, mascotas, PNJ, misiones, zonas y raros."],
	construir = construir,
})

---------------------------------------------------------------------------
-- Comandos
---------------------------------------------------------------------------
local function comando(resto)
	resto = type(resto) == "string" and resto:gsub("^%s+", ""):gsub("%s+$", "") or ""
	if resto == "" then return V.Alternar() end
	V.Abrir({ texto = resto })
end
A.RegisterCommand("enciclopedia", comando, L["abre la Enciclopedia (o busca: /alfa enciclopedia <texto>)"])
A.RegisterCommand("wiki", comando, L["lo mismo que /alfa enciclopedia"])
A.RegisterCommand("monturas", function() V.Abrir({ tipo = "montura" }) end, L["abre las monturas de la Enciclopedia"])
A.RegisterCommand("mascotas", function() V.Abrir({ tipo = "mascota" }) end, L["abre las mascotas de la Enciclopedia"])
A.RegisterCommand("legado", function() V.Abrir({ kind = "guia", id = "legado" }) end, L["abre la guía de los puntos del legado"])
