-- Alfa - La Jauría: los raros con reloj (1.2.8). toxic3000 / La Jauría.
-- GPL-3.0.
--
-- Cuando ves muerto a un raro (el motor lo anota en su historial: entry.dead,
-- RARES_HISTORY), Alfa recuerda cuándo lo cazaron. Un raro vuelve, a ojo, en
-- VUELVE_MIN a VUELVE_MAX segundos (no hay datos de cada uno): su cuadro, la
-- página y Lya dicen «Lo cazaron hace 25 min» y, pasada la media hora, «pudo
-- volver ya». Una vez por raro, si anda en tu zona, Lya avisa cuando pudo
-- volver, con «Ir de caza». Visto vivo otra vez (por ti o por la manada, 1V),
-- se olvida.
--
-- Mensaje (Red.lua, prefijo AlfaManada, solo entre quienes comparten):
--   1T|<mapa>|<x>|<y>|<hace>|<nombre>   un raro cazado (x, y en 0-100; hace:
--                                        segundos desde que cayó, sin relojes)
-- Uno por raro cada CADA. Se guarda en N.Datos("manada").cazados y se olvida
-- a las OLVIDA horas. Ajuste manada.rarosReloj.
--
--   Rl.Anotar(nombre, map, x, y, muerto, por)   un raro cazado
--   Rl.De(nombre) -> { nombre, map, x, y, muerto, por } | nil
--   Rl.Texto(nombre) -> "Lo cazaron hace 25 min", "pudo volver ya" | nil
--   Rl.Lista() -> { cazado }                    los de tu zona primero, el más nuevo arriba

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local U, L, ID = M.U, M.L, M.ID

local Rl = {}
M.Reloj = Rl

local type, tonumber, tostring, pairs, ipairs, pcall, format = type, tonumber, tostring, pairs, ipairs, pcall, string.format
local floor, sort = math.floor, table.sort

local V = "1"
local VUELVE_MIN, VUELVE_MAX = 1800, 3600
local OLVIDA = 6 * 3600
local CADA = 300
local TOPE = 40

Rl.VUELVE_MIN, Rl.VUELVE_MAX = VUELVE_MIN, VUELVE_MAX

local function on(clave) return N.Get(ID, clave) and true or false end
local function activo() return N.Get(ID, "rarosReloj") ~= false end

Rl.version = 0
local function cambio()
	Rl.version = Rl.version + 1
	if M.Avisar then M.Avisar() end
end

local function datos()
	local d = N.Datos(ID)
	if type(d.cazados) ~= "table" then d.cazados = {} end
	return d.cazados
end

local function limpiar(s)
	if type(s) ~= "string" or U.Secreto(s) then return nil end
	s = s:gsub("[|\n\r]", ""):sub(1, 48)
	return s ~= "" and s or nil
end

local function llave(nombre) return U.Plegar(nombre or "") end

local function caducar()
	local c, t = datos(), U.Reloj()
	local n = 0
	for k, x in pairs(c) do
		if type(x) ~= "table" or not tonumber(x.muerto) or t - x.muerto > OLVIDA then c[k] = nil else n = n + 1 end
	end
	-- Demasiados: se van los más viejos.
	while n > TOPE do
		local viejo, cuando
		for k, x in pairs(c) do if not cuando or x.muerto < cuando then viejo, cuando = k, x.muerto end end
		c[viejo] = nil
		n = n - 1
	end
end

function Rl.De(nombre)
	if not activo() then return nil end
	local x = datos()[llave(nombre)]
	if not x or U.Reloj() - x.muerto > OLVIDA then return nil end
	return x
end

-- "Lo cazaron hace 25 min" y, si ya pasó la media hora, "pudo volver ya".
function Rl.Texto(nombre)
	local x = Rl.De(nombre)
	if not x then return nil end
	local edad = math.max(0, U.Reloj() - x.muerto)
	local t = format(L["Lo cazaron %s"], U.Hace(edad) or "")
	if edad >= VUELVE_MIN then return t, L["pudo volver ya"] end
	return t, nil
end

local enviados = {}
local function compartir(x)
	if not (on("compartir") and on("rarosManada")) then return end
	local k = llave(x.nombre)
	local t = U.Ahora()
	if enviados[k] and t - enviados[k] < CADA then return end
	if not (x.map and x.x and x.y) then return end
	local hace = math.max(0, floor(U.Reloj() - x.muerto))
	if M.Red.Enviar("T:" .. k, format("%sT|%d|%.2f|%.2f|%d|%s", V, x.map, x.x, x.y, hace, x.nombre)) then enviados[k] = t end
end

-- Un raro cazado. `muerto`: segundos del servidor; `por`: quién lo dijo (nil: tú).
function Rl.Anotar(nombre, map, x, y, muerto, por)
	nombre = limpiar(nombre)
	muerto = tonumber(muerto)
	if not (nombre and muerto) or not activo() then return nil end
	local c = datos()
	local k = llave(nombre)
	local e = c[k]
	if e then
		-- La misma cacería (su cuerpo visto otra vez, o la manada lo dice):
		-- vale la hora más temprana. Una más vieja que la que sabías, nada.
		if math.abs(muerto - e.muerto) < 600 then
			if muerto < e.muerto then e.muerto = muerto cambio() end
			return e
		end
		if muerto < e.muerto then return e end
	end
	e = { nombre = nombre, map = tonumber(map), x = tonumber(x), y = tonumber(y), muerto = muerto, por = por }
	c[k] = e
	caducar()
	if not por then
		compartir(e)
		-- 1.2.9: tu semana y el logro de la manada (Logros.lua).
		if M.Logros and M.Logros.Raro then pcall(M.Logros.Raro, nombre) end
	end
	cambio()
	return e
