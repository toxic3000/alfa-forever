-- Alfa - Curación: quién está en peligro, a la primera mirada (toxic3000 / La Jauría). GPL-3.0.
--
-- 1.3.7 (tercera vuelta, pedido de Toxic: «aviso visual de quién recibe daño
-- fuerte o de aggro»). Dos señales sobre los marcos, sin decidir nada por ti
-- (a quién curar lo decide tu clic):
--   * «En peligro» (curacion.peligro, prendido de fábrica): un velo rojo que
--     respira sobre la barra de quien baja del 35 % de vida, sea quien sea
--     (el tanque además late con su borde, como siempre). La vida llega
--     secreta en combate y en mazmorras: no se compara. Va por una curva de
--     color (C_CurveUtil) y UnitHealthPercent, que dan el color ya hecho
--     (transparente arriba del umbral); sin curva, solo si la vida se lee.
--   * «Le pegan a él» (con el ajuste de Amenaza): si un enemigo va por
--     alguien que no es el tanque, su marco brilla en naranja por fuera, además
--     de la línea de arriba. UnitThreatSituation solo cuando llega legible.
-- Todo son texturas dentro de los marcos: nada atrapa clics, nada se arma en
-- combate (las piezas nacen con el cuerpo de cada marco, M.CrearCuerpo, que
-- nace fuera de combate) y no hay relojes: se pinta con los eventos de vida y
-- de amenaza que ya escucha Marcos.lua.

local ADDON, M = ...
local N = AlfaNucleo
local L = M.L
local ID = M.ID
local secreto = M.Secreto

M.AJUSTES.peligro = true

M.UMBRAL_PELIGRO = 0.35
local ROJO = { 1, 0.16, 0.14 }
local NARANJA = { 1, 0.5, 0.12 } -- el resplandor de la amenaza: distinto del rojo del tanque en apuros
local VELO = 0.34 -- opacidad del velo
local BLANCO = "Interface\\Buttons\\WHITE8x8"

local function opt(k) return N.Get(ID, k) end

-- La curva: rojo con su opacidad debajo del umbral, transparente arriba.
local curva
do
	local CU = C_CurveUtil
	if CU and CU.CreateColorCurve and CreateColor then
		local ok, c = pcall(CU.CreateColorCurve)
		if ok and c then
			local bien = pcall(function()
				if c.SetType and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step then c:SetType(Enum.LuaCurveType.Step) end
				c:AddPoint(0, CreateColor(ROJO[1], ROJO[2], ROJO[3], VELO))
				c:AddPoint(M.UMBRAL_PELIGRO, CreateColor(ROJO[1], ROJO[2], ROJO[3], 0))
			end)
			if bien then curva = c end
		end
	end
end
M.curvaPeligro = curva

local function respirar(t, desde, hasta, dur)
	if not t.CreateAnimationGroup then return end
	local ag = t:CreateAnimationGroup()
	if ag.SetLooping then ag:SetLooping("BOUNCE") end
	local an = ag.CreateAnimation and ag:CreateAnimation("Alpha")
	if an and an.SetFromAlpha then
		an:SetFromAlpha(desde)
		an:SetToAlpha(hasta)
		an:SetDuration(dur)
		if an.SetSmoothing then an:SetSmoothing("IN_OUT") end
	end
	t.alfaLatido = ag
end

local function latir(t, si)
	local ag = t.alfaLatido
	if not ag then return end
	if si then
		if not ag:IsPlaying() then ag:Play() end
	elseif ag:IsPlaying() then
		ag:Stop()
	end
end

-- El velo (sobre la barra, debajo de los textos) y el resplandor (por fuera del marco).
local function piezas(c)
	if c.alfaPeligro then return c.alfaPeligro end
	local p = {}
	local capa = c.capa or c
	p.velo = capa:CreateTexture(nil, "BACKGROUND", nil, 1)
	p.velo:SetTexture(BLANCO)
	p.velo:SetAllPoints(c.barra or c)
	p.velo:SetVertexColor(ROJO[1], ROJO[2], ROJO[3], 0)
	p.velo:Hide()
	respirar(p.velo, 1, 0.45, 0.7)
	-- El resplandor: un marco por fuera, 3 px, con cuatro franjas.
	local g = CreateFrame("Frame", nil, c)
	g:SetPoint("TOPLEFT", c, "TOPLEFT", -3, 3)
	g:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 3, -3)
	if g.SetFrameLevel and capa.GetFrameLevel then g:SetFrameLevel(capa:GetFrameLevel() + 2) end
	if g.EnableMouse then g:EnableMouse(false) end
	g.lados = {}
	for i = 1, 4 do
		local t = g:CreateTexture(nil, "OVERLAY")
		t:SetTexture(BLANCO)
		t:SetVertexColor(NARANJA[1], NARANJA[2], NARANJA[3], 0.95)
		g.lados[i] = t
	end
	local l = g.lados
	l[1]:SetPoint("TOPLEFT", g, "TOPLEFT", 0, 0) l[1]:SetPoint("TOPRIGHT", g, "TOPRIGHT", 0, 0) l[1]:SetHeight(2)
	l[2]:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", 0, 0) l[2]:SetPoint("BOTTOMRIGHT", g, "BOTTOMRIGHT", 0, 0) l[2]:SetHeight(2)
	l[3]:SetPoint("TOPLEFT", l[1], "BOTTOMLEFT", 0, 0) l[3]:SetPoint("BOTTOMLEFT", l[2], "TOPLEFT", 0, 0) l[3]:SetWidth(2)
	l[4]:SetPoint("TOPRIGHT", l[1], "BOTTOMRIGHT", 0, 0) l[4]:SetPoint("BOTTOMRIGHT", l[2], "TOPRIGHT", 0, 0) l[4]:SetWidth(2)
	respirar(g, 1, 0.3, 0.9)
	g:Hide()
	p.brillo = g
	c.alfaPeligro = p
	return p
