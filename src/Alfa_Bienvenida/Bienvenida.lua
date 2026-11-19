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
--   AlfaBienvenida.Notas()        las notas de tu versión de Alfa (Notas.lua)
-- Al terminar se dispara el mensaje del motor ALFA_CONFIGURADO.
--
-- Las notas de cada versión (Notas.lua, M.NOTAS en Novedades.lua): al entrar
-- al juego, unos segundos después de los demás avisos de entrada y fuera de
-- combate, de instancias, de cinemáticas y de la elección de camino:
--   - con la configuración pendiente (quien no tenía Alfa): la intro del lobo
--     y la configuración, como siempre; al terminarla, la versión de ahora
--     queda vista (todo es nuevo para quien empieza: no hay notas que ver);
--   - ya configurada y con una versión de Alfa más nueva que la última que
--     viste (datos().versionVista; sin registro, quien ya configuró viene de
--     una versión anterior): la intro del lobo y luego la ventana de notas.
-- Una vez por versión y por cuenta (AlfaNucleoDB): las notas hablan del
-- addon, no del personaje, y verlas otra vez en cada personaje cansaría. Si
-- entras en combate durante la intro, la ventana espera a que termine.
--
-- El saludo (1.2.0, bienvenida.introSiempre, encendido de fábrica): cada vez
-- que entras al juego (no al recargar), aunque no haya nada nuevo, la intro
-- del lobo te recibe sola, cuando se puede (fuera de combate, de instancias y
-- de cinemáticas). Con la configuración pendiente o con notas nuevas no hace
-- falta: la intro ya sale con ellas.

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
local ESPERA_NOTAS = 6 -- las notas de una versión nueva: después de todo lo demás al entrar

local function datos() return N.Datos(ID) end

---------------------------------------------------------------------------
-- La versión de Alfa que ya viste (sus notas)
---------------------------------------------------------------------------
function M.VersionVista()
	local v = datos().versionVista
	return type(v) == "string" and v or nil
end

function M.MarcarNotasVistas(version)
	version = version or (M.VersionAlfa and M.VersionAlfa())
	if version then datos().versionVista = version end
end

-- Las notas que te tocan al entrar, o nil. La de tu versión (o la más nueva
-- con notas que no pase de ella) si es más nueva que la última que viste.
function M.NotasPorVer()
	if M.Pendiente() or not (M.VersionAlfa and M.NOTAS) then return nil end
	local actual = M.VersionAlfa()
	if not actual then return nil end
	local vista = M.VersionVista()
	if vista and M.CompararVersion(vista, actual) >= 0 then return nil end
	for _, n in ipairs(M.NOTAS) do
		if M.CompararVersion(n.version, actual) <= 0 and (not vista or M.CompararVersion(n.version, vista) > 0) then
			return n
		end
	end
	return nil
end

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

-- El aullido largo de la intro (1.2.1). El juego clásico no trae un aullido
-- largo en un solo archivo, así que se arma con los suyos: cuando termina uno
-- empieza el siguiente (C_Sound.IsPlaying), y otro lobo contesta a lo lejos
-- en el canal de ambiente (que suena más bajo, como un eco del valle).
--   564211  Sound/CREATURE/Wolf/WolfStandVar4.ogg   el lobo quieto, aullando
--   564217  Sound/CREATURE/Wolf/WolfStandVar4b.ogg  la otra toma del mismo aullido
-- Cada paso: ids (se prueba en orden), canal y cuándo: tras = "fin" (cuando
-- termina el anterior) o segundos después de que empezó el anterior.
-- Para compararlos en el juego: /alfa bienvenida aullido corto|largo|manada
-- (suena y queda como el de la intro).
M.AULLIDOS = {
	corto = { { ids = { 569109, 564211 } } },
	largo = {
		{ ids = { 564211, 569109 } },
		{ ids = { 564217 }, tras = "fin" },
		{ ids = { 564211 }, canal = "Ambience", tras = 0.55 },
	},
	manada = {
		{ ids = { 564211, 569109 } },
		{ ids = { 564217 }, tras = "fin" },
		{ ids = { 564211 }, canal = "Ambience", tras = 0.45 },
		{ ids = { 564217 }, canal = "Ambience", tras = "fin" },
		{ ids = { 564211 }, canal = "Ambience", tras = 0.7 },
	},
}
M.AULLIDO_INTRO = "largo" -- el de fábrica; bienvenida.aullidoIntro lo cambia

