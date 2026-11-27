-- Alfa - Rutas: «Llévame» a cualquier misión de tu registro y «La misión más cerca» (1.4.2). toxic3000 / La Jauría. GPL-3.0.
--
-- Hasta ahora la flecha solo iba a lo que pedía tu guía. Con una misión que
-- la guía no lleva (la tomaste por tu cuenta, te la compartieron) había que
-- buscar en el mapa dónde se hacía. Ahora:
--   * En el registro de misiones del juego y en su seguimiento, el clic
--     derecho en una misión trae «Alfa: llévame» (Contrato.lua): la flecha va
--     al objetivo sin terminar más cercano o, si ya está lista, a quien la
--     recibe.
--   * «La misión más cerca» (tecla, /alfa mision, el menú del rastreador y
--     el de la flecha): de todo tu registro, lo más cerca de ti por hacer o
--     por entregar, de un clic.
--   * El viaje sigue después de /reload o de reconectarte: si la flecha iba
--     a una misión o a un lugar de «Llévame a…», vuelve ahí sola (mientras la
--     misión siga en tu registro).
-- El Codex se lee solo con tu clic y nunca en combate; sin él, lo que sabe la
-- base de misiones (Ligero.lua) sirve para entregar y para los enemigos.
--
--   Ir.Punto(qid, desde, sinCargar) -> punto { map, x, y, f, z, nombre }, que ("objetivo" | "entrega") | nil, motivo
--   Ir.Ir(qid) -> ok, motivo         la flecha a esa misión (con su aviso)
--   Ir.MasCerca(lista) -> ok, qid    la más cerca de tu registro (o de `lista`)
--   Ir.Viajar(p, nombre, etiqueta, qid) -> objetivo de la flecha | nil
--   Ir.Recordar(t, datos)  Ir.Olvidar()  Ir.Retomar() -> bool   el viaje tras /reload
-- Ajuste: rutas.llevameMision (de fábrica, sí). Comando: /alfa mision [nombre].
-- Tecla: ALFA_RUTAS_MAS_CERCA (Bindings.xml).

local ADDON, M = ...
local A, L, N = M.A, M.L, M.N
local Ir = {}
M.IrMision = Ir

A.RegisterDefaults(M.ID, { llevameMision = true })

local type, ipairs, pairs, tonumber, tostring, pcall = type, ipairs, pairs, tonumber, tostring, pcall
local format = string.format

local function CX() return M.Motor("Codex") end
local function CP() return M.Motor("Compat") end
local function I() return M.Indice end
local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end
local function secreto(v) return issecretvalue and issecretvalue(v) or false end

function Ir.Encendido() return A.Get(M.ID .. ".llevameMision") ~= false end

local function codexCargado()
	local C = CX()
	return C and C.IsLoaded and C.IsLoaded() and true or false
end

local function desdeAqui() return A.PlayerPoint and A.PlayerPoint() or nil end

local function nombreBueno(s)
	return type(s) == "string" and s ~= "" and not secreto(s)
end

-- Los objetivos que el juego ya da por hechos (por su orden en la misión).
local function hechos(qid)
	local out = {}
	local QL = C_QuestLog
	if not (QL and QL.GetQuestObjectives) then return out, 0 end
	local ok, objs = pcall(QL.GetQuestObjectives, qid)
	if not (ok and type(objs) == "table") then return out, 0 end
	for i, o in ipairs(objs) do
		if type(o) == "table" and N.Leer(o.finished) == true then out[i] = true end
	end
	return out, #objs
end

local function costo(desde, p)
	local Ix = I()
	if not (desde and Ix and Ix.Viaje) then return 0 end
	return Ix.Viaje(desde, p)
end

local function punto(s, nombre)
	if not (type(s) == "table" and s.map and s.x and s.y) then return nil end
	return { map = s.map, x = s.x, y = s.y, f = s.f, z = s.z, nombre = nombreBueno(nombre) and nombre or nil }
end

