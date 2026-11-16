-- Alfa - Builds: ayudas en combate, solo lo permitido (Toxic / La Jauría). GPL-3.0.
--
-- Nada aquí decide por el jugador: solo muestra.
--   * Sugerencia: la ayuda oficial de Blizzard (C_AssistedCombat.GetNextCastSpell)
--     como un ícono movible, con su tecla. Si el cliente trae el resaltado
--     oficial de botones (AssistedCombatManager), se usa ese; si no, Alfa
--     marca con un borde el botón de tu barra que tiene la sugerencia.
--   * Alertas de reacción: habilidades propias que se activan por algo que
--     pasó (Abrumar, Revancha, Ejecutar...). Se leen con datos del jugador:
--     C_Spell.IsSpellUsable, su recarga y el brillo oficial del hechizo
--     (SPELL_ACTIVATION_OVERLAY_GLOW_SHOW). Un valor secreto se ignora.
--   * Temporizador de golpe: PLAYER_SWING (duración y mano), sin registro de combate.
--   * Panel de estadísticas: tus números, con los más importantes de tu build.
-- Los marcos cuelgan de Alfa.UIParent (se esconden con Alfa) y solo se
-- mueven fuera de combate.

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local W, Th = A.Widgets, A.Theme
local C = {}
M.Combate = C

local type, pairs, ipairs, pcall, format, floor = type, pairs, ipairs, pcall, string.format, math.floor

local function R(v) return A.Compat.Readable(v) end
local function get(k) return N.Get(M.ID, k) end
local function secreto(v) return v ~= nil and issecretvalue ~= nil and issecretvalue(v) end

local function llamar(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d = pcall(fn, ...)
	if ok then return a, b, c, d end
end

-- Un borde que sigue el tema (acento o un color de la paleta).
local function borde(f, nombre, alfa, grosor)
	W.Painter(f, function(self)
		local r, g, b
		if nombre == "accent" then r, g, b = Th.Accent() else r, g, b = Th.Color(nombre) end
		Th.Border(self, r, g, b, alfa or 1, nil, grosor)
	end)
end
M.Borde = borde

---------------------------------------------------------------------------
-- Marcos movibles
---------------------------------------------------------------------------

local marcos = {} -- clave -> frame
local desbloqueado = false

local function posiciones()
	local d = N.Datos(M.ID)
	d.pos = type(d.pos) == "table" and d.pos or {}
	return d.pos
end

local function colocar(f)
	local p = posiciones()[f.alfaClave]
	f:ClearAllPoints()
	if type(p) == "table" and p[1] then
		f:SetPoint(p[1], UIParent, p[2] or p[1], p[3] or 0, p[4] or 0)
	else
		f:SetPoint(f.alfaPunto[1], UIParent, f.alfaPunto[2], f.alfaPunto[3], f.alfaPunto[4])
	end
end

local function guardar(f)
	local a, _, b, x, y = f:GetPoint(1)
	posiciones()[f.alfaClave] = { a, b, floor((x or 0) + 0.5), floor((y or 0) + 0.5) }
end

-- Un marco de Alfa en pantalla: arrastrable mientras está desbloqueado.
local function marco(clave, nombre, ancho, alto, punto)
	local f = CreateFrame("Frame", "AlfaBuilds" .. clave, A.UIParent)
	f.alfaClave, f.alfaPunto, f.alfaNombre = clave, punto, nombre
	f:SetSize(ancho, alto)
	f:SetFrameStrata("MEDIUM")
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self) if desbloqueado and not InCombatLockdown() then self:StartMoving() end end)
	f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); guardar(self) end)
	-- El aviso de "arrástrame" mientras se puede mover.
	f.Guia = CreateFrame("Frame", nil, f)
	f.Guia:SetAllPoints(f)
	f.Guia:SetFrameLevel(f:GetFrameLevel() + 20)
	local fondo = W.Fill(f.Guia, "accent", "OVERLAY")
	W.Color(fondo, "accent", 0.18)
	borde(f.Guia, "accent")
	f.Guia.Text = W.Text(f.Guia, "caption", "text", "OVERLAY")
	f.Guia.Text:SetPoint("BOTTOM", f.Guia, "TOP", 0, 3)
	f.Guia.Text:SetText(nombre)
	f.Guia:Hide()
	colocar(f)
	marcos[clave] = f
	return f
