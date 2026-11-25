-- Alfa - Rutas: «Comprar lo que falta» en las guías de oficio (toxic3000 / La
-- Jauría). GPL-3.0. 1.4.0 (31)
--
-- En una guía de profesión de Alfa (Oficios.lua), el paso «Tus materiales
-- para 75–150» dice cuánto te falta de cada cosa. Con un clic, «Comprar lo
-- que falta» lo pasa a tu lista de compras de Comercio (AlfaComercio.Lista:
-- sus palomitas se marcan solas mientras juntas, y en la subasta te dice qué
-- buscar), con lo que ya traes y lo de tus otros personajes descontado.
-- Volver a pedirlo no lo suma dos veces: pone la cantidad de ahora.
--
-- El rastreador lo ofrece en el paso de materiales del tramo en que vas (o el
-- siguiente que tenga materiales, si el de ahora es de recetas), con cuántas
-- cosas faltan y lo que costaría en la subasta si Alfa ya conoce sus precios.
-- Ajuste rutas.comprarFalta (de fábrica, sí). Nada en combate.
--
--   Comprar.Faltan() -> { { id, nombre, faltan, precio }, ... }, total | nil, motivo
--   Comprar.Agregar() -> n (cuántos objetos pasaron a la lista) | nil, motivo
--   Comprar.Aviso(v, live) -> el aviso del rastreador | nil
--   AlfaRuta.ComprarFalta() (Contrato.lua): lo mismo, para Comercio y los demás

local ADDON, M = ...
local A, L, N = M.A, M.L, M.N
local Cm = {}
M.Comprar = Cm

A.RegisterDefaults(M.ID, { comprarFalta = true })

local type, ipairs, tonumber, pcall, format, max = type, ipairs, tonumber, pcall, string.format, math.max

local MAX_PASOS = 12 -- pasos hacia adelante donde buscar el de materiales

local function E() return A.Engine end
local function encendido() return A.Get(M.ID .. ".comprarFalta") ~= false end
local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end

local function lista()
	local C = rawget(_G, "AlfaComercio")
	local Li = type(C) == "table" and C.Lista
	return type(Li) == "table" and type(Li.Agregar) == "function" and Li or nil
end

-- ¿Una guía de oficio de Alfa? -> la línea del oficio | nil
local function oficio(g)
	local Of = M.OficiosGuia
	if not (Of and Of.LineaDe and type(g) == "table") then return nil end
	return Of.LineaDe(g.id)
end

-- Los materiales de un paso: sus metas de juntar o comprar un objeto.
local function materialesDe(paso)
	local out = {}
	for _, x in ipairs(type(paso) == "table" and paso.goals or {}) do
		local id, n = tonumber(x.item), tonumber(x.count)
		if id and n and n > 0 and not x.quest and (x.t == "collect" or x.t == "buy") then out[#out + 1] = { id = id, n = n, x = x } end
	end
	return out
end

-- El paso de materiales que toca: el de ahora o el siguiente de su tramo.
local function pasoMateriales(g, live)
	local e = E()
	local s0 = g.steps[live]
	local tramo = type(s0) == "table" and s0.section or nil
	for s = live, math.min(#g.steps, live + MAX_PASOS) do
		local paso = g.steps[s]
		if type(paso) == "table" then
			if s > live and tramo and paso.section and paso.section ~= tramo then break end
			local v = e and e.GetStepView and e.GetStepView(s)
			local fuera = type(v) == "table" and (v.status == "done" or v.status == "na" or v.skipped)
			local mats = materialesDe(paso)
			if #mats > 0 and not fuera then return s, mats end
		end
	end
	return nil
end

local function aqui(id)
	local Of = M.OficiosGuia
	local n = Of and Of.Aqui and select(2, pcall(Of.Aqui, id))
	return tonumber(n) or 0
end

local function precio(id)
	local Of = M.OficiosGuia
	local p = Of and Of.Precio and select(2, pcall(Of.Precio, id))
	return type(p) == "number" and p > 0 and p or nil
end

function Cm.Faltan()
	if not encendido() then return nil, "apagado" end
	local e = E()
	local g = e and e.GetGuide and e.GetGuide()
	local live = e and e.GetLiveStep and e.GetLiveStep()
	if not (oficio(g) and type(g.steps) == "table" and live) then return nil, "guia" end
	local s, mats = pasoMateriales(g, live)
	if not s then return nil, "paso" end
	local out, total, todos = {}, 0, true
	for _, m in ipairs(mats) do
		local faltan = max(0, m.n - aqui(m.id))
		if faltan > 0 then
			local p = precio(m.id)
			if p then total = total + p * faltan else todos = false end
			out[#out + 1] = { id = m.id, nombre = M.NombreObjeto(m.id), faltan = faltan, precio = p }
		end
	end
	return out, todos and total or nil, s
end

function Cm.Agregar()
	if enCombate() then
		M.Aviso(L["Comprar lo que falta"], L["Se puede al salir de combate."], { icono = "ic-aviso", tono = "aviso" })
		return nil, "combate"
	end
	local Li = lista()
	if not Li then
		M.Aviso(L["Comprar lo que falta"], L["Hace falta el módulo Comercio de Alfa para la lista de compras."], { icono = "ic-aviso", tono = "aviso" })
		return nil, "comercio"
	end
	local faltan, motivo = Cm.Faltan()
	if not faltan then return nil, motivo end
	if #faltan == 0 then
		M.Aviso(L["Comprar lo que falta"], L["Ya tienes todo lo de este tramo."], { icono = "ic-exito" })
		return 0
	end
	local n = 0
	for _, f in ipairs(faltan) do
		-- La cantidad de ahora (no se suma a lo que ya estaba en la lista).
		local metas = type(Li.Metas) == "function" and Li.Metas() or {}
		for i = #metas, 1, -1 do
			local m = metas[i]
			if type(m) == "table" and m.id == f.id and not m.oficio and type(Li.Quitar) == "function" then Li.Quitar(i) end
		end
		if Li.Agregar(f.id, f.faltan) then n = n + 1 end
	end
	if n > 0 then
		M.Aviso(L["Lo que falta, en tu lista de compras"],
			M.Plural(n, L["%d objeto en tu lista de Comercio: en la subasta te digo qué buscar."], L["%d objetos en tu lista de Comercio: en la subasta te digo qué buscar."]),
			{ icono = "ic-comercio", accion = { texto = L["Ver la lista"], alClic = function() N.Abrir("comercio") end } })
	end
	return n
end

function Cm.Aviso(v, live)
	if not (v and live and v.index == live) or enCombate() or not lista() then return nil end
	local faltan, total, s = Cm.Faltan()
	if not faltan or #faltan == 0 then return nil end
	local partes = {}
	for i = 1, math.min(3, #faltan) do partes[i] = format("%d %s", faltan[i].faltan, faltan[i].nombre) end
	local texto = table.concat(partes, ", ")
	if #faltan > 3 then texto = texto .. " " .. format(L["y %d más"], #faltan - 3) end
	if total and total > 0 and N.DineroTexto then texto = texto .. "\n" .. format(L["≈ %s en la subasta"], N.DineroTexto(total, true)) end
	return { tono = "info", icono = "ic-comercio", clave = "rutas.comprar:" .. tostring(s),
		titulo = M.Plural(#faltan, L["Te falta %d material para este tramo"], L["Te faltan %d materiales para este tramo"]),
		texto = texto,
		uno = { L["Comprar lo que falta"], function() Cm.Agregar() end } }
end
