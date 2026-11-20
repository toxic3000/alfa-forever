-- Alfa - Pesca: cocina junto al agua (toxic3000 / La Jauría). GPL-3.0.
--
-- Las recetas de pescado (Datos.lua: M.RECETAS) con lo que dice el juego:
-- si ya la sabes, la habilidad de Cocina que pide, los ingredientes (la receta
-- del juego, C_TradeSkillUI.GetRecipeSchematic; si no responde, el pescado)
-- y para cuántas te alcanza con lo que llevas.
-- La cola de cocina: tú eliges qué y cuánto; cada clic (o tu tecla en la
-- ventana) cocina el siguiente lote. Nunca cocina sola: si la ventana de
-- Cocina del juego no está abierta, ese clic la abre ("/cast Cocina", con el
-- botón seguro) y el siguiente cocina.
-- La fogata básica se enciende con su botón (hechizo de Cocina).

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = M.L
local Eq = M.Eq

local floor, max, min, format, type, pairs, ipairs, tonumber = math.floor, math.max, math.min, string.format, type, pairs, ipairs, tonumber

local Co = {}
M.Cocina = Co

local COCINA_HECHIZOS = { 2550, 3102, 3413, 18260 }

local function legible(v) return v ~= nil and not (issecretvalue and issecretvalue(v)) end

local function nombreHechizo(id)
	local S = C_Spell
	if S and S.GetSpellName then
		local ok, n = pcall(S.GetSpellName, id)
		if ok and type(n) == "string" and n ~= "" and legible(n) then return n end
	end
	if GetSpellInfo then
		local ok, n = pcall(GetSpellInfo, id)
		if ok and type(n) == "string" and n ~= "" then return n end
	end
	return nil
end

local function sabe(id)
	if C_SpellBook and C_SpellBook.IsSpellKnown then
		local ok, si = pcall(C_SpellBook.IsSpellKnown, id)
		if ok and si == true then return true end
	end
	if IsPlayerSpell then
		local ok, si = pcall(IsPlayerSpell, id)
		if ok and si == true then return true end
	end
	return false
end
Co.Sabe = sabe

function Co.NombreFogata() return nombreHechizo(M.FOGATA) end
function Co.SabeFogata() return sabe(M.FOGATA) end
function Co.NombreCocina()
	for _, id in ipairs(COCINA_HECHIZOS) do
		local n = nombreHechizo(id)
		if n then return n end
	end
	return N.espanol and "Cocina" or "Cooking"
end

-- -> rango, máximo (nil si no sabe Cocina)
function Co.Habilidad()
	local S = C_SkillInfo
	if S and S.GetSkillLineInfoByID then
		local ok, info = pcall(S.GetSkillLineInfoByID, M.COCINA)
		if ok and type(info) == "table" then
			local r, mx = tonumber(info.rank), tonumber(info.maxRank)
			if r and mx and legible(r) and not (r == 0 and mx == 0) then return r, mx end
		end
	end
	local C = A.Compat
	if C and C.GetSkillRank then
		local ok, r, mx = pcall(C.GetSkillRank, M.COCINA)
		if ok and type(r) == "number" then return r, tonumber(mx) or 0 end
	end
	return nil
end

---------------------------------------------------------------------------
-- Ingredientes de cada receta (la receta del juego, una vez)
---------------------------------------------------------------------------
local ingredientes = {}

