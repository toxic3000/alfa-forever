-- Alfa - Núcleo: respaldos automáticos de tus ajustes (1.2.9). toxic3000 /
-- La Jauría. GPL-3.0.
--
-- Una copia de los ajustes de la cuenta (AlfaDB.settings) y de lo que los
-- módulos anotan como suyo (los perfiles de Alfa_Bienvenida) cada semana y
-- antes de cualquier migración. Se guardan los últimos 3, con su fecha y su
-- versión, en AlfaNucleoDB.respaldos: otro archivo que el de los ajustes,
-- así un AlfaDB dañado o vacío no se lleva sus respaldos.
--
-- Al entrar, antes de las migraciones, se revisa si los ajustes llegaron
-- vacíos cuando el último respaldo tenía muchos (el archivo se dañó o se
-- borró): N.AjustesDanados() lo dice y el mensaje ALFA_AJUSTES_DANADOS avisa
-- (Alfa_Bienvenida ofrece restaurar). Mientras tanto no se respalda encima.
--
--   N.Respaldar(motivo) -> ok, respaldo    motivo: "semanal" | "migracion" | "manual"
--   N.Respaldos() -> { { t, cuando, v, motivo, n, ajustes, extras }, ... } el más nuevo al final
--   N.RestaurarRespaldo(i) -> ok           pone los ajustes de ese respaldo
--   N.RespaldoExtra(clave, leer, poner)    algo más que va en cada respaldo:
--                                          leer() -> tabla, poner(tabla) al restaurar
--   N.AjustesDanados() -> respaldo | nil

local _, N = ...
local A = N.A

local type, pairs, ipairs, pcall, tonumber, next = type, pairs, ipairs, pcall, tonumber, next

local MAX = 3
local SEMANA = 7 * 24 * 3600
local POCOS = 5       -- con menos ajustes que esto, un respaldo no cuenta como "lleno"
local MAX_NODOS = 60000

local extras = {}
local danado

local function d() return N.Datos("respaldos") end
local function guardados()
	local x = d()
	x.lista = type(x.lista) == "table" and x.lista or {}
	return x.lista
end

local function ajustes()
	local db = A.DB and A.DB()
	return type(db) == "table" and db or nil, type(db) == "table" and db.settings or nil
end

-- Una copia de sí/no, números, textos y tablas (sin funciones ni ciclos).
local function copiar(t, cuenta, prof)
	local out = {}
	prof = prof or 0
	if prof > 12 then return out end
	for k, v in pairs(t) do
		cuenta.n = cuenta.n + 1
		if cuenta.n > MAX_NODOS then break end
		local tk, tv = type(k), type(v)
		if tk == "string" or tk == "number" then
			if tv == "table" then out[k] = copiar(v, cuenta, prof + 1)
			elseif tv == "boolean" or tv == "number" or tv == "string" then out[k] = v end
		end
	end
	return out
end
local function copia(t) return copiar(t, { n = 0 }) end
N.CopiarTabla = copia

-- Cuántos valores (hojas) tiene una tabla de ajustes.
local function contar(t, prof)
	if type(t) ~= "table" then return 0 end
	prof = prof or 0
	if prof > 12 then return 0 end
	local n = 0
	for _, v in pairs(t) do
		if type(v) == "table" then n = n + contar(v, prof + 1) else n = n + 1 end
	end
	return n
end
N.ContarAjustes = contar

function N.RespaldoExtra(clave, leer, poner)
	if type(clave) ~= "string" or type(leer) ~= "function" then return false end
	extras[clave] = { leer = leer, poner = poner }
	return true
end

function N.Respaldos() return guardados() end
function N.AjustesDanados() return danado end

function N.Respaldar(motivo)
	local _, s = ajustes()
	if type(s) ~= "table" then return false, "sin ajustes" end
	local r = {
		t = time and time() or 0, cuando = date and date("%d/%m/%Y %H:%M") or "",
		v = tostring(N.version or "dev"), motivo = motivo or "manual",
		ajustes = copia(s), n = contar(s), extras = {},
	}
	for clave, e in pairs(extras) do
		local ok, x = pcall(e.leer)
		if ok and type(x) == "table" then r.extras[clave] = copia(x) end
	end
	local l = guardados()
	l[#l + 1] = r
	while #l > MAX do table.remove(l, 1) end
	d().ultimo = r.t
	if A.Fire then A.Fire("ALFA_RESPALDO", r) end
	return true, r
end

function N.RestaurarRespaldo(i)
	local l = guardados()
	local r = l[tonumber(i) or #l]
	local db = ajustes()
	if type(r) ~= "table" or type(r.ajustes) ~= "table" or not db then return false end
	db.settings = copia(r.ajustes)
	for clave, x in pairs(r.extras or {}) do
		local e = extras[clave]
		if e and type(e.poner) == "function" and type(x) == "table" then pcall(e.poner, copia(x)) end
	end
	danado = nil
	-- Todos los módulos escuchan el cambio general ("" = todo).
	if A.Fire then A.Fire("SETTING_CHANGED", "") end
	local K = N.Kit
	if K and K.Repintar then pcall(K.Repintar) end
	return true, r
end

-- El último respaldo con ajustes de verdad.
local function ultimoLleno()
	local l = guardados()
	for i = #l, 1, -1 do
		local r = l[i]
		if type(r) == "table" and (tonumber(r.n) or 0) >= POCOS and type(r.ajustes) == "table" then return r, i end
	end
	return nil
end

-- Al entrar, antes de las migraciones: ¿llegaron los ajustes vacíos?
function N.RevisarAjustes()
	danado = nil
	local r = ultimoLleno()
	if not r then return nil end
	local _, s = ajustes()
	local n = contar(s)
	local nueva = A.IsNewAccount and A.IsNewAccount() or false
	if type(s) ~= "table" or n == 0 or (nueva and n < POCOS) then
		-- Una vez por respaldo: quien lo dejó así a propósito no lo vuelve a ver.
		if d().ofrecido ~= r.t then
			danado = r
			d().ofrecido = r.t
			if A.Fire then A.Fire("ALFA_AJUSTES_DANADOS", r) end
		end
	end
	return danado
end

-- Antes de una migración (Nucleo.lua, N.CorrerMigraciones).
function N.AntesDeMigrar()
	if danado then return false end
	local _, s = ajustes()
	if contar(s) == 0 then return false end
	return N.Respaldar("migracion")
end

-- Una vez por semana (al entrar, después de las migraciones).
function N.RespaldoSemanal()
	if danado then return false end
	local _, s = ajustes()
	if contar(s) == 0 then return false end
	local ult = tonumber(d().ultimo) or 0
	local now = time and time() or 0
	if now - ult < SEMANA then return false end
	return N.Respaldar("semanal")
end
