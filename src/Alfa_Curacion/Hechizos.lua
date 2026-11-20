-- Alfa - Curación: los hechizos, las ranuras del ratón y los preajustes
-- (toxic3000 / La Jauría). GPL-3.0.
--
-- Los hechizos se guardan por spellID (todos sus rangos conocidos de Forever,
-- el primero es el rango 1) y su nombre sale siempre del cliente con
-- C_Spell.GetSpellName: nunca se escribe un nombre a mano. Se lanzan por
-- nombre ("spell" = "Sanar"), así el juego usa tu rango más alto.
--
-- Un preajuste dice, para cada ranura del ratón, una lista de hechizos de
-- mejor a peor; la ranura toma el primero que conoces. Al aprender uno mejor,
-- Mapa.lua lo ofrece con un aviso: nunca lo cambia solo.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)
M.L = L

local ID = "curacion"
M.ID = ID
M.botones = {} -- los botones seguros de los marcos (Marcos.lua los registra)

local function secreto(v) return issecretvalue ~= nil and issecretvalue(v) and true or false end
M.Secreto = secreto
-- Un valor que se puede leer: ni secreto ni nil.
local function legible(v)
	if secreto(v) then return false end
	return v ~= nil
end
M.Legible = legible

---------------------------------------------------------------------------
-- Ranuras: botón del ratón (1 izquierdo, 2 derecho, 3 central) con o sin
-- una tecla. El prefijo es el de los atributos seguros ("shift-type1").
---------------------------------------------------------------------------

M.BOTONES = {
	{ s = "1", nombre = L["Izquierdo"], blizzard = "LeftButton" },
	{ s = "3", nombre = L["Central"], blizzard = "MiddleButton" },
	{ s = "2", nombre = L["Derecho"], blizzard = "RightButton" },
}
M.MODS = {
	{ p = "", nombre = L["Sin tecla"], corto = "" },
	{ p = "shift-", nombre = L["Mayús"], corto = L["Mayús"] },
	{ p = "ctrl-", nombre = L["Ctrl"], corto = L["Ctrl"] },
	{ p = "alt-", nombre = L["Alt"], corto = L["Alt"] },
}

