-- Alfa - Mundo: misiones cercanas por color (1.3.8). toxic3000 / La Jauría. GPL-3.0.
--
-- Una capa propia de Alfa.Pins, mundo.misionesColor: quien te da misiones en
-- tu zona que ya puedes tomar, con el color de lo difícil que es para tu
-- nivel, como el registro de misiones del juego:
--   verde: fácil (2 niveles o más por debajo del tuyo, sin ser gris)
--   amarillo: buena (de 2 abajo a 2 arriba)
--   naranja: difícil (3 o 4 arriba)
--   rojo: peligrosa (5 arriba o más)
-- Las grises no salen (no dan experiencia que valga).
--
-- Los datos son los de la base de misiones del motor (A.QuestDB,
-- Alfa_QuestDB): nada del Codex. La base no se carga al entrar: se pide al
-- abrir el mapa de Alfa con la capa encendida (Marcas.lua, Mc.PrepararDatos),
-- o se usa si ya la cargó otra cosa (QUESTDB_LOADED). El índice (zona ->
-- misiones que te tocan por facción, raza y clase, con el lugar de quien la
-- da) se arma una vez por sesión, poco a poco (LOTE misiones por cuadro,
-- nunca en combate). Si puedes tomarla ya (nivel, previas, excluyentes, ni
-- hecha ni en tu registro) lo dice la base del motor (Q.CheckAvailable).
--
--   Mc2.Preparar()  Mc2.Indexar(listo)  Mc2.Lista(zona, nivel) -> { e, ... }
--   Mc2.Color(nivelMision, nivel) -> "facil" | "buena" | "dificil" | "peligrosa" | nil (gris)
--   Mc2.Refrescar()

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)

local type, ipairs, pairs, pcall, tonumber, format, floor = type, ipairs, pairs, pcall, tonumber, string.format, math.floor
local sort = table.sort

local Mc2 = {}
M.MisionesColor = Mc2

local CAPA = "mundo.misionesColor"
Mc2.CAPA = CAPA
local LOTE = 150
local PINES = 60
local CERCA = 1.5 -- % del mapa: dos misiones del mismo PNJ comparten pin

-- Los colores de dificultad del juego (QuestDifficultyColors del Clásico).
Mc2.COLORES = {
	facil = { 0.25, 0.75, 0.25, 1 },
	buena = { 1, 0.82, 0, 1 },
	dificil = { 1, 0.5, 0.25, 1 },
	peligrosa = { 1, 0.1, 0.1, 1 },
}
local NOMBRE = { facil = "Fácil", buena = "Buena para ti", dificil = "Difícil", peligrosa = "Peligrosa" }
local ORDEN = { peligrosa = 1, dificil = 2, buena = 3, facil = 4 }

local login = false
local pedido = false -- el mapa de Alfa pidió la capa (no se arma sola al entrar)
local indice   -- zona -> { { q, nivel, x, y, f }, ... }
local armando  -- { ids, i, porZona, ctx, listo }

local function activa() return A.Get(CAPA) ~= false end
local function QD()
	local Q = A.QuestDB
	return type(Q) == "table" and Q or nil
end
local function lista() local Q = QD() return Q and type(Q.IsLoaded) == "function" and Q.IsLoaded() and Q or nil end

local function nivelJugador()
	local n = UnitLevel and UnitLevel("player")
	n = N.Leer(n)
	return tonumber(n) or 1
end

-- El nivel más alto que es gris para ti (el del juego, como el motor).
local function gris(nivel)
	local Q = QD()
	if Q and type(Q.GreyLevel) == "function" then return Q.GreyLevel(nivel) end
	if nivel <= 5 then return 0 end
	if nivel <= 39 then return nivel - 5 - floor(nivel / 10) end
	if nivel <= 59 then return nivel - 1 - floor(nivel / 5) end
	return nivel - 9
end

function Mc2.Color(nm, nivel)
	nm, nivel = tonumber(nm), tonumber(nivel) or nivelJugador()
	if not nm or nm <= 0 then nm = nivel end -- sin nivel: de tu nivel
	if nm <= gris(nivel) then return nil end
	local d = nm - nivel
	if d >= 5 then return "peligrosa" end
	if d >= 3 then return "dificil" end
	if d >= -2 then return "buena" end
	return "facil"
end

function Mc2.NombreColor(c) return c and NOMBRE[c] and L[NOMBRE[c]] or nil end

---------------------------------------------------------------------------
-- El índice
---------------------------------------------------------------------------

