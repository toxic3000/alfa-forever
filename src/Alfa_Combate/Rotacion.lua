-- Alfa - Combate: la ayuda de rotación (toxic3000 / La Jauría). GPL-3.0.
--
-- Un ícono compacto con la habilidad que conviene ahora y, a su derecha y
-- más chicas, las que vienen después. Dos fuentes (R.Fuente):
--   * la ayuda oficial de Blizzard (C_AssistedCombat.GetNextCastSpell), con
--     las siguientes sacadas de GetRotationSpells: primero las listas, luego
--     las que esperan recurso y luego las que salen antes de recarga;
--   * si el cliente no la ofrece (Forever la trae apagada en sus opciones) o
--     si la pides, la prioridad propia de Alfa (Prioridad.lua), leída solo
--     con datos de tu personaje y según la situación (uno o varios enemigos,
--     recurso, recargas, procs, vida del enemigo).
-- Solo muestra: tú decides qué presionar. Al pelear no se llena de texto: el
-- ícono, su barrido de recarga y el borde que late (un proc) dicen todo; la
-- línea corta del porqué sale unas pocas veces por texto (M.TextoPuede) y se
-- calla con su × o con clic derecho.
--   * En combate se ve entero; fuera de combate, con un enemigo elegido y
--     transparente (ajustes). Sin sugerencia no se ve nada.
--   * La tecla de la habilidad sale sobre el ícono (la de tu barra).
--   * Resaltar el botón de tu barra: si el cliente trae el resaltado oficial
--     (AssistedCombatManager), el ajuste es el del juego; si no, Alfa dibuja
--     un borde propio sobre el botón (marcos nuestros, creados fuera de
--     combate; en combate solo se muestran u ocultan).
-- Un valor secreto se muestra tal cual (la textura lo acepta) y no se compara.

local ADDON, M = ...
local N, A, K, L = M.N, M.A, M.K, M.L
local R = {}
M.Rotacion = R

local type, ipairs, pairs, pcall, floor, max, min, tonumber, format = type, ipairs, pairs, pcall, math.floor, math.max, math.min, tonumber, string.format
local ESP = K.ESP
local MAX_DESPUES = 3
local GCD = 1.6 -- una recarga más corta que esto es la global

---------------------------------------------------------------------------
-- La ayuda de Blizzard
---------------------------------------------------------------------------
function R.Existe()
	return type(C_AssistedCombat) == "table" and type(C_AssistedCombat.GetNextCastSpell) == "function"
end

-- -> true | false, por qué (texto del juego o de Alfa)
function R.Disponible()
	if not R.Existe() then return false, L["Tu cliente no trae la ayuda de combate de Blizzard."] end
	if type(C_AssistedCombat.IsAvailable) == "function" then
		local si, porque = M.Llamar(C_AssistedCombat.IsAvailable)
		si, porque = M.Legible(si), M.Legible(porque)
		if si == false then
			return false, (type(porque) == "string" and porque ~= "") and porque or L["El juego no la ofrece ahora mismo."]
		end
	end
	return true
end

-- De dónde sale la sugerencia: "blizzard" (la ayuda oficial), "alfa" (la
-- prioridad propia de Alfa, si el juego no ofrece la oficial o si la pides)
-- o nil (ninguna sirve para tu clase ahora).
function R.Fuente()
	if not M.Opt("prioridadAlfa") and R.Disponible() then return "blizzard" end
	if M.Prioridad and M.Prioridad.Hay() then return "alfa" end
	if R.Disponible() then return "blizzard" end
	return nil
end

-- La habilidad sugerida: nil, un número o un valor secreto.
function R.Siguiente()
	if not R.Existe() then return nil end
	local ok, s = pcall(C_AssistedCombat.GetNextCastSpell, false)
	if ok then return s end
	return nil
end

