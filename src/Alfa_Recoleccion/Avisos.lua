-- Alfa - Recolección: dos avisos en el momento justo (toxic3000 / La Jauría).
-- GPL-3.0. 1.4.0 (diario, 96 y 97)
--
-- 96. Un recurso nuevo: al subir Minería o Herboristería al nivel que abre
--     otro recurso («Minería 65: ya puedes minar Filón de estaño»), un aviso
--     con «Llévame» (la ruta a la zona más cercana de tu nivel, Llevar.lua).
--     Los niveles son los del catálogo (Catalogo.lua, su mínimo). Lo que ya
--     podías al entrar no se avisa (solo al subir mientras juegas).
-- 97. La herramienta que falta: si el juego no te deja minar o desollar
--     porque no llevas el pico o el cuchillo (su error en rojo nombra la
--     herramienta), Alfa explica qué falta, si la tienes en el banco (la foto
--     de Bolsas) y dónde se compra. Una vez por sesión y herramienta.
-- Nada en combate. Ajustes recoleccion.avisoNuevo y recoleccion.avisoHerramienta (sí).
--
--   Av.Nuevos(tipo, antes, ahora) -> { grupo, ... }
--   Av.AlSubir() ; Av.AlError(texto) -> aviso | nil

local _, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local R = M.R
local L = N.Textos(M.EN)

local type, ipairs, pairs, pcall, format, tonumber = type, ipairs, pairs, pcall, string.format, tonumber

local Av = {}
M.Avisos = Av

local ID = R.ID

local function on(k) return N.Get(ID, k) ~= false end
local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end

---------------------------------------------------------------------------
-- 96. Un recurso nuevo al subir tu habilidad
---------------------------------------------------------------------------
local VERBO = { mineria = "Ya puedes minar %s.", hierbas = "Ya puedes recoger %s." }

function Av.Nuevos(tipo, antes, ahora)
	local out = {}
	if not (antes and ahora) or ahora <= antes then return out end
	for g, gr in ipairs(M.GRUPOS) do
		local minimo = gr.tipo == tipo and type(gr.niveles) == "table" and tonumber(gr.niveles[1]) or nil
		-- Los de nivel 1 los tienes desde el principio.
		if minimo and minimo > 1 and minimo > antes and minimo <= ahora then out[#out + 1] = g end
	end
	return out
end

local vistos = {} -- tipo -> la habilidad que ya se vio

local function avisarNuevo(tipo, nivel, grupos)
	if not (K and K.Aviso) or #grupos == 0 then return end
	local nombres = {}
	for _, g in ipairs(grupos) do nombres[#nombres + 1] = R.Nombre(g) end
	local lista = table.concat(nombres, ", ")
	local oficio = (R.NombreOficio and R.NombreOficio(tipo)) or R.NombreTipo(tipo)
	local g1 = M.GRUPOS[grupos[1]]
	local acciones
	local Ll = M.Llevar
	if Ll and Ll.Llevar and g1 then
		acciones = { { texto = L["Llévame"], alClic = function() Ll.Llevar(g1.clave) end } }
	end
	K.Aviso({
		id = "recoleccion.nuevo." .. tipo, titulo = format(L["¡%s %d!"], oficio, nivel),
		texto = format(L[VERBO[tipo]], lista) .. " " .. L["«Llévame» te lleva a la zona más cercana de tu nivel."],
		icono = "ic-recoleccion", tono = "exito", duracion = 12, prioridad = "util", acciones = acciones,
	})
end

function Av.AlSubir()
	if R.HabilidadesListas and not R.HabilidadesListas() then return end
	for _, tipo in ipairs({ "mineria", "hierbas" }) do
		local ahora = tonumber(R.Habilidad(tipo))
		local antes = vistos[tipo]
		if ahora then
			vistos[tipo] = ahora
			if antes and ahora > antes and on("avisoNuevo") and not enCombate() then
				local nuevos = Av.Nuevos(tipo, antes, ahora)
				if #nuevos > 0 then avisarNuevo(tipo, ahora, nuevos) end
			end
		end
	end
end
-- Para el banco: lo que ya «se vio».
function Av.Visto(tipo, v) vistos[tipo] = v end

A.RegisterEvent("SKILL_LINES_CHANGED", function()
	-- Después de que Recoleccion.lua relee las habilidades (0,3 s).
	N.Una("recoleccion.nuevo", 0.6, function() N.FueraDeCombate("recoleccion.nuevo", Av.AlSubir) end)
end)
A.OnLogin(function() N.Una("recoleccion.nuevo", 4, Av.AlSubir) end)

---------------------------------------------------------------------------
-- 97. La herramienta que falta
---------------------------------------------------------------------------
-- itemID de la herramienta -> tipo (para el texto)
Av.HERRAMIENTAS = {
	{ id = 2901, oficio = "mineria" },   -- Pico de minero
	{ id = 7005, oficio = "desuello" },  -- Cuchillo para desollar
}

local function nombreObjeto(id)
	local CI = rawget(_G, "C_Item")
	local f = CI and CI.GetItemNameByID
	if type(f) ~= "function" then return nil end
	local ok, n = pcall(f, id)
	n = ok and N.Leer(n) or nil
	return type(n) == "string" and n ~= "" and n or nil
end

local avisadoHerr = {}

function Av.AlError(texto)
	texto = N.Leer(texto)
	if type(texto) ~= "string" or texto == "" or not on("avisoHerramienta") then return nil end
	for _, h in ipairs(Av.HERRAMIENTAS) do
		local nombre = nombreObjeto(h.id)
		if nombre and texto:find(nombre, 1, true) and not avisadoHerr[h.id] then
			avisadoHerr[h.id] = true
			if not (K and K.Aviso) then return nil end
			local B = rawget(_G, "AlfaBolsas")
			local enBanco = 0
			if type(B) == "table" and type(B.Cuantos) == "function" then
				local ok, _, _, b = pcall(B.Cuantos, h.id)
				enBanco = ok and tonumber(b) or 0
			end
			local t
			if enBanco and enBanco > 0 then
				t = format(L["Necesitas %s en tus bolsas. Tienes uno en el banco: sácalo la próxima vez que pases."], nombre)
			else
				t = format(L["Necesitas %s en tus bolsas. Lo venden los comerciantes de suministros de oficios en las ciudades y los pueblos grandes."], nombre)
			end
			return K.Aviso({
				id = "recoleccion.herramienta", titulo = L["Te falta la herramienta"], texto = t,
				icono = "ic-recoleccion", tono = "aviso", duracion = 14, prioridad = "importante", pedido = true,
			})
		end
	end
	return nil
end

A.RegisterEvent("UI_ERROR_MESSAGE", function(_, _, texto)
	if enCombate() then return end
	pcall(Av.AlError, texto)
end)
