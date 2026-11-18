-- Alfa - La Jauría: las insignias de la manada. toxic3000 / La Jauría. GPL-3.0.
--
-- Una chapita discreta junto al nombre de ciertas personas de La Jauría (no
-- de todos los que usan Alfa). Es solo visual: no da permisos ni cambia nada
-- del juego. Dos rangos:
--   "alfa"     los Alfas: los líderes y los más queridos de la manada
--              (el lobo en oro, "Alfa de La Jauría")
--   "jauria"   los miembros de La Jauría (el lobo en verde, "De La Jauría")
--
-- Dónde se ve:
--   * en el cuadro de un jugador (al pasar el ratón o al tenerlo de objetivo):
--     una línea con el lobo y su rango;
--   * en la página de La Jauría: el lobo junto a su nombre;
--   * en el mapa (Mapa.lua): un aro del color de su rango en su marca.
--
-- La lista (I.LISTA, abajo) la lleva Toxic a mano, con permiso de cada
-- persona para salir en ella. Una línea por personaje:
--
--     ["Nombre Apellido-Reino"] = "alfa",
--     ["Nombre-Reino"] = "jauria",
--
-- Cómo se compara un nombre de la lista con el de un jugador:
--   * Sin importar mayúsculas ni acentos: "Rocío" = "ROCIO", "Ñandú" = "nandu".
--   * El reino va después del último guion y se compara sin espacios,
--     guiones, puntos ni apóstrofos ("Zul'jin" = "zuljin"). Es el reino como lo
--     da el juego (/dump GetRealmName()). Entre el nombre y el apellido va un
--     espacio (un guion también sirve si después va el reino: "Ana-Smith-Reino").
--   * Con reino (lo recomendado): cuenta solo en ese reino. A quien el juego
--     no le da reino se le toma como de tu reino, igual que hace el juego con
--     los de tu mismo reino. En Forever el cuadro de un jugador nunca trae el
--     reino (el segundo dato de UnitName es el apellido): ahí cuenta como de tu
--     reino. Los mensajes de quien comparte sí lo traen cuando es de otro.
--   * Sin reino pero con apellido ("Ana Smith"): cuenta en cualquier reino.
--     Con nombre y apellido casi no hay dos iguales, y la insignia solo se ve.
--   * Un nombre solo, sin apellido ni reino ("Ana"), no cuenta: hay muchas
--     "Ana" en cada reino y la insignia le saldría a quien no es.
--   * Un rango que no sea "alfa" ni "jauria" no cuenta. Si alguien sale dos
--     veces, gana "alfa".
--
--   I.De(nombre)       "alfa" | "jauria" | nil
--   I.DeFila(fila)     lo mismo para una fila de Gente.lua (su nombre completo)
--   I.DeUnidad(unit)   lo mismo para una unidad del juego (solo jugadores)
--   I.Estilo(tipo)     { texto, icono, color = { r, g, b } } o nil
--   I.Icono(tipo)      el lobo dentro de un texto (|T...|t), del alto de la letra
--   I.Linea(tipo)      texto, r, g, b: la línea del cuadro
--   I.Rehacer()        vuelve a leer I.LISTA (si se cambia con el juego abierto)
--
-- El cuadro del jugador: por el gancho de unidades del motor (Alfa.Hooks.
-- UnitLines, que usa TooltipDataProcessor.AddTooltipPostCall de unidades o,
-- sin él, OnTooltipSetUnit). Solo agrega una línea (AddLine): nada protegido.
-- Lo secreto (combate en mazmorras) se toma como desconocido y no agrega
-- nada. Con la lista vacía no se engancha nada.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local U, L = M.U, M.L

local I = {}
M.Insignias = I

local type, pairs, ipairs, pcall, tonumber, floor = type, pairs, ipairs, pcall, tonumber, math.floor

---------------------------------------------------------------------------
-- La lista (la lleva Toxic). Quita los dos guiones del principio de una
-- línea para que cuente. Guarda el archivo en UTF-8.
---------------------------------------------------------------------------

I.LISTA = {
	-- Los Alfas: los líderes y los más queridos de la manada.
	-- Toxic, el creador de Alfa (1.2.0). Su carpeta del juego es
	-- "Toxic-Darunia": van las dos formas, por si Darunia es su apellido o
	-- su reino (la que no corresponda no le sale a nadie más).
	["Toxic Darunia"] = "alfa",
	["Toxic-Darunia"] = "alfa",

	-- La Jauría: los miembros.
	-- ["Ana Smith-Darunia"] = "jauria",
	-- ["Ana Smith"] = "jauria",          -- sin reino: en cualquier reino
}

---------------------------------------------------------------------------
-- Cómo se ve cada rango
---------------------------------------------------------------------------

