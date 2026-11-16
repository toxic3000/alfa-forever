-- Alfa - Comodidades (Toxic / La Jauría). GPL-3.0.
--
-- Las comodidades de Leatrix Plus que el motor de Alfa todavía no tiene,
-- hechas con código propio (Leatrix no tiene licencia libre: solo se imitan
-- sus funciones). Lo que el motor ya hace (vender grises, reparar con fondos
-- de la hermandad y sus resúmenes, aceptar resurrecciones fuera de combate,
-- la hermandad como amigos, texto instantáneo...) no se repite: ver LEEME.md.
--
-- Sus ajustes viven en la página "Calidad de vida" que ya existe en la
-- ventana de Alfa (Opciones.lua), en sus pestañas o en la pestaña nueva
-- "Interfaz". Este archivo guarda lo que comparten las demás partes.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)

M.N, M.A, M.L = N, A, L
local ID = "comodidades"
M.ID = ID

---------------------------------------------------------------------------
-- Ajustes. Los interruptores principales vienen como quien juega los tiene
-- en Leatrix Plus (apagados: ClassColFrames, MinimapModder, TipModEnable,
-- EnhanceDressup, AutomateQuests, MaxCameraZoom y MuteGameSounds están en
-- Off), y las opciones de dentro como allí (ClassColPlayer, SquareMinimap,
-- TipShowTarget, DressupItemButtons, AutoQuestDaily... en On). Así, al
-- encender un grupo queda igual que en Leatrix.
---------------------------------------------------------------------------
M.AJUSTES = {
	-- Misiones (AutomateQuests y sus AutoQuest*)
	misiones = false, misionesNormales = true, misionesDiarias = true, misionesSemanales = true, misionesEntregar = true,
	-- Vuelo: la siguiente parada bajo el temporizador del motor (FlightBarNextHop)
	vueloParada = true,
	-- Minimapa (MinimapModder: SquareMinimap, HideMiniAddonButtons, HideMiniAddonMenu)
	minimapa = false, minimapaCuadrado = true, minimapaBotones = true, minimapaMenu = true,
	-- Colores de clase (ClassColFrames: ClassColPlayer, ClassColTarget)
	colores = false, coloresJugador = true, coloresObjetivo = true,
	-- Cuadro de información (TipModEnable: TipShowTarget, TipShowRank, TipHideInCombat, TipHideShiftOverride)
	cuadro = false, cuadroObjetivo = true, cuadroRango = true, cuadroCombate = false, cuadroShift = true,
	-- Probador (EnhanceDressup: DressupItemButtons, DressupAnimControl)
	probador = false, probadorBotones = true, probadorAnimacion = true,
	-- Favoritos de Leatrix que no estaban encendidos
	camara = false, grifos = false,
	silenciarErrores = false, silenciarDialogos = false, silenciarMascotas = false, silenciarGestos = false, silenciarLista = false,
}

-- El módulo en el núcleo, sin página propia: sus controles van a la página
-- "Calidad de vida" del motor (Opciones.lua). Con el nombre de esa página,
-- el registro la encuentra (pageOf en UI/Options.lua) y no crea otra; sin
-- subtítulo ni vista propia, no cambia nada de ella.
N.Modulo({ id = ID, nombre = A.L["Quality of Life"], ajustes = M.AJUSTES })

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
-- Abrir sus ajustes: /alfa comodidades, o N.Abrir("comodidades") desde
-- otro módulo. La página es la del motor ("qualityoflife"), en la pestaña
-- Interfaz, que es la de este módulo.
---------------------------------------------------------------------------
function M.AbrirAjustes()
	A.Fire("SHOW_OPTIONS", "qualityoflife")
	local O = A.UI and A.UI.Options
	if O and O.Select then M.Seguro(O.Select, "qualityoflife", L["Interfaz"]) end
end

-- N.Abrir(ID) busca una página con esa clave, que no existe: el motor
-- muestra la primera; aquí se lleva a la nuestra (este manejador corre
-- después del de la ventana, que se registró antes).
A.On("SHOW_OPTIONS", function(section)
	if section ~= ID then return end
	local O = A.UI and A.UI.Options
	if O and O.Select then M.Seguro(O.Select, "qualityoflife", L["Interfaz"]) end
end)

A.RegisterCommand("comodidades", function() M.AbrirAjustes() end, L["Abrir las comodidades (minimapa, cuadro de información, probador...)"])
