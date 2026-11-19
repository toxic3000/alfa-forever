-- Alfa - Rutas: Mis planes, listas de metas que arma el jugador
-- (toxic3000 / La Jauría). GPL-3.0.
--
-- Un plan es una lista ordenada de metas: "primero un objeto, luego 10 de
-- oro, luego cocina y luego el banco". Se guarda en la cuenta (sirve a
-- todos tus personajes); lo que lleva cada personaje se mide en vivo con el
-- juego y las metas pasadas quedan marcadas por personaje. El rastreador
-- muestra la meta de ahora (una a la vez) y, si tiene lugar, la flecha va
-- ahí sola al llegarle el turno.
--
-- Metas (tipo y sus datos):
--   objeto  item, kind, cantidad      hecha cuando tus bolsas lo tienen (Compat.GetItemCount)
--   oro     cobre                     hecha con GetMoney
--   prof    linea, nivel              hecha con el nivel de esa línea (nivel 1: aprenderla)
--   lugar   modo = "servicio" (servicio, linea) | "punto" (mapa, x, y, f, nombre)
--           | "marcador" (marcador + su mapa, x, y, nombre)      hecha al llegar
--   mision  quest, verbo = "accept" | "complete" | "turnin", titulo
--   nivel   nivel                     hecha con tu nivel
--   nota    texto                     la marcas tú
--
-- Datos de la cuenta (N.Datos("rutas").misPlanes):
--   { seq, orden = { id, ... }, lista = { [id] = { id, nombre, metas = { meta, ... }, creado, plantilla? } } }
-- Datos del personaje (N.DatosPersonaje("rutas")): planActivo = id,
--   planHechas = { [id] = { [uid] = true } }.
--
-- AlfaPlanes (global): Lista(), Activo(), Seguir(id), Dejar(), Nuevo(nombre),
--   Abrir(id) (el editor), Tarjeta() (la meta de ahora, para Hoy),
--   AgregarObjeto(itemID[, cantidad]) (a tu plan activo o a uno nuevo),
--   AgregarMeta(id, meta) (una meta como las de arriba).

local ADDON, M = ...
local A, L, N = M.A, M.L, M.N
local K = M.K

local Pl = {}
M.Planes = Pl

local type, ipairs, pairs, tostring, tonumber, pcall = type, ipairs, pairs, tostring, tonumber, pcall
local floor, max, min, format, sqrt = math.floor, math.max, math.min, string.format, math.sqrt

-- rutas.planFlecha: la flecha va sola a la meta con lugar cuando le toca.
A.RegisterDefaults(M.ID, { planFlecha = true })

local LLEGAR = 25 -- yardas: "llegaste"
local RIDING = 762

local ticker  -- revisa la meta de lugar mientras le toca
local ultima  -- uid de la meta de ahora en la última revisión (false: plan terminado)
local olvidarLugar -- adelante: el lugar ya buscado de una meta de servicio

