-- Alfa - Comercio: gangas en la subasta (1.3.7, toxic3000 / La Jauría). GPL-3.0.
--
-- Mientras miras la subasta (tus búsquedas o el escaneo de Alfa), señala lo
-- que está más barato de lo que suele valer en tu reino, o lo que deja
-- ganancia si lo desencantas tú o un personaje tuyo. Solo es un indicador:
-- Alfa nunca compra ni puja; la compra es del jugador.
--
--   * «cuesta menos de lo que vale»: el precio por unidad está por lo menos
--     un 30 % bajo el promedio de los días anteriores (el historial corto de
--     Precios.lua, hacen falta 2 días o más) y ahorras por lo menos 10p.
--   * «se desencanta con ganancia»: solo en tus búsquedas (el escaneo no pide
--     la información de miles de objetos); los materiales esperados valen un
--     15 % más que el precio y dejan por lo menos 5p.
-- Las gangas son de esta sesión (no se guardan): los precios cambian rápido.
--
-- Aparecen en el cuadro del objeto (con la subasta abierta) y en un botón de
-- la barra de Alfa bajo la subasta, que al pasar el ratón las enumera.

local _, M = ...
local N = AlfaNucleo
local K = N.Kit
local L = M.L

local type, floor, pairs, tonumber = type, math.floor, pairs, tonumber

local DIA = 86400
M.GANGA_BARATO = 0.30
M.GANGA_MIN_AHORRO = 1000 -- 10p
M.GANGA_DE = 0.15
M.GANGA_MIN_DE = 500 -- 5p
local TOPE = 30

local gangas = {} -- [itemID] = { id, precio, tipo = "barato" | "desencantar", normal, ganancia, t }

function M.GangasActivas() return M.Ajuste("gangas") ~= false end

-- Lo que suele valer: el promedio de los días anteriores a hoy (nil sin 2 días).
function M.ValorNormal(id, r, hoy)
	r = r or M.Reino()
	local s = type(r.h) == "table" and r.h[id] or nil
	if type(s) ~= "string" then return nil end
	hoy = hoy or floor(M.Ahora() / DIA)
	local suma, n = 0, 0
	for d, p in s:gmatch("(%d+):(%d+)") do
		d, p = tonumber(d), tonumber(p)
		if d < hoy and p > 0 then suma, n = suma + p, n + 1 end
	end
	if n < 2 then return nil end
	return suma / n
end

local function quitarVieja()
	local cuantas, vieja = 0, nil
	for id, g in pairs(gangas) do
		cuantas = cuantas + 1
		if not vieja or g.t < gangas[vieja].t then vieja = id end
	end
	if cuantas > TOPE and vieja then gangas[vieja] = nil end
end

-- ¿Es ganga este precio por unidad? -> ganga | nil (y la anota o la quita).
function M.RevisarGanga(id, precio, fuente, r)
	if type(id) ~= "number" or type(precio) ~= "number" or precio <= 0 then return nil end
	local g
	local normal = M.ValorNormal(id, r)
	if normal and precio <= normal * (1 - M.GANGA_BARATO) and normal - precio >= M.GANGA_MIN_AHORRO then
		g = { id = id, precio = precio, tipo = "barato", normal = normal, ganancia = floor(normal - precio) }
	elseif fuente == 2 then
		local de = M.Desencantar(id)
		if de and not de.incompleto and de.valor >= precio * (1 + M.GANGA_DE) and de.valor - precio >= M.GANGA_MIN_DE then
			g = { id = id, precio = precio, tipo = "desencantar", normal = de.valor, ganancia = floor(de.valor - precio), quien = de.quien, propio = de.propio }
		end
	end
	if g then
		g.t = M.Ahora()
		gangas[id] = g
		quitarVieja()
	else
		gangas[id] = nil
	end
	return g
end

function M.GangaDe(id) return type(id) == "number" and gangas[id] or nil end

