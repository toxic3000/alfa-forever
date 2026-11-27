-- Alfa - Pesca: qué pica aquí y tus mejores lugares (1.4.2). toxic3000 / La Jauría. GPL-3.0.
--
-- Con tus propias capturas (el registro de Registro.lua: las 1500 últimas,
-- con su zona y subzona) Alfa dice qué sale donde estás pescando y en qué
-- proporción («Bagre 45 %, Salmón 30 %…»), cuánto vale en promedio cada
-- captura aquí y cuáles son tus lugares que más oro dejan por captura. Así
-- sabes si te conviene quedarte o moverte, y adónde.
-- Se ve en el clic derecho de la barra de pesca («Qué pica aquí») y con
-- /alfa pesca aqui. Nada se inventa: sin capturas tuyas aquí, lo dice.
--
--   Aq.Aqui() -> { lugar, total, lista = { { clave, nombre, n, pct, icono } }, valor, sub }
--   Aq.Mejores(n) -> { { lugar, total, valor } } (lo que más deja por captura primero)

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = M.L
local ID = M.ID

local type, ipairs, pairs, tonumber, tostring, floor, max, min, format = type, ipairs, pairs, tonumber, tostring, math.floor, math.max, math.min, string.format

local Aq = {}
M.Aqui = Aq

Aq.MIN_SUB = 10      -- con menos capturas en la subzona se mira toda la zona
Aq.MIN_LUGAR = 15    -- para entrar en «tus mejores lugares»

local function lugares() local l = N.DatosPersonaje(ID).lugares return type(l) == "table" and l or {} end

local function indice(nombre)
	if not nombre then return nil end
	for i, n in ipairs(lugares()) do if n == nombre then return i end end
	return nil
end

local function nombreDe(clave)
	local e = M.Diario()[clave]
	if type(e) == "table" and type(e.nombre) == "string" then return e.nombre end
	if type(clave) == "number" then return (M.Eq and M.Eq.Nombre(clave)) or ("#" .. clave) end
	return tostring(clave)
end

local function iconoDe(clave)
	local e = M.Diario()[clave]
	if type(e) == "table" and e.icono and type(e.icono) ~= "table" then return e.icono end
	local CI = rawget(_G, "C_Item")
	if type(clave) == "number" and type(CI) == "table" and type(CI.GetItemIconByID) == "function" then
		local ok, ic = pcall(CI.GetItemIconByID, clave)
		if ok and N.Leer(ic) then return N.Leer(ic) end
	end
	return nil
end

-- Lo que vale una captura de esa clave (la subasta si Comercio la sabe; si no, el comerciante).
local function valorDe(clave)
	if type(clave) ~= "number" or not M.ValorDe then return 0 end
	local venta, subasta = M.ValorDe(clave)
	return subasta or venta or 0
end

-- Cuenta las capturas del registro que cumplen fn(entrada).
local function contar(fn)
	local por, total, valor = {}, 0, 0
	for _, r in ipairs(M.Registro()) do
		if type(r) == "table" and r.id ~= nil and fn(r) then
			local n = max(1, tonumber(r.n) or 1)
			por[r.id] = (por[r.id] or 0) + n
			total = total + n
			valor = valor + valorDe(r.id) * n
		end
	end
	return por, total, valor
end

