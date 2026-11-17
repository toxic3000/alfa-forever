-- Alfa - Bienvenida: el primer arranque, las novedades y el aullido
-- (toxic3000 / La Jauría). GPL-3.0.
--
-- Toma el lugar de la bienvenida y de las novedades del motor (SHOW_WELCOME y
-- SHOW_WHATSNEW, docs/KIT.md "Reemplazos"): las dos abren la ventana de Alfa
-- 1.0 (Asistente.lua), que muestra lo nuevo y pregunta, en este orden, el
-- estilo, si las misiones automáticas son solo las de tu ruta, si compartes tu
-- ubicación con La Jauría y si quieres el aullido.
--
-- Cuándo sale sola: una vez por cuenta, también a quien ya vio la bienvenida
-- de antes (AlfaNucleoDB.bienvenida.visto < VERSION). Unos segundos después
-- de entrar, fuera de combate, de instancias, de cinemáticas y de la elección
-- de camino (espera a que termine cada cosa). Mostrarla la marca vista: un
-- /reload no la repite. /alfa bienvenida, Acerca de > "Mostrar la bienvenida
-- otra vez" y la página Estilo y sonido la abren cuando sea.
--
-- El aullido (Aullar): un lobo del propio juego la primera vez que abres la
-- ventana de Alfa en cada sesión (con el ajuste bienvenida.aullido). Ver
-- SONIDOS y LEEME.md.
--
-- Contrato (global AlfaBienvenida):
--   AlfaBienvenida.Abrir(vista)   "portada" (por omisión) o "asistente"
--   AlfaBienvenida.Aullar()       el aullido ahora (si está encendido)
--   AlfaBienvenida.Visto()        true si ya salió el asistente de la 1.0

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit

local ID = "bienvenida"
local L = N.Textos(M.EN)
M.ID, M.L = ID, L

-- La versión del asistente: subirla lo vuelve a mostrar una vez a todos.
M.VERSION = 1
local ESPERA = 4 -- segundos después de entrar (tras la bienvenida del motor, 2, y sus novedades, 3)

local function datos() return N.Datos(ID) end

function M.Visto() return (tonumber(datos().visto) or 0) >= M.VERSION end
function M.MarcarVisto()
	local d = datos()
	d.visto = M.VERSION
	d.cuando = time and time() or nil
end

---------------------------------------------------------------------------
-- El aullido
---------------------------------------------------------------------------
-- Sonidos del propio juego, por FileDataID (el listado de la comunidad,
-- github.com/wowdev/wow-listfile, parts/sound.csv; ver LEEME.md). Se prueba
-- en orden: si el cliente no tiene uno (o lo calla), el siguiente.
--   569109  Sound/SPELLS/FuriousHowl1.ogg      Aullido furioso, la habilidad
--                                             del lobo del cazador (1.x)
--   564211  Sound/CREATURE/Wolf/WolfStandVar4.ogg  el lobo de siempre, quieto
--                                             y aullando (1.x)
M.SONIDOS = { 569109, 564211 }

local function sonar(id)
	local tocar = A.PlaySoundFile or PlaySoundFile
	if not tocar then return false end
	local ok, va = pcall(tocar, id, "SFX")
	return ok and va and true or false
end

-- forzar: suena aunque el ajuste esté apagado (el botón "Escuchar").
function M.Aullar(forzar)
	if not forzar and not N.Get(ID, "aullido") then return false end
	for _, id in ipairs(M.SONIDOS) do
		if sonar(id) then return true end
	end
	return false
end

-- La primera vez que abres la ventana de Alfa en la sesión (no cuenta un
-- /reload: la marca vive en el personaje y se borra al entrar de nuevo).
local function alAbrirAlfa()
	local d = N.DatosPersonaje(ID)
	if d.aulloSesion then return end
	d.aulloSesion = true
	M.Aullar()
end

if A.UI and type(A.UI.ShowOptions) == "function" and hooksecurefunc then
	hooksecurefunc(A.UI, "ShowOptions", function() K.Llamar(alAbrirAlfa) end)
end

