-- Alfa - Inicio: la tarjeta «Para tu <clase>» (toxic3000 / La Jauría). GPL-3.0.
--
-- Tres mini tarjetas por clase y por rol, solo con datos del propio jugador
-- que el cliente deja leer, y nada que decida en combate: muestran y, con un
-- clic, abren el módulo que les toca (N.Abrir). Las de buffs usan la misma
-- lectura que los recordatorios (M.Rec.Grupo).
--
--   K.Rol() -> "cura" | "tanque" | "dano", nombre de la rama (o nil)
--   K.Tarjetas() -> { def, def, def }   def = { id, titulo, glifo, abrir, leer }
--   K.Leer(def) -> { valor, color, detalle, textura, tip }
--   K.Sucio()   -- las bolsas o el equipo cambiaron: contar de nuevo las mejoras
--
-- El rol sale de la rama del motor (Alfa.Gear.GetSpec: la columna de talentos
-- con más puntos, o la que el jugador eligió) y, sin ella, de la
-- especialización del cliente (C_SpecializationInfo). Curan: sacerdote
-- disciplina y sagrado, paladín sagrado, chamán y druida restauración.
--
-- API de Forever (Blizzard_APIDocumentationGenerated): C_UnitAuras (por
-- M.Rec), UnitPower, UnitPowerMax, UnitExists, UnitName, UnitCreatureFamily,
-- UnitUsesAmmo, UnitLevel, IsInGuild, C_PetInfo.GetPetHappiness, GetTotemInfo,
-- C_Item.GetItemCount / GetItemNameByID / GetWeaponEnchantInfo,
-- C_ClassTalents.HasUnspentTalentPoints, C_SpecializationInfo,
-- C_Container.GetContainerNumSlots / GetContainerItemLink. Globales clásicas
-- que usa el FrameXML de Forever y no están en la documentación:
-- GetInventoryItemID (EquipmentManager.lua), INVSLOT_AMMO (Constants.lua),
-- PET_HAPPINESS1..3 (PetHappiness.lua); y GetWeaponEnchantInfo() como
-- respaldo. Todo va con pcall y un valor secreto cuenta como "no se sabe".

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)
local R = M.Rec
local num, texto, miles = M.num, M.texto, M.miles

local type, ipairs, pairs, pcall, floor, max, format = type, ipairs, pairs, pcall, math.floor, math.max, string.format

local K = {}
M.Clase = K

local RAYA = "\226\128\148"
local DOT = "  \194\183  "

local function secreto(v) return issecretvalue and issecretvalue(v) end

-- Un sí del cliente (un valor secreto o un error cuentan como no).
local function si(fn, ...)
	if type(fn) ~= "function" then return false end
	local ok, v = pcall(fn, ...)
	return ok and not secreto(v) and v == true
end

local function claseJugador()
	if not UnitClass then return nil end
	local _, file = UnitClass("player")
	return texto(file)
end

local function nivel() return num(UnitLevel and UnitLevel("player")) end

local function hay(id) return N.ModuloPorId(id) ~= nil end

local function cuenta(itemID)
	local C = A.Compat
	if type(C) ~= "table" or type(C.GetItemCount) ~= "function" then return nil end
	local ok, n = pcall(C.GetItemCount, itemID)
	return ok and num(n) or nil
end

local function icono(itemID)
	local C = A.Compat
	if type(C) ~= "table" or type(C.ItemIcon) ~= "function" then return nil end
	return C.ItemIcon(itemID)
end

local function iconoHechizo(spellID)
	local C = A.Compat
	if not spellID or type(C) ~= "table" or type(C.SpellIcon) ~= "function" then return nil end
	return C.SpellIcon(spellID)
end

-- "[Nombre]" de un enlace, con el color de su calidad.
local function nombreDeEnlace(link)
	link = texto(link)
	if not link then return nil end
	local name = link:match("%[(.-)%]")
	if not name or name == "" then return nil end
	local color = link:match("^(|c%x%x%x%x%x%x%x%x)")
	return color and (color .. name .. "|r") or name
end

-- Segundos -> "Quedan 12 min 03 s" / "Sin límite de tiempo".
local function resto(seg)
	if not seg then return nil end
	if seg == math.huge then return L["Sin límite de tiempo"] end
	return format(L["Quedan %s"], N.Duracion(seg))
