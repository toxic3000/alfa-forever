-- Alfa - La Jauría: "Seguir" a alguien de la manada con la flecha de Alfa
-- (la del motor: el estilo de la flecha de lobo lo pone la apariencia) y su
-- ruta. toxic3000 / La Jauría. GPL-3.0.
--
-- Pone su posición como destino de la navegación del motor (Alfa.Nav.SetTarget,
-- lo mismo que "/alfa way" y el seguir del grupo de Quests/Party.lua), como un
-- viaje (Alfa.Nav.StartTrip): la ventana de la guía dice "De camino a ..." con
-- "Volver a la guía", y el viaje termina solo al llegar. Mientras se mueve,
-- el destino se mueve con ella cada CADA segundos (Alfa.Nav.MoveTarget: una
-- sola llegada, un solo sonido) cuando cambió más de MOVER yardas.
-- Se detiene al llegar, al cancelar (aquí, en la flecha o en la guía), cuando
-- otro destino toma la flecha, o cuando su posición se pierde por más de
-- PERDIDO segundos (salió del grupo, entró a una mazmorra, dejó de compartir).

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local U = M.U
local L = M.L

local S = {}
M.Seguir = S

local CADA = 3
local MOVER = 12
local PERDIDO = 45

local sig -- { clave, nombre, tipo, objetivo, ticker, map, c, wx, wy, perdidoDesde }

local function nav() return A.Nav end

local function etiqueta(tipo)
	if tipo == "grupo" then return L["Tu grupo"] end
	return L["La Jauría"]
end

local function avisar()
	M.Gente.Cambio()
	if M.Mapa then M.Mapa.Refrescar(true) end
	if M.Avisar then M.Avisar() end
end

local function soltar()
	if sig and sig.ticker then sig.ticker:Cancel() end
	sig = nil
	avisar()
end

-- Dónde está ahora la persona seguida.
local function dondeEsta(s)
	local G = M.Gente
	if s.tipo == "grupo" or G.EnGrupo(s.clave) then
		local unit = G.UnidadDe(s.clave)
		if unit then
			local con = UnitIsConnected and U.Leer(UnitIsConnected(unit))
			if con ~= false then
				local map, x, y = U.PosUnidad(unit)
				if map then return map, x, y end
			end
		end
	end
	return G.PosicionDe({ clave = s.clave })
end

local function tick()
	local Nav = nav()
	if not sig then return end
	if Nav.GetTarget() ~= sig.objetivo then
		-- Otro destino tomó la flecha (un paso nuevo de la guía, un clic en el
		-- mapa, "Volver a la guía"): se dice, salvo al llegar.
		local nombre, llego = sig.nombre, sig.llego
		soltar()
		if not llego then U.Decir(L["La flecha tomó otro destino: dejaste de seguir a %s."]:format(nombre)) end
		return
	end
	local map, x, y = dondeEsta(sig)
	local ahora = U.Ahora()
	if not map then
		sig.perdidoDesde = sig.perdidoDesde or ahora
		if ahora - sig.perdidoDesde > PERDIDO then
			local nombre = sig.nombre
			S.Parar(true)
			U.Decir(L["Perdimos el rastro de %s: ya no sabemos dónde está."]:format(nombre))
		end
		return
	end
	sig.perdidoDesde = nil
	local c, wx, wy = U.AlMundo(map, x, y)
	local movio = map ~= sig.map or not c or c ~= sig.c
	if not movio then
		local dx, dy = wx - sig.wx, wy - sig.wy
		movio = dx * dx + dy * dy >= MOVER * MOVER
	end
	if movio then
		sig.map, sig.c, sig.wx, sig.wy = map, c, wx, wy
		pcall(Nav.MoveTarget, sig.objetivo, map, x, y)
	end
end

-- Sigue a `fila` (de la página o del mapa). true si la flecha la sigue.
function S.A(fila)
	local Nav = nav()
	if not (fila and fila.clave and Nav and Nav.SetTarget) then return false end
	if U.EnInstancia() then
		U.Decir(L["Dentro de una instancia no se puede seguir a nadie."])
		return false
	end
	local s = { clave = fila.clave, nombre = fila.nombre or "?", tipo = fila.tipo }
	local map, x, y = dondeEsta(s)
	if not map then
		U.Decir(L["No sabemos dónde está %s. Solo se puede seguir a tu grupo y a quien comparte su ubicación con Alfa."]:format(s.nombre))
		return false
	end
	if Nav.SayHandedOff and Nav.SayHandedOff() then return false end
	if sig then
		if sig.ticker then sig.ticker:Cancel() end
		sig = nil
	end
	local objetivo = Nav.SetTarget(map, x, y, s.nombre)
	if type(objetivo) ~= "table" then return false end
	if Nav.StartTrip then Nav.StartTrip(objetivo, s.nombre, etiqueta(s.tipo)) end
	if N.EmpezarRuta then N.EmpezarRuta() end -- cierra las ventanas de Alfa y muestra el seguimiento
	s.objetivo = objetivo
	s.map = map
	s.c, s.wx, s.wy = U.AlMundo(map, x, y)
	s.ticker = A.NewTicker(CADA, tick)
	sig = s
	U.Decir(L["Siguiendo el rastro de %s. La flecha te lleva hasta su posición."]:format(s.nombre))
	if Nav.SayGuideHidden then Nav.SayGuideHidden() end
	avisar()
	return true
end

-- Deja de seguir. `callado`: sin aviso del motor ("La flecha vuelve a la guía").
function S.Parar(callado)
	if not sig then return false end
	local Nav = nav()
	local t = sig.objetivo
	if sig.ticker then sig.ticker:Cancel() end
	sig = nil
	if Nav and Nav.GetTarget and Nav.GetTarget() == t then
		local trip = Nav.Trip and Nav.Trip()
		if trip and trip.target == t and not callado then
			Nav.EndTrip()
		elseif Nav.ReleaseTarget then
			Nav.ReleaseTarget()
		end
	end
	avisar()
	return true
end

-- A quién se sigue: { clave, nombre, tipo } o nil.
-- (Si otro destino tomó la flecha ya no cuenta; el tick lo suelta y lo dice.)
function S.Actual()
	if sig and nav().GetTarget() ~= sig.objetivo then return nil end
	return sig
end

function S.Sigue(clave)
	local s = S.Actual()
	return s ~= nil and s.clave == clave
end

-- Seguir por nombre (/alfa manada seguir Ana): el primero que coincide.
function S.PorNombre(texto)
	local buscar = U.Plegar(texto)
	if buscar == "" then return false end
	for _, f in ipairs(M.Gente.Manada()) do
		local n = U.Plegar(f.nombre)
		if n == buscar or n:sub(1, #buscar) == buscar then return S.A(f) end
	end
	U.Decir(L["No encontramos a \"%s\" en tu grupo ni entre quienes comparten su ubicación."]:format(texto))
	return false
end

-- Al llegar el motor termina el viaje solo; aquí solo se dice con quién.
A.On("NAV_ARRIVED", function(t)
	if sig and t == sig.objetivo then
		local nombre = sig.nombre
		sig.llego = true
		A.After(0, function()
			if sig and sig.objetivo == t then soltar() end
		end)
		U.Decir(L["Llegaste con %s."]:format(nombre))
	end
end)
