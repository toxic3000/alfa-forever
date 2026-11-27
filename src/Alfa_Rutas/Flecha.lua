-- Alfa - Rutas: el clic derecho en la flecha, todo lo de la flecha a la mano (1.4.2). toxic3000 / La Jauría. GPL-3.0.
--
-- La flecha solo sabía moverse y, en un área, ir al siguiente lugar. Para
-- todo lo demás había que abrir el rastreador o la ventana de Alfa. Ahora su
-- clic derecho abre un menú corto con lo que se pide a la flecha:
--   Otro lugar (si el objetivo está en varios) · Volver a la guía (si va a un
--   lugar elegido a mano) · La misión más cerca · Vuelta a entregar (con 2 o
--   más listas) · Llévame a… · Buscar cerca… · Ver el camino en el mapa ·
--   Devolver la flecha a su lugar · Esconder la flecha (con «Mostrarla» en el aviso).
-- Su globo dice «Clic derecho: más opciones». El gancho va con K.Enganchar
-- (la flecha ya toma el ratón: es lo que se mueve) y nada de esto toca algo
-- protegido.
--
--   Fl.Opciones() -> { { valor = fn, texto, icono }, ... }   lo que trae el menú ahora
--   Fl.Menu()                                             lo abre junto a la flecha

local ADDON, M = ...
local A, L, N, K = M.A, M.L, M.N, M.K
local Fl = {}
M.Flecha = Fl

local type, pairs, pcall = type, pairs, pcall
local format = string.format

local function Nav() return A.Nav end
local function arrow() local n = Nav() return n and n.arrow end
local function marco() return rawget(_G, "AlfaNavArrow") end

local function si(fn, ...)
	if type(fn) ~= "function" then return false end
	local ok, r = pcall(fn, ...)
	return ok and r and true or false
end

local function hayGuia()
	local E = A.Engine
	local ok, g = pcall(function() return E and E.GetGuide and E.GetGuide() end)
	return ok and g ~= nil
end

local function esconder()
	A.Set("nav.arrow", false)
	M.Aviso(L["Flecha escondida"], L["La flecha se escondió. Para verla otra vez, «Mostrarla» aquí o en el menú del botón del minimapa."], {
		icono = "ic-flecha", duracion = 15, acciones = { { texto = L["Mostrarla"], alClic = function() A.Set("nav.arrow", true) end } } })
end

function Fl.Opciones()
	local op = {}
	local Ar, Nv = arrow(), Nav()
	if Ar and si(Ar.HayOtroLugar) then
		op[#op + 1] = { valor = function() if Ar.OtroLugar then Ar.OtroLugar() end end, texto = L["Otro lugar"], icono = "ic-huella" }
	end
	if Nv and si(Nv.IsOverride) and hayGuia() then
		op[#op + 1] = { valor = function() if Nv.BackToGuide then Nv.BackToGuide() end end, texto = L["Volver a la guía"], icono = "ic-guia" }
	end
	if M.IrMision then
		op[#op + 1] = { valor = function() M.IrMision.MasCerca() end, texto = L["La misión más cerca"], icono = "ic-misiones" }
	end
	local Ca = M.ListaAviso
	local listas = 0
	if Ca then for _ in pairs(Ca.Listas()) do listas = listas + 1 end end
	if listas >= 2 and A.Get(M.ID .. ".vueltaEntregar") ~= false then
		op[#op + 1] = { valor = function() M.EntregarListas() end, texto = format(L["Vuelta a entregar (%d)"], listas), icono = "ic-misiones" }
	end
	if M.Viaje and A.Get(M.ID .. ".llevame") ~= false then
		op[#op + 1] = { valor = function() M.Viaje.Abrir() end, texto = L["Llévame a…"], icono = "ic-huella" }
	end
	if M.Cerca then
		op[#op + 1] = { valor = function() M.Cerca.Menu(marco()) end, texto = L["Buscar cerca…"], icono = "ic-cerca" }
	end
	if M.Rastreador and M.Rastreador.VerEnMapa then
		op[#op + 1] = { valor = function() M.Rastreador.VerEnMapa() end, texto = L["Ver el camino en el mapa"], icono = "ic-mapa" }
	end
	op[#op + 1] = { separador = true }
	if Nv and Nv.ResetArrowPosition and A.Get("nav.arrowPos") ~= nil then
		op[#op + 1] = { valor = function() Nv.ResetArrowPosition() end, texto = L["Devolver la flecha a su lugar"], icono = "ic-ventana" }
	end
	op[#op + 1] = { valor = esconder, texto = L["Esconder la flecha"], icono = "ic-cerrar" }
	return op
end

function Fl.Menu()
	local f = marco()
	if not (f and K and K.Menu) then return false end
	K.Menu(f, Fl.Opciones(), nil, function(fn) if type(fn) == "function" then fn() end end, 220)
	return true
end

local enganchada = false
local function enganchar()
	local f = marco()
	if enganchada or not (f and K and K.Enganchar) then return end
	enganchada = true
	K.Enganchar(f, "OnMouseUp", function(_, boton) if boton == "RightButton" then Fl.Menu() end end)
	K.Enganchar(f, "OnEnter", function()
		if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(f) then
			local r, g, b = K.Color("textoSuave")
			GameTooltip:AddLine(L["Clic derecho: más opciones."], r, g, b)
			GameTooltip:Show()
		end
	end)
end
Fl.Enganchar = enganchar

enganchar()
A.OnLogin(enganchar)
