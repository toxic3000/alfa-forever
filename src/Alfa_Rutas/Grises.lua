-- Alfa - Rutas: misiones grises que puedes soltar (toxic3000 / La Jauría).
-- GPL-3.0.
-- 1.3.0
--
-- Las misiones de tu registro que ya son grises para ti y no valen la pena:
-- ni dan un objeto raro o mejor ni abren una misión de la cadena que aún no
-- es gris (la misma regla de M.GrisValiosa, Cadenas.lua). Una ventana las
-- lista, cada una con «Abandonar»: el jugador hace clic y lo confirma (nada
-- se abandona solo). Ajuste rutas.grises (la tarjeta de la página Ruta y el
-- aviso de cuántas hay).
--
-- 1.3.1: sin el Codex no se juzga. Lo que da cada misión (un objeto raro)
-- solo está en el Codex: sin él, una gris que da un objeto azul salía como
-- «no vale la pena». Ahora, sin el Codex, la lista no sale (nil, "sinDatos")
-- y la tarjeta tampoco; «Misiones grises» lo carga con tu clic (fuera de
-- combate) antes de armar la lista.
--
--   Grises.Lista() -> { { qid, titulo, nivel }, ... } | nil, motivo ("combat" | "missing" | "sinDatos")
--   Grises.Abrir()                la ventana (carga el Codex si hace falta)
--   Grises.Abandonar(qid, sinPreguntar) -> pregunta (o abandona con sinPreguntar)

local ADDON, M = ...
local A, L, K = M.A, M.L, M.K
local Gr = {}
M.Grises = Gr

A.RegisterDefaults(M.ID, { grises = true })

local type, ipairs, tonumber = type, ipairs, tonumber
local format = string.format

local function CP() return M.Motor("Compat") end
local function CX() return M.Motor("Codex") end
local function encendido() return A.Get(M.ID .. ".grises") ~= false end
local function enCombate() return InCombatLockdown and InCombatLockdown() or false end

-- ¿Ya se puede juzgar? El premio de cada misión sale del Codex.
local function codexListo()
	local C = CX()
	return C and C.IsLoaded and C.IsLoaded() and true or false
end

function Gr.Lista()
	if enCombate() then return nil, "combat" end
	local Cp, Ch = CP(), M.Cadenas
	if not (Cp and Cp.GetLogQuests and Ch and Ch.EsGris) then return nil, "missing" end
	if not codexListo() then return nil, "sinDatos" end
	local out = {}
	for _, qid in ipairs(Cp.GetLogQuests() or {}) do
		qid = tonumber(qid)
		local esGris, nivel = false, nil
		if qid then esGris, nivel = Ch.EsGris(qid) end
		if esGris and not (Cp.IsQuestReadyForTurnIn and Cp.IsQuestReadyForTurnIn(qid)) and not M.GrisValiosa(qid) then
			out[#out + 1] = { qid = qid, titulo = M.TituloMision(qid), nivel = nivel }
		end
	end
	table.sort(out, function(a, b) return (a.nivel or 0) < (b.nivel or 0) end)
	return out
end

local ventana

local function refrescar()
	if not (ventana and ventana:IsShown()) then return end
	local lista = Gr.Lista() or {}
	ventana:Llenar(lista, nil, nil, #lista > 0 and L["Ya no te dan casi experiencia y no abren nada que valga la pena. Abandónalas para tener espacio en tu registro."] or "")
end

function Gr.Abandonar(qid, sinPreguntar)
	qid = tonumber(qid)
	if not qid then return false end
	local function hacer()
		local n = M.Plan.Abandonar({ qid })
		if n > 0 then
			M.Aviso(L["Misión abandonada"], M.TituloMision(qid), { icono = "ic-exito" })
		end
		A.After(0.3, refrescar)
		return n > 0
	end
	if sinPreguntar then return hacer() end
	K.Dialogo({
		titulo = L["¿Abandonar esta misión?"],
		texto = M.Citar(M.TituloMision(qid)) .. "\n\n" .. L["Sale de tu registro. Para hacerla otra vez tendrías que volver a pedirla."],
		aceptar = L["Abandonar"], peligro = true, alAceptar = hacer,
	})
	return true
end

local function armar()
	ventana = M.VentanaSimple({
		nombre = "AlfaRutasGrises", titulo = L["Misiones grises"], icono = "ic-misiones", ancho = 440, alto = 460,
		vacio = { lobo = "contento", titulo = L["Nada que soltar"], texto = L["Tus misiones grises valen la pena o no tienes ninguna."] },
		crear = function(fila)
			fila.Texto = K.Texto(fila, "cuerpo", "texto")
			fila.Texto:SetPoint("LEFT", fila, "LEFT", 10, 0)
			fila.Boton = K.Boton(fila, L["Abandonar"], function(b)
				local d = b:GetParent().alfaDato
				if d then Gr.Abandonar(d.qid) end
			end, { tipo = "secundario", tam = "chico" })
			fila.Boton:SetPoint("RIGHT", fila, "RIGHT", -8, 0)
			fila.Texto:SetPoint("RIGHT", fila.Boton, "LEFT", -8, 0)
		end,
		pintar = function(fila, d)
			fila.alfaDato = d
			K.Escribir(fila.Texto, d.nivel and format(L["[%d] %s"], d.nivel, d.titulo) or d.titulo)
			K.ColorTexto(fila.Texto, "textoTenue")
		end,
	})
end

function Gr.Abrir()
	if enCombate() then
		M.Aviso(L["Misiones grises"], L["Se puede al salir de combate."], { icono = "ic-aviso", tono = "aviso" })
		return false
	end
	-- 1.3.1: el Codex dice qué da cada una; se carga con este clic.
	local I = M.Indice
	local ok, motivo = I.CodexListo()
	local lista
	if ok then lista, motivo = Gr.Lista() end
	if not lista then
		M.Aviso(L["Misiones grises"], I.TextoMotivo(motivo), { icono = "ic-aviso", tono = "aviso" })
		return false
	end
	if not ventana then armar() end
	ventana:Llenar(lista, L["Misiones grises"], format(L["%d que no valen la pena"], #lista),
		#lista > 0 and L["Ya no te dan casi experiencia y no abren nada que valga la pena. Abandónalas para tener espacio en tu registro."] or "")
	return true
end

-- Cuántas hay, para la tarjeta de la página (0 con el ajuste apagado y,
-- 1.3.1, sin el Codex: la página no lo carga).
function Gr.Cuantas()
	if not encendido() then return 0 end
	local l = Gr.Lista()
	return l and #l or 0
end

A.RegisterEvent("QUEST_REMOVED", function() if ventana and ventana:IsShown() then A.After(0.3, refrescar) end end)
