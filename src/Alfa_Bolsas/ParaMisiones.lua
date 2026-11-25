-- Alfa - Bolsas: lo que piden tus misiones y está en tu banco (toxic3000 /
-- La Jauría). GPL-3.0. 1.4.0 (diario, 98)
--
-- El juego solo cuenta para una misión lo que llevas en las bolsas: si las
-- 6 pieles que pide ya las guardaste en el banco, la misión dice 0/6 y sales a
-- cazar de más. Alfa lo cruza con lo que tu banco tiene (en vivo con el
-- banquero, o la última foto de Datos.lua):
--   * al aceptar una misión, si tu banco ya tiene lo que pide: «Esto ya lo
--     tienes en el banco», con «Llévame al banco»;
--   * con el banco abierto: «Saca lo de tus misiones», con «Sacarlo», que lo
--     pasa a tus bolsas por lotes (Lotes.lua, el clic derecho del juego), solo
--     lo que falta (montón por montón).
-- Las misiones y sus objetivos son los del motor (Alfa.QuestDB:
-- ObjectivesForItem, con cur/max/done de tu registro). Nada en combate,
-- nunca sin tu clic. Ajuste bolsas.paraMisiones (sí).
--
--   Pm.Lista(enVivo) -> { { id, enBanco, falta, titulo, casillas = { { bolsa, casilla, cuantos } } } }
--   Pm.Sacar(lista) -> true si empezó

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local D = M.Datos
local K = N.Kit

local type, ipairs, pairs, pcall, format, min, max, sort = type, ipairs, pairs, pcall, string.format, math.min, math.max, table.sort

local Pm = {}
M.ParaMisiones = Pm

local function encendido() return M.Get("paraMisiones") ~= false end

local function Q()
	local q = A and A.QuestDB
	if type(q) ~= "table" or type(q.ObjectivesForItem) ~= "function" then return nil end
	if type(q.IsRunning) == "function" and not q.IsRunning() then return nil end
	return q
end

-- Lo que una misión de tu registro aún pide de ese objeto: -> falta, título
local function falta(q, id)
	local ok, objs = pcall(q.ObjectivesForItem, id)
	if not ok or type(objs) ~= "table" then return 0 end
	local mas, titulo = 0, nil
	for _, o in ipairs(objs) do
		if type(o) == "table" and not o.done then
			local f = (M.Num(o.max) or 1) - (M.Num(o.cur) or 0)
			if f > mas then
				mas = f
				local okT, t = pcall(q.GetQuestTitle, o.q)
				titulo = okT and M.Texto(t) or nil
			end
		end
	end
	return mas, titulo
end

