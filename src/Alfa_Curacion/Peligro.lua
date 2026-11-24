-- Alfa - Curación: quién está en peligro, a la primera mirada (toxic3000 / La Jauría). GPL-3.0.
--
-- 1.3.7 (tercera vuelta, pedido de Toxic: «aviso visual de quién recibe daño
-- fuerte o de aggro»). Dos señales sobre los marcos, sin decidir nada por ti
-- (a quién curar lo decide tu clic):
--   * «En peligro» (curacion.peligro, prendido de fábrica): quien baja del
--     35 % de vida, sea quien sea (el tanque además late con su borde).
--   * «Le pegan a él» (con el ajuste de Amenaza): si un enemigo va por
--     alguien que no es el tanque, su marco brilla en naranja por fuera, además
--     de la línea de arriba. UnitThreatSituation solo cuando llega legible.
--
-- 1.3.8 (el bug del rojo fijo que vio Toxic): el velo de la 1.3.7 era un rojo
-- sobre TODA la barra que se volvía transparente con la opacidad de una curva
-- de color (UnitHealthPercent + C_CurveUtil); en el juego esa opacidad no se
-- respetaba y los marcos salían rojos de punta a punta, con la vida llena.
-- (El banco no tenía curvas: nunca se probó ese camino.) Ahora:
--   * Con la vida legible (fuera de combate, en el mundo) no hay curva: se
--     compara la vida y solo debajo del 35 % sale la señal.
--   * La señal es un borde rojo suave de 2 px por dentro y un tinte apenas
--     visible sobre la barra, que respiran juntos. Nunca un rojo sólido.
--   * Con la vida secreta (combate, mazmorras), las dos piezas suman luz (ADD)
--     con el color de una curva de escalones: rojo oscuro abajo del umbral y
--     NEGRO arriba. Con ADD el negro no se ve, así que no depende de la
--     opacidad de la curva: si el juego la ignora, igual no pinta nada.
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
M.PELIGRO = {
	borde = { 1, 0.32, 0.26, 0.85 },  -- el borde (r, g, b, opacidad)
	tinte = { 1, 0.2, 0.16, 0.14 },   -- el tinte sobre la barra: apenas
	-- con la vida secreta (ADD): lo que suma cada pieza abajo del umbral
	bordeSuma = { 0.78, 0.15, 0.11 },
	tinteSuma = { 0.16, 0.03, 0.025 },
}
local P = M.PELIGRO
local NARANJA = { 1, 0.5, 0.12 } -- el resplandor de la amenaza: distinto del rojo del tanque en apuros
local BLANCO = "Interface\\Buttons\\WHITE8x8"
local GROSOR = 2

local function opt(k) return N.Get(ID, k) end

-- Las curvas (vida secreta), al primer uso: rojo abajo del umbral, negro arriba.
local curvas
function M.CurvasPeligro()
	if curvas == nil then
		local u = M.UMBRAL_PELIGRO * (M.EscalaVida and M.EscalaVida() or 1) -- (1.3.8 revisión: 0–1 o 0–100)
		local b, t = P.bordeSuma, P.tinteSuma
		local cb = M.CurvaEscalones and M.CurvaEscalones({ { 0, b[1], b[2], b[3] }, { u, 0, 0, 0 } })
		local ct = M.CurvaEscalones and M.CurvaEscalones({ { 0, t[1], t[2], t[3] }, { u, 0, 0, 0 } })
		curvas = (cb and ct) and { borde = cb, tinte = ct } or false
	end
	return curvas or nil
end
function M.OlvidarCurvaPeligro() curvas = nil end

local function respirar(f, desde, hasta, dur)
	if not f.CreateAnimationGroup then return end
	local ag = f:CreateAnimationGroup()
	if ag.SetLooping then ag:SetLooping("BOUNCE") end
	local an = ag.CreateAnimation and ag:CreateAnimation("Alpha")
	if an and an.SetFromAlpha then
		an:SetFromAlpha(desde)
		an:SetToAlpha(hasta)
		an:SetDuration(dur)
		if an.SetSmoothing then an:SetSmoothing("IN_OUT") end
	end
	f.alfaLatido = ag
end

local function latir(f, si)
	local ag = f.alfaLatido
	if not ag then return end
	if si then
		if not ag:IsPlaying() then ag:Play() end
	elseif ag:IsPlaying() then
		ag:Stop()
	end
	if not si and f.SetAlpha then f:SetAlpha(1) end
end

