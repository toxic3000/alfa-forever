-- Alfa - Bienvenida: Dos pantallas deja tu pantalla como estaba (1.4.0).
-- toxic3000 / La Jauría. GPL-3.0.
--
-- El bug de la 1.3.9 (Toxic): después de «Dos pantallas en un clic» y volver,
-- toda la interfaz del juego quedó más grande (barras, chat, Amigos) y la
-- ventana en 1919 × 1079. Lo que pasaba: al devolver la ventana, Alfa ponía
-- primero «maximizada» (gxMaximize = 1) y DESPUÉS le daba un tamaño fijo
-- (C_VideoOptions.SetGameWindowSize con el tamaño leído de la ventana
-- maximizada, 1919 × 1079). Dar un tamaño fijo vuelve la ventana una ventana
-- normal (ya no «ventana a pantalla completa»), y al reiniciar los gráficos
-- el juego recalcula la escala automática de la interfaz para esa ventana:
-- quedó más grande. Además solo guardaba 3 ajustes y nunca revisaba al volver.
--
-- Ahora:
--   * Antes de tocar nada se guarda TODO (Rp.Foto): el modo de la ventana
--     (gxWindow, gxMaximize, gxFullscreenResolution, gxWindowedResolution,
--     gxMonitor), la escala (useUiScale, uiScale), el tamaño real de la
--     ventana y la escala de UIParent. Queda en AlfaNucleoDB.pantallas.antes
--     hasta confirmar que todo volvió (sobrevive a un /reload o a reiniciar).
--   * Al volver (Rp.Restaurar) el tamaño fijo solo se pone si la ventana era
--     una ventana normal, y va ANTES de los ajustes; luego los ajustes en su
--     orden y un solo reinicio de gráficos. Al regresar los gráficos se revisa
--     cada ajuste y la escala (Rp.Verificar); lo que no quedó se arregla una
--     vez más y se dice.
--   * «Reparar mi pantalla» (/alfa pantallas reparar, la página Dos pantallas
--     y el menú de Alfa): con confirmación, deja la ventana y la interfaz como
--     antes de usar Dos pantallas; sin lo de antes guardado (la 1.3.9 no lo
--     guardaba), «ventana a pantalla completa» y escala automática.
--   Nada de esto se hace en combate (espera con N.FueraDeCombate).

local _, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ESP = K.ESP
local Es = M.Escritorio

local type, ipairs, pairs, tonumber, tostring, pcall = type, ipairs, pairs, tonumber, tostring, pcall
local floor, abs = math.floor, math.abs
local format = string.format

local Rp = {}
M.EscritorioReparar = Rp

-- Los ajustes de la ventana y de la escala, en el orden en que se devuelven.
Rp.CVARS = { "gxMonitor", "gxWindow", "gxMaximize", "gxFullscreenResolution", "gxWindowedResolution", "useUiScale", "uiScale" }
local GRAFICOS = { gxMonitor = true, gxWindow = true, gxMaximize = true, gxFullscreenResolution = true, gxWindowedResolution = true }

local function datos() return N.Datos(Es.ID) end
local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end
local function leer(v) if N.Secreto and N.Secreto(v) then return nil end return v end
local function video() local v = rawget(_G, "C_VideoOptions") return type(v) == "table" and v or nil end

local function cvar(n)
	if type(GetCVar) ~= "function" then return nil end
	local ok, v = pcall(GetCVar, n)
	v = ok and leer(v) or nil
	return type(v) == "string" and v or nil
end
-- 1.4.0 (revisión): lo que cambia Alfa (sus SetCVar, un reinicio de gráficos
-- y los segundos que siguen) contra lo que cambia el jugador mientras usa Dos
-- pantallas (Rp.AlCambiarJugador).
local propioHasta = 0
local function reloj() return GetTime and GetTime() or 0 end
function Rp.MarcarPropio(seg)
	local hasta = reloj() + (tonumber(seg) or 20)
	if hasta > propioHasta then propioHasta = hasta end
