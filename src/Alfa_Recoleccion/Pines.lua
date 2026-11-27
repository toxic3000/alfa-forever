-- Alfa - Recolección: el aspecto de un pin y su cuadro de información
-- (toxic3000 / La Jauría, GPL-3.0). Lo comparten el mapa del mundo y el minimapa.
--
-- Un pin: un disco oscuro, el ícono del recurso recortado en círculo y un
-- aro del color de su tipo (cobre la minería, verde las hierbas, azul la
-- pesca, oro los tesoros). Lo que tu habilidad todavía no alcanza se ve gris
-- y tenue. Un grupo de nodos juntos (el mapa alejado) lleva su cantidad.

local _, M = ...
local N = AlfaNucleo
local A = N.A
local T = A.Theme
local R = M.R
local L = N.Textos(M.EN)

local P = {}
M.P = P

local NAV = (A.Nav and A.Nav.MEDIA) or "Interface\\AddOns\\Alfa\\Media\\Nav\\"
local ARO = NAV .. "ring"
local CIRCULO = T.Media("circle")

local function fuente(fs, tam)
	if T.SetFace and T.FontSpec then
		T.SetFace(fs, (T.FontSpec("number")), tam, "OUTLINE")
	else
		fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", tam, "OUTLINE")
	end
end

function P.Construir(f)
	f.fondo = f:CreateTexture(nil, "BACKGROUND")
	f.fondo:SetTexture(CIRCULO)
	f.fondo:SetPoint("CENTER")
	f.icono = f:CreateTexture(nil, "ARTWORK")
	f.icono:SetPoint("CENTER")
	if f.CreateMaskTexture and f.icono.AddMaskTexture then
		f.mascara = f:CreateMaskTexture()
		f.mascara:SetTexture(CIRCULO, "CLAMPTOBLACKADDITIONAL", "CLAMPTOBLACKADDITIONAL")
		f.mascara:SetAllPoints(f.icono)
		f.icono:AddMaskTexture(f.mascara)
	end
	f.aro = f:CreateTexture(nil, "OVERLAY")
	f.aro:SetTexture(ARO)
	f.aro:SetPoint("CENTER")
	f.cuenta = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	f.cuenta:SetPoint("CENTER", f, "BOTTOMRIGHT", -1, 2)
	f.cuenta:Hide()
	return f
end

-- 1.4.2: lo que recolectaste hace poco todavía no vuelve (el juego tarda unos
-- minutos en hacerlo reaparecer): su pin se ve tenue y su cuadro dice hace
-- cuánto. Ajuste recoleccion.recientes (sí). -> minutos desde entonces | nil
P.RECIENTE = 8 * 60
function P.Reciente(rec, ahora)
	if type(rec) ~= "table" or N.Get(R.ID, "recientes") == false then return nil end
	local t = tonumber(rec.t)
	if not t then return nil end
	local s = (ahora or time()) - t
	if s < 0 or s >= P.RECIENTE then return nil end
	return math.floor(s / 60)
end

-- El pin f muestra el grupo g a `tam` unidades. tenue: tu habilidad no
-- alcanza. cuenta: cuántos nodos agrupa (nil o 1: uno solo). reciente
-- (1.4.2): lo recolectaste hace poco.
function P.Aplicar(f, g, tam, tenue, cuenta, reciente)
	cuenta = cuenta and cuenta > 1 and cuenta or nil
	reciente = reciente and true or nil
	if f.psG == g and f.psTam == tam and f.psTenue == tenue and f.psCuenta == cuenta and f.psReciente == reciente then return end
	f.psG, f.psTam, f.psTenue, f.psCuenta, f.psReciente = g, tam, tenue, cuenta, reciente
	local gr = M.GRUPOS[g]
	local tex, glifo = R.Icono(g)
	f:SetSize(tam, tam)
	f.icono:SetTexture(tex)
	if glifo then
		f.icono:SetTexCoord(0, 1, 0, 1)
		f.icono:SetSize(tam * 0.78, tam * 0.78)
		local c = M.TIPO.tesoros.color
		f.icono:SetVertexColor(c[1], c[2], c[3], 1)
	else
		f.icono:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		f.icono:SetSize(tam, tam)
		f.icono:SetVertexColor(1, 1, 1, 1)
	end
	if f.icono.SetDesaturated then f.icono:SetDesaturated((tenue or reciente) and true or false) end
	f.fondo:SetSize(tam * 1.2, tam * 1.2)
	local sr, sg, sb = T.Color("scrim")
	f.fondo:SetVertexColor(sr or 0.04, sg or 0.05, sb or 0.08, 0.82)
	local c = gr and M.TIPO[gr.tipo] and M.TIPO[gr.tipo].color or { 1, 1, 1 }
	f.aro:SetSize(tam * 1.42, tam * 1.42)
	f.aro:SetVertexColor(c[1], c[2], c[3], reciente and 0.3 or (tenue and 0.45 or 0.95))
	f:SetAlpha(P.Alfa(tenue, reciente))
	if cuenta then
		fuente(f.cuenta, math.max(8, math.floor(tam * 0.62 + 0.5)))
		f.cuenta:SetText(cuenta > 99 and "99+" or tostring(cuenta))
		f.cuenta:SetTextColor(1, 1, 1, 1)
		f.cuenta:Show()
	else
		f.cuenta:Hide()
	end
