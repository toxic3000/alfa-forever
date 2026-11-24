-- Alfa - Pesca: la pestaña Sesiones (toxic3000 / La Jauría). GPL-3.0.
--
-- 1.3.8: el historial de tus sesiones de pesca, una tarjeta por sesión con
-- dónde fue, cuántos peces, el tamaño total, peces por hora y la mejor
-- captura. Arriba, filtros por día (hoy, esta semana, este mes) y por lugar,
-- y lo que suman las sesiones a la vista. La sesión de ahora va primero.
-- Las sesiones las guarda Registro.lua (las 40 últimas).

local ADDON, M = ...
local N = AlfaNucleo
local K = N.Kit
local L = M.L
local V = M.V

local floor, max, min, format, type, pairs, ipairs, tonumber, tostring = math.floor, math.max, math.min, string.format, type, pairs, ipairs, tonumber, tostring
local ESP = K.ESP
local DOT = " \194\183 "

local function num(v) return tonumber(v) or 0 end

-- El lugar principal de una sesión (donde más sacaste) y cuántos más hubo.
local function lugarDe(h)
	local mejor, n, otros = nil, -1, 0
	for z, c in pairs(h.zonas or {}) do
		otros = otros + 1
		if num(c) > n then mejor, n = z, num(c) end
	end
	return mejor, max(0, otros - 1)
end

local function inicioDelDia(t)
	local d = date("*t", t)
	d.hour, d.min, d.sec = 0, 0, 0
	return time(d)
end

-- filtro: "todas" | "hoy" | "semana" | "mes"
local function pasa(h, filtro, lugar, ahora)
	local t = num(h.inicio)
	if filtro == "hoy" and t < inicioDelDia(ahora) then return false end
	if filtro == "semana" and t < ahora - 7 * 86400 then return false end
	if filtro == "mes" and t < ahora - 30 * 86400 then return false end
	if lugar and lugar ~= "" then
		local z = h.zonas or {}
		if num(z[lugar]) <= 0 then return false end
	end
	return true
end

