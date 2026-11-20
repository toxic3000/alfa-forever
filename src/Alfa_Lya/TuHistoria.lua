-- Alfa - Lya: tu historia (1.2.8). toxic3000 / La Jauría. GPL-3.0.
--
--   Un diario de lo grande que vas logrando con este personaje: tu primera
--   mazmorra, los niveles 10, 20, 30, 40, 50 y 60, tu primera montura, el
--   primer raro que cazaste, tu primer oficio al máximo, tu mejor día de caza
--   (Dia.lua: d.record), tu primera semana de caza (d.dias) y tu última
--   mazmorra (FinMazmorra.lua). Cada página lleva su fecha, su ícono y una
--   línea de Lya; al escribir una nueva, Lya la festeja (una vez).
--   Se ve en su página («Tu historia») y con /alfa lya historia.
--
--   Lo que ya tenías al empezar a escribir (tu nivel, tu montura, un oficio al
--   máximo) no se festeja: la primera página dice desde dónde empezamos.
--   lya.historia apaga el diario (y sus festejos).
--
--   Di.Anotar(e) -> bool   e = { clave, icono, t, a = { ... }, l, b = { ... },
--                                 reemplaza (la misma clave, al día), festejo (false: callada) }
--     t / l: claves de texto (el título y la línea de Lya) y sus argumentos a / b
--   Di.Lista() -> { entrada, ... } (la más nueva primero)   Di.Titulo(e)  Di.Linea(e)
--   Di.Tiene(clave)   Di.Empezar()

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID

local type, tonumber, ipairs, pcall, format, unpack = type, tonumber, ipairs, pcall, string.format, unpack or table.unpack

local Di = {}
M.Diario = Di

local MAX = 60
local NIVELES = { [10] = true, [20] = true, [30] = true, [40] = true, [50] = true, [60] = true }
local LINEA_NIVEL = {
	[10] = "Diez niveles juntos. Ya hueles a aventura.",
	[20] = "Veinte. Ya te respetan en los caminos.",
	[30] = "Treinta. La manada habla de ti.",
	[40] = "Cuarenta. ¡Hora de correr más rápido!",
	[50] = "Cincuenta. Casi en la cima, y yo contigo.",
	[60] = "¡Sesenta! Lo lograste. Me debes una salchicha gigante.",
}
local RIDING = 762

local function secreto(v) return issecretvalue ~= nil and v ~= nil and issecretvalue(v) and true or false end
local function num(v) if secreto(v) then return nil end return tonumber(v) end
local function texto(v) if secreto(v) or type(v) ~= "string" or v == "" then return nil end return v end
local function si(v) if secreto(v) then return false end return v == true end
local function fecha() return date and date("%Y-%m-%d") or "?" end
local function reloj() return (GetServerTime and GetServerTime()) or (time and time()) or 0 end

local function libro()
	local d = N.DatosPersonaje(ID)
	local h = type(d.historia) == "table" and d.historia or {}
	d.historia = h
	h.lista = type(h.lista) == "table" and h.lista or {}
	h.hechos = type(h.hechos) == "table" and h.hechos or {}
	return h
end

function Di.Activo() return N.Get(ID, "historia") ~= false end
function Di.Lista() return libro().lista end
function Di.Tiene(clave) return libro().hechos[clave] ~= nil end

local function armar(clave, args)
	if type(clave) ~= "string" then return "" end
	local t = L[clave]
	if type(args) == "table" and #args > 0 then
		local ok, s = pcall(format, t, unpack(args))
		if ok then return s end
	end
	return t
end
function Di.Titulo(e) return armar(e.t, e.a) end
function Di.Linea(e)
	-- La última mazmorra: su línea se arma con el tiempo de ahora (el idioma de hoy).
	if e.clave == "corrida" and M.FinMazmorra and M.FinMazmorra.Linea then
		local ok, s = pcall(M.FinMazmorra.Linea, e)
		if ok and type(s) == "string" then return s end
	end
	return armar(e.l, e.b)
end

local function festejar(e)
	local Ce = M.Cerebro
	if not Ce then return end
	local c = { importante = true, aullar = true, segundos = 12, lineas = 4, enMazmorra = true,
		texto = format(L["¡Nueva página en tu historia: %s! %s"], Di.Titulo(e), Di.Linea(e)),
		acciones = { { texto = L["Ver tu historia"], fn = function() N.Abrir(ID) end } } }
	-- Después de lo que Lya diga en ese momento (el aullido del nivel, el consejo de la mazmorra).
	K.Despues(20, function() Ce.Decir(c) end)
