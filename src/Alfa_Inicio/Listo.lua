-- Alfa - Inicio: listo para la mazmorra (toxic3000 / La Jauría). GPL-3.0. -- 1.2.9
--
-- Antes de una mazmorra, lo que hace falta llevar: el equipo reparado
-- (inicio.listoDur), espacio en las bolsas (inicio.listoBolsas), comida y,
-- si usas maná, agua (inicio.listoComida), la munición del cazador y los
-- componentes de tu clase (solo los de hechizos que ya sabes). Lo que falta
-- sale en un aviso (por Lya si está a la vista) con la flecha a donde se
-- consigue lo primero: reparar, comida, munición, componentes o un vendedor.
--
-- Revisa sola (con inicio.listoAuto) al entrar a una mazmorra y al juntarse
-- un grupo de 4 o más; y cuando se pide (Revisar en Hoy, /alfa listo,
-- AlfaInicio.RevisarMazmorra). Nunca en combate: espera a que acabe.
--
--   M.Listo.Faltas() -> { { clave, texto, ir }, ... }   lo que falta, lo más urgente primero
--   M.Listo.Revisar(motivo, nombre) -> faltas            motivo: "boton" | "entrar" | "grupo"
--     (con "boton" también dice «¡Todo listo!»; sola, solo si falta algo)

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = N.Textos(M.EN)
local num, texto = M.num, M.texto

local type, ipairs, pairs, pcall, tonumber, format = type, ipairs, pairs, pcall, tonumber, string.format
local floor, max = math.floor, math.max

local Li = {}
M.Listo = Li

local function on(clave) return N.Get("inicio", clave) and true or false end
local function combate() return InCombatLockdown and InCombatLockdown() and true or false end
local function nivel() return num(UnitLevel and UnitLevel("player")) or 1 end

