-- Alfa - Rutas: tu registro casi lleno (toxic3000 / La Jauría). GPL-3.0.
-- 1.3.9 (27)
--
-- Cuando tomas una misión y tu registro queda a 2 o menos de su tope (20 de
-- 20 en Forever), Alfa te avisa una vez y te sugiere cuáles soltar: las
-- fallidas, las grises que no valen la pena (M.GrisValiosa), las lejanas y
-- las de otra zona; nunca una lista para entregar. «Ver cuáles» abre una
-- ventana con su porqué y «Abandonar» en cada una (con confirmación); nada
-- se abandona solo. Ajuste rutas.diarioLleno (de fábrica, sí).
--
--   Diario.Tope() -> cuántas caben          Diario.Cuantas() -> cuántas llevas
--   Diario.Sugerencias(fn(lista | nil, motivo))  { { qid, titulo, por, puntos } } (revisa con Cerrar)
--   Diario.Abrir()                          la ventana
--   Diario.Revisar()                        el aviso, si toca (lo llama QUEST_ACCEPTED)

local ADDON, M = ...
local A, L, N, K = M.A, M.L, M.N, M.K
local Di = {}
M.Diario = Di

A.RegisterDefaults(M.ID, { diarioLleno = true })

local type, ipairs, tonumber, pcall = type, ipairs, tonumber, pcall
local format, concat, min = string.format, table.concat, math.min

local CERCA = 2 -- avisa desde tope - 2
local MAX_SUGERIDAS = 6

local function encendido() return A.Get(M.ID .. ".diarioLleno") ~= false end
local function CP() return M.Motor("Compat") end
local function enCombate() return InCombatLockdown and InCombatLockdown() and true or false end

function Di.Tope()
	local f = C_QuestLog and C_QuestLog.GetMaxNumQuestsCanAccept
	if type(f) == "function" then
		local ok, n = pcall(f)
		n = ok and tonumber(N.Leer(n)) or nil
		if n and n > 0 then return n end
	end
	local g = tonumber(rawget(_G, "MAX_QUESTLOG_QUESTS"))
	if g and g > 0 then return g end
	return 20
end

function Di.Cuantas()
	local Cp = CP()
	if not (Cp and Cp.GetLogQuests) then return 0 end
	local ok, l = pcall(Cp.GetLogQuests)
	return ok and type(l) == "table" and #l or 0
end

-- Las que conviene soltar, de la revisión de «Cerrar mis misiones».
local function puntos(it)
	if not it.enLog or it.listo then return 0, nil end
	if it.fallida then return 5, L["Fallida"] end
	if it.gris and not (M.GrisValiosa and M.GrisValiosa(it.id)) then return 4, L["Gris: ya no da casi experiencia"] end
	if it.lejos and it.otraZona then return 3, it.zona and format(L["Lejos, en %s"], M.Zona(it.zona) or "") or L["Lejos de aquí"] end
	if it.alto then return 2, format(L["Nivel %d: aún te queda grande"], it.nivel or 0) end
	if it.lejos then return 2, L["Lejos de aquí"] end
	if it.otraZona then return 1, it.zona and format(L["En otra zona: %s"], M.Zona(it.zona) or "") or L["En otra zona"] end
	return 0, nil
end