end

---------------------------------------------------------------------------
-- El rol
---------------------------------------------------------------------------

local CURA = { PRIEST = { discipline = true, holy = true }, PALADIN = { holy = true },
	SHAMAN = { restoration = true }, DRUID = { restoration = true } }
local TANQUE = { WARRIOR = { protection = true }, PALADIN = { protection = true } }
local ROL_CLIENTE = { HEALER = "cura", TANK = "tanque", DAMAGER = "dano" }

function K.Rol()
	local clase = claseJugador()
	local key, label, source
	local G = A.Gear
	if type(G) == "table" and type(G.GetSpec) == "function" then
		local ok, k, l, s = pcall(G.GetSpec)
		if ok then key, label, source = k, l, s end
	end
	-- Sin puntos gastados ("default") la rama es la de subir de nivel del
	-- motor: vale para el rol, pero no se muestra como si la hubieras elegido.
	local nombre
	if type(label) == "string" and label ~= "" and source ~= "custom" and source ~= "default" then
		local Lm = A.L
		local t = type(Lm) == "table" and Lm[label] or label
		nombre = ((type(t) == "string" and t or label):gsub("%s*%b()", ""))
	end
	if type(key) == "string" and source ~= "custom" then
		if CURA[clase] and CURA[clase][key] then return "cura", nombre end
		if TANQUE[clase] and TANQUE[clase][key] then return "tanque", nombre end
		return "dano", nombre
	end
	-- Sin la rama del motor: la especialización del cliente.
	local S = C_SpecializationInfo
	if S and S.GetSpecialization and S.GetSpecializationInfo then
		local ok, idx = pcall(S.GetSpecialization)
		idx = ok and num(idx) or nil
		if idx and idx > 0 then
			local ok2, _, n, _, _, role = pcall(S.GetSpecializationInfo, idx)
			-- texto() descarta los valores secretos: indexar una tabla con uno es error.
			role = ok2 and texto(role) or nil
			if role and ROL_CLIENTE[role] then return ROL_CLIENTE[role], texto(n) end
		end
	end
	return "dano", nil
end

---------------------------------------------------------------------------
-- Lecturas
---------------------------------------------------------------------------

-- Maná del jugador: actual, máximo (nil si no se sabe).
local function mana()
	if not (UnitPower and UnitPowerMax) then return nil end
	local pt = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0
	local ok, cur = pcall(UnitPower, "player", pt)
	local ok2, mx = pcall(UnitPowerMax, "player", pt)
	cur, mx = ok and num(cur) or nil, ok2 and num(mx) or nil
	if not (cur and mx and mx > 0) then return nil end
	return cur, mx
end

-- Encantamiento temporal de un arma (veneno, encantamiento de chamán):
-- { tiene, resto } para la mano principal (0) o la secundaria (1); nil si no se sabe.
-- C_Item.GetWeaponEnchantInfo(slot) devuelve una lista de WeaponEnchantInfo;
-- el respaldo es la global clásica GetWeaponEnchantInfo(). Las dos dan el
-- tiempo en milisegundos (BuffFrame.lua lo divide entre 1000; la global es
-- remainingTimeMs, Deprecated_12_1_0.lua).
local function segundos(t)
	t = num(t)
	if not t then return nil end
	return t / 1000
end

local function encantamiento(mano)
	local fn = C_Item and C_Item.GetWeaponEnchantInfo
	if fn then
		local slot = (Enum and Enum.WeaponSlot and (mano == 1 and Enum.WeaponSlot.OffHand or Enum.WeaponSlot.MainHand)) or mano
		local ok, lista = pcall(fn, slot)
		if ok and type(lista) == "table" and not secreto(lista) then
			local items = lista.hasEnchant ~= nil and { lista } or lista
			for _, e in ipairs(items) do
				if type(e) == "table" and e.hasEnchant == true then
					local tipo = num(e.enchantType)
					if tipo == nil or tipo == 2 or tipo == 3 then return { tiene = true, resto = segundos(e.timeLeft) } end
				end
			end
			return { tiene = false }
		end
	end
	if GetWeaponEnchantInfo then
		local ok, hasMH, mhExp, _, _, hasOH, ohExp = pcall(GetWeaponEnchantInfo)
		if not ok then return nil end
		if mano == 1 then
			if secreto(hasOH) then return nil end
			return { tiene = hasOH and true or false, resto = segundos(ohExp) }
		end
		if secreto(hasMH) then return nil end
		return { tiene = hasMH and true or false, resto = segundos(mhExp) }
	end
	return nil
