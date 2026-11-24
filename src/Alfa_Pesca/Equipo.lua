-- Alfa - Pesca: el equipo, los cebos y los juguetes de pesca (toxic3000 / La Jauría). GPL-3.0.
--
-- Lee tus bolsas y lo que llevas puesto para saber:
--   * la mejor caña y el mejor equipo con bonificación de Pesca que tienes
--     (sombrero, guantes, botas, abalorios...), por la línea de su
--     descripción que nombra la Pesca y su número;
--   * el mejor cebo que puedes usar (o el que prefieres) y si tu caña ya
--     lleva uno;
--   * los juguetes y consumibles de pesca, con cuántos tienes y su espera.
-- Con eso arma lo que hace tu tecla (M.Plan): primero ponerte el equipo,
-- luego el cebo y luego lanzar, un paso por pulsación. Nada de esto actúa
-- solo: el botón seguro (Pesca.lua) lo hace cuando tú pulsas.
-- También recuerda tu equipo normal y lo vuelve a poner al cerrar el modo
-- pesca (si lo pides), sin tocar las ranuras que excluyes.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = M.L
local ID = M.ID

local floor, max, min, format, type, pairs, ipairs, tonumber, tostring = math.floor, math.max, math.min, string.format, type, pairs, ipairs, tonumber, tostring

local Eq = {}
M.Eq = Eq

-- Las ranuras del equipo y en qué grupo de exclusión cae cada una.
Eq.RANURAS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 }
Eq.GRUPO = { [1] = "cabeza", [10] = "manos", [8] = "pies", [13] = "abalorios", [14] = "abalorios" }
Eq.GRUPOS = {
	{ id = "cabeza", nombre = L["Cabeza"] }, { id = "manos", nombre = L["Manos"] }, { id = "pies", nombre = L["Pies"] },
	{ id = "abalorios", nombre = L["Abalorios"] }, { id = "resto", nombre = L["Las demás ranuras"] },
}
local DE_LUGAR = {
	INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
	INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
	INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
	INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 },
}

local function legible(v) return type(v) ~= "nil" and not (issecretvalue and issecretvalue(v)) end
local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end

---------------------------------------------------------------------------
-- La bonificación de Pesca de un objeto, por su descripción
---------------------------------------------------------------------------
local cache = {} -- enlace -> { bono, uso (bool), usable (bool), pesca (menciona la pesca) }

local function palabra()
	local n = M.NombrePesca and M.NombrePesca() or "Pesca"
	return (n:lower())
end

local function esLetra(c) return c ~= "" and (c:match("%a") ~= nil or c:byte() and c:byte() >= 128) end

-- La posición de la palabra completa (no "pescar" ni "pescado") o nil.
local function buscarPalabra(t, w)
	local i = 1
	while true do
		local a, b = t:find(w, i, true)
		if not a then return nil end
		local antes, despues = t:sub(a - 1, a - 1), t:sub(b + 1, b + 1)
		if not esLetra(antes) and not esLetra(despues) then return a, b end
		i = b + 1
	end
end

