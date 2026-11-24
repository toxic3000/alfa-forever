-- Alfa - Bienvenida: la primera vez en cada página (1.3.9). toxic3000 / La Jauría. GPL-3.0.
--
-- Mejoras 35 y 53 de la 1.3.9:
--   * La primera vez que abres una página de Alfa, abajo de la ventana sale
--     una franja con «para qué sirve» (el subtítulo de la página) que se va
--     sola a los 12 s (o con su ×). No tapa nada importante ni atrapa clics
--     fuera de ella; en combate no sale.
--   * «Enséñame» hace un recorrido corto de 3 pasos por esa página: para qué
--     sirve (señala el título), lo principal (señala el cuerpo) y el «?» de
--     Lya. «Saltar» lo termina; nunca se repite solo.
-- Hoy no lleva franja: su recorrido es el de toda la ventana (Recorrido.lua).
-- Ajuste: bienvenida.primeraVez (prendido de fábrica). Las páginas vistas se
-- guardan por cuenta (AlfaNucleoDB.bienvenida.paginasVistas).
--
--   Pv.Mostrar(clave, subtitulo) -> bool   Pv.Enseñar(clave)   Pv.Cerrar()
--   Pv.Visible() -> bool   Pv.Paso() -> 0..3   Pv.Olvidar()  (todas otra vez)

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID
local ESP = K.ESP

local format, type, ipairs, pcall = string.format, type, ipairs, pcall

local Pv = {}
M.PrimeraVez = Pv

A.RegisterDefaults(ID, { primeraVez = true })

local SEGUNDOS = 12
local SIN_FRANJA = { inicio = true }

-- Lo principal de las páginas más usadas (el paso 2 del recorrido); las
-- demás dicen lo de siempre.
local PRINCIPAL = {
	rutas = "Arriba, la guía que sigues y su siguiente paso; abajo, tus misiones y lo que puedes armar con ellas.",
	planes = "Las guías y planes que sigues a la vez. La que sigues ahora es la que marca la flecha.",
	mundo = "El mapa de Alfa: tu ruta, tus marcadores y las capas que quieras ver, con un solo control.",
	bolsas = "Tus bolsas, el banco y lo de tus otros personajes; qué vender cuando se llenan y el candado para lo tuyo.",
	builds = "Qué talento poner ahora, tu plan de talentos y tu equipo.",
	manada = "Tu grupo y los lobos de La Jauría: guaridas, citas, el tablón y quién anda cerca.",
	pesca = "Tu nivel de pescador, dónde pescar y tu diario de capturas.",
	comercio = "Qué conviene vender, subastar o fabricar con cada objeto.",
	enciclopedia = "Busca cualquier objeto, misión, PNJ o lugar, aunque no lo tengas, y «Guíame» te lleva.",
	combate = "Tu medidor, tus recargas y los avisos de pelea, cada uno con su interruptor.",
	curacion = "Tus marcos de curación y qué hace cada clic.",
	mazmorras = "La mazmorra que te toca, sus misiones y cómo llegar a la entrada.",
	lya = "Lo que Lya platica y cuándo; pregúntale lo que sea con «?».",
}
local GENERAL = "Arriba va lo más útil y abajo los detalles. Lo que cambies se guarda solo."

local function datos()
	local d = N.Datos(ID)
	if type(d.paginasVistas) ~= "table" then d.paginasVistas = {} end
	return d
end

local function ventana()
	local O = A.UI and A.UI.Options
	return O and O.frame or rawget(_G, "AlfaOptions")
end

local franja, marco
local estado = { clave = nil, paso = 0, sub = "" }

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

