-- Alfa - Enciclopedia: el cuadro de un objeto al pasar el ratón y el menú del
-- clic derecho (1.3.7, toxic3000 / La Jauría). GPL-3.0.
--
-- Antes el cuadro del juego salía en cuanto el ratón tocaba una fila, con las
-- dos comparaciones del equipo puesto: tres cuadros tapando la lista. Ahora:
--   * sale después de un rato con el ratón quieto (ajuste enciclopedia.cuadro:
--     "ya", "corto", "normal" (0,6 s, de fábrica), "largo" o "nunca");
--   * sin comparaciones: es un cuadro propio (AlfaEnciclopediaCuadro, del
--     molde del juego, sin la comparación automática). Con Mayús sale el del
--     juego, que compara solo, como en tus bolsas;
--   * clic derecho: un menú con Comparar con mi equipo, Comparar con…, Ver
--     ficha, Guíame, Agregar a mi lista de compras y Vincular en el chat.
-- Nada de esto toca funciones protegidas: la comparación de Alfa son cuadros
-- propios (SetInventoryItem / SetBagItem / SetHyperlink), no la del juego.
--
--   Cu.Entrar(dueno, que)  que = { item = id, ancla } | { spell = id } | { titulo, texto }
--   Cu.Salir(dueno), Cu.Cerrar(), Cu.Estado() -> { pendiente, abierto, conMayus, fijo, cuadros }
--   Cu.Menu(kind, id, o)   o = { verFicha = fn, inv = número de ranura del catálogo, dueno = la fila }
--   Cu.Comparar(id, piezas, dueno), Cu.Piezas(id, inv) -> { { puesto = ranura } | { bolsa, ranura }, ... }

local ADDON, M = ...
local N, A, K, L = M.N, M.A, M.K, M.L
local F = M.F
local Cu = {}
M.Cuadro = Cu

local type, tonumber, tostring, ipairs, pairs, pcall, select = type, tonumber, tostring, ipairs, pairs, pcall, select
local abs, min, format = math.abs, math.min, string.format

local CLAVE = "enciclopedia.cuadro"
local CLAVE_VIGIA = "enciclopedia.cuadroVigia"
local CLAVE_FIJO = "enciclopedia.cuadroFijo"
local NOMBRE = "AlfaEnciclopediaCuadro"
local FIJO_SEG = 30 -- lo que pediste comparar se queda hasta que tocas otra fila (o esto)

---------------------------------------------------------------------------
-- El retraso
---------------------------------------------------------------------------
Cu.RETRASOS = { ya = 0, corto = 0.3, normal = 0.6, largo = 1, nunca = false }
Cu.OPCIONES = {
	{ valor = "ya", texto = L["Al instante"] },
	{ valor = "corto", texto = L["Rápido (0,3 s)"] },
	{ valor = "normal", texto = L["Normal (0,6 s)"] },
	{ valor = "largo", texto = L["Con calma (1 s)"] },
	{ valor = "nunca", texto = L["Solo con Mayús o clic derecho"] },
}

-- -> segundos, o false (no sale solo)
function Cu.Retraso()
	local v = N.Get(M.ID, "cuadro")
	local r = Cu.RETRASOS[v]
	if r == nil then r = Cu.RETRASOS.normal end
	return r
end

local function conMayus()
	if IsShiftKeyDown and IsShiftKeyDown() then return true end
	return false
end

local function cursor()
	if not GetCursorPosition then return 0, 0 end
	local x, y = GetCursorPosition()
	return tonumber(x) or 0, tonumber(y) or 0
end

---------------------------------------------------------------------------
-- Los cuadros: el propio (sin comparación automática) y dos para comparar
---------------------------------------------------------------------------
local function sirve(t) return type(t) == "table" and type(t.SetOwner) == "function" and type(t.SetHyperlink) == "function" end

local cuadros = {}
local function cuadro(n)
	n = n or 1
	if cuadros[n] ~= nil then return cuadros[n] or nil end
	local nombre = n == 1 and NOMBRE or (NOMBRE .. "Compara" .. (n - 1))
	local t = rawget(_G, nombre)
	if not t then
		local ok, f = pcall(CreateFrame, "GameTooltip", nombre, UIParent, "GameTooltipTemplate")
		t = ok and f or nil
	end
	if sirve(t) then
		if t.SetFrameStrata then t:SetFrameStrata("TOOLTIP") end
		if t.SetClampedToScreen then t:SetClampedToScreen(true) end
		cuadros[n] = t
	else
		cuadros[n] = false -- sin el molde del juego: el cuadro del juego, con las comparaciones escondidas
	end
	return cuadros[n] or nil