-- Lo que hay en tu banco: id -> { cuantos, casillas }
local function banco(enVivo)
	local out = {}
	local function anotar(id, bolsa, casilla, c)
		local e = out[id]
		if not e then e = { cuantos = 0, casillas = {} } out[id] = e end
		e.cuantos = e.cuantos + c
		e.casillas[#e.casillas + 1] = { bolsa = bolsa, casilla = casilla, cuantos = c }
	end
	if enVivo then
		for _, bolsa in ipairs(D.BANCO) do
			local n = M.Num(M.Llamar(M.CC.GetContainerNumSlots, bolsa)) or 0
			for s = 1, n do
				local i = M.Llamar(M.CC.GetContainerItemInfo, bolsa, s)
				local id = type(i) == "table" and M.Num(i.itemID)
				if id then anotar(id, bolsa, s, M.Num(i.stackCount) or 1) end
			end
		end
	else
		local r = D.Actual()
		for bolsa, t in pairs(r and r.banco or {}) do
			if type(t) == "table" then
				for s, x in pairs(t) do
					if type(s) == "number" and type(x) == "table" and x.i then anotar(x.i, bolsa, s, x.c or 1) end
				end
			end
		end
	end
	return out
end

function Pm.Lista(enVivo)
	local q = Q()
	local out = {}
	if not q then return out end
	for id, e in pairs(banco(enVivo)) do
		local f, titulo = falta(q, id)
		if f > 0 then
			sort(e.casillas, function(a, b) return a.cuantos > b.cuantos end)
			out[#out + 1] = { id = id, enBanco = e.cuantos, falta = f, titulo = titulo, casillas = e.casillas }
		end
	end
	sort(out, function(a, b) return a.id < b.id end)
	return out
end

local function nombre(id)
	local CI = rawget(_G, "C_Item")
	local n = CI and CI.GetItemNameByID and M.Texto(M.Llamar(CI.GetItemNameByID, id))
	return n or L["un objeto"]
end

local function linea(e)
	local t = format(L["%s ×%d"], nombre(e.id), min(e.enBanco, e.falta))
	if e.titulo then t = t .. " " .. format(L["para «%s»"], e.titulo) end
	return t
end

local function texto(lista)
	local t = linea(lista[1])
	if #lista > 1 then t = t .. " " .. format(L["y %s más"], N.Plural(#lista - 1, L["%d cosa"], L["%d cosas"])) end
	return t
end

-- Pasa a tus bolsas lo que falta de cada uno (montón por montón).
function Pm.Sacar(lista)
	if not D.BancoAbierto() then return false end
	lista = lista or Pm.Lista(true)
	local mover = {}
	for _, e in ipairs(lista) do
		local falta_ = e.falta
		for _, c in ipairs(e.casillas) do
			if falta_ <= 0 then break end
			mover[#mover + 1] = { c.bolsa, c.casilla, e.id }
			falta_ = falta_ - c.cuantos
		end
	end
	local Lotes = M.Lotes
	if not (Lotes and Lotes.Iniciar) then return false end
	return Lotes.Iniciar({
		nombre = "paraMisiones", lista = mover,
		puede = function() return D.BancoAbierto(), "cerrado" end,
		mover = function(bolsa, casilla) M.Llamar(M.CC.UseContainerItem, bolsa, casilla) end,
		alTerminar = function(hechos)
			if hechos and hechos > 0 then N.Imprimir(format(L["Pasé a tus bolsas lo de tus misiones (%s)."], N.Plural(hechos, L["%d montón"], L["%d montones"]))) end
		end,
	})
end

local avisados = {} -- id -> true (al aceptar una misión, una vez por objeto)

local function alAceptar()
	if not encendido() or M.EnCombate() or D.BancoAbierto() or not (K and K.Aviso) then return end
	local lista, nuevos = Pm.Lista(false), {}
	for _, e in ipairs(lista) do
		if not avisados[e.id] then
			avisados[e.id] = true
			nuevos[#nuevos + 1] = e
		end
	end
	if #nuevos == 0 then return end
	local S = M.Sugerencias
	K.Aviso({
		id = "bolsas.paraMisiones", titulo = L["Esto ya lo tienes en el banco"],
		texto = texto(nuevos) .. ". " .. L["El juego solo cuenta lo que llevas en las bolsas."],
		icono = "ic-misiones", tono = "acento", duracion = 12, prioridad = "util",
		acciones = S and S.LlevarBanco and { { texto = L["Llévame al banco"], alClic = function() S.LlevarBanco() end } } or nil,
	})
end

local function alAbrirBanco()
	if not encendido() or M.EnCombate() or not D.BancoAbierto() or not (K and K.Aviso) then return end
	local lista = Pm.Lista(true)
	if #lista == 0 then return end
	K.Aviso({
		id = "bolsas.paraMisiones", titulo = L["Saca lo de tus misiones"],
		texto = texto(lista) .. ".", icono = "ic-misiones", tono = "acento", duracion = 15, prioridad = "util", pedido = true,
		acciones = { { texto = L["Sacarlo"], alClic = function() Pm.Sacar(lista) end } },
	})
end

A.RegisterEvent("QUEST_ACCEPTED", function()
	N.Una("bolsas.paraMisiones", 1.5, function() N.FueraDeCombate("bolsas.paraMisiones", alAceptar) end)
end)
A.RegisterEvent("BANKFRAME_OPENED", function()
	N.Una("bolsas.paraMisiones.banco", 0.8, alAbrirBanco)
end)
