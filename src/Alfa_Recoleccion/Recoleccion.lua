-- Alfa - Recolección (toxic3000 / La Jauría, GPL-3.0): nodos, rutas de farmeo e historial.
--
-- Esta parte: la página del módulo, hecha con el Kit (docs/KIT.md, plantilla
-- Tablero), las capas de Alfa_Mundo, el comando /alfa recoleccion y el
-- arranque. Los nodos están en Nodos.lua, la detección en Deteccion.lua,
-- el mapa en Mapa.lua, el minimapa en Minimapa.lua y la ruta en Ruta.lua.
--
-- La página, de arriba abajo:
--   1. tu ruta de farmeo: qué hacer ahora (crearla, seguirla, detenerla),
--      con su avance en huellas, y qué recolectar (tipo y recurso);
--   2. esta sesión en números (solo si ya recolectaste algo);
--   3. lo recolectado: por recurso, los objetos, por zona y las sesiones
--      anteriores (cada lista solo si tiene algo; sin nada, el lobo dormido);
--   4. los ajustes: dónde y qué se ve, y el mapa;
--   5. tus datos: lo que trae la base y lo que descubriste, y borrar.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local R, Ruta = M.R, M.Ruta
local L = N.Textos(M.EN)

local floor, max, min, format = math.floor, math.max, math.min, string.format
local ID = R.ID
local ESP = K.ESP
local DOT = "  \194\183  "

---------------------------------------------------------------------------
-- Capas de Alfa_Mundo (si está): un interruptor por tipo en su control.
---------------------------------------------------------------------------
local function hayMundo()
	return type(AlfaMundo) == "table" and type(AlfaMundo.RegistrarCapa) == "function"
end

if hayMundo() then
	for _, tipo in ipairs(M.TIPOS) do
		local ok, id = pcall(AlfaMundo.RegistrarCapa, {
			id = "recoleccion." .. tipo, grupo = L["Recolección"], nombre = R.NombreTipo(tipo),
			icono = (R.IconoTipo(tipo)), activa = N.Get(ID, tipo) ~= false,
			-- En el mapa continuo, desde que se ven las zonas (MapaMundo.lua).
			zoom = 4.5,
			alCambiar = function(activa)
				-- Se guarda también aquí, para cuando Alfa_Mundo no esté.
				N.Set(ID, tipo, activa and true or false)
				R.Refiltrar()
			end,
		})
		-- Solo cuenta la capa que Alfa_Mundo aceptó (devuelve nil, error si no):
		-- la de un tipo que no aceptó la decide el ajuste propio (R.TipoActivo).
		if ok and id then
			R.capas = R.capas or {}
			R.capas[tipo] = true
			R.mundo = true
		end
	end
end

-- Encender o apagar un tipo: con Alfa_Mundo, en su capa.
local function ponerTipo(tipo, valor)
	if valor == nil then valor = true end
	if R.mundo and type(AlfaMundo) == "table" and type(AlfaMundo.ActivarCapa) == "function" then
		pcall(AlfaMundo.ActivarCapa, "recoleccion." .. tipo, valor)
	end
	N.Set(ID, tipo, valor and true or false)
	R.Refiltrar()
end

---------------------------------------------------------------------------
-- Ajustes y su búsqueda (la ventana de Alfa los encuentra por su nombre)
---------------------------------------------------------------------------
local AJUSTES = {
	mapa = true, minimapa = true,
	mineria = true, hierbas = true, pesca = true, tesoros = true,
	soloProfesiones = true, soloHabilidad = false,
	base = true, agrupar = true,
	tamanoMapa = 1, tamanoMinimapa = 1,
	-- "auto": la profesión de recolección que tiene tu personaje (tipoRuta);
	-- lo que elijas en "Tipo" se guarda y manda.
	rutaTipo = "auto", rutaRecurso = "todos",
	avisoNuevo = true, -- 1.4.0 (diario): un recurso nuevo al subir tu habilidad (Avisos.lua)
	avisoHerramienta = true, -- 1.4.0 (diario): el pico o el cuchillo que falta (Avisos.lua)
	juntaRuta = true, -- 1.4.0 (Junta.lua): los pasos «Junta N de X» usan la ruta corta de Alfa
}

local function porciento(v) return floor(v * 100 + 0.5) .. " %" end
local function clave(k) return ID .. "." .. k end

local function buscable(tipo, k, etiqueta, ayuda, extra)
	local c = { kind = tipo, key = clave(k), label = etiqueta, help = ayuda }
	for a, b in pairs(extra or {}) do c[a] = b end
	return c
end

