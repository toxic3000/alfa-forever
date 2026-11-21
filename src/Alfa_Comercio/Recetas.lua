-- Alfa - Comercio: recetas que conoces y Encantamiento (toxic3000 / La Jauría). GPL-3.0.
--
-- Al abrir la ventana de una profesión se guardan sus recetas aprendidas:
-- reactivos (con cantidades) y producto. Se guardan por personaje en los
-- datos de la cuenta, así un consejo puede decir "créalo con tu otro
-- personaje" cuando está en el mismo reino y facción.
--
-- API (Blizzard_APIDocumentationGenerated/TradeSkillUIDocumentation.lua y
-- TradeSkillUITypesDocumentation.lua):
--   C_TradeSkillUI.GetRecipeInfo(id) -> TradeSkillRecipeInfo (learned, name)
--   C_TradeSkillUI.GetRecipeSchematic(id, false) -> CraftingRecipeSchematic
--       (outputItemID, quantityMin, quantityMax, reagentSlotSchematics:
--        reagents[].itemID, quantityRequired, reagentType, required)
--   C_TradeSkillUI.GetRecipeOutputItemData(id) -> CraftingRecipeOutputInfo.itemID
--   C_TradeSkillUI.GetBaseProfessionInfo() -> ProfessionInfo (professionName,
--       profession, skillLevel)
--   TRADE_SKILL_SHOW, TRADE_SKILL_LIST_UPDATE, TRADE_SKILL_DATA_SOURCE_CHANGED
--   Enum.CraftingReagentType.Basic = 1, Enum.Profession.Enchanting = 9
--   (ProfessionConstantsDocumentation.lua).
-- La lista de recetas: C_TradeSkillUI.GetFilteredRecipeIDs, la que usa la
-- ventana de profesiones de Forever (Blizzard_ProfessionsTemplates/
-- Blizzard_Professions.lua); no figura en la documentación generada, por eso
-- va protegida. GetAllRecipeIDs se usa primero si existe. IsTradeSkillReady,
-- IsTradeSkillLinked, IsTradeSkillGuild e IsNPCCrafting también vienen de ese
-- código de Blizzard.
-- Encantamiento sin abrir la ventana: Alfa.Compat.GetSkillRank(333) del motor.

local _, M = ...
local N = AlfaNucleo
local A = N.A

local type, pairs, ipairs, next, tostring = type, pairs, ipairs, next, tostring
local BASICO = 1
local ENCANTAMIENTO = 9

---------------------------------------------------------------------------
-- Datos
---------------------------------------------------------------------------

local function datos()
	local d = M.Datos()
	d.recetas = type(d.recetas) == "table" and d.recetas or {}
	d.encantar = type(d.encantar) == "table" and d.encantar or {}
	return d
end

local function miFicha()
	local d = datos()
	local clave = M.ClavePersonaje()
	local f = d.recetas[clave]
	if type(f) ~= "table" then
		f = {}
		d.recetas[clave] = f
	end
	f.rk = M.ClaveReino()
	f.nombre = M.NombrePersonaje()
	f.r = type(f.r) == "table" and f.r or {}
	f.profs = type(f.profs) == "table" and f.profs or {}
	return f
end