end
function Rp.EsPropio() return reloj() < propioHasta end
local function ponerCVar(n, v)
	if v == nil or type(SetCVar) ~= "function" then return false end
	Rp.MarcarPropio()
	return (pcall(SetCVar, n, v))
end
Rp.CVar = cvar

local function tamanoVentana()
	local V = video()
	if not (V and type(V.GetCurrentGameWindowSize) == "function") then return nil end
	local ok, s = pcall(V.GetCurrentGameWindowSize)
	s = ok and leer(s) or nil
	if type(s) ~= "table" then return nil end
	local x, y = leer(s.x), leer(s.y)
	if (x == nil or y == nil) and type(s.GetXY) == "function" then
		local ok2, a, b = pcall(s.GetXY, s)
		if ok2 then x, y = leer(a), leer(b) end
	end
	x, y = tonumber(x), tonumber(y)
	if x and y and x > 0 and y > 0 then return floor(x + 0.5), floor(y + 0.5) end
	return nil
end

local function escalaUI()
	local ok, s = pcall(UIParent.GetScale, UIParent)
	s = ok and tonumber(leer(s)) or nil
	return s
end

-- Todo lo que Dos pantallas puede cambiar, ahora mismo.
function Rp.Foto()
	local f = { cvars = {}, cuando = time and time() or 0 }
	for _, n in ipairs(Rp.CVARS) do f.cvars[n] = cvar(n) end
	f.w, f.h = tamanoVentana()
	f.escala = escalaUI()
	-- Qué llenaba la ventana (un mundo achicado por otro addon se respeta).
	if Es.FotoAntes then
		local ok, x = pcall(Es.FotoAntes)
		if ok then f.lleno = { mundo = x.mundo, interfaz = x.interfaz } end
	end
	return f
end

-- Guarda lo de antes (lo que vio Alfa antes de tocar nada). 1.4.0 (revisión):
-- se renueva cada vez que empiezas Dos pantallas, salvo con una vuelta
-- pendiente sin verificar o con la ventana estirada por el «un clic»: entonces
-- lo guardado es lo único que sabe cómo estaba tu pantalla. Así una foto vieja
-- (de una vuelta que no quedó exacta) nunca pisa lo que pusiste después.
function Rp.Pendiente()
	local d = datos()
	return type(d.verificar) == "table" or type(d.auto) == "table"
end
function Rp.Guardar(foto)
	local d = datos()
	if type(d.antes) ~= "table" or not Rp.Pendiente() then d.antes = foto or Rp.Foto() end
	return d.antes
end
function Rp.Antes() local a = datos().antes return type(a) == "table" and a or nil end
function Rp.Olvidar() datos().antes = nil datos().verificar = nil end

local function reiniciar()
	local r = rawget(_G, "RestartGx")
	if type(r) == "function" then Rp.MarcarPropio() pcall(r) return true end
	return false
end

-- ¿Era una ventana normal (con tamaño propio)? Solo entonces se le da tamaño.
local function ventanaNormal(f)
	return f and f.cvars and f.cvars.gxWindow == "1" and f.cvars.gxMaximize == "0" and tonumber(f.w) and tonumber(f.h)
end

-- La escala de la interfaz como estaba (Alfa nunca la cambia; el juego sí al
-- reiniciar los gráficos con otra ventana).
local function devolverEscala(f)
	local e = f and tonumber(f.escala)
	local ahora = escalaUI()
	if e and e > 0 and ahora and abs(ahora - e) > 0.001 then
		pcall(UIParent.SetScale, UIParent, e)
		return true
	end
	return false
end