end

function Di.Anotar(e)
	if type(e) ~= "table" or type(e.clave) ~= "string" or not Di.Activo() then return false end
	local h = libro()
	if not h.empezado and e.clave ~= "inicio" then return false end
	if h.hechos[e.clave] and not e.reemplaza then return false end
	local entrada = { clave = e.clave, fecha = fecha(), hora = reloj(), icono = e.icono or "ic-huella",
		t = e.t, a = e.a, l = e.l, b = e.b, datos = e.datos }
	if e.reemplaza then
		for i = #h.lista, 1, -1 do if h.lista[i].clave == e.clave then table.remove(h.lista, i) end end
	end
	h.hechos[e.clave] = entrada.fecha
	table.insert(h.lista, 1, entrada)
	while #h.lista > MAX do table.remove(h.lista) end
	M.Avisar()
	if e.festejo ~= false then festejar(entrada) end
	return true
end

-- Lya te la cuenta (el enlace de su página, /alfa lya historia la abre).
function Di.Contar()
	local lista = Di.Lista()
	local t
	if #lista == 0 then
		t = L["Todavía no escribimos nada en tu historia. ¡Vamos a hacer algo grande!"]
	elseif #lista == 1 then
		t = format(L["Tu historia tiene una página: %s."], Di.Titulo(lista[1]))
	else
		t = format(L["Llevamos %d páginas en tu historia. La más nueva: %s."], #lista, Di.Titulo(lista[1]))
	end
	local Ce = M.Cerebro
	if Ce and Ce.Activa and Ce.Activa() and Ce.Decir({ texto = t, pedido = true, salto = true, lineas = 4 }) == true then return true end
	N.Imprimir(t)
	return true
end

---------------------------------------------------------------------------
-- Lo que ya tenías: la primera página
---------------------------------------------------------------------------
local function nivel() return num(UnitLevel and UnitLevel("player")) end

local function montado()
	if not IsMounted then return false end
	local ok, v = pcall(IsMounted)
	return ok and si(v)
end

local function cabalgas()
	local S = C_SkillInfo
	if S and S.GetSkillLineInfoByID then
		local ok, info = pcall(S.GetSkillLineInfoByID, RIDING)
		if ok and type(info) == "table" then return (num(info.rank) or 0) > 0 end
	end
	return false
end

-- La primera vez (o al prender el diario): desde dónde empezamos.
function Di.Empezar()
	if not Di.Activo() then return false end
	local h = libro()
	if h.empezado then return false end
	local lv = nivel()
	if not lv then return false end
	h.empezado = fecha()
	for n in pairs(NIVELES) do if n <= lv then h.hechos["nivel" .. n] = h.empezado end end
	if montado() or cabalgas() then h.hechos.montura = h.empezado end
	local O = M.Oficios
	if O and O.Leer then
		local ok, lista = pcall(O.Leer)
		if ok and type(lista) == "table" then
			for _, o in ipairs(lista) do if o.rank >= 300 then h.hechos.oficioMax = h.empezado end end
		end
	end
	if lv > 1 then
		return Di.Anotar({ clave = "inicio", icono = "ic-huella", t = "Empezamos a escribir (nivel %d)", a = { lv },
			l = "Desde hoy apunto cada paso grande que demos juntos.", festejo = false })
	end
	return Di.Anotar({ clave = "inicio", icono = "ic-huella", t = "Tu primer día en Azeroth",
		l = "Aquí empieza tu historia. Y yo voy contigo.", festejo = false })
end

---------------------------------------------------------------------------
-- Lo que se anota
---------------------------------------------------------------------------
A.RegisterEvent("PLAYER_LEVEL_UP", function(_, n)
	n = num(n)
	if not (n and NIVELES[n]) then return end
	Di.Anotar({ clave = "nivel" .. n, icono = "ic-nivel", t = "Nivel %d", a = { n }, l = LINEA_NIVEL[n] })
end)

-- La primera montura: al montarte (o al aprender a cabalgar).
local function anotarMontura()
	if Di.Tiene("montura") then return end
	Di.Anotar({ clave = "montura", icono = "ic-aventura", t = "Tu primera montura",
		l = "¡Ahora sí te sigo corriendo con la lengua de fuera!" })
end
A.RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED", function() if montado() then anotarMontura() end end)
A.RegisterEvent("SKILL_LINES_CHANGED", function() if libro().empezado and cabalgas() then anotarMontura() end end)

-- El primer raro que cazaste: lo tienes en el blanco y cae.
local presa -- { guid, nombre }
local function esRaro(unit)
	if not UnitClassification then return false end
	local ok, cl = pcall(UnitClassification, unit)
	if not ok or secreto(cl) then return false end
	return cl == "rare" or cl == "rareelite"
end
local function revisarPresa()
	if not presa or Di.Tiene("raro") then return end
	local guid = texto(UnitGUID and UnitGUID("target"))
	if guid ~= presa.guid then return end
	local muerto = UnitIsDead and si(UnitIsDead("target"))
	if not muerto then return end
	-- Que fuera tuyo (no de otro que lo marcó primero).
	if UnitIsTapDenied and si(UnitIsTapDenied("target")) then presa = nil return end
	local nombre = presa.nombre
	presa = nil
	if nombre then
		Di.Anotar({ clave = "raro", icono = "ic-raros", t = "Tu primer raro: %s", a = { nombre },
			l = "Lo olimos, lo seguimos y cayó. ¡Así caza la manada!" })
	else
		Di.Anotar({ clave = "raro", icono = "ic-raros", t = "Tu primer raro",
			l = "Lo olimos, lo seguimos y cayó. ¡Así caza la manada!" })
	end
end
-- (1.3.2) La vida del blanco se escucha solo mientras hay presa, y solo la de
-- "target": UNIT_HEALTH de todas las unidades son cientos por segundo en banda.
local vida
local function vigilar(prender)
	if prender then
		if not vida then
			vida = CreateFrame("Frame")
			vida:SetScript("OnEvent", A.Safe(function(_, _, unit)
				if presa and not secreto(unit) and unit == "target" then revisarPresa() end
				if not presa then vigilar(false) end
			end))
		end
		if not vida.alfaOyendo then
			vida:RegisterUnitEvent("UNIT_HEALTH", "target")
			vida.alfaOyendo = true
		end
	elseif vida and vida.alfaOyendo then
		vida:UnregisterEvent("UNIT_HEALTH")
		vida.alfaOyendo = nil
	end
end
function Di.VigilaPresa() return vida ~= nil and vida.alfaOyendo == true end -- (para el banco)

A.RegisterEvent("PLAYER_TARGET_CHANGED", function()
	if Di.Tiene("raro") or not Di.Activo() then presa = nil vigilar(false) return end
	local guid = texto(UnitGUID and UnitGUID("target"))
	if guid and esRaro("target") and not (UnitIsDead and si(UnitIsDead("target"))) then
		local puede = not UnitCanAttack or si(UnitCanAttack("player", "target"))
		if puede then presa = { guid = guid, nombre = texto(UnitName and UnitName("target")) } end
	end
	vigilar(presa ~= nil)
end)

-- Tu mejor día (Dia.lua lo festeja; aquí se apunta) y tu primera semana de caza.
local function revisarDias()
	local d = N.DatosPersonaje(ID)
	local rec = type(d.record) == "table" and d.record or nil
	local n = rec and tonumber(rec.misiones) or 0
	local h = libro()
	if n >= 10 and n > (tonumber(h.record) or 0) and rec.fecha == fecha() then
		h.record = n
		Di.Anotar({ clave = "record", icono = "ic-misiones", t = "Tu mejor día: %d misiones", a = { n },
			l = "Ese día ni la manada te alcanzaba.", reemplaza = true, festejo = false })
	end
	if type(d.dias) == "table" and #d.dias >= 6 then
		Di.Anotar({ clave = "semana", icono = "ic-hoy", t = "Una semana de caza juntos",
			l = "Siete días de caza contigo. Esto ya es costumbre, y me encanta." })
	end
end
A.RegisterEvent("QUEST_TURNED_IN", function() pcall(revisarDias) end)

A.OnLogin(function()
	A.After(20, function()
		Di.Empezar()
		if M.Dia and M.Dia.Hoy then M.Dia.Hoy() end
		pcall(revisarDias)
	end)
end)

A.On("SETTING_CHANGED", function(path)
	if path == ID .. ".historia" and Di.Activo() then Di.Empezar() end
end)
