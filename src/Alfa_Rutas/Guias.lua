-- Alfa - Rutas: las rutas como guías del motor. Cada ruta compilada es una
-- guía del paquete "mis-rutas" (A.RegisterPack / A.RegisterGuide, como
-- cualquier paquete de la comunidad), así que la flecha, los pasos, el mapa
-- y las pestañas del motor la siguen igual que a las guías de Alfa, y el
-- menú de guías la lista bajo "Mis rutas". Toxic / La Jauría. GPL-3.0.
--
-- Los pasos compilados se guardan por personaje (M.Personaje().guias[rutaId],
-- y .liberar): al cargar el addon se registran otra vez, antes de que el
-- motor reabra las pestañas guardadas al entrar al mundo.
--
--   Guias.IdRuta(rutaId), Guias.IdLiberar()
--   Guias.Def(id, titulo, pasos, extra) -> def    -- la guía con los campos del paquete
--   Guias.Instalar(def) -> ok, motivo             -- registra (o reemplaza) y la guarda
--   Guias.Abrir(id) -> índice de pestaña | nil, motivo ("login" | "tabs" | "nada")
--   Guias.Activa() -> rutaId | "liberar" | nil    -- la de la pestaña activa, si es nuestra
--   Guias.Retirar(rutaId)                         -- una ruta borrada
--   Guias.MostrarEnMenu(id)                       -- abre el menú de guías en "Mis rutas"

local ADDON, M = ...
local A, L = M.A, M.L
local G = {}
M.Guias = G

local type, ipairs, pairs, tostring = type, ipairs, pairs, tostring

local PACK = M.PACK
local LIBERAR = PACK .. "/liberar"
local registrado = false

function G.IdRuta(rutaId) return PACK .. "/" .. tostring(rutaId) end
function G.IdLiberar() return LIBERAR end

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
		notes = L["Las rutas que armas en la página Rutas de Alfa."],
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
	if def.id == LIBERAR then
		p.liberar = M.Copia(def)
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
	-- Como el "Guíame" del motor: la ventana de la guía se muestra.
	if A.Set then A.Set("ui.shown", true) end
	return i
end

function G.Activa()
	local E = M.Motor("Engine")
	local g = E and E.GetGuide and E.GetGuide()
	local id = g and g.id
	if type(id) ~= "string" or id:sub(1, #PACK + 1) ~= PACK .. "/" then return nil end
	if id == LIBERAR then return "liberar" end
	return id:sub(#PACK + 2)
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

function G.MostrarEnMenu(id)
	local UI = M.Motor("UI")
	local Pk = UI and UI.Picker
	if not (UI and UI.ShowPicker) then return false end
	if Pk then
		if Pk.ShowSection then Pk.ShowSection(nil) end
		if Pk.SetCategory then Pk.SetCategory("pack:" .. PACK) end
		if id and Pk.Select then Pk.Select(id) end
	end
	UI.ShowPicker()
	return true
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
	if type(p.liberar) == "table" and not registrar(p.liberar) then p.liberar = nil end
end

local function alCargar(_, nombre)
	if nombre ~= ADDON then return end
	if A.UnregisterEvent then A.UnregisterEvent("ADDON_LOADED", alCargar) end
	local ok, err = pcall(restaurar)
	if not ok and geterrorhandler then geterrorhandler()(err) end
end
A.RegisterEvent("ADDON_LOADED", alCargar)