end

function C.Desbloquear(on)
	if InCombatLockdown() then
		N.Imprimir(L["Los marcos solo se mueven fuera de combate."])
		return
	end
	desbloqueado = on and true or false
	for _, f in pairs(marcos) do
		f:EnableMouse(desbloqueado)
		f.Guia:SetShown(desbloqueado)
	end
	C.Refrescar()
end

function C.Desbloqueado() return desbloqueado end

function C.ReiniciarPosiciones()
	local d = N.Datos(M.ID)
	d.pos = {}
	for _, f in pairs(marcos) do colocar(f) end
end

---------------------------------------------------------------------------
-- Sugerencia oficial (C_AssistedCombat)
---------------------------------------------------------------------------

local sug
local sugSpell, sugTecla

function C.SugerenciaDisponible()
	if not (C_AssistedCombat and C_AssistedCombat.GetNextCastSpell) then
		return false, L["Tu cliente no trae la ayuda de combate de Blizzard."]
	end
	if C_AssistedCombat.IsAvailable then
		local ok, si, porque = pcall(C_AssistedCombat.IsAvailable)
		if ok and R(si) == false then return false, R(porque) end
	end
	return true
end

-- El resaltado oficial de botones existe solo si el cliente carga su gestor.
function C.ResaltadoOficial()
	return type(AssistedCombatManager) == "table" and C_CVar and C_CVar.GetCVar
		and C_CVar.GetCVar("assistedCombatHighlight") ~= nil or false
end

local BARRAS = { -- primera ranura de cada barra y su comando de tecla
	{ 1, "ACTIONBUTTON" }, { 61, "MULTIACTIONBAR1BUTTON" }, { 49, "MULTIACTIONBAR2BUTTON" },
	{ 25, "MULTIACTIONBAR3BUTTON" }, { 37, "MULTIACTIONBAR4BUTTON" },
}

local function corta(k)
	if type(k) ~= "string" then return nil end
	k = k:gsub("SHIFT%-", "s"):gsub("CTRL%-", "c"):gsub("ALT%-", "a"):gsub("BUTTON", "B"):gsub("MOUSEWHEELUP", "RU"):gsub("MOUSEWHEELDOWN", "RD")
	return k
end

-- La tecla de la primera ranura de tus barras que tiene el hechizo.
local function teclaDe(spell)
	if not (C_ActionBar and C_ActionBar.FindSpellActionButtons and GetBindingKey) then return nil end
	local slots = llamar(C_ActionBar.FindSpellActionButtons, spell)
	if type(slots) ~= "table" then return nil end
	for _, s in ipairs(slots) do
		s = R(s)
		if type(s) == "number" then
			for _, b in ipairs(BARRAS) do
				if s >= b[1] and s < b[1] + 12 then
					local k = llamar(GetBindingKey, b[2] .. (s - b[1] + 1))
					if k then return corta(k) end
				end
			end
			-- Barra de actitud o de forma: comparte las teclas de la barra principal.
			if s > 72 then
				local k = llamar(GetBindingKey, "ACTIONBUTTON" .. (((s - 1) % 12) + 1))
				if k then return corta(k) end
			end
		end
	end
	return nil
end

local function crearSugerencia()
	if sug then return sug end
	sug = marco("Sugerencia", L["Sugerencia de Blizzard"], 52, 52, { "CENTER", "CENTER", 0, -160 })
	sug.Icon = sug:CreateTexture(nil, "ARTWORK")
	sug.Icon:SetPoint("TOPLEFT", sug, "TOPLEFT", 2, -2)
	sug.Icon:SetPoint("BOTTOMRIGHT", sug, "BOTTOMRIGHT", -2, 2)
	sug.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	sug.Fondo = W.Fill(sug, "shade", "BACKGROUND")
	borde(sug, "accent")
	sug.CD = CreateFrame("Cooldown", nil, sug, "CooldownFrameTemplate")
	sug.CD:SetAllPoints(sug.Icon)
	if sug.CD.SetHideCountdownNumbers then sug.CD:SetHideCountdownNumbers(true) end
	sug.Tecla = W.Text(sug, "caption", "text", "OVERLAY")
	sug.Tecla:SetPoint("TOPRIGHT", sug, "TOPRIGHT", -3, -3)
	Th.SetOutline(sug.Tecla, true)
	sug.Nombre = W.Text(sug, "small", "textDim", "OVERLAY")
	sug.Nombre:SetPoint("TOP", sug, "BOTTOM", 0, -3)
	Th.SetOutline(sug.Nombre, true)
	local acum = 0
	sug:SetScript("OnUpdate", function(self, dt)
		acum = acum + dt
		if acum < 0.1 then return end
		acum = 0
		C.ActualizarSugerencia()
	end)
	sug:Hide()
	return sug