-- A quién se entrega: el Codex si ya está leído; si no, la base de misiones;
-- si tampoco, el Codex con tu clic (sinCargar = false).
local function entrega(qid, desde, sinCargar)
	local Ix = I()
	if codexCargado() and Ix and Ix.FinDe then
		local q = CX().Quest(qid)
		local ok, fin = pcall(Ix.FinDe, q and q["end"], desde, Ix.Jugador())
		if ok and fin then return punto(fin, fin.name) end
	end
	local Lg = M.Ligero
	if Lg and Lg.Listo() then
		local ok, p = pcall(Lg.Entrega, qid, desde)
		if ok and p then return punto(p, p.name) end
	end
	if sinCargar or codexCargado() then return nil, "sinLugar" end
	if enCombate() then return nil, "combat" end
	local listo, motivo = Ix.CodexListo()
	if not listo then return nil, motivo end
	return entrega(qid, desde, true)
end

-- Lo más cerca por hacer: los objetivos que te faltan, con su lugar.
local function objetivo(qid, desde, sinCargar)
	local Ix = I()
	if not codexCargado() then
		-- Sin el Codex: los enemigos que pide (la base de misiones).
		local Lg = M.Ligero
		if sinCargar or enCombate() then
			if Lg and Lg.Listo() then
				local mejor, mc
				for _, e in ipairs(Lg.Enemigos(qid) or {}) do
					for _, s in ipairs(e.spawns or {}) do
						local c = costo(desde, s)
						if not mc or c < mc then mejor, mc = punto(s, e.nombre), c end
					end
				end
				if mejor then return mejor end
			end
			return nil, enCombate() and "combat" or "sinLugar"
		end
		local listo, motivo = Ix.CodexListo()
		if not listo then return nil, motivo end
	end
	local q = CX().Quest(qid)
	if not q then return nil, "sinLugar" end
	local ok, partes = pcall(Ix.PasosMision, q, desde)
	if not (ok and type(partes) == "table") then return nil, "sinLugar" end
	local ya, total = hechos(qid)
	-- Solo se filtra si el juego y el Codex cuentan los mismos objetivos.
	local filtrar = total > 0 and total == #(q.objectives or {})
	local mejor, mc
	for _, g in ipairs(partes.objetivos or {}) do
		if g.map and not (filtrar and g.oi and ya[g.oi]) then
			local c = costo(desde, g)
			if not mc or c < mc then
				mejor, mc = punto(g, g.target or g.itemName or g.objName or g.npcName or g.dentroDe), c
			end
		end
	end
	if mejor then return mejor end
	if partes.objetivo then return punto(partes.objetivo) end
	return nil, partes.dentro and "dentro" or "sinLugar"
end

function Ir.Punto(qid, desde, sinCargar)
	qid = tonumber(qid)
	local Cp = CP()
	if not (qid and Cp and Cp.IsOnQuest and Cp.IsOnQuest(qid)) then return nil, "noEsta" end
	desde = desde or desdeAqui()
	if Cp.IsQuestReadyForTurnIn(qid) then
		local p, motivo = entrega(qid, desde, sinCargar)
		if not p then return nil, motivo end
		p.nombre = p.nombre or L["Quien recibe la misión"]
		return p, "entrega"
	end
	local p, motivo = objetivo(qid, desde, sinCargar)
	if not p then return nil, motivo end
	p.nombre = p.nombre or M.TituloMision(qid)
	return p, "objetivo"
end

local function textoMotivo(m)
	if m == "combat" then return L["Espera a salir de combate."] end
	if m == "noEsta" then return L["Esa misión ya no está en tu registro."] end
	if m == "dentro" then return L["Se hace dentro de una mazmorra: busca su entrada en el mapa."] end
	if m == "sinLugar" then return L["No sé dónde se hace esa misión: el juego no lo dice."] end
	local Ix = I()
	return Ix and Ix.TextoMotivo and Ix.TextoMotivo(m) or L["No se pudieron leer los datos del juego."]
end
Ir.TextoMotivo = textoMotivo

---------------------------------------------------------------------------
-- La flecha, y el viaje que sigue tras /reload
---------------------------------------------------------------------------