local function leerIngredientes(r)
	local hay = ingredientes[r.hechizo]
	if hay then return hay end
	local out
	local T = C_TradeSkillUI
	if T and T.GetRecipeSchematic then
		local ok, s = pcall(T.GetRecipeSchematic, r.hechizo, false)
		if ok and type(s) == "table" and type(s.reagentSlotSchematics) == "table" then
			out = {}
			for _, slot in ipairs(s.reagentSlotSchematics) do
				local q = tonumber(slot.quantityRequired) or 0
				local re = type(slot.reagents) == "table" and slot.reagents[1]
				local id = re and tonumber(re.itemID)
				if id and q > 0 and slot.required ~= false then out[#out + 1] = { id = id, n = q } end
			end
			if #out == 0 then out = nil end
		end
	end
	out = out or { { id = r.crudo, n = 1 } }
	ingredientes[r.hechizo] = out
	return out
end

local function nombreObjeto(id)
	return Eq.Nombre(id) or (M.V and M.V.NombreObjeto(id)) or nil
end

-- Todas las recetas de pescado con su estado:
-- { r (de Datos), nombre, icono, aprendida, habilidad, ingredientes = { { id, n, tienes, nombre } }, alcanza, puede, motivo }
function Co.Recetas()
	local rango = Co.Habilidad()
	local out = {}
	for _, r in ipairs(M.RECETAS) do
		local ing = leerIngredientes(r)
		local alcanza = math.huge
		local lista = {}
		for _, x in ipairs(ing) do
			local tienes = Eq.Cuenta(x.id)
			lista[#lista + 1] = { id = x.id, n = x.n, tienes = tienes, nombre = nombreObjeto(x.id) }
			alcanza = min(alcanza, floor(tienes / max(1, x.n)))
		end
		if alcanza == math.huge then alcanza = 0 end
		local aprendida = sabe(r.hechizo)
		local d = {
			r = r, nombre = Eq.Nombre(r.cocinado) or nombreHechizo(r.hechizo) or nombreObjeto(r.cocinado), icono = Eq.Icono(r.cocinado),
			aprendida = aprendida, habilidad = r.habilidad, ingredientes = lista, alcanza = alcanza,
		}
		if not rango then
			d.motivo = L["Aprende Cocina con un instructor."]
		elseif not aprendida then
			d.motivo = (rango < r.habilidad) and format(L["Pide %d de Cocina y aprender la receta."], r.habilidad) or L["Te falta aprender la receta."]
		elseif alcanza <= 0 then
			d.motivo = L["Te faltan ingredientes."]
		end
		d.puede = aprendida and alcanza > 0 and rango ~= nil
		out[#out + 1] = d
	end
	table.sort(out, function(a, b)
		if a.puede ~= b.puede then return a.puede end
		if a.aprendida ~= b.aprendida then return a.aprendida end
		if a.alcanza ~= b.alcanza then return a.alcanza > b.alcanza end
		return a.r.habilidad < b.r.habilidad
	end)
	return out
end

-- Las que puedes cocinar ya, de la que más alcanza a la que menos (n: cuántas).
function Co.Listas(n)
	local out = {}
	for _, d in ipairs(Co.Recetas()) do
		if d.puede then out[#out + 1] = d end
		if n and #out >= n then break end
	end
	return out
end

---------------------------------------------------------------------------
-- La cola: { { hechizo, nombre, icono, cantidad, hechas } }
---------------------------------------------------------------------------
Co.cola = {}
local cocinaAbierta = false

function Co.Encolar(d, cantidad)
	cantidad = max(1, floor(tonumber(cantidad) or 1))
	for _, c in ipairs(Co.cola) do
		if c.hechizo == d.r.hechizo then
			c.cantidad = c.cantidad + cantidad
			M.Avisar("cocina")
			return c
		end
	end
	local c = { hechizo = d.r.hechizo, crudo = d.r.crudo, nombre = d.nombre, icono = d.icono, cantidad = cantidad, hechas = 0 }
	Co.cola[#Co.cola + 1] = c
	M.Avisar("cocina")
	return c
end

function Co.Quitar(i)
	table.remove(Co.cola, i)
	M.Avisar("cocina")
end

function Co.Vaciar()
	Co.cola = {}
	M.Avisar("cocina")
end

function Co.Siguiente() return Co.cola[1] end

-- ¿La ventana de Cocina del juego está abierta?
function Co.Abierta()
	if not cocinaAbierta then return false end
	local T = C_TradeSkillUI
	if T and T.GetBaseProfessionInfo then
		local ok, info = pcall(T.GetBaseProfessionInfo)
		if ok and type(info) == "table" and info.professionID then
			return info.professionID == M.COCINA or info.parentProfessionID == M.COCINA
		end
	end
	return true
end

-- Lo que hace el botón "Cocinar" ahora: abrir la Cocina (botón seguro) o
-- cocinar el siguiente lote (su clic).
function Co.Atributos()
	if Co.Abierta() then return {} end
	return { type = "macro", macrotext = "/cast " .. Co.NombreCocina() }
end

-- Cocina el siguiente lote de la cola (desde un clic tuyo). -> ok, texto
local cocinando = nil
function Co.CocinarLote()
	local c = Co.cola[1]
	if not c then return false, L["La cola está vacía."] end
	if not Co.Abierta() then return false, L["Abre la Cocina del juego (el botón lo hace) y vuelve a pulsar."] end
	local alcanza = math.huge
	for _, x in ipairs(leerIngredientes({ hechizo = c.hechizo, crudo = c.crudo })) do
		alcanza = min(alcanza, floor(Eq.Cuenta(x.id) / max(1, x.n)))
	end
	if alcanza == math.huge then alcanza = 0 end
	local n = min(c.cantidad - c.hechas, alcanza)
	if n <= 0 then return false, L["Te faltan ingredientes para el siguiente lote."] end
	local T = C_TradeSkillUI
	if not (T and T.CraftRecipe) then return false, L["El juego no deja cocinar desde aquí."] end
	local ok = pcall(T.CraftRecipe, c.hechizo, n)
	if not ok then return false, L["El juego no aceptó el lote."] end
	cocinando = { c = c, n = n }
	return true, format(L["Cocinando %d de %s"], n, c.nombre or "?")
end

A.RegisterEvent("TRADE_SKILL_SHOW", function() cocinaAbierta = true M.Avisar("cocina") end)
A.RegisterEvent("TRADE_SKILL_CLOSE", function() cocinaAbierta = false M.Avisar("cocina") end)

-- Cada pieza cocinada de una receta de pescado cuenta; un lote terminado se quita de la cola.
local HECHIZOS = {}
for _, r in ipairs(M.RECETAS) do HECHIZOS[r.hechizo] = true end

AlfaNucleo.DeUnidad("UNIT_SPELLCAST_SUCCEEDED", "player", function(_, unidad, _, spell)
	-- Lo secreto primero: un token de unidad secreto no se compara (1.2.0).
	if not legible(unidad) or unidad ~= "player" or not legible(spell) or not HECHIZOS[spell] then return end
	local c = Co.cola[1]
	local lote = false
	if c and c.hechizo == spell then
		c.hechas = c.hechas + 1
		if c.hechas >= c.cantidad then
			table.remove(Co.cola, 1)
			lote = true
		elseif cocinando and cocinando.c == c then
			cocinando.n = cocinando.n - 1
			if cocinando.n <= 0 then lote = true cocinando = nil end
		end
	end
	M.R.Cocinado(1, lote)
	M.Avisar("cocina")
end)

A.RegisterEvent("BAG_UPDATE_DELAYED", function() if M.V and M.V.Visible and M.V.Visible() then M.Avisar("cocina") end end)
