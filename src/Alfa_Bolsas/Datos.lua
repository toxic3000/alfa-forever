-- Alfa - Bolsas: el registro de lo que lleva cada personaje de la cuenta.
-- GPL-3.0.
--
-- N.Datos("bolsas").personajes["Nombre-Reino"] = {
--   nombre, reino, faccion ("Alliance" | "Horde"), clase ("WARRIOR"), nivel,
--   dinero (cobre), visto (time()),
--   bolsas = { [bolsa] = { n = casillas, [casilla] = { i = id, c = cantidad, l = enlace, q = calidad } } },
--   banco  = { igual, con las pestañas del banco },  bancoVisto = time() de la última foto,
--   equipo = { [ranura] = { i = id, l = enlace, q = calidad } },
--   v = versión (sube con cada cambio: los conteos del cuadro se rehacen),
-- }
-- Se escribe al cambiar las bolsas (agrupado, BAG_UPDATE_DELAYED), el banco
-- (solo mientras está abierto: si no, el juego no lo deja leer), el equipo y
-- el dinero. Las bolsas: 0 (mochila) a 4, la de componentes (5) y el llavero
-- (-1); el banco: las pestañas del personaje (6 a 14).

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L

local type, pairs, ipairs, tonumber, next = type, pairs, ipairs, tonumber, next
local floor = math.floor

local D = {}
M.Datos = D

D.BOLSAS = { 0, 1, 2, 3, 4, 5 }
D.LLAVERO = -1
D.BANCO = { 6, 7, 8, 9, 10, 11, 12, 13, 14 }
D.REAGENTES = 5
local RANURAS = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 }

local esBolsa, esBanco = {}, {}
for _, b in ipairs(D.BOLSAS) do esBolsa[b] = true end
esBolsa[D.LLAVERO] = true
for _, b in ipairs(D.BANCO) do esBanco[b] = true end
D.EsBolsa, D.EsBanco = esBolsa, esBanco

---------------------------------------------------------------------------
-- Dónde se guarda
---------------------------------------------------------------------------

-- La raíz de los datos de la cuenta. Se pide cada vez (el juego puede
-- devolver las variables guardadas en nil al arrancar).
function D.Raiz()
	local d = N.Datos(M.ID)
	if type(rawget(d, "personajes")) ~= "table" then d.personajes = {} end
	if type(rawget(d, "ui")) ~= "table" then d.ui = {} end
	if type(rawget(d.ui, "plegadas")) ~= "table" then d.ui.plegadas = {} end
	return d
end

local clave -- "Nombre-Reino" del personaje actual

function D.Clave()
	if clave then return clave end
	local nombre = M.Texto(UnitName and UnitName("player"))
	local reino = M.Texto(GetNormalizedRealmName and GetNormalizedRealmName()) or M.Texto(GetRealmName and GetRealmName())
	if not nombre or nombre == "" then return nil end
	clave = reino and (nombre .. "-" .. reino) or nombre
	return clave
end

-- El registro del personaje actual (se crea si falta). nil antes de saber quién es.
function D.Actual()
	local k = D.Clave()
	if not k then return nil end
	local lista = D.Raiz().personajes
	local r = lista[k]
	if type(r) ~= "table" then
		r = {}
		lista[k] = r
	end
	if type(r.bolsas) ~= "table" then r.bolsas = {} end
	if type(r.banco) ~= "table" then r.banco = {} end
	if type(r.equipo) ~= "table" then r.equipo = {} end
	return r
end

function D.Personaje(k)
	local r = type(k) == "string" and D.Raiz().personajes[k]
	return type(r) == "table" and r or nil
end

function D.EsActual(k) return k ~= nil and k == D.Clave() end

local function tocar(r)
	r.v = (tonumber(r.v) or 0) + 1
	r.visto = time and time() or r.visto
end

---------------------------------------------------------------------------
-- Lectura del cliente
---------------------------------------------------------------------------

local C = C_Container

-- Casillas de una bolsa en vivo: -> { n = casillas, [casilla] = { i, c, l, q } }
function D.Escanear(bolsa)
	local n = C and M.Num(M.Llamar(C.GetContainerNumSlots, bolsa)) or 0
	n = n or 0
	local t = { n = n }
	for s = 1, n do
		local info = M.Llamar(C.GetContainerItemInfo, bolsa, s)
		if type(info) == "table" then
			local id = M.Num(info.itemID)
			if id then
				t[s] = { i = id, c = M.Num(info.stackCount) or 1, l = M.Texto(info.hyperlink), q = M.Num(info.quality) }
			end
		end
	end
	return t
end

local function cabecera(r)
	local nombre = M.Texto(UnitName and UnitName("player"))
	if nombre then r.nombre = nombre end
	r.reino = M.Texto(GetRealmName and GetRealmName()) or r.reino
	local faccion = M.Texto(UnitFactionGroup and UnitFactionGroup("player"))
	if faccion == "Alliance" or faccion == "Horde" then r.faccion = faccion end
	if UnitClass then
		local _, clase = UnitClass("player")
		clase = M.Texto(clase)
		if clase then r.clase = clase end
	end
	r.nivel = M.Num(UnitLevel and UnitLevel("player")) or r.nivel
	r.dinero = M.Num(GetMoney and GetMoney()) or r.dinero
