-- Alfa - Rutas: el asistente "¿Qué quieres hacer?" (toxic3000 / La Jauría). GPL-3.0.
--
-- Dos clics y estás en marcha:
--   1. eliges tu camino: Subir de nivel, Profesiones, Hacer oro, Mazmorras o
--      Mi propio plan (Planes.lua: uno nuevo, una plantilla o uno tuyo);
--   2. eliges cómo: la opción recomendada en grande (la guía para tu nivel y
--      tu zona, tu plan de misiones si tienes muchas listas, la ruta de
--      Alfa...) y las demás en tarjetas. Un clic la pone en marcha.
-- AlfaRuta.Asistente(camino) abre directo en el paso 2 de ese camino.

local ADDON, M = ...
local A, L, N = M.A, M.L, M.N
local K = M.K
local As = {}
M.Asistente = As

local ipairs, type, format, min = ipairs, type, string.format, math.min

local v, asis
local est = { camino = nil }

local function G() return A.Guides end
local function U() return A.UI end

local CAMINOS = {
	{ clave = "nivel", icono = "ic-nivel", tono = "exito", titulo = L["Subir de nivel"], texto = L["Una guía para tu nivel y tu zona, o tu propia ruta de misiones."] },
	{ clave = "profesiones", icono = "ic-oficios", tono = "aviso", titulo = L["Profesiones"], texto = L["Sube tu profesión o junta sus materiales donde más hay."] },
	{ clave = "oro", icono = "ic-oro", tono = "oro", titulo = L["Hacer oro"], texto = L["Misiones que dejan dinero y materiales que se venden bien."] },
	{ clave = "mazmorras", icono = "ic-mazmorra", tono = "mazmorra", titulo = L["Mazmorras"], texto = L["La mazmorra para tu nivel, sus misiones y cómo llegar."] },
	{ clave = "planes", icono = "ic-lista", tono = "acento", titulo = L["Mi propio plan"], texto = L["Tus metas en tu orden: un objeto, oro, una profesión, un lugar…"] },
}

local function cerrar() if v then v:Cerrar() end end

-- Hace la opción y cierra el asistente.
local function hacer(fn)
	return function()
		cerrar()
		K.Llamar(fn)
	end
end

local function rutaDePlantilla(clave)
	return function()
		local r = M.DesdePlantilla(clave)
		if r and M.Seguir then M.Seguir(r) end
	end
end

