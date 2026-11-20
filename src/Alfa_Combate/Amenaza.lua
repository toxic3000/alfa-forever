-- Alfa - Combate: tu amenaza (toxic3000 / La Jauría). GPL-3.0.
--
-- 1.3.0. Una barra pequeña con tu amenaza sobre tu objetivo, en combate y
-- cuando importa (en grupo o con mascota: solo, siempre eres tú). Avisa
--   * si no eres tanque: antes de quitarle la atención al tanque
--     (combate.amenazaAviso, 80 % de fábrica) y cuando ya te ataca a ti;
--   * si eres tanque: cuando están por quitártelo y cuando lo perdiste.
-- Con UnitDetailedThreatSituation("player", "target") (UnitDocumentation):
-- isTanking, status (0 a 3) y scaledPercentage. Si el juego los oculta
-- (secretos), la barra los muestra tal cual (StatusBar:SetValue los acepta)
-- y no se avisa: no se comparan.
-- Tu papel: el de tu grupo si lo marcaste; si no, tu actitud o forma
-- (actitud defensiva, oso) o Furia justa del paladín; o el que elijas.
-- Se repinta con los eventos de amenaza, juntados (como mucho 5 por segundo).
-- Nada recibe el ratón.

local ADDON, M = ...
local N, A, K, L = M.N, M.A, M.K, M.L
local Am = {}
M.Amenaza = Am

local type, pcall, floor, max, min, format, tonumber = type, pcall, math.floor, math.max, math.min, string.format, tonumber
local ESP = K.ESP
local ANCHO, ALTO = 180, 14

Am.PAPELES = {
	{ clave = "auto", texto = L["Automático"] },
	{ clave = "tanque", texto = L["Tanque"] },
	{ clave = "dano", texto = L["Daño o curas"] },
}

local FURIA_JUSTA = 25780

-- -> "tanque" | "dano"
function Am.Papel()
	local p = M.Opt("amenazaPapel")
	if p == "tanque" or p == "dano" then return p end
	local rol = M.Legible(M.Llamar(UnitGroupRolesAssigned, "player"))
	if rol == "TANK" then return "tanque" end
	if rol == "DAMAGER" or rol == "HEALER" then return "dano" end
	local clase = M.Clase()
	local forma = M.Legible(M.Llamar(rawget(_G, "GetShapeshiftFormID")))
	if clase == "WARRIOR" and forma == 18 then return "tanque" end
	if clase == "DRUID" and (forma == 5 or forma == 8) then return "tanque" end
	if clase == "PALADIN" then
		local n = M.NombreHechizo(FURIA_JUSTA)
		local fn = C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
		if n and fn then
			local aura = M.Llamar(fn, "player", n)
			if M.Secreto(aura) or type(aura) == "table" then return "tanque" end
		end
	end
	return "dano"
end

-- ¿Importa ahora? En combate, con un enemigo elegido, en grupo o con mascota.
function Am.Importa()
	if not M.EnCombate() or not M.HayEnemigo() then return false end
	if IsInGroup and IsInGroup() then return true end
	return M.Legible(M.Llamar(UnitExists, "pet")) == true
end

-- -> { pct (número o secreto), estado ("bien" | "cerca" | "tuya" | "perdida" |
--    "riesgo" | nil si no se puede leer), tanque }
function Am.Leer()
	local tanque = Am.Papel() == "tanque"
	local atacando, status, pct = M.Llamar(UnitDetailedThreatSituation, "player", "target")
	local r = { pct = pct, tanque = tanque }
	if M.Secreto(atacando) or M.Secreto(status) or M.Secreto(pct) then
		-- 1.3.3: contra un jefe el detalle llega secreto, pero tu estado (0 a 3)
		-- con UnitThreatSituation("player", "target") en general no: con él se
		-- pinta y se avisa, aunque no haya porcentaje (r.sinPct).
		local st = M.Legible(M.Llamar(UnitThreatSituation, "player", "target"))
		if type(st) ~= "number" then return r end
		r.sinPct = true
		if tanque then
			if st >= 3 then r.estado = "bien"
			elseif st == 2 then r.estado = "riesgo"
			else r.estado = "perdida" end
		else
			if st >= 2 then r.estado = "tuya"
			elseif st == 1 then r.estado = "cerca"
			else r.estado = "bien" end
		end
		return r
	end
	if status == nil and pct == nil then r.vacia = true return r end
	status = tonumber(status) or 0
	pct = tonumber(pct) or 0
	r.pct = pct
	if tanque then
		if status >= 3 then r.estado = "bien"
		elseif status == 2 then r.estado = "riesgo"
		else r.estado = "perdida" end
	else
		local aviso = max(50, min(100, tonumber(M.Opt("amenazaAviso")) or 80))
		if atacando == true or status >= 2 then r.estado = "tuya"
		elseif status == 1 or pct >= aviso then r.estado = "cerca"
		else r.estado = "bien" end
	end
	return r
