-- Alfa - Inicio: «¿Cuánto tiempo tienes?», el plan de tu rato de juego
-- (toxic3000 / La Jauría). GPL-3.0. -- 1.2.9
--
-- Lo de «Una hora de caza» (AlfaRuta.UnaHora, 1.2.7), pero para el tiempo
-- que tú digas (30 min, 1 h, 2 h u otro, inicio.horaMin): Alfa arma un plan
-- completo en pasos con sus minutos, por tu ritmo de verdad:
--   1. entregar las misiones listas (AlfaRuta.Listas);
--   2. cerrar las de tu zona (las de tu registro bajo el encabezado de tu zona);
--   3. una mazmorra para tu nivel si cabe (AlfaMazmorras.Recomendada);
--   4. un rato de recolección si tienes Minería, Herboristería o Desuello;
--   5. lo que sobre, tu guía (o recoger misiones nuevas);
--   6. y al final, entregar lo que terminaste.
-- El ritmo: los minutos por misión de tu diario (las sesiones con misiones
-- entregadas) y los minutos por paso de tu guía (AlfaRuta.Estimado); sin
-- datos, unos minutos por misión de siempre (MIN_MISION).
--
-- «Empezar» guarda el plan (por personaje, N.DatosPersonaje("inicio").hora)
-- y lleva la flecha al primer paso con la API de la ruta; «Siguiente» lo da
-- por hecho y lleva al que sigue. Un paso de entregar o de tu zona se da por
-- hecho solo cuando ya no queda nada (inicio.horaAuto): sale un aviso con
-- «Llévame» (la flecha la pone tu clic, nunca un avance solo).
--
--   M.Tiempo.Armar(minutos) -> plan { total, pasos = { { tipo, min, titulo, texto, icono, n, key } }, ritmo }
--   M.Tiempo.Empezar(plan), .Siguiente(), .Dejar(), .Actual() -> plan en curso | nil
--   M.Tiempo.Ir(paso)             la acción de un paso (la flecha)
--   M.Tiempo.MinPorMision() -> minutos, fuente ("diario" | "guia" | "normal")
--   mensaje INICIO_HORA cuando el plan cambia

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = N.Textos(M.EN)
local num, texto = M.num, M.texto

local type, ipairs, pairs, pcall, tonumber, tostring, format = type, ipairs, pairs, pcall, tonumber, tostring, string.format
local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min

local T = {}
M.Tiempo = T

T.MIN_MISION = 6    -- minutos por misión sin datos
T.FINAL = 5         -- minutos de la entrega del final
T.OPCIONES = { 30, 60, 120 }

local function on(clave) return N.Get("inicio", clave) and true or false end
local function combate() return InCombatLockdown and InCombatLockdown() and true or false end
local function nivel() return num(UnitLevel and UnitLevel("player")) or 1 end
local function ahora() return time() end
local function db() return N.DatosPersonaje("inicio") end