-- Las guías de una categoría para tu personaje, las sugeridas primero.
local function guiasDe(cat, cuantas)
	local Gd = G()
	if not Gd then return {} end
	local C = M.Motor("Compat")
	local p = C and C.GetPlayerInfo and C.GetPlayerInfo() or {}
	local out = {}
	for _, g in ipairs(Gd.List and Gd.List() or {}) do
		if (g.category == cat or (cat == "Leveling" and g.category == nil)) and (not Gd.GuideMatches or Gd.GuideMatches(g, p)) then
			out[#out + 1] = g
		end
	end
	return out
end

local function tarjetaGuia(g, sobre)
	local u = U()
	local lugar = u and u.GuidePlace and u.GuidePlace(g)
	local lv = u and u.LevelRange and u.LevelRange(g.minLevel, g.maxLevel)
	local ins = {}
	if lv then ins[#ins + 1] = { format(L["Nivel %s"], lv), "neutro" } end
	return { icono = "ic-guia", titulo = g.title or g.id, texto = lugar or g.pitch, sobre = sobre, insignias = ins,
		alClic = hacer(function() M.Biblioteca.Seguir(g.id) end) }
end

-- Las opciones de cada camino: la primera es la recomendada.
local function opciones(camino)
	local out = {}
	local listas = M.Cerrar.ListasAhora()
	if camino == "nivel" then
		local Gd = G()
		local id = Gd and Gd.Suggest and Gd.Suggest()
		local g = id and Gd.Get(id)
		if listas >= M.Vuelta.MIN then
			out[#out + 1] = { icono = "ic-misiones", tono = "exito", titulo = format(L["Entrega tus %d misiones listas"], listas),
				texto = L["Primero cobra lo que ya hiciste: una ruta por el camino más corto, junta por PNJ."],
				accion = { texto = L["Armar la ruta"], icono = "ic-seguir" }, alClic = hacer(function() M.EntregarListas() end) }
		end
		if g then
			local t = tarjetaGuia(g)
			t.texto = g.pitch or L["La guía que mejor te queda por tu nivel y donde estás."]
			t.accion = { texto = L["Seguir esta guía"], icono = "ic-seguir" }
			out[#out + 1] = t
		end
		out[#out + 1] = { icono = "ic-ruta", tono = "acento", titulo = L["Mi ruta: subir rápido"], texto = L["Alfa elige las misiones que más XP dan cerca de ti, en tres tandas."],
			alClic = hacer(rutaDePlantilla("rapido")) }
		out[#out + 1] = { icono = "ic-misiones", tono = "acento", titulo = L["Recoger misiones cerca"], texto = L["Toma las mejores misiones de por aquí y después ciérralas juntas."],
			alClic = hacer(function() M.Recoger.Ahora() end) }
		out[#out + 1] = { icono = "ic-guia", tono = "neutro", titulo = L["Ver todas las guías"], texto = L["Elige tú la zona."],
			alClic = hacer(function() M.Biblioteca.Abrir() end) }
	elseif camino == "profesiones" then
		-- 1.3.9 (oficios): primero tus oficios, cada uno con su guía de Alfa por
		-- tramos (OficiosGuia: armada para ti al abrirla); sin oficio, los que
		-- puedes aprender. Después, juntar materiales y la Biblioteca.
		local Og = M.OficiosGuia
		local mios = Og and Og.Mios() or {}
		for _, x in ipairs(mios) do
			if #out >= 4 then break end
			local linea = x.linea
			local ins = { { format(L["%d de %d"], x.rank, x.max), x.rank >= x.max and x.max < 300 and "aviso" or "neutro" } }
			local texto = x.rank >= 300 and L["Al máximo: ya no hay más que subir."]
				or (x.rank >= x.max and format(L["Llegaste a tu tope (%d): toca ir con el instructor."], x.max))
				or L["Qué hacer en tu tramo, cuántas, tus materiales y a dónde ir."]
			out[#out + 1] = { icono = "ic-oficios", tono = "aviso", titulo = format(L["Guía de %s"], Og.Nombre(linea)), texto = texto, insignias = ins,
				accion = { texto = L["Seguir mi guía"], icono = "ic-seguir" }, alClic = hacer(function() Og.Abrir(linea) end) }
		end
		if Og and #mios == 0 then
			for _, linea in ipairs(M.OficiosDatos.ORDEN) do
				if #out >= 6 then break end
				out[#out + 1] = { icono = "ic-oficios", tono = "neutro", titulo = format(L["Aprender %s"], Og.Nombre(linea)),
					texto = M.OficiosDatos.OFICIOS[linea].tipo == "juntar" and L["Recolección: juntas en el mundo y vendes o usas."] or L["Fabricación: haces cosas con materiales."],
					alClic = hacer(function() Og.Abrir(linea) end) }
			end
		end
		out[#out + 1] = { icono = "ic-oficios", tono = "aviso", titulo = L["Juntar los materiales de mi profesión"],
			texto = L["Una ruta por los mejores lugares para tu habilidad, con unas misiones de XP en medio."],
			accion = { texto = L["Armar la ruta"], icono = "ic-seguir" }, alClic = hacer(rutaDePlantilla("prof")) }
		out[#out + 1] = { icono = "ic-guia", tono = "neutro", titulo = L["Todas las guías de profesiones"], alClic = hacer(function() M.Biblioteca.Abrir({ categoria = "Professions" }) end) }
	elseif camino == "oro" then
		out[#out + 1] = { icono = "ic-oro", tono = "oro", titulo = L["Mi ruta: hacer oro"], texto = L["Misiones que dejan dinero y materiales de tu profesión para vender."],
			accion = { texto = L["Armar la ruta"], icono = "ic-seguir" }, alClic = hacer(rutaDePlantilla("oro")) }
		if listas > 0 then
			out[#out + 1] = { icono = "ic-misiones", tono = "exito", titulo = listas == 1 and L["Cobra tu misión lista"] or format(L["Cobra tus %d misiones listas"], listas), texto = L["Su oro y sus recompensas ya son tuyos: solo falta entregarlas."],
				alClic = hacer(function() M.EntregarListas() end) }
		end
		out[#out + 1] = { icono = "ic-oficios", tono = "aviso", titulo = L["Juntar materiales para vender"], texto = L["Lo que tu profesión de recolección junta mejor."],
			alClic = hacer(rutaDePlantilla("prof")) }
		if N.ModuloPorId("comercio") then
			out[#out + 1] = { icono = "ic-comercio", tono = "neutro", titulo = L["Comercio"], texto = L["Precios y qué conviene vender."], alClic = hacer(function() N.Abrir("comercio") end) }
		end
	elseif camino == "mazmorras" then
		-- La de Mazmorras (área D): la recomendada para tu nivel y "Prepárame"
		-- (recoge sus misiones y te lleva a la entrada).
		local AM = AlfaMazmorras
		local reco = AM and AM.Recomendada and AM.Recomendada()
		if reco and reco.key then
			local ins = {}
			local u = A.UI
			local lv = u and u.LevelRange and u.LevelRange(reco.min, reco.max)
			if lv then ins[#ins + 1] = { format(L["Nivel %s"], lv), "mazmorra" } end
			if (reco.recoger or 0) > 0 then ins[#ins + 1] = { M.Plural(reco.recoger, L["%d misión para recoger"], L["%d misiones para recoger"]), "acento" } end
			local frase = AM.Frase and AM.Frase(reco.key)
			out[#out + 1] = { icono = "ic-mazmorra", tono = "mazmorra", titulo = reco.nombre or L["La mazmorra para mi nivel"],
				texto = frase or reco.zona or L["Sus jefes, su botín, sus misiones y cómo llegar."], insignias = ins,
				accion = { texto = L["Prepárame"], icono = "ic-seguir" }, alClic = hacer(function() AM.Preparar(reco.key) end) }
			out[#out + 1] = { icono = "ic-mazmorra", tono = "neutro", titulo = format(L["Ver %s"], reco.nombre or ""), texto = L["Sus jefes, su botín, sus misiones y cómo llegar."],
				alClic = hacer(function() AM.Abrir(reco.key) end) }
			out[#out + 1] = { icono = "ic-mazmorra", tono = "neutro", titulo = L["Todas las mazmorras"], texto = L["La lista por nivel y tu progreso."],
				alClic = hacer(function() AM.Abrir() end) }
		else
			out[#out + 1] = { icono = "ic-mazmorra", tono = "mazmorra", titulo = L["La mazmorra para mi nivel"], texto = L["Sus jefes, su botín, sus misiones y cómo llegar."],
				accion = { texto = L["Abrir Mazmorras"], icono = "ic-seguir" }, alClic = hacer(function()
					if AM and AM.Abrir then AM.Abrir() elseif A.Fire then A.Fire("SHOW_DUNGEON") end
				end) }
		end
		out[#out + 1] = { icono = "ic-misiones", tono = "acento", titulo = L["Cerrar mis misiones antes"], texto = L["Entra con el registro limpio: entrega lo que ya tienes."],
			alClic = hacer(function() M.Cerrar.Ahora("listas") end) }
	elseif camino == "planes" then
		-- Mis planes (Planes.lua): seguir el tuyo, armar uno o empezar una plantilla.
		local Pl, VP = M.Planes, M.VistaPlanes
		local activo = Pl.Activo()
		if activo then
			local m = Pl.Actual(activo, true)
			out[#out + 1] = { icono = "ic-lista", tono = "acento", titulo = activo.nombre,
				texto = (#activo.metas == 0 and L["Sin metas todavía: ábrelo y agrégale una."]) or (m and format(L["Sigue: %s"], Pl.Titulo(m)))
					or L["Terminado: cumpliste todas sus metas."],
				accion = { texto = L["Ver mi plan"], icono = "ic-seguir" }, alClic = hacer(function() VP.Abrir(activo.id) end) }
		end
		out[#out + 1] = { icono = "ic-mas", tono = "acento", titulo = L["Armar un plan nuevo"],
			texto = L["Primero un objeto, luego oro, luego una profesión y al final el banco: tú eliges el orden."],
			accion = { texto = L["Nuevo plan"], icono = "ic-mas" }, alClic = hacer(function() VP.Nuevo() end) }
		for _, p in ipairs(Pl.Plantillas()) do
			local clave = p.clave
			out[#out + 1] = { icono = p.icono, tono = "neutro", titulo = p.nombre, texto = p.texto,
				alClic = hacer(function()
					local pl = Pl.DesdePlantilla(clave)
					if pl then Pl.Seguir(pl.id) end
				end) }
		end
		for _, pl in ipairs(Pl.Lista()) do
			if not (activo and activo.id == pl.id) and #out < 8 then
				local id = pl.id
				out[#out + 1] = { icono = "ic-lista", tono = "neutro", titulo = pl.nombre, texto = #pl.metas == 1 and L["1 meta"] or format(L["%d metas"], #pl.metas),
					alClic = hacer(function() VP.Abrir(id) end) }
			end
		end
	end
	return out
end

local function construir()
	v = K.Ventana({ nombre = "AlfaAsistente", titulo = L["¿Qué quieres hacer?"], subtitulo = L["Dos clics y Alfa te lleva"], icono = "ic-lobo", ancho = 780, alto = 600 })
	asis = K.Asistente(v.Cuerpo, { margen = v.margen, textoTerminar = L["Empezar"], pasos = {
		{
			titulo = L["¿Qué quieres hacer hoy?"],
			texto = L["Elige tu camino. Si no sabes, empieza por subir de nivel: Alfa te dice qué conviene."],
			construir = function(pila, a)
				local r = pila:Agregar(K.Rejilla(pila, { min = 300, gap = K.ESP.base }))
				local datos = {}
				for i, c in ipairs(CAMINOS) do
					datos[i] = { icono = c.icono, tono = c.tono, titulo = c.titulo, texto = c.texto,
						alClic = function() est.camino = c.clave a:Siguiente() end }
				end
				r:Llenar(datos)
			end,
			listo = function() return est.camino ~= nil end,
		},
		{
			titulo = L["¿Cómo quieres hacerlo?"],
			texto = L["Arriba, lo que Alfa recomienda. Un clic y empiezas."],
			construir = function(pila)
				pila.reco = pila:Agregar(K.Tarjeta(pila, { variante = "accion" }))
				pila.rej = pila:Agregar(K.Rejilla(pila, { min = 210, gap = K.ESP.base }))
			end,
			alMostrar = function(pila)
				local ops = opciones(est.camino)
				local primera = table.remove(ops, 1)
				if primera then
					primera.sobre = L["Recomendado"]
					local fn = primera.alClic
					primera.accion = primera.accion or { texto = L["Empezar"], icono = "ic-seguir" }
					primera.accion.alClic = fn
					pila.reco:Set(primera)
					pila.primera = fn
				end
				K.Mostrar(pila.reco, primera ~= nil)
				for _, o in ipairs(ops) do o.accion = nil end
				pila.rej:Llenar(ops)
				K.Mostrar(pila.rej, #ops > 0)
			end,
		},
	}, alTerminar = function(a)
		local p = a.pilas and a.pilas[2]
		if p and p.primera then p.primera() end
	end })
	v.alAcomodar = function() if asis then asis:Acomodar(v:AnchoCuerpo(), v:AltoCuerpo()) end end
	v.alAcomodar()
end

-- camino: "nivel" | "profesiones" | "oro" | "mazmorras" | "planes" | nil (empieza en el paso 1)
function As.Abrir(camino)
	if not v then construir() end
	local valido = false
	for _, c in ipairs(CAMINOS) do if c.clave == camino then valido = true end end
	est.camino = valido and camino or nil
	v:Abrir()
	asis:Ir(valido and 2 or 1)
	asis:Acomodar(v:AnchoCuerpo(), v:AltoCuerpo())
end

function As.Visible() return v ~= nil and v:IsShown() end