end

-- Visto vivo: ya volvió.
function Rl.Vivo(nombre)
	local c = datos()
	local k = llave(nombre)
	if c[k] then c[k] = nil cambio() end
end

function Rl.Lista()
	caducar()
	if not activo() then return {} end
	local zona = U.ZonaDe((U.MiPosicion()))
	local out = {}
	for _, x in pairs(datos()) do
		x.aqui = zona ~= nil and x.map ~= nil and U.ZonaDe(x.map) == zona
		out[#out + 1] = x
	end
	sort(out, function(a, b)
		if a.aqui ~= b.aqui then return a.aqui end
		if a.muerto ~= b.muerto then return a.muerto > b.muerto end
		return a.nombre < b.nombre
	end)
	return out
end

-- La flecha al lugar donde cayó.
function Rl.Ir(x)
	local Nav = A.Nav
	if x and x.map and x.x and Nav and Nav.SetTarget then
		Nav.SetTarget(x.map, x.x, x.y, x.nombre)
		N.EmpezarRuta()
		return true
	end
	return false
end

---------------------------------------------------------------------------
-- Del historial de raros del motor
---------------------------------------------------------------------------

local function alHistorial(key)
	if not activo() or type(key) ~= "string" then return end
	local Ra = A.Rares
	if not (Ra and Ra.History) then return end
	local ok, h = pcall(Ra.History)
	local e = ok and type(h) == "table" and h[key]
	if type(e) ~= "table" or e.kind == "treasure" then return end
	local nombre = limpiar(e.name)
	if not nombre then return end
	local muerto, visto = tonumber(e.dead), tonumber(e.t)
	if muerto and visto and visto - muerto <= 10 then
		Rl.Anotar(nombre, e.map, e.x, e.y, muerto)
	elseif visto and Rl.De(nombre) and visto > Rl.De(nombre).muerto + 60 then
		-- Lo volvieron a ver (y no muerto): ya volvió.
		Rl.Vivo(nombre)
	end
end
Rl.AlHistorial = alHistorial
if A.On then A.On("RARES_HISTORY", function(key) pcall(alHistorial, key) end) end

-- La manada lo vio vivo (1V, Guaridas.lua): ya volvió.
if A.On then
	A.On("RARE_SPOTTED", function(a)
		if type(a) == "table" and a.kind == "rare" and a.source ~= "sample" and not a.dead then
			local n = limpiar(a.name)
			if n then Rl.Vivo(n) end
		end
	end)
end

local function numero(s, max)
	if type(s) ~= "string" or not s:match("^%d+%.?%d*$") or #s > 10 then return nil end
	local n = tonumber(s)
	if not n or n > max then return nil end
	return n
end

M.Red.Oyentes.T = function(clave, remitente, _, f)
	if not (activo() and on("rarosManada")) then return end
	local map, x, y, hace = numero(f[1], 100000), numero(f[2], 100), numero(f[3], 100), numero(f[4], OLVIDA)
	local nombre = limpiar(f[5])
	if not (map and x and y and hace and nombre) then return end
	Rl.Anotar(nombre, floor(map), x, y, U.Reloj() - hace, U.Mostrar(remitente))
end

---------------------------------------------------------------------------
-- En el cuadro del raro y el aviso «pudo volver ya»
---------------------------------------------------------------------------

function Rl.AlCuadro(tooltip, unit)
	if not activo() or type(unit) ~= "string" or not (tooltip and tooltip.AddLine) then return end
	if not (UnitExists and UnitName and UnitClassification) then return end
	local okP, j = pcall(UnitIsPlayer, unit)
	if okP and U.Leer(j) then return end
	local okC, c = pcall(UnitClassification, unit)
	c = okC and U.Leer(c) or nil
	if c ~= "rare" and c ~= "rareelite" then return end
	local okN, n = pcall(UnitName, unit)
	n = okN and limpiar(n) or nil
	if not n then return end
	local t, volver = Rl.Texto(n)
	if t then tooltip:AddLine(volver and (t .. " \194\183 " .. volver) or t, 0.55, 0.88, 0.31) end
end

local H = A.Hooks
if type(H) == "table" and type(H.UnitLines) == "function" then
	H.UnitLines(ADDON .. ":reloj", function(tooltip, unit) pcall(Rl.AlCuadro, tooltip, unit) end)
end

local avisados = {} -- llave -> muerto: ya se dijo que pudo volver
function Rl.Revisar()
	if not activo() or U.EnInstancia() or (InCombatLockdown and InCombatLockdown()) then return 0 end
	local t, n = U.Reloj(), 0
	for _, x in ipairs(Rl.Lista()) do
		local k = llave(x.nombre)
		if x.aqui and t - x.muerto >= VUELVE_MIN and t - x.muerto < VUELVE_MAX + 1800 and avisados[k] ~= x.muerto then
			avisados[k] = x.muerto
			n = n + 1
			local K = N.Kit
			local o = {
				titulo = format(L["%s pudo volver ya"], x.nombre),
				texto = format(L["Lo cazaron %s. Ve a ver si ya salió."], U.Hace(t - x.muerto) or ""),
				icono = "ic-raros", duracion = 12,
				accion = x.map and x.x and { texto = L["Ir de caza"], alClic = function() Rl.Ir(x) end } or nil,
			}
			if K and K.Aviso then K.Aviso(o) else U.Decir(o.titulo) end
		end
	end
	return n
end

-- Para el banco.
function Rl.Olvidar() wipe(datos()) avisados = {} enviados = {} cambio() end

A.OnLogin(function()
	caducar()
	N.Cada("manada.relojRaros", 60, function() pcall(Rl.Revisar) end)
end)
