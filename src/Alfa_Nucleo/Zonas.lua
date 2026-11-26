-- Alfa - Núcleo: llegar a una zona se siente (1.3.7). toxic3000 / La Jauría. GPL-3.0.
--
-- Pedido de Toxic: «cuando descubres una ubicación aparece "has descubierto",
-- pero solo una vez; quiero que cada vez que llegues a ese tipo de zonas
-- aparezca ese anuncio como el de los barcos, los trenes o los raros, y que
-- haya diferentes animaciones para cada estilo». Con el anuncio animado del
-- Kit (Kit/Anuncio.lua, K.Anuncio con su `estilo`):
--   zona       al llegar a una zona (ZONE_CHANGED_NEW_AREA, al aterrizar del
--              grifo, al salir de una pantalla de carga): su nombre con el color
--              de quién es (verde amistosa, rojo hostil, ámbar disputada, azul
--              santuario, C_PvP.GetZonePVPInfo), el rincón donde estás y su
--              rango de niveles (Maps.GetZoneLevels del motor: ya cargado, sin el Codex).
--   subzona    al pasar a otro rincón (ZONE_CHANGED): chico, de fábrica.
--   descubrir  el mensaje del juego al descubrir (ERR_ZONE_EXPLORED[_XP]):
--              destello dorado, la experiencia ganada y, la primera vez en esa
--              zona, algo que Lya sabe de ella (AlfaLya.DatoDeZona).
--   ciudad     llegar a una ciudad o a una posada (descansas, IsResting).
--   mazmorra   al entrar: morado, sus niveles y jefes (de los datos de la
--              cuenta de Alfa_Mazmorras, sin cargar el Codex); una vez cada
--              30 min por instancia.
--   peligro    una zona de 4 niveles o más sobre el tuyo: rojo, «ve con cuidado».
-- Límites para que no canse: nada en grifo ni en combate; la misma zona o
-- rincón no antes de 10 min; entre dos rincones, 20 s; como mucho un anuncio
-- de zona cada 8 s (Kit: `espaciar`). Todo pasa por N.AlLibre (Momentos.lua):
-- espera la pantalla de carga, una cinemática...
-- El nombre del juego (ZoneTextFrame / SubZoneTextFrame): cuando Alfa va a
-- anunciar, el del juego se esconde (solo :Hide(); el juego lo vuelve a
-- mostrar en la siguiente zona, y si Alfa no anuncia, como cuando la zona se
-- repite o vas en grifo, sale el del juego): nunca salen dos.
--
--   N.Zonas.Probar(tipo)       un ejemplo de ese tipo (Ajustes)
--   N.Zonas.Zona() / .Subzona() -> o, clave    lo que diría ahora
--   N.Zonas.AlMensaje(texto)   un mensaje del juego (descubrir)
--   N.Zonas.Mazmorra()         al entrar a una instancia
--   N.Zonas.Olvidar()          (para el banco) olvida lo que ya anunció
--   N.GrupoAnuncios(padre)     el grupo de Ajustes: un interruptor y «Probar» por tipo
-- Ajustes: anuncios.<tipo> (Kit/Anuncio.lua), anuncios.subzonaChica, anuncios.sonido.

local _, N = ...
local A = N.A
local K = N.Kit
local L = K and K.L or N.Textos(N.EN)

local type, ipairs, pairs, pcall, tonumber, tostring, rawget, format = type, ipairs, pairs, pcall, tonumber, tostring, rawget, string.format
local concat = table.concat

local Z = {}
N.Zonas = Z

local REPETIR = 600        -- s: la misma zona o rincón
local ENTRE_RINCONES = 20  -- s entre dos anuncios de rincón (vas y vienes)
local TRAS_ZONA = 4        -- s: el rincón ya lo dijo la zona
local MAZMORRA_CADA = 1800 -- s por instancia
local PELIGRO = 4          -- niveles sobre el tuyo
Z.REPETIR, Z.ENTRE_RINCONES, Z.MAZMORRA_CADA = REPETIR, ENTRE_RINCONES, MAZMORRA_CADA

local function ahora() return GetTime and GetTime() or 0 end
local function reloj() return (GetServerTime and GetServerTime()) or (time and time()) or 0 end
local secreto = N.Secreto
local function texto(v)
	if type(v) ~= "string" or secreto(v) or v == "" then return nil end
	return v