end

---------------------------------------------------------------------------
-- Escritura agrupada
---------------------------------------------------------------------------

local sucias = {}      -- bolsa -> true: por volver a leer
local bancoAbierto = false
local programado = false

function D.BancoAbierto() return bancoAbierto end

local function guardar()
	programado = false
	local r = D.Actual()
	if not r then return end
	local cambio = false
	for bolsa in pairs(sucias) do
		sucias[bolsa] = nil
		if esBolsa[bolsa] then
			r.bolsas[bolsa] = D.Escanear(bolsa)
			cambio = true
		elseif esBanco[bolsa] and bancoAbierto then
			r.banco[bolsa] = D.Escanear(bolsa)
			r.bancoVisto = time and time() or r.bancoVisto
			cambio = true
		end
	end
	if cambio then
		tocar(r)
		M.Avisar("DATOS", D.Clave())
	end
end

local function programar(seg)
	if programado then return end
	programado = true
	M.Luego(seg or 0.25, guardar)
end

function D.MarcarBolsa(bolsa)
	if type(bolsa) ~= "number" then return end
	if esBolsa[bolsa] or (esBanco[bolsa] and bancoAbierto) then sucias[bolsa] = true end
end

function D.TodasLasBolsas()
	for _, b in ipairs(D.BOLSAS) do sucias[b] = true end
	sucias[D.LLAVERO] = true
	programar(0.1)
end

function D.TodoElBanco()
	if not bancoAbierto then return end
	local r = D.Actual()
	if r then r.banco = {} end
	for _, b in ipairs(D.BANCO) do sucias[b] = true end
	programar(0.1)
end

function D.GuardarEquipo()
	local r = D.Actual()
	if not (r and GetInventoryItemLink) then return end
	local eq = {}
	for _, ranura in ipairs(RANURAS) do
		local link = M.Texto(GetInventoryItemLink("player", ranura))
		local id = M.Num(GetInventoryItemID and GetInventoryItemID("player", ranura)) or M.ItemID(link)
		if id then
			eq[ranura] = { i = id, l = link, q = M.Num(GetInventoryItemQuality and GetInventoryItemQuality("player", ranura)) }
		end
	end
	r.equipo = eq
	tocar(r)
	M.Avisar("DATOS", D.Clave())
end

function D.GuardarCabecera()
	local r = D.Actual()
	if not r then return end
	cabecera(r)
	r.visto = time and time() or r.visto
	M.Avisar("DINERO")
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------

local function alEntrar()
	clave = nil
	D.GuardarCabecera()
	D.TodasLasBolsas()
	M.Luego(1, D.GuardarEquipo)
end

A.RegisterEvent("PLAYER_ENTERING_WORLD", alEntrar)
A.RegisterEvent("BAG_UPDATE", function(_, bolsa) D.MarcarBolsa(M.Num(bolsa)) end)
A.RegisterEvent("BAG_UPDATE_DELAYED", function() if next(sucias) then programar() end end)
A.RegisterEvent("BAG_CONTAINER_UPDATE", function()
	D.TodasLasBolsas()
	if bancoAbierto then D.TodoElBanco() end
end)
A.RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function() M.Luego(0.2, D.GuardarEquipo) end)
A.RegisterEvent("PLAYER_MONEY", D.GuardarCabecera)
A.RegisterEvent("PLAYER_LEVEL_UP", function() M.Luego(0.5, D.GuardarCabecera) end)

A.RegisterEvent("BANKFRAME_OPENED", function()
	bancoAbierto = true
	D.TodoElBanco()
end)
A.RegisterEvent("BANKFRAME_CLOSED", function()
	bancoAbierto = false
	for b in pairs(sucias) do if esBanco[b] then sucias[b] = nil end end
end)
-- slot: el número de la pestaña del banco que cambió (1 = la primera).
A.RegisterEvent("PLAYERBANKSLOTS_CHANGED", function(_, pestana)
	if not bancoAbierto then return end
	pestana = M.Num(pestana)
	local bolsa = pestana and D.BANCO[pestana]
	if bolsa then sucias[bolsa] = true else for _, b in ipairs(D.BANCO) do sucias[b] = true end end
	programar()
end)
A.RegisterEvent("BANK_TABS_CHANGED", function() D.TodoElBanco() end)

---------------------------------------------------------------------------
-- Consultas
---------------------------------------------------------------------------

