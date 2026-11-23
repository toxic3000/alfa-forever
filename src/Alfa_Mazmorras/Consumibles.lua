-- Alfa - Mazmorras: lo que te falta tomar antes de un jefe (1.3.7).
-- toxic3000 / La Jauría. GPL-3.0.
--
-- Al apuntar a un jefe fuera de combate (EnVivo.lua llama a Co.AlJefe) y al
-- entrar a una banda, un aviso chico con lo que no llevas puesto o encima:
--   * comida de bufo («Bien alimentado»), desde el nivel COMIDA o en banda;
--   * frasco o elixir, solo en banda;
--   * piedra de salud, si hay un brujo en tu grupo (o lo eres) y no llevas;
--   * munición, si eres cazador y te quedan pocas.
-- Una vez por jefe y por entrada; nunca en combate; espera a que Alfa esté
-- libre (N.AlLibre) para no taparte una cinemática o una pantalla de carga.
-- Solo se leen tus propios bufos y tus bolsas, nada del enemigo.
-- Ajuste: mazmorras.consumibles (sí).
--
--   Co.Faltas(enBanda) -> { texto, ... }    Co.AlJefe(key, jefe)    Co.AlEntrarBanda()

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = N.Textos(M.EN)
local D = M.D

local type, ipairs, pairs, pcall, tonumber, format = type, ipairs, pairs, pcall, tonumber, string.format

local Co = {}
M.Consumibles = Co

local ID = D.ID
local COMIDA = 30      -- desde este nivel se recuerda la comida en mazmorras
local MUNICION = 200   -- menos de esto, se recuerda

local function leer(v) return D.Legible(v) end
local function activo() return N.Get(ID, "consumibles") ~= false end
local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end

-- «Bien alimentado» de la comida de bufo (sus hechizos más comunes; su
-- nombre en el idioma del cliente sale del primero que el juego conozca).
local COMIDA_IDS = { 19705, 19706, 19708, 19709, 19710, 19711, 24799, 18191, 18192, 18193, 18194, 18125, 18141, 22730, 25661, 5004, 5005, 5006, 5007, 10256, 10257 }
local ICONO_COMIDA = 136000 -- Spell_Misc_Food
-- Frascos y elixires (de batalla y de guardián) de Clásico, y el Espíritu de Zanza.
local ELIXIR_IDS = {
	17626, 17627, 17628, 17629, 17538, 11405, 11334, 11328, 3160, 2374, 11396, 17535, 11474, 26276, 7844, 21920,
	17539, 11390, 3593, 11348, 11349, 3220, 673, 17537, 3164, 2378, 3166, 24382, 16323, 16329, 11406, 17549, 17548,
}
-- Piedras de salud (de menor a mayor, con sus talentos).
local PIEDRAS = { 5512, 19004, 19005, 5511, 19006, 19007, 5509, 19008, 19009, 5510, 19010, 19011, 9421, 19012, 19013 }

local function conjunto(t)
	local s = {}
	for _, id in ipairs(t) do s[id] = true end
	return s
end
local ES_COMIDA, ES_ELIXIR = conjunto(COMIDA_IDS), conjunto(ELIXIR_IDS)

local nombreComida
local function nombreBienAlimentado()
	if nombreComida ~= nil then return nombreComida end
	nombreComida = false
	local S = rawget(_G, "C_Spell")
	for _, id in ipairs(COMIDA_IDS) do
		local n
		if type(S) == "table" and type(S.GetSpellName) == "function" then n = D.Llamar(S.GetSpellName, id) end
		if not n and GetSpellInfo then n = D.Llamar(GetSpellInfo, id) end
		if type(n) == "string" and n ~= "" then nombreComida = n break end
	end
	return nombreComida
end

-- Tus bufos: -> comida, elixir
local function misBufos()
	local comida, elixir = false, false
	local nombre = nombreBienAlimentado()
	local CU = rawget(_G, "C_UnitAuras")
	for i = 1, 40 do
		local id, icono, n
		if type(CU) == "table" and type(CU.GetAuraDataByIndex) == "function" then
			local a = leer(D.Llamar(CU.GetAuraDataByIndex, "player", i, "HELPFUL"))
			if type(a) ~= "table" then break end
			id, icono, n = leer(a.spellId), leer(a.icon), leer(a.name)
		elseif UnitBuff then
			local nb, ic, _, _, _, _, _, _, _, sid = D.Llamar(UnitBuff, "player", i)
			if not leer(nb) then break end
			id, icono, n = leer(sid), leer(ic), leer(nb)
		else
			break
		end
		if ES_COMIDA[id] or icono == ICONO_COMIDA or (nombre and n == nombre) then comida = true end
		if ES_ELIXIR[id] then elixir = true end
	end
	return comida, elixir
