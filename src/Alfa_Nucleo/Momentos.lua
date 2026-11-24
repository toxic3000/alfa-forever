-- Alfa - Núcleo: los momentos (1.3.7). toxic3000 / La Jauría. GPL-3.0.
--
-- Una sola cola para todo lo que Alfa muestra o recalcula cuando pasa algo
-- grande, para no encimarse con el juego ni consigo misma. Lo que no es
-- urgente espera a que termine lo del juego (subir de nivel, una pantalla de
-- carga, una cinemática, hablar con un PNJ, una pelea) y sale una cosa a la
-- vez, por prioridad.
--
--   N.Ocupado(tipo, prioridad) -> bool, motivo
--       tipo: "aviso" (de fábrica), "anuncio", "lya", "pesado" (recálculos)
--       motivo: "cinematica", "nivel", "carga", "combate", "estandarte",
--               "calma", "pnj", "lleno"
--   N.AlLibre(clave, fn, prioridad, o) -> true (ya corrió) | "espera"
--       corre fn en cuanto no esté ocupado; una por clave (la nueva reemplaza
--       a la que esperaba); o = { tipo = "aviso", caduca = s, alCaducar = fn }
--   N.PRIORIDAD = { urgente = 1, importante = 2, util = 3, detalle = 4 }
--   N.Prioridad(p) -> 1..4 (número o nombre; de fábrica 3)
--   N.TrasNivel(clave, fn) -> manejador de PLAYER_LEVEL_UP que espera a la
--       animación del juego y se escalona con los demás («pesado»)
--   N.ResumenNivelCubre(que) -> bool  el resumen de nivel ya dice eso
--       ("talento", "hechizos"): quien lo diría aparte se calla
--   N.EnCalma() -> bool, motivo   N.Calma(modo) («30», «60», «sesion», «no»)
--   N.Perdido(o)   N.Perdidos() -> lista   N.PerdidosSinVer() -> n
--   N.OlvidarPerdido(e)   N.VerPerdidos()   N.MenuPerdidos() -> item del menú
--   1.3.7, la campanita: N.Avisos()  N.AvisosSinVer()  N.VerAvisos()  N.MenuAvisos()
--       N.AvisoReciente(o, por)  N.MarcarAvisosVistos()  (más abajo, «Avisos»)
--   N.Sonar(tipo, prioridad)   N.SonidoPermitido(prioridad) -> bool
--   N.YaDicho(voz) -> bool   N.Anotar(voz)   (AlfaNucleo.dichosSesion)
--   N.AnunciosGrandes() -> bool   el ajuste que manda sobre los anuncios grandes
--   N.MomentosActivos() -> bool   falso en el banco de pruebas salvo
--       BANCO_MOMENTOS = true (sus escenas viejas prueban todo al instante)
--
-- Ajustes (nucleo.*): sonidos = "todos" | "importantes" | "ninguno",
-- respetarDnd = true, resumenNivel = true, callarRepetidos = true (1.3.9),
-- avisos.<firma> = false (1.3.9: un tipo apagado en el Centro de avisos).
--
-- 1.3.9 (67, 68 y 70):
--   N.AvisoApagado(o) -> bool   su tipo (la firma de su módulo) está apagado
--   N.Repeticion(o) -> "sale" | "ultima" | "callado", clave
--       la cuarta vez que un aviso igual sale en la sesión es la última (con
--       «Ya te lo dije 3 veces»); las siguientes se callan
--   N.AvisoCallado(o, clave) -> o   el aviso de la última vez
--   N.Reactivar(clave)   N.ReactivarTodos()   N.Callados() -> n
--   N.GrupoCentroAvisos(padre) -> grupo de ajustes   N.ProbarAviso(firma)

local _, N = ...
local A = N.A
local K = N.Kit
local L = K and K.L or N.Textos(N.EN)

local type, pairs, ipairs, pcall, tonumber, tostring, select = type, pairs, ipairs, pcall, tonumber, tostring, select
local min, max, floor, huge, format, unpack = math.min, math.max, math.floor, math.huge, string.format, unpack
local tinsert, tremove, tsort, concat = table.insert, table.remove, table.sort, table.concat

local function ahora() return GetTime and GetTime() or 0 end
local function reloj() return (GetServerTime and GetServerTime()) or (time and time()) or 0 end
local function secreto(v) return issecretvalue ~= nil and type(v) ~= "nil" and issecretvalue(v) and true or false end
local function num(v) if secreto(v) then return nil end return tonumber(v) end
local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end
local function datos() return N.DatosPersonaje("momentos") end

-- El banco de pruebas (el único con FIRE_EVENT) no espera al juego: sus
-- escenas viejas prueban los avisos al instante. Las de los momentos lo piden.
local function banco() return rawget(_G, "FIRE_EVENT") ~= nil and rawget(_G, "BANCO_MOMENTOS") ~= true end
function N.MomentosActivos() return not banco() end

if A and A.RegisterDefaults then
	-- 1.3.9: callarRepetidos (68) y avisos.<firma> = false para apagar un tipo (67).
	local avisos = {}
	for c in pairs(K and K.FIRMAS or {}) do avisos[c] = true end
	A.RegisterDefaults("nucleo", { sonidos = "todos", respetarDnd = true, resumenNivel = true, callarRepetidos = true,
		avisos = avisos })
end

N.PRIORIDAD = { urgente = 1, importante = 2, util = 3, detalle = 4 }
function N.Prioridad(p)
	if type(p) == "string" then p = N.PRIORIDAD[p] end
	p = tonumber(p)
	if not p then return 3 end
	return max(1, min(4, floor(p)))
end
local prioridad = N.Prioridad

---------------------------------------------------------------------------
-- Una sola voz (1.3.3 y 1.3.7): lo que ya se dijo en la sesión no lo repite
-- otro módulo. Las voces de un nivel llevan el nivel ("entrenador:12").
---------------------------------------------------------------------------
N.dichosSesion = type(rawget(N, "dichosSesion")) == "table" and N.dichosSesion or {}
function N.YaDicho(voz) return voz ~= nil and N.dichosSesion[voz] ~= nil end
function N.Anotar(voz) if voz ~= nil then N.dichosSesion[voz] = ahora() end end
-- -> true la primera vez (y la anota); false si ya se dijo.
function N.UnaVez(voz)
	if N.YaDicho(voz) then return false end
	N.Anotar(voz)
	return true
end

---------------------------------------------------------------------------
-- 1.3.8: un mensaje por suceso (pedido de Toxic: «los mensajes al llegar en
-- barco se repiten o se empalman; quiero que se sientan únicos»).
--   N.Suceso(clave, ventana) -> true la primera vez en `ventana` s (y la
--       anota); false si otro canal ya lo dijo. Quien avisa de lo mismo
--       (la zona peligrosa: el anuncio de zona y el aviso de Rutas) usa la
--       misma clave: el primero lo dice, el segundo se calla.
--   N.Visto(texto, canal)   anota lo que salió (avisos, anuncios, Lya, chat)
--   N.YaSeVio(texto, ventana, canal) -> bool, canal   ¿ya salió por OTRO canal?
--   N.Normalizar(texto) -> el texto sin colores, íconos, signos ni mayúsculas
--   N.Salidas() -> los últimos mensajes { canal, texto, t } (banco, /alfa rendimiento)
---------------------------------------------------------------------------
local SUCESO_VENTANA = 60
local VISTO_VENTANA = 45
local MAX_SALIDAS = 40
local sucesos = {}  -- clave -> GetTime()
local vistosTexto = {} -- texto normalizado -> { t, canal }
local salidas = {}
N.SUCESO_VENTANA, N.VISTO_VENTANA = SUCESO_VENTANA, VISTO_VENTANA

function N.Normalizar(t)
	if type(t) ~= "string" or secreto(t) then return nil end
	t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|H.-|h(.-)|h", "%1")
	t = t:lower():gsub("[%p]", " "):gsub("\194[\161\171\183\187\191]", " "):gsub("\226\128[\147\148\166]", " ")
	t = t:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
	if t == "" then return nil end
	return t
end

local function podar(tabla, ventana)
	local t0 = ahora()
	for k, v in pairs(tabla) do
		local cuando = type(v) == "table" and v.t or v
		if t0 - (tonumber(cuando) or 0) > ventana then tabla[k] = nil end
	end
end

function N.Suceso(clave, ventana)
	if clave == nil then return true end
	clave = tostring(clave)
	local t = sucesos[clave]
	if t and ahora() - t < (tonumber(ventana) or SUCESO_VENTANA) then return false end
	podar(sucesos, 3600)
	sucesos[clave] = ahora()
	return true
end
-- (1.3.8 revisión) Lo que se anotó y al final no se dijo.
function N.OlvidarSuceso(clave)
	if clave ~= nil then sucesos[tostring(clave)] = nil end
