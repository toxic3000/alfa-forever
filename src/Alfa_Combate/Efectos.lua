-- Alfa - Combate: tus efectos a la vista (toxic3000 / La Jauría). GPL-3.0.
--
-- 1.3.7. Una fila chica de íconos con lo tuyo que corre: tus efectos de daño
-- en tu objetivo (venenos, sangrados, maldiciones, «DoT») y tus escudos y
-- curas que duran sobre ti, con lo que les queda. Si uno de tus efectos se
-- cae de tu objetivo en plena pelea, un aviso suave («Se acabó: Corrupción»).
--   * Apagado de fábrica (combate.efectos): sirve sobre todo a quien pone
--     efectos que duran (brujo, sacerdote, druida, cazador...).
--   * Solo datos de tus auras (C_UnitAuras con el filtro PLAYER). Lo secreto
--     no se lee: ese ícono no sale.
--   * Nada recibe el ratón; se mueve con «Mover marcos» o «Acomodar».

local ADDON, M = ...
local N, A, K, L = M.N, M.A, M.K, M.L
local E = {}
M.Efectos = E

local type, ipairs, pairs, pcall, floor, max, min, format, tonumber, tostring = type, ipairs, pairs, pcall, math.floor, math.max, math.min, string.format, tonumber, tostring

local TAM, MAX, ESPACIO = 26, 8, 3
local LARGO_MAX = 120 -- s: lo que dura más (un buff de una hora) no se muestra

local f, ev
local enObjetivo = {} -- spellId -> { hasta, nombre } de tu objetivo de ahora
local objetivo

local function numero(v) if M.Secreto(v) or type(v) ~= "number" then return nil end return v end

-- Tus auras en `unidad` con `filtro`: { { id, icono, hasta, dura, nombre } }
function E.Leer(unidad, filtro)
	local out = {}
	local fn = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
	if type(fn) ~= "function" then return out end
	for i = 1, 40 do
		local a = M.Llamar(fn, unidad, i, filtro)
		if M.Secreto(a) then out.secretos = true break end
		if type(a) ~= "table" then break end
		-- 1.3.7: una lectura secreta no es «se cayó» (Revisar no avisa con ella).
		if M.Secreto(a.spellId) or M.Secreto(a.expirationTime) or M.Secreto(a.duration) then out.secretos = true end
		local id, icono, hasta, dura = numero(a.spellId), M.Legible(a.icon), numero(a.expirationTime), numero(a.duration)
		local mio = M.Legible(a.isFromPlayerOrPlayerPet)
		if id and icono and mio ~= false and dura and dura > 0 and dura <= LARGO_MAX and hasta then
			local nombre = M.Legible(a.name)
			out[#out + 1] = { id = id, icono = icono, hasta = hasta, dura = dura, nombre = type(nombre) == "string" and nombre or nil }
			if #out >= MAX then break end
		end
	end
	return out
end

local function crear()
	if f then return f end
	f = M.Marco("Efectos", L["Tus efectos"], MAX * (TAM + ESPACIO), TAM + 16, { "CENTER", "CENTER", 0, -190 })
	f.iconos = {}
	for i = 1, MAX do
		local b = CreateFrame("Frame", nil, f)
		b:SetSize(TAM, TAM)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", (i - 1) * (TAM + ESPACIO), 0)
		b:EnableMouse(false)
		b.Tex = b:CreateTexture(nil, "ARTWORK")
		b.Tex:SetAllPoints(b)
		b.Tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		b.Barrido = M.CrearBarrido(b, b.Tex)
		b.Falta = K.Texto(b, "pequeno", "texto")
		b.Falta:SetJustifyH("CENTER")
		b.Falta:SetPoint("TOP", b, "BOTTOM", 0, -1)
		b:Hide()
		f.iconos[i] = b
	end
	f.Caida = K.Texto(f, "pequeno", "aviso")
	f.Caida:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 2)
	f:Hide()
	return f
end

local function texto(seg)
	seg = floor(seg + 0.5)
	if seg >= 60 then return format("%d:%02d", floor(seg / 60), seg % 60) end
	return tostring(seg)
end

