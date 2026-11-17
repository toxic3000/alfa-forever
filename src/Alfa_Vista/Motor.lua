-- Alfa - Paisaje y gráficos: leer y escribir las variables del juego
-- (toxic3000 / La Jauría). GPL-3.0.
--
-- Reglas:
--   * Una CVar que el cliente no tiene (o que el juego bloquea) no se
--     muestra ni se escribe nunca (C_CVar.GetCVarInfo).
--   * Al instalar Alfa no cambia nada: solo lee. Lo que el jugador toca se
--     guarda (N.Datos("vista").valores) con el valor que el juego de verdad
--     dejó (se vuelve a leer después de escribir).
--   * Nada se escribe en combate: lo pedido espera a que termine
--     (N.FueraDeCombate) y la ventana lo dice.
--   * Al entrar, cuando el juego terminó de cargar, se vuelven a poner los
--     valores elegidos (ajuste vista.reaplicar). Después, si el menú del
--     juego o /console cambian uno, Alfa se queda con el nuevo (no pelea).
-- También guarda el valor de antes de Alfa (originales) y el de antes del
-- último preajuste (para Deshacer).

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local ID = M.ID

local type, pairs, ipairs, pcall, tonumber, tostring, format, floor, abs =
	type, pairs, ipairs, pcall, tonumber, tostring, string.format, math.floor, math.abs

local function datos()
	local d = N.Datos(ID)
	d.valores = type(d.valores) == "table" and d.valores or {}
	d.originales = type(d.originales) == "table" and d.originales or {}
	return d
end
M.Datos = datos

---------------------------------------------------------------------------
-- Leer
---------------------------------------------------------------------------
local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end
M.EnCombate = enCombate

function M.Leer(cvar)
	local get = (C_CVar and C_CVar.GetCVar) or GetCVar
	if type(get) ~= "function" then return nil end
	local ok, v = pcall(get, cvar)
	if ok and type(v) == "string" then return v end
	return nil
end

-- "2.600000" -> 2.6 ; "1" -> 1 ; nil si no es número
function M.Numero(v) return tonumber(v) end

-- Dos valores iguales para el juego ("2.6" y "2.600000" lo son).
function M.Igual(a, b)
	if a == nil or b == nil then return a == b end
	local na, nb = tonumber(a), tonumber(b)
	if na and nb then return abs(na - nb) < 1e-4 end
	return tostring(a) == tostring(b)
end
local igual = M.Igual

-- Un número como lo escribe una persona: 3, 2.6, 0.15
function M.Texto(v)
	local n = tonumber(v)
	if not n then return tostring(v or "") end
	if abs(n - floor(n + 0.5)) < 1e-6 then return tostring(floor(n + 0.5)) end
	local s = format("%.3f", n):gsub("0+$", ""):gsub("%.$", "")
	return s
end

-- Lo que el cliente sabe de una CVar: { defecto, seguro } o false si no la
-- tiene, si está bloqueada o si es de solo lectura. Se guarda por sesión.
local cache = {}
local function cvarsListas()
	if C_CVar and C_CVar.AreCVarsLoaded then
		local ok, si = pcall(C_CVar.AreCVarsLoaded)
		if ok and si == false then return false end
	end
	return true
end

function M.Info(cvar)
	local c = cache[cvar]
	if c ~= nil then return c end
	local valor, defecto, bloqueada, segura, soloLectura
	if C_CVar and C_CVar.GetCVarInfo then
		local ok, a, b, _, _, e, f, g = pcall(C_CVar.GetCVarInfo, cvar)
		if ok and type(a) == "table" then
			valor, defecto, bloqueada, segura, soloLectura = a.value, a.defaultValue, a.isLockedFromUser, a.isSecure, a.isReadOnly
		elseif ok and type(a) == "string" then
			valor, defecto, bloqueada, segura, soloLectura = a, b, e, f, g
		end
	end
	if type(valor) ~= "string" then valor = M.Leer(cvar) end
	local info = false
	if type(valor) == "string" and bloqueada ~= true and soloLectura ~= true then
		if type(defecto) ~= "string" and C_CVar and C_CVar.GetCVarDefault then
			local ok, d = pcall(C_CVar.GetCVarDefault, cvar)
			if ok and type(d) == "string" then defecto = d end
		end
		info = { defecto = type(defecto) == "string" and defecto or nil, segura = segura == true }
	end
	if info or cvarsListas() then cache[cvar] = info end
	return info