A.RegisterEvent("PLAYER_ENTERING_WORLD", function(_, inicio, recarga)
	if inicio == true and not recarga then N.DatosPersonaje(ID).aulloSesion = nil end
end)

---------------------------------------------------------------------------
-- Cuándo se abre
---------------------------------------------------------------------------
local pendiente -- nil | "login" | "pedido": espera a poder abrirse
local esperaListo -- el Listo() de la bienvenida del motor: avisa WELCOME_CLOSED al cerrar

local function enCinematica()
	return (InCinematic and InCinematic()) or (IsInCinematicScene and IsInCinematicScene()) or false
end

local function eleccionDeCamino()
	local RC = A.UI and A.UI.RouteChoice
	return RC and RC.IsShown and RC.IsShown() or false
end

local function libre(motivo)
	if InCombatLockdown and InCombatLockdown() then return false end
	if enCinematica() or eleccionDeCamino() then return false end
	if motivo == "login" and A.Compat and A.Compat.IsInInstance and A.Compat.IsInInstance() then return false end
	return true
end

-- vista: "portada" o "asistente"
function M.Abrir(motivo, vista)
	motivo = motivo or "pedido"
	if not libre(motivo) then
		pendiente = (pendiente == "pedido" or motivo == "pedido") and "pedido" or "login"
		M.vistaPendiente = vista or M.vistaPendiente
		return false
	end
	pendiente = nil
	if motivo == "login" then M.MarcarVisto() end
	M.AbrirVentana(vista or M.vistaPendiente or "portada")
	M.vistaPendiente = nil
	return true
end

local function intentar()
	if pendiente == "pedido" or (pendiente == "login" and not M.Visto()) then M.Abrir(pendiente) end
end

-- Al cerrarse la ventana: la bienvenida del motor que esperaba queda cerrada
-- (WELCOME_CLOSED: las novedades del motor, reemplazadas aquí, ya no salen).
function M.AlCerrar()
	local listo = esperaListo
	esperaListo = nil
	if listo then K.Llamar(listo) else A.Fire("WELCOME_CLOSED") end
end

local function visible() return M.Visible and M.Visible() or false end

N.Reemplazar("SHOW_WELCOME", function(p)
	esperaListo = p.Listo
	if p.motivo == "login" and M.Visto() then M.AlCerrar() return end
	M.Abrir(p.motivo == "login" and "login" or "pedido", "portada")
end, visible)

N.Reemplazar("SHOW_WHATSNEW", function(p)
	if p.motivo == "login" and M.Visto() then return end
	M.Abrir(p.motivo == "login" and "login" or "pedido", "portada")
end, visible)

A.OnLogin(function()
	if M.Visto() then return end
	pendiente = pendiente or "login"
	if C_Timer and C_Timer.After then C_Timer.After(ESPERA, intentar) else intentar() end
end)

A.RegisterEvent("PLAYER_REGEN_ENABLED", function() intentar() end)
A.RegisterEvent("CINEMATIC_STOP", function()
	if C_Timer and C_Timer.After then C_Timer.After(1, intentar) else intentar() end
end)
A.RegisterEvent("PLAYER_ENTERING_WORLD", function()
	if pendiente and C_Timer and C_Timer.After then C_Timer.After(ESPERA, intentar) end
end)
A.On("ROUTE_CHOICE_HIDDEN", function() intentar() end)

---------------------------------------------------------------------------
-- Comando y contrato
---------------------------------------------------------------------------
A.RegisterCommand("bienvenida", function(resto)
	resto = type(resto) == "string" and resto:lower():match("^%s*(%S*)") or ""
	M.Abrir("pedido", (resto == "asistente" or resto == "pasos") and "asistente" or "portada")
end, L["abre la bienvenida de Alfa 1.0 (también: asistente)"])

AlfaBienvenida = type(AlfaBienvenida) == "table" and AlfaBienvenida or {}
function AlfaBienvenida.Abrir(vista) return M.Abrir("pedido", vista) end
function AlfaBienvenida.Aullar() return M.Aullar() end
function AlfaBienvenida.Visto() return M.Visto() end
