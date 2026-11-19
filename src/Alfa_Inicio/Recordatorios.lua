-- Alfa - Inicio: los recordatorios (toxic3000 / La Jauría). GPL-3.0.
--
-- Cada uno con su interruptor y su umbral (ajustes "inicio.*"), y un aviso en
-- pantalla (M.Aviso) solo cuando algo cambia, nunca en bucle:
--   * Durabilidad: al bajar una pieza de durAviso (30 %) y de durUrgente
--     (10 %), con su nombre; el urgente suena. UPDATE_INVENTORY_DURABILITY,
--     PLAYER_EQUIPMENT_CHANGED y al entrar. GetInventoryItemDurability y
--     GetInventoryItemLink (globales clásicas que usa el FrameXML de Forever,
--     EquipmentManager.lua).
--   * Bolsas: con bolsasLibres espacios o menos. Cuenta las bolsas con el
--     contador del motor (Alfa.QoL.Space), que deja fuera carcajes, bolsas de
--     profesión y la de componentes.
--   * Entrenar: lo decide el motor. Su tarjeta de habilidades nuevas
--     (qol.levelUpSpells) sale al subir de nivel y su nota en la ventana de la
--     guía (behavior.trainReminder, TRAIN_DUE) cada 2 niveles. Inicio no las
--     repite: avisa cuando llegas a una ciudad o posada con entrenarMin
--     habilidades o más por aprender (Alfa.QoL.Spells.NewAt, una vez por
--     nivel), y repite la nota de la guía en un aviso solo si la ventana de la
--     guía está oculta.
--   * Buff propio fuera de combate: una lista mínima por clase (BUFFS). Se
--     busca por nombre (cualquier rango, también si te lo dio otro jugador).
--     Grito de batalla solo se recuerda con 10 de furia o más: sin furia no
--     se puede lanzar. Cada buffCada minutos a lo más por buff; con buffQueda
--     también cuando le quedan menos de esos segundos (un temporizador, no un
--     OnUpdate).
--   * Descanso: al entrar a una zona de descanso, y cuando tu XP descansada
--     baja de descansoBajo % de un nivel (o se acaba).
--
--   M.Rec.Estado() -> { equipo, bolsas, entrenar, buff, descanso } para la página

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)
local Aviso = M.Aviso
local num, texto, miles = M.num, M.texto, M.miles

local type, ipairs, pairs, floor, max, min, format = type, ipairs, pairs, math.floor, math.max, math.min, string.format

local R = {}
M.Rec = R

local function on(clave) return N.Get("inicio", clave) and true or false end
local function valor(clave, def) return tonumber(N.Get("inicio", clave)) or def end
local function combate() return InCombatLockdown and InCombatLockdown() and true or false end
local function nivel() return num(UnitLevel and UnitLevel("player")) end
local function ahora() return GetTime and GetTime() or 0 end

local function maximo()
	local lv, mx = nivel(), num(GetMaxPlayerLevel and GetMaxPlayerLevel())
	return lv ~= nil and mx ~= nil and lv >= mx
end

local function claseJugador()
	if not UnitClass then return nil end
	local _, file = UnitClass("player")
	return texto(file)
end

-- Una llamada que se junta: muchas seguidas corren una vez, `espera` después.
local function juntar(espera, fn)
	local pendiente = false
	return function()
		if pendiente then return end
		pendiente = true
		A.After(espera, function()
			pendiente = false
			fn()
		end)
	end
end

-- Con la ruta cargada, su Buscar cerca (AlfaCerca.Ir: mensajes de Alfa, el
-- aviso con el lugar, el rastreador a la vista y las ventanas cerradas); sin
-- ella, el motor directo y N.EmpezarRuta.
local function irA(tipo)
	local Ce = rawget(_G, "AlfaCerca")
	if type(Ce) == "table" and type(Ce.Ir) == "function" then
		local ok, err = pcall(Ce.Ir, tipo)
		if not ok and geterrorhandler then geterrorhandler()(err) end
		return
	end
	local Nav = A.Nav
	local near = type(Nav) == "table" and Nav.nearby
	if type(near) == "table" and type(near.Go) == "function" then
		local ok, puesto = pcall(near.Go, tipo)
		if ok and puesto and N.EmpezarRuta then N.EmpezarRuta() end
	else
		N.Imprimir(L["La búsqueda de lugares cercanos no está disponible."])
	end
