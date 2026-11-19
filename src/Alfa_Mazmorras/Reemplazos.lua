-- Alfa - Mazmorras: toma el lugar del diario de mazmorras del motor y de su
-- tarjeta de "mazmorra abierta" (toxic3000 / La Jauría). GPL-3.0.
--
-- docs/KIT.md, "Reemplazos":
--   SHOW_DUNGEON   (Dungeons.Open, /alfa dungeons, el botón del centro, el
--                  acceso de Tu guía...) abre esta página en esa mazmorra.
--   DUNGEON_TOAST  la tarjeta que el motor muestra cuando sus misiones se
--                  abren para ti: aquí es un aviso del Kit con «Prepárame». El
--                  motor sigue decidiendo cuándo y cuál (una a la vez); al
--                  cerrarse el aviso se le avisa (pedido.Cerrar) para que pase
--                  el siguiente.
--
-- Contrato para otras áreas (docs/PLAN-1.0.md):
--   AlfaMazmorras.Abrir(key | nil[, pestana])   la página (en una mazmorra)
--   AlfaMazmorras.Recomendada() -> { key, nombre, zona, min, max, modo, recoger, esperan, hecha } | nil
--   AlfaMazmorras.Preparar(key) -> true         recoge lo que puedes tomar y te lleva a la entrada
--   AlfaMazmorras.Frase(key) -> texto           qué hará Prepárame, en palabras

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = N.Textos(M.EN)
local D, P, V = M.D, M.P, M.V

local type, format = type, string.format

---------------------------------------------------------------------------
-- El diario
---------------------------------------------------------------------------
N.Reemplazar("SHOW_DUNGEON", function(pedido)
	local key = pedido and pedido.mazmorra
	if type(key) == "string" then V.AbrirMazmorra(key) else V.Ir("inicio") end
end, function() return V.Visible() end)

---------------------------------------------------------------------------
-- La tarjeta de mazmorra abierta
---------------------------------------------------------------------------
local actual -- { pedido, aviso, turno, cerrado }

local function CT() return A.UI and A.UI.ClassToast end

-- Le dice al motor que el aviso se fue (una sola vez, y solo si sigue siendo el suyo).
local function cerrar(a)
	if not a or a.cerrado then return end
	a.cerrado = true
	if actual == a then actual = nil end
	local ct = CT()
	local p = a.pedido
	if p and p.Cerrar and (not ct or ct.current == p.modelo) then D.Llamar(p.Cerrar) end
end

local function alOcultar(self)
	local a = self.alfaMazmorra
	if a and self.alfaTurno == a.turno then
		self.alfaMazmorra = nil
		cerrar(a)
	end
end

N.Reemplazar("DUNGEON_TOAST", function(p)
	if p.accion == "ocultar" then
		-- El motor lo cerró (otro aviso, un cambio de ajuste): se quita el nuestro.
		local a = actual
		if a and not a.cerrado then
			a.cerrado = true
			actual = nil
			if a.aviso and a.aviso.alfaTurno == a.turno and type(a.aviso.Cerrar) == "function" then a.aviso:Cerrar(a.turno) end
		end
		return
	end
	local m = p.modelo or {}
	local key = m.dungeon
	if type(key) ~= "string" then error("DUNGEON_TOAST sin mazmorra") end
	local d = D.Info(key) or (A.Dungeons and A.Dungeons.Get and D.Llamar(A.Dungeons.Get, key)) or { name = key }
	local e = P.Estado(key)
	local rango = d.minLevel and (d.maxLevel and d.maxLevel ~= d.minLevel and (d.minLevel .. "\226\128\147" .. d.maxLevel) or tostring(d.minLevel))
	local partes = {}
	partes[1] = rango and d.zoneName and format(L["Niveles %s, en %s."], rango, d.zoneName) or nil
	partes[#partes + 1] = P.Frase(e)
	local a = { pedido = p }
	a.aviso = K.Aviso({
		lobo = "atento", tono = "mazmorra", duracion = 14, lya = false,
		titulo = format(L["%s ya es para ti"], d.name or key),
		texto = table.concat(partes, " "),
		accion = { texto = #e.recoger > 0 and L["Prepárame"] or L["Ver la mazmorra"], alClic = function()
			if #e.recoger > 0 then P.Preparar(key) else V.AbrirMazmorra(key) end
		end },
	})
	local f = a.aviso
	if f then
		a.turno = f.alfaTurno
		f.alfaMazmorra = a
		if not f.alfaMazmorraGancho then
			f.alfaMazmorraGancho = true
			f:HookScript("OnHide", alOcultar)
		end
	end
	if actual and actual ~= a then cerrar(actual) end
	actual = a
	-- Por si el aviso cede su lugar a otro sin ocultarse: el motor no se queda esperando.
	if A.After then A.After(40, function() cerrar(a) end) end
end)

---------------------------------------------------------------------------
-- El contrato
---------------------------------------------------------------------------
AlfaMazmorras = {
	Abrir = function(key, pestana)
		if type(key) == "string" then V.AbrirMazmorra(key, pestana) else V.Ir("inicio") end
	end,
	Recomendada = function()
		local d, modo = V.Recomendada()
		if not d then return nil end
		local e = modo ~= "pronto" and P.Estado(d.key) or nil
		return {
			key = d.key, nombre = d.name, zona = d.zoneName, min = d.minLevel, max = d.maxLevel, modo = modo,
			recoger = e and #e.recoger or 0, esperan = e and #e.esperan or 0, hecha = D.Hecha(d.key) ~= nil,
		}
	end,
	Preparar = function(key) return P.Preparar(key) end,
	Frase = function(key) return P.Frase(P.Estado(key)) end,
}
