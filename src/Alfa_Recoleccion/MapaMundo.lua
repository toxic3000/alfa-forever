-- Alfa - Recolección: los nodos en el mapa continuo de Alfa_Mundo
-- (toxic3000 / La Jauría, GPL-3.0). 1.1.8.
--
-- Alfa_Mundo dibuja las capas de Alfa.Pins que tienen el id de una capa
-- registrada (recoleccion.<tipo>, Recoleccion.lua). Aquí se publican esos
-- pines, pero solo de las zonas que el mapa continuo muestra en este momento
-- (AlfaMundo.ZonasALaVista) y agrupados: los nodos de un mismo tipo que caen
-- en una celda de la zona son un solo punto del color de su tipo, con su
-- cantidad. Así el mapa no se llena de miles de pines ni le quita lugar a
-- las misiones. Con world = false y minimap = false: el mapa del juego y el
-- minimapa siguen con lo suyo (Mapa.lua y Minimapa.lua).

local _, M = ...
local N = AlfaNucleo
local A = N.A
local R = M.R
local L = N.Textos(M.EN)

local floor, max = math.floor, math.max
local ID = R.ID

local MM = {}
M.MapaMundo = MM

local CELDAS = 28        -- celdas por lado de cada zona para agrupar
local CADA = 0.75        -- segundos entre miradas al mapa abierto
local ZOOM = 4.5         -- desde qué zoom del mapa continuo se ven

local firmaHecha = {}    -- tipo -> la firma de lo publicado
local vacias = {}        -- tipo -> ya se publicó vacía

local function colorTipo(tipo)
	local t = M.TIPO and M.TIPO[tipo]
	local c = t and t.color
	if c then return { c[1], c[2], c[3], 1 } end
	return { 1, 1, 1, 1 }
end

-- El cuadro de un punto: qué hay y cuántos.
local function cuadro(pin)
	return function(tt)
		tt:SetText(R.NombreTipo(pin.tipo))
		for g, n in pairs(pin.cuenta) do
			local r, gg, b = 0.85, 0.85, 0.85
			if R.ColorNivel then r, gg, b = R.ColorNivel(g) end
			tt:AddLine(n > 1 and (R.Nombre(g) .. "  x" .. n) or R.Nombre(g), r, gg, b)
		end
		if pin.total > 1 then tt:AddLine(L["Varios puntos juntos: acércate en el mapa para verlos."], 0.6, 0.6, 0.6, true) end
	end
end

-- Los puntos de un tipo en las zonas a la vista: { pin, ... }, y su firma.
local function puntos(tipo, zonas)
	local lista, partes = {}, {}
	local color = colorTipo(tipo)
	for _, mapa in ipairs(zonas) do
		local idx = R.IndiceSiHay(mapa)
		if idx and idx.n > 0 then
			local celdas = {}
			for i = 1, idx.n do
				local g = idx.g[i]
				local gr = M.GRUPOS[g]
				if gr and gr.tipo == tipo and R.Muestra(idx, i) then
					local cx = floor(idx.x[i] * CELDAS)
					local cy = floor(idx.y[i] * CELDAS)
					local k = cx * CELDAS + cy
					local c = celdas[k]
					if not c then
						c = { sx = 0, sy = 0, total = 0, cuenta = {}, tenue = true }
						celdas[k] = c
					end
					c.sx, c.sy, c.total = c.sx + idx.x[i], c.sy + idx.y[i], c.total + 1
					c.cuenta[g] = (c.cuenta[g] or 0) + 1
					if R.Puede(g) then c.tenue = false end
				end
			end
			local n = 0
			for k, c in pairs(celdas) do
				n = n + 1
				local pin = {
					map = mapa, x = c.sx / c.total * 100, y = c.sy / c.total * 100,
					color = color, size = c.total > 1 and 13 or 11, priority = 1,
					badge = c.total > 1 and c.total or nil,
					state = c.tenue and "dim" or nil,
					tipo = tipo, total = c.total, cuenta = c.cuenta,
				}
				pin.tooltip = cuadro(pin)
				lista[#lista + 1] = pin
				partes[#partes + 1] = mapa .. ":" .. k .. ":" .. c.total
			end
			if n == 0 then partes[#partes + 1] = mapa .. ":-" end
		end
	end
	table.sort(partes)
	return lista, table.concat(partes, ",")
end

local function publicar(tipo, pines, firma)
	local P = A.Pins
	if not (P and P.SetLayer) then return end
	if firmaHecha[tipo] == firma then return end
	firmaHecha[tipo] = firma
	P.SetLayer("recoleccion." .. tipo, pines, { world = false, minimap = false })
end

-- Mira el mapa abierto y publica lo que cambió. Sin cambios en las zonas a
-- la vista (ni en los nodos o filtros: `forzar`), no recorre nada.
local claveHecha
function MM.Refrescar(forzar)
	if forzar then firmaHecha = {} end
	local API = AlfaMundo
	local zonas = type(API) == "table" and type(API.ZonasALaVista) == "function" and API.ZonasALaVista() or nil
	local encendido = N.Get(ID, "mapa") ~= false and not A.Hidden()
	local clave = "-"
	if zonas and encendido then
		local ordenadas = {}
		for i, z in ipairs(zonas) do ordenadas[i] = z end
		table.sort(ordenadas)
		clave = table.concat(ordenadas, ",")
	end
	if not forzar and clave == claveHecha then return end
	claveHecha = clave
	for _, tipo in ipairs(M.TIPOS) do
		if zonas and encendido and R.TipoActivo(tipo) then
			local pines, firma = puntos(tipo, zonas)
			publicar(tipo, pines, firma)
			vacias[tipo] = nil
		elseif not vacias[tipo] then
			-- Cerrado o apagado: la capa queda vacía una sola vez (nada que recorrer).
			publicar(tipo, {}, "")
			vacias[tipo] = true
		end
	end
end

-- 1.3.2: la mirada al mapa corre solo con el mapa de Alfa abierto
-- (ALFA_VENTANA del Kit); al cerrarlo, la capa queda vacía y el reloj se quita.
local MAPA = "AlfaMundoMapa"
local RELOJ = "recoleccion.mapaMundo"
local instalado = false
local function mapaAbierto()
	local f = rawget(_G, MAPA)
	return type(f) == "table" and f.IsShown and f:IsShown() and true or false
end
function MM.Vigilar()
	if not instalado then return end
	if mapaAbierto() then
		if not N.HayTarea(RELOJ) then N.Cada(RELOJ, CADA, function() MM.Refrescar(false) end) end
	else
		N.Quitar(RELOJ)
	end
	MM.Refrescar(false)
end

function MM.Instalar()
	if instalado or not (R.mundo and type(AlfaMundo) == "table" and type(AlfaMundo.ZonasALaVista) == "function") then return end
	instalado = true
	A.On("ALFA_VENTANA", function(nombre) if nombre == MAPA then MM.Vigilar() end end)
	MM.Vigilar()
	MM.Refrescar(true)
end

R.AlCambiar(function(que)
	if que == "nodos" or que == "filtros" then MM.Refrescar(true) end
end)

MM.ZOOM = ZOOM
