-- Alfa - Mazmorras: el resumen al terminar una mazmorra (1.3.8). toxic3000 /
-- La Jauría. GPL-3.0.
--
-- Al vencer al último jefe, en vez del aviso de siempre, una tarjeta con lo
-- que fue la vuelta: el tiempo (del cronómetro, Cronometro.lua) y si es tu
-- récord, tu daño o tu curación (del medidor del juego: lo que sumaste desde
-- que entraste) y tu botín (lo poco común o mejor que te tocó, con su ícono).
--
-- Reglas:
--   * La vuelta empieza al entrar (Cronometro.lua): ahí se anota cuánto
--     llevaba el medidor (fuera de combate, legible); al final se resta. Si
--     el medidor se reinició en medio, se toma lo que diga al final.
--   * El botín sale de tus propios mensajes de botín (CHAT_MSG_LOOT con los
--     textos del juego, «Recibes botín: ...»); un texto secreto no se lee.
--   * La tarjeta solo sale fuera de combate (N.AlLibre) y se esconde sola si
--     empieza una pelea o pasan 30 s; sus dos botones son tuyos.
--   * Ajuste mazmorras.resumenFin (sí). Apagado: el aviso de siempre.
--
--   Rs.Mostrar(key, crono, veces, accion) -> true | false   Rs.Ocultar()   Rs.Marco()
--   Rs.Daño() -> dano, cura (lo del medidor ahora, o nil)

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = N.Textos(M.EN)
local D = M.D

local type, ipairs, pairs, pcall, tonumber, format, match = type, ipairs, pairs, pcall, tonumber, string.format, string.match
local max, min, floor = math.max, math.min, math.floor

local Rs = {}
M.ResumenVuelta = Rs

local ID = D.ID
local ANCHO, PAD = 380, 14
local BOTIN_MAX = 6
local SEGUNDOS = 30

local function activo() return N.Get(ID, "resumenFin") ~= false end
local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end
local function leer(v) return D.Legible(v) end

local function prog() return N.DatosPersonaje(ID) end
local function vuelta()
	local v = prog().vuelta
	return type(v) == "table" and v or nil
end

---------------------------------------------------------------------------
-- El medidor: lo tuyo en la sesión «todo» (legible fuera de combate)
---------------------------------------------------------------------------
local function tuyo(tipo)
	local C = rawget(_G, "AlfaCombate")
	if type(C) ~= "table" or type(C.LeerMedidor) ~= "function" then return nil end
	local ok, r = pcall(C.LeerMedidor, "todo", tipo, 40)
	if not ok or type(r) ~= "table" or not r.ok or r.secreto then return nil end
	for _, f in ipairs(r.filas or {}) do
		if f.yo then
			local v = leer(f.valor)
			return type(v) == "number" and v or nil
		end
	end
	return 0
end

function Rs.Dano()
	if enCombate() then return nil end
	return tuyo("dano"), tuyo("curacion")
end

-- Al empezar la vuelta: lo que llevaba el medidor (una vez por vuelta).
local function anotarInicio()
	local v = vuelta()
	if not v or v.dano0 ~= nil or enCombate() then return end
	local dano, cura = Rs.Dano()
	v.dano0, v.cura0 = dano or false, cura or false
	v.botin = type(v.botin) == "table" and v.botin or {}
end
Rs.AnotarInicio = anotarInicio

A.RegisterEvent("PLAYER_ENTERING_WORLD", function()
	-- Después del cronómetro (que espera 3 s): la vuelta ya existe.
	local f = function() N.FueraDeCombate("mazmorras.resumenInicio", anotarInicio) end
	if N.Una then N.Una("mazmorras.resumenInicio", 5, f) elseif A.After then A.After(5, f) end
end)

