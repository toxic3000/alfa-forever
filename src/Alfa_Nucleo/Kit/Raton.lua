-- Alfa - Kit: el ratón es del jugador (1.4.1). toxic3000 / La Jauría. GPL-3.0.
--
-- Bug de Toxic con la 1.4.0: «no le puedo picar a un enemigo lejos, la cámara
-- no se mueve, no puedo clicar las pestañas de profesiones ni el volumen». En
-- el juego, poner o enganchar OnMouseDown/OnMouseUp/OnEnter/OnLeave/OnMouseWheel
-- a un marco le PRENDE el ratón; un ancla invisible de Alfa (la de los
-- anuncios, 560x150 arriba del centro) se volvió una pared que se tragaba el
-- clic al mundo. Dos defensas para que no vuelva a pasar sin que se note:
--
--   K.SinRaton(marco, nombre)  un marco que NUNCA debe tomar el ratón (las
--       anclas: solo sostienen a otros). Se le apaga clic, paso y rueda ahora
--       y la guardia lo revisa: al entrar, al soltar Mayús, al cerrar
--       «Acomodar» y cada rato fuera de combate. Si algo se lo prendió, lo
--       apaga y lo anota en /alfa errores (para encontrar quién fue).
--   K.RevisarRaton() -> cuántos tuvo que apagar
--
--   /alfa raton     ¿quién se queda con tu clic? Lo que está bajo el ratón
--                   (de Alfa o del juego) y las paredes invisibles de Alfa que
--                   haya en pantalla. /alfa raton arreglar: les apaga el ratón.
--
-- Ningún marco de Alfa que no dibuje nada debe tomar el ratón: el banco lo
-- revisa en cada prueba (tools/banco/raton.lua, prueba_141_raton.lua).

local _, N = ...
local K = N.Kit
local A = N.A
local L = K.L

local type, pairs, ipairs, pcall, tostring, tonumber, format, rawget = type, pairs, ipairs, pcall, tostring, tonumber, string.format, rawget

local VIGILADOS = {} -- marco -> nombre
local anotados = {}  -- nombre -> true (cada pared se anota una vez por sesión)

local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end

local function tomaRaton(f)
	local ok, m = pcall(f.IsMouseEnabled, f)
	if ok and m then return true end
	if f.IsMouseWheelEnabled then
		local ok2, r = pcall(f.IsMouseWheelEnabled, f)
		if ok2 and r then return true end
	end
	return false
end

local function apagar(f)
	if f.IsProtected and f:IsProtected() and enCombate() then return false end
	pcall(f.EnableMouse, f, false)
	if f.EnableMouseWheel then pcall(f.EnableMouseWheel, f, false) end
	return true
end

function K.SinRaton(f, nombre)
	if type(f) ~= "table" or not f.EnableMouse then return f end
	VIGILADOS[f] = nombre or (f.GetName and f:GetName()) or "?"
	apagar(f)
	return f
end

function K.RevisarRaton()
	local n = 0
	for f, nombre in pairs(VIGILADOS) do
		if tomaRaton(f) and apagar(f) then
			n = n + 1
			if not anotados[nombre] then
				anotados[nombre] = true
				-- Que quede en /alfa errores y en el reporte: alguien le prendió el ratón.
				if N.AnotarError then
					N.AnotarError("Interface/AddOns/Alfa_Nucleo/Kit/Raton.lua: " .. tostring(nombre) .. " tomaba el ratón (apagado)",
						debugstack and debugstack(2, 4, 0) or nil)
				end
			end
		end
	end
	return n
end

-- K.Enganchar(marco, script, fn): HookScript que NO le prende el ratón al
-- marco (en el juego, enganchar OnEnter/OnMouseDown/OnMouseWheel lo prende).
-- Para marcos del juego o de otros addons (el minimapa, su contenedor, el
-- chat) y para anclas: el gancho solo corre si el marco ya tomaba el ratón.
local function leer(f, metodo)
	local m = f[metodo]
	if type(m) ~= "function" then return nil end
	local ok, v = pcall(m, f)
	if ok then return v and true or false end
	return nil
