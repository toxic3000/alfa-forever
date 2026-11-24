-- Alfa - Núcleo: eventos más baratos (1.3.5). toxic3000 / La Jauría. GPL-3.0.
--
--   N.DeUnidad(evento, unidades, fn)  fn(evento, ...) solo para esas unidades
--                                     ("player", "pet", ...; hasta 2, como el
--                                     juego). En grupo o en banda, UNIT_AURA o
--                                     UNIT_SPELLCAST_* llegan cientos de veces
--                                     por segundo de los demás: así el juego ni
--                                     siquiera llama a Alfa por ellos.
--   N.Juntar(fn) -> g                 g(...) cuantas veces quieras en un cuadro:
--                                     fn corre una sola vez, en el siguiente
--                                     (con los argumentos de la última llamada).
--                                     Para eventos que llegan en ráfaga (al
--                                     cambiar de zona salen 2 o 3 juntos).
--   N.PorPrefijo(prefijo, fn)         fn("CHAT_MSG_ADDON", prefijo, texto, canal, ...)
--                                     solo para los mensajes de ese prefijo. Un
--                                     solo marco escucha los mensajes de TODOS
--                                     los addons del juego y reparte los de Alfa.

local _, N = ...

local pcall, type, select, unpack = pcall, type, select, unpack

local function avisar(err)
	if geterrorhandler then pcall(geterrorhandler(), err) end
end

function N.DeUnidad(evento, unidades, fn)
	if type(unidades) == "string" then unidades = { unidades } end
	local f = CreateFrame("Frame")
	local ok = f.RegisterUnitEvent and pcall(f.RegisterUnitEvent, f, evento, unidades[1], unidades[2])
	if not ok then
		-- Un evento que este cliente no conoce: nada que escuchar.
		if not pcall(f.RegisterEvent, f, evento) then return nil end
	end
	f:SetScript("OnEvent", function(_, ev, ...)
		local bien, err = pcall(fn, ev, ...)
		if not bien then avisar(err) end
	end)
	return f
end

function N.Juntar(fn)
	local pendiente, args, n = false, {}, 0
	local function correr()
		pendiente = false
		local bien, err = pcall(fn, unpack(args, 1, n))
		if not bien then avisar(err) end
	end
	return function(...)
		n = select("#", ...)
		for i = 1, n do args[i] = select(i, ...) end
		if pendiente then return end
		pendiente = true
		if C_Timer and C_Timer.After then C_Timer.After(0, correr) else correr() end
	end
end

local porPrefijo, marcoPrefijos = {}, nil
function N.PorPrefijo(prefijo, fn)
	local lista = porPrefijo[prefijo]
	if not lista then
		lista = {}
		porPrefijo[prefijo] = lista
	end
	for i = 1, #lista do if lista[i] == fn then return end end
	lista[#lista + 1] = fn
	if marcoPrefijos then return end
	marcoPrefijos = CreateFrame("Frame")
	marcoPrefijos:RegisterEvent("CHAT_MSG_ADDON")
	marcoPrefijos:SetScript("OnEvent", function(_, ev, pre, texto, ...)
		if issecretvalue and issecretvalue(pre) then return end
		local l = porPrefijo[pre]
		if not l then return end
		-- 1.3.8 (Faccion.lua): lo de la otra facción no llega a nadie, y la
		-- marca de facción se quita antes de repartir.
		if N.FiltroFaccion then
			local sigue, limpio = N.FiltroFaccion(texto, ...)
			if not sigue then return end
			texto = limpio
		end
		for i = 1, #l do
			local bien, err = pcall(l[i], ev, pre, texto, ...)
			if not bien then avisar(err) end
		end
	end)
end