local lista = {}
function E.Pintar()
	if not f then return end
	local ahora = GetTime()
	local n = 0
	for i, x in ipairs(lista) do
		local b = f.iconos[i]
		if not b then break end
		local falta = x.hasta - ahora
		if falta > 0 or x.prueba then
			n = n + 1
			b.Tex:SetTexture(x.icono)
			K.Escribir(b.Falta, texto(max(0, falta)))
			K.ColorTexto(b.Falta, falta <= 3 and "aviso" or "texto")
			b:Show()
		else
			b:Hide()
		end
	end
	for i = #lista + 1, MAX do f.iconos[i]:Hide() end
	return n
end

-- Se cayó uno de tus efectos de tu objetivo (aún peleando).
function E.Caida(nombre)
	if not (f and M.Opt("efectosAviso")) then return end
	K.Escribir(f.Caida, format(L["Se acabó: %s"], nombre or L["un efecto tuyo"]))
	f.Caida:Show()
	M.Sonar("MAP_PING", 3175)
	N.Una("combate.efectosCaida", 2.5, function() if f then f.Caida:Hide() end end)
end

function E.Revisar()
	if not M.Opt("efectos") then return end
	local peleando = M.enPelea or (InCombatLockdown and InCombatLockdown())
	local enemigo = M.HayEnemigo()
	local nuevos = enemigo and E.Leer("target", "HARMFUL|PLAYER") or {}
	-- ¿Se cayó alguno de tu objetivo (el mismo) antes de lo esperado o al acabarse?
	local guid = M.Legible(M.Llamar(UnitGUID, "target"))
	if peleando and enemigo and guid and guid == objetivo and not nuevos.secretos then
		local siguen = {}
		for _, x in ipairs(nuevos) do siguen[x.id] = true end
		for id, x in pairs(enObjetivo) do
			if not siguen[id] then E.Caida(x.nombre) break end
		end
	end
	for k in pairs(enObjetivo) do enObjetivo[k] = nil end
	for _, x in ipairs(nuevos) do enObjetivo[x.id] = x end
	objetivo = guid
	local propios = E.Leer("player", "HELPFUL|PLAYER")
	lista = {}
	for _, x in ipairs(nuevos) do lista[#lista + 1] = x end
	for _, x in ipairs(propios) do if #lista < MAX then lista[#lista + 1] = x end end
	if #lista == 0 and M.Desbloqueado() then
		lista = { { icono = 136118, hasta = GetTime() + 12, dura = 18, prueba = true } }
	end
	if #lista == 0 then
		if f then f:Hide() end
		N.Quitar("combate.efectos")
		return
	end
	crear()
	f:Show()
	for i, x in ipairs(lista) do
		local b = f.iconos[i]
		if b and b.Barrido and x.dura then pcall(b.Barrido.SetCooldown, b.Barrido, x.hasta - x.dura, x.dura) end
	end
	E.Pintar()
	N.Cada("combate.efectos", 0.25, function()
		if not (f and f:IsShown()) or (E.Pintar() or 0) == 0 then E.Revisar() end
	end)
end

function E.Ver()
	local quiere = M.Opt("efectos")
	if quiere and not ev then
		ev = CreateFrame("Frame")
		-- 1.3.7: UNIT_AURA llega muchas veces seguidas: una revisión cada 0,2 s.
		ev:SetScript("OnEvent", function()
			if N.HayTarea and N.HayTarea("combate.efectosJunta") then return end
			if N.Una then N.Una("combate.efectosJunta", 0.2, function() K.Llamar(E.Revisar) end)
			else K.Llamar(E.Revisar) end
		end)
	end
	if ev then
		if quiere then
			if not pcall(ev.RegisterUnitEvent, ev, "UNIT_AURA", "player", "target") then pcall(ev.RegisterEvent, ev, "UNIT_AURA") end
			pcall(ev.RegisterEvent, ev, "PLAYER_TARGET_CHANGED")
		else
			ev:UnregisterAllEvents()
		end
	end
	if quiere then
		E.Revisar()
	else
		lista = {}
		N.Quitar("combate.efectos")
		if f then f:Hide() end
	end
end

A.OnLogin(function()
	M.Ensenar({ id = "combate.efectos", icono = "ic-reloj",
		pregunta = L["¿Cuánto le queda a mis efectos?"],
		respuesta = L["Prende «Tus efectos a la vista» en Combate: una fila chica con tus venenos, maldiciones, escudos y curas que duran, con los segundos que les quedan. Si uno se cae en plena pelea, te avisa."] })
end)