function Aq.Aqui(zona, sub)
	if not zona then zona, sub = M.Lugar() end
	local zi, si = indice(zona), indice(sub)
	local por, total, valor, lugar = {}, 0, 0, zona
	if zi and si then
		por, total, valor = contar(function(r) return r.z == zi and r.s == si end)
		lugar = sub
	end
	if total < Aq.MIN_SUB and zi then
		por, total, valor = contar(function(r) return r.z == zi end)
		lugar = zona
	end
	local lista = {}
	for clave, n in pairs(por) do
		lista[#lista + 1] = { clave = clave, nombre = nombreDe(clave), n = n, pct = total > 0 and n / total or 0, icono = iconoDe(clave) }
	end
	table.sort(lista, function(a, b)
		if a.n ~= b.n then return a.n > b.n end
		return tostring(a.nombre) < tostring(b.nombre)
	end)
	return { lugar = lugar, total = total, lista = lista, valor = total > 0 and floor(valor / total + 0.5) or 0, sub = lugar == sub and sub ~= zona }
end

function Aq.Mejores(cuantos)
	local por = {}
	for _, r in ipairs(M.Registro()) do
		if type(r) == "table" and r.id ~= nil and r.z then
			local k = tostring(r.z) .. ":" .. tostring(r.s or 0)
			local e = por[k]
			if not e then e = { z = r.z, s = r.s, total = 0, valor = 0 } por[k] = e end
			local n = max(1, tonumber(r.n) or 1)
			e.total = e.total + n
			e.valor = e.valor + valorDe(r.id) * n
		end
	end
	local out = {}
	for _, e in pairs(por) do
		if e.total >= Aq.MIN_LUGAR then
			local zona, sub = M.NombreLugar(e.z), e.s and M.NombreLugar(e.s) or nil
			local corto = (sub and sub ~= zona) and sub or (zona or "?")
			local lugar = (sub and sub ~= zona) and format("%s (%s)", sub, zona or "?") or (zona or "?")
			out[#out + 1] = { lugar = lugar, corto = corto, zona = corto ~= zona and zona or nil, total = e.total, valor = floor(e.valor / e.total + 0.5) }
		end
	end
	table.sort(out, function(a, b)
		if a.valor ~= b.valor then return a.valor > b.valor end
		return a.total > b.total
	end)
	for i = #out, (cuantos or 3) + 1, -1 do out[i] = nil end
	return out
end

-- «Bagre 45 %, Salmón 30 %»
function Aq.Corto(a, cuantos)
	local partes = {}
	for i = 1, min(#a.lista, cuantos or 2) do
		local e = a.lista[i]
		partes[#partes + 1] = format("%s %d %%", tostring(e.nombre), floor(e.pct * 100 + 0.5))
	end
	return table.concat(partes, ", ")
end

---------------------------------------------------------------------------
-- En la barra: una fila en «Más de la pesca» y su menú
---------------------------------------------------------------------------
function Aq.Menu()
	local a = Aq.Aqui()
	local filas = {}
	for i = 1, min(#a.lista, 6) do
		local e = a.lista[i]
		filas[#filas + 1] = { icono = e.icono, nombre = tostring(e.nombre),
			valor = format("%d %% · ×%d", floor(e.pct * 100 + 0.5), e.n) }
	end
	local nota
	if a.total == 0 then
		nota = L["Aún no pescas aquí. Cuando saques algo, te digo qué pica y en qué proporción."]
	else
		nota = format(L["De tus %d capturas en %s. Cada una vale unos %s."], a.total, tostring(a.lugar), N.Dinero(a.valor))
	end
	local mejores = Aq.Mejores(3)
	if #mejores > 0 then
		filas[#filas + 1] = { icono = "ic-exito", nombre = L["Tus lugares que más dejan"], valor = "", apagada = true }
		for _, m in ipairs(mejores) do
			-- (el nombre corto arriba y la zona abajo: nada se corta en el menú)
			filas[#filas + 1] = { icono = "ic-mapa", nombre = m.corto, valor = format(L["%s c/u"], N.Dinero(m.valor)) .. (m.zona and ("  ·  " .. m.zona) or ""),
				ayuda = format(L["%d capturas tuyas ahí."], m.total) }
		end
	end
	return { titulo = format(L["Qué pica en %s"], tostring(a.lugar or L["Sin zona"])), nota = nota, filas = filas }
end

local B = M.Barra
local ultimoDueno -- de dónde se abrió el último menú de la barra (el de «Qué pica aquí» sale ahí mismo)
if B and type(B.MostrarMenu) == "function" then
	local mostrar = B.MostrarMenu
	B.MostrarMenu = function(id, dueno, contenido)
		ultimoDueno = dueno
		return mostrar(id, dueno, contenido)
	end
end
if B and B.MENUS then
	B.MENUS.aqui = Aq.Menu
	local mas = B.MENUS.mas
	if type(mas) == "function" then
		B.MENUS.mas = function()
			local c = mas()
			if type(c) == "table" and type(c.filas) == "table" then
				local a = Aq.Aqui()
				table.insert(c.filas, 1, { icono = M.ICONO and M.ICONO.diario or "ic-pesca", nombre = L["Qué pica aquí"],
					valor = a.total > 0 and Aq.Corto(a, 2) or L["Sin capturas aquí"],
					ayuda = L["Lo que sale aquí según tus capturas, lo que vale cada una y tus lugares que más dejan."],
					alClic = function()
						B.MostrarMenu("aqui", ultimoDueno or UIParent, Aq.Menu())
					end })
			end
			return c
		end
	end
end

-- /alfa pesca aqui
function Aq.Imprimir()
	local a = Aq.Aqui()
	if a.total == 0 then N.Imprimir(L["Aún no pescas aquí. Cuando saques algo, te digo qué pica y en qué proporción."]) return end
	N.Imprimir(format(L["En %s (%d capturas, unos %s cada una): %s."], tostring(a.lugar), a.total, N.Dinero(a.valor), Aq.Corto(a, 5)))
	local mejores = Aq.Mejores(3)
	if #mejores > 0 then
		local partes = {}
		for _, m in ipairs(mejores) do partes[#partes + 1] = format("%s (%s)", m.lugar, N.Dinero(m.valor)) end
		N.Imprimir(format(L["Tus lugares que más dejan: %s."], table.concat(partes, ", ")))
	end
end

local comando = M.Comando
if type(comando) == "function" then
	M.Comando = function(resto)
		local r = (type(resto) == "string" and resto or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
		if r == "aqui" or r == "aquí" or r == "here" then return Aq.Imprimir() end
		return comando(resto)
	end
end
