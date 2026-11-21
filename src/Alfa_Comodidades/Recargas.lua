-- Alfa - Comodidades: números en las recargas de tus barras (1.3.7).
-- toxic3000 / La Jauría. GPL-3.0.
--
-- Sobre cada botón de acción que espera su recarga sale cuánto le falta, en
-- grande, con la letra del estilo de las barras; el color cambia según lo que
-- falta (blanco, amarillo los últimos 10 s, rojo los últimos 3) y, al quedar
-- lista, el botón da un destello corto. La recarga global (1.5 s) no cuenta.
--
-- Cómo, sin estorbar:
--   * El juego ya sabe poner números en una recarga (Cooldown:
--     SetHideCountdownNumbers / GetCountdownFontString, FrameAPICooldown-
--     Documentation): se usan esos. Así siguen funcionando aunque la recarga
--     llegue en secreto (combate en mazmorras): el número lo pone el juego.
--     Alfa solo cambia su letra, su tamaño y su color.
--   * Un cliente sin esos números: un texto propio sobre el botón, solo con
--     valores que se pueden leer.
--   * Lo que pasa se sabe con hooksecurefunc(cooldown, "SetCooldown"/"Clear")
--     y HookScript("OnCooldownDone"): nada de OnUpdate por botón. El color y
--     el texto propio los mueve un solo reloj de Alfa (N.Cada), solo mientras
--     alguna recarga legible corre.
--   * Los botones son seguros: no se mueve, cambia ni se les pone nada; la
--     capa del destello es un marco de Alfa hijo del botón, sin ratón, y se
--     arma fuera de combate. Al apagarlo vuelve todo como estaba.
-- Ajustes: comodidades.recargas (de fábrica, apagado), recargasColor y
-- recargasDestello (encendidos).

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local K = N.Kit

local Rc = {}
M.Recargas = Rc

local type, pairs, pcall, floor, ceil, max, min, format, next = type, pairs, pcall, math.floor, math.ceil, math.max, math.min, string.format, next

local GCD = 1.6          -- una recarga de hasta esto es la global: no lleva número ni destello
local MIN_DESTELLO = 2.5 -- segundos que debió durar para destellar al quedar lista
local RELOJ = "comodidades.recargas"
local CADA = 0.2

local registros = {} -- cooldown -> r
local activos = {}   -- cooldown -> r (con su fin legible)

local function on(k) return M.On("recargas", k) end
local function ahora() return GetTime and GetTime() or 0 end
local function legible(v) v = M.Legible(v) return type(v) == "number" and v or nil end

local function delJuego(cd)
	return type(cd.SetHideCountdownNumbers) == "function" and type(cd.GetCountdownFontString) == "function"
end

local function cooldownDe(b)
	if type(b) ~= "table" then return nil end
	local cd = rawget(b, "cooldown")
	if type(cd) ~= "table" and b.GetName then
		local ok, n = pcall(b.GetName, b)
		if ok and type(n) == "string" then cd = rawget(_G, n .. "Cooldown") end
	end
	if type(cd) == "table" and type(cd.SetCooldown) == "function" then return cd end
	return nil
end

---------------------------------------------------------------------------
-- Lo que se ve
---------------------------------------------------------------------------

-- 75 -> "2m", 12.3 -> "13", 2.34 -> "2.3"
function Rc.Formato(falta)
	if falta >= 3600 then return format(L["%dh [recarga]"], ceil(falta / 3600)) end
	if falta >= 60 then return format(L["%dm [recarga]"], ceil(falta / 60)) end
	if falta >= 3 then return tostring(ceil(falta)) end
	return format("%.1f", max(0, falta))
end

-- El color según lo que falta.
function Rc.Tono(falta)
	if falta <= 3 then return "peligro" end
	if falta <= 10 then return "aviso" end
	return "texto"
end

local function textoDe(r)
	if r.fs then return r.fs end
	if delJuego(r.cd) then
		local ok, fs = pcall(r.cd.GetCountdownFontString, r.cd)
		if ok and type(fs) == "table" then return fs end
	end
	return nil
end

local function tamano(r)
	local w = r.b.GetWidth and tonumber(r.b:GetWidth()) or 36
	return max(12, min(20, floor(w * 0.45 + 0.5)))
end

