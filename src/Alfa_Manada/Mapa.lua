-- Alfa - La Jauría: la manada en el mapa del mundo y el minimapa.
-- toxic3000 / La Jauría. GPL-3.0.
--
-- Dos capas de pines del motor (Alfa.Pins.SetLayer):
--   manada.grupo    tu grupo o banda (posiciones del juego)
--   manada.jauria   los usuarios de Alfa que comparten su ubicación contigo
-- Cada pin es una marca de mapa de Alfa (el medallón de la casa) con el
-- alfiler del color de la clase y el nombre en su etiqueta. El cuadro al
-- pasar el ratón dice nombre, nivel, clase, zona, distancia y hace cuánto se
-- supo; un clic lo sigue (Seguir.lua). Una posición de más de un minuto se
-- dibuja tenue. A quien sigues se le ve más grande, con el aro de Alfa y un
-- halo.
-- Con Alfa_Mundo, las dos capas se registran en su control de capas
-- (AlfaMundo.RegistrarCapa); apagar una allí apaga el ajuste aquí y al revés.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local U = M.U
local L = M.L
local ID = M.ID

local Mapa = {}
M.Mapa = Mapa

-- icono: el de la capa en el control de Alfa_Mundo.
local CAPAS = {
	grupo = { id = "manada.grupo", ajuste = "capaGrupo", nombre = "Tu grupo", icono = "ic-personajes" },
	manada = { id = "manada.jauria", ajuste = "capaJauria", nombre = "La Jauría", icono = "ic-manada" },
}
local ORDEN = { "grupo", "manada" }
Mapa.CAPAS, Mapa.ORDEN = CAPAS, ORDEN

local function themeRGB(nombre)
	local T = A.Theme
	local ok, r, g, b
	if nombre == "accent" then ok, r, g, b = pcall(T.Accent) else ok, r, g, b = pcall(T.Color, nombre) end
	if ok and type(r) == "number" then return r, g, b end
	return 0.545, 0.878, 0.306
end

-- El nombre corto para la etiqueta del pin: el nombre sin el apellido, como
-- mucho 12 letras.
local function corto(nombre)
	local n = U.Texto(nombre) or "?"
	n = n:match("^(%S+)") or n
	local out, letras = {}, 0
	for c in n:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		letras = letras + 1
		if letras > 12 then break end
		out[letras] = c
	end
	return table.concat(out)
end
Mapa.Corto = corto

local function media(nombre)
	local T = A.Theme
	local ok, p = pcall(T.Media, nombre)
	if ok and type(p) == "string" then return p end
	return "Interface\\AddOns\\Alfa\\Media\\UI\\" .. nombre
end

---------------------------------------------------------------------------
-- El cuadro del pin
---------------------------------------------------------------------------

