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
--   N.Sonar(tipo, prioridad)   N.SonidoPermitido(prioridad) -> bool
--   N.YaDicho(voz) -> bool   N.Anotar(voz)   (AlfaNucleo.dichosSesion)
--   N.AnunciosGrandes() -> bool   el ajuste que manda sobre los anuncios grandes
--   N.MomentosActivos() -> bool   falso en el banco de pruebas salvo
--       BANCO_MOMENTOS = true (sus escenas viejas prueban todo al instante)
--
-- Ajustes (nucleo.*): sonidos = "todos" | "importantes" | "ninguno",
-- respetarDnd = true, resumenNivel = true.

local _, N = ...
local A = N.A
local K = N.Kit
local L = K and K.L or N.Textos(N.EN)

local type, pairs, ipairs, pcall, tonumber, tostring, select = type, pairs, ipairs, pcall, tonumber, tostring, select
local min, max, floor, huge, format, unpack = math.min, math.max, math.floor, math.huge, string.format, unpack
local tinsert, tremove, tsort, concat = table.insert, table.remove, table.sort, table.concat

local function ahora() return GetTime and GetTime() or 0 end
local function reloj() return (GetServerTime and GetServerTime()) or (time and time()) or 0 end
local function secreto(v) return issecretvalue ~= nil and v ~= nil and issecretvalue(v) and true or false end
local function num(v) if secreto(v) then return nil end return tonumber(v) end
local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end
local function datos() return N.DatosPersonaje("momentos") end

-- El banco de pruebas (el único con FIRE_EVENT) no espera al juego: sus
-- escenas viejas prueban los avisos al instante. Las de los momentos lo piden.
local function banco() return rawget(_G, "FIRE_EVENT") ~= nil and rawget(_G, "BANCO_MOMENTOS") ~= true end
function N.MomentosActivos() return not banco() end

if A and A.RegisterDefaults then
	A.RegisterDefaults("nucleo", { sonidos = "todos", respetarDnd = true, resumenNivel = true })
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
---------------------------------------------------------------------------
local MAX_PERDIDOS = 30
local acciones = setmetatable({}, { __mode = "k" }) -- entrada -> { texto, alClic }

local function lista()
	local d = datos()
	if type(d.perdidos) ~= "table" then d.perdidos = {} end
	return d.perdidos
end
local pintarContador -- abajo

local function avisarCambio()
	if A and A.Fire then pcall(A.Fire, "ALFA_PERDIDOS") end
	if pintarContador then pcall(pintarContador) end
end

function N.Perdido(o)
	if type(o) ~= "table" then return nil end
	local titulo = type(o.titulo) == "string" and o.titulo or ""
	local texto = type(o.texto) == "string" and o.texto or ""
	if titulo == "" and texto == "" then return nil end
	local l = lista()
	for i = #l, 1, -1 do
		local x = l[i]
		if x.titulo == titulo and x.texto == texto then tremove(l, i) end
	end
	local e = { titulo = titulo, texto = texto, icono = type(o.icono) == "string" and o.icono or nil,
		origen = type(o.origen) == "string" and o.origen or nil, t = reloj(),
		hora = date and date("%H:%M") or "" }
	local ac = o.accion
	if type(ac) == "table" and type(ac.alClic or ac.fn) == "function" and not ac.seguro and type(ac.texto) == "string" then
		acciones[e] = { texto = ac.texto, alClic = ac.alClic or ac.fn }
	end
	tinsert(l, 1, e)
	while #l > MAX_PERDIDOS do tremove(l) end
	avisarCambio()
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
	local visto = tonumber(datos().perdidosVisto) or 0
	local n = 0
	for _, e in ipairs(lista()) do if (tonumber(e.t) or 0) > visto then n = n + 1 end end
	return n
end
function N.MarcarPerdidosVistos()
	datos().perdidosVisto = reloj()
	avisarCambio()
end

-- El contador en el botón de Alfa del minimapa (52).
pintarContador = function()
	local b = rawget(_G, "AlfaMinimapButton")
	if type(b) ~= "table" or not b.CreateTexture or not K then return end
	local n = N.PerdidosSinVer()
	if not b.alfaContador then
		if n == 0 then return end
		local c = CreateFrame("Frame", nil, b)
		c:SetSize(16, 16)
		c:SetPoint("TOPRIGHT", b, "TOPRIGHT", 4, 4)
		c:SetFrameLevel((b.GetFrameLevel and b:GetFrameLevel() or 1) + 5)
		c.Fondo = K.Plano(c, "peligro", "ARTWORK", 0)
		c.Fondo:SetAllPoints(c)
		c.Texto = K.Texto(c, "pequeno", "texto", "OVERLAY")
		c.Texto:SetPoint("CENTER", c, "CENTER", 0, 0)
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

