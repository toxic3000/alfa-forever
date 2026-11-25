-- Alfa - Núcleo: /alfa revisar (1.4.0). toxic3000 / La Jauría. GPL-3.0.
--
-- Recorre en el juego de verdad las páginas de Alfa (las que ves en tu modo)
-- una por una, y en cada una mira lo que está a la vista:
--   * errores de Lua de Alfa que salieron al abrirla (N.AnotarError);
--   * textos cortados (FontString:IsTruncated);
--   * ventanas de Alfa que se salen de la pantalla.
-- Solo reporta lo que falla; si nada falla, una línea que lo dice. Nunca en
-- combate: no empieza en combate y, si empieza uno a la mitad, se detiene
-- y deja todo como estaba. Una página por cada medio segundo (N.Una), nada
-- pesado de golpe. Al terminar vuelve a la página en la que estabas.
--   N.Revisar.Empezar() ; N.Revisar.Corriendo() ; N.Revisar.Revisar(marco, donde, out)

local _, N = ...
local A = N.A
local L = N.Kit and N.Kit.L or N.Textos(N.EN)

local type, ipairs, pairs, pcall, tostring, select = type, ipairs, pairs, pcall, tostring, select
local format = string.format

local R = {}
N.Revisar = R

local PROFUNDO = 14 -- niveles de marcos que se miran dentro de cada ventana
local TOPE = 40     -- problemas que se cuentan uno por uno
local MARGEN = 2    -- píxeles que una ventana puede pasarse del borde

local corriendo -- { cola, i, out, errores, volver }

local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end
local function secreto(v) return issecretvalue and issecretvalue(v) end

local function visible(f)
	local ok, v = pcall(f.IsVisible, f)
	return ok and v == true
end

local function texto(fs)
	local ok, t = pcall(fs.GetText, fs)
	if not ok or secreto(t) or type(t) ~= "string" or t == "" then return nil end
	t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("\n", " ")
	if #t > 48 then t = t:sub(1, 45):gsub("[\192-\255][\128-\191]*$", "") .. "…" end
	return t
end

local function nombreDe(f)
	local ok, n = pcall(f.GetName, f)
	return ok and type(n) == "string" and n or nil
end

