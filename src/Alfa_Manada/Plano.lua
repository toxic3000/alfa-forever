-- Alfa - La Jauría: cambiar de plano cuando está lleno (1.2.9). toxic3000 /
-- La Jauría. GPL-3.0.
--
-- Mientras cazas o recolectas fuera de instancias, Alfa mira cuánta gente hay
-- en tu plano (la capa de la zona, Guaridas.lua):
--   * los jugadores que se ven en las placas de nombre (sin tu grupo),
--   * las presas de alrededor que ya tomó otro (UnitIsTapDenied),
--   * los nodos que se te van («ya lo está usando alguien», UI_ERROR_MESSAGE).
-- Con eso arma un puntaje de 0 a 100 de lo que vio en los últimos VENTANA
-- segundos: tranquilo, con gente o lleno. Si está claramente lleno (dos
-- revisiones seguidas), Lya te lo dice una vez cada ENFRIA segundos:
-- «Esto está lleno de cazadores. ¿Nos cambiamos de plano?» con «Cambiar de
-- plano» (Gu.CambiarPlano: le pregunta a la manada con la guarida abierta en
-- otro plano). Al llegar, te compara cómo estaba antes y cómo está ahora.
-- Solo lee: no envía nada hasta que pulsas el botón. Ajuste manada.planoAviso.
--
--   Pl.Estado() -> { puntos, nivel = "tranquilo"|"gente"|"lleno", jugadores, tapados, nodos }
--   Pl.Texto(e) -> "lleno: 8 cazadores cerca, 5 presas ya tomadas"
--   Pl.CambiarYDecir() -> ok    el botón «Cambiar de plano» (y /alfa plano)
--   Pl.Revisar() -> sugirió?     lo que corre cada CADA segundos
--   Pl.NodoPerdido()            un nodo que se te fue (para otros módulos y las pruebas)

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local U, L, ID = M.U, M.L, M.ID

local Pl = {}
M.Plano = Pl

local type, pcall, pairs, format, min, floor = type, pcall, pairs, string.format, math.min, math.floor

local VENTANA = 180    -- segundos que cuentan
local CADA = 10        -- una revisión cada tanto
local ENFRIA = 900     -- Lya lo sugiere una vez cada 15 min
local COMPARAR = 75    -- segundos en el plano nuevo antes de comparar
local LLENO, GENTE = 60, 25
local POR_JUGADOR, POR_TAPADO, POR_NODO = 7, 8, 20

local function on(clave) return N.Get(ID, clave) and true or false end

local jugadores, tapados, nodos = {}, {}, {} -- guid -> visto; nodos: lista de tiempos
local seguidas = 0          -- revisiones seguidas con el plano lleno
local sugerido = -math.huge
local nivelVisto
Pl.version = 0