end
Cu.Cuadro = cuadro

-- Los cuadros de comparación del juego (ShoppingTooltip1/2).
local function deCompra()
	local tip = rawget(_G, "GameTooltip")
	local l = type(tip) == "table" and type(rawget(tip, "shoppingTooltips")) == "table" and tip.shoppingTooltips or nil
	if l then return l end
	return { rawget(_G, "ShoppingTooltip1"), rawget(_G, "ShoppingTooltip2") }
end

local function compraVisible()
	for _, s in pairs(deCompra()) do
		if type(s) == "table" and s.IsShown and s:IsShown() then return true end
	end
	return false
end

local function esconderCompra()
	for _, s in pairs(deCompra()) do
		if type(s) == "table" and s.IsShown and s:IsShown() and s.Hide then s:Hide() end
	end
end

local pend -- lo que está bajo el ratón: { dueno, que, abierto, mayus, usaJuego, x, y, veces }
local fijo = false -- lo que pediste comparar (Cu.Comparar) se queda hasta que sale otro cuadro
local vig  -- escucha Mayús mientras hay algo

local function esconderCuadros()
	for n = 1, 3 do
		local t = cuadros[n]
		if t and t.Hide then t:Hide() end
	end
end

-- Esconde lo que abrió `dueno` (el cuadro propio, el del juego si es suyo y su info).
local function esconderDe(dueno)
	esconderCuadros()
	local tip = rawget(_G, "GameTooltip")
	if dueno and tip and tip.GetOwner and tip:GetOwner() == dueno then
		tip:Hide()
		esconderCompra()
	end
	if dueno then K.OcultarInfo(dueno) end
end

-- Suelta lo que pediste comparar.
function Cu.Soltar()
	if not fijo then return end
	fijo = false
	N.Quitar(CLAVE_FIJO)
	esconderCuadros()
end

local function vigilar(on)
	if not vig then
		vig = CreateFrame("Frame")
		vig:SetScript("OnEvent", function(_, _, tecla)
			if not pend then return end
			if type(tecla) == "string" and not tecla:find("SHIFT", 1, true) then return end
			local m = conMayus()
			if (pend.abierto and m ~= pend.mayus) or (not pend.abierto and m) then Cu.Abrir(m) end
		end)
	end
	if on then vig:RegisterEvent("MODIFIER_STATE_CHANGED") else vig:UnregisterEvent("MODIFIER_STATE_CHANGED") end
end

-- Mientras se ve el cuadro sin Mayús, las comparaciones del juego no salen
-- (por si otro cuadro del juego las abre: el ajuste «comparar siempre»).
local function vigia()
	if pend and pend.abierto and not pend.mayus and pend.usaJuego then
		if compraVisible() then esconderCompra() end
		return
	end
	N.Quitar(CLAVE_VIGIA)
end

local function pintar(p, mayus)
	local que, dueno = p.que, p.dueno
	Cu.Soltar()
	esconderDe(dueno)
	p.usaJuego = nil
	if que.item or que.spell then
		local tip = (not mayus) and cuadro(1) or nil
		if not tip then
			tip = rawget(_G, "GameTooltip")
			p.usaJuego = true
		end
		if not sirve(tip) then return end
		tip:SetOwner(dueno, que.ancla or "ANCHOR_RIGHT")
		if que.item then
			tip:SetHyperlink("item:" .. tostring(que.item))
		elseif tip.SetSpellByID then
			if not pcall(tip.SetSpellByID, tip, que.spell) then tip:Hide() return end
		end
		tip:Show()
		p.tip = tip
		-- Sin Mayús y con el cuadro del juego (sin molde propio): nada de comparar.
		if p.usaJuego and not mayus then
			esconderCompra()
			N.Cada(CLAVE_VIGIA, 0.1, vigia)
		end
	elseif (que.titulo and que.titulo ~= "") or (que.texto and que.texto ~= "") then
		K.MostrarInfo(dueno, que.titulo, que.texto)
	end
	p.abierto, p.mayus = true, mayus and true or false
end

function Cu.Abrir(mayus)
	if not pend then return end
	N.Quitar(CLAVE)
	if mayus == nil then mayus = conMayus() end
	pintar(pend, mayus)
end

