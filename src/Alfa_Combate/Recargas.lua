-- Alfa - Combate: tus recargas largas (toxic3000 / La Jauría). GPL-3.0.
--
-- 1.3.0. Una barra discreta con tus habilidades de recarga larga (30 s o más,
-- combate.recargasMin) mientras corren: su ícono, el barrido y lo que falta.
-- Cuando vuelve a estar lista, se va sola. Solo datos de tu personaje:
--   * UNIT_SPELLCAST_SUCCEEDED del jugador: lo que lanzaste y cuándo;
--   * su recarga con C_Spell.GetSpellCooldown. Si llega secreta (combate en
--     mazmorras), isActive (nunca secreto) dice si sigue y lo que falta se
--     estima con la duración que Alfa vio cuando sí se podía leer
--     (AlfaNucleoCharDB.combate.recargas, la misma tabla de Prioridad.lua).
--   * Las que conoces se recuerdan (combate.largas) para que elijas en la
--     página cuáles no quieres ver (combate.recargasOcultas, por nombre).
-- Sin OnUpdate: un reloj de medio segundo solo mientras alguna corre. Nada
-- recibe el ratón.

local ADDON, M = ...
local N, A, K, L = M.N, M.A, M.K, M.L
local Rg = {}
M.Recargas = Rg

local type, pairs, ipairs, pcall, floor, max, min, format, tonumber, sort = type, pairs, ipairs, pcall, math.floor, math.max, math.min, string.format, tonumber, table.sort
local ESP = K.ESP
local GCD = 1.6
local TAM = 30
local MAX = 8

local ultimo = {}  -- nombre -> cuándo lo lanzaste
local activas = {} -- nombre -> { id, nombre, inicio, dur }

local function numero(v)
	if M.Secreto(v) or type(v) ~= "number" then return nil end
	return v
end

local function datos()
	local d = N.DatosPersonaje(M.ID)
	if type(d.recargas) ~= "table" then d.recargas = {} end
	if type(d.largas) ~= "table" then d.largas = {} end
	if type(d.recargasOcultas) ~= "table" then d.recargasOcultas = {} end
	return d
end

function Rg.Minimo()
	local v = floor(tonumber(M.Opt("recargasMin")) or 30)
	return max(30, min(300, v))
end

---------------------------------------------------------------------------
-- Lo que falta de una recarga
---------------------------------------------------------------------------
-- -> segundos que faltan (0: lista) o nil si sigue en recarga pero no se
--    sabe cuánto; y la duración total si se conoce.
function Rg.Falta(id)
	local nombre = M.NombreHechizo(id)
	local vista = nombre and tonumber(datos().recargas[nombre]) or nil
	local fn = C_Spell and C_Spell.GetSpellCooldown
	if fn then
		local info = M.Llamar(fn, id)
		if type(info) == "table" and not M.Secreto(info) then
			local s, d = numero(info.startTime), numero(info.duration)
			if s and d then
				if d > GCD then return max(0, s + d - GetTime()), d end
				return 0, vista
			end
			local activa, global = M.Legible(info.isActive), M.Legible(info.isOnGCD)
			if activa == true and global ~= true then
				local t = nombre and ultimo[nombre]
				if t and vista then return max(0, t + vista - GetTime()), vista end
				return nil, vista
			end
			return 0, vista
		end
	end
	local s, d = A.Compat.GetSpellCooldown(id)
	if d > GCD then return max(0, s + d - GetTime()), d end
	return 0, vista
end

function Rg.Tiempo(seg)
	seg = floor((seg or 0) + 0.5)
	if seg >= 60 then return format("%d:%02d", floor(seg / 60), seg % 60) end
	return tostring(seg)
end