---------------------------------------------------------------------------
-- Tu botín de la vuelta
---------------------------------------------------------------------------
local patrones
local function esMio(texto)
	if not patrones then
		patrones = {}
		for _, g in ipairs({ "LOOT_ITEM_SELF", "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE" }) do
			local p = D.Patron(rawget(_G, g))
			if p then patrones[#patrones + 1] = p end
		end
	end
	for _, p in ipairs(patrones) do
		if texto:find(p) then return true end
	end
	return false
end

local function calidad(link)
	local Hb = M.Historial
	if Hb and Hb.Calidad then return Hb.Calidad(link) end
	return nil
end

function Rs.Anotar(texto)
	if type(texto) ~= "string" or leer(texto) == nil then return false end
	local v = vuelta()
	if not v or not esMio(texto) then return false end
	local link = match(texto, "(|c%x+|Hitem:[^|]+|h[^|]*|h|r)")
	local id = tonumber(match(texto, "|Hitem:(%d+)"))
	if not (link and id) then return false end
	v.objetos = (v.objetos or 0) + 1
	local q = calidad(link)
	if q and q >= 2 then
		v.botin = type(v.botin) == "table" and v.botin or {}
		if #v.botin < BOTIN_MAX then v.botin[#v.botin + 1] = { id = id, link = link, q = q } end
	end
	return true
end

A.RegisterEvent("CHAT_MSG_LOOT", function(_, texto)
	if D.Secreto and D.Secreto(texto) then return end
	if issecretvalue and type(texto) ~= "nil" and issecretvalue(texto) then return end
	pcall(Rs.Anotar, texto)
end)

-- Lo de la vuelta antes de que el cronómetro la cierre (Cr.Fin la borra).
local Cr = M.Crono
if Cr and Cr.Fin then
	local fin = Cr.Fin
	Cr.Fin = function(key)
		local v = vuelta()
		local copia
		if v and v.key == key then
			copia = { dano0 = v.dano0, cura0 = v.cura0, botin = v.botin, objetos = v.objetos }
		end
		local r = fin(key)
		if type(r) == "table" then r.vuelta = copia end
		return r
	end
end

---------------------------------------------------------------------------
-- La tarjeta
---------------------------------------------------------------------------
local t

local function icono(id)
	local CI = C_Item
	if CI and CI.GetItemIconByID then
		local ok, x = pcall(CI.GetItemIconByID, id)
		if ok and x then return x end
	end
	return 134400
end

local function numero(v)
	if type(v) ~= "number" then return "?" end
	if type(AbbreviateLargeNumbers) == "function" then
		local ok, s = pcall(AbbreviateLargeNumbers, floor(v + 0.5))
		if ok and type(s) == "string" then return s end
	end
	return tostring(floor(v + 0.5))
end

-- Una cifra: su número grande y su nombre abajo.
local function cifra(padre)
	local c = CreateFrame("Frame", nil, padre)
	c.Valor = K.Texto(c, "cifra", "texto")
	c.Valor:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
	c.Nombre = K.Texto(c, "pequeno", "textoTenue")
	c.Nombre:SetPoint("TOPLEFT", c.Valor, "BOTTOMLEFT", 0, -2)
	function c:Set(valor, nombre, color)
		K.Escribir(self.Valor, valor)
		K.ColorTexto(self.Valor, color or "texto")
		K.Escribir(self.Nombre, nombre)
		local w = max(K.AnchoTexto(self.Valor), K.AnchoTexto(self.Nombre))
		self:SetSize(w, K.AltoTexto(self.Valor) + 2 + K.AltoTexto(self.Nombre))
		return w
	end
	return c
end

local function construir()
	t = CreateFrame("Frame", "AlfaMazmorrasResumen", K.Raiz())
	t:SetFrameStrata("HIGH")
	t:SetClampedToScreen(true)
	t:EnableMouse(true)
	t:SetSize(ANCHO, 200)
	t:SetPoint("TOP", UIParent, "TOP", 0, -170)
	t.caja = K.Caja(t, { fondo = "panel", borde = "lineaFuerte", corte = K.CORTE.panel })
	t.Marca = K.Marca and K.Marca(t, K.CORTE.panel, "acento", 44) or nil
	t.Lobo = t:CreateTexture(nil, "ARTWORK")
	t.Lobo:SetSize(52, 52)
	t.Lobo:SetPoint("TOPLEFT", t, "TOPLEFT", PAD, -PAD)
	t.Sobre = K.Texto(t, "mayus", "acento")
	t.Sobre:SetPoint("TOPLEFT", t, "TOPLEFT", PAD + 62, -PAD - 2)
	t.Titulo = K.Texto(t, "subtitulo", "texto")
	t.Record = K.Insignia(t, "", "exito")
	t.Cifras = { cifra(t), cifra(t), cifra(t) }
	t.Botin = CreateFrame("Frame", nil, t)
	t.Botin.iconos = {}
	t.BotinTexto = K.Texto(t, "nota", "textoSuave")
	t.Cerrar = K.BotonIcono(t, "ic-cerrar", function() Rs.Ocultar() end, { tam = 24, icono = 12, ayuda = L["Cerrar"] })
	t.Cerrar:SetPoint("TOPRIGHT", t, "TOPRIGHT", -6, -6)
	t.Accion = K.Boton(t, "", function() if t.alClic then t.alClic() end Rs.Ocultar() end, { tipo = "primario", tam = "chico" })
	t:SetScript("OnEnter", function(self) self.sobre = true end)
	t:SetScript("OnLeave", function(self) self.sobre = false end)
	t:Hide()
	return t
end

local turno = 0
function Rs.Ocultar()
	turno = turno + 1
	if t then t:Hide() end
end
function Rs.Marco() return t end
function Rs.Visible() return t and t:IsShown() and true or false end

local function irseEn(seg)
	turno = turno + 1
	local mio = turno
	local function ver()
		if mio ~= turno or not (t and t:IsShown()) then return end
		if t.sobre then K.Despues(3, ver) return end
		Rs.Ocultar()
	end
	K.Despues(seg, ver)
end

-- crono = lo de Cr.Fin ({ seg, record, antes, primera, vuelta }); accion = { texto, alClic }.
local function pintar(key, crono, veces, accion)
	if not t then construir() end
	local papel = M.EnVivo and M.EnVivo.Papel and M.EnVivo.Papel() or "dano"
	t.Lobo:SetTexture(K.Lobo("aullando"))
	t.Lobo:SetVertexColor(K.Color("acento"))
	K.Escribir(t.Sobre, (veces or 1) > 1 and format(L["Vuelta %d"], veces) or L["Primera vez"])
	K.Escribir(t.Titulo, format(L["¡Completaste %s!"], D.Nombre(key) or "?"))
	local tx = PAD + 62
	local tw = ANCHO - tx - PAD - 24
	t.Titulo:ClearAllPoints()
	t.Titulo:SetPoint("TOPLEFT", t.Sobre, "BOTTOMLEFT", 0, -3)
	local hTit = K.Parrafo(t.Titulo, tw, 2)
	local y = PAD + 2 + K.AltoTexto(t.Sobre) + 3 + hTit
	-- El récord.
	local esRecord = type(crono) == "table" and crono.record
	if esRecord then
		t.Record:Set(format(L["¡Récord! Antes: %s"], N.Duracion(crono.antes)), "exito", "ic-exito")
		t.Record:ClearAllPoints()
		t.Record:SetPoint("TOPLEFT", t, "TOPLEFT", tx, -(y + 6))
		y = y + 6 + K.num(t.Record:GetHeight(), 20)
	else
		t.Record:Hide()
	end
	y = max(y, PAD + 52) + 12
	-- Las cifras: tiempo, tu daño o tu curación, el botín.
	local v = type(crono) == "table" and crono.vuelta or nil
	local dano, cura = Rs.Dano()
	local function resta(ahora, antes)
		if type(ahora) ~= "number" then return nil end
		if type(antes) == "number" and ahora >= antes then return ahora - antes end
		return ahora
	end
	dano = resta(dano, v and v.dano0)
	cura = resta(cura, v and v.cura0)
	local lista = {}
	if type(crono) == "table" and crono.seg then
		lista[#lista + 1] = { N.Duracion(crono.seg), esRecord and L["Tu tiempo (récord)"] or (crono.antes and format(L["Tu tiempo (récord: %s)"], N.Duracion(crono.antes)) or L["Tu tiempo"]), esRecord and "exito" or "texto" }
	end
	local principal = papel == "cura" and cura and cura > 0 and "cura" or "dano"
	if principal == "cura" then
		lista[#lista + 1] = { numero(cura), L["Tu curación"], "texto" }
	elseif dano and dano > 0 then
		lista[#lista + 1] = { numero(dano), L["Tu daño"], "texto" }
	end
	local botin = v and type(v.botin) == "table" and v.botin or {}
	lista[#lista + 1] = { tostring(v and v.objetos or #botin), ((v and v.objetos or #botin) == 1 and L["objeto de botín"] or L["objetos de botín"]), "texto" }
	local x = PAD
	local alto = 0
	local hueco = floor((ANCHO - 2 * PAD) / max(1, #lista))
	for i, c in ipairs(t.Cifras) do
		local d = lista[i]
		if d then
			c:Set(d[1], d[2], d[3])
			c:ClearAllPoints()
			c:SetPoint("TOPLEFT", t, "TOPLEFT", x, -y)
			-- El nombre no se sale de su hueco.
			K.Parrafo(c.Nombre, hueco - 8, 2)
			c:SetSize(hueco - 8, K.AltoTexto(c.Valor) + 2 + K.AltoTexto(c.Nombre))
			alto = max(alto, K.num(c:GetHeight(), 30))
			c:Show()
			x = x + hueco
		else
			c:Hide()
		end
	end
	y = y + alto + 10
	-- Los íconos del botín (poco común o mejor).
	local ic = t.Botin.iconos
	for i = 1, BOTIN_MAX do
		local e = botin[i]
		local b = ic[i]
		if e and not b then
			b = CreateFrame("Button", nil, t.Botin)
			b:SetSize(26, 26)
			b.Icono = b:CreateTexture(nil, "ARTWORK")
			b.Icono:SetAllPoints(b)
			b.Icono:SetTexCoord(0.07, 0.93, 0.07, 0.93)
			b:SetScript("OnEnter", function(self)
				if self.link and GameTooltip then
					GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
					pcall(GameTooltip.SetHyperlink, GameTooltip, self.link)
					GameTooltip:Show()
				end
				t.sobre = true
			end)
			b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end t.sobre = false end)
			ic[i] = b
		end
		if b then
			if e then
				b.link = e.link
				b.Icono:SetTexture(icono(e.id))
				b:ClearAllPoints()
				b:SetPoint("LEFT", t.Botin, "LEFT", (i - 1) * 30, 0)
				b:Show()
			else
				b:Hide()
			end
		end
	end
	t.Botin:ClearAllPoints()
	t.Botin:SetPoint("TOPLEFT", t, "TOPLEFT", PAD, -y)
	t.Botin:SetSize(ANCHO - 2 * PAD, 26)
	if #botin > 0 then
		t.Botin:Show()
		t.BotinTexto:Hide()
		y = y + 26 + 10
	else
		t.Botin:Hide()
		K.Escribir(t.BotinTexto, L["Esta vez no te tocó nada poco común. ¡La próxima!"])
		t.BotinTexto:ClearAllPoints()
		t.BotinTexto:SetPoint("TOPLEFT", t, "TOPLEFT", PAD, -y)
		y = y + K.Parrafo(t.BotinTexto, ANCHO - 2 * PAD, 2) + 10
	end
	-- El botón.
	t.alClic = accion and accion.alClic or nil
	if accion and accion.texto then
		t.Accion:SetTexto(accion.texto)
		t.Accion:ClearAllPoints()
		t.Accion:SetPoint("TOPRIGHT", t, "TOPRIGHT", -PAD, -y)
		t.Accion:Show()
		y = y + K.num(t.Accion:GetHeight(), 26) + PAD
	else
		t.Accion:Hide()
		y = y + PAD - 10
	end
	t:SetHeight(y)
	t:Show()
	if A.Anim and A.Anim.To then pcall(A.Anim.To, t, "alpha", 0, 1, A.Anim.FAST, "out") end
	irseEn(SEGUNDOS)
	return true
end
Rs.Pintar = pintar

function Rs.Mostrar(key, crono, veces, accion)
	if not activo() or type(key) ~= "string" then return false end
	local libre = N.AlLibre or function(_, f) f() end
	libre("mazmorras.resumen", function()
		if enCombate() then return end
		pcall(pintar, key, crono, veces, accion)
	end, 2)
	return true
end

-- Una pelea nueva: la tarjeta se va (nada que atrape clics en combate).
A.RegisterEvent("PLAYER_REGEN_DISABLED", function() if t and t:IsShown() then Rs.Ocultar() end end)
A.RegisterEvent("PLAYER_ENTERING_WORLD", function() if t and t:IsShown() then Rs.Ocultar() end end)
