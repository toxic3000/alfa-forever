-- Alfa - Rutas: las rutas como guías del motor. Cada ruta compilada es una
-- guía del paquete "mis-rutas" (A.RegisterPack / A.RegisterGuide, como
-- cualquier paquete de la comunidad), así que la flecha, los pasos, el mapa
-- y las pestañas del motor la siguen igual que a las guías de Alfa, y el
-- menú de guías la lista bajo "Mis rutas". toxic3000 / La Jauría. GPL-3.0.
--
-- Los pasos compilados se guardan por personaje (M.Personaje().guias[rutaId],
-- y .liberar): al cargar el addon se registran otra vez, antes de que el
-- motor reabra las pestañas guardadas al entrar al mundo.
--
--   Guias.IdRuta(rutaId), Guias.IdLiberar()
--   Guias.Def(id, titulo, pasos, extra) -> def    -- la guía con los campos del paquete
--   Guias.Instalar(def) -> ok, motivo             -- registra (o reemplaza) y la guarda
--   Guias.Abrir(id) -> índice de pestaña | nil, motivo ("login" | "tabs" | "nada")
--   Guias.IdEspecial(nombre), Guias.Especial(id) -> "liberar" | "recoger" | "desbloquear" | nil
--   Guias.Activa() -> rutaId | "liberar" | "recoger" | "desbloquear" | nil  -- la de la pestaña activa, si es nuestra
--   Guias.Retirar(rutaId)                         -- una ruta borrada

local ADDON, M = ...
local A, L = M.A, M.L
local G = {}
M.Guias = G

local type, ipairs, pairs, tostring = type, ipairs, pairs, tostring

local PACK = M.PACK
local LIBERAR = PACK .. "/liberar"
local registrado = false

-- Las guías que no son rutas del árbol: cerrar tus misiones, recoger las de
-- cerca y desbloquear una misión (lo que pide antes). Se guardan aparte.
local ESPECIALES = { liberar = true, recoger = true, desbloquear = true, circuito = true } -- circuito: 1.3.0 (Circuito.lua)

function G.IdRuta(rutaId) return PACK .. "/" .. tostring(rutaId) end
function G.IdLiberar() return LIBERAR end
function G.IdEspecial(nombre) return PACK .. "/" .. nombre end