-- Los personajes guardados, el actual primero, luego por nombre.
-- -> { { clave, r }, ... }
function D.Lista()
	local out = {}
	local actual = D.Clave()
	for k, r in pairs(D.Raiz().personajes) do
		if type(k) == "string" and type(r) == "table" then out[#out + 1] = { clave = k, r = r } end
	end
	table.sort(out, function(a, b)
		if (a.clave == actual) ~= (b.clave == actual) then return a.clave == actual end
		local na, nb = tostring(a.r.nombre or a.clave), tostring(b.r.nombre or b.clave)
		if na ~= nb then return na < nb end
		return a.clave < b.clave
	end)
	return out
end

function D.Olvidar(k)
	if type(k) ~= "string" or k == D.Clave() then return false end
	D.Raiz().personajes[k] = nil
	M.Avisar("DATOS", k)
	return true
end

-- Dinero de toda la cuenta (el actual en vivo).
function D.DineroCuenta()
	local total = 0
	local actual = D.Clave()
	for k, r in pairs(D.Raiz().personajes) do
		if type(r) == "table" then
			local d = (k == actual and M.Num(GetMoney and GetMoney())) or tonumber(r.dinero) or 0
			total = total + d
		end
	end
	return total
end

-- Objetos y casillas de un juego de bolsas guardado: -> objetos, ocupadas, total
function D.Resumen(bolsas)
	local objetos, ocupadas, total = 0, 0, 0
	if type(bolsas) ~= "table" then return 0, 0, 0 end
	for bolsa, t in pairs(bolsas) do
		if type(t) == "table" and bolsa ~= D.LLAVERO then
			local n = tonumber(t.n) or 0
			total = total + n
			for s = 1, n do
				local e = t[s]
				if type(e) == "table" then
					ocupadas = ocupadas + 1
					objetos = objetos + (tonumber(e.c) or 1)
				end
			end
		end
	end
	return objetos, ocupadas, total
end

-- Índice por personaje: id -> { bolsas, banco, equipo }, rehecho cuando sube r.v.
local indices = setmetatable({}, { __mode = "k" })

local function sumar(t, id, campo, n)
	local e = t[id]
	if not e then
		e = { 0, 0, 0 }
		t[id] = e
	end
	e[campo] = e[campo] + n
end

local function indice(r)
	local hit = indices[r]
	if hit and hit.v == r.v then return hit.t end
	local t = {}
	for _, grupo in ipairs({ { r.bolsas, 1 }, { r.banco, 2 } }) do
		local bolsas, campo = grupo[1], grupo[2]
		if type(bolsas) == "table" then
			for _, b in pairs(bolsas) do
				if type(b) == "table" then
					for s = 1, tonumber(b.n) or 0 do
						local e = b[s]
						if type(e) == "table" and type(e.i) == "number" then sumar(t, e.i, campo, tonumber(e.c) or 1) end
					end
				end
			end
		end
	end
	if type(r.equipo) == "table" then
		for _, e in pairs(r.equipo) do
			if type(e) == "table" and type(e.i) == "number" then sumar(t, e.i, 3, 1) end
		end
	end
	indices[r] = { v = r.v, t = t }
	return t
end

-- Cuántos tiene la cuenta de un objeto: -> total, { { clave, r, bolsas, banco, equipo }, ... }
function D.Conteo(id)
	id = tonumber(id)
	if not id then return 0, {} end
	local total, partes = 0, {}
	for _, p in ipairs(D.Lista()) do
		local e = indice(p.r)[id]
		if e then
			local n = e[1] + e[2] + e[3]
			if n > 0 then
				total = total + n
				partes[#partes + 1] = { clave = p.clave, r = p.r, bolsas = e[1], banco = e[2], equipo = e[3] }
			end
		end
	end
	return total, partes
end

-- "Tienes 12 (Toxic: 7 en bolsas, Alt: 5 en banco)" -> texto | nil
function D.LineaCuadro(id)
	local total, partes = D.Conteo(id)
	if total <= 0 then return nil end
	local trozos = {}
	for _, p in ipairs(partes) do
		local donde = {}
		if p.bolsas > 0 then donde[#donde + 1] = (L["%d en bolsas"]):format(p.bolsas) end
		if p.banco > 0 then donde[#donde + 1] = (L["%d en banco"]):format(p.banco) end
		if p.equipo > 0 then donde[#donde + 1] = (p.equipo == 1 and L["%d equipado"] or L["%d equipados"]):format(p.equipo) end
		local r, g, b = M.ColorClase(p.r.clase)
		local nombre = M.Pintado(p.r.nombre or p.clave, r, g, b)
		trozos[#trozos + 1] = nombre .. ": " .. table.concat(donde, L[" y "])
	end
	local ar, ag, ab = M.Acento()
	return M.Pintado((L["Tienes %d"]):format(total), ar, ag, ab) .. " (" .. table.concat(trozos, ", ") .. ")"
end

-- El cuadro de cada objeto (bolsas, botín, comerciante, enlaces...), por el
-- gancho de cuadros del motor (TooltipDataProcessor.AddTooltipPostCall).
if A.Hooks and A.Hooks.ItemLines then
	A.Hooks.ItemLines("Alfa_Bolsas", function(tooltip, link, id)
		if not M.Get("cuadroConteo") then return end
		local texto = D.LineaCuadro(id or M.ItemID(link))
		if not texto or not (tooltip and tooltip.AddLine) then return end
		local r, g, b = M.Color("textDim", 0.75, 0.78, 0.85)
		tooltip:AddLine(texto, r, g, b, true)
	end)
end