end

local resaltados = {} -- botón -> marco
local resaltadoSpell

local NOMBRES_BOTONES = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton", "MultiBarLeftButton" }

-- Bordes propios sobre los botones de Blizzard: marcos nuestros, hijos del
-- botón, creados fuera de combate; en combate solo se muestran u ocultan.
local function prepararResaltados()
	if InCombatLockdown() or C.ResaltadoOficial() then return end
	for _, base in ipairs(NOMBRES_BOTONES) do
		for i = 1, 12 do
			local b = _G[base .. i]
			if b and not resaltados[b] then
				local m = A.CreateFrameUnder("Frame", nil, b)
				m:SetPoint("TOPLEFT", b, "TOPLEFT", -3, 3)
				m:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 3, -3)
				m:SetFrameLevel(b:GetFrameLevel() + 6)
				m.Glow = m:CreateTexture(nil, "OVERLAY")
				m.Glow:SetTexture(Th.Media("glow"))
				m.Glow:SetPoint("TOPLEFT", m, "TOPLEFT", -8, 8)
				m.Glow:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", 8, -8)
				m.Glow:SetBlendMode("ADD")
				borde(m, "accent", 1, 2)
				m:Hide()
				resaltados[b] = m
			end
		end
	end
end

local function ranuraDe(b)
	local s = rawget(b, "action")
	if type(s) ~= "number" and b.GetAttribute then
		local ok, v = pcall(b.GetAttribute, b, "action")
		s = ok and tonumber(v) or nil
	end
	return R(s)
end

local function resaltar(spell)
	if spell == resaltadoSpell then return end
	resaltadoSpell = spell
	local quiero = {}
	if spell and get("resaltado") and not C.ResaltadoOficial() and C_ActionBar and C_ActionBar.FindSpellActionButtons then
		local slots = llamar(C_ActionBar.FindSpellActionButtons, spell)
		if type(slots) == "table" then
			for _, s in ipairs(slots) do s = R(s); if s then quiero[s] = true end end
		end
	end
	for b, m in pairs(resaltados) do
		local s = ranuraDe(b)
		local on = s ~= nil and quiero[s] == true and b:IsVisible()
		m:SetShown(on)
		if on then
			local r, g, bl = Th.Accent()
			m.Glow:SetVertexColor(r, g, bl, 0.55)
		end
	end
end

-- Las barras cambiaron: se vuelve a buscar el botón con la sugerencia.
function C.OlvidarResaltado() resaltadoSpell = nil end

local function hayEnemigo()
	if not UnitExists("target") then return false end
	return R(UnitCanAttack("player", "target")) and not R(UnitIsDead("target")) or false
end

function C.ActualizarSugerencia()
	if not sug then return end
	local spell
	if C_AssistedCombat and C_AssistedCombat.GetNextCastSpell then
		local ok, s = pcall(C_AssistedCombat.GetNextCastSpell, false)
		if ok then spell = s end
	end
	if spell == nil then
		sug.Icon:SetTexture(desbloqueado and Th.Media("icon-skill") or nil)
		sug.Tecla:SetText("")
		sug.Nombre:SetText(desbloqueado and L["Sugerencia de Blizzard"] or "")
		resaltar(nil)
		return
	end
	if secreto(spell) then
		-- Se muestra tal cual: la textura acepta el valor, pero no se compara.
		pcall(function() sug.Icon:SetTexture(C_Spell.GetSpellTexture(spell)) end)
		sug.Tecla:SetText("")
		sug.Nombre:SetText("")
		return
	end
	if spell ~= sugSpell then
		sugSpell = spell
		sug.Icon:SetTexture(A.Compat.SpellIcon(spell))
		sugTecla = teclaDe(spell)
		sug.Tecla:SetText(sugTecla or "")
		sug.Nombre:SetText(get("sugerenciaNombre") and (M.Arbol.Nombre(spell) or "") or "")
	end
	local start, dur = A.Compat.GetSpellCooldown(spell)
	if dur and dur > 0 then sug.CD:SetCooldown(start, dur) elseif sug.CD.Clear then sug.CD:Clear() end
	resaltar(spell)