local function anotar(Q, F, porZona, q, ctx)
	local okR, r = pcall(Q.QuestRecord, q)
	if not (okR and type(r) == "table") then return end
	if r[F.HOLIDAY] then return end
	local okE, eleg = pcall(Q.IsEligible, r, ctx)
	if not (okE and eleg) then return end
	local start = r[F.START]
	if start == nil then return end
	local nivel = tonumber(r[F.LEVEL])
	local vistos = {}
	for _, ref in Q.Each(start) do
		if type(ref) == "number" then
			pcall(Q.EachSpawn, ref, function(_, _, map, f, x, y)
				map, x, y = tonumber(map), tonumber(x), tonumber(y)
				if not (map and x and y) or vistos[map] then return end
				vistos[map] = true
				local l = porZona[map]
				if not l then l = {} porZona[map] = l end
				l[#l + 1] = { q = q, nivel = nivel, x = x, y = y, f = f }
			end)
		end
	end
end

local function paso()
	local b = armando
	if not b then return end
	local Q = lista()
	if not Q then armando = nil return end
	if InCombatLockdown and InCombatLockdown() then
		N.FueraDeCombate("mundo.misionesColor", function() A.After(0, paso) end)
		return
	end
	local F = Q.F
	local hasta = math.min(#b.ids, b.i + LOTE - 1)
	for i = b.i, hasta do anotar(Q, F, b.porZona, b.ids[i], b.ctx) end
	b.i = hasta + 1
	if b.i > #b.ids then
		indice = b.porZona
		armando = nil
		local fin = b.listo
		Mc2.Refrescar()
		if fin then pcall(fin) end
	else
		A.After(0, paso)
	end
end

-- Arma el índice (una vez por sesión); `listo` al terminar.
function Mc2.Indexar(listo)
	if indice then if listo then listo() end return true end
	if armando then return false end
	local Q = lista()
	if not (Q and type(Q.QuestIds) == "function" and type(Q.QuestRecord) == "function" and type(Q.EachSpawn) == "function"
		and type(Q.Each) == "function" and type(Q.IsEligible) == "function" and type(Q.F) == "table") then return false end
	local okI, ids = pcall(Q.QuestIds)
	if not (okI and type(ids) == "table") then return false end
	local ctx = {}
	if type(Q.PlayerContext) == "function" then pcall(Q.PlayerContext, nil, ctx) end
	armando = { ids = ids, i = 1, porZona = {}, ctx = ctx, listo = listo }
	A.After(0, paso)
	return false
end

function Mc2.Listo() return indice ~= nil end
function Mc2.Olvidar() indice, armando = nil, nil end

-- La base de misiones: si no está, se pide (al abrir el mapa de Alfa).
function Mc2.Preparar()
	if not (login and activa()) then return false end
	pedido = true
	if lista() then
		if not indice then Mc2.Indexar() end
		return true
	end
	local Q = QD()
	if not (Q and type(Q.Load) == "function") or (InCombatLockdown and InCombatLockdown()) then return false end
	local ok = pcall(Q.Load)
	if ok and lista() then Mc2.Indexar() end
	return ok
end

---------------------------------------------------------------------------
-- Las que puedes tomar ya
---------------------------------------------------------------------------

local function hecha(q)
	local C = C_QuestLog
	local f = C and C.IsQuestFlaggedCompleted
	if type(f) ~= "function" then return false end
	local ok, v = pcall(f, q)
	return ok and N.Si(v)
end

local function enRegistro(q)
	local C = C_QuestLog
	local f = C and C.GetLogIndexForQuestID
	if type(f) == "function" then
		local ok, i = pcall(f, q)
		i = ok and tonumber(N.Leer(i)) or nil
		if i and i > 0 then return true end
	end
	f = C and C.IsOnQuest
	if type(f) == "function" then
		local ok, v = pcall(f, q)
		return ok and N.Si(v)
	end
	return false
end

-- Las de una zona que puedes tomar ya, con su color: { { q, nivel, x, y, f, color }, ... }
-- (las más difíciles primero; a lo más PINES).
function Mc2.Lista(zona, nivel)
	local out = {}
	local Q = lista()
	if not (indice and zona and Q) then return out end
	nivel = nivel or nivelJugador()
	local ctx = {}
	if type(Q.PlayerContext) == "function" then pcall(Q.PlayerContext, nil, ctx) end
	ctx.level = nivel
	for _, e in ipairs(indice[zona] or {}) do
		local ok, puede = false, false
		if type(Q.CheckAvailable) == "function" then ok, puede = pcall(Q.CheckAvailable, e.q, ctx, hecha, enRegistro, nil) end
		if ok and puede then
			local c = Mc2.Color(e.nivel, nivel)
			if c then out[#out + 1] = { q = e.q, nivel = e.nivel, x = e.x, y = e.y, f = e.f, color = c } end
		end
	end
	sort(out, function(a, b)
		if a.color ~= b.color then return ORDEN[a.color] < ORDEN[b.color] end
		return a.q < b.q
	end)
	for i = #out, PINES + 1, -1 do out[i] = nil end
	return out
end

---------------------------------------------------------------------------
-- La capa
---------------------------------------------------------------------------

local function titulo(q)
	local Q = QD()
	local t = Q and type(Q.GetQuestTitle) == "function" and select(2, pcall(Q.GetQuestTitle, q)) or nil
	if type(t) ~= "string" or N.Secreto(t) or t == "" then t = format(L["Misión %d"], q) end
	return t
end

local function pines(zona)
	local out, juntos = {}, {}
	for _, e in ipairs(Mc2.Lista(zona)) do
		-- Varias del mismo PNJ: un pin, con la más difícil (ya van primero).
		local llave
		for _, j in ipairs(juntos) do
			if j.f == e.f and math.abs(j.x - e.x) < CERCA and math.abs(j.y - e.y) < CERCA then llave = j break end
		end
		if llave then
			llave.mas[#llave.mas + 1] = e
		else
			local p = { e = e, mas = {}, x = e.x, y = e.y, f = e.f }
			juntos[#juntos + 1] = p
		end
	end
	for _, j in ipairs(juntos) do
		local e = j.e
		local col = Mc2.COLORES[e.color]
		local todos = { e }
		for _, x in ipairs(j.mas) do todos[#todos + 1] = x end
		out[#out + 1] = {
			map = zona, x = e.x, y = e.y, f = e.f, icon = "map:quest-available", size = 14, color = col, ring = col,
			priority = 5 - ORDEN[e.color], label = titulo(e.q),
			tooltip = function(tip)
				for i, x in ipairs(todos) do
					local r, g, b = Mc2.COLORES[x.color][1], Mc2.COLORES[x.color][2], Mc2.COLORES[x.color][3]
					if i == 1 then tip:SetText(titulo(x.q), r, g, b) else tip:AddLine(titulo(x.q), r, g, b) end
					local nv = tonumber(x.nivel)
					tip:AddLine(nv and nv > 0 and format(L["Nivel %d · %s"], nv, Mc2.NombreColor(x.color)) or Mc2.NombreColor(x.color), 0.8, 0.8, 0.8)
				end
			end,
		}
	end
	return out
end
Mc2.Pines = pines

function Mc2.Refrescar()
	local Pins = A.Pins
	if not (login and Pins and type(Pins.SetLayer) == "function") then return end
	local zona = M.Descubrir and M.Descubrir.Zona()
	if not (activa() and zona) then Pins.ClearLayer(CAPA) return end
	if not indice then
		Pins.ClearLayer(CAPA)
		if pedido and lista() then Mc2.Indexar() end
		return
	end
	local l = pines(zona)
	if #l > 0 then
		Pins.SetLayer(CAPA, l, { world = true, minimap = false, edge = false })
	else
		Pins.ClearLayer(CAPA)
	end
end

local pendiente = false
local function pronto(espera)
	if pendiente then return end
	pendiente = true
	A.After(espera or 1, function()
		pendiente = false
		local ok, e = pcall(Mc2.Refrescar)
		if not ok and geterrorhandler then geterrorhandler()(e) end
	end)
end
Mc2.Pronto = pronto

-- Para el banco.
function Mc2.Login() login = true end
function Mc2.Pedido() return pedido end

if type(A.OnLogin) == "function" then
	A.OnLogin(function()
		login = true
		local Lya = rawget(_G, "AlfaLya")
		if type(Lya) == "table" and type(Lya.Ensenar) == "function" then
			pcall(Lya.Ensenar, { id = "mundo.misionesColor", icono = "ic-misiones", modulo = "mundo",
				pregunta = L["¿Qué misiones me quedan bien aquí?"],
				respuesta = L["En el mapa de Alfa, la capa «Misiones por color» marca a quien te da misiones en tu zona: verde fácil, amarillo buena, naranja difícil y rojo peligrosa para tu nivel."] })
		end
	end)
end

local function luego() if login and activa() and indice then pronto(1) end end
for _, ev in ipairs({ "ZONE_CHANGED_NEW_AREA", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "PLAYER_LEVEL_UP" }) do
	A.RegisterEvent(ev, ev == "PLAYER_LEVEL_UP" and N.TrasNivel and N.TrasNivel("mundo.misionesColor", luego) or luego)
end
if A.On then
	A.On("QUESTDB_LOADED", function() if login and pedido and activa() and not indice then Mc2.Indexar() end end)
	A.On("SETTING_CHANGED", function(path)
		if path == "" or path == "mundo" or path == CAPA then
			if activa() and pedido and not indice then Mc2.Preparar() end
			pronto(0)
		end
	end)
end