-- Las habilidades de tu rotación, en el orden del juego (se guardan hasta
-- que cambian tus hechizos).
local rotacion
function R.Hechizos()
	if rotacion then return rotacion end
	rotacion = {}
	if R.Existe() and type(C_AssistedCombat.GetRotationSpells) == "function" then
		local lista = M.Llamar(C_AssistedCombat.GetRotationSpells)
		if type(lista) == "table" and not M.Secreto(lista) then
			local vistos = {}
			for _, id in ipairs(lista) do
				if not M.Secreto(id) and type(id) == "number" and not vistos[id] then
					vistos[id] = true
					rotacion[#rotacion + 1] = id
				end
			end
		end
	end
	return rotacion
end

---------------------------------------------------------------------------
-- Tus barras: qué botón tiene una habilidad y con qué tecla
---------------------------------------------------------------------------
local BARRAS = {
	{ "ActionButton", "ACTIONBUTTON" }, { "MultiBarBottomLeftButton", "MULTIACTIONBAR1BUTTON" },
	{ "MultiBarBottomRightButton", "MULTIACTIONBAR2BUTTON" }, { "MultiBarRightButton", "MULTIACTIONBAR3BUTTON" },
	{ "MultiBarLeftButton", "MULTIACTIONBAR4BUTTON" }, { "MultiBar5Button", "MULTIACTIONBAR5BUTTON" },
	{ "MultiBar6Button", "MULTIACTIONBAR6BUTTON" }, { "MultiBar7Button", "MULTIACTIONBAR7BUTTON" },
}

local function ranuraDe(b)
	local s = rawget(b, "action")
	if type(s) ~= "number" and b.GetAttribute then
		s = tonumber(M.Llamar(b.GetAttribute, b, "action"))
	end
	if M.Secreto(s) or type(s) ~= "number" then return nil end
	return s
end

-- Las ranuras de tus barras que tienen la habilidad: { [ranura] = true }.
local function ranuras(spell)
	local out = {}
	if not (C_ActionBar and C_ActionBar.FindSpellActionButtons) then return out end
	local lista = M.Llamar(C_ActionBar.FindSpellActionButtons, spell)
	if type(lista) ~= "table" or M.Secreto(lista) then return out end
	for _, s in ipairs(lista) do
		if not M.Secreto(s) and type(s) == "number" then out[s] = true end
	end
	return out
end

local function corta(k)
	if type(k) ~= "string" then return nil end
	k = k:gsub("SHIFT%-", "s"):gsub("CTRL%-", "c"):gsub("ALT%-", "a"):gsub("META%-", "m")
	k = k:gsub("MOUSEWHEELUP", "RU"):gsub("MOUSEWHEELDOWN", "RD"):gsub("BUTTON", "B"):gsub("NUMPAD", "N")
	return k
end

-- La tecla del primer botón visible de tus barras con la habilidad.
local function teclaDe(spell)
	if not GetBindingKey then return nil end
	local quiero = ranuras(spell)
	if next(quiero) == nil then return nil end
	for _, par in ipairs(BARRAS) do
		for i = 1, 12 do
			local b = _G[par[1] .. i]
			if type(b) == "table" and b.IsVisible and b:IsVisible() then
				local s = ranuraDe(b)
				if s and quiero[s] then
					local k = M.Llamar(GetBindingKey, par[2] .. i)
					if type(k) == "string" and k ~= "" then return corta(k) end
				end
			end
		end
	end
	return nil
end

---------------------------------------------------------------------------
-- Resaltar el botón de tu barra
---------------------------------------------------------------------------
-- El cliente trae el resaltado oficial (y su ajuste del juego).
function R.ResaltadoOficial()
	if type(AssistedCombatManager) ~= "table" then return false end
	return M.Llamar(GetCVar, "assistedCombatHighlight") ~= nil
end

function R.ResaltadoActivo()
	if R.ResaltadoOficial() then
		local get = (C_CVar and C_CVar.GetCVarBool) or GetCVarBool
		return M.Llamar(get, "assistedCombatHighlight") == true
	end
	return M.Opt("resaltar") and true or false
end

-- Con el clic del jugador: el ajuste del juego (fuera de combate) o el de Alfa.
function R.SetResaltado(on)
	if R.ResaltadoOficial() then
		N.FueraDeCombate(function()
			local set = (C_CVar and C_CVar.SetCVar) or SetCVar
			M.Llamar(set, "assistedCombatHighlight", on and "1" or "0")
			M.Avisar()
		end)
	else
		M.SetOpt("resaltar", on and true or false)
	end
end

local marcas = {}  -- botón -> nuestro borde
local resaltado    -- la habilidad resaltada ahora

-- Un borde de 2 px que late, sobre un botón de la barra.
local function marca(b)
	local m = A.CreateFrameUnder("Frame", nil, b)
	m:SetPoint("TOPLEFT", b, "TOPLEFT", -2, 2)
	m:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -2)
	m:SetFrameLevel(K.num(b:GetFrameLevel(), 1) + 8)
	m.caja = K.Caja(m, { fondo = false, borde = "acento", corte = K.CORTE.chico })
	m.Dentro = CreateFrame("Frame", nil, m)
	m.Dentro:SetPoint("TOPLEFT", m, "TOPLEFT", 1, -1)
	m.Dentro:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", -1, 1)
	m.Dentro.caja = K.Caja(m.Dentro, { fondo = false, borde = "acento", corte = K.CORTE.casilla })
	local ag = m:CreateAnimationGroup()
	local a = ag:CreateAnimation("Alpha")
	a:SetFromAlpha(1)
	a:SetToAlpha(0.45)
	a:SetDuration(0.55)
	a:SetSmoothing("IN_OUT")
	ag:SetLooping("BOUNCE")
	m.late = ag
	m:Hide()
	return m