end

local function verSugerencia()
	if not get("sugerencia") then
		if sug then sug:Hide() end
		resaltar(nil)
		return
	end
	local f = crearSugerencia()
	f:SetScale((get("tamSugerencia") or 52) / 52)
	local disponible = C.SugerenciaDisponible()
	local ver = desbloqueado or (disponible and (InCombatLockdown() or get("sugerenciaFuera") or hayEnemigo()))
	f:SetShown(ver and true or false)
	if ver then C.ActualizarSugerencia() else resaltar(nil) end
end

---------------------------------------------------------------------------
-- Alertas de reacción
---------------------------------------------------------------------------

local alerta
local reacciones = {} -- { def, id }
local listo = {}      -- clave -> estaba lista
local ultimaAlerta = {}

local function prepararReacciones()
	reacciones = {}
	local d = M.DatosClase()
	for _, r in ipairs(d and d.reacciones or {}) do
		local id
		for i = #r.ids, 1, -1 do
			local x = r.ids[i]
			if A.Compat.IsPlayerSpell(x) or A.Compat.IsSpellKnown(x) then id = x break end
		end
		if id then reacciones[#reacciones + 1] = { def = r, id = id } end
	end
end
C.PrepararReacciones = prepararReacciones
function C.Reacciones() return reacciones end

local function crearAlerta()
	if alerta then return alerta end
	alerta = marco("Alerta", L["Alertas de reacción"], 300, 56, { "CENTER", "CENTER", 0, 140 })
	alerta.Icon = alerta:CreateTexture(nil, "ARTWORK")
	alerta.Icon:SetSize(44, 44)
	alerta.Icon:SetPoint("LEFT", alerta, "LEFT", 6, 0)
	alerta.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	alerta.Borde = CreateFrame("Frame", nil, alerta)
	alerta.Borde:SetAllPoints(alerta.Icon)
	borde(alerta.Borde, "accent")
	alerta.Texto = W.Text(alerta, "display", "accent", "OVERLAY")
	alerta.Texto:SetPoint("LEFT", alerta.Icon, "RIGHT", 10, 6)
	Th.SetOutline(alerta.Texto, true)
	alerta.Sub = W.Text(alerta, "small", "text", "OVERLAY")
	alerta.Sub:SetPoint("TOPLEFT", alerta.Texto, "BOTTOMLEFT", 0, -2)
	alerta.Sub:SetWidth(236)
	alerta.Sub:SetWordWrap(true)
	alerta.Sub:SetJustifyV("TOP")
	Th.SetOutline(alerta.Sub, true)
	alerta:SetScript("OnUpdate", function(self)
		if desbloqueado then self:SetAlpha(1) return end
		local resta = (self.hasta or 0) - GetTime()
		if resta <= 0 then self:Hide() return end
		self:SetAlpha(resta < 0.4 and resta / 0.4 or 1)
	end)
	alerta:Hide()
	return alerta
end

function C.MostrarAlerta(r, prueba)
	if not (get("alertas") or prueba) then return end
	local f = crearAlerta()
	local now = GetTime()
	if not prueba and ultimaAlerta[r.def.clave] and now - ultimaAlerta[r.def.clave] < 1.5 then return end
	ultimaAlerta[r.def.clave] = now
	f.Icon:SetTexture(A.Compat.SpellIcon(r.id) or Th.Media("icon-skill"))
	f.Texto:SetText(r.def.texto)
	f.Sub:SetText(get("alertasPorque") and r.def.porque or "")
	f.hasta = now + 1.8
	f:SetAlpha(1)
	f:Show()
	if get("alertasSonido") and SOUNDKIT then
		pcall(A.PlaySound, SOUNDKIT.RAID_WARNING or 8959, "SFX")
	end
end

local function lista(r)
	local usable = select(1, llamar(C_Spell and C_Spell.IsSpellUsable, r.id))
	if usable == nil or secreto(usable) then return nil end
	if not usable then return false end
	local start, dur = A.Compat.GetSpellCooldown(r.id)
	if dur and dur > 1.6 and start + dur - GetTime() > 0.25 then return false end
	return true
end

local vigia = CreateFrame("Frame")
vigia:Hide()
do
	local acum = 0
	vigia:SetScript("OnUpdate", function(_, dt)
		acum = acum + dt
		if acum < 0.15 then return end
		acum = 0
		if not get("alertas") then return end
		for _, r in ipairs(reacciones) do
			local ahora = lista(r)
			if ahora == true and listo[r.def.clave] == false then C.MostrarAlerta(r) end
			if ahora ~= nil then listo[r.def.clave] = ahora end
		end
	end)
end

function C.OnBrillo(_, spellID)
	if secreto(spellID) or not get("alertas") then return end
	for _, r in ipairs(reacciones) do
		for _, id in ipairs(r.def.ids) do
			if id == spellID then C.MostrarAlerta(r) return end
		end
	end
end

function C.ProbarAlerta()
	local r = reacciones[1]
	if not r then
		local d = M.DatosClase()
		local def = d and d.reacciones and d.reacciones[1]
		r = def and { def = def, id = def.ids[1] } or { def = { clave = "prueba", texto = L["¡Así se ve una alerta!"], ids = {} }, id = nil }
	end
	C.MostrarAlerta(r, true)
end

---------------------------------------------------------------------------
-- Temporizador de golpe (PLAYER_SWING)
---------------------------------------------------------------------------

local golpe
local CUERPO = { WARRIOR = true, ROGUE = true, PALADIN = true, SHAMAN = true, DRUID = true, HUNTER = true }
local manos = {} -- tipo -> { inicio, dur }
local COLORES = { [0] = "accent", [1] = "link", [2] = "success" }
local ETIQUETA = { [0] = L["Principal"], [1] = L["Secundaria"], [2] = L["Distancia"] }

local function barra(parent, i)
	local b = CreateFrame("StatusBar", nil, parent)
	b:SetHeight(8)
	b:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(i * 12))
	b:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -(i * 12))
	b:SetStatusBarTexture(Th.Media("white"))
	b:SetMinMaxValues(0, 1)
	b:SetValue(0)
	b.Fondo = W.Fill(b, "shade", "BACKGROUND")
	W.Color(b.Fondo, "shade", 0.6)
	b.Texto = W.Text(b, "caption", "text", "OVERLAY")
	b.Texto:SetPoint("RIGHT", b, "RIGHT", -2, 0)
	Th.SetOutline(b.Texto, true)
	b.Mano = W.Text(b, "caption", "textDim", "OVERLAY")
	b.Mano:SetPoint("LEFT", b, "LEFT", 2, 0)
	Th.SetOutline(b.Mano, true)
	b:Hide()
	return b