end

-- Lo transparente de un pin: el recién recolectado, más que el que no alcanzas.
function P.Alfa(tenue, reciente)
	if reciente then return 0.38 end
	return tenue and 0.6 or 1
end

---------------------------------------------------------------------------
-- Cuadro de información
---------------------------------------------------------------------------
local function fecha(t)
	if type(t) ~= "number" then return nil end
	return date("%d/%m %H:%M", t)
end

local function icono(g, tam)
	local tex = R.Icono(g)
	return ("|T%s:%d:%d:0:0:64:64:5:59:5:59|t"):format(tostring(tex), tam, tam)
end

-- Requisito: "Requiere Minería (65)" en el color de tu habilidad, o qué es.
local function requisito(tip, g)
	local gr = M.GRUPOS[g]
	local oficio = R.NombreOficio(gr.tipo)
	if gr.niveles and oficio then
		local r, gg, b = R.ColorNivel(g)
		local rango = R.Habilidad(gr.tipo)
		local linea = L["Requiere %s (%d)"]:format(oficio, gr.niveles[1])
		if rango then linea = linea .. "  " .. L["(tienes %d)"]:format(rango) end
		tip:AddLine(linea, r, gg, b)
	else
		tip:AddLine(R.NombreTipo(gr.tipo), 0.65, 0.65, 0.65)
	end
end

local function historia(tip, rec)
	local veces = rec and tonumber(rec.n) or 0
	if veces > 0 then
		local texto = veces == 1 and L["Lo recolectaste 1 vez"] or L["Lo recolectaste %d veces"]:format(veces)
		local cuando = fecha(rec.t)
		if cuando then texto = texto .. "  ·  " .. L["última: %s"]:format(cuando) end
		tip:AddLine(texto, 0.55, 0.85, 1)
		-- 1.4.2: si fue hace poco, que no vayas en balde.
		local min = P.Reciente(rec)
		if min then
			tip:AddLine(min < 1 and L["Lo recolectaste hace un momento: aún no vuelve."]
				or N.Plural(min, L["Lo recolectaste hace %d minuto: puede que aún no vuelva."], L["Lo recolectaste hace %d minutos: puede que aún no vuelva."]), 1, 0.72, 0.3, true)
		end
	else
		tip:AddLine(L["Todavía no lo recolectas"], 0.6, 0.6, 0.6)
	end
end

-- Un nodo: idx y su índice i. pista: una línea final (qué hace el clic).
function P.Info(dueno, idx, i, pista, ancla)
	local tip = GameTooltip
	if not (tip and idx and idx.g[i]) then return end
	local g = idx.g[i]
	tip:SetOwner(dueno, ancla or "ANCHOR_RIGHT")
	tip:AddLine(icono(g, 16) .. " " .. R.Nombre(g), 1, 0.82, 0)
	requisito(tip, g)
	historia(tip, idx.d[i] or nil)
	if idx.base[i] and not idx.d[i] then
		tip:AddLine(L["De la base de datos incluida"], 0.5, 0.5, 0.5)
	end
	if pista then tip:AddLine(pista, 0.55, 0.55, 0.55, true) end
	tip:Show()
end

-- Varios nodos juntos: miembros = { i, ... } del mismo idx.
function P.InfoGrupo(dueno, idx, miembros, pista, ancla)
	local tip = GameTooltip
	if not (tip and idx and miembros and #miembros > 0) then return end
	if #miembros == 1 then return P.Info(dueno, idx, miembros[1], pista, ancla) end
	local porGrupo, orden, veces = {}, {}, 0
	for _, i in ipairs(miembros) do
		local g = idx.g[i]
		if not porGrupo[g] then
			porGrupo[g] = 0
			orden[#orden + 1] = g
		end
		porGrupo[g] = porGrupo[g] + 1
		local rec = idx.d[i]
		if rec then veces = veces + (tonumber(rec.n) or 0) end
	end
	table.sort(orden, function(a, b)
		if porGrupo[a] ~= porGrupo[b] then return porGrupo[a] > porGrupo[b] end
		return R.Nombre(a) < R.Nombre(b)
	end)
	tip:SetOwner(dueno, ancla or "ANCHOR_RIGHT")
	tip:AddLine(L["%d nodos en esta zona del mapa"]:format(#miembros), 1, 0.82, 0)
	for k, g in ipairs(orden) do
		if k > 8 then
			tip:AddLine(L["y %d recursos más"]:format(#orden - 8), 0.6, 0.6, 0.6)
			break
		end
		local gr = M.GRUPOS[g]
		local r, gg, b = 1, 1, 1
		if gr.niveles then r, gg, b = R.ColorNivel(g) end
		tip:AddDoubleLine(icono(g, 14) .. " " .. R.Nombre(g), "×" .. porGrupo[g], r, gg, b, 0.8, 0.8, 0.8)
	end
	if veces > 0 then tip:AddLine(N.Plural(veces, L["Los recolectaste %d vez en total"], L["Los recolectaste %d veces en total"]), 0.55, 0.85, 1) end
	if pista then tip:AddLine(pista, 0.55, 0.55, 0.55, true) end
	tip:Show()
end
