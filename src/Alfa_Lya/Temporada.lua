-- Alfa - Lya: tu temporada con la manada (1.4.0, 11). toxic3000 / La Jauría.
-- GPL-3.0.
--
--   Tu aventura desde que usas Alfa con este personaje, junta en un solo
--   lugar: lo que ya guardan Lya (tu día de caza, tu historia, las
--   salchichas, las historias de tus misiones), Pesca (peces y récords),
--   Inicio (tu tiempo jugado) y Bolsas (tu oro). Nada se toca: solo se lee.
--   Lo que nadie contaba de por vida (misiones, niveles, oro ganado, raros,
--   caídas, minutos y días de caza, mazmorras y guías terminadas) lo cuenta
--   aquí desde la 1.4.0: N.DatosPersonaje("lya").temporada. La primera vez
--   empieza con lo que ya había en tu semana de caza (Dia.lua) y desde el día
--   en que empezó tu historia (TuHistoria.lua).
--   Se ve en su ventana (VentanaTemporada.lua, /alfa temporada, la página de
--   Lya) y se comparte con un texto para Discord SIN tu nombre, tu reino ni
--   los de nadie (N.SinPrivado).
--
--   Te.Sumar(campo, n)  (Dia.lua, FinMazmorra.lua, Festejos.lua)
--   Te.Libro() -> la cuenta guardada     Te.Datos() -> todo junto, ya leído
--   Te.TextoCompartir(d) -> texto para Discord     Te.Abrir()

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = M.L
local ID = M.ID

local type, tonumber, tostring, ipairs, pairs, pcall, format, floor, max = type, tonumber, tostring, ipairs, pairs, pcall, string.format, math.floor, math.max

local Te = {}
M.Temporada = Te

local CAMPOS = { "misiones", "niveles", "oro", "raros", "muertes", "minutos", "mazmorras", "guias" }
local DEL_DIA = { misiones = true, niveles = true, oro = true, raros = true, muertes = true, minutos = true }

local function secreto(v) return issecretvalue ~= nil and type(v) ~= "nil" and issecretvalue(v) and true or false end
local function leer(v) if secreto(v) then return nil end return v end
local function fecha() return date and date("%Y-%m-%d") or "?" end