end

local TONO = { bien = "exito", cerca = "aviso", riesgo = "aviso", tuya = "peligro", perdida = "peligro" }
local TEXTO = {
	cerca = L["¡Bájale, casi se lo quitas al tanque!"],
	tuya = L["¡Te está atacando a ti!"],
	riesgo = L["Están por quitártelo"],
	perdida = L["¡Perdiste su atención!"],
}

---------------------------------------------------------------------------
-- La barra
---------------------------------------------------------------------------
local f, antes

local function crear()
	if f then return f end
	f = M.Marco("Amenaza", L["Barra de amenaza"], ANCHO, ALTO, { "CENTER", "CENTER", 0, -122 })
	f.Barra = CreateFrame("StatusBar", nil, f)
	f.Barra:SetAllPoints(f)
	f.Barra:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
	f.Barra:SetMinMaxValues(0, 100)
	f.Barra:SetValue(0)
	f.Barra.Pista = K.Plano(f.Barra, "hundido", "BACKGROUND", 0)
	f.Barra.Pista:SetAllPoints(f.Barra)
	f.Capa = CreateFrame("Frame", nil, f)
	f.Capa:SetAllPoints(f)
	f.Capa:SetFrameLevel(f.Barra:GetFrameLevel() + 2)
	f.Nombre = K.Texto(f.Capa, "pequeno", "texto")
	f.Nombre:SetPoint("LEFT", f, "LEFT", 4, 0)
	K.Escribir(f.Nombre, L["Amenaza"])
	f.Valor = K.Texto(f.Capa, "pequeno", "texto")
	f.Valor:SetPoint("RIGHT", f, "RIGHT", -4, 0)
	f.Aviso = K.Texto(f, "pequeno", "aviso")
	f.Aviso:SetPoint("TOP", f, "BOTTOM", 0, -3)
	f:Hide()
	return f
end

local function color(tono)
	f.Barra:SetStatusBarColor(K.Color(tono or "textoTenue"))
end

function Am.Ver()
	if not M.Opt("amenaza") then
		if f then f:Hide() end
		antes = nil
		return
	end
	if M.Desbloqueado() then
		crear()
		f.Barra:SetValue(65)
		color("exito")
		f.Valor:SetText("65 %")
		f.Aviso:SetText("")
		f:Show()
		return
	end
	if not Am.Importa() then
		if f then f:Hide() end
		antes = nil
		return
	end
	crear()
	local r = Am.Leer()
	if r.vacia then f:Hide() antes = nil return end
	-- 1.3.1: un secreto va tal cual a SetValue (sin `or`, que lo compararía).
	local valor = r.pct
	if not M.Secreto(valor) and type(valor) ~= "number" then valor = 0 end
	pcall(f.Barra.SetValue, f.Barra, valor)
	if r.estado then
		color(TONO[r.estado])
		if r.sinPct then f.Valor:SetText("") else f.Valor:SetText(format("%d %%", floor((r.pct or 0) + 0.5))) end
		local t = TEXTO[r.estado]
		f.Aviso:SetText(t or "")
		if t then K.ColorTexto(f.Aviso, TONO[r.estado]) end
		-- Suena al pasar a lo peligroso, no a cada repintada.
		if TONO[r.estado] == "peligro" and antes ~= r.estado and M.Opt("amenazaSonido") then
			M.Sonar("RAID_WARNING", 8959)
		end
		antes = r.estado
	else
		color("textoTenue")
		f.Valor:SetText("")
		f.Aviso:SetText("")
		antes = nil
	end
	f:Show()
end

local pendiente = false
function Am.Pedir()
	if pendiente or not M.Opt("amenaza") then return end
	pendiente = true
	A.After(0.2, function() pendiente = false K.Llamar(Am.Ver) end)
end

A.OnLogin(function()
	M.Ensenar({ id = "combate.amenaza", icono = "ic-manada",
		pregunta = L["¿Cómo sé si le voy a quitar el enemigo al tanque?"],
		respuesta = L["En grupo, Alfa muestra una barra pequeña con tu amenaza sobre tu objetivo. Se pone amarilla antes de que se lo quites al tanque y roja si ya te ataca a ti. Si eres tanque, te avisa cuando están por quitártelo."] })
end)
