-- Alfa - Recolección: dónde subir tu Minería o tu Herboristería (1.4.2). toxic3000 / La Jauría. GPL-3.0.
--
-- Para subir un oficio de recolección hay que juntar lo que todavía te da
-- puntos: lo naranja y lo amarillo casi siempre, lo verde a veces y lo gris
-- nunca (los niveles del catálogo: mínimo, amarillo, verde y gris). Alfa mira
-- tu habilidad, elige esos nodos y busca la zona con más de ellos, de tu
-- facción, de tu nivel y cerca de ti (Llevar.lua: Ll.Zonas); ahí arma una
-- vuelta corta y la flecha te guía. Lo verde cuenta la mitad.
--
-- Se pide desde la página de Recolección (la tarjeta de arriba: «Subir
-- Minería»), con /alfa recoleccion subir [mineria|hierbas] o desde otros
-- módulos (AlfaRecoleccion.Subir).
--
--   Su.Claves(tipo, habilidad) -> fuertes { clave }, flojas { clave }
--   Su.Mejor(tipo) -> zona, op | nil, motivo ("oficio" | "tope" | "nada")
--   Su.Llevar(tipo) -> true, zona | false, motivo

local _, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local R, Ruta = M.R, M.Ruta
local L = N.Textos(M.EN)

local type, ipairs, tonumber, format, min = type, ipairs, tonumber, string.format, math.min

local Su = {}
M.Subir = Su

Su.TOPE = 300
Su.PARADAS = 24

local OFICIO = { mineria = "Minería", hierbas = "Herboristería" }

function Su.NombreOficio(tipo)
	return (R.NombreOficio and R.NombreOficio(tipo)) or L[OFICIO[tipo] or "Minería"]
end

-- Los nodos que te dan puntos con esa habilidad.
function Su.Claves(tipo, hab)
	local fuertes, flojas = {}, {}
	hab = tonumber(hab)
	if not hab then return fuertes, flojas end
	for _, gr in ipairs(M.GRUPOS) do
		local n = gr.tipo == tipo and type(gr.niveles) == "table" and #gr.niveles == 4 and gr.niveles or nil
		if n and hab >= n[1] then
			if hab < n[3] then fuertes[#fuertes + 1] = gr.clave
			elseif hab < n[4] then flojas[#flojas + 1] = gr.clave end
		end
	end
	return fuertes, flojas
end

function Su.Mejor(tipo)
	local hab = tonumber(R.Habilidad(tipo))
	if not hab then return nil, "oficio" end
	if hab >= Su.TOPE then return nil, "tope" end
	local fuertes, flojas = Su.Claves(tipo, hab)
	if #fuertes == 0 and #flojas == 0 then return nil, "nada" end
	-- Sin nada naranja ni amarillo, lo verde manda (cuenta entero).
	local op = #fuertes > 0 and { claves = fuertes, anfitriones = flojas } or { claves = flojas, anfitriones = {} }
	local zonas = M.Llevar.Zonas(op)
	if not zonas[1] then return nil, "nada" end
	op.habilidad = hab
	return zonas[1], op
end

local function nombres(claves, cuantos)
	local out = {}
	for i = 1, min(#claves, cuantos) do
		local g = M.porClave[claves[i]]
		if g then out[#out + 1] = R.Nombre(g) end
	end
	return table.concat(out, ", ")
end

local MOTIVO = {
	oficio = "Tu personaje no tiene ese oficio. Te lo enseña un instructor de profesión.",
	tope = "Tu oficio ya está al máximo. ¡Bien hecho!",
	nada = "No encontré una zona de tu facción con lo que te da puntos.",
}
function Su.TextoMotivo(m) return L[MOTIVO[m] or MOTIVO.nada] end

function Su.Llevar(tipo)
	tipo = (tipo == "hierbas") and "hierbas" or (tipo == "mineria" and "mineria") or (R.TipoRuta and R.TipoRuta()) or "mineria"
	if tipo ~= "mineria" and tipo ~= "hierbas" then tipo = "mineria" end
	if InCombatLockdown and InCombatLockdown() then return false, "combate" end
	local z, op = Su.Mejor(tipo)
	if not z then
		N.Imprimir(Su.TextoMotivo(op))
		return false, op
	end
	local set = {}
	for _, c in ipairs(op.claves) do set[c] = true end
	for _, c in ipairs(op.anfitriones) do set[c] = true end
	local ok, por = Ruta.Crear(tipo, set, z.mapa, function(r) if r then Ruta.Guiar() end end, { cerca = Su.PARADAS })
	if not ok then
		N.Imprimir(por or Su.TextoMotivo("nada"))
		return false, por
	end
	local oficio = Su.NombreOficio(tipo)
	local texto = format(L["Con %s %d te dan puntos: %s."], oficio, op.habilidad, nombres(op.claves, 3))
	if #op.anfitriones > 0 and op.claves[1] ~= op.anfitriones[1] then
		texto = texto .. " " .. format(L["Lo verde (%s) a veces."], nombres(op.anfitriones, 2))
	end
	texto = texto .. " " .. (M.Llevar.Motivo(z, op) or "")
	if K and K.Aviso then
		K.Aviso({ id = "recoleccion.subir", titulo = format(L["A subir %s"], oficio), texto = texto, icono = "ic-recoleccion",
			tono = "acento", duracion = 12, pedido = true })
	else
		N.Imprimir(texto)
	end
	Su.ultima = { zona = z, op = op, tipo = tipo }
	return true, z
end

AlfaRecoleccion = type(rawget(_G, "AlfaRecoleccion")) == "table" and rawget(_G, "AlfaRecoleccion") or {}
AlfaRecoleccion.Subir = function(tipo) return Su.Llevar(tipo) end