-- Devuelve la ventana y la escala a la foto f. -> reinició los gráficos
function Rp.Restaurar(f, porque)
	if type(f) ~= "table" or type(f.cvars) ~= "table" then return false end
	if enCombate() then
		N.FueraDeCombate("pantallas.restaurar", function() Rp.Restaurar(f, porque) end)
		return false
	end
	local graficos = false
	-- 1. El tamaño, solo para una ventana normal, y ANTES de los ajustes (dar
	-- un tamaño quita «maximizada»: por eso iba mal en la 1.3.9).
	local V = video()
	if ventanaNormal(f) and V and type(V.SetGameWindowSize) == "function" then
		local w, h = tamanoVentana()
		if w ~= tonumber(f.w) or h ~= tonumber(f.h) then
			Rp.MarcarPropio()
			pcall(V.SetGameWindowSize, tonumber(f.w), tonumber(f.h))
			graficos = true
		end
	end
	-- 2. Cada ajuste, en su orden, solo si cambió.
	for _, n in ipairs(Rp.CVARS) do
		local v = f.cvars[n]
		if v ~= nil and cvar(n) ~= v then
			ponerCVar(n, v)
			if GRAFICOS[n] then graficos = true end
		end
	end
	datos().verificar = { foto = f, intentos = (type(datos().verificar) == "table" and datos().verificar.intentos or 0) }
	if porque then N.Imprimir(porque) end
	-- 3. Un solo reinicio de gráficos; al volver se revisa (Rp.Verificar).
	if graficos and reiniciar() then
		N.Una("pantallas.verificar", 12, function() Rp.Verificar() end)
		return true
	end
	Rp.Verificar()
	return false
end

