-- Alfa - Combate: «¡Sal de ahí!» (toxic3000 / La Jauría). GPL-3.0.
--
-- 1.3.7. Si estás parado en algo que daña (fuego, veneno o la sombra de un
-- jefe en el suelo), un aviso rojo breve en el centro y un sonido. Sin
-- registro de combate (está restringido en Forever): se leen solo tus
-- perjuicios con UNIT_AURA de "player" y C_UnitAuras.
--   * Lo que cuenta como «del suelo»: un perjuicio que no es tuyo, que no se
--     puede disipar y que dura muy poco (hasta 3 s) o nada (dura mientras
--     estás dentro), y que se renueva mientras sigues ahí (dos veces en 4 s),
--     o que no tiene duración.
--   * Solo dentro de instancias (mazmorras y bandas) y peleando.
--   * Cada valor se pregunta con issecretvalue antes de mirarlo. Si el juego
--     esconde esos datos, «Sal de ahí» se apaga solo hasta tu próxima zona.
--   * Ligero: el evento llega solo por "player" y solo se escucha dentro de
--     una instancia con el ajuste prendido.

local ADDON, M = ...
local N, A, K, L = M.N, M.A, M.K, M.L
local S = {}
M.SalDeAhi = S

local type, ipairs, pairs, pcall, max, tonumber, GetTime = type, ipairs, pairs, pcall, math.max, tonumber, GetTime

local VENTANA = 4       -- s en que se cuentan las renovaciones
local DURA_MAX = 3      -- s: lo que dura más no es del suelo
local A_LA_VISTA = 1.6  -- s del aviso en pantalla
local ENTRE_IGUAL = 5   -- s entre dos avisos por lo mismo
local ENTRE = 2.5       -- s entre dos avisos cualesquiera

local ev               -- el marco que escucha UNIT_AURA de "player"
local oculto = false   -- el juego esconde los datos: apagado hasta tu próxima zona
local vistos = {}      -- spellId -> { veces }
local ultimo = {}      -- spellId -> cuándo se avisó
local ultimoAviso = 0
local f

function S.Oculto() return oculto end

local function activo()
	if oculto or not M.Opt("salDeAhi") then return false end
	if not M.EnInstancia() then return false end
	return M.enPelea or (InCombatLockdown and InCombatLockdown()) or false
end

---------------------------------------------------------------------------
-- El aviso
---------------------------------------------------------------------------
local function crear()
	if f then return f end
	f = CreateFrame("Frame", "AlfaCombateSalDeAhi", K.Raiz())
	f:SetSize(320, 64)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
	f:SetFrameStrata("HIGH")
	f:EnableMouse(false)
	f.Icono = f:CreateTexture(nil, "ARTWORK")
	f.Icono:SetSize(36, 36)
	f.Texto = K.Texto(f, "cifra", "peligro")
	f.Texto:SetJustifyH("CENTER")
	f.Texto:SetPoint("CENTER", f, "CENTER", 22, 6)
	f.Icono:SetPoint("RIGHT", f.Texto, "LEFT", -10, 0)
	f.Nota = K.Texto(f, "pequeno", "textoSuave")
	f.Nota:SetJustifyH("CENTER")
	f.Nota:SetPoint("TOP", f.Texto, "BOTTOM", 0, -4)
	f:Hide()
	return f
end

-- a: { nombre, icono } (lo legible del perjuicio)
function S.Avisar(a)
	crear()
	K.Escribir(f.Texto, L["¡Sal de ahí!"])
	local icono = a and a.icono
	if icono then f.Icono:SetTexture(icono) f.Icono:Show() else f.Icono:Hide() end
	K.Escribir(f.Nota, a and a.nombre or "")
	f:SetAlpha(1)
	f:Show()
	if M.Opt("salDeAhiSonido") then M.Sonar("RAID_WARNING", 8959) end
	N.Una("combate.salDeAhi", A_LA_VISTA, function() if f then f:Hide() end end)
	return true
end

function S.Probar()
	return S.Avisar({ nombre = L["Así se ve cuando pisas algo que daña."], icono = 135805 })
end

function S.Marco() return f end

---------------------------------------------------------------------------
-- Leer tus perjuicios
---------------------------------------------------------------------------
-- Algo llegó secreto: el juego esconde los datos. Se apaga solo.
local function esconde()
	if oculto then return end
	oculto = true
	if ev then ev:UnregisterAllEvents() end
	if f then f:Hide() end
end

local function sec(v) return M.Secreto(v) end