end
Co.MisBufos = misBufos

local function cuantos(id)
	local CI = rawget(_G, "C_Item")
	local fn = type(CI) == "table" and CI.GetItemCount or rawget(_G, "GetItemCount")
	local n = type(fn) == "function" and leer(D.Llamar(fn, id)) or 0
	return type(n) == "number" and n or 0
end

local function clase(unidad)
	if not UnitClass then return nil end
	local ok, _, c = pcall(UnitClass, unidad)
	return ok and leer(c) or nil
end

local function hayBrujo()
	if clase("player") == "WARLOCK" then return true end
	local n = GetNumGroupMembers and leer(D.Llamar(GetNumGroupMembers)) or 0
	if type(n) ~= "number" or n <= 1 then return false end
	local banda = IsInRaid and IsInRaid()
	for i = 1, (banda and n or n - 1) do
		local u = (banda and "raid" or "party") .. i
		if clase(u) == "WARLOCK" then return true end
	end
	return false
end

local function tengoPiedra()
	for _, id in ipairs(PIEDRAS) do if cuantos(id) > 0 then return true end end
	return false
end

-- Lo que te falta: -> { texto, ... }
function Co.Faltas(enBanda)
	local out = {}
	local nivel = D.Nivel()
	local comida, elixir = misBufos()
	if not comida and (enBanda or nivel >= COMIDA) then out[#out + 1] = L["Comida de bufo («Bien alimentado»)"] end
	if enBanda and not elixir then out[#out + 1] = L["Un frasco o un elixir"] end
	if hayBrujo() and not tengoPiedra() then out[#out + 1] = L["Una piedra de salud (pídela a tu brujo)"] end
	if clase("player") == "HUNTER" and GetInventoryItemCount then
		local n = leer(D.Llamar(GetInventoryItemCount, "player", 0))
		if type(n) == "number" and n < MUNICION then
			out[#out + 1] = N.Plural(n, L["Munición: te queda %d"], L["Munición: te quedan %d"])
		end
	end
	return out
end

local function avisar(titulo, faltas)
	if #faltas == 0 then return false end
	local lineas = {}
	for i, f in ipairs(faltas) do
		if i > 3 then break end
		lineas[i] = "\194\183 " .. f
	end
	if K and K.Aviso then
		K.Aviso({ titulo = titulo, texto = table.concat(lineas, "\n"), icono = "ic-mazmorra", tono = "aviso", duracion = 8 })
	else
		N.Imprimir(titulo .. " " .. table.concat(faltas, ", "))
	end
	return true
end

-- "party" | "raid" | nil
function Co.Tipo()
	if not (M.Crono and M.Crono.Instancia) then return nil end
	local dentro, tipo = M.Crono.Instancia()
	return dentro and tipo or nil
end

local libre = function(clave, fn, prioridad)
	if N.AlLibre then return N.AlLibre(clave, fn, prioridad) end
	return fn()
end

local vistos = {} -- key:jefe -> true (en esta entrada)

function Co.AlJefe(key, jefe)
	if not activo() or enCombate() or type(jefe) ~= "table" then return false end
	local llave = tostring(key) .. ":" .. tostring(jefe.id or jefe.nombre)
	if vistos[llave] or D.Vencido(key, jefe.id) then return false end
	vistos[llave] = true
	local tipo = Co.Tipo()
	local faltas = Co.Faltas(tipo == "raid")
	if #faltas == 0 then return false end
	libre("mazmorras.consumibles", function()
		if enCombate() then return end
		avisar(format(L["Antes de %s, te falta:"], type(jefe.nombre) == "string" and jefe.nombre or L["este jefe"]), Co.Faltas(tipo == "raid"))
	end, 3)
	return true
end

function Co.AlEntrarBanda()
	if not activo() then return false end
	local faltas = Co.Faltas(true)
	if #faltas == 0 then return false end
	libre("mazmorras.consumibles", function()
		if enCombate() then return end
		avisar(L["Antes de la banda, te falta:"], Co.Faltas(true))
	end, 3)
	return true
end

function Co.Olvidar() vistos = {} end

A.RegisterEvent("PLAYER_ENTERING_WORLD", function()
	vistos = {}
	local f = function()
		N.FueraDeCombate("mazmorras.consumibles", function()
			local tipo = Co.Tipo()
			if tipo == "raid" then Co.AlEntrarBanda() end
		end)
	end
	if N.Una then N.Una("mazmorras.consumiblesBanda", 8, f) elseif A.After then A.After(8, f) end
end)
