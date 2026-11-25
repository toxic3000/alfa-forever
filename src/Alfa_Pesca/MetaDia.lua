-- Alfa - Pesca: la meta del día (1.4.0, plan 49; toxic3000 / La Jauría). GPL-3.0.
--
-- Cada día una meta chiquita de pesca, distinta según el día y lo que te
-- falta: «Pesca 3 peces nuevos» (que nunca has sacado, mientras te falten),
-- «Saca 30 capturas» o «Pesca en 3 bancos de peces». Va primero en la
-- ventanita de metas (Metas.lua) y, al cumplirla, Lya la festeja (aúlla, la
-- anota en tu historia) o, sin Lya, un aviso. Por personaje; ajuste
-- pesca.metaDia (de fábrica, sí).
--   Md.Hoy() -> { dia, tipo, objetivo, hecho, cumplida } | nil
--   Md.Texto(m) ; Md.Anotar(nuevos, capturas, bancos)

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID

local floor, min, max, format, type, ipairs, pairs, tonumber = math.floor, math.min, math.max, string.format, type, ipairs, pairs, tonumber

local Md = {}
M.MetaDia = Md

local function activo() return N.Get(ID, "metaDia") ~= false end
local function hoy() return date and date("%Y-%m-%d") or "?" end
local function numeroDia() return floor(((time and time() or 0) + 6 * 3600) / 86400) end

-- Peces (y trofeos) del catálogo que nunca has sacado.
function Md.Faltantes()
	local diario = M.Diario()
	local n = 0
	for _, c in ipairs(M.CATALOGO or {}) do
		if (c.clase == "pez" or c.clase == "trofeo") then
			local e = diario[c.id]
			if not (type(e) == "table" and (tonumber(e.n) or 0) > 0) then n = n + 1 end
		end
	end
	return n
end

local function elegir()
	local opciones = {}
	local faltan = Md.Faltantes()
	if faltan > 0 then
		opciones[#opciones + 1] = { tipo = "nuevos", objetivo = min(3, faltan) }
		opciones[#opciones + 1] = { tipo = "nuevos", objetivo = min(2, faltan) }
	end
	opciones[#opciones + 1] = { tipo = "capturas", objetivo = 30 }
	opciones[#opciones + 1] = { tipo = "bancos", objetivo = 3 }
	local o = opciones[numeroDia() % #opciones + 1]
	return { dia = hoy(), tipo = o.tipo, objetivo = o.objetivo, hecho = 0 }
end

-- La de hoy (la elige al primer uso del día). Sin Pesca, nada.
function Md.Hoy()
	if not activo() then return nil end
	if M.Habilidad and not M.Habilidad() then return nil end
	local d = N.DatosPersonaje(ID)
	local m = d.metaDia
	if type(m) ~= "table" or m.dia ~= hoy() then
		m = elegir()
		d.metaDia = m
	end
	return m
end

function Md.Texto(m)
	m = m or Md.Hoy()
	if not m then return nil end
	local o = tonumber(m.objetivo) or 1
	if m.tipo == "nuevos" then return N.Plural(o, L["Pesca %d pez que nunca has sacado"], L["Pesca %d peces que nunca has sacado"]):format(o) end
	if m.tipo == "bancos" then return N.Plural(o, L["Pesca en %d banco de peces"], L["Pesca en %d bancos de peces"]):format(o) end
	return N.Plural(o, L["Saca %d captura"], L["Saca %d capturas"]):format(o)
end

-- Corto, para la fila de la ventanita: «3 peces nuevos».
function Md.Corto(m)
	local o = tonumber(m.objetivo) or 1
	if m.tipo == "nuevos" then return N.Plural(o, L["%d pez nuevo"], L["%d peces nuevos"]):format(o) end
	if m.tipo == "bancos" then return N.Plural(o, L["%d banco de peces"], L["%d bancos de peces"]):format(o) end
	return N.Plural(o, L["%d captura"], L["%d capturas"]):format(o)
end

-- Como meta de la ventanita (Metas.lua): { tipo = "dia", ... }.
function Md.Fila()
	local m = Md.Hoy()
	if not m then return nil end
	return { uid = "dia", tipo = "dia", objetivo = m.objetivo, hecho = min(m.hecho or 0, m.objetivo), cumplida = m.cumplida,
		texto = Md.Corto(m), largo = Md.Texto(m) }
end

local function festejar(m)
	local texto = format(L["¡Meta de pesca del día cumplida! %s. Te ganaste una salchicha."], Md.Texto(m))
	local Lya = rawget(_G, "AlfaLya")
	local dijo = false
	if type(Lya) == "table" and type(Lya.Decir) == "function" then
		local ok, r = pcall(Lya.Decir, texto, { aullar = true, cara = "feliz", id = "pesca.dia" })
		dijo = ok and r == true
		if type(Lya.Festejar) == "function" then pcall(Lya.Festejar, "pesca.dia." .. m.dia, L["Meta de pesca del día"], Md.Texto(m)) end
	end
	if not dijo and K and K.Aviso then
		K.Aviso({ id = "pesca.dia", icono = M.ICONO and M.ICONO.meta or "ic-pesca", tono = "exito", duracion = 6,
			titulo = L["Meta de pesca del día cumplida"], texto = Md.Texto(m), lya = false })
	end
	Md.festejada = m.dia
end

-- Lo de una captura.
function Md.Anotar(nuevos, capturas, bancos)
	local m = Md.Hoy()
	if not m or m.cumplida then return end
	local n = (m.tipo == "nuevos" and nuevos) or (m.tipo == "bancos" and bancos) or (m.tipo == "capturas" and capturas) or 0
	if (n or 0) <= 0 then return end
	m.hecho = (tonumber(m.hecho) or 0) + n
	if m.hecho >= (tonumber(m.objetivo) or 1) then
		m.cumplida = time and time() or 1
		festejar(m)
	end
	if M.Avisar then M.Avisar("metas") end
end

-- Cada captura (Registro.lua): cuántos peces nuevos, 1 captura y si fue un banco nuevo.
local R = M.R
local captura = R.Captura
function R.Captura(objetos, info)
	local s = M.Sesion and M.Sesion()
	local bancosAntes = s and tonumber(s.bancos) or 0
	local out = captura(objetos, info)
	if activo() and type(out) == "table" and #out > 0 then
		local nuevos = 0
		for _, x in ipairs(out) do if x.primera then nuevos = nuevos + 1 end end
		local s2 = M.Sesion and M.Sesion()
		local bancos = s2 and max(0, (tonumber(s2.bancos) or 0) - bancosAntes) or 0
		pcall(Md.Anotar, nuevos, 1, bancos)
	end
	return out
end
