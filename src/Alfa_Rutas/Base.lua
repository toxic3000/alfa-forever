-- Alfa - Rutas: piezas comunes (ramas, datos guardados, plantillas, exportar
-- e importar). toxic3000 / La Jauría. GPL-3.0.
--
-- Datos de la cuenta (N.Datos("rutas")): las rutas que arma el jugador.
--   { v = 1, seq = n, orden = { id, ... }, rutas = { [id] = ruta } }
--   ruta  = { id, nombre, creada, cambiada, plantilla?, tramos = { tramo, ... } }
--   tramo = { uid, rama = "xp"|"oro"|"prof"|"clase"|"objeto", cantidad,
--             item?, fijas = { questId, ... }?, quitar = { questId, ... }? }
-- Datos del personaje (N.DatosPersonaje("rutas")): lo que depende de quién
-- juega (facción, clase, nivel, lugar).
--   { activa = rutaId?, editando = rutaId?, planes = { [rutaId] = plan },
--     guias = { [rutaId] = guía compilada }, liberar = guía?, marcas = { [questId] = "abandonar" | "fuera" | "quitada" },
--     progreso = { [rutaId] = { inicio, nivel } },
--     extra = { questId, ... } (misiones agregadas a mano al plan de misiones),
--     incluir = { [questId] = true } (las del registro que el filtro deja fuera pero tú pusiste),
--     filtro = "todas" | "listas" | "zona" }

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)

M.ADDON, M.N, M.A, M.L = ADDON, N, A, L
M.K = N.Kit
M.ID = "rutas"
M.PACK = "mis-rutas" -- el paquete de guías del motor donde viven las rutas ("Mis rutas")

local type, pairs, ipairs, tonumber, tostring = type, pairs, ipairs, tonumber, tostring
local floor, format, concat = math.floor, string.format, table.concat

---------------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------------

-- Un número de verdad (ni nil, ni un valor raro del cliente), o d.
function M.num(v, d)
	if issecretvalue and issecretvalue(v) then return d end -- 1.4.0: un secreto no es un número que se pueda usar
	if type(v) == "number" and v == v then return v end
	return d
end

-- Copia profunda de datos simples (sin metatablas ni funciones).
function M.Copia(t, vistos)
	if type(t) ~= "table" then return t end
	vistos = vistos or {}
	if vistos[t] then return vistos[t] end
	local out = {}
	vistos[t] = out
	for k, v in pairs(t) do
		local tv = type(v)
		if tv == "table" then out[k] = M.Copia(v, vistos)
		elseif tv ~= "function" and tv ~= "userdata" and tv ~= "thread" then out[k] = v end
	end
	return out
end