end

local function crearGolpe()
	if golpe then return golpe end
	golpe = marco("Golpe", L["Temporizador de golpe"], 200, 32, { "CENTER", "CENTER", 0, -220 })
	golpe.Barras = { [0] = barra(golpe, 0), [1] = barra(golpe, 1), [2] = barra(golpe, 2) }
	W.Painter(golpe, function(self)
		for t, b in pairs(self.Barras) do
			b:SetStatusBarColor(Th.Color(COLORES[t]))
			b.Mano:SetText(ETIQUETA[t])
		end
	end)
	golpe:SetScript("OnUpdate", function(self)
		local now, alguno = GetTime(), false
		for t, b in pairs(self.Barras) do
			local m = manos[t]
			if m and now < m.inicio + m.dur + 0.4 then
				local frac = math.min(1, (now - m.inicio) / m.dur)
				b:SetValue(frac)
				local resta = m.inicio + m.dur - now
				b.Texto:SetText(resta > 0 and format("%.1f", resta) or "")
				b:Show()
				alguno = true
			elseif not desbloqueado then
				b:Hide()
			end
		end
		if not alguno and not desbloqueado and not InCombatLockdown() then self:Hide() end
	end)
	golpe:Hide()
	return golpe
end

function C.OnGolpe(_, dur, tipo)
	if not get("golpe") or secreto(dur) or secreto(tipo) then return end
	local _, clase = UnitClass("player")
	if not CUERPO[R(clase) or ""] then return end
	dur, tipo = tonumber(dur), tonumber(tipo) or 0
	if not dur or dur <= 0 then return end
	manos[tipo] = { inicio = GetTime(), dur = dur }
	crearGolpe():Show()
