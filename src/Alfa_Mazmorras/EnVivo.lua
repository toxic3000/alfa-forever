-- Alfa - Mazmorras: la mazmorra en vivo (1.2.9). toxic3000 / La Jauría. GPL-3.0.
--
-- Dentro de una mazmorra, cuando apuntas a un jefe (o empieza su encuentro),
-- una tarjeta chica arriba de la pantalla: su nombre, lo que te toca hacer
-- según tu papel (tanque, cura o daño) de sus consejos (Consejos/*.lua) y tus
-- misiones de esta mazmorra con cómo van (Plan.lua): las listas, palomeadas.
--
-- Reglas:
--   * Nunca atrapa clics (no tiene ratón) y nunca abre ventanas del juego.
--   * Los nombres y la vida de los enemigos en una mazmorra pueden ser
--     secretos: aquí solo se lee el GUID del objetivo si no es secreto (para
--     sacar el id del PNJ) o el id del encuentro (ENCOUNTER_START). El nombre
--     del jefe sale de los datos del diario, nunca del objetivo.
--   * Nada pesado en combate: los jefes de la mazmorra (por PNJ y por
--     encuentro) se indexan al entrar, fuera de combate; tus misiones se
--     leen fuera de combate y en combate se usa lo último leído.
--   * Se va sola al perder al jefe de objetivo (unos segundos después), al
--     terminar el encuentro y al salir de la mazmorra.
-- Ajustes: mazmorras.enVivo (sí) y mazmorras.enVivoRol ("auto" | "tanque" |
-- "cura" | "dano"). Con "auto": el papel del buscador de grupo si lo hay; si
-- no, por tu clase y tu forma (un guerrero en postura defensiva o un druida
-- oso tanquean, un sacerdote cura; lo demás, daño).
--
--   Ev.Papel() -> "tanque" | "cura" | "dano"
--   Ev.Mostrar(key, jefe) -> true    Ev.Ocultar()    Ev.Indexar() -> key | nil
--   Ev.Consejos(jefe, papel) -> { texto, ... }   Ev.Misiones(key) -> { { texto, lista }, ... }

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = N.Textos(M.EN)
local D = M.D

local type, ipairs, pairs, pcall, tonumber, tostring, format, next = type, ipairs, pairs, pcall, tonumber, tostring, string.format, next
local max, min = math.max, math.min

local Ev = {}
M.EnVivo = Ev

local ID = D.ID
local ANCHO, PAD = 300, 10
local CONSEJOS, MISIONES = 3, 3
local LISTO = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t"

local function secreto(v)
	local C = A.Compat
	if C and C.IsSecret then return C.IsSecret(v) == true end
	return issecretvalue ~= nil and type(v) ~= "nil" and issecretvalue(v) and true or false
end
local function leer(v) if secreto(v) then return nil end return v end

local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end

local function enMazmorra()
	if not IsInInstance then return false end
	local ok, dentro, tipo = pcall(IsInInstance)
	return ok and leer(dentro) == true and leer(tipo) == "party"
end

local function activa() return N.Get(ID, "enVivo") ~= false end

---------------------------------------------------------------------------
-- Tu papel
---------------------------------------------------------------------------
local ROL = { TANK = "tanque", HEALER = "cura", DAMAGER = "dano" }

function Ev.Papel()
	local v = N.Get(ID, "enVivoRol")
	if v == "tanque" or v == "cura" or v == "dano" then return v end
	if UnitGroupRolesAssigned then
		local ok, r = pcall(UnitGroupRolesAssigned, "player")
		r = ok and leer(r) or nil
		if ROL[r] then return ROL[r] end
	end
	local clase
	if UnitClass then
		local ok, _, t = pcall(UnitClass, "player")
		clase = ok and leer(t) or nil
	end
	local forma
	if GetShapeshiftFormID then
		local ok, f = pcall(GetShapeshiftFormID)
		forma = ok and tonumber(leer(f)) or nil
	end
	if clase == "PRIEST" then return "cura" end
	if clase == "WARRIOR" then
		local ok, f = pcall(GetShapeshiftForm or function() return 0 end)
		if (ok and tonumber(leer(f)) == 2) or forma == 18 then return "tanque" end
	end
	if clase == "DRUID" and (forma == 5 or forma == 8) then return "tanque" end
	return "dano"
end

local NOMBRE_ROL = { tanque = "Tanqueas", cura = "Curas", dano = "Haces daño" }

---------------------------------------------------------------------------
-- Los jefes de la mazmorra donde estás, indexados fuera de combate
---------------------------------------------------------------------------
local actual -- { key, porNpc = { [id] = jefe }, porEncuentro = { [id] = jefe } }

function Ev.Indexar()
	if enCombate() or not enMazmorra() then return actual and actual.key or nil end
	if not D.Listo() then return nil end
	local key = D.MazmorraActual()
	if not key then actual = nil return nil end
	if actual and actual.key == key and next(actual.porNpc) then return key end
	local x = { key = key, porNpc = {}, porEncuentro = {} }
	for _, j in ipairs(D.Jefes(key)) do
		if type(j.npc) == "number" then x.porNpc[j.npc] = j end
		if type(j.encuentro) == "number" then x.porEncuentro[j.encuentro] = j end
	end
	actual = x
	Ev.LeerMisiones()
	return key
end
Ev.Actual = function() return actual end

-- El id del PNJ de un GUID legible ("Creature-0-1-2-3-644-000...").
local function npcDe(guid)
	if type(guid) ~= "string" or secreto(guid) then return nil end
	local partes = {}
	for p in guid:gmatch("[^%-]+") do partes[#partes + 1] = p end
	local tipo, id = partes[1], partes[6]
	if tipo ~= "Creature" and tipo ~= "Vehicle" then return nil end
	return tonumber(id)
end
Ev.NpcDe = npcDe

---------------------------------------------------------------------------
-- Qué decir
---------------------------------------------------------------------------
-- Los consejos para tu papel primero, luego los de todos; hasta CONSEJOS.
function Ev.Consejos(jefe, papel)
	local out = {}
	local lista = type(jefe) == "table" and jefe.consejos or nil
	if type(lista) ~= "table" then return out end
	for _, c in ipairs(lista) do
		if type(c) == "table" and c.rol == papel and #out < CONSEJOS then out[#out + 1] = N.Traducir(c[1], c[2]) end
	end
	for _, c in ipairs(lista) do
		if type(c) == "table" and not c.rol and #out < CONSEJOS then out[#out + 1] = N.Traducir(c[1], c[2]) end
	end
	return out
end

-- 1.3.8: lo que más importa de la pelea, en una línea: el consejo con más
-- peso (interrumpir, salir del fuego, quitar un veneno, matar primero a sus
-- ayudantes...), los de tu papel con un poco más. Se mira el texto en
-- español (el de los datos); sale en el idioma del cliente.
local PESOS = {
	{ "interrump", 6 }, { "fuego", 5 }, { "sal de", 5 }, { "salgan", 5 }, { "aléj", 5 }, { "alej", 5 }, { "charco", 5 },
	{ "suelo", 4 }, { "quita", 4 }, { "veneno", 3 }, { "maldición", 3 }, { "enfermedad", 3 }, { "primero", 3 },
	{ "invoca", 3 }, { "llama a", 3 }, { "asusta", 3 }, { "miedo", 3 }, { "huye", 3 }, { "no corran", 2 },
	{ "rápido", 2 }, { "aturde", 2 }, { "espaldas", 2 }, { "vida del tanque", 2 },
}
local function peso(es)
	if type(es) ~= "string" then return 0 end
	local t = es:lower()
	local n = 0
	for _, p in ipairs(PESOS) do
		if t:find(p[1], 1, true) then n = n + p[2] end
	end
	return n
end
Ev.Peso = peso

function Ev.LoMasImportante(jefe, papel)
	local lista = type(jefe) == "table" and jefe.consejos or nil
	if type(lista) ~= "table" then return nil end
	local mejor, mejorPeso
	for _, c in ipairs(lista) do
		if type(c) == "table" and (c.rol == nil or c.rol == papel) then
			local w = peso(c[1]) + (c.rol == papel and 2 or 0)
			if not mejor or w > mejorPeso then mejor, mejorPeso = c, w end
		end
	end
	return mejor and N.Traducir(mejor[1], mejor[2]) or nil
end

-- Tus misiones de esta mazmorra (las de tu registro): leídas fuera de combate.
local misiones = {} -- key -> { { texto, lista }, ... }

function Ev.LeerMisiones(key)
	key = key or (actual and actual.key)
	if not key or enCombate() then return misiones[key] end
	local P = M.P
	local ok, e = pcall(function() return P and P.Estado(key) end)
	local out = {}
	if ok and type(e) == "table" then
		for _, f in ipairs(e.lista or {}) do
			if f.grupo == "registro" and type(f.q) == "table" then
				local lista = f.orden == 1 or f.orden == 2
				local titulo = P.Citar and P.Citar(f.q.title) or tostring(f.q.title or "")
				local tx = P.Texto and P.Texto(f) or f.texto
				local detalle = not lista and type(tx) == "string" and tx ~= "" and tx or nil
				out[#out + 1] = { texto = detalle and format(L["%s: %s"], titulo, detalle) or titulo, lista = lista }
			end
		end
		table.sort(out, function(a, b) if a.lista ~= b.lista then return not a.lista end return a.texto < b.texto end)
	end
	misiones[key] = out
	return out
end

function Ev.Misiones(key) return misiones[key] or {} end

---------------------------------------------------------------------------
-- La tarjeta
---------------------------------------------------------------------------
local t -- el marco

local function construir()
	t = CreateFrame("Frame", "AlfaMazmorrasEnVivo", K.Raiz())
	t:SetFrameStrata("MEDIUM")
	t:SetFrameLevel(20)
	t:SetClampedToScreen(true)
	t:EnableMouse(false) -- nunca atrapa clics
	t:SetSize(ANCHO, 60)
	t:SetPoint("TOP", UIParent, "TOP", 0, -150)
	t.caja = K.Caja(t, { fondo = "panel", borde = "lineaFuerte", corte = K.CORTE.panel })
	t.Icono = K.Icono(t, "ic-mazmorra", 16, "acento")
	t.Icono:SetPoint("TOPLEFT", t, "TOPLEFT", PAD, -PAD)
	t.Titulo = K.Texto(t, "encabezado", "texto")
	t.Titulo:SetPoint("TOPLEFT", t, "TOPLEFT", PAD + 22, -PAD)
	t.Papel = K.Texto(t, "pequeno", "acento")
	t.Papel:SetJustifyH("RIGHT")
	t.Papel:SetPoint("TOPRIGHT", t, "TOPRIGHT", -PAD, -PAD - 1)
	t.lineas = {}
	t:Hide()
	return t
end

local function linea(i)
	local fs = t.lineas[i]
	if not fs then
		fs = K.Texto(t, "nota", "texto")
		t.lineas[i] = fs
	end
	return fs
end

local turno = 0

---------------------------------------------------------------------------
-- 1.3.8: la línea (de fábrica): una tira chica con el jefe y lo que más
-- importa de su pelea. Tampoco atrapa clics. Ajuste mazmorras.enVivoForma:
-- "linea" | "tarjeta" (la de antes, con tres consejos y tus misiones).
---------------------------------------------------------------------------
local tl
local LINEA_MAX, LINEA_MIN = 440, 220

local function forma() return N.Get(ID, "enVivoForma") == "tarjeta" and "tarjeta" or "linea" end
Ev.Forma = forma

local function construirLinea()
	tl = CreateFrame("Frame", "AlfaMazmorrasEnVivoLinea", K.Raiz())
	tl:SetFrameStrata("MEDIUM")
	tl:SetFrameLevel(20)
	tl:SetClampedToScreen(true)
	tl:EnableMouse(false) -- nunca atrapa clics
	tl:SetSize(LINEA_MIN, 28)
	tl:SetPoint("TOP", UIParent, "TOP", 0, -150)
	tl.caja = K.Caja(tl, { fondo = "panel", borde = "lineaFuerte", corte = K.CORTE.control })
	tl.Icono = K.Icono(tl, "ic-mazmorra", 14, "acento")
	tl.Icono:SetPoint("TOPLEFT", tl, "TOPLEFT", 8, -7)
	tl.Texto = K.Texto(tl, "nota", "texto")
	tl.Texto:SetPoint("TOPLEFT", tl, "TOPLEFT", 28, -7)
	tl:Hide()
	return tl
end

local function mostrarLinea(key, jefe)
	if not tl then construirLinea() end
	local papel = Ev.Papel()
	tl.key, tl.jefe = key, jefe
	local nombre = type(jefe.nombre) == "string" and jefe.nombre or L["Jefe"]
	local consejo = Ev.LoMasImportante(jefe, papel) or L["Sin consejos para este jefe: vayan con calma y escuchen al tanque."]
	local texto = K.Tenir("acento", nombre) .. "  \194\183  " .. consejo
	K.Escribir(tl.Texto, texto)
	local ancho = math.floor(K.AnchoTexto(tl.Texto) + 0.5)
	local w = max(LINEA_MIN, min(LINEA_MAX, ancho + 28 + 10))
	local h = K.Parrafo(tl.Texto, w - 28 - 10, 2)
	tl:SetSize(w, max(28, h + 14))
	tl:Show()
	if t then t:Hide() end
	return true
end

function Ev.Mostrar(key, jefe)
	if not (activa() and type(jefe) == "table") then return false end
	if forma() == "linea" then
		turno = turno + 1
		return mostrarLinea(key, jefe)
	end
	if tl then tl:Hide() end
	if not t then construir() end
	turno = turno + 1
	local papel = Ev.Papel()
	t.key, t.jefe = key, jefe
	K.Escribir(t.Papel, L[NOMBRE_ROL[papel]])
	local anchoPapel = K.AnchoTexto(t.Papel)
	K.Escribir(t.Titulo, type(jefe.nombre) == "string" and jefe.nombre or L["Jefe"])
	K.Parrafo(t.Titulo, ANCHO - 2 * PAD - 22 - anchoPapel - 8, 1)
	t.Titulo:SetWordWrap(false)
	local y = PAD + max(16, K.AltoTexto(t.Titulo)) + 6
	local n = 0
	local tw = ANCHO - 2 * PAD
	local function poner(texto, color)
		n = n + 1
		local fs = linea(n)
		fs.alfaColor = color or "texto"
		K.ColorTexto(fs, fs.alfaColor)
		K.Escribir(fs, texto)
		fs:ClearAllPoints()
		fs:SetPoint("TOPLEFT", t, "TOPLEFT", PAD, -y)
		y = y + K.Parrafo(fs, tw, 3) + 4
		fs:Show()
	end
	local consejos = Ev.Consejos(jefe, papel)
	for _, c in ipairs(consejos) do poner("- " .. c, "texto") end
	if #consejos == 0 then poner(L["Sin consejos para este jefe: vayan con calma y escuchen al tanque."], "textoSuave") end
	local ms = Ev.Misiones(key)
	if #ms > 0 then
		y = y + 2
		poner(L["Tus misiones aquí"], "acento")
		for i = 1, min(MISIONES, #ms) do
			local m = ms[i]
			poner((m.lista and (LISTO .. " ") or "- ") .. m.texto, m.lista and "exito" or "textoSuave")
		end
	end
	for i = n + 1, #t.lineas do t.lineas[i]:Hide() end
	t:SetHeight(y + PAD - 4)
	t:Show()
	return true
end

function Ev.Ocultar()
	turno = turno + 1
	if t then t:Hide() t.key, t.jefe = nil, nil end
	if tl then tl:Hide() tl.key, tl.jefe = nil, nil end
end

function Ev.Visible() return (t and t:IsShown()) or (tl and tl:IsShown()) and true or false end
function Ev.Marco() return t end
function Ev.Linea() return tl end
-- Lo que se ve ahora (la tarjeta o la línea): su clave y su jefe.
local function vista()
	if tl and tl:IsShown() then return tl end
	return t
end

-- Se va en unos segundos si nada la vuelve a pedir.
local function irseEn(seg)
	turno = turno + 1
	local mio = turno
	K.Despues(seg, function() if mio == turno then Ev.Ocultar() end end)
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------
local encuentro = false

local function alObjetivo()
	if not activa() or not enMazmorra() then Ev.Ocultar() return end
	if not actual then
		if enCombate() then return end
		Ev.Indexar()
		if not actual then return end
	end
	local guid = UnitGUID and UnitGUID("target")
	local npc = npcDe(guid)
	local jefe = npc and actual.porNpc[npc]
	if jefe then
		if not enCombate() then Ev.LeerMisiones(actual.key) end
		Ev.Mostrar(actual.key, jefe)
		-- 1.3.7: lo que te falta tomar antes de la pelea (Consumibles.lua).
		if not enCombate() and M.Consumibles then pcall(M.Consumibles.AlJefe, actual.key, jefe) end
	elseif Ev.Visible() and not encuentro then
		irseEn(4)
	end
end
Ev.AlObjetivo = alObjetivo

A.RegisterEvent("PLAYER_TARGET_CHANGED", function() alObjetivo() end)

A.RegisterEvent("ENCOUNTER_START", function(_, encId)
	encId = tonumber(leer(encId))
	if not (encId and activa() and actual) then return end
	local jefe = actual.porEncuentro[encId]
	if jefe then
		encuentro = true
		Ev.Mostrar(actual.key, jefe)
	end
end)

A.RegisterEvent("ENCOUNTER_END", function()
	encuentro = false
	if Ev.Visible() then irseEn(3) end
end)

-- Al salir del combate: tus misiones al día (lo que mataste pudo contar).
A.RegisterEvent("PLAYER_REGEN_ENABLED", function()
	encuentro = false
	if not actual then return end
	Ev.LeerMisiones(actual.key)
	local x = vista()
	if Ev.Visible() and x and x.jefe then Ev.Mostrar(x.key, x.jefe) irseEn(20) end
end)

A.RegisterEvent("QUEST_LOG_UPDATE", function()
	if actual and not enCombate() and Ev.Visible() then
		K.Despues(0.5, function()
			local x = vista()
			if actual and not enCombate() and Ev.Visible() and x and x.jefe then
				Ev.LeerMisiones(actual.key)
				Ev.Mostrar(x.key, x.jefe)
			end
		end)
	end
end)

A.RegisterEvent("PLAYER_ENTERING_WORLD", function()
	Ev.Ocultar()
	actual, encuentro = nil, false
	A.After(5, function() N.FueraDeCombate("mazmorras.envivo", function() pcall(Ev.Indexar) end) end)
end)

A.On("CODEX_LOADED", function() if actual then actual.porNpc = {} end end)

A.On("SETTING_CHANGED", function(path)
	if path == ID .. ".enVivo" and not activa() then Ev.Ocultar() end
	local x = vista()
	if (path == ID .. ".enVivoRol" or path == ID .. ".enVivoForma") and Ev.Visible() and x and x.jefe then Ev.Mostrar(x.key, x.jefe) end
end)

-- Lya lo enseña en «¿En qué te ayudo?».
if A.OnLogin then
	A.OnLogin(function()
		local Lya = rawget(_G, "AlfaLya")
		if type(Lya) == "table" and type(Lya.Ensenar) == "function" then
			pcall(Lya.Ensenar, { id = "mazmorras.envivo", icono = "ic-mazmorra", modulo = "mazmorras",
				pregunta = L["¿Qué hago contra este jefe?"],
				respuesta = L["Dentro de una mazmorra, apunta al jefe: arriba te sale una tarjeta con lo que te toca según tu papel y cómo van tus misiones de ahí."] })
		end
	end)
end
