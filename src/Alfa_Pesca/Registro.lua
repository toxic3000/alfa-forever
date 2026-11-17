-- Alfa - Pesca: el registro (toxic3000 / La Jauría). GPL-3.0.
--
-- Todo lo que pescas queda anotado por personaje (N.DatosPersonaje("pesca")):
--   sesion     la de ahora: lanzamientos, capturas, escapes, tiempo, valor,
--              lo pescado y dónde
--   historial  las sesiones anteriores (las 40 últimas), con lo pescado y
--              las zonas
--   vida       los totales desde que usas Alfa
--   diario     por captura: cuántas, la primera y la última vez, con qué
--              habilidad la sacaste la primera vez y en qué zonas
--   registro   cada captura (objeto, cantidad, zona, subzona, fecha): las
--              1500 últimas
--   logros     los logros de pesca de Alfa y cuándo los ganaste
--   metas      tus metas (Metas.lua) y cuánto llevas
-- Una sesión termina sola tras 20 minutos sin lanzar (o al empezar una nueva
-- a mano) y pasa al historial.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = M.L
local ID = M.ID

local floor, max, min, format, time, tonumber, type, pairs, ipairs = math.floor, math.max, math.min, string.format, time, tonumber, type, pairs, ipairs

local R = {}
M.R = R

local PAUSA_SESION = 20 * 60   -- sin lanzar este tiempo, la sesión se cierra
local MAX_HISTORIAL = 40
local MAX_REGISTRO = 1500
local HUECO_ACTIVO = 60         -- un hueco entre lanzamientos más corto que esto cuenta como pescar

local function datos() return N.DatosPersonaje(ID) end
local function num(v) return tonumber(v) or 0 end

