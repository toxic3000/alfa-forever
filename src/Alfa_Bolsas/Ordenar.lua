-- Alfa - Bolsas: ordenar a tu manera (toxic3000 / La Jauría). GPL-3.0. 1.3.9.
--
-- El botón «Ordenar» usa el orden del juego (C_Container.SortBags) salvo que
-- elijas otro (bolsas.ordenarModo) o que lo que tiene candado se quede en su
-- casilla (bolsas.ordenarCandado): entonces ordena Alfa, con tu clic y fuera
-- de combate:
--   1. junta los montones a medias del mismo objeto (como el juego);
--   2. acomoda lo demás en el orden que elegiste: por tipo (equipo,
--      consumibles, misiones, materiales... y la chatarra al final), por
--      calidad o por nombre; con bolsas.ordenarInverso, desde el final;
--   3. lo que tiene candado (con ordenarCandado) no se toca, y lo demás se
--      acomoda alrededor.
-- Solo en tus bolsas que aceptan cualquier objeto (la mochila y las bolsas
-- normales: las de hierbas, munición o almas y el llavero se quedan como
-- están). El banco sigue con el orden del juego.
-- Cada paso vuelve a leer tus bolsas, busca la primera casilla que no tiene
-- lo que le toca y hace UN cambio (PickupContainerItem en las dos casillas:
-- el juego las intercambia; ContainerDocumentation, sin restricciones). Si
-- algo está bloqueado (el servidor aún no contesta), espera al siguiente
-- paso. Un reloj de Alfa (N.Ticker «bolsas.ordenar», 0,15 s) mientras
-- trabaja; entrar en combate, abrir algo con el cursor o 3 pasos sin poder
-- moverse lo detienen.
--   Or.Usar() -> bool (¿ordena Alfa?) ; Or.Plan() -> destino, casillas ;
--   Or.Paso() -> "hecho" | "movi" | "espera" ; Or.Empezar() ; Or.Activo() ; Or.Detener()

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local D, O = M.Datos, M.Objetos

local type, ipairs, pairs, tonumber, tostring, format = type, ipairs, pairs, tonumber, tostring, string.format
local sort = table.sort

local Ord = {}
M.Ordenar = Ord

local GENERALES = { 0, 1, 2, 3, 4 }
local CADA = 0.15
local TOPE_PASOS = 400   -- un tope por si algo no converge
local TOPE_ESPERAS = 20  -- pasos seguidos sin poder mover nada (bloqueado)
local RELOJ = "bolsas.ordenar"

-- El orden de los tipos «por tipo»: lo que más usas primero, la chatarra al final.
local ORDEN_CAT = { equipo = 1, consumibles = 2, misiones = 3, artesania = 4, reagentes = 5, monturas = 6, otros = 7, chatarra = 9 }

local function modo()
	local m = M.Get("ordenarModo")
	if m == "tipo" or m == "calidad" or m == "nombre" then return m end
	return "juego"
end
Ord.Modo = modo

-- ¿Ordena Alfa? Con otro orden que el del juego, o si lo del candado no se mueve.
function Ord.Usar()
	if modo() ~= "juego" then return true end
	return M.Get("ordenarCandado") == true and M.Candado ~= nil and M.Candado.Encendido()
end

---------------------------------------------------------------------------
-- Lo que hay
---------------------------------------------------------------------------

local CC = M.CC

local function fijo(bolsa, casilla)
	if not (M.Get("ordenarCandado") == true and M.Candado) then return false end
	return M.Candado.TieneCasilla(bolsa, casilla) and true or false
end