end

function M.Existe(cvar) return M.Info(cvar) and true or false end
function M.Defecto(cvar) local i = M.Info(cvar) return i and i.defecto end

-- Distinto del valor de fábrica del juego.
function M.Cambiada(cvar)
	local d = M.Defecto(cvar)
	return d ~= nil and not igual(M.Leer(cvar), d)
end

-- Alfa la mantiene (la eligió el jugador aquí).
function M.Elegida(cvar) return datos().valores[cvar] ~= nil end

-- Cuántas CVars del catálogo tiene este cliente y cuáles no.
function M.Conteo()
	local hay, faltan = 0, {}
	for cvar in pairs(M.FILA) do
		if M.Existe(cvar) then hay = hay + 1 else faltan[#faltan + 1] = cvar end
	end
	table.sort(faltan)
	return hay, faltan
end

---------------------------------------------------------------------------
-- Avisar a la ventana y a la página (una vez por cuadro)
---------------------------------------------------------------------------
M.oyentes = {}
function M.AlCambiar(fn) M.oyentes[#M.oyentes + 1] = fn end
local avisando = false
function M.Avisar()
	if avisando then return end
	avisando = true
	local function correr()
		avisando = false
		for _, fn in ipairs(M.oyentes) do
			local ok, err = pcall(fn)
			if not ok and geterrorhandler then geterrorhandler()(err) end
		end
	end
	if C_Timer and C_Timer.After then C_Timer.After(0, correr) else correr() end
end

---------------------------------------------------------------------------
-- Escribir (solo fuera de combate)
---------------------------------------------------------------------------
local escribiendo = false
local pendientes, programado = {}, false
M.limites = {} -- [cvar] = { pedido, quedo } cuando el juego no dejó el valor pedido

local function escribir(cvar, valor)
	local set = (C_CVar and C_CVar.SetCVar) or SetCVar
	if type(set) ~= "function" then return M.Leer(cvar) end
	escribiendo = true
	pcall(set, cvar, valor)
	escribiendo = false
	local quedo = M.Leer(cvar)
	if quedo ~= nil and not igual(quedo, valor) then
		M.limites[cvar] = { valor, quedo }
	else
		M.limites[cvar] = nil
	end
	local f = M.FILA[cvar]
	if f and f.reinicio and not igual(quedo, datos().reinicioDe and datos().reinicioDe[cvar]) then
		datos().reinicio = true
	end
	return quedo
end

local function vaciar()
	programado = false
	local lista = pendientes
	pendientes = {}
	local d = datos()
	for cvar, v in pairs(lista) do
		if v == false then
			escribir(cvar, M.Defecto(cvar) or M.Leer(cvar))
			d.valores[cvar] = nil
		else
			d.valores[cvar] = escribir(cvar, v)
		end
	end
	M.Avisar()
end

local function programar()
	if programado then return end
	programado = true
	N.FueraDeCombate(vaciar)
end

function M.Pendiente(cvar) return pendientes[cvar] ~= nil end

-- El valor que se ve en la ventana: el que espera al combate, si hay uno.
function M.ValorDe(cvar)
	local p = pendientes[cvar]
	if p == false then return M.Defecto(cvar) end
	if p ~= nil then return p end
	return M.Leer(cvar)
end
function M.Pendientes()
	local n = 0
	for _ in pairs(pendientes) do n = n + 1 end
	return n
end

local function guardarOriginal(cvar)
	local d = datos()
	if d.originales[cvar] == nil then d.originales[cvar] = M.Leer(cvar) end
end

-- Pide poner una CVar. -> "ok" | "limitado", quedo | "espera" | "falta"
function M.Pedir(cvar, valor, quieto, libre)
	if not M.Existe(cvar) then return "falta" end
	valor = M.Texto(valor)
	-- Nunca fuera de lo que Alfa ofrece: un deslizador se queda en su rango y
	-- una lista solo acepta sus opciones (el agua no pasa de 3: más cierra el juego).
	local f = not libre and M.FILA[cvar] or nil
	if f and f.tipo == "deslizador" then
		local n = tonumber(valor)
		if not n then return "invalido" end
		if f.min and n < f.min then valor = M.Texto(f.min) end
		if f.max and n > f.max then valor = M.Texto(f.max) end
	elseif f and f.tipo == "lista" then
		local esta = false
		for _, o in ipairs(f.opciones) do if igual(o[1], valor) then esta = true end end
		if not esta then return "invalido" end
	elseif f and f.tipo == "interruptor" then
		valor = (tonumber(valor) or 0) ~= 0 and "1" or "0"
	end
	guardarOriginal(cvar)
	if enCombate() then
		pendientes[cvar] = valor
		programar()
		if not quieto then M.Avisar() end
		return "espera"
	end
	pendientes[cvar] = nil
	local quedo = escribir(cvar, valor)
	datos().valores[cvar] = quedo
	if not quieto then M.Avisar() end
	if not igual(quedo, valor) then return "limitado", quedo end
	return "ok", quedo
end

-- "Por defecto": el valor de fábrica del juego, y Alfa deja de mantenerla.
function M.Restablecer(cvar)
	local def = M.Defecto(cvar)
	if def == nil then return "falta" end
	guardarOriginal(cvar)
	if enCombate() then
		pendientes[cvar] = false
		programar()
		M.Avisar()
		return "espera"
	end
	pendientes[cvar] = nil
	escribir(cvar, def)
	datos().valores[cvar] = nil
	M.Avisar()
	return "ok"
end

---------------------------------------------------------------------------
-- Preajustes y deshacer
---------------------------------------------------------------------------
local function buscarPreset(nombre)
	if type(nombre) ~= "string" then return nil end
	if M.PRESET[nombre] then return M.PRESET[nombre] end
	local bajo = nombre:lower()
	for _, p in ipairs(M.PRESETS) do
		if p.id == bajo or p.nombre:lower() == bajo then return p end
	end
end

-- -> true, "ok" | "espera" ; false, motivo
function M.AplicarPreset(nombre)
	local p = buscarPreset(nombre)
	if not p then return false, L["No conozco ese preajuste."] end
	local antes = {}
	for cvar in pairs(p.valores) do
		if M.Existe(cvar) then antes[cvar] = pendientes[cvar] or M.Leer(cvar) end
	end
	local d = datos()
	d.deshacer = { preset = p.id, valores = antes }
	d.ultimoPreset = p.id
	local espera = false
	for cvar, v in pairs(p.valores) do
		if antes[cvar] ~= nil then
			if M.Pedir(cvar, v, true) == "espera" then espera = true end
		end
	end
	M.Avisar()
	return true, espera and "espera" or "ok"
end

function M.PuedeDeshacer() return type(datos().deshacer) == "table" end

function M.Deshacer()
	local d = datos()
	local u = d.deshacer
	if type(u) ~= "table" or type(u.valores) ~= "table" then return false end
	for cvar, v in pairs(u.valores) do M.Pedir(cvar, v, true, true) end
	d.deshacer = nil
	d.ultimoPreset = nil
	M.Avisar()
	return true
end

function M.UltimoPreset()
	local id = datos().ultimoPreset
	local p = id and M.PRESET[id]
	if not p then return nil end
	-- Sigue puesto solo si nada de lo suyo cambió desde entonces.
	for cvar, v in pairs(p.valores) do
		if M.Existe(cvar) and not M.Pendiente(cvar) and not igual(M.Leer(cvar), v) and not M.limites[cvar] then return nil end
	end
	return p
end

-- Todo como estaba antes de que Alfa tocara algo.
function M.VolverOriginal()
	if enCombate() then
		N.FueraDeCombate(M.VolverOriginal)
		M.Avisar()
		return
	end
	local d = datos()
	for cvar, v in pairs(d.originales) do
		if M.Existe(cvar) then M.Pedir(cvar, v, true, true) end
	end
	d.valores, d.originales, d.deshacer, d.ultimoPreset = {}, {}, nil, nil
	M.Avisar()
end

function M.HayOriginales() return next(datos().originales) ~= nil end

function M.Elegidas()
	local n = 0
	for cvar in pairs(datos().valores) do if M.FILA[cvar] then n = n + 1 end end
	return n
end

---------------------------------------------------------------------------
-- Reiniciar los gráficos (lo piden algunos ajustes, como el HDR)
---------------------------------------------------------------------------
function M.NecesitaReinicio() return datos().reinicio == true end

function M.PedirReinicio()
	local K = N.Kit
	K.Dialogo({
		titulo = L["¿Reiniciar los gráficos?"],
		texto = L["La pantalla se pone negra uno o dos segundos mientras el juego vuelve a arrancar los gráficos. No sales del juego ni pierdes nada."],
		aceptar = L["Reiniciar gráficos"],
		alAceptar = function()
			N.FueraDeCombate(function()
				datos().reinicio = nil
				local d = datos()
				d.reinicioDe = {}
				for cvar, f in pairs(M.FILA) do
					if f.reinicio then d.reinicioDe[cvar] = M.Leer(cvar) end
				end
				if type(RestartGx) == "function" then pcall(RestartGx) end
				M.Avisar()
			end)
		end,
	})
end

---------------------------------------------------------------------------
-- Al entrar: volver a poner lo elegido, y luego seguir al juego
---------------------------------------------------------------------------
local listo = false

-- "Alejar más la cámara" de Comodidades manda sobre la distancia de la cámara.
function M.CamaraDeComodidades()
	return A.Get("comodidades.camara") == true
end

local function reaplicar()
	local d = datos()
	for cvar, v in pairs(d.valores) do
		if M.FILA[cvar] and M.Existe(cvar) and not (cvar == "cameraDistanceMaxZoomFactor" and M.CamaraDeComodidades()) then
			if not igual(M.Leer(cvar), v) then escribir(cvar, v) end
		end
	end
	listo = true
	M.Avisar()
end

-- El menú del juego o /console cambiaron algo: Alfa se queda con lo nuevo.
function M.Sincronizar()
	if not listo then return end
	local d, cambio = datos(), false
	for cvar, v in pairs(d.valores) do
		if pendientes[cvar] == nil and M.FILA[cvar] then
			local ahora = M.Leer(cvar)
			if ahora ~= nil and not igual(ahora, v) then
				d.valores[cvar] = ahora
				M.limites[cvar] = nil
				cambio = true
			end
		end
	end
	if cambio then M.Avisar() end
end

local sincronizando = false
A.RegisterEvent("CVAR_UPDATE", function()
	if escribiendo or not listo or sincronizando then return end
	sincronizando = true
	C_Timer.After(0.3, function()
		sincronizando = false
		M.Sincronizar()
	end)
end)

local entro = false
A.RegisterEvent("PLAYER_ENTERING_WORLD", function()
	if entro then return end
	entro = true
	-- El juego termina de aplicar sus opciones al cargar: se espera un poco.
	C_Timer.After(3, function()
		if N.Get(ID, "reaplicar") == false or next(datos().valores) == nil then
			listo = true
			return
		end
		N.FueraDeCombate(reaplicar)
	end)
end)

-- La ventana avisa si hay cambios en espera por el combate.
A.RegisterEvent("PLAYER_REGEN_DISABLED", function() M.Avisar() end)
A.RegisterEvent("PLAYER_REGEN_ENABLED", function() M.Avisar() end)