-- De la que más deja a la que menos.
function M.Gangas()
	local out = {}
	for _, g in pairs(gangas) do out[#out + 1] = g end
	table.sort(out, function(a, b)
		if a.ganancia ~= b.ganancia then return a.ganancia > b.ganancia end
		return a.id < b.id
	end)
	return out
end

function M.OlvidarGangas() gangas = {} end

-- Cada precio que se anota pasa antes por aquí (el escaneo y tus búsquedas).
local anotar = M.Anotar
function M.Anotar(id, precio, cantidad, fuente, fecha, r)
	if M.GangasActivas() and type(id) == "number" and type(precio) == "number" and precio > 0 then
		pcall(M.RevisarGanga, id, floor(precio), fuente, r)
	end
	return anotar(id, precio, cantidad, fuente, fecha, r)
end

local function nombre(id)
	local info = M.InfoObjeto(id)
	return info and (info.link or info.nombre) or ("#" .. id)
end

-- Una línea corta de la ganga: «cuesta 35 % menos de lo que vale».
function M.TextoGanga(g)
	if not g then return nil end
	if g.tipo == "barato" then
		local p = floor((1 - g.precio / g.normal) * 100 + 0.5)
		return L["Ganga: cuesta %d %% menos de lo que suele valer"]:format(p)
	end
	if g.quien and not g.propio then
		return L["Ganga: desencantarlo (con %s) deja %s"]:format(g.quien, M.Dinero(g.ganancia))
	end
	return L["Ganga: desencantarlo deja %s"]:format(M.Dinero(g.ganancia))
end

---------------------------------------------------------------------------
-- En la barra de la subasta (Subasta.lua llama a ArmarGangas y PintarGangas)
---------------------------------------------------------------------------

local function listaInfo()
	local lista = M.Gangas()
	if #lista == 0 then return L["Gangas en la subasta"], L["Todavía no veo gangas. Busca algo o escanea la subasta."] end
	local lineas = {}
	for i = 1, math.min(6, #lista) do
		local g = lista[i]
		lineas[#lineas + 1] = nombre(g.id) .. "  " .. M.Dinero(g.precio)
		lineas[#lineas + 1] = "|cff9d9d9d" .. M.TextoGanga(g) .. "|r"
	end
	if #lista > 6 then lineas[#lineas + 1] = L["y %d más"]:format(#lista - 6) end
	lineas[#lineas + 1] = L["La compra es tuya: Alfa no compra ni puja."]
	return L["Gangas en la subasta"], table.concat(lineas, "\n")
end

function M.ImprimirGangas()
	local lista = M.Gangas()
	if #lista == 0 then
		N.Imprimir(L["Todavía no veo gangas. Busca algo o escanea la subasta."])
		return
	end
	for i = 1, math.min(10, #lista) do
		local g = lista[i]
		N.Imprimir(nombre(g.id) .. " " .. M.Dinero(g.precio) .. " · " .. M.TextoGanga(g))
	end
end

function M.ArmarGangas(barra)
	if barra.Gangas then return barra.Gangas end
	local b = K.Boton(barra, "", function() M.ImprimirGangas() end, { tipo = "secundario", tam = "chico", icono = "ic-oro" })
	K.ConInfo(b, listaInfo)
	b:Hide()
	barra.Gangas = b
	return b
end

-- -> el marco junto al que termina el texto de estado
function M.PintarGangas(barra)
	local b = barra.Gangas
	if not b then return barra.Abrir end
	local n = #M.Gangas()
	local ver = M.GangasActivas() and n > 0
	b:SetShown(ver)
	if not ver then return barra.Abrir end
	b:SetTexto(N.Plural(n, L["%d ganga"], L["%d gangas"]))
	b:ClearAllPoints()
	b:SetPoint("RIGHT", barra.Abrir, "LEFT", -K.ESP.s, 0)
	return b
end