end

local function itemEn(slot)
	if not GetInventoryItemID then return nil end
	local ok, id = pcall(GetInventoryItemID, "player", slot)
	return ok and num(id) or nil
end

local function mascota()
	return si(UnitExists, "pet")
end

---------------------------------------------------------------------------
-- Mejoras de equipo en las bolsas (con el juicio del motor: Alfa.Gear)
---------------------------------------------------------------------------

local mejoras = { sucio = true, en = -100 }

local function contarMejoras()
	mejoras.sucio = false
	mejoras.en = GetTime and GetTime() or 0
	mejoras.n, mejoras.primera, mejoras.apagado = nil, nil, false
	local G = A.Gear
	if type(G) ~= "table" or type(G.IsUpgrade) ~= "function" then return end
	if type(G.IsEnabled) == "function" and not G.IsEnabled() then
		mejoras.apagado = true
		return
	end
	local C = C_Container
	if not (C and C.GetContainerNumSlots and C.GetContainerItemLink) then return end
	local n, primera = 0, nil
	for bag = 0, tonumber(NUM_BAG_SLOTS) or 4 do
		local ok, slots = pcall(C.GetContainerNumSlots, bag)
		slots = ok and num(slots) or 0
		for slot = 1, slots do
			local ok2, link = pcall(C.GetContainerItemLink, bag, slot)
			link = ok2 and texto(link) or nil
			if link then
				local ok3, up = pcall(G.IsUpgrade, link)
				local sirve = ok3 and up == true
				if not sirve and type(G.FillsEmptySlot) == "function" then
					local ok4, f = pcall(G.FillsEmptySlot, link)
					sirve = ok4 and f == true
				end
				if sirve then
					n = n + 1
					primera = primera or link
				end
			end
		end
	end
	mejoras.n, mejoras.primera = n, primera
end

function K.Sucio() mejoras.sucio = true end

local function leerMejoras()
	local t = GetTime and GetTime() or 0
	if mejoras.sucio and t - mejoras.en >= 2 then contarMejoras() end
	return mejoras
end

A.RegisterEvent("BAG_UPDATE_DELAYED", K.Sucio)
A.RegisterEvent("PLAYER_EQUIPMENT_CHANGED", K.Sucio)
A.RegisterEvent("PLAYER_LEVEL_UP", K.Sucio)
A.On("GEAR_UPDATED", K.Sucio)

---------------------------------------------------------------------------
-- Las mini tarjetas
---------------------------------------------------------------------------

local function sinDato(detalle)
	return { valor = RAYA, color = "textMuted", detalle = detalle or L["El juego no lo dice ahora."] }
end

-- Una tarjeta de buff: g es un grupo { ids = { ... } } (M.Rec.BUFFS u otro).
-- o = { titulo (fijo), usarNombre (el nombre del hechizo del cliente),
--       falta = { valor, color, detalle }, faltaDetalle, abrir, glifo }
local function tarjetaBuff(id, grupo, o)
	o = o or {}
	return {
		id = id, glifo = o.glifo or "bolt", abrir = o.abrir or "builds",
		titulo = function()
			local g = grupo()
			if o.usarNombre and g then return R.NombreHechizo(g.ids[1]) or o.titulo end
			return o.titulo
		end,
		leer = function()
			local g = grupo()
			if not g then return nil end
			local st = R.Grupo(g)
			local r = { textura = iconoHechizo(st.id or g.ids[1]) }
			if st.estado == "ok" then
				-- Un grupo de un solo hechizo ya dice su nombre en el título.
				r.valor, r.color = (not o.usarNombre and st.activo) or L["Activo"], "success"
				local det = resto(st.resto)
				if (st.cargas or 0) > 1 then det = (det and (det .. DOT) or "") .. format(L["%d cargas"], st.cargas) end
				r.detalle = det or L["Activo"]
			elseif st.estado == "falta" then
				local f = o.falta or {}
				r.valor, r.color = f.valor or L["Te falta"], f.color or "warning"
				r.detalle = f.detalle or (type(o.faltaDetalle) == "function" and o.faltaDetalle()) or L["Lánzalo antes de pelear."]
			elseif st.estado == "noaprendido" then
				r.valor, r.color, r.detalle = L["Aún no lo aprendes"], "textMuted", L["Te lo enseña tu entrenador."]
			else
				local s = sinDato()
				s.textura = r.textura
				return s
			end
			return r
		end,
	}
