-- Alfa - Bolsas: qué guardar en el banco o para otro personaje (toxic3000 / La Jauría). GPL-3.0. 1.2.9.
--
-- En la página de Bolsas, lo que llevas encima y te sirve más guardado:
--   * materiales de las recetas de otro de tus personajes (Comercio sabe sus
--     recetas: AlfaComercio.Usan) que este no usa;
--   * objetos que pide una misión que lleva otro de tus personajes (cada uno
--     anota sus misiones al jugar; el Codex del motor dice qué objetos pide);
--   * equipo que se liga al equiparlo y tu clase no usa (Alfa.Gear del motor).
-- Con un banquero, «Al banco» lo deposita con tu clic (Banco.lua, por lotes);
-- si no, te dice que lo guardes o se lo mandes por correo. Nunca se mueve
-- nada solo. Ajuste bolsas.queGuardar (de fábrica, encendido).
--   Gu.Sugerencias() -> { { bolsa, casilla, id, link, cantidad, motivo, para }, ... }
--   Gu.AlBanco() -> true si empezó a depositar
-- Misiones: C_QuestLog.GetNumQuestLogEntries / GetInfo (QuestLogDocumentation.lua).

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local D = M.Datos

local type, pairs, ipairs, tonumber, format = type, pairs, ipairs, tonumber, string.format

local Gu = {}
M.Guardar = Gu

local PIEDRA_HOGAR = 6948
local ORIGEN = { 0, 1, 2, 3, 4, 5 }
local MAX_MISIONES = 35

local function encendido() return M.Get("queGuardar") ~= false end

---------------------------------------------------------------------------
-- Las misiones de cada personaje (para los objetos que piden)
---------------------------------------------------------------------------