local vivo -- { t = objetivo de la flecha }

local function guardado() return M.Personaje() end

function Ir.Recordar(t, datos)
	if not (t and type(datos) == "table" and datos.map and datos.x and datos.y) then return end
	vivo = { t = t }
	guardado().viajeVivo = { map = datos.map, x = datos.x, y = datos.y, f = datos.f, z = datos.z,
		nombre = datos.nombre, etiqueta = datos.etiqueta, qid = tonumber(datos.qid) }
end

function Ir.Olvidar()
	vivo = nil
	guardado().viajeVivo = nil
end

function Ir.Viajar(p, nombre, etiqueta, qid)
	local Nav = A.Nav
	if not (p and Nav and type(Nav.SetTarget) == "function") then return nil end
	nombre = nombreBueno(nombre) and nombre or L["Tu destino"]
	local ok, t = pcall(Nav.SetTarget, p.map, p.x, p.y, nombre, p.f, nil, p.z)
	if not (ok and t) then return nil end
	if type(Nav.StartTrip) == "function" then pcall(Nav.StartTrip, t, nombre, etiqueta) end
	Ir.Recordar(t, { map = p.map, x = p.x, y = p.y, f = p.f, z = p.z, nombre = nombre, etiqueta = etiqueta, qid = qid })
	return t
end

-- ¿La flecha sigue en el viaje que se recuerda?
local function sigueVivo()
	if not vivo then return false end
	local Nav = A.Nav
	local ok, t = pcall(function() return Nav and Nav.GetTarget and Nav.GetTarget() end)
	return ok and t ~= nil and t == vivo.t
end
Ir.SigueVivo = sigueVivo

function Ir.Retomar()
	local g = guardado().viajeVivo
	if type(g) ~= "table" or not (g.map and g.x and g.y) then return false end
	if enCombate() then return false end
	local Cp = CP()
	if g.qid and not (Cp and Cp.IsOnQuest and Cp.IsOnQuest(g.qid)) then Ir.Olvidar() return false end
	local Nav = A.Nav
	-- Otra cosa ya apunta la flecha a mano (la vuelta a entregar, un raro): manda esa.
	if Nav and Nav.IsOverride and Nav.IsOverride() then return false end
	local t = Ir.Viajar(g, g.nombre, g.etiqueta, g.qid)
	return t ~= nil
end

A.OnLogin(function() A.After(4, function() pcall(Ir.Retomar) end) end)

-- Al salir (y en /reload): si la flecha ya no iba ahí (llegaste, otra cosa
-- tomó la flecha), se olvida.
A.RegisterEvent("PLAYER_LOGOUT", function() if not sigueVivo() then Ir.Olvidar() end end)
A.On("NAV_TRIP", function(trip) if trip == nil and not sigueVivo() then Ir.Olvidar() end end)
A.RegisterEvent("QUEST_TURNED_IN", function(_, qid)
	local g = guardado().viajeVivo
	if type(g) == "table" and g.qid and tonumber(qid) == g.qid then Ir.Olvidar() end
end)
A.RegisterEvent("QUEST_REMOVED", function(_, qid)
	local g = guardado().viajeVivo
	if type(g) == "table" and g.qid and tonumber(qid) == g.qid then Ir.Olvidar() end
end)

---------------------------------------------------------------------------
-- «Llévame» y «La misión más cerca»
---------------------------------------------------------------------------

local function avisoIr(qid, p, que)
	local titulo = M.Citar(M.TituloMision(qid))
	if que == "entrega" then
		M.Aviso(L["Llévame"], format(L["Vamos a entregar %s con %s: sigue la flecha."], titulo, p.nombre), { icono = "ic-flecha" })
	else
		M.Aviso(L["Llévame"], format(L["Vamos a %s: %s. Sigue la flecha."], titulo, p.nombre), { icono = "ic-flecha" })
	end
end