-- "liberar", "recoger", "desbloquear" o nil, de un id de guía.
function G.Especial(id)
	if type(id) ~= "string" or id:sub(1, #PACK + 1) ~= PACK .. "/" then return nil end
	local resto = id:sub(#PACK + 2)
	return ESPECIALES[resto] and resto or nil
end

local function nombreJugador()
	local n = UnitName and UnitName("player")
	if type(n) == "string" and n ~= "" then return n end
	return "Alfa"
end

function G.Paquete()
	if registrado then return true end
	if type(A.RegisterPack) ~= "function" then return false end
	local ok = A.RegisterPack({
		addon = ADDON, id = PACK, format = 9, title = L["Mis rutas"], author = nombreJugador(),
		version = tostring(M.N.version or "1"), license = "GPL-3.0-only",
		notes = L["Las rutas y los planes que armas en la página Ruta de Alfa."],
	})
	registrado = ok and true or false
	return registrado
end

-- La guía con lo que el menú de guías y el motor esperan de ella.
function G.Def(id, titulo, pasos, extra)
	local p = M.Indice.Jugador()
	local def = {
		id = id, pack = PACK, title = (type(titulo) == "string" and titulo ~= "") and titulo or L["Mi ruta"],
		category = L["Mis rutas"], author = nombreJugador(), version = 1,
		faction = (p.faction == "Alliance" or p.faction == "Horde") and p.faction or nil,
		keywords = { L["ruta"], L["rutas"], "alfa" }, steps = pasos,
	}
	for k, v in pairs(extra or {}) do def[k] = v end
	if def.zone then
		local Cp = M.Motor("Compat")
		def.zoneName = Cp and Cp.MapName and Cp.MapName(def.zone) or nil
	end
	return def
end

local function avisarMotor()
	if A.IsLoggedIn and A.IsLoggedIn() then
		A.Fire("GUIDES_REGISTERED")
		-- Una pestaña abierta con esta guía toma la nueva versión (Engine, PACKS_CHANGED).
		A.Fire("PACKS_CHANGED", PACK)
	end
end

-- El motor escapa y traduce los textos de la guía en su lugar: se le da una copia.
local function registrar(def)
	if not G.Paquete() then return false, "paquete" end
	local ok, err = A.RegisterGuide(M.Copia(def))
	return ok and true or false, err
end

-- A dónde se guarda una guía de este personaje.
local function guardar(def)
	local p = M.Personaje()
	local esp = G.Especial(def.id)
	if esp then
		p.especiales = type(p.especiales) == "table" and p.especiales or {}
		p.especiales[esp] = M.Copia(def)
	else
		local rutaId = def.id:sub(#PACK + 2)
		p.guias[rutaId] = M.Copia(def)
	end
end

function G.Instalar(def)
	local ok, err = registrar(def)
	if not ok then return false, err end
	guardar(def)
	avisarMotor()
	return true
end

-- Un plan nuevo, pedido con un clic, empieza limpio (1.2.2). El motor
-- reconoce los pasos por su contenido y, al cambiar la guía, les devuelve lo
-- que ya tenían (checkShape): un paso de «Cerrar mis misiones» que omitiste
-- seguía omitido en cada plan nuevo con esa misión, y con todos omitidos el
-- plan quedaba sin paso (ni terminado ni con algo que seguir). Se olvida lo
-- guardado de esa guía: omitidos, marcados, su forma y su paso fijado.
local ESTADO = { "manual", "skipped", "when", "skipStored", "added", "gone", "behind", "passedBefore", "lostQuests",
	"guideEnds", "shapes", "stepKeys", "shapeVersions", "ownShapes", "pins" }
function G.Olvidar(id)
	if type(id) ~= "string" or type(A.CharState) ~= "function" then return end
	local ok, s = pcall(A.CharState)
	if not ok or type(s) ~= "table" then return end
	for _, campo in ipairs(ESTADO) do
		if type(s[campo]) == "table" then s[campo][id] = nil end
	end
end

function G.Abrir(id)
	local E = M.Motor("Engine")
	if not (E and E.OpenTab and A.IsLoggedIn and A.IsLoggedIn()) then return nil, "login" end
	local Gd = M.Motor("Guides")
	if not (Gd and Gd.Get and Gd.Get(id)) then return nil, "nada" end
	for i, t in ipairs(E.GetTabs() or {}) do
		if t.guideId == id then
			E.SelectTab(i)
			return i
		end
	end
	local i = E.OpenTab(id, true)
	if not i then return nil, "tabs" end
	-- Como el "Guíame" del motor: la ventana de la guía se muestra (y las
	-- de Alfa se cierran). Solo lo abre un clic: Seguir, Liberar, Recoger...
	M.Empezar()
	return i
end

-- 1.2.6: la guía que tenías antes de abrir «Desbloquear», para volver a
-- ella al terminar. Se guarda por personaje (sobrevive a un /reload).
function G.RecordarVuelta()
	local E = M.Motor("Engine")
	local g = E and E.GetGuide and E.GetGuide()
	local id = g and g.id
	if type(id) ~= "string" or G.Especial(id) == "desbloquear" then return end
	M.Personaje().vuelta = id
end

-- Regresa a la guía de antes (si sigue existiendo); true si la abrió.
function G.Volver()
	local p = M.Personaje()
	local id = p.vuelta
	p.vuelta = nil
	if type(id) ~= "string" then return false end
	return G.Abrir(id) ~= nil
end

function G.Activa()
	local E = M.Motor("Engine")
	local g = E and E.GetGuide and E.GetGuide()
	local id = g and g.id
	if type(id) ~= "string" or id:sub(1, #PACK + 1) ~= PACK .. "/" then return nil end
	return G.Especial(id) or id:sub(#PACK + 2)
end

-- ¿Está la guía de esta ruta abierta en alguna pestaña?
function G.Abierta(id)
	local E = M.Motor("Engine")
	if not (E and E.GetTabs) then return false end
	for _, t in ipairs(E.GetTabs() or {}) do
		if t.guideId == id then return true end
	end
	return false
end

-- Una ruta borrada: su pestaña se cierra y la guía queda vacía hasta
-- recargar (el motor no deja quitar guías de un paquete en marcha).
function G.Retirar(rutaId)
	local id = G.IdRuta(rutaId)
	local Gd, E = M.Motor("Guides"), M.Motor("Engine")
	if not (Gd and Gd.Get and Gd.Get(id)) then return end
	if E and E.GetTabs then
		for i, t in ipairs(E.GetTabs() or {}) do
			if t.guideId == id then E.CloseTab(i, true) break end
		end
	end
	registrar(G.Def(id, L["Ruta borrada"], { { title = L["Ruta borrada"],
		goals = { { t = "note", text = L["Borraste esta ruta. Desaparece del menú al recargar la interfaz."] } } } }))
	avisarMotor()
end

---------------------------------------------------------------------------
-- Al cargar: el paquete y las guías guardadas de este personaje
---------------------------------------------------------------------------

G.Paquete()

local function restaurar()
	local p = M.Personaje()
	for rutaId, def in pairs(p.guias) do
		if type(def) == "table" and M.Ruta(rutaId) then
			if not registrar(def) then p.guias[rutaId] = nil end
		else
			p.guias[rutaId] = nil
		end
	end
	p.liberar = nil -- (versiones viejas: ahora va en especiales)
	-- Una vez por personaje (1.2.2): «Cerrar mis misiones» sin los pasos
	-- omitidos que heredaba de planes viejos (G.Olvidar), antes de que el
	-- motor reabra sus pestañas; así un plan atorado sin paso se arregla solo.
	if not p.olvido122 then
		p.olvido122 = true
		G.Olvidar(LIBERAR)
	end
	if type(p.especiales) == "table" then
		for k, def in pairs(p.especiales) do
			if not (ESPECIALES[k] and type(def) == "table" and registrar(def)) then p.especiales[k] = nil end
		end
	end
end

local function alCargar(_, nombre)
	if nombre ~= ADDON then return end
	if A.UnregisterEvent then A.UnregisterEvent("ADDON_LOADED", alCargar) end
	local ok, err = pcall(restaurar)
	if not ok and geterrorhandler then geterrorhandler()(err) end
end
A.RegisterEvent("ADDON_LOADED", alCargar)