local function leer(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, v = pcall(fn, ...)
	if not ok then return nil end
	return U.Leer(v)
end

function Pl.Reiniciar()
	wipe(jugadores) wipe(tapados) wipe(nodos)
	seguidas = 0
end

local function contar(t, ahora)
	local n = 0
	for k, at in pairs(t) do
		if ahora - at > VENTANA then t[k] = nil else n = n + 1 end
	end
	return n
end

-- Una unidad vista (placa de nombre, objetivo, cursor).
function Pl.Ver(unit)
	if not leer(UnitExists, unit) then return end
	local okG, guid = pcall(UnitGUID, unit)
	if not okG or type(guid) ~= "string" or U.Secreto(guid) then return end
	local ahora = U.Ahora()
	if leer(UnitIsPlayer, unit) then
		if leer(UnitIsUnit, unit, "player") then return end
		if leer(UnitInParty, unit) or leer(UnitInRaid, unit) then return end
		jugadores[guid] = ahora
	elseif leer(UnitIsTapDenied, unit) and not leer(UnitIsDead, unit) then
		tapados[guid] = ahora
	end
end

function Pl.NodoPerdido()
	nodos[#nodos + 1] = U.Ahora()
end

local function muestrear()
	if U.EnInstancia() then return end
	for i = 1, 40 do Pl.Ver("nameplate" .. i) end
end
Pl.Muestrear = muestrear

function Pl.Estado()
	local ahora = U.Ahora()
	local nj, nt = contar(jugadores, ahora), contar(tapados, ahora)
	local i = 1
	while nodos[i] do
		if ahora - nodos[i] > VENTANA then table.remove(nodos, i) else i = i + 1 end
	end
	local nn = #nodos
	local puntos = min(100, nj * POR_JUGADOR + nt * POR_TAPADO + nn * POR_NODO)
	local nivel = puntos >= LLENO and "lleno" or (puntos >= GENTE and "gente" or "tranquilo")
	return { puntos = puntos, nivel = nivel, jugadores = nj, tapados = nt, nodos = nn }
end

local NIVELES = { tranquilo = "tranquilo", gente = "con gente", lleno = "lleno" }

function Pl.NombreNivel(nivel) return L[NIVELES[nivel] or "tranquilo"] end

-- "lleno: 8 cazadores cerca, 5 presas ya tomadas"
function Pl.Texto(e)
	e = e or Pl.Estado()
	local partes = {}
	if e.jugadores > 0 then partes[#partes + 1] = format(e.jugadores == 1 and L["%d cazador cerca"] or L["%d cazadores cerca"], e.jugadores) end
	if e.tapados > 0 then partes[#partes + 1] = format(e.tapados == 1 and L["%d presa ya tomada"] or L["%d presas ya tomadas"], e.tapados) end
	if e.nodos > 0 then partes[#partes + 1] = format(e.nodos == 1 and L["%d nodo que se te fue"] or L["%d nodos que se te fueron"], e.nodos) end
	local t = Pl.NombreNivel(e.nivel)
	if #partes > 0 then t = t .. ": " .. table.concat(partes, ", ") end
	return t
end

local function aviso(o)
	local K = N.Kit
	if M.U and M.U.Aviso then M.U.Aviso(o) else U.Decir(o.titulo .. (o.texto and (" " .. o.texto) or "")) end
end

local function enGrupo()
	return leer(IsInGroup) and true or false
end

---------------------------------------------------------------------------
-- Cambiar de plano
---------------------------------------------------------------------------

Pl.MOTIVOS = {
	compartir = "Para cambiar de plano con la manada, primero deja que te vea en el mapa (ajustes de La Jauría).",
	grupo = "Sal de tu grupo primero: el juego te pasa al plano de quien te invita.",
	instancia = "Dentro de una instancia no hay planos.",
	mapa = "Alfa no sabe en qué zona estás.",
	sincapa = "Mira a una criatura primero: así Alfa sabe en qué plano estás.",
	pedido = "Ya estás tocando a una puerta. Espera tantito.",
	espera = "Ya le preguntaste a la manada hace poco. Te aviso si alguien abre su guarida.",
	red = "Ahora no se puede hablar con la manada. Prueba en un rato.",
}

-- Nadie en otro plano: lo dice claro y ofrece preguntarle a la manada.
local function nadie()
	aviso({ titulo = L["Nadie de la manada anda en otro plano"],
		texto = L["Ningún lobo de tu zona tiene su guarida abierta en otro plano. ¿Le pregunto a la manada si alguien te abre la suya?"],
		icono = "ic-manada", duracion = 20,
		accion = { texto = L["Preguntar a la manada"], alClic = function() Pl.PreguntarYDecir() end } })
end

function Pl.PreguntarYDecir()
	local ok, por = M.Guaridas.PreguntarManada()
	if ok then
		U.Decir(L["Le pregunté a la manada de tu zona. Si alguien abre su guarida en otro plano, te aviso."])
	elseif Pl.MOTIVOS[por] then
		U.Decir(L[Pl.MOTIVOS[por]])
	end
	return ok
end

local antesDe -- el estado al pedir el cambio
function Pl.CambiarYDecir()
	local e = Pl.Estado()
	local ok, por = M.Guaridas.CambiarPlano(e)
	if ok then
		antesDe = e
		return true
	end
	if por == "nadie" then nadie()
	elseif Pl.MOTIVOS[por] then U.Decir(L[Pl.MOTIVOS[por]]) end
	return false, por
end

-- Llegaste a otro plano: se empieza a contar de nuevo y, al rato, se compara.
function Pl.AlLlegar(antes)
	antes = antes or antesDe
	antesDe = nil
	Pl.Reiniciar()
	sugerido = U.Ahora() -- (en el plano nuevo no se sugiere cambiar enseguida)
	if not antes then return end
	A.After(COMPARAR, function()
		muestrear()
		local ahora = Pl.Estado()
		aviso({ titulo = L["Tu plano nuevo"], icono = "ic-manada", duracion = 15, detalle = true,
			texto = format(L["Antes: %s. Ahora: %s."], Pl.Texto(antes), Pl.Texto(ahora)) })
		Pl.ultimaComparacion = { antes = antes, ahora = ahora }
	end)
end

---------------------------------------------------------------------------
-- La sugerencia de Lya
---------------------------------------------------------------------------

function Pl.Revisar()
	if U.EnInstancia() then seguidas = 0 return false end
	if InCombatLockdown and InCombatLockdown() then return false end
	muestrear()
	local e = Pl.Estado()
	if e.nivel ~= nivelVisto then
		nivelVisto = e.nivel
		Pl.version = Pl.version + 1
		if M.Avisar then M.Avisar() end
	end
	if e.nivel ~= "lleno" then seguidas = 0 return false end
	seguidas = seguidas + 1
	if seguidas < 2 or not on("planoAviso") or not on("compartir") or enGrupo() then return false end
	local G = M.Guaridas
	if not (G.Actual() and not G.Pedido()) then return false end
	local ahora = U.Ahora()
	if ahora - sugerido < ENFRIA then return false end
	sugerido = ahora
	aviso({ titulo = L["Esto está lleno de cazadores"], icono = "ic-manada", duracion = 20, detalle = true,
		texto = L["¿Nos cambiamos de plano?"] .. " " .. format(L["Cerca de ti: %s."], Pl.Texto(e)),
		accion = { texto = L["Cambiar de plano"], alClic = function() Pl.CambiarYDecir() end } })
	return true
end

function Pl.Olvidar() Pl.Reiniciar() sugerido = -math.huge end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------

-- «Ya lo está usando alguien»: un nodo (mineral, hierba, cofre) que se te fue.
local OCUPADO = { "SPELL_FAILED_CHEST_IN_USE", "ERR_OBJECT_IS_BUSY" }
A.RegisterEvent("UI_ERROR_MESSAGE", function(_, _, msg)
	if type(msg) ~= "string" or U.Secreto(msg) then return end
	for i = 1, #OCUPADO do
		local g = rawget(_G, OCUPADO[i])
		if type(g) == "string" and g == msg then Pl.NodoPerdido() return end
	end
end)
A.RegisterEvent("PLAYER_TARGET_CHANGED", function() pcall(Pl.Ver, "target") end)
A.RegisterEvent("ZONE_CHANGED_NEW_AREA", function() Pl.Reiniciar() end)

A.OnLogin(function()
	M.Cada("manada.plano", CADA, function() pcall(Pl.Revisar) end)
end)
