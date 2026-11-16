-- Alfa - Builds: pesos de estadísticas de cada build (Toxic / La Jauría). GPL-3.0.
--
-- Cada build trae su escala: los pesos del motor para su rama y tu nivel
-- (Gear.WeightsFor) ajustados por su estilo y su objetivo (M.AJUSTE_PESOS) y
-- por los suyos propios (build.pesos.mult). Al activarla se guarda como una
-- escala personalizada del motor (Gear.Scales, que la importa como cadena de
-- texto) y se elige en gear.spec.<CLASE>: así las flechas de mejora de las
-- bolsas, los cuadros de los objetos y las recompensas de misión la usan.
--
--   P.Pesos(build) -> weights | nil
--   P.Activar(build) -> ok, texto
--   P.Desactivar() ; P.Activa() -> build id | nil (si la escala sigue elegida)
--   P.Orden(build) -> { { clave, peso, relativo } } para dibujar barras

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local P = {}
M.Pesos = P

local function gear() return A.Gear end

-- La parte del motor que escribe las cadenas de escala (así se llama su tabla
-- en el código de Polestar).
local function escritor(G) return G and G.Pawn end

local function datos() return N.DatosPersonaje(M.ID) end

function P.Pesos(b)
	local G = gear()
	if not (b and G and G.WeightsFor) then return nil end
	local nivel = (G.GetPlayer and G.GetPlayer().level) or UnitLevel("player") or 1
	local base = (b.pesos and b.pesos.base) or b.spec
	local w = G.WeightsFor(b.clase, base, nivel)
	if not w then return nil end
	local out = {}
	for k, v in pairs(w) do out[k] = v end
	local function aplicar(mult)
		if type(mult) ~= "table" then return end
		for k, m in pairs(mult) do if out[k] then out[k] = out[k] * m end end
	end
	aplicar(M.AJUSTE_PESOS[b.estilo])
	aplicar(M.AJUSTE_PESOS[b.objetivo])
	aplicar(b.pesos and b.pesos.mult)
	if b.pesos and type(b.pesos.fijo) == "table" then
		for k, v in pairs(b.pesos.fijo) do out[k] = v end
	end
	-- Redondeo a 3 decimales: así la cadena exportada coincide con lo usado.
	for k, v in pairs(out) do out[k] = math.floor(v * 1000 + 0.5) / 1000 end
	return out
end

-- Nombre de la escala: corto (el motor corta a 40 letras) y reconocible.
local function nombreEscala(b)
	local t = "Alfa: " .. (b.titulo or b.id)
	if #t > 40 then t = t:sub(1, 40) end
	return t
end

function P.Activar(b)
	local G = gear()
	local E = escritor(G)
	if not (G and G.Scales and E and E.Build) then return false, L["El sistema de equipo de Alfa no está disponible."] end
	local w = P.Pesos(b)
	if not w then return false, L["Esta clase no tiene pesos de estadísticas en Alfa."] end
	local d = datos()
	local clase = b.clase
	-- La escala anterior de este personaje se reemplaza: no se acumulan.
	if d.escala and d.escalaClase == clase and G.Scales.Get(clase, d.escala) then
		G.Scales.Delete(clase, d.escala)
	end
	local texto = E.Build(nombreEscala(b), clase, w)
	local ok, res = G.Scales.Import(texto, clase)
	if not ok then
		return false, G.Scales.ErrorText and G.Scales.ErrorText(res) or tostring(res)
	end
	d.escala, d.escalaClase, d.escalaBuild = res.scale.id, clase, b.id
	A.Set("gear.spec." .. clase, "custom:" .. res.scale.id)
	return true, string.format(L["Pesos de %s activos: las flechas de mejora ya los usan."], b.titulo or b.id)
end

function P.Desactivar()
	local d = datos()
	local clase = d.escalaClase or M.ClaseJugador()
	if clase then A.Set("gear.spec." .. clase, "auto") end
	d.escalaBuild = nil
end

-- El build cuya escala está elegida ahora (otro cambio en Opciones la suelta).
function P.Activa()
	local d = datos()
	if not (d.escala and d.escalaClase) then return nil end
	local elegido = A.Get("gear.spec." .. d.escalaClase)
	if elegido ~= "custom:" .. d.escala then return nil end
	local G = gear()
	if G and G.Scales and not G.Scales.Get(d.escalaClase, d.escala) then return nil end
	return d.escalaBuild
end

-- Al subir de nivel, los pesos del motor cambian por tramos: se renueva la
-- escala del build activo para seguirlos.
function P.Renovar()
	local id = P.Activa()
	local b = id and M.Build(id)
	if b then P.Activar(b) end
end

-- Pesos para mostrar: el de cada estadística de la prioridad del build,
-- relativo al mayor "por pieza típica" (un punto de crítico no vale lo mismo
-- que un punto de fuerza, así que se escala por lo que suele traer un objeto).
local TIPICO = {
	str = 10, agi = 10, sta = 10, int = 10, spi = 10, armor = 200, ap = 20, rap = 20, sp = 12, heal = 22,
	crit = 1, hit = 1, spellCrit = 1, spellHit = 1, mp5 = 4, hp5 = 4, defense = 8, dodge = 1, parry = 1,
	block = 1, blockValue = 15, dps = 3, rdps = 3,
}
function P.Orden(b)
	local w = P.Pesos(b) or {}
	local lista, top = {}, 0
	for _, k in ipairs(b.stats or {}) do
		local v = (w[k] or 0) * (TIPICO[k] or 1)
		lista[#lista + 1] = { clave = k, peso = w[k], valor = v }
		if v > top then top = v end
	end
	for i, e in ipairs(lista) do
		-- El orden manda (lo eligió una persona): la barra baja con la posición.
		local porPos = 1 - (i - 1) * 0.14
		e.relativo = top > 0 and math.max(0.12, math.min(porPos, (e.valor / top) * 0.5 + porPos * 0.5)) or porPos
	end
	return lista
end