---------------------------------------------------------------------------
-- Avisos internos: quien dibuja algo se anota y recibe los cambios juntos.
---------------------------------------------------------------------------
local oyentes, pendiente, motivos = {}, false, {}
function M.Escuchar(fn) oyentes[#oyentes + 1] = fn end

function M.Avisar(que)
	motivos[que or "todo"] = true
	if pendiente then return end
	pendiente = true
	A.After(0.05, function()
		pendiente = false
		local m = motivos
		motivos = {}
		for i = 1, #oyentes do
			local ok, err = pcall(oyentes[i], m)
			if not ok and geterrorhandler then geterrorhandler()(err) end
		end
		if M.alCambiar then M.alCambiar(m) end
	end)
end

---------------------------------------------------------------------------
-- Sesión
---------------------------------------------------------------------------
local CAMPOS = { "segundos", "activo", "lanzamientos", "capturas", "total", "escapes", "fallos", "valor", "subasta",
	"racha", "mejorRacha", "tiempoCaptura", "nTiempo", "bancos" }

function M.Sesion()
	local d = datos()
	local s = d.sesion
	if type(s) ~= "table" then
		s = {}
		d.sesion = s
	end
	if type(s.objetos) ~= "table" then s.objetos = {} end
	if type(s.zonas) ~= "table" then s.zonas = {} end
	s.inicio = tonumber(s.inicio) or time()
	for _, k in ipairs(CAMPOS) do s[k] = num(s[k]) end
	if s.rangoInicial == nil and M.Habilidad then s.rangoInicial = M.Habilidad() end
	return s
end

function M.Vida()
	local d = datos()
	local v = d.vida
	if type(v) ~= "table" then
		v = { primera = time() }
		d.vida = v
	end
	for _, k in ipairs({ "lanzamientos", "capturas", "total", "escapes", "segundos", "activo", "valor", "subasta", "sesiones",
		"cebos", "bancos", "lotes", "cocinado", "mejorRacha", "mejorHora", "mejorValor" }) do v[k] = num(v[k]) end
	return v
end

local function lista(d, clave)
	if type(d[clave]) ~= "table" then d[clave] = {} end
	return d[clave]
end

function M.Historial() return lista(datos(), "historial") end
function M.Diario() return lista(datos(), "diario") end
function M.Logros() return lista(datos(), "logros") end
function M.MetasGuardadas() return lista(datos(), "metas") end

-- La sesión de ahora pasa al historial (si tuvo algo) y empieza otra.
function M.CerrarSesion()
	local d = datos()
	local s = d.sesion
	if type(s) == "table" and num(s.lanzamientos) + num(s.capturas) > 0 then
		local h = M.Historial()
		local objetos = {}
		for _, o in pairs(s.objetos or {}) do
			if type(o) == "table" and num(o.cantidad) > 0 then objetos[o.id or o.nombre or "?"] = num(o.cantidad) end
		end
		local zonas = {}
		for z, n in pairs(s.zonas or {}) do zonas[z] = num(n) end
		table.insert(h, 1, {
			inicio = s.inicio, fin = s.fin or s.inicio, segundos = num(s.segundos), activo = num(s.activo),
			lanzamientos = num(s.lanzamientos), capturas = num(s.capturas), total = num(s.total), escapes = num(s.escapes),
			valor = num(s.valor), subasta = num(s.subasta), objetos = objetos, zonas = zonas,
			rangoInicial = s.rangoInicial, rangoFinal = M.Habilidad and M.Habilidad() or nil,
		})
		for i = #h, MAX_HISTORIAL + 1, -1 do h[i] = nil end
		M.Vida().sesiones = M.Vida().sesiones + 1
	end
	d.sesion = nil
	return M.Sesion()
end

function M.NuevaSesion()
	local s = M.CerrarSesion()
	M.Avisar("registro")
	return s
end

-- Si la sesión lleva mucho sin lanzar, se cierra.
function R.Revisar(ahora)
	local s = M.Sesion()
	ahora = ahora or time()
	if s.fin and ahora - s.fin > PAUSA_SESION and s.lanzamientos + s.capturas > 0 then
		return M.CerrarSesion()
	end
	return s
end

-- Lo que pescaste en la sesión, de lo más a lo menos.
function M.Objetos()
	local out = {}
	for _, o in pairs(M.Sesion().objetos) do
		if type(o) == "table" and num(o.cantidad) > 0 then out[#out + 1] = o end
	end
	table.sort(out, function(a, b)
		if a.cantidad ~= b.cantidad then return a.cantidad > b.cantidad end
		return tostring(a.nombre or "") < tostring(b.nombre or "")
	end)
	return out
end

---------------------------------------------------------------------------
-- Lugares: la zona y la subzona de ahora (índices para el registro compacto)
---------------------------------------------------------------------------
local function texto(fn)
	if type(fn) ~= "function" then return nil end
	local ok, v = pcall(fn)
	if ok and type(v) == "string" and v ~= "" and not (issecretvalue and issecretvalue(v)) then return v end
	return nil
end

function M.Lugar()
	local zona = texto(GetRealZoneText) or texto(GetZoneText) or L["Sin zona"]
	local sub = texto(GetSubZoneText)
	return zona, sub
end

local function indiceLugar(nombre)
	if not nombre then return nil end
	local d = datos()
	local l = lista(d, "lugares")
	for i = 1, #l do if l[i] == nombre then return i end end
	l[#l + 1] = nombre
	return #l
end

function M.NombreLugar(i)
	local l = datos().lugares
	return type(l) == "table" and l[tonumber(i) or 0] or nil
end

function M.Registro() return lista(datos(), "registro") end

---------------------------------------------------------------------------
-- Valor de una captura: lo que paga el comerciante y, si Comercio sabe, la subasta
---------------------------------------------------------------------------
function M.ValorDe(id)
	id = tonumber(id)
	if not id then return 0, nil end
	local venta = 0
	if C_Item and C_Item.GetItemInfo then
		local ok, _, _, _, _, _, _, _, _, _, _, precio = pcall(C_Item.GetItemInfo, id)
		if ok and type(precio) == "number" then venta = precio end
	elseif GetItemInfo then
		local ok, _, _, _, _, _, _, _, _, _, _, precio = pcall(GetItemInfo, id)
		if ok and type(precio) == "number" then venta = precio end
	end
	local subasta
	local C = rawget(_G, "AlfaComercio")
	if type(C) == "table" and type(C.PrecioSubasta) == "function" then
		local ok, bruto = pcall(C.PrecioSubasta, id)
		if ok and type(bruto) == "number" and bruto > 0 then subasta = bruto end
	end
	return venta, subasta
end

---------------------------------------------------------------------------
-- Los momentos de la pesca (los llama Pesca.lua)
---------------------------------------------------------------------------
local ultimoInicio

-- Empezó un lanzamiento.
function R.Lanzamiento()
	local ahora = time()
	local s = R.Revisar(ahora)
	if s.ultimaActividad and ahora - s.ultimaActividad <= HUECO_ACTIVO then
		local hueco = max(0, ahora - s.ultimaActividad)
		s.activo = s.activo + hueco
		M.Vida().activo = M.Vida().activo + hueco
		M.SumarMeta("tiempo", nil, hueco)
	end
	s.lanzamientos = s.lanzamientos + 1
	s.fin = ahora
	ultimoInicio = GetTime and GetTime() or nil
	M.Vida().lanzamientos = M.Vida().lanzamientos + 1
	M.SumarMeta("lanzamientos", nil, 1)
	M.Avisar("registro")
end

-- Terminó el canal: seg con la caña en el agua; botin: si abrió el botín.
function R.FinCanal(seg, botin)
	local s = M.Sesion()
	seg = max(0, num(seg))
	s.segundos = s.segundos + seg
	s.activo = s.activo + seg
	s.ultimaActividad = time()
	s.fin = s.ultimaActividad
	local v = M.Vida()
	v.segundos = v.segundos + seg
	v.activo = v.activo + seg
	M.SumarMeta("tiempo", nil, seg)
	if not botin then s.fallos = s.fallos + 1 end
	if s.activo > v.mejorHora then v.mejorHora = s.activo end
	R.RevisarLogros()
	M.Avisar("registro")
end

function R.Escape()
	local s = M.Sesion()
	s.escapes = s.escapes + 1
	s.racha = 0
	M.Vida().escapes = M.Vida().escapes + 1
	M.Avisar("registro")
end

function R.Cebo()
	M.Vida().cebos = M.Vida().cebos + 1
	R.RevisarLogros()
end

function R.Cocinado(piezas, lote)
	local v = M.Vida()
	v.cocinado = v.cocinado + max(0, num(piezas))
	if lote then v.lotes = v.lotes + 1 end
	R.RevisarLogros()
	M.Avisar("registro")
end

-- Una ventana de botín de pesca que se cerró con lo que tomaste.
--   objetos = { { id, nombre, enlace, icono, calidad, cantidad }, ... }
--   info = { banco = objectID | nil }
-- -> lo nuevo: { { o, primera = bool, nivel = maestría alcanzada | nil }, ... }
function R.Captura(objetos, info)
	info = info or {}
	if #objetos == 0 then return {} end
	local s = M.Sesion()
	local v = M.Vida()
	local d = datos()
	local diario = M.Diario()
	local zona, sub = M.Lugar()
	local zi, si = indiceLugar(zona), indiceLugar(sub)
	local ahora = time()
	local rango = M.Habilidad and M.Habilidad() or nil
	local reg = M.Registro()
	local out = {}
	s.capturas = s.capturas + 1
	v.capturas = v.capturas + 1
	s.racha = s.racha + 1
	if s.racha > s.mejorRacha then s.mejorRacha = s.racha end
	if s.racha > v.mejorRacha then v.mejorRacha = s.racha end
	if ultimoInicio and GetTime then
		local t = GetTime() - ultimoInicio
		if t > 0 and t < 40 then
			s.tiempoCaptura = s.tiempoCaptura + t
			s.nTiempo = s.nTiempo + 1
		end
	end
	if info.banco then
		s.bancos = s.bancos + 1
		v.bancos = v.bancos + 1
	end
	s.zonas[zona] = num(s.zonas[zona]) + 1
	M.SumarMeta("capturas", nil, 1)
	for _, o in ipairs(objetos) do
		local clave = o.id or o.nombre or "?"
		local n = max(1, num(o.cantidad))
		-- La sesión.
		local g = s.objetos[clave]
		if type(g) ~= "table" then
			g = { id = o.id, nombre = o.nombre, cantidad = 0 }
			s.objetos[clave] = g
		end
		g.nombre, g.enlace, g.calidad = o.nombre, o.enlace, o.calidad
		g.icono = type(o.icono) ~= "table" and o.icono or nil
		g.cantidad = num(g.cantidad) + n
		s.total = s.total + n
		v.total = v.total + n
		-- El valor.
		local venta, subasta = M.ValorDe(o.id)
		s.valor = s.valor + venta * n
		v.valor = v.valor + venta * n
		if subasta then
			s.subasta = s.subasta + subasta * n
			v.subasta = v.subasta + subasta * n
		else
			s.subasta = s.subasta + venta * n
			v.subasta = v.subasta + venta * n
		end
		M.SumarMeta("valor", nil, venta * n)
		-- El diario.
		local e = diario[clave]
		local primera = type(e) ~= "table"
		if primera then
			e = { n = 0, primera = ahora, hab = rango, zonas = {} }
			diario[clave] = e
		end
		if type(e.zonas) ~= "table" then e.zonas = {} end
		local antes = M.Maestria(e.n)
		e.n = num(e.n) + n
		e.ultima = ahora
		e.nombre, e.calidad = o.nombre, o.calidad
		e.icono = type(o.icono) ~= "table" and o.icono or e.icono
		if rango and (not e.hab or rango < e.hab) then e.hab = rango end
		e.zonas[zona] = num(e.zonas[zona]) + n
		if info.banco then e.banco = info.banco end
		local despues = M.Maestria(e.n)
		M.SumarMeta("pez", clave, n)
		-- El registro de cada captura.
		reg[#reg + 1] = { t = ahora, id = clave, n = n, z = zi, s = si }
		out[#out + 1] = { o = o, primera = primera, nivel = despues > antes and despues or nil, total = e.n }
	end
	while #reg > MAX_REGISTRO do table.remove(reg, 1) end
	if s.valor > v.mejorValor then v.mejorValor = s.valor end
	s.fin = ahora
	s.ultimaActividad = ahora
	if M.EnConcurso and M.EnConcurso() and M.MapaJugador and M.MapaJugador() == M.CONCURSO.mapa then
		d.concurso = (tonumber(d.concurso) or 0) + 1
	end
	R.RevisarLogros()
	M.Avisar("registro")
	return out
end

---------------------------------------------------------------------------
-- Números para mostrar
---------------------------------------------------------------------------
-- t: una sesión, el historial o la vida -> { exito, porHora, medio }
function M.Cuentas(t)
	t = t or M.Sesion()
	local lanz, capt = num(t.lanzamientos), num(t.capturas)
	local exito = lanz > 0 and min(1, capt / lanz) or nil
	local activo = num(t.activo)
	local porHora = activo >= 60 and capt / (activo / 3600) or nil
	local medio = num(t.nTiempo) > 0 and num(t.tiempoCaptura) / num(t.nTiempo) or nil
	return { exito = exito, porHora = porHora, medio = medio }
end

-- Especies distintas que pescaste (en el diario).
function M.Especies()
	local n = 0
	for _, e in pairs(M.Diario()) do if type(e) == "table" and num(e.n) > 0 then n = n + 1 end end
	return n
end

local function especiesPorZona()
	local por = {}
	for _, e in pairs(M.Diario()) do
		if type(e) == "table" and type(e.zonas) == "table" then
			for z in pairs(e.zonas) do por[z] = (por[z] or 0) + 1 end
		end
	end
	local mejor, zonas = 0, 0
	for _, n in pairs(por) do
		zonas = zonas + 1
		if n > mejor then mejor = n end
	end
	return mejor, zonas
end

---------------------------------------------------------------------------
-- Logros
---------------------------------------------------------------------------
-- Cuánto llevas de lo que mide un logro.
function R.Medir(que)
	local v = M.Vida()
	if que == "capturas" then return v.capturas end
	if que == "especies" then return M.Especies() end
	if que == "trofeo" then
		local n = 0
		for clave, e in pairs(M.Diario()) do
			local c = M.CLASE[clave]
			if type(e) == "table" and (c == "trofeo" or c == "concurso") then n = n + num(e.n) end
		end
		return n
	end
	if que == "habilidad" then return (M.Habilidad and M.Habilidad()) or 0 end
	if que == "maximo" then
		local r, mx
		if M.Habilidad then r, mx = M.Habilidad() end
		if r and mx and mx >= 300 and r >= mx then return 300 end
		return r or 0
	end
	if que == "cebos" then return v.cebos end
	if que == "bancos" then return v.bancos end
	if que == "zonas" then return select(2, especiesPorZona()) end
	if que == "especiesZona" then return (especiesPorZona()) end
	if que == "lotes" then return v.lotes end
	if que == "cocinado" then return v.cocinado end
	if que == "hora" then return max(v.mejorHora, M.Sesion().activo) end
	if que == "racha" then return v.mejorRacha end
	if que == "maestria" then
		local mejor = 0
		for _, e in pairs(M.Diario()) do
			if type(e) == "table" then mejor = max(mejor, (M.Maestria(e.n))) end
		end
		return mejor
	end
	if que == "concurso" then return tonumber(datos().concurso) or 0 end
	if que == "valor" then return max(v.mejorValor, M.Sesion().valor) end
	return 0
end

-- Revisa todos; los nuevos se anuncian juntos en un solo aviso.
local revisando = false
function R.RevisarLogros()
	if revisando then return end
	revisando = true
	local hechos = M.Logros()
	local nuevos = {}
	for _, lg in ipairs(M.LOGROS) do
		if not hechos[lg.id] and R.Medir(lg.que) >= lg.n then
			hechos[lg.id] = time()
			nuevos[#nuevos + 1] = lg
		end
	end
	revisando = false
	if #nuevos > 0 and M.AnunciarLogros then M.AnunciarLogros(nuevos) end
	if #nuevos > 0 then M.Avisar("logros") end
end

---------------------------------------------------------------------------
-- Metas (Metas.lua las muestra): { uid, tipo, item, nombre, objetivo, hecho, cumplida }
--   tipo: "pez" (item: id o nombre) | "capturas" | "lanzamientos" | "tiempo" (segundos) | "valor" (cobre)
---------------------------------------------------------------------------
local seq = 0
function M.AgregarMeta(m)
	if type(m) ~= "table" or not m.tipo then return nil end
	seq = seq + 1
	local meta = {
		uid = tostring(time()) .. "_" .. seq, tipo = m.tipo, item = m.item, nombre = m.nombre,
		objetivo = max(1, floor(num(m.objetivo))), hecho = 0, creada = time(),
	}
	local lista = M.MetasGuardadas()
	lista[#lista + 1] = meta
	M.Avisar("metas")
	return meta
end

function M.QuitarMeta(uid)
	local lista = M.MetasGuardadas()
	for i = #lista, 1, -1 do
		if lista[i].uid == uid then table.remove(lista, i) end
	end
	M.Avisar("metas")
end

function M.ReiniciarMeta(uid)
	for _, m in ipairs(M.MetasGuardadas()) do
		if m.uid == uid then m.hecho, m.cumplida = 0, nil end
	end
	M.Avisar("metas")
end

function M.SumarMeta(tipo, item, n)
	n = num(n)
	if n <= 0 or #M.MetasGuardadas() == 0 then return end
	local cumplidas
	for _, m in ipairs(M.MetasGuardadas()) do
		if m.tipo == tipo and (tipo ~= "pez" or m.item == item) and not m.cumplida then
			m.hecho = num(m.hecho) + n
			if m.hecho >= num(m.objetivo) then
				m.cumplida = time()
				cumplidas = cumplidas or {}
				cumplidas[#cumplidas + 1] = m
			end
		end
	end
	if cumplidas and M.AnunciarMetas then M.AnunciarMetas(cumplidas) end
	M.Avisar("metas")
end

---------------------------------------------------------------------------
-- Borrar
---------------------------------------------------------------------------
function M.BorrarTodo()
	local d = datos()
	for _, k in ipairs({ "sesion", "historial", "vida", "diario", "registro", "lugares", "logros", "metas", "concurso" }) do d[k] = nil end
	M.Sesion()
	M.Avisar("registro")
end
