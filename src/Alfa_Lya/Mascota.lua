-- Alfa - Lya y tu mascota (1.3.0). toxic3000 / La Jauría. GPL-3.0.
--
--   lya.mascota (prendido de fábrica): cuando llamas a tu mascota (cazador o
--   brujo), Lya la saluda por su nombre y su familia (una vez por mascota y
--   sesión). Con un cazador, si tu mascota se pone triste o tiene hambre
--   (C_PetInfo.GetPetHappiness), Lya te avisa para que le des de comer (una
--   vez por cada vez que baja). Nunca en combate (espera a que termine).
--
--   Ma.Revisar()  Ma.Felicidad() -> 1 (triste) | 2 (normal) | 3 (feliz) | nil

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = M.L
local ID = M.ID

local type, tonumber, pcall, format = type, tonumber, pcall, string.format
local random = math.random

local Ma = {}
M.Mascota = Ma

local function secreto(v) return issecretvalue ~= nil and type(v) ~= "nil" and issecretvalue(v) and true or false end
local function texto(v) if secreto(v) or type(v) ~= "string" or v == "" then return nil end return v end
local function activo() return N.Get(ID, "mascota") ~= false end

local SALUDOS = {
	"¡Hola, %s! Familia %s y de buena casta. Tú y yo vamos a cuidar a nuestro alfa.",
	"Mira quién llegó: %s, de la familia %s. Nos vamos a llevar bien... casi siempre.",
	"%s (%s) ya está aquí. Te guardo un pedacito de salchicha.",
}
local SALUDOS_SIN = {
	"¡Hola, %s! Tú y yo vamos a cuidar a nuestro alfa.",
	"%s, bienvenido a la manada. Te guardo un pedacito de salchicha.",
}

local function claseJugador()
	if not UnitClass then return nil end
	local _, c = UnitClass("player")
	return texto(c)
end

function Ma.Felicidad()
	local fn = (C_PetInfo and C_PetInfo.GetPetHappiness) or rawget(_G, "GetPetHappiness")
	if type(fn) ~= "function" then return nil end
	local ok, h = pcall(fn)
	if not ok or secreto(h) then return nil end
	return tonumber(h)
end

local saludadas = {} -- nombre -> true (esta sesión)
local antes          -- la felicidad de antes
local ultimo         -- la mascota de antes

local function decir(t, extra)
	local Ce = M.Cerebro
	if not (Ce and Ce.Decir) then return false end
	local c = { texto = t, salto = true }
	if extra then for k, v in pairs(extra) do c[k] = v end end
	return Ce.Decir(c)
end

function Ma.Revisar()
	if not activo() then return false end
	if not (UnitExists and UnitExists("pet")) then ultimo, antes = nil, nil return false end
	if InCombatLockdown and InCombatLockdown() then
		N.FueraDeCombate("lya.mascota", Ma.Revisar)
		return false
	end
	local nombre = texto(UnitName and UnitName("pet"))
	if not nombre then return false end
	local dicho = false
	if not saludadas[nombre] then
		local familia = texto(UnitCreatureFamily and UnitCreatureFamily("pet"))
		local r
		if familia then
			r = decir(format(L[SALUDOS[random(#SALUDOS)]], nombre, familia), { id = "mascotaHola" })
		else
			r = decir(format(L[SALUDOS_SIN[random(#SALUDOS_SIN)]], nombre), { id = "mascotaHola" })
		end
		if r == true then saludadas[nombre] = true dicho = true end
	end
	-- Solo el cazador alimenta a su mascota.
	if claseJugador() == "HUNTER" then
		local h = Ma.Felicidad()
		if nombre ~= ultimo then antes = h end
		if h and antes and h < antes and not dicho then
			if h == 1 then
				dicho = decir(format(L["%s está triste y ya no te hace mucho caso. Dale de comer pronto, por favor."], nombre),
					{ id = "mascotaTriste", importante = true }) == true
			elseif h == 2 then
				dicho = decir(format(L["%s tiene hambre. Una buena comida y vuelve a pelear contento."], nombre),
					{ id = "mascotaHambre" }) == true
			end
		elseif h == 3 and antes and antes < 3 and not dicho then
			dicho = decir(format(L["¡%s ya está feliz! Así sí da gusto cazar juntos."], nombre), { id = "mascotaFeliz" }) == true
		end
		antes = h
	end
	ultimo = nombre
	return dicho
end

AlfaNucleo.DeUnidad("UNIT_PET", "player", function(_, unit)
	if unit ~= "player" then return end
	A.After(2, Ma.Revisar)
end)
AlfaNucleo.DeUnidad("UNIT_HAPPINESS", "pet", function(_, unit)
	if unit ~= "pet" then return end
	Ma.Revisar()
end)
A.RegisterEvent("PET_UI_UPDATE", function() Ma.Revisar() end)

A.OnLogin(function()
	local Lya = rawget(_G, "AlfaLya")
	if type(Lya) == "table" and type(Lya.Ensenar) == "function" then
		pcall(Lya.Ensenar, { id = "lya.mascota", icono = "ic-huella", modulo = "lya",
			pregunta = L["¿Te llevas bien con mi mascota?"],
			respuesta = L["¡Claro! Saludo a tu mascota cuando la llamas y, si eres cazador, te aviso cuando tiene hambre o está triste para que le des de comer."] })
	end
end)
