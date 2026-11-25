-- Alfa - Lya 2.0: sus recuerdos y sus días especiales (1.4.0, 12).
-- toxic3000 / La Jauría. GPL-3.0.
--
--   * «¿Te acuerdas de cuando…?»: de vez en cuando, en un rato tranquilo (la
--     ronda de Charla.lua, «recuerdo»), Lya recuerda una página de tu historia
--     (TuHistoria.lua) que tenga al menos DIAS días: tu primera montura, el
--     nivel 30, tu primer raro, tu mejor día... La misma, como mucho una vez
--     cada OLVIDO días. También a pedido: /alfa lya recuerdo.
--   * Días especiales: la semana, el mes, los 100 días, el medio año y el año
--     desde que empezaron a cazar juntos (Temporada.lua: desde), y tus días de
--     caza 10, 50, 100 y 365. Una vez cada uno, con su aullido, al poco de
--     entrar (fuera de combate y de instancias: lo cuida Cerebro).
--   lya.recuerdos (de fábrica, sí).
--
--   Re.Elegir() -> entrada, días | nil     Re.Algo(opts) -> true si habló
--   Re.Contar(pedido)    Re.Especial() -> clave | nil (lo que festejó)

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = M.L
local ID = M.ID

local tostring, type, tonumber, ipairs, pairs, pcall, format, random, floor = tostring, type, tonumber, ipairs, pairs, pcall, string.format, math.random, math.floor

local Re = {}
M.Recuerdos = Re

local DIAS = 2      -- una página es recuerdo desde los 2 días
local OLVIDO = 20   -- la misma, como mucho una vez cada 20 días

local FRASES = { -- %s: la página, %s: hace cuánto
	"¿Te acuerdas de «%s»? Fue hace %s. Yo lo recuerdo como si fuera ayer.",
	"«%s»… hace %s de eso. ¡Qué buena caza fue esa!",
	"Estaba pensando en «%s», hace %s. Desde ahí supe que íbamos lejos.",
	"¿Te acuerdas de cuando pasó esto: «%s»? Ya van %s. Cómo crecimos.",
}

local ANIVERSARIOS = { -- días desde que empezaron
	{ 7, "Hoy cumplimos una semana cazando juntos. ¡Y apenas vamos empezando!" },
	{ 30, "¡Un mes cazando juntos! Gracias por dejarme acompañarte. ¿Me das una salchicha de festejo?" },
	{ 100, "¡Cien días desde que empezamos! Mira todo lo que hemos hecho: está en «Tu temporada»." },
	{ 182, "Medio año juntos. La manada ya no se imagina la caza sin ti." },
	{ 365, "¡Un año! Un año entero de caminos, misiones y salchichas. Te quiero mucho, compañero de caza." },
}
local DIAS_CAZA = { -- tus días de caza
	{ 10, "Diez días de caza contigo. Esto ya es costumbre, y me encanta." },
	{ 50, "¡Cincuenta días de caza! Ya conozco tu paso de memoria." },
	{ 100, "¡Cien días de caza juntos! Eres de los que no se rinden." },
	{ 365, "Trescientos sesenta y cinco días de caza. Un año de días contigo. ¡Auuu!" },
}
Re.ANIVERSARIOS, Re.DIAS_CAZA = ANIVERSARIOS, DIAS_CAZA

local function activo() return N.Get(ID, "recuerdos") ~= false end
local function reloj() return (GetServerTime and GetServerTime()) or (time and time()) or 0 end

local function memoria()
	local d = N.DatosPersonaje(ID)
	d.recuerdos = type(d.recuerdos) == "table" and d.recuerdos or {}
	local r = d.recuerdos
	r.dichos = type(r.dichos) == "table" and r.dichos or {}
	r.especiales = type(r.especiales) == "table" and r.especiales or {}
	return r
end

local function diasDe(f)
	local Te = M.Temporada
	return Te and Te.DiasDesde and Te.DiasDesde(f) or 0
end

