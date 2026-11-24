-- Alfa - Bienvenida: «Lo más usado» en Ajustes (1.3.8). toxic3000 / La
-- Jauría. GPL-3.0.
--
-- Alfa recuerda qué ajustes cambias tú (con un clic en una ventana de Alfa:
-- N.PidioJugador; lo que cambia Alfa sola, una migración o un perfil no
-- cuenta) y pone los que más tocas arriba de Ajustes, en la primera página
-- (Estilo y sonido), en una tarjeta: los de prender y apagar se cambian ahí
-- mismo; los demás dicen cómo están y «Cambiar» te lleva a su página.
-- Se guarda por cuenta: N.Datos("bienvenida").usados[clave] = { n, t }.
--
--   Us.Anotar(clave) ; Us.Lista(n) -> { { clave, n, c = control (O.ControlDe) }, ... }
--   Us.Grupo(padre) -> bloque para la página ; Us.Olvidar()

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L

local type, pairs, ipairs, tostring, format, sort = type, pairs, ipairs, tostring, string.format, table.sort

local Us = {}
M.Usados = Us

Us.MAX = 5
local GUARDA = 60

local function datos()
	local d = N.Datos(M.ID)
	if type(d.usados) ~= "table" then d.usados = {} end
	return d.usados
end

local function ahora() return time and time() or 0 end

function Us.Anotar(clave)
	if type(clave) ~= "string" or clave == "" then return end
	local u = datos()
	local x = type(u[clave]) == "table" and u[clave] or { n = 0 }
	x.n, x.t = (x.n or 0) + 1, ahora()
	u[clave] = x
	-- Que no crezca sin fin: se quitan los menos usados.
	local claves = {}
	for k in pairs(u) do claves[#claves + 1] = k end
	if #claves > GUARDA then
		sort(claves, function(a, b) return (u[a].n or 0) < (u[b].n or 0) end)
		for i = 1, #claves - GUARDA do u[claves[i]] = nil end
	end
end

function Us.Olvidar() N.Datos(M.ID).usados = {} end

local function opciones() return A.UI and A.UI.Options end

local USABLE = { toggle = true, dropdown = true, slider = true }

function Us.Lista(n)
	n = n or Us.MAX
	local O = opciones()
	local u = datos()
	local claves = {}
	for k, x in pairs(u) do
		if type(x) == "table" then claves[#claves + 1] = k end
	end
	sort(claves, function(a, b)
		local na, nb = u[a].n or 0, u[b].n or 0
		if na ~= nb then return na > nb end
		local ta, tb = u[a].t or 0, u[b].t or 0
		if ta ~= tb then return ta > tb end
		return a < b
	end)
	local out = {}
	for _, k in ipairs(claves) do
		local c = O and O.ControlDe and O.ControlDe(k)
		if c and USABLE[c.kind] then
			out[#out + 1] = { clave = k, n = u[k].n, c = c }
			if #out >= n then break end
		end
	end
	return out
end

-- Cómo está ahora: «Sí», «Automático», «80 %».
local function valorTexto(c)
	local v = A.Get(c.clave or c.key)
	if c.kind == "toggle" then return v and L["Sí"] or L["No"] end
	if c.kind == "dropdown" then
		for _, ch in ipairs(c.choices or {}) do
			if ch.value == v then return tostring(ch.text) end
		end
		return tostring(v)
	end
	if c.kind == "slider" then
		if type(c.format) == "function" then
			local ok, s = pcall(c.format, v)
			if ok and s then return tostring(s) end
		elseif type(c.format) == "string" and type(v) == "number" then
			local ok, s = pcall(format, c.format, v)
			if ok then return s end
		end
		return tostring(v)
	end
	return tostring(v)
end

---------------------------------------------------------------------------
-- La tarjeta de la página
---------------------------------------------------------------------------
function Us.Grupo(padre)
	local g = K.GrupoAjustes(padre, { titulo = L["Lo más usado"] })
	local filasSi, filasIr = {}, {}
	for i = 1, Us.MAX do
		filasSi[i] = g:Fila({ titulo = "", texto = "",
			control = function(fila)
				return K.Interruptor(fila, {
					-- Solo con una clave de verdad (texto): sin ella, ni se lee ni se guarda.
					get = function() local k = rawget(fila, "alfaClave") return type(k) == "string" and A.Get(k) and true or false end,
					set = function(v) local k = rawget(fila, "alfaClave") if type(k) == "string" then A.Set(k, v and true or false) end end })
			end })
		filasIr[i] = g:Fila({ titulo = "", texto = "",
			control = function(fila)
				return K.Boton(fila, L["Cambiar"], function()
					local O = opciones()
					if O and O.Select and fila.alfaPagina then O.Select(fila.alfaPagina, fila.alfaPestana) end
				end, { tipo = "secundario" })
			end })
	end
	local refrescar = g.Refrescar
	function g:Refrescar()
		local lista = Us.Lista()
		for i = 1, Us.MAX do
			local x = lista[i]
			local si, ir = filasSi[i], filasIr[i]
			K.Mostrar(si, x ~= nil and x.c.kind == "toggle")
			K.Mostrar(ir, x ~= nil and x.c.kind ~= "toggle")
			if x then
				local fila = x.c.kind == "toggle" and si or ir
				fila.alfaClave, fila.alfaPagina, fila.alfaPestana = x.clave, x.c.page, x.c.tab
				fila.alfaDatos.titulo = x.c.label or x.clave
				local donde = format(L["En %s"], tostring(x.c.pageLabel or x.c.page))
				fila.alfaDatos.texto = x.c.kind == "toggle" and donde or (donde .. " \194\183 " .. format(L["ahora: %s"], valorTexto(x.c)))
			else
				si.alfaClave, ir.alfaClave = nil, nil
			end
		end
		K.Mostrar(self, #lista > 0)
		refrescar(self)
	end
	return g
end

-- Lo que cambias tú (un clic en una ventana de Alfa).
A.On("SETTING_CHANGED", function(path)
	if type(path) ~= "string" or path == "" then return end
	if not (N.PidioJugador and N.PidioJugador()) then return end
	Us.Anotar(path)
end)
