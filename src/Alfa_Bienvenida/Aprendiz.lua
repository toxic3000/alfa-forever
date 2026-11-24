-- Alfa - Bienvenida: el Modo aprendiz (1.3.9). toxic3000 / La Jauría. GPL-3.0.
--
-- Mejora 55 de la 1.3.9: un modo opcional para quien empieza. La primera
-- vez que sale cada aviso de Alfa (K.Aviso), Lya dice de dónde viene y dónde
-- se apaga, con un botón que lleva a esa página. Una sola explicación por
-- tipo de aviso (se guarda), una a la vez (a lo más una por minuto) y nunca
-- en combate ni encima de lo importante (Lya decide con su cola).
-- Ajuste: bienvenida.aprendiz (apagado de fábrica; se prende en Ajustes >
-- Estilo y sonido > Para leer mejor, o en «Ajustar más» de la bienvenida).
--
--   Ap.Activo() -> bool   Ap.Explicar(o) -> bool (la dijo)   Ap.Olvidar()

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID

local format, type, pcall, tostring = string.format, type, pcall, tostring

local Ap = {}
M.Aprendiz = Ap

A.RegisterDefaults(ID, { aprendiz = false })

local ESPERA = 60 -- s entre una explicación y la siguiente
local ultima = -ESPERA

-- La firma de un aviso (Kit/Firmas.lua) -> la página donde se ajusta.
local PAGINA = {
	ruta = "rutas", hoy = "inicio", bolsas = "bolsas", pesca = "pesca", combate = "combate", curacion = "curacion",
	manada = "manada", lya = "lya", comercio = "comercio", oficios = "comercio", mundo = "mundo",
	mazmorras = "mazmorras", talentos = "builds", comodidades = "comodidades", recoleccion = "recoleccion",
	enciclopedia = "enciclopedia", alfa = "bienvenida",
}

local function ahora() return GetTime and GetTime() or 0 end

function Ap.Activo() return A.Get(ID .. ".aprendiz") == true end

local function vistos()
	local d = N.Datos(ID)
	if type(d.avisosExplicados) ~= "table" then d.avisosExplicados = {} end
	return d.avisosExplicados
end

-- El tipo de un aviso: su id, o su título sin números (el mismo aviso con
-- otra cantidad es el mismo tipo).
local function tipoDe(o)
	local t = o.id or o.clave
	if type(t) ~= "string" or t == "" then
		t = type(o.titulo) == "string" and o.titulo or (type(o.texto) == "string" and o.texto or "")
		if issecretvalue and issecretvalue(t) then return nil end
		t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%d+", "#"):sub(1, 60)
	end
	return t ~= "" and t or nil
end

-- -> el texto de Lya para este aviso y la página donde se ajusta (o nil).
function Ap.Texto(o)
	local clave = o.alfaFirma
	if type(clave) ~= "string" and K.FirmaDe then
		local _, c = K.FirmaDe(o)
		clave = c
	end
	local firma = K.FIRMAS and clave and K.FIRMAS[clave]
	local pagina = clave and PAGINA[clave]
	local spec = pagina and N.ModuloPorId and N.ModuloPorId(pagina)
	local deDonde = firma and K.L[firma.nombre] or L["Alfa"]
	if spec and spec.nombre then
		return format(L["Ese aviso es de %s: te lo digo para que no se te pase. Si no lo quieres, lo apagas en su página, %s."], deDonde, spec.nombre), pagina
	end
	return format(L["Ese aviso es de %s: te lo digo para que no se te pase. Si no lo quieres, lo apagas en Ajustes."], deDonde), nil
end

function Ap.Explicar(o)
	if type(o) ~= "table" or not Ap.Activo() then return false end
	local Lya = rawget(_G, "AlfaLya")
	if not (type(Lya) == "table" and type(Lya.Decir) == "function") then return false end
	if InCombatLockdown and InCombatLockdown() then return false end
	local tipo = tipoDe(o)
	if not tipo or vistos()[tipo] then return false end
	if ahora() - ultima < ESPERA then return false end
	local texto, pagina = Ap.Texto(o)
	local opts = { id = "aprendiz" }
	if pagina then opts.accion = { texto = L["Llévame ahí"], fn = function() N.Abrir(pagina) end } end
	local ok, dijo = pcall(Lya.Decir, texto, opts)
	if ok and dijo then
		vistos()[tipo] = true
		ultima = ahora()
		return true
	end
	return false
end

function Ap.Olvidar() N.Datos(ID).avisosExplicados = {} end

-- Cada aviso que sale (Kit/Ventanas.lua: ALFA_AVISO), un momento después.
A.On("ALFA_AVISO", function(o)
	if not Ap.Activo() or type(o) ~= "table" then return end
	K.Despues(1.5, function() pcall(Ap.Explicar, o) end)
end)

-- Prenderlo: Lya se presenta como maestra (una vez por prendida).
A.On("SETTING_CHANGED", function(path, valor)
	if path ~= ID .. ".aprendiz" or valor ~= true then return end
	local Lya = rawget(_G, "AlfaLya")
	if type(Lya) == "table" and type(Lya.Decir) == "function" then
		pcall(Lya.Decir, L["¡Modo aprendiz! La primera vez que salga cada aviso, te cuento de dónde viene y cómo apagarlo."], { id = "aprendiz.hola" })
	end
end)
