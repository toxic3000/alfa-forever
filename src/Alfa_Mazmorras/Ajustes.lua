-- Alfa - Mazmorras: sus ajustes, en Ajustes > Descubrir > Mazmorras
-- (toxic3000 / La Jauría). GPL-3.0.
--
-- La página de Mazmorras solo guía; quien quiera detalle entra a Ajustes
-- (docs/PLAN-1.0.md). Aquí van, junto a los del diario del motor:
--   Tu diario        modo historia, avisos al entrar y al descubrir, el botín
--                    que te sirve, las entradas en el minimapa, borrar tu progreso;
--   Avisos de jefes  los de Blizzard (línea de tiempo y mensajes en pantalla:
--                    Avisos.lua), explicados en sencillo, con la prueba y el
--                    ajuste que recomienda Alfa.
-- /alfa mazmorras ajustes abre esta pestaña.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)
local D, Av = M.D, M.Avisos
local ID = D.ID

local format = string.format

local Aj = {}
M.Ajustes = Aj

-- La página y la pestaña del motor (sus nombres en el idioma del cliente,
-- los mismos con que Options las declaró).
local EL = A.L or {}
local PAGINA, PESTANA = EL["Discovery"] or "Discovery", EL["Dungeons"] or "Dungeons"

function Aj.Abrir() A.Fire("SHOW_OPTIONS", "dungeons") end

local function cambio() D.Avisar("ajustes") end

---------------------------------------------------------------------------
-- Tu diario
---------------------------------------------------------------------------
local DIARIO = {
	{ kind = "toggle", key = ID .. ".historia", label = L["Modo historia"],
		help = L["Los jefes se descubren al vencerlos: su nombre y su botín quedan ocultos hasta entonces. Sus consejos siempre se pueden ver."] },
	{ kind = "toggle", key = ID .. ".avisoDescubrir", label = L["Avisarme al descubrir un jefe"], child = true,
		help = L["Un aviso cuando vences a un jefe nuevo, con un clic a su botín."],
		disabled = function() return not N.Get(ID, "historia") end },
	{ kind = "toggle", key = ID .. ".avisoEntrar", label = L["Avisarme al entrar a una mazmorra"],
		help = L["Un aviso con sus jefes y lo que llevas vencido, con un clic a sus consejos."] },
	{ kind = "toggle", key = ID .. ".paraMi", label = L["¿Qué cae aquí para mí?"],
		help = L["Al entrar a una mazmorra, un aviso chico con cuántas mejoras hay para ti y de qué jefes. También con /alfa mazmorras parami."],
		search = "loot for me, upgrades, what drops, botín, mejoras, para mí" },
	{ kind = "toggle", key = ID .. ".meSirve", label = L["Solo el botín que me sirve"],
		help = L["Oculta lo que tu clase no puede usar o no le conviene: armadura de otro tipo, armas que no usas, piezas sin nada para tu especialización."] },
	{ kind = "toggle", label = L["Entradas en el minimapa"],
		help = L["Marca en el minimapa la entrada de cada mazmorra (en verde las que ya hiciste). El mapa del mundo ya las marca solo."],
		get = function() return M.Capa ~= nil and M.Capa.Activa() end,
		set = function(on) if M.Capa then M.Capa.Poner(on ~= false) end cambio() end },
	-- 1.3.7
	{ kind = "toggle", key = ID .. ".consumibles", label = L["Recordarme lo que me falta antes de un jefe"],
		help = L["Al apuntar a un jefe (y al entrar a una banda): comida de bufo, frasco o elixir en banda, piedra de salud si hay brujo y tu munición. Un aviso chico, nunca en combate."] },
	-- 1.4.0 (diario, 91)
	{ kind = "toggle", key = ID .. ".ofrecerReiniciar", label = L["Ofrecer reiniciar la mazmorra al salir"],
		help = L["Al salir de una mazmorra, si vas solo o diriges el grupo, un aviso con «Reiniciar» y cuántas instancias llevas en esta hora. También con /alfa mazmorras reiniciar."],
		search = "reset instance, reset dungeon, reiniciar, repetir mazmorra" },
	{ kind = "toggle", key = ID .. ".mapaDentro", label = L["Botón del mapa por dentro en el mapa del juego"],
		help = L["Dentro de una mazmorra, el mapa del juego trae un botón para abrir su plano con zoom, sus pisos y tu avance por jefes. También con su tecla."] },
	{ kind = "toggle", key = ID .. ".historial", label = L["Anotar el botín de mi grupo"],
		help = L["Quién se llevó qué y con qué tirada, de lo que el juego ya pone en tu chat. Lo ves en Tu progreso; no se anuncia nada."] },
	{ kind = "button", label = L["Borrar todo mi progreso"], button = L["Borrar"], icon = "reset", danger = true,
		help = L["Jefes vencidos, mazmorras hechas y botín anotado de este personaje. No toca tus ajustes."],
		confirm = true, confirmTitle = L["¿Borrar todo tu progreso?"], confirmAction = L["Borrar"],
		confirmText = L["Se borra el progreso de mazmorras de este personaje. No se puede deshacer."],
		onClick = function() D.OlvidarTodo() end },
}