-- Personajes del mismo reino y facción (el actual primero):
-- { { clave, nombre, ficha, propio }, ... }
function M.Personajes()
	local d = datos()
	local rk, yo = M.ClaveReino(), M.ClavePersonaje()
	local out = {}
	for clave, f in pairs(d.recetas) do
		if type(f) == "table" and f.rk == rk then
			out[#out + 1] = { clave = clave, nombre = f.nombre or clave, ficha = f, propio = clave == yo }
		end
	end
	table.sort(out, function(a, b)
		if a.propio ~= b.propio then return a.propio end
		return tostring(a.nombre) < tostring(b.nombre)
	end)
	return out
end

---------------------------------------------------------------------------
-- Índice: reactivo -> recetas que lo usan (se rehace cuando cambian)
---------------------------------------------------------------------------

local indice, indiceVersion

function M.RecetasCambiaron()
	indice = nil
	M.Cambio()
end

-- { [itemID] = { { rec, id, quien = nombre, propio = bool }, ... } }
function M.IndiceReactivos()
	local rk = M.ClaveReino()
	if indice and indiceVersion == rk then return indice end
	indice, indiceVersion = {}, rk
	for _, p in ipairs(M.Personajes()) do
		for rid, rec in pairs(p.ficha.r) do
			if type(rec) == "table" and type(rec.r) == "table" then
				for i = 1, #rec.r, 2 do
					local id = rec.r[i]
					if type(id) == "number" then
						local lista = indice[id]
						if not lista then
							lista = {}
							indice[id] = lista
						end
						lista[#lista + 1] = { rec = rec, id = rid, quien = p.nombre, propio = p.propio }
					end
				end
			end
		end
	end
	return indice
end

-- Todas las recetas de tus personajes de este reino: { { rec, id, quien, propio }, ... }
function M.TodasLasRecetas()
	local out = {}
	for _, p in ipairs(M.Personajes()) do
		for rid, rec in pairs(p.ficha.r) do
			if type(rec) == "table" then
				out[#out + 1] = { rec = rec, id = rid, quien = p.nombre, propio = p.propio }
			end
		end
	end
	return out
end

---------------------------------------------------------------------------
-- Encantamiento: habilidad del personaje actual y de los demás
---------------------------------------------------------------------------

function M.AnotarEncantamiento(nivel)
	local d = datos()
	local clave = M.ClavePersonaje()
	if type(nivel) == "number" and nivel > 0 then
		d.encantar[clave] = { rk = M.ClaveReino(), s = nivel, nombre = M.NombrePersonaje() }
	else
		d.encantar[clave] = nil
	end
end

local function leerEncantamiento()
	local C = A.Compat
	if not (C and C.GetSkillRank) then return end
	local ok, nivel = pcall(C.GetSkillRank, M.LINEA_ENCANTAMIENTO)
	if not ok then return end
	local antes = datos().encantar[M.ClavePersonaje()]
	M.AnotarEncantamiento(type(nivel) == "number" and nivel or 0)
	local ahora = datos().encantar[M.ClavePersonaje()]
	if (antes and antes.s) ~= (ahora and ahora.s) then M.Cambio() end
end

-- Mejor encantador del reino: nivel, nombre, propio (o nil).
function M.Encantador()
	local d = datos()
	local rk, yo = M.ClaveReino(), M.ClavePersonaje()
	local mejor
	for clave, e in pairs(d.encantar) do
		if type(e) == "table" and e.rk == rk and type(e.s) == "number" then
			local propio = clave == yo
			if not mejor or e.s > mejor.s or (e.s == mejor.s and propio) then
				mejor = { s = e.s, nombre = e.nombre or clave, propio = propio }
			end
		end
	end
	return mejor
end

function M.MiEncantamiento()
	local e = datos().encantar[M.ClavePersonaje()]
	return type(e) == "table" and e.s or 0
end

---------------------------------------------------------------------------
-- 1.3.1: olvidar a un personaje («Olvidar» en la página de Bolsas): sus
-- recetas y su Encantamiento. La clave es nombre-reino con el reino del juego
-- (GetRealmName, con espacios); también se reconoce sin espacios ni guiones,
-- como la clave de Bolsas (GetNormalizedRealmName). Tu personaje de ahora no se
-- olvida. -> true si quitó algo
---------------------------------------------------------------------------

local function sinEspacios(s) return (tostring(s):gsub("[%s%-]", "")):lower() end

function M.OlvidarPersonaje(nombre, reino)
	if type(nombre) ~= "string" or nombre == "" then return false end
	local d = datos()
	local yo = M.ClavePersonaje()
	local exacta = type(reino) == "string" and reino ~= "" and (nombre .. "-" .. reino) or nil
	local parecida = exacta and sinEspacios(exacta) or nil
	local quitado = false
	for _, t in ipairs({ d.recetas, d.encantar }) do
		for clave in pairs(t) do
			if clave ~= yo and type(clave) == "string" and (clave == exacta or (parecida and sinEspacios(clave) == parecida)) then
				t[clave] = nil
				quitado = true
			end
		end
	end
	if quitado then M.RecetasCambiaron() end
	return quitado
end

AlfaComercio = type(AlfaComercio) == "table" and AlfaComercio or {}
AlfaComercio.OlvidarPersonaje = M.OlvidarPersonaje

---------------------------------------------------------------------------
-- Lectura de la ventana de profesión
---------------------------------------------------------------------------

local function api()
	local TS = C_TradeSkillUI
	if type(TS) ~= "table" or type(TS.GetRecipeInfo) ~= "function" or type(TS.GetRecipeSchematic) ~= "function" then return nil end
	return TS
end

local function si(fn)
	if type(fn) ~= "function" then return false end
	local ok, v = pcall(fn)
	return ok and v and true or false
end

local function listaRecetas(TS)
	local f = TS.GetAllRecipeIDs or TS.GetFilteredRecipeIDs
	if type(f) ~= "function" then return nil, false end
	local ok, ids = pcall(f)
	if not ok or type(ids) ~= "table" then return nil, false end
	return ids, f == TS.GetAllRecipeIDs
end

-- Una receta aprendida -> registro guardado, o nil (encantamientos sin
-- objeto, reactivos de moneda, datos incompletos).
local function leerReceta(TS, id, profesion)
	local ok, info = pcall(TS.GetRecipeInfo, id)
	if not ok or type(info) ~= "table" or not info.learned then return nil end
	local ok2, sch = pcall(TS.GetRecipeSchematic, id, false)
	if not ok2 or type(sch) ~= "table" then return nil end
	local salida = sch.outputItemID
	if type(salida) ~= "number" and type(TS.GetRecipeOutputItemData) == "function" then
		local ok3, out = pcall(TS.GetRecipeOutputItemData, id)
		if ok3 and type(out) == "table" and type(out.itemID) == "number" then salida = out.itemID end
	end
	if type(salida) ~= "number" then return nil end
	local reactivos = {}
	local slots = type(sch.reagentSlotSchematics) == "table" and sch.reagentSlotSchematics or {}
	for i = 1, #slots do
		local s = slots[i]
		if type(s) == "table" and (s.reagentType == nil or s.reagentType == BASICO) and s.required ~= false then
			local r1 = type(s.reagents) == "table" and s.reagents[1]
			local cant = s.quantityRequired
			if type(r1) ~= "table" or type(cant) ~= "number" or cant <= 0 then return nil end
			if type(r1.itemID) ~= "number" then return nil end -- moneda u otra cosa
			if r1.itemID == salida then return nil end -- recrear
			reactivos[#reactivos + 1] = r1.itemID
			reactivos[#reactivos + 1] = cant
		end
	end
	if #reactivos == 0 then return nil end
	local qmin = type(sch.quantityMin) == "number" and sch.quantityMin or 1
	local qmax = type(sch.quantityMax) == "number" and sch.quantityMax or qmin
	if qmin < 1 then qmin = 1 end
	if qmax < qmin then qmax = qmin end
	return {
		n = (type(sch.name) == "string" and sch.name) or (type(info.name) == "string" and info.name) or "?",
		o = salida, q = (qmin + qmax) / 2, r = reactivos, p = profesion,
	}
end

local ventanaAbierta = false
-- 1.3.7: la última lectura (profesión, cuántas recetas, habilidad). Al fabricar,
-- el juego manda TRADE_SKILL_LIST_UPDATE con cada pieza; si la lista no cambió
-- no se relee toda la profesión.
local ultimaFirma
local forzar = false

local function leerVentana()
	local TS = api()
	if not TS or not ventanaAbierta then return end
	if InCombatLockdown and InCombatLockdown() then return end
	if type(TS.IsTradeSkillReady) == "function" and not si(TS.IsTradeSkillReady) then return end
	if si(TS.IsTradeSkillLinked) or si(TS.IsTradeSkillGuild) or si(TS.IsTradeSkillGuildMember) or si(TS.IsNPCCrafting) then return end
	local base
	if type(TS.GetBaseProfessionInfo) == "function" then
		local ok, b = pcall(TS.GetBaseProfessionInfo)
		if ok and type(b) == "table" then base = b end
	end
	local profesion = base and type(base.professionName) == "string" and base.professionName or "?"
	if base and base.profession == ENCANTAMIENTO and type(base.skillLevel) == "number" then
		M.AnotarEncantamiento(base.skillLevel)
	end
	local ids, completa = listaRecetas(TS)
	if not ids then return end
	local firma = profesion .. ":" .. #ids .. ":" .. tostring(base and base.skillLevel or "?") .. ":" .. tostring(completa)
	if firma == ultimaFirma and not forzar then return end
	local puesta = M.Tarea("recetas", function()
		local ficha = miFicha()
		local nuevas = {}
		for i = 1, #ids do
			local rec = leerReceta(TS, ids[i], profesion)
			if rec then nuevas[ids[i]] = rec end
			if i % 20 == 0 then M.Ceder() end
		end
		-- Con la lista completa se reemplaza la profesión; con la filtrada solo se suma.
		-- Si cerraste la ventana a mitad de la lectura, lo que faltó no se leyó:
		-- solo se suma, para no borrar recetas que sí tienes.
		if not ventanaAbierta then completa = false end
		ficha = miFicha()
		if completa and next(nuevas) then
			for rid, rec in pairs(ficha.r) do
				if type(rec) == "table" and rec.p == profesion and not nuevas[rid] then ficha.r[rid] = nil end
			end
		end
		for rid, rec in pairs(nuevas) do ficha.r[rid] = rec end
		if base and type(base.skillLevel) == "number" then ficha.profs[profesion] = base.skillLevel end
		M.RecetasCambiaron()
	end)
	if puesta then
		ultimaFirma, forzar = firma, false
	elseif ventanaAbierta then
		-- Ya había una lectura corriendo: esta no se pierde, se lee al terminar aquella.
		N.Una("comercio.recetasOtra", 1, leerVentana, { fueraDeCombate = true })
	end
end
M.LeerRecetas = leerVentana

-- 1.3.7: con el reloj de Alfa y nunca en combate (fueraDeCombate).
local function pedirLectura(siempre)
	if siempre == true then forzar = true end
	N.Una("comercio.recetas", 0.5, leerVentana, { fueraDeCombate = true })
end
local function pedirSiempre() pedirLectura(true) end

A.RegisterEvent("TRADE_SKILL_SHOW", function()
	ventanaAbierta = true
	pedirSiempre()
end)
A.RegisterEvent("TRADE_SKILL_CLOSE", function() ventanaAbierta = false end)
A.RegisterEvent("TRADE_SKILL_LIST_UPDATE", function() pedirLectura() end)
A.RegisterEvent("TRADE_SKILL_DATA_SOURCE_CHANGED", pedirSiempre)
A.RegisterEvent("NEW_RECIPE_LEARNED", pedirSiempre)
A.RegisterEvent("SKILL_LINES_CHANGED", function() leerEncantamiento() end)
A.OnLogin(leerEncantamiento)
