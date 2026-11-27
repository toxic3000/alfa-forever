-- Alfa - Combate: «¿Qué me tumbó?», lo que te tumbó al caer (1.4.2). toxic3000 / La Jauría. GPL-3.0.
--
-- Al morir, cuando el juego deja leer los números (fuera de combate), un
-- aviso corto: el golpe final, los tres golpes que más daño te hicieron (y
-- de quién) y cuánto de ese daño se podía evitar (lo del suelo, lo que el
-- juego marca como evitable). Así sabes qué cambiar en el siguiente intento.
-- De dónde sale: el medidor oficial del juego (C_DamageMeter), tipo
-- DamageTaken de tu propia fila (GetCombatSessionSourceFromType con tu
-- GUID): sus hechizos traen isDeadly, isAvoidable y overkillAmount. El
-- registro de combate es restringido en Forever: no se usa.
-- Reglas:
--   * Nada en combate: se lee 1,5 s después de caer y fuera de combate; si
--     el juego aún lo da secreto (tu grupo sigue peleando), se intenta otra
--     vez unos segundos después (hasta 3 veces). Lo secreto no se lee: si un
--     nombre llega secreto, esa parte no sale.
--   * Nada se manda a nadie. La última caída se guarda por personaje para
--     verla otra vez desde Combate, el menú del medidor o /alfa combate caida.
--   * Ajuste combate.caida (sí): apagado no sale el aviso, pero se guarda.
--
--   Ca.Leer() -> { total, evitable, golpes = { { nombre, quien, valor } }, final } | nil
--   Ca.Ultima() -> lo guardado | nil   Ca.Texto(c) -> texto   Ca.Ver(pedido) -> true | false

local ADDON, M = ...
local N, A, K, L = M.N, M.A, M.K, M.L
local Ca = {}
M.Caida = Ca

local type, ipairs, pcall, floor, min, format, tostring = type, ipairs, pcall, math.floor, math.min, string.format, tostring

M.AJUSTES.caida = true -- el aviso al caer (siempre se guarda)

Ca.INTENTOS = 3   -- cuántas veces se intenta leer si llega secreto
Ca.ESPERA = 5     -- segundos entre intentos
Ca.TOPE = 3       -- cuántos golpes se dicen

local function numero(v)
	if M.Secreto(v) or type(v) ~= "number" then return nil end
	return v
end

local function texto(v)
	if M.Secreto(v) or type(v) ~= "string" or v == "" then return nil end
	return v
end

local function actual()
	local E = Enum and Enum.DamageMeterSessionType
	return E and E.Current or 1
end

local function num(v)
	if M.Medidor and M.Medidor.Numero then return M.Medidor.Numero(v) end
	return tostring(floor((v or 0) + 0.5))
end

---------------------------------------------------------------------------
-- Leer
---------------------------------------------------------------------------
-- El nombre de un golpe: su hechizo; sin hechizo, cuerpo a cuerpo si alguien
-- te lo dio, o el entorno (una caída, la lava, el agua).
local function nombreGolpe(id, quien)
	if id and id > 0 then
		local n = M.NombreHechizo(id)
		if n then return n end
	end
	if quien then return L["Golpes cuerpo a cuerpo"] end
	return L["El entorno (una caída, lava o el agua)"]
end