local function sonar(id, canal)
	local tocar = A.PlaySoundFile or PlaySoundFile
	if not tocar then return false end
	local ok, va, mango = pcall(tocar, id, canal or "SFX")
	if ok and va then return true, mango end
	return false
end

local turnoAullido = 0
local function sonando(mango)
	if not (mango and C_Sound and C_Sound.IsPlaying) then return nil end
	local ok, si = pcall(C_Sound.IsPlaying, mango)
	if not ok or (issecretvalue and issecretvalue(si)) then return nil end
	return si and true or false
end

-- Toca los pasos de un aullido, uno tras otro. Un aullido nuevo calla al
-- que todavía estaba encadenando pasos.
local function secuencia(pasos)
	turnoAullido = turnoAullido + 1
	local mio = turnoAullido
	local i, mango = 0, nil
	local function siguiente()
		if mio ~= turnoAullido then return end
		i = i + 1
		local p = pasos[i]
		if not p then return end
		local va = false
		for _, id in ipairs(p.ids) do
			local ok, m = sonar(id, p.canal)
			if ok then va, mango = true, m break end
		end
		if i == 1 and not va then return end -- sin sonido: nada más
		local q = pasos[i + 1]
		if not q then return end
		if q.tras == "fin" and sonando(mango) ~= nil then
			-- espera a que termine, mirando cada décima (8 s como mucho)
			local vueltas = 0
			local function mirar()
				if mio ~= turnoAullido then return end
				vueltas = vueltas + 1
				if sonando(mango) and vueltas < 80 then K.Despues(0.1, mirar) else siguiente() end
			end
			K.Despues(0.1, mirar)
		else
			K.Despues(tonumber(q.tras) or 1.6, siguiente)
		end
	end
	siguiente()
	return true
end

-- forzar: suena aunque el ajuste esté apagado (el botón "Escuchar").
-- cual: "intro" (el aullido largo de la intro) o el nombre de uno de M.AULLIDOS;
-- sin él, el corto de siempre (al abrir la ventana de Alfa y "Escuchar").
function M.Aullar(forzar, cual)
	if not forzar and not N.Get(ID, "aullido") then return false end
	if cual == "intro" then
		cual = N.Get(ID, "aullidoIntro")
		if not M.AULLIDOS[cual or ""] then cual = M.AULLIDO_INTRO end
	end
	local pasos = M.AULLIDOS[cual or ""]
	if pasos and #pasos > 1 then return secuencia(pasos) end
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
		M.Intro(function(por)
			-- la intro se cortó porque entraste en combate: el asistente espera
			if por == "combate" then
				pendiente = (pendiente == "pedido" or motivo == "pedido") and "pedido" or "login"
				M.vistaPendiente = cual
				return
			end
			M.AbrirVentana(cual)
		end)
	else
		M.AbrirVentana(cual)
	end
	return true
end

local function intentar()
	if pendiente == "pedido" or (pendiente == "login" and M.Pendiente()) then M.Abrir(pendiente) end
end

-- Las notas de la versión nueva: la intro y luego la ventana, cuando se pueda.
local notasPendientes

local function intentarNotas()
	if not notasPendientes then return end
	if M.Pendiente() then notasPendientes = nil return end -- primero la configuración
	if not libre("login") or (M.Visible and M.Visible()) then return end -- espera
	if M.NotasVisibles and M.NotasVisibles() then notasPendientes = nil return end
	local nota = M.NotasPorVer()
	notasPendientes = nil
	if not nota then
		M.MarcarNotasVistas()
		return
	end
	local function abrir(por)
		if por == "combate" or (InCombatLockdown and InCombatLockdown()) then
			notasPendientes = true -- al salir del combate (PLAYER_REGEN_ENABLED)
			return
		end
		if M.AbrirNotas then M.AbrirNotas(nota) end
	end
	if M.Intro then M.Intro(abrir, { version = M.VersionAlfa() }) else abrir() end
end
M.IntentarNotas = intentarNotas

