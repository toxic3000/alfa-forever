-- Alfa - Comodidades (toxic3000 / La Jauría). GPL-3.0.
--
-- Las comodidades de calidad de vida que el motor de Alfa todavía no tiene,
-- hechas con código propio. Lo que el motor ya hace (vender grises, reparar
-- con fondos de la hermandad y sus resúmenes, aceptar resurrecciones fuera
-- de combate, la hermandad como amigos, texto instantáneo...) no se repite:
-- ver LEEME.md.
--
-- Sus ajustes viven en su propia página de la ventana de Alfa, hecha con el
-- Kit (Pagina.lua, en Ajustes > Comodidades). Este archivo guarda lo que
-- comparten las demás partes.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)

M.N, M.A, M.L = N, A, L
local ID = "comodidades"
M.ID = ID

---------------------------------------------------------------------------
-- Ajustes. Las opciones de dentro vienen encendidas: al encender un grupo
-- queda listo para usar. Desde la 1.2.0 vienen encendidas de fábrica las
-- recomendadas, el minimapa mejorado y las barras con el estilo de Alfa
-- (decisión de Toxic); quien ya tenía Alfa conserva lo suyo (la migración de
-- abajo deja anotados los valores de antes).
---------------------------------------------------------------------------
M.AJUSTES = {
	-- Misiones: aceptar y entregar todas (normales, diarias, semanales y completadas)
	misiones = false, misionesNormales = true, misionesDiarias = true, misionesSemanales = true, misionesEntregar = true,
	-- Vuelo: la siguiente parada bajo el temporizador del motor
	vueloParada = true,
	-- Minimapa: cuadrado, sin botones de addons a la vista y sin su menú
	minimapa = true, minimapaCuadrado = true, minimapaBotones = true, minimapaMenu = true,
	-- Colores de clase: tu marco y el del objetivo
	colores = true, coloresJugador = true, coloresObjetivo = true,
	-- Cuadro de información: a quién apunta, rango de hermandad, ocultarlo en combate y verlo con Mayús
	cuadro = true, cuadroObjetivo = true, cuadroRango = true, cuadroCombate = false, cuadroShift = true,
	-- Probador: botones de objetos y control de la animación
	probador = true, probadorBotones = true, probadorAnimacion = true,
	-- Sueltos: la cámara y los sonidos (las voces de error, calladas de fábrica)
	camara = false,
	silenciarErrores = true, silenciarDialogos = false, silenciarMascotas = false, silenciarGestos = false, silenciarLista = false,
	-- Estilo del chat (Chat.lua): "igual" sigue al estilo de Alfa (alfa, clasico, cristal)
	chat = true, chatEstilo = "igual", chatOpacidad = 0.7, chatPestanas = true, chatEscribir = true,
	chatLetra = true, chatBotones = false,
	-- Estilo del minimapa (MinimapaEstilo.lua)
	minimapaEstilo = true, minimapaEstiloTema = "igual", minimapaCabecera = true,
	-- Estilo de las barras (Barras.lua). Los grifos (o dragones) de la barra
	-- principal: "como" | "color" (con el estilo de las barras) | "ocultar"
	-- (con o sin el estilo; desde la 1.2.0 es el único ajuste de los grifos).
	barras = true, barrasEstilo = "igual", barrasBotones = true, barrasGrifos = "como",
	barrasExperiencia = true, barrasMenu = true,
	-- La barra de una forma vacía (Formas.lua): avisar una vez y ofrecer llenarla
	barraForma = true,
}

-- Los valores por omisión, desde el principio (las partes los leen al
-- cargar); la página se registra al final (Pagina.lua).
A.RegisterDefaults(ID, M.AJUSTES)

-- 1.2.0, la mudanza de los ajustes (corre una sola vez por cuenta, N.Migracion):
--   * Quien ya tenía Alfa conserva lo que tenía: lo que hasta la 1.1.9 venía
--     apagado y ahora viene encendido queda anotado como apagado. Una
--     instalación nueva recibe lo nuevo.
--   * "Ocultar los grifos" (grifos) y "Grifos" del estilo de las barras eran
--     dos ajustes para lo mismo: queda uno, barrasGrifos.
M.ANTES_APAGADAS = { "minimapa", "colores", "cuadro", "probador", "silenciarErrores", "barras" }
N.Migracion(1, function(db)
	local s = type(db.settings) == "table" and db.settings or nil
	if not s then return end
	local mio = type(s[ID]) == "table" and s[ID] or {}
	if not (A.IsNewAccount and A.IsNewAccount()) then
		for _, k in ipairs(M.ANTES_APAGADAS) do
			if mio[k] == nil then mio[k] = false end
		end
	end
	if mio.grifos == true and mio.barrasGrifos == nil then mio.barrasGrifos = "ocultar" end
	mio.grifos = nil
	if next(mio) ~= nil then s[ID] = mio end
end)