-- 18400 -> "18,400".
function M.Miles(n)
	n = floor(M.num(n, 0) + 0.5)
	local s = tostring(math.abs(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then out = out:sub(2) end
	return (n < 0 and "-" or "") .. out
end

-- Segundos de camino -> "≈ 4 min" / "≈ 1 h 10 min".
function M.Minutos(seg)
	seg = M.num(seg, 0)
	local m = floor(seg / 60 + 0.5)
	if m < 1 then return L["menos de 1 min"] end
	-- 1.3.7: el mismo formato que todo Alfa (N.Duracion).
	return N.Duracion(m * 60, true)
end

-- 1.3.7: la experiencia que te da una misión al entregarla (97, 98): la del
-- juego (GetQuestLogRewardXP, ya con tu nivel) y, sin ella, la del Codex si
-- ya está cargado (nunca se carga aquí). -> xp | nil
function M.XPMision(qid)
	qid = tonumber(qid)
	if not qid then return nil end
	local f = rawget(_G, "GetQuestLogRewardXP")
	if type(f) == "function" then
		local ok, xp = pcall(f, qid)
		if ok and type(xp) == "number" and not (issecretvalue and issecretvalue(xp)) and xp > 0 then return xp end
	end
	local C = M.Motor("Codex")
	if C and C.IsLoaded and C.IsLoaded() and C.Quest then
		local ok, q = pcall(C.Quest, qid)
		local xp = ok and type(q) == "table" and tonumber(q.xp) or nil
		if xp and xp > 0 then
			local Lv = M.Motor("Levels")
			local nivel = UnitLevel and N.LeerNumero(UnitLevel("player"), 1) -- 1.4.0: secreto
			local parte = 1
			if Lv and Lv.Share and tonumber(q.level or q.lvl) then
				local okS, p = pcall(Lv.Share, nivel, tonumber(q.level or q.lvl))
				if okS and tonumber(p) then parte = p end
			end
			return floor(xp * parte + 0.5)
		end
	end
	return nil
end

-- 1.3.7: tus misiones listas y la experiencia que dan juntas, y si con
-- entregarlas subes de nivel (98). -> { n, xp, conocidas, subes, faltan }
local xpListas, xpListasEn = nil, -1e9
A.RegisterEvent("QUEST_LOG_UPDATE", function() xpListasEn = -1e9 end)
A.RegisterEvent("PLAYER_XP_UPDATE", function() xpListasEn = -1e9 end)
function M.XPListas()
	-- (Hoy pregunta cada segundo: vale unos segundos, o hasta que cambie el registro)
	local t = GetTime and GetTime() or 0
	if xpListas and t - xpListasEn < 5 then return xpListas end
	local Cp = M.Motor("Compat")
	local r = { n = 0, xp = 0, conocidas = 0, subes = false }
	xpListas, xpListasEn = r, t
	if not (Cp and Cp.GetLogQuests and Cp.IsQuestReadyForTurnIn) then return r end
	for _, q in ipairs(Cp.GetLogQuests() or {}) do
		if Cp.IsQuestReadyForTurnIn(q) then
			r.n = r.n + 1
			local xp = M.XPMision(q)
			if xp then r.xp, r.conocidas = r.xp + xp, r.conocidas + 1 end
		end
	end
	-- 1.4.1: la experiencia puede llegar secreta en mazmorras (como el nivel).
	local x, mx = UnitXP and N.LeerNumero(UnitXP("player"), 0) or 0, UnitXPMax and N.LeerNumero(UnitXPMax("player"), 0) or 0
	r.faltan = mx > 0 and math.max(0, mx - x) or nil
	r.subes = r.faltan ~= nil and r.xp > 0 and r.xp >= r.faltan
	return r
end

-- 1.3.7: un número con su palabra en singular o plural (N.Plural del Núcleo;
-- sin él, el plural).
function M.Plural(n, uno, varios)
	if N.Plural then return N.Plural(n, uno, varios) end
	return format(n == 1 and uno or varios, n)
end

-- Texto en minúsculas y sin acentos, para buscar.
function M.Plegar(s)
	if type(s) ~= "string" then return "" end
	local S = A.Search
	if S and type(S.Fold) == "function" then
		local ok, r = pcall(S.Fold, s)
		if ok and type(r) == "string" then return (r:gsub("^%s+", "")) end
	end
	return s:lower()
end

-- Algo del motor que puede no estar: A.Lookup, A.Codex...
function M.Motor(nombre)
	local v = A[nombre]
	if type(v) == "table" then return v end
	return nil
end

---------------------------------------------------------------------------
-- Ramas: cada tramo de la ruta es una
---------------------------------------------------------------------------

M.RAMAS = { "xp", "oro", "prof", "clase", "objeto" }
M.RAMA = {
	xp = { nombre = L["XP"], icono = "ic-nivel", tono = "exito",
		uno = L["%d misión de XP"], varios = L["%d misiones de XP"], desc = L["Las misiones que más experiencia dan cerca de ti."] },
	oro = { nombre = L["Oro"], icono = "ic-oro", tono = "oro",
		uno = L["%d misión de oro"], varios = L["%d misiones de oro"], desc = L["Misiones que dejan dinero u objetos que se venden bien."] },
	prof = { nombre = L["Profesión"], icono = "ic-oficios", tono = "aviso",
		uno = L["%d de %s"], varios = L["%d de %s"], desc = L["Junta materiales de tu profesión donde más hay."] },
	clase = { nombre = L["Clase"], icono = "ic-talentos", tono = "clase",
		uno = L["%d misión de clase"], varios = L["%d misiones de clase"], desc = L["Misiones solo para tu clase que dan un objeto o una habilidad única."] },
	objeto = { nombre = L["Objeto"], icono = "ic-bolsas", tono = "raro",
		uno = L["Conseguir %s"], varios = L["Conseguir %d de %s"], desc = L["Un objeto que quieres: Alfa arma el camino para conseguirlo, con lo que haga falta antes."] },
}

-- El nombre de un objeto para mostrar (Codex en tu idioma, o el cliente).
function M.NombreObjeto(id)
	id = tonumber(id)
	if not id then return "?" end
	local C = M.Motor("Codex")
	local n = C and C.IsLoaded and C.IsLoaded() and C.Name and C.Name("item", id)
	if type(n) == "string" and n ~= "" then return n end
	local Cp = M.Motor("Compat")
	n = Cp and Cp.GetItemName and Cp.GetItemName(id)
	if type(n) == "string" and n ~= "" then return n end
	return format(L["Objeto %d"], id)
end

-- El título de una misión en tu idioma (el cliente, el Codex o su número).
function M.TituloMision(qid)
	local Cp = M.Motor("Compat")
	local t = Cp and Cp.GetQuestTitle and Cp.GetQuestTitle(qid)
	if type(t) == "string" and t ~= "" then return t end
	local C = M.Motor("Codex")
	local q = C and C.IsLoaded and C.IsLoaded() and C.Quest(qid)
	if q and q.title then return q.title end
	return format(L["Misión %d"], tonumber(qid) or 0)
end

-- El nombre de un mapa (zona) en tu idioma.
function M.Zona(map)
	local Cp = M.Motor("Compat")
	local n = map and Cp and Cp.MapName and Cp.MapName(map)
	if type(n) == "string" and n ~= "" then return n end
	return nil
end

-- "«Nombre»" como lo cita el motor.
function M.Citar(s)
	if A.Quoted then
		local ok, r = pcall(A.Quoted, s)
		if ok and type(r) == "string" then return r end
	end
	return tostring(s)
end

-- El jugador empezó algo que se sigue (una guía, una ruta, un plan, un
-- viaje de Buscar cerca, un Llévame): el rastreador a la vista y las
-- ventanas de Alfa cerradas (N.EmpezarRuta del núcleo). No para lo que pasa
-- solo (el paso siguiente, la flecha que avanza sola).
function M.Empezar()
	if N.EmpezarRuta then
		N.EmpezarRuta()
	else
		A.Set("ui.shown", true)
	end
end

-- Un aviso flotante de la ruta (el del Kit), o una línea en el chat si el
-- Kit no está (no debería pasar).
function M.Aviso(titulo, texto, extra)
	local K = M.K
	if K and K.Aviso then
		local o = { titulo = titulo, texto = texto, icono = "ic-ruta", tono = "acento" }
		for k, v in pairs(extra or {}) do o[k] = v end
		return K.Aviso(o)
	end
	A.Print(texto and (titulo .. " " .. texto) or titulo)
end

-- "3 misiones de XP", "20 de Mena de cobre", "Conseguir Espada de Arcanita".
function M.TituloTramo(t)
	local r = M.RAMA[t.rama] or M.RAMA.xp
	local n = M.num(t.cantidad, 1)
	if t.rama == "prof" then
		return format(r.varios, n, t.item and M.NombreObjeto(t.item) or L["material"])
	elseif t.rama == "objeto" then
		local nombre = t.item and M.NombreObjeto(t.item) or L["un objeto"]
		if n > 1 then return format(r.varios, n, nombre) end
		return format(r.uno, nombre)
	end
	return format(n == 1 and r.uno or r.varios, n)
end

---------------------------------------------------------------------------
-- Avisos internos (para que la vista se redibuje)
---------------------------------------------------------------------------

local oyentes = {}
function M.Escuchar(evento, fn)
	local lista = oyentes[evento]
	if not lista then
		lista = {}
		oyentes[evento] = lista
	end
	lista[#lista + 1] = fn
end

function M.Avisar(evento, ...)
	for _, fn in ipairs(oyentes[evento] or {}) do
		local ok, err = pcall(fn, ...)
		if not ok and geterrorhandler then geterrorhandler()(err) end
	end
end

---------------------------------------------------------------------------
-- Datos guardados
---------------------------------------------------------------------------

function M.Cuenta()
	local d = N.Datos(M.ID)
	if type(d.rutas) ~= "table" then d.rutas = {} end
	if type(d.orden) ~= "table" then d.orden = {} end
	d.seq = M.num(d.seq, 0)
	d.v = 1
	return d
end

function M.Personaje()
	local d = N.DatosPersonaje(M.ID)
	for _, k in ipairs({ "planes", "guias", "progreso", "marcas", "extra", "incluir" }) do
		if type(d[k]) ~= "table" then d[k] = {} end
	end
	return d
end

local function nuevoId(prefijo)
	local d = M.Cuenta()
	d.seq = d.seq + 1
	return prefijo .. tostring(time and time() or 0) .. "_" .. d.seq
end

-- Un tramo limpio a partir de lo que llegue (plantilla, importación, editor).
function M.NuevoTramo(t)
	t = type(t) == "table" and t or {}
	local rama = M.RAMA[t.rama] and t.rama or "xp"
	local cant = floor(M.num(tonumber(t.cantidad), rama == "prof" and 20 or (rama == "objeto" and 1 or 3)))
	if cant < 1 then cant = 1 elseif cant > 99 then cant = 99 end
	local tramo = { uid = nuevoId("t"), rama = rama, cantidad = cant }
	if t.item then tramo.item = tonumber(t.item) end
	if type(t.fijas) == "table" and #t.fijas > 0 then
		tramo.fijas = {}
		for _, q in ipairs(t.fijas) do if tonumber(q) then tramo.fijas[#tramo.fijas + 1] = tonumber(q) end end
	end
	if type(t.quitar) == "table" and #t.quitar > 0 then
		tramo.quitar = {}
		for _, q in ipairs(t.quitar) do if tonumber(q) then tramo.quitar[#tramo.quitar + 1] = tonumber(q) end end
	end
	return tramo
end

function M.Rutas()
	local d = M.Cuenta()
	local out, vistos = {}, {}
	for _, id in ipairs(d.orden) do
		if type(d.rutas[id]) == "table" and not vistos[id] then
			out[#out + 1] = d.rutas[id]
			vistos[id] = true
		end
	end
	-- Una ruta que quedó fuera del orden (datos editados a mano) también cuenta.
	for id, r in pairs(d.rutas) do
		if not vistos[id] and type(r) == "table" then
			out[#out + 1] = r
			d.orden[#d.orden + 1] = id
		end
	end
	return out
end

function M.Ruta(id)
	if not id then return nil end
	local r = M.Cuenta().rutas[id]
	if type(r) ~= "table" then return nil end
	if type(r.tramos) ~= "table" then r.tramos = {} end
	return r
end

function M.NuevaRuta(nombre, tramos, plantilla)
	local d = M.Cuenta()
	local r = { id = nuevoId("r"), nombre = (type(nombre) == "string" and nombre ~= "") and nombre or L["Mi ruta"],
		creada = time and time() or 0, tramos = {}, plantilla = plantilla }
	r.cambiada = r.creada
	for _, t in ipairs(tramos or {}) do r.tramos[#r.tramos + 1] = M.NuevoTramo(t) end
	d.rutas[r.id] = r
	d.orden[#d.orden + 1] = r.id
	M.Personaje().editando = r.id
	M.Avisar("RUTAS")
	return r
end

-- Marca la ruta como cambiada: su plan del personaje se rehace.
function M.Cambio(r)
	if not r then return end
	r.cambiada = time and time() or 0
	M.Avisar("RUTA", r.id)
end

function M.BorrarRuta(id)
	local d = M.Cuenta()
	if not d.rutas[id] then return false end
	d.rutas[id] = nil
	for i = #d.orden, 1, -1 do
		if d.orden[i] == id then table.remove(d.orden, i) end
	end
	local p = M.Personaje()
	p.planes[id], p.progreso[id] = nil, nil
	if p.activa == id then p.activa = nil end
	if p.editando == id then p.editando = nil end
	if M.Guias and M.Guias.Retirar then M.Guias.Retirar(id) end
	p.guias[id] = nil
	M.Avisar("RUTAS")
	return true
end

-- La ruta que se edita en la página: la elegida, la activa, o la primera.
function M.RutaEditada()
	local p = M.Personaje()
	local r = M.Ruta(p.editando) or M.Ruta(p.activa)
	if r then return r end
	-- La primera, igual que M.Ruta: sus tramos siempre en una tabla.
	r = M.Rutas()[1]
	if r and type(r.tramos) ~= "table" then r.tramos = {} end
	return r
end

-- La ruta en seguimiento de este personaje (la que siguió con "Seguir").
function M.RutaActiva()
	return M.Ruta(M.Personaje().activa)
end

-- Una firma de lo que define el plan: si cambia, el plan se rehace.
function M.Firma(r)
	if not r then return "" end
	local partes = {}
	for i, t in ipairs(r.tramos) do
		partes[i] = concat({ t.uid or "", t.rama or "", tostring(t.cantidad or ""), tostring(t.item or ""),
			concat(t.fijas or {}, "."), concat(t.quitar or {}, ".") }, ",")
	end
	return concat(partes, ";")
end

---------------------------------------------------------------------------
-- Exportar e importar como texto: !ALFARUTA1!<nombre>!<tramos>!<control>
-- tramo = rama,cantidad,item,fijas(a.b.c),quitar(a.b); el nombre va escapado.
-- Es solo texto: al importar se lee campo por campo, nunca se ejecuta.
---------------------------------------------------------------------------

local CABEZA = "!ALFARUTA1!"

local function esc(s)
	return (tostring(s or ""):gsub("[^%w _%-]", function(c) return format("%%%02X", c:byte()) end))
end

local function unesc(s)
	return (tostring(s or ""):gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

local function control(s)
	local n = 0
	for i = 1, #s do n = (n * 31 + s:byte(i)) % 65521 end
	return format("%04x", n)
end

function M.Exportar(r)
	if not r then return "" end
	local tramos = {}
	for i, t in ipairs(r.tramos) do
		tramos[i] = concat({ t.rama, tostring(t.cantidad or 1), t.item and tostring(t.item) or "",
			concat(t.fijas or {}, "."), concat(t.quitar or {}, ".") }, ",")
	end
	local cuerpo = esc(r.nombre) .. "!" .. concat(tramos, ";")
	return CABEZA .. cuerpo .. "!" .. control(cuerpo)
end

local function lista(s)
	local out = {}
	for n in tostring(s or ""):gmatch("%d+") do
		if #out < 60 then out[#out + 1] = tonumber(n) end
	end
	return out
end

-- texto -> nombre, tramos | nil, motivo
function M.LeerImportacion(texto)
	if type(texto) ~= "string" then return nil, L["No pegaste nada."] end
	texto = texto:gsub("^%s+", ""):gsub("%s+$", "")
	if texto:sub(1, #CABEZA) ~= CABEZA then return nil, L["Ese texto no es una ruta de Alfa."] end
	if #texto > 6000 then return nil, L["El texto es demasiado largo."] end
	local resto = texto:sub(#CABEZA + 1)
	local cuerpo, sello = resto:match("^(.*)!(%x%x%x%x)$")
	if not cuerpo then return nil, L["Falta el final del texto: cópialo completo."] end
	if control(cuerpo) ~= sello then return nil, L["El texto llegó cortado o cambiado: cópialo otra vez."] end
	local nombre, crudo = cuerpo:match("^([^!]*)!(.*)$")
	if not nombre then return nil, L["Ese texto no es una ruta de Alfa."] end
	local tramos = {}
	for parte in (crudo .. ";"):gmatch("([^;]*);") do
		if parte ~= "" and #tramos < 40 then
			local rama, cant, item, fijas, quitar = parte:match("^(%a+),(%d*),(%d*),([%d%.]*),?([%d%.]*)$")
			if rama and M.RAMA[rama] then
				tramos[#tramos + 1] = { rama = rama, cantidad = tonumber(cant), item = tonumber(item),
					fijas = lista(fijas), quitar = lista(quitar) }
			end
		end
	end
	if #tramos == 0 then return nil, L["La ruta no trae tramos."] end
	nombre = unesc(nombre):sub(1, 60)
	return nombre ~= "" and nombre or L["Ruta importada"], tramos
end

function M.Importar(texto)
	local nombre, tramos = M.LeerImportacion(texto)
	if not nombre then return nil, tramos end
	return M.NuevaRuta(nombre, tramos, "importada")
end

---------------------------------------------------------------------------
-- Plantillas: rutas listas para empezar (cada una se puede cambiar después)
---------------------------------------------------------------------------

-- La profesión de recolección del personaje decide el material (Indice.lua).
local function material()
	local I = M.Indice
	return I and I.MaterialSugerido and I.MaterialSugerido() or nil
end

M.PLANTILLAS = {
	{ clave = "rapido", nombre = L["Subir rápido"], icono = "ic-nivel",
		desc = L["Solo misiones de XP, las mejores cerca de ti, en tres tandas."],
		tramos = function() return { { rama = "xp", cantidad = 5 }, { rama = "xp", cantidad = 5 }, { rama = "xp", cantidad = 5 } } end },
	{ clave = "equilibrada", nombre = L["Equilibrada"], icono = "ic-ruta",
		desc = L["3 de XP, 3 de oro, 3 de XP, 20 de tu profesión y 3 de clase para un objeto único."],
		tramos = function()
			return { { rama = "xp", cantidad = 3 }, { rama = "oro", cantidad = 3 }, { rama = "xp", cantidad = 3 },
				{ rama = "prof", cantidad = 20, item = material() }, { rama = "clase", cantidad = 3 } }
		end },
	{ clave = "oro", nombre = L["Hacer oro"], icono = "ic-oro",
		desc = L["Misiones que dejan dinero y materiales para vender."],
		tramos = function()
			return { { rama = "oro", cantidad = 5 }, { rama = "prof", cantidad = 20, item = material() }, { rama = "oro", cantidad = 5 } }
		end },
	{ clave = "prof", nombre = L["Profesión"], icono = "ic-oficios",
		desc = L["Junta materiales de tu profesión, con unas misiones de XP en medio."],
		tramos = function()
			local m = material()
			return { { rama = "prof", cantidad = 20, item = m }, { rama = "xp", cantidad = 3 }, { rama = "prof", cantidad = 20, item = m } }
		end },
	{ clave = "alfa", nombre = L["Recomendada por Alfa"], icono = "ic-lobo",
		desc = L["Alfa elige todo: misiones ordenadas por XP por distancia y tus misiones de clase."],
		tramos = function()
			local t = { { rama = "xp", cantidad = 6 }, { rama = "xp", cantidad = 6 } }
			local I = M.Indice
			if I and I.HayClase and I.HayClase() then t[#t + 1] = { rama = "clase", cantidad = 3 } end
			t[#t + 1] = { rama = "xp", cantidad = 6 }
			return t
		end },
}

function M.Plantilla(clave)
	for _, p in ipairs(M.PLANTILLAS) do
		if p.clave == clave then return p end
	end
	return nil
end

function M.DesdePlantilla(clave)
	local p = M.Plantilla(clave)
	if not p then return nil end
	local ok, tramos = pcall(p.tramos)
	if not ok or type(tramos) ~= "table" then tramos = { { rama = "xp", cantidad = 3 } } end
	return M.NuevaRuta(p.nombre, tramos, p.clave)
end