local function cara()
	return M.CaraDe(M.EstiloDe("barrasEstilo"), "semibold") or K.Cara("semibold")
end

local function letra(r)
	local fs = textoDe(r)
	if not (fs and fs.SetFont) then return end
	if r.letraAntes == nil and fs.GetFont then
		local f, t, b = fs:GetFont()
		r.letraAntes = { f, t, b }
	end
	K.FuenteSegura(fs, cara(), tamano(r), "OUTLINE")
end

local function colorBlanco(r)
	local fs = textoDe(r)
	if fs and fs.SetTextColor then fs:SetTextColor(1, 1, 1, 1) end
end

local function pintar(r, falta)
	local fs = textoDe(r)
	if not fs then return end
	if r.fs then K.Escribir(r.fs, Rc.Formato(falta)) end
	if on("recargasColor") then
		local tono = Rc.Tono(falta)
		if tono ~= r.tono then
			r.tono = tono
			fs:SetTextColor(K.Color(tono))
		end
	elseif r.tono then
		r.tono = nil
		colorBlanco(r)
	end
end

local function apagarTexto(r)
	if r.fs then K.Escribir(r.fs, "") end
	if r.tono then r.tono = nil colorBlanco(r) end
end

-- El destello al quedar lista: la capa sube y se desvanece (una animación del
-- juego; sin animaciones, un solo paso del reloj la apaga).
function Rc.Destello(r)
	if not (r.brillo and on("recargasDestello")) then return false end
	r.destellos = (r.destellos or 0) + 1
	r.brillo:SetAlpha(0.75)
	r.brillo:Show()
	if r.anim and r.anim.Play then
		if r.anim.Stop then r.anim:Stop() end
		r.anim:Play()
	else
		N.Una("comodidades.destello", 0.35, function()
			for _, x in pairs(registros) do if x.brillo then x.brillo:SetAlpha(0) end end
		end)
	end
	return true
end

---------------------------------------------------------------------------
-- El reloj: solo mientras alguna recarga legible corre
---------------------------------------------------------------------------
local function tic()
	local t = ahora()
	for cd, r in pairs(activos) do
		local falta = r.fin and (r.fin - t) or 0
		if falta <= 0 then
			activos[cd] = nil
			apagarTexto(r)
		else
			pintar(r, falta)
		end
	end
	if next(activos) == nil then N.Quitar(RELOJ) end
end
Rc.Tic = tic

local function despertar()
	if not N.HayTarea(RELOJ) then N.Cada(RELOJ, CADA, tic) end
end

---------------------------------------------------------------------------
-- Lo que cuenta el juego
---------------------------------------------------------------------------
local function alPoner(r, inicio, dur)
	if not M.Get("recargas") then return end
	local t = ahora()
	if not r.corriendo then r.corriendo, r.desde = true, t end
	local i, d = legible(inicio), legible(dur)
	if i and d then
		if d <= 0 then return end
		if d <= GCD then
			-- La global: si no hay una de verdad corriendo, no lleva número.
			if r.fin and r.fin > t then return end
			r.fin = nil
			activos[r.cd] = nil
			apagarTexto(r)
			return
		end
		r.fin, r.dur = i + d, d
		activos[r.cd] = r
		pintar(r, r.fin - t)
		despertar()
	else
		-- En secreto: el número lo pone el juego (si sabe); sin color propio.
		r.fin = nil
		activos[r.cd] = nil
		apagarTexto(r)
	end
end
Rc.AlPoner = alPoner

local function alQuitar(r, terminada)
	local t = ahora()
	-- El juego puede limpiarla (Clear) justo al terminar, antes de OnCooldownDone:
	-- si su fin legible es ahora, también cuenta como lista.
	if not terminada and r.fin and r.dur and r.dur > GCD and math.abs(r.fin - t) < 0.5 then terminada = true end
	if terminada and r.corriendo and r.desde and (t - r.desde) >= MIN_DESTELLO and M.Get("recargas") then
		Rc.Destello(r)
	end
	r.corriendo, r.desde, r.fin = false, nil, nil
	activos[r.cd] = nil
	apagarTexto(r)
end
Rc.AlQuitar = alQuitar