local BUSCAR = {
	buscable("toggle", "mapa", L["En el mapa del mundo"], nil, { search = "mapa, world map, pins, nodos" }),
	buscable("toggle", "minimapa", L["En el minimapa"], nil, { search = "minimap, nodos, cerca" }),
	buscable("slider", "tamanoMapa", L["Tamaño en el mapa"], nil, { min = 0.6, max = 1.8, step = 0.05, format = porciento }),
	buscable("slider", "tamanoMinimapa", L["Tamaño en el minimapa"], nil, { min = 0.6, max = 1.8, step = 0.05, format = porciento }),
	buscable("toggle", "soloProfesiones", L["Ocultar lo de profesiones que no tienes"]),
	buscable("toggle", "soloHabilidad", L["Solo lo que ya puedes recolectar"]),
	buscable("toggle", "agrupar", L["Juntar nodos cercanos al alejar"]),
	buscable("toggle", "base", L["Usar la base de datos incluida"]),
	buscable("toggle", "avisoNuevo", L["Avisar al poder recolectar algo nuevo"], nil,
		{ search = "new node, skill up, mining, herbalism, recurso nuevo, ya puedes minar" }),
	buscable("toggle", "avisoHerramienta", L["Avisar si te falta el pico o el cuchillo"], nil,
		{ search = "mining pick, skinning knife, tool, pico, cuchillo, herramienta" }),
	buscable("toggle", "juntaRuta", L["Guiar los pasos de juntar con una ruta corta"], nil,
		{ search = "collect, gather route, tin ore, juntar, mena, ruta corta, guía" }),
}
for _, tipo in ipairs(M.TIPOS) do
	BUSCAR[#BUSCAR + 1] = buscable("toggle", tipo, R.NombreTipo(tipo), nil, {
		search = "capas, layers, nodos, " .. tipo,
		get = function() return R.TipoActivo(tipo) end,
		set = function(v) ponerTipo(tipo, v) end,
	})
end

---------------------------------------------------------------------------
-- Utilidades de la página
---------------------------------------------------------------------------
local function miles(n)
	local s = tostring(floor(tonumber(n) or 0))
	-- En español de México los miles van con coma (12,345), como en Comercio.
	-- 1.3.7: en alemán, francés, portugués y ruso, el separador de su idioma.
	local loc = GetLocale and GetLocale()
	local sep = ({ deDE = ".", ptBR = ".", esES = ".", frFR = " ", ruRU = " " })[loc] or ","
	while true do
		local k
		s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1" .. sep .. "%2")
		if k == 0 then return s end
	end
end

local function nombreZona(mapID)
	local C = A.Compat
	return (C and C.MapName and C.MapName(mapID)) or L["Zona %d"]:format(tonumber(mapID) or 0)
end

local function porHora(total, seg)
	if seg < 300 or total == 0 then return nil end
	return floor(total / (seg / 3600) + 0.5)
end