end

---------------------------------------------------------------------------
-- Panel de estadísticas
---------------------------------------------------------------------------

local panel
local ultimo = {} -- clave -> último texto legible

local function num(v) v = R(v); return type(v) == "number" and v or nil end
local function maxEscuelas(fn)
	local best
	for s = 2, 7 do
		local v = num(llamar(fn, s))
		if v and (not best or v > best) then best = v end
	end
	return best
end

-- clave -> función que devuelve el texto (nil si es secreto o no hay dato)
local LECTOR = {
	str = function() local _, e = UnitStat("player", 1); e = num(e); return e and tostring(e) end,
	agi = function() local _, e = UnitStat("player", 2); e = num(e); return e and tostring(e) end,
	sta = function() local _, e = UnitStat("player", 3); e = num(e); return e and tostring(e) end,
	int = function() local _, e = UnitStat("player", 4); e = num(e); return e and tostring(e) end,
	spi = function() local _, e = UnitStat("player", 5); e = num(e); return e and tostring(e) end,
	armor = function() local _, e = UnitArmor("player"); e = num(e); return e and tostring(floor(e)) end,
	ap = function()
		local b, p, n = UnitAttackPower("player")
		b, p, n = num(b), num(p), num(n)
		return b and tostring(b + (p or 0) + (n or 0))
	end,
	rap = function()
		local b, p, n = UnitRangedAttackPower("player")
		b, p, n = num(b), num(p), num(n)
		return b and tostring(b + (p or 0) + (n or 0))
	end,
	crit = function() local v = num(llamar(GetCritChance)); return v and format("%.1f%%", v) end,
	hit = function() local v = num(llamar(GetHitModifier)); return v and format("+%d%%", v) end,
	spellCrit = function() local v = maxEscuelas(GetSpellCritChance); return v and format("%.1f%%", v) end,
	spellHit = function() local v = num(llamar(GetSpellHitModifier)); return v and format("+%d%%", v) end,
	sp = function() local v = maxEscuelas(GetSpellBonusDamage); return v and tostring(v) end,
	heal = function() local v = num(llamar(GetSpellBonusHealing)); return v and tostring(v) end,
	mp5 = function() local _, c = llamar(GetManaRegen); c = num(c); return c and format("%.0f", c * 5) end,
	dodge = function() local v = num(llamar(GetDodgeChance)); return v and format("%.1f%%", v) end,
	parry = function() local v = num(llamar(GetParryChance)); return v and format("%.1f%%", v) end,
	block = function() local v = num(llamar(GetBlockChance)); return v and format("%.1f%%", v) end,
	blockValue = function() local v = num(llamar(GetShieldBlock)); return v and tostring(v) end,
	defense = function() local b, m = llamar(UnitDefense, "player"); b, m = num(b), num(m); return b and tostring(b + (m or 0)) end,
	dps = function()
		local lo, hi = llamar(UnitDamage, "player")
		local vel = llamar(UnitAttackSpeed, "player")
		lo, hi, vel = num(lo), num(hi), num(vel)
		return lo and hi and vel and vel > 0 and format("%.1f", (lo + hi) / 2 / vel)
	end,
	rdps = function() return nil end,
	hp5 = function() return nil end,
	vida = function() local v = num(UnitHealthMax("player")); return v and tostring(v) end,
}
LECTOR.health = LECTOR.vida
C.LECTOR = LECTOR

local function filasPanel()
	local b = M.BuildElegido and M.BuildElegido()
	local claves = {}
	for _, k in ipairs(b and b.stats or { "str", "sta", "crit", "hit", "armor" }) do
		if LECTOR[k] and k ~= "rdps" and k ~= "hp5" and #claves < 6 then claves[#claves + 1] = k end
	end
	table.insert(claves, 1, "vida")
	return claves
