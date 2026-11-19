-- Alfa - Lya: tu día de caza y lo que festeja (1.2.5). toxic3000 / La Jauría.
-- GPL-3.0.
--
--   * Tu día de caza: por personaje y por día, las misiones que entregaste,
--     los niveles que subiste, el oro que ganaste, los raros que viste, las
--     veces que caíste y el tiempo jugado. Lya lo cuenta cuando se lo pides
--     (/alfa lya dia, «Pregúntale a Lya») y, al entrar otro día, te cuenta
--     cómo te fue la última vez.
--   * Al entregar una misión, Lya da su saltito; cada 5 en el día (salvo 10 y
--     25, que ya son un logro en Cerebro.lua) te echa porras. Con
--     lya.aullidoMision (apagado de fábrica), un aullido corto.
--   * Cuando alguien de tu grupo sube de nivel, Lya aúlla y lo felicita, con
--     «Felicitar en el grupo» (lya.aullarGrupo, prendido de fábrica).
--
--   Di.Hoy() -> { fecha, misiones, niveles, oro, raros, muertes, minutos }
--   Di.Resumen(d) -> texto | nil (nil: un día sin nada que contar)

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = M.L
local ID = M.ID

local Di = {}
M.Dia = Di

local format, floor, type, tonumber = string.format, math.floor, type, tonumber

local function num(v)
	if issecretvalue and issecretvalue(v) then return nil end
	return tonumber(v)
end
local function texto(v)
	if issecretvalue and issecretvalue(v) then return nil end
	return type(v) == "string" and v ~= "" and v or nil
end

local function fecha() return date and date("%Y-%m-%d") or "?" end

-- El día de hoy de este personaje (al cambiar de día, el de antes queda como «ayer»).
function Di.Hoy()
	local d = N.DatosPersonaje(ID)
	local f = fecha()
	if type(d.dia) ~= "table" or d.dia.fecha ~= f then
		if type(d.dia) == "table" then
			d.diaAyer = d.dia
			-- 1.2.6: los últimos 6 días, para tu semana de caza.
			d.dias = type(d.dias) == "table" and d.dias or {}
			table.insert(d.dias, 1, d.dia)
			while #d.dias > 6 do table.remove(d.dias) end
		end
		d.dia = { fecha = f, misiones = 0, niveles = 0, oro = 0, raros = 0, muertes = 0, minutos = 0 }
	end
	return d.dia
end

local function sumar(campo, n)
	local h = Di.Hoy()
	h[campo] = (tonumber(h[campo]) or 0) + (n or 1)
	return h[campo]
end

local function oro(cobre)
	if N.Dinero then
		local ok, s = pcall(N.Dinero, cobre)
		if ok and type(s) == "string" then return s end
	end
	return format("%d o", floor(cobre / 10000))
end

local function tiempo(min)
	min = floor(tonumber(min) or 0)
	if min < 60 then return format(L["%d min"], min) end
	return format(L["%d h %d min"], floor(min / 60), min % 60)
end

