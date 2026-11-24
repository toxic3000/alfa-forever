-- Alfa - Lya según tu hora del día (1.3.8). toxic3000 / La Jauría. GPL-3.0.
--
--   Lya vive con tu reloj (la hora local de tu computadora, date("%H"); la
--   misma que usa Ahora.lua):
--     * te saluda según la hora al llegar corriendo (Cerebro.lua: llegada,
--       saludoManana/Tarde/Noche/Madrugada): «¡Buenos días!», «Buenas
--       noches, lobo»;
--     * de noche y de madrugada está más tranquila: platica menos (la espera
--       entre sus ratos de plática es CALMA veces más larga) y entre globos
--       se sienta o se estira en vez de correr y buscarse la cola (Lya.lua);
--     * cuando el día cambia de rato mientras juegas (amanece, cae la noche),
--       lo dice una vez al día con su propio saludo.
--   Ajuste lya.horaReal (de fábrica, sí). Apagado, todo es como antes.
--
--   Hr.Rato(h) -> "madrugada" | "manana" | "tarde" | "noche"
--   Hr.Tranquila() -> bool        Hr.Espera(seg) -> seg
--   Hr.Pose() -> nombre | nil     Hr.Llegada() -> categoría de frases
--   Hr.Revisar() -> true si habló (el latido)

local ADDON, M = ...
local N = AlfaNucleo
local L = M.L
local ID = M.ID

local type, tonumber, random = type, tonumber, math.random

local Hr = {}
M.HoraReal = Hr

local CALMA = 1.6
local POSES_NOCHE = { "sentada", "estirarse", "sentada" }

local CAMBIO = {
	manana = { "¡Ya amaneció, lobo! Buenos días. El sol pinta bonito Azeroth.", "Buenos días: ya salió el sol. ¿Seguimos con energía?" },
	noche = { "Ya se hizo de noche, lobo. Me pongo tranquilita: aquí sigo contigo.", "Buenas noches, lobo. La luna ya salió; cazamos con calma." },
	madrugada = { "Ya es de madrugada… buenas noches, lobo. Si sigues, yo te cuido despacito.", "Qué tarde es ya. No te desveles mucho, ¿sí? Mañana también se caza." },
}

local function encendido() return N.Get(ID, "horaReal") ~= false end

function Hr.Rato(h)
	h = tonumber(h) or tonumber(date and date("%H")) or 12
	if h < 5 then return "madrugada" end
	if h < 12 then return "manana" end
	if h < 19 then return "tarde" end
	return "noche"
end

function Hr.Tranquila()
	if not encendido() then return false end
	local r = Hr.Rato()
	return r == "noche" or r == "madrugada"
end

function Hr.Espera(seg)
	seg = tonumber(seg)
	if not seg then return seg end
	return Hr.Tranquila() and seg * CALMA or seg
end

function Hr.Pose()
	if not Hr.Tranquila() then return nil end
	return POSES_NOCHE[random(#POSES_NOCHE)]
end

local LLEGADA = { manana = "llegadaManana", noche = "llegadaNoche", madrugada = "llegadaMadrugada" }
function Hr.Llegada()
	if not encendido() then return nil end
	return LLEGADA[Hr.Rato()]
end

-- El rato del día cambió mientras juegas: una vez al día por rato.
local visto -- el rato que vio al entrar (no se dice: ya te saludó)
function Hr.Revisar()
	if not encendido() then return false end
	local r = Hr.Rato()
	if not visto then visto = r return false end
	if r == visto then return false end
	local lista = CAMBIO[r]
	if not lista then visto = r return false end
	local d = N.DatosPersonaje(ID)
	d.horaDicha = type(d.horaDicha) == "table" and d.horaDicha or {}
	local hoy = date and date("%Y-%m-%d") or "?"
	if d.horaDicha[r] == hoy then visto = r return false end
	local Ce = M.Cerebro
	if not (Ce and Ce.Decir) then return false end
	local ok = Ce.Decir({ texto = L[lista[random(#lista)]], clase = "momento", cara = "normal", segundos = 10, lineas = 4, ancho = 340 })
	if ok == true then
		visto = r
		d.horaDicha[r] = hoy
	end
	return ok == true
end

-- Para el banco.
function Hr.Reiniciar(r) visto = r end
