-- Alfa - Lya: los cumpleaños (1.3.0). toxic3000 / La Jauría. GPL-3.0.
--
--   lya.cumple (prendido de fábrica): Lya apunta el primer día que ve a tu
--   personaje (o el inicio de tu historia, TuHistoria.lua, si es más viejo) y
--   cada año, ese día, te festeja con un anuncio. También el cumpleaños de
--   Alfa: el 16 de noviembre (la 1.0.0, la primera versión con fecha en el
--   CHANGELOG, salió el 16/11/2026). Cada festejo, una vez al año.
--
--   Cu.Nacio() -> "AAAA-MM-DD"   Cu.Hoy(fecha) -> { tuyo = años | nil, alfa = años | nil }
--   Cu.Festejar() -> true si festejó algo

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID

local type, tonumber, pcall, format = type, tonumber, pcall, string.format

local Cu = {}
M.Cumple = Cu

Cu.ALFA = { anio = 2026, mes = 11, dia = 16 }

local function activo() return N.Get(ID, "cumple") ~= false end
local function hoy() return date and date("%Y-%m-%d") or "2026-01-01" end

local function partes(f)
	if type(f) ~= "string" then return nil end
	local y, m, d = f:match("^(%d+)%-(%d+)%-(%d+)$")
	if not y then return nil end
	return tonumber(y), tonumber(m), tonumber(d)
end

function Cu.Nacio()
	local d = N.DatosPersonaje(ID)
	local f = d.nacio
	if not partes(f) then
		f = hoy()
		d.nacio = f
	end
	-- Si tu historia empezó antes, esa es la fecha buena.
	local h = type(d.historia) == "table" and d.historia.empezado
	if partes(h) and h < f then f = h d.nacio = h end
	return f
end

-- Los años que se cumplen en `fecha` (o hoy): del personaje y de Alfa.
function Cu.Hoy(fecha)
	local y, m, d = partes(fecha or hoy())
	local out = {}
	if not y then return out end
	local ny, nm, nd = partes(Cu.Nacio())
	if ny and nm == m and nd == d and y > ny then out.tuyo = y - ny end
	if Cu.ALFA.mes == m and Cu.ALFA.dia == d and y > Cu.ALFA.anio then out.alfa = y - Cu.ALFA.anio end
	return out
end

local function anuncio(titulo, texto)
	if type(K.Anuncio) == "function" and not (InCombatLockdown and InCombatLockdown()) then
		pcall(K.Anuncio, { sobre = L["Lya"], titulo = titulo, texto = texto, lobo = "aullando", segundos = 8 })
	end
end

function Cu.Festejar(fecha)
	if not activo() then return false end
	fecha = fecha or hoy()
	local y = partes(fecha)
	local d = N.DatosPersonaje(ID)
	d.cumple = type(d.cumple) == "table" and d.cumple or {}
	local c = Cu.Hoy(fecha)
	local Ce = M.Cerebro
	local hizo = false
	local nombre = UnitName and UnitName("player")
	if issecretvalue and issecretvalue(nombre) then nombre = nil end
	nombre = type(nombre) == "string" and nombre or ""
	if c.tuyo and d.cumple.tuyo ~= y then
		d.cumple.tuyo = y
		local t = c.tuyo == 1 and format(L["¡Hoy cumplimos 1 año cazando juntos, %s! Gracias por dejarme ser tu loba. Auuuu."], nombre)
			or format(L["¡Hoy cumplimos %d años cazando juntos, %s! Gracias por dejarme ser tu loba. Auuuu."], c.tuyo, nombre)
		anuncio(L["¡Feliz cumpleaños!"], c.tuyo == 1 and L["1 año de aventuras"] or format(L["%d años de aventuras"], c.tuyo))
		if Ce and Ce.Decir then Ce.Decir({ importante = true, aullar = true, salto = true, texto = t }) end
		hizo = true
	end
	if c.alfa and N.Datos(ID).cumpleAlfa ~= y then
		N.Datos(ID).cumpleAlfa = y
		local t = c.alfa == 1 and L["¡Hoy Alfa cumple 1 año! La Jauría lo hizo con cariño para ti. ¿Lo festejamos con una salchicha?"]
			or format(L["¡Hoy Alfa cumple %d años! La Jauría lo hizo con cariño para ti. ¿Lo festejamos con una salchicha?"], c.alfa)
		if not hizo then anuncio(L["¡Feliz cumpleaños, Alfa!"], L["La Jauría está de fiesta"]) end
		if Ce and Ce.Decir then Ce.Decir({ importante = true, aullar = not hizo, salto = true, texto = t }) end
		hizo = true
	end
	return hizo
end

A.OnLogin(function()
	Cu.Nacio()
	A.After(25, function() N.FueraDeCombate("lya.cumple", function() Cu.Festejar() end) end)
	local Lya = rawget(_G, "AlfaLya")
	if type(Lya) == "table" and type(Lya.Ensenar) == "function" then
		pcall(Lya.Ensenar, { id = "lya.cumple", icono = "ic-huella", modulo = "lya",
			pregunta = L["¿Cuándo es nuestro cumpleaños?"],
			respuesta = L["Apunto el primer día que te vi. Cada año, ese día, lo festejamos juntos. Y el 16 de noviembre es el cumpleaños de Alfa."] })
	end
end)