end

local function crearPanel()
	if panel then return panel end
	panel = marco("Panel", L["Panel de estadísticas"], 170, 120, { "RIGHT", "RIGHT", -240, 0 })
	panel.Fondo = W.Fill(panel, "panel", "BACKGROUND")
	W.Color(panel.Fondo, "panel", 0.85)
	borde(panel, "border")
	panel.Titulo = W.Text(panel, "caption", "accent")
	panel.Titulo:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -6)
	panel.Filas = {}
	return panel
end

function C.ActualizarPanel()
	if not (panel and panel:IsShown()) then return end
	local claves = filasPanel()
	local b = M.BuildElegido and M.BuildElegido()
	panel.Titulo:SetText(b and b.titulo or L["Tus estadísticas"])
	for i, k in ipairs(claves) do
		local f = panel.Filas[i]
		if not f then
			f = {}
			f.Label = W.Text(panel, "small", "textDim")
			f.Valor = W.Text(panel, "number", "text")
			f.Valor:SetJustifyH("RIGHT")
			panel.Filas[i] = f
		end
		f.Label:ClearAllPoints()
		f.Label:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -(22 + (i - 1) * 15))
		f.Valor:ClearAllPoints()
		f.Valor:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -(22 + (i - 1) * 15))
		f.Label:SetText(k == "vida" and L["Vida"] or (M.STATS[k] and M.STATS[k].nombre or k))
		local ok, texto = pcall(LECTOR[k])
		if ok and texto then ultimo[k] = texto end
		f.Valor:SetText(ultimo[k] or "\226\128\147")
		W.Color(f.Valor, (ok and texto) and "text" or "textMuted")
		f.Label:Show(); f.Valor:Show()
	end
	for i = #claves + 1, #panel.Filas do panel.Filas[i].Label:Hide(); panel.Filas[i].Valor:Hide() end
	panel:SetHeight(28 + #claves * 15)
end

local function verPanel()
	if not get("panel") then
		if panel then panel:Hide() end
		return
	end
	crearPanel():Show()
	C.ActualizarPanel()
end

local panelPendiente = false
function C.PedirPanel()
	if panelPendiente then return end
	panelPendiente = true
	A.After(0.3, function()
		panelPendiente = false
		C.ActualizarPanel()
	end)
end

---------------------------------------------------------------------------
-- Encender, apagar y eventos
---------------------------------------------------------------------------

function C.Refrescar()
	verSugerencia()
	verPanel()
	if desbloqueado then
		crearAlerta()
		alerta.Icon:SetTexture(Th.Media("icon-skill"))
		alerta.Texto:SetText(L["¡Abrumar!"])
		alerta:Show()
		local g = crearGolpe()
		for t, b in pairs(g.Barras) do b:SetValue(0.6); b:Show() end
		g:Show()
	else
		if alerta then alerta:Hide() end
		if golpe and not InCombatLockdown() then golpe:Hide() end
	end
	if InCombatLockdown() then vigia:Show() else vigia:Hide() end
end

function C.EntrarCombate()
	for k in pairs(listo) do listo[k] = nil end
	for _, r in ipairs(reacciones) do listo[r.def.clave] = false end
	vigia:SetShown(get("alertas") and #reacciones > 0)
	verSugerencia()
end

function C.SalirCombate()
	vigia:Hide()
	prepararResaltados()
	verSugerencia()
	C.PedirPanel()
end

function C.Iniciar()
	prepararReacciones()
	prepararResaltados()
	C.Refrescar()
end

-- El panel se refresca con los eventos de estadísticas del jugador.
local ev = CreateFrame("Frame")
for _, e in ipairs({ "UNIT_STATS", "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER", "UNIT_MAXHEALTH", "UNIT_RESISTANCES" }) do
	pcall(ev.RegisterUnitEvent, ev, e, "player")
end
for _, e in ipairs({ "COMBAT_RATING_UPDATE", "PLAYER_DAMAGE_DONE_MODS", "PLAYER_EQUIPMENT_CHANGED" }) do
	pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function() C.PedirPanel() end)