end

-- Los bordes se crean fuera de combate, una vez por botón.
function R.PrepararBarras()
	if InCombatLockdown() or R.ResaltadoOficial() then return end
	if A.GamepadUI and A.GamepadUI() then return end
	for _, par in ipairs(BARRAS) do
		for i = 1, 12 do
			local b = _G[par[1] .. i]
			if type(b) == "table" and b.GetObjectType and not marcas[b] then
				marcas[b] = marca(b)
			end
		end
	end
end

local function resaltar(spell)
	if spell == resaltado then return end
	resaltado = spell
	local quiero = {}
	if spell and M.Opt("resaltar") and not R.ResaltadoOficial() then quiero = ranuras(spell) end
	for b, m in pairs(marcas) do
		local s = ranuraDe(b)
		local on = s ~= nil and quiero[s] == true and b:IsVisible() and true or false
		m:SetShown(on)
		if on then m.late:Play() else m.late:Stop() end
	end
end

---------------------------------------------------------------------------
-- El ícono: la siguiente en grande, las que siguen chicas a la derecha, el
-- barrido de su recarga, un borde que late si el juego la activó y, unas
-- pocas veces, una línea corta con el porqué.
---------------------------------------------------------------------------
local f
local ultimo, ticker, cada
local DUR_LINEA = 2.6 -- segundos que se queda el porqué

-- El barrido de la recarga (un marco Cooldown del cliente, sin números).
local function barrido(b)
	local ok, cd = pcall(CreateFrame, "Cooldown", nil, b, "CooldownFrameTemplate")
	if not ok or type(cd) ~= "table" then ok, cd = pcall(CreateFrame, "Cooldown", nil, b) end
	if not ok or type(cd) ~= "table" then return nil end
	cd:SetAllPoints(b.Icono)
	pcall(cd.SetDrawEdge, cd, false)
	pcall(cd.SetDrawBling, cd, false)
	pcall(cd.SetHideCountdownNumbers, cd, true)
	pcall(cd.SetSwipeColor, cd, 0, 0, 0, 0.55)
	if cd.EnableMouse then cd:EnableMouse(false) end
	return cd
end

local function cuadro(padre, principal)
	local b = CreateFrame("Frame", nil, padre)
	b.caja = K.Caja(b, { fondo = "hundido", borde = principal and "acento" or "lineaFuerte", corte = K.CORTE.casilla })
	b.Icono = b:CreateTexture(nil, "ARTWORK")
	b.Icono:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
	b.Icono:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
	b.Icono:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.Recarga = barrido(b)
	b:Hide()
	return b