-- Al entrar al juego: ¿hay notas nuevas que ver? (Sin notas para tu versión,
-- queda vista y no sale nada.)
function M.RevisarNotas(espera)
	if M.Pendiente() then return false end
	if not M.NotasPorVer() then
		local actual = M.VersionAlfa and M.VersionAlfa()
		local vista = M.VersionVista()
		if actual and (not vista or M.CompararVersion(vista, actual) < 0) then M.MarcarNotasVistas(actual) end
		return false
	end
	notasPendientes = true
	if espera and espera > 0 and C_Timer and C_Timer.After then C_Timer.After(espera, intentarNotas) else intentarNotas() end
	return true
end

-- La línea que explica por qué Alfa no abre todavía.
local function recordar()
	N.Imprimir(L["Termina la configuración para usar Alfa (2 minutos)."])
end

-- Al cerrarse la ventana: la bienvenida del motor que esperaba queda cerrada
-- (WELCOME_CLOSED: las novedades del motor, reemplazadas aquí, ya no salen).
-- Cerrarla sin terminar no cambia nada: se recuerda que falta.
function M.AlCerrar()
	-- Escondida por un combate (Asistente.lua): vuelve sola al terminar.
	if M.porCombate then return end
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
	if not M.Pendiente() then
		M.RevisarNotas(ESPERA_NOTAS)
		return
	end
	pendiente = pendiente or "login"
	if C_Timer and C_Timer.After then C_Timer.After(ESPERA, intentar) else intentar() end
end)

-- El saludo de cada entrada (ver arriba).
local saludoPendiente = false

local function saludar()
	if not saludoPendiente then return end
	-- la configuración o las notas ya traen la intro: el saludo sobra
	if M.Pendiente() or notasPendientes or (M.NotasVisibles and M.NotasVisibles()) or (M.Visible and M.Visible()) then
		saludoPendiente = false
		return
	end
	if not libre("login") then return end -- espera: combate, cinemática o instancia
	saludoPendiente = false
	local nombre = UnitName and UnitName("player")
	local texto = type(nombre) == "string" and nombre ~= "" and string.format(L["¡De vuelta en la manada, %s!"], nombre) or nil
	if M.Intro then M.Intro(nil, { texto = texto }) end
end
M.Saludar = saludar

A.RegisterEvent("PLAYER_ENTERING_WORLD", function(_, inicio, recarga)
	if inicio == true and not recarga and N.Get(ID, "introSiempre") ~= false then
		saludoPendiente = true
	end
	if saludoPendiente and C_Timer and C_Timer.After then C_Timer.After(ESPERA_NOTAS + 1, saludar) end
end)

local function intentarTodo()
	intentar()
	intentarNotas()
	saludar()
end
A.RegisterEvent("PLAYER_REGEN_ENABLED", function() intentarTodo() end)
A.RegisterEvent("CINEMATIC_STOP", function()
	if C_Timer and C_Timer.After then C_Timer.After(1, intentarTodo) else intentarTodo() end
end)
A.RegisterEvent("PLAYER_ENTERING_WORLD", function()
	if pendiente and C_Timer and C_Timer.After then C_Timer.After(ESPERA, intentar) end
	if notasPendientes and C_Timer and C_Timer.After then C_Timer.After(ESPERA_NOTAS, intentarNotas) end
end)
A.On("ROUTE_CHOICE_HIDDEN", function() intentarTodo() end)

---------------------------------------------------------------------------
-- Comando y contrato
---------------------------------------------------------------------------
A.RegisterCommand("bienvenida", function(resto)
	local cual = type(resto) == "string" and resto:lower():match("^%s*aullido%s*(%S*)")
	resto = type(resto) == "string" and resto:lower():match("^%s*(%S*)") or ""
	-- /alfa bienvenida aullido [corto|largo|manada]: suena y queda como el de la intro
	if cual then
		if M.AULLIDOS[cual] then N.Set(ID, "aullidoIntro", cual) end
		M.Aullar(true, "intro")
		return
	end
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
function AlfaBienvenida.Aullar(forzar) return M.Aullar(forzar and true or nil) end
function AlfaBienvenida.Visto() return M.Visto() end
function AlfaBienvenida.Notas() return M.AbrirNotas and M.AbrirNotas() or false end