local function cuatro(padre, g, capa)
	local e = {}
	for i = 1, 4 do
		local t = padre:CreateTexture(nil, capa or "ARTWORK")
		t:SetTexture(BLANCO)
		e[i] = t
	end
	e[1]:SetPoint("TOPLEFT", padre, "TOPLEFT", 0, 0) e[1]:SetPoint("TOPRIGHT", padre, "TOPRIGHT", 0, 0) e[1]:SetHeight(g)
	e[2]:SetPoint("BOTTOMLEFT", padre, "BOTTOMLEFT", 0, 0) e[2]:SetPoint("BOTTOMRIGHT", padre, "BOTTOMRIGHT", 0, 0) e[2]:SetHeight(g)
	e[3]:SetPoint("TOPLEFT", e[1], "BOTTOMLEFT", 0, 0) e[3]:SetPoint("BOTTOMLEFT", e[2], "TOPLEFT", 0, 0) e[3]:SetWidth(g)
	e[4]:SetPoint("TOPRIGHT", e[1], "BOTTOMRIGHT", 0, 0) e[4]:SetPoint("BOTTOMRIGHT", e[2], "TOPRIGHT", 0, 0) e[4]:SetWidth(g)
	return e
end

-- El velo (un marco con el borde y el tinte, sobre la barra y debajo de los
-- textos) y el resplandor (por fuera del marco).
local function piezas(c)
	if c.alfaPeligro then return c.alfaPeligro end
	local p = {}
	local capa = c.capa or c
	local v = CreateFrame("Frame", nil, c)
	v:SetAllPoints(c)
	if v.SetFrameLevel and capa.GetFrameLevel then v:SetFrameLevel(math.max(0, capa:GetFrameLevel() - 1)) end
	if v.EnableMouse then v:EnableMouse(false) end
	p.tinte = v:CreateTexture(nil, "BACKGROUND", nil, 1)
	p.tinte:SetTexture(BLANCO)
	p.tinte:SetAllPoints(c.barra or c)
	p.borde = cuatro(v, GROSOR, "ARTWORK")
	respirar(v, 1, 0.35, 0.8)
	v:Hide()
	p.velo = v
	-- El resplandor: un marco por fuera, 3 px, con cuatro franjas.
	local g = CreateFrame("Frame", nil, c)
	g:SetPoint("TOPLEFT", c, "TOPLEFT", -3, 3)
	g:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 3, -3)
	if g.SetFrameLevel and capa.GetFrameLevel then g:SetFrameLevel(capa:GetFrameLevel() + 2) end
	if g.EnableMouse then g:EnableMouse(false) end
	g.lados = cuatro(g, 2, "OVERLAY")
	for i = 1, 4 do g.lados[i]:SetVertexColor(NARANJA[1], NARANJA[2], NARANJA[3], 0.95) end
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

local function mezcla(p, modo)
	if p.alfaMezcla == modo then return end
	p.alfaMezcla = modo
	if p.tinte.SetBlendMode then p.tinte:SetBlendMode(modo) end
	for i = 1, 4 do if p.borde[i].SetBlendMode then p.borde[i]:SetBlendMode(modo) end end
end

-- Los colores normales (vida legible y marcos de prueba).
local function colores(p)
	mezcla(p, "BLEND")
	p.tinte:SetVertexColor(P.tinte[1], P.tinte[2], P.tinte[3], P.tinte[4])
	for i = 1, 4 do p.borde[i]:SetVertexColor(P.borde[1], P.borde[2], P.borde[3], P.borde[4]) end
end

local function quitar(p)
	latir(p.velo, false)
	p.velo:Hide()
end

local function poner(p)
	colores(p)
	p.velo:Show()
	latir(p.velo, true)
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
		if c.alfaPeligro then quitar(c.alfaPeligro) end
		return
	end
	local p = piezas(c)
	-- Legible: se compara y listo.
	local f, v = fraccionVida(u)
	if f then
		local bajo = v > 0 and f < M.UMBRAL_PELIGRO
		b.alfaEnPeligro = bajo or nil
		if bajo then poner(p) else quitar(p) end
		return
	end
	-- Secreta: suma luz con el color de la curva (negro arriba del umbral = nada).
	b.alfaEnPeligro = nil
	local cs = M.CurvasPeligro()
	if not (cs and UnitHealthPercent) then return quitar(p) end
	local ok = pcall(function()
		local cb = UnitHealthPercent(u, true, cs.borde)
		local ct = UnitHealthPercent(u, true, cs.tinte)
		local r, g, bb = cb:GetRGB()
		local tr, tg, tb = ct:GetRGB()
		mezcla(p, "ADD")
		for i = 1, 4 do p.borde[i]:SetVertexColor(r, g, bb, 1) end
		p.tinte:SetVertexColor(tr, tg, tb, 1)
	end)
	if not ok then
		colores(p)
		return quitar(p)
	end
	-- (fijo: con la vida secreta no se sabe si está bajo; no se anima de balde)
	latir(p.velo, false)
	p.velo:Show()
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
	if enPeligro then poner(p) else quitar(p) end
	local aggro = opt("amenaza") and e.amenaza and e[4] ~= "TANK" and not (e.muerto or e.desconectado)
	p.brillo:SetShown(aggro and true or false)
	latir(p.brillo, aggro)
end
