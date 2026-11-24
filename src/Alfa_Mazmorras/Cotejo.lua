-- Alfa - Mazmorras: «Prepárame» con su lista de cotejo (1.3.9).
-- toxic3000 / La Jauría. GPL-3.0.
--
-- Antes de entrar, lo que conviene tener listo, y se va marcando solo:
--   1. las misiones de la mazmorra que ya puedes tomar (Plan.lua);
--   2. tu equipo reparado, tu comida y tu agua, tu munición y tu espacio
--      (lo que revisa «Listo para la mazmorra» de Alfa_Inicio, AlfaInicio.Faltas);
--   3. tu grupo;
--   4. llegar a la entrada.
-- Cada cosa que falta trae su botón (recoger, llévame al vendedor, buscar
-- grupo en tu hermandad, la flecha a la entrada); todo lo hace tu clic.
-- Después de «Prepárame», al quedar todo marcado, un aviso «¡Todo listo!»
-- (una vez). Se revisa fuera de combate y con calma (N.Una).
--   Ct.Lista(key) -> { { clave, texto, hecho, accion = { texto, alClic } }, ... }
--   Ct.Progreso(key) -> hechos, total ; Ct.Empezar(key) ; Ct.Activa()

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = N.Textos(M.EN)
local D = M.D

local type, ipairs, pcall, format = type, ipairs, pcall, string.format

local Ct = {}
M.Cotejo = Ct

local activa      -- la mazmorra de tu último «Prepárame»
local avisada = {} -- key -> true: ya dijo «¡Todo listo!»

local function G(n) local v = rawget(_G, n) return type(v) == "table" and v or nil end
local function llamar(t, fn, ...)
	if not (t and type(t[fn]) == "function") then return nil end
	local ok, a, b = pcall(t[fn], ...)
	if ok then return a, b end
	return nil
end

local function enGrupo() return IsInGroup and IsInGroup() == true or false end

function Ct.Lista(key)
	if type(key) ~= "string" then return {} end
	local out = {}
	local P = M.P
	local nombre = D.Nombre(key)
	-- 1. Las misiones.
	local e = P and P.Estado(key)
	if e then
		local n = #e.recoger
		if n > 0 then
			out[#out + 1] = { clave = "misiones", hecho = false,
				texto = N.Plural(n, L["Recoge %d misión de aquí"], L["Recoge %d misiones de aquí"]),
				accion = { texto = L["Recogerlas"], alClic = function() Ct.Empezar(key) P.Preparar(key) end } }
		else
			out[#out + 1] = { clave = "misiones", hecho = true,
				texto = (e.llevas or 0) > 0 and N.Plural(e.llevas, L["Llevas %d misión de aquí"], L["Llevas %d misiones de aquí"])
					or L["No hay misiones que puedas tomar ahora"] }
		end
	end
	-- 2. Tu equipo, comida, munición y espacio.
	local faltas = llamar(G("AlfaInicio"), "Faltas")
	if type(faltas) == "table" then
		if #faltas == 0 then
			out[#out + 1] = { clave = "listo", hecho = true, texto = L["Equipo, comida y bolsas en orden"] }
		else
			for _, f in ipairs(faltas) do
				local ir = f.ir
				out[#out + 1] = { clave = "falta:" .. tostring(f.clave), hecho = false, texto = f.texto,
					accion = ir and { texto = L["Llévame"], alClic = function() llamar(G("AlfaCerca"), "Ir", ir) if N.EmpezarRuta then N.EmpezarRuta() end end } or nil }
			end
		end
	end
	-- 3. Tu grupo.
	local dentro = D.MazmorraActual() == key
	if enGrupo() then
		out[#out + 1] = { clave = "grupo", hecho = true, texto = L["Vas con tu grupo"] }
	else
		local Mn = G("AlfaManada")
		out[#out + 1] = { clave = "grupo", hecho = false, texto = L["Todavía vas solo"],
			accion = Mn and type(Mn.BuscoGrupo) == "function" and IsInGuild and IsInGuild() and { texto = L["Buscar en mi hermandad"],
				alClic = function() Mn.BuscoGrupo(format(L["Busco grupo para %s"], nombre), "m") end } or nil }
	end
	-- 4. La entrada.
	out[#out + 1] = { clave = "entrada", hecho = dentro, texto = dentro and L["Ya estás dentro"] or L["Llega a la entrada"],
		accion = not dentro and P and { texto = L["Llévame"], alClic = function() Ct.Empezar(key) P.Entrada(key) end } or nil }
	return out
end

function Ct.Progreso(key)
	local hechos, total = 0, 0
	for _, x in ipairs(Ct.Lista(key)) do
		total = total + 1
		if x.hecho then hechos = hechos + 1 end
	end
	return hechos, total
end

function Ct.Empezar(key)
	activa = key
	avisada[key] = nil
end
function Ct.Activa() return activa end

-- Todo marcado tras «Prepárame»: el aviso, una vez.
function Ct.Revisar()
	local key = activa
	if not key or avisada[key] then return false end
	local hechos, total = Ct.Progreso(key)
	if total == 0 or hechos < total then return false end
	avisada[key] = true
	local libre = N.AlLibre or function(_, f) f() end
	libre("mazmorras.cotejo", function()
		if K and K.Aviso then
			K.Aviso({ id = "mazmorras.cotejo", lobo = "aullando", tono = "exito", duracion = 6, prioridad = 3,
				titulo = format(L["¡Todo listo para %s!"], D.Nombre(key)), texto = L["Tu lista de cotejo quedó completa. ¡A cazar!"] })
		end
	end, 3)
	return true
end

-- «Prepárame» empieza la lista.
do
	local P = M.P
	if P and P.Preparar then
		local antes = P.Preparar
		P.Preparar = function(key, ...)
			if type(key) == "string" then Ct.Empezar(key) end
			return antes(key, ...)
		end
	end
end

local function cambio()
	N.Una("mazmorras.cotejo", 1.5, function()
		if M.V and M.V.Visible and M.V.Visible() then M.V.RefrescarPronto(0.1) end
		Ct.Revisar()
	end, { fueraDeCombate = true })
end
for _, ev in ipairs({ "BAG_UPDATE_DELAYED", "QUEST_ACCEPTED", "QUEST_REMOVED", "GROUP_ROSTER_UPDATE",
	"UPDATE_INVENTORY_DURABILITY", "MERCHANT_CLOSED", "ZONE_CHANGED_NEW_AREA" }) do
	pcall(A.RegisterEvent, ev, cambio)
end
