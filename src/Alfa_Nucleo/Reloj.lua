-- Alfa - Núcleo: un solo reloj para las tareas de Alfa (1.2.9). toxic3000 /
-- La Jauría. GPL-3.0.
--
-- En lugar de que cada módulo tenga su propio OnUpdate o su ticker, las
-- tareas que se repiten se anotan aquí y las mueve UN marco. Ese marco
-- duerme (oculto, sin OnUpdate) mientras falta para la siguiente tarea; un
-- temporizador del juego lo despierta poco antes. Sin tareas, no corre nada.
--
--   N.Cada(clave, seg, fn, o)   fn(dt) cada seg segundos (dt: desde su última vez).
--                               o.ya = true: la primera vez en el siguiente cuadro;
--                               o.fueraDeCombate = true: en combate espera a que termine.
--                               Otra tarea con la misma clave la reemplaza.
--   N.Una(clave, seg, fn, o)    lo mismo, una sola vez.
--   N.Quitar(clave)             la tarea ya no corre.
--   N.HayTarea(clave) -> bool
--   N.Ticker(clave, seg, fn, o) -> h   como N.Cada, con h:Cancel() / h:IsCancelled()
--                               (el reemplazo de A.NewTicker / C_Timer.NewTicker)
--   N.Tareas() -> { { clave, cada, veces, ms, fallos }, ... }  lo que más tarda primero
--                               (ms: tiempo total medido con debugprofilestop)
-- Un error en una tarea se avisa (geterrorhandler) y la tarea sigue; tras 5
-- errores seguidos se quita, para no llenar la pantalla de errores.

local _, N = ...

local pairs, pcall, type, tonumber, max, huge = pairs, pcall, type, tonumber, math.max, math.huge

local tareas = {}            -- clave -> tarea
local marco = CreateFrame("Frame")
marco:Hide()
local turno = 0              -- cada plan nuevo invalida el despertador anterior
local siguiente = huge       -- cuándo toca la próxima tarea (GetTime)
local DESPIERTO = 0.1        -- con menos de esto para la próxima, el marco no duerme
local ANTES = 0.05           -- el despertador suena esto antes (unos 3 cuadros)
local MAX_FALLOS = 5
local seq = 0                -- orden en que se anotaron (Adelantar las corre así)

N.Reloj = { marco = marco, lista = tareas } -- (lista: para /alfa rendimiento y las pruebas)

local function ahora() return GetTime and GetTime() or 0 end
local function medir()
	if not debugprofilestop then return nil end
	local ok, t = pcall(debugprofilestop)
	return ok and tonumber(t) or nil
end
local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end

local function planificar()
	turno = turno + 1
	local now = ahora()
	siguiente = huge
	for _, t in pairs(tareas) do
		if t.proxima < siguiente then siguiente = t.proxima end
	end
	if siguiente == huge then
		marco:Hide()
		return
	end
	local falta = siguiente - now
	if falta <= DESPIERTO or not (C_Timer and C_Timer.After) then
		marco:Show()
		return
	end
	-- Duerme y se despierta un poco antes (el OnUpdate afina el momento).
	marco:Hide()
	local mio = turno
	C_Timer.After(max(0, falta - ANTES), function()
		if mio == turno then marco:Show() end
	end)
end

local function correr(t, now)
	local t0 = medir()
	local ok, err = pcall(t.fn, now - (t.ultima or now))
	local t1 = medir()
	if t0 and t1 and t1 >= t0 then t.ms = t.ms + (t1 - t0) end
	t.veces = t.veces + 1
	t.ultima = now
	if ok then
		t.fallos = 0
	else
		t.fallos = t.fallos + 1
		if geterrorhandler then pcall(geterrorhandler(), err) end
		if t.fallos >= MAX_FALLOS then t.muerta = true end
	end
end

local function tic()
	local now = ahora()
	if now < siguiente then return end
	-- Primero las que tocan (una tarea puede anotar o quitar otras al correr).
	local tocan = {}
	for clave, t in pairs(tareas) do
		if t.proxima <= now then tocan[#tocan + 1] = clave end
	end
	local combate = enCombate()
	for _, clave in ipairs(tocan) do
		local t = tareas[clave]
		if t and t.proxima <= now then
			if t.fueraDeCombate and combate then
				t.proxima = now + 1 -- se vuelve a mirar en un segundo
			else
				correr(t, now)
				if tareas[clave] == t then
					if t.una or t.muerta then tareas[clave] = nil
					else t.proxima = now + t.cada end
				end
			end
		end
	end
	planificar()
end
marco:SetScript("OnUpdate", tic)
N.Reloj.Tic = tic

local function anotar(clave, seg, fn, o, una)
	assert(type(clave) == "string" and clave ~= "", "Reloj: falta la clave")
	assert(type(fn) == "function", "Reloj: falta la función")
	seg = max(0, tonumber(seg) or 0)
	o = type(o) == "table" and o or {}
	local now = ahora()
	seq = seq + 1
	tareas[clave] = {
		clave = clave, seq = seq, fn = fn, cada = una and 0 or max(0.05, seg), una = una,
		proxima = (o.ya and now or now + seg), ultima = now,
		fueraDeCombate = o.fueraDeCombate and true or false,
		veces = 0, ms = 0, fallos = 0,
	}
	planificar()
	return clave
end

function N.Cada(clave, seg, fn, o) return anotar(clave, seg, fn, o, false) end
function N.Una(clave, seg, fn, o) return anotar(clave, seg, fn, o, true) end

function N.Quitar(clave)
	if tareas[clave] == nil then return false end
	tareas[clave] = nil
	planificar()
	return true
end

function N.HayTarea(clave) return tareas[clave] ~= nil end

-- Un temporizador que se repite y se cancela igual que los de C_Timer
-- (h:Cancel(), h:IsCancelled()), pero movido por este reloj: así los módulos
-- cambian `A.NewTicker(seg, fn)` por `N.Ticker(clave, seg, fn)` sin tocar el
-- resto. Cancelar un temporizador viejo no quita a otro nuevo con su clave.
function N.Ticker(clave, seg, fn, o)
	anotar(clave, seg, fn, o, false)
	local h = { clave = clave, tarea = tareas[clave] }
	function h:Cancel()
		self.cancelado = true
		if tareas[self.clave] == self.tarea then N.Quitar(self.clave) end
	end
	function h:IsCancelled() return self.cancelado or tareas[self.clave] ~= self.tarea end
	return h
end

-- Para el banco de pruebas (tools/banco): corre cada tarea una vez, sin
-- esperar su hora, como el banco hace con los temporizadores del juego.
-- -> true si quedan tareas.
function N.Reloj.Adelantar()
	local now = ahora()
	local claves = {}
	for clave in pairs(tareas) do claves[#claves + 1] = clave end
	table.sort(claves, function(a, b) return tareas[a].seq < tareas[b].seq end)
	local combate = enCombate()
	for _, clave in ipairs(claves) do
		local t = tareas[clave]
		if t and not (t.fueraDeCombate and combate) then
			correr(t, now)
			if tareas[clave] == t then
				if t.una or t.muerta then tareas[clave] = nil
				else t.proxima = now + t.cada end
			end
		end
	end
	planificar()
	return next(tareas) ~= nil
end

function N.Tareas()
	local out = {}
	for clave, t in pairs(tareas) do
		out[#out + 1] = { clave = clave, cada = t.cada, veces = t.veces, ms = t.ms, fallos = t.fallos, una = t.una }
	end
	table.sort(out, function(a, b)
		if a.ms ~= b.ms then return a.ms > b.ms end
		return a.clave < b.clave
	end)
	return out
end
