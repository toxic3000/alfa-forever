-- Alfa - Bienvenida: el recorrido por la ventana de Alfa (1.2.7).
-- toxic3000 / La Jauría. GPL-3.0.
--
-- La primera vez que abres la ventana de Alfa después de configurarla, Lya
-- te enseña sus partes en 5 pasos: Hoy, las secciones, el buscador, el «?» de
-- cada página y ella misma. Un marco del color de Alfa señala cada parte
-- (sin tapar ni atrapar clics). Lya lo dice con «Siguiente» y «Saltar»; si
-- no está a la vista, un aviso. Se repite con /alfa recorrido o desde la
-- página Estilo y sonido.
--
--   Rc.Empezar()   Rc.Paso()   Rc.Terminar()

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L

local Rc = {}
M.Recorrido = Rc

local function ventana() return rawget(_G, "AlfaOptions") end

local PASOS = {
	{ titulo = "Esta es Hoy", texto = "Lo más útil para este momento, en grande: tu siguiente paso, lo urgente y tu camino a un par de clics.",
		parte = function(w) return w and (w.Scroll or w.Body) end },
	{ titulo = "Todas las secciones", texto = "Aventura, Personaje, Mundo, Oficios, Manada y Ajustes. Cada una tiene sus páginas.",
		parte = function(w) return w and (w.Sidebar or w.Nav) end },
	{ titulo = "El buscador", texto = "Escribe lo que buscas: un ajuste, o algo del juego, y te lo busco en la Enciclopedia.",
		parte = function(w) return w and w.Search end },
	{ titulo = "El «?» de cada página", texto = "Junto al título de cada página. Tócalo y te explico esa página con sus preguntas.",
		parte = function(w) return w and w.psLyaHelp end },
	{ titulo = "Y aquí estoy yo", texto = "Dame clic derecho y elige «¿En qué te ayudo?» cuando quieras. ¡Buena caza, lobo!",
		parte = function() return rawget(_G, "AlfaLyaLoba") end },
}

local marco
local paso = 0

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
	if marco then marco:Hide() end
	N.Datos(M.ID).recorrido = true
end

function Rc.Paso()
	paso = paso + 1
	local p = PASOS[paso]
	if not p then return Rc.Terminar() end
	senalar(p.parte(ventana()))
	local ultimo = paso == #PASOS
	local siguiente = { texto = ultimo and L["Listo"] or L["Siguiente"], fn = function() Rc.Paso() end }
	local saltar = { texto = L["Saltar"], fn = function() Rc.Terminar() end }
	local t = format("%s (%d/%d). %s", L[p.titulo], paso, #PASOS, L[p.texto])
	local Lya = rawget(_G, "AlfaLya")
	if type(Lya) == "table" and Lya.Decir and Lya.Visible and Lya.Visible()
		and Lya.Decir(t, { importante = true, acciones = ultimo and { siguiente } or { siguiente, saltar }, id = "recorrido" .. paso .. ":" .. tostring(time and time() or 0) }) then
		return
	end
	K.Aviso({ titulo = L[p.titulo], texto = format("(%d/%d) %s", paso, #PASOS, L[p.texto]), lobo = "atento", duracion = 30, lya = false,
		accion = { texto = siguiente.texto, alClic = siguiente.fn } })
end

function Rc.Empezar()
	-- Si cierras la ventana a medias, el marco se va (y el recorrido se da por visto).
	local w = ventana()
	if w and w.HookScript and not w.alfaRecorrido then
		w.alfaRecorrido = true
		w:HookScript("OnHide", function() if paso > 0 and paso < #PASOS then Rc.Terminar() end end)
	end
	paso = 0
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
end, L["Lya te enseña la ventana de Alfa en 5 pasos"])