end

-- El barrido sobre un cuadro: con el objeto de duración del cliente (acepta
-- valores secretos sin compararlos) o, si no hay, con los tiempos legibles.
-- global: también la recarga global (solo en el principal).
local function ponerBarrido(b, id, global)
	local cd = b.Recarga
	if not cd then return end
	if not (id and M.Opt("barrido")) then pcall(cd.Clear, cd) return end
	local hecho = false
	if C_Spell and C_Spell.GetSpellCooldownDuration and cd.SetCooldownFromDurationObject then
		local ok, dur = pcall(C_Spell.GetSpellCooldownDuration, id, not global)
		if ok and (M.Secreto(dur) or type(dur) == "table" or type(dur) == "userdata") then
			hecho = pcall(cd.SetCooldownFromDurationObject, cd, dur, true)
		end
	end
	if hecho then return end
	local s, d = A.Compat.GetSpellCooldown(id)
	if d > 0 and (global or d > GCD) then pcall(cd.SetCooldown, cd, s, d) else pcall(cd.Clear, cd) end
end

-- Una placa oscura con un texto (sobre el mundo, sin sombras).
local function placa(padre, rol, color)
	local p = CreateFrame("Frame", nil, padre)
	p.caja = K.Caja(p, { fondo = "fondo", alfaFondo = 0.85, borde = false, corte = K.CORTE.casilla })
	p.Texto = K.Texto(p, rol, color)
	p.Texto:SetPoint("CENTER", p, "CENTER", 0, 0)
	function p:Set(t)
		if not t or t == "" then self:Hide() return end
		K.Escribir(self.Texto, t)
		self:SetSize(K.Ajustar(self.Texto, 160) + 8, K.Tamano(rol) + 6)
		self:Show()
	end
	p:Hide()
	return p
end

-- La línea del porqué: con su × ("No volver a mostrar") y clic derecho.
local function lineaPorque(padre)
	local p = CreateFrame("Frame", nil, padre)
	p.caja = K.Caja(p, { fondo = "fondo", alfaFondo = 0.88, borde = "linea", corte = K.CORTE.casilla })
	p.Texto = K.Texto(p, "pequeno", "texto")
	p.Texto:SetPoint("LEFT", p, "LEFT", 6, 0)
	p.Cerrar = K.BotonIcono(p, "ic-cerrar", function() if p.alfaClave then M.Callar(p.alfaClave) end p:Hide() end,
		{ tam = 16, ayuda = L["No volver a mostrar"], ayudaTexto = L["Esta explicación no saldrá más. En Combate puedes volver a encenderlas."] })
	p.Cerrar:SetPoint("RIGHT", p, "RIGHT", -2, 0)
	p:EnableMouse(true)
	p:SetScript("OnMouseUp", function(self, boton)
		if boton == "RightButton" and self.alfaClave then M.Callar(self.alfaClave) self:Hide() end
	end)
	function p:Set(clave, t)
		self.alfaClave = clave
		K.Escribir(self.Texto, t)
		local w = K.Ajustar(self.Texto, 220)
		self:SetSize(w + 6 + 4 + 16 + 2, max(18, K.Tamano("pequeno") + 8))
		self:Show()
	end
	p:SetScript("OnHide", function(self) if self.alfaClave then M.TextoFin(self.alfaClave) end end)
	p:Hide()
	return p
end

-- El borde que late cuando el juego activó la habilidad (un proc).
local function brillo(padre)
	local g = CreateFrame("Frame", nil, padre)
	g:SetPoint("TOPLEFT", padre, "TOPLEFT", -3, 3)
	g:SetPoint("BOTTOMRIGHT", padre, "BOTTOMRIGHT", 3, -3)
	g:SetFrameLevel(padre:GetFrameLevel() + 4)
	g.caja = K.Caja(g, { fondo = false, borde = "acento", corte = K.CORTE.chico })
	local ag = g:CreateAnimationGroup()
	local a = ag:CreateAnimation("Alpha")
	a:SetFromAlpha(1)
	a:SetToAlpha(0.35)
	a:SetDuration(0.45)
	a:SetSmoothing("IN_OUT")
	ag:SetLooping("BOUNCE")
	g.late = ag
	g:Hide()
	return g