-- Una página de tu historia para recordar (al azar entre las que tocan).
function Re.Elegir()
	local Di = M.Diario
	if not Di then return nil end
	local r = memoria()
	local ahora = reloj()
	local opciones = {}
	for _, e in ipairs(Di.Lista()) do
		local dias = diasDe(e.fecha)
		local llave = tostring(e.clave) .. ":" .. tostring(e.fecha)
		if e.clave ~= "inicio" and dias >= DIAS and ahora - (tonumber(r.dichos[llave]) or 0) >= OLVIDO * 86400 then
			opciones[#opciones + 1] = { e = e, dias = dias, llave = llave }
		end
	end
	if #opciones == 0 then return nil end
	local o = opciones[random(#opciones)]
	return o.e, o.dias, o.llave
end

function Re.Texto(e, dias, n)
	local Di = M.Diario
	local titulo = Di and Di.Titulo(e) or "?"
	local hace = N.Plural(dias, L["%d día"], L["%d días"])
	n = n or random(#FRASES)
	return format(L[FRASES[n]], titulo, hace)
end

function Re.Algo(opts)
	opts = opts or {}
	if not activo() and not opts.pedido then return false end
	local e, dias, llave = Re.Elegir()
	if not e then return false end
	local Ce = M.Cerebro
	if not (Ce and Ce.Decir) then return false end
	local ok, por = Ce.Decir({ texto = Re.Texto(e, dias), pedido = opts.pedido, salto = true, lineas = 4, clase = "charla",
		acciones = { { texto = L["Ver tu temporada"], fn = function() if M.Temporada then M.Temporada.Abrir() end end } },
		alDecir = function() memoria().dichos[llave] = reloj() end })
	return ok == true, por
end

function Re.Contar(pedido)
	if Re.Algo({ pedido = pedido ~= false }) then return true end
	local Ce = M.Cerebro
	local t = L["Todavía estamos juntando recuerdos. ¡Vamos a hacer algo que contar!"]
	if Ce and Ce.Activa and Ce.Activa() and Ce.Decir({ texto = t, pedido = true, salto = true }) == true then return true end
	N.Imprimir(t)
	return false
end

-- Los días especiales: -> la clave de lo que festejó, o nil.
function Re.Especial()
	if not activo() then return nil end
	local Te = M.Temporada
	if not Te then return nil end
	local t = Te.Libro()
	local r = memoria()
	local hoy = diasDe(t.desde)
	local dias = tonumber(t.dias) or 0
	local cual, texto
	for _, a in ipairs(ANIVERSARIOS) do
		-- El día justo (o hasta 2 días después, si no entraste ese día).
		if hoy >= a[1] and hoy <= a[1] + 2 and not r.especiales["a" .. a[1]] then cual, texto = "a" .. a[1], a[2] end
	end
	if not cual then
		for _, a in ipairs(DIAS_CAZA) do
			if dias >= a[1] and not r.especiales["d" .. a[1]] then cual, texto = "d" .. a[1], a[2] end
		end
	end
	if not cual then return nil end
	local Ce = M.Cerebro
	if not (Ce and Ce.Decir) then return nil end
	local ok = Ce.Decir({ texto = L[texto], importante = true, aullar = true, segundos = 12, lineas = 4,
		acciones = { { texto = L["Ver tu temporada"], fn = function() Te.Abrir() end } },
		alDecir = function() memoria().especiales[cual] = reloj() end })
	if ok == true or ok == "espera" then
		-- Lo que ya pasó sin festejarse (días de caza más chicos) no se festeja después.
		for _, a in ipairs(DIAS_CAZA) do if dias >= a[1] then r.especiales["d" .. a[1]] = r.especiales["d" .. a[1]] or true end end
		return cual
	end
	return nil
end

A.OnLogin(function()
	-- La primera vez con la 1.4.0: los días de caza que ya tenías no se festejan.
	local r = memoria()
	if not r.empezado then
		r.empezado = reloj()
		local Te = M.Temporada
		local dias = Te and tonumber(Te.Libro().dias) or 0
		for _, a in ipairs(DIAS_CAZA) do if dias >= a[1] then r.especiales["d" .. a[1]] = true end end
	end
	A.After(75, function() pcall(Re.Especial) end)
end)