local REQUIERE = {}
do
	local f = type(ITEM_REQ_SKILL) == "string" and ITEM_REQ_SKILL or nil
	if f then REQUIERE[#REQUIERE + 1] = (f:gsub("%%s.*$", "")):lower() end
	REQUIERE[#REQUIERE + 1] = "requiere"
	REQUIERE[#REQUIERE + 1] = "requires"
end
local USO = (type(ITEM_SPELL_TRIGGER_ONUSE) == "string" and ITEM_SPELL_TRIGGER_ONUSE or "Uso:"):lower()

local function leerLineas(datos)
	local out = { bono = 0, uso = false, usable = true, pesca = false }
	if type(datos) ~= "table" or type(datos.lines) ~= "table" then return out end
	local w = palabra()
	for _, ln in ipairs(datos.lines) do
		local t = ln.leftText
		if type(t) == "string" and legible(t) then
			local c = ln.leftColor
			if type(c) == "table" and type(c.r) == "number" and c.r > 0.9 and (c.g or 1) < 0.25 and (c.b or 1) < 0.25 then
				out.usable = false
			end
			local lt = t:lower()
			local req = false
			for _, r in ipairs(REQUIERE) do if r ~= "" and lt:find(r, 1, true) == 1 then req = true end end
			local a, b = buscarPalabra(lt, w)
			if a and not req then
				out.pesca = true
				local n = tonumber(lt:sub(b + 1):match("^%D-(%d+)")) or tonumber(lt:sub(1, a - 1):match("(%d+)%D*$"))
				if n and n > 0 and n < 500 then
					local esUso = lt:find(USO, 1, true) == 1
					if n > out.bono then out.bono, out.uso = n, esUso end
				end
			end
		end
	end
	return out
end

local function tooltip(fn, ...)
	local T = C_TooltipInfo
	local f = T and T[fn]
	if type(f) ~= "function" then return nil end
	local ok, d = pcall(f, ...)
	return ok and d or nil
end

-- -> { bono, uso, usable, pesca }
local function infoBolsa(bolsa, ranura, enlace)
	local e = enlace and cache[enlace]
	if e then return e end
	e = leerLineas(tooltip("GetBagItem", bolsa, ranura))
	if enlace then cache[enlace] = e end
	return e
end

local function infoPuesto(ranura, enlace)
	local e = enlace and cache["p" .. ranura .. enlace]
	if e then return e end
	e = leerLineas(tooltip("GetInventoryItem", "player", ranura))
	if enlace then cache["p" .. ranura .. enlace] = e end
	return e
end

function Eq.InfoEnlace(enlace)
	if type(enlace) ~= "string" then return { bono = 0, usable = true } end
	local e = cache["h" .. enlace]
	if e then return e end
	e = leerLineas(tooltip("GetHyperlink", enlace))
	cache["h" .. enlace] = e
	return e
end

---------------------------------------------------------------------------
-- Objetos
---------------------------------------------------------------------------
local function instante(id)
	if not (C_Item and C_Item.GetItemInfoInstant) then return nil end
	local ok, _, _, _, lugar, icono, clase, sub = pcall(C_Item.GetItemInfoInstant, id)
	if not ok then return nil end
	return lugar, icono, clase, sub
end

local function esCana(id)
	local _, _, clase, sub = instante(id)
	local arma = Enum and Enum.ItemClass and Enum.ItemClass.Weapon or 2
	local cana = Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Fishingpole or 20
	return clase == arma and sub == cana
end
Eq.EsCana = esCana

function Eq.Nombre(id, enlace)
	if C_Item and C_Item.GetItemNameByID then
		local ok, n = pcall(C_Item.GetItemNameByID, id)
		if ok and type(n) == "string" and n ~= "" then return n end
	end
	if type(enlace) == "string" then
		local n = enlace:match("%[(.-)%]")
		if n then return n end
	end
	return nil
end

function Eq.Calidad(id)
	if C_Item and C_Item.GetItemQualityByID then
		local ok, q = pcall(C_Item.GetItemQualityByID, id)
		if ok and type(q) == "number" then return q end
	end
	return 1
end

function Eq.Icono(id)
	local _, icono = instante(id)
	if icono then return icono end
	if C_Item and C_Item.GetItemIconByID then
		local ok, v = pcall(C_Item.GetItemIconByID, id)
		if ok then return v end
	end
	return nil
end

function Eq.Cuenta(id)
	if C_Item and C_Item.GetItemCount then
		local ok, n = pcall(C_Item.GetItemCount, id)
		if ok and type(n) == "number" then return n end
	end
	if GetItemCount then
		local ok, n = pcall(GetItemCount, id)
		if ok and type(n) == "number" then return n end
	end
	return 0
end

-- Segundos que faltan de su espera (0 si está listo).
function Eq.Espera(id)
	local f = (C_Container and C_Container.GetItemCooldown) or GetItemCooldown
	if type(f) ~= "function" then return 0 end
	local ok, inicio, dur = pcall(f, id)
	if not ok or type(inicio) ~= "number" or type(dur) ~= "number" or inicio <= 0 or dur <= 1.5 then return 0 end
	return max(0, inicio + dur - GetTime())
end

local function enlaceBolsa(bolsa, ranura)
	local C = C_Container
	if C and C.GetContainerItemLink then
		local ok, l = pcall(C.GetContainerItemLink, bolsa, ranura)
		if ok and type(l) == "string" and legible(l) then return l end
	end
	return nil
end

local function ranurasDe(bolsa)
	local C = C_Container
	if C and C.GetContainerNumSlots then
		local ok, n = pcall(C.GetContainerNumSlots, bolsa)
		if ok and type(n) == "number" then return n end
	end
	return 0
end

local function puesto(ranura)
	if not GetInventoryItemLink then return nil end
	local ok, l = pcall(GetInventoryItemLink, "player", ranura)
	if ok and type(l) == "string" and legible(l) then return l end
	return nil
end
Eq.Puesto = puesto

local function idDe(enlace) return type(enlace) == "string" and tonumber(enlace:match("item:(%d+)")) or nil end
Eq.IdDe = idDe

---------------------------------------------------------------------------
-- El inventario de pesca (se rehace solo cuando cambian las bolsas)
---------------------------------------------------------------------------
local sucio, inv = true, nil

function Eq.Marcar() sucio = true end

local BOLSAS = { 0, 1, 2, 3, 4, 5 }

-- -> { canas = {}, equipo = {}, cebos = {}, juguetes = {} }; cada uno { id, enlace, bolsa, ranura, bono, nombre, usable }
function Eq.Inventario()
	if not sucio and inv then return inv end
	sucio = false
	local t = { canas = {}, equipo = {}, cebos = {}, juguetes = {} }
	local vistos = {}
	local juguete = {}
	for _, id in ipairs(M.JUGUETES) do juguete[id] = true end
	local uso = (Enum and Enum.ItemClass and Enum.ItemClass.Consumable) or 0
	for _, b in ipairs(BOLSAS) do
		for r = 1, ranurasDe(b) do
			local enlace = enlaceBolsa(b, r)
			local id = idDe(enlace)
			if id then
				local lugar, _, clase = instante(id)
				local e
				if esCana(id) then
					e = infoBolsa(b, r, enlace)
					t.canas[#t.canas + 1] = { id = id, enlace = enlace, bolsa = b, ranura = r, bono = e.bono, usable = e.usable }
				elseif lugar and DE_LUGAR[lugar] and not esCana(id) then
					e = infoBolsa(b, r, enlace)
					if e.bono > 0 and not e.uso then
						t.equipo[#t.equipo + 1] = { id = id, enlace = enlace, bolsa = b, ranura = r, bono = e.bono, usable = e.usable, lugar = lugar }
					end
				elseif not vistos[id] and (M.CEBOS[id] or juguete[id] or clase == uso) then
					vistos[id] = true
					e = infoBolsa(b, r, enlace)
					local c = M.CEBOS[id]
					if c or (e.uso and e.bono > 0) then
						t.cebos[#t.cebos + 1] = { id = id, enlace = enlace, bono = (c and c.bono) or e.bono, usable = e.usable,
							pide = c and c.pide or 0, minutos = c and c.min or 10 }
					elseif juguete[id] or e.pesca then
						t.juguetes[#t.juguetes + 1] = { id = id, enlace = enlace, usable = e.usable }
					end
				end
			end
		end
	end
	inv = t
	return t
end

-- La bonificación de lo que llevas puesto en una ranura.
function Eq.BonoPuesto(ranura)
	local l = puesto(ranura)
	if not l then return 0, nil end
	return infoPuesto(ranura, l).bono, l
end

function Eq.CanaPuesta()
	local l = puesto(16)
	local id = idDe(l)
	return id ~= nil and esCana(id), id, l
end

---------------------------------------------------------------------------
-- Exclusiones
---------------------------------------------------------------------------
function Eq.Excluido(ranura)
	if ranura == 16 then return false end
	local g = Eq.GRUPO[ranura] or "resto"
	local t = N.Get(ID, "excluir")
	return type(t) == "table" and t[g] == true
end

function Eq.SetExcluido(grupo, si)
	local t = N.Get(ID, "excluir")
	local nuevo = {}
	if type(t) == "table" then for k, v in pairs(t) do nuevo[k] = v end end
	nuevo[grupo] = si and true or nil
	N.Set(ID, "excluir", nuevo)
end

---------------------------------------------------------------------------
-- 1.3.7: las piezas que no entran (únicas, bolsas llenas para la caña de dos
-- manos, una que pide más nivel...). EquipItemByName no avisa si falla: una
-- pieza que tu tecla intentó ponerte y que un momento después sigue en tus
-- bolsas se salta, para que la siguiente pulsación lance en vez de atorarse.
---------------------------------------------------------------------------
local intentos = {} -- "enlace@ranura" -> GetTime() del primer intento
local ESPERA_INTENTO = 1

local function claveIntento(enlace, ranura) return tostring(enlace) .. "@" .. tostring(ranura) end

function Eq.Intentado(lista)
	local ahora = GetTime and GetTime() or 0
	for _, c in ipairs(lista or {}) do
		local k = claveIntento(c.enlace, c.ranura)
		if not intentos[k] then intentos[k] = ahora end
	end
end

function Eq.NoEntra(enlace, ranura)
	local t = intentos[claveIntento(enlace, ranura)]
	return t ~= nil and (GetTime and GetTime() or 0) - t >= ESPERA_INTENTO
end

-- Al abrir el modo (o al subir de nivel o de habilidad) cada pieza tiene otra oportunidad.
function Eq.OlvidarIntentos() intentos = {} end

---------------------------------------------------------------------------
-- 1.3.8: lo que elegiste en la ventana de antes de pescar (Previa.lua), por
-- personaje: { cana = id | nil, cebo = id | 0 (el mejor) | nil }
---------------------------------------------------------------------------
function Eq.Eleccion()
	local d = N.DatosPersonaje(ID)
	if type(d.previa) ~= "table" then d.previa = {} end
	return d.previa
end

function Eq.CanaElegida() return tonumber(Eq.Eleccion().cana) end

-- El cebo que prefieres: lo de este personaje (ventana de antes de pescar o el
-- clic derecho del menú de cebos) y, si no eligió nada, el ajuste de siempre.
function Eq.CeboElegido()
	local c = Eq.Eleccion().cebo
	if c ~= nil then return tonumber(c) or 0 end
	return tonumber(N.Get(ID, "ceboPreferido")) or 0
end

---------------------------------------------------------------------------
-- Lo mejor que tienes
---------------------------------------------------------------------------
-- -> lista de cambios { { ranura, id, enlace, nombre, bono } } para quedar con lo mejor de pesca
function Eq.MejorEquipo()
	local t = Eq.Inventario()
	local cambios = {}
	-- La caña.
	local tiene, idPuesta, enlace16 = Eq.CanaPuesta()
	local bono16 = tiene and Eq.BonoPuesto(16) or -1
	-- 1.3.8: la caña que elegiste antes de pescar (Previa.lua) manda, si la
	-- tienes y te sirve; si ya la llevas puesta, no se cambia por otra.
	local elegida = Eq.CanaElegida()
	local mejor, porGusto
	if elegida and tiene and idPuesta == elegida then
		porGusto = true
	elseif elegida then
		for _, c in ipairs(t.canas) do
			if c.id == elegida and c.usable and not Eq.NoEntra(c.enlace, 16) then mejor, porGusto = c, true break end
		end
	end
	if not porGusto then
		for _, c in ipairs(t.canas) do
			if c.usable and not Eq.NoEntra(c.enlace, 16)
				and (not mejor or c.bono > mejor.bono or (c.bono == mejor.bono and Eq.Calidad(c.id) > Eq.Calidad(mejor.id))) then mejor = c end
		end
	end
	if mejor and (porGusto or not tiene or mejor.bono > bono16) and mejor.enlace ~= enlace16 then
		cambios[#cambios + 1] = { ranura = 16, id = mejor.id, enlace = mejor.enlace, bono = mejor.bono }
	end
	-- Las demás ranuras: por cada lugar, lo de más bono que supere lo puesto.
	local porRanura = {}
	for _, e in ipairs(t.equipo) do
		if e.usable then
			for _, r in ipairs(DE_LUGAR[e.lugar] or {}) do
				if r ~= 16 and not Eq.NoEntra(e.enlace, r) then
					porRanura[r] = porRanura[r] or {}
					table.insert(porRanura[r], e)
				end
			end
		end
	end
	local usado = {}
	for _, par in ipairs({ { 1 }, { 2 }, { 3 }, { 5 }, { 6 }, { 7 }, { 8 }, { 9 }, { 10 }, { 15 }, { 11, 12 }, { 13, 14 } }) do
		local cands = {}
		for _, e in ipairs(porRanura[par[1]] or {}) do cands[#cands + 1] = e end
		table.sort(cands, function(a, b) return a.bono > b.bono end)
		local ranuras = {}
		for _, r in ipairs(par) do
			if not Eq.Excluido(r) then ranuras[#ranuras + 1] = { r = r, bono = (Eq.BonoPuesto(r)) } end
		end
		table.sort(ranuras, function(a, b) return a.bono < b.bono end)
		local i = 1
		for _, rr in ipairs(ranuras) do
			while cands[i] and usado[cands[i].enlace .. cands[i].bolsa .. ":" .. cands[i].ranura] do i = i + 1 end
			local c = cands[i]
			if c and c.bono > rr.bono then
				usado[c.enlace .. c.bolsa .. ":" .. c.ranura] = true
				cambios[#cambios + 1] = { ranura = rr.r, id = c.id, enlace = c.enlace, bono = c.bono }
				i = i + 1
			end
		end
	end
	for _, c in ipairs(cambios) do c.nombre = Eq.Nombre(c.id, c.enlace) end
	return cambios
end

-- Lo que suma tu equipo de pesca puesto ahora.
function Eq.BonoTotal()
	local total = 0
	for _, r in ipairs(Eq.RANURAS) do total = total + (Eq.BonoPuesto(r)) end
	return total
end

-- El cebo puesto en la caña: segundos que le quedan, o nil.
function Eq.CeboActivo()
	if not GetWeaponEnchantInfo then return nil end
	local ok, tiene, expira = pcall(GetWeaponEnchantInfo)
	if not ok or not legible(tiene) or not tiene then return nil end
	if not Eq.CanaPuesta() then return nil end
	return max(0, (tonumber(expira) or 0) / 1000)
end

-- El cebo que toca: el preferido si lo tienes y lo puedes usar, si no el de más bono.
function Eq.MejorCebo()
	local t = Eq.Inventario()
	local rango = M.Habilidad and M.Habilidad() or 0
	local pref = Eq.CeboElegido()
	local mejor
	for _, c in ipairs(t.cebos) do
		local puede = c.usable and (rango or 0) >= (c.pide or 0) and Eq.Cuenta(c.id) > 0
		if puede then
			if c.id == pref then return c end
			if not mejor or c.bono > mejor.bono then mejor = c end
		end
	end
	return mejor
end

---------------------------------------------------------------------------
-- Lo que hace tu tecla ahora: un paso por pulsación
---------------------------------------------------------------------------
-- -> { fase = "equipo" | "cebo" | "lanzar", equipar = {...}, cebo = {...}, cana = bool }
function Eq.Plan()
	local p = { fase = "lanzar", equipar = {} }
	p.cana = Eq.CanaPuesta() and true or false
	if N.Get(ID, "prepararEquipo") then
		p.equipar = Eq.MejorEquipo()
		if #p.equipar > 0 then
			p.fase = "equipo"
			return p
		end
	end
	if N.Get(ID, "prepararCebo") and p.cana and not Eq.CeboActivo() then
		local c = Eq.MejorCebo()
		if c then
			p.fase, p.cebo = "cebo", c
			p.cebo.nombre = Eq.Nombre(c.id, c.enlace)
		end
	end
	return p
end

-- El texto de la macro del botón seguro para ese paso.
function Eq.Macro(p, hechizo)
	local lanzar = "/cast [nocombat,noflying] " .. hechizo
	if p.fase == "equipo" then
		local lineas = {}
		local largo = 0
		for _, c in ipairs(p.equipar) do
			if c.nombre then
				local l = format("/equipslot [nocombat] %d %s", c.ranura, c.nombre)
				if largo + #l + 1 > 900 then break end
				lineas[#lineas + 1] = l
				largo = largo + #l + 1
			end
		end
		if #lineas > 0 then return table.concat(lineas, "\n") end
	elseif p.fase == "cebo" and p.cebo and p.cebo.nombre then
		return "/use [nocombat] " .. p.cebo.nombre .. "\n/use [nocombat] 16"
	end
	return lanzar
end

---------------------------------------------------------------------------
-- Tu equipo normal: se anota al ponerte algo de pesca y vuelve al cerrar
---------------------------------------------------------------------------
local foto = {}          -- ranura -> enlace puesto (lo último que se vio)
Eq.restaurando = false

local function normal()
	local d = N.DatosPersonaje(ID)
	if type(d.equipoNormal) ~= "table" then d.equipoNormal = {} end
	return d.equipoNormal
end
Eq.Normal = normal

local function esDePesca(enlace, ranura)
	local id = idDe(enlace)
	if not id then return false end
	if esCana(id) then return true end
	return infoPuesto(ranura, enlace).bono > 0
end

function Eq.Foto()
	for r = 1, 18 do foto[r] = puesto(r) or false end
end

-- PLAYER_EQUIPMENT_CHANGED: si entró algo de pesca, lo que estaba se recuerda.
function Eq.AlCambiar(ranura)
	ranura = tonumber(ranura)
	-- 1.3.8: también la ranura 18 (varita, arco, arma arrojadiza).
	if not ranura or ranura > 18 then return end
	local nuevo = puesto(ranura)
	local viejo = foto[ranura]
	foto[ranura] = nuevo or false
	if Eq.restaurando then return end
	local n = normal()
	if nuevo and esDePesca(nuevo, ranura) then
		if n[ranura] == nil and viejo ~= nil and not (viejo and esDePesca(viejo, ranura)) then
			n[ranura] = viejo or false
		end
	elseif (ranura == 17 or ranura == 18) and not nuevo and viejo and n[ranura] == nil then
		-- Una caña de dos manos quita lo de la otra mano: también se recuerda
		-- (1.3.8: igual con la varita o el arco que se quitó con la caña puesta).
		local cana = Eq.CanaPuesta()
		if cana then n[ranura] = viejo end
	elseif nuevo and n[ranura] ~= nil and not esDePesca(nuevo, ranura) then
		-- Te pusiste otra cosa a mano: esa ranura ya no se devuelve.
		n[ranura] = nil
	end
end

function Eq.HayNormal()
	for _ in pairs(normal()) do return true end
	return false
end

-- 1.3.8: ¿es un arma de dos manos (no una caña)? Con ella, la otra mano queda vacía.
function Eq.DosManos(enlace)
	local id = idDe(enlace)
	if not id or esCana(id) then return false end
	local lugar = instante(id)
	return lugar == "INVTYPE_2HWEAPON"
end

-- 1.3.8: ¿sigue en tus bolsas o puesto? true | false | nil (no se pueden leer las bolsas).
local function loTienes(enlace)
	local id = idDe(enlace)
	if not id then return false end
	for r = 1, 18 do if idDe(puesto(r)) == id then return true end end
	local alguna = false
	for _, b in ipairs(BOLSAS) do
		local n = ranurasDe(b)
		if n > 0 then alguna = true end
		for s = 1, n do if idDe(enlaceBolsa(b, s)) == id then return true end end
	end
	if not alguna then return nil end
	return false
end
Eq.LoTienes = loTienes

-- 1.3.8: con un arma de dos manos recordada en la derecha, la izquierda no se
-- devuelve (te la quitaría); lo que vendiste o tiraste tampoco.
local function limpiarNormal()
	local n = normal()
	if type(n[16]) == "string" and Eq.DosManos(n[16]) then n[17] = nil end
end
Eq.LimpiarNormal = limpiarNormal

-- 1.3.7: tus armas de antes (mano derecha, mano izquierda y, desde la 1.3.8,
-- la ranura 18: varita, arco o arma arrojadiza) para el botón «A pelear»: en
-- combate el juego deja cambiar las armas, no la armadura.
-- -> { { ranura, enlace, nombre } } (sin las ranuras que excluyes ni lo que ya no tienes)
function Eq.Armas()
	limpiarNormal()
	local n, out = normal(), {}
	local dos = type(n[16]) == "string" and Eq.DosManos(n[16])
	for _, r in ipairs({ 16, 17, 18 }) do
		local e = n[r]
		if type(e) == "string" and not Eq.Excluido(r) and not (r == 17 and dos) and loTienes(e) ~= false then
			local id = idDe(e)
			local nombre = Eq.Nombre(id, e) or (id and ("item:" .. id))
			if nombre then out[#out + 1] = { ranura = r, enlace = e, nombre = nombre } end
		end
	end
	return out
end

-- La macro que te pone esas armas (funciona también en combate). -> texto | nil
-- (1.3.8 revisión) Con dos armas del mismo nombre en 16 y 17, «/equipslot 17
-- Nombre» podría tomar la misma que la 16: cada una va por su bolsa y casilla
-- reales. La macro se rearma al moverse las bolsas (Pelear.lua).
local function casillasDe(id)
	local out = {}
	for _, b in ipairs(BOLSAS) do
		for s = 1, ranurasDe(b) do
			if idDe(enlaceBolsa(b, s)) == id then out[#out + 1] = { b, s } end
		end
	end
	return out
end

function Eq.MacroArmas()
	local lineas = {}
	local armas = Eq.Armas()
	local por = {} -- ranura -> { bolsa, casilla }
	local a16, a17
	for _, a in ipairs(armas) do
		if a.ranura == 16 then a16 = a elseif a.ranura == 17 then a17 = a end
	end
	if a16 and a17 and a16.nombre == a17.nombre then
		local id = idDe(a17.enlace)
		local c = id and casillasDe(id) or {}
		if #c >= 2 then por[16], por[17] = c[1], c[2]
		elseif #c == 1 and idDe(puesto(16)) == id then por[17] = c[1] end
	end
	for _, a in ipairs(armas) do
		local c = por[a.ranura]
		if c then lineas[#lineas + 1] = format("/equipslot %d %d %d", a.ranura, c[1], c[2])
		else lineas[#lineas + 1] = format("/equipslot %d %s", a.ranura, a.nombre) end
	end
	if #lineas == 0 then return nil end
	return table.concat(lineas, "\n")
end

-- ¿Queda algo que no sea arma por devolver?
function Eq.HayResto()
	for r in pairs(normal()) do if r ~= 16 and r ~= 17 and r ~= 18 then return true end end
	return false
end

local function equipar(enlace, ranura)
	local f = (C_Item and C_Item.EquipItemByName) or EquipItemByName
	if type(f) ~= "function" or not enlace then return false end
	return pcall(f, enlace, ranura)
end

-- Vuelve a poner tu equipo normal (fuera de combate). -> cuántas ranuras
function Eq.Restaurar()
	if enCombate() then
		N.FueraDeCombate(Eq.Restaurar)
		return 0
	end
	local n = normal()
	local orden = {}
	for r in pairs(n) do orden[#orden + 1] = r end
	table.sort(orden, function(a, b)
		if a == 16 then return true end
		if b == 16 then return false end
		return a < b
	end)
	if #orden == 0 or Eq.restaurando then return 0 end
	-- 1.3.8: un arma de dos manos recordada: la otra mano no se pone (te la quitaría).
	if type(n[16]) == "string" and Eq.DosManos(n[16]) and n[17] ~= nil then
		n[17] = nil
		for k = #orden, 1, -1 do if orden[k] == 17 then table.remove(orden, k) end end
	end
	Eq.restaurando = true
	-- 1.3.7: si el botón «Volver a mi equipo» (Pelear.lua) ya te puso las armas
	-- con su macro, esas no se vuelven a pedir (quedan anotadas hasta verlas puestas).
	local sinArmas = Eq.armasYa and (GetTime and GetTime() or 0) - Eq.armasYa < 3
	Eq.armasYa = nil
	local i = 0
	-- Una pieza se olvida solo cuando de verdad quedó puesta: EquipItemByName no
	-- avisa si falla (bolsas llenas para la caña de dos manos, la vendiste...).
	local function verificar()
		for _, r in ipairs(orden) do
			local e = n[r]
			if e and idDe(puesto(r)) == idDe(e) then n[r] = nil end
		end
	end
	local function siguiente()
		-- Si empieza un combate a medias, se espera a que termine sin borrar
		-- nada: la pieza sigue anotada hasta que de verdad se pone.
		if enCombate() then
			N.FueraDeCombate(siguiente)
			return
		end
		i = i + 1
		local r = orden[i]
		if not r then
			Eq.restaurando = false
			verificar()
			Eq.Foto()
			M.Avisar("equipo")
			-- El juego confirma el cambio un poco después: otra mirada.
			A.After(1, function()
				if Eq.restaurando then return end
				verificar()
				M.Avisar("equipo")
			end)
			return
		end
		local e = n[r]
		if e and loTienes(e) == false then
			-- 1.3.8: ya no lo tienes (lo vendiste o lo tiraste): se olvida.
			n[r] = nil
		elseif e and sinArmas and (r == 16 or r == 17 or r == 18) then
			-- Ya va en camino por la macro: solo se espera a que entre.
		elseif e and not Eq.Excluido(r) then
			-- Queda anotada hasta que verificar() la ve puesta; si falló, queda para la próxima.
			equipar(e, r)
		else
			n[r] = nil
		end
		-- La otra mano espera a que entre el arma.
		A.After(r == 16 and 0.6 or 0.15, siguiente)
	end
	siguiente()
	return #orden
end

-- "Ponerme lo de pesca" (tu clic, fuera de combate). -> cuántas piezas
function Eq.PonerPesca()
	if enCombate() then return 0 end
	local cambios = Eq.MejorEquipo()
	local i = 0
	local function siguiente()
		-- Si empieza un combate a medias, lo que falta se pone al salir.
		if enCombate() then
			N.FueraDeCombate(siguiente)
			return
		end
		i = i + 1
		local c = cambios[i]
		if not c then M.Avisar("equipo") return end
		equipar(c.enlace, c.ranura)
		A.After(c.ranura == 16 and 0.6 or 0.15, siguiente)
	end
	siguiente()
	return #cambios
end

-- Los juguetes y consumibles de pesca para el menú: { id, nombre, icono, cuenta, espera }
function Eq.Juguetes()
	local out, visto = {}, {}
	local t = Eq.Inventario()
	for _, j in ipairs(t.juguetes) do
		if not visto[j.id] then
			visto[j.id] = true
			out[#out + 1] = { id = j.id, nombre = Eq.Nombre(j.id, j.enlace), icono = Eq.Icono(j.id), cuenta = Eq.Cuenta(j.id), espera = Eq.Espera(j.id) }
		end
	end
	table.sort(out, function(a, b) return tostring(a.nombre or "") < tostring(b.nombre or "") end)
	return out
end

-- Los cebos para el menú: { id, nombre, icono, cuenta, bono, puede, motivo }
function Eq.Cebos()
	local out = {}
	local rango = M.Habilidad and M.Habilidad() or 0
	for _, c in ipairs(Eq.Inventario().cebos) do
		local puede = c.usable and (rango or 0) >= (c.pide or 0)
		out[#out + 1] = { id = c.id, nombre = Eq.Nombre(c.id, c.enlace), icono = Eq.Icono(c.id), cuenta = Eq.Cuenta(c.id), bono = c.bono,
			puede = puede, motivo = not puede and format(L["Pide %d de habilidad de pesca."], c.pide or 0) or nil }
	end
	table.sort(out, function(a, b) return a.bono > b.bono end)
	return out
end

-- Tu equipo de pesca (puesto y en bolsas) para el menú: { id, nombre, icono, bono, puesto, ranura }
function Eq.Lista()
	local out = {}
	for _, r in ipairs(Eq.RANURAS) do
		local b, l = Eq.BonoPuesto(r)
		local id = idDe(l)
		if id and (b > 0 or (r == 16 and esCana(id))) then
			out[#out + 1] = { id = id, nombre = Eq.Nombre(id, l), icono = Eq.Icono(id), bono = b, puesto = true, ranura = r }
		end
	end
	local t = Eq.Inventario()
	for _, c in ipairs(t.canas) do out[#out + 1] = { id = c.id, nombre = Eq.Nombre(c.id, c.enlace), icono = Eq.Icono(c.id), bono = c.bono, ranura = 16 } end
	for _, c in ipairs(t.equipo) do out[#out + 1] = { id = c.id, nombre = Eq.Nombre(c.id, c.enlace), icono = Eq.Icono(c.id), bono = c.bono } end
	return out
end

A.RegisterEvent("BAG_UPDATE_DELAYED", function() sucio = true end)
A.RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function(_, ranura) sucio = true Eq.AlCambiar(ranura) end)
-- Lo que pide un objeto (habilidad, nivel) cambia su línea roja: se vuelve a leer.
local function olvidar() sucio = true cache = {} intentos = {} end
A.RegisterEvent("SKILL_LINES_CHANGED", olvidar)
A.RegisterEvent("PLAYER_LEVEL_UP", olvidar)
A.RegisterEvent("GET_ITEM_INFO_RECEIVED", function() sucio = true end)