end

local function crear()
	if f then return f end
	f = M.Marco("Rotacion", L["Ayuda de rotación"], 44, 44, { "CENTER", "CENTER", 0, -170 })
	f.Principal = cuadro(f, true)
	f.Principal:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	f.Brillo = brillo(f.Principal)
	f.Tecla = placa(f.Principal, "insignia", "texto")
	f.Tecla:SetFrameLevel(f.Principal:GetFrameLevel() + 6)
	f.Tecla:SetPoint("TOPRIGHT", f.Principal, "TOPRIGHT", 3, 3)
	f.Nombre = placa(f, "pequeno", "texto")
	f.Nombre:SetPoint("TOPLEFT", f.Principal, "BOTTOMLEFT", 0, -3)
	f.Porque = lineaPorque(f)
	f.Porque:SetPoint("TOPLEFT", f.Principal, "BOTTOMLEFT", 0, -3)
	f.Varios = placa(f.Principal, "insignia", "aviso")
	f.Varios:SetFrameLevel(f.Principal:GetFrameLevel() + 6)
	f.Varios:SetPoint("BOTTOMLEFT", f.Principal, "BOTTOMLEFT", -3, -3)
	f.Siguientes = {}
	for i = 1, MAX_DESPUES do f.Siguientes[i] = cuadro(f, false) end
	f:Hide()
	return f
end

local function acomodar()
	local tam = max(28, min(72, floor(tonumber(M.Opt("tam")) or 44)))
	local chico = floor(tam * 0.6 + 0.5)
	local n = max(0, min(MAX_DESPUES, floor(tonumber(M.Opt("despues")) or 0)))
	f.Principal:SetSize(tam, tam)
	local x = tam + ESP.s
	for i, s in ipairs(f.Siguientes) do
		s:SetSize(chico, chico)
		s:ClearAllPoints()
		s:SetPoint("BOTTOMLEFT", f, "TOPLEFT", x, -tam)
		s.alfaUsar = i <= n
		if not s.alfaUsar then s:Hide() end
		x = x + chico + ESP.xs
	end
	f:SetSize(tam + (n > 0 and (ESP.s - ESP.xs) + n * (chico + ESP.xs) or 0), tam)
	f.alfaN = n
end

local function sinTicker()
	if ticker then ticker:Cancel() ticker = nil end
	cada = nil
end

local function conTicker(seg)
	if ticker and cada == seg then return end
	sinTicker()
	cada = seg
	ticker = A.NewTicker(seg, R.Actualizar)
end

local function ocultar()
	if f then
		f.Porque:Hide()
		f:Hide()
	end
	sinTicker()
	resaltar(nil)
end