-- "12 misiones, 1 nivel, 3 raros y 2 o 15 p ganados en 1 h 20 min".
function Di.Resumen(d)
	d = d or Di.Hoy()
	local partes = {}
	local function poner(n, uno, varios)
		n = tonumber(n) or 0
		if n > 0 then partes[#partes + 1] = format(n == 1 and L[uno] or L[varios], n) end
	end
	poner(d.misiones, "%d misión", "%d misiones")
	poner(d.niveles, "%d nivel", "%d niveles")
	poner(d.raros, "%d raro visto", "%d raros vistos")
	if (tonumber(d.oro) or 0) > 0 then partes[#partes + 1] = format(L["%s ganados"], oro(d.oro)) end
	if #partes == 0 then return nil end
	local lista = partes[1]
	if #partes > 1 then lista = table.concat(partes, ", ", 1, #partes - 1) .. L[" y "] .. partes[#partes] end
	local t = format(L["%s en %s de caza."], lista, tiempo(d.minutos))
	local caidas = tonumber(d.muertes) or 0
	if caidas > 0 then t = t .. " " .. format(caidas == 1 and L["Caíste %d vez, pero te levantaste."] or L["Caíste %d veces, pero siempre te levantaste."], caidas) end
	return t
end

-- 1.2.6: tu semana de caza: hoy y los 6 días de antes que jugaste, sumados.
function Di.Semana()
	local d = N.DatosPersonaje(ID)
	local s = { misiones = 0, niveles = 0, oro = 0, raros = 0, muertes = 0, minutos = 0, dias = 0 }
	local lista = { Di.Hoy() }
	for _, x in ipairs(type(d.dias) == "table" and d.dias or {}) do lista[#lista + 1] = x end
	for _, x in ipairs(lista) do
		if type(x) == "table" then
			for k in pairs(s) do if k ~= "dias" then s[k] = s[k] + (tonumber(x[k]) or 0) end end
			if (tonumber(x.minutos) or 0) > 0 then s.dias = s.dias + 1 end
		end
	end
	return s
end

-- Tu mejor día (lo más que entregaste en un día): { misiones, fecha } o nil.
function Di.Record()
	local r = N.DatosPersonaje(ID).record
	return type(r) == "table" and r or nil
end

function Di.ContarSemana()
	local s = Di.Semana()
	local r = Di.Resumen(s)
	local t = r and format(L["Esta semana llevas %s"], r) or L["Esta semana todavía no cazamos nada. ¿Salimos?"]
	local rec = Di.Record()
	if rec and (tonumber(rec.misiones) or 0) > 0 then
		t = t .. " " .. format(L["Tu mejor día: %d misiones."], rec.misiones)
	end
	local Ce = M.Cerebro
	if Ce and Ce.Activa and Ce.Activa() and Ce.Decir({ texto = t, salto = true, pedido = true, lineas = 5 }) then return true end
	N.Imprimir(t)
	return true
end

-- Lya lo cuenta (o lo dice en el chat si no está a la vista).
function Di.Contar()
	local r = Di.Resumen()
	local t = r and format(L["Hoy llevas %s"], r) or L["Hoy todavía no cazamos nada. ¿Salimos?"]
	local Ce = M.Cerebro
	if Ce and Ce.Activa and Ce.Activa() and Ce.Decir({ texto = t, salto = true }) then return true end
	N.Imprimir(t)
	return true
end

---------------------------------------------------------------------------
-- Lo que se cuenta
---------------------------------------------------------------------------

local dinero
local function leerDinero()
	if not GetMoney then return nil end
	local ok, m = pcall(GetMoney)
	return ok and num(m) or nil
end

A.RegisterEvent("PLAYER_ENTERING_WORLD", function() dinero = leerDinero() end)
A.RegisterEvent("PLAYER_MONEY", function()
	local m = leerDinero()
	if m and dinero and m > dinero then sumar("oro", m - dinero) end
	dinero = m or dinero
end)
A.RegisterEvent("PLAYER_LEVEL_UP", function() sumar("niveles") end)
A.RegisterEvent("PLAYER_DEAD", function() sumar("muertes") end)
if A.On then
	A.On("RARE_SPOTTED", function(a)
		if type(a) == "table" and a.kind ~= "founder" then sumar("raros") end
	end)
end
N.Cada("lya.minutos", 60, function() sumar("minutos") end) -- un solo reloj (1.2.9)

local PORRAS = {
	"¡Van %d misiones hoy! La manada está orgullosa.",
	"¡%d misiones hoy! A este paso me debes una salchicha.",
	"%d misiones y contando. ¡Qué buena caza!",
}

A.RegisterEvent("QUEST_TURNED_IN", function()
	local n = sumar("misiones")
	local UI = M.UI
	local combate = InCombatLockdown and InCombatLockdown()
	if UI and UI.Visible and UI.Visible() and not combate then pcall(UI.Saltar) end
	if N.Get(ID, "aullidoMision") then
		local B = rawget(_G, "AlfaBienvenida")
		if B and B.Aullar then pcall(B.Aullar, true) end
	end
	-- 1.2.6: tu récord de misiones en un día (lo dice una vez al día, desde 5).
	local d = N.DatosPersonaje(ID)
	local rec = type(d.record) == "table" and d.record or { misiones = 0 }
	local nuevo = n > (tonumber(rec.misiones) or 0)
	if nuevo then d.record = { misiones = n, fecha = fecha() } end
	local h = Di.Hoy()
	if nuevo and n >= 5 and not h.recordDicho and (tonumber(rec.misiones) or 0) > 0 and M.Cerebro then
		h.recordDicho = true
		M.Cerebro.Decir({ importante = true, aullar = true, texto = format(L["¡Nuevo récord: %d misiones en un día! Ni la manada te alcanza."], n) })
		return
	end
	if n % 5 == 0 and n ~= 10 and n ~= 25 and M.Cerebro then
		M.Cerebro.Decir({ texto = format(L[PORRAS[math.random(#PORRAS)]], n), salto = true })
	end
end)

-- Otro día: cómo te fue la última vez (una vez).
A.OnLogin(function()
	A.After(40, function()
		Di.Hoy()
		local d = N.DatosPersonaje(ID)
		local ayer = d.diaAyer
		if type(ayer) ~= "table" or ayer.dicho then return end
		ayer.dicho = true
		local r = Di.Resumen(ayer)
		if r and M.Cerebro then M.Cerebro.Decir({ texto = format(L["La última vez cazamos %s"], r) }) end
	end)
end)

---------------------------------------------------------------------------
-- La manada aúlla contigo: alguien de tu grupo sube de nivel
---------------------------------------------------------------------------

local niveles = {} -- guid -> nivel
local function felicitar(nombre, nivel)
	local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
	if not send then return end
	local canal = (IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)) and "INSTANCE_CHAT" or "PARTY"
	pcall(send, format(L["¡Felicidades por el nivel %d, %s! Auuuu."], nivel, nombre), canal)
end

A.RegisterEvent("UNIT_LEVEL", function(_, unit)
	if type(unit) ~= "string" or (issecretvalue and issecretvalue(unit)) then return end
	if not unit:match("^party%d$") then return end
	local guid = texto(UnitGUID and UnitGUID(unit))
	local nivel = num(UnitLevel and UnitLevel(unit))
	if not (guid and nivel and nivel > 0) then return end
	local antes = niveles[guid]
	niveles[guid] = nivel
	if not antes or nivel <= antes or not N.Get(ID, "aullarGrupo") then return end
	local nombre = texto(UnitName and UnitName(unit))
	if not nombre or not M.Cerebro then return end
	M.Cerebro.Decir({ importante = true, aullar = true,
		texto = format(L["¡%s subió a nivel %d! Auuuu, felicidades."], nombre, nivel),
		acciones = { { texto = L["Felicitar en el grupo"], fn = function() felicitar(nombre, nivel) end } } })
end)

-- Los niveles de tu grupo al formarse, para notar cuándo suben.
A.RegisterEvent("GROUP_ROSTER_UPDATE", function()
	for i = 1, 4 do
		local unit = "party" .. i
		local guid = texto(UnitGUID and UnitGUID(unit))
		local nivel = num(UnitLevel and UnitLevel(unit))
		if guid and nivel and nivel > 0 and not niveles[guid] then niveles[guid] = nivel end
	end
end)