-- Un ajuste del módulo como verdadero o falso.
function M.Get(clave)
	return N.Get(ID, clave) and true or false
end

-- Una opción de dentro de un grupo: su interruptor principal y ella.
function M.On(principal, opcion)
	if not M.Get(principal) then return false end
	return opcion == nil or M.Get(opcion)
end

---------------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------------

-- fn en su propio pcall: un error se informa y no corta lo demás.
function M.Seguro(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok and geterrorhandler then geterrorhandler()(err) end
	return ok
end

-- Valores secretos (combate, mazmorras): se leen como desconocidos.
function M.Legible(v)
	local C = A.Compat
	if C and C.Readable then return C.Readable(v) end
	if v ~= nil and issecretvalue and issecretvalue(v) then return nil end
	return v
end

function M.Shift()
	local C = A.Compat
	if C and C.IsShiftKeyDown then return C.IsShiftKeyDown() and true or false end
	return IsShiftKeyDown and IsShiftKeyDown() and true or false
end

-- Variables de la consola (CVar): nil si este cliente no la tiene.
function M.LeerCVar(nombre)
	if C_CVar and C_CVar.GetCVar then return C_CVar.GetCVar(nombre) end
	return GetCVar and GetCVar(nombre) or nil
end

function M.PonerCVar(nombre, valor)
	if C_CVar and C_CVar.SetCVar then return pcall(C_CVar.SetCVar, nombre, valor) end
	if SetCVar then return pcall(SetCVar, nombre, valor) end
	return false
end

-- Pone una CVar en `valor` mientras `activo`, guardando el valor que tenía
-- quien juega para devolverlo al apagar la opción (como hace el motor con
-- el texto instantáneo). `alterno`: otro valor por si el cliente no acepta
-- el primero. Fuera de combate. -> false si la CVar no existe.
-- Dos valores de CVar iguales ("2.6" y "2.600000" lo son).
local function igual(a, b)
	if a == nil or b == nil then return a == b end
	local na, nb = tonumber(a), tonumber(b)
	if na and nb then return math.abs(na - nb) < 1e-4 end
	return tostring(a) == tostring(b)
end

function M.ForzarCVar(nombre, valor, activo, alterno)
	if M.LeerCVar(nombre) == nil then return false end
	N.FueraDeCombate(function()
		local actual = M.LeerCVar(nombre)
		if actual == nil then return end
		local d = N.Datos(ID)
		d.previos = type(d.previos) == "table" and d.previos or {}
		if activo then
			if not igual(actual, valor) and not (alterno and igual(actual, alterno)) then
				if d.previos[nombre] == nil then d.previos[nombre] = tostring(actual) end
				M.PonerCVar(nombre, valor)
				if alterno and not igual(M.LeerCVar(nombre), valor) then M.PonerCVar(nombre, alterno) end
			end
		elseif d.previos[nombre] ~= nil then
			M.PonerCVar(nombre, d.previos[nombre])
			d.previos[nombre] = nil
		end
	end)
	return true
end

function M.ExisteCVar(nombre)
	return M.LeerCVar(nombre) ~= nil
end

---------------------------------------------------------------------------
-- Aplicar los ajustes: cada parte se registra con sus claves; su función
-- corre al entrar al juego y cada vez que cambia una de ellas (o se
-- restablece la página).
---------------------------------------------------------------------------
local partes = {}

function M.AlCambiar(claves, fn)
	local set = {}
	for _, k in ipairs(claves) do set[ID .. "." .. k] = true end
	partes[#partes + 1] = { set = set, fn = fn }
	if A.IsLoggedIn and A.IsLoggedIn() then M.Seguro(fn) end
end

A.On("SETTING_CHANGED", function(path)
	if not (A.IsLoggedIn and A.IsLoggedIn()) then return end
	for i = 1, #partes do
		local p = partes[i]
		if path == "" or path == ID or p.set[path] then M.Seguro(p.fn) end
	end
end)

A.OnLogin(function()
	for i = 1, #partes do M.Seguro(partes[i].fn) end
end)

---------------------------------------------------------------------------
-- Abrir su página: /alfa comodidades, o N.Abrir("comodidades") desde otro
-- módulo.
---------------------------------------------------------------------------
function M.AbrirAjustes() N.Abrir(ID) end

A.RegisterCommand("comodidades", function() M.AbrirAjustes() end, L["Abrir las comodidades (minimapa, cuadro de información, probador...)"])