-- -> true si es «del suelo» y hay que avisar ahora
function S.Revisar(a, ahora)
	if sec(a) or type(a) ~= "table" then return false end
	local danino, mio, id, dura, disipa, fuente = a.isHarmful, a.isFromPlayerOrPlayerPet, a.spellId, a.duration, a.dispelName, a.sourceUnit
	if sec(danino) or sec(mio) or sec(id) or sec(dura) or sec(disipa) or sec(fuente) then esconde() return false end
	if danino ~= true or mio == true or type(id) ~= "number" then return false end
	if disipa ~= nil and disipa ~= "" then return false end -- maldiciones, venenos que se curan: no son del suelo
	if type(dura) ~= "number" or dura > DURA_MAX then return false end
	if type(fuente) == "string" and fuente ~= "" then
		local jugador = M.Legible(M.Llamar(UnitPlayerControlled, fuente))
		if jugador == true then return false end
	end
	ahora = ahora or GetTime()
	local v = vistos[id]
	if not v then v = {} vistos[id] = v end
	local n = 0
	for i = #v, 1, -1 do if ahora - v[i] > VENTANA then table.remove(v, i) end end
	v[#v + 1] = ahora
	n = #v
	if n < 2 then
		if dura > 0 then return false end
		-- 1.3.7: sin duración, a la primera no: que se repita o que siga ahí en 1 s.
		local inst = a.auraInstanceID
		local fn = C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID
		if N.Una and type(fn) == "function" and not sec(inst) and type(inst) == "number" then
			N.Una("combate.salDeAhiSigue", 1, function()
				if oculto then return end
				local b = M.Llamar(fn, "player", inst)
				if sec(b) or type(b) ~= "table" or sec(b.spellId) or b.spellId ~= id then return end
				S.AvisarDe(a, id, GetTime())
			end)
		end
		return false
	end
	return S.AvisarDe(a, id, ahora)
end

-- Avisa (si no acaba de avisar). -> true si salió
function S.AvisarDe(a, id, ahora)
	if ultimo[id] and ahora - ultimo[id] < ENTRE_IGUAL then return false end
	if ahora - ultimoAviso < ENTRE then return false end
	ultimo[id], ultimoAviso = ahora, ahora
	local nombre, icono = M.Legible(a.name), M.Legible(a.icon)
	S.Avisar({ nombre = type(nombre) == "string" and nombre or nil, icono = icono })
	return true
end

local function porId(id)
	local fn = C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID
	if type(fn) ~= "function" then return nil end
	return M.Llamar(fn, "player", id)
end

function S.Evento(_, unidad, info)
	if unidad ~= "player" or not activo() then return end
	if sec(info) or type(info) ~= "table" then return end
	if sec(info.addedAuras) or sec(info.updatedAuraInstanceIDs) then esconde() return end
	local ahora = GetTime()
	if type(info.addedAuras) == "table" then
		for _, a in ipairs(info.addedAuras) do
			if oculto then return end
			if S.Revisar(a, ahora) then return end
		end
	end
	if type(info.updatedAuraInstanceIDs) == "table" then
		for _, id in ipairs(info.updatedAuraInstanceIDs) do
			if oculto then return end
			if not sec(id) and S.Revisar(porId(id), ahora) then return end
		end
	end
end

---------------------------------------------------------------------------
-- Escuchar solo cuando sirve
---------------------------------------------------------------------------
function S.Ver()
	local quiere = M.Opt("salDeAhi") and M.EnInstancia() and not oculto
	if quiere and not ev then
		ev = CreateFrame("Frame")
		ev:SetScript("OnEvent", function(_, evento, ...) K.Llamar(S.Evento, evento, ...) end)
	end
	if not ev then return end
	if quiere then
		if not (ev.IsEventRegistered and ev:IsEventRegistered("UNIT_AURA")) then
			if not pcall(ev.RegisterUnitEvent, ev, "UNIT_AURA", "player") then pcall(ev.RegisterEvent, ev, "UNIT_AURA") end
		end
	else
		ev:UnregisterAllEvents()
	end
end

-- Una zona nueva: se vuelve a intentar (en la anterior el juego escondía los datos).
A.RegisterEvent("PLAYER_ENTERING_WORLD", function()
	oculto = false
	for k in pairs(vistos) do vistos[k] = nil end
	K.Llamar(S.Ver)
end)
A.RegisterEvent("PLAYER_REGEN_ENABLED", function()
	for k in pairs(vistos) do vistos[k] = nil end
	if f then f:Hide() end
end)

A.OnLogin(function()
	M.Ensenar({ id = "combate.salDeAhi", icono = "ic-alerta",
		pregunta = L["¿Cómo sé que estoy parado en algo que daña?"],
		respuesta = L["En mazmorras y bandas, si pisas fuego, veneno o algo que deja un jefe en el suelo, Alfa te dice «¡Sal de ahí!» en rojo con un sonido. Lo apagas en Combate, en Ajustes."] })
end)