-- Colores fijos de la marca (no el acento elegido): la insignia se reconoce
-- igual en cualquier apariencia.
local ORO = { 0.949, 0.816, 0.42 }     -- #f2d06b
local VERDE = { 0.545, 0.878, 0.306 }  -- #8be04e, el verde de Alfa
I.VERDE = VERDE

local ESTILOS = {
	alfa = { texto = "Alfa de La Jauría", icono = "ic-lobo", color = ORO },
	jauria = { texto = "De La Jauría", icono = "ic-lobo", color = VERDE },
}

local function media(nombre)
	local T = A.Theme
	local ok, p = pcall(T.Media, nombre)
	if ok and type(p) == "string" then return p end
	return "Interface\\AddOns\\Alfa\\Media\\UI\\" .. nombre
end

function I.Estilo(tipo)
	local e = ESTILOS[tipo]
	if not e then return nil end
	return { texto = L[e.texto], icono = media(e.icono), color = { e.color[1], e.color[2], e.color[3] } }
end

-- r, g, b del rango (o nil).
function I.Color(tipo)
	local e = ESTILOS[tipo]
	if not e then return nil end
	return e.color[1], e.color[2], e.color[3]
end

local function b255(v) return floor(v * 255 + 0.5) end

-- El lobo teñido del color del rango, dentro de un texto. Alto 0: el de la letra.
function I.Icono(tipo, alto)
	local e = ESTILOS[tipo]
	if not e then return "" end
	alto = tonumber(alto) or 0
	local c = e.color
	return ("|T%s:%d:%d:0:0:32:32:0:32:0:32:%d:%d:%d|t"):format(media(e.icono), alto, alto, b255(c[1]), b255(c[2]), b255(c[3]))
end

-- La línea del cuadro: el lobo y el rango, en su color.
function I.Linea(tipo)
	local e = ESTILOS[tipo]
	if not e then return nil end
	return I.Icono(tipo) .. " " .. L[e.texto], e.color[1], e.color[2], e.color[3]
end

-- Agrega la línea a un cuadro; true si la puso.
function I.AgregarLinea(tooltip, tipo)
	local texto, r, g, b = I.Linea(tipo)
	if not (texto and tooltip and tooltip.AddLine) then return false end
	tooltip:AddLine(texto, r, g, b)
	return true
end

---------------------------------------------------------------------------
-- Comparar nombres
---------------------------------------------------------------------------

-- Las letras con acento del latín (U+00C0 a U+00FF) a su letra base.
local BASE = { "a", "a", "a", "a", "a", "a", "ae", "c", "e", "e", "e", "e", "i", "i", "i", "i",
	"d", "n", "o", "o", "o", "o", "o", false, "o", "u", "u", "u", "u", "y", "th", "ss" }
local PLIEGUE = {}
for i, b in ipairs(BASE) do
	if b then
		PLIEGUE["\195" .. string.char(127 + i)] = b
		if i < 32 then PLIEGUE["\195" .. string.char(159 + i)] = b end
	end
end
PLIEGUE["\195\191"] = "y" -- ÿ

-- Sin acentos y en minúsculas.
local function plegar(s)
	s = s:gsub("\195[\128-\191]", PLIEGUE)
	return (s:lower())
end
I.Plegar = plegar

local function limpiarReino(r)
	r = r:gsub("[%s%-'%.]", "")
	return r ~= "" and r or nil
end

-- "Ana Smith-Reino" -> "ana smith", "reino"; "Ana Smith" -> "ana smith", nil.
local function partir(nombre)
	local s = plegar(nombre)
	local base, reino = s:match("^(.-)%-([^%-]*)$")
	if not base then base = s end
	base = base:gsub("[%s%-_]+", " "):gsub("^ ", ""):gsub(" $", "")
	if base == "" then return nil end
	return base, reino and limpiarReino(reino) or nil
end
I.Partir = partir

-- Tu reino, como lo da el juego (con y sin espacios: los dos cuentan).
local misReinos
local function reinosPropios()
	if misReinos then return misReinos end
	local t, hay = {}, false
	for _, fn in ipairs({ GetRealmName or false, GetNormalizedRealmName or false }) do
		if fn then
			local ok, v = pcall(fn)
			v = ok and U.Texto(v) or nil
			local r = v and limpiarReino(plegar(v))
			if r then
				t[r] = true
				hay = true
			end
		end
	end
	-- Se recuerda solo cuando el juego ya lo dio.
	if hay then misReinos = t end
	return t, hay
end

local conReino, sinReino = {}, {} -- "ana smith-reino" -> tipo ; "ana smith" -> tipo
local hayAlguien = false
local cache, enCache = {}, 0
local CACHE_MAX = 400

local function mejor(a, b)
	if a == "alfa" or b == "alfa" then return "alfa" end
	return a or b
end

local instalar -- abajo: el gancho del cuadro

