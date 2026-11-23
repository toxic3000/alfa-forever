-- Alfa - Lya: los retos de la semana (1.3.0). toxic3000 / La Jauría. GPL-3.0.
--
--   lya.retos (prendido de fábrica): cada semana (de lunes a domingo) Lya te
--   pone tres retos chiquitos: entregar misiones, ver raros y uno que cambia
--   (una mazmorra, subir niveles o un rato de caza). El avance sale de tu día
--   de caza (Dia.lua: los días de esta semana sumados) y se ve en su página.
--   Al cumplir uno, Lya lo festeja y te ganas una salchicha de premio (para
--   ella, claro): N.DatosPersonaje("lya").retos = { semana, hechos, premios }.
--
--   Re.Semana() -> "2026-11-16" (el lunes)    Re.Lista() -> { reto, ... }
--     reto = { clave, meta, avance, hecho, titulo, icono }
--   Re.Revisar() -> cuántos festejó ahora     Re.Premios() -> salchichas ganadas

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = M.L
local ID = M.ID

local type, tonumber, pcall, ipairs, format, floor = type, tonumber, pcall, ipairs, string.format, math.floor

local Re = {}
M.Retos = Re

local DIA = 24 * 3600
local NIVEL_MAX = 60

local function secreto(v) return issecretvalue ~= nil and type(v) ~= "nil" and issecretvalue(v) and true or false end
local function activo() return N.Get(ID, "retos") ~= false end

local function datos()
	local d = N.DatosPersonaje(ID)
	d.retos = type(d.retos) == "table" and d.retos or {}
	return d.retos
end

-- El lunes de esta semana, "AAAA-MM-DD".
function Re.Semana(t)
	t = t or (time and time()) or 0
	local dia = tonumber(date("%w", t)) or 1 -- 0 = domingo
	local desdeLunes = (dia + 6) % 7
	return date("%Y-%m-%d", t - desdeLunes * DIA)
end

local function hash(s)
	local h = 0
	for i = 1, #s do h = (h * 31 + s:byte(i)) % 1000003 end
	return h
end

local function nivel()
	local n = UnitLevel and UnitLevel("player")
	return (not secreto(n) and tonumber(n)) or 1
end

-- Lo que se cuenta: campo del día de caza, metas posibles, título e ícono.
Re.TIPOS = {
	misiones = { metas = { 15, 20, 25 }, uno = "Entrega %d misión", varios = "Entrega %d misiones", icono = "ic-misiones" },
	raros = { metas = { 2, 3, 4 }, uno = "Encuentra %d raro", varios = "Encuentra %d raros", icono = "ic-raros" },
	mazmorras = { metas = { 1, 2 }, uno = "Entra a %d mazmorra", varios = "Entra a %d mazmorras", icono = "ic-mazmorra" },
	niveles = { metas = { 1, 2, 3 }, uno = "Sube %d nivel", varios = "Sube %d niveles", icono = "ic-nivel" },
	minutos = { metas = { 120, 180, 300 }, uno = "Caza %d horas", varios = "Caza %d horas", icono = "ic-reloj" },
}