end
function N.SucesoDicho(clave, ventana)
	local t = clave ~= nil and sucesos[tostring(clave)]
	return t ~= nil and t ~= false and ahora() - t < (tonumber(ventana) or SUCESO_VENTANA)
end

function N.Visto(texto, canal)
	local n = N.Normalizar(texto)
	if not n then return end
	podar(vistosTexto, 300)
	vistosTexto[n] = { t = ahora(), canal = canal or "?" }
	salidas[#salidas + 1] = { canal = canal or "?", texto = texto, t = ahora() }
	while #salidas > MAX_SALIDAS do tremove(salidas, 1) end
end

function N.YaSeVio(texto, ventana, canal)
	local n = N.Normalizar(texto)
	local v = n and vistosTexto[n]
	if not v or ahora() - v.t >= (tonumber(ventana) or VISTO_VENTANA) then return false end
	if canal and v.canal == canal then return false end
	return true, v.canal
end

function N.Salidas() return salidas end
function N.OlvidarSucesos() sucesos, vistosTexto, salidas = {}, {}, {} end -- (para el banco)

---------------------------------------------------------------------------
-- Lo que hace el juego
---------------------------------------------------------------------------
local CALMA_CARGA = 3      -- s de calma después de una pantalla de carga
local PNJ_SUYO = 2         -- s después de abrir un PNJ en que lo que sale es "de ese PNJ"
local PNJ_MAX = 600        -- s: un PNJ que nunca avisó que cerró se da por cerrado
local NIVEL_SIN_MARCO = 4  -- s de espera al subir de nivel si el juego no trae su estandarte
local NIVEL_TRAS = 1       -- s después de que se va el estandarte del juego
local NIVEL_MAX = 12       -- s como mucho

local cargaHasta = -huge
local enCarga = false
local cine = false
local pnj = { abierto = false, desde = -huge }
local nivel = { desde = nil, visto = nil, n = nil }

local function visible(nombre)
	local g = rawget(_G, nombre)
	if type(g) ~= "table" or type(g.IsShown) ~= "function" then return false, false end
	local ok, si = pcall(g.IsShown, g)
	if not (ok and si) then return false, true end
	local a = g.GetAlpha and g:GetAlpha()
	if type(a) == "number" and a <= 0.05 then return false, true end
	return true, true
end

local NIVEL_JUEGO = { "LevelUpDisplay", "EventToastManagerFrame" }
local function marcoNivel()
	local existe = false
	for _, n in ipairs(NIVEL_JUEGO) do
		local v, e = visible(n)
		if v then return true, true end
		existe = existe or e
	end
	return false, existe
end

-- Los estandartes del juego arriba del centro (jefes, logros, nivel).
local ESTANDARTES = { "BossBanner", "EventToastManagerFrame", "LevelUpDisplay" }
function N.JuegoEnPantalla()
	for _, n in ipairs(ESTANDARTES) do if visible(n) then return true end end
	return false
end

local function nivelOcupado(t)
	if not nivel.desde then return false end
	local dt = t - nivel.desde
	if dt > NIVEL_MAX or dt < 0 then nivel.desde = nil return false end
	local ve, existe = marcoNivel()
	if ve then nivel.visto = t return true end
	if existe then
		if nivel.visto then return t < nivel.visto + NIVEL_TRAS end
		return dt < NIVEL_SIN_MARCO -- el marco existe pero no salió: lo normal de un nivel sin estandarte
	end
	return dt < NIVEL_SIN_MARCO
end
function N.SubiendoNivel() return nivelOcupado(ahora()) end

local cineDesde = -huge
local function cinematica()
	local vc, ec = visible("CinematicFrame")
	local vm, em = visible("MovieFrame")
	if vc or vm then return true end
	-- 1.3.7: una película que acaba sola, se corta con Esc o no arranca pasa
	-- por FinishMovie() sin STOP_MOVIE: si ya no se ve nada, se acabó.
	if cine and (ec or em) and ahora() - cineDesde > 1 then cine = false end
	return cine
end
N.EnCinematica = cinematica -- (para el banco)

local MARCOS_PNJ = { "GossipFrame", "MerchantFrame", "QuestFrame", "ClassTrainerFrame", "TaxiFrame" }
local function pnjAbierto(t)
	if not pnj.abierto then return false end
	if t - pnj.desde > PNJ_MAX then pnj.abierto = false return false end
	-- Si el juego trae esas ventanas y ninguna se ve, ya se cerró (se perdió el evento).
	local alguno, existe = false, false
	for _, n in ipairs(MARCOS_PNJ) do
		local v, e = visible(n)
		alguno = alguno or v
		existe = existe or e
	end
	if existe and not alguno and t - pnj.desde > 1 then pnj.abierto = false return false end
	return true
end
local function pnjOcupado(t) return pnjAbierto(t) and t - pnj.desde > PNJ_SUYO end
function N.HablandoConPnj() return pnjAbierto(ahora()) end

---------------------------------------------------------------------------
-- No molestar (/alfa calma)
---------------------------------------------------------------------------
local calmaSesion = false
local calmaAvisada -- el motivo con que empezó (para avisar al terminar)

local function dnd()
	if A and A.Get and A.Get("nucleo.respetarDnd") == false then return false end
	if not UnitIsDND then return false end
	local ok, v = pcall(UnitIsDND, "player")
	return ok and not secreto(v) and (v == true or v == 1)
end

function N.EnCalma()
	if calmaSesion then return true, "sesion" end
	local h = tonumber(datos().calmaHasta) or 0
	if h > reloj() then return true, "tiempo" end
	if dnd() then return true, "dnd" end
	return false
end
function N.CalmaHasta()
	if calmaSesion then return huge end
	return tonumber(datos().calmaHasta) or 0
end

---------------------------------------------------------------------------
-- N.Ocupado
---------------------------------------------------------------------------
local avisosLlenos -- (Kit/Ventanas.lua lo pone: K.AvisosLlenos)

function N.Ocupado(tipo, p)
	tipo = type(tipo) == "string" and tipo or "aviso"
	p = prioridad(p)
	local t = ahora()
	local sim = not banco()
	if sim and cinematica() then return true, "cinematica" end
	if sim and nivelOcupado(t) then return true, "nivel" end
	if tipo == "pesado" then
		if sim and (enCarga or t < cargaHasta) then return true, "carga" end
		return false
	end
	if p >= 2 then
		if sim and (enCarga or t < cargaHasta) then return true, "carga" end
		if enCombate() then return true, "combate" end
		if sim and N.JuegoEnPantalla() then return true, "estandarte" end
		if tipo ~= "aviso" and N.EnCalma() then return true, "calma" end
	end
	if p >= 3 and sim and pnjOcupado(t) then return true, "pnj" end
	-- 40: un aviso útil no sale encima de un anuncio grande de Alfa (Kit/Anuncio.lua).
	if p >= 3 and sim and tipo == "aviso" and visible("AlfaAnuncio") then return true, "anuncio" end
	if tipo == "aviso" then
		local f = K and K.AvisosLlenos
		if type(f) == "function" and f() then return true, "lleno" end
	end
	return false
end

---------------------------------------------------------------------------
-- La cola: un carril por tipo, una cosa a la vez, por prioridad.
---------------------------------------------------------------------------
local ESPACIO = { aviso = 1, lya = 1.5, anuncio = 2, pesado = 0.2 }
local carriles = {}
local porClave = {}
local seq = 0
local function carril(tipo)
	local c = carriles[tipo]
	if not c then c = { lista = {}, proxima = -huge } carriles[tipo] = c end
	return c
end
for tipo in pairs(ESPACIO) do carril(tipo) end

-- 1.3.7: lo que corre ahora, por clave. Quien se vuelve a pedir a sí mismo
-- mientras corre (Lya esperando dentro de una mazmorra) va a la fila y no se
-- llama otra vez en el acto: así no da vueltas sin fin («C stack overflow»).
local enCurso = {}
local function correr(fn, clave)
	if clave then enCurso[clave] = (enCurso[clave] or 0) + 1 end
	local ok, err = pcall(fn)
	if clave then
		local n = (enCurso[clave] or 1) - 1
		enCurso[clave] = n > 0 and n or nil
	end
	if not ok and geterrorhandler then geterrorhandler()(err) end
end

local bombear
local function despertar()
	if N.HayTarea and N.HayTarea("nucleo.momentos") then return end
	if N.Cada then N.Cada("nucleo.momentos", 0.25, function() bombear() end) end
end

local function quitarClave(e) if e.clave and porClave[e.clave] == e then porClave[e.clave] = nil end end
local function antes(a, b)
	if a.prio ~= b.prio then return a.prio < b.prio end
	return a.seq < b.seq
end

-- Lo que se ve (avisos, Lya, anuncios, Hoy) sale de uno en uno entre todos
-- los carriles, por prioridad; los recálculos («pesado») van aparte.
local visibleProxima = -huge
local POR_VUELTA = 3 -- recálculos por vuelta de la cola (cada 0.25 s)
local function sacar(c, e)
	for i, x in ipairs(c.lista) do if x == e then tremove(c.lista, i) break end end
	quitarClave(e)
end

-- ¿Todo lo que espera, solo por la calma? (lo pesado nunca espera por ella)
local function soloCalma()
	if #carriles.pesado.lista > 0 then return false end
	local alguno = false
	for tipo, c in pairs(carriles) do
		if tipo ~= "pesado" then
			for _, e in ipairs(c.lista) do
				local oc, por = N.Ocupado(e.tipo, e.prio)
				if not (oc and por == "calma") then return false end
				alguno = true
			end
		end
	end
	return alguno
end

bombear = function()
	local t = ahora()
	local tipos = {}
	for tipo in pairs(carriles) do tipos[#tipos + 1] = tipo end
	-- Lo vencido se va (y quien lo pidió se entera).
	for _, tipo in ipairs(tipos) do
		local c = carriles[tipo]
		for i = #c.lista, 1, -1 do
			local e = c.lista[i]
			if e.hasta and t > e.hasta then
				tremove(c.lista, i)
				quitarClave(e)
				if e.alCaducar then correr(e.alCaducar) end
			end
		end
	end
	-- Unos pocos recálculos por vuelta (escalonados: nunca todos en el mismo cuadro).
	local p = carriles.pesado
	if p and #p.lista > 0 and t >= p.proxima then
		tsort(p.lista, antes)
		for _ = 1, POR_VUELTA do
			local e = p.lista[1]
			if not e or N.Ocupado("pesado", e.prio) then break end
			sacar(p, e)
			p.proxima = t + ESPACIO.pesado
			correr(e.fn, e.clave)
		end
	end
	-- Lo que se ve: el primero que ya puede, de todos los carriles.
	if t >= visibleProxima then
		local todos = {}
		for _, tipo in ipairs(tipos) do
			if tipo ~= "pesado" then
				for _, e in ipairs(carriles[tipo].lista) do todos[#todos + 1] = e end
			end
		end
		tsort(todos, antes)
		for _, e in ipairs(todos) do
			if not N.Ocupado(e.tipo, e.prio) then
				sacar(carriles[e.tipo], e)
				visibleProxima = t + (ESPACIO[e.tipo] or 1)
				correr(e.fn, e.clave)
				break
			end
		end
	end
	if N.EnEspera() == 0 then
		if N.Quitar then N.Quitar("nucleo.momentos") end
	elseif soloCalma() and N.Quitar then
		-- 1.3.7: lo que queda solo espera a que acabe la calma: la cola duerme
		-- (la despierta el fin de la calma) y solo se asoma cuando algo caduca.
		N.Quitar("nucleo.momentos")
		local h = huge
		for tipo, c in pairs(carriles) do
			if tipo ~= "pesado" then for _, e in ipairs(c.lista) do if e.hasta and e.hasta < h then h = e.hasta end end end
		end
		if h < huge and N.Una then N.Una("nucleo.momentosVence", max(0.25, h - t + 0.05), despertar) end
	end
end
N.BombearMomentos = bombear -- (para el banco)
function N.EstadoMomentos() -- (para el banco y /alfa rendimiento)
	local out = { ahora = ahora(), visibleProxima = visibleProxima }
	for tipo, c in pairs(carriles) do
		local claves = {}
		for i, e in ipairs(c.lista) do claves[i] = tostring(e.clave) .. "/" .. tostring(e.prio) end
		out[tipo] = { n = #c.lista, proxima = c.proxima, claves = concat(claves, ", ") }
	end
	return out
end

function N.AlLibre(clave, fn, p, o)
	if type(fn) ~= "function" then return false end
	o = type(o) == "table" and o or {}
	local tipo = type(o.tipo) == "string" and o.tipo or "aviso"
	p = prioridad(p)
	clave = clave ~= nil and tostring(clave) or nil
	local c = carril(tipo)
	local ya = clave and porClave[clave]
	if ya then
		ya.fn = fn
		if p < ya.prio then ya.prio = p end
		if o.caduca then ya.hasta = ahora() + o.caduca end
		return "espera"
	end
	-- Sale ya si nada espera antes que él (lo urgente no hace fila) y no está ocupado.
	local fila = false
	if tipo == "pesado" then
		fila = #c.lista > 0
	elseif p > 1 then
		fila = ahora() < visibleProxima
		for t2, c2 in pairs(carriles) do if t2 ~= "pesado" and #c2.lista > 0 then fila = true end end
	end
	if clave and enCurso[clave] then fila = true end
	if not fila and not N.Ocupado(tipo, p) then
		correr(fn, clave)
		return true
	end
	seq = seq + 1
	local e = { clave = clave, fn = fn, prio = p, tipo = tipo, desde = ahora(), seq = seq,
		hasta = tonumber(o.caduca) and ahora() + tonumber(o.caduca) or nil, alCaducar = o.alCaducar }
	c.lista[#c.lista + 1] = e
	if clave then porClave[clave] = e end
	despertar()
	return "espera"
end

-- Cuántas cosas esperan (de un tipo, o todas).
function N.EnEspera(tipo)
	local n = 0
	for t, c in pairs(carriles) do if not tipo or t == tipo then n = n + #c.lista end end
	return n
end
function N.Esperando(clave) return clave ~= nil and porClave[tostring(clave)] ~= nil end

-- Un manejador de PLAYER_LEVEL_UP que espera la animación del juego y se escalona.
function N.TrasNivel(clave, fn)
	if type(fn) ~= "function" then return fn end
	return function(...)
		local n, args = select("#", ...), { ... }
		N.AlLibre("nivel." .. tostring(clave), function() fn(unpack(args, 1, n)) end, 3, { tipo = "pesado" })
	end
end

---------------------------------------------------------------------------
-- Sonidos (69-71)
---------------------------------------------------------------------------
local SONIDOS = {
	aviso = "IG_QUEST_LIST_OPEN", importante = "UI_BNET_TOAST", exito = "IG_QUEST_LIST_COMPLETE",
	nivel = "IG_QUEST_LIST_COMPLETE", peligro = "ALARM_CLOCK_WARNING_2", lya = "IG_MAINMENU_OPTION_CHECKBOX_ON",
}
local SONIDO_ID = { IG_QUEST_LIST_OPEN = 875, UI_BNET_TOAST = 18019, IG_QUEST_LIST_COMPLETE = 878,
	ALARM_CLOCK_WARNING_2 = 12867, IG_MAINMENU_OPTION_CHECKBOX_ON = 856 }

function N.SonidoPermitido(p)
	local m = A and A.Get and A.Get("nucleo.sonidos")
	if m == "ninguno" then return false end
	if m == "importantes" then return prioridad(p) <= 2 end
	return true
end

N.ultimoSonido = nil -- (para el banco: el último que sonó)
local sonadoEn = -huge
function N.Sonar(tipo, p)
	if not N.SonidoPermitido(p) then return false end
	local t = ahora()
	if t - sonadoEn < 0.5 then return false end -- dos cosas juntas: un solo sonido
	local nombre = SONIDOS[tipo or "aviso"] or SONIDOS.aviso
	local id = (SOUNDKIT and SOUNDKIT[nombre]) or SONIDO_ID[nombre]
	if not id then return false end
	sonadoEn = t
	N.ultimoSonido = tipo or "aviso"
	if A and A.PlaySound then pcall(A.PlaySound, id, "SFX")
	elseif PlaySound then pcall(PlaySound, id, "SFX") end
	return true
end

-- 1.3.8: un sonido por su nombre del juego (o su id de respaldo): la firma de
-- cada módulo (Kit/Firmas.lua). Las mismas reglas que N.Sonar.
function N.SonarId(nombre, respaldo, etiqueta, p)
	if not N.SonidoPermitido(p) then return false end
	local t = ahora()
	if t - sonadoEn < 0.5 then return false end
	local id = type(SOUNDKIT) == "table" and type(nombre) == "string" and rawget(SOUNDKIT, nombre) or nil
	if type(id) ~= "number" then id = respaldo end
	if type(id) ~= "number" then return false end
	sonadoEn = t
	N.ultimoSonido = etiqueta or nombre
	if A and A.PlaySound then pcall(A.PlaySound, id, "SFX")
	elseif PlaySound then pcall(PlaySound, id, "SFX") end
	return true
end

-- 61: un solo ajuste manda sobre los anuncios grandes (bienvenida.anuncios),
-- y con No molestar tampoco salen.
function N.AnunciosGrandes()
	if A and A.Get and A.Get("bienvenida.anuncios") == false then return false end
	-- (el modo ligero solo quita el fundido: Kit/Anuncio.lua)
	if N.EnCalma() then return false end
	return true
end

---------------------------------------------------------------------------
-- «Te perdiste esto» (51-53): lo que se fue sin que lo vieras, guardado por
-- personaje (los últimos 30, con su hora). Los botones solo viven en la sesión.
--
-- 1.3.7 (la campanita): «Avisos» junta en una sola lista lo que te perdiste
-- y los últimos avisos que sí viste (N.AvisoReciente, desde K.Aviso). Una
-- sola cuenta para todo: N.AvisosSinVer() (lo perdido que no has visto) es
-- la de la campanita de la ventana de Alfa y la del globito del minimapa.
--   N.Avisos() -> lista (lo más nuevo primero)   N.AvisosSinVer() -> n
--   N.MarcarVisto(e)   N.MarcarAvisosVistos()   N.OlvidarAviso(e)   N.OlvidarAvisos()
--   N.IrDeAviso(e) -> { texto, alClic } | nil    N.VerAvisos()   N.MenuAvisos()
-- Evento ALFA_AVISOS: la lista cambió (ALFA_PERDIDOS: además cambió lo perdido).
---------------------------------------------------------------------------
local MAX_PERDIDOS = 30
local MAX_RECIENTES = 20
local acciones = setmetatable({}, { __mode = "k" }) -- entrada -> { texto, alClic }

local function lista()
	local d = datos()
	if type(d.perdidos) ~= "table" then d.perdidos = {} end
	-- 1.3.7: lo visto va en cada aviso (e.visto); la hora de «visto hasta» de
	-- antes se pasa una vez a sus avisos.
	local hasta = tonumber(d.perdidosVisto)
	if hasta then
		for _, e in ipairs(d.perdidos) do
			if type(e) == "table" and (tonumber(e.t) or 0) <= hasta then e.visto = true end
		end
		d.perdidosVisto = nil
	end
	return d.perdidos
end
local function recientes()
	local d = datos()
	if type(d.recientes) ~= "table" then d.recientes = {} end
	return d.recientes
end
local pintarContador -- abajo
local refrescarVentana -- abajo

local function avisarCambio(soloLista)
	if not soloLista and A and A.Fire then pcall(A.Fire, "ALFA_PERDIDOS") end
	if A and A.Fire then pcall(A.Fire, "ALFA_AVISOS") end
	if pintarContador then pcall(pintarContador) end
	if refrescarVentana then pcall(refrescarVentana) end
end

-- El título y el texto de un aviso, si se pueden guardar (nunca un valor secreto).
local function textosDe(o)
	if secreto(o.titulo) or secreto(o.texto) then return nil end
	local titulo = type(o.titulo) == "string" and o.titulo or ""
	local texto = type(o.texto) == "string" and o.texto or ""
	if titulo == "" and texto == "" then return nil end
	return titulo, texto
end
local function quitarIgual(l, titulo, texto)
	for i = #l, 1, -1 do
		local x = l[i]
		if type(x) ~= "table" or (x.titulo == titulo and x.texto == texto) then tremove(l, i) end
	end
end
local function guardarAccion(e, ac)
	if type(ac) == "table" and type(ac.alClic or ac.fn) == "function" and not ac.seguro and type(ac.texto) == "string" then
		acciones[e] = { texto = ac.texto, alClic = ac.alClic or ac.fn }
	end
end

function N.Perdido(o)
	if type(o) ~= "table" then return nil end
	local titulo, texto = textosDe(o)
	if not titulo then return nil end
	local l = lista()
	quitarIgual(l, titulo, texto)
	quitarIgual(recientes(), titulo, texto) -- (el que viste y se fue sin tocarlo queda como perdido)
	local e = { titulo = titulo, texto = texto, icono = type(o.icono) == "string" and o.icono or nil,
		origen = type(o.origen) == "string" and o.origen or nil, t = reloj(),
		hora = date and date("%H:%M") or "", pagina = type(o.pagina) == "string" and o.pagina or nil }
	guardarAccion(e, o.accion)
	tinsert(l, 1, e)
	while #l > MAX_PERDIDOS do tremove(l) end
	avisarCambio()
	return e
end

-- 1.3.7: un aviso que salió en pantalla (o que dijo Lya): queda en «Avisos»
-- como visto. Lo que pediste también (es lo que Alfa te contestó).
function N.AvisoReciente(o, por)
	if type(o) ~= "table" or o.historial == false then return nil end
	local titulo, texto = textosDe(o)
	if not titulo then return nil end
	local l = recientes()
	quitarIgual(l, titulo, texto)
	local e = { titulo = titulo, texto = texto, icono = type(o.icono) == "string" and o.icono or (o.lobo and "ic-lobo") or nil,
		origen = type(por) == "string" and por or "aviso", t = reloj(), hora = date and date("%H:%M") or "",
		visto = true, reciente = true, pagina = type(o.pagina) == "string" and o.pagina or nil }
	local ac = type(o.accion) == "table" and o.accion or (type(o.acciones) == "table" and o.acciones[1]) or nil
	guardarAccion(e, ac)
	tinsert(l, 1, e)
	while #l > MAX_RECIENTES do tremove(l) end
	avisarCambio(true)
	return e
end

function N.Perdidos() return lista() end
function N.AccionPerdido(e) return e and acciones[e] or nil end
function N.OlvidarPerdido(e)
	local l = lista()
	for i = #l, 1, -1 do if l[i] == e then tremove(l, i) end end
	avisarCambio()
end
function N.OlvidarPerdidos()
	datos().perdidos = {}
	avisarCambio()
end
function N.PerdidosSinVer()
	local n = 0
	for _, e in ipairs(lista()) do if type(e) == "table" and not e.visto then n = n + 1 end end
	return n
end
N.AvisosSinVer = N.PerdidosSinVer -- (la misma cuenta: campanita y minimapa)
function N.MarcarPerdidosVistos()
	for _, e in ipairs(lista()) do if type(e) == "table" then e.visto = true end end
	avisarCambio()
end
N.MarcarAvisosVistos = N.MarcarPerdidosVistos
function N.MarcarVisto(e)
	if type(e) ~= "table" or e.visto then return end
	e.visto = true
	avisarCambio()
end

-- Todo junto, lo más nuevo primero (lo perdido gana si son del mismo segundo).
function N.Avisos()
	local a, b, out = lista(), recientes(), {}
	local i, j = 1, 1
	while a[i] or b[j] do
		local x, y = a[i], b[j]
		if x and (not y or (tonumber(x.t) or 0) >= (tonumber(y.t) or 0)) then
			out[#out + 1] = x
			i = i + 1
		else
			out[#out + 1] = y
			j = j + 1
		end
	end
	return out
end
function N.OlvidarAviso(e)
	if type(e) ~= "table" then return end
	local l = e.reciente and recientes() or lista()
	for i = #l, 1, -1 do if l[i] == e then tremove(l, i) end end
	avisarCambio(e.reciente)
end
function N.OlvidarAvisos()
	local d = datos()
	d.perdidos, d.recientes = {}, {}
	avisarCambio()
end

-- Su botón: el que traía el aviso (en esta sesión) o, si no, la página de
-- Alfa de donde salió (por su ícono o su o.pagina).
local MISMO_ICONO = { ["ic-huella"] = "ic-ruta", ["ic-guia"] = "ic-ruta", ["ic-misiones"] = "ic-ruta", ["ic-seguir"] = "ic-ruta",
	["ic-flecha"] = "ic-ruta", ["ic-oro"] = "ic-comercio", ["ic-oficios"] = "ic-comercio", ["ic-raros"] = "ic-mundo",
	["ic-mapa"] = "ic-mundo", ["ic-nivel"] = "ic-hoy", ["ic-reloj"] = "ic-hoy" }
-- 1.3.7: el módulo de Alfa de un aviso (su página, o el dueño de su ícono), o nil.
function N.ModuloDeAviso(e)
	if type(e) ~= "table" then return nil end
	local spec = e.pagina and N.ModuloPorId and N.ModuloPorId(e.pagina)
	if not spec and e.icono then
		local ic = MISMO_ICONO[e.icono] or e.icono
		for _, m in ipairs(N.modulos or {}) do
			if m.icono == ic and m.construir then spec = m break end
		end
	end
	return (spec and spec.id) and spec or nil
end

function N.IrDeAviso(e)
	if type(e) ~= "table" then return nil end
	local ac = acciones[e]
	if ac then return ac end
	local spec = N.ModuloDeAviso(e)
	if not (spec and spec.id) then return nil end
	local nombre = type(spec.nombre) == "string" and spec.nombre or spec.id
	return { texto = format(L["Ver en %s"], nombre), alClic = function() N.Abrir(spec.id) end }
end

-- El contador en el botón de Alfa del minimapa (52).
pintarContador = function()
	local b = rawget(_G, "AlfaMinimapButton")
	if type(b) ~= "table" or not b.CreateTexture or not K then return end
	local n = N.AvisosSinVer()
	if not b.alfaContador then
		if n == 0 then return end
		-- 1.3.7: el globito dice qué es al pasar el ratón y su clic abre «Avisos».
		local c = CreateFrame("Button", nil, b)
		c:SetSize(16, 16)
		c:SetPoint("TOPRIGHT", b, "TOPRIGHT", 4, 4)
		c:SetFrameLevel((b.GetFrameLevel and b:GetFrameLevel() or 1) + 5)
		c.Fondo = K.Plano(c, "peligro", "ARTWORK", 0)
		c.Fondo:SetAllPoints(c)
		c.Texto = K.Texto(c, "pequeno", "texto", "OVERLAY")
		c.Texto:SetPoint("CENTER", c, "CENTER", 0, 0)
		-- Solo su clic izquierdo es suyo: el derecho (el menú de Alfa) y el
		-- arrastre (mover el botón) pasan al botón de Alfa, como si no estuviera.
		-- (SetPassThroughButtons es protegida: se reenvía a mano.)
		if c.RegisterForClicks then c:RegisterForClicks("LeftButtonUp") end
		if c.RegisterForDrag then c:RegisterForDrag("LeftButton") end
		local function alPadre(script, ...)
			local fn = b.GetScript and b:GetScript(script)
			if fn then K.Llamar(fn, b, ...) end
		end
		c:SetScript("OnClick", function(self)
			K.OcultarInfo(self)
			N.VerAvisos()
		end)
		c:SetScript("OnMouseUp", function(self, boton)
			if boton ~= "RightButton" then return end
			K.OcultarInfo(self)
			if self.IsMouseOver and not self:IsMouseOver() then return end
			alPadre("OnClick", "RightButton")
		end)
		c:SetScript("OnDragStart", function(self) K.OcultarInfo(self) alPadre("OnDragStart") end)
		c:SetScript("OnDragStop", function() alPadre("OnDragStop") end)
		c:SetScript("OnEnter", function(self)
			K.MostrarInfo(self, N.TextoSinVer(), L["Clic: ver tus avisos"])
		end)
		c:SetScript("OnLeave", function(self) K.OcultarInfo(self) end)
		b.alfaContador = c
	end
	local c = b.alfaContador
	if n > 0 then
		K.Escribir(c.Texto, n > 9 and "9+" or tostring(n))
		c:SetWidth(n > 9 and 22 or 16)
		c:Show()
	else
		c:Hide()
	end
end
N.PintarContadorPerdidos = pintarContador

-- «3 avisos sin ver» (el globito, la campanita y el botón del minimapa).
function N.TextoSinVer(n)
	n = n or N.AvisosSinVer()
	if n <= 0 then return L["No tienes avisos sin ver"] end
	return N.Plural(n, L["%d aviso sin ver"], L["%d avisos sin ver"])
end

-- La ventana «Avisos» (1.3.7: antes «Lo que me perdí»; la abre la campanita
-- de la ventana de Alfa, el globito del minimapa, el menú y /alfa avisos).
-- Abrirla no marca nada como visto: eso es «Marcar todo como visto» o el
-- botón de cada aviso.
local ventana, ui = nil, {}
local DE_DONDE = { calma = "Mientras tenías la calma", entrada = "Mientras entrabas", lya = "Te lo dijo Lya",
	apagado = "Apagado en el Centro de avisos", callado = "Callado: se repetía mucho" } -- (1.3.9)
-- 1.3.7: los filtros de arriba: «Todos», «Sin ver» y uno por módulo con avisos
-- (los 4 con más), más «Otros» para los que no son de ninguno.
local filtro = "todos"
local FILTROS_MODULO = 4
local function claveFiltro(e)
	local spec = N.ModuloDeAviso(e)
	return spec and spec.id or "otros"
end
function N.FiltroAvisos(v)
	if v ~= nil then filtro = v end
	return filtro
end
local function opcionesFiltro(todos)
	local sinVer, por, orden = 0, {}, {}
	for _, e in ipairs(todos) do
		if not e.visto then sinVer = sinVer + 1 end
		local k = claveFiltro(e)
		if not por[k] then por[k] = 0 orden[#orden + 1] = k end
		por[k] = por[k] + 1
	end
	local opciones = { { valor = "todos", texto = L["Todos"], cuenta = #todos } }
	if sinVer > 0 then opciones[#opciones + 1] = { valor = "sinver", texto = L["Sin ver"], cuenta = sinVer } end
	local mods = {}
	for _, k in ipairs(orden) do if k ~= "otros" then mods[#mods + 1] = k end end
	table.sort(mods, function(a, b) if por[a] ~= por[b] then return por[a] > por[b] end return a < b end)
	local hayOtros = por.otros ~= nil
	for i, k in ipairs(mods) do
		if i > FILTROS_MODULO then hayOtros = true break end
		local spec = N.ModuloPorId and N.ModuloPorId(k)
		opciones[#opciones + 1] = { valor = k, texto = spec and spec.nombre or k, icono = spec and spec.icono or nil, cuenta = por[k] }
	end
	-- «Otros» solo si separa algo (con un solo tipo de aviso no hace falta).
	if hayOtros and #mods > 0 then
		local n = 0
		for _, e in ipairs(todos) do
			local k = claveFiltro(e)
			local listado = false
			for i = 1, math.min(#mods, FILTROS_MODULO) do if mods[i] == k then listado = true end end
			if not listado then n = n + 1 end
		end
		opciones[#opciones + 1] = { valor = "otros", texto = L["Otros"], cuenta = n }
	end
	return opciones, mods
end
local function pasaFiltro(e, mods)
	if filtro == "todos" then return true end
	if filtro == "sinver" then return not e.visto end
	local k = claveFiltro(e)
	if filtro == "otros" then
		for i = 1, math.min(#mods, FILTROS_MODULO) do if mods[i] == k then return false end end
		return true
	end
	return k == filtro
end
local function llenarVentana()
	if not ventana then return end
	local items = {}
	local todos = N.Avisos()
	local opciones, mods = opcionesFiltro(todos)
	local existe = false
	for _, o in ipairs(opciones) do if o.valor == filtro then existe = true end end
	if not existe then filtro = "todos" end
	if ui.filtros then
		ui.filtros:SetOpciones(opciones)
		ui.filtros:SetValor(filtro)
		K.Mostrar(ui.filtros, #opciones > 2 or (#opciones == 2 and opciones[2].valor == "sinver"))
	end
	local lista = {}
	for _, e in ipairs(todos) do if pasaFiltro(e, mods) then lista[#lista + 1] = e end end
	for _, e in ipairs(lista) do
		local ir = N.IrDeAviso(e)
		local nuevo = not e.visto
		local partes = {}
		if (e.hora or "") ~= "" then partes[#partes + 1] = e.hora end
		if nuevo then partes[#partes + 1] = L["no lo viste"] end
		if e.origen and DE_DONDE[e.origen] then partes[#partes + 1] = L[DE_DONDE[e.origen]] end
		local linea = concat(partes, "  \194\183  ")
		local cuerpo = (e.titulo ~= "" and e.texto ~= "") and e.texto or ""
		if cuerpo ~= "" then linea = linea ~= "" and (linea .. "\n" .. cuerpo) or cuerpo end
		items[#items + 1] = {
			icono = e.icono or "ic-aviso",
			titulo = e.titulo ~= "" and e.titulo or e.texto,
			texto = linea,
			tono = nuevo and "aviso" or "neutro",
			elegida = nuevo or nil,
			accion = ir and { texto = ir.texto, alClic = function()
				N.MarcarVisto(e)
				K.Llamar(ir.alClic)
			end } or (nuevo and { texto = L["Visto"], alClic = function() N.MarcarVisto(e) end }) or nil,
			secundaria = { texto = L["Quitar"], alClic = function() N.OlvidarAviso(e) end },
		}
	end
	ui.rejilla:Llenar(items)
	local n = N.AvisosSinVer()
	K.Escribir(ui.resumen.Texto, #todos == 0 and ""
		or (n > 0 and (N.TextoSinVer(n) .. ". " .. L["Lo más nuevo va arriba."]) or L["Ya viste todo. Lo más nuevo va arriba."]))
	K.Mostrar(ui.resumen, #todos > 0)
	if ui.vacio.Set then
		ui.vacio:Set({ lobo = "dormido", titulo = L["Todo tranquilo"],
			texto = L["No hay avisos. Aquí quedan los últimos que te dio Alfa y los que se fueron sin que los vieras."] })
	end
	K.Mostrar(ui.vacio, #todos == 0)
	K.Mostrar(ui.rejilla, #todos > 0)
	if ui.marcar then ui.marcar:SetActivo(n > 0) end
	if ui.borrar then ui.borrar:SetActivo(#todos > 0) end
	local ancho = ventana:AnchoCuerpo()
	local h = ui.pila:Acomodar(ancho)
	ui.pila:ClearAllPoints()
	ui.pila:SetPoint("TOPLEFT", ventana.Cuerpo, "TOPLEFT", ventana.margen, -ventana.margen)
	ventana:SetAltoContenido(h + 2 * ventana.margen)
end
refrescarVentana = function() if ventana and ventana:IsShown() then llenarVentana() end end

local function parrafo(p, color)
	local f = CreateFrame("Frame", nil, p)
	f.Texto = K.Texto(f, "nota", color or "textoTenue")
	f.Texto:SetPoint("TOPLEFT")
	function f:Acomodar(ancho) local h = K.Parrafo(self.Texto, ancho) self:SetHeight(h) return h end
	return f
end

local function armarVentana()
	ventana = K.Ventana({ nombre = "AlfaPerdidos", titulo = L["Avisos"], icono = "ic-aviso", ancho = 540, alto = 500, desplazar = true })
	ventana:SetTitulo(L["Avisos"], L["Lo que Alfa te dijo, con su hora"], "ic-aviso")
	ventana.alAcomodar = llenarVentana
	local p = K.Pila(ventana.Cuerpo, { espacio = K.ESP.base })
	ui.pila = p
	ui.resumen = p:Agregar(parrafo(p, "textoSuave"))
	-- 1.3.7: filtros por tipo y un estado vacío con el lobo dormido.
	ui.filtros = p:Agregar(K.Segmentos(p, { alCambiar = function(v) filtro = v llenarVentana() end }))
	ui.vacio = p:Agregar(K.Vacio(p, {}), { espacio = K.ESP.l })
	ui.rejilla = p:Agregar(K.Rejilla(p, { min = 440, gap = K.ESP.s, variante = "normal" }))
	ui.marcar = K.Boton(ventana, L["Marcar todo como visto"], function() N.MarcarAvisosVistos() end, { tipo = "secundario" })
	ui.borrar = K.Boton(ventana, L["Borrar"], function()
		K.Dialogo({ titulo = L["¿Borrar todos los avisos?"], texto = L["La lista queda vacía. Lo que Alfa te diga después vuelve a aparecer aquí."],
			aceptar = L["Borrar"], peligro = true, alAceptar = function() N.OlvidarAvisos() end })
	end, { tipo = "fantasma" })
	ventana:SetPie({ K.Boton(ventana, L["Cerrar"], function() ventana:Cerrar() end, { tipo = "primario" }) }, { ui.borrar, ui.marcar })
end

function N.VerAvisos()
	if not K then return end
	if not ventana then armarVentana() end
	ventana:Abrir()
	llenarVentana()
	-- 1.3.7: el juego mide mal un texto antes de su primer dibujo (las
	-- pastillas de los filtros salían «Mun…»): se acomoda otra vez al siguiente cuadro.
	if N.Una then N.Una("momentos.avisosOtraVez", 0, function() if refrescarVentana then refrescarVentana() end end) end
	return ventana
end
N.VerPerdidos = N.VerAvisos -- (/alfa perdi y quien lo llamaba así)

-- El renglón del menú de Alfa (motor/Alfa/UI/Options.lua, O.MenuItems).
function N.MenuAvisos()
	local n = N.AvisosSinVer()
	local t = L["Avisos"]
	if n > 0 then t = t .. "  (" .. n .. ")" end
	return { text = t, icon = "ic-aviso", onClick = function() N.VerAvisos() end }
end
N.MenuPerdidos = N.MenuAvisos

-- Lo que sale en pantalla queda en la lista (Kit/Ventanas.lua dispara ALFA_AVISO).
if A and A.On then
	A.On("ALFA_AVISO", function(o) if type(o) == "table" then pcall(N.AvisoReciente, o, o.origen) end end)
end
-- Al entrar, el globito del minimapa con lo que quedó sin ver (el botón se arma al entrar).
if A and A.OnLogin then
	A.OnLogin(function()
		if N.Una then N.Una("nucleo.contadorAvisos", 2, function() pcall(pintarContador) end) else pcall(pintarContador) end
	end)
end

---------------------------------------------------------------------------
-- /alfa calma
---------------------------------------------------------------------------
local function aviso(o)
	if K and K.Aviso then return K.Aviso(o) end
end

local function terminarCalma()
	despertar() -- lo que esperaba la calma sale ya
	local estaba = calmaAvisada
	calmaAvisada = nil
	if not estaba then return end
	local n = N.PerdidosSinVer()
	aviso({ titulo = L["Se acabó la calma"], pedido = true, lya = false, icono = "ic-aviso",
		texto = n > 0 and N.Plural(n, L["Te guardé %d cosa mientras tanto."], L["Te guardé %d cosas mientras tanto."])
			or L["No pasó nada importante mientras tanto."],
		accion = n > 0 and { texto = L["Ver mis avisos"], alClic = N.VerPerdidos } or nil })
end

-- modo: "30" | "60" | "sesion" | "no" -> true
function N.Calma(modo)
	modo = tostring(modo or ""):lower()
	local d = datos()
	if modo == "no" or modo == "off" or modo == "nada" or modo == "fin" then
		calmaSesion = false
		d.calmaHasta = nil
		if N.Quitar then N.Quitar("nucleo.calmaFin") end
		terminarCalma()
		return false
	end
	local seg
	if modo == "sesion" or modo == "sesión" or modo == "session" then
		calmaSesion = true
		d.calmaHasta = nil
	else
		local m = tonumber(modo:match("(%d+)")) or 30
		if modo:find("h") then m = m * 60 end
		m = max(5, min(240, m))
		seg = m * 60
		calmaSesion = false
		d.calmaHasta = reloj() + seg
		if N.Una then N.Una("nucleo.calmaFin", seg + 1, function() if not N.EnCalma() then terminarCalma() end end) end
	end
	calmaAvisada = "si"
	aviso({ titulo = L["No molestar"], pedido = true, lya = false, icono = "ic-aviso", importante = "siempre",
		texto = seg and format(L["Durante %s Alfa no te avisa nada que no sea urgente. Lo que llegue queda en tus avisos (la campanita)."],
				seg < 3600 and format(L["%d min"], floor(seg / 60)) or N.Plural(floor(seg / 3600), L["%d hora"], L["%d horas"]))
			or L["Hasta que salgas del juego Alfa no te avisa nada que no sea urgente. Lo que llegue queda en tus avisos (la campanita)."],
		accion = { texto = L["Quitar la calma"], alClic = function() N.Calma("no") end } })
	if A and A.Fire then pcall(A.Fire, "ALFA_CALMA", true) end
	return true
end

if A and A.RegisterCommand then
	A.RegisterCommand("calma", function(resto)
		local r = type(resto) == "string" and resto:match("^%s*(%S*)") or ""
		if r == "" then
			if N.EnCalma() and not dnd() then N.Calma("no") else N.Calma("30") end
		else
			N.Calma(r)
		end
	end, L["no molestar: /alfa calma 30 | 60 | sesion | no"])
	A.RegisterCommand("perdi", function() N.VerAvisos() end, L["abre tus avisos"])
	A.RegisterCommand("avisos", function() N.VerAvisos() end, L["abre tus avisos (la campanita)"])
end

---------------------------------------------------------------------------
-- El resumen de nivel (17, 18, 34): uno solo, después de la animación del juego.
---------------------------------------------------------------------------
local resumen -- { nivel, desde, mostrado }

function N.ResumenNivelCubre(_que)
	if not resumen then return false end
	if resumen.mostrado then return ahora() - resumen.mostrado < 60 end
	return ahora() - resumen.desde < 60
end

local function irA(tipo)
	local Cerca = rawget(_G, "AlfaCerca")
	if type(Cerca) == "table" and type(Cerca.Ir) == "function" then
		local ok, puesto = pcall(Cerca.Ir, tipo)
		if ok and puesto and N.EmpezarRuta then N.EmpezarRuta() end
		return
	end
	local Nav = A and A.Nav
	local near = type(Nav) == "table" and Nav.nearby
	if type(near) == "table" and type(near.Go) == "function" then
		local ok, puesto = pcall(near.Go, tipo)
		if ok and puesto and N.EmpezarRuta then N.EmpezarRuta() end
	end
end

local function porAprender(lv)
	local Q = A and A.QoL
	local Sp = type(Q) == "table" and Q.Spells
	if type(Sp) ~= "table" or type(Sp.NewAt) ~= "function" or not lv then return 0 end
	local n = 0
	for l = 1, lv do
		local ok, l2 = pcall(Sp.NewAt, l)
		if ok and type(l2) == "table" then n = n + #l2 end
	end
	return n
end

local mostrarResumen
mostrarResumen = function()
	local r = resumen
	if not r or r.mostrado then return end
	-- Los recálculos del nivel primero (las cuentas de abajo los necesitan).
	if N.EnEspera("pesado") > 0 and ahora() - r.desde < 15 then
		-- (sin ocupar el turno de lo que se ve mientras tanto)
		if N.Una then N.Una("nucleo.resumenEspera", 0.5, function() N.AlLibre("nucleo.resumenNivel", mostrarResumen, 2) end) end
		return
	end
	r.mostrado = ahora()
	local lv = r.nivel or num(UnitLevel and UnitLevel("player"))
	if not lv then return end
	local partes, botones = {}, {}
	local B = rawget(_G, "AlfaBuilds")
	if type(B) == "table" and type(B.SiguienteTalento) == "function" and not (A.Get and A.Get("builds.aviso") == false) then
		local ok, s = pcall(B.SiguienteTalento)
		if ok and type(s) == "table" and s.ahora and (tonumber(s.libres) or 0) > 0 then
			partes[#partes + 1] = N.Plural(s.libres, L["%d punto de talento"], L["%d puntos de talento"])
			botones[#botones + 1] = { texto = L["Ver talentos"], alClic = function() if B.Abrir then B.Abrir() end end }
			N.Anotar("talento:" .. lv)
		end
	end
	local n = porAprender(lv)
	if n > 0 then
		partes[#partes + 1] = N.Plural(n, L["%d habilidad por aprender"], L["%d habilidades por aprender"])
		botones[#botones + 1] = { texto = L["Llévame a entrenar"], alClic = function() irA("class") end }
		N.Anotar("entrenador:" .. lv)
	end
	local Mz = rawget(_G, "AlfaMazmorras")
	-- 1.3.7: solo con el Codex ya cargado (cargarlo aquí son ~7 MB en tu primer nivel).
	local X = A and A.Codex
	local okX, codex = false, false
	if type(X) == "table" and type(X.IsLoaded) == "function" then okX, codex = pcall(X.IsLoaded) end
	if okX and codex and type(Mz) == "table" and type(Mz.Recomendada) == "function" then
		local ok, d = pcall(Mz.Recomendada)
		if ok and type(d) == "table" and tonumber(d.min) == lv and not d.hecha and type(d.nombre) == "string" then
			partes[#partes + 1] = format(L["ya puedes ir a %s"], d.nombre)
			botones[#botones + 1] = { texto = L["Ver la mazmorra"], alClic = function() if Mz.Abrir then Mz.Abrir(d.key) end end }
		end
	end
	if #partes == 0 then return end
	while #botones > 2 do tremove(botones) end
	N.UltimoResumenNivel = { nivel = lv, partes = partes }
	aviso({ id = "nivel", titulo = format(L["¡Nivel %d!"], lv), texto = concat(partes, "  \194\183  "), icono = "ic-nivel",
		tono = "exito", prioridad = 2, sonido = "nivel", acciones = botones, duracion = 14, lya = false, alfaTurno = true })
end

if A and A.RegisterEvent then
	A.RegisterEvent("PLAYER_LEVEL_UP", function(_, lv)
		nivel.desde, nivel.visto, nivel.n = ahora(), nil, num(lv)
		if banco() or (A.Get and A.Get("nucleo.resumenNivel") == false) then resumen = nil return end
		resumen = { nivel = nivel.n, desde = ahora() }
		N.AlLibre("nucleo.resumenNivel", mostrarResumen, 2)
	end)
	-- Pantallas de carga
	A.RegisterEvent("LOADING_SCREEN_ENABLED", function() enCarga = true end)
	A.RegisterEvent("LOADING_SCREEN_DISABLED", function()
		enCarga = false
		cargaHasta = ahora() + CALMA_CARGA
		despertar()
	end)
	A.RegisterEvent("PLAYER_ENTERING_WORLD", function()
		enCarga = false
		cargaHasta = max(cargaHasta, ahora() + CALMA_CARGA)
		pnj.abierto = false
		despertar()
	end)
	-- Cinemáticas
	A.RegisterEvent("CINEMATIC_START", function() cine, cineDesde = true, ahora() end)
	A.RegisterEvent("CINEMATIC_STOP", function() cine = false despertar() end)
	A.RegisterEvent("PLAY_MOVIE", function() cine, cineDesde = true, ahora() end)
	A.RegisterEvent("STOP_MOVIE", function() cine = false despertar() end)
	for _, n in ipairs({ "MovieFrame", "CinematicFrame" }) do
		local f = rawget(_G, n)
		if type(f) == "table" and type(f.HookScript) == "function" then
			pcall(f.HookScript, f, "OnHide", function() cine = false despertar() end)
		end
	end
	-- Hablando con un PNJ
	local function abre() if not pnj.abierto then pnj.abierto, pnj.desde = true, ahora() end end
	local function cierra() pnj.abierto = false despertar() end
	for _, ev in ipairs({ "GOSSIP_SHOW", "MERCHANT_SHOW", "QUEST_DETAIL", "QUEST_GREETING", "QUEST_PROGRESS",
		"QUEST_COMPLETE", "TRAINER_SHOW", "TAXIMAP_OPENED" }) do A.RegisterEvent(ev, abre) end
	for _, ev in ipairs({ "GOSSIP_CLOSED", "MERCHANT_CLOSED", "QUEST_FINISHED", "TRAINER_CLOSED", "TAXIMAP_CLOSED" }) do
		A.RegisterEvent(ev, cierra)
	end
	A.RegisterEvent("PLAYER_REGEN_ENABLED", despertar)
	-- /dnd: al quitarlo, lo que se guardó.
	local estabaDnd = false
	A.RegisterEvent("PLAYER_FLAGS_CHANGED", function()
		local d = dnd()
		if d and not estabaDnd then calmaAvisada = calmaAvisada or "dnd" end
		if estabaDnd and not d and not N.EnCalma() then terminarCalma() despertar() end
		estabaDnd = d
	end)
end
if A and A.OnLogin then
	A.OnLogin(function()
		pcall(pintarContador)
		-- La calma por tiempo sigue después de un /reload.
		local h = tonumber(datos().calmaHasta) or 0
		if h > reloj() and N.Una then
			calmaAvisada = "si"
			N.Una("nucleo.calmaFin", h - reloj() + 1, function() if not N.EnCalma() then terminarCalma() end end)
		elseif h > 0 then
			datos().calmaHasta = nil
		end
	end)
end

---------------------------------------------------------------------------
-- 1.3.9 (67): el Centro de avisos. Cada tipo de aviso es la firma de su
-- módulo (Kit/Firmas.lua) con su interruptor (nucleo.avisos.<firma>) y un
-- botón «Probar». Apagado, el aviso no sale (queda en la campanita); lo
-- urgente, lo importante «siempre» y lo que pides tú salen igual.
---------------------------------------------------------------------------
local refrescarCentro -- abajo
local function prioridadAviso(o)
	if o.prioridad ~= nil then return prioridad(o.prioridad) end
	if o.importante == "siempre" then return 1 end
	if o.importante then return 2 end
	if o.detalle then return 4 end
	return 3
end

function N.AvisoApagado(o)
	if type(o) ~= "table" or o.pedido == true or o.importante == "siempre" then return false end
	local f = o.alfaFirma
	if type(f) ~= "string" or not (A and A.Get) then return false end
	if A.Get("nucleo.avisos." .. f) ~= false then return false end
	return prioridadAviso(o) > 1
end

-- El orden del Centro: los módulos, y al final Alfa y sus errores.
local ORDEN_CENTRO = { "ruta", "hoy", "lya", "manada", "mundo", "mazmorras", "combate", "curacion", "bolsas",
	"comercio", "oficios", "pesca", "recoleccion", "talentos", "enciclopedia", "comodidades", "alfa", "errores" }
function N.TiposDeAviso()
	local out, ya = {}, {}
	local F = K and K.FIRMAS or {}
	for _, c in ipairs(ORDEN_CENTRO) do
		if F[c] then out[#out + 1] = c ya[c] = true end
	end
	local resto = {}
	for c in pairs(F) do if not ya[c] then resto[#resto + 1] = c end end
	tsort(resto)
	for _, c in ipairs(resto) do out[#out + 1] = c end
	return out
end

local function nombreFirma(c)
	local f = K and K.FIRMAS and K.FIRMAS[c]
	return f and L[f.nombre] or c
end

-- «Probar»: un aviso de muestra de ese tipo (sale aunque esté apagado).
function N.ProbarAviso(c)
	if not (K and K.Aviso) then return nil end
	local f = K.FIRMAS and K.FIRMAS[c]
	if not f then return nil end
	local apagado = A and A.Get and A.Get("nucleo.avisos." .. c) == false
	local a = K.Aviso({ pedido = true, firma = c, historial = false, agrupar = false, sonido = false, lya = false,
		textura = f.textura, titulo = format(L["Así se ve un aviso de %s"], nombreFirma(c)),
		texto = apagado and L["Ahora está apagado: no te saldrá hasta que lo prendas."]
			or L["Con su color, su ícono y su sonido, para saber de dónde viene sin leerlo."] })
	if K.SonarFirma then K.SonarFirma(c, 2) end
	return a
end

---------------------------------------------------------------------------
-- 1.3.9 (68): lo que se repite mucho en una sesión se calla solo
---------------------------------------------------------------------------
local REPETIR_MAX = 3
N.REPETIR_MAX = REPETIR_MAX
local repetidos = {} -- clave -> { n, callado, titulo }

-- La clave de «lo mismo»: su id o su título (sin números: «Bolsas llenas (3)»
-- y «(4)» son el mismo aviso).
local function claveRepetido(o)
	-- El título y el texto: «Misión lista: El lobo hambriento» y «…: Correo
	-- para Gamon» son avisos distintos; solo los números no cuentan.
	local titulo = type(o.titulo) == "string" and not secreto(o.titulo) and o.titulo or ""
	local texto = type(o.texto) == "string" and not secreto(o.texto) and o.texto or ""
	local t = N.Normalizar(titulo .. " " .. texto)
	t = t and (t:gsub("%d+", "#")) or nil
	-- Con id o clave, también cuenta el texto: «¡Lista! Sigue: X» y «…: Y»
	-- comparten clave pero dicen otra cosa (1.3.9, revisión 1).
	local id = o.id
	if id == nil then id = o.clave end
	if id ~= nil then return "id:" .. tostring(id) .. "|" .. (t or "") end
	if not t then return nil end
	return "t:" .. t
end

function N.Repeticion(o)
	if type(o) ~= "table" or o.repetir == true then return "sale" end
	if A and A.Get and A.Get("nucleo.callarRepetidos") == false then return "sale" end
	local c = claveRepetido(o)
	if not c then return "sale" end
	local r = repetidos[c]
	if not r then
		r = { n = 0 }
		repetidos[c] = r
	end
	r.n = r.n + 1
	if r.callado then return "callado", c end
	if not secreto(o.titulo) and type(o.titulo) == "string" then r.titulo = o.titulo end
	if r.n > REPETIR_MAX then
		r.callado = true
		if refrescarCentro then pcall(refrescarCentro) end
		return "ultima", c
	end
	return "sale", c
end

-- La última vez: el mismo aviso con «Ya te lo dije» y «Seguir avisando».
function N.AvisoCallado(o, c)
	local nuevo = {}
	for k, v in pairs(o) do nuevo[k] = v end
	local nota = format(L["Ya te lo dije %d veces: no lo repito en esta sesión."], REPETIR_MAX)
	local texto = type(o.texto) == "string" and not secreto(o.texto) and o.texto or ""
	nuevo.texto = texto ~= "" and (texto .. "\n" .. nota) or nota
	local botones = {}
	local primero = type(o.accion) == "table" and o.accion or (type(o.acciones) == "table" and o.acciones[1]) or nil
	if primero then botones[1] = primero end
	botones[#botones + 1] = { texto = L["Seguir avisando"], alClic = function() N.Reactivar(c) end }
	nuevo.accion, nuevo.acciones = nil, botones
	nuevo.duracion = nil
	nuevo.alfaCallado = c
	return nuevo
end

function N.Reactivar(c)
	if c ~= nil then repetidos[c] = nil end
	if refrescarCentro then pcall(refrescarCentro) end
end
function N.ReactivarTodos()
	repetidos = {}
	if refrescarCentro then pcall(refrescarCentro) end
end
function N.Callados()
	local n = 0
	for _, r in pairs(repetidos) do if r.callado then n = n + 1 end end
	return n
end

---------------------------------------------------------------------------
-- El Centro de avisos en la página «Estilo y sonido»: un grupo de ajustes
---------------------------------------------------------------------------
local centroBoton
refrescarCentro = function()
	if centroBoton and centroBoton.SetActivo then centroBoton:SetActivo(N.Callados() > 0) end
end

function N.GrupoCentroAvisos(padre)
	if not (K and K.GrupoAjustes) then return nil end
	local g = K.GrupoAjustes(padre, { titulo = L["Centro de avisos"] })
	g:Fila({ titulo = L["Callar lo que se repite"],
		texto = format(L["Un aviso que ya salió %d veces en la sesión se calla solo (queda en la campanita). «Seguir avisando» lo vuelve a prender."], REPETIR_MAX),
		control = function(fila) return K.Interruptor(fila, { clave = "nucleo.callarRepetidos" }) end })
	g:Fila({ titulo = L["Avisos callados"],
		texto = L["Los que se callaron en esta sesión por repetirse."],
		control = function(fila)
			centroBoton = K.Boton(fila, L["Reactivar todos"], function() N.ReactivarTodos() end, { tipo = "secundario" })
			return centroBoton
		end })
	for _, c in ipairs(N.TiposDeAviso()) do
		local f = K.FIRMAS[c]
		g:Fila({ titulo = nombreFirma(c), texto = f.ayuda and L[f.ayuda] or nil,
			control = function(fila)
				local caja = CreateFrame("Frame", nil, fila)
				local sw = K.Interruptor(caja, { clave = "nucleo.avisos." .. c })
				local pb = K.Boton(caja, L["Probar"], function() N.ProbarAviso(c) end, { tipo = "fantasma" })
				sw:ClearAllPoints()
				sw:SetPoint("RIGHT", caja, "RIGHT", 0, 0)
				pb:ClearAllPoints()
				pb:SetPoint("RIGHT", sw, "LEFT", -K.ESP.s, 0)
				caja:SetSize(K.num(pb:GetWidth(), 60) + K.ESP.s + K.num(sw:GetWidth(), 40),
					max(K.num(pb:GetHeight(), 24), K.num(sw:GetHeight(), 24)))
				caja.Interruptor, caja.Probar = sw, pb
				function caja:Leer() sw:Leer() end
				return caja
			end })
	end
	pcall(refrescarCentro)
	return g
end

---------------------------------------------------------------------------
-- Ajustes para la página «Estilo y sonido» (Alfa_Bienvenida): la fila y su búsqueda.
---------------------------------------------------------------------------
local function opcionesSonido()
	return { { valor = "todos", texto = L["Todos"] }, { valor = "importantes", texto = L["Solo los importantes"] },
		{ valor = "ninguno", texto = L["Ninguno [sonidos]"] } }
end

function N.FilasMomentos(grupo)
	if not (grupo and grupo.Fila and K) then return end
	grupo:Fila({ titulo = L["Sonidos de Alfa"],
		texto = L["Cada aviso suena suave según su tipo. Con «Solo los importantes», lo demás sale callado."],
		control = function(fila) return K.Desplegable(fila, { opciones = opcionesSonido(), clave = "nucleo.sonidos", ancho = 180 }) end })
	grupo:Fila({ titulo = L["No molestar"],
		texto = L["Con /alfa calma, Alfa no te avisa nada que no sea urgente por 30 min, 1 h o la sesión. También respeta el /dnd del juego. Lo callado queda en tus avisos (la campanita)."],
		control = function(fila) return K.Boton(fila, L["30 min de calma"], function() N.Calma("30") end, { tipo = "secundario", icono = "ic-aviso" }) end })
end

function N.ControlesMomentos()
	return {
		{ kind = "dropdown", key = "nucleo.sonidos", label = L["Sonidos de Alfa"],
			help = L["Cada aviso suena suave según su tipo. Con «Solo los importantes», lo demás sale callado."],
			choices = function()
				local out = {}
				for i, o in ipairs(opcionesSonido()) do out[i] = { value = o.valor, label = o.texto } end
				return out
			end, search = "sounds, sound, mute, quiet, notifications, sonidos, silencio, alertas" },
		{ kind = "toggle", key = "nucleo.respetarDnd", label = L["Respetar el /dnd del juego"],
			help = L["Con /dnd (no molestar del juego), Alfa también se calla y guarda lo que te diría."],
			search = "dnd, do not disturb, busy, no molestar, calma" },
		{ kind = "button", label = L["No molestar"], button = L["30 min de calma"], icon = "info",
			help = L["Con /alfa calma, Alfa no te avisa nada que no sea urgente por 30 min, 1 h o la sesión. También respeta el /dnd del juego. Lo callado queda en tus avisos (la campanita)."],
			onClick = function() N.Calma("30") end, search = "do not disturb, quiet, calm, silence, no molestar, calma" },
		{ kind = "button", label = L["Avisos"], button = L["Ver"], icon = "info",
			help = L["Lo que Alfa te dijo, con su hora, y lo que se fue sin que lo vieras. También con la campanita de la ventana de Alfa o /alfa avisos."],
			onClick = function() N.VerAvisos() end, search = "missed, history, notifications, perdidos, historial, avisos" },
		-- 1.3.9 (67 y 68): el Centro de avisos, para la búsqueda.
		{ kind = "toggle", key = "nucleo.callarRepetidos", label = L["Callar lo que se repite"],
			help = format(L["Un aviso que ya salió %d veces en la sesión se calla solo (queda en la campanita). «Seguir avisando» lo vuelve a prender."], REPETIR_MAX),
			search = "repeated, spam, notification center, centro de avisos, repetidos, callar" },
		{ kind = "toggle", key = "nucleo.avisos.errores", label = L["Errores de Alfa"],
			help = L["Cuando Alfa atrapa un error suyo, un aviso chico te ofrece reportarlo. Nunca en combate."],
			search = "lua errors, bug report, bugs, errores, reportar, lobo malo, notification center, centro de avisos" },
	}
end