function Ir.Ir(qid)
	qid = tonumber(qid)
	local p, que = Ir.Punto(qid)
	if not p then
		M.Aviso(L["Llévame"], textoMotivo(que), { icono = "ic-aviso", tono = "aviso" })
		return false, que
	end
	local t = Ir.Viajar(p, p.nombre, que == "entrega" and L["Entregar"] or L["Tu misión"], qid)
	if not t then return false, "flecha" end
	M.Empezar()
	avisoIr(qid, p, que)
	return true
end

function Ir.MasCerca(lista)
	local Cp = CP()
	if enCombate() then
		M.Aviso(L["La misión más cerca"], L["Espera a salir de combate."], { icono = "ic-aviso", tono = "aviso" })
		return false, "combat"
	end
	local qids = type(lista) == "table" and lista or (Cp and Cp.GetLogQuests and Cp.GetLogQuests()) or {}
	if #qids == 0 then
		M.Aviso(L["La misión más cerca"], L["Tu registro de misiones está vacío. ¿Buscamos misiones cerca de ti?"], {
			icono = "ic-misiones", accion = { texto = L["Recoger misiones"], alClic = function() if M.Recoger then M.Recoger.Ahora() end end } })
		return false, "vacio"
	end
	local desde = desdeAqui()
	local mejor, mq, mque, mc, motivo
	for _, qid in ipairs(qids) do
		if not (Cp.IsQuestFailed and Cp.IsQuestFailed(qid)) then
			local p, que = Ir.Punto(qid, desde)
			if p then
				local c = costo(desde, p)
				if not mc or c < mc then mejor, mq, mque, mc = p, qid, que, c end
			elseif que == "combat" or que == "missing" or que == "disabled" then
				motivo = que
				break
			end
		end
	end
	if not mejor then
		M.Aviso(L["La misión más cerca"], motivo and textoMotivo(motivo) or L["No sé dónde se hacen tus misiones: el juego no lo dice."], {
			icono = "ic-aviso", tono = "aviso" })
		return false, motivo or "sinLugar"
	end
	local t = Ir.Viajar(mejor, mejor.nombre, mque == "entrega" and L["Entregar"] or L["Tu misión"], mq)
	if not t then return false, "flecha" end
	M.Empezar()
	avisoIr(mq, mejor, mque)
	return true, mq
end

-- Una misión de tu registro por su nombre (o parte de él).
function Ir.Buscar(texto)
	local Cp = CP()
	local q = M.Plegar(texto or "")
	if q == "" or not (Cp and Cp.GetLogQuests) then return nil end
	for _, qid in ipairs(Cp.GetLogQuests()) do
		local t = M.TituloMision(qid)
		if type(t) == "string" and M.Plegar(t):find(q, 1, true) then return qid end
	end
	return nil
end

A.RegisterCommand("mision", function(resto)
	local texto = type(resto) == "string" and resto:match("^%s*(.-)%s*$") or ""
	if texto == "" or texto == "cerca" or texto == "cercana" then return Ir.MasCerca() end
	local qid = Ir.Buscar(texto)
	if not qid then
		M.Aviso(L["Llévame"], format(L["No tienes en tu registro una misión que se llame %s."], M.Citar(texto)), { icono = "ic-aviso", tono = "aviso" })
		return
	end
	Ir.Ir(qid)
end, L["La flecha a tu misión más cerca, o a la que nombres (/alfa mision Pieles de jabalí)."])

BINDING_NAME_ALFA_RUTAS_MAS_CERCA = L["La misión más cerca (la flecha a lo más cerca de tu registro)"]
BINDING_NAME_ALFA_RUTAS_ENTREGAR = L["Vuelta a entregar (tus misiones listas)"]
BINDING_NAME_ALFA_RUTAS_CERRAR = L["Cerrar mis misiones"]

AlfaRuta = type(rawget(_G, "AlfaRuta")) == "table" and rawget(_G, "AlfaRuta") or {}
AlfaRuta.LlevameMision = function(qid) return Ir.Ir(qid) end
AlfaRuta.MisionMasCerca = function(lista) return Ir.MasCerca(lista) end