-- Los tres de la semana: siempre misiones y raros; el tercero cambia.
function Re.Elegir(semana)
	local h = hash(semana or Re.Semana())
	local terceros = { "mazmorras", "minutos" }
	if nivel() < NIVEL_MAX then terceros[#terceros + 1] = "niveles" end
	local claves = { "misiones", "raros", terceros[(h % #terceros) + 1] }
	local lista = {}
	for i, k in ipairs(claves) do
		local t = Re.TIPOS[k]
		lista[i] = { clave = k, meta = t.metas[(floor(h / (i * 7)) % #t.metas) + 1] }
	end
	return lista
end

-- La semana sumada: hoy y los días de antes que caen desde el lunes.
function Re.Avance(semana)
	semana = semana or Re.Semana()
	local s = { misiones = 0, raros = 0, mazmorras = 0, niveles = 0, minutos = 0 }
	local Di = M.Dia
	if not Di then return s end
	local d = N.DatosPersonaje(ID)
	local lista = { Di.Hoy() }
	for _, x in ipairs(type(d.dias) == "table" and d.dias or {}) do lista[#lista + 1] = x end
	for _, x in ipairs(lista) do
		if type(x) == "table" and type(x.fecha) == "string" and x.fecha >= semana then
			for k in pairs(s) do s[k] = s[k] + (tonumber(x[k]) or 0) end
		end
	end
	return s
end

function Re.Lista()
	local semana = Re.Semana()
	local av = Re.Avance(semana)
	local r = datos()
	if r.semana ~= semana then r.semana, r.hechos = semana, {} end
	local out = {}
	for i, e in ipairs(Re.Elegir(semana)) do
		local t = Re.TIPOS[e.clave]
		local meta = e.meta
		local avance = av[e.clave] or 0
		local mostrar, metaTexto = avance, meta
		if e.clave == "minutos" then mostrar, metaTexto = floor(avance / 60), floor(meta / 60) end
		out[i] = {
			clave = e.clave, meta = meta, avance = avance, hecho = avance >= meta,
			actual = math.min(mostrar, metaTexto), total = metaTexto,
			titulo = format(metaTexto == 1 and L[t.uno] or L[t.varios], metaTexto), icono = t.icono,
		}
	end
	return out
end

function Re.Premios() return tonumber(datos().premios) or 0 end

local FESTEJOS = {
	"¡Reto cumplido: %s! Me gané una salchicha... digo, te la ganaste tú. Bueno, nos la ganamos.",
	"¡Lo lograste: %s! Esa salchicha de premio me la voy a comer despacito.",
	"¡%s, listo! La manada aúlla por ti. Auuuu. ¿Y mi salchicha?",
}

function Re.Revisar()
	if not activo() then return 0 end
	local r = datos()
	local n = 0
	for _, e in ipairs(Re.Lista()) do
		if e.hecho and not r.hechos[e.clave] then
			r.hechos[e.clave] = true
			r.premios = Re.Premios() + 1
			n = n + 1
			local Ce = M.Cerebro
			if Ce and Ce.Decir then
				Ce.Decir({ importante = true, aullar = true, salto = true,
					texto = format(L[FESTEJOS[(hash(e.clave .. (r.semana or "")) % #FESTEJOS) + 1]], e.titulo) })
			end
		end
	end
	if n > 0 and M.Avisar then M.Avisar() end
	return n
end

-- Una mazmorra por entrada (la misma, no antes de 30 minutos).
local ultima = { nombre = nil, t = -1e9 }
local function alEntrar()
	if not IsInInstance then return end
	local ok, dentro, tipo = pcall(IsInInstance)
	if not ok or secreto(dentro) or secreto(tipo) or dentro ~= true or tipo ~= "party" then return end
	local nombre = GetInstanceInfo and GetInstanceInfo()
	if secreto(nombre) then nombre = nil end
	local ahora = GetTime and GetTime() or 0
	if nombre == ultima.nombre and ahora - ultima.t < 30 * 60 then return end
	ultima.nombre, ultima.t = nombre, ahora
	if M.Dia and M.Dia.Sumar then M.Dia.Sumar("mazmorras") end
	N.FueraDeCombate("lya.retos", Re.Revisar)
end

A.RegisterEvent("PLAYER_ENTERING_WORLD", function() A.After(2, alEntrar) end)
local function pronto() A.After(1, function() N.FueraDeCombate("lya.retos", Re.Revisar) end) end
A.RegisterEvent("QUEST_TURNED_IN", pronto)
A.RegisterEvent("PLAYER_LEVEL_UP", pronto)
if A.On then A.On("RARE_SPOTTED", pronto) end
N.Cada("lya.retos", 300, function() if activo() then N.FueraDeCombate("lya.retos", Re.Revisar) end end)

A.OnLogin(function()
	local Lya = rawget(_G, "AlfaLya")
	if type(Lya) == "table" and type(Lya.Ensenar) == "function" then
		pcall(Lya.Ensenar, { id = "lya.retos", icono = "ic-exito", modulo = "lya",
			pregunta = L["¿Qué retos tengo esta semana?"],
			respuesta = L["Cada lunes te pongo tres retos chiquitos: misiones, raros y uno sorpresa. Tu avance está en mi página y cada reto cumplido vale una salchicha de premio."] })
	end
end)