---------------------------------------------------------------------------
-- Preparar cada botón (fuera de combate, una sola vez)
---------------------------------------------------------------------------
local function preparar(b)
	local cd = cooldownDe(b)
	if not cd then return nil end
	local r = registros[cd]
	if r then return r end
	r = { cd = cd, b = b }
	registros[cd] = r
	hooksecurefunc(cd, "SetCooldown", function(_, inicio, dur) M.Seguro(alPoner, r, inicio, dur) end)
	if type(cd.Clear) == "function" then
		hooksecurefunc(cd, "Clear", function() M.Seguro(alQuitar, r, false) end)
	end
	if cd.HookScript then
		cd:HookScript("OnCooldownDone", function() M.Seguro(alQuitar, r, true) end)
	end
	-- La capa del destello (y del número propio): de Alfa, sin ratón.
	local capa = CreateFrame("Frame", nil, b)
	capa:SetAllPoints(b)
	capa:EnableMouse(false)
	local nivel = (cd.GetFrameLevel and cd:GetFrameLevel()) or (b.GetFrameLevel and b:GetFrameLevel()) or 1
	capa:SetFrameLevel(nivel + 2)
	r.capa = capa
	r.brillo = capa:CreateTexture(nil, "OVERLAY")
	r.brillo:SetAllPoints(capa)
	r.brillo:SetColorTexture(1, 1, 1, 1)
	if r.brillo.SetBlendMode then r.brillo:SetBlendMode("ADD") end
	r.brillo:SetAlpha(0)
	if capa.CreateAnimationGroup then
		local g = capa:CreateAnimationGroup()
		local a = g and g.CreateAnimation and g:CreateAnimation("Alpha")
		if a and a.SetTarget then
			a:SetTarget(r.brillo)
			a:SetFromAlpha(0.75)
			a:SetToAlpha(0)
			a:SetDuration(0.45)
			g:SetScript("OnFinished", function() r.brillo:SetAlpha(0) end)
			r.anim = g
		end
	end
	if not delJuego(cd) then
		r.fs = capa:CreateFontString(nil, "OVERLAY")
		K.FuenteSegura(r.fs, cara(), tamano(r), "OUTLINE")
		r.fs:SetPoint("CENTER", capa, "CENTER", 0, 0)
		r.fs:SetText("")
	end
	return r
end

-- Encender: cada botón usa los números del juego (o el texto propio) con la letra de Alfa.
local function encender()
	local lista = M.BotonesDeAccion and M.BotonesDeAccion() or {}
	for _, b in ipairs(lista) do
		local r = preparar(b)
		if r then
			if not r.fs and delJuego(r.cd) then
				if r.ocultoAntes == nil and type(r.cd.GetHideCountdownNumbers) == "function" then
					local ok, v = pcall(r.cd.GetHideCountdownNumbers, r.cd)
					r.ocultoAntes = ok and M.Legible(v) and true or false
				end
				pcall(r.cd.SetHideCountdownNumbers, r.cd, false)
			end
			if r.capa then r.capa:Show() end
			letra(r)
		end
	end
end

-- Apagar: los números del juego como los tenías, su letra y su color.
local function apagar()
	for cd, r in pairs(registros) do
		activos[cd] = nil
		r.corriendo, r.fin = false, nil
		apagarTexto(r)
		if r.capa then r.capa:Hide() end
		if not r.fs and r.ocultoAntes ~= nil and delJuego(cd) then
			pcall(cd.SetHideCountdownNumbers, cd, r.ocultoAntes)
			r.ocultoAntes = nil
		end
		local fs = textoDe(r)
		if fs and r.letraAntes and r.letraAntes[1] then
			pcall(fs.SetFont, fs, r.letraAntes[1], r.letraAntes[2], r.letraAntes[3])
		end
		r.letraAntes = nil
	end
	N.Quitar(RELOJ)
end

local function aplicar()
	if M.Get("recargas") then encender() else apagar() end
end
Rc.Aplicar = aplicar

M.AlCambiar({ "recargas", "recargasColor", "recargasDestello", "barras", "barrasEstilo" },
	function() N.FueraDeCombate("comodidades.recargas", aplicar) end)

-- El estilo de las barras cambia la letra.
M.AlCambiarAspecto(function()
	if M.Get("recargas") then N.FueraDeCombate("comodidades.recargas", aplicar) end
end)

-- Para pruebas.
Rc.Registros = registros
Rc.Activos = activos
Rc.Preparar = preparar