end

local function buffDe(clase, i)
	return function()
		local lista = R.BUFFS and R.BUFFS[clase]
		return lista and lista[i] or nil
	end
end

local function fijo(g) return function() return g end end

-- Formas del druida y sellos del paladín: un aura del jugador cada uno.
local FORMAS = { ids = { 5487, 9634, 768, 1066, 783, 24858 } }      -- Oso, Oso temible, Felino, Acuática, Viaje, Lechúcico
local SELLOS = { ids = { 21084, 20154, 21082, 20165, 20166, 20164, 20375 } } -- Rectitud, Cruzado, Luz, Sabiduría, Justicia, Orden

local AGUA = { 5350, 2288, 2136, 3772, 8077, 8078, 8079 }
local COMIDA = { 5349, 1113, 1114, 1487, 8075, 8076, 22895 }
local FRAGMENTO = 6265

local T = {}

T.mana = {
	id = "mana", glifo = "bolt", titulo = L["Maná"],
	abrir = function() return (K.Rol() == "cura" and hay("curacion")) and "curacion" or "builds" end,
	leer = function()
		local cur, mx = mana()
		if not cur then return sinDato() end
		local pct = floor(cur / mx * 100 + 0.5)
		return { valor = format("%d%%", pct), color = (pct < 25 and "danger") or (pct < 50 and "warning") or "text",
			detalle = format(L["%s de %s"], miles(cur), miles(mx)) }
	end,
}

T.curacion = {
	id = "curacion", glifo = "plus", titulo = L["Curación"], abrir = "curacion",
	leer = function()
		local on = N.Get("curacion", "activo")
		if on == nil then return sinDato(L["El módulo Curación no está cargado."]) end
		if on then return { valor = L["Marcos encendidos"], color = "success", detalle = L["Cura a tu grupo con un clic."] } end
		return { valor = L["Marcos apagados"], color = "textMuted", detalle = L["Enciéndelos en la página Curación."] }
	end,
}

T.talentos = {
	id = "talentos", glifo = "icon-skill", titulo = L["Talentos"], abrir = "builds",
	leer = function()
		local lv = nivel()
		if lv and lv < 10 then
			return { valor = L["Desde el nivel 10"], color = "textMuted", detalle = L["Tu primer punto, en el nivel 10."] }
		end
		local _, rama = K.Rol()
		local det = rama and format(L["Tu rama: %s"], rama) or L["Tu plan está en Talentos."]
		local fn = C_ClassTalents and C_ClassTalents.HasUnspentTalentPoints
		if fn then
			local ok, v = pcall(fn)
			if ok and not secreto(v) then
				if v == true then return { valor = L["Puntos por gastar"], color = "warning", detalle = L["Talentos te dice cuál sigue."] } end
				if v == false then return { valor = L["Al día"], color = "success", detalle = det } end
			end
		end
		return { valor = L["Ver mi plan"], color = "text", detalle = det }
	end,
}

T.mejoras = {
	id = "mejoras", glifo = "qol-upgrade", titulo = L["Mejoras de equipo"],
	abrir = function() return hay("bolsas") and "bolsas" or "builds" end,
	leer = function()
		local m = leerMejoras()
		if m.apagado then return { valor = L["Apagado"], color = "textMuted", detalle = L["Consejos de equipo apagados."] } end
		if not m.n then return sinDato() end
		if m.n == 0 then return { valor = L["Nada nuevo"], color = "textMuted", detalle = L["Las marca con una flecha."] } end
		return { valor = m.n == 1 and L["1 mejora"] or format(L["%d mejoras"], m.n), color = "success",
			detalle = nombreDeEnlace(m.primera) or L["En tus bolsas"] }
	end,
}