---------------------------------------------------------------------------
-- Avisos de jefes (los del juego)
---------------------------------------------------------------------------
local function ctlCVar(nombre, etiqueta, ayuda, hijo, depende)
	return {
		kind = "toggle", label = etiqueta, help = ayuda, child = hijo,
		needs = function() return Av.Existe(nombre) end,
		get = function() return Av.Bool(nombre) end,
		set = function(on) Av.Poner(nombre, on) cambio() end,
		disabled = function()
			if nombre ~= "combatWarningsEnabled" and not Av.Activo("combatWarningsEnabled") then return true end
			return depende ~= nil and not Av.Activo(depende)
		end,
	}
end

local AVISOS = {
	ctlCVar("combatWarningsEnabled", L["Avisos de jefes del juego"],
		L["Prende todo el sistema de avisos de jefes de Blizzard: la línea de tiempo y los mensajes en pantalla. Sin esto, lo demás no se ve."]),
	ctlCVar("encounterTimelineEnabled", L["Línea de tiempo del jefe"],
		L["Una barra con los ataques que el jefe va a hacer y cuánto falta para cada uno. Así sabes cuándo moverte o defenderte."], true),
	ctlCVar("encounterTimelineHideLongCountdowns", L["Ocultar cuentas largas"],
		L["No muestra los ataques que todavía tardan mucho: la barra queda más limpia."], true, "encounterTimelineEnabled"),
	ctlCVar("encounterTimelineHideQueuedCountdowns", L["Ocultar ataques en espera"],
		L["No muestra los ataques que ya deberían haber llegado y esperan su momento."], true, "encounterTimelineEnabled"),
	ctlCVar("encounterTimelineHideForOtherRoles", L["Solo lo de mi papel"],
		L["Oculta los avisos que son para otro papel (por ejemplo, los del tanque si tú curas)."], true, "encounterTimelineEnabled"),
	ctlCVar("encounterTimelineIconographyEnabled", L["Íconos de ayuda"],
		L["Pequeños íconos en cada ataque: si es para el tanque, para quien cura, si se puede quitar o si es mortal."], true, "encounterTimelineEnabled"),
	ctlCVar("encounterWarningsEnabled", L["Mensajes de aviso en pantalla"],
		L["Letras grandes en el centro de la pantalla cuando el jefe hace algo importante."], true),
	{
		-- La clave (mazmorras.nivelAvisos) solo hace visible el control en
		-- Ajustes: el valor vive en la variable del juego.
		kind = "dropdown", key = ID .. ".nivelAvisos", label = L["Qué mensajes mostrar"], child = true,
		help = L["Todos: también los avisos leves. Solo los graves: únicamente lo que puede matarte."],
		needs = function() return Av.Existe("encounterWarningsLevel") end,
		choices = {
			{ value = 0, text = L["Todos"] },
			{ value = 1, text = L["Medianos y graves"] },
			{ value = 2, text = L["Solo los graves"] },
		},
		get = function() return Av.Numero("encounterWarningsLevel") end,
		set = function(v) Av.Poner("encounterWarningsLevel", v) cambio() end,
		disabled = function() return not (Av.Activo("combatWarningsEnabled") and Av.Activo("encounterWarningsEnabled")) end,
	},
	ctlCVar("encounterWarningsHideIfNotTargetingPlayer", L["Solo los que me apuntan a mí"],
		L["Oculta los mensajes de ataques que van contra otro jugador."], true, "encounterWarningsEnabled"),
	{ kind = "button", label = L["Dejarlo como recomienda Alfa"], button = L["Aplicar"], icon = "check",
		help = L["Prende la línea de tiempo, los íconos de ayuda y los mensajes medianos y graves."],
		needs = function() return Av.Existe("combatWarningsEnabled") end,
		onClick = function()
			local puestas, hay = Av.Recomendado()
			local K = N.Kit
			if hay > 0 and K and K.Aviso then
				local todo = puestas == hay
				K.Aviso({ icono = todo and "ic-exito" or "ic-aviso", tono = todo and "exito" or "aviso",
					titulo = todo and L["Avisos de jefes como los recomienda Alfa"] or format(L["Se pusieron %d de %d opciones"], puestas, hay),
					texto = not todo and L["El juego no dejó cambiar las demás."] or nil })
			end
			cambio()
		end },
	{ kind = "button", label = L["Probar la línea de tiempo"], button = L["Probar"], icon = "hourglass",
		help = L["Pone tres ataques de prueba en la línea de tiempo para que veas dónde sale. Se borran solos. Para moverla: menú del juego (Esc) > Modo de edición."],
		needs = function() return type(C_EncounterTimeline) == "table" end,
		onClick = function()
			local ok, porque = Av.Probar()
			local K = N.Kit
			if K and K.Aviso then
				K.Aviso({ icono = ok and "ic-reloj" or "ic-alerta", tono = ok and "acento" or "aviso",
					titulo = ok and L["Mira la línea de tiempo: llegan tres ataques de prueba"] or L["No se pudo probar ahora"],
					texto = not ok and porque or nil })
			end
		end },
}