local function ordenadoPorValor(t)
	local out = {}
	for k, v in pairs(t or {}) do out[#out + 1] = { k = k, v = tonumber(v) or 0 } end
	table.sort(out, function(a, b)
		if a.v ~= b.v then return a.v > b.v end
		return tostring(a.k) < tostring(b.k)
	end)
	return out
end

-- Los íconos del Kit para cada tipo (las tarjetas los tiñen).
local ICONO_TIPO = {
	mineria = "ic-oficios", hierbas = "ic-recoleccion", pesca = "ic-pesca",
	tesoros = "Interface\\AddOns\\Alfa\\Media\\Map\\icon-treasure",
}

local V = { esperaObjetos = false }

---------------------------------------------------------------------------
-- 1. La ruta de farmeo
---------------------------------------------------------------------------
local function nombreRecurso(tipo, recurso)
	if recurso and recurso ~= "todos" and M.porClave[recurso] then return R.Nombre(M.porClave[recurso]) end
	return R.NombreTipo(tipo)
end

-- El tipo de la ruta: el que elegiste en "Tipo" o, sin elegir ("auto"), la
-- profesión de recolección que tiene tu personaje (Minería, luego
-- Herboristería). nil: no tiene ninguna (la tarjeta lo dice).
local OFICIOS_RUTA = { "mineria", "hierbas" }
local function tipoRuta()
	local t = N.Get(ID, "rutaTipo")
	if t ~= "auto" and M.TIPO[t] then return t end
	if not R.HabilidadesListas() then return "mineria" end
	for _, x in ipairs(OFICIOS_RUTA) do
		if R.Habilidad(x) ~= nil then return x end
	end
	return nil
end
R.TipoRuta = tipoRuta

-- La flecha al instructor de una profesión más cercano (Buscar cerca del
-- motor: Alfa.Nav.nearby.Go("trainer", línea)); sin eso, cómo encontrarlo.
local function irInstructor(linea)
	local Nav = A.Nav
	local near = type(Nav) == "table" and Nav.nearby
	if type(near) == "table" and type(near.Go) == "function" then
		local ok, puesto = pcall(near.Go, "trainer", linea)
		if ok and puesto and N.EmpezarRuta then N.EmpezarRuta() end
		return
	end
	N.Imprimir(L["Pregúntale a un guardia de la ciudad por el instructor de la profesión."])
end

local function crearRuta()
	local zona = Ruta.ZonaActual()
	local ok, motivo = Ruta.Crear(tipoRuta() or "mineria", N.Get(ID, "rutaRecurso") or "todos", zona, function(r)
		if r and r.n then N.Imprimir(L["Ruta lista en %s: %s"]:format(nombreZona(r.mapa), Ruta.Resumen(r) or "")) end
	end)
	V.aviso = not ok and motivo or nil
	M.Pagina.Actualizar()
end

local function verEnMapa()
	local r = Ruta.Actual()
	local mapa = (r and r.mapa) or Ruta.ZonaActual()
	if not mapa then return end
	-- El mapa del juego dibuja la ruta; el de Alfa, si M lo abre.
	local C = A.Compat
	if C and C.CanOpenWorldMap and C.CanOpenWorldMap() and C.OpenWorldMap(mapa) then return end
	if AlfaMundo and AlfaMundo.Abrir then AlfaMundo.Abrir(mapa) end
end

local function tarjetaRuta()
	local r = Ruta.Actual()
	local zona = Ruta.ZonaActual()
	local tipo = tipoRuta()
	local recurso = N.Get(ID, "rutaRecurso") or "todos"
	local d = { icono = "ic-ruta" }
	if Ruta.Calculando() then
		d.titulo, d.tono = L["Calculando la vuelta más corta…"], "aviso"
		d.texto = L["Alfa ordena las paradas para que no camines de más. Tarda unos segundos y no traba el juego."]
		d.estado = { texto = L["Calculando"], tono = "aviso" }
		return d
	end
	if r and r.n and r.n > 0 then
		local nombre = nombreRecurso(r.tipo, r.recurso)
		if r.guiando then
			d.titulo, d.tono = L["Siguiendo tu ruta de %s"]:format(nombre), "acento"
			d.texto = L["%s. La flecha te lleva a la parada %d; al llegar o recolectar ahí pasa sola a la siguiente."]:format(Ruta.Resumen(r) or "", r.siguiente or 1)
			d.estado = { texto = L["En camino"], tono = "acento" }
			d.progreso = { actual = max(0, (r.siguiente or 1) - 1), total = r.n, huellas = true, texto = L["Parada %d de %d"]:format(r.siguiente or 1, r.n) }
			d.accion = { texto = L["Detener"], icono = "ic-cerrar", alClic = function() Ruta.Detener() end }
			d.secundaria = { texto = L["Ver en el mapa"], alClic = verEnMapa }
		else
			d.titulo, d.tono = L["Tu ruta de %s en %s está lista"]:format(nombre, nombreZona(r.mapa)), "exito"
			d.texto = (Ruta.Resumen(r) or "") .. ". " .. L["Pulsa Guiarme y la flecha te lleva de parada en parada desde la más cercana."]
			d.estado = { texto = L["Lista"], tono = "exito" }
			d.accion = { texto = L["Guíame"], icono = "ic-seguir", alClic = function() Ruta.Guiar() end }
			d.secundaria = { texto = L["Borrar la ruta"], alClic = function() Ruta.Borrar() end }
		end
		return d
	end
	if not zona or R.EnInstancia() then
		d.titulo, d.tono = L["Aquí no hay nodos que recolectar"], "neutro"
		d.texto = L["Dentro de mazmorras y ciudades no hay nodos. Sal al mundo y tu ruta se arma en un clic."]
		d.estado = { texto = L["Sin zona"], tono = "neutro" }
		return d
	end
	if not tipo then
		-- Sin Minería ni Herboristería no hay ruta que armar: quién te las enseña.
		d.titulo, d.tono = L["Aprende Minería o Herboristería"], "acento"
		d.texto = L["Tu personaje todavía no recolecta. Con Minería o Herboristería, Alfa une las minas o las hierbas de tu zona en una vuelta corta. Te las enseña un instructor de profesión."]
		d.estado = { texto = L["Sin profesión"], tono = "neutro" }
		d.accion = { texto = L["Instructor de Minería"], icono = "ic-flecha", alClic = function() irInstructor(M.TIPO.mineria.oficio) end }
		d.secundaria = { texto = L["Instructor de Herboristería"], alClic = function() irInstructor(M.TIPO.hierbas.oficio) end }
		return d
	end
	local hay = 0
	for _, x in ipairs(Ruta.RecursosEn(zona, tipo)) do
		if recurso == "todos" or x.clave == recurso then hay = hay + x.cuenta end
	end
	local nombre = nombreRecurso(tipo, recurso)
	if hay < 3 then
		d.titulo, d.tono = L["Pocos lugares de %s en %s"]:format(nombre, nombreZona(zona)), "aviso"
		d.texto = L["Una ruta necesita al menos 3 lugares que tu habilidad alcance. Elige otro tipo o recurso abajo, o recolecta aquí: Alfa anota cada nodo que encuentras."]
		d.estado = { texto = hay == 1 and L["1 lugar"] or L["%d lugares"]:format(hay), tono = "aviso" }
		return d
	end
	d.titulo, d.tono = L["Arma una ruta de %s en %s"]:format(nombre, nombreZona(zona)), "acento"
	d.texto = V.aviso or L["Une los %d lugares que tu habilidad alcanza en una vuelta corta, la dibuja en el mapa y la flecha te lleva de parada en parada."]:format(hay)
	if V.aviso then d.tono = "aviso" end
	d.estado = { texto = hay == 1 and L["1 lugar"] or L["%d lugares"]:format(hay), tono = V.aviso and "aviso" or "acento" }
	d.accion = { texto = L["Crear ruta"], icono = "ic-ruta", alClic = crearRuta }
	return d
end

local function opcionesRecurso()
	local tipo = tipoRuta() or "mineria"
	local out = { { valor = "todos", texto = L["Todos"] } }
	local elegido, esta = N.Get(ID, "rutaRecurso"), false
	for _, r in ipairs(Ruta.RecursosEn(Ruta.ZonaActual(), tipo)) do
		out[#out + 1] = { valor = r.clave, texto = ("%s (%d)"):format(r.nombre, r.cuenta) }
		if r.clave == elegido then esta = true end
	end
	if elegido and elegido ~= "todos" and not esta and M.porClave[elegido] then
		out[#out + 1] = { valor = elegido, texto = ("%s (0)"):format(R.Nombre(M.porClave[elegido])) }
	end
	return out
end

local function grupoQueRecolectar(padre)
	local g = K.GrupoAjustes(padre, { titulo = L["Qué recolectar"] })
	local CORTO = { mineria = L["Minería"], hierbas = L["Hierbas"], pesca = L["Pesca"], tesoros = L["Tesoros"] }
	local tipos = {}
	for _, tipo in ipairs(M.TIPOS) do tipos[#tipos + 1] = { valor = tipo, texto = CORTO[tipo] or R.NombreTipo(tipo) } end
	g:Fila({ titulo = L["Tipo"], texto = L["El tipo de nodos que une la ruta."],
		control = function(fila)
			local s = K.Segmentos(fila, { estilo = "segmentos", opciones = tipos, valor = tipoRuta() or "mineria",
				alCambiar = function(v) N.Set(ID, "rutaTipo", v) end })
			function s:Leer() self:SetValor(tipoRuta() or "mineria") end
			V.segTipo = s
			return s
		end })
	g:Fila({ titulo = L["Recurso"], texto = L["Todos los de ese tipo, o solo uno (por ejemplo, solo cobre). Entre paréntesis, cuántos hay en tu zona."],
		control = function(fila)
			local d = K.Desplegable(fila, { clave = clave("rutaRecurso"), ancho = 220, opciones = opcionesRecurso() })
			V.desRecurso = d
			return d
		end })
	return g
end

---------------------------------------------------------------------------
-- 2. Esta sesión, en números
---------------------------------------------------------------------------
local function numeros()
	local s = R.Sesion()
	local total = tonumber(s.total) or 0
	if total == 0 then return {} end
	local dur = max(0, time() - (tonumber(s.inicio) or time()))
	local ph = porHora(total, dur)
	local out = {
		{ variante = "compacta", icono = "ic-recoleccion", titulo = L["Recolectado"], valor = miles(total),
			texto = L["en %s"]:format(N.Duracion(dur)) },
	}
	if ph then out[#out + 1] = { variante = "compacta", icono = "ic-reloj", titulo = L["Por hora"], valor = miles(ph) } end
	-- 1.4.0 (plan 48): lo que vale lo que juntaste (subasta o comerciante) y por hora.
	local oro = R.ValorSesion(s)
	if oro > 0 then
		local t = { variante = "compacta", icono = "ic-oro", titulo = L["Oro estimado"], valor = N.DineroTexto(oro, true) }
		if dur >= 300 then t.texto = L["≈ %s por hora"]:format(N.DineroTexto(floor(oro / (dur / 3600) + 0.5), true)) end
		out[#out + 1] = t
	end
	for _, tipo in ipairs(M.TIPOS) do
		local n = tonumber(s.tipos[tipo]) or 0
		if n > 0 then out[#out + 1] = { variante = "compacta", icono = ICONO_TIPO[tipo], titulo = R.NombreTipo(tipo), valor = miles(n) } end
	end
	return out
end

---------------------------------------------------------------------------
-- 3. Lo recolectado: listas que solo se ven si tienen algo
---------------------------------------------------------------------------
local MAX_FILAS, FILA = 8, 36

-- datos = { { icono, glifo, objeto, nombre, detalle, valor }, ... }
local function bloqueLista(padre, titulo)
	local b = CreateFrame("Frame", nil, padre)
	b.Seccion = K.Seccion(b, titulo)
	b.Panel = CreateFrame("Frame", nil, b)
	b.Panel.caja = K.Caja(b.Panel, { fondo = "panel", borde = "linea", corte = K.CORTE.panel })
	b.Mas = K.Texto(b, "pequeno", "textoTenue")
	b.filas, b.lineas, b.datos = {}, {}, {}
	local function fila(i)
		local f = b.filas[i]
		if f then return f end
		f = CreateFrame("Frame", nil, b.Panel)
		f:SetHeight(FILA)
		f.Tex = f:CreateTexture(nil, "ARTWORK")
		f.Tex:SetSize(20, 20)
		f.Tex:SetPoint("LEFT", f, "LEFT", ESP.base, 0)
		f.Objeto = K.IconoObjeto(f, 22)
		f.Objeto:SetPoint("LEFT", f, "LEFT", ESP.base - 1, 0)
		f.Nombre = K.Texto(f, "cuerpo", "texto")
		f.Nombre:SetPoint("LEFT", f, "LEFT", ESP.base + 20 + ESP.m, 0)
		f.Valor = K.Texto(f, "numero", "texto")
		f.Valor:SetJustifyH("RIGHT")
		f.Valor:SetPoint("RIGHT", f, "RIGHT", -ESP.base, 0)
		f.Detalle = K.Texto(f, "pequeno", "textoTenue")
		f.Detalle:SetJustifyH("RIGHT")
		f.Detalle:SetPoint("RIGHT", f.Valor, "RIGHT", -64, 0)
		b.filas[i] = f
		return f
	end
	function b:Set(datos) self.datos = datos or {} end
	function b:Acomodar(ancho)
		local y = self.Seccion:Acomodar(ancho)
		self.Seccion:ClearAllPoints()
		self.Seccion:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
		self.Seccion:SetWidth(ancho)
		y = y + ESP.s
		local n = min(#self.datos, MAX_FILAS)
		for i = 1, n do
			local d = self.datos[i]
			local f = fila(i)
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", self.Panel, "TOPLEFT", 0, -(i - 1) * FILA)
			f:SetWidth(ancho)
			f.Objeto:SetShown(d.objeto ~= nil)
			f.Tex:SetShown(d.objeto == nil and d.icono ~= nil)
			if d.objeto then
				f.Objeto:SetObjeto(d.objeto)
			elseif d.icono then
				f.Tex:SetTexture(d.icono)
				if d.glifo then
					f.Tex:SetTexCoord(0, 1, 0, 1)
					f.Tex:SetVertexColor(K.Color("oro"))
				else
					f.Tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
					f.Tex:SetVertexColor(1, 1, 1, 1)
				end
			end
			local conIcono = d.objeto ~= nil or d.icono ~= nil
			f.Nombre:ClearAllPoints()
			f.Nombre:SetPoint("LEFT", f, "LEFT", conIcono and (ESP.base + 22 + ESP.m) or ESP.base, 0)
			K.Escribir(f.Nombre, d.nombre or "")
			K.Escribir(f.Detalle, d.detalle or "")
			K.Escribir(f.Valor, d.valor or "")
			local dw = (d.detalle and d.detalle ~= "") and (K.Ajustar(f.Detalle, floor(ancho * 0.45)) + ESP.base) or 0
			f.Nombre:SetWidth(max(60, ancho - (conIcono and 54 or 16) - 80 - dw))
			f.Nombre:SetWordWrap(false)
			f:Show()
			if i > 1 then
				local ln = self.lineas[i - 1] or K.Linea(self.Panel, "linea")
				self.lineas[i - 1] = ln
				ln:ClearAllPoints()
				ln:SetPoint("TOPLEFT", self.Panel, "TOPLEFT", ESP.base, -(i - 1) * FILA)
				ln:SetPoint("TOPRIGHT", self.Panel, "TOPRIGHT", -ESP.base, -(i - 1) * FILA)
				ln:Show()
			end
		end
		for i = n + 1, #self.filas do self.filas[i]:Hide() end
		for i = max(1, n), #self.lineas do self.lineas[i]:Hide() end
		self.Panel:ClearAllPoints()
		self.Panel:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
		self.Panel:SetSize(ancho, max(1, n * FILA))
		y = y + n * FILA
		if #self.datos > n then
			K.Escribir(self.Mas, L["y %d más"]:format(#self.datos - n))
			self.Mas:ClearAllPoints()
			self.Mas:SetPoint("TOPLEFT", self, "TOPLEFT", 2, -(y + ESP.s))
			self.Mas:Show()
			y = y + ESP.s + 14
		else
			self.Mas:Hide()
		end
		self:SetSize(ancho, y)
		return y
	end
	return b
end

local function datosRecursos(s)
	local out = {}
	for _, e in ipairs(ordenadoPorValor(s.recursos)) do
		local g = M.porClave[e.k]
		if g then
			local gr = M.GRUPOS[g]
			local icono, glifo = R.Icono(g)
			out[#out + 1] = { icono = icono, glifo = glifo, nombre = R.Nombre(g), detalle = R.NombreTipo(gr.tipo), valor = miles(e.v) }
		end
	end
	return out
end

local function datosObjetos(s)
	local out = {}
	local C = A.Compat
	for _, e in ipairs(ordenadoPorValor(s.objetos)) do
		local id = tonumber(e.k)
		if id then
			local nombre = C.GetItemName and C.GetItemName(id)
			if not nombre then
				if C.RequestItem then C.RequestItem(id) end
				nombre = L["Cargando…"]
				V.esperaObjetos = true
			end
			out[#out + 1] = { objeto = id, nombre = nombre, valor = "\195\151" .. miles(e.v) }
		end
	end
	return out
end

local function datosZonas(P)
	local out, lista = {}, {}
	for mapID, z in pairs(P.zonas or {}) do
		if type(z) == "table" then lista[#lista + 1] = { m = mapID, z = z, v = tonumber(z.total) or 0 } end
	end
	table.sort(lista, function(a, b)
		if a.v ~= b.v then return a.v > b.v end
		return tostring(a.m) < tostring(b.m)
	end)
	for _, e in ipairs(lista) do
		local partes = {}
		for _, tipo in ipairs(M.TIPOS) do
			local n = tonumber(e.z.tipos and e.z.tipos[tipo]) or 0
			if n > 0 then partes[#partes + 1] = R.NombreTipo(tipo) .. " " .. miles(n) end
		end
		out[#out + 1] = { nombre = nombreZona(e.m), detalle = table.concat(partes, DOT), valor = miles(e.v) }
	end
	return out
end

local function datosSesiones(P)
	local out = {}
	local actual = R.Sesion()
	local lista = P.sesiones or {}
	for k = #lista, 1, -1 do
		local s = lista[k]
		if type(s) == "table" and s ~= actual and (tonumber(s.total) or 0) > 0 then
			local dur = max(0, (tonumber(s.fin) or 0) - (tonumber(s.inicio) or 0))
			local detalle = N.Duracion(dur)
			local ph = porHora(tonumber(s.total) or 0, dur)
			if ph then detalle = detalle .. DOT .. L["%s por hora"]:format(miles(ph)) end
			local oro = R.ValorSesion(s)
			if oro > 0 then detalle = detalle .. DOT .. L["≈ %s"]:format(N.DineroTexto(oro, true)) end
			out[#out + 1] = { nombre = date("%d/%m/%Y %H:%M", tonumber(s.inicio) or 0), detalle = detalle, valor = miles(s.total) }
		end
	end
	return out
end

local function bloqueHistorial(padre)
	local b = K.Pila(padre, { espacio = ESP.l })
	b.Recursos = b:Agregar(bloqueLista(b, L["Esta sesión, por recurso"]))
	b.Objetos = b:Agregar(bloqueLista(b, L["Lo que obtuviste en esta sesión"]))
	b.Zonas = b:Agregar(bloqueLista(b, L["Por zona (este personaje)"]))
	b.Sesiones = b:Agregar(bloqueLista(b, L["Sesiones anteriores"]))
	b.Vacio = b:Agregar(K.Vacio(b, {
		lobo = "dormido", titulo = L["Todavía no recolectas nada"],
		texto = L["Mina, herboriza, pesca en un banco o abre un cofre: aquí verás cuánto, qué te dio cada nodo y en qué zona."],
	}))
	function b:Llenar()
		local s, P = R.Sesion(), R.Personaje()
		V.esperaObjetos = false
		local hay = false
		for _, par in ipairs({ { self.Recursos, datosRecursos(s) }, { self.Objetos, datosObjetos(s) },
			{ self.Zonas, datosZonas(P) }, { self.Sesiones, datosSesiones(P) } }) do
			par[1]:Set(par[2])
			K.Mostrar(par[1], #par[2] > 0)
			if #par[2] > 0 then hay = true end
		end
		K.Mostrar(self.Vacio, not hay)
	end
	return b
end

---------------------------------------------------------------------------
-- 4. Los ajustes y 5. tus datos
---------------------------------------------------------------------------
local function interruptor(k) return function(fila) return K.Interruptor(fila, { clave = clave(k) }) end end
local function deslizador(k)
	return function(fila)
		local d = K.Deslizador(fila, { min = 0.6, max = 1.8, paso = 0.05, clave = clave(k), formato = porciento })
		d.alfaAnchoFila = 220
		return d
	end
end
local function interruptorTipo(tipo)
	return function(fila)
		-- Su ajuste (recoleccion.<tipo>) copia la capa de Mundo; manda la capa.
		local s = K.Interruptor(fila, { clave = clave(tipo), alCambiar = function(v) ponerTipo(tipo, v) end })
		function s:Leer() self:SetValor(R.TipoActivo(tipo)) end
		s:Leer()
		return s
	end
end
local function on(k) return function() return N.Get(ID, k) ~= false end end

local function grupos(padre)
	local donde = K.GrupoAjustes(padre, { titulo = L["Dónde se ven"] })
	donde:Fila({ titulo = L["En el mapa del mundo"], control = interruptor("mapa"),
		texto = L["Los nodos de la zona que miras, con su nombre, nivel y cuántas veces los recolectaste al pasar el ratón. Clic en uno: la flecha te lleva."] })
	donde:Fila({ titulo = L["Tamaño en el mapa"], hija = true, activa = on("mapa"), control = deslizador("tamanoMapa") })
	donde:Fila({ titulo = L["En el minimapa"], control = interruptor("minimapa"),
		texto = L["Los nodos que tienes cerca. El punto del rastreo del juego dice si ahora hay algo ahí."] })
	donde:Fila({ titulo = L["Tamaño en el minimapa"], hija = true, activa = on("minimapa"), control = deslizador("tamanoMinimapa") })

	local que = K.GrupoAjustes(padre, { titulo = L["Qué se ve"] })
	local AYUDA = {
		mineria = L["Filones y depósitos de mineral."], hierbas = L["Las plantas de herboristería."],
		pesca = L["Bancos y restos flotantes donde pescar."], tesoros = L["Cofres, baúles y almejas que se abren."],
	}
	for _, tipo in ipairs(M.TIPOS) do
		que:Fila({ titulo = R.NombreTipo(tipo), texto = AYUDA[tipo], control = interruptorTipo(tipo) })
	end
	que:Fila({ titulo = L["Ocultar lo de profesiones que no tienes"], control = interruptor("soloProfesiones"),
		texto = L["Sin Minería no ves filones; sin Herboristería, hierbas; sin Pesca, bancos. Los tesoros siempre se ven."] })
	que:Fila({ titulo = L["Solo lo que ya puedes recolectar"], control = interruptor("soloHabilidad"),
		texto = L["Esconde lo que pide más habilidad de la que tienes. Sin esto se ve gris y tenue."] })

	que:Fila({ titulo = L["Avisar al poder recolectar algo nuevo"], control = interruptor("avisoNuevo"),
		texto = L["Al subir Minería o Herboristería al nivel de otro recurso, un aviso con «Llévame» a la zona más cercana de tu nivel."] })
	que:Fila({ titulo = L["Avisar si te falta el pico o el cuchillo"], control = interruptor("avisoHerramienta"),
		texto = L["Si el juego no te deja minar o desollar por la herramienta, Alfa te dice qué falta y dónde se compra."] })

	local mapa = K.GrupoAjustes(padre, { titulo = L["En el mapa"] })
	mapa:Fila({ titulo = L["Juntar nodos cercanos al alejar"], control = interruptor("agrupar"),
		texto = L["Los nodos que se pisarían en pantalla van en un solo pin con su cantidad. Al acercar el mapa se separan."] })
	mapa:Fila({ titulo = L["Usar la base de datos incluida"], control = interruptor("base"),
		texto = L["Los nodos que trae Alfa. Sin esto solo ves los que tú descubriste."] })
	mapa:Fila({ titulo = L["Guiar los pasos de juntar con una ruta corta"], control = interruptor("juntaRuta"),
		texto = L["Cuando tu guía pide juntar un mineral o una hierba, la flecha te lleva por las vetas más cercanas de una zona de tu nivel, empezando por la más cercana."] })

	local datos = K.GrupoAjustes(padre, { titulo = L["Tus datos"] })
	datos.conteo = datos:Fila({ titulo = L["Lo que conoce Alfa"], texto = "",
		control = function(fila)
			V.bDescubiertos = K.Boton(fila, L["Borrar lo que descubrí"], function()
				K.Dialogo({ titulo = L["¿Borrar lo que descubriste?"], peligro = true, aceptar = L["Borrar"],
					texto = L["Se quitan los nodos que anotaste al recolectar y cuántas veces los recolectaste. La base incluida se queda. No se puede deshacer."],
					alAceptar = function() R.BorrarDescubiertos() end })
			end, { tipo = "peligro", tam = "chico" })
			return V.bDescubiertos
		end })
	datos.historial = datos:Fila({ titulo = L["Tu historial"], texto = L["Las sesiones, las zonas y los objetos de este personaje."],
		control = function(fila)
			return K.Boton(fila, L["Borrar el historial"], function()
				K.Dialogo({ titulo = L["¿Borrar el historial?"], peligro = true, aceptar = L["Borrar"],
					texto = L["Se borran las sesiones, las zonas y los objetos de este personaje. No se puede deshacer."],
					alAceptar = function() R.BorrarHistorial() end })
			end, { tipo = "peligro", tam = "chico" })
		end })
	return { donde, que, mapa, datos }
end

-- -> texto, cuántos descubriste
local function textoConteo()
	local base, propios, zonas = R.Conteos()
	return L["La base incluida trae %s lugares en %d zonas. Tú descubriste %s."]:format(miles(base), zonas, miles(propios)), propios
end

local function hayHistorial()
	local P = R.Personaje()
	if (tonumber(P.total) or 0) > 0 then return true end
	for _, s in ipairs(P.sesiones or {}) do if type(s) == "table" and (tonumber(s.total) or 0) > 0 then return true end end
	return false
end

---------------------------------------------------------------------------
-- La página
---------------------------------------------------------------------------
local pagina

local function construir(view)
	pagina = view
	local t = K.Tablero(view, { margen = N.MargenPagina(), accion = "estado", tituloOpciones = L["Esta sesión"], min = 200 })
	V.que = t:AgregarBloque(grupoQueRecolectar(t.Extra), { espacio = ESP.base })
	V.historial = t:AgregarBloque(bloqueHistorial(t.Extra))
	V.grupos = grupos(t.Extra)
	for i, g in ipairs(V.grupos) do t:AgregarBloque(g, { espacio = i == 1 and ESP.xl or ESP.l }) end
	K.EnPagina(view, t, function()
		t:SetAccion(tarjetaRuta())
		t:SetOpciones(numeros(), L["Esta sesión"])
		-- "Qué recolectar" solo donde hay nodos (fuera de instancias).
		if V.desRecurso then V.desRecurso:SetOpciones(opcionesRecurso()) end
		V.que:Refrescar()
		K.Mostrar(V.que, Ruta.ZonaActual() ~= nil and not R.EnInstancia() and not Ruta.Calculando())
		V.historial:Llenar()
		-- Borrar solo cuando hay algo que borrar.
		local datos = V.grupos[4]
		local texto, propios = textoConteo()
		datos.conteo.alfaDatos.texto = texto
		for _, g in ipairs(V.grupos) do g:Refrescar() end
		if V.bDescubiertos then V.bDescubiertos:SetShown(propios > 0) end
		K.Mostrar(datos.historial, hayHistorial())
	end)
	-- 1.3.6: sin OnShow; la ventana ya mide la página al mostrarla (O.Select).
end

---------------------------------------------------------------------------
-- Volver a armar la página abierta (como mucho 4 veces por segundo).
---------------------------------------------------------------------------
M.Pagina = {}
local pendiente = false

local function rehacer()
	pendiente = false
	if pagina then N.RehacerPagina(pagina) end
end

function M.Pagina.Actualizar()
	if pendiente then return end
	pendiente = true
	A.After(0.25, rehacer)
end

R.AlCambiar(function() M.Pagina.Actualizar() end)
A.RegisterEvent("GET_ITEM_INFO_RECEIVED", function()
	if V.esperaObjetos then M.Pagina.Actualizar() end
end)
A.RegisterEvent("ZONE_CHANGED_NEW_AREA", function() M.Pagina.Actualizar() end)

---------------------------------------------------------------------------
-- El módulo
---------------------------------------------------------------------------
N.Modulo({
	id = ID, nombre = L["Recolección"], icono = "ic-recoleccion", orden = 32,
	-- 1.3.6: subtítulo corto y sin jerga («farmeo»).
	subtitulo = L["Minas, hierbas, pesca y tesoros, con rutas para juntar"],
	comando = "recoleccion",
	ajustes = AJUSTES,
	controles = BUSCAR,
	construir = construir,
})

-- /alfa recoleccion [ruta [tipo] | guiar | parar | mapa | minimapa]
local TIPO_POR_PALABRA = {
	mineria = "mineria", ["minería"] = "mineria", mining = "mineria", minar = "mineria",
	hierbas = "hierbas", herboristeria = "hierbas", ["herboristería"] = "hierbas", herbs = "hierbas",
	pesca = "pesca", fishing = "pesca", peces = "pesca",
	tesoros = "tesoros", cofres = "tesoros", chests = "tesoros",
}

-- 1.3.6: crear y seguir una ruta, para el comando y para el botón del aviso.
local function crearRuta(arg)
	local tipo = TIPO_POR_PALABRA[arg or ""] or tipoRuta() or "mineria"
	local recurso = TIPO_POR_PALABRA[arg or ""] and "todos" or (N.Get(ID, "rutaRecurso") or "todos")
	local ok, motivo = Ruta.Crear(tipo, recurso, nil, function(r)
		if r and r.n then
			N.Imprimir(L["Ruta lista en %s: %s"]:format(nombreZona(r.mapa), Ruta.Resumen(r) or ""))
			Ruta.Guiar()
		end
	end)
	if not ok then N.Imprimir(motivo) end
end

A.RegisterCommand("recoleccion", function(resto)
	local orden, arg = (resto or ""):lower():match("^%s*(%S*)%s*(%S*)")
	if orden == "" then return N.Abrir(ID) end
	if orden == "ruta" then
		crearRuta(arg)
	elseif orden == "guiar" then
		-- 1.3.6: un aviso con el botón que la crea, en vez de pedir otro comando.
		if not Ruta.Guiar() then
			K.Aviso({ titulo = L["Todavía no tienes una ruta"], icono = "ic-recoleccion", tono = "acento",
				texto = L["Alfa arma una con lo que puedes juntar en tu zona y la flecha te lleva de punto en punto."],
				accion = { texto = L["Crear una ruta aquí"], alClic = function() crearRuta("") end } })
		end
	-- 1.3.9 (oficios): /alfa recoleccion llevame plata: la mejor zona y la ruta por sus puntos.
	elseif orden == "llevame" or orden == "llévame" or orden == "buscar" then
		local texto = (resto or ""):match("^%s*%S+%s+(.+)$")
		local ok = M.Llevar.Llevar(texto or "")
		if not ok then N.Imprimir(L["No encontré ese recurso en las zonas de tu facción."]) end
	elseif orden == "parar" then
		Ruta.Detener()
	elseif orden == "mapa" or orden == "minimapa" then
		-- 1.3.7: cada uno prende o apaga lo suyo y lo dice (antes los dos
		-- decían «Nodos visibles.» y no se sabía cuál cambió).
		N.Set(ID, orden, N.Get(ID, orden) == false)
		local ver = N.Get(ID, orden) ~= false
		if orden == "mapa" then
			N.Imprimir(ver and L["Nodos en el mapa del mundo: visibles."] or L["Nodos en el mapa del mundo: ocultos."])
		else
			N.Imprimir(ver and L["Nodos en el minimapa: visibles."] or L["Nodos en el minimapa: ocultos."])
		end
	else
		N.Imprimir(L["Uso: /alfa recoleccion [ruta [mineria|hierbas|pesca|tesoros] | guiar | parar | mapa | minimapa]"])
	end
end, L["Abre Recolección. Con «ruta», crea y sigue una ruta para juntar en tu zona."])

---------------------------------------------------------------------------
-- Arranque
---------------------------------------------------------------------------
local FILTROS = { mineria = true, hierbas = true, pesca = true, tesoros = true, soloProfesiones = true, soloHabilidad = true, base = true }

A.On("SETTING_CHANGED", function(path)
	if type(path) ~= "string" then return end
	local k = path:match("^recoleccion%.(.+)$")
	if not k then
		-- Ajustes de vuelta a sus valores: todos ("") o los de este módulo.
		if path == "" or path == ID then
			R.Refiltrar()
			M.Pagina.Actualizar()
		end
		return
	end
	if FILTROS[k] then R.Refiltrar() end
	if k == "rutaTipo" or k == "rutaRecurso" then V.aviso = nil end
	if k == "rutaTipo" then N.Set(ID, "rutaRecurso", "todos") end
	M.Pagina.Actualizar()
end)

local habilidadesPendiente = false
local function releer()
	habilidadesPendiente = false
	R.LeerHabilidades()
	R.Refiltrar()
end
A.RegisterEvent("SKILL_LINES_CHANGED", function()
	if habilidadesPendiente then return end
	habilidadesPendiente = true
	A.After(0.3, releer)
end)

A.RegisterEvent("PLAYER_LOGOUT", function() R.CerrarSesion() end)

-- 1.3.9 (oficios): lo que las guías de oficios de Alfa (Alfa_Rutas/Oficios*.lua)
-- leen de aquí: el catálogo, la base de nodos y el nombre de cada recurso.
AlfaRecoleccion = type(rawget(_G, "AlfaRecoleccion")) == "table" and rawget(_G, "AlfaRecoleccion") or {}
AlfaRecoleccion.Datos = function() return { grupos = M.GRUPOS, base = M.BASE, nombre = R.Nombre, porObjeto = M.porObjeto, puntosDe = R.PuntosDe } end

A.OnLogin(function()
	R.LeerHabilidades()
	R.Refiltrar()
	R.Sesion()
	M.Mapa.Instalar()
	M.Mini.Instalar()
	if M.MapaMundo then M.MapaMundo.Instalar() end
	-- Las habilidades pueden llegar tarde.
	A.After(3, releer)
end)