local function esperar()
	local p = pend
	if not p then return end
	if p.dueno.IsVisible and not p.dueno:IsVisible() then return Cu.Salir() end
	-- Quieto: si el ratón se siguió moviendo, un poco más (pasar por la lista no abre nada).
	local x, y = cursor()
	if p.x and (abs(x - p.x) > 6 or abs(y - p.y) > 6) and (p.veces or 0) < 8 then
		p.x, p.y, p.veces = x, y, (p.veces or 0) + 1
		N.Una(CLAVE, 0.25, esperar)
		return
	end
	Cu.Abrir()
end

-- El ratón entró en una fila.
function Cu.Entrar(dueno, que)
	Cu.Salir()
	if not (dueno and type(que) == "table") then return end
	if not (que.item or que.spell or (que.titulo and que.titulo ~= "") or (que.texto and que.texto ~= "")) then return end
	pend = { dueno = dueno, que = que }
	vigilar(true)
	if conMayus() then return Cu.Abrir(true) end
	local r = Cu.Retraso()
	if r == false then return end
	if r <= 0 then return Cu.Abrir(false) end
	pend.x, pend.y = cursor()
	N.Una(CLAVE, r, esperar)
end

-- El ratón salió de la fila (lo que pediste comparar se queda).
function Cu.Salir(dueno)
	if dueno and pend and pend.dueno ~= dueno then return end
	N.Quitar(CLAVE)
	N.Quitar(CLAVE_VIGIA)
	local p = pend
	pend = nil
	vigilar(false)
	if p and p.abierto then esconderDe(p.dueno) end
end

-- Todo fuera (al cerrar la ventana o abrir el menú).
function Cu.Cerrar()
	Cu.Salir()
	Cu.Soltar()
end

-- Para el banco de pruebas.
function Cu.Estado()
	local p = pend
	local abiertos = {}
	for n = 1, 3 do
		local t = cuadros[n]
		abiertos[n] = t and t.IsShown and t:IsShown() and true or false
	end
	return { pendiente = p ~= nil and not p.abierto, abierto = p ~= nil and p.abierto == true, conMayus = p and p.mayus or false,
		fijo = fijo, usaJuego = p and p.usaJuego or false, cuadros = abiertos, comparaJuego = compraVisible() }
end

---------------------------------------------------------------------------
-- Comparar: tus piezas de la misma ranura
---------------------------------------------------------------------------
-- La ranura del objeto (su equipLoc del juego) -> las de tu personaje.
local RANURAS = {
	INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 },
	INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
	INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 },
	INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16, 17 }, INVTYPE_SHIELD = { 17 },
	INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 },
	INVTYPE_HOLDABLE = { 17 }, INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 },
	INVTYPE_RELIC = { 18 }, INVTYPE_TABARD = { 19 },
}
-- El número de ranura del catálogo (Enum.InventoryType) -> su equipLoc.
local POR_NUMERO = { [1] = "INVTYPE_HEAD", [2] = "INVTYPE_NECK", [3] = "INVTYPE_SHOULDER", [4] = "INVTYPE_BODY",
	[5] = "INVTYPE_CHEST", [6] = "INVTYPE_WAIST", [7] = "INVTYPE_LEGS", [8] = "INVTYPE_FEET", [9] = "INVTYPE_WRIST",
	[10] = "INVTYPE_HAND", [11] = "INVTYPE_FINGER", [12] = "INVTYPE_TRINKET", [13] = "INVTYPE_WEAPON",
	[14] = "INVTYPE_SHIELD", [15] = "INVTYPE_RANGED", [16] = "INVTYPE_CLOAK", [17] = "INVTYPE_2HWEAPON",
	[19] = "INVTYPE_TABARD", [20] = "INVTYPE_ROBE", [21] = "INVTYPE_WEAPONMAINHAND", [22] = "INVTYPE_WEAPONOFFHAND",
	[23] = "INVTYPE_HOLDABLE", [25] = "INVTYPE_THROWN", [26] = "INVTYPE_RANGEDRIGHT", [28] = "INVTYPE_RELIC" }
Cu.RANURAS = RANURAS

local function equipLoc(id, inv)
	local CI = C_Item
	local loc
	if CI and type(CI.GetItemInfoInstant) == "function" and id then
		local ok, _, _, _, l = pcall(CI.GetItemInfoInstant, id)
		if ok and type(l) == "string" and l ~= "" then loc = l end
	end
	if not loc and type(inv) == "number" then loc = POR_NUMERO[inv] end
	return loc
