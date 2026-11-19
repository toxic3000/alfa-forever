-- Alfa - Inicio: comida y agua (toxic3000 / La Jauría). GPL-3.0. -- 1.2.9
--
-- Cuenta lo que llevas para comer y beber (las bolsas, con los objetos que
-- se usan con el hechizo «Comida» o «Bebida», más una lista de los de
-- vendedor y los conjurados por si el juego no lo dice todavía) y avisa
-- cuando se te acaba: una vez al bajar de inicio.comidaMin y otra al
-- quedarte sin nada (nunca en combate). El agua solo cuenta para las clases
-- con maná. Sugiere qué comprar a tu nivel (la comida de vendedor por
-- niveles, Co.NIVELES) y la flecha al vendedor de comida más cercano.
--
--   M.Comida.Contar() -> comida, agua      lo que llevas en las bolsas
--   M.Comida.NecesitaAgua() -> bool        tu clase usa maná
--   M.Comida.Sugerencia(nivel) -> { comida = id, agua = id, nivel }
--   M.Comida.Nombre(id) -> texto           el nombre del objeto (el del juego si ya lo sabe)
--   M.Comida.Estado() -> { comida, agua, agua?, bajo = { comida = bool, agua = bool } }
--   M.Comida.Bajo() -> bool                ya avisó y sigue bajo (la alerta de Hoy)
--   M.Comida.Revisar(silencio)             vuelve a contar (y avisa si toca)
--   M.Comida.Ir()                          la flecha al vendedor de comida

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = N.Textos(M.EN)
local num, texto = M.num, M.texto

local type, ipairs, pairs, pcall, tonumber, format = type, ipairs, pairs, pcall, tonumber, string.format
local floor = math.floor

local Co = {}
M.Comida = Co

-- La comida y el agua de vendedor, por el nivel que piden.
Co.NIVELES = {
	{ nivel = 1, pan = 4540, carne = 117, agua = 159 },
	{ nivel = 5, pan = 4541, carne = 2287, agua = 1179 },
	{ nivel = 15, pan = 4542, carne = 3770, agua = 1205 },
	{ nivel = 25, pan = 4544, carne = 3771, agua = 1708 },
	{ nivel = 35, pan = 4601, carne = 4599, agua = 1645 },
	{ nivel = 45, pan = 8950, carne = 8952, agua = 8766 },
}

-- Por si el juego todavía no tiene el nombre (la primera vez que lo pides).
local NOMBRES = {
	[4540] = L["Pedazo de pan duro"], [4541] = L["Pan recién horneado"], [4542] = L["Pan de maíz húmedo"],
	[4544] = L["Pan de especias de Mulgore"], [4601] = L["Pan de plátano suave"], [8950] = L["Pastel de cerezas casero"],
	[117] = L["Cecina dura"], [2287] = L["Pierna de carne"], [3770] = L["Chuleta de cordero"],
	[3771] = L["Pata de jabalí salvaje"], [4599] = L["Filete de jamón curado"], [8952] = L["Codorniz asada"],
	[159] = L["Agua de manantial refrescante"], [1179] = L["Leche helada"], [1205] = L["Jugo de melón"],
	[1708] = L["Néctar dulce"], [1645] = L["Jugo de baya lunar"], [8766] = L["Rocío de gloria de la mañana"],
}

-- Lo que se sabe sin preguntarle al juego: "agua" o "comida".
local CONOCIDOS = {}
for _, f in ipairs(Co.NIVELES) do
	CONOCIDOS[f.pan], CONOCIDOS[f.carne], CONOCIDOS[f.agua] = "comida", "comida", "agua"
end
for _, id in ipairs({ 5350, 2288, 2136, 3772, 8077, 8078, 8079 }) do CONOCIDOS[id] = "agua" end -- agua conjurada
for _, id in ipairs({ 5349, 1113, 1114, 1487, 8075, 8076, -- pan conjurado
	2070, 414, 422, 1707, 3927, 8932, 787, 4592, 4593, 4594, 8957, 4536, 4537, 4538, 4539, 4602, 8953,
	4604, 4605, 4606, 4607, 4608, 8948 }) do CONOCIDOS[id] = "comida" end
Co.CONOCIDOS = CONOCIDOS

local MANA = { MAGE = true, PRIEST = true, WARLOCK = true, DRUID = true, SHAMAN = true, PALADIN = true, HUNTER = true }