local function llamar(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if ok then return a, b, c end
	return nil
end

local function Cp() return M.Motor("Compat") end

---------------------------------------------------------------------------
-- Datos
---------------------------------------------------------------------------

local function cuenta()
	local d = N.Datos(M.ID)
	local p = d.misPlanes
	if type(p) ~= "table" then
		p = {}
		d.misPlanes = p
	end
	if type(p.lista) ~= "table" then p.lista = {} end
	if type(p.orden) ~= "table" then p.orden = {} end
	p.seq = M.num(p.seq, 0)
	return p
end

local function personaje()
	local d = N.DatosPersonaje(M.ID)
	if type(d.planHechas) ~= "table" then d.planHechas = {} end
	return d
end

local function nuevoId(prefijo)
	local p = cuenta()
	p.seq = p.seq + 1
	return prefijo .. tostring(time and time() or 0) .. "_" .. p.seq
end

local TIPOS = { objeto = true, oro = true, prof = true, lugar = true, mision = true, nivel = true, nota = true }
Pl.TIPOS = { "objeto", "oro", "prof", "lugar", "mision", "nivel", "nota" }

-- Una meta limpia a partir de lo que llegue (editor, plantilla). -> meta | nil
function Pl.NuevaMeta(m)
	if type(m) ~= "table" or not TIPOS[m.tipo] then return nil end
	local t = { uid = m.uid or nuevoId("m"), tipo = m.tipo }
	if m.tipo == "objeto" then
		t.item = tonumber(m.item)
		if not t.item then return nil end
		t.kind = type(m.kind) == "string" and m.kind or "item"
		t.cantidad = max(1, min(9999, floor(M.num(tonumber(m.cantidad), 1))))
		t.nombre = type(m.nombre) == "string" and m.nombre or nil
	elseif m.tipo == "oro" then
		t.cobre = floor(M.num(tonumber(m.cobre), 0))
		if t.cobre <= 0 then return nil end
	elseif m.tipo == "prof" then
		t.linea = tonumber(m.linea)
		t.nivel = max(1, min(450, floor(M.num(tonumber(m.nivel), 1))))
		if not t.linea then return nil end
	elseif m.tipo == "lugar" then
		t.modo = m.modo
		t.nombre = type(m.nombre) == "string" and m.nombre or nil
		if m.modo == "servicio" then
			if type(m.servicio) ~= "string" then return nil end
			t.servicio, t.linea = m.servicio, tonumber(m.linea)
		elseif m.modo == "punto" or m.modo == "marcador" then
			t.mapa, t.x, t.y = tonumber(m.mapa), tonumber(m.x), tonumber(m.y)
			if not (t.mapa and t.x and t.y) then return nil end
			t.f = m.f == "e" and "e" or nil
			t.marcador = m.marcador
			t.mazmorra = m.mazmorra
		else
			return nil
		end
	elseif m.tipo == "mision" then
		t.quest = tonumber(m.quest)
		if not t.quest then return nil end
		t.verbo = (m.verbo == "accept" or m.verbo == "complete") and m.verbo or "turnin"
		t.titulo = type(m.titulo) == "string" and m.titulo or nil
	elseif m.tipo == "nivel" then
		t.nivel = max(2, min(80, floor(M.num(tonumber(m.nivel), 2))))
	elseif m.tipo == "nota" then
		t.texto = type(m.texto) == "string" and m.texto:sub(1, 200) or ""
		if t.texto == "" then return nil end
	end
	return t
end

function Pl.Lista()
	local p = cuenta()
	local out, vistos = {}, {}
	for _, id in ipairs(p.orden) do
		local pl = p.lista[id]
		if type(pl) == "table" and not vistos[id] then
			vistos[id] = true
			out[#out + 1] = pl
		end
	end
	-- Los que quedaron fuera del orden (no debería pasar) van al final.
	for id, pl in pairs(p.lista) do
		if not vistos[id] and type(pl) == "table" then
			p.orden[#p.orden + 1] = id
			out[#out + 1] = pl
		end
	end
	return out
end

function Pl.De(id)
	local pl = id and cuenta().lista[id]
	if type(pl) ~= "table" then return nil end
	if type(pl.metas) ~= "table" then pl.metas = {} end
	return pl
end

-- PLANES (interno) y ALFA_PLAN (del motor, para Hoy): algo cambió en los planes.
local function cambio(pl)
	if pl then pl.cambiado = time and time() or 0 end
	M.Avisar("PLANES")
	A.Fire("ALFA_PLAN")
end

-- Tras editar un plan: revisar sin anunciar "Meta cumplida" ni mover la flecha.
local function revisarCallado()
	ultima = nil
	Pl.Revisar()
end

function Pl.Nuevo(nombre, metas, plantilla)
	local p = cuenta()
	local pl = { id = nuevoId("p"), nombre = (type(nombre) == "string" and nombre ~= "") and nombre or L["Mi plan"], metas = {},
		creado = time and time() or 0, plantilla = plantilla }
	for _, m in ipairs(metas or {}) do
		local t = Pl.NuevaMeta(m)
		if t then pl.metas[#pl.metas + 1] = t end
	end
	p.lista[pl.id] = pl
	table.insert(p.orden, 1, pl.id)
	cambio(pl)
	return pl
end

function Pl.Duplicar(id)
	local pl = Pl.De(id)
	if not pl then return nil end
	local metas = {}
	for i, m in ipairs(pl.metas) do
		local c = M.Copia(m)
		c.uid = nil
		metas[i] = c
	end
	return Pl.Nuevo(format(L["%s (copia)"], pl.nombre), metas, pl.plantilla)
end

function Pl.Borrar(id)
	local p = cuenta()
	if not p.lista[id] then return end
	p.lista[id] = nil
	for i = #p.orden, 1, -1 do if p.orden[i] == id then table.remove(p.orden, i) end end
	local c = personaje()
	c.planHechas[id] = nil
	if c.planActivo == id then c.planActivo = nil end
	cambio(nil)
end

function Pl.Renombrar(id, nombre)
	local pl = Pl.De(id)
	if not pl or type(nombre) ~= "string" then return end
	nombre = nombre:gsub("^%s+", ""):gsub("%s+$", "")
	if nombre == "" then return end
	pl.nombre = nombre:sub(1, 60)
	cambio(pl)
end

local function indice(pl, uid)
	for i, m in ipairs(pl.metas) do if m.uid == uid then return i end end
	return nil
end

function Pl.AgregarMeta(id, meta, pos)
	local pl = Pl.De(id)
	local t = pl and Pl.NuevaMeta(meta)
	if not t then return nil end
	pos = tonumber(pos)
	if pos and pos >= 1 and pos <= #pl.metas + 1 then table.insert(pl.metas, pos, t) else pl.metas[#pl.metas + 1] = t end
	cambio(pl)
	revisarCallado()
	return t
end

function Pl.CambiarMeta(id, uid, meta)
	local pl = Pl.De(id)
	local i = pl and indice(pl, uid)
	if not i then return nil end
	meta.uid = uid
	local t = Pl.NuevaMeta(meta)
	if not t then return nil end
	pl.metas[i] = t
	local hechas = personaje().planHechas[id]
	if hechas then hechas[uid] = nil end
	-- El lugar que se buscó era del servicio de antes (otro tipo, otra profesión).
	if olvidarLugar then olvidarLugar(uid) end
	cambio(pl)
	revisarCallado()
	return t
end

function Pl.QuitarMeta(id, uid)
	local pl = Pl.De(id)
	local i = pl and indice(pl, uid)
	if not i then return end
	table.remove(pl.metas, i)
	cambio(pl)
	revisarCallado()
end

function Pl.MoverMeta(id, uid, delta)
	local pl = Pl.De(id)
	local i = pl and indice(pl, uid)
	if not i then return end
	local j = i + delta
	if j < 1 or j > #pl.metas then return end
	pl.metas[i], pl.metas[j] = pl.metas[j], pl.metas[i]
	cambio(pl)
	revisarCallado()
end

---------------------------------------------------------------------------
-- Cómo va cada meta (en vivo)
---------------------------------------------------------------------------

local function nombreOficio(linea)
	if linea == RIDING then
		local C = Cp()
		local n = C and llamar(C.GetSkillLineName, RIDING)
		return type(n) == "string" and n ~= "" and n or L["Equitación"]
	end
	local Nav = A.Nav
	local nb = type(Nav) == "table" and Nav.nearby
	local n = nb and llamar(nb.ProfessionName, linea)
	return type(n) == "string" and n ~= "" and n or tostring(linea)
end
Pl.NombreOficio = nombreOficio

local function rango(linea)
	local C = Cp()
	local r = C and llamar(C.GetSkillRank, linea)
	return type(r) == "number" and r or 0
end

local function dinero() return M.num(GetMoney and GetMoney(), 0) end

local function nivel()
	local n = UnitLevel and UnitLevel("player")
	return M.num(n, 1)
end

local function cuantos(item)
	local C = Cp()
	return M.num(C and llamar(C.GetItemCount, item, false), 0)
end

function Pl.NombreObjeto(m)
	local n = M.NombreObjeto(m.item)
	if n and n ~= format(L["Objeto %d"], m.item) then return n end
	return m.nombre or n
end

local function tituloMision(m)
	local C = Cp()
	local t = C and llamar(C.GetQuestTitle, m.quest)
	if type(t) == "string" and t ~= "" then return t end
	t = M.TituloMision(m.quest)
	if t and t ~= format(L["Misión %d"], m.quest) then return t end
	return m.titulo or t
end

-- Lo que pide la meta, en una línea.
function Pl.Titulo(m)
	local t = m.tipo
	if t == "objeto" then
		local n = Pl.NombreObjeto(m)
		return m.cantidad > 1 and format(L["Conseguir %d × %s"], m.cantidad, n) or format(L["Conseguir %s"], n)
	elseif t == "oro" then
		return format(L["Juntar %s"], N.Dinero(m.cobre, true))
	elseif t == "prof" then
		if m.nivel <= 1 then return format(L["Aprender %s"], nombreOficio(m.linea)) end
		return format(L["Subir %s a %d"], nombreOficio(m.linea), m.nivel)
	elseif t == "lugar" then
		if m.modo == "servicio" then
			local Ce = M.Cerca
			return format(L["Ir a: %s"], m.nombre or (Ce and Ce.Nombre(m.servicio, m.linea)) or m.servicio)
		end
		return format(L["Ir a: %s"], m.nombre or M.Zona(m.mapa) or L["un lugar"])
	elseif t == "mision" then
		local q = M.Citar(tituloMision(m))
		if m.verbo == "accept" then return format(L["Tomar %s"], q) end
		if m.verbo == "complete" then return format(L["Completar %s"], q) end
		return format(L["Entregar %s"], q)
	elseif t == "nivel" then
		return format(L["Llegar a nivel %d"], m.nivel)
	end
	return m.texto or ""
end

Pl.ICONO = { objeto = "ic-bolsas", oro = "ic-oro", prof = "ic-oficios", lugar = "ic-flecha", mision = "ic-misiones", nivel = "ic-nivel", nota = "ic-info" }
Pl.NOMBRE = { objeto = L["Conseguir un objeto"], oro = L["Juntar oro"], prof = L["Subir una profesión"], lugar = L["Ir a un lugar"],
	mision = L["Una misión"], nivel = L["Llegar a un nivel"], nota = L["Nota libre"] }

local rt = { lugar = {} } -- lo que no se guarda: el lugar de cada meta de servicio

-- Dónde queda una meta con lugar: mapa, x, y, f, nombre (o nil).
local function destino(m)
	if m.tipo ~= "lugar" then return nil end
	if m.modo == "servicio" then
		local p = rt.lugar[m.uid]
		if p then return p.map, p.x, p.y, p.f, p.name end
		return nil
	end
	return m.mapa, m.x, m.y, m.f, m.nombre
end

local function distancia(mapa, x, y, f)
	local C = Cp()
	if not C then return nil end
	local c, wx, wy = llamar(C.MapToWorld, mapa, x, y, f)
	local pc, px, py = llamar(C.GetPlayerWorldPosition)
	if not (c and pc and c == pc and type(wx) == "number" and type(px) == "number") then return nil end
	return sqrt((wx - px) ^ 2 + (wy - py) ^ 2)
end

-- -> hecha, actual, total, texto del avance
function Pl.Estado(m)
	local t = m.tipo
	if t == "objeto" then
		local n = cuantos(m.item)
		return n >= m.cantidad, min(n, m.cantidad), m.cantidad, format(L["%d de %d en tus bolsas"], min(n, m.cantidad), m.cantidad)
	elseif t == "oro" then
		local d = dinero()
		return d >= m.cobre, min(d, m.cobre), m.cobre, format(L["Tienes %s de %s"], N.Dinero(min(d, m.cobre), true), N.Dinero(m.cobre, true))
	elseif t == "prof" then
		local r = rango(m.linea)
		if m.nivel <= 1 then return r > 0, r > 0 and 1 or 0, 1, r > 0 and L["Ya la sabes"] or L["Aún no la aprendes"] end
		return r >= m.nivel, min(r, m.nivel), m.nivel, r > 0 and format(L["Vas en %d de %d"], r, m.nivel) or L["Aún no la aprendes"]
	elseif t == "nivel" then
		local n = nivel()
		return n >= m.nivel, min(n, m.nivel), m.nivel, format(L["Eres nivel %d"], n)
	elseif t == "mision" then
		local C = Cp()
		local hecha = C and llamar(C.IsQuestCompleted, m.quest) and true or false
		local en = C and llamar(C.IsOnQuest, m.quest) and true or false
		local lista = en and C and llamar(C.IsQuestReadyForTurnIn, m.quest) and true or false
		if m.verbo == "accept" then return hecha or en, (hecha or en) and 1 or 0, 1, en and L["En tu registro"] or (hecha and L["Ya la hiciste"] or L["Aún no la tomas"]) end
		if m.verbo == "complete" then return hecha or lista, (hecha or lista) and 1 or 0, 1, lista and L["Lista para entregar"] or (en and L["En tu registro"] or (hecha and L["Ya la hiciste"] or L["Aún no la tomas"])) end
		return hecha, hecha and 1 or 0, 1, lista and L["Lista para entregar"] or (en and L["En tu registro"] or (hecha and L["Entregada"] or L["Aún no la tomas"]))
	elseif t == "lugar" then
		local mapa, x, y, f = destino(m)
		local d = mapa and distancia(mapa, x, y, f)
		if d then
			if d <= LLEGAR then return true, 1, 1, L["Ya llegaste"] end
			local txt = type(A.FormatDistance) == "function" and llamar(A.FormatDistance, d) or format("%d yd", floor(d + 0.5))
			return false, 0, 1, format(L["A %s"], txt)
		end
		local z = mapa and M.Zona(mapa)
		return false, 0, 1, z and format(L["En %s"], z) or L["Clic en Llévame: la flecha te lleva"]
	end
	return false, 0, 1, L["Márcala cuando la hagas"]
end

---------------------------------------------------------------------------
-- El plan activo y su meta de ahora
---------------------------------------------------------------------------

function Pl.Activo()
	local id = personaje().planActivo
	local pl = Pl.De(id)
	if id and not pl then personaje().planActivo = nil end
	return pl
end

local function hechas(pl)
	local c = personaje()
	local h = c.planHechas[pl.id]
	if type(h) ~= "table" then
		h = {}
		c.planHechas[pl.id] = h
	end
	return h
end

function Pl.EstaHecha(pl, m) return hechas(pl)[m.uid] == true end

-- La primera meta sin hacer -> meta, índice. Al pasar por las ya cumplidas,
-- las marca (si después vendes el objeto, la meta sigue hecha).
function Pl.Actual(pl, sinMarcar)
	if not pl then return nil end
	local h = hechas(pl)
	for i, m in ipairs(pl.metas) do
		if not h[m.uid] then
			local ok = m.tipo ~= "nota" and Pl.Estado(m)
			if ok and not sinMarcar then
				h[m.uid] = true
			elseif not ok then
				return m, i
			end
		end
	end
	return nil
end

function Pl.Avance(pl)
	local h = hechas(pl)
	local n = 0
	for _, m in ipairs(pl.metas) do if h[m.uid] then n = n + 1 end end
	return n, #pl.metas
end

function Pl.MarcarHecha(pl, m, si)
	hechas(pl)[m.uid] = si and true or nil
	cambio(pl)
	if si then Pl.Revisar() else revisarCallado() end
end

function Pl.Reiniciar(pl)
	personaje().planHechas[pl.id] = {}
	cambio(pl)
	revisarCallado()
end

---------------------------------------------------------------------------
-- Acciones de cada meta: Llévame (la flecha o una guía) y su ayuda
---------------------------------------------------------------------------

local function asistente(camino) if M.Asistente then M.Asistente.Abrir(camino) end end

local function flechaA(mapa, x, y, nombre, f, auto)
	local Nav = A.Nav
	if type(Nav) ~= "table" or type(Nav.SetTarget) ~= "function" then
		M.Aviso(L["Mi plan"], L["La flecha no está disponible ahora."], { icono = "ic-aviso", tono = "aviso" })
		return false
	end
	local t = llamar(Nav.SetTarget, mapa, x, y, nombre, f)
	if not t then
		M.Aviso(L["Mi plan"], L["No pude poner la flecha ahí."], { icono = "ic-aviso", tono = "aviso" })
		return false
	end
	if type(Nav.StartTrip) == "function" then llamar(Nav.StartTrip, t, nombre, L["Mi plan"]) end
	if not auto then M.Empezar() end
	return true
end

-- La guía del motor hacia un objeto (la misma "Guíame" de la Enciclopedia).
local function guiarObjeto(m)
	local Lk = M.Motor("Lookup")
	if not (Lk and type(Lk.Guide) == "function") then
		M.Aviso(Pl.Titulo(m), L["El motor no puede armar guías ahora."], { icono = "ic-aviso", tono = "aviso" })
		return
	end
	if InCombatLockdown and InCombatLockdown() then
		M.Aviso(Pl.Titulo(m), L["Se puede al salir de combate."], { icono = "ic-aviso", tono = "aviso" })
		return
	end
	local ok, gid, motivo = pcall(Lk.Guide, m.kind or "item", m.item)
	if ok and gid then
		M.Empezar()
		M.Aviso(Pl.Titulo(m), L["Guía abierta en una pestaña nueva: sigue la flecha."], { icono = "ic-guia" })
		return
	end
	local textos = {
		tabs = L["Ya tienes seis guías abiertas: cierra una y vuelve a intentar."],
		nosource = L["No se conoce de dónde sale."], noguide = L["No hay un camino que Alfa pueda guiar para esto."],
		disabled = L["El buscador del motor está apagado (Ajustes > Descubrir): enciéndelo para que Alfa arme guías."],
	}
	local texto = ok and textos[motivo] or L["No se pudo armar la guía."]
	M.Aviso(Pl.Titulo(m), texto, { icono = "ic-aviso", tono = "aviso",
		accion = AlfaEnciclopedia and AlfaEnciclopedia.Abrir and { texto = L["Ver en la Enciclopedia"], alClic = function() AlfaEnciclopedia.Abrir("item", m.item) end } or nil })
end

-- El lugar de una meta de servicio (lo busca la primera vez).
local function resolverServicio(m)
	local Ce = M.Cerca
	if not Ce then return nil end
	local p = Ce.Lugar(m.servicio, m.linea)
	if p then rt.lugar[m.uid] = p end
	return p
end

-- Pl.Revisar: la meta de servicio de ahora sin lugar todavía (tras /reload o
-- recién agregada) lo busca fuera de combate, a lo más cada 30 s si no sale.
local buscado = {}
olvidarLugar = function(uid) rt.lugar[uid], buscado[uid] = nil, nil end
local function servicioPendiente(m)
	if not (m and m.tipo == "lugar" and m.modo == "servicio") or rt.lugar[m.uid] then return false end
	if InCombatLockdown and InCombatLockdown() then return false end
	local ahora = GetTime and GetTime() or 0
	if buscado[m.uid] and ahora - buscado[m.uid] < 30 then return false end
	buscado[m.uid] = ahora
	return resolverServicio(m) ~= nil
end

-- Llévame: lo que acerca a la meta. -> true si hizo algo. auto: la flecha
-- que va sola al llegarle el turno (no cierra ventanas ni muestra nada).
function Pl.Ir(m, auto)
	local t = m.tipo
	if t == "lugar" then
		if m.modo == "servicio" then
			local Ce = M.Cerca
			if not Ce then return false end
			local ok = Ce.Ir(m.servicio, m.linea, auto)
			if ok then resolverServicio(m) end
			return ok
		end
		if m.modo == "marcador" and m.marcador and AlfaMundo and AlfaMundo.SeguirMarcador then
			-- false: el marcador ya no está (o no se pudo): al punto guardado.
			local ok, puesto = pcall(AlfaMundo.SeguirMarcador, m.marcador)
			if ok and puesto then
				if not auto then M.Empezar() end
				return true
			end
		end
		return flechaA(m.mapa, m.x, m.y, m.nombre or Pl.Titulo(m), m.f, auto)
	elseif t == "objeto" then
		guiarObjeto(m)
		return true
	elseif t == "prof" then
		if M.Cerca and m.linea ~= RIDING then return M.Cerca.Ir("trainer", m.linea) end
		asistente("profesiones")
		return true
	elseif t == "mision" then
		local C = Cp()
		local en = C and llamar(C.IsOnQuest, m.quest)
		if en then
			M.Cerrar.Agregar(m.quest)
			M.Cerrar.Ahora()
		else
			M.Recoger.Desbloquear(m.quest)
		end
		return true
	elseif t == "oro" then
		asistente("oro")
		return true
	elseif t == "nivel" then
		asistente("nivel")
		return true
	end
	return false
end

-- El texto del botón de Llévame (o nil si la meta no tiene).
function Pl.TextoIr(m)
	local t = m.tipo
	if t == "lugar" then return L["Llévame"] end
	if t == "objeto" then return L["Guíame"] end
	if t == "prof" then return m.linea ~= RIDING and M.Cerca and L["A su entrenador"] or L["Cómo subirla"] end
	if t == "mision" then return L["Llévame"] end
	if t == "oro" then return L["Cómo hacer oro"] end
	if t == "nivel" then return L["Cómo subir"] end
	return nil
end

---------------------------------------------------------------------------
-- Revisar: avanza el plan cuando cumples la meta de ahora
---------------------------------------------------------------------------

local function relojLugar(m)
	local quiere = m ~= nil and m.tipo == "lugar"
	if quiere and not ticker then
		ticker = N.Ticker("rutas.planes", 1.5, function() Pl.Revisar(true) end)
	elseif not quiere and ticker then
		ticker:Cancel()
		ticker = nil
	end
end

local function alLlegarTurno(m)
	if not m or m.tipo ~= "lugar" then return end
	if m.modo == "servicio" and not rt.lugar[m.uid] and not (InCombatLockdown and InCombatLockdown()) then resolverServicio(m) end
	if A.Get(M.ID .. ".planFlecha") ~= false then Pl.Ir(m, true) end
end

-- desdeReloj: la revisión de cada 1.5 s; solo avisa PLAN_AVANCE si algo cambió.
local firmaAvance
function Pl.Revisar(desdeReloj)
	local pl = Pl.Activo()
	if not pl then
		relojLugar(nil)
		ultima = nil
		return
	end
	local antes = ultima
	local m = Pl.Actual(pl)
	if servicioPendiente(m) then m = Pl.Actual(pl) end
	ultima = m and m.uid or false
	relojLugar(m)
	if antes ~= nil and antes ~= ultima then
		-- Cambió la meta de ahora.
		if not m then
			M.Aviso(format(L["¡Terminaste %s!"], pl.nombre), L["Cumpliste todas sus metas. Elige otro plan o arma uno nuevo."],
				{ lobo = "aullando", accion = { texto = L["Mis planes"], alClic = function() N.Abrir(M.ID) end } })
		elseif antes then
			local n, total = Pl.Avance(pl)
			M.Aviso(format(L["Meta cumplida (%d de %d)"], n, total), format(L["Sigue: %s"], Pl.Titulo(m)), { icono = Pl.ICONO[m.tipo] or "ic-exito" })
		end
		alLlegarTurno(m)
		A.Fire("ALFA_PLAN")
	end
	local firma = tostring(pl.id) .. "|" .. tostring(ultima) .. "|" .. tostring((Pl.Avance(pl))) .. "|" .. tostring(m and select(4, Pl.Estado(m)) or "")
	if desdeReloj and firma == firmaAvance then return end
	firmaAvance = firma
	M.Avisar("PLAN_AVANCE")
end

local pendiente = false
local function revisarPronto()
	if pendiente or not Pl.Activo() then return end
	pendiente = true
	A.After(0.3, function()
		pendiente = false
		Pl.Revisar()
	end)
end

for _, ev in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_MONEY", "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL", "PLAYER_LEVEL_UP",
	"QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "QUEST_LOG_UPDATE", "ZONE_CHANGED_NEW_AREA" }) do
	A.RegisterEvent(ev, revisarPronto)
end
A.OnLogin(function() A.After(2, function() if Pl.Activo() then ultima = nil Pl.Revisar() end end) end)

function Pl.Seguir(id)
	local pl = Pl.De(id)
	if not pl then return false end
	personaje().planActivo = pl.id
	ultima = nil
	cambio(pl)
	Pl.Revisar()
	local m = Pl.Actual(pl, true)
	M.Empezar()
	if m then
		M.Aviso(format(L["Plan en marcha: %s"], pl.nombre), format(L["Primero: %s"], Pl.Titulo(m)), { lobo = "aullando" })
		alLlegarTurno(m)
	end
	return true
end

function Pl.Dejar()
	personaje().planActivo = nil
	ultima = nil
	relojLugar(nil)
	cambio(nil)
	M.Avisar("PLAN_AVANCE")
end

---------------------------------------------------------------------------
-- Lo que muestran el rastreador y Hoy: la meta de ahora
---------------------------------------------------------------------------

-- -> { plan, meta, indice, hechas, total, titulo, texto, frac, icono, ir = { texto, fn }, hecha = fn, fin } | nil
function Pl.Tarjeta()
	local pl = Pl.Activo()
	if not pl then return nil end
	local n, total = Pl.Avance(pl)
	local m, i = Pl.Actual(pl, true)
	local d = { plan = pl, hechas = n, total = total, nombre = pl.nombre }
	if not m then
		d.fin = true
		d.titulo = total > 0 and L["¡Plan terminado!"] or L["Tu plan no tiene metas"]
		d.texto = total > 0 and L["Cumpliste todas sus metas."] or L["Agrégale una en Mis planes."]
		d.icono = "ic-exito"
		return d
	end
	local _, actual, tope, txt = Pl.Estado(m)
	d.meta, d.indice = m, i
	d.titulo, d.texto, d.icono = Pl.Titulo(m), txt, Pl.ICONO[m.tipo] or "ic-huella"
	if (m.tipo == "objeto" or m.tipo == "oro" or m.tipo == "prof" or m.tipo == "nivel") and tope and tope > 1 then d.frac = actual / tope end
	-- Una misión: lo que Llévame agrega antes, o por qué no se puede (Disp.Resumen).
	if m.tipo == "mision" and m.quest and M.Disp then d.antes, d.noDisponible = M.Disp.Resumen(m.quest) end
	local ir = Pl.TextoIr(m)
	if ir then d.ir = { ir, function() Pl.Ir(m) end } end
	d.hecha = function() Pl.MarcarHecha(pl, m, true) end
	return d
end

---------------------------------------------------------------------------
-- Plantillas: planes listos, armados con los datos del juego
---------------------------------------------------------------------------

-- El entrenador de equitación de cada raza y la facción que da el descuento
-- (los datos del recordatorio de equitación del motor, QoL/Riding.lua).
local EQUITACION = {
	Orc = { mapa = 1454, x = 69.4, y = 13.1, faccion = 76 },
	Troll = { mapa = 1411, x = 55.3, y = 75.5, faccion = 530 },
	Tauren = { mapa = 1412, x = 46.8, y = 62.0, faccion = 81 },
	Scourge = { mapa = 1420, x = 60.1, y = 52.6, faccion = 68 },
	Human = { mapa = 1429, x = 84.3, y = 64.9, faccion = 72 },
	NightElf = { mapa = 1438, x = 25.3, y = 50.2, faccion = 69 },
	Dwarf = { mapa = 1426, x = 63.7, y = 50.1, faccion = 47 },
	Gnome = { mapa = 1426, x = 49.2, y = 48.1, faccion = 54 },
}
local EQUITACION_SKYBORNE = { Alliance = { mapa = 2521, x = 53.5, y = 80.5, faccion = 2779 }, Horde = { mapa = 2521, x = 53.5, y = 80.5, faccion = 2778 } }

local function equitacion()
	local C = Cp()
	local info = C and llamar(C.GetPlayerInfo) or {}
	local e = info.race == "Skyborne" and EQUITACION_SKYBORNE[info.faction or ""] or EQUITACION[info.race or ""]
	local costo = 1000000
	local R = A.QoL and A.QoL.Riding
	if R and type(R.EffectiveCost) == "function" then costo = M.num(llamar(R.EffectiveCost, 1, e and e.faccion), costo) end
	return e, costo
end

local CANA = 6256 -- Caña de pescar
local PESCA, COCINA = 356, 185

local PLANTILLAS = {
	{ clave = "mazmorra", icono = "ic-mazmorra", nombre = L["Preparar la mazmorra"],
		texto = L["Tu nivel, reparar, comida y bebida, y la entrada de la mazmorra para ti."],
		metas = function()
			local AM = AlfaMazmorras
			local reco = AM and AM.Recomendada and llamar(AM.Recomendada)
			local D = M.Motor("Dungeons")
			local d = reco and reco.key and D and llamar(D.Get, reco.key)
			local e = d and d.entrance
			if not (e and e.map and e.x and e.y) then return nil end
			local out = {}
			if reco.min and reco.min > nivel() then out[#out + 1] = { tipo = "nivel", nivel = reco.min } end
			out[#out + 1] = { tipo = "lugar", modo = "servicio", servicio = "repair", nombre = L["Reparar tu equipo"] }
			out[#out + 1] = { tipo = "lugar", modo = "servicio", servicio = "food", nombre = L["Comprar comida y bebida"] }
			out[#out + 1] = { tipo = "nota", texto = L["Arma tu grupo de 5 (buscador de grupos o tu manada)."] }
			out[#out + 1] = { tipo = "lugar", modo = "punto", mapa = e.map, x = e.x, y = e.y, f = e.f, nombre = format(L["La entrada de %s"], reco.nombre or d.name or "?"), mazmorra = reco.key }
			return out, reco.nombre or d.name
		end },
	{ clave = "montura", icono = "ic-lobo", nombre = L["Mi primera montura"],
		texto = L["Nivel 40, el oro, tu entrenador de equitación y aprender a montar."],
		metas = function()
			if rango(RIDING) > 0 then return nil end
			local e, costo = equitacion()
			local out = { { tipo = "nivel", nivel = 40 }, { tipo = "oro", cobre = costo } }
			if e then out[#out + 1] = { tipo = "lugar", modo = "punto", mapa = e.mapa, x = e.x, y = e.y, nombre = L["Tu entrenador de equitación"] } end
			out[#out + 1] = { tipo = "prof", linea = RIDING, nivel = 1 }
			return out
		end },
	{ clave = "oroMontura", icono = "ic-oro", nombre = L["Oro para la montura"],
		texto = L["Vende lo que no usas y junta lo que cuesta aprender a montar."],
		metas = function()
			if rango(RIDING) > 0 then return nil end
			local _, costo = equitacion()
			return { { tipo = "lugar", modo = "servicio", servicio = "vendor", nombre = L["Vender lo que no usas"] }, { tipo = "oro", cobre = costo } }
		end },
	{ clave = "cocinaPesca", icono = "ic-pesca", nombre = L["Subir cocina y pesca juntas"],
		texto = L["Aprende las dos, consigue una caña y cocina lo que pescas hasta 75."],
		metas = function()
			return {
				{ tipo = "prof", linea = PESCA, nivel = 1 },
				{ tipo = "prof", linea = COCINA, nivel = 1 },
				{ tipo = "objeto", item = CANA, cantidad = 1, nombre = L["Caña de pescar"] },
				{ tipo = "prof", linea = PESCA, nivel = 75 },
				{ tipo = "prof", linea = COCINA, nivel = 75 },
			}
		end },
}

-- Las plantillas que sirven a este personaje: { clave, nombre, texto, icono, metas = { ... } }.
function Pl.Plantillas()
	local out = {}
	for _, p in ipairs(PLANTILLAS) do
		local ok, metas, sub = pcall(p.metas)
		if ok and type(metas) == "table" and #metas > 0 then
			local texto = p.texto
			if sub then texto = format(L["%s: %s"], sub, texto) end
			out[#out + 1] = { clave = p.clave, nombre = p.nombre, texto = texto, icono = p.icono, metas = metas }
		end
	end
	return out
end

-- Una plantilla como plan nuevo (para seguirla o editarla). -> plan
function Pl.DesdePlantilla(clave)
	for _, p in ipairs(Pl.Plantillas()) do
		if p.clave == clave then return Pl.Nuevo(p.nombre, p.metas, p.clave) end
	end
	return nil
end

-- Un objeto (de la Enciclopedia u otro módulo) a tu plan activo, o a uno nuevo.
function Pl.AgregarObjeto(item, cantidad)
	item = tonumber(item)
	if not item then return false end
	local pl = Pl.Activo() or Pl.Nuevo(L["Mi plan"])
	local m = Pl.AgregarMeta(pl.id, { tipo = "objeto", item = item, cantidad = cantidad or 1 })
	if m then
		M.Aviso(L["Agregado a tu plan"], format(L["%s, en %s."], Pl.Titulo(m), pl.nombre), { icono = "ic-bolsas",
			accion = { texto = L["Ver mi plan"], alClic = function() if M.VistaPlanes then M.VistaPlanes.Abrir(pl.id) end end } })
	end
	return m ~= nil
end

---------------------------------------------------------------------------
-- AlfaPlanes (global)
---------------------------------------------------------------------------

local G = AlfaPlanes or {}
AlfaPlanes = G
G.Lista = function() return Pl.Lista() end
G.Activo = function() return Pl.Activo() end
G.Seguir = function(id) return Pl.Seguir(id) end
G.Dejar = function() return Pl.Dejar() end
G.Nuevo = function(nombre)
	if M.VistaPlanes then return M.VistaPlanes.Nuevo(nombre) end
	return Pl.Nuevo(nombre)
end
G.Abrir = function(id) if M.VistaPlanes then M.VistaPlanes.Abrir(id) end end
G.Tarjeta = function() return Pl.Tarjeta() end
G.AgregarObjeto = function(item, cantidad) return Pl.AgregarObjeto(item, cantidad) end
G.AgregarMeta = function(id, meta) return Pl.AgregarMeta(id, meta) end