-- Las casillas que se ordenan, en orden, y lo que tiene cada una.
-- -> casillas = { { bolsa, casilla, obj = { id, link, n, q, max, e } | nil } }
local function leer()
	local casillas = {}
	for _, bolsa in ipairs(GENERALES) do
		local n = M.Num(M.Llamar(CC.GetContainerNumSlots, bolsa)) or 0
		if n > 0 and D.Familia(bolsa) == 0 then
			for s = 1, n do
				if not fijo(bolsa, s) then
					local info = M.Llamar(CC.GetContainerItemInfo, bolsa, s)
					local id = type(info) == "table" and M.Num(info.itemID)
					local x = { bolsa, s }
					if id then
						local link = M.Texto(info.hyperlink)
						local e = O.Info(id, link)
						local _, _, _, _, _, _, _, apila = M.Llamar(C_Item and C_Item.GetItemInfo, link or id)
						x.obj = { id = id, link = link, n = M.Num(info.stackCount) or 1, q = M.Num(info.quality) or 1,
							max = M.Num(apila) or 1, e = e, bloqueado = M.Leer(info.isLocked) == true,
							basura = M.Leer(info.hasNoValue) ~= true and (M.Num(info.quality) == 0) }
					end
					casillas[#casillas + 1] = x
				end
			end
		end
	end
	if M.Get("ordenarInverso") then
		-- Desde el final: la última casilla es la primera que se llena.
		local r = {}
		for i = #casillas, 1, -1 do r[#r + 1] = casillas[i] end
		casillas = r
	end
	return casillas
end
Ord.Leer = leer

local function nombre(o)
	return O.Doblar(O.NombreEnlace(o.link) or (o.e and o.e.nombre) or "")
end

local function categoria(o)
	local rec = { i = o.id, q = o.q, l = o.link, basura = false }
	return O.CategoriaFija(rec, o.e or {}, nil)
end

-- Un orden total. Dos montónes del mismo objeto son intercambiables aunque
-- tengan otra cantidad: el juego los junta en vez de cambiarlos de lugar y
-- deja lo que sobra en el cursor (1.3.9, revisión 2).
local function antes(m)
	return function(a, b)
		local ka, kb
		if m == "tipo" then
			ka, kb = ORDEN_CAT[categoria(a)] or 8, ORDEN_CAT[categoria(b)] or 8
			if ka ~= kb then return ka < kb end
		end
		if m == "tipo" or m == "calidad" then
			if a.q ~= b.q then return a.q > b.q end
			if m == "calidad" then
				ka, kb = ORDEN_CAT[categoria(a)] or 8, ORDEN_CAT[categoria(b)] or 8
				if ka ~= kb then return ka < kb end
			end
		end
		local na, nb = nombre(a), nombre(b)
		if na ~= nb then return na < nb end
		if a.id ~= b.id then return a.id < b.id end
		return (a.link or "") < (b.link or "")
	end
end

local function igual(a, b)
	if a == nil or b == nil then return a == b end
	return a.id == b.id and (a.link or "") == (b.link or "")
end

-- -> destino (lista de objetos en el orden en que deben quedar), casillas
function Ord.Plan(casillas)
	casillas = casillas or leer()
	local objs = {}
	for _, x in ipairs(casillas) do if x.obj then objs[#objs + 1] = x.obj end end
	local m = modo()
	sort(objs, antes(m == "juego" and "tipo" or m))
	return objs, casillas
end

---------------------------------------------------------------------------
-- Un paso
---------------------------------------------------------------------------

local function tomar(bolsa, casilla) M.Llamar(CC.PickupContainerItem, bolsa, casilla) end
local function cursorLleno()
	local f = rawget(_G, "CursorHasItem")
	return type(f) == "function" and M.Leer(M.Llamar(f)) == true
end

-- 1. Un montón a medias que cabe en otro igual (el de más atrás va al de más adelante).
local function juntar(casillas)
	local vistos = {}
	for _, x in ipairs(casillas) do
		local o = x.obj
		if o and o.max > 1 and o.n < o.max then
			local k = o.id .. "|" .. (o.link or "")
			local otro = vistos[k]
			-- Solo si caben juntos: lo que sobra se quedaría en el cursor.
			if otro and otro.obj.n + o.n <= o.max then
				if o.bloqueado or otro.obj.bloqueado then return "espera" end
				tomar(x[1], x[2])
				tomar(otro[1], otro[2])
				return "movi"
			end
			vistos[k] = x
		end
	end
	return nil
end

function Ord.Paso()
	if M.EnCombate() then return "combate" end
	if cursorLleno() then return "cursor" end
	local destino, casillas = Ord.Plan()
	local r = juntar(casillas)
	if r then return r end
	for i, x in ipairs(casillas) do
		local quiero = destino[i]
		if not igual(x.obj, quiero) then
			-- Lo que le toca, más adelante: primero una casilla donde tampoco va
			-- (así un cambio acomoda las dos), si no, cualquiera.
			local mejor, cualquiera
			for j = i + 1, #casillas do
				local y = casillas[j]
				if igual(y.obj, quiero) then
					cualquiera = cualquiera or y
					if not igual(y.obj, destino[j]) then mejor = y break end
				end
			end
			local y = mejor or cualquiera
			if y then
				if (x.obj and x.obj.bloqueado) or y.obj.bloqueado then return "espera" end
				tomar(y[1], y[2])
				tomar(x[1], x[2])
				return "movi"
			end
		end
	end
	return "hecho"
end

---------------------------------------------------------------------------
-- La tanda (tras el clic)
---------------------------------------------------------------------------

local tanda -- { pasos, movidos, esperas }

function Ord.Activo() return tanda ~= nil end

local function terminar(porque)
	local t = tanda
	tanda = nil
	if N.Quitar then N.Quitar(RELOJ) end
	if not t then return end
	if porque == "combate" then
		N.Imprimir(L["Dejé de ordenar: entraste en combate."])
	elseif porque == "cursor" then
		N.Imprimir(L["Dejé de ordenar: tienes algo en el cursor."])
	elseif porque == "atorado" then
		N.Imprimir(L["Dejé de ordenar: el juego no soltó algunos objetos. Dale otra vez en un momento."])
	end
	M.Avisar("ORDENAR", false)
end
Ord.Detener = function() terminar("detenido") end

local function tic()
	local t = tanda
	if not t then return end
	t.pasos = t.pasos + 1
	local r = Ord.Paso()
	if r == "movi" then
		t.movidos, t.esperas = t.movidos + 1, 0
	elseif r == "espera" then
		t.esperas = t.esperas + 1
		if t.esperas >= TOPE_ESPERAS then return terminar("atorado") end
	elseif r == "hecho" then
		return terminar("hecho")
	else
		return terminar(r)
	end
	if t.pasos >= TOPE_PASOS then terminar("atorado") end
end
Ord.Tic = tic

-- -> true si empezó
function Ord.Empezar()
	if tanda then
		terminar("detenido")
		return false
	end
	if M.EnCombate() then
		N.Imprimir(L["No se puede ordenar en combate."])
		return false
	end
	if cursorLleno() then
		N.Imprimir(L["Suelta lo que tienes en el cursor y vuelve a ordenar."])
		return false
	end
	tanda = { pasos = 0, movidos = 0, esperas = 0 }
	M.Avisar("ORDENAR", true)
	if N.Ticker then
		N.Ticker(RELOJ, CADA, tic)
	else
		-- Sin reloj (pruebas): todo de una vez.
		while tanda do tic() end
	end
	return true
end

A.RegisterEvent("PLAYER_REGEN_DISABLED", function() if tanda then terminar("combate") end end)