function Ca.Leer()
	local D = M.Medidor
	if not (D and D.Existe() and D.Disponible()) then return nil end
	if M.EnCombate() then return nil, "combate" end
	local fn = C_DamageMeter.GetCombatSessionSourceFromType
	if type(fn) ~= "function" then return nil end
	local guid = M.Legible(M.Llamar(UnitGUID, "player"))
	if type(guid) ~= "string" then return nil end
	local tipo = D.EnumTipo and D.EnumTipo("DamageTaken") or 7
	local s = M.Llamar(fn, actual(), tipo, guid)
	if M.Secreto(s) then return nil, "secreto" end
	local lista = type(s) == "table" and s.combatSpells
	if M.Secreto(lista) then return nil, "secreto" end
	if type(lista) ~= "table" then return nil end
	local todos, total, evitable, final = {}, 0, 0, nil
	local oculto = false
	for _, x in ipairs(lista) do
		if type(x) == "table" then
			local v = numero(x.totalAmount)
			if M.Secreto(x.totalAmount) then oculto = true end
			if v and v > 0 then
				local id = numero(x.spellID)
				local quien = texto(x.creatureName)
				local g = { id = id, quien = quien, valor = v, nombre = nombreGolpe(id, quien) }
				todos[#todos + 1] = g
				total = total + v
				if M.Legible(x.isAvoidable) == true then evitable = evitable + v g.evitable = true end
				-- El golpe final: el que el juego marca como mortal, o el que pasó de largo tu vida.
				local mortal = M.Legible(x.isDeadly) == true or (numero(x.overkillAmount) or 0) > 0
				if mortal and (not final or v > final.valor) then final = g end
			end
		end
	end
	if #todos == 0 then return nil, oculto and "secreto" or nil end
	table.sort(todos, function(a, b) return a.valor > b.valor end)
	local golpes = {}
	for i = 1, min(Ca.TOPE, #todos) do
		local g = todos[i]
		golpes[i] = { nombre = g.nombre, quien = g.quien, valor = g.valor, evitable = g.evitable }
	end
	return { total = total, evitable = evitable, golpes = golpes,
		final = final and { nombre = final.nombre, quien = final.quien } or nil }
end

---------------------------------------------------------------------------
-- Decirlo
---------------------------------------------------------------------------
function Ca.Texto(c)
	if type(c) ~= "table" then return nil end
	local lineas = {}
	local f = c.final
	if type(f) == "table" and f.nombre then
		lineas[#lineas + 1] = f.quien and format(L["El golpe final: %s, de %s."], f.nombre, f.quien)
			or format(L["El golpe final: %s."], f.nombre)
	end
	for _, g in ipairs(c.golpes or {}) do
		local quien = g.quien and format(L["%s (de %s)"], g.nombre, g.quien) or g.nombre
		lineas[#lineas + 1] = format("\194\183 %s: %s", quien, num(g.valor))
	end
	local total, ev = tonumber(c.total) or 0, tonumber(c.evitable) or 0
	if total > 0 and ev > 0 then
		local pct = floor(ev * 100 / total + 0.5)
		if pct >= 1 then
			lineas[#lineas + 1] = format(L["El %d %% de ese daño se podía evitar: muévete de lo que hay en el suelo y de lo que el jefe avisa."], pct)
		end
	end
	if #lineas == 0 then return nil end
	return table.concat(lineas, "\n")
end

function Ca.Ultima()
	local u = N.DatosPersonaje(M.ID).ultimaCaida
	return type(u) == "table" and u or nil
end

-- pedido: lo pediste tú (sale ya, sin esperar su turno).
function Ca.Ver(pedido)
	local u = Ca.Ultima()
	if not u then
		if pedido then N.Imprimir(L["Todavía no has caído en una pelea: aquí saldrá lo que te tumbó."]) end
		return false
	end
	local t = Ca.Texto(u)
	if not t then return false end
	K.Aviso({ id = "combate.caida", titulo = L["Lo que te tumbó"], texto = t, icono = "ic-alerta", tono = "aviso",
		duracion = 16, pedido = pedido and true or nil, prioridad = 3, agrupar = false,
		donde = L["Combate > Tu última caída"] })
	return true
end

---------------------------------------------------------------------------
-- Al caer
---------------------------------------------------------------------------
local intentos = 0

local function revisar()
	local c, porque = Ca.Leer()
	if not c then
		if (porque == "secreto" or porque == "combate") and intentos < Ca.INTENTOS then
			intentos = intentos + 1
			N.Una("combate.caida", Ca.ESPERA, function() N.FueraDeCombate("combate.caida", revisar) end)
		end
		return false
	end
	intentos = 0
	local z = GetRealZoneText and GetRealZoneText()
	c.zona = texto(z)
	c.cuando = time and time() or nil
	N.DatosPersonaje(M.ID).ultimaCaida = c
	M.Avisar()
	if M.Opt("caida") then Ca.Ver(false) end
	return true
end
Ca.Revisar = revisar

function Ca.AlCaer()
	intentos = 0
	N.Una("combate.caida", 1.5, function() N.FueraDeCombate("combate.caida", revisar) end)
end

A.RegisterEvent("PLAYER_DEAD", function() K.Llamar(Ca.AlCaer) end)

A.OnLogin(function()
	M.Ensenar({ id = "combate.caida", icono = "ic-alerta",
		pregunta = L["¿Qué me tumbó?"],
		respuesta = L["Cuando caes, Alfa te dice el golpe final, lo que más daño te hizo y cuánto se podía evitar. Lo ves otra vez en Combate, en el menú del medidor o con /alfa combate caida."] })
end)
