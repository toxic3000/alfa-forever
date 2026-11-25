-- Alfa - La Jauría: un lobo de la manada anda cerca (1.3.2). toxic3000 /
-- La Jauría. GPL-3.0.
--
-- Antes solo había aviso cuando el fundador (Toxic) aparecía a la vista
-- (motor/Alfa/Rares). Toxic (1.3.2): que avise de cualquiera que use Alfa.
-- Cuando un jugador entra a la vista (su placa de nombre, tu objetivo o el
-- ratón encima) y es alguien de quien La Jauría ya oyó que usa Alfa
-- (Gente.lua: solo quienes aceptaron compartir), sale el anuncio de Alfa
-- (K.Anuncio) unos segundos: «Un lobo de La Jauría anda cerca», su nombre y
-- «También usa Alfa: salúdalo». Nunca de ti, de tu grupo ni del fundador
-- (ese tiene su propio anuncio), ni en combate ni en instancias. Una vez por
-- persona cada SESION segundos y como mucho uno cada HUECO segundos.
-- Se apaga con manada.lobosCerca. No envía nada a nadie.
--
--   Ce.Revisar(unidad) -> true si avisó     Ce.Olvidar() (banco)

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local U, L, ID = M.U, M.L, M.ID

local Ce = {}
M.Cerca = Ce

local type, pcall = type, pcall

Ce.SEGUNDOS = 8     -- lo que dura el anuncio (Toxic: como mucho 10)
local SESION = 3600 -- s: la misma persona, como mucho una vez por hora
local HUECO = 60    -- s entre un aviso de lobo cerca y el siguiente

local vistos = {}   -- clave -> cuándo se avisó
local ultimo = -math.huge

local function encendido() return N.Get(ID, "lobosCerca") ~= false end

local function enInstancia()
	if type(IsInInstance) ~= "function" then return false end
	local ok, dentro, tipo = pcall(IsInInstance)
	return ok and U.Leer(dentro) == true and U.Leer(tipo) ~= "none"
end

local function enCombate()
	return (InCombatLockdown and InCombatLockdown()) or false
end

local function fundador(nombre)
	local R = A.Rares
	local f = type(R) == "table" and R.FOUNDER
	if type(f) ~= "string" then return false end
	return U.Clave(nombre) == U.Clave(f)
end

-- El nombre completo de un jugador a la vista (nil si no es jugador, si soy
-- yo o si el juego lo da secreto).
local function jugador(unit)
	if type(unit) ~= "string" or type(UnitIsPlayer) ~= "function" then return nil end
	local ok, es = pcall(UnitIsPlayer, unit)
	if not (ok and U.Leer(es) == true) then return nil end
	if type(UnitIsUnit) == "function" then
		local okY, yo = pcall(UnitIsUnit, unit, "player")
		if okY and U.Leer(yo) == true then return nil end
	end
	local okN, nombre = pcall(A.Compat.UnitFullName, unit)
	if not okN then return nil end
	return U.Texto(nombre)
end

function Ce.Revisar(unit)
	if not encendido() or enCombate() or enInstancia() then return false end
	local nombre = jugador(unit)
	if not nombre or fundador(nombre) then return false end
	local clave = U.Clave(nombre)
	if not clave or clave == U.MiClave() then return false end
	if M.Callados and M.Callados.Esta(clave) then return false end -- 1.4.0 (56): lo silenciaste
	local G = M.Gente
	if not (G and G.Alfa and G.Alfa(clave)) then return false end
	if G.EnGrupo and G.EnGrupo(clave) then return false end
	local ahora = U.Ahora()
	if ahora - ultimo < HUECO then return false end
	if vistos[clave] and ahora - vistos[clave] < SESION then return false end
	-- 1.3.7 (62): la misma persona, una vez al día (también entre sesiones).
	local hoy = date and date("%Y-%m-%d") or "?"
	local dd = N.DatosPersonaje(ID)
	if type(dd.cercaDia) ~= "table" or dd.cercaDia.fecha ~= hoy then dd.cercaDia = { fecha = hoy, vistos = {} } end
	if dd.cercaDia.vistos[clave] then return false end
	local K = N.Kit
	if not (K and K.Anuncio) then return false end
	vistos[clave], ultimo = ahora, ahora
	dd.cercaDia.vistos[clave] = true
	-- 1.3.5: en el modo ligero, una tarjeta sin animación. 1.3.7 (62): en una
	-- ciudad o posada (donde se cruza mucha gente), también: un aviso chico.
	local enCiudad = IsResting and U.Leer(IsResting()) == true
	if ((N.Ligero and N.Ligero()) or enCiudad or (N.AnunciosGrandes and not N.AnunciosGrandes())) and K.Aviso then
		M.U.Aviso({ titulo = L["Un lobo de La Jauría anda cerca"],
			texto = (U.Mostrar(nombre) or nombre) .. ". " .. L["También usa Alfa: salúdalo."], icono = "ic-lobo" })
		return true
	end
	K.Anuncio({
		sobre = L["Un lobo de La Jauría anda cerca"],
		titulo = U.Mostrar(nombre) or nombre,
		texto = L["También usa Alfa: salúdalo."],
		lobo = "atento",
		estilo = "manada",
		segundos = Ce.SEGUNDOS,
	})
	return true
end

function Ce.Olvidar()
	vistos, ultimo = {}, -math.huge
	N.DatosPersonaje(ID).cercaDia = nil
end

-- El juego pasa el nombre del evento primero; la unidad no se lee si es secreta.
A.RegisterEvent("NAME_PLATE_UNIT_ADDED", function(_, unit)
	if issecretvalue and issecretvalue(unit) then return end
	Ce.Revisar(unit)
end)
A.RegisterEvent("PLAYER_TARGET_CHANGED", function() Ce.Revisar("target") end)
A.RegisterEvent("UPDATE_MOUSEOVER_UNIT", function() Ce.Revisar("mouseover") end)
