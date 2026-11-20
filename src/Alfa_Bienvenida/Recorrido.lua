-- Alfa - Bienvenida: el recorrido por la ventana de Alfa (1.2.7).
-- toxic3000 / La Jauría. GPL-3.0.
--
-- La primera vez que abres la ventana de Alfa después de configurarla, Lya
-- te enseña sus partes paso a paso: Hoy, las secciones, el buscador, el «?» de
-- cada página y ella misma. Un marco del color de Alfa señala cada parte
-- (sin tapar ni atrapar clics). Lya lo dice con «Siguiente» y «Saltar»; si
-- no está a la vista, un aviso. Se repite con /alfa recorrido o desde la
-- página Estilo y sonido.
-- 1.3.1: si no le das «Siguiente» (el globo se va), a los 40 s de un paso se
-- termina solo («alfa.recorrido», N.Una), y cerrar la ventana lo termina en
-- cualquier paso: el marco nunca se queda señalando y el recorrido queda visto.
-- 1.3.6: los pasos se arman al empezar: las secciones que ves en tu modo
-- (Sencillo o Completo), el lobo del minimapa (si está a la vista), la ayuda
-- «¿Qué es esto?» con tu tecla y, al final, Lya (o, sin ella a la vista, cómo
-- preguntarle). En el aviso (sin Lya), cerrarlo con su X es «Saltar».
--
--   Rc.Empezar()   Rc.Paso()   Rc.Terminar()   Rc.Activo() -> bool

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L

local Rc = {}
M.Recorrido = Rc

local function ventana() return rawget(_G, "AlfaOptions") end