T.municion = {
	id = "municion", glifo = "icon-buy", titulo = L["Munición"],
	abrir = function() return hay("bolsas") and "bolsas" or nil end,
	leer = function()
		if UnitUsesAmmo then
			local ok, usa = pcall(UnitUsesAmmo, "player")
			if ok and not secreto(usa) and usa == false then
				return { valor = L["No la usas"], color = "textMuted", detalle = L["Tu arma no usa munición."] }
			end
		end
		local id = itemEn(INVSLOT_AMMO or 0)
		if not id then return { valor = L["Sin munición"], color = "danger", detalle = L["Cómprala con un vendedor."] } end
		local n = cuenta(id)
		if not n then return sinDato() end
		local nombre = C_Item and C_Item.GetItemNameByID and texto((C_Item.GetItemNameByID(id)))
		return { valor = miles(n), color = (n <= 100 and "danger") or (n <= 400 and "warning") or "text",
			detalle = nombre or L["Tu munición"], textura = icono(id) }
	end,
}

local FELIZ = { "danger", "warning", "success" }
local FELIZ_TEXTO = { L["Descontenta"], L["Contenta"], L["Feliz"] }

T.mascota = {
	id = "mascota", glifo = "star", titulo = L["Tu mascota"], abrir = "builds",
	leer = function()
		if not mascota() then
			if R.Conoce(883) then return { valor = L["Sin mascota"], color = "warning", detalle = L["Llámala antes de pelear."] } end
			return { valor = L["Desde el nivel 10"], color = "textMuted", detalle = L["En el nivel 10 domas tu bestia."] }
		end
		local partes = {}
		local nombre = UnitName and texto((UnitName("pet")))
		if nombre then partes[#partes + 1] = nombre end
		local familia = UnitCreatureFamily and texto((UnitCreatureFamily("pet")))
		if familia then partes[#partes + 1] = familia end
		local det = #partes > 0 and table.concat(partes, DOT) or L["Tu compañera de caza"]
		local fn = C_PetInfo and C_PetInfo.GetPetHappiness
		local h
		if fn then
			local ok, v = pcall(fn)
			h = ok and num(v) or nil
		end
		if not (h and FELIZ[h]) then return { valor = L["Contigo"], color = "success", detalle = det } end
		local txt = _G["PET_HAPPINESS" .. h]
		local r = { valor = type(txt) == "string" and txt ~= "" and txt or FELIZ_TEXTO[h], color = FELIZ[h], detalle = det }
		if h < 3 then r.tip = { L["Dale de comer para que esté feliz: pega más fuerte."] } end
		return r
	end,
}

T.venenos = {
	id = "venenos", glifo = "icon-craft", titulo = L["Venenos"], abrir = "builds",
	leer = function()
		local lv = nivel()
		if lv and lv < 20 then return { valor = L["Desde el nivel 20"], color = "textMuted", detalle = L["En el nivel 20 aprendes venenos."] } end
		local mh = encantamiento(0)
		if not mh then return sinDato() end
		local dos = itemEn(17) ~= nil
		local oh = dos and encantamiento(1) or nil
		local puestos = (mh.tiene and 1 or 0) + (oh and oh.tiene and 1 or 0)
		local total = dos and 2 or 1
		local function linea(nom, e)
			if not e then return nil end
			local t = e.resto and (e.resto >= 60 and format(L["%d min"], floor(e.resto / 60)) or format(L["%d s"], floor(e.resto))) or L["Activo"]
			return nom .. ": " .. (e.tiene and t or RAYA)
		end
		local partes = { linea(L["Principal"], mh) }
		if dos then partes[#partes + 1] = linea(L["Secundaria"], oh) end
		local r = { detalle = table.concat(partes, DOT) }
		if puestos >= total then
			r.valor, r.color = total == 2 and L["En las dos armas"] or L["En tu arma"], "success"
		elseif puestos > 0 then
			r.valor, r.color = L["Falta en un arma"], "warning"
		else
			r.valor, r.color = L["Sin veneno"], "warning"
		end
		return r
	end,
}

T.arma = {
	id = "arma", glifo = "icon-craft", titulo = L["Arma"], abrir = "builds",
	leer = function()
		if not R.Conoce(8017) then return { valor = L["Aún no lo aprendes"], color = "textMuted", detalle = L["Te lo enseña tu entrenador."] } end
		local mh = encantamiento(0)
		if not mh then return sinDato() end
		if mh.tiene then return { valor = L["Encantada"], color = "success", detalle = resto(mh.resto) or L["Activo"], textura = iconoHechizo(8017) } end
		return { valor = L["Sin encantar"], color = "warning", detalle = L["Encanta tu arma antes de pelear."], textura = iconoHechizo(8017) }
	end,
}

T.totems = {
	id = "totems", glifo = "icon-sethome", titulo = L["Tótems"], abrir = "builds",
	leer = function()
		local conoce = R.Conoce(8071) or R.Conoce(3599) or R.Conoce(2484) or R.Conoce(5394)
		if not conoce then return { valor = L["Aún no los aprendes"], color = "textMuted", detalle = L["Te los enseña tu entrenador."] } end
		if not GetTotemInfo then return sinDato() end
		local n, nombres = 0, {}
		for slot = 1, 4 do
			local ok, tiene, nombre = pcall(GetTotemInfo, slot)
			if ok and not secreto(tiene) and tiene == true then
				n = n + 1
				nombre = texto(nombre)
				if nombre and nombre ~= "" then nombres[#nombres + 1] = nombre end
			end
		end
		if n == 0 then return { valor = L["Ninguno puesto"], color = "text", detalle = L["Ponlos al empezar a pelear."] } end
		return { valor = n == 1 and L["1 tótem puesto"] or format(L["%d tótems puestos"], n), color = "success",
			detalle = #nombres > 0 and table.concat(nombres, ", ") or L["Activo"] }
	end,
}

T.conjurado = {
	id = "conjurado", glifo = "qol-coin", titulo = L["Agua y comida"],
	abrir = function() return hay("bolsas") and "bolsas" or nil end,
	leer = function()
		if not (R.Conoce(5504) or R.Conoce(587)) then
			return { valor = L["Aún no lo aprendes"], color = "textMuted", detalle = L["Te lo enseña tu entrenador."] }
		end
		local agua, comida, tex = 0, 0, nil
		for _, id in ipairs(AGUA) do
			local n = cuenta(id) or 0
			agua = agua + n
			if n > 0 and not tex then tex = icono(id) end
		end
		for _, id in ipairs(COMIDA) do comida = comida + (cuenta(id) or 0) end
		return { valor = format(L["%d agua · %d comida"], agua, comida),
			color = (agua == 0 and comida == 0) and "warning" or "text",
			detalle = L["Conjúralas fuera de combate."], textura = tex or icono(AGUA[1]) }
	end,
}

T.fragmentos = {
	id = "fragmentos", glifo = "icon-collect", titulo = L["Fragmentos de alma"],
	abrir = function() return hay("bolsas") and "bolsas" or nil end,
	leer = function()
		local n = cuenta(FRAGMENTO)
		if not n then return sinDato() end
		local r = { valor = n == 1 and L["1 fragmento"] or format(L["%d fragmentos"], n), color = "text",
			detalle = L["Drenar alma al rematar te da uno."], textura = icono(FRAGMENTO) }
		if n == 0 then r.color = R.Conoce(1120) and "warning" or "textMuted" end
		return r
	end,
}

T.demonio = {
	id = "demonio", glifo = "star", titulo = L["Tu demonio"], abrir = "builds",
	leer = function()
		if not mascota() then
			if R.Conoce(688) then return { valor = L["Sin demonio"], color = "warning", detalle = L["Invócalo antes de pelear."], textura = iconoHechizo(688) } end
			return { valor = L["Aún no lo aprendes"], color = "textMuted", detalle = L["Te lo enseña tu entrenador."] }
		end
		local familia = UnitCreatureFamily and texto((UnitCreatureFamily("pet")))
		local nombre = UnitName and texto((UnitName("pet")))
		return { valor = familia or nombre or L["Contigo"], color = "success", detalle = (familia and nombre) and nombre or L["Contigo"] }
	end,
}

T.grito = tarjetaBuff("grito", buffDe("WARRIOR", 1), {
	titulo = L["Grito de batalla"], usarNombre = true,
	faltaDetalle = function()
		if R.Furia() < 10 then return L["Con 10 de furia o más lo lanzas."] end
		return L["Más poder de ataque para tu grupo."]
	end,
})
T.intelecto = tarjetaBuff("intelecto", buffDe("MAGE", 1), { titulo = L["Intelecto Arcano"], usarNombre = true })
T.armaduraMago = tarjetaBuff("armaduraMago", buffDe("MAGE", 2), { titulo = L["Armadura"] })
T.entereza = tarjetaBuff("entereza", buffDe("PRIEST", 1), { titulo = L["Entereza"], usarNombre = true })
T.fuegoInterno = tarjetaBuff("fuegoInterno", buffDe("PRIEST", 2), { titulo = L["Fuego interno"], usarNombre = true })
T.marca = tarjetaBuff("marca", buffDe("DRUID", 1), { titulo = L["Marca de lo Salvaje"], usarNombre = true })
T.pielDemoniaca = tarjetaBuff("pielDemoniaca", buffDe("WARLOCK", 1), { titulo = L["Piel o armadura demoníaca"] })
T.aura = tarjetaBuff("aura", buffDe("PALADIN", 1), { titulo = L["Aura"] })
T.bendicion = tarjetaBuff("bendicion", buffDe("PALADIN", 2), { titulo = L["Bendición"] })
T.aspecto = tarjetaBuff("aspecto", buffDe("HUNTER", 1), { titulo = L["Aspecto"] })
T.escudo = tarjetaBuff("escudo", buffDe("SHAMAN", 1), { titulo = L["Escudo de relámpagos"], usarNombre = true })
T.forma = tarjetaBuff("forma", fijo(FORMAS), {
	titulo = L["Forma"], glifo = "icon-mount",
	falta = { valor = L["Forma normal"], color = "text", detalle = L["Sin cambiar de forma."] },
})
T.sello = tarjetaBuff("sello", fijo(SELLOS), {
	titulo = L["Sello"],
	falta = { valor = L["Sin sello"], color = "textMuted", detalle = L["Lo pones al empezar a pelear."] },
})

K.T = T

-- Las tres de cada clase; `cura`: las de quien cura (con el módulo Curación).
local POR_CLASE = {
	WARRIOR = { T.grito, T.talentos, T.mejoras },
	PALADIN = { T.aura, T.sello, T.bendicion }, PALADIN_cura = { T.curacion, T.mana, T.aura },
	HUNTER = { T.municion, T.mascota, T.aspecto },
	ROGUE = { T.venenos, T.talentos, T.mejoras },
	PRIEST = { T.entereza, T.fuegoInterno, T.mana }, PRIEST_cura = { T.curacion, T.mana, T.entereza },
	SHAMAN = { T.totems, T.escudo, T.mana }, SHAMAN_cura = { T.curacion, T.mana, T.totems },
	MAGE = { T.conjurado, T.intelecto, T.armaduraMago },
	WARLOCK = { T.fragmentos, T.demonio, T.pielDemoniaca },
	DRUID = { T.forma, T.marca, T.mana }, DRUID_cura = { T.curacion, T.mana, T.marca },
}

function K.Tarjetas()
	local clase = claseJugador()
	if not clase then return {} end
	local rol = K.Rol()
	if rol == "cura" and hay("curacion") and POR_CLASE[clase .. "_cura"] then return POR_CLASE[clase .. "_cura"] end
	-- El chamán de mejora pelea con su arma encantada.
	if clase == "SHAMAN" then
		local G = A.Gear
		local ok, key = false, nil
		if type(G) == "table" and type(G.GetSpec) == "function" then ok, key = pcall(G.GetSpec) end
		if ok and key == "enhancement" then return { T.totems, T.escudo, T.arma } end
	end
	return POR_CLASE[clase] or { T.talentos, T.mejoras, T.mana }
end

function K.Titulo(def)
	local t = def.titulo
	if type(t) == "function" then t = t() end
	return type(t) == "string" and t or ""
end

-- El módulo que abre una tarjeta (nil si no está cargado).
function K.Destino(def)
	local d = def.abrir
	if type(d) == "function" then d = d() end
	if type(d) == "string" and hay(d) then return d end
	return nil
end

function K.Leer(def)
	local ok, r = pcall(def.leer)
	if ok and type(r) == "table" then return r end
	return sinDato()
end