end
R.IrA = irA

local function cambio()
	if M.Pagina and M.Pagina.Pintar then M.Pagina.Pintar() end
end

---------------------------------------------------------------------------
-- Durabilidad
---------------------------------------------------------------------------

local RANURAS = { 1, 3, 5, 6, 7, 8, 9, 10, 16, 17, 18 }
local GLOBAL_RANURA = {
	[1] = "HEADSLOT", [3] = "SHOULDERSLOT", [5] = "CHESTSLOT", [6] = "WAISTSLOT", [7] = "LEGSSLOT", [8] = "FEETSLOT",
	[9] = "WRISTSLOT", [10] = "HANDSSLOT", [16] = "MAINHANDSLOT", [17] = "SECONDARYHANDSLOT", [18] = "RANGEDSLOT",
}
local NOMBRE_RANURA = {
	[1] = L["Cabeza"], [3] = L["Hombros"], [5] = L["Pecho"], [6] = L["Cintura"], [7] = L["Piernas"], [8] = L["Pies"],
	[9] = L["Muñecas"], [10] = L["Manos"], [16] = L["Mano principal"], [17] = L["Mano secundaria"], [18] = L["A distancia"],
}

function R.NombreRanura(slot)
	local g = _G[GLOBAL_RANURA[slot] or ""]
	if type(g) == "string" and g ~= "" then return g end
	return NOMBRE_RANURA[slot] or "?"
end

-- El nombre de la pieza con el color de su calidad; nil si no se sabe.
function R.NombrePieza(slot)
	if not GetInventoryItemLink then return nil end
	local ok, link = pcall(GetInventoryItemLink, "player", slot)
	link = ok and texto(link) or nil
	if not link then return nil end
	local name = link:match("%[(.-)%]")
	if not name or name == "" then return nil end
	local color = link:match("^(|c%x%x%x%x%x%x%x%x)")
	return color and (color .. name .. "|r") or name
end

