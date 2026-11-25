-- Alfa - Bolsas: comparar con lo que llevas puesto (toxic3000 / La Jauría). GPL-3.0. 1.3.0.
--
-- En el cuadro de una pieza de equipo, una línea con lo que ganas y lo que
-- pierdes contra lo que llevas en esa ranura, con números claros:
--   Contra lo que llevas: +5 Fuerza · +12 Armadura · −3 Aguante
-- La ranura con la que se compara la decide el motor (Alfa.Gear.CompareToEquipped:
-- el anillo o abalorio más flojo, un arma de dos manos contra las dos manos)
-- y los números salen de Alfa.Gear.GetItemInfo (las cifras del juego,
-- C_Item.GetItemStats, con los sufijos «del oso»). El orden: lo que más pesa
-- para tu clase primero (Alfa.Gear.GetWeights). El «+12 %» de mejora ya lo
-- dice el motor en su propia línea; esta solo dice qué cambia.
-- Se cuelga de Alfa.Hooks.ItemLines (cuadros prohibidos y enlaces secretos
-- fuera). Ajuste bolsas.comparar (de fábrica, encendido).
--   Co.Diferencias(link) -> { { clave, delta }, ... } | nil ; Co.Linea(link) -> texto | nil

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L

local type, pairs, ipairs, abs, floor, format = type, pairs, ipairs, math.abs, math.floor, string.format

local Co = {}
M.Comparar = Co

local MAX = 5
local MAIN, OFF, DOS_MANOS = 16, 17, 17 -- ranuras; 17 es también el tipo «dos manos» del motor

-- Las cifras del motor (Gear.CLIENT_STATS) con su nombre.
Co.NOMBRES = {
	str = L["Fuerza"], agi = L["Agilidad"], sta = L["Aguante"], int = L["Intelecto"], spi = L["Espíritu"],
	armor = L["Armadura"], dps = L["Daño por segundo"], health = L["Salud"], mana = L["Maná"],
	ap = L["Poder de ataque"], rap = L["Poder de ataque a distancia"], sp = L["Poder con hechizos"],
	heal = L["Curación"], mp5 = L["Maná cada 5 s"], hp5 = L["Salud cada 5 s"], crit = L["Golpe crítico"],
	hit = L["Golpe"], spellCrit = L["Crítico con hechizos"], spellHit = L["Golpe con hechizos"],
	defense = L["Defensa"], dodge = L["Esquivar"], parry = L["Parar"], block = L["Bloquear"],
	blockValue = L["Valor de bloqueo"],
}

local function encendido() return M.Get("comparar") ~= false end

local function gear()
	local G = A.Gear
	if not (G and type(G.CompareToEquipped) == "function" and type(G.GetItemInfo) == "function") then return nil end
	if type(G.IsEnabled) == "function" and not M.Leer(M.Llamar(G.IsEnabled)) then return nil end
	return G
end

local function cifras(G, link)
	if type(link) ~= "string" then return nil end
	local info = M.Llamar(G.GetItemInfo, link)
	return type(info) == "table" and type(info.stats) == "table" and info.stats or nil, info
end

local function puesto(ranura)
	return GetInventoryItemLink and M.Texto(M.Llamar(GetInventoryItemLink, "player", ranura)) or nil
end