-- La ventana «Lo que me perdí».
local ventana, ui = nil, {}
local function llenarVentana()
	if not ventana then return end
	local items = {}
	for _, e in ipairs(lista()) do
		local ac = acciones[e]
		items[#items + 1] = {
			icono = e.icono or "ic-aviso",
			titulo = e.titulo ~= "" and e.titulo or e.texto,
			texto = (e.titulo ~= "" and e.texto ~= "") and (e.hora .. "  \194\183  " .. e.texto) or e.hora,
			ayuda = e.texto ~= "" and e.texto or nil,
			tono = "aviso",
			alClic = ac and function()
				N.OlvidarPerdido(e)
				K.Llamar(ac.alClic)
				llenarVentana()
			end or nil,
		}
	end
	ui.rejilla:Llenar(items)
	K.Mostrar(ui.vacio, #items == 0)
	K.Mostrar(ui.rejilla, #items > 0)
	local ancho = ventana:AnchoCuerpo()
	local h = ui.pila:Acomodar(ancho)
	ui.pila:ClearAllPoints()
	ui.pila:SetPoint("TOPLEFT", ventana.Cuerpo, "TOPLEFT", ventana.margen, -ventana.margen)
	ventana:SetAltoContenido(h + 2 * ventana.margen)
end

local function armarVentana()
	ventana = K.Ventana({ nombre = "AlfaPerdidos", titulo = L["Lo que me perdí"], icono = "ic-aviso", ancho = 520, alto = 460,
		desplazar = true, alAbrir = function() N.MarcarPerdidosVistos() end })
	ventana:SetTitulo(L["Lo que me perdí"], L["Lo que Alfa te dijo mientras no veías"], "ic-aviso")
	ventana.alAcomodar = llenarVentana
	local p = K.Pila(ventana.Cuerpo, { espacio = K.ESP.base })
	ui.pila = p
	local vacio = CreateFrame("Frame", nil, p)
	vacio.Texto = K.Texto(vacio, "nota", "textoTenue")
	vacio.Texto:SetPoint("TOPLEFT")
	K.Escribir(vacio.Texto, L["No te perdiste nada. Aquí quedan los avisos que se fueron sin que los vieras."])
	function vacio:Acomodar(ancho) local h = K.Parrafo(self.Texto, ancho) self:SetHeight(h) return h end
	ui.vacio = p:Agregar(vacio)
	ui.rejilla = p:Agregar(K.Rejilla(p, { min = 420, variante = "compacta" }))
	ventana:SetPie({ K.Boton(ventana, L["Cerrar"], function() ventana:Cerrar() end, { tipo = "primario" }) },
		{ K.Boton(ventana, L["Borrar todo"], function() N.OlvidarPerdidos() llenarVentana() end, { tipo = "fantasma" }) })
end

function N.VerPerdidos()
	if not K then return end
	if not ventana then armarVentana() end
	ventana:Abrir()
	N.MarcarPerdidosVistos()
	llenarVentana()
end

-- El renglón del menú de Alfa (motor/Alfa/UI/Options.lua, O.MenuItems).
function N.MenuPerdidos()
	local n = N.PerdidosSinVer()
	local t = L["Lo que me perdí"]
	if n > 0 then t = t .. "  (" .. n .. ")" end
	return { text = t, icon = "ic-aviso", onClick = function() N.VerPerdidos() end }
end

if A and A.On then
	A.On("ALFA_PERDIDOS", function() if ventana and ventana:IsShown() then llenarVentana() end end)
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
		accion = n > 0 and { texto = L["Ver lo que me perdí"], alClic = N.VerPerdidos } or nil })
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
		texto = seg and format(L["Durante %s Alfa no te avisa nada que no sea urgente. Lo que llegue queda en «Lo que me perdí»."],
				seg < 3600 and format(L["%d min"], floor(seg / 60)) or N.Plural(floor(seg / 3600), L["%d hora"], L["%d horas"]))
			or L["Hasta que salgas del juego Alfa no te avisa nada que no sea urgente. Lo que llegue queda en «Lo que me perdí»."],
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
	A.RegisterCommand("perdi", function() N.VerPerdidos() end, L["abre «Lo que me perdí»"])
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
		texto = L["Con /alfa calma, Alfa no te avisa nada que no sea urgente por 30 min, 1 h o la sesión. También respeta el /dnd del juego. Lo callado queda en «Lo que me perdí»."],
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
			help = L["Con /alfa calma, Alfa no te avisa nada que no sea urgente por 30 min, 1 h o la sesión. También respeta el /dnd del juego. Lo callado queda en «Lo que me perdí»."],
			onClick = function() N.Calma("30") end, search = "do not disturb, quiet, calm, silence, no molestar, calma" },
		{ kind = "button", label = L["Lo que me perdí"], button = L["Ver"], icon = "info",
			help = L["Los avisos que se fueron sin que los vieras, con su hora. También con /alfa perdi."],
			onClick = function() N.VerPerdidos() end, search = "missed, history, notifications, perdidos, historial, avisos" },
	}
end