local function llamar(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d = pcall(fn, ...)
	if ok then return a, b, c, d end
	if geterrorhandler then geterrorhandler()(a) end
	return nil
end

local function deRuta(nombre)
	local R0 = rawget(_G, "AlfaRuta")
	local fn = type(R0) == "table" and R0[nombre]
	return type(fn) == "function" and fn or nil
end

local function mazmorras()
	local Mz = rawget(_G, "AlfaMazmorras")
	return type(Mz) == "table" and Mz or nil
end

-- "45 min", "1 h", "1 h 30 min"
function T.Minutos(m)
	m = floor((tonumber(m) or 0) + 0.5)
	if m < 60 then return format(L["%d min"], m) end
	local h, r = floor(m / 60), m % 60
	if r == 0 then return format(L["%d h"], h) end
	return format(L["%d h %d min"], h, r)
end

---------------------------------------------------------------------------
-- Tu ritmo
---------------------------------------------------------------------------

function T.MinPorMision()
	local S = M.Sesion
	local dur, mis = 0, 0
	if S then
		local lista = S.Sesiones()
		for k = #lista, max(1, #lista - 9), -1 do
			local s = lista[k]
			local m = tonumber(s.misiones) or 0
			if m > 0 then
				dur, mis = dur + (tonumber(s.dur) or 0), mis + m
			end
		end
		local e = S.Estado()
		if (e.misiones or 0) > 0 then dur, mis = dur + (e.dur or 0), mis + e.misiones end
	end
	if mis >= 5 and dur > 0 then
		return max(2, min(20, dur / 60 / mis)), "diario"
	end
	-- Los pasos de tu guía: unos 3 pasos por misión (tomar, hacer, entregar).
	local est = deRuta("Estimado")
	local m = est and tonumber((llamar(est)))
	local E = A.Engine
	if m and m > 0 and type(E) == "table" and type(E.GetProgress) == "function" then
		local ok, hechos, todos = pcall(E.GetProgress)
		local quedan = ok and ((tonumber(todos) or 0) - (tonumber(hechos) or 0)) or 0
		if quedan > 0 then return max(2, min(20, m / quedan * 3)), "guia" end
	end
	return T.MIN_MISION, "normal"
end

---------------------------------------------------------------------------
-- Qué hay
---------------------------------------------------------------------------

local function listas()
	local f = deRuta("Listas")
	return f and num((llamar(f))) or 0
end
T.Listas = listas

local function zonaActual()
	for _, fn in ipairs({ rawget(_G, "GetRealZoneText"), rawget(_G, "GetZoneText") }) do
		if type(fn) == "function" then
			local ok, z = pcall(fn)
			z = ok and texto(z) or nil
			if z and z ~= "" then return z end
		end
	end
	return nil
end

T.ZonaActual = zonaActual

-- Las de tu registro sin terminar bajo el encabezado de una zona (sin zona: la
-- tuya de ahora). 1.3.1: el paso «Cierra misiones de esta zona» guarda la suya
-- (p.zona), así que contar las de otra zona ya no lo da por hecho.
function T.EnZona(zona)
	local QL = C_QuestLog
	local Cp = A.Compat
	if not (QL and QL.GetNumQuestLogEntries and QL.GetInfo) then return 0 end
	zona = zona or zonaActual()
	if not zona then return 0 end
	local ok, n = pcall(QL.GetNumQuestLogEntries)
	n = ok and num(n) or 0
	local enZona, cuenta = false, 0
	for i = 1, n do
		local okI, info = pcall(QL.GetInfo, i)
		if okI and type(info) == "table" then
			if info.isHeader then
				enZona = texto(info.title) == zona
			elseif enZona and not info.isHidden then
				local q = num(info.questID)
				local lista = q and type(Cp) == "table" and type(Cp.IsQuestReadyForTurnIn) == "function" and Cp.IsQuestReadyForTurnIn(q)
				if q and q > 0 and not lista then cuenta = cuenta + 1 end
			end
		end
	end
	return cuenta
end

-- La mazmorra para tu nivel y cuánto dura: { key, nombre, min }, o nil.
function T.Mazmorra()
	-- Los datos de las mazmorras vienen del Codex: nunca se piden peleando.
	if combate() then return nil end
	local Mz = mazmorras()
	if not (Mz and type(Mz.Recomendada) == "function") then return nil end
	local d = llamar(Mz.Recomendada)
	if type(d) ~= "table" or type(d.key) ~= "string" or d.modo == "pronto" then return nil end
	local jefes
	local Dg = A.Dungeons
	if type(Dg) == "table" and type(Dg.List) == "function" then
		local ok, l = pcall(Dg.List)
		for _, x in ipairs(ok and type(l) == "table" and l or {}) do
			if x.key == d.key then jefes = tonumber(x.bosses) end
		end
	end
	local m = jefes and max(45, min(120, 20 + jefes * 8)) or 60
	return { key = d.key, nombre = texto(d.nombre) or d.key, min = m }
end

-- Las de recolección que sabes: { nombre } o nil (la primera que sabes).
local RECOLECCION = {
	{ id = "mineria", nombre = L["Minería"], hechizos = { 2575, 2576, 3564, 10248, 2580 } },
	{ id = "hierbas", nombre = L["Herboristería"], hechizos = { 2366, 2368, 3570, 11993, 2383 } },
	{ id = "desuello", nombre = L["Desuello"], hechizos = { 8613, 8617, 8618, 10768 } },
}
T.RECOLECCION = RECOLECCION

function T.Recoleccion()
	local f = rawget(_G, "IsPlayerSpell") or rawget(_G, "IsSpellKnown")
	if type(f) ~= "function" then return nil end
	for _, r in ipairs(RECOLECCION) do
		for _, id in ipairs(r.hechizos) do
			local ok, si = pcall(f, id)
			if ok and si then return r end
		end
	end
	return nil
end

local function hayGuia()
	local E = A.Engine
	if type(E) ~= "table" or type(E.GetGuide) ~= "function" then return false end
	local ok, g = pcall(E.GetGuide)
	return ok and type(g) == "table"
end

---------------------------------------------------------------------------
-- El plan
---------------------------------------------------------------------------

local ICONO = { entregar = "ic-exito", zona = "ic-misiones", mazmorra = "ic-mazmorra", recolectar = "ic-recoleccion",
	guia = "ic-ruta", recoger = "ic-misiones", final = "ic-exito" }

-- Los textos de un paso (se arman al mostrarlo: así salen en el idioma de ahora).
function T.Textos(p)
	local t, n = p.tipo, p.n or 0
	if t == "entregar" then
		return L["Entrega tus misiones listas"], n == 1 and L["1 lista: la flecha te lleva"] or format(L["%d listas: la flecha te lleva por el camino más corto"], n)
	elseif t == "zona" then
		-- 1.3.2: con el nombre de su zona (el paso lo guarda desde la 1.3.1).
		local titulo = p.zona and format(L["Cierra misiones de %s"], p.zona) or L["Cierra misiones de esta zona"]
		return titulo, n == 1 and L["1 de tu registro aquí cerca"] or format(L["%d de tu registro aquí cerca"], n)
	elseif t == "mazmorra" then
		return format(L["Mazmorra: %s"], p.nombre or "?"), L["La de tu nivel. Antes, revisa que lleves todo."]
	elseif t == "recolectar" then
		return format(L["Recolecta: %s"], p.nombre or ""), L["Una vuelta de recolección en tu zona"]
	elseif t == "guia" then
		return L["Sigue tu guía"], n > 0 and format(L["Unos %d pasos a tu ritmo"], n) or L["Avanza en tu guía con la flecha"]
	elseif t == "recoger" then
		return L["Recoge misiones nuevas"], L["Las de tu ruta que tienes cerca"]
	elseif t == "final" then
		return L["Entrega lo que terminaste"], L["Para cerrar tu rato con todo cobrado"]
	end
	return tostring(t), nil
end

function T.Armar(total)
	total = max(15, floor(tonumber(total) or tonumber(N.Get("inicio", "horaMin")) or 60))
	local mpm, fuente = T.MinPorMision()
	local pasos = {}
	local final = total >= 45 and T.FINAL or 0
	local resto = total - final
	local function agregar(p)
		p.min = max(1, floor(p.min + 0.5))
		p.icono = ICONO[p.tipo]
		pasos[#pasos + 1] = p
		resto = resto - p.min
	end
	-- 1. Lo que ya está listo: entregarlo primero.
	local nl = listas()
	if nl > 0 then agregar({ tipo = "entregar", n = nl, min = min(resto, max(3, ceil(nl * 1.5) + 2)) }) end
	-- 2. Lo de esta zona (con su nombre: el paso es de esta zona, no de la que pises luego).
	local zona = zonaActual()
	local nz = zona and T.EnZona(zona) or 0
	if nz > 0 and resto >= 5 then
		local cabe = max(1, floor(resto * 0.6 / mpm))
		local n = min(nz, cabe)
		agregar({ tipo = "zona", n = n, zona = zona, min = min(resto, max(5, n * mpm)) })
	end
	-- 3. Una mazmorra, si cabe.
	local mz = T.Mazmorra()
	if mz and resto >= mz.min then agregar({ tipo = "mazmorra", key = mz.key, nombre = mz.nombre, min = mz.min }) end
	-- 4. Un rato de recolección.
	local rec = T.Recoleccion()
	if rec and resto >= 25 then agregar({ tipo = "recolectar", prof = rec.id, nombre = rec.nombre, min = resto >= 50 and 20 or 15 }) end
	-- 5. Lo que sobra: tu guía, o recoger misiones nuevas.
	if resto >= 8 then
		if hayGuia() then
			agregar({ tipo = "guia", n = floor(resto / mpm * 3), min = resto })
		else
			agregar({ tipo = "recoger", min = resto })
		end
	end
	-- 6. Y al final, entregar lo que terminaste.
	if final > 0 then
		resto = resto + final
		agregar({ tipo = "final", min = resto })
	end
	local usado = 0
	for _, p in ipairs(pasos) do usado = usado + p.min end
	return { total = total, usado = usado, pasos = pasos, ritmo = mpm, fuente = fuente }
end

---------------------------------------------------------------------------
-- En marcha
---------------------------------------------------------------------------

local function avisarCambio()
	A.Fire("INICIO_HORA")
	if M.Pagina and M.Pagina.Relayout then M.Pagina.Relayout() end
end

function T.Actual()
	local h = db().hora
	if type(h) ~= "table" or type(h.pasos) ~= "table" or #h.pasos == 0 then return nil end
	-- Un plan muy viejo (otro día, o el doble de su tiempo) ya no sigue.
	local t0 = tonumber(h.t0) or 0
	if ahora() - t0 > max(h.total * 2, h.total + 60) * 60 then
		db().hora = nil
		return nil
	end
	h.i = max(1, min(tonumber(h.i) or 1, #h.pasos))
	return h
end

-- Los minutos que llevas en el plan.
function T.Llevas(h)
	h = h or T.Actual()
	if not h then return 0 end
	return max(0, floor((ahora() - (tonumber(h.t0) or ahora())) / 60))
end

-- La acción de un paso: la flecha a donde toca (desde el clic del jugador).
function T.Ir(p)
	if type(p) ~= "table" then return end
	if combate() then
		N.FueraDeCombate("inicio.horaIr", function() T.Ir(p) end)
		return
	end
	local t = p.tipo
	if t == "entregar" or t == "final" then
		local vuelta = deRuta("VueltaEntregar")
		if vuelta and listas() >= 2 then
			if llamar(vuelta) then return end
		end
		local f = deRuta("Entregar") or deRuta("Liberar")
		if f then llamar(f, "listas") end
	elseif t == "zona" then
		-- 1.3.2: en otra zona, «Llévame» armaría las misiones de esa: primero hay que volver.
		local aqui = zonaActual()
		if p.zona and aqui and aqui ~= p.zona then
			K.Aviso({ titulo = format(L["Vuelve a %s"], p.zona), icono = "ic-misiones", tono = "aviso", duracion = 8,
				texto = format(L["Este paso es para cerrar tus misiones de %s. Cuando estés allá, «Llévame» te lleva a cada una."], p.zona) })
			return
		end
		local f = deRuta("Liberar")
		if f then llamar(f, "zona") end
	elseif t == "mazmorra" then
		local Mz = mazmorras()
		if Mz and type(Mz.Preparar) == "function" then llamar(Mz.Preparar, p.key)
		elseif Mz and type(Mz.Abrir) == "function" then llamar(Mz.Abrir, p.key) end
	elseif t == "recolectar" then
		if N.ModuloPorId("recoleccion") then N.Abrir("recoleccion") end
	elseif t == "guia" then
		if A.Get("nav.arrow") == false then A.Set("nav.arrow", true) end
		if N.EmpezarRuta then N.EmpezarRuta() else A.Fire("SHOW_FRAME") end
	elseif t == "recoger" then
		local f = deRuta("Recoger")
		if f then llamar(f) end
	end
end

function T.Empezar(plan)
	plan = plan or T.Armar()
	if type(plan) ~= "table" or #plan.pasos == 0 then return false end
	local S = M.Sesion
	local copia = { total = plan.total, t0 = ahora(), i = 1, pasos = {},
		misiones0 = S and (num(S.Actual().misiones) or 0) or 0, xp0 = S and (num(S.Actual().xp) or 0) or 0 }
	for i, p in ipairs(plan.pasos) do
		copia.pasos[i] = { tipo = p.tipo, min = p.min, n = p.n, key = p.key, nombre = p.nombre, prof = p.prof, zona = p.zona }
	end
	db().hora = copia
	avisarCambio()
	T.Ir(copia.pasos[1])
	return true
end

function T.Dejar()
	db().hora = nil
	avisarCambio()
end

local function terminar(h)
	local S = M.Sesion
	local mis = S and max(0, (num(S.Actual().misiones) or 0) - (h.misiones0 or 0)) or 0
	db().hora = nil
	avisarCambio()
	local txt = format(L["Cumpliste tu plan en %s."], T.Minutos(T.Llevas(h)))
	if mis > 0 then txt = txt .. " " .. (mis == 1 and L["Entregaste 1 misión."] or format(L["Entregaste %d misiones."], mis)) end
	K.Aviso({ titulo = L["¡Plan cumplido!"], lobo = "aullando", tono = "exito", texto = txt, duracion = 8, detalle = true })
end

-- El paso de ahora, hecho: al siguiente (con ir = true, la flecha va ahí).
function T.Siguiente(ir)
	local h = T.Actual()
	if not h then return false end
	h.pasos[h.i].hecho = true
	if h.i >= #h.pasos then
		terminar(h)
		return true
	end
	h.i = h.i + 1
	avisarCambio()
	if ir ~= false then T.Ir(h.pasos[h.i]) end
	return true
end

-- Un paso que se cumple solo (ya no quedan listas, o ya cerraste tu zona):
-- un aviso con el que sigue; la flecha la pone el clic.
local function revisarSolo()
	local h = T.Actual()
	if not h or not on("horaAuto") then return end
	local p = h.pasos[h.i]
	-- 1.3.1: el de tu zona solo se da por hecho estando en ella (antes, al ir a
	-- otra zona contaba las de la nueva, 0, y lo daba por hecho).
	if p.tipo == "zona" and p.zona and zonaActual() ~= p.zona then return end
	local hecho = ((p.tipo == "entregar" or p.tipo == "final") and listas() == 0) or (p.tipo == "zona" and T.EnZona(p.zona) == 0)
	if not hecho then return end
	local ultimo = h.i >= #h.pasos
	T.Siguiente(false)
	if ultimo then return end
	local sig = T.Actual()
	if not sig then return end
	local q = sig.pasos[sig.i]
	local titulo, txt = T.Textos(q)
	K.Aviso({ titulo = format(L["Listo. Ahora: %s"], titulo), texto = txt, icono = q.icono or ICONO[q.tipo] or "ic-reloj", duracion = 10,
		accion = { texto = L["Llévame"], alClic = function() T.Ir(q) end } })
end
T.RevisarSolo = revisarSolo

local pendiente = false
local function revisarPronto()
	if pendiente then return end
	pendiente = true
	A.After(1.5, function()
		pendiente = false
		N.FueraDeCombate("inicio.horaSolo", revisarSolo)
	end)
end

A.RegisterEvent("QUEST_TURNED_IN", revisarPronto)
A.RegisterEvent("QUEST_LOG_UPDATE", revisarPronto)