-- Las que vienen después de `excluir` (hasta n), con la ayuda de Blizzard.
function R.Despues(excluir, n)
	local cand = {}
	if n <= 0 then return cand end
	local ahora = GetTime()
	for i, id in ipairs(R.Hechizos()) do
		if id ~= excluir then
			local usable, sinPoder = M.Llamar(C_Spell and C_Spell.IsSpellUsable, id)
			usable, sinPoder = M.Legible(usable), M.Legible(sinPoder)
			if usable == true or sinPoder == true then
				local inicio, dur = A.Compat.GetSpellCooldown(id)
				local resta = dur > GCD and max(0, inicio + dur - ahora) or 0
				local grupo = resta > 0 and 3 or (usable == true and 1 or 2)
				cand[#cand + 1] = { id = id, orden = i, resta = resta, grupo = grupo }
			end
		end
	end
	table.sort(cand, function(a, b)
		if a.grupo ~= b.grupo then return a.grupo < b.grupo end
		if a.grupo == 3 and a.resta ~= b.resta then return a.resta < b.resta end
		return a.orden < b.orden
	end)
	for i = n + 1, #cand do cand[i] = nil end
	return cand
end

local function sinSiguientes()
	for _, s in ipairs(f.Siguientes) do s:Hide() end
end

-- La sugerencia de ahora y las que siguen, de la fuente que toca:
-- -> spell (nil, número o secreto), lista de las que siguen, la primera
--    (su dato completo, o nil con la ayuda de Blizzard), hay varios enemigos
local function sugerencia(n)
	if R.Fuente() == "alfa" then
		local lista, varios = M.Prioridad.Calcular(n + 1)
		local primera = table.remove(lista, 1)
		if not primera then return nil, lista, nil, varios end
		return primera.id, lista, primera, varios
	end
	local spell = R.Siguiente()
	if M.Secreto(spell) or type(spell) ~= "number" then return spell, {}, nil, false end
	local usable = M.Legible(M.Llamar(C_Spell and C_Spell.IsSpellUsable, spell))
	local nombre = M.NombreHechizo(spell)
	return spell, R.Despues(spell, n), { id = spell, nombre = nombre, grupo = usable == false and 2 or 1, motivo = "juego" }, false
end

-- La línea del porqué: solo unas pocas veces por texto (M.TextoPuede) y,
-- si no sale, el nombre (si lo pediste).
local lineaVista -- la clave de la última línea que se decidió
local function linea(spell, dato)
	local p = f.Porque
	local texto, clave
	if dato and M.Opt("porque") then
		if dato.motivo == "juego" then
			texto, clave = dato.nombre and format(L["%s: la sugiere el juego"], dato.nombre), "juego"
		elseif M.Prioridad then
			texto, clave = M.Prioridad.Corto(dato)
		end
	end
	local id = texto and ("rot:" .. tostring(clave) .. ":" .. tostring(dato.nombre))
	if p:IsShown() and p.alfaClave == id then return end
	if id ~= lineaVista then
		lineaVista = id
		if id and M.TextoPuede(id) then
			p:Set(id, texto)
			f.Nombre:Hide()
			f.Nombre.alfaTexto = nil
			M.TextoMostrado(id, DUR_LINEA)
			A.After(DUR_LINEA, function()
				if p:IsShown() and p.alfaClave == id then p:Hide() if f and f:IsShown() then R.Actualizar() end end
			end)
			return
		end
	end
	if p:IsShown() and p.alfaClave ~= id then p:Hide() end
	if not p:IsShown() then
		local n = M.Opt("nombre") and spell and M.NombreHechizo(spell) or nil
		if n ~= f.Nombre.alfaTexto or (n ~= nil) ~= f.Nombre:IsShown() then
			f.Nombre.alfaTexto = n
			f.Nombre:Set(n)
		end
	end
end

function R.Actualizar()
	if not (f and f:IsShown()) then return end
	local spell, lista, dato, varios = sugerencia(f.alfaN or 0)
	local p = f.Principal
	if M.Secreto(spell) then
		-- Tal cual: la textura acepta el valor; nada se compara.
		ultimo = nil
		pcall(function() p.Icono:SetTexture(C_Spell.GetSpellTexture(spell)) end)
		p.Icono:SetVertexColor(1, 1, 1, 1)
		p.Icono:SetDesaturated(false)
		p:Show()
		ponerBarrido(p, nil)
		f.Brillo:Hide()
		f.Tecla:Hide()
		f.Nombre:Hide()
		f.Porque:Hide()
		f.Varios:Hide()
		sinSiguientes()
		resaltar(nil)
		return
	end
	if type(spell) ~= "number" then
		ultimo = nil
		f.Tecla:Hide()
		f.Nombre:Hide()
		f.Porque:Hide()
		f.Varios:Hide()
		f.Brillo:Hide()
		ponerBarrido(p, nil)
		sinSiguientes()
		resaltar(nil)
		if M.Desbloqueado() then
			-- Mientras lo mueves: el lobo en su lugar.
			p.Icono:SetTexture(K.Lobo("normal"))
			p.Icono:SetVertexColor(K.Color("acento"))
			p.Icono:SetDesaturated(false)
			p:Show()
			for _, s in ipairs(f.Siguientes) do
				if s.alfaUsar then
					s.Icono:SetTexture(K.Lobo("dormido"))
					s.Icono:SetVertexColor(K.Color("textoTenue"))
					s:SetAlpha(0.6)
					ponerBarrido(s, nil)
					s:Show()
				end
			end
		else
			p:Hide()
		end
		return
	end
	if spell ~= ultimo then
		ultimo = spell
		p.Icono:SetTexture(M.IconoHechizo(spell) or K.Lobo("normal"))
		p.Icono:SetVertexColor(1, 1, 1, 1)
		f.Tecla:Set(M.Opt("tecla") and teclaDe(spell) or nil)
	end
	local espera = dato and dato.grupo and dato.grupo >= 2
	-- Sin color: todavía no se puede (te falta recurso o sale de recarga).
	p.Icono:SetDesaturated(espera and true or false)
	p:Show()
	ponerBarrido(p, spell, true)
	local luz = dato and dato.brilla and true or false
	if luz ~= (f.Brillo:IsShown() and true or false) then
		f.Brillo:SetShown(luz)
		if luz then f.Brillo.late:Play() else f.Brillo.late:Stop() end
	end
	f.Varios:Set(varios and L["Área"] or nil)
	linea(spell, dato)
	for i, s in ipairs(f.Siguientes) do
		local c = s.alfaUsar and lista[i]
		if c then
			if s.alfaId ~= c.id then
				s.alfaId = c.id
				s.Icono:SetTexture(M.IconoHechizo(c.id) or K.Lobo("normal"))
				s.Icono:SetVertexColor(1, 1, 1, 1)
			end
			s.Icono:SetDesaturated(c.grupo == 2)
			s:SetAlpha(c.grupo <= 1 and 0.9 or 0.65)
			ponerBarrido(s, c.id, false)
			s:Show()
		else
			s.alfaId = nil
			s:Hide()
		end
	end
	resaltar(spell)
end

-- ¿Se ve? En combate, fuera con un enemigo (si quieres) o mientras lo mueves.
function R.Ver()
	if not M.Opt("rotacion") then ocultar() return end
	crear()
	local hay = R.Fuente() ~= nil
	local combate = M.EnCombate()
	local mover = M.Desbloqueado()
	local ver = mover or (hay and (combate or (M.Opt("fuera") and M.HayEnemigo())))
	if not ver then ocultar() return end
	ultimo = nil
	for _, s in ipairs(f.Siguientes) do s.alfaId = nil end
	acomodar()
	f:SetAlpha((combate or mover) and 1 or max(0.15, min(1, tonumber(M.Opt("alfaFuera")) or 0.45)))
	f:Show()
	R.Actualizar()
	conTicker(combate and 0.15 or 0.3)
	if not combate then R.Presentar() end
end

-- La primera vez (por personaje, fuera de combate): un aviso que explica
-- cómo leer el ícono. Sale una sola vez.
function R.Presentar()
	if not M.Opt("rotacion") or M.EnCombate() or R.Fuente() == nil then return end
	local d = N.DatosPersonaje(M.ID)
	if d.presentado then return end
	d.presentado = true
	K.Aviso({
		titulo = L["Así se lee tu ayuda de rotación"],
		texto = L["El ícono grande es lo que conviene presionar ahora y los pequeños, lo que sigue. Si late, el juego activó esa habilidad; el barrido oscuro es su recarga. Tú decides: Alfa nunca aprieta nada."],
		icono = M.ICONO, tono = "acento", duracion = 16,
		accion = { texto = L["Ver mi prioridad"], alClic = function() N.Abrir(M.ID) end },
	})
end

-- Cambiaron tus hechizos: se vuelve a leer la rotación.
function R.Olvidar()
	rotacion = nil
	R.OlvidarBarras()
end

-- Cambiaron tus barras o tus teclas: se vuelve a buscar el botón y la tecla.
function R.OlvidarBarras()
	ultimo, resaltado = nil, false
	if not InCombatLockdown() then R.PrepararBarras() end
end
