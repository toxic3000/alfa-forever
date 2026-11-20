-- Alfa - Núcleo: la entrada en silencio (1.3.3). toxic3000 / La Jauría.
-- GPL-3.0.
--
-- Al entrar al juego solo se ve la animación de Alfa (la intro del lobo) y a
-- Lya llegando a su lugar. Lo demás que antes salía solo (avisos, tu sesión
-- anterior, lo nuevo, consejos) no se muestra: se guarda y te espera en Hoy
-- («Mientras entrabas») y con Lya («¿Qué hay de nuevo?").
--
--   N.Entrando() -> bool       verdadero desde que carga Alfa hasta 60 s después
--                              de que termina la intro (sin intro, o en un
--                              /reload, 60 s después de PLAYER_ENTERING_WORLD).
--                              Con bienvenida.alEntrar = "avisos", siempre falso.
--                              Lo que haces a propósito no se calla: un comando
--                              de /alfa o la ventana de Alfa (o una del Kit) abierta.
--   N.GuardarAlEntrar(o)       o = { id, titulo, texto, icono, accion = { texto, alClic }, origen }
--                              (un id repetido reemplaza al anterior) -> el recuerdo
--   N.AlEntrar() -> lista      lo guardado, en orden (el más viejo primero)
--   N.OlvidarAlEntrar(id)      borra uno (sin id: todos)
--   A.Fire("ALFA_ALENTRAR")    cuando cambia la lista, y al terminar la entrada
--   N.EntradaTermina() -> GetTime en que termina (math.huge: esperando la intro)
--
-- K.Aviso (Kit/Ventanas.lua) y N.Imprimir (Nucleo.lua) lo respetan.

local _, N = ...
local A = N.A

local type, ipairs, pcall, tostring = type, ipairs, pcall, tostring
local huge = math.huge

local ESPERA = 60      -- s de silencio después de la intro (o de entrar)
local SIN_FIN = 45     -- s que se espera el fin de la intro antes de contar sin él
local MAX = 30         -- recuerdos guardados como mucho

local limite = huge    -- GetTime hasta el que dura la entrada (huge: aún no termina la intro)
local lista, porId = {}, {}
local pidiendo = 0     -- > 0 mientras corre un comando de /alfa

local function ahora() return GetTime and GetTime() or 0 end

local function modo()
	local v = A and A.Get and A.Get("bienvenida.alEntrar")
	return v == "avisos" and "avisos" or "silencio"
end
N.ModoEntrada = modo

-- La ventana de Alfa o una ventana del Kit abierta (no las piezas de la capa
-- MEDIUM, que acompañan al jugar): el jugador está haciendo algo a propósito.
local function algoAbierto()
	local O = A and A.UI and A.UI.Options
	local f = O and O.frame
	if f and f.IsShown and f:IsShown() then return true end
	local K = N.Kit
	for _, v in ipairs(K and K.VENTANAS or {}) do
		if v:IsShown() then
			local ok, capa = pcall(v.GetFrameStrata, v)
			if not (ok and capa == "MEDIUM") then return true end
		end
	end
	return false
end

-- El banco de pruebas (tools/banco: el único con FIRE_EVENT) entra sin
-- silencio, porque sus escenas prueban los avisos recién entradas; la escena
-- de la entrada lo pide con BANCO_ENTRADA = true.
local function banco() return rawget(_G, "FIRE_EVENT") ~= nil and rawget(_G, "BANCO_ENTRADA") ~= true end

-- Solo el tiempo y el ajuste (sin lo que hace el jugador): para las pruebas.
function N.EntrandoPorTiempo()
	return modo() ~= "avisos" and not banco() and ahora() < limite
end

function N.Entrando()
	if not N.EntrandoPorTiempo() then return false end
	if pidiendo > 0 or algoAbierto() then return false end
	return true
end

function N.EntradaTermina() return limite end

local function avisar() if A and A.Fire then A.Fire("ALFA_ALENTRAR") end end

function N.GuardarAlEntrar(o)
	if type(o) ~= "table" then return nil end
	local id = o.id or o.titulo or o.texto
	if type(id) ~= "string" or id == "" then return nil end
	local e = { id = id, titulo = o.titulo, texto = o.texto, icono = o.icono, accion = o.accion,
		origen = o.origen, t = ahora() }
	if porId[id] then
		for i, x in ipairs(lista) do if x.id == id then table.remove(lista, i) break end end
	end
	lista[#lista + 1] = e
	porId[id] = e
	while #lista > MAX do
		local viejo = table.remove(lista, 1)
		porId[viejo.id] = nil
	end
	avisar()
	return e
end

function N.AlEntrar() return lista end

function N.OlvidarAlEntrar(id)
	if id == nil then
		if #lista == 0 then return end
		lista, porId = {}, {}
		avisar()
		return
	end
	if not porId[id] then return end
	porId[id] = nil
	for i, x in ipairs(lista) do if x.id == id then table.remove(lista, i) break end end
	avisar()
end

-- La entrada termina ESPERA s después de ahora (al terminar la intro, o sin ella).
local function empezarCuenta()
	limite = ahora() + ESPERA
	if N.Una then N.Una("nucleo.entradaFin", ESPERA + 0.5, avisar) end
end
N.EmpezarCuentaEntrada = empezarCuenta

local entro = false

-- Para el banco: como si se volviera a entrar (otra sesión o un /reload).
function N.ReiniciarEntrada()
	entro = false
	limite = huge
end
local function hayIntro(esLogin, esRecarga)
	if esLogin ~= true or esRecarga == true then return false end
	local B = rawget(_G, "AlfaBienvenida")
	if not (type(B) == "table" and type(B.Pendiente) == "function") then return false end
	local ok, pendiente = pcall(B.Pendiente)
	if ok and pendiente == true then return true end
	return not (A and A.Get and A.Get("bienvenida.introSiempre") == false)
end

if A and A.RegisterEvent then
	A.RegisterEvent("PLAYER_ENTERING_WORLD", function(_, esLogin, esRecarga)
		if entro then return end
		entro = true
		if hayIntro(esLogin, esRecarga) then
			-- Hasta que termine la intro (ALFA_INTRO_FIN); si no llega, se cuenta igual.
			limite = huge
			if N.Una then N.Una("nucleo.entrada", SIN_FIN, function() if limite == huge then empezarCuenta() end end) end
		else
			empezarCuenta()
		end
	end)
end
if A and A.On then
	A.On("ALFA_INTRO_FIN", function()
		-- Solo la intro de la entrada (otra intro después no alarga nada).
		if limite == huge or limite > ahora() + ESPERA then empezarCuenta() end
	end)
end

-- Un comando de /alfa es algo que pediste: lo que escriba o avise sale.
if A and type(A.RunCommand) == "function" then
	local run = A.RunCommand
	A.RunCommand = function(...)
		pidiendo = pidiendo + 1
		local ok, err = pcall(run, ...)
		pidiendo = pidiendo - 1
		if not ok and geterrorhandler then geterrorhandler()(err) end
	end
	if SlashCmdList and SlashCmdList.ALFA == run then SlashCmdList.ALFA = A.RunCommand end
end
