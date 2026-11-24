-- Alfa - Lya festeja lo que logras con Alfa (1.3.8). toxic3000 / La Jauría. GPL-3.0.
--
--   Páginas nuevas en tu historia (TuHistoria.lua: al escribirlas, Lya aúlla
--   y lo festeja una vez, fuera de combate):
--     * tu primer pez raro: el logro «De los que se presumen» de Pesca (un
--       trofeo o un pez de concurso; se lee de sus datos, sin tocarlos);
--     * tu primer récord de pesca: tu mejor racha, tu mejor hora o lo más que
--       sacaste en una sesión pasa la marca que ya tenías;
--     * tu primera mazmorra terminada (FinMazmorra.lua: saliste vivo tras 3
--       minutos o más adentro);
--     * tu primera guía completa (GUIDE_COMPLETED del motor);
--     * nivel 60: además de su página, un anuncio grande con el lobo aullando.
--   Lo que ya tenías al llegar esta versión no se festeja: la primera vez que
--   mira, anota lo que hay y festeja solo lo nuevo. Ajuste lya.festejos.
--
--   Fe.Revisar()   Fe.Mazmorra(r)   Fe.Guia(id)   Fe.Nivel(n)
--   AlfaLya.Festejar(clave, titulo, linea): una página para otros módulos

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID

local type, tonumber, pairs, pcall = type, tonumber, pairs, pcall

local Fe = {}
M.Festejos = Fe

local function encendido() return N.Get(ID, "festejos") ~= false end
local function datos()
	local d = N.DatosPersonaje(ID)
	d.festejos = type(d.festejos) == "table" and d.festejos or {}
	return d.festejos
end
local function pesca() return N.DatosPersonaje("pesca") end
local function anotar(e)
	if not (M.Diario and M.Diario.Anotar) then return false end
	return M.Diario.Anotar(e)
end

---------------------------------------------------------------------------
-- La pesca (solo se leen sus datos)
---------------------------------------------------------------------------
local function marcas()
	local v = pesca().vida
	if type(v) ~= "table" then return 0, 0, 0 end
	return tonumber(v.mejorRacha) or 0, tonumber(v.mejorValor) or 0, tonumber(v.mejorHora) or 0
end

-- El nombre de lo más nuevo del diario de pesca (el trofeo recién sacado).
local function ultimoPez()
	local mejor, cuando
	for _, e in pairs(type(pesca().diario) == "table" and pesca().diario or {}) do
		local t = type(e) == "table" and tonumber(e.primera)
		if t and type(e.nombre) == "string" and e.nombre ~= "" and not N.Secreto(e.nombre) and (not cuando or t > cuando) then
			mejor, cuando = e.nombre, t
		end
	end
	return mejor
end

local function trofeo()
	local lg = pesca().logros
	return type(lg) == "table" and lg.trofeo ~= nil
end

function Fe.Revisar()
	if not encendido() then return false end
	local f = datos()
	local racha, valor, hora = marcas()
	-- La primera vez: lo que ya hay es la línea de partida.
	if not f.base then
		f.base = { racha = racha, valor = valor, hora = hora }
		f.pezVisto = trofeo() or nil
		return false
	end
	local dijo = false
	if not f.pezVisto and trofeo() then
		f.pezVisto = true
		local nombre = ultimoPez()
		dijo = anotar(nombre and { clave = "pezRaro", icono = "ic-raros", t = "Tu primer pez raro: %s", a = { nombre },
			l = "¡Mira cómo brilla! Ese no lo saca cualquiera." }
			or { clave = "pezRaro", icono = "ic-raros", t = "Tu primer pez raro", l = "¡Mira cómo brilla! Ese no lo saca cualquiera." }) or dijo
	end
	local b = f.base
	if not f.record then
		local supera = ((b.racha or 0) > 0 and racha > b.racha) or ((b.valor or 0) > 0 and valor > b.valor) or ((b.hora or 0) > 0 and hora > b.hora)
		if supera then
			f.record = true
			dijo = anotar({ clave = "recordPesca", icono = "ic-oro", t = "Tu primer récord de pesca",
				l = "Le ganaste a tu propia marca. ¡Yo me pido la cola del pescado!" }) or dijo
		elseif racha > (b.racha or 0) or valor > (b.valor or 0) or hora > (b.hora or 0) then
			-- Sin marca de antes (tu primera pesca), la de hoy es la línea de partida.
			b.racha, b.valor, b.hora = (b.racha or 0) > 0 and b.racha or racha, (b.valor or 0) > 0 and b.valor or valor, (b.hora or 0) > 0 and b.hora or hora
		end
	end
	return dijo
