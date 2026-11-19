-- Alfa - Rutas: la siguiente guía, sola (toxic3000 / La Jauría). GPL-3.0.
-- 1.2.9
--
-- Al terminar una guía de zona (el fin del motor, GUIDE_END, o
-- M.GuiaTerminada: todos sus pasos hechos), si el motor no trae una que siga
-- ni caminos para elegir, Alfa propone la siguiente para tu nivel con un clic:
-- «Seguir con <guía>». Es la primera de las sugeridas del motor
-- (Guides.Suggestions: tu nivel, tu zona y lo más cerca) que no sea la que
-- terminaste ni una ya hecha. Ajuste rutas.siguienteGuia.
--
--   Siguiente.Proponer(sinId) -> { id, nombre } | nil
--   Siguiente.Seguir(p)                 la abre (en la pestaña de ahora) y te lleva

local ADDON, M = ...
local A, L = M.A, M.L
local Sg = {}
M.Siguiente = Sg

A.RegisterDefaults(M.ID, { siguienteGuia = true })

local type, ipairs, pcall = type, ipairs, pcall

local function encendido() return A.Get(M.ID .. ".siguienteGuia") ~= false end

local function etiqueta(h)
	local u = A.UI
	if u and type(u.GuideLabel) == "function" then
		local ok, s = pcall(u.GuideLabel, h)
		if ok and type(s) == "string" and s ~= "" then return s end
	end
	return h.title or h.id
end

-- Lo propuesto vale unos segundos (el rastreador pregunta en cada repintado
-- y las sugerencias del motor miden caminos).
local VIGENCIA = 10
local guardada -- { sin, at, p }

function Sg.Olvidar() guardada = nil end

function Sg.Proponer(sinId)
	if not encendido() then return nil end
	local Gd, E = A.Guides, A.Engine
	if not (Gd and type(Gd.Suggestions) == "function") then return nil end
	if not sinId and E and E.GetGuide then
		local g = E.GetGuide()
		sinId = type(g) == "table" and g.id or nil
	end
	local ahora = GetTime and GetTime() or 0
	if guardada and guardada.sin == sinId and ahora - guardada.at < VIGENCIA then return guardada.p or nil end
	local p = Sg.Buscar(sinId)
	guardada = { sin = sinId, at = ahora, p = p or false }
	return p
end

function Sg.Buscar(sinId)
	local Gd, E = A.Guides, A.Engine
	local ok, lista = pcall(Gd.Suggestions)
	if not ok or type(lista) ~= "table" then return nil end
	for _, id in ipairs(lista) do
		if id ~= sinId and not (M.Guias and M.Guias.Especial and M.Guias.Especial(id)) then
			local estado = E and E.GetGuideState and select(2, pcall(E.GetGuideState, id))
			local h = Gd.Get and Gd.Get(id)
			if h and estado ~= "done" then return { id = id, nombre = etiqueta(h) } end
		end
	end
	return nil
end

function Sg.Seguir(p)
	if not (p and p.id) then return false end
	local B = M.Biblioteca
	if B and B.Seguir then
		B.Seguir(p.id)
	else
		local E = A.Engine
		if not (E and E.SetGuide) then return false end
		E.SetGuide(p.id)
		M.Empezar()
	end
	return true
end

A.On("GUIDE_CHANGED", function() guardada = nil end)
A.RegisterEvent("PLAYER_LEVEL_UP", function() guardada = nil end)