-- 1.3.6: las secciones a la vista en tu modo, del motor (O.SECCIONES, O.PagesOf).
local function opciones() return A and A.UI and A.UI.Options end
local function secciones()
	local O = opciones()
	local out = {}
	if O and type(O.SECCIONES) == "table" and O.PagesOf then
		for _, s in ipairs(O.SECCIONES) do
			if s.key ~= "hoy" then
				local ok, pags = pcall(O.PagesOf, s.key)
				if ok and type(pags) == "table" and #pags > 0 then out[#out + 1] = L[s.label] end
			end
		end
		out[#out + 1] = L["Ajustes"]
	end
	if #out <= 1 then return L["Aventura, Personaje, Mundo, Oficios, Manada y Ajustes"] end
	return table.concat(out, ", ")
end

local function lyaVisible()
	local f = rawget(_G, "AlfaLyaLoba")
	if not (f and f.IsShown and f:IsShown()) then return false end
	local Lya = rawget(_G, "AlfaLya")
	if type(Lya) == "table" and Lya.Visible then return Lya.Visible() and true or false end
	return true
end

-- 1.3.6: «¿Qué es esto?» con la tecla que elegiste (nucleo.ayudaTecla, Kit/Ayuda.lua).
local NOMBRE_TECLA = { ALT = "Alt", CTRL = "Ctrl", SHIFT = "Mayús" }
local function textoAyuda()
	local t = K.TeclaAyuda and K.TeclaAyuda() or "ALT"
	if NOMBRE_TECLA[t] then
		return format(L["Deja %s abajo y pasa el ratón por cualquier cosa de Alfa: te digo para qué sirve."], L[NOMBRE_TECLA[t]])
	end
	return L["Prende el «Modo ayuda» con su atajo o en Ajustes > Estilo y sonido, y pasa el ratón por cualquier cosa de Alfa: te digo para qué sirve."]
end

local function minimapa()
	local b = rawget(_G, "AlfaMinimapButton")
	return b and b.IsShown and b:IsShown() and b or nil
end

-- Cada paso: titulo y texto (claves en español, o funciones que dan el texto ya traducido),
-- parte (lo que señala) y si (si va en este recorrido).
local TODOS = {
	{ titulo = "Esta es Hoy", texto = "Lo más útil para este momento, en grande: tu siguiente paso, lo urgente y tu camino a un par de clics.",
		parte = function(w) return w and (w.Scroll or w.Body) end },
	{ titulo = "Todas las secciones",
		texto = function()
			local t = format(L["%s. Cada una tiene sus páginas."], secciones())
			if N.Sencillo and N.Sencillo() then
				t = t .. " " .. L["Estás en Alfa sencillo: en Ajustes > Estilo y sonido puedes ver todo Alfa (modo Completo)."]
			end
			return t
		end,
		parte = function(w) return w and (w.Sidebar or w.Nav) end },
	{ titulo = "El buscador", texto = "Escribe lo que buscas: un ajuste, o algo del juego, y te lo busco en la Enciclopedia.",
		parte = function(w) return w and w.Search end },
	{ titulo = "El «?» de cada página", texto = "Junto al título de cada página. Tócalo y te explico esa página con sus preguntas.",
		parte = function(w) return w and w.psLyaHelp end },
	{ titulo = L["«¿Qué es esto?»"], texto = textoAyuda, parte = function() return nil end },
	{ titulo = L["El lobo del minimapa"], texto = L["Clic: abre Alfa. Clic derecho: el menú de Alfa."],
		parte = minimapa, si = function() return minimapa() ~= nil end },
	{ titulo = function() return lyaVisible() and L["Y aquí estoy yo"] or L["Siempre estoy contigo"] end,
		texto = function()
			if lyaVisible() then return L["Dame clic derecho y elige «¿En qué te ayudo?» cuando quieras. ¡Buena caza, lobo!"] end
			return L["Pregúntame lo que sea con el «?» de cada página o con /alfa ayuda. ¡Buena caza, lobo!"]
		end,
		parte = function() return lyaVisible() and rawget(_G, "AlfaLyaLoba") or nil end },
}
local PASOS = {}

local function armar()
	PASOS = {}
	for _, p in ipairs(TODOS) do
		if not p.si or p.si() then PASOS[#PASOS + 1] = p end
	end
end

local function texto(v)
	if type(v) == "function" then return v() end
	return L[v]
end

local marco
local paso = 0
local ESPERA = 40 -- s que un paso espera su «Siguiente» antes de terminar solo

function Rc.Activo() return paso > 0 end

local function senalar(f)
	if not marco then
		marco = CreateFrame("Frame", nil, K.Raiz and K.Raiz() or UIParent)
		marco:SetFrameStrata("TOOLTIP")
		marco:EnableMouse(false)
		marco.caja = K.Caja(marco, { fondo = false, borde = "acento", corte = K.CORTE.control })
	end
	if not (f and f.IsShown and f:IsShown()) then marco:Hide() return end
	marco:ClearAllPoints()
	marco:SetPoint("TOPLEFT", f, "TOPLEFT", -4, 4)
	marco:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 4, -4)
	marco:Show()
end

function Rc.Terminar()
	paso = 0
	if N.Quitar then N.Quitar("alfa.recorrido") end
	if marco then marco:Hide() end
	N.Datos(M.ID).recorrido = true
end

function Rc.Paso()
	paso = paso + 1
	local p = PASOS[paso]
	if not p then return Rc.Terminar() end
	-- La espera de seguridad, otra vez desde cero en cada paso.
	if N.Una then N.Una("alfa.recorrido", ESPERA, Rc.Terminar) end
	senalar(p.parte(ventana()))
	local ultimo = paso == #PASOS
	local siguiente = { texto = ultimo and L["Listo"] or L["Siguiente"], fn = function() Rc.Paso() end }
	local saltar = { texto = L["Saltar"], fn = function() Rc.Terminar() end }
	local titulo, cuerpo = texto(p.titulo), texto(p.texto)
	local t = format("%s (%d/%d). %s", titulo, paso, #PASOS, cuerpo)
	local Lya = rawget(_G, "AlfaLya")
	if type(Lya) == "table" and Lya.Decir and Lya.Visible and Lya.Visible()
		and Lya.Decir(t, { importante = true, acciones = ultimo and { siguiente } or { siguiente, saltar } }) then
		return
	end
	-- 1.3.6: el aviso no tiene segundo botón (K.Aviso trae una sola acción):
	-- cerrarlo sin «Siguiente» (su X, o que se vaya solo) es «Saltar».
	local miPaso, avanzo = paso, false
	K.Aviso({ titulo = titulo, texto = format("(%d/%d) %s", paso, #PASOS, cuerpo), lobo = "atento", duracion = 30, lya = false,
		accion = { texto = siguiente.texto, alClic = function() avanzo = true siguiente.fn() end },
		alCerrar = function() if not avanzo and paso == miPaso then Rc.Terminar() end end })
end

function Rc.Empezar()
	-- Si cierras la ventana a medias (en cualquier paso), el marco se va y el
	-- recorrido se da por visto.
	local w = ventana()
	if w and w.HookScript and not w.alfaRecorrido then
		w.alfaRecorrido = true
		w:HookScript("OnHide", function() if paso > 0 then Rc.Terminar() end end)
	end
	paso = 0
	armar() -- 1.3.6
	Rc.Paso()
end

-- La primera vez que abres la ventana de Alfa, ya configurada.
local function alAbrir()
	if N.Datos(M.ID).recorrido or (M.Pendiente and M.Pendiente()) then return end
	if InCombatLockdown and InCombatLockdown() then return end
	A.After(0.6, function()
		local w = ventana()
		if paso == 0 and w and w:IsShown() and not N.Datos(M.ID).recorrido then Rc.Empezar() end
	end)
end
if A.On then A.On("SHOW_OPTIONS", alAbrir) end


A.RegisterCommand("recorrido", function()
	if N.Abrir then N.Abrir("inicio") end
	A.After(0.6, Rc.Empezar)
end, L["Lya te enseña la ventana de Alfa paso a paso"]) -- 1.3.6: ya no son 5 pasos fijos