local function llamar(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d = pcall(fn, ...)
	if ok then return a, b, c, d end
	return nil
end

local function claseJugador()
	if not UnitClass then return nil end
	local _, file = UnitClass("player")
	return texto(file)
end

-- Los componentes de cada clase: el objeto, desde qué nivel, cuántos llevar
-- y los hechizos que lo piden (con uno sabido basta; sin forma de saberlo,
-- cuenta el nivel).
local COMPONENTES = {
	ROGUE = { { item = 5140, nivel = 22, min = 5, hechizos = { 1856, 1857, 11305 } } },          -- Polvo cegador (Esfumarse)
	MAGE = { { item = 17020, nivel = 56, min = 5, hechizos = { 23028 } } },                     -- Polvo arcano (Luminosidad Arcana)
	PRIEST = { { item = 17028, nivel = 48, min = 5, hechizos = { 21562, 21564 } } },            -- Vela sagrada (Rezo de entereza)
	SHAMAN = { { item = 17030, nivel = 30, min = 1, hechizos = { 20608 } } },                   -- Ankh (Reencarnación)
	PALADIN = { { item = 21177, nivel = 52, min = 5, hechizos = { 25782, 25916, 25894, 25918, 25890, 25898, 25899 } } }, -- Símbolo de reyes
	WARLOCK = { { item = 6265, nivel = 10, min = 3, comprar = false } },                         -- Fragmento de alma
	DRUID = {
		{ item = 17038, nivel = 60, min = 1, hechizos = { 20748 } }, { item = 17037, nivel = 50, min = 1, hechizos = { 20747 } },
		{ item = 17036, nivel = 40, min = 1, hechizos = { 20742 } }, { item = 17035, nivel = 30, min = 1, hechizos = { 20739 } },
		{ item = 17034, nivel = 20, min = 1, hechizos = { 20484 } },                                  -- semillas (Renacer)
		{ item = 17026, nivel = 60, min = 2, hechizos = { 21850 }, grupo = "don" }, { item = 17021, nivel = 50, min = 2, hechizos = { 21849 }, grupo = "don" },
	},
}
Li.COMPONENTES = COMPONENTES

local NOMBRES = {
	[5140] = L["Polvo cegador"], [17020] = L["Polvo arcano"], [17028] = L["Vela sagrada"], [17030] = L["Ankh"],
	[21177] = L["Símbolo de reyes"], [6265] = L["Fragmento de alma"], [17034] = L["Semilla de arce"],
	[17035] = L["Semilla de Tuercespina"], [17036] = L["Semilla de fresno"], [17037] = L["Semilla de carpe"],
	[17038] = L["Semilla de palo de hierro"], [17021] = L["Bayas silvestres"], [17026] = L["Raíz espinosa silvestre"],
}

local function nombreObjeto(id)
	local n = GetItemInfo and texto((llamar(GetItemInfo, id)))
	return n or NOMBRES[id] or ("#" .. tostring(id))
end

local function sabe(lista)
	local f = rawget(_G, "IsPlayerSpell") or rawget(_G, "IsSpellKnown")
	if type(f) ~= "function" or not lista then return nil end
	for _, id in ipairs(lista) do
		if llamar(f, id) then return true end
	end
	return false
end

local function cuantos(id)
	return GetItemCount and (num(llamar(GetItemCount, id)) or 0) or 0
end

-- Los componentes que te faltan: { { item, tienes, min, comprar } }.
function Li.Componentes()
	local lv = nivel()
	local out, grupos = {}, {}
	for _, c in ipairs(COMPONENTES[claseJugador() or ""] or {}) do
		local g = c.grupo or "base"
		if not grupos[g] and lv >= c.nivel then
			local s = sabe(c.hechizos)
			if s == true or (s == nil) or not c.hechizos then
				grupos[g] = true
				local n = cuantos(c.item)
				if n < c.min then out[#out + 1] = { item = c.item, tienes = n, min = c.min, comprar = c.comprar ~= false } end
			end
		end
	end
	return out
end

-- La munición del cazador: cuántas lleva y si son flechas o balas.
function Li.Municion()
	if claseJugador() ~= "HUNTER" then return nil end
	local n = GetInventoryItemCount and num(llamar(GetInventoryItemCount, "player", 0)) or nil
	if not n then return nil end
	local tipo = "arrows"
	local link = GetInventoryItemLink and llamar(GetInventoryItemLink, "player", 18)
	local Ci = rawget(_G, "C_Item")
	local inst = (Ci and Ci.GetItemInfoInstant) or rawget(_G, "GetItemInfoInstant")
	if link and inst then
		local _, _, _, _, _, clase, sub = llamar(inst, link)
		if num(clase) == 2 and num(sub) == 3 then tipo = "bullets" end -- armas de fuego
	end
	return n, tipo
end

---------------------------------------------------------------------------
-- Lo que falta
---------------------------------------------------------------------------

local IR = {
	repair = L["Llévame a reparar"], food = L["Llévame a comprar comida"], arrows = L["Llévame por flechas"],
	bullets = L["Llévame por balas"], reagents = L["Llévame por componentes"], vendor = L["Llévame a un vendedor"],
}
Li.IR = IR

function Li.Faltas()
	local R, Co = M.Rec, M.Comida
	local faltas = {}
	-- El equipo.
	local dur = tonumber(N.Get("inicio", "listoDur")) or 50
	local lista = R and R.LeerDurabilidad() or {}
	local peor = lista[1]
	if peor and peor.pct < dur then
		local pct = floor(peor.pct + 0.5)
		faltas[#faltas + 1] = { clave = "reparar", ir = "repair",
			texto = pct <= 0 and format(L["%s está rota"], R.NombrePieza(peor.slot) or R.NombreRanura(peor.slot))
				or format(L["Tu equipo está al %d %%: repara antes de entrar"], pct) }
	end
	-- Comida y agua.
	local minimo = tonumber(N.Get("inicio", "listoComida")) or 10
	if Co then
		local comida, agua = Co.Contar()
		local s = Co.Sugerencia()
		if comida < minimo then
			faltas[#faltas + 1] = { clave = "comida", ir = "food",
				texto = format(L["Comida: llevas %d (mejor %d o más). A tu nivel: %s"], comida, minimo, Co.Nombre(s.comida)) }
		end
		if Co.NecesitaAgua() and agua < minimo then
			faltas[#faltas + 1] = { clave = "agua", ir = "food",
				texto = format(L["Agua: llevas %d (mejor %d o más). A tu nivel: %s"], agua, minimo, Co.Nombre(s.agua)) }
		end
	end
	-- La munición.
	local mun, tipo = Li.Municion()
	if mun then
		local quiere = nivel() >= 20 and 400 or 200
		if mun < quiere then
			faltas[#faltas + 1] = { clave = "municion", ir = tipo,
				texto = format(tipo == "bullets" and L["Balas: llevas %d (mejor %d o más)"] or L["Flechas: llevas %d (mejor %d o más)"], mun, quiere) }
		end
	end
	-- Los componentes.
	for _, c in ipairs(Li.Componentes()) do
		faltas[#faltas + 1] = { clave = "componente", ir = c.comprar and "reagents" or nil,
			texto = c.comprar and format(L["%s: llevas %d de %d"], nombreObjeto(c.item), c.tienes, c.min)
				or format(L["%s: llevas %d de %d (los juntas con Drenar alma)"], nombreObjeto(c.item), c.tienes, c.min) }
	end
	-- Las bolsas.
	local libres = R and R.Bolsas() or nil
	local quiere = tonumber(N.Get("inicio", "listoBolsas")) or 6
	if libres and libres < quiere then
		faltas[#faltas + 1] = { clave = "bolsas", ir = "vendor",
			texto = libres == 1 and L["Bolsas: te queda 1 espacio para el botín"] or format(L["Bolsas: te quedan %d espacios para el botín"], libres) }
	end
	return faltas
end

local function primeraIda(faltas)
	for _, f in ipairs(faltas) do
		if f.ir then return f.ir end
	end
	return nil
end

function Li.Revisar(motivo, nombre)
	motivo = motivo or "boton"
	if combate() then
		N.FueraDeCombate("inicio.listo", function() Li.Revisar(motivo, nombre) end)
		return nil
	end
	local faltas = Li.Faltas()
	Li.ultima = faltas
	if A.Hidden and A.Hidden() and motivo ~= "boton" then return faltas end
	if #faltas == 0 then
		if motivo == "boton" then
			K.Aviso({ titulo = L["¡Todo listo para la mazmorra!"], lobo = "aullando", tono = "exito", duracion = 6,
				texto = L["Equipo reparado, comida, espacio y lo de tu clase: a cazar con la manada."] })
		end
		return faltas
	end
	local lineas = {}
	for i, f in ipairs(faltas) do
		if i > 5 then break end
		lineas[#lineas + 1] = "\194\183 " .. f.texto
	end
	local ir = primeraIda(faltas)
	local titulo = nombre and format(L["Antes de %s te falta:"], nombre) or L["Antes de la mazmorra te falta:"]
	K.Aviso({ titulo = titulo, texto = table.concat(lineas, "\n"), icono = "ic-mazmorra", tono = "aviso", duracion = 14,
		accion = ir and { texto = IR[ir] or L["Llévame"], alClic = function() if M.Rec then M.Rec.IrA(ir) end end } or nil })
	return faltas
end

---------------------------------------------------------------------------
-- Sola: al entrar a una mazmorra y al juntarse un grupo
---------------------------------------------------------------------------

local dentro = false  -- ya avisó en esta entrada a la mazmorra
local enGrupo = false -- ya avisó con este grupo

local function enMazmorra()
	if not IsInInstance then return false end
	local _, tipo = IsInInstance()
	return tipo == "party"
end

local function nombreZona()
	local z = GetRealZoneText and texto(llamar(GetRealZoneText))
	return z ~= "" and z or nil
end

local function alEntrar()
	if not enMazmorra() then
		dentro = false
		return
	end
	if dentro or not on("listoAuto") then return end
	dentro = true
	A.After(3, function() Li.Revisar("entrar", nombreZona()) end)
end
Li.AlEntrar = alEntrar

local function alGrupo()
	local n = GetNumGroupMembers and num(llamar(GetNumGroupMembers)) or 0
	local raid = IsInRaid and llamar(IsInRaid) or false
	if n < 2 then
		enGrupo = false
		return
	end
	if enGrupo or raid or n < 4 or nivel() < 10 or not on("listoAuto") then return end
	enGrupo = true
	A.After(2, function() Li.Revisar("grupo") end)
end
Li.AlGrupo = alGrupo

-- Para el banco: vuelve a empezar.
function Li.Reiniciar() dentro, enGrupo = false, false end

A.RegisterEvent("PLAYER_ENTERING_WORLD", alEntrar)
A.RegisterEvent("ZONE_CHANGED_NEW_AREA", alEntrar)
A.RegisterEvent("GROUP_ROSTER_UPDATE", alGrupo)

A.RegisterCommand("listo", function() Li.Revisar("boton") end, L["revisa si estás listo para la mazmorra"], true)