---------------------------------------------------------------------------
-- La cuenta de por vida
---------------------------------------------------------------------------
function Te.Libro()
	local d = N.DatosPersonaje(ID)
	local t = d.temporada
	if type(t) == "table" then return t end
	t = { dias = 0 }
	for _, c in ipairs(CAMPOS) do t[c] = 0 end
	-- Lo que ya había: tu semana de caza (hoy y los 6 días de antes).
	local lista = {}
	if type(d.dia) == "table" then lista[#lista + 1] = d.dia end
	for _, x in ipairs(type(d.dias) == "table" and d.dias or {}) do lista[#lista + 1] = x end
	local primera
	for _, x in ipairs(lista) do
		if type(x) == "table" then
			for c in pairs(DEL_DIA) do t[c] = t[c] + (tonumber(x[c]) or 0) end
			if (tonumber(x.minutos) or 0) > 0 then t.dias = t.dias + 1 end
			if type(x.fecha) == "string" and (not primera or x.fecha < primera) then primera = x.fecha end
		end
	end
	if type(d.dia) == "table" and (tonumber(d.dia.minutos) or 0) > 0 then t.ultimoDia = d.dia.fecha end
	-- Desde cuándo: el día que empezó tu historia (o el más viejo que se sabe).
	local h = type(d.historia) == "table" and d.historia or nil
	local desde = h and type(h.empezado) == "string" and h.empezado or nil
	if primera and (not desde or primera < desde) then desde = primera end
	t.desde = desde or fecha()
	local okN, lv = pcall(UnitLevel, "player")
	t.nivelInicio = okN and tonumber(leer(lv)) or nil
	d.temporada = t
	return t
end

function Te.Sumar(campo, n)
	local t = Te.Libro()
	n = tonumber(n) or 1
	t[campo] = (tonumber(t[campo]) or 0) + n
	-- Un día de caza más: el primer minuto de cada día.
	if campo == "minutos" then
		local hoy = fecha()
		if t.ultimoDia ~= hoy then
			t.ultimoDia = hoy
			t.dias = (tonumber(t.dias) or 0) + 1
		end
	end
	return t[campo]
end

---------------------------------------------------------------------------
-- Todo junto
---------------------------------------------------------------------------
local function pesca()
	local d = N.DatosPersonaje("pesca")
	local v = type(d) == "table" and type(d.vida) == "table" and d.vida or nil
	if not v then return nil end
	local distintos = 0
	for _ in pairs(type(d.diario) == "table" and d.diario or {}) do distintos = distintos + 1 end
	return { capturas = tonumber(v.capturas) or 0, racha = tonumber(v.mejorRacha) or 0, horas = floor((tonumber(v.segundos) or 0) / 3600),
		distintos = distintos }
end

local function jugado()
	local I = rawget(_G, "AlfaInicio")
	if type(I) ~= "table" or type(I.Jugado) ~= "function" then return nil end
	local ok, j = pcall(I.Jugado)
	return ok and type(j) == "table" and tonumber(j.total) or nil
end

local function oroAhora()
	local ok, m = pcall(GetMoney)
	return ok and tonumber(leer(m)) or nil
end

local function personaje()
	local okC, clase = pcall(UnitClass, "player")
	local okR, raza = pcall(UnitRace, "player")
	local okN, nivel = pcall(UnitLevel, "player")
	clase, raza, nivel = okC and leer(clase), okR and leer(raza), okN and tonumber(leer(nivel))
	return type(clase) == "string" and clase or nil, type(raza) == "string" and raza or nil, nivel
end

-- Días entre dos fechas "AAAA-MM-DD" (0 el mismo día).
local function diasDesde(f)
	if type(f) ~= "string" then return 0 end
	local y, m, d = f:match("^(%d+)%-(%d+)%-(%d+)$")
	if not y then return 0 end
	local ok, a = pcall(time, { year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
	local hoy = date and date("*t")
	local ok2, b = pcall(time, { year = hoy and hoy.year or 2000, month = hoy and hoy.month or 1, day = hoy and hoy.day or 1, hour = 12 })
	if not (ok and ok2 and a and b) then return 0 end
	return max(0, floor((b - a) / 86400 + 0.5))
end
Te.DiasDesde = diasDesde

function Te.Datos()
	local t = Te.Libro()
	local d = N.DatosPersonaje(ID)
	local clase, raza, nivel = personaje()
	local x = { desde = t.desde, conAlfa = diasDesde(t.desde), dias = tonumber(t.dias) or 0, clase = clase, raza = raza,
		nivel = nivel, nivelInicio = t.nivelInicio, jugado = jugado(), oroAhora = oroAhora(), pesca = pesca() }
	for _, c in ipairs(CAMPOS) do x[c] = tonumber(t[c]) or 0 end
	-- Récords
	local rec = type(d.record) == "table" and d.record or nil
	x.mejorDia = rec and tonumber(rec.misiones) or 0
	x.mejorDiaFecha = rec and rec.fecha or nil
	-- Momentos con Lya
	x.salchichas = M.Momentos and M.Momentos.Salchichas and M.Momentos.Salchichas() or tonumber(d.salchichas) or 0
	local Hi = M.Historias
	x.historias = Hi and Hi.Cuantas and select(2, pcall(Hi.Cuantas)) or 0
	x.historias = tonumber(x.historias) or 0
	local Di = M.Diario
	local lista = Di and Di.Lista() or {}
	x.paginas = #lista
	x.momentos = {}
	for i = 1, math.min(4, #lista) do
		local e = lista[i]
		x.momentos[i] = { icono = e.icono or "ic-huella", titulo = Di.Titulo(e), linea = Di.Linea(e), fecha = e.fecha }
	end
	return x
end

---------------------------------------------------------------------------
-- El texto para Discord (sin nada privado)
---------------------------------------------------------------------------
local function miles(n)
	n = floor(tonumber(n) or 0)
	if N.Numero then
		local ok, s = pcall(N.Numero, n)
		if ok and type(s) == "string" then return s end
	end
	return tostring(n)
end

local function oro(cobre) return format(L["%s de oro"], miles(floor((tonumber(cobre) or 0) / 10000))) end

-- -> el texto (en líneas cortas, con ** de Discord), sin tu nombre ni tu reino.
function Te.TextoCompartir(x)
	x = x or Te.Datos()
	local l = {}
	l[#l + 1] = L["**Mi temporada con la manada** (Alfa, La Jauría)"]
	local quien = {}
	if x.raza then quien[#quien + 1] = x.raza end
	if x.clase then quien[#quien + 1] = x.clase end
	if x.nivel then quien[#quien + 1] = format(L["nivel %d"], x.nivel) end
	if #quien > 0 then l[#l + 1] = table.concat(quien, " · ") end
	l[#l + 1] = format(L["%s de caza en %s con Alfa"], N.Plural(x.dias, L["%d día"], L["%d días"]), N.Plural(max(1, x.conAlfa), L["%d día"], L["%d días"]))
	local partes = {}
	if x.misiones > 0 then partes[#partes + 1] = N.Plural(x.misiones, L["%d misión"], L["%d misiones"]) end
	if x.niveles > 0 then partes[#partes + 1] = N.Plural(x.niveles, L["%d nivel"], L["%d niveles"]) end
	if x.mazmorras > 0 then partes[#partes + 1] = N.Plural(x.mazmorras, L["%d mazmorra"], L["%d mazmorras"]) end
	if x.guias > 0 then partes[#partes + 1] = N.Plural(x.guias, L["%d guía terminada"], L["%d guías terminadas"]) end
	if #partes > 0 then l[#l + 1] = table.concat(partes, " · ") end
	partes = {}
	if x.pesca and x.pesca.capturas > 0 then partes[#partes + 1] = N.Plural(x.pesca.capturas, L["%d pez"], L["%d peces"]) end
	if x.raros > 0 then partes[#partes + 1] = N.Plural(x.raros, L["%d raro visto"], L["%d raros vistos"]) end
	if x.oro > 0 then partes[#partes + 1] = format(L["%s ganados"], oro(x.oro)) end
	if #partes > 0 then l[#l + 1] = table.concat(partes, " · ") end
	if x.mejorDia > 0 then l[#l + 1] = format(L["Mi mejor día: %d misiones"], x.mejorDia) end
	if x.salchichas > 0 then l[#l + 1] = format(L["Salchichas para Lya: %d"], x.salchichas) end
	l[#l + 1] = L["¡Auuu!"]
	local s = table.concat(l, "\n")
	if N.SinPrivado then
		local ok, r = pcall(N.SinPrivado, s)
		if ok and type(r) == "string" then s = r end
	end
	return s
end

function Te.Abrir()
	local V = M.VentanaTemporada
	if V and V.Abrir then return V.Abrir() end
	N.Imprimir(Te.TextoCompartir())
	return false
end

A.RegisterCommand("temporada", function() Te.Abrir() end, L["tu temporada con la manada: tu aventura desde que usas Alfa"])

A.OnLogin(function()
	Te.Libro()
	local Lya = rawget(_G, "AlfaLya")
	if type(Lya) == "table" and type(Lya.Ensenar) == "function" then
		pcall(Lya.Ensenar, { id = "lya.temporada", icono = "ic-lobo", modulo = "lya",
			pregunta = L["¿Cuánto llevamos cazando juntos?"],
			respuesta = L["Mira «Tu temporada» (en mi página o con /alfa temporada): tus días de caza, misiones, mazmorras, peces, oro y récords, y un texto para presumirlo en Discord."] })
	end
end)

local API = rawget(_G, "AlfaLya")
if type(API) == "table" then API.Temporada = function() return Te.Datos() end end