local function on(clave) return N.Get("inicio", clave) and true or false end
local function combate() return InCombatLockdown and InCombatLockdown() and true or false end
local function nivel() return num(UnitLevel and UnitLevel("player")) or 1 end

local function llamar(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d, e = pcall(fn, ...)
	if ok then return a, b, c, d, e end
	return nil
end

---------------------------------------------------------------------------
-- Qué es comida y qué es agua
---------------------------------------------------------------------------

local function nombreHechizo(id)
	local CS = rawget(_G, "C_Spell")
	local n = CS and CS.GetSpellName and llamar(CS.GetSpellName, id)
	if not n and GetSpellInfo then n = llamar(GetSpellInfo, id) end
	return texto(n)
end

local hechizos -- { [nombre] = "comida" | "agua" }
local function porHechizo()
	if hechizos then return hechizos end
	local h = {}
	local comida, bebida = nombreHechizo(433), nombreHechizo(430)
	if comida then h[comida] = "comida" end
	if bebida then h[bebida] = "agua" end
	if next(h) then hechizos = h end
	return h
end

local tipos = {} -- id -> "comida" | "agua" | false
function Co.Tipo(id)
	id = num(id)
	if not id then return nil end
	if CONOCIDOS[id] then return CONOCIDOS[id] end
	local t = tipos[id]
	if t ~= nil then return t or nil end
	if not GetItemSpell then return nil end
	local n = texto(llamar(GetItemSpell, id))
	if not n then return nil end -- aún no lo sabe: se vuelve a preguntar después
	t = porHechizo()[n] or false
	tipos[id] = t
	return t or nil
end

function Co.NecesitaAgua()
	if UnitPowerMax then
		local mx = num(llamar(UnitPowerMax, "player", 0))
		if mx ~= nil then return mx > 0 end
	end
	local _, file = UnitClass and UnitClass("player")
	return MANA[texto(file) or ""] or false
end

-- Lo que llevas: comida y agua (la que sirve para las dos cuenta en cada una).
function Co.Contar()
	local comida, agua = 0, 0
	local C = rawget(_G, "C_Container")
	if C and C.GetContainerNumSlots and C.GetContainerItemInfo then
		for bag = 0, NUM_BAG_SLOTS or 4 do
			local n = num(llamar(C.GetContainerNumSlots, bag)) or 0
			for slot = 1, n do
				local info = llamar(C.GetContainerItemInfo, bag, slot)
				local id = type(info) == "table" and num(info.itemID) or nil
				local t = id and Co.Tipo(id)
				if t then
					local c = num(info.stackCount) or 1
					if t == "agua" then agua = agua + c else comida = comida + c end
				end
			end
		end
		return comida, agua
	end
	if GetItemCount then
		for id, t in pairs(CONOCIDOS) do
			local c = num(llamar(GetItemCount, id)) or 0
			if t == "agua" then agua = agua + c else comida = comida + c end
		end
	end
	return comida, agua
end

function Co.Sugerencia(lv)
	lv = num(lv) or nivel()
	local f = Co.NIVELES[1]
	for _, x in ipairs(Co.NIVELES) do
		if x.nivel <= lv then f = x end
	end
	return { comida = f.pan, carne = f.carne, agua = f.agua, nivel = f.nivel }
end

function Co.Nombre(id)
	local n = GetItemInfo and texto((llamar(GetItemInfo, id)))
	return n or NOMBRES[id] or ("#" .. tostring(id))
end

-- La flecha al vendedor de comida (o al posadero) más cercano.
function Co.Ir()
	if M.Rec and M.Rec.IrA then M.Rec.IrA("food") end
end

---------------------------------------------------------------------------
-- El aviso
---------------------------------------------------------------------------

local nivelAviso = { comida = 0, agua = 0 } -- 0 bien, 1 poca, 2 nada (lo último que se dijo)
local conocido = false                      -- la primera cuenta no avisa
local tuvo = {}                             -- comida / agua: alguna vez llevabas bastante (esta sesión)
local estado = { comida = 0, agua = 0, bajo = {} }

local function grado(n, umbral)
	if n <= 0 then return 2 end
	if n <= umbral then return 1 end
	return 0
end

-- "Pan de maíz húmedo" o "Jugo de melón": lo de tu nivel para lo que falta.
function Co.QueComprar(faltan)
	local s = Co.Sugerencia()
	if faltan.comida and faltan.agua then return format(L["%s y %s"], Co.Nombre(s.comida), Co.Nombre(s.agua)) end
	return Co.Nombre(faltan.agua and s.agua or s.comida)
end

local function avisar(faltan, nada, cuantos)
	local titulo
	if faltan.comida and faltan.agua then
		titulo = nada and L["Te quedaste sin comida ni agua"] or L["Te queda poca comida y agua"]
	elseif faltan.agua then
		titulo = nada and L["Te quedaste sin agua"] or L["Te queda poca agua"]
	else
		titulo = nada and L["Te quedaste sin comida"] or L["Te queda poca comida"]
	end
	local txt = format(L["A tu nivel te conviene %s: lo vende el posadero o un vendedor de comida."], Co.QueComprar(faltan))
	if cuantos and cuantos > 0 then txt = (cuantos == 1 and L["Te queda 1."] or format(L["Te quedan %d."], cuantos)) .. " " .. txt end
	K.Aviso({ titulo = titulo, texto = txt, icono = "ic-comercio", tono = "aviso", duracion = 10,
		accion = { texto = L["Llévame a comprar"], alClic = Co.Ir } })
end

function Co.Revisar(silencio)
	if combate() then
		N.FueraDeCombate("inicio.comida", function() Co.Revisar(silencio) end)
		return
	end
	local comida, agua = Co.Contar()
	local umbral = tonumber(N.Get("inicio", "comidaMin")) or 5
	local mana = Co.NecesitaAgua()
	estado.comida, estado.agua, estado.mana = comida, agua, mana
	local gc = grado(comida, umbral)
	local ga = mana and grado(agua, umbral) or 0
	local faltan, nada, sube = {}, false, false
	local primera = not conocido
	if gc > nivelAviso.comida then faltan.comida, sube = true, true end
	if ga > nivelAviso.agua then faltan.agua, sube = true, true end
	-- Al avisar de una, la otra también si ya anda baja.
	if sube then
		if gc > 0 then faltan.comida = true end
		if ga > 0 then faltan.agua = true end
		nada = (not faltan.comida or gc == 2) and (not faltan.agua or ga == 2)
	end
	nivelAviso.comida, nivelAviso.agua = gc, ga
	-- La alerta de Hoy solo para lo que sí llevabas (o ya se avisó).
	if gc == 0 then tuvo.comida = true end
	if ga == 0 then tuvo.agua = true end
	if faltan.comida and not primera and not silencio then tuvo.comida = true end
	if faltan.agua and not primera and not silencio then tuvo.agua = true end
	estado.bajo.comida, estado.bajo.agua = gc > 0 and tuvo.comida or false, ga > 0 and tuvo.agua or false
	conocido = true
	if primera or silencio or not sube or not on("comidaAviso") then return end
	if A.Hidden and A.Hidden() then return end
	local cuantos = (faltan.comida and not faltan.agua and comida) or (faltan.agua and not faltan.comida and agua) or nil
	avisar(faltan, nada, cuantos)
	if M.Pagina and M.Pagina.Relayout then M.Pagina.Relayout() end
end

function Co.Estado() return estado end

-- Para el banco: como recién entrando.
function Co.Reiniciar()
	nivelAviso.comida, nivelAviso.agua = 0, 0
	conocido = false
	tuvo = {}
end

-- La alerta de Hoy: solo después de que se te acabó (no a quien nunca lleva).
function Co.Bajo()
	if not on("comidaAviso") then return false end
	return (estado.bajo.comida or estado.bajo.agua) and true or false
end

local pendiente = false
local function pronto()
	if pendiente then return end
	pendiente = true
	A.After(2, function()
		pendiente = false
		Co.Revisar()
	end)
end
Co.Pronto = pronto

A.RegisterEvent("BAG_UPDATE_DELAYED", pronto)
A.RegisterEvent("PLAYER_ENTERING_WORLD", function() A.After(5, function() Co.Revisar(true) end) end)
A.On("SETTING_CHANGED", function(path)
	if path == "inicio.comidaMin" or path == "inicio.comidaAviso" then
		Co.Revisar(true)
		if M.Pagina and M.Pagina.Relayout then M.Pagina.Relayout() end
	end
end)
