-- Alfa - Kit: «¿Qué es esto?», la ayuda de cada control (1.3.0). toxic3000 /
-- La Jauría. GPL-3.0.
--
-- Con la tecla de ayuda abajo (Alt, por omisión: nucleo.ayudaTecla) o con el
-- modo ayuda prendido (su atajo, ALFA_AYUDA, en Alfa_Nucleo/Bindings.xml),
-- pasar el ratón por un control de Alfa dice para qué sirve.
--   K.Ayuda(marco, titulo, texto)  la ayuda de un control (cadenas, o una
--                                  función que devuelve titulo, texto)
--   K.AyudaActiva() -> bool        si ahora se muestra la ayuda
--   K.ModoAyuda() -> bool          si el modo ayuda está prendido
--   K.AlternarAyuda([on])          prende o apaga el modo ayuda
-- Las filas de ajustes (K.FilaAjuste) dan su título y su descripción a su
-- control; un control con K.ConInfo (las opciones `ayuda` de K.Boton,
-- K.Interruptor, K.BotonIcono...) ya la tiene: en modo ayuda también sale.

local _, N = ...
local K = N.Kit
local A = N.A
local L = K.L

local type = type

if A and A.RegisterDefaults then
	-- "ALT" | "CTRL" | "SHIFT" | "NO" (solo con el modo ayuda)
	A.RegisterDefaults("nucleo", { ayudaTecla = "ALT" })
end

local fija = false
local sobre -- el control con ayuda que está bajo el ratón

local TECLAS = {
	ALT = function() return IsAltKeyDown and IsAltKeyDown() end,
	CTRL = function() return IsControlKeyDown and IsControlKeyDown() end,
	SHIFT = function() return IsShiftKeyDown and IsShiftKeyDown() end,
}

function K.TeclaAyuda()
	local t = A and A.Get and A.Get("nucleo.ayudaTecla")
	return TECLAS[t] and t or (t == "NO" and "NO" or "ALT")
end

function K.AyudaActiva()
	if fija then return true end
	local f = TECLAS[K.TeclaAyuda()]
	return f and f() and true or false
end

function K.ModoAyuda() return fija end

-- El título y el texto de ayuda de un control: los suyos, o los de su
-- cuadro de información.
local function leer(par, marco)
	if not par then return nil, nil end
	local t, x = par[1], par[2]
	if type(t) == "function" then t, x = t(marco) end
	if t == "" then t = nil end
	if x == "" then x = nil end
	return t, x
end

function K.TextoAyuda(marco)
	if not marco then return nil, nil end
	local t, x = leer(rawget(marco, "alfaAyuda"), marco)
	if not x then
		local it, ix = leer(rawget(marco, "alfaInfo"), marco)
		t, x = t or it, ix
	end
	return t, x
end

local function mostrar(marco)
	local ok, t, x = pcall(K.TextoAyuda, marco)
	if not ok or not (t or x) then return false end
	if not x then t, x = L["¿Qué es esto?"], t end
	K.MostrarInfo(marco, t, x)
	return true
end
K.MostrarAyuda = mostrar

function K.Ayuda(marco, titulo, texto)
	if not (marco and marco.HookScript) then return marco end
	marco.alfaAyuda = { titulo, texto }
	if marco.alfaConAyuda then return marco end
	marco.alfaConAyuda = true
	marco:HookScript("OnEnter", function(self)
		sobre = self
		if K.AyudaActiva() then mostrar(self) end
	end)
	marco:HookScript("OnLeave", function(self)
		if sobre == self then sobre = nil end
		K.OcultarInfo(self)
	end)
	return marco
end

-- Un control con K.ConInfo también cuenta como "bajo el ratón" (para la
-- tecla que se pulsa ya encima).
function K.SobreAyuda(marco) sobre = marco end
function K.FueraAyuda(marco) if sobre == marco then sobre = nil end end

local function refrescar()
	local m = sobre
	if not (m and m.IsVisible and m:IsVisible()) then return end
	if K.AyudaActiva() then
		mostrar(m)
	elseif rawget(m, "alfaAyuda") and not rawget(m, "alfaInfo") then
		K.OcultarInfo(m)
	end
end

function K.AlternarAyuda(on)
	if on == nil then on = not fija end
	fija = on and true or false
	if fija then
		K.Aviso({ titulo = L["¿Qué es esto?"], icono = "ic-info", duracion = 5,
			texto = L["Pasa el ratón por cualquier cosa de Alfa y te digo para qué sirve. Pulsa tu tecla otra vez para terminar."] })
	else
		K.OcultarInfo()
	end
	refrescar()
	return fija
end

BINDING_NAME_ALFA_AYUDA = L["«¿Qué es esto?»: la ayuda de Alfa"]

if CreateFrame then
	local f = CreateFrame("Frame")
	if f.RegisterEvent then
		pcall(f.RegisterEvent, f, "MODIFIER_STATE_CHANGED")
		f:SetScript("OnEvent", function() refrescar() end)
	end
end