-- Lo que no quedó como en la foto -> lista de { nombre, antes, ahora }
function Rp.Diferencias(f)
	f = f or Rp.Antes()
	local out = {}
	if type(f) ~= "table" or type(f.cvars) ~= "table" then return out end
	for _, n in ipairs(Rp.CVARS) do
		local v = f.cvars[n]
		if v ~= nil and cvar(n) ~= v then out[#out + 1] = { n, v, cvar(n) or "" } end
	end
	if ventanaNormal(f) then
		local w, h = tamanoVentana()
		if w and (w ~= tonumber(f.w) or h ~= tonumber(f.h)) then out[#out + 1] = { "ventana", f.w .. "x" .. f.h, w .. "x" .. h } end
	end
	local e, ahora = tonumber(f.escala), escalaUI()
	if e and ahora and abs(e - ahora) > 0.001 then out[#out + 1] = { "escala", format("%.3f", e), format("%.3f", ahora) } end
	return out
end

-- Al volver los gráficos: ¿quedó todo? Lo que no, otra vez (una sola vez más).
function Rp.Verificar()
	local v = datos().verificar
	if type(v) ~= "table" or type(v.foto) ~= "table" then return true end
	if enCombate() then
		N.FueraDeCombate("pantallas.verificar", Rp.Verificar)
		return false
	end
	N.Quitar("pantallas.verificar")
	-- La escala se arregla aquí mismo (sin reiniciar nada).
	devolverEscala(v.foto)
	if Es.Aplicado() == nil and Es.Limpiar then Es.Limpiar(v.foto.lleno or { mundo = true, interfaz = true }) end
	local dif = Rp.Diferencias(v.foto)
	if #dif == 0 then
		datos().verificar = nil
		Rp.Olvidar()
		A.Fire("ALFA_ESCRITORIO", "pantallaOk")
		return true
	end
	if (v.intentos or 0) < 1 then
		v.intentos = (v.intentos or 0) + 1
		Rp.Restaurar(v.foto)
		return false
	end
	datos().verificar = nil
	N.Imprimir(L["No pude dejar tu pantalla exactamente como estaba. Prueba «Reparar mi pantalla» (/alfa pantallas reparar) o revisa Esc > Sistema > Gráficos."])
	return false
end
local function alVolverGraficos()
	if type(datos().verificar) == "table" then N.Una("pantallas.verificar", 0.5, Rp.Verificar) end
end
A.RegisterEvent("DISPLAY_SIZE_CHANGED", alVolverGraficos)
A.RegisterEvent("GX_RESTARTED", alVolverGraficos)
A.RegisterEvent("UI_SCALE_CHANGED", alVolverGraficos)
-- 1.4.0 (revisión): lo que cambias tú mientras usas Dos pantallas (la
-- resolución, la escala, el monitor, el tamaño de la ventana) se respeta: pasa
-- a lo de antes, así la vuelta no lo deshace. No cuenta lo que cambia Alfa
-- (Rp.EsPropio) ni, con la ventana estirada por el «un clic», el modo y el
-- tamaño de la ventana (esos los puso Alfa).
local ESTIRA = { gxWindow = true, gxMaximize = true, gxWindowedResolution = true }
function Rp.AlCambiarJugador(que)
	local d = datos()
	local f = d.antes
	if type(f) ~= "table" or type(f.cvars) ~= "table" then return false end
	if Es.Aplicado() == nil and type(d.auto) ~= "table" then return false end
	if Rp.EsPropio() or type(d.verificar) == "table" then return false end
	local estirada = type(d.auto) == "table"
	local cambio = false
	if que == nil or que == "cvars" then
		for _, n in ipairs(Rp.CVARS) do
			local v = cvar(n)
			if v ~= nil and f.cvars[n] ~= nil and v ~= f.cvars[n] and not (estirada and ESTIRA[n]) then
				f.cvars[n] = v
				cambio = true
			end
		end
	end
	if (que == nil or que == "ventana") and not estirada and ventanaNormal(f) then
		local w, h = tamanoVentana()
		if w and h and (w ~= tonumber(f.w) or h ~= tonumber(f.h)) then f.w, f.h, cambio = w, h, true end
	end
	if que == nil or que == "escala" then
		local e = escalaUI()
		if e and tonumber(f.escala) and abs(e - tonumber(f.escala)) > 0.001 then f.escala, cambio = e, true end
	end
	return cambio
end
A.RegisterEvent("CVAR_UPDATE", function(_, nombre)
	nombre = leer(nombre)
	if type(nombre) ~= "string" then return end
	for _, n in ipairs(Rp.CVARS) do
		if n:lower() == nombre:lower() then Rp.AlCambiarJugador("cvars") return end
	end
end)
A.RegisterEvent("DISPLAY_SIZE_CHANGED", function() Rp.AlCambiarJugador("ventana") end)
A.RegisterEvent("UI_SCALE_CHANGED", function() Rp.AlCambiarJugador("escala") end)
-- Un /reload a media revisión: se revisa al entrar.
A.RegisterEvent("PLAYER_ENTERING_WORLD", function()
	if type(datos().verificar) == "table" then N.Una("pantallas.verificar", 2, Rp.Verificar) end
end)

---------------------------------------------------------------------------
-- «Reparar mi pantalla»
---------------------------------------------------------------------------
-- ¿Tiene sentido ofrecerlo? (usaste Dos pantallas alguna vez o hay algo guardado)
function Rp.Ofrecer()
	local d = datos()
	return Rp.Antes() ~= nil or d.elegido == true or d.auto ~= nil or d.autoPreguntado == true or Es.Aplicado() ~= nil
end

-- Lo que hace, sin preguntar (el botón «Sí, reparar»).
function Rp.Reparar()
	if enCombate() then
		N.Imprimir(L["Las pantallas se acomodan fuera de combate."])
		return false
	end
	if Es.Probando() then Es.Rechazar(true) end
	if Es.CerrarVista then Es.CerrarVista() end
	N.Set(Es.ID, "activo", false)
	if Es.Aplicado() then Es.Volver() end
	datos().auto = nil
	local f = Rp.Antes()
	if not f then
		-- Sin lo de antes: «ventana a pantalla completa» y la escala automática.
		f = { cvars = { gxWindow = "1", gxMaximize = "1", useUiScale = "0" } }
	end
	-- El mundo y la interfaz enteros, y la escala de antes.
	if Es.Limpiar then Es.Limpiar({ mundo = true, interfaz = true }) end
	Rp.Restaurar(f, L["Reparando tu pantalla: vuelve como estaba antes de Dos pantallas."])
	return true
end

local cuadro
local function armarCuadro()
	local f = CreateFrame("Frame", "AlfaEscritorioReparar", K.Raiz())
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetFrameLevel(50)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
	f:EnableMouse(true)
	f:SetClampedToScreen(true)
	f.caja = K.Caja(f, { fondo = "panel", borde = "lineaFuerte", corte = K.CORTE.ventana })
	f.Marca = K.Marca(f, K.CORTE.ventana, "acento", 44)
	f.Lobo = f:CreateTexture(nil, "ARTWORK")
	f.Lobo:SetSize(44, 44)
	f.Lobo:SetPoint("TOPLEFT", f, "TOPLEFT", ESP.l, -ESP.l)
	f.Lobo:SetTexture(K.Lobo("atento"))
	K.Pintar(f.Lobo, function(t) t:SetVertexColor(K.Color("acento")) end)
	f.Titulo = K.Texto(f, "titulo", "texto")
	f.Titulo:SetJustifyH("LEFT")
	f.Texto = K.Texto(f, "texto", "textoSuave")
	f.Texto:SetJustifyH("LEFT")
	f.Si = K.Boton(f, L["Sí, reparar"], function() f:Hide() Rp.Reparar() end, { tipo = "primario", icono = "ic-exito" })
	f.No = K.Boton(f, L["Ahora no"], function() f:Hide() end, { tipo = "fantasma" })
	f:Hide()
	return f
end

-- Con confirmación: el cuadro «¿Reparo tu pantalla?».
function Rp.Preguntar()
	if enCombate() then
		N.Imprimir(L["Las pantallas se acomodan fuera de combate."])
		return false
	end
	cuadro = cuadro or armarCuadro()
	local f = cuadro
	local W = 480
	local x = ESP.l + 44 + ESP.base
	local tw = W - x - ESP.l
	K.Escribir(f.Titulo, L["¿Reparo tu pantalla?"])
	f.Titulo:ClearAllPoints()
	f.Titulo:SetPoint("TOPLEFT", f, "TOPLEFT", x, -ESP.l)
	local th = K.Parrafo(f.Titulo, tw, 2)
	K.Escribir(f.Texto, Rp.Antes() and L["Dejo la ventana del juego y el tamaño de la interfaz como estaban antes de usar Dos pantallas. La pantalla parpadea un momento."]
		or L["Pongo el juego en «ventana a pantalla completa» y la interfaz en su tamaño automático, como viene el juego. La pantalla parpadea un momento."])
	f.Texto:ClearAllPoints()
	f.Texto:SetPoint("TOPLEFT", f, "TOPLEFT", x, -(ESP.l + th + ESP.s))
	local y = ESP.l + th + ESP.s + K.Parrafo(f.Texto, tw, 5) + ESP.base
	f.Si:ClearAllPoints()
	f.Si:SetPoint("TOPLEFT", f, "TOPLEFT", x, -y)
	f.No:ClearAllPoints()
	f.No:SetPoint("LEFT", f.Si, "RIGHT", ESP.s, 0)
	f:SetSize(W, y + K.ALTO.boton + ESP.l)
	f:Show()
	return true
end
function Rp.CuadroVisible() return cuadro ~= nil and cuadro:IsShown() end

-- Para el menú de Alfa (motor/Alfa/UI/Options.lua) y la página.
local API = AlfaEscritorio
API.Reparar = function() return Rp.Preguntar() end
API.OfrecerReparar = function() return Rp.Ofrecer() end