end
function K.Enganchar(f, script, fn)
	if type(f) ~= "table" or not f.HookScript then return false end
	local clic, paso, rueda = leer(f, "IsMouseClickEnabled"), leer(f, "IsMouseMotionEnabled"), leer(f, "IsMouseWheelEnabled")
	local ok = pcall(f.HookScript, f, script, fn)
	if not ok then return false end
	if f.IsProtected and f:IsProtected() and enCombate() then return true end
	if clic == false and leer(f, "IsMouseClickEnabled") and f.SetMouseClickEnabled then pcall(f.SetMouseClickEnabled, f, false) end
	if paso == false and leer(f, "IsMouseMotionEnabled") and f.SetMouseMotionEnabled then pcall(f.SetMouseMotionEnabled, f, false) end
	if rueda == false and leer(f, "IsMouseWheelEnabled") and f.EnableMouseWheel then pcall(f.EnableMouseWheel, f, false) end
	return true
end

---------------------------------------------------------------------------
-- La guardia
---------------------------------------------------------------------------
-- Las anclas del motor (se crean antes que el Núcleo): se buscan por nombre.
K.SIN_RATON_GLOBALES = { "AlfaNavPlacas" }

if A and A.RegisterEvent then
	A.RegisterEvent("PLAYER_ENTERING_WORLD", function()
		for _, nombre in ipairs(K.SIN_RATON_GLOBALES) do
			local f = rawget(_G, nombre)
			if type(f) == "table" and not VIGILADOS[f] then K.SinRaton(f, nombre) end
		end
		if N.Una then N.Una("kit.raton.entrar", 2, K.RevisarRaton) else K.RevisarRaton() end
		if N.Cada and not (N.HayTarea and N.HayTarea("kit.raton")) then
			N.Cada("kit.raton", 10, function() if not enCombate() then K.RevisarRaton() end end)
		end
	end)
	A.RegisterEvent("MODIFIER_STATE_CHANGED", function()
		if not (IsShiftKeyDown and IsShiftKeyDown()) then K.RevisarRaton() end
	end)
	A.RegisterEvent("PLAYER_REGEN_DISABLED", function() K.RevisarRaton() end)
end

---------------------------------------------------------------------------
-- /alfa raton
---------------------------------------------------------------------------
local function nombreDe(f)
	if type(f) ~= "table" then return "?" end
	if f.IsForbidden and f:IsForbidden() then return "(" .. L["marco protegido del juego"] .. ")" end
	local ok, n = pcall(function() return f.GetDebugName and f:GetDebugName() end)
	if ok and type(n) == "string" and n ~= "" then return n end
	-- Sin nombre: el camino de padres con nombre («AlfaRastreador.<marco>»).
	local partes, x = {}, f
	for _ = 1, 6 do
		if type(x) ~= "table" then break end
		local okN, nom = pcall(x.GetName, x)
		if okN and type(nom) == "string" and nom ~= "" then
			table.insert(partes, 1, nom)
			break
		end
		table.insert(partes, 1, "<" .. tostring(x.GetObjectType and x:GetObjectType() or "?") .. ">")
		local okP, p = pcall(x.GetParent, x)
		if not okP then break end
		x = p
	end
	return table.concat(partes, ".")
end

local function esDeAlfa(f)
	local x = f
	for _ = 1, 12 do
		if type(x) ~= "table" or (x.IsForbidden and x:IsForbidden()) then return false end
		local ok, n = pcall(x.GetName, x)
		if ok and type(n) == "string" and n:find("^Alfa") then return true end
		local ok2, p = pcall(x.GetParent, x)
		if not ok2 then return false end
		x = p
	end
	return false
end

local function alfaEfectiva(f)
	local ok, a = pcall(f.GetEffectiveAlpha, f)
	return ok and tonumber(a) or 1
end

-- ¿Dibuja algo que se vea? (una región a la vista con alfa, o un hijo que dibuje)
local function dibuja(f, prof)
	prof = prof or 0
	if prof > 5 then return false end
	local ok, regiones = pcall(function() return { f:GetRegions() } end)
	if ok then
		for _, r in ipairs(regiones) do
			local vis = pcall(r.IsVisible, r) and r:IsVisible()
			if vis and (tonumber(r:GetAlpha()) or 1) > 0.02 then
				local tipo = r.GetObjectType and r:GetObjectType()
				if tipo == "FontString" then
					local okT, t = pcall(r.GetText, r)
					if okT and (issecretvalue and issecretvalue(t) or (type(t) == "string" and t ~= "")) then return true end
				else
					return true
				end
			end
		end
	end
	local okH, hijos = pcall(function() return { f:GetChildren() } end)
	if okH then
		for _, h in ipairs(hijos) do
			if h.IsVisible and h:IsVisible() and dibuja(h, prof + 1) then return true end
		end
	end
	return false