local function armar(win)
	local f = CreateFrame("Frame", nil, win)
	f:SetFrameLevel((win:GetFrameLevel() or 1) + 30)
	f:EnableMouse(true)
	f.caja = K.Caja(f, { fondo = "elevado", borde = "acento", corte = K.CORTE.panel, alfaBorde = 0.6 })
	f.Lobo = f:CreateTexture(nil, "ARTWORK")
	f.Lobo:SetSize(28, 28)
	f.Lobo:SetPoint("LEFT", f, "LEFT", ESP.m, 0)
	f.Sobre = K.Texto(f, "mayus", "acento")
	f.Texto = K.Texto(f, "nota", "texto")
	f.Cerrar = K.BotonIcono(f, "ic-cerrar", function() Pv.Cerrar() end, { tam = 20, ayuda = L["Cerrar"] })
	f.Cerrar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
	f.Ensenar = K.Boton(f, L["Enséñame"], function() Pv.Siguiente() end, { tipo = "secundario", tam = "chico", icono = "ic-huella" })
	f.Saltar = K.Boton(f, L["Saltar"], function() Pv.Cerrar() end, { tipo = "fantasma", tam = "chico" })
	f:SetScript("OnHide", function() if marco then marco:Hide() end end)
	return f
end

-- Acomoda la franja abajo del cuerpo de la ventana, a todo su ancho.
local function acomodar()
	local win = ventana()
	if not (franja and win) then return end
	local ancho = K.num(win.BodyWidth, 600)
	local pad = ESP.m
	local x = pad + 28 + ESP.m
	local derecha = 20 + ESP.s
	local bw = 0
	for _, b in ipairs({ franja.Ensenar, franja.Saltar }) do
		if b:IsShown() then bw = bw + K.num(b:AnchoNatural(), 80) + ESP.s end
	end
	local tw = math.max(120, ancho - x - pad - derecha - bw)
	local y = pad
	if (franja.Sobre:GetText() or "") ~= "" then
		franja.Sobre:ClearAllPoints()
		franja.Sobre:SetPoint("TOPLEFT", franja, "TOPLEFT", x, -y)
		y = y + K.AltoTexto(franja.Sobre) + 2
	end
	franja.Texto:ClearAllPoints()
	franja.Texto:SetPoint("TOPLEFT", franja, "TOPLEFT", x, -y)
	y = y + K.Parrafo(franja.Texto, tw, 4) + pad
	local h = math.max(y, 28 + 2 * pad)
	local bx = -(derecha + pad - 6)
	for _, b in ipairs({ franja.Ensenar, franja.Saltar }) do
		if b:IsShown() then
			b:ClearAllPoints()
			b:SetPoint("RIGHT", franja, "RIGHT", bx, 0)
			bx = bx - K.num(b:AnchoNatural(), 80) - ESP.s
		end
	end
	franja:ClearAllPoints()
	local base = win.Footer or win
	franja:SetPoint("BOTTOMLEFT", base, "TOPLEFT", N.MargenPagina and N.MargenPagina() or 32, ESP.m)
	franja:SetSize(ancho, h)
end

local function pintar()
	local texto, sobre
	local p = estado.paso
	franja.Lobo:SetTexture(K.Lobo(p == 0 and "atento" or "normal"))
	franja.Lobo:SetVertexColor(K.Color("acento"))
	if p == 0 then
		sobre = L["Para qué sirve"]
		texto = estado.sub ~= "" and estado.sub or L[GENERAL]
		franja.Ensenar:SetTexto(L["Enséñame"])
	elseif p == 1 then
		sobre = format(L["Paso %d de %d"], 1, 3)
		texto = format(L["Esta página: %s"], estado.sub ~= "" and estado.sub or L[GENERAL])
		franja.Ensenar:SetTexto(L["Siguiente"])
	elseif p == 2 then
		sobre = format(L["Paso %d de %d"], 2, 3)
		texto = L[PRINCIPAL[estado.clave or ""] or GENERAL]
		franja.Ensenar:SetTexto(L["Siguiente"])
	else
		sobre = format(L["Paso %d de %d"], 3, 3)
		local win0 = ventana()
		local conAyuda = win0 and win0.psLyaHelp and win0.psLyaHelp:IsShown()
		texto = conAyuda and L["¿Dudas? Toca el «?» junto al título y Lya te explica esta página con sus preguntas."]
			or L["¿Dudas? Escribe /alfa ayuda y Lya te explica esta página con sus preguntas."]
		franja.Ensenar:SetTexto(L["Listo"])
	end
	K.Escribir(franja.Sobre, K.Mayus(sobre))
	K.Escribir(franja.Texto, texto)
	franja.Saltar:SetShown(p > 0 and p < 3)
	acomodar()
	local win = ventana()
	-- (una página con pestañas no muestra su título: se señalan las pestañas)
	local titulo = win and ((win.Title and win.Title:IsShown() and (win.Title:GetText() or "") ~= "" and win.Title) or win.TabRow)
	if p == 1 then senalar(titulo)
	elseif p == 2 then senalar(win and (win.Scroll or win.Body))
	elseif p == 3 then senalar(win and win.psLyaHelp)
	elseif marco then marco:Hide() end