function I.Rehacer()
	wipe(conReino)
	wipe(sinReino)
	wipe(cache)
	enCache = 0
	hayAlguien = false
	for nombre, tipo in pairs(I.LISTA) do
		local t = type(tipo) == "string" and (plegar(tipo):gsub("%s", "")) or nil
		if type(nombre) == "string" and (t == "alfa" or t == "jauria") then
			local base, reino = partir(nombre)
			if base and reino then
				local k = base .. "-" .. reino
				conReino[k] = mejor(conReino[k], t)
				hayAlguien = true
			elseif base and base:find(" ", 1, true) then
				sinReino[base] = mejor(sinReino[base], t)
				hayAlguien = true
			end
		end
	end
	if hayAlguien then instalar() end
	-- El mapa y la página se rehacen (al cargar todavía no existen).
	local G = M.Gente
	if G and G.Cambio then G.Cambio() end
	if M.Avisar then M.Avisar() end
end

local function buscar(nombre)
	local base, reino = partir(nombre)
	if not base then return nil end
	if reino then
		local t = conReino[base .. "-" .. reino]
		if t then return t end
	end
	-- Sin reino (o con el tuyo): como de tu reino.
	local propios = reinosPropios()
	if not reino or propios[reino] then
		for r in pairs(propios) do
			local t = conReino[base .. "-" .. r]
			if t then return t end
		end
	end
	return sinReino[base]
end

-- La insignia de un personaje ("Nombre Apellido", "Nombre-Reino"...) o nil.
function I.De(nombre)
	if not hayAlguien then return nil end
	nombre = U.Texto(nombre)
	if not nombre then return nil end
	local c = cache[nombre]
	if c ~= nil then return c or nil end
	local t = buscar(nombre) or false
	-- Se recuerda solo cuando ya se sabe tu reino (antes podría salir distinto).
	if misReinos then
		if enCache >= CACHE_MAX then
			wipe(cache)
			enCache = 0
		end
		cache[nombre] = t
		enCache = enCache + 1
	end
	return t or nil
end

-- Una fila de Gente.lua: el nombre como lo dio el juego (con su reino, si es
-- de otro); el nombre para mostrar ya no lo trae y podría confundir reinos.
function I.DeFila(f)
	if type(f) ~= "table" then return nil end
	return I.De(f.envio or f.nombre)
end

-- Una unidad del juego: solo jugadores.
function I.DeUnidad(unit)
	if not hayAlguien or type(unit) ~= "string" then return nil end
	if UnitIsPlayer then
		local ok, v = pcall(UnitIsPlayer, unit)
		if not (ok and U.Leer(v)) then return nil end
	end
	local ok, full = pcall(A.Compat.UnitFullName, unit)
	if not ok then return nil end
	return I.De(full)
end

function I.Hay() return hayAlguien end

---------------------------------------------------------------------------
-- El cuadro del jugador
---------------------------------------------------------------------------

-- Lo que hace el gancho con el cuadro de una unidad; true si puso la línea.
function I.AlCuadro(tooltip, unit)
	local tipo = I.DeUnidad(unit)
	if not tipo then return false end
	return I.AgregarLinea(tooltip, tipo)
end

local function prohibido(tooltip)
	if not (tooltip and tooltip.IsForbidden) then return false end
	local ok, f = pcall(tooltip.IsForbidden, tooltip)
	if not ok or U.Secreto(f) then return true end
	return f and true or false
end

local function unidadDe(tooltip)
	if not tooltip.GetUnit then return nil end
	local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
	if not ok then return nil end
	return U.Texto(unit)
end

local instalado = false
instalar = function()
	if instalado then return end
	instalado = true
	-- Lo normal: el gancho de unidades del motor (el único dueño de los
	-- ganchos del cuadro en Alfa: no repite líneas y salta lo prohibido y lo
	-- secreto).
	local H = A.Hooks
	if H and type(H.UnitLines) == "function" then
		H.UnitLines(ADDON, function(tooltip, unit) I.AlCuadro(tooltip, unit) end)
		return
	end
	-- Sin él: el del juego directo, con las mismas precauciones.
	local P, T = TooltipDataProcessor, Enum and Enum.TooltipDataType
	if type(P) == "table" and type(P.AddTooltipPostCall) == "function" and T and T.Unit then
		P.AddTooltipPostCall(T.Unit, function(tooltip)
			if tooltip ~= GameTooltip or prohibido(tooltip) then return end
			pcall(I.AlCuadro, tooltip, unidadDe(tooltip))
		end)
	elseif GameTooltip and GameTooltip.HookScript then
		GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
			if prohibido(tooltip) then return end
			local ok, puso = pcall(I.AlCuadro, tooltip, unidadDe(tooltip))
			-- Este aviso llega antes de que el cuadro tome su tamaño.
			if ok and puso then tooltip:Show() end
		end)
	end
end

I.Rehacer()