end
local function llamar(fn, ...)
	if type(fn) ~= "function" then return nil end
	local r = { pcall(fn, ...) }
	if not r[1] then return nil end
	-- 1.3.7-fix: una función del juego que no devuelve nada (C_Map.
	-- GetBestMapForUnit en el tranvía o en un túnel: no hay mapa) devolvía
	-- CERO valores y quien la envolvía en tonumber() tronaba con
	-- «bad argument #1 to 'tonumber' (value expected)». Ahora siempre llega
	-- al menos un nil.
	if #r < 2 then return nil end
	return unpack(r, 2, #r)
end
local function datos()
	local d = N.DatosPersonaje("anuncios")
	if type(d.mazmorras) ~= "table" then d.mazmorras = {} end
	if type(d.lya) ~= "table" then d.lya = {} end
	return d
end

local vistos = {}             -- clave -> GetTime() de su anuncio
local ultimaZona, ultimoRincon = -math.huge, -math.huge
local vuelo = false           -- cambió la zona en grifo: se anuncia al aterrizar
function Z.Olvidar()
	vistos = {}
	ultimaZona, ultimoRincon = -math.huge, -math.huge
	vuelo = false
	if Z.OlvidarViaje then Z.OlvidarViaje() end
	local d = datos()
	d.mazmorras, d.lya, d.zonas = {}, {}, {}
end

local function enTaxi() return N.SiJuego(UnitOnTaxi, "player") end
local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end
local function descansando() return IsResting and IsResting() and true or false end
local function repetido(clave, cada)
	local t = vistos[clave]
	return t ~= nil and ahora() - t < (cada or REPETIR)
end

-- Lo de siempre antes de anunciar.
local function puede(tipo)
	if not (K and K.Anuncio and K.AnuncioPrendido and K.AnuncioPrendido(tipo)) then return false end
	if A.Hidden and A.Hidden() then return false end
	if enTaxi() then vuelo = true return false end
	if enCombate() then return false end
	return true
end

-- Al Kit, cuando Alfa esté libre (Momentos.lua). La caducidad cuenta desde ya.
local function lanzar(o, clave, prioridad)
	if clave then vistos[clave] = ahora() end
	local est = K.ESTILOS_ANUNCIO and K.ESTILOS_ANUNCIO[o.estilo] or {}
	if o.caduca == nil and est.caduca then o.caduca = ahora() + est.caduca end
	local fn = function() K.Anuncio(o) end
	local libre = rawget(N, "AlLibre")
	if type(libre) == "function" then
		local ok = pcall(libre, "anuncio." .. (o.clave or "zona"), fn, prioridad or 3, { tipo = "anuncio", caduca = est.caduca or 15,
			alCaducar = function() if K.AvisarPerdido then K.AvisarPerdido(o) end end }) -- (1.3.8 revisión)
		if ok then return end
	end
	fn()
end

---------------------------------------------------------------------------
-- El nombre que pone el juego
---------------------------------------------------------------------------
local ocultarHasta = setmetatable({}, { __mode = "k" })
local escondidos = setmetatable({}, { __mode = "k" }) -- marco -> cuándo lo escondió Alfa
local enganchados = setmetatable({}, { __mode = "k" })
local function marcoJuego(nombre)
	local g = rawget(_G, nombre)
	if type(g) == "table" and type(g.Hide) == "function" and type(g.IsShown) == "function" then return g end
	return nil
end
-- Esconde los del juego que están a la vista y los que salgan en los siguientes
-- `seg` s (2 de fábrica; 1.3.8: al saber que Alfa va a anunciar, desde ya).
local function ocultarJuego(nombres, seg)
	for _, n in ipairs(nombres) do
		local g = marcoJuego(n)
		if g then
			if not enganchados[g] and type(g.HookScript) == "function" then
				enganchados[g] = true
				pcall(g.HookScript, g, "OnShow", function(self)
					if ahora() <= (ocultarHasta[self] or 0) then self:Hide() escondidos[self] = ahora() end
				end)
			end
			ocultarHasta[g] = math.max(ocultarHasta[g] or 0, ahora() + (seg or 2))
			if g:IsShown() then g:Hide() escondidos[g] = ahora() end
		end
	end
end
Z.OcultarJuego = ocultarJuego

-- (1.3.8 revisión) El de Alfa no salió (falló, caducó o se calló): el del
-- juego ya no se esconde y, si se acaba de esconder, vuelve a salir.
local function devolverJuego(nombres)
	for _, n in ipairs(nombres) do
		local g = marcoJuego(n)
		if g then
			ocultarHasta[g] = 0
			local cuando = escondidos[g]
			escondidos[g] = nil
			local fs = rawget(_G, "FadingFrame_Show")
			if cuando and ahora() - cuando < 8 and not g:IsShown() and type(fs) == "function" then pcall(fs, g) end
		end
	end
end
Z.DevolverJuego = devolverJuego
local ZONA_JUEGO = { "ZoneTextFrame", "SubZoneTextFrame" }
local RINCON_JUEGO = { "SubZoneTextFrame" }

---------------------------------------------------------------------------
-- Lo que se sabe de la zona
---------------------------------------------------------------------------
local DUENO = {
	friendly = { color = "exito", sobre = "Tierra amiga" },
	hostile = { color = "peligro", sobre = "Tierra hostil" },
	contested = { color = "aviso", sobre = "Territorio en disputa" },
	sanctuary = { color = "pnj", sobre = "Santuario" },
	combat = { color = "peligro", sobre = "Zona de combate" },
	arena = { color = "peligro", sobre = "Todos contra todos" },
}
Z.DUENO = DUENO

function Z.Dueno()
	local fn = (C_PvP and C_PvP.GetZonePVPInfo) or rawget(_G, "GetZonePVPInfo")
	local tipo = llamar(fn)
	if type(tipo) == "string" and not secreto(tipo) then return tipo end
	return nil
end

-- La zona donde estás (su uiMapID de tipo zona: una cueva cuenta como su zona).
function Z.MapaZona()
	if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
	-- 1.3.7-fix: sin mapa (el tranvía, un túnel) no hay id: no se anuncia con
	-- niveles, pero tampoco se rompe nada.
	local mejor = N.Leer(llamar(C_Map.GetBestMapForUnit, "player"))
	local id = mejor ~= nil and tonumber(mejor) or nil
	local primero = id
	for _ = 1, 6 do
		if not id then break end
		local info = llamar(C_Map.GetMapInfo, id)
		if type(info) ~= "table" then break end
		local t = tonumber(info.mapType)
		if t == 3 then return id end
		if t and t < 3 then break end
		id = tonumber(info.parentMapID)
	end
	return primero
end

-- 1.3.9 (80): los rangos del anuncio, revisados zona por zona. Los del motor
-- (Maps/ZoneLevels.lua) salen de medir las criaturas y en varias zonas se
-- estiran de más (Mulgore 3–27, Los Baldíos 8–28, Claro de la Luna 23–60):
-- el anuncio usa los de siempre de cada zona. Las zonas nuevas de Forever
-- (Monte Hyjal, Isla Zephras, Riverglades) conservan las del motor, que son
-- las únicas medidas; un `false` es una zona sin rango (un santuario).
-- { de siempre, de siempre, lo que mide el motor, lo que mide el motor }
Z.NIVELES = {
	[1411] = { 1, 10, 1, 10 }, [1412] = { 1, 10, 3, 27 }, [1413] = { 10, 25, 8, 28 }, [1416] = { 30, 40, 24, 39 }, [1417] = { 30, 40, 31, 39 },
	[1418] = { 35, 45, 36, 43 }, [1419] = { 45, 55, 45, 54 }, [1420] = { 1, 10, 1, 10 }, [1421] = { 10, 20, 11, 19 }, [1422] = { 51, 58, 51, 57 },
	[1423] = { 53, 60, 54, 59 }, [1424] = { 20, 30, 21, 33 }, [1425] = { 40, 50, 42, 51 }, [1426] = { 1, 10, 2, 10 }, [1427] = { 43, 50, 45, 56 },
	[1428] = { 50, 58, 50, 56 }, [1429] = { 1, 10, 1, 10 }, [1430] = { 55, 60, 55, 60 }, [1431] = { 18, 30, 21, 39 }, [1432] = { 10, 20, 10, 18 },
	[1433] = { 15, 25, 16, 25 }, [1434] = { 30, 45, 32, 45 }, [1435] = { 35, 45, 36, 45 }, [1436] = { 10, 20, 10, 18 }, [1437] = { 20, 30, 21, 29 },
	[1438] = { 1, 10, 1, 10 }, [1439] = { 10, 20, 10, 20 }, [1440] = { 18, 30, 19, 41 }, [1441] = { 25, 35, 25, 34 }, [1442] = { 15, 27, 16, 26 },
	[1443] = { 30, 40, 31, 38 }, [1444] = { 40, 50, 41, 51 }, [1445] = { 35, 45, 36, 43 }, [1446] = { 40, 50, 42, 50 }, [1447] = { 45, 55, 47, 54 },
	[1448] = { 48, 55, 48, 54 }, [1449] = { 48, 55, 49, 54 }, [1450] = false, [1451] = { 55, 60, 55, 60 }, [1452] = { 53, 60, 54, 59 },
}
-- Quién es la zona cuando el juego no lo dice (las nuevas de Forever, o un
-- cliente que devuelve nada): el color y el sobretítulo de siempre.
Z.DUENO_ALFA = { [1450] = "sanctuary", [2482] = "contested", [2521] = "contested", [2548] = "contested" }
-- Las zonas nuevas de Forever (para revisarlas en el juego y en el banco).
Z.NUEVAS_FOREVER = { [2482] = "Mount Hyjal", [2521] = "Zephras Isle", [2548] = "Riverglades" }

function Z.Niveles(mapa)
	if not mapa then return nil end
	local fijo = Z.NIVELES[tonumber(mapa) or 0]
	if fijo == false then return nil end
	local Maps = A.Maps
	if Maps and type(Maps.GetZoneLevels) == "function" then
		local lo, hi = llamar(Maps.GetZoneLevels, mapa)
		lo, hi = tonumber(lo), tonumber(hi)
		if lo and hi then
			-- Lo medido por el motor se corrige con el rango de siempre (si el
			-- motor dice otra cosa, otra versión de sus datos, se le cree).
			if fijo and lo == fijo[3] and hi == fijo[4] then return fijo[1], fijo[2] end
			return lo, hi
		end
	end
	if fijo then return fijo[1], fijo[2] end
	if C_Map and C_Map.GetMapLevels then
		local lo, hi = llamar(C_Map.GetMapLevels, mapa)
		lo, hi = tonumber(lo), tonumber(hi)
		if lo and hi and lo > 0 and hi >= lo then return lo, hi end
	end
	return nil
end

local function rango(lo, hi) return lo == hi and tostring(lo) or (lo .. "\226\128\147" .. hi) end
-- 1.4.0: «Nivel 60» (no «Niveles 60») cuando el rango es de un solo nivel.
local function textoNiveles(lo, hi)
	if tonumber(lo) == tonumber(hi) then return format(L["Nivel %s"], tostring(lo)) end
	return format(L["Niveles %s"], rango(lo, hi))
end
Z.TextoNiveles = textoNiveles
local function miNivel() return tonumber(N.Leer(llamar(UnitLevel, "player"))) end
-- «Niveles 17–24» en el color de qué tan difícil es para ti (el del mapa del
-- juego, Maps.LevelColor); 1.4.0: también en las mazmorras.
local function nivelesColor(lo, hi)
	local t = textoNiveles(lo, hi)
	local nivel = miNivel()
	local Maps = A.Maps
	local tok = nivel and Maps and type(Maps.LevelColor) == "function" and llamar(Maps.LevelColor, lo, hi, nivel) or nil
	if type(tok) == "string" and tok ~= "textDim" and K and K.Hex then t = "|c" .. K.Hex(tok) .. t .. "|r" end
	return t
end
Z.NivelesColor = nivelesColor

-- 1.4.0 (77): cuánto descanso llevas, en % de un nivel («Descanso: 35 % de un nivel»).
local function lineaDescanso()
	local n = miNivel()
	if not n or n >= 60 then return nil end
	local exh = tonumber(N.Leer(llamar(rawget(_G, "GetXPExhaustion"))))
	local tope = tonumber(N.Leer(llamar(UnitXPMax, "player")))
	if not (exh and tope and tope > 0 and exh > 0) then return nil end
	return format(L["XP descansada: %d %% de un nivel"], math.min(150, math.floor(exh / tope * 100 + 0.5)))
end
Z.LineaDescanso = lineaDescanso

-- Lo que Lya cuenta en un anuncio: una frase corta (la entera queda en su diario).
local function corto(s, tope)
	tope = tope or 110
	if type(s) ~= "string" or #s <= tope then return s end
	local cut = s:sub(1, tope):match("^(.*)[%s,;]") or s:sub(1, tope)
	return cut .. "\226\128\166"
end
Z.Corto = corto

local function nombres()
	local zona = texto(llamar(GetRealZoneText)) or texto(llamar(GetZoneText))
	local sub = texto(llamar(GetSubZoneText))
	if sub == zona then sub = nil end
	return zona, sub
end

-- 1.3.7c: ¿es tu primera vez en esta zona? Nunca anunciada para este
-- personaje Y el juego no tiene explorado más de un rincón de ella (así un
-- personaje que ya anduvo ahí antes de esta versión no la ve como nueva).
-- Sin el dato de exploración, nunca es «primera vez».
function Z.PrimeraVez(mapa)
	mapa = tonumber(mapa)
	if not mapa then return false end
	local d = datos()
	if type(d.zonas) ~= "table" then d.zonas = {} end
	if d.zonas[mapa] then return false end
	local X = C_MapExplorationInfo
	if not (X and type(X.GetExploredMapTextures) == "function") then return false end
	local lista = llamar(X.GetExploredMapTextures, mapa)
	if type(lista) ~= "table" or secreto(lista) then return false end
	return #lista <= 1
end
-- Ya anunciada (no vuelve a ser «primera vez»).
function Z.Visitada(mapa)
	mapa = tonumber(mapa)
	if not mapa then return end
	local d = datos()
	if type(d.zonas) ~= "table" then d.zonas = {} end
	d.zonas[mapa] = true
end

-- 1.3.7c: cuántas misiones de tu registro van bajo el encabezado de esta zona.
function Z.MisionesDe(zona)
	local QL = C_QuestLog
	if type(zona) ~= "string" or not (QL and QL.GetNumQuestLogEntries and QL.GetInfo) then return 0 end
	local n = tonumber(N.Leer(llamar(QL.GetNumQuestLogEntries))) or 0
	local enZona, cuenta = false, 0
	for i = 1, n do
		local info = llamar(QL.GetInfo, i)
		if type(info) == "table" and not secreto(info) then
			local cab = N.Leer(info.isHeader)
			if cab then
				local t = texto(info.title)
				enZona = t == zona
			elseif enZona and not N.Si(info.isHidden) then
				cuenta = cuenta + 1
			end
		end
	end
	return cuenta
end

-- 1.3.8: el viaje en que llegaste. Nav/Alerts.lua avisa a bordo («¡Tierra a
-- la vista!») y lo anota aquí: la zona a la que llegas dice cómo llegaste.
--   Z.Llegando(kind, lugar, segundos)   Z.DeViaje() -> { kind, lugar, t } | nil
local SOBRE_LLEGADA = { boat = "La manada desembarca", zeppelin = "La manada baja del zepelín", tram = "La manada baja del tranvía" }
Z.SOBRE_LLEGADA = SOBRE_LLEGADA
local llegada
function Z.Llegando(kind, lugar, seg)
	if type(lugar) ~= "string" or secreto(lugar) then return end
	llegada = { kind = kind, lugar = lugar, t = ahora() + (tonumber(seg) or 0) }
end
function Z.DeViaje()
	if not llegada then return nil end
	local t = ahora()
	if t > llegada.t + 90 then llegada = nil return nil end
	if t < llegada.t - 40 then return nil end
	return llegada
end
function Z.OlvidarViaje() llegada = nil end

-- 1.3.8: la clave del suceso «zona peligrosa» (la misma para Rutas/Peligro.lua).
function Z.SucesoPeligro(zona)
	local n = N.Normalizar and N.Normalizar(zona) or zona
	return "peligro:" .. tostring(n or "?")
end

-- Lo que diría al llegar a la zona donde estás: o, clave.
function Z.Zona()
	local zona, sub = nombres()
	if not zona then return nil end
	local mapa = Z.MapaZona()
	local lo, hi = Z.Niveles(mapa)
	local d = DUENO[Z.Dueno() or Z.DUENO_ALFA[tonumber(mapa) or 0] or ""]
	local o = { estilo = "zona", clave = "zona", titulo = zona, color = d and d.color or nil,
		sobre = d and L[d.sobre] or L["Llegas a"] }
	local partes = {}
	if sub then partes[#partes + 1] = sub end
	local nivel = miNivel()
	if lo and hi then
		-- 1.3.9 (80): el rango en el color de qué tan difícil es para ti (el
		-- mismo que el mapa del juego: Maps.LevelColor).
		partes[#partes + 1] = nivelesColor(lo, hi)
	end
	if lo and hi and nivel and lo >= nivel + PELIGRO and K.AnuncioPrendido("peligro") then
		o.estilo, o.color, o.sobre = "peligro", "peligro", L["Zona peligrosa"]
		-- 1.4.0: tu nivel junto al de la zona (lo que el juego no dice).
		partes = { format(L["Zona de nivel %s y tú eres %d: ve con cuidado"], rango(lo, hi), nivel) }
		-- 1.3.8: un solo aviso de la zona peligrosa (el de Rutas se calla) y
		-- con su salida: la guía de tu nivel (Rutas la presta: N.SalidaPeligro).
		o.sucesoPeligro = Z.SucesoPeligro(zona)
		local salida = rawget(N, "SalidaPeligro")
		if type(salida) == "function" then
			o.alClic, o.pista = function() K.Llamar(salida) end, L["Clic: llévame a una zona de mi nivel"]
		end
	elseif descansando() and K.AnuncioPrendido("ciudad") then
		o.estilo, o.color, o.sobre = "ciudad", nil, L["Un lugar para descansar"]
		local dl = lineaDescanso()
		if dl then partes[#partes + 1] = dl end
	elseif Z.PrimeraVez(mapa) then
		-- 1.3.7c: tu primera vez en la zona (lo dice arriba, en su color).
		o.sobre, o.primera = L["¡Primera vez aquí!"], true
	end
	-- 1.3.8: llegaste en barco, zepelín o tranvía (el aviso de a bordo ya dijo
	-- el muelle): arriba, cómo llegaste; el muelle no se repite abajo.
	local v = Z.DeViaje()
	if v and o.estilo ~= "peligro" then
		o.sobre, o.viaje = L[SOBRE_LLEGADA[v.kind] or SOBRE_LLEGADA.boat], v.kind
		local nl = N.Normalizar and N.Normalizar(v.lugar)
		if sub and nl and N.Normalizar(sub) == nl and partes[1] == sub then table.remove(partes, 1) end
		if nl and N.Normalizar(zona) == nl then o.mismoMuelle = true end
	end
	o.texto = concat(partes, "  \194\183  ")
	-- 1.3.7c: cuántas misiones de tu registro son de esta zona.
	local n = Z.MisionesDe(zona)
	if n > 0 then
		local m = N.Plural(n, L["%d de tus misiones es de aquí"], L["%d de tus misiones son de aquí"])
		o.texto = o.texto ~= "" and (o.texto .. "\n" .. m) or m
	end
	return o, "z:" .. zona, sub
end

-- Lo que diría al pasar al rincón donde estás: o, clave.
function Z.Subzona()
	local zona, sub = nombres()
	if not (zona and sub) then return nil end
	local d = DUENO[Z.Dueno() or ""]
	local o = { estilo = "subzona", clave = "rincon", titulo = sub, sobre = zona, color = d and d.color or nil }
	-- 1.4.0: una línea útil y corta, solo si hay algo que decir: en una
	-- posada, el descanso que llevas; si no, tus misiones de esta zona (una
	-- vez cada 10 min por zona: no en cada rincón).
	if descansando() then
		o.color = "pnj"
		o.texto = lineaDescanso()
	else
		local n = Z.MisionesDe(zona)
		if n > 0 and not repetido("m:" .. zona) then
			o.texto = N.Plural(n, L["%d de tus misiones es de aquí"], L["%d de tus misiones son de aquí"])
			o.alMostrarMisiones = "m:" .. zona
		end
	end
	return o, "s:" .. zona .. ":" .. sub
end

---------------------------------------------------------------------------
-- Al llegar
---------------------------------------------------------------------------
local function enInstancia()
	local en, tipo = llamar(IsInInstance)
	return N.Si(en), N.Leer(tipo)
end

local function anunciarZona(como)
	-- (1.3.8 revisión) Si Alfa no anuncia, el nombre del juego ya no se esconde.
	if enInstancia() then devolverJuego(ZONA_JUEGO) return false end
	local o, clave, sub = Z.Zona()
	if not o or repetido(clave) or not puede("zona") then
		if o and o.sucesoPeligro and not repetido(clave) and N.OlvidarSuceso then N.OlvidarSuceso(o.sucesoPeligro) end
		devolverJuego(ZONA_JUEGO)
		return false
	end
	if o.sucesoPeligro and N.Suceso then N.Suceso(o.sucesoPeligro, 600) end -- (apartado hasta que salga o se pierda)
	-- 1.3.8: al aterrizar del grifo, arriba dice cómo llegaste.
	if como == "grifo" and o.estilo == "zona" and not o.primera and not o.viaje then o.sobre = L["Aterrizas en"] end
	-- (el nombre del juego ya se escondió al cambiar de zona; la espera se alarga)
	o.caduca = ahora() + 20
	ultimaZona = ahora()
	-- El rincón ya lo dijo la zona.
	if sub then vistos["s:" .. o.titulo .. ":" .. sub] = ahora() end
	-- 1.3.7: el nombre del juego se esconde cuando el de Alfa sale de verdad
	-- (si empieza una pelea o caduca en la fila, se queda el del juego).
	-- (1.3.8 revisión) El suceso de zona peligrosa se anota solo si el anuncio
	-- sale: si no, el aviso de Rutas sigue pudiendo decirlo.
	o.alMostrar = function()
		if o.sucesoPeligro and N.Suceso then N.Suceso(o.sucesoPeligro, 600) end
		ocultarJuego(ZONA_JUEGO)
	end
	o.alPerder = function()
		if o.sucesoPeligro and N.OlvidarSuceso then N.OlvidarSuceso(o.sucesoPeligro) end
		devolverJuego(ZONA_JUEGO)
	end
	o.tapaJuego = ZONA_JUEGO
	lanzar(o, clave, o.estilo == "peligro" and 2 or 3)
	Z.Visitada(Z.MapaZona()) -- 1.3.7c
	return true
end

function Z.AlCambiarZona()
	if enInstancia() then return Z.Mazmorra() end
	local o, clave = Z.Zona()
	if not o or repetido(clave) or not puede("zona") then return end
	-- 1.3.8: Alfa va a anunciar: el nombre del juego no sale ni un momento
	-- antes (si no, salían los dos, uno tras otro). Y si es peligrosa, el
	-- suceso queda apartado desde ya: el aviso de Rutas (2 s después) espera.
	-- (1.3.8 revisión: si el anuncio no sale, se olvida y Rutas lo dice.)
	ocultarJuego(ZONA_JUEGO, 6)
	if o.sucesoPeligro and N.Suceso then N.Suceso(o.sucesoPeligro, 600) end
	-- Un momento: el juego termina de decir dónde estás (el rincón, el dueño).
	N.Una("anuncios.zona", 0.6, anunciarZona)
end

local function anunciarRincon(claveAntes)
	if enInstancia() then return false end
	local o, clave = Z.Subzona()
	if not o or (claveAntes and clave ~= claveAntes) then return false end -- ya no estás ahí
	if repetido(clave) or not puede("subzona") then return false end
	local t = ahora()
	if t - ultimaZona < TRAS_ZONA or t - ultimoRincon < ENTRE_RINCONES then return false end
	ultimoRincon = t
	o.alMostrar = function()
		ocultarJuego(RINCON_JUEGO)
		if o.alMostrarMisiones then vistos[o.alMostrarMisiones] = ahora() end
	end
	o.tapaJuego = RINCON_JUEGO
	lanzar(o, clave, 4)
	return true
end

-- 1.3.7: con un nombre de Alfa a la vista, el rincón del juego no sale encima
-- (ni se va el de Alfa para que vuelva).
local TAPA_RINCON = { zona = true, subzona = true, ciudad = true, peligro = true }
local function taparRincon()
	local ac = K and K.AnuncioActual and K.AnuncioActual()
	if (ac and TAPA_RINCON[ac.estilo]) or ahora() - ultimaZona < TRAS_ZONA then ocultarJuego(RINCON_JUEGO) end
end
Z.TaparRincon = taparRincon

function Z.AlCambiarRincon()
	if enInstancia() then return end
	local o, clave = Z.Subzona()
	if not o or repetido(clave) or not puede("subzona") then taparRincon() return end
	local t = ahora()
	if t - ultimaZona < TRAS_ZONA or t - ultimoRincon < ENTRE_RINCONES then taparRincon() return end
	-- Cruzar una franja de un paso no cuenta: tiene que seguir ahí en 1 s.
	N.Una("anuncios.rincon", 1, function() anunciarRincon(clave) end)
end

-- Llegaste a una posada (o a la ciudad) y descansas.
local function descanso()
	if not descansando() or enInstancia() then return end
	-- Llegaste a la ciudad: ya lo dijo la zona.
	if ahora() - ultimaZona < TRAS_ZONA then return end
	local zona, sub = nombres()
	local nombre = sub or zona
	if not nombre then return end
	local clave = "c:" .. nombre
	if repetido(clave) or not puede("ciudad") then return end
	lanzar({ estilo = "ciudad", clave = "ciudad", titulo = nombre, sobre = L["Un lugar para descansar"],
		texto = lineaDescanso() or L["Descansas aquí: tu experiencia de descanso se llena."] }, clave, 3)
end
-- Un momento después: al llegar a una ciudad, el juego dice que descansas
-- antes de que salga el anuncio de la zona.
function Z.AlDescansar()
	if not descansando() then return end
	N.Una("anuncios.descanso", 1.5, descanso)
end

---------------------------------------------------------------------------
-- Descubrir
---------------------------------------------------------------------------
local patrones
local function hacerPatron(g)
	if type(g) ~= "string" or not g:find("%%s") then return nil end
	local p = g:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
	p = p:gsub("%%s", "(.-)"):gsub("%%d", "(%%d+)")
	return "^" .. p .. "$"
end
local function nombreDescubierto(msg)
	if type(msg) ~= "string" or secreto(msg) then return nil end
	if not patrones then
		patrones = {}
		for _, g in ipairs({ "ERR_ZONE_EXPLORED_XP", "ERR_ZONE_EXPLORED" }) do
			local p = hacerPatron(rawget(_G, g))
			if p then patrones[#patrones + 1] = p end
		end
	end
	for _, p in ipairs(patrones) do
		local nombre, xp = msg:match(p)
		if nombre and nombre ~= "" then return nombre, tonumber(xp) end
	end
	return nil
end

function Z.AlMensaje(msg)
	local nombre, xp = nombreDescubierto(msg)
	if not nombre then return false end
	-- El juego lo dice dos veces (el chat y el aviso de arriba): una sola.
	if repetido("d:" .. nombre, 5) then return true end
	vistos["d:" .. nombre] = ahora()
	if not puede("descubrir") then return true end
	-- El rincón nuevo ya no sale aparte.
	N.Quitar("anuncios.rincon")
	local zona = nombres()
	if zona then vistos["s:" .. zona .. ":" .. nombre] = ahora() end
	local partes = {}
	-- 1.4.0: la experiencia y de qué zona es (en una línea).
	if xp then partes[1] = format(L["+%d de experiencia"], xp) end
	if zona and zona ~= nombre then partes[1] = partes[1] and (partes[1] .. "  \194\183  " .. zona) or zona end
	-- La primera vez en esa zona, Lya cuenta algo de ella.
	local mapa = Z.MapaZona()
	local d = datos()
	if mapa and not d.lya[mapa] then
		local Lya = rawget(_G, "AlfaLya")
		local dato = type(Lya) == "table" and texto(llamar(Lya.DatoDeZona, mapa)) or nil
		if dato then
			d.lya[mapa] = true
			partes[#partes + 1] = format(L["Lya: «%s»"], corto(dato))
			-- 1.3.8: Lya no lo vuelve a contar en su globo al ratito.
			if N.Visto then N.Visto(dato, "anuncio") end
		end
	end
	local o = { estilo = "descubrir", clave = "descubrir", titulo = nombre, sobre = L["¡Descubriste un lugar nuevo!"],
		texto = concat(partes, "\n") }
	lanzar(o, nil, 2)
	return true
end

---------------------------------------------------------------------------
-- Mazmorras
---------------------------------------------------------------------------
-- Sus niveles y jefes, de los datos de la cuenta de Alfa_Mazmorras (el
-- minimapa los guarda sin el Codex).
function Z.InfoMazmorra(nombre)
	local db = rawget(_G, "AlfaNucleoDB")
	local mz = type(db) == "table" and rawget(db, "mazmorras")
	local e = type(mz) == "table" and mz.entradas
	if type(e) ~= "table" then return nil end
	for _, v in pairs(e) do
		if type(v) == "table" and v.nombre == nombre then return v end
	end
	return nil
end

function Z.Mazmorra(forzar)
	local en, tipo = enInstancia()
	if not en or (tipo ~= "party" and tipo ~= "raid") then return false end
	if not forzar and not puede("mazmorra") then return false end
	local nombre, _, _, _, _, _, _, id = llamar(GetInstanceInfo)
	nombre, id = texto(nombre), tonumber(N.Leer(id))
	if not nombre then return false end
	local marca = tostring(id or nombre)
	local d = datos()
	local t = reloj()
	if not forzar and tonumber(d.mazmorras[marca]) and t - d.mazmorras[marca] < MAZMORRA_CADA then return false end
	d.mazmorras[marca] = t
	for k, v in pairs(d.mazmorras) do if t - (tonumber(v) or 0) > 86400 then d.mazmorras[k] = nil end end
	local info = Z.InfoMazmorra(nombre)
	local partes = {}
	if info and tonumber(info.min) and tonumber(info.max) then partes[#partes + 1] = nivelesColor(tonumber(info.min), tonumber(info.max)) end
	local jefes = info and tonumber(info.jefes)
	if jefes and jefes > 0 then partes[#partes + 1] = N.Plural(jefes, L["%d jefe"], L["%d jefes"]) end
	-- 1.4.0 (77): la banda con su propio anuncio (corona, ámbar).
	lanzar({ estilo = tipo == "raid" and "banda" or "mazmorra", clave = "mazmorra", titulo = nombre, texto = concat(partes, "  \194\183  "),
		sobre = tipo == "raid" and L["Entras a una banda"] or L["Entras a una mazmorra"],
		alMostrar = function() ocultarJuego(ZONA_JUEGO) end, tapaJuego = ZONA_JUEGO }, nil, 2)
	return true
end

---------------------------------------------------------------------------
-- Los eventos
---------------------------------------------------------------------------
A.RegisterEvent("ZONE_CHANGED_NEW_AREA", function() Z.AlCambiarZona() end)
A.RegisterEvent("ZONE_CHANGED", function() Z.AlCambiarRincon() end)
A.RegisterEvent("ZONE_CHANGED_INDOORS", function() Z.AlCambiarRincon() end)
A.RegisterEvent("PLAYER_UPDATE_RESTING", function() Z.AlDescansar() end)
A.RegisterEvent("PLAYER_ENTERING_WORLD", function(_, login, recarga)
	-- Al entrar al juego (o con /reload) no: lo de dónde estás ya lo sabes.
	-- La zona queda como vista para no salir en cuanto termine la entrada.
	if login or recarga then
		local o, clave = Z.Zona()
		if clave then vistos[clave] = ahora() end
		local en = enInstancia()
		if en then
			local nombre, _, _, _, _, _, _, id = llamar(GetInstanceInfo)
			local marca = tostring(tonumber(N.Leer(id)) or texto(nombre) or "?")
			datos().mazmorras[marca] = reloj()
		end
		return
	end
	-- Una pantalla de carga (un portal, una mazmorra): como llegar.
	-- 1.3.8: si Alfa lo va a anunciar, el nombre del juego se esconde desde ya.
	if not enInstancia() then
		local o, clave = Z.Zona()
		if o and not repetido(clave) and puede("zona") then -- (1.3.8 revisión: lo de siempre, también combate)
			ocultarJuego(ZONA_JUEGO, 8)
		end
	end
	N.Una("anuncios.entrar", 1, function()
		if enInstancia() then Z.Mazmorra() else Z.AlCambiarZona() end
	end)
end)
-- Aterrizaste: la zona a la que llegaste en grifo.
A.RegisterEvent("PLAYER_CONTROL_GAINED", function()
	if not vuelo or enTaxi() then return end
	vuelo = false
	-- 1.3.8: el nombre del juego no sale encima del de Alfa al aterrizar.
	local o, clave = Z.Zona()
	if o and not repetido(clave) and puede("zona") then ocultarJuego(ZONA_JUEGO, 4) end
	N.Una("anuncios.zona", 1, function() anunciarZona("grifo") end)
end)
A.RegisterEvent("CHAT_MSG_SYSTEM", function(_, msg) Z.AlMensaje(msg) end)
A.RegisterEvent("UI_INFO_MESSAGE", function(_, _, msg) Z.AlMensaje(msg) end)

---------------------------------------------------------------------------
-- Probar (Ajustes)
---------------------------------------------------------------------------
local function ejemploMazmorra()
	local db = rawget(_G, "AlfaNucleoDB")
	local mz = type(db) == "table" and rawget(db, "mazmorras")
	local e = type(mz) == "table" and mz.entradas
	if type(e) == "table" then
		for _, v in pairs(e) do
			if type(v) == "table" and texto(v.nombre) then return v end
		end
	end
	return nil
end

function Z.Probar(tipo)
	if not (K and K.Anuncio) then return false end
	K.QuitarAnuncio()
	local zona, sub = nombres()
	zona = zona or L["Llegas a"]
	if tipo == "barco" or tipo == "zepelin" or tipo == "tranvia" then
		local Al = A.Nav and A.Nav.alerts
		local kind = tipo == "barco" and "boat" or tipo == "zepelin" and "zeppelin" or "tram"
		if Al and Al.ShowSample then Al.ShowSample(kind, tipo ~= "barco" and zona or nil) return true end
		return false
	end
	local o
	if tipo == "zona" or tipo == "peligro" or tipo == "ciudad" then
		o = Z.Zona() or { titulo = zona, sobre = L["Llegas a"] }
		o.estilo = tipo
		if tipo == "peligro" then
			o.color, o.sobre = "peligro", L["Zona peligrosa"]
			o.texto = format(L["Zona de nivel %s y tú eres %d: ve con cuidado"], rango((miNivel() or 20) + 5, (miNivel() or 20) + 12), miNivel() or 20)
		elseif tipo == "ciudad" then
			o.color, o.sobre = nil, L["Un lugar para descansar"]
			o.texto = lineaDescanso() or L["Descansas aquí: tu experiencia de descanso se llena."]
		end
	elseif tipo == "subzona" then
		o = Z.Subzona() or { estilo = "subzona", titulo = zona, sobre = zona }
	elseif tipo == "descubrir" then
		local partes = { format(L["+%d de experiencia"], 120) }
		local Lya = rawget(_G, "AlfaLya")
		local dato = type(Lya) == "table" and texto(llamar(Lya.DatoDeZona, Z.MapaZona())) or nil
		if dato then partes[2] = format(L["Lya: «%s»"], dato) end
		o = { estilo = "descubrir", titulo = sub or zona, sobre = L["¡Descubriste un lugar nuevo!"], texto = concat(partes, "\n") }
	elseif tipo == "mazmorra" then
		local v = ejemploMazmorra()
		local partes = {}
		if v and tonumber(v.min) and tonumber(v.max) then partes[1] = textoNiveles(v.min, v.max) end
		if v and tonumber(v.jefes) and v.jefes > 0 then partes[#partes + 1] = N.Plural(v.jefes, L["%d jefe"], L["%d jefes"]) end
		o = { estilo = "mazmorra", titulo = v and v.nombre or L["Mazmorra de prueba"], sobre = L["Entras a una mazmorra"],
			texto = concat(partes, "  \194\183  ") }
	elseif tipo == "banda" then
		o = { estilo = "banda", titulo = L["Núcleo de Magma"], sobre = L["Entras a una banda"],
			texto = textoNiveles(60, 60) .. "  \194\183  " .. N.Plural(10, L["%d jefe"], L["%d jefes"]) }
	elseif tipo == "nivel" then
		o = { estilo = "nivel", titulo = L["¡Nivel 60!"], sobre = L["La manada aúlla"],
			texto = L["Llegaste a la cima, alfa. Lya está orgullosa de ti."] }
	elseif tipo == "raro" then
		o = { estilo = "raro", titulo = "Mor'Ladim", sobre = L["Lya olfateó un raro"], texto = zona }
	elseif tipo == "tesoro" then
		o = { estilo = "tesoro", titulo = L["Un cofre escondido"], sobre = L["Lya encontró un tesoro"], texto = zona }
	elseif tipo == "manada" then
		o = { estilo = "manada", titulo = UnitName and llamar(UnitName, "player") or "La Jauría", sobre = L["La manada anda cerca"] }
	else
		o = { estilo = tipo, titulo = zona }
	end
	o.ya, o.caduca, o.clave, o.espaciar = true, nil, "probar", false
	return K.Anuncio(o)
end
-- 1.4.0: un anuncio de muestra (la bienvenida de la 1.4.0: «Pruébalo»).
K.ProbarAnuncio = function(tipo) return Z.Probar(type(tipo) == "string" and tipo or "zona") end

---------------------------------------------------------------------------
-- Ajustes: un interruptor y «Probar» por tipo (página Estilo y sonido)
---------------------------------------------------------------------------
local FILAS = {
	{ "zona", "Alfa anuncia las zonas", "Al llegar a una zona, su nombre en grande con el color de quién es y sus niveles, y el del juego se esconde para que no salgan dos. Nunca en grifo ni en combate." },
	{ "subzona", "Los rincones de cada zona", "Al pasar a un pueblo, una mina o un lago, su nombre. Cada uno una vez cada 10 minutos." },
	{ "subzonaChica", "Rincones en chico", "Que el de los rincones salga pequeño y sin el lobo.", hija = true, sinProbar = true },
	{ "descubrir", "Lugares que descubres", "La primera vez que pisas un lugar: un destello dorado, la experiencia que ganaste y algo que Lya sabe de esa zona." },
	{ "ciudad", "Ciudades y posadas", "Al llegar a donde descansas, un anuncio azul y tranquilo." },
	{ "mazmorra", "Mazmorras y bandas", "Al entrar, su nombre con sus niveles y sus jefes: morado en las mazmorras y ámbar con corona en las bandas. Una vez cada 30 minutos." },
	{ "peligro", "Zonas peligrosas", "Si la zona es de más nivel que tú, un aviso en rojo para que vayas con cuidado." },
	{ "barco", "Barcos", "Cuando tu barco está por llegar al muelle." },
	{ "zepelin", "Zepelines", "Cuando tu zepelín está por llegar." },
	{ "tranvia", "Tranvía", "Cuando el tranvía subterráneo está por llegar." },
	{ "raro", "Raros", "Cuando Lya olfatea un raro. En plena pelea, un ícono chico y el anuncio después." },
	{ "tesoro", "Tesoros", "Cuando Lya encuentra un tesoro." },
	{ "manada", "La manada", "Cuando el alfa de La Jauría anda cerca." },
	-- 1.4.0: el fondo detrás del nombre (Kit/Anuncio.lua, anuncios.fondo).
	{ "fondo", "Fondo de los anuncios", "Cómo se ve detrás del nombre: una placa de esquinas cortadas, una cinta de pendón, ornamentos finos a los lados, una sombra suave o nada más el texto con contorno.",
		opciones = { { valor = "placa", texto = "Placa" }, { valor = "cinta", texto = "Cinta" }, { valor = "filigrana", texto = "Filigrana" },
			{ valor = "suave", texto = "Sombra suave" }, { valor = "nada", texto = "Sin fondo" } } },
	{ "sonido", "Sonido de los anuncios", "Cada tipo con el suyo: el mapa al llegar, el destello al descubrir, el aviso de peligro.", sinProbar = true },
}
Z.FILAS = FILAS

local function control(fila, fl)
	local clave = "anuncios." .. fl[1]
	if fl.opciones then
		-- Elegir entre varias (el fondo): al cambiar, un anuncio de muestra.
		local ops = {}
		for i, op in ipairs(fl.opciones) do ops[i] = { valor = op.valor, texto = L[op.texto] } end
		local seg = K.Segmentos(fila, { estilo = "pildoras", opciones = ops, valor = A.Get(clave),
			alCambiar = function(v) A.Set(clave, v) Z.Probar("zona") end })
		seg:Acomodar(300) -- (en dos renglones si no caben: nada se sale de la fila)
		function seg:Leer() self:SetValor(A.Get(clave)) end
		return seg
	end
	if fl.sinProbar then return K.Interruptor(fila, { clave = clave }) end
	local c = CreateFrame("Frame", nil, fila)
	c.I = K.Interruptor(c, { clave = clave })
	c.B = K.Boton(c, L["Probar"], function() Z.Probar(fl[1]) end, { tipo = "secundario" })
	c.I:ClearAllPoints()
	c.I:SetPoint("RIGHT", c, "RIGHT", 0, 0)
	c.B:ClearAllPoints()
	c.B:SetPoint("RIGHT", c.I, "LEFT", -8, 0)
	local wi, hi = K.num(c.I:GetWidth(), 36), K.num(c.I:GetHeight(), 20)
	local wb, hb = K.num(c.B:GetWidth(), 60), K.num(c.B:GetHeight(), 24)
	c:SetSize(wi + 8 + wb, math.max(hi, hb))
	function c:Leer() if self.I.Leer then self.I:Leer() end end
	function c:SetActivo(on)
		if self.I.SetActivo then self.I:SetActivo(on) end
		if self.B.SetActivo then self.B:SetActivo(on) elseif self.B.Enable and self.B.Disable then if on then self.B:Enable() else self.B:Disable() end end
	end
	return c
end

function N.GrupoAnuncios(padre)
	local g = K.GrupoAjustes(padre, { titulo = L["Anuncios"] })
	local function grandes() return not (A.Get and A.Get("bienvenida.anuncios") == false) end
	for _, fl in ipairs(FILAS) do
		g:Fila({ titulo = L[fl[2]], texto = L[fl[3]], hija = fl.hija, activa = grandes,
			control = function(fila) return control(fila, fl) end })
	end
	return g
end
