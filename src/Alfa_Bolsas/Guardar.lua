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
		if not D.EsActual(p.clave) and type(p.r.misiones) == "table" and #p.r.misiones > 0 then hay = true break end
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
						if propio then mios[o.id] = true elseif not deOtros[o.id] then deOtros[o.id] = p.r.nombre or p.clave end
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
	if e.profesion then return format(L["%s (%s)"], tostring(e.quien or "?"), tostring(e.profesion)) end
	return tostring(e.quien or "?")
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
				else
					local otro = paraOtro(id)
					if otro then
						x.motivo, x.para, x.tipo = format(L["Para las recetas de %s."], otro), otro, "oficio"
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
		N.Imprimir(L["No se puede en combate."])
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
			respuesta = L["Guarda lo que llevas como un conjunto (curar, daño, pesca...) desde el botón de tus bolsas o en Bolsas, y póntelo con un clic. En combate te lo pongo al terminar."] },
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

local function enVivo(bolsas, id)
	local C = C_Container
	local n = 0
	if not C then return 0 end
	for _, b in ipairs(bolsas) do
		for s = 1, M.Num(M.Llamar(C.GetContainerNumSlots, b)) or 0 do
			local info = M.Llamar(C.GetContainerItemInfo, b, s)
			if type(info) == "table" and M.Num(info.itemID) == id then n = n + (M.Num(info.stackCount) or 1) end
		end
	end
	return n
end

function Gu.Cuantos(id)
	id = tonumber(id)
	if not id then return 0, 0, 0, 0 end
	local bolsas = enVivo(ORIGEN, id)
	local banco = 0
	local total, partes = D.Conteo(id)
	if D.BancoAbierto() then
		banco = enVivo(D.BANCO, id)
	else
		for _, p in ipairs(partes) do
			if D.EsActual(p.clave) then banco = p.banco end
		end
	end
	local otros = 0
	for _, p in ipairs(partes) do
		if not D.EsActual(p.clave) then otros = otros + p.bolsas + p.banco + p.equipo end
	end
	return bolsas + banco, bolsas, banco, bolsas + banco + otros
end

AlfaBolsas = type(rawget(_G, "AlfaBolsas")) == "table" and rawget(_G, "AlfaBolsas") or {}
AlfaBolsas.Cuantos = Gu.Cuantos
AlfaBolsas.QueGuardar = Gu.Sugerencias
