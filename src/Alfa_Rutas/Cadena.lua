-- Alfa - Rutas: la cadena completa de una misión (toxic3000 / La Jauría).
-- GPL-3.0.
-- 1.3.0
--
-- La ficha de una misión con toda su cadena: las que van antes (lo que pide,
-- del Codex: pre / preAny) y las que siguen (Cadenas.Siguientes), cuál ya
-- hiciste, cuál llevas y cuáles faltan, y el premio del final (lo que da la
-- última de la cadena). Se abre desde el menú del registro de misiones, el
-- de una meta del rastreador o AlfaRuta.VerCadena(questID). Ajuste
-- rutas.cadenaCompleta. Nada se busca en combate.
--
--   Cadena.De(qid) -> { lista = { { qid, titulo, nivel, estado } }, final, premio = { itemID... }, xp } | nil
--       estado: "hecha" | "llevas" | "esta" (la que miras) | "falta"
--   Cadena.Abrir(qid)

local ADDON, M = ...
local A, L, K = M.A, M.L, M.K
local Ca = {}
M.Cadena = Ca

A.RegisterDefaults(M.ID, { cadenaCompleta = true })

local type, ipairs, tonumber = type, ipairs, tonumber
local format, concat = string.format, table.concat

local MAX = 30 -- misiones de cada lado (una cadena rota o circular no cuelga nada)

local function CX() return M.Motor("Codex") end
local function CP() return M.Motor("Compat") end
local function enCombate() return InCombatLockdown and InCombatLockdown() or false end

local function codexListo()
	local C = CX()
	return C and C.IsLoaded and C.IsLoaded() and C.Quest and true or false
end

local function estado(qid, mirada)
	local Cp = CP()
	if Cp and Cp.IsQuestCompleted and Cp.IsQuestCompleted(qid) then return "hecha" end
	if Cp and Cp.IsOnQuest and Cp.IsOnQuest(qid) then return "llevas" end
	if qid == mirada then return "esta" end
	return "falta"
end

-- La que va antes: la primera de pre (todas hacen falta) o de preAny.
local function anterior(q)
	local p = q and ((q.pre and q.pre[1]) or (q.preAny and q.preAny[1]))
	return tonumber(p)
end

function Ca.De(qid)
	qid = tonumber(qid)
	if not qid or enCombate() or not codexListo() then return nil end
	local C = CX()
	local vistas = { [qid] = true }
	local antes = {}
	local q = C.Quest(qid)
	if not q then return nil end
	local p = anterior(q)
	while p and not vistas[p] and #antes < MAX do
		vistas[p] = true
		table.insert(antes, 1, p)
		p = anterior(C.Quest(p))
	end
	local despues = {}
	local f = qid
	while #despues < MAX do
		local ok, sig = pcall(M.Cadenas.Siguientes, f)
		local s = ok and type(sig) == "table" and sig[1] or nil
		if not s or vistas[s] then break end
		vistas[s] = true
		despues[#despues + 1] = s
		f = s
	end
	local ids = {}
	for _, x in ipairs(antes) do ids[#ids + 1] = x end
	ids[#ids + 1] = qid
	for _, x in ipairs(despues) do ids[#ids + 1] = x end
	local lista = {}
	for i, x in ipairs(ids) do
		local r = C.Quest(x)
		lista[i] = { qid = x, titulo = M.TituloMision(x), nivel = r and tonumber(r.level), estado = estado(x, qid) }
	end
	local final = ids[#ids]
	local rf = C.Quest(final)
	local premio = {}
	for _, l in ipairs({ rf and rf.rewards or {}, rf and rf.choices or {} }) do
		for _, it in ipairs(l) do premio[#premio + 1] = it end
	end
	return { lista = lista, final = final, premio = premio, xp = rf and tonumber(rf.xp), mirada = qid }
end

-- "Premio final: Espada de X o Escudo de Y"
function Ca.TextoPremio(d)
	if not d then return "" end
	local nombres = {}
	for i, it in ipairs(d.premio or {}) do
		if i > 4 then break end
		nombres[#nombres + 1] = M.NombreObjeto(it)
	end
	if #nombres == 0 then
		if d.xp then return format(L["Premio final: %s de experiencia"], M.Miles(d.xp)) end
		return L["El final de la cadena no da objetos."]
	end
	return format(L["Premio final: %s"], concat(nombres, ", "))
end

local ventana

local TONO = { hecha = "textoTenue", llevas = "acento", esta = "texto", falta = "textoSuave" }
local ICONO = { hecha = "ic-exito", llevas = "ic-huella", esta = "ic-misiones", falta = "ic-ruta" }

local function armar()
	ventana = M.VentanaSimple({
		nombre = "AlfaRutasCadena", titulo = L["La cadena completa"], icono = "ic-ruta", ancho = 440, alto = 480,
		vacio = { lobo = "atento", titulo = L["Sin cadena"], texto = L["Esta misión va sola: no pide otra ni abre otra."] },
		crear = function(fila)
			fila.Icono = K.Icono(fila, "ic-ruta", 14, "acento")
			fila.Icono:SetPoint("LEFT", fila, "LEFT", 10, 0)
			fila.Texto = K.Texto(fila, "cuerpo", "texto")
			fila.Texto:SetPoint("LEFT", fila, "LEFT", 32, 0)
			fila.Texto:SetPoint("RIGHT", fila, "RIGHT", -10, 0)
		end,
		pintar = function(fila, d, i)
			K.SetIcono(fila.Icono, ICONO[d.estado] or "ic-ruta", d.estado == "llevas" and "acento" or "textoTenue")
			local t = format(L["%d. %s"], i, d.titulo)
			if d.nivel then t = t .. " (" .. d.nivel .. ")" end
			K.Escribir(fila.Texto, t)
			K.ColorTexto(fila.Texto, TONO[d.estado] or "texto")
		end,
		alClic = function(d)
			local E = rawget(_G, "AlfaEnciclopedia")
			if type(E) == "table" and type(E.Abrir) == "function" then pcall(E.Abrir, "quest", d.qid) end
		end,
	})
end

function Ca.Abrir(qid)
	if A.Get(M.ID .. ".cadenaCompleta") == false then return false end
	if enCombate() then
		M.Aviso(L["La cadena completa"], L["Se puede al salir de combate."], { icono = "ic-aviso", tono = "aviso" })
		return false
	end
	local ok, motivo = M.Indice.CodexListo()
	if not ok then
		M.Aviso(L["La cadena completa"], M.Indice.TextoMotivo(motivo), { icono = "ic-aviso", tono = "aviso" })
		return false
	end
	local d = Ca.De(qid)
	if not d then return false end
	if not ventana then armar() end
	local lista = #d.lista > 1 and d.lista or {}
	local hechas = 0
	for _, x in ipairs(d.lista) do if x.estado == "hecha" then hechas = hechas + 1 end end
	ventana:Llenar(lista, M.TituloMision(qid),
		#lista > 0 and format(L["%d misiones, %d hechas"], #lista, hechas) or nil,
		#lista > 0 and Ca.TextoPremio(d) or "")
	return true
end