-- Las piezas con durabilidad, de la más gastada a la menos: { { slot, pct } }.
local durCache = {}
function R.LeerDurabilidad()
	local lista = {}
	if GetInventoryItemDurability then
		for _, slot in ipairs(RANURAS) do
			local ok, cur, mx = pcall(GetInventoryItemDurability, slot)
			cur, mx = ok and num(cur) or nil, ok and num(mx) or nil
			if cur and mx and mx > 0 then lista[#lista + 1] = { slot = slot, pct = cur / mx * 100 } end
		end
	end
	table.sort(lista, function(a, b) return a.pct < b.pct end)
	durCache = lista
	return lista
end

local nivelDur = {} -- slot -> 0 bien, 1 primer aviso, 2 urgente (lo último que se dijo)

local function avisarDurabilidad(peor, otras)
	local urgente = peor.nivel == 2
	local pieza = R.NombrePieza(peor.slot) or R.NombreRanura(peor.slot)
	local pct = floor(peor.pct + 0.5)
	local linea = pct <= 0 and format(L["%s está rota"], pieza) or format(L["%s: %d%%"], pieza, pct)
	local txt = urgente and L["Si llega a 0 % se rompe y deja de darte sus estadísticas. Repara cuanto antes con un herrero o un vendedor que repare."]
		or L["Repara con un herrero o un vendedor que repare antes de que se rompa."]
	if otras > 0 then
		txt = txt .. "\n" .. (otras == 1 and L["Y 1 pieza más necesita reparación."] or format(L["Y %d piezas más necesitan reparación."], otras))
	end
	Aviso.Mostrar({
		clave = "durabilidad", tipo = urgente and "peligro" or "aviso", icono = "ic-oficios",
		titulo = urgente and L["¡Repara tu equipo!"] or L["Tu equipo se está gastando"],
		linea = linea, texto = txt, sonido = urgente,
		botones = { { texto = L["Llévame a reparar"], fn = function() irA("repair") end } },
	})
end

local function revisarDurabilidad()
	local lista = R.LeerDurabilidad()
	cambio()
	local activo = on("recDurabilidad")
	local primer, urg = valor("durAviso", 30), valor("durUrgente", 10)
	if urg > primer then urg = primer end
	local peor, otras = nil, 0
	local vistas = {}
	for _, e in ipairs(lista) do
		vistas[e.slot] = true
		local n = (e.pct <= urg and 2) or (e.pct <= primer and 1) or 0
		if n > 0 then otras = otras + 1 end
		if activo and n > (nivelDur[e.slot] or 0) and (not peor or n > peor.nivel or (n == peor.nivel and e.pct < peor.pct)) then
			peor = { slot = e.slot, pct = e.pct, nivel = n }
		end
		nivelDur[e.slot] = n
	end
	for slot in pairs(nivelDur) do
		if not vistas[slot] then nivelDur[slot] = nil end
	end
	if peor then avisarDurabilidad(peor, otras - 1) end
end
local revisarDurabilidadPronto = juntar(1, revisarDurabilidad)

A.RegisterEvent("UPDATE_INVENTORY_DURABILITY", revisarDurabilidadPronto)
A.RegisterEvent("PLAYER_EQUIPMENT_CHANGED", revisarDurabilidadPronto)

---------------------------------------------------------------------------
-- Bolsas
---------------------------------------------------------------------------

-- Espacios libres y totales de las bolsas que aceptan cualquier objeto.
function R.Bolsas()
	local Q = A.QoL
	local Sp = type(Q) == "table" and Q.Space
	if type(Sp) == "table" then
		for _, fn in ipairs({ Sp.Free, Sp.Count }) do
			if type(fn) == "function" then
				local ok, f, t = pcall(fn)
				f, t = ok and num(f) or nil, ok and num(t) or nil
				if f and t and t > 0 then return f, t end
			end
		end
	end
	local C = C_Container
	if not (C and C.GetContainerNumFreeSlots and C.GetContainerNumSlots) then return nil end
	local f, t = 0, 0
	for bag = 0, NUM_BAG_SLOTS or 4 do
		local free, family = C.GetContainerNumFreeSlots(bag)
		free, family = num(free) or 0, num(family)
		if not family or family == 0 then
			f = f + free
			t = t + (num(C.GetContainerNumSlots(bag)) or 0)
		end
	end
	return f, t
end

local nivelBolsas = 0 -- 0 bien, 1 casi llenas, 2 llenas (lo último que se dijo)
local bolsasEn = -1000

local function revisarBolsas()
	local libres, total = R.Bolsas()
	cambio()
	if not libres then return end
	local umbral = valor("bolsasLibres", 4)
	local n = (libres == 0 and 2) or (libres <= umbral and 1) or 0
	local antes = nivelBolsas
	nivelBolsas = n
	if not on("recBolsas") or n <= antes or n == 0 then return end
	-- Vender y saquear sube y baja el número: no más de un aviso cada 2 minutos, salvo al llenarse.
	if n == 1 and ahora() - bolsasEn < 120 then return end
	bolsasEn = ahora()
	local txt = L["Vende lo gris con cualquier vendedor o tira algo que ya no uses."]
	local Q = A.QoL
	local Sp = type(Q) == "table" and Q.Space
	if type(Sp) == "table" and type(Sp.Cheapest) == "function" and type(Sp.ItemText) == "function" then
		local ok, j = pcall(Sp.Cheapest)
		if ok and type(j) == "table" then
			local ok2, nombre = pcall(Sp.ItemText, j)
			if ok2 and type(nombre) == "string" then txt = txt .. "\n" .. format(L["Lo que menos vale: %s"], nombre) end
		end
	end
	-- Con Bolsas (y el consejo de Comercio): qué vender y cuánto te dan. 1.1.9.
	local B = rawget(_G, "AlfaBolsas")
	if type(B) == "table" and type(B.Venta) == "function" then
		local ok, n, cobre, nombres = pcall(B.Venta)
		if ok and type(n) == "number" and n > 0 and type(cobre) == "number" and cobre > 0 then
			txt = txt .. "\n" .. format(L["Puedes vender %s por %s."], nombres or tostring(n), N.Dinero(cobre))
		end
	end
	local botones = { { texto = L["Llévame a un vendedor"], fn = function() irA("vendor") end } }
	if N.ModuloPorId("bolsas") then
		table.insert(botones, 1, { texto = L["Abrir bolsas"], fn = function() N.Abrir("bolsas") end })
	end
	Aviso.Mostrar({
		clave = "bolsas", tipo = n == 2 and "peligro" or "aviso", icono = "ic-bolsas",
		titulo = n == 2 and L["Tus bolsas están llenas"] or L["Tus bolsas están casi llenas"],
		linea = libres == 1 and L["Te queda 1 espacio"] or format(L["Te quedan %d de %d espacios"], libres, total or 0),
		texto = txt, botones = botones,
	})
end
local revisarBolsasPronto = juntar(0.5, revisarBolsas)

A.RegisterEvent("BAG_UPDATE_DELAYED", revisarBolsasPronto)

---------------------------------------------------------------------------
-- Habilidades por entrenar
---------------------------------------------------------------------------

local entrenar = { n = 0, costo = 0, listo = false }

-- Las habilidades que tu entrenador de clase ya te puede enseñar, de todos
-- los niveles hasta el tuyo (Alfa.QoL.Spells.NewAt deja fuera las que sabes).
local function contarEntrenar()
	local Q = A.QoL
	local Sp = type(Q) == "table" and Q.Spells
	local lv = nivel()
	if type(Sp) ~= "table" or type(Sp.NewAt) ~= "function" or not lv then
		entrenar.listo = false
		return
	end
	local n, costo = 0, 0
	for l = 1, lv do
		local ok, list = pcall(Sp.NewAt, l)
		if ok and type(list) == "table" then
			for _, s in ipairs(list) do
				n = n + 1
				costo = costo + (num(s.cost) or 0)
			end
		end
	end
	entrenar.n, entrenar.costo, entrenar.listo = n, costo, true
end

function R.Entrenar()
	return entrenar
end

-- Dónde entrenar: lo mismo que dicen la nota de la guía y la tarjeta del motor.
local function dondeEntrenar(trainer)
	local E = A.Engine
	if not trainer and type(E) == "table" and type(E.TrainingAdvice) == "function" then
		local ok, adv = pcall(E.TrainingAdvice)
		if ok and type(adv) == "table" then
			if adv.guide and num(adv.steps) then
				-- El motor cuenta el paso de ahora como el 1 (Engine.GuideTrainStop).
				if adv.steps <= 1 then return L["El paso de ahora de tu guía te lleva a entrenar."], false end
				return format(L["La guía te lleva a entrenar en %d pasos."], adv.steps), false
			end
			trainer = adv.trainer
		end
	end
	if type(trainer) == "table" and texto(trainer.npcName) then
		local zona = A.Compat and type(A.Compat.GetMapName) == "function" and num(trainer.map) and A.Compat.GetMapName(trainer.map)
		if type(zona) == "string" then return format(L["Tu entrenador: %s (%s)."], trainer.npcName, zona), true end
		return format(L["Tu entrenador: %s."], trainer.npcName), true
	end
	return L["Busca al entrenador de tu clase en la ciudad."], true
end

local function avisarEntrenar(trainer)
	local donde, boton = dondeEntrenar(trainer)
	local n = entrenar.n
	local linea
	if n > 0 then
		linea = n == 1 and L["1 habilidad por aprender"] or format(L["%d habilidades por aprender"], n)
		if entrenar.costo > 0 then linea = linea .. "  \194\183  " .. N.Dinero(entrenar.costo) end
	else
		linea = L["Tu entrenador tiene algo nuevo para ti"]
	end
	Aviso.Mostrar({
		clave = "entrenar", tipo = "info", icono = "ic-nivel",
		titulo = L["Tienes habilidades nuevas"],
		linea = linea, texto = donde,
		botones = boton and { { texto = L["Llévame con mi entrenador"], fn = function() irA("class") end } } or nil,
	})
	N.DatosPersonaje("inicio").entrenarAvisado = nivel()
end

local function yaAvisado()
	return N.DatosPersonaje("inicio").entrenarAvisado == nivel()
end

local function revisarEntrenar()
	contarEntrenar()
	cambio()
end
local revisarEntrenarPronto = juntar(2, revisarEntrenar)

-- Forever no tiene LEARNED_SPELL_IN_TAB: su evento es este (1.2.0; SPELLS_CHANGED también lo cubre).
A.RegisterEvent("LEARNED_SPELL_IN_SKILL_LINE", revisarEntrenarPronto)
A.RegisterEvent("SPELLS_CHANGED", revisarEntrenarPronto)
A.RegisterEvent("PLAYER_LEVEL_UP", function() A.After(3, revisarEntrenar) end)
A.On("CLASS_TRAINED", revisarEntrenarPronto)

-- La nota de entrenar del motor, solo si la ventana de la guía no se ve.
A.On("TRAIN_DUE", function(_level, trainer)
	if not on("recEntrenar") or A.GuideShown() then return end
	contarEntrenar()
	avisarEntrenar(type(trainer) == "table" and trainer or nil)
end)

---------------------------------------------------------------------------
-- Buff propio fuera de combate
---------------------------------------------------------------------------

-- Por clase, una lista mínima. Cada grupo se cumple con cualquiera de sus
-- hechizos (el primer rango basta: se busca por nombre). `furia`: lo que
-- cuesta, para no pedir lo imposible. `nombre`: cómo se dice un grupo de varios.
local BUFFS = {
	WARRIOR = { { ids = { 6673 }, furia = 10 } },                              -- Grito de batalla
	MAGE = {
		{ ids = { 1459 } },                                                     -- Intelecto Arcano
		{ ids = { 168, 7302, 6117 }, nombre = L["una armadura de mago"] },       -- Escarcha, Hielo, Mago
	},
	PRIEST = { { ids = { 1243 } }, { ids = { 588 } } },                          -- Palabra de poder: entereza, Fuego interno
	DRUID = { { ids = { 1126 } } },                                              -- Marca de lo Salvaje
	WARLOCK = { { ids = { 687, 706 }, nombre = L["tu piel o armadura demoníaca"] } },
	PALADIN = {
		{ ids = { 465, 7294, 19746, 19876, 19888, 19891, 20218 }, nombre = L["un aura"] },
		{ ids = { 19740, 19742, 20217, 1038, 19977, 20911 }, nombre = L["una bendición"] },
	},
	HUNTER = { { ids = { 13165, 13163, 5118, 13159, 20043, 13161 }, nombre = L["un aspecto"] } },
	SHAMAN = { { ids = { 324 } } },                                              -- Escudo de relámpagos
	ROGUE = {},
}
R.BUFFS = BUFFS

local function nombreHechizo(id)
	local fn = C_Spell and C_Spell.GetSpellName
	if not fn then return nil end
	local ok, n = pcall(fn, id)
	return ok and texto(n) or nil
end

local function conoce(id)
	local C = A.Compat
	if type(C) == "table" and type(C.IsSpellKnown) == "function" then
		local ok, k = pcall(C.IsSpellKnown, id)
		if ok and k then return true end
	end
	if type(C) == "table" and type(C.IsPlayerSpell) == "function" then
		local ok, k = pcall(C.IsPlayerSpell, id)
		if ok and k == true then return true end
	end
	return false
end

-- El aura del jugador con ese nombre: la tabla, false si no está, nil si el
-- cliente no lo dice.
local function aura(id, nombre)
	local U = C_UnitAuras
	if not U then return nil end
	if U.GetPlayerAuraBySpellID then
		local ok, a = pcall(U.GetPlayerAuraBySpellID, id)
		if ok and type(a) == "table" and not (issecretvalue and issecretvalue(a)) then return a end
	end
	if U.GetAuraDataBySpellName and nombre then
		local ok, a = pcall(U.GetAuraDataBySpellName, "player", nombre, "HELPFUL")
		if not ok or (issecretvalue and issecretvalue(a)) then return nil end
		if type(a) == "table" then return a end
		return false
	end
	return nil
end

-- Segundos que le quedan a un aura (math.huge si no se acaba), nil si no se sabe.
local function queda(a)
	local exp = num(a.expirationTime)
	if not exp then return nil end
	if exp == 0 then return math.huge end
	return max(0, exp - ahora())
end

local buff = { estado = "ninguno" } -- para la página: estado, nombre, id
local buffEn = {}                   -- grupo -> GetTime() del último aviso
local buffGen = 0

local function furia()
	local p = num(UnitPower and UnitPower("player", 1))
	return p or 0
end

-- Un sí del cliente (un valor secreto cuenta como no).
local function si(v)
	if issecretvalue and issecretvalue(v) then return false end
	return v == true
end

-- Muerto, en un vuelo o montado: no es momento de pedir un buff.
local function impedido()
	if combate() then return true end
	if UnitIsDeadOrGhost and si(UnitIsDeadOrGhost("player")) then return true end
	if UnitOnTaxi and si(UnitOnTaxi("player")) then return true end
	if IsMounted and si(IsMounted()) then return true end
	return false
end

local revisarBuffs

local function programar(segundos)
	buffGen = buffGen + 1
	if not segundos or segundos == math.huge then return end
	local mia = buffGen
	A.After(max(1, segundos) + 0.2, function()
		if mia == buffGen then revisarBuffs() end
	end)
end

revisarBuffs = function()
	local grupos = BUFFS[claseJugador() or ""]
	if not grupos or #grupos == 0 then
		buff.estado, buff.nombre, buff.id = "ninguno", nil, nil
		cambio()
		return
	end
	local umbral = valor("buffQueda", 0)
	local cada = valor("buffCada", 3) * 60
	local proximo
	local peor -- el primer grupo que falta, para la página
	local algunoConocido = false
	for gi, g in ipairs(grupos) do
		local conocidos = {}
		for _, id in ipairs(g.ids) do
			if conoce(id) then conocidos[#conocidos + 1] = id end
		end
		if #conocidos > 0 then
			algunoConocido = true
			local presente, incierto, resto
			for _, id in ipairs(conocidos) do
				local a = aura(id, nombreHechizo(id))
				if type(a) == "table" then
					presente = a
					break
				elseif a == nil then
					incierto = true
				end
			end
			local nombre = g.nombre or nombreHechizo(conocidos[1]) or "?"
			local falta = false
			if presente then
				resto = queda(presente)
				if umbral > 0 and resto and resto ~= math.huge then
					if resto <= umbral then
						falta = "poco"
					elseif not proximo or resto - umbral < proximo then
						proximo = resto - umbral
					end
				end
			elseif not incierto then
				falta = "falta"
			end
			if falta and not peor then peor = { estado = falta, nombre = nombre, id = conocidos[1] } end
			-- Grito de batalla sin furia no se puede lanzar: no se pide.
			local puede = not g.furia or furia() >= g.furia
			if falta and puede and on("recBuff") and not impedido() and ahora() - (buffEn[gi] or -1e9) >= cada then
				buffEn[gi] = ahora()
				local icono = A.Compat and type(A.Compat.SpellIcon) == "function" and A.Compat.SpellIcon(conocidos[1]) or nil
				Aviso.Mostrar({
					clave = "buff" .. gi, tipo = "aviso", textura = icono, icono = "ic-aviso",
					titulo = falta == "poco" and format(L["A %s le queda poco"], nombre) or format(L["Te falta %s"], nombre),
					linea = L["Fuera de combate es el mejor momento"],
					texto = g.furia and L["Tienes furia: úsalo antes de la siguiente pelea, te da más poder de ataque a ti y a tu grupo."]
						or L["Lánzalo antes de la siguiente pelea."],
				})
			end
		end
	end
	if peor then
		buff.estado, buff.nombre, buff.id = peor.estado, peor.nombre, peor.id
	elseif algunoConocido then
		buff.estado, buff.nombre, buff.id = "ok", nil, nil
	else
		buff.estado, buff.nombre, buff.id = "noaprendido", nil, nil
	end
	cambio()
	programar(proximo)
end
local revisarBuffsPronto = juntar(1, function() revisarBuffs() end)

function R.Buff() return buff end

-- Para la tarjeta de la clase (Clase.lua): lo mismo que usan los avisos.
R.NombreHechizo, R.Conoce, R.Furia = nombreHechizo, conoce, furia

-- El estado de un grupo (una tabla { ids = { ... } } como las de BUFFS) sin
-- avisar nada: { estado = "ok" | "falta" | "noaprendido" | "nose", id, nombre
-- (el del grupo), activo (el nombre del aura puesta), resto (segundos,
-- math.huge si no se acaba), cargas }. "nose": el cliente no lo dice ahora
-- (un valor secreto).
function R.Grupo(g)
	local out = { estado = "noaprendido", nombre = g.nombre or nombreHechizo(g.ids[1]) }
	local conocidos = {}
	for _, id in ipairs(g.ids) do
		if conoce(id) then conocidos[#conocidos + 1] = id end
	end
	if #conocidos == 0 then return out end
	out.id = conocidos[1]
	out.nombre = g.nombre or nombreHechizo(conocidos[1]) or out.nombre
	local incierto = false
	for _, id in ipairs(conocidos) do
		local a = aura(id, nombreHechizo(id))
		if type(a) == "table" then
			out.estado, out.id = "ok", id
			out.activo = texto(a.name) or nombreHechizo(id)
			out.resto = queda(a)
			out.cargas = num(a.applications)
			return out
		elseif a == nil then
			incierto = true
		end
	end
	out.estado = incierto and "nose" or "falta"
	return out
end

A.RegisterEvent("UNIT_AURA", function(_, unit)
	if unit == "player" and not combate() then revisarBuffsPronto() end
end)
A.RegisterEvent("PLAYER_REGEN_ENABLED", function() A.After(1, function() revisarBuffs() end) end)
A.RegisterEvent("PLAYER_ALIVE", revisarBuffsPronto)
A.RegisterEvent("PLAYER_UNGHOST", revisarBuffsPronto)

---------------------------------------------------------------------------
-- Descanso
---------------------------------------------------------------------------

local function leerDescanso()
	local r = num(GetXPExhaustion and GetXPExhaustion()) or 0
	local mx = num(UnitXPMax and UnitXPMax("player")) or 0
	local pct = mx > 0 and r / mx * 100 or 0
	local resting = IsResting and IsResting() == true or false
	return r, pct, resting
end

function R.Descanso()
	return leerDescanso()
end

local descansando
local pctAntes
local nivelAntes -- al subir de nivel el % baja solo (el nivel pide más XP): no es gastar
local descansoEn = -1000

local function revisarDescanso(entrar)
	local r, pct, resting = leerDescanso()
	cambio()
	if maximo() then
		pctAntes, descansando = pct, resting
		return
	end
	local activo = on("recDescanso")
	-- Al entrar a una posada o ciudad. 1.2.8: se lee un segundo después (al
	-- entrar el juego aún no la actualiza) y con menos de 1 % ya no dice «0 %»:
	-- dice que empiezas a juntarla.
	if entrar and resting and descansando == false and activo and ahora() - descansoEn >= 600 then
		descansoEn = ahora()
		A.After(1, function()
			local _, p, sigue = leerDescanso()
			if not sigue then return end
			local redondo = floor(p + 0.5)
			Aviso.Mostrar({
				clave = "descanso", tipo = "exito", icono = "ic-hoy",
				titulo = L["Estás descansando"],
				linea = redondo >= 1 and format(L["XP descansada: %d%% de un nivel"], redondo) or L["Empiezas a juntar XP descansada"],
				texto = redondo >= 1 and L["En posadas y ciudades acumulas XP descansada: ganas el doble de XP por enemigo hasta gastarla. Si cierras sesión aquí, también se acumula."]
					or L["Aquí juntas XP descansada poco a poco (más si cierras sesión aquí): luego ganas el doble por enemigo hasta gastarla."],
			})
		end)
	end
	-- Al bajar del umbral (con umbral 0: al acabarse). Un aviso, no dos.
	local umbral = valor("descansoBajo", 5)
	local nivel = UnitLevel and UnitLevel("player")
	if type(nivel) ~= "number" or (issecretvalue and issecretvalue(nivel)) then nivel = nil end
	local subio = nivel and nivelAntes and nivel ~= nivelAntes
	if nivel then nivelAntes = nivel end
	if activo and pctAntes and not resting and not subio then
		local cruzo
		if umbral > 0 then
			cruzo = pctAntes > umbral and pct <= umbral
		else
			cruzo = pctAntes > 0 and r <= 0
		end
		if cruzo then
			Aviso.Mostrar({
				clave = "descansoBajo", tipo = "info", icono = "ic-hoy",
				titulo = r <= 0 and L["Se acabó tu XP descansada"] or L["Te queda poca XP descansada"],
				linea = r <= 0 and L["Ahora ganas la XP normal"] or format(L["%d%% de un nivel"], floor(pct + 0.5)),
				texto = L["Para volver a acumularla, descansa (o cierra sesión) en una posada o una ciudad."],
			})
		end
	end
	pctAntes, descansando = pct, resting
end

A.RegisterEvent("PLAYER_UPDATE_RESTING", function() revisarDescanso(true) end)
A.RegisterEvent("UPDATE_EXHAUSTION", function() revisarDescanso(false) end)
A.RegisterEvent("PLAYER_XP_UPDATE", function(_, unit)
	if unit == nil or unit == "player" then revisarDescanso(false) end
end)

---------------------------------------------------------------------------
-- Al entrar, y lo que lee la página
---------------------------------------------------------------------------

local entrado = false
local listoTodo = false -- 10 s después de entrar: el libro de hechizos ya cargó
A.RegisterEvent("PLAYER_ENTERING_WORLD", function()
	if entrado then return end
	entrado = true
	local _, pct, resting = leerDescanso()
	pctAntes, descansando = pct, resting
	-- Después de los avisos del motor al entrar (bienvenida, hechizos: 6 s) y
	-- del resumen de la sesión anterior (8 s), que así sale primero.
	A.After(10, function()
		listoTodo = true
		contarEntrenar()
		revisarDurabilidad()
		revisarBolsas()
		revisarBuffs()
	end)
end)

-- Llegar a una ciudad o posada con habilidades por aprender (una vez por nivel).
A.RegisterEvent("PLAYER_UPDATE_RESTING", function()
	if not listoTodo or not (on("recEntrenar") and IsResting and IsResting() == true) or combate() or yaAvisado() then return end
	contarEntrenar()
	if entrenar.listo and entrenar.n >= valor("entrenarMin", 1) then avisarEntrenar(nil) end
end)

A.On("SETTING_CHANGED", function(path)
	if type(path) ~= "string" then return end
	if path:find("^inicio%.dur") or path == "inicio.recDurabilidad" then
		for k in pairs(nivelDur) do nivelDur[k] = nil end
		revisarDurabilidadPronto()
	elseif path == "inicio.bolsasLibres" or path == "inicio.recBolsas" then
		nivelBolsas = 0
		revisarBolsasPronto()
	elseif path:find("^inicio%.buff") or path == "inicio.recBuff" then
		revisarBuffsPronto()
	end
end)

local estado = { equipo = {}, bolsas = {}, entrenar = entrenar, buff = buff, descanso = {} }

function R.Estado()
	local peor = durCache[1]
	estado.equipo.slot = peor and peor.slot or nil
	estado.equipo.pct = peor and peor.pct or nil
	local n = 0
	for _, e in ipairs(durCache) do
		if e.pct <= valor("durAviso", 30) then n = n + 1 end
	end
	estado.equipo.gastadas = n
	local f, t = R.Bolsas()
	estado.bolsas.libres, estado.bolsas.total = f, t
	local r, pct, resting = leerDescanso()
	estado.descanso.xp, estado.descanso.pct, estado.descanso.activo, estado.descanso.maximo = r, pct, resting, maximo()
	return estado
end

-- Lee todo otra vez (al abrir la página).
function R.Leer()
	R.LeerDurabilidad()
	if not entrenar.listo then contarEntrenar() end
end