---------------------------------------------------------------------------
-- La lista configurable
---------------------------------------------------------------------------
-- Las de recarga larga que conoces: { { nombre, id, dur, oculta } }, por duración.
function Rg.Conocidas()
	local d, out = datos(), {}
	local minimo = Rg.Minimo()
	for nombre, x in pairs(d.largas) do
		local dur = type(x) == "table" and tonumber(x.dur) or nil
		local id = type(x) == "table" and tonumber(x.id) or nil
		if id and dur and dur >= minimo and M.Conoce(id) then
			out[#out + 1] = { nombre = nombre, id = id, dur = dur, oculta = d.recargasOcultas[nombre] == true }
		end
	end
	sort(out, function(a, b) if a.dur ~= b.dur then return a.dur > b.dur end return a.nombre < b.nombre end)
	return out
end

function Rg.Oculta(nombre) return datos().recargasOcultas[nombre] == true end

function Rg.Ocultar(nombre, on)
	if type(nombre) ~= "string" then return end
	datos().recargasOcultas[nombre] = on and true or nil
	if on then activas[nombre] = nil end
	Rg.Pintar()
	M.Avisar()
end

function Rg.Activas()
	local out = {}
	for _, x in pairs(activas) do out[#out + 1] = { nombre = x.nombre, id = x.id, falta = max(0, x.inicio + x.dur - GetTime()) } end
	sort(out, function(a, b) return a.falta < b.falta end)
	return out
end

---------------------------------------------------------------------------
-- La barra
---------------------------------------------------------------------------
local f, reloj

local function cuadro(i)
	local b = CreateFrame("Frame", nil, f)
	b:SetSize(TAM, TAM)
	b.caja = K.Caja(b, { fondo = "hundido", borde = "lineaFuerte", corte = K.CORTE.casilla })
	b.Icono = b:CreateTexture(nil, "ARTWORK")
	b.Icono:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
	b.Icono:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
	b.Icono:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.Recarga = M.CrearBarrido(b, b.Icono)
	b.Capa = CreateFrame("Frame", nil, b)
	b.Capa:SetAllPoints(b)
	b.Capa:SetFrameLevel(b:GetFrameLevel() + 6)
	b.Texto = K.Texto(b.Capa, "insignia", "texto")
	b.Texto:SetPoint("BOTTOM", b, "BOTTOM", 0, 2)
	b:Hide()
	return b
end

local function crear()
	if f then return f end
	f = M.Marco("Recargas", L["Recargas largas"], TAM * 4 + ESP.xs * 3, TAM, { "CENTER", "CENTER", 0, -262 })
	f.cuadros = {}
	f:Hide()
	return f
end

local function sinReloj()
	if reloj then reloj:Cancel() reloj = nil end
end

local function lista()
	local out = {}
	for _, x in pairs(activas) do out[#out + 1] = x end
	sort(out, function(a, b) return (a.inicio + a.dur) < (b.inicio + b.dur) end)
	return out
end

-- Repasa lo que corre (quita lo que ya volvió) y lo pinta.
function Rg.Pintar()
	if not M.Opt("recargas") then
		if f then f:Hide() end
		sinReloj()
		return
	end
	local ahora = GetTime()
	for nombre, x in pairs(activas) do
		local falta = Rg.Falta(x.id)
		if falta == 0 or ahora > x.inicio + x.dur + 1 or Rg.Oculta(nombre) then activas[nombre] = nil
		elseif falta then x.inicio, x.dur = ahora + falta - x.dur, x.dur end
	end
	local xs = lista()
	if #xs == 0 and not M.Desbloqueado() then
		if f then f:Hide() end
		sinReloj()
		return
	end
	crear()
	local n = 0
	if #xs == 0 then
		-- Mientras lo mueves: el lobo dormido en su lugar.
		n = 1
		local b = f.cuadros[1] or cuadro(1)
		f.cuadros[1] = b
		b.Icono:SetTexture(K.Lobo("dormido"))
		b.Icono:SetVertexColor(K.Color("textoTenue"))
		b.Texto:SetText("")
		if b.Recarga then pcall(b.Recarga.Clear, b.Recarga) end
		b.alfaId = nil
		b:SetPoint("LEFT", f, "LEFT", 0, 0)
		b:Show()
	end
	for i, x in ipairs(xs) do
		if i > MAX then break end
		n = i
		local b = f.cuadros[i] or cuadro(i)
		f.cuadros[i] = b
		if b.alfaId ~= x.id or b.alfaInicio ~= x.inicio then
			b.alfaId, b.alfaInicio = x.id, x.inicio
			b.Icono:SetTexture(M.IconoHechizo(x.id) or K.Lobo("normal"))
			b.Icono:SetVertexColor(1, 1, 1, 1)
			if b.Recarga then pcall(b.Recarga.SetCooldown, b.Recarga, x.inicio, x.dur) end
		end
		b.Texto:SetText(Rg.Tiempo(max(0, x.inicio + x.dur - ahora)))
		b:ClearAllPoints()
		b:SetPoint("LEFT", f, "LEFT", (i - 1) * (TAM + ESP.xs), 0)
		b:Show()
	end
	for i = n + 1, #f.cuadros do f.cuadros[i].alfaId = nil f.cuadros[i]:Hide() end
	f:SetSize(max(TAM, n * (TAM + ESP.xs) - ESP.xs), TAM)
	f:Show()
	if #xs > 0 and not reloj then reloj = N.Ticker("combate.recargas", 0.5, Rg.Pintar) end
	if #xs == 0 then sinReloj() end
end

Rg.Ver = Rg.Pintar

local pendiente = false
function Rg.Pedir()
	if pendiente or next(activas) == nil then return end
	pendiente = true
	A.After(0.1, function() pendiente = false Rg.Pintar() end)
end

---------------------------------------------------------------------------
-- Lo que lanzas
---------------------------------------------------------------------------
-- Tras lanzar: ¿tiene recarga larga? Se anota su duración y, si cuenta, entra.
function Rg.Revisar(id)
	local nombre = M.NombreHechizo(id)
	if not nombre then return end
	local d = datos()
	local falta, dur = Rg.Falta(id)
	dur = dur or tonumber(d.recargas[nombre])
	if not dur or dur <= GCD then return end
	d.recargas[nombre] = dur
	if dur >= 30 then d.largas[nombre] = { id = id, dur = floor(dur + 0.5) } end
	if dur < Rg.Minimo() or Rg.Oculta(nombre) or not M.Opt("recargas") then return end
	if falta == 0 then return end
	local ahora = GetTime()
	local resta = falta or max(0, (ultimo[nombre] or ahora) + dur - ahora)
	activas[nombre] = { id = id, nombre = nombre, inicio = ahora + resta - dur, dur = dur }
	Rg.Pintar()
end

function Rg.Lanzaste(id)
	if M.Secreto(id) or type(id) ~= "number" then return end
	local nombre = M.NombreHechizo(id)
	if not nombre then return end
	ultimo[nombre] = GetTime()
	A.After(0.2, function() K.Llamar(Rg.Revisar, id) end)
end

local ev = CreateFrame("Frame")
if not pcall(ev.RegisterUnitEvent, ev, "UNIT_SPELLCAST_SUCCEEDED", "player") then
	pcall(ev.RegisterEvent, ev, "UNIT_SPELLCAST_SUCCEEDED")
end
ev:SetScript("OnEvent", function(_, _, unidad, _, id)
	if unidad ~= "player" then return end
	K.Llamar(Rg.Lanzaste, id)
end)

A.OnLogin(function()
	M.Ensenar({ id = "combate.recargas", icono = "ic-reloj",
		pregunta = L["¿Cómo sé cuándo vuelven mis habilidades grandes?"],
		respuesta = L["Cuando usas una habilidad que tarda 30 segundos o más en volver, Alfa la pone en una barra discreta con lo que le falta. En Combate eliges cuáles no quieres ver."] })
end)
