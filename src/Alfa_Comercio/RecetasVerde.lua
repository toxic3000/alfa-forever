-- Alfa - Comercio: la receta que pasa a verde (1.4.0, plan 51; toxic3000 / La Jauría). GPL-3.0.
--
-- Mientras subes un oficio, la receta que haces pasa de amarillo a verde: ya
-- solo da puntos a veces y gastas materiales de más. Alfa te lo dice una vez
-- por receta (y cuál sigue, la más barata que aún da puntos seguros):
--   * con la ventana del oficio abierta, por el color real que da el juego
--     (Recetas.lua llama a M.AlCambiarColores al releer las recetas);
--   * con la ventana cerrada (fabricar desde un botón o una macro), por los
--     colores del recetario (M.Colores): la receta que fabricaste hace poco
--     y tu habilidad nueva (SKILL_LINES_CHANGED).
-- Ajuste comercio.avisoVerde (de fábrica, sí). Nada en combate.
--   M.AvisarVerde(linea, rid, nombre) ; M.RecetaSiguiente(linea, rank, menos)

local _, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L

local type, pairs, ipairs, tonumber, format, floor = type, pairs, ipairs, tonumber, string.format, math.floor

local RECIENTE = 600 -- s: una receta fabricada hace menos que esto cuenta para el aviso
local hechas = {}    -- recetaID -> GetTime() de la última vez que la fabricaste
local habAntes = {}  -- línea -> habilidad vista antes

local function activo() return M.Ajuste("avisoVerde") ~= false end

local function vistos()
	local d = N.DatosPersonaje(M.ID)
	d.verdes = type(d.verdes) == "table" and d.verdes or {}
	return d.verdes
end

local function nombreReceta(linea, rid)
	local c = N.Datos(M.ID).catalogo
	local e = type(c) == "table" and type(c[linea]) == "table" and c[linea][rid] or nil
	if e and type(e.n) == "string" then return e.n end
	if e and e.o and M.NombreObjeto then return M.NombreObjeto(e.o) end
	return nil
end

-- La que sigue: la más barata que todavía da puntos seguros (naranja o amarilla).
function M.RecetaSiguiente(linea, rank, menos)
	local Of = M.Oficios
	if not (Of and Of.MasBarata) then return nil end
	local ok, lista = pcall(Of.MasBarata, linea, rank)
	for _, x in ipairs(ok and type(lista) == "table" and lista or {}) do
		local c = x.color
		local segura = c == nil or c == "guia" or (type(c) == "number" and c <= 1)
		if x.o ~= menos and segura and (x.chance or 0) >= 0.5 then
			return x
		end
	end
	return nil
end

function M.AvisarVerde(linea, rid, nombre, rank, producto)
	if not activo() or not rid then return false end
	local v = vistos()
	if v[rid] then return false end
	v[rid] = rank or true
	nombre = nombre or nombreReceta(linea, rid) or L["Tu receta"]
	local texto = format(L["«%s» ya está en verde: solo da puntos a veces y gastas materiales de más."], nombre)
	local sig = M.RecetaSiguiente(linea, rank, producto)
	if sig and sig.o and M.NombreObjeto then
		texto = texto .. " " .. format(L["Sigue con «%s», que todavía da puntos seguros."], M.NombreObjeto(sig.o))
	end
	local AR = rawget(_G, "AlfaRuta")
	local accion
	if type(AR) == "table" and type(AR.GuiaOficio) == "function" and AR.TieneGuiaOficio and AR.TieneGuiaOficio(linea) then
		accion = { texto = L["Ver la guía"], alClic = function() AR.GuiaOficio(linea) end }
	end
	K.Aviso({ id = "comercio.verde." .. tostring(rid), icono = "ic-oficios", tono = "aviso", titulo = L["Tu receta pasó a verde"],
		texto = texto, accion = accion, duracion = 8, donde = L["Comercio > Oficios"] })
	return true
end

-- Con la ventana abierta: el color real (Recetas.lua). antes: rid -> color de antes.
function M.AlCambiarColores(linea, antes, nuevas)
	if not activo() then return end
	local ahora = GetTime and GetTime() or 0
	for rid, rec in pairs(nuevas or {}) do
		local a = antes and antes[rid]
		if a == 1 and rec.d == 2 then
			-- Solo la que estás haciendo (fabricada hace poco): las demás no importan ahora.
			local t = hechas[rid]
			if t and ahora - t < RECIENTE then M.AvisarVerde(linea, rid, rec.n, rec.s, rec.o) end
		end
	end
end

-- Con la ventana cerrada: por el recetario.
local function porRecetario(linea, rank)
	local c = N.Datos(M.ID).catalogo
	c = type(c) == "table" and c[linea] or nil
	if type(c) ~= "table" then return end
	local ahora = GetTime and GetTime() or 0
	local antes = habAntes[linea]
	for rid, t in pairs(hechas) do
		local e = c[rid]
		if e and ahora - t < RECIENTE then
			local y, gris = M.Colores(e)
			if y and gris then
				local verde = floor((y + gris) / 2)
				if antes and antes < verde and rank >= verde and rank < gris then M.AvisarVerde(linea, rid, e.n, rank, e.o) end
			end
		end
	end
end

local LINEAS = { 129, 164, 165, 171, 185, 197, 202, 333 }
local function revisarHabilidades()
	if not activo() or (InCombatLockdown and InCombatLockdown()) then return end
	local Of = M.Oficios
	for _, linea in ipairs(LINEAS) do
		local r = Of and Of.Habilidad and Of.Habilidad(linea)
		if r then
			if habAntes[linea] and r > habAntes[linea] then porRecetario(linea, r) end
			habAntes[linea] = r
		end
	end
end
M.RevisarVerdes = revisarHabilidades

-- Lo que fabricas: el hechizo de la receta (recetaID = hechizo).
function M.AnotarFabricada(spellID)
	spellID = N.Leer(spellID) -- 1.4.0: («Leer and Leer(x) or x» devolvía el secreto)
	if type(spellID) ~= "number" then return end
	local c = N.Datos(M.ID).catalogo
	if type(c) ~= "table" then return end
	for _, l in pairs(c) do
		if type(l) == "table" and l[spellID] then hechas[spellID] = GetTime and GetTime() or 0 return end
	end
end
function M.OlvidarVerdes() hechas, habAntes = {}, {} local d = N.DatosPersonaje(M.ID) d.verdes = nil end -- (para el banco)

if N.DeUnidad then
	N.DeUnidad("UNIT_SPELLCAST_SUCCEEDED", "player", function(_, unidad, _, spellID)
		if InCombatLockdown and InCombatLockdown() then return end
		M.AnotarFabricada(spellID)
	end)
end
A.RegisterEvent("SKILL_LINES_CHANGED", function() N.Una("comercio.verde", 0.5, revisarHabilidades, { fueraDeCombate = true }) end)
A.OnLogin(function() N.Una("comercio.verdeInicio", 5, revisarHabilidades, { fueraDeCombate = true }) end)
