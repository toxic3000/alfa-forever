-- Alfa - Núcleo: los datos técnicos del reporte (1.3.9). toxic3000 / La
-- Jauría. GPL-3.0.
--
-- /alfa reportar (Alfa_Bienvenida/Reporte.lua) junta aquí lo que ayuda a
-- arreglar un error y no es privado:
--   N.InformeTecnico() -> { línea, ... }
--     «Módulos: Bolsas, Combate, ... · apagados: Pesca»
--     «Modo sencillo · Alfa usa 41.2 MB · 23 tareas del reloj (la que más tarda: rutas.rastreador)»
--     «Otros addons (3): BugSack, Details, WeakAuras»
--   N.SinPrivado(s) -> s sin el nombre de tu personaje ni tu reino ni los de
--     otros jugadores (Nombre-Reino): para lo que se copia fuera del juego.
-- La memoria se mide como mucho una vez cada 30 s: UpdateAddOnMemoryUsage
-- recorre todos los addons, y el reporte se rearma con cada letra que escribes.

local _, N = ...
local L = N.Kit and N.Kit.L or N.Textos(N.EN)

local type, tostring, ipairs, pcall, format, concat, sort = type, tostring, ipairs, pcall, string.format, table.concat, table.sort

local function legible(x)
	if issecretvalue and issecretvalue(x) then return nil end
	return x
end

local function addons()
	local C = C_AddOns
	local num = C and C.GetNumAddOns or rawget(_G, "GetNumAddOns")
	local info = C and C.GetAddOnInfo or rawget(_G, "GetAddOnInfo")
	local cargado = C and C.IsAddOnLoaded or rawget(_G, "IsAddOnLoaded")
	local meta = C and C.GetAddOnMetadata or rawget(_G, "GetAddOnMetadata")
	local estado = C and C.GetAddOnEnableState
	local out = {}
	if not (num and info and cargado) then return out end
	local ok, n = pcall(num)
	for i = 1, ok and tonumber(n) or 0 do
		local ok2, nombre = pcall(info, i)
		if ok2 and type(nombre) == "string" then
			local ok3, si = pcall(cargado, nombre)
			local autor = meta and select(2, pcall(meta, nombre, "Author")) or nil
			local apagado = false
			if estado then
				local ok4, e = pcall(estado, nombre, UnitName and UnitName("player") or nil)
				if not ok4 then ok4, e = pcall(estado, nombre) end
				apagado = ok4 and e == 0
			end
			out[#out + 1] = { nombre = nombre, cargado = ok3 and si == true, apagado = apagado,
				modulo = nombre:find("^Alfa_") ~= nil and type(autor) == "string" and autor:lower():find("toxic3000", 1, true) ~= nil }
		end
	end
	return out
end

-- La memoria de Alfa (todas sus carpetas), medida como mucho cada 30 s.
local memoria, medida = nil, -1e9
local function memoriaAlfa(lista)
	local ahora = GetTime and GetTime() or 0
	if memoria and ahora - medida < 30 then return memoria end
	local get = C_AddOns and C_AddOns.GetAddOnMemoryUsage or rawget(_G, "GetAddOnMemoryUsage")
	if not get then return nil end
	if UpdateAddOnMemoryUsage then pcall(UpdateAddOnMemoryUsage) end
	local kb = 0
	for _, a in ipairs(lista) do
		if a.cargado and (a.nombre == "Alfa" or a.nombre:find("^Alfa_")) then
			local ok, x = pcall(get, a.nombre)
			if ok and type(x) == "number" then kb = kb + x end
		end
	end
	memoria, medida = kb, ahora
	return kb
end

function N.InformeTecnico()
	local lista = addons()
	local mods, apagados, otros = {}, {}, {}
	for _, a in ipairs(lista) do
		if a.modulo then
			local corto = a.nombre:gsub("^Alfa_", "")
			if a.cargado then mods[#mods + 1] = corto elseif a.apagado then apagados[#apagados + 1] = corto end
		elseif a.cargado and a.nombre ~= "Alfa" and not a.nombre:find("^Alfa_") and not a.nombre:find("^Blizzard_") then
			otros[#otros + 1] = a.nombre
		end
	end
	sort(mods) sort(apagados) sort(otros)
	local out = {}
	local l = format(L["Módulos: %s"], #mods > 0 and concat(mods, ", ") or "?")
	if #apagados > 0 then l = l .. " · " .. format(L["apagados: %s"], concat(apagados, ", ")) end
	out[#out + 1] = l
	local partes = { N.Sencillo and N.Sencillo() and L["Modo sencillo"] or L["Modo completo"] }
	local kb = memoriaAlfa(lista)
	if kb then partes[#partes + 1] = format(L["Alfa usa %.1f MB"], kb / 1024) end
	local tareas = N.Tareas and N.Tareas() or {}
	if #tareas > 0 then
		partes[#partes + 1] = format(L["%d tareas del reloj (la que más tarda: %s)"], #tareas, tostring(tareas[1].clave))
	end
	out[#out + 1] = concat(partes, " · ")
	if #otros > 0 then
		local muestra = {}
		for i = 1, math.min(#otros, 12) do muestra[i] = otros[i] end
		out[#out + 1] = format(L["Otros addons (%d): %s"], #otros, concat(muestra, ", ") .. (#otros > 12 and ", ..." or ""))
	end
	return out
end

-- Sin tu nombre, tu reino ni el de otros jugadores.
local function escapar(s) return (s:gsub("[%p]", "%%%0")) end
function N.SinPrivado(s)
	if type(s) ~= "string" or s == "" then return s end
	local nombre = UnitName and legible((UnitName("player")))
	local reino = GetRealmName and legible(GetRealmName())
	-- Nombre-Reino (como los da el chat y la manada): fuera los dos.
	s = s:gsub("([%a\192-\255][%w\128-\255']+)%-([%a\192-\255][%w\128-\255']+)", function(a, b)
		if a:sub(1, 1):match("[%u\192-\255]") and b:sub(1, 1):match("[%u\192-\255]") then return L["<jugador>"] end
	end)
	if type(nombre) == "string" and #nombre >= 2 then s = s:gsub(escapar(nombre), L["<tu personaje>"]) end
	if type(reino) == "string" and #reino >= 2 then s = s:gsub(escapar(reino), L["<tu reino>"]) end
	return s
end