end

-- Una zona de clic transparente dentro de un panel que sí se ve (la cabecera
-- del rastreador) no tapa nada nuevo: el panel ya está ahí.
local function dentroDeAlgoVisible(f)
	local ok, l, b, w, h = pcall(f.GetRect, f)
	if not ok or not (l and b and w and h) then return false end
	local okP, x = pcall(f.GetParent, f)
	if not okP then return false end
	for _ = 1, 8 do
		if type(x) ~= "table" or x == UIParent or (x.IsForbidden and x:IsForbidden()) then return false end
		local okN, n = pcall(x.GetName, x)
		if okN and n == "AlfaUIParent" then return false end
		if x:IsVisible() and alfaEfectiva(x) > 0.05 and dibuja(x) then
			local okR, pl, pb, pw, ph = pcall(x.GetRect, x)
			if okR and pl and l >= pl - 1 and b >= pb - 1 and l + w <= pl + pw + 1 and b + h <= pb + ph + 1 then return true end
		end
		local okX, p = pcall(x.GetParent, x)
		if not okX then return false end
		x = p
	end
	return false
end

-- Las paredes invisibles de Alfa: marcos de Alfa a la vista que toman el
-- ratón (clic o rueda) sin dibujar nada, o con alfa casi 0.
function K.ParedesRaton()
	local out = {}
	if not EnumerateFrames then return out end
	local f = EnumerateFrames()
	local vueltas = 0
	while f and vueltas < 200000 do
		vueltas = vueltas + 1
		if not (f.IsForbidden and f:IsForbidden()) and f.IsVisible and f:IsVisible() and tomaRaton(f) and esDeAlfa(f) then
			local ok, w, h = pcall(function() return f:GetWidth(), f:GetHeight() end)
			if ok and (tonumber(w) or 0) > 1 and (tonumber(h) or 0) > 1 and (alfaEfectiva(f) < 0.05 or not dibuja(f)) and not dentroDeAlgoVisible(f) then
				out[#out + 1] = { marco = f, nombre = nombreDe(f), w = w, h = h }
			end
		end
		f = EnumerateFrames(f)
	end
	return out
end

local function bajoElRaton()
	if GetMouseFoci then
		local ok, t = pcall(GetMouseFoci)
		if ok and type(t) == "table" then return t end
	end
	if GetMouseFocus then
		local ok, f = pcall(GetMouseFocus)
		if ok and f then return { f } end
	end
	return {}
end

local function comando(resto)
	resto = type(resto) == "string" and resto:lower() or ""
	if enCombate() then
		N.Imprimir(L["En combate no reviso el ratón: prueba al salir."])
		return
	end
	local arreglar = resto:find("arregl") or resto:find("fix")
	local foci = bajoElRaton()
	local mundo = true
	for _, f in ipairs(foci) do
		if f ~= WorldFrame then
			mundo = false
			N.Imprimir(format(L["Bajo tu ratón: %s%s"], nombreDe(f), esDeAlfa(f) and (" — " .. L["de Alfa"]) or ""))
		end
	end
	if mundo then N.Imprimir(L["Bajo tu ratón no hay nada: el clic va al mundo."]) end
	local paredes = K.ParedesRaton()
	if #paredes == 0 then
		N.Imprimir(L["Ninguna parte de Alfa tapa el ratón sin verse."])
		return
	end
	for _, p in ipairs(paredes) do
		N.Imprimir(format(L["Pared invisible de Alfa: %s (%dx%d)"], p.nombre, math.floor(tonumber(p.w) or 0), math.floor(tonumber(p.h) or 0)))
		if arreglar then apagar(p.marco) end
	end
	if arreglar then
		N.Imprimir(L["Listo: ya no toman el ratón. Cuéntale a Toxic qué salió aquí arriba."])
	else
		N.Imprimir(L["Escribe /alfa raton arreglar para quitarles el ratón ahora."])
	end
end

if A and A.RegisterCommand then
	A.RegisterCommand("raton", comando, L["¿quién se queda con tu clic? (y lo arregla)"])
end