local function leerMisiones()
	local Q = C_QuestLog
	if not (Q and Q.GetNumQuestLogEntries and Q.GetInfo) then return nil end
	local n = M.Num(M.Llamar(Q.GetNumQuestLogEntries)) or 0
	local out = {}
	for i = 1, n do
		local info = M.Llamar(Q.GetInfo, i)
		if type(info) == "table" and not M.Leer(info.isHeader) then
			local q = M.Num(info.questID)
			if q and q > 0 then out[#out + 1] = q end
		end
		if #out >= MAX_MISIONES then break end
	end
	return out
end

function Gu.AnotarMisiones()
	local r = D.Actual()
	local lista = leerMisiones()
	if not (r and lista) then return end
	r.misiones = lista
end

local pendiente = false
local function anotarLuego()
	if pendiente then return end
	pendiente = true
	M.Luego(3, function()
		pendiente = false
		Gu.AnotarMisiones()
	end)
end
A.RegisterEvent("QUEST_LOG_UPDATE", anotarLuego)
A.OnLogin(anotarLuego)

-- Los objetos que piden las misiones de tus otros personajes (el Codex se
-- carga al ver la página): -> { [itemID] = nombre del personaje }, { [itemID] = true } (los tuyos)
local function objetosDeMisiones()
	local X = A.Codex
	if not (X and X.Quest) then return {}, {} end
	-- Sin misiones de otros personajes no hace falta cargar el Codex.
	local hay = false
	for _, p in ipairs(D.Lista()) do
		if not D.EsActual(p.clave) and not p.otraFaccion and type(p.r.misiones) == "table" and #p.r.misiones > 0 then hay = true break end
	end
	if not hay then return {}, {} end
	if not (X.IsLoaded and X.IsLoaded()) then
		if M.EnCombate() or not X.Load then return {}, {} end
		local ok, si = pcall(X.Load)
		if not (ok and si) then return {}, {} end
	end
	local deOtros, mios = {}, {}
	for _, p in ipairs(D.Lista()) do
		local propio = D.EsActual(p.clave)
		for _, q in ipairs(type(p.r.misiones) == "table" and p.r.misiones or {}) do
			local ok, rec = pcall(X.Quest, q)
			if ok and type(rec) == "table" then
				for _, o in ipairs(rec.objectives or {}) do
					if o.type == "item" and type(o.id) == "number" then
						if propio then mios[o.id] = true elseif not deOtros[o.id] and not p.otraFaccion then deOtros[o.id] = p.r.nombre or p.clave end
					end
				end
			end
		end
	end
	return deOtros, mios
end

---------------------------------------------------------------------------
-- Lo que sugiere
---------------------------------------------------------------------------

local function guardaLaGuia(id)
	local Q = A.QoL
	local kept = Q and Q.Kept
	return type(kept) == "function" and M.Leer(M.Llamar(kept, id)) ~= nil
end

-- Las recetas de tus otros personajes que usan el objeto: -> "Lobato (Herrería)" | nil
local function paraOtro(id)
	local C = rawget(_G, "AlfaComercio")
	if not (type(C) == "table" and type(C.Usan) == "function") then return nil end
	local lista = M.Llamar(C.Usan, id)
	if type(lista) ~= "table" or #lista == 0 then return nil end
	for _, e in ipairs(lista) do
		if e.propio then return nil end -- este personaje también lo usa: se queda
	end
	local e = lista[1]
	-- 1.3.9: también el nombre solo (para la carta de «Lo que me sobra», Sobra.lua).
	if e.profesion then return format(L["%s (%s)"], tostring(e.quien or "?"), tostring(e.profesion)), e.quien end
	return tostring(e.quien or "?"), e.quien
end

-- ¿Equipo que se liga al equiparlo y tu clase no usa?
local function boeQueNoUsas(info, link)
	if M.Leer(info.isBound) then return false end
	local q = M.Num(info.quality) or 0
	if q < 2 or not link then return false end
	local CI = C_Item
	if not (CI and CI.GetItemInfoInstant) then return false end
	local _, _, _, loc = M.Llamar(CI.GetItemInfoInstant, link)
	loc = M.Texto(loc)
	if not loc or loc == "" or loc == "INVTYPE_NON_EQUIP_IGNORE" or loc == "INVTYPE_BAG" then return false end
	local G = A.Gear
	if not (G and type(G.CompareToEquipped) == "function") then return false end
	local r = M.Llamar(G.CompareToEquipped, link)
	return type(r) == "table" and r.usable == false
end

function Gu.Sugerencias()
	local out = {}
	if not encendido() then return out end
	local C = C_Container
	if not C then return out end
	local deOtros, mios = objetosDeMisiones()
	for _, bolsa in ipairs(ORIGEN) do
		for s = 1, M.Num(M.Llamar(C.GetContainerNumSlots, bolsa)) or 0 do
			local info = M.Llamar(C.GetContainerItemInfo, bolsa, s)
			local id = type(info) == "table" and M.Num(info.itemID)
			if id and id ~= PIEDRA_HOGAR and not guardaLaGuia(id) and not mios[id] then
				local link = M.Texto(info.hyperlink)
				local x = { bolsa = bolsa, casilla = s, id = id, link = link, cantidad = M.Num(info.stackCount) or 1, calidad = M.Num(info.quality) }
				local quien = deOtros[id]
				if quien then
					x.motivo, x.para, x.tipo = format(L["Lo pide una misión de %s."], quien), quien, "mision"
					x.nombre = quien
				else
					local otro, quien2 = paraOtro(id)
					if otro then
						x.motivo, x.para, x.tipo = format(L["Para las recetas de %s."], otro), otro, "oficio"
						x.nombre = type(quien2) == "string" and quien2 or nil
					elseif boeQueNoUsas(info, link) then
						x.motivo, x.tipo = L["Tu clase no lo usa: guárdalo para otro personaje o súbelo a la subasta."], "equipo"
					end
				end
				if x.motivo then out[#out + 1] = x end
			end
		end
	end
	return out
end

function Gu.AlBanco(lista)
	lista = lista or Gu.Sugerencias()
	if #lista == 0 then return false end
	if not D.BancoAbierto() then
		N.Imprimir(L["Para depositar, habla con un banquero."])
		return false
	end
	if M.EnCombate() then
		N.Imprimir(L["Se puede al salir de combate."])
		return false
	end
	local plan = M.Banco.PlanCasillas(lista)
	if #plan.lista == 0 then
		N.Imprimir(L["El banco está lleno: compra otra casilla o pon una bolsa más grande en el banco."])
		return false
	end
	return M.Banco.Mandar(plan) and true or false
end

-- 1.2.9: Lya sabe contar «Ponte esto» y «Qué guardar» (Pregúntale a Lya).
A.OnLogin(function()
	local Lya = rawget(_G, "AlfaLya")
	if type(Lya) ~= "table" or type(Lya.Ensenar) ~= "function" then return end
	for _, p in ipairs({
		{ id = "bolsas.ponteEsto", icono = "ic-nivel", pregunta = L["¿Cómo sé si lo que me cayó es mejor?"],
			respuesta = L["Si te llega equipo mejor que lo que llevas, te aviso con «Ponte esto» y un botón para ponértelo. Solo con tu clic, y nunca en combate."] },
		{ id = "bolsas.guardar", icono = "ic-bolsas", pregunta = L["¿Qué guardo en el banco?"],
			respuesta = L["En Bolsas, «Qué guardar» te dice lo que sirve más en el banco: materiales de las recetas de tus otros personajes, lo que piden sus misiones y equipo que tu clase no usa. Con un banquero, «Al banco» y listo."] },
		-- 1.3.0
		{ id = "bolsas.conjuntos", icono = "ic-personaje", pregunta = L["¿Cómo cambio de equipo rápido?"],
			respuesta = L["Guarda lo que llevas como un conjunto (curar, daño, pesca…) desde el botón de tus bolsas o en Bolsas, y póntelo con un clic. En combate te lo pongo al terminar."] },
		{ id = "bolsas.comparar", icono = "ic-nivel", pregunta = L["¿Qué gano con esta pieza?"],
			respuesta = L["Pásale el ratón: en su cuadro te digo lo que ganas y lo que pierdes contra lo que llevas puesto, con números. Lo primero es lo que más le sirve a tu clase."] },
		{ id = "bolsas.buscarTodos", icono = "ic-buscar", pregunta = L["¿Quién de mis personajes tiene esto?"],
			respuesta = L["En Bolsas, «Buscar en todos tus personajes» revisa bolsas, bancos y equipo de todos, con filtros de tipo, calidad y personaje."] },
		{ id = "bolsas.acomodar", icono = "ic-bolsas", pregunta = L["¿Cómo limpio mis bolsas rápido?"],
			respuesta = L["Con un comerciante o un banquero abierto, «Acomodar» en tus bolsas vende tu chatarra o guarda tus materiales en el banco. Un clic, y otro para detenerlo."] },
	}) do
		p.modulo = M.ID
		pcall(Lya.Ensenar, p)
	end
end)

---------------------------------------------------------------------------
-- Cuántos tienes de un objeto (para la lista de compras de Comercio)
--   AlfaBolsas.Cuantos(id) -> tuyos (bolsas + banco), en bolsas, en banco, en toda la cuenta
-- Las bolsas, en vivo; el banco, en vivo con el banquero o de la última foto.
---------------------------------------------------------------------------

-- 1.3.1: lo que llevas, contado en una sola pasada (id -> cantidad) y guardado
-- hasta que cambian tus bolsas o el banco (BAG_UPDATE, PLAYERBANKSLOTS_CHANGED,
-- BANKFRAME_*) o pasa el cuadro. Antes cada material de la lista de compras y
-- cada reactivo de «Fabricar» recorría todas tus bolsas (y el banco) otra vez.
local conteo = {} -- "bolsas" | "banco" -> { t = GetTime(), [id] = cantidad }

local function ahora() return GetTime and GetTime() or 0 end

local function contar(cual)
	local hit = conteo[cual]
	if hit and hit.t == ahora() then return hit end
	local C = C_Container
	local t = { t = ahora() }
	if C then
		for _, b in ipairs(cual == "banco" and D.BANCO or ORIGEN) do
			for s = 1, M.Num(M.Llamar(C.GetContainerNumSlots, b)) or 0 do
				local info = M.Llamar(C.GetContainerItemInfo, b, s)
				local id = type(info) == "table" and M.Num(info.itemID)
				if id then t[id] = (t[id] or 0) + (M.Num(info.stackCount) or 1) end
			end
		end
	end
	conteo[cual] = t
	return t
end

function Gu.Olvidar(cual)
	if cual then conteo[cual] = nil else conteo.bolsas, conteo.banco = nil, nil end
end
A.RegisterEvent("BAG_UPDATE", function(_, bolsa)
	bolsa = M.Num(bolsa)
	if bolsa and D.EsBanco[bolsa] then conteo.banco = nil
	elseif bolsa and D.EsBolsa[bolsa] then conteo.bolsas = nil
	else Gu.Olvidar() end
end)
A.RegisterEvent("BAG_UPDATE_DELAYED", function() Gu.Olvidar() end)
A.RegisterEvent("BAG_CONTAINER_UPDATE", function() Gu.Olvidar() end)
A.RegisterEvent("PLAYERBANKSLOTS_CHANGED", function() conteo.banco = nil end)
A.RegisterEvent("BANKFRAME_OPENED", function() conteo.banco = nil end)
A.RegisterEvent("BANKFRAME_CLOSED", function() conteo.banco = nil end)

function Gu.Cuantos(id)
	id = tonumber(id)
	if not id or id == 0 then return 0, 0, 0, 0 end
	local bolsas = contar("bolsas")[id] or 0
	local bancoFoto, otros = D.Sumas(id)
	local banco = D.BancoAbierto() and (contar("banco")[id] or 0) or bancoFoto
	return bolsas + banco, bolsas, banco, bolsas + banco + otros
end

AlfaBolsas = type(rawget(_G, "AlfaBolsas")) == "table" and rawget(_G, "AlfaBolsas") or {}
AlfaBolsas.Cuantos = Gu.Cuantos
-- 1.3.8: quién de tus otros personajes tiene un objeto (para la lista de compras
-- de Comercio): -> { { nombre, clase, bolsas, banco, equipo }, ... } (sin el actual)
AlfaBolsas.QuienTiene = function(id)
	local out = {}
	local ok, _, partes = pcall(D.Conteo, id)
	if not ok or type(partes) ~= "table" then return out end
	local yo = D.Clave()
	for _, p in ipairs(partes) do
		if p.clave ~= yo then
			local r = type(p.r) == "table" and p.r or {}
			out[#out + 1] = { nombre = r.nombre or p.clave, clase = r.clase, bolsas = p.bolsas or 0, banco = p.banco or 0, equipo = p.equipo or 0, otraFaccion = p.otraFaccion }
		end
	end
	return out
end
AlfaBolsas.QueGuardar = Gu.Sugerencias