M.RANURAS = {}
for _, md in ipairs(M.MODS) do
	for _, bt in ipairs(M.BOTONES) do M.RANURAS[#M.RANURAS + 1] = md.p .. bt.s end
end

-- "shift-1" -> "shift-", "1"
function M.Partes(ranura)
	local p, s = string.match(ranura or "", "^(.-)(%d)$")
	return p or "", s or "1"
end

local NOMBRE_BOTON = { ["1"] = L["clic izquierdo"], ["2"] = L["clic derecho"], ["3"] = L["clic central"] }
local NOMBRE_MOD = { [""] = "", ["shift-"] = L["Mayús"], ["ctrl-"] = L["Ctrl"], ["alt-"] = L["Alt"] }

-- "Mayús + clic izquierdo"
function M.NombreRanura(ranura)
	local p, s = M.Partes(ranura)
	local b = NOMBRE_BOTON[s] or "?"
	if p == "" then return b:sub(1, 1):upper() .. b:sub(2) end
	return string.format(L["%s + %s"], NOMBRE_MOD[p] or p, b)
end

-- "Menú" solo funciona donde el juego tiene su clic de interacción (izquierdo
-- y derecho sin tecla): ver Mapa.lua.
function M.PermiteMenu(ranura) return ranura == "1" or ranura == "2" end

---------------------------------------------------------------------------
-- Hechizos que sirven sobre aliados, por clase. { rango 1, rango 2, ... }
---------------------------------------------------------------------------

local H = {
	-- Sacerdote
	sanarInferior = { 2050, 2052, 2053 },
	sanar = { 2054, 2055, 6063, 6064 },
	sanacionSuperior = { 2060, 10963, 10964, 10965, 25314 },
	curacionRelampago = { 2061, 9472, 9473, 9474, 10915, 10916, 10917 },
	renovar = { 139, 6074, 6075, 6076, 6077, 6078, 10927, 10928, 10929, 25315 },
	escudo = { 17, 592, 600, 3747, 6065, 6066, 10898, 10899, 10900, 10901 },
	disiparMagia = { 527, 988 },
	curarEnfermedadS = { 528 },
	suprimirEnfermedad = { 552 },
	resurreccion = { 2006, 2010, 10880, 10881, 20770 },
	rezoSanacion = { 596, 996, 10960, 10961, 25316 },
	entereza = { 1243, 1244, 1245, 2791, 10937, 10938 },
	espirituDivino = { 14752, 14818, 14819, 27841 },
	proteccionSombras = { 976, 10957, 10958 },
	-- Druida
	toqueSanacion = { 5185, 5186, 5187, 5188, 5189, 6778, 8903, 9758, 9888, 9889, 25297 },
	rejuvenecimiento = { 774, 1058, 1430, 2090, 2091, 3627, 8910, 9839, 9840, 9841, 25299 },
	recrecimiento = { 8936, 8938, 8939, 8940, 8941, 9750, 9856, 9857, 9858 },
	eliminarMaldicion = { 2782 },
	curarVenenoD = { 8946 },
	suprimirVeneno = { 2893 },
	renacer = { 20484, 20739, 20742, 20747, 20748 },
	estimular = { 29166 },
	marcaSalvaje = { 1126, 5232, 6756, 5234, 8907, 9884, 9885 },
	espinas = { 467, 782, 1075, 8914, 9756, 9910 },
	-- Paladín
	luzSagrada = { 635, 639, 647, 1026, 1042, 3472, 10328, 10329, 25292 },
	destelloLuz = { 19750, 19939, 19940, 19941, 19942, 19943 },
	choqueSagrado = { 20473, 20929, 20930 },
	purificar = { 1152 },
	limpiar = { 4987 },
	redencion = { 7328, 10322, 10324, 20772, 20773 },
	imposicionManos = { 633, 2800, 10310 },
	bendicionProteccion = { 1022, 5599, 10278 },
	bendicionPoderio = { 19740, 19834, 19835, 19836, 19837, 19838, 25291 },
	bendicionSabiduria = { 19742, 19850, 19852, 19853, 19854, 25290 },
	bendicionReyes = { 20217 },
	bendicionSalvacion = { 1038 },
	-- Chamán
	olaSanacion = { 331, 332, 547, 913, 939, 959, 8005, 10395, 10396, 25357 },
	olaInferior = { 8004, 8008, 8010, 10466, 10467, 10468 },
	sanacionCadena = { 1064, 10622, 10623 },
	curarVenenoC = { 526 },
	curarEnfermedadC = { 2870 },
	espirituAncestral = { 2008, 20609, 20610, 20776, 20777 },
	respiracionAcuatica = { 131 },
	caminarAgua = { 546 },
	-- Mago
	intelectoArcano = { 1459, 1460, 1461, 10156, 10157 },
	eliminarMaldicionMenor = { 475 },
	amplificarMagia = { 1008, 8455, 10169, 10170 },
	atenuarMagia = { 604, 8450, 8451, 10173, 10174 },
	-- Brujo
	respiracionInagotable = { 5697 },
	detectarInvisibilidadSuperior = { 11743 },
	detectarInvisibilidad = { 2970 },
	detectarInvisibilidadMenor = { 132 },
	-- 1.3.0: las versiones de grupo de los buffs (cuentan como "ya lo tiene")
	rezoEntereza = { 21562, 21564 },
	donSalvaje = { 21849, 21850 },
	brillanteArcano = { 23028 },
	bendicionSuperiorPoderio = { 25782, 25916 },
	bendicionSuperiorSabiduria = { 25894, 25918 },
	bendicionSuperiorReyes = { 25898 },
	bendicionSuperiorSalvacion = { 25895 },
}
M.H = H

---------------------------------------------------------------------------
-- 1.3.0: para qué sirve cada hechizo (la lista «Tus clics»), qué perjuicios
-- quita y cuál es el buff de tu clase (el punto en los marcos).
---------------------------------------------------------------------------

M.CATEGORIAS = {
	{ id = "cura", nombre = L["Curas"] },
	{ id = "quitar", nombre = L["Quitar perjuicios"] },
	{ id = "buff", nombre = L["Buffs"] },
	{ id = "revivir", nombre = L["Revivir"] },
}

local CATEGORIA = {
	sanarInferior = "cura", sanar = "cura", sanacionSuperior = "cura", curacionRelampago = "cura", renovar = "cura",
	escudo = "cura", rezoSanacion = "cura", toqueSanacion = "cura", rejuvenecimiento = "cura", recrecimiento = "cura",
	luzSagrada = "cura", destelloLuz = "cura", choqueSagrado = "cura", imposicionManos = "cura",
	olaSanacion = "cura", olaInferior = "cura", sanacionCadena = "cura",
	disiparMagia = "quitar", curarEnfermedadS = "quitar", suprimirEnfermedad = "quitar", eliminarMaldicion = "quitar",
	curarVenenoD = "quitar", suprimirVeneno = "quitar", purificar = "quitar", limpiar = "quitar",
	curarVenenoC = "quitar", curarEnfermedadC = "quitar", eliminarMaldicionMenor = "quitar",
	resurreccion = "revivir", renacer = "revivir", redencion = "revivir", espirituAncestral = "revivir",
	entereza = "buff", espirituDivino = "buff", proteccionSombras = "buff", estimular = "buff", marcaSalvaje = "buff",
	espinas = "buff", bendicionProteccion = "buff", bendicionPoderio = "buff", bendicionSabiduria = "buff",
	bendicionReyes = "buff", bendicionSalvacion = "buff", respiracionAcuatica = "buff", caminarAgua = "buff",
	intelectoArcano = "buff", amplificarMagia = "buff", atenuarMagia = "buff", respiracionInagotable = "buff",
	detectarInvisibilidadSuperior = "buff", detectarInvisibilidad = "buff", detectarInvisibilidadMenor = "buff",
}
M.CATEGORIA = CATEGORIA

-- Qué tipo de perjuicio quita cada hechizo (los nombres del juego: dispelName).
M.QUITA = {
	disiparMagia = { Magic = true },
	curarEnfermedadS = { Disease = true }, suprimirEnfermedad = { Disease = true },
	eliminarMaldicion = { Curse = true }, eliminarMaldicionMenor = { Curse = true },
	curarVenenoD = { Poison = true }, suprimirVeneno = { Poison = true },
	purificar = { Poison = true, Disease = true },
	limpiar = { Poison = true, Disease = true, Magic = true },
	curarVenenoC = { Poison = true }, curarEnfermedadC = { Disease = true },
}
M.TIPOS = {
	Magic = { nombre = L["Magia"], color = { 0.2, 0.6, 1 }, icono = "Interface\\RaidFrame\\Raid-Icon-DebuffMagic" },
	Curse = { nombre = L["Maldición"], color = { 0.6, 0, 1 }, icono = "Interface\\RaidFrame\\Raid-Icon-DebuffCurse" },
	Disease = { nombre = L["Enfermedad"], color = { 0.6, 0.4, 0 }, icono = "Interface\\RaidFrame\\Raid-Icon-DebuffDisease" },
	Poison = { nombre = L["Veneno"], color = { 0, 0.6, 0 }, icono = "Interface\\RaidFrame\\Raid-Icon-DebuffPoison" },
}
M.ORDEN_TIPOS = { "Magic", "Curse", "Poison", "Disease" }

-- El buff de tu clase: grupos de claves; tenerlo de cualquiera de su grupo
-- cuenta. El primero de cada grupo que conoces es el que lanzas tú.
M.BUFF_CLASE = {
	PRIEST = { { "entereza", "rezoEntereza" } },
	DRUID = { { "marcaSalvaje", "donSalvaje" } },
	MAGE = { { "intelectoArcano", "brillanteArcano" } },
	PALADIN = { { "bendicionPoderio", "bendicionSabiduria", "bendicionReyes", "bendicionSalvacion",
		"bendicionSuperiorPoderio", "bendicionSuperiorSabiduria", "bendicionSuperiorReyes", "bendicionSuperiorSalvacion" } },
}

-- Las vendas, de la mejor a la peor (itemID).
M.VENDAS = { 14530, 14529, 8545, 8544, 6451, 6450, 3531, 3530, 2581, 1251 }

local CURANDEROS = { PRIEST = true, DRUID = true, PALADIN = true, SHAMAN = true }

-- Clase del jugador: "PRIEST", ...
function M.Clase()
	if not UnitClass then return nil end
	local ok, nombre, clase = pcall(UnitClass, "player")
	if not ok or secreto(clase) or type(clase) ~= "string" then return nil, nil end
	return clase, (not secreto(nombre) and type(nombre) == "string") and nombre or clase
end

function M.EsCurandero(clase) return CURANDEROS[clase or M.Clase() or ""] == true end

-- Nombre en el idioma del cliente ("Sanar" en esMX), o nil.
function M.NombreHechizo(id)
	if type(id) ~= "number" then return nil end
	local S = C_Spell
	if S and S.GetSpellName then
		local ok, n = pcall(S.GetSpellName, id)
		if ok and not secreto(n) and type(n) == "string" and n ~= "" then return n end
	end
	return nil
end

function M.IconoHechizo(id)
	if type(id) ~= "number" then return nil end
	local S = C_Spell
	if S and S.GetSpellTexture then
		local ok, icono = pcall(S.GetSpellTexture, id)
		if ok and not secreto(icono) and icono ~= nil then return icono end
	end
	return nil
end

-- ¿Conoces este spellID? Primero C_SpellBook.IsSpellKnown (Forever), luego
-- IsPlayerSpell (el que usa el motor para habilidades sin libro).
local function sabe(id)
	local B = C_SpellBook
	if B and B.IsSpellKnown then
		local ok, si = pcall(B.IsSpellKnown, id)
		if ok and not secreto(si) and si == true then return true end
	end
	if IsPlayerSpell then
		local ok, si = pcall(IsPlayerSpell, id)
		if ok and not secreto(si) and si == true then return true end
	end
	return false
end

-- Si Forever cambió algún spellID, el hechizo se busca en tu libro por su
-- nombre (el del rango 1 en el idioma del cliente).
local function enLibro(nombre)
	local B = C_SpellBook
	if not (nombre and B and B.FindSpellBookSlotForSpell) then return false end
	local ok, ranura = pcall(B.FindSpellBookSlotForSpell, nombre)
	return ok and not secreto(ranura) and type(ranura) == "number"
end

-- clave de H -> spellID con el que se reconoce (el primero que conoces), o nil.
-- 1.3.1: se recuerda (clave -> id, o false si no lo conoces) hasta que cambia
-- tu libro: la página y los marcos lo preguntan cientos de veces.
local conocidos = {}
local function buscar(ids)
	for i = 1, #ids do
		if sabe(ids[i]) then return ids[i] end
	end
	if enLibro(M.NombreHechizo(ids[1])) then return ids[1] end
	return nil
end

function M.Conocido(clave)
	local ids = H[clave]
	if not ids then return nil end
	local v = conocidos[clave]
	if v == nil then
		v = buscar(ids) or false
		conocidos[clave] = v
	end
	return v or nil
end

-- Tu libro cambió (aprendiste, subiste de nivel, entraste al mundo): se
-- vuelve a preguntar. Se registra aquí, antes que Mapa.lua y Marcos.lua,
-- para que sus avisos de SPELLS_CHANGED ya lean el libro nuevo.
function M.OlvidarConocidos()
	for k in pairs(conocidos) do conocidos[k] = nil end
end
for _, ev in ipairs({ "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD" }) do
	A.RegisterEvent(ev, M.OlvidarConocidos)
end

---------------------------------------------------------------------------
-- Preajustes: ranura -> lista de claves (de mejor a peor), o "target"/"menu".
---------------------------------------------------------------------------

local CURAR = {
	PRIEST = {
		["1"] = { "curacionRelampago", "sanar", "sanarInferior" },
		["2"] = { "renovar" },
		["3"] = { "sanacionSuperior", "sanar", "sanarInferior" },
		["shift-1"] = { "disiparMagia" },
		["shift-2"] = { "escudo" },
		["ctrl-1"] = { "resurreccion" },
		["ctrl-2"] = { "suprimirEnfermedad", "curarEnfermedadS" },
		["alt-1"] = { "entereza" },
		["alt-2"] = { "rezoSanacion" },
	},
	DRUID = {
		["1"] = { "toqueSanacion" },
		["2"] = { "rejuvenecimiento" },
		["3"] = { "recrecimiento" },
		["shift-1"] = { "eliminarMaldicion" },
		["shift-2"] = { "suprimirVeneno", "curarVenenoD" },
		["ctrl-1"] = { "renacer" },
		["ctrl-2"] = { "estimular" },
		["alt-1"] = { "marcaSalvaje" },
		["alt-2"] = { "espinas" },
	},
	PALADIN = {
		["1"] = { "luzSagrada" },
		["2"] = { "destelloLuz" },
		["3"] = { "choqueSagrado" },
		["shift-1"] = { "limpiar", "purificar" },
		["shift-2"] = { "bendicionProteccion" },
		["ctrl-1"] = { "redencion" },
		["ctrl-2"] = { "imposicionManos" },
		["alt-1"] = { "bendicionPoderio" },
		["alt-2"] = { "bendicionSabiduria" },
		["alt-3"] = { "bendicionReyes", "bendicionSalvacion" },
	},
	SHAMAN = {
		["1"] = { "olaSanacion" },
		["2"] = { "olaInferior" },
		["3"] = { "sanacionCadena" },
		["shift-1"] = { "curarVenenoC" },
		["shift-2"] = { "curarEnfermedadC" },
		["ctrl-1"] = { "espirituAncestral" },
		["alt-1"] = { "respiracionAcuatica" },
		["alt-2"] = { "caminarAgua" },
	},
}

-- "Solo buffs": izquierdo selecciona, derecho abre el menú, y los buffs de tu
-- clase con Mayús y Ctrl.
local BUFFS = {
	PRIEST = { ["shift-1"] = { "entereza" }, ["shift-2"] = { "proteccionSombras" }, ["ctrl-1"] = { "espirituDivino" } },
	DRUID = { ["shift-1"] = { "marcaSalvaje" }, ["shift-2"] = { "espinas" } },
	PALADIN = {
		["shift-1"] = { "bendicionPoderio" }, ["shift-2"] = { "bendicionSabiduria" },
		["ctrl-1"] = { "bendicionReyes", "bendicionSalvacion" },
	},
	SHAMAN = { ["shift-1"] = { "respiracionAcuatica" }, ["shift-2"] = { "caminarAgua" } },
	MAGE = {
		["shift-1"] = { "intelectoArcano" }, ["shift-2"] = { "eliminarMaldicionMenor" },
		["ctrl-1"] = { "amplificarMagia" }, ["ctrl-2"] = { "atenuarMagia" },
	},
	WARLOCK = {
		["shift-1"] = { "respiracionInagotable" },
		["shift-2"] = { "detectarInvisibilidadSuperior", "detectarInvisibilidad", "detectarInvisibilidadMenor" },
	},
}

M.PREAJUSTES = {
	curar = { nombre = L["Curandero"], icono = "plus" },
	buffs = { nombre = L["Solo buffs"], icono = "star" },
	cero = { nombre = L["Desde cero"], icono = "reset" },
}

-- ¿Tu clase tiene buffs para otros? (guerrero, pícaro y cazador, no)
function M.TieneBuffs(clase)
	clase = clase or M.Clase()
	local t = BUFFS[clase or ""]
	return type(t) == "table" and next(t) ~= nil
end

-- El nombre del preajuste para tu clase: sin buffs para otros, "Solo buffs"
-- es "Básico" (el izquierdo selecciona y el derecho abre el menú).
function M.NombrePreajuste(pre, clase)
	local P = M.PREAJUSTES[pre]
	if not P then return tostring(pre) end
	if pre == "buffs" and not M.TieneBuffs(clase) then return L["Básico"] end
	return P.nombre
end

-- Los preajustes que tu clase puede usar, en orden. Sin buffs para otros,
-- "Desde cero" pone los mismos clics que Básico: no se ofrece, salvo que sea
-- el que ya usas (así no te quedas sin su tarjeta "En uso").
function M.PreajustesDe(clase)
	clase = clase or M.Clase()
	local t = {}
	if CURAR[clase or ""] then t[#t + 1] = "curar" end
	t[#t + 1] = "buffs"
	local enUso = clase == M.Clase() and M.Datos and M.Datos().preajuste or nil
	if M.TieneBuffs(clase) or enUso == "cero" then t[#t + 1] = "cero" end
	return t
end

function M.Recomendado(clase)
	clase = clase or M.Clase()
	return CURAR[clase or ""] and "curar" or "buffs"
end

local function tablaDe(pre, clase)
	if pre == "curar" then return CURAR[clase or ""] end
	if pre == "buffs" then return BUFFS[clase or ""] or {} end
	return {}
end

-- Ranura -> { t = "spell", id, k, p = true } | { t = "target", p = true } |
-- { t = "menu", p = true }. Las ranuras se resuelven en el orden de
-- M.RANURAS y un hechizo no se repite. Con izqSel (el clic izquierdo solo
-- selecciona) la cura del izquierdo pasa al clic central.
-- Ranura -> lista de claves de mejor a peor, o "target" / "menu".
function M.Candidatos(pre, izqSel, clase)
	clase = clase or M.Clase()
	local tabla = tablaDe(pre, clase)
	local fuente = {}
	if type(tabla) == "table" then
		for r, lista in pairs(tabla) do fuente[r] = lista end
	end
	if pre ~= "curar" then
		fuente["1"], fuente["2"] = "target", "menu"
		-- 1.3.0: una venda en el primer clic libre (cualquier clase la usa).
		if pre == "buffs" then
			for _, r in ipairs({ "shift-1", "ctrl-1", "alt-1", "ctrl-2", "alt-2" }) do
				if fuente[r] == nil then fuente[r] = "venda" break end
			end
		end
	elseif izqSel then
		fuente["3"] = fuente["1"]
		fuente["1"] = "target"
	end
	return fuente
end

-- Lugar de una clave en la lista de su ranura (1 = la mejor), o nil.
function M.Lugar(fuente, ranura, clave)
	local lista = fuente[ranura]
	if type(lista) ~= "table" then return nil end
	for i = 1, #lista do
		if lista[i] == clave then return i end
	end
	return nil
end

function M.Resolver(pre, izqSel, clase)
	local fuente = M.Candidatos(pre, izqSel, clase)
	local mapa, usados = {}, {}
	for _, r in ipairs(M.RANURAS) do
		local lista = fuente[r]
		if lista == "target" then
			mapa[r] = { t = "target", p = true }
		elseif lista == "menu" then
			mapa[r] = { t = "menu", p = true }
		elseif lista == "venda" then
			mapa[r] = { t = "venda", p = true }
		elseif type(lista) == "table" then
			for i = 1, #lista do
				local k = lista[i]
				if not usados[k] then
					local id = M.Conocido(k)
					if id then
						usados[k] = true
						mapa[r] = { t = "spell", id = id, k = k, p = true }
						break
					end
				end
			end
		end
	end
	return mapa
end

-- Lo que un preajuste pondría, en una línea: "Izquierdo: Sanar · Derecho: Renovar".
function M.ResumenDe(mapa, max)
	local partes = {}
	for _, r in ipairs(M.RANURAS) do
		local e = mapa[r]
		if e and e.t == "spell" then
			local n = M.NombreHechizo(e.id)
			if n then partes[#partes + 1] = M.NombreRanura(r) .. ": " .. n end
		elseif e and e.t == "venda" then
			partes[#partes + 1] = M.NombreRanura(r) .. ": " .. L["Usar una venda"]
		end
		if max and #partes >= max then break end
	end
	return table.concat(partes, "  \194\183  ")
end

---------------------------------------------------------------------------
-- Tu libro de hechizos: los que se pueden lanzar sobre aliados.
---------------------------------------------------------------------------

local MAX_LIBRO = 28

function M.HechizosDelLibro()
	local B, S = C_SpellBook, C_Spell
	local lista, vistos = {}, {}
	if not (B and B.GetNumSpellBookSkillLines and B.GetSpellBookSkillLineInfo and B.GetSpellBookItemInfo) then return lista end
	local banco = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
	local tipoHechizo = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell or 1
	local okN, lineas = pcall(B.GetNumSpellBookSkillLines)
	lineas = okN and tonumber(lineas) or 0
	for l = 1, lineas do
		local okL, info = pcall(B.GetSpellBookSkillLineInfo, l)
		if okL and type(info) == "table" and info.shouldHide ~= true then
			local desde, cuantos = tonumber(info.itemIndexOffset) or 0, tonumber(info.numSpellBookItems) or 0
			for i = desde + 1, desde + cuantos do
				local okI, item = pcall(B.GetSpellBookItemInfo, i, banco)
				if okI and type(item) == "table" and item.itemType == tipoHechizo and item.isPassive ~= true
					and type(item.spellID) == "number" then
					local util = false
					if S and S.IsSpellHelpful then
						local okH, si = pcall(S.IsSpellHelpful, item.spellID)
						util = okH and not secreto(si) and si == true
					end
					local nombre = M.NombreHechizo(item.spellID)
					if util and nombre and not vistos[nombre] then
						vistos[nombre] = true
						lista[#lista + 1] = { id = item.spellID, nombre = nombre }
					end
				end
			end
		end
	end
	table.sort(lista, function(a, b) return a.nombre < b.nombre end)
	while #lista > MAX_LIBRO do table.remove(lista) end
	return lista
end

---------------------------------------------------------------------------
-- 1.3.0: los hechizos de tu clase que conoces, por categoría (para «Tus
-- clics»), lo que tus clics pueden quitar, tu buff de clase y tu venda.
---------------------------------------------------------------------------

-- La clave de H de un spellID (cualquier rango), o nil.
local claveDe
function M.ClaveDe(id)
	if type(id) ~= "number" then return nil end
	if not claveDe then
		claveDe = {}
		for k, ids in pairs(H) do for _, x in ipairs(ids) do claveDe[x] = k end end
	end
	return claveDe[id]
end

-- -> { { categoria, nombre, lista = { { id, k, nombre } } }, ... } solo con lo que conoces.
function M.HechizosPorCategoria()
	local por, vistos, claves = {}, {}, {}
	for k in pairs(CATEGORIA) do claves[#claves + 1] = k end
	table.sort(claves)
	for _, k in ipairs(claves) do
		local id = M.Conocido(k)
		local nombre = id and M.NombreHechizo(id)
		if nombre and not vistos[nombre] then
			vistos[nombre] = true
			local c = CATEGORIA[k]
			por[c] = por[c] or {}
			por[c][#por[c] + 1] = { id = id, k = k, nombre = nombre }
		end
	end
	-- Lo demás de tu libro que sirve sobre aliados, en "Otros".
	for _, h in ipairs(M.HechizosDelLibro()) do
		if not vistos[h.nombre] then
			vistos[h.nombre] = true
			por.otro = por.otro or {}
			por.otro[#por.otro + 1] = { id = h.id, k = M.ClaveDe(h.id), nombre = h.nombre }
		end
	end
	local t = {}
	for _, c in ipairs(M.CATEGORIAS) do
		if por[c.id] then
			table.sort(por[c.id], function(a, b) return a.nombre < b.nombre end)
			t[#t + 1] = { categoria = c.id, nombre = c.nombre, lista = por[c.id] }
		end
	end
	if por.otro then t[#t + 1] = { categoria = "otro", nombre = L["Otros"], lista = por.otro } end
	return t
end

-- ¿Qué perjuicios puedes quitar con lo que conoces? -> { Magic = clave, ... }
function M.TiposQuePuedesQuitar()
	local t = {}
	for k, tipos in pairs(M.QUITA) do
		if M.Conocido(k) then
			for tipo in pairs(tipos) do t[tipo] = t[tipo] or k end
		end
	end
	return t
end

-- La ranura que quita un tipo de perjuicio (la primera de M.RANURAS), o nil.
function M.RanuraQueQuita(tipo, mapa)
	mapa = mapa or (M.Mapa and M.Mapa()) or {}
	for _, r in ipairs(M.RANURAS) do
		local e = mapa[r]
		if type(e) == "table" and e.t == "spell" then
			local k = e.k or M.ClaveDe(e.id)
			local q = k and M.QUITA[k]
			if q and q[tipo] then return r end
		end
	end
	return nil
end

-- Los tipos que tu clase puede quitar pero ningún clic quita. -> lista ordenada
function M.QuitarSinClic(mapa)
	local puedes = M.TiposQuePuedesQuitar()
	local t = {}
	for _, tipo in ipairs(M.ORDEN_TIPOS) do
		if puedes[tipo] and not M.RanuraQueQuita(tipo, mapa) then t[#t + 1] = tipo end
	end
	return t
end

-- Tu buff de clase, si lo conoces -> { grupo, k, id } o nil.
function M.BuffDeClase(clase)
	local grupos = M.BUFF_CLASE[clase or M.Clase() or ""]
	if not grupos then return nil end
	for _, g in ipairs(grupos) do
		for _, k in ipairs(g) do
			local id = M.Conocido(k)
			if id then return { grupo = g, k = k, id = id } end
		end
	end
	return nil
end

-- La ranura que da tu buff de clase (cualquiera de su grupo), o nil.
function M.RanuraDelBuff(mapa)
	local b = M.BuffDeClase()
	if not b then return nil end
	local en = {}
	for _, k in ipairs(b.grupo) do en[k] = true end
	mapa = mapa or M.Mapa()
	for _, r in ipairs(M.RANURAS) do
		local e = mapa[r]
		if type(e) == "table" and e.t == "spell" then
			local k = e.k or M.ClaveDe(e.id)
			if k and en[k] then return r end
		end
	end
	return nil
end

-- Tu mejor venda en las bolsas -> itemID o nil.
function M.MejorVenda()
	local C = C_Container
	if not (C and C.GetContainerNumSlots and C.GetContainerItemID) then return nil end
	local tienes = {}
	for bolsa = 0, 4 do
		local ok, n = pcall(C.GetContainerNumSlots, bolsa)
		n = ok and tonumber(n) or 0
		for i = 1, n do
			local okI, id = pcall(C.GetContainerItemID, bolsa, i)
			if okI and not secreto(id) and type(id) == "number" then tienes[id] = true end
		end
	end
	for _, id in ipairs(M.VENDAS) do
		if tienes[id] then return id end
	end
	return nil
end