-- Todas: la de ahora (si ya pescaste algo) y las anteriores.
local function sesiones()
	local out = {}
	local s = M.Sesion()
	if num(s.lanzamientos) + num(s.capturas) > 0 then
		local actual = {}
		for k, v in pairs(s) do actual[k] = v end
		actual.enCurso = true
		local objetos = {}
		for _, o in pairs(s.objetos or {}) do
			if type(o) == "table" and num(o.cantidad) > 0 then objetos[o.id or o.nombre or "?"] = num(o.cantidad) end
		end
		actual.objetos = objetos
		out[1] = actual
	end
	for _, h in ipairs(M.Historial()) do if type(h) == "table" then out[#out + 1] = h end end
	return out
end

local function lugares(lista)
	local vistos, out = {}, {}
	for _, h in ipairs(lista) do
		for z in pairs(h.zonas or {}) do
			if not vistos[z] then vistos[z] = true out[#out + 1] = z end
		end
	end
	table.sort(out)
	return out
end

local function topObjetos(objetos, n)
	local o = {}
	for id, c in pairs(objetos or {}) do o[#o + 1] = { id, num(c) } end
	table.sort(o, function(a, b) return a[2] > b[2] end)
	local out = {}
	for i = 1, min(n or 3, #o) do
		local id = o[i][1]
		local nombre = type(id) == "number" and V.NombreObjeto(id) or tostring(id)
		out[#out + 1] = { format(L["%s ×%d"], nombre, o[i][2]), M.TONO_CLASE[M.CLASE[id] or "otro"] or "neutro" }
	end
	return out
end

function M.TarjetaSesion(h)
	local Pz = M.Pez
	local c = M.Cuentas(h)
	local fin = h.enCurso and L["ahora"] or (h.fin and date("%H:%M", h.fin) or "?")
	local lugar, otros = lugarDe(h)
	local lineas = {}
	if lugar then
		lineas[#lineas + 1] = otros > 0 and format(L["%s y %s"], lugar, N.Plural(otros, L["%d lugar más"], L["%d lugares más"])) or lugar
	end
	local partes = { N.Plural(num(h.total), L["%d pez"], L["%d peces"]) }
	if num(h.peso) > 0 and Pz then partes[#partes + 1] = Pz.Peso(h.peso) end
	partes[#partes + 1] = c.porHora and format(L["%d por hora"], floor(c.porHora + 0.5)) or L["— por hora"]
	lineas[#lineas + 1] = table.concat(partes, DOT)
	if type(h.mejor) == "table" and Pz then
		local nombre = h.mejor.nombre or (type(h.mejor.id) == "number" and V.NombreObjeto(h.mejor.id)) or "?"
		lineas[#lineas + 1] = format(L["La mejor: %s, %s"], nombre, Pz.Texto(h.mejor) or Pz.Peso(h.mejor.g))
	end
	return {
		icono = h.enCurso and "ic-pesca" or "ic-lista", tono = h.enCurso and "exito" or "acento",
		sobre = h.enCurso and L["En curso"] or nil,
		titulo = format(L["%s – %s"], V.Fecha(h.inicio), fin),
		texto = table.concat(lineas, "\n"), insignias = topObjetos(h.objetos, 3),
		valor = N.Dinero(num(h.valor), true),
		lineas = 4,
	}
end

local function construir(padre)
	local p = V.Pagina(padre)
	local pila = p.pila
	local estado = { filtro = "todas", lugar = "" }
	local ui = {}
	local barra = CreateFrame("Frame", nil, pila)
	barra.Seg = K.Segmentos(barra, { estilo = "pildoras", valor = "todas", opciones = {
		{ valor = "todas", texto = L["Todas"] }, { valor = "hoy", texto = L["Hoy"] },
		{ valor = "semana", texto = L["Esta semana"] }, { valor = "mes", texto = L["Este mes"] },
	}, alCambiar = function(v2) estado.filtro = v2 V.Acomodar() end })
	barra.Lugar = K.Desplegable(barra, { ancho = 220, opciones = {}, valor = "",
		alCambiar = function(v2) estado.lugar = v2 or "" V.Acomodar() end })
	function barra:Acomodar(ancho)
		local h, w = self.Seg:Acomodar(ancho - 220 - ESP.m)
		self.Seg:ClearAllPoints()
		self.Seg:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
		self.Lugar:ClearAllPoints()
		if (w or 0) + ESP.m + 220 <= ancho then
			self.Lugar:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0)
			-- Las pastillas, al centro del alto del desplegable.
			self.Seg:ClearAllPoints()
			self.Seg:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -floor((K.ALTO.control - h) / 2))
			h = max(h, K.ALTO.control)
		else
			self.Lugar:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -(h + ESP.s))
			h = h + ESP.s + K.ALTO.control
		end
		self:SetSize(ancho, h)
		return h
	end
	ui.barra = pila:Agregar(barra)
	ui.resumen = pila:Agregar(K.Tarjeta(pila, { variante = "compacta" }), { espacio = ESP.m })
	ui.lista = pila:Agregar(K.Rejilla(pila, { min = 360, gap = ESP.m }), { espacio = ESP.m })
	ui.vacio = pila:Agregar(K.Vacio(pila, { lobo = "dormido", titulo = L["No hay sesiones con ese filtro"],
		texto = L["Una sesión termina tras 20 minutos sin lanzar o cuando empiezas otra; entonces aparece aquí con lo que sacaste y dónde."] }), { espacio = ESP.m })
	p.antes = function()
		local todas = sesiones()
		local ops = { { valor = "", texto = L["Todos los lugares"] } }
		for _, z in ipairs(lugares(todas)) do ops[#ops + 1] = { valor = z, texto = z } end
		barra.Lugar:SetOpciones(ops)
		local existe = estado.lugar == ""
		for _, o in ipairs(ops) do if o.valor == estado.lugar then existe = true end end
		if not existe then estado.lugar = "" end
		barra.Lugar:SetValor(estado.lugar)
		barra.Seg:SetValor(estado.filtro)
		local ahora = time()
		local vistas, datos = {}, {}
		local peces, peso, activo, capt = 0, 0, 0, 0
		for _, h in ipairs(todas) do
			if pasa(h, estado.filtro, estado.lugar, ahora) then
				vistas[#vistas + 1] = h
				datos[#datos + 1] = M.TarjetaSesion(h)
				peces = peces + num(h.total)
				peso = peso + num(h.peso)
				activo = activo + num(h.activo)
				capt = capt + num(h.capturas)
			end
		end
		ui.lista:Llenar(datos)
		K.Mostrar(ui.lista, #datos > 0)
		K.Mostrar(ui.vacio, #datos == 0)
		local partes = { N.Plural(peces, L["%d pez"], L["%d peces"]) }
		if peso > 0 and M.Pez then partes[#partes + 1] = M.Pez.Peso(peso) end
		if activo >= 60 then partes[#partes + 1] = format(L["%d por hora"], floor(capt / (activo / 3600) + 0.5)) end
		if activo >= 1 then partes[#partes + 1] = N.Duracion(activo, true) end
		ui.resumen:Set({ variante = "compacta", icono = "ic-nivel", tono = "acento",
			titulo = N.Plural(#vistas, L["%d sesión"], L["%d sesiones"]), texto = table.concat(partes, DOT) })
		K.Mostrar(ui.resumen, #vistas > 0)
	end
	return p
end

V.Registrar("sesiones", { nombre = L["Sesiones"], icono = "ic-lista", orden = 2.5,
	cambia = { registro = true, captura = true }, construir = construir })
