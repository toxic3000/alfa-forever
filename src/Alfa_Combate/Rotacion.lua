-- Alfa - Combate: la ayuda de rotación (toxic3000 / La Jauría). GPL-3.0.
--
-- Un ícono compacto con la habilidad que conviene ahora y, a su derecha y
-- más chicas, las que vienen después. Dos fuentes (R.Fuente):
--   * la ayuda oficial de Blizzard (C_AssistedCombat.GetNextCastSpell), con
--     las siguientes sacadas de GetRotationSpells: primero las listas, luego
--     las que esperan recurso y luego las que salen antes de recarga;
--   * si el cliente no la ofrece (Forever la trae apagada en sus opciones) o
--     si la pides, la prioridad propia de Alfa (Prioridad.lua), leída solo
--     con datos de tu personaje y según la situación (uno o varios enemigos).
-- Solo muestra: tú decides qué presionar.
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

local type, ipairs, pairs, pcall, floor, max, min, tonumber = type, ipairs, pairs, pcall, math.floor, math.max, math.min, tonumber
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
-- El ícono
---------------------------------------------------------------------------
local f
local ultimo, ticker, cada

local function cuadro(padre, principal)
	local b = CreateFrame("Frame", nil, padre)
	b.caja = K.Caja(b, { fondo = "hundido", borde = principal and "acento" or "lineaFuerte", corte = K.CORTE.casilla })
	b.Icono = b:CreateTexture(nil, "ARTWORK")
	b.Icono:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
	b.Icono:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
	b.Icono:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b:Hide()
	return b
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

local function crear()
	if f then return f end
	f = M.Marco("Rotacion", L["Ayuda de rotación"], 44, 44, { "CENTER", "CENTER", 0, -170 })
	f.Principal = cuadro(f, true)
	f.Principal:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	f.Tecla = placa(f.Principal, "insignia", "texto")
	f.Tecla:SetFrameLevel(f.Principal:GetFrameLevel() + 3)
	f.Tecla:SetPoint("TOPRIGHT", f.Principal, "TOPRIGHT", 3, 3)
	f.Nombre = placa(f, "pequeno", "texto")
	f.Nombre:SetPoint("TOP", f.Principal, "BOTTOM", 0, -3)
	f.Varios = placa(f.Principal, "insignia", "aviso")
	f.Varios:SetFrameLevel(f.Principal:GetFrameLevel() + 3)
	f.Varios:SetPoint("BOTTOMLEFT", f.Principal, "BOTTOMLEFT", -3, -3)
	f.Siguientes = {}
	for i = 1, MAX_DESPUES do f.Siguientes[i] = cuadro(f, false) end
	f:Hide()
	return f
end

local function acomodar()
	local tam = max(28, min(72, floor(tonumber(M.Opt("tam")) or 44)))
	local chico = floor(tam * 0.64 + 0.5)
	local n = max(0, min(MAX_DESPUES, floor(tonumber(M.Opt("despues")) or 0)))
	f.Principal:SetSize(tam, tam)
	local x = tam + ESP.xs
	for i, s in ipairs(f.Siguientes) do
		s:SetSize(chico, chico)
		s:ClearAllPoints()
		s:SetPoint("BOTTOMLEFT", f, "TOPLEFT", x, -tam)
		s.alfaUsar = i <= n
		if not s.alfaUsar then s:Hide() end
		x = x + chico + ESP.xs
	end
	f:SetSize(tam + (n > 0 and n * (chico + ESP.xs) or 0), tam)
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
	if f then f:Hide() end
	sinTicker()
	resaltar(nil)
end

-- Las que vienen después de `excluir` (hasta n).
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
--    espera recurso, hay varios enemigos
local function sugerencia(n)
	if R.Fuente() == "alfa" then
		local lista, varios = M.Prioridad.Calcular(n + 1)
		local primera = table.remove(lista, 1)
		if not primera then return nil, lista, false, varios end
		return primera.id, lista, primera.grupo ~= 1, varios
	end
	local spell = R.Siguiente()
	if M.Secreto(spell) or type(spell) ~= "number" then return spell, {}, false, false end
	local usable = M.Legible(M.Llamar(C_Spell and C_Spell.IsSpellUsable, spell))
	return spell, R.Despues(spell, n), usable == false, false
end

function R.Actualizar()
	if not (f and f:IsShown()) then return end
	local spell, lista, espera, varios = sugerencia(f.alfaN or 0)
	local p = f.Principal
	if M.Secreto(spell) then
		-- Tal cual: la textura acepta el valor; nada se compara.
		ultimo = nil
		pcall(function() p.Icono:SetTexture(C_Spell.GetSpellTexture(spell)) end)
		p.Icono:SetVertexColor(1, 1, 1, 1)
		p.Icono:SetDesaturated(false)
		p:Show()
		f.Tecla:Hide()
		f.Nombre:Hide()
		f.Varios:Hide()
		sinSiguientes()
		resaltar(nil)
		return
	end
	if type(spell) ~= "number" then
		ultimo = nil
		f.Tecla:Hide()
		f.Nombre:Hide()
		f.Varios:Hide()
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
		f.Nombre:Set(M.Opt("nombre") and M.NombreHechizo(spell) or nil)
	end
	-- Sin color: el juego dice que todavía no se puede (te falta recurso).
	p.Icono:SetDesaturated(espera and true or false)
	p:Show()
	f.Varios:Set(varios and L["Área"] or nil)
	for i, s in ipairs(f.Siguientes) do
		local c = s.alfaUsar and lista[i]
		if c then
			s.Icono:SetTexture(M.IconoHechizo(c.id) or K.Lobo("normal"))
			s.Icono:SetVertexColor(1, 1, 1, 1)
			s.Icono:SetDesaturated(c.grupo ~= 1)
			s:SetAlpha(c.grupo == 1 and 0.9 or 0.6)
			s:Show()
		else
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
	acomodar()
	f:SetAlpha((combate or mover) and 1 or max(0.15, min(1, tonumber(M.Opt("alfaFuera")) or 0.45)))
	f:Show()
	R.Actualizar()
	conTicker(combate and 0.15 or 0.3)
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