function Di.Sugerencias(alTerminar)
	if enCombate() then return alTerminar(nil, "combat") end
	M.Cerrar.Revisar(function(lista, motivo)
		if not lista then return alTerminar(nil, motivo) end
		local out = {}
		for _, it in ipairs(lista) do
			local p, por = puntos(it)
			if p > 0 then out[#out + 1] = { qid = it.id, titulo = it.titulo, por = por, puntos = p, nivel = it.nivel } end
		end
		table.sort(out, function(a, b)
			if a.puntos ~= b.puntos then return a.puntos > b.puntos end
			return (a.nivel or 0) < (b.nivel or 0)
		end)
		while #out > MAX_SUGERIDAS do out[#out] = nil end
		alTerminar(out)
	end)
end

local ventana
local function armar()
	ventana = M.VentanaSimple({
		nombre = "AlfaRutasDiario", titulo = L["Tu registro va lleno"], icono = "ic-misiones", ancho = 460, alto = 440,
		altoFila = 44,
		vacio = { lobo = "aullando", titulo = L["Nada que convenga soltar"], texto = L["Todas tus misiones valen la pena. Entrega las listas para hacer lugar."] },
		crear = function(fila)
			fila.Texto = K.Texto(fila, "cuerpo", "texto")
			fila.Texto:SetPoint("TOPLEFT", fila, "TOPLEFT", 10, -6)
			fila.Sub = K.Texto(fila, "pequeno", "textoTenue")
			fila.Sub:SetPoint("TOPLEFT", fila.Texto, "BOTTOMLEFT", 0, -2)
			fila.Boton = K.Boton(fila, L["Abandonar"], function(b)
				local d = b:GetParent().alfaDato
				if d and M.Grises then M.Grises.Abandonar(d.qid) end
			end, { tipo = "secundario", tam = "chico" })
			fila.Boton:SetPoint("RIGHT", fila, "RIGHT", -8, 0)
			fila.Texto:SetPoint("RIGHT", fila.Boton, "LEFT", -8, 0)
			fila.Sub:SetPoint("RIGHT", fila.Boton, "LEFT", -8, 0)
		end,
		pintar = function(fila, d)
			fila.alfaDato = d
			K.Escribir(fila.Texto, d.nivel and format(L["[%d] %s"], d.nivel, d.titulo or "") or (d.titulo or ""))
			K.Escribir(fila.Sub, d.por or "")
		end,
	})
end

function Di.Abrir()
	if enCombate() then
		M.Aviso(L["Tu registro va lleno"], L["Se puede al salir de combate."], { icono = "ic-aviso", tono = "aviso" })
		return false
	end
	local I = M.Indice
	local ok, motivo = I.CodexListo()
	if not ok then
		M.Aviso(L["Tu registro va lleno"], I.TextoMotivo(motivo), { icono = "ic-aviso", tono = "aviso" })
		return false
	end
	Di.Sugerencias(function(lista)
		if not ventana then armar() end
		local n, tope = Di.Cuantas(), Di.Tope()
		ventana:Llenar(lista or {}, L["Tu registro va lleno"], format(L["%d de %d"], n, tope),
			L["Estas son las que menos te sirven ahora. Suelta las que quieras: Alfa te pregunta antes de cada una."])
	end)
	return true
end

-- El aviso, una vez por cada misión de más (y otra vez si llegas al tope).
local avisadoEn = 0
function Di.Revisar()
	if not encendido() then return false end
	local n, tope = Di.Cuantas(), Di.Tope()
	if n < tope - CERCA then avisadoEn = 0 return false end
	if n <= avisadoEn then return false end
	avisadoEn = n
	local grises = 0
	local Cp, Ch = CP(), M.Cadenas
	if Cp and Cp.GetLogQuests and Ch and Ch.EsGris then
		for _, qid in ipairs(Cp.GetLogQuests() or {}) do
			if Ch.EsGris(qid) and not (Cp.IsQuestReadyForTurnIn and Cp.IsQuestReadyForTurnIn(qid)) then grises = grises + 1 end
		end
	end
	local texto
	if n >= tope then
		texto = L["Ya no te cabe otra. Te digo cuáles soltar: las que menos te sirven ahora."]
	elseif grises > 0 then
		texto = M.Plural(grises, L["Tienes %d gris que ya casi no da experiencia: buena para soltar."], L["Tienes %d grises que ya casi no dan experiencia: buenas para soltar."])
	else
		texto = L["Antes de tomar más, mira cuáles te conviene soltar (lejanas o de otra zona)."]
	end
	M.Aviso(format(L["Tu registro va %d de %d"], n, tope), texto, { icono = "ic-misiones", tono = "aviso", clave = "rutas.diarioLleno",
		accion = { texto = L["Ver cuáles"], alClic = function() Di.Abrir() end } })
	return true
end

A.RegisterEvent("QUEST_ACCEPTED", function()
	if not encendido() then return end
	A.After(1, function()
		if N.FueraDeCombate then N.FueraDeCombate("rutas.diarioLleno", Di.Revisar) else Di.Revisar() end
	end)
end)
A.RegisterEvent("QUEST_REMOVED", function()
	if ventana and ventana:IsShown() then A.After(0.5, function() if ventana:IsShown() then Di.Abrir() end end) end
end)
