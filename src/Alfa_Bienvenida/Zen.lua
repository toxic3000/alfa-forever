-- Alfa - Bienvenida: el modo Zen (1.3.8). toxic3000 / La Jauría. GPL-3.0.
--
-- Un toque (su tecla ALFA_ZEN, Bindings.xml, el menú de Alfa o el botón de
-- Estilo y sonido) esconde todo Alfa menos la flecha, para explorar o tomar
-- capturas; otro toque lo devuelve como estaba. Es el «Esconder Alfa» del
-- motor (A.SetHidden) con «la flecha se queda» (A.SetHideKeepsArrow) puesto
-- solo mientras dura: al salir se deja ese ajuste como lo tenías.
-- Nada protegido: el motor esconde su capa (no es un marco protegido) y los
-- botones seguros de la guía cambian solos fuera de combate. Si vuelves a
-- mostrar Alfa de otra forma (el lobo del minimapa, /alfa), el Zen termina.
-- Sobrevive a un /reload (por personaje: N.DatosPersonaje("bienvenida").zen).
--
--   AlfaZen.Alternar(si) ; AlfaZen.Activo() ; AlfaZen.TextoMenu()

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = M.L

local Z = {}
M.Zen = Z

local function datos() return N.DatosPersonaje(M.ID) end

local function oculto() return A.Hidden and A.Hidden() and true or false end

function Z.Activo()
	local z = datos().zen
	return type(z) == "table" and oculto()
end

local cambiando = false

function Z.Alternar(si)
	if not (A.SetHidden and A.SetHideKeepsArrow) then return false end
	if si == nil then si = not Z.Activo() end
	local d = datos()
	cambiando = true
	if si then
		if not Z.Activo() then
			d.zen = { flecha = A.HideKeepsArrow and A.HideKeepsArrow() or false, oculto = oculto() }
			A.SetHideKeepsArrow(true)
			A.SetHidden(true)
			N.Imprimir(L["Modo Zen: solo queda la flecha. Otro toque de tu tecla (o /alfa zen) devuelve todo."])
		end
	else
		local z = type(d.zen) == "table" and d.zen or {}
		d.zen = nil
		A.SetHidden(z.oculto and true or false)
		A.SetHideKeepsArrow(z.flecha and true or false)
	end
	cambiando = false
	return si
end

function Z.TextoMenu()
	return Z.Activo() and L["Salir del modo Zen"] or L["Modo Zen (solo la flecha)"]
end

-- Alfa se mostró por otro camino: el Zen termina y la flecha vuelve a tu ajuste.
A.On("ALFA_HIDDEN", function(on)
	if cambiando or on then return end
	local d = datos()
	if type(d.zen) == "table" then
		local flecha = d.zen.flecha
		d.zen = nil
		if A.SetHideKeepsArrow then A.SetHideKeepsArrow(flecha and true or false) end
	end
end)

-- Tras un /reload: si ya no está escondido, el Zen se olvida.
A.OnLogin(function()
	local d = datos()
	if type(d.zen) == "table" and not oculto() then
		local flecha = d.zen.flecha
		d.zen = nil
		if A.SetHideKeepsArrow then A.SetHideKeepsArrow(flecha and true or false) end
	end
end)

A.RegisterCommand("zen", function() Z.Alternar() end, L["Modo Zen: todo Alfa fuera menos la flecha (otra vez lo devuelve)"])

BINDING_NAME_ALFA_ZEN = L["Modo Zen: solo la flecha"]

AlfaZen = { Alternar = function(si) return Z.Alternar(si) end, Activo = function() return Z.Activo() end,
	TextoMenu = function() return Z.TextoMenu() end }