end
M.PiezasPeligro = piezas

-- Las piezas nacen con el cuerpo de cada marco (fuera de combate, como él).
local crearCuerpo = M.CrearCuerpo
if type(crearCuerpo) == "function" then
	M.CrearCuerpo = function(...)
		local c = crearCuerpo(...)
		if c then pcall(piezas, c) end
		return c
	end
end

-- late: si el velo respira (de fábrica, igual que si). Quieto, el velo queda
-- con la opacidad que trae su color.
local function velo(c, si, late)
	local p = piezas(c)
	p.velo:SetShown(si and true or false)
	if late == nil then late = si end
	latir(p.velo, si and late)
	if not (si and late) and p.velo.SetAlpha then p.velo:SetAlpha(1) end
end

-- La vida, si se puede leer: -> fracción (0..1), vida | nil
local function fraccionVida(u)
	local okV, v = pcall(UnitHealth, u)
	local okM, mx = pcall(UnitHealthMax, u)
	if not (okV and okM) or secreto(v) or secreto(mx) or type(v) ~= "number" or type(mx) ~= "number" or mx <= 0 then
		return nil
	end
	return v / mx, v
end

---------------------------------------------------------------------------
-- En peligro (con UNIT_HEALTH, desde vida() de Marcos.lua)
---------------------------------------------------------------------------
function M.Peligro(b)
	local c, u = b and b.cuerpo, b and b.unidad
	if not (c and u) then return end
	if not opt("peligro") or b.alfaEstado then
		b.alfaEnPeligro = nil
		if c.alfaPeligro then velo(c, false) end
		return
	end
	local p = piezas(c)
	local curva = M.curvaPeligro
	-- Con la curva: el color (y su opacidad) llega hecho; secreto o no, va directo.
	if curva and UnitHealthPercent then
		local ok = pcall(function()
			local col = UnitHealthPercent(u, true, curva)
			local r, g, bb, a = col:GetRGBA()
			p.velo:SetVertexColor(r, g, bb, a)
		end)
		if ok then
			-- El color lo dice (con la vida llena, transparente). Late solo si la
			-- vida se puede leer y está baja; secreta, el velo queda fijo.
			local f, v = fraccionVida(u)
			local bajo = (f and v > 0 and f < M.UMBRAL_PELIGRO) and true or false
			b.alfaEnPeligro = bajo or nil
			velo(c, true, bajo)
			return
		end
	end
	-- Sin curva: solo si la vida se puede leer.
	local f, v = fraccionVida(u)
	if not f then
		b.alfaEnPeligro = nil
		velo(c, false)
		return
	end
	local bajo = v > 0 and f < M.UMBRAL_PELIGRO
	b.alfaEnPeligro = bajo or nil
	p.velo:SetVertexColor(ROJO[1], ROJO[2], ROJO[3], VELO)
	velo(c, bajo)
end

---------------------------------------------------------------------------
-- Le pegan a él (desde amenaza() de Marcos.lua): s es UnitThreatSituation legible o nil.
---------------------------------------------------------------------------
function M.Aggro(b, s)
	local c = b and b.cuerpo
	if not c then return end
	local si = opt("amenaza") and not b.esTanque and not b.alfaEstado and type(s) == "number" and s >= 2
	b.alfaAggro = si or nil
	if not si and not c.alfaPeligro then return end
	local g = piezas(c).brillo
	g:SetShown(si and true or false)
	latir(g, si)
end

---------------------------------------------------------------------------
-- El modo prueba (marcos de ejemplo de Marcos.lua): e = { nombre, clase, vida, rol, ... }
---------------------------------------------------------------------------
function M.PeligroFalso(c, e)
	if not (c and e) then return end
	local p = piezas(c)
	local vida = tonumber(e[3]) or 1
	local enPeligro = opt("peligro") and not (e.muerto or e.desconectado) and vida > 0 and vida < M.UMBRAL_PELIGRO
	p.velo:SetVertexColor(ROJO[1], ROJO[2], ROJO[3], VELO)
	velo(c, enPeligro)
	local aggro = opt("amenaza") and e.amenaza and e[4] ~= "TANK" and not (e.muerto or e.desconectado)
	p.brillo:SetShown(aggro and true or false)
	latir(p.brillo, aggro)
end
