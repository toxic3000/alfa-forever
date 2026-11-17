-- Alfa - Bienvenida: la configuración de Alfa, las novedades y el aullido
-- (toxic3000 / La Jauría). GPL-3.0.
--
-- Toma el lugar de la bienvenida y de las novedades del motor (SHOW_WELCOME y
-- SHOW_WHATSNEW, docs/KIT.md "Reemplazos"). Lo principal es el asistente de
-- configuración (Asistente.lua, con sus pasos en Pasos.lua): el idioma, el
-- estilo, todo lo que Alfa hace sola (misiones, guía, comerciantes y viajes,
-- otros jugadores, tu personaje), La Jauría y un resumen con "Cambiar".
--
-- Es obligatorio: hasta terminarlo, Pendiente() es true y Alfa no se usa (la
-- puerta central del núcleo y del motor llama a AlfaBienvenida.Exigir()).
-- Nunca bloquea el juego: solo las ventanas de Alfa. Sale solo al entrar
-- (unos segundos después, fuera de combate, de instancias, de cinemáticas y
-- de la elección de camino) cada vez que entras mientras esté pendiente, y
-- sigue en el paso donde lo dejaste (también tras recargar por el idioma).
-- Subir M.VERSION lo vuelve a pedir una vez a todos, con sus ajustes de ahora
-- ya elegidos (cada paso lee los ajustes reales).
--
-- El aullido (Aullar): un lobo del propio juego la primera vez que abres la
-- ventana de Alfa en cada sesión (con el ajuste bienvenida.aullido). Ver
-- SONIDOS y LEEME.md.
--
-- Contrato (global AlfaBienvenida):
--   AlfaBienvenida.Abrir(vista)   abre el asistente (pendiente: donde lo
--                                 dejaste, con la línea de por qué; terminado:
--                                 el resumen), o "portada" para lo nuevo
--                                 de la versión (solo ya terminado)
--   AlfaBienvenida.Pendiente()    true mientras la configuración no se terminó
--   AlfaBienvenida.Exigir()       si está pendiente: lo abre, dice por qué en
--                                 el chat y devuelve true (la puerta lo usa
--                                 antes de abrir cualquier ventana de Alfa)
--   AlfaBienvenida.Aullar()       el aullido ahora (si está encendido)
--   AlfaBienvenida.Visto()        true si ya salió la configuración de esta versión
-- Al terminar se dispara el mensaje del motor ALFA_CONFIGURADO.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit

local ID = "bienvenida"
local L = N.Textos(M.EN)
M.ID, M.L = ID, L

-- La versión del asistente: subirla lo vuelve a pedir una vez a todos. La 1
-- era el asistente de cuatro preguntas; la 2 es la configuración completa.
M.VERSION = 2
local ESPERA = 4 -- segundos después de entrar (tras la bienvenida del motor, 2, y sus novedades, 3)

local function datos() return N.Datos(ID) end

function M.Visto() return (tonumber(datos().visto) or 0) >= M.VERSION end
-- true mientras la configuración de esta versión no se terminó.
function M.Pendiente() return (tonumber(datos().respondio) or 0) < M.VERSION end
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

-- vista: "asistente" (por omisión) o "portada"
function M.Abrir(motivo, vista)
	motivo = motivo or "pedido"
	if not libre(motivo) then
		pendiente = (pendiente == "pedido" or motivo == "pedido") and "pedido" or "login"
		M.vistaPendiente = vista or M.vistaPendiente
		return false
	end
	pendiente = nil
	M.MarcarVisto()
	local cual = vista or M.vistaPendiente or "asistente"
	M.vistaPendiente = nil
	-- falta la configuracion: primero la intro del lobo (una vez por sesion), luego el asistente
	if cual == "asistente" and M.Pendiente() and M.Intro then
		M.Intro(function() M.AbrirVentana(cual) end)
	else
		M.AbrirVentana(cual)
	end
	return true
end

local function intentar()
	if pendiente == "pedido" or (pendiente == "login" and M.Pendiente()) then M.Abrir(pendiente) end
end

-- La línea que explica por qué Alfa no abre todavía.
local function recordar()
	N.Imprimir(L["Termina la configuración para usar Alfa (2 minutos)."])
end

-- Al cerrarse la ventana: la bienvenida del motor que esperaba queda cerrada
-- (WELCOME_CLOSED: las novedades del motor, reemplazadas aquí, ya no salen).
-- Cerrarla sin terminar no cambia nada: se recuerda que falta.
function M.AlCerrar()
	local listo = esperaListo
	esperaListo = nil
	if listo then K.Llamar(listo) else A.Fire("WELCOME_CLOSED") end
	if M.Pendiente() and not M.recargando then recordar() end
end

-- La puerta: si falta la configuración, la abre y lo dice. -> true si detuvo.
function M.Exigir()
	if not M.Pendiente() then return false end
	if not (M.Visible and M.Visible()) then
		recordar()
		M.Abrir("pedido", "asistente")
	end
	return true
end

local function visible() return M.Visible and M.Visible() or false end

N.Reemplazar("SHOW_WELCOME", function(p)
	esperaListo = p.Listo
	if p.motivo == "login" then
		if M.Pendiente() then M.Abrir("login", "asistente") else M.AlCerrar() end
		return
	end
	M.Abrir("pedido", M.Pendiente() and "asistente" or "portada")
end, visible)

N.Reemplazar("SHOW_WHATSNEW", function(p)
	if p.motivo == "login" then return end
	M.Abrir("pedido", M.Pendiente() and "asistente" or "portada")
end, visible)

A.OnLogin(function()
	if not M.Pendiente() then return end
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
	local portada = resto == "novedades" or resto == "portada" or resto == "nuevo"
	M.Abrir("pedido", (portada and not M.Pendiente()) and "portada" or "asistente")
end, L["abre la configuración de Alfa (también: novedades)"])

AlfaBienvenida = type(AlfaBienvenida) == "table" and AlfaBienvenida or {}
function AlfaBienvenida.Abrir(vista)
	if M.Pendiente() then
		-- La puerta del núcleo (N.Permitido) llega aquí: decir por qué.
		M.Exigir()
		return true
	end
	return M.Abrir("pedido", vista == "portada" and "portada" or "asistente")
end
function AlfaBienvenida.Pendiente() return M.Pendiente() end
function AlfaBienvenida.Exigir() return M.Exigir() end
function AlfaBienvenida.Aullar() return M.Aullar() end
function AlfaBienvenida.Visto() return M.Visto() end