end

---------------------------------------------------------------------------
-- La mazmorra, la guía y el 60
---------------------------------------------------------------------------
function Fe.Mazmorra(r)
	if not encendido() then return false end
	local nombre = type(r) == "table" and type(r.nombre) == "string" and r.nombre ~= "" and r.nombre or nil
	return anotar(nombre and { clave = "mazmorraFin", icono = "ic-mazmorra", t = "Tu primera mazmorra terminada: %s", a = { nombre },
		l = "Entramos, peleamos y salimos enteros. ¡Así caza la manada!" }
		or { clave = "mazmorraFin", icono = "ic-mazmorra", t = "Tu primera mazmorra terminada", l = "Entramos, peleamos y salimos enteros. ¡Así caza la manada!" })
end

function Fe.Guia(id)
	if not encendido() then return false end
	local R = rawget(_G, "AlfaRuta")
	local nombre = type(R) == "table" and type(R.NombreGuia) == "function" and R.NombreGuia(id) or nil
	if type(nombre) ~= "string" or nombre == "" then nombre = nil end
	return anotar(nombre and { clave = "guia", icono = "ic-guia", t = "Tu primera guía completa: %s", a = { nombre },
		l = "De principio a fin, sin perder el rastro." }
		or { clave = "guia", icono = "ic-guia", t = "Tu primera guía completa", l = "De principio a fin, sin perder el rastro." })
end

function Fe.Nivel(n)
	if not encendido() or tonumber(n) ~= 60 then return false end
	local f = datos()
	if f.n60 then return false end
	f.n60 = true
	if K and K.Anuncio then
		pcall(K.Anuncio, { estilo = "llegada", lobo = "aullando", sobre = L["La manada aúlla"], titulo = L["¡Nivel 60!"],
			texto = L["Llegaste a la cima, alfa. Lya está orgullosa de ti."], segundos = 8, prioridad = 2, clave = "lya.n60" })
	end
	return true
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------
local pendiente = false
local function pronto()
	if pendiente then return end
	pendiente = true
	A.After(2, function()
		pendiente = false
		local ok, e = pcall(Fe.Revisar)
		if not ok and geterrorhandler then geterrorhandler()(e) end
	end)
end

if A.OnLogin then A.OnLogin(function() A.After(12, pronto) end) end
A.RegisterEvent("LOOT_CLOSED", pronto)
A.RegisterEvent("PLAYER_LEVEL_UP", N.TrasNivel and N.TrasNivel("lya.festejo60", function(_, n) Fe.Nivel(n) end)
	or function(_, n) Fe.Nivel(n) end)
if A.On then A.On("GUIDE_COMPLETED", function(id) pcall(Fe.Guia, id) end) end

-- Para otros módulos: una página de tu historia (Lya la festeja).
local API = type(AlfaLya) == "table" and AlfaLya or nil
if API then
	function API.Festejar(clave, titulo, linea)
		if type(clave) ~= "string" or type(titulo) ~= "string" or titulo == "" then return false end
		return anotar({ clave = "otro:" .. clave, icono = "ic-raros", t = titulo, l = type(linea) == "string" and linea or nil })
	end
end