end

function Pv.Visible() return franja ~= nil and franja:IsShown() end
function Pv.Paso() return estado.paso end

function Pv.Cerrar()
	if N.Quitar then N.Quitar("bienvenida.primeraVez") end
	estado.paso = 0
	if marco then marco:Hide() end
	if franja then franja:Hide() end
end

-- Por qué no sale en una página (nil: sí sale).
function Pv.PorQueNo(clave)
	if type(clave) ~= "string" or clave == "" then return "sin página" end
	local d = datos()
	if A.Get(ID .. ".primeraVez") == false then return "apagada" end
	if d.paginasVistas[clave] then return "ya vista" end
	if SIN_FRANJA[clave] then return "sin franja" end
	if InCombatLockdown and InCombatLockdown() then return "combate" end
	if M.Pendiente and M.Pendiente() then return "configuración pendiente" end
	if M.Recorrido and M.Recorrido.Activo and M.Recorrido.Activo() then return "recorrido" end
	local win = ventana()
	if not (win and win.IsShown and win:IsShown()) then return "ventana cerrada" end
	return nil
end

-- -> true si la mostró.
function Pv.Mostrar(clave, sub)
	if Pv.PorQueNo(clave) then return false end
	local win = ventana()
	local d = datos()
	d.paginasVistas[clave] = true
	franja = franja or armar(win)
	estado.clave, estado.paso, estado.sub = clave, 0, type(sub) == "string" and sub or ""
	franja:Show()
	pintar()
	-- Se va sola (si el ratón no está encima: la estás leyendo).
	local function vencer()
		if not (franja and franja:IsShown()) or estado.paso > 0 then return end
		if franja.IsMouseOver and franja:IsMouseOver() then
			if N.Una then N.Una("bienvenida.primeraVez", 3, vencer) end
			return
		end
		Pv.Cerrar()
	end
	if N.Una then N.Una("bienvenida.primeraVez", SEGUNDOS, vencer) end
	return true
end

-- «Enséñame» y «Siguiente»: el recorrido corto de 3 pasos.
function Pv.Siguiente()
	if not franja then return end
	if N.Quitar then N.Quitar("bienvenida.primeraVez") end
	if estado.paso >= 3 then Pv.Cerrar() return end
	estado.paso = estado.paso + 1
	pintar()
end

-- Desde fuera (Lya, el banco): el recorrido de una página, ya en el paso 1.
function Pv.Ensenar(clave, sub)
	datos().paginasVistas[clave] = nil
	if not Pv.Mostrar(clave, sub) then return false end
	Pv.Siguiente()
	return true
end

function Pv.Olvidar() datos().paginasVistas = {} end

-- Al elegir una página (motor/Alfa/UI/Options.lua: ALFA_PAGINA clave, pestaña, subtítulo).
A.On("ALFA_PAGINA", function(clave, _, sub)
	if franja and franja:IsShown() and estado.clave ~= clave then Pv.Cerrar() end
	local ok, err = pcall(Pv.Mostrar, clave, sub)
	if not ok and geterrorhandler then geterrorhandler()(err) end
end)
A.RegisterEvent("PLAYER_REGEN_DISABLED", function() if Pv.Visible() then Pv.Cerrar() end end)
K.AlRepintar(function() if Pv.Visible() then pintar() end end)