end
Cu.EquipLoc = equipLoc

local function seCruzan(a, b)
	for _, x in ipairs(a) do for _, y in ipairs(b) do if x == y then return true end end end
	return false
end

local function contenedor()
	local CC = C_Container
	if type(CC) == "table" and type(CC.GetContainerNumSlots) == "function" and type(CC.GetContainerItemInfo) == "function" then return CC end
	return nil
end

-- Tus piezas que van en la misma ranura: las puestas primero, luego las de tus bolsas.
function Cu.Piezas(id, inv)
	local loc = equipLoc(id, inv)
	local ranuras = loc and RANURAS[loc]
	local out = {}
	if not ranuras then return out, false end
	for _, r in ipairs(ranuras) do
		local link = GetInventoryItemLink and GetInventoryItemLink("player", r)
		if type(link) == "string" and link ~= "" then out[#out + 1] = { puesto = r, link = link } end
	end
	local CC = contenedor()
	if CC then
		local ultima = (tonumber(rawget(_G, "NUM_BAG_SLOTS")) or 4)
		for b = 0, ultima do
			local ok, n = pcall(CC.GetContainerNumSlots, b)
			for s = 1, (ok and tonumber(n) or 0) do
				local ok2, info = pcall(CC.GetContainerItemInfo, b, s)
				if ok2 and type(info) == "table" and info.itemID and info.itemID ~= id then
					local l2 = equipLoc(info.itemID)
					local r2 = l2 and RANURAS[l2]
					if r2 and seCruzan(r2, ranuras) then
						out[#out + 1] = { bolsa = b, ranura = s, link = info.hyperlink, id = info.itemID }
						if #out >= 20 then return out, true end
					end
				end
			end
		end
	end
	return out, true
end

local function nombrePieza(p)
	local link = p.link
	local nombre = type(link) == "string" and link:match("%[(.-)%]") or nil
	if not nombre and p.id then nombre = M.Nombre("item", p.id) end
	return nombre or "?", type(link) == "string" and link:match("^(|c%x%x%x%x%x%x%x%x)") or nil
end

-- Pone el cuadro del objeto y, al lado, tus piezas (hasta dos).
function Cu.Comparar(id, piezas, dueno)
	dueno = dueno or (pend and pend.dueno)
	local tip1 = cuadro(1)
	if not tip1 then
		-- Sin cuadros propios: el del juego con Mayús es la comparación.
		Cu.Cerrar()
		return false
	end
	Cu.Cerrar()
	fijo = true
	if dueno then tip1:SetOwner(dueno, "ANCHOR_RIGHT") else tip1:SetOwner(UIParent, "ANCHOR_CURSOR") end
	tip1:SetHyperlink("item:" .. tostring(id))
	tip1:Show()
	local derecha = true
	local W = K.num(UIParent and UIParent:GetWidth(), 1920)
	local r = tip1.GetRight and K.num(tip1:GetRight(), 0) or 0
	if r > W * 0.62 then derecha = false end
	local previo = tip1
	for n = 1, min(2, #(piezas or {})) do
		local p = piezas[n]
		local t = cuadro(n + 1)
		if t then
			t:SetOwner(tip1, "ANCHOR_NONE")
			t:ClearAllPoints()
			if derecha then t:SetPoint("TOPLEFT", previo, "TOPRIGHT", 4, 0) else t:SetPoint("TOPRIGHT", previo, "TOPLEFT", -4, 0) end
			local ok = false
			if p.puesto and t.SetInventoryItem then ok = pcall(t.SetInventoryItem, t, "player", p.puesto) end
			if not ok and p.bolsa and t.SetBagItem then ok = pcall(t.SetBagItem, t, p.bolsa, p.ranura) end
			if not ok and p.link then ok = pcall(t.SetHyperlink, t, p.link) end
			if ok then
				if t.AddLine then
					t:AddLine(" ")
					t:AddLine(p.puesto and L["Lo que llevas puesto"] or L["En tus bolsas"], 0.55, 0.88, 0.31)
				end
				t:Show()
				previo = t
			end
		end
	end
	N.Una(CLAVE_FIJO, FIJO_SEG, function() Cu.Soltar() end)
	return true
end

---------------------------------------------------------------------------
-- El menú del clic derecho
---------------------------------------------------------------------------
local ancla
local function anclaEnCursor()
	if not ancla then
		ancla = CreateFrame("Frame", nil, UIParent)
		ancla:SetSize(1, 1)
	end
	local x, y = K.CursorEnUI() -- (1.3.8 revisión: con el escritorio movido, igual)
	ancla:ClearAllPoints()
	ancla:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
	ancla:Show()
	return ancla
end

local function aviso(ok, texto)
	if not texto then return end
	K.Aviso({ titulo = ok and L["Listo"] or L["No se pudo"], texto = texto, icono = ok and "ic-exito" or "ic-aviso",
		tono = ok and "acento" or "aviso", duracion = ok and 4 or 6 })
end

local function menuPiezas(id, piezas, dueno)
	local ops = {}
	for _, p in ipairs(piezas) do
		local nombre, color = nombrePieza(p)
		local donde = p.puesto and L["puesto"] or L["en tus bolsas"]
		ops[#ops + 1] = { valor = #ops + 1, texto = (color and (color .. nombre .. "|r") or nombre) .. M.SEP .. donde,
			icono = p.puesto and "ic-personajes" or "ic-bolsas", pieza = p }
	end
	K.Menu(anclaEnCursor(), ops, nil, function(_, o) if o and o.pieza then Cu.Comparar(id, { o.pieza }, dueno) end end, 220)
	return ops
end

-- -> la lista de opciones (para el banco); abre el menú junto al ratón.
function Cu.Opciones(kind, id, o)
	o = o or {}
	local ops = {}
	local esObjeto = M.ES_OBJETO[kind] and true or false
	local piezas, equipable = {}, false
	if esObjeto then piezas, equipable = Cu.Piezas(id, o.inv) end
	if equipable then
		local puestas = {}
		for _, p in ipairs(piezas) do if p.puesto then puestas[#puestas + 1] = p end end
		ops[#ops + 1] = { valor = "equipo", texto = L["Comparar con mi equipo"], icono = "ic-personajes",
			apagada = #puestas == 0, motivo = L["No llevas nada puesto en esa ranura."],
			fn = function() Cu.Comparar(id, puestas, o.dueno) end }
		ops[#ops + 1] = { valor = "con", texto = L["Comparar con…"], icono = "ic-bolsas",
			apagada = #piezas == 0, motivo = L["No tienes piezas de esa ranura, ni puestas ni en tus bolsas."],
			fn = function() menuPiezas(id, piezas, o.dueno) end }
		ops[#ops + 1] = { separador = true }
	end
	if o.verFicha then
		ops[#ops + 1] = { valor = "ficha", texto = L["Ver ficha"], icono = "ic-enciclopedia", fn = o.verFicha }
	end
	-- Lo demás sale de la ficha (lo mismo que sus botones).
	local okF, f = pcall(F.Construir, kind, id)
	local a = okF and type(f) == "table" and f.acciones or {}
	ops[#ops + 1] = { valor = "guiar", texto = L["Guíame"], icono = "ic-seguir", apagada = a.guiar == nil,
		motivo = L["Alfa no conoce un camino que pueda guiar para esto."],
		fn = function() local ok, msg = a.guiar() aviso(ok, msg) end }
	if esObjeto then
		ops[#ops + 1] = { valor = "compra", texto = L["Agregar a mi lista de compras"], icono = "ic-oro", apagada = a.compra == nil,
			motivo = L["La lista de compras es de Comercio: actívalo para usarla."],
			fn = function()
				local ok, r = pcall(a.compra)
				if ok and r ~= false then aviso(true, L["Está en tu lista de compras."])
				elseif not ok then aviso(false, L["Tu lista de compras no pudo agregarlo."]) end
			end }
	end
	local vincular = a.vincular or ((esObjeto or kind == "quest") and function() return F.Vincular(esObjeto and "item" or kind, id) end) or nil
	if vincular then
		ops[#ops + 1] = { valor = "vincular", texto = L["Vincular en el chat"], icono = "ic-mas",
			fn = function() local ok, msg = vincular() if not ok then aviso(false, msg) end end }
	end
	return ops
end

function Cu.Menu(kind, id, o)
	if not (kind and id) then return nil end
	Cu.Cerrar()
	-- En combate, nada que atrape clics (el menú pone una capa en toda la pantalla).
	if InCombatLockdown and InCombatLockdown() then
		aviso(false, L["Se puede al salir de combate."])
		return nil
	end
	local ops = Cu.Opciones(kind, id, o)
	K.Menu(anclaEnCursor(), ops, nil, function(_, op) if op and op.fn then K.Llamar(op.fn) end end, 200)
	return ops
end