local function agregar(out, linea)
	out.n = (out.n or 0) + 1
	if #out < TOPE then
		for i = 1, #out do if out[i] == linea then return end end
		out[#out + 1] = linea
	end
end

-- Lo que se mira de un marco y lo de adentro: textos cortados.
local function mirar(f, donde, out, nivel, vistos)
	if nivel > PROFUNDO or vistos[f] then return end
	vistos[f] = true
	if f.GetRegions then
		local regiones = { pcall(f.GetRegions, f) }
		for i = 2, #regiones do
			local r = regiones[i]
			if type(r) == "table" and r.IsTruncated and visible(r) then
				local ok, cortado = pcall(r.IsTruncated, r)
				if ok and cortado == true and not secreto(cortado) then
					local t = texto(r)
					if t then agregar(out, format(L["%s: texto cortado «%s»"], donde, t)) end
				end
			end
		end
	end
	if f.GetChildren then
		local hijos = { pcall(f.GetChildren, f) }
		for i = 2, #hijos do
			local h = hijos[i]
			if type(h) == "table" and visible(h) then mirar(h, donde, out, nivel + 1, vistos) end
		end
	end
end

-- Una ventana que se sale de la pantalla (solo las de arriba: lo de adentro
-- de una lista que se desplaza puede estar fuera a propósito).
local function fuera(f)
	local P = UIParent
	if not (P and f.GetLeft) then return false end
	local ok, l, r, t, b = pcall(function() return f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom() end)
	if not ok or type(l) ~= "number" or type(r) ~= "number" or type(t) ~= "number" or type(b) ~= "number" then return false end
	local s = (f.GetEffectiveScale and f:GetEffectiveScale() or 1) / (P.GetEffectiveScale and P:GetEffectiveScale() or 1)
	local w, h = P:GetWidth(), P:GetHeight()
	if type(w) ~= "number" or type(h) ~= "number" or w <= 0 or h <= 0 then return false end
	return l * s < -MARGEN or b * s < -MARGEN or r * s > w + MARGEN or t * s > h + MARGEN
end

-- Las ventanas de Alfa a la vista: hijas de UIParent con nombre «Alfa…».
local function ventanas()
	local out = {}
	local P = UIParent
	if not (P and P.GetChildren) then return out end
	local hijos = { pcall(P.GetChildren, P) }
	for i = 2, #hijos do
		local f = hijos[i]
		local n = type(f) == "table" and nombreDe(f)
		if n and n:find("^Alfa") and visible(f) then out[#out + 1] = f end
	end
	local o = A.UI and A.UI.Options and A.UI.Options.frame
	if o and visible(o) then
		local ya = false
		for _, f in ipairs(out) do if f == o then ya = true end end
		if not ya then out[#out + 1] = o end
	end
	return out
end

-- Revisa un marco suelto (para otros módulos y el banco). -> out
function R.Revisar(marco, donde, out)
	out = out or {}
	if type(marco) ~= "table" then return out end
	if fuera(marco) then agregar(out, format(L["%s: la ventana %s se sale de la pantalla"], donde, nombreDe(marco) or "?")) end
	mirar(marco, donde, out, 1, {})
	return out
end

local function cuentaErrores()
	local n = 0
	for _, e in ipairs(N.Errores and N.Errores() or {}) do n = n + (tonumber(e.n) or 1) end
	return n
end

local function ultimoError()
	local l = N.Errores and N.Errores() or {}
	local e = l[#l]
	return e and e.msg or "?"
end

local function terminar(motivo)
	local c = corriendo
	corriendo = nil
	if N.Quitar then N.Quitar("nucleo.revisar") end
	if not c then return end
	local O = A.UI and A.UI.Options
	-- (en combate solo se cierra la ventana de Alfa: nada se abre)
	if c.volver and motivo ~= "combate" then pcall(N.Abrir, c.volver)
	elseif O and O.frame and O.frame.Hide then pcall(O.frame.Hide, O.frame) end
	if motivo == "combate" then
		N.Imprimir(L["Revisar: paré porque empezó un combate. Nada cambió; vuelve a probar al terminar."])
		return
	end
	local out = c.out
	if (out.n or 0) == 0 then
		N.Imprimir(format(L["Revisar: %d páginas revisadas, todo bien."], c.i))
		return
	end
	N.Imprimir(format(L["Revisar: %d páginas revisadas, %d cosas por arreglar:"], c.i, out.n))
	for _, linea in ipairs(out) do N.Imprimir("  · " .. linea) end
	if out.n > #out then N.Imprimir(format(L["  … y %d más."], out.n - #out)) end
end

local function paso()
	local c = corriendo
	if not c then return end
	if enCombate() then return terminar("combate") end
	-- Lo que se abrió en el paso anterior ya se dibujó: se mira.
	local anterior = c.cola[c.i]
	if anterior then
		local donde = anterior.nombre
		local e = cuentaErrores()
		if e > c.errores then agregar(c.out, format(L["%s: error de Lua (%s)"], donde, ultimoError())) end
		c.errores = e
		for _, f in ipairs(ventanas()) do R.Revisar(f, donde, c.out) end
	end
	c.i = c.i + 1
	local sig = c.cola[c.i]
	if not sig then
		c.i = c.i - 1
		return terminar()
	end
	pcall(N.Abrir, sig.id)
	N.Una("nucleo.revisar", 0.5, paso)
end

function R.Corriendo() return corriendo ~= nil end

function R.Empezar()
	if corriendo then return false end
	if enCombate() then
		N.Imprimir(L["Revisar espera a que termine el combate."])
		return false
	end
	local cola = {}
	for _, m in ipairs(N.modulos or {}) do
		if type(m.id) == "string" and (not N.PaginaVisible or N.PaginaVisible(m.id)) then
			cola[#cola + 1] = { id = m.id, nombre = m.nombre or m.id }
		end
	end
	local O = A.UI and A.UI.Options
	local abierta = O and O.frame and visible(O.frame)
	corriendo = { cola = cola, i = 0, out = {}, errores = cuentaErrores(), volver = abierta and O.ultimaVista or nil }
	N.Imprimir(format(L["Revisar: voy a abrir %d páginas de Alfa, una por una. No juegues mientras tanto."], #cola))
	N.Una("nucleo.revisar", 0.2, paso)
	return true
end

if A.RegisterEvent then
	A.RegisterEvent("PLAYER_REGEN_DISABLED", function() if corriendo then terminar("combate") end end)
end
if A.RegisterCommand then
	A.RegisterCommand("revisar", function() R.Empezar() end, L["abre cada página de Alfa y te dice solo lo que falla (errores, textos cortados, ventanas fuera de la pantalla)"])
end