local function lineaNivel(f)
	local partes = {}
	if f.nivel then partes[#partes + 1] = L["Nivel %d"]:format(f.nivel) end
	local clase = U.NombreClase(f.clase)
	if clase then partes[#partes + 1] = clase end
	return #partes > 0 and table.concat(partes, " · ") or nil
end
Mapa.LineaNivel = lineaNivel

local function cuadro(f, capa)
	return function(tip)
		local G = M.Gente
		local r, g, b = U.ColorTexto(f.clase)
		tip:SetText(f.nombre or "?", r, g, b)
		local nivel = lineaNivel(f)
		if nivel then tip:AddLine(nivel, 1, 1, 1) end
		local map, x, y, edad = G.PosicionDe(f)
		if map then
			local zona = U.NombreMapa(U.ZonaDe(map))
			local yd, otro = U.Distancia(map, x, y)
			local lugar = zona or ""
			if yd then
				lugar = lugar .. "  ·  " .. U.TextoDistancia(yd)
			elseif otro then
				lugar = lugar .. "  ·  " .. L["otro continente"]
			end
			if lugar ~= "" then tip:AddLine(lugar, 0.8, 0.8, 0.8) end
			if capa ~= "grupo" and edad and edad >= 20 then tip:AddLine(L["Ubicación de %s"]:format(U.Hace(edad)), 0.6, 0.6, 0.6) end
		end
		local ar, ag, ab = themeRGB("accent")
		tip:AddLine(capa == "grupo" and L["Tu grupo"] or L["La Jauría"], ar, ag, ab)
		if M.Seguir.Sigue(f.clave) then
			tip:AddLine(L["Lo estás siguiendo."], themeRGB("success"))
		else
			tip:AddLine(L["Clic: seguir con la flecha"], themeRGB("success"))
		end
	end
end

---------------------------------------------------------------------------
-- Las capas
---------------------------------------------------------------------------

local function capaActiva(capa) return N.Get(ID, CAPAS[capa].ajuste) and true or false end

local hecho = -1     -- G.version dibujada
local sigHecho       -- a quién se seguía al dibujar
local ultimoDibujo = -math.huge

-- Rehace los pines si algo cambió (o con `forzar`).
function Mapa.Refrescar(forzar)
	local P = A.Pins
	if not (P and P.SetLayer) then return end
	local G = M.Gente
	local sigue = M.Seguir.Actual()
	local ahora = U.Ahora()
	-- Las posiciones envejecen solas: se redibuja al menos cada 20 s.
	if not forzar and hecho == G.version and sigHecho == (sigue and sigue.clave) and ahora - ultimoDibujo < 20 then return end
	hecho, sigHecho, ultimoDibujo = G.version, sigue and sigue.clave, ahora
	local porCapa = { grupo = {}, manada = {} }
	for _, p in ipairs(G.ParaElMapa()) do
		local f, capa = p.fila, p.capa
		local r, g, b = U.ColorClase(f.clase)
		local alfa = (capa ~= "grupo" and f.edad and f.edad > G.VIEJA) and 0.55 or 1
		local seguido = sigue and sigue.clave == f.clave
		local lista = porCapa[capa]
		lista[#lista + 1] = {
			map = f.map, x = f.x, y = f.y,
			icon = "map:pin-small",
			color = { r, g, b, alfa },
			badge = corto(f.nombre),
			state = seguido and "focus" or nil,
			size = 15, minimapSize = 13,
			glow = seguido or nil,
			priority = seguido and 10 or 2,
			tooltip = cuadro(f, capa),
			onClick = function(button)
				if button == "LeftButton" or button == nil then M.Seguir.A(f) end
			end,
		}
	end
	local mini = N.Get(ID, "minimapa") and true or false
	for _, capa in ipairs(ORDEN) do
		local c = CAPAS[capa]
		-- Solo se rehace la capa que cambió (el mapa abierto no parpadea).
		local firma = { mini and "m" or "-" }
		for i, pin in ipairs(porCapa[capa]) do
			firma[i + 1] = ("%s%d:%.1f:%.1f:%s:%s"):format(pin.badge, pin.map, pin.x, pin.y, pin.color[4], pin.glow and "g" or "")
		end
		firma = table.concat(firma, "|")
		if forzar or c.firma ~= firma then
			c.firma = firma
			pcall(P.SetLayer, c.id, porCapa[capa], { world = true, minimap = mini, edge = false })
		end
		pcall(P.SetLayerVisible, c.id, capaActiva(capa))
	end
end

-- Un ajuste de capa cambió: se ve o se esconde ya.
function Mapa.AlCambiarAjustes()
	local P = A.Pins
	if P and P.SetLayerVisible then
		for _, capa in ipairs(ORDEN) do pcall(P.SetLayerVisible, CAPAS[capa].id, capaActiva(capa)) end
	end
	Mapa.Refrescar(true)
	Mapa.AvisarMundo()
end

---------------------------------------------------------------------------
-- Alfa_Mundo: un solo control de capas para todo el mapa
---------------------------------------------------------------------------

local function mundo()
	local AM = _G and rawget(_G, "AlfaMundo")
	return type(AM) == "table" and AM or nil
end

local registradas = false
function Mapa.RegistrarEnMundo()
	if registradas then return true end
	local AM = mundo()
	if not (AM and type(AM.RegistrarCapa) == "function") then return false end
	registradas = true
	for _, capa in ipairs(ORDEN) do
		local c = CAPAS[capa]
		pcall(AM.RegistrarCapa, {
			id = c.id, grupo = L["La Jauría"], nombre = L[c.nombre], icono = media(c.icono),
			activa = capaActiva(capa),
			alCambiar = function(activa)
				if (N.Get(ID, c.ajuste) and true or false) ~= (activa and true or false) then
					N.Set(ID, c.ajuste, activa and true or false)
				end
			end,
		})
	end
	return true
end

-- Cuando una capa cambia desde esta página, se le dice a Alfa_Mundo (si
-- ofrece cómo: AlfaMundo.ActivarCapa(id, activa)).
function Mapa.AvisarMundo()
	local AM = mundo()
	if not (registradas and AM and type(AM.ActivarCapa) == "function") then return end
	for _, capa in ipairs(ORDEN) do pcall(AM.ActivarCapa, CAPAS[capa].id, capaActiva(capa)) end
end

Mapa.RegistrarEnMundo()