-- -> { { clave, delta }, ... } (lo que más pesa primero) | nil
function Co.Diferencias(link)
	local G = gear()
	if not G or type(link) ~= "string" then return nil end
	local r = M.Llamar(G.CompareToEquipped, link)
	if type(r) ~= "table" or r.equipped or r.usable == false or not r.slot then return nil end
	local nuevas, info = cifras(G, link)
	if not nuevas then return nil end
	-- Lo que se quita: la ranura; un arma de dos manos quita también la otra mano.
	local viejas = {}
	local ranuras = { r.slot }
	if info and info.inv == DOS_MANOS and r.slot == MAIN then ranuras[2] = OFF end
	local alguna = false
	for _, s in ipairs(ranuras) do
		local l = puesto(s)
		local t = l and cifras(G, l)
		if t then
			alguna = true
			for k, v in pairs(t) do viejas[k] = (viejas[k] or 0) + v end
		end
	end
	if not alguna and not r.empty then return nil end
	local pesos = M.Llamar(G.GetWeights)
	pesos = type(pesos) == "table" and pesos or {}
	local out = {}
	local claves = {}
	for k in pairs(nuevas) do claves[k] = true end
	for k in pairs(viejas) do claves[k] = true end
	for k in pairs(claves) do
		local d = (nuevas[k] or 0) - (viejas[k] or 0)
		if Co.NOMBRES[k] and abs(d) >= 0.05 then out[#out + 1] = { clave = k, delta = d } end
	end
	table.sort(out, function(a, b)
		local pa, pb = abs(a.delta * (tonumber(pesos[a.clave]) or 0.01)), abs(b.delta * (tonumber(pesos[b.clave]) or 0.01))
		if pa ~= pb then return pa > pb end
		return a.clave < b.clave
	end)
	-- 1.4.0 (24): cuánto pesa el cambio para tu clase (con los pesos del motor).
	local puntos, conPeso = 0, false
	for _, x in ipairs(out) do
		local w = tonumber(pesos[x.clave])
		if w and w ~= 0 then puntos, conPeso = puntos + x.delta * w, true end
	end
	out.puntos = conPeso and puntos or nil
	return out, r
end

-- 1.4.0 (24): «mejor», «peor» o nil (parecido o sin pesos para tu clase).
function Co.Veredicto(lista)
	local p = type(lista) == "table" and tonumber(lista.puntos)
	if not p then return nil end
	if p > 0.5 then return "mejor" end
	if p < -0.5 then return "peor" end
	return nil
end

local function numero(d)
	local n = abs(d)
	local t = (n == floor(n)) and tostring(floor(n)) or format("%.1f", n)
	return (d >= 0 and "+" or "\226\136\146") .. t
end

-- "Contra lo que llevas: +5 Fuerza · −3 Aguante" (con colores) | nil
function Co.Linea(link)
	if not encendido() then return nil end
	local lista, r = Co.Diferencias(link)
	if not lista then return nil end
	if #lista == 0 then return L["Contra lo que llevas: lo mismo."] end
	local gr, gg, gb = M.Color("success", 0.42, 0.85, 0.6)
	local rr, rg, rb = M.Color("danger", 0.96, 0.45, 0.45)
	local partes = {}
	for i = 1, math.min(#lista, MAX) do
		local x = lista[i]
		local texto = numero(x.delta) .. " " .. Co.NOMBRES[x.clave]
		if x.delta >= 0 then partes[i] = M.Pintado(texto, gr, gg, gb) else partes[i] = M.Pintado(texto, rr, rg, rb) end
	end
	-- 1.4.0 (24): primero el veredicto, en la misma línea: «Mejor que lo que llevas:».
	local cabeza = L["Contra lo que llevas:"]
	local v = Co.Veredicto(lista)
	if r and r.empty then cabeza = L["Ranura vacía:"]
	elseif v == "mejor" then cabeza = M.Pintado(L["Mejor que lo que llevas:"], gr, gg, gb)
	elseif v == "peor" then cabeza = M.Pintado(L["Peor que lo que llevas:"], rr, rg, rb) end
	local texto = cabeza .. " " .. table.concat(partes, " \194\183 ")
	if #lista > MAX then texto = texto .. " " .. format(L["y %d más"], #lista - MAX) end
	return texto
end

if A.Hooks and A.Hooks.ItemLines then
	A.Hooks.ItemLines("Alfa_Bolsas_Comparar", function(tooltip, link)
		if not encendido() or type(link) ~= "string" or not (tooltip and tooltip.AddLine) then return end
		local texto = Co.Linea(link)
		if not texto then return end
		local r, g, b = M.Color("textDim", 0.75, 0.78, 0.85)
		tooltip:AddLine(texto, r, g, b, true)
	end)
end