---------------------------------------------------------------------------
-- 1.2.9: la mazmorra en vivo (EnVivo.lua)
---------------------------------------------------------------------------
local EN_VIVO = {
	{ kind = "toggle", key = ID .. ".enVivo", label = L["La mazmorra en vivo"],
		help = L["Dentro de una mazmorra, al apuntar a un jefe sale una tarjeta chica con lo que te toca según tu papel y cómo van tus misiones de ahí. No atrapa clics."] },
	{ kind = "dropdown", key = ID .. ".enVivoRol", label = L["Tu papel"], child = true,
		help = L["Automático: el del buscador de grupo, o por tu clase y tu forma (postura defensiva u oso tanquean)."],
		choices = {
			{ value = "auto", text = L["Automático"] },
			{ value = "tanque", text = L["Tanque"] },
			{ value = "cura", text = L["Cura"] },
			{ value = "dano", text = L["Daño"] },
		},
		disabled = function() return N.Get(ID, "enVivo") == false end },
	-- 1.3.8: una línea con lo que más importa (de fábrica) o la tarjeta de antes.
	{ kind = "dropdown", key = ID .. ".enVivoForma", label = L["Cómo se ve"], child = true,
		help = L["Una línea: el jefe y lo más importante de su pelea, sin tapar nada. Tarjeta: tres consejos y tus misiones de ahí."],
		choices = {
			{ value = "linea", text = L["Una línea"] },
			{ value = "tarjeta", text = L["Tarjeta"] },
		},
		search = "boss tip, one line, compact, card, jefe, consejo, una línea",
		disabled = function() return N.Get(ID, "enVivo") == false end },
	-- 1.3.8: el resumen al terminar (Resumen.lua).
	{ kind = "toggle", key = ID .. ".resumenFin", label = L["Resumen al terminar una mazmorra"],
		help = L["Al vencer al último jefe, una tarjeta con tu tiempo, tu daño o tu curación, tu botín y si hiciste récord."],
		search = "dungeon summary, run summary, record, time, loot, resumen, récord" },
}

A.RegisterDefaults(ID, { nivelAvisos = 1 })

local ok, err = A.RegisterOptions({ page = PAGINA, tab = PESTANA, section = L["Tu diario de mazmorras"], controls = DIARIO })
if not ok and geterrorhandler then geterrorhandler()(err) end
ok, err = A.RegisterOptions({ page = PAGINA, tab = PESTANA, section = L["Avisos de jefes"], controls = AVISOS })
if not ok and geterrorhandler then geterrorhandler()(err) end
ok, err = A.RegisterOptions({ page = PAGINA, tab = PESTANA, section = L["La mazmorra en vivo"], controls = EN_VIVO })
if not ok and geterrorhandler then geterrorhandler()(err) end
